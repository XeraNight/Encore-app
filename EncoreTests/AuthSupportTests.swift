import Testing
import Foundation
import Supabase
@testable import Encore

struct PasswordPolicyTests {

    @Test func rejectsShortPasswords() {
        #expect(PasswordPolicy.issue(for: "abc1234") != nil)
        #expect(PasswordPolicy.issue(for: "") != nil)
    }

    @Test func acceptsEightCharactersWithoutSymbols() {
        #expect(PasswordPolicy.issue(for: "tancujeme8") == nil)
    }

    @Test func rejectsCommonAndRepeatedPasswords() {
        #expect(PasswordPolicy.issue(for: "Password123") != nil)
        #expect(PasswordPolicy.issue(for: "12345678") != nil)
        #expect(PasswordPolicy.issue(for: "aaaaaaaaaa") != nil)
    }

    @Test func rejectsPasswordEqualToEmail() {
        #expect(PasswordPolicy.issue(for: "meno@domena.sk", email: "Meno@Domena.sk") != nil)
    }

    @Test func rejectsVeryLongPasswords() {
        #expect(PasswordPolicy.issue(for: String(repeating: "ab", count: 70)) != nil)
    }

    @Test func passwordsAreNeverTrimmedBySpaces() {
        // Leading and trailing spaces are legitimate characters
        #expect(PasswordPolicy.issue(for: " moje heslo ") == nil)
    }

    @Test func strengthGrowsWithLengthAndVariety() {
        #expect(PasswordPolicy.strength(of: "") == 0)
        #expect(PasswordPolicy.strength(of: "short") <= 1)
        #expect(PasswordPolicy.strength(of: "Tancujeme8Dnes!") >= 3)
    }
}

struct EmailValidatorTests {

    @Test func acceptsNormalAddresses() {
        #expect(EmailValidator.isValid("meno@domena.sk"))
        #expect(EmailValidator.isValid("  meno.priezvisko+encore@sub.domena.com  "))
    }

    @Test func rejectsBrokenAddresses() {
        #expect(!EmailValidator.isValid(""))
        #expect(!EmailValidator.isValid("a@b"))
        #expect(!EmailValidator.isValid("meno domena.sk"))
        #expect(!EmailValidator.isValid("@domena.sk"))
        #expect(!EmailValidator.isValid("meno@domena."))
    }

    @Test func rejectsOverlongAddresses() {
        let long = String(repeating: "a", count: 250) + "@x.sk"
        #expect(!EmailValidator.isValid(long))
    }
}

struct AuthErrorMapperTests {

    @Test func mapsKnownServerCodesRegardlessOfLanguage() {
        #expect(AuthErrorMapper.message(forCode: .invalidCredentials) != nil)
        #expect(AuthErrorMapper.message(forCode: .emailNotConfirmed) != nil)
        #expect(AuthErrorMapper.message(forCode: .otpExpired) != nil)
        #expect(AuthErrorMapper.message(forCode: .userBanned) != nil)
        #expect(AuthErrorMapper.message(forCode: .weakPassword) != nil)
    }

    @Test func unknownCodeFallsThrough() {
        #expect(AuthErrorMapper.message(forCode: ErrorCode("something_new")) == nil)
    }

    @Test func networkErrorsAreRecognisedByCodeNotText() {
        let offline = URLError(.notConnectedToInternet)
        let timeout = URLError(.timedOut)
        let offlineText = AuthErrorMapper.message(for: offline, fallback: "X")
        let timeoutText = AuthErrorMapper.message(for: timeout, fallback: "X")
        #expect(offlineText.contains("internet"))
        #expect(timeoutText.contains("neodpovedá"))
        #expect(offlineText != timeoutText)
    }

    @Test func genericErrorNeverLeaksEnglishText() {
        struct Boom: LocalizedError { var errorDescription: String? { "Some raw English failure" } }
        let text = AuthErrorMapper.message(for: Boom(), fallback: "Prihlásenie zlyhalo")
        #expect(!text.contains("English"))
        #expect(text.hasPrefix("Prihlásenie zlyhalo"))
    }
}

struct EmailCodePolicyTests {

    /// The project sends 8-digit codes; a 6-digit-only check rejected every real code (13. 10. 2026).
    @Test func acceptsEveryLengthSupabaseCanSend() {
        #expect(EmailCodePolicy.isComplete("317779"))
        #expect(EmailCodePolicy.isComplete("31777923"))
        #expect(EmailCodePolicy.isComplete("3177792312"))
    }

    @Test func rejectsTooShortOrTooLong() {
        #expect(!EmailCodePolicy.isComplete("31777"))
        #expect(!EmailCodePolicy.isComplete("31777923123"))
        #expect(!EmailCodePolicy.isComplete(""))
    }
}
