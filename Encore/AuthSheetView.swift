import SwiftUI
import AuthenticationServices

// MARK: - Native Official Google "G" Vector Mark
struct GoogleLogoView: View {
    var size: CGFloat = 18

    var body: some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 24.0
            
            // 1. Blue: M 22.56 12.25
            var pBlue = Path()
            pBlue.move(to: CGPoint(x: 22.56 * s, y: 12.25 * s))
            pBlue.addCurve(to: CGPoint(x: 22.36 * s, y: 10.0 * s), control1: CGPoint(x: 22.56 * s, y: 11.47 * s), control2: CGPoint(x: 22.49 * s, y: 10.72 * s))
            pBlue.addLine(to: CGPoint(x: 12.0 * s, y: 10.0 * s))
            pBlue.addLine(to: CGPoint(x: 12.0 * s, y: 14.26 * s))
            pBlue.addLine(to: CGPoint(x: 17.92 * s, y: 14.26 * s))
            pBlue.addCurve(to: CGPoint(x: 15.71 * s, y: 17.57 * s), control1: CGPoint(x: 17.66 * s, y: 15.63 * s), control2: CGPoint(x: 16.88 * s, y: 16.79 * s))
            pBlue.addLine(to: CGPoint(x: 19.28 * s, y: 20.34 * s))
            pBlue.addCurve(to: CGPoint(x: 22.56 * s, y: 12.25 * s), control1: CGPoint(x: 21.36 * s, y: 18.42 * s), control2: CGPoint(x: 22.56 * s, y: 15.6 * s))
            pBlue.closeSubpath()
            context.fill(pBlue, with: .color(Color(red: 66/255, green: 133/255, blue: 244/255)))

            // 2. Green
            var pGreen = Path()
            pGreen.move(to: CGPoint(x: 12.0 * s, y: 23.0 * s))
            pGreen.addCurve(to: CGPoint(x: 19.28 * s, y: 20.34 * s), control1: CGPoint(x: 14.97 * s, y: 23.0 * s), control2: CGPoint(x: 17.46 * s, y: 22.02 * s))
            pGreen.addLine(to: CGPoint(x: 15.71 * s, y: 17.57 * s))
            pGreen.addCurve(to: CGPoint(x: 12.0 * s, y: 18.63 * s), control1: CGPoint(x: 14.73 * s, y: 18.23 * s), control2: CGPoint(x: 13.48 * s, y: 18.63 * s))
            pGreen.addCurve(to: CGPoint(x: 5.84 * s, y: 14.1 * s), control1: CGPoint(x: 9.14 * s, y: 18.63 * s), control2: CGPoint(x: 6.71 * s, y: 16.7 * s))
            pGreen.addLine(to: CGPoint(x: 2.18 * s, y: 16.94 * s))
            pGreen.addCurve(to: CGPoint(x: 12.0 * s, y: 23.0 * s), control1: CGPoint(x: 3.99 * s, y: 20.53 * s), control2: CGPoint(x: 7.7 * s, y: 23.0 * s))
            pGreen.closeSubpath()
            context.fill(pGreen, with: .color(Color(red: 52/255, green: 168/255, blue: 83/255)))

            // 3. Yellow
            var pYellow = Path()
            pYellow.move(to: CGPoint(x: 5.84 * s, y: 14.09 * s))
            pYellow.addCurve(to: CGPoint(x: 5.49 * s, y: 12.0 * s), control1: CGPoint(x: 5.62 * s, y: 13.43 * s), control2: CGPoint(x: 5.49 * s, y: 12.73 * s))
            pYellow.addCurve(to: CGPoint(x: 5.84 * s, y: 9.91 * s), control1: CGPoint(x: 5.49 * s, y: 11.27 * s), control2: CGPoint(x: 5.62 * s, y: 10.57 * s))
            pYellow.addLine(to: CGPoint(x: 2.18 * s, y: 7.07 * s))
            pYellow.addCurve(to: CGPoint(x: 1.0 * s, y: 12.0 * s), control1: CGPoint(x: 1.43 * s, y: 8.55 * s), control2: CGPoint(x: 1.0 * s, y: 10.22 * s))
            pYellow.addCurve(to: CGPoint(x: 2.18 * s, y: 16.93 * s), control1: CGPoint(x: 1.0 * s, y: 13.78 * s), control2: CGPoint(x: 1.43 * s, y: 15.45 * s))
            pYellow.addLine(to: CGPoint(x: 5.84 * s, y: 14.09 * s))
            pYellow.closeSubpath()
            context.fill(pYellow, with: .color(Color(red: 251/255, green: 188/255, blue: 5/255)))

