import Foundation
import Security
import OSLog

// MARK: - Saved Auth Session Model
struct SavedAuthSession: Sendable {
    let email: String
    let provider: String // "email", "google", "apple"
}

// MARK: - Thread-safe iOS Keychain Helper for Biometric / Saved Auth
final class KeychainHelper: @unchecked Sendable {
    static let shared = KeychainHelper()
    private let serviceName = "com.encore.app.auth"
    private let lock = NSLock()
    
    private init() {}
    
    // MARK: - Save Session
    /// Stores only the e-mail (pre-fill) and the provider. Never a password or token.
    func saveSession(email: String, provider: String = "email") {
        lock.lock()
        defer { lock.unlock() }

        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanEmail.isEmpty else { return }

        if let emailData = cleanEmail.data(using: .utf8) {
            saveItem(key: "userEmail", data: emailData)
        }
        if let providerData = provider.data(using: .utf8) {
            saveItem(key: "authProvider", data: providerData)
        }
    }

    // MARK: - Read Session
    func readSession() -> SavedAuthSession? {
        lock.lock()
        defer { lock.unlock() }

        guard let emailData = readItem(key: "userEmail"),
              let email = String(data: emailData, encoding: .utf8),
              !email.isEmpty else {
            return nil
        }

        let provider = readItem(key: "authProvider")
            .flatMap { String(data: $0, encoding: .utf8) }
            .flatMap { $0.isEmpty ? nil : $0 } ?? "email"

        return SavedAuthSession(email: email, provider: provider)
    }

    // MARK: - Delete Credentials
    func deleteCredentials() {
        lock.lock()
        defer { lock.unlock() }
        deleteItem(key: "userEmail")
        deleteItem(key: "authProvider")
        deleteLegacySecrets()
    }

    /// Removes the password and refresh-token copies that older builds stored here.
    func purgeLegacySecrets() {
        lock.lock()
        defer { lock.unlock() }
        deleteLegacySecrets()
    }

    private func deleteLegacySecrets() {
        deleteItem(key: "userPass")
        deleteItem(key: "refreshToken")
    }

    // MARK: - Low-level Keychain API wrapper
    private func saveItem(key: String, data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        // Update in place when the item exists (atomic), add it otherwise
        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess { return }
        
        var newQuery = query
        newQuery[kSecValueData as String] = data
        newQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        
        let status = SecItemAdd(newQuery as CFDictionary, nil)
        if status != errSecSuccess {
            Logger.auth.warning("[KeychainHelper] SecItemAdd warning for key \(key, privacy: .public): status \(status)")
        }
    }
    
    private func readItem(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess {
            return dataTypeRef as? Data
        }
        return nil
    }
    
    private func deleteItem(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
