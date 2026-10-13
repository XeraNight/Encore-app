import Foundation
import Supabase
import UIKit

// MARK: - Feature flags
enum AuthFeatureFlags {
    /// Sign in with Apple needs the paid Developer account (capability + provisioning profile).
    /// The button stays hidden until this is true. Also see supabase/functions/delete-account.
    static let appleSignInEnabled = false
}

// MARK: - Password rules
/// Mirrors the server rule (Dashboard: minimum 8 characters) so users get an instant, clear message.
/// Length matters more than special characters, so there is no "must contain a symbol" rule.
enum PasswordPolicy {
    static let minLength = 8
    static let maxLength = 128

    private static let commonPasswords: Set<String> = [
        "12345678", "123456789", "1234567890", "11111111", "00000000", "password", "password1",
        "password123", "qwertyui", "qwerty123", "iloveyou", "abcd1234", "abc12345", "letmein1",
        "encore123", "dance1234", "admin123", "welcome1"
    ]

    /// Returns a Slovak message describing the problem, or nil when the password is acceptable.
    static func issue(for password: String, email: String = "") -> String? {
        if password.count < minLength { return "Heslo musí mať aspoň \(minLength) znakov." }
        if password.count > maxLength { return "Heslo môže mať najviac \(maxLength) znakov." }
        if Set(password).count == 1 { return "Heslo nemôže byť len opakovaný znak." }
        if commonPasswords.contains(password.lowercased()) { return "Toto heslo je príliš časté. Zvoľ iné." }
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !cleanEmail.isEmpty, password.lowercased() == cleanEmail {
            return "Heslo nesmie byť rovnaké ako e-mail."
        }
        return nil
    }

    /// 0 (empty) … 4 (strong), for a small strength bar. Guidance only, not a gate.
    static func strength(of password: String) -> Int {
        guard !password.isEmpty else { return 0 }
        var score = 0
        if password.count >= minLength { score += 1 }
        if password.count >= 12 { score += 1 }
        let hasLetters = password.rangeOfCharacter(from: .letters) != nil
        let hasDigits = password.rangeOfCharacter(from: .decimalDigits) != nil
        let hasMixedCase = password.rangeOfCharacter(from: .lowercaseLetters) != nil
            && password.rangeOfCharacter(from: .uppercaseLetters) != nil
        let hasSymbols = password.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) != nil
        if hasLetters && hasDigits { score += 1 }
        if hasMixedCase || hasSymbols { score += 1 }
        if issue(for: password) != nil { return min(score, 1) }
        return min(score, 4)
    }
}

// MARK: - E-mail codes
/// Supabase sends 6–10 digit codes; the length is a project setting (Authentication → Email → OTP length,
/// 8 on this project). The app accepts any length the server may use, so changing it never breaks sign-in.
enum EmailCodePolicy {
    static let allowedLengths = 6...10

    static func isComplete(_ code: String) -> Bool { allowedLengths.contains(code.count) }
}

// MARK: - E-mail and name checks
enum EmailValidator {
    private static let pattern = #"^[^\s@]+@[^\s@]+\.[^\s@]{2,}$"#

    static func isValid(_ email: String) -> Bool {
        let clean = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count <= 254 else { return false }
        return clean.range(of: pattern, options: .regularExpression) != nil
    }
}

enum NameRules {
    static let maxLength = 60
}

// MARK: - Presenting from the right view controller
extension UIViewController {
    /// The view controller currently on top, so Google Sign-In still appears when the login
    /// screen itself is presented as a sheet.
    @MainActor
    static func topMost() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var top = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }
}