            // 4. Red
            var pRed = Path()
            pRed.move(to: CGPoint(x: 12.0 * s, y: 5.38 * s))
            pRed.addCurve(to: CGPoint(x: 16.21 * s, y: 7.02 * s), control1: CGPoint(x: 13.62 * s, y: 5.38 * s), control2: CGPoint(x: 15.06 * s, y: 5.94 * s))
            pRed.addLine(to: CGPoint(x: 19.36 * s, y: 3.87 * s))
            pRed.addCurve(to: CGPoint(x: 12.0 * s, y: 1.0 * s), control1: CGPoint(x: 17.45 * s, y: 2.09 * s), control2: CGPoint(x: 14.97 * s, y: 1.0 * s))
            pRed.addCurve(to: CGPoint(x: 2.18 * s, y: 7.07 * s), control1: CGPoint(x: 7.7 * s, y: 1.0 * s), control2: CGPoint(x: 3.99 * s, y: 3.47 * s))
            pRed.addLine(to: CGPoint(x: 5.84 * s, y: 9.91 * s))
            pRed.addCurve(to: CGPoint(x: 12.0 * s, y: 5.38 * s), control1: CGPoint(x: 6.71 * s, y: 7.3 * s), control2: CGPoint(x: 9.14 * s, y: 5.38 * s))
            pRed.closeSubpath()
            context.fill(pRed, with: .color(Color(red: 234/255, green: 67/255, blue: 53/255)))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Login & registration
/// Brand screen in the §1A look: velvet, a glass card, gold capsules for Prihlásenie / Registrácia and
/// Tanečník / Tréner. All logic lives in `AuthManager`; this view only collects input.
struct AuthSheetView: View {
    var isSheet: Bool = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var authManager = AuthManager.shared

    enum AuthTab: Hashable {
        case signIn, signUp
    }

    @State private var selectedTab: AuthTab = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var nickname = ""
    @State private var legalTab: LegalComplianceView.LegalTab?
    @State private var showForgotPassword = false
    @State private var showCodeSheet = false
    @State private var birthYear: Int?
    @State private var parentConsent = false
    @State private var danceRole = "dancer"
    @State private var showBiometricButton = false
    @State private var tapFeedback = 0
    @State private var shakes = 0
    @FocusState private var focus: AuthField?

    private var isSignUp: Bool { selectedTab == .signUp }

