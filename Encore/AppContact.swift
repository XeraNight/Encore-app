import Foundation

// MARK: - The one contact address
/// Used by feedback, reports, ban appeals and the privacy policy, and it must match the App Store
/// listing (support, privacy contact, EU trader details). Change it only here.
enum AppContact {
    static let supportEmail = "encore.support.sk@gmail.com"

    /// A `mailto:` link with a prefilled subject and optional body.
    static func mailURL(subject: String, body: String = "") -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        var items = [URLQueryItem(name: "subject", value: subject)]
        if !body.isEmpty { items.append(URLQueryItem(name: "body", value: body)) }
        components.queryItems = items
        return components.url
    }
}