// MARK: - Error translation
/// Turns SDK and network errors into Slovak messages. It looks at error codes and `URLError`
/// codes, never at the English text, so it works the same on a Slovak or English iPhone.
enum AuthErrorMapper {
    static func message(for error: Error, fallback: String) -> String {
        if let network = networkMessage(for: error) { return network }

        if let authError = error as? AuthError {
            switch authError {
            case .weakPassword:
                return "Heslo je príliš slabé alebo sa objavilo v uniknutých databázach. Zvoľ iné."
            case .sessionMissing:
                return "Prihlásenie vypršalo. Prihlás sa prosím znova."
            case .pkceGrantCodeExchange, .implicitGrantRedirect:
                return "Odkaz sa nepodarilo spracovať. Otvor ho na tom istom iPhone, z ktorého si ho vyžiadal, alebo použi kód z e-mailu."
            case .api(let apiMessage, let code, _, let response):
                if let mapped = message(forCode: code) { return mapped }
                // The server could not send the confirmation / recovery e-mail (SMTP problem).
                let lower = apiMessage.lowercased()
                if response.statusCode >= 500, lower.contains("email") || lower.contains("smtp") {
                    return "Nepodarilo sa odoslať e-mail s kódom. Skús to o chvíľu alebo napíš na podporu."
                }
                if response.statusCode == 429 {
                    return "Príliš veľa pokusov za krátky čas. Počkaj chvíľu a skús to znova."
                }
                if response.statusCode >= 500 {
                    return "Server má momentálne problém. Skús to o chvíľu."
                }
            default:
                if let mapped = message(forCode: authError.errorCode) { return mapped }
            }
        }

        return "\(fallback). Skús to prosím znova."
    }

    static func message(forCode code: ErrorCode) -> String? {
        switch code {
        case .invalidCredentials:
            return "E-mail alebo heslo nie je správne."
        case .emailNotConfirmed:
            return "E-mail ešte nie je potvrdený. Zadaj kód z e-mailu alebo si vyžiadaj nový."
        case .userAlreadyExists, .emailExists:
            return "Účet s týmto e-mailom už existuje. Prihlás sa alebo si obnov heslo."
        case .weakPassword:
            return "Heslo je príliš slabé alebo sa objavilo v uniknutých databázach. Zvoľ iné."
        case .samePassword:
            return "Nové heslo musí byť iné ako súčasné."
        case .otpExpired:
            return "Kód je nesprávny alebo už vypršal. Skontroluj ho alebo si vyžiadaj nový."
        case .overEmailSendRateLimit:
            return "E-mail sme ti už nedávno poslali. Počkaj chvíľu a skús to znova."
        case .overRequestRateLimit:
            return "Príliš veľa pokusov za krátky čas. Počkaj chvíľu a skús to znova."
        case .userBanned:
            return "Tento účet bol zablokovaný. Napíš na podporu."
        case .signupDisabled, .emailProviderDisabled:
            return "Registrácia e-mailom momentálne nie je dostupná."
        case .validationFailed:
            return "Skontroluj zadané údaje."
        case .flowStateExpired, .flowStateNotFound:
            return "Odkaz už nie je platný. Vyžiadaj si nový alebo použi kód z e-mailu."
        case .reauthenticationNeeded, .reauthenticationNotValid:
            return "Pre túto zmenu sa najprv znova prihlás."
        case .captchaFailed:
            return "Overenie, že nie si robot, zlyhalo. Skús to znova."
        case .userNotFound:
            return "Účet sa nenašiel."
        default:
            return nil
        }
    }

    private static func networkMessage(for error: Error) -> String? {
        let ns = error as NSError
        guard ns.domain == NSURLErrorDomain else { return nil }
        switch ns.code {
        case NSURLErrorNotConnectedToInternet, NSURLErrorDataNotAllowed, NSURLErrorInternationalRoamingOff:
            return "Nie si pripojený na internet. Skontroluj pripojenie a skús to znova."
        case NSURLErrorTimedOut:
            return "Server neodpovedá. Skús to o chvíľu."
        case NSURLErrorNetworkConnectionLost, NSURLErrorCannotConnectToHost, NSURLErrorCannotFindHost,
             NSURLErrorDNSLookupFailed:
            return "Nepodarilo sa spojiť so serverom. Skontroluj pripojenie."
        case NSURLErrorSecureConnectionFailed, NSURLErrorServerCertificateUntrusted,
             NSURLErrorServerCertificateHasBadDate, NSURLErrorServerCertificateNotYetValid,
             NSURLErrorServerCertificateHasUnknownRoot:
            return "Zabezpečené spojenie zlyhalo. Skontroluj dátum a čas v iPhone alebo skús inú sieť (Wi-Fi s prihlásením v hoteli či hale to často blokuje)."
        default:
            return "Problém so sieťou. Skús to o chvíľu."
        }
    }
}