    var body: some View {
        ZStack {
            EllegancePageBackground()
                .contentShape(Rectangle())
                .onTapGesture { focus = nil }

            GeometryReader { geometry in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        Spacer(minLength: 12)
                        header
                        PlannerChoice(
                            options: [(AuthTab.signIn, "Prihlásenie"), (AuthTab.signUp, "Registrácia")],
                            selection: $selectedTab
                        )
                        .accessibilityIdentifier("auth.mode")
                        formCard
                        alternativeSignIn
                        legalLinks
                        Spacer(minLength: 12)
                    }
                    .padding(.horizontal, 20)
                    .frame(minHeight: geometry.size.height)
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedTab)
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: authManager.authErrorMessage)
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: authManager.pendingConfirmationEmail)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.interactively)
            }

            if isSheet {
                VStack {
                    HStack {
                        LiquidGlassCircleButton(icon: "xmark", label: "Zavrieť", size: 40) { dismiss() }
                        Spacer()
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
            }
        }
        .environment(\.locale, Locale(identifier: "sk"))
        .preferredColorScheme(.dark)
        .sheet(item: $legalTab) { LegalComplianceView(initialTab: $0) }
        .sheet(isPresented: $showForgotPassword) { ForgotPasswordSheet(prefillEmail: email) }
        .sheet(isPresented: $showCodeSheet) { EmailCodeSheet() }
        .onAppear {
            if email.isEmpty, let saved = authManager.savedEmail {
                email = saved
            }
            // Read once, not on every redraw (it touches the Keychain).
            showBiometricButton = authManager.canUseBiometricLogin
        }
        .onChange(of: selectedTab) { _, _ in clearMessages() }
        .onChange(of: authManager.authErrorMessage) { _, message in
            guard let message else { return }
            shakes += 1
            // VoiceOver users hear the error without hunting for it.
            AccessibilityNotification.Announcement(message).post()
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: tapFeedback)
        .sensoryFeedback(.error, trigger: shakes)
    }

    // MARK: Header
    private var header: some View {
        VStack(spacing: 10) {
            Image("EncoreLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .shadow(color: Color.gold500.opacity(0.35), radius: 18)
                .accessibilityHidden(true)
            EncoreWordmark(size: 15, color: .gold400)
            Text(isSignUp ? "Vytvor si účet" : "Vitaj späť")
                .font(.system(.title, design: .rounded).weight(.heavy))
                .foregroundColor(.white)
                .contentTransition(.opacity)
                .accessibilityAddTraits(.isHeader)
            Text(isSignUp ? "Zostavy, tréningy a súťaže na jednom mieste." : "Prihlás sa a pokračuj tam, kde si skončil.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
        }
    }

    // MARK: Form card
    private var formCard: some View {
        VStack(spacing: 14) {
            if isSignUp {
                if AppFeatures.coachTools {
                    PlannerChoice(options: [("dancer", "Tanečník"), ("coach", "Tréner")], selection: $danceRole)
                        .accessibilityLabel("Kto som")
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                TextField("", text: $nickname, prompt: fieldPrompt("Meno alebo prezývka"))
                    .textContentType(.name)
                    .autocorrectionDisabled()
                    .focused($focus, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focus = .email }
                    .onChange(of: nickname) { _, value in
                        if value.count > NameRules.maxLength {
                            nickname = String(value.prefix(NameRules.maxLength))
                        }
                    }
                    .authFieldChrome(isFocused: focus == .name)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            TextField("", text: $email, prompt: fieldPrompt("E-mail"))
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focus, equals: .email)
                .submitLabel(.next)
                .onSubmit { focus = .password }
                .authFieldChrome(isFocused: focus == .email)

            PasswordField(
                prompt: isSignUp ? "Heslo (aspoň \(PasswordPolicy.minLength) znakov)" : "Heslo",
                text: $password,
                contentType: isSignUp ? .newPassword : .password,
                submitLabel: isSignUp ? .done : .go,
                focus: $focus,
                field: .password,
                onSubmit: { handleAuthSubmit() }
            )

            if isSignUp {
                signUpExtras
            }

            messages

            PrimarySheetButton(
                title: isSignUp ? "Vytvoriť účet" : "Prihlásiť sa",
                isLoading: authManager.isLoading,
                isEnabled: canSubmit,
                action: handleAuthSubmit
            )
            .accessibilityIdentifier("auth.submit")
            .padding(.top, 4)

            if let submitHint {
                Text(submitHint)
                    .font(.footnote)
                    .foregroundColor(Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .transition(.opacity)
            }

            accountLinks
        }
        .padding(18)
        .homeCard(cornerRadius: 24)
        .shake(shakes, reduceMotion: reduceMotion)
    }

    @ViewBuilder
    private var signUpExtras: some View {
        PasswordStrengthBar(password: password)

        if !password.isEmpty, let issue = PasswordPolicy.issue(for: password, email: email) {
            Text(issue)
                .font(.footnote.weight(.medium))
                .foregroundColor(.latinRed)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity)
        }

        BirthYearField(year: $birthYear, parentConsent: $parentConsent)
            .accessibilityIdentifier("auth.age")
            .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func fieldPrompt(_ text: String) -> Text {
        Text(text).foregroundColor(Color.textSecondary)
    }

    // MARK: Messages
    @ViewBuilder
    private var messages: some View {
        if let errorMessage = authManager.authErrorMessage {
            VStack(alignment: .leading, spacing: 8) {
                SheetBanner(text: errorMessage, isError: true)
                if authManager.showSettingsLink {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Otvoriť Nastavenia iPhonu", systemImage: "gearshape.fill")
                            .font(.footnote.weight(.bold))
                            .foregroundColor(.gold400)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.gold500.opacity(0.12), in: Capsule())
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.pressable)
                }
            }
        }

        if let successMessage = authManager.authSuccessMessage {
            SheetBanner(text: successMessage, isError: false)
        }

        // The sign-up waits for the e-mail code (the code sheet was closed): one tap back to it.
        if let pending = authManager.pendingConfirmationEmail, !showCodeSheet {
            Button {
                showCodeSheet = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "envelope.badge.fill")
                        .foregroundColor(.gold400)
                        .symbolEffect(.pulse)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mám kód z e-mailu")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.white)
                        Text("Potvrdenie pre \(pending)")
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.65))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.bold))
                        .foregroundColor(Color.textSecondary)
                }
                .padding(12)
                .background(Color.gold500.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.gold400.opacity(0.4), lineWidth: 1)
                )
            }
            .buttonStyle(.pressable(scale: 0.98))
            .accessibilityIdentifier("auth.enterCode")
            .transition(.scale(scale: 0.95).combined(with: .opacity))
        }
    }

    // MARK: Links under the main button
    @ViewBuilder
    private var accountLinks: some View {
        if !isSignUp {
            Button("Zabudnuté heslo?") {
                clearMessages()
                showForgotPassword = true
            }
            .font(.footnote.weight(.semibold))
            .foregroundColor(.gold400)
            .frame(minHeight: 44)
            .buttonStyle(.pressable)
            .accessibilityIdentifier("auth.forgotPassword")
        }
    }

    // MARK: Google, Apple, Face ID
    private var alternativeSignIn: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Rectangle().fill(Color.white.opacity(0.15)).frame(height: 1)
                Text("alebo")
                    .font(.footnote)
                    .foregroundColor(Color.textSecondary)
                Rectangle().fill(Color.white.opacity(0.15)).frame(height: 1)
            }
            .accessibilityHidden(true)

            Button(action: handleGoogleAuth) {
                HStack(spacing: 10) {
                    GoogleLogoView(size: 18)
                    Text("Pokračovať cez Google")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 50)
                .homeCard(cornerRadius: 16)
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("auth.google")

            if AuthFeatureFlags.appleSignInEnabled {
                SignInWithAppleButton(.continue, onRequest: { request in
                    let hashedNonce = authManager.startAppleSignInNonce()
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = hashedNonce
                }, onCompletion: handleAppleAuthCompletion)
                .signInWithAppleButtonStyle(.white)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            if !isSignUp && showBiometricButton {
                Button(action: handleFaceIDAuth) {
                    Label("Prihlásiť sa cez \(authManager.biometryName)", systemImage: authManager.biometrySystemImage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .homeCard(cornerRadius: 16)
                }
                .buttonStyle(.pressable)
                .transition(.opacity)
            }
        }
    }

    /// Two real links in one sentence; each opens its own section of the legal screen.
    private var legalLinks: some View {
        Text("Pokračovaním súhlasíš s [Podmienkami používania](encore-legal://terms) a [Zásadami ochrany súkromia](encore-legal://privacy).")
            .font(.caption)
            .foregroundColor(Color.textSecondary)
            .tint(.gold400)
            .multilineTextAlignment(.center)
            .environment(\.openURL, OpenURLAction { url in
                legalTab = url.host == "terms" ? .terms : .privacy
                return .handled
            })
    }

    // MARK: Actions
    private var cleanEmail: String { email.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var canSubmit: Bool {
        if isSignUp {
            return EmailValidator.isValid(cleanEmail)
                && PasswordPolicy.issue(for: password, email: cleanEmail) == nil
                && !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && BirthYear.isComplete(birthYear, parentConsent: parentConsent)
        }
        return !cleanEmail.isEmpty && !password.isEmpty
    }

    /// Why the dimmed main button cannot be tapped yet (§1A). Hidden until the user starts typing.
    private var submitHint: String? {
        guard !canSubmit, !authManager.isLoading else { return nil }
        let started = !cleanEmail.isEmpty || !password.isEmpty || (isSignUp && !nickname.isEmpty)
        guard started else { return nil }
        if !isSignUp { return "Zadaj e-mail aj heslo." }
        if nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Doplň meno alebo prezývku." }
        if !EmailValidator.isValid(cleanEmail) { return "Zadaj platný e-mail, napr. meno@domena.sk." }
        if PasswordPolicy.issue(for: password, email: cleanEmail) != nil { return "Heslo ešte nespĺňa pravidlá vyššie." }
        if birthYear == nil { return "Vyber rok narodenia." }
        if !BirthYear.isComplete(birthYear, parentConsent: parentConsent) { return "Pod 16 rokov potvrď súhlas rodiča." }
        return nil
    }

    private func clearMessages() {
        authManager.authErrorMessage = nil
        authManager.authSuccessMessage = nil
    }

    private func handleAuthSubmit() {
        guard canSubmit, !authManager.isLoading else { return }
        focus = nil
        tapFeedback += 1
        Task {
            let success: Bool
            if isSignUp {
                // canSubmit already asked for the year.
                guard let birthYear else { return }
                success = await authManager.signUp(email: email, pass: password, name: nickname, danceRole: danceRole,
                                                   birthYear: birthYear, parentConsent: parentConsent)
            } else {
                success = await authManager.signIn(email: email, pass: password)
            }
            if success {
                if isSheet { dismiss() }
            } else if authManager.pendingConfirmationEmail != nil {
                showCodeSheet = true
            }
        }
    }

    private func handleGoogleAuth() {
        tapFeedback += 1
        focus = nil
        guard let presenter = UIViewController.topMost() else {
            Task {
                let success = await authManager.signInWithGoogle()
                if success && isSheet { dismiss() }
            }
            return
        }

        Task {
            let success = await authManager.signInWithGoogleNative(presenting: presenter)
            if success && isSheet { dismiss() }
        }
    }

    private func handleAppleAuthCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idTokenString = String(data: tokenData, encoding: .utf8) else {
                authManager.authErrorMessage = "Nepodarilo sa získať Apple prihlasovací token."
                return
            }

            let fullName: String? = {
                if let name = credential.fullName {
                    let parts = [name.givenName, name.familyName].compactMap { $0 }.filter { !$0.isEmpty }
                    return parts.isEmpty ? nil : parts.joined(separator: " ")
                }
                return nil
            }()
            let appleEmail = credential.email

            tapFeedback += 1
            Task {
                let success = await authManager.signInWithApple(
                    idToken: idTokenString,
                    fullName: fullName,
                    email: appleEmail
                )
                if success && isSheet { dismiss() }
            }
        case .failure(let error):
            // User cancelling the sheet isn't a real error — don't show a scary message for it.
            let nsError = error as NSError
            if nsError.code != ASAuthorizationError.canceled.rawValue {
                authManager.authErrorMessage = AuthErrorMapper.message(for: error, fallback: "Prihlásenie cez Apple zlyhalo")
            }
        }
    }

    private func handleFaceIDAuth() {
        tapFeedback += 1
        Task {
            let success = await authManager.authenticateWithBiometrics()
            if success && isSheet { dismiss() }
        }
    }
}

#Preview("Prihlásenie") {
    AuthSheetView(isSheet: true)
}
