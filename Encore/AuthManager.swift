import Foundation
import Combine
import Supabase
import SwiftUI
import LocalAuthentication
import GoogleSignIn
import AuthenticationServices
import CryptoKit
import OSLog

// MARK: - Google Sign-In Outcome (Sendable bridge out of the SDK callback)
private struct GoogleCredentialPayload: Sendable {
    let idToken: String
    let email: String
    let name: String
    let sub: String
    let avatar: String
    /// Raw nonce that belongs to the hashed one sent to Google. nil when no nonce was used.
    let nonce: String?
}

private enum GoogleSignInOutcome: Sendable {
    case success(GoogleCredentialPayload)
    case cancelled
    case failure(String)
}

// MARK: - Supabase Auth Manager
// Single source of truth: the user is "authenticated" if and only if a Supabase session exists.
// The session lives in the Keychain (supabase-swift default) and is refreshed automatically,
// so a temporarily expired access token or a lost network connection never logs the user out.
@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var currentUser: User? = nil
    @Published var isAuthenticated: Bool
    @Published var isCheckingInitialAuth: Bool = true
    @Published var isLoading = false
    @Published var authErrorMessage: String? = nil
    @Published var authSuccessMessage: String? = nil
    @Published var showSettingsLink: Bool = false
    /// Presented globally (RootAppView) after the user opens a password-recovery link.
    @Published var showPasswordRecoverySheet: Bool = false
    /// Set after a sign-up that still needs the e-mail code; the login screen shows the code entry.
    @Published var pendingConfirmationEmail: String? = nil

    @AppStorage("profileName") var userName: String = "Tanečník"
    @AppStorage("userEmail")   var userEmail: String = ""
    @AppStorage("userAvatarURL") var userAvatarURL: String = ""
    @AppStorage("googleSubId") var googleSubId: String = ""
    /// Off until the user turns it on (Settings or the offer after the first sign-in); turning it on
    /// asks for Face ID first, so only the owner of the iPhone can enable it.
    @AppStorage("isBiometricsEnabled") var isBiometricsEnabled: Bool = false

    /// App lock: with Face ID sign-in on, the user stays signed in and unlocks Encore with Face ID
    /// when opening it (after a restart or more than 5 minutes in the background).
    @Published var isAppLocked = false
    private var backgroundedAt: Date?
    private static let lockGracePeriod: TimeInterval = 5 * 60

    private static let authCallbackURL = URL(string: "encore://auth-callback")!
    private static let pendingResetKey = "encore_pending_password_reset_at"
    private static let freshInstallKey = "encore.hasLaunchedBefore"

    // Uses the shared SupabaseConfig.client singleton
    nonisolated private var client: SupabaseClient? { SupabaseConfig.client }

    private init() {
        self.isAuthenticated = false
        self.isCheckingInitialAuth = true

        // Older builds stored the password / a refresh-token copy; remove them.
        KeychainHelper.shared.purgeLegacySecrets()

        Task { await checkInitialAuth() }
    }

    // MARK: - Initial Auth Restoration
    private func checkInitialAuth() async {
        await signOutLeftoverSessionAfterReinstall()
        Task { await startAuthListener() }

        if let client {
            // 1. Apply the locally cached session immediately (no flash of the login screen).
            // Even if the access token is expired, Supabase refreshes it with the refresh token.
            if let local = client.auth.currentSession {
                applySession(local)
            }

            do {
                let session = try await client.auth.session
                applySession(session)
            } catch {
                // Offline / temporary failure → NEVER clear the local session here.
                // A truly revoked refresh token is reported by the listener as .signedOut.
                Logger.auth.debug("[AuthManager] Initial session check note: \(error.localizedDescription, privacy: .public)")
            }
        }

        // 2. Silent Google restore – only when Supabase has no session at all.
        if !isAuthenticated {
            _ = await restoreGoogleSignInAsync(silent: true)
        }

        // A restored session opens locked when Face ID sign-in is on; a fresh sign-in never does.
        if isAuthenticated && isBiometricsEnabled { isAppLocked = true }
        isCheckingInitialAuth = false
    }

    /// The Keychain survives deleting the app, but the local database does not. After a reinstall the
    /// user would look signed in with an empty app, so a fresh install starts signed out.
    /// An update keeps UserDefaults (the stored e-mail), so it is not treated as a fresh install.
    private func signOutLeftoverSessionAfterReinstall() async {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.freshInstallKey) else { return }
        defaults.set(true, forKey: Self.freshInstallKey)
        guard userEmail.isEmpty else { return }
        if let client, client.auth.currentSession != nil {
            try? await client.auth.signOut(scope: .local)
        }
        KeychainHelper.shared.deleteCredentials()
    }

    // MARK: - Reactive Auth State Listener
    private func startAuthListener() async {
        guard let client else {
            isCheckingInitialAuth = false
            return
        }
        for await (event, session) in client.auth.authStateChanges {
            switch event {
            case .initialSession:
                if let s = session {
                    applySession(s)
                } else if !isAuthenticated {
                    clearSession()
                }
                isCheckingInitialAuth = false
            case .signedIn, .tokenRefreshed, .userUpdated:
                if let s = session { applySession(s) }
                isCheckingInitialAuth = false
            case .passwordRecovery:
                if let s = session { applySession(s) }
                showPasswordRecoverySheet = true
                isCheckingInitialAuth = false
            case .signedOut, .userDeleted:
                clearSession()
                isCheckingInitialAuth = false
            default:
                break
            }
        }
    }

    private func applySession(_ session: Session) {
        let isNewUser = currentUser?.id != session.user.id
        // Before anything is shown or synced for a different account, drop the previous one's data.
        if isNewUser { LocalDataGuard.claim(for: session.user.id) }
        currentUser = session.user
        isAuthenticated = true
        if let email = session.user.email, !email.isEmpty {
            userEmail = email
        }
        if let metaName = session.user.userMetadata["name"] {
            if case let .string(str) = metaName, !str.isEmpty {
                userName = str
            }
        }
        // Token refreshes arrive as new sessions too; only a real user change reloads the profile and the
        // routines (after an account switch or on a new iPhone the list would stay empty until a pull-to-refresh).
        if isNewUser {
            UserProfileStore.shared.refreshForActiveUser()
            Task { await SupabaseSyncManager.shared.pullRoutinesIntoApp() }
        }
    }

    private func clearSession() {
        isAppLocked = false
        currentUser = nil
        isAuthenticated = false
        userEmail = ""
        userName = "Tanečník"
        UserProfileStore.shared.refreshForActiveUser()
    }

    /// Remembers only the e-mail (to pre-fill the form) and the provider (to offer the right
    /// quick-login). Passwords and tokens are never stored by us: the Supabase SDK keeps the
    /// session in the Keychain, and iOS AutoFill / iCloud Keychain handles saved passwords.
    private func persistLogin(email: String, provider: String) {
        KeychainHelper.shared.saveSession(email: email, provider: provider)
    }

    // MARK: - Saved Credentials Info
    var savedEmail: String? {
        let fromKeychain = KeychainHelper.shared.readSession()?.email
        if let fromKeychain, !fromKeychain.isEmpty { return fromKeychain }
        return userEmail.isEmpty ? nil : userEmail
    }

    /// True when the login screen can honestly offer biometric login: a Supabase session that
    /// can still be restored, or a previous Google sign-in.
    var canUseBiometricLogin: Bool {
        guard isBiometricsEnabled else { return false }
        if client?.auth.currentSession != nil { return true }
        if KeychainHelper.shared.readSession()?.provider == "google" {
            return GIDSignIn.sharedInstance.hasPreviousSignIn()
        }
        return false
    }

    /// The account is linked to Sign in with Apple (its tokens must be revoked on deletion).
    var isAppleAccount: Bool {
        guard let user = currentUser else { return false }
        if let identities = user.identities, identities.contains(where: { $0.provider == "apple" }) { return true }
        if case let .array(providers)? = user.appMetadata["providers"] {
            return providers.contains(.string("apple"))
        }
        return false
    }

    /// Only users who registered with e-mail + password have a password to change.
    var canChangePassword: Bool {
        guard isAuthenticated, let user = currentUser else { return false }
        if let identities = user.identities, !identities.isEmpty {
            return identities.contains { $0.provider == "email" }
        }
        if case let .string(provider)? = user.appMetadata["provider"] {
            return provider == "email"
        }
        return false
    }

    var biometryType: LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }

    var biometryName: String {
        switch biometryType {
        case .touchID: return "Touch ID"
        case .faceID:  return "Face ID"
        case .opticID: return "Optic ID"
        default:       return "Face ID"
        }
    }

    var biometrySystemImage: String {
        switch biometryType {
        case .touchID: return "touchid"
        case .faceID:  return "faceid"
        case .opticID: return "opticid"
        default:       return "faceid"
        }
    }

    // Called on scenePhase → active. NEVER destroys the local session on a network error.
    func checkCurrentSession() async {
        guard let client, isAuthenticated else { return }
        do {
            let session = try await client.auth.session
            applySession(session)
        } catch {
            Logger.auth.debug("[AuthManager] Background session check note: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static let missingConfigMessage = "Chyba spojenia: Chýba platná konfigurácia Supabase servera."

    /// Keeps only the digits of a pasted code ("123 456" -> "123456").
    private static func digits(_ text: String) -> String {
        text.filter { $0.isASCII && $0.isNumber }
    }

    // MARK: - Sign In (Email & Password)
    func signIn(email: String, pass: String) async -> Bool {
        guard let client else {
            authErrorMessage = Self.missingConfigMessage
            return false
        }
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        // Passwords may legitimately contain leading/trailing spaces – never trim them.
        guard !cleanEmail.isEmpty, !pass.isEmpty else {
            authErrorMessage = "Zadaj prosím e-mail aj heslo."
            return false
        }
        guard EmailValidator.isValid(cleanEmail) else {
            authErrorMessage = "Zadaj platný formát e-mailovej adresy (napr. meno@domena.sk)."
            return false
        }

        isLoading = true
        authErrorMessage = nil
        authSuccessMessage = nil
        defer { isLoading = false }
        do {
            let session = try await client.auth.signIn(email: cleanEmail, password: pass)
            applySession(session)
            persistLogin(email: cleanEmail, provider: "email")
            return true
        } catch {
            // Registered but never confirmed: send a fresh code and go straight to code entry.
            if let authError = error as? AuthError, authError.errorCode == .emailNotConfirmed {
                try? await client.auth.resend(email: cleanEmail, type: .signup, emailRedirectTo: Self.authCallbackURL)
                pendingConfirmationEmail = cleanEmail
                return false
            }
            authErrorMessage = friendlyAuthError(from: error, isSignUp: false)
            return false
        }
    }

    // MARK: - Sign Up (Email & Password)
    func signUp(email: String, pass: String, name: String, danceRole: String = "dancer", ageConfirmed: Bool) async -> Bool {
        guard let client else {
            authErrorMessage = Self.missingConfigMessage
            return false
        }
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanName.isEmpty, cleanName.count <= NameRules.maxLength else {
            authErrorMessage = "Zadaj meno (najviac \(NameRules.maxLength) znakov)."
            return false
        }
        guard EmailValidator.isValid(cleanEmail) else {
            authErrorMessage = "Zadaj platný formát e-mailovej adresy (napr. meno@domena.sk)."
            return false
        }
        if let issue = PasswordPolicy.issue(for: pass, email: cleanEmail) {
            authErrorMessage = issue
            return false
        }
        guard ageConfirmed else {
            authErrorMessage = "Potvrď vek, aby si mohol pokračovať."
            return false
        }

        isLoading = true
        authErrorMessage = nil
        authSuccessMessage = nil
        defer { isLoading = false }
        do {
            let response = try await client.auth.signUp(
                email: cleanEmail,
                password: pass,
                data: [
                    "name": .string(cleanName),
                    "platform": .string("ios"),
                    "last_platform": .string("ios"),
                    "client_type": .string("ios_native"),
                    "dance_role": .string(danceRole == "coach" ? "coach" : "dancer"),
                    "age_confirmed": .bool(true)
                ],
                redirectTo: Self.authCallbackURL
            )

            // Supabase hides "already registered" by returning a user without identities.
            if response.user.identities?.isEmpty == true {
                authErrorMessage = AuthErrorMapper.accountExists
                return false
            }

            if let session = response.session {
                applySession(session)
                userName = cleanName
                // Must run AFTER applySession so the profile is stored under the new user id.
                UserProfileStore.shared.saveProfile(name: cleanName, club: "")
                persistLogin(email: cleanEmail, provider: "email")
                return true
            } else {
                // The server wants the e-mail confirmed: the login screen asks for the code from the e-mail.
                persistLogin(email: cleanEmail, provider: "email")
                pendingConfirmationEmail = cleanEmail
                return false
            }
        } catch {
            authErrorMessage = friendlyAuthError(from: error, isSignUp: true)
            return false
        }
    }

    // MARK: - E-mail confirmation (code from the e-mail)
    /// Confirms the e-mail with the code from the message and signs the user in.
    /// Returns an error message, or nil on success.
    func verifySignupCode(_ rawCode: String) async -> String? {
        guard let client else { return Self.missingConfigMessage }
        guard let email = pendingConfirmationEmail else { return "Najprv sa zaregistruj alebo prihlás." }
        let code = Self.digits(rawCode)
        guard EmailCodePolicy.isComplete(code) else { return "Zadaj \(EmailCodePolicy.length)-miestny kód z e-mailu." }
        do {
            let response = try await client.auth.verifyOTP(email: email, token: code, type: .signup)
            guard let session = response.session else { return "Kód sa nepodarilo overiť. Skús to znova." }
            applySession(session)
            if case let .string(name)? = session.user.userMetadata["name"], !name.isEmpty {
                UserProfileStore.shared.saveProfile(name: name, club: "")
            }
            persistLogin(email: email, provider: "email")
            pendingConfirmationEmail = nil
            return nil
        } catch {
            return friendlyAuthError(from: error, fallbackPrefix: "Overenie zlyhalo")
        }
    }

    /// Sends a new confirmation code. Returns an error message, or nil on success.
    func resendSignupCode() async -> String? {
        guard let client else { return Self.missingConfigMessage }
        guard let email = pendingConfirmationEmail else { return "Najprv sa zaregistruj alebo prihlás." }
        do {
            try await client.auth.resend(email: email, type: .signup, emailRedirectTo: Self.authCallbackURL)
            return nil
        } catch {
            return friendlyAuthError(from: error, fallbackPrefix: "Odoslanie kódu zlyhalo")
        }
    }

    func cancelPendingConfirmation() {
        pendingConfirmationEmail = nil
    }

    // MARK: - Password Reset (forgot password)
    /// Sends a recovery e-mail (with a code). Returns an error message, or nil on success.
    /// Supabase answers identically for unknown addresses (no account enumeration).
    func sendPasswordReset(email: String) async -> String? {
        guard let client else { return Self.missingConfigMessage }
        let clean = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard EmailValidator.isValid(clean) else {
            return "Zadaj platný formát e-mailovej adresy (napr. meno@domena.sk)."
        }
        do {
            try await client.auth.resetPasswordForEmail(clean, redirectTo: Self.authCallbackURL)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.pendingResetKey)
            return nil
        } catch {
            return friendlyAuthError(from: error, fallbackPrefix: "Odoslanie kódu zlyhalo")
        }
    }

    /// Verifies the recovery code. On success the user holds a session and the app opens the
    /// "new password" sheet. Returns an error message, or nil on success.
    func verifyRecoveryCode(email: String, code rawCode: String) async -> String? {
        guard let client else { return Self.missingConfigMessage }
        let clean = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let code = Self.digits(rawCode)
        guard EmailCodePolicy.isComplete(code) else { return "Zadaj \(EmailCodePolicy.length)-miestny kód z e-mailu." }
        do {
            let response = try await client.auth.verifyOTP(email: clean, token: code, type: .recovery)
            guard let session = response.session else { return "Kód sa nepodarilo overiť. Skús to znova." }
            UserDefaults.standard.removeObject(forKey: Self.pendingResetKey)
            applySession(session)
            showPasswordRecoverySheet = true
            return nil
        } catch {
            return friendlyAuthError(from: error, fallbackPrefix: "Overenie zlyhalo")
        }
    }

    /// Sets a new password for the current session (used after the recovery code or link).
    /// Ends every other session so a stolen token stops working. Returns an error message, or nil.
    func setNewPassword(_ newPassword: String) async -> String? {
        guard let client else { return Self.missingConfigMessage }
        let email = currentUser?.email ?? userEmail
        if let issue = PasswordPolicy.issue(for: newPassword, email: email) { return issue }
        do {
            _ = try await client.auth.update(user: UserAttributes(password: newPassword))
            persistLogin(email: email, provider: "email")
            UserDefaults.standard.removeObject(forKey: Self.pendingResetKey)
            try? await client.auth.signOut(scope: .others)
            return nil
        } catch {
            return friendlyAuthError(from: error, fallbackPrefix: "Zmena hesla zlyhala")
        }
    }

    /// Changes the password of a signed-in e-mail user after verifying the current one.
    /// Returns an error message, or nil on success.
    func changePassword(current: String, new newPassword: String) async -> String? {
        guard let client else { return Self.missingConfigMessage }
        let email = (currentUser?.email ?? userEmail).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else { return "Nepodarilo sa zistiť e-mail účtu. Prihlás sa znova." }
        guard !current.isEmpty else { return "Zadaj súčasné heslo." }
        guard newPassword != current else { return "Nové heslo musí byť iné ako súčasné." }
        if let issue = PasswordPolicy.issue(for: newPassword, email: email) { return issue }

        // Re-verify the current password (also guarantees a fresh session for the update).
        do {
            let session = try await client.auth.signIn(email: email, password: current)
            applySession(session)
        } catch {
            if let authError = error as? AuthError, authError.errorCode == .invalidCredentials {
                return "Súčasné heslo nie je správne."
            }
            return friendlyAuthError(from: error, fallbackPrefix: "Overenie hesla zlyhalo")
        }
        return await setNewPassword(newPassword)
    }

    // MARK: - Biometric Auth (Face ID / Touch ID)
    /// Face ID / Touch ID, or the iPhone passcode when biometrics are not set up.
    /// Used before sensitive actions (turning on quick sign-in, deleting the account).
    /// Returns true when the device has no passcode at all, because there is nothing to verify with.
    func confirmDeviceOwner(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Zrušiť"
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else { return true }
        return (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) ?? false
    }

    // MARK: - App lock
    func appDidEnterBackground() {
        backgroundedAt = Date()
    }

    func appDidBecomeActive() {
        defer { backgroundedAt = nil }
        guard isAuthenticated, isBiometricsEnabled, let backgroundedAt,
              Date().timeIntervalSince(backgroundedAt) > Self.lockGracePeriod else { return }
        isAppLocked = true
    }

    func unlockApp() async {
        if await confirmDeviceOwner(reason: "Odomknúť Encore") {
            isAppLocked = false
        }
    }

    /// Offered once per account, right after the first sign-in on this iPhone.
    var shouldOfferBiometricLogin: Bool {
        guard isAuthenticated, !isBiometricsEnabled, let id = currentUser?.id.uuidString else { return false }
        guard !UserDefaults.standard.bool(forKey: "biometricOfferShown_\(id)") else { return false }
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    func markBiometricOfferShown() {
        guard let id = currentUser?.id.uuidString else { return }
        UserDefaults.standard.set(true, forKey: "biometricOfferShown_\(id)")
    }

    /// Turns quick sign-in on after Face ID confirms the owner; turning it off needs no check.
    func setBiometricLogin(_ enabled: Bool) async {
        guard enabled else {
            isBiometricsEnabled = false
            return
        }
        if await confirmDeviceOwner(reason: "Zapnúť prihlásenie cez \(biometryName)") {
            isBiometricsEnabled = true
        }
    }

    func authenticateWithBiometrics() async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Zrušiť"
        var error: NSError?
        showSettingsLink = false

        let canEvaluateBiometrics = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        let canEvaluatePasscode = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)

        guard canEvaluateBiometrics || canEvaluatePasscode else {
            showSettingsLink = true
            if let laError = error as? LAError, laError.code == .biometryLockout {
                authErrorMessage = "\(biometryName) je zablokované. Odomkni iPhone kódom alebo prejdi do Nastavení."
            } else {
                authErrorMessage = "\(biometryName) nie je na tomto zariadení povolené. Povoľ ho v Nastaveniach iPhonu."
            }
            return false
        }

        let policy: LAPolicy = canEvaluateBiometrics ? .deviceOwnerAuthenticationWithBiometrics : .deviceOwnerAuthentication

        isLoading = true
        authErrorMessage = nil
        defer { isLoading = false }

        do {
            let reason = "Prihlásiť sa do Encore pomocou \(biometryName)"
            let success = try await context.evaluatePolicy(policy, localizedReason: reason)
            guard success else {
                authErrorMessage = "\(biometryName) overenie nebolo úspešné."
                return false
            }

            // 1. A refreshable Supabase session is still around.
            if let client = self.client {
                if let local = client.auth.currentSession {
                    applySession(local)
                    return true
                }
                if let session = try? await client.auth.session {
                    applySession(session)
                    return true
                }
            }

            // 2. No restorable session: fall back to the previous Google sign-in, if any.
            let saved = KeychainHelper.shared.readSession()
            let email = saved?.email ?? userEmail
            let provider = saved?.provider ?? "email"

            if provider == "google" {
                if await restoreGoogleSignInAsync(silent: false) { return true }
                if authErrorMessage == nil {
                    authErrorMessage = "Platnosť Google prihlásenia vypršala. Ťukni na Pokračovať cez Google."
                }
                return false
            }

            if !email.isEmpty {
                authErrorMessage = "Platnosť prihlásenia pre \(email) vypršala. Prihlás sa heslom (môžeš použiť automatické dopĺňanie) alebo cez Google."
            } else {
                authErrorMessage = "Na tomto zariadení zatiaľ nie sú uložené prihlasovacie údaje. Prihlás sa najprv e-mailom, cez Google alebo Apple."
            }
            return false

        } catch let laError as LAError {
            if laError.code == .biometryNotAvailable || laError.code == .biometryLockout {
                showSettingsLink = true
                authErrorMessage = "\(biometryName) je pre Encore zablokované. Povoľ ho v Nastaveniach iPhonu."
            } else if laError.code == .userCancel || laError.code == .appCancel || laError.code == .systemCancel {
                authErrorMessage = nil
            } else {
                authErrorMessage = "Biometrické overenie zlyhalo."
            }
            return false
        } catch {
            authErrorMessage = "Biometrické overenie zlyhalo alebo bolo zrušené."
            return false
        }
    }

    // MARK: - Friendly Error Translation
    private func friendlyAuthError(from error: Error, isSignUp: Bool) -> String {
        friendlyAuthError(from: error, fallbackPrefix: isSignUp ? "Registrácia zlyhala" : "Prihlásenie zlyhalo")
    }

    private func friendlyAuthError(from error: Error, fallbackPrefix: String) -> String {
        AuthErrorMapper.message(for: error, fallback: fallbackPrefix)
    }

    // MARK: - Google Sign In (native SDK → Supabase ID-token exchange)
    func signInWithGoogleNative(presenting rootViewController: UIViewController) async -> Bool {
        isLoading = true
        authErrorMessage = nil
        authSuccessMessage = nil
        defer { isLoading = false }

        // Google puts the nonce into the ID token and Supabase checks it: Google gets the SHA-256 hash,
        // Supabase gets the raw value. Without it the server rejects the token
        // ("Passed nonce and nonce in id_token should either both exist or not").
        let rawNonce = AuthManager.randomNonceString()
        let hashedNonce = AuthManager.sha256(rawNonce)

        let outcome: GoogleSignInOutcome = await withCheckedContinuation { continuation in
            GIDSignIn.sharedInstance.signIn(
                withPresenting: rootViewController,
                hint: nil,
                additionalScopes: nil,
                nonce: hashedNonce
            ) { signInResult, error in
                if let error {
                    let nsError = error as NSError
                    if nsError.code == GIDSignInError.canceled.rawValue {
                        continuation.resume(returning: .cancelled)
                    } else {
                        Logger.auth.error("[GoogleSignIn] Error: \(error.localizedDescription, privacy: .public)")
                        continuation.resume(returning: .failure(
                            AuthErrorMapper.message(for: error, fallback: "Prihlásenie cez Google zlyhalo")
                        ))
                    }
                    return
                }
                guard let user = signInResult?.user, let idToken = user.idToken?.tokenString else {
                    continuation.resume(returning: .failure("Nepodarilo sa získať Google token."))
                    return
                }
                continuation.resume(returning: .success(GoogleCredentialPayload(
                    idToken: idToken,
                    email: user.profile?.email ?? "",
                    name: user.profile?.name ?? "Tanečník",
                    sub: user.userID ?? "",
                    avatar: user.profile?.imageURL(withDimension: 200)?.absoluteString ?? "",
                    nonce: rawNonce
                )))
            }
        }

        switch outcome {
        case .cancelled:
            return false
        case .failure(let message):
            authErrorMessage = message
            return false
        case .success(let payload):
            return await completeGoogleLogin(payload, silent: false)
        }
    }

    /// Exchanges a Google ID token for a Supabase session. The user only becomes authenticated
    /// when the exchange really succeeded – no half-logged-in state without a server session.
    private func completeGoogleLogin(_ payload: GoogleCredentialPayload, silent: Bool) async -> Bool {
        guard let client else {
            if !silent { authErrorMessage = "Chyba spojenia: Chýba platná konfigurácia Supabase servera." }
            return false
        }
        do {
            let session = try await client.auth.signInWithIdToken(
                credentials: .init(provider: .google, idToken: payload.idToken, nonce: payload.nonce)
            )
            applySession(session)
            if userName == "Tanečník" { userName = payload.name }
            googleSubId = payload.sub
            if !payload.avatar.isEmpty { userAvatarURL = payload.avatar }
            persistLogin(email: session.user.email ?? payload.email, provider: "google")
            AnalyticsManager.shared.signInGoogle()
            Logger.auth.info("[GoogleSignIn] Supabase session established.")
            return true
        } catch {
            Logger.auth.error("[GoogleSignIn] Supabase token exchange error: \(error.localizedDescription, privacy: .public)")
            if !silent {
                authErrorMessage = friendlyAuthError(from: error, fallbackPrefix: "Google prihlásenie zlyhalo")
            }
            return false
        }
    }

    // MARK: - Restore Google Sign In
    private func restoreGoogleSignInAsync(silent: Bool) async -> Bool {
        guard GIDSignIn.sharedInstance.hasPreviousSignIn() else { return false }

        let payload: GoogleCredentialPayload? = await withCheckedContinuation { continuation in
            GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
                guard let user, error == nil, let idToken = user.idToken?.tokenString else {
                    if let error {
                        Logger.auth.debug("[GoogleSignIn] Silent restore note: \(error.localizedDescription, privacy: .public)")
                    }
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: GoogleCredentialPayload(
                    idToken: idToken,
                    email: user.profile?.email ?? "",
                    name: user.profile?.name ?? "Tanečník",
                    sub: user.userID ?? "",
                    avatar: user.profile?.imageURL(withDimension: 200)?.absoluteString ?? "",
                    nonce: nil
                ))
            }
        }

        guard let payload else { return false }
        return await completeGoogleLogin(payload, silent: silent)
    }

    // MARK: - Sign in with Apple
    private var currentAppleNonce: String?

    /// Call from the SignInWithAppleButton's onRequest to get the hashed nonce to attach to the request.
    func startAppleSignInNonce() -> String {
        let nonce = AuthManager.randomNonceString()
        currentAppleNonce = nonce
        return AuthManager.sha256(nonce)
    }

    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if status != errSecSuccess {
            return UUID().uuidString + UUID().uuidString
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Call after ASAuthorizationAppleIDCredential returns an identityToken.
    func signInWithApple(idToken: String, fullName: String? = nil, email: String? = nil) async -> Bool {
        guard let client else {
            authErrorMessage = "Chyba spojenia: Chýba platná konfigurácia Supabase servera."
            return false
        }
        guard let nonce = currentAppleNonce else {
            authErrorMessage = "Chyba prihlásenia cez Apple: chýba bezpečnostný nonce. Skús to znova."
            return false
        }
        isLoading = true
        authErrorMessage = nil
        authSuccessMessage = nil
        defer { isLoading = false; currentAppleNonce = nil }

        do {
            let session = try await client.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
            )
            applySession(session)
            // Apple only sends the name / e-mail on the very first authorization.
            if let fullName, !fullName.isEmpty {
                userName = fullName
                UserProfileStore.shared.saveProfile(name: fullName, club: "")
            }
            persistLogin(email: session.user.email ?? email ?? userEmail, provider: "apple")
            AnalyticsManager.shared.signInApple()
            return true
        } catch {
            Logger.auth.error("[AppleSignIn] Supabase token exchange error: \(error.localizedDescription, privacy: .public)")
            authErrorMessage = friendlyAuthError(from: error, fallbackPrefix: "Prihlásenie cez Apple zlyhalo")
            return false
        }
    }

    // MARK: - Google OAuth Sign In (system web sheet fallback)
    /// Used when the native Google sheet cannot be presented. Runs in an ASWebAuthenticationSession
    /// and only reports success when a real session was created.
    func signInWithGoogle() async -> Bool {
        guard let client else { return false }
        isLoading = true
        authErrorMessage = nil
        defer { isLoading = false }
        do {
            let session = try await client.auth.signInWithOAuth(provider: .google, redirectTo: Self.authCallbackURL)
            applySession(session)
            persistLogin(email: session.user.email ?? userEmail, provider: "google")
            AnalyticsManager.shared.signInGoogle()
            return true
        } catch {
            if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin { return false }
            authErrorMessage = friendlyAuthError(from: error, fallbackPrefix: "Prihlásenie cez Google zlyhalo")
            return false
        }
    }

    // MARK: - Deep Link (e-mail confirmation / OAuth callback / password recovery)
    /// Only `encore://auth-callback…` URLs belong to Supabase Auth. Friend-invite links
    /// (which can carry a `code` query item too) are routed elsewhere by the app.
    func handleDeepLink(_ url: URL) async {
        guard url.scheme == "encore", url.host == "auth-callback" else { return }
        // The app uses PKCE: a real callback carries a one-time `code` that only works with the verifier
        // stored on this device. A link carrying ready tokens could sign this device into someone else's account.
        let carriesTokens = [url.fragment ?? "", url.query ?? ""].contains { $0.contains("access_token") || $0.contains("refresh_token") }
        guard !carriesTokens else {
            Logger.auth.warning("[AuthManager] Ignored an auth callback that carried tokens")
            return
        }
        guard let client else { return }
        do {
            let session = try await client.auth.session(from: url)
            applySession(session)

            // A link only proves the e-mail; the code flow is the main path. No misleading
            // "e-mail confirmed" text here: this also runs for OAuth and recovery links.
            showPasswordRecoverySheet = isRecoveryLink(url)
            authSuccessMessage = nil
            authErrorMessage = nil
        } catch {
            Logger.auth.error("[AuthManager] Deep link error: \(error.localizedDescription, privacy: .public)")
            authErrorMessage = friendlyAuthError(from: error, fallbackPrefix: "Odkaz sa nepodarilo spracovať")
        }
    }

    /// Implicit flow marks recovery links with `type=recovery`. PKCE links only carry a `code`,
    /// so we also remember that a reset was requested from this device in the last hour.
    private func isRecoveryLink(_ url: URL) -> Bool {
        if url.absoluteString.contains("type=recovery") { return true }
        let defaults = UserDefaults.standard
        let requestedAt = defaults.double(forKey: Self.pendingResetKey)
        defaults.removeObject(forKey: Self.pendingResetKey)
        guard requestedAt > 0 else { return false }
        return Date().timeIntervalSince1970 - requestedAt < 3600
    }

    // MARK: - Sign Out
    func signOut(forgetDevice: Bool = false) async {
        GIDSignIn.sharedInstance.signOut()
        userAvatarURL = ""
        googleSubId = ""

        if let client {
            // .local: sign out this device only – don't kick the user off their other devices.
            try? await client.auth.signOut(scope: .local)
        }

        if forgetDevice {
            KeychainHelper.shared.deleteCredentials()
            isBiometricsEnabled = false
        }
        clearSession()
    }

    // MARK: - Delete Account (Apple Guideline 5.1.1(v), GDPR art. 17)
    /// Deletes the account on the server (files, data, login) and only then cleans this device.
    /// Returns nil when the server confirmed the deletion, otherwise a message for the user;
    /// in that case nothing was deleted and the user stays signed in.
    func deleteAccount() async -> String? {
        guard let client else { return Self.missingConfigMessage }

        var body = ["confirm": "DELETE"]
        if isAppleAccount {
            // Apple requires revoking its tokens; that needs a fresh code from Apple.
            guard let code = await AppleReauthorization.authorizationCode() else {
                return "Na zmazanie účtu sa potvrď cez Apple. Nič nebolo zmazané."
            }
            body["appleAuthorizationCode"] = code
        }

        do {
            try await client.functions.invoke(
                "delete-account",
                options: FunctionInvokeOptions(body: body)
            )
        } catch {
            Logger.auth.error("[AuthManager] delete-account failed: \(error.localizedDescription, privacy: .public)")
            if (error as NSError).domain == NSURLErrorDomain {
                return friendlyAuthError(from: error, fallbackPrefix: "Účet sa nepodarilo zmazať")
            }
            return "Účet sa nepodarilo zmazať. Nič nebolo zmazané. Skús to znova alebo napíš na podporu."
        }

        if GIDSignIn.sharedInstance.hasPreviousSignIn() {
            try? await GIDSignIn.sharedInstance.disconnect()
        }
        AppleWalletPassManager.shared.removePassFromWallet()
        userAvatarURL = ""
        googleSubId = ""
        try? await client.auth.signOut(scope: .local)
        LocalDataGuard.wipeAll()
        LocalDataGuard.forgetOwner()
        KeychainHelper.shared.deleteCredentials()
        isBiometricsEnabled = false
        clearSession()
        return nil
    }
}
