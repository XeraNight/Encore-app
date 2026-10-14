import Foundation

// MARK: - The one contact address
/// Used by feedback, reports, ban appeals and the privacy policy, and it must match the App Store
/// listing (support, privacy contact, EU trader details). Change it only here.
enum AppContact {
    static let supportEmail = "support@encore-sk.com"

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

// MARK: - The website
/// encore-sk.com redirects to www, so the app links straight to www. Older QR codes and links
/// (the Vercel addresses, encore-sk.com) are still recognised as our own.
enum AppWebsite {
    static let host = "www.encore-sk.com"
    private static let ownHosts: Set<String> = [host, "encore-sk.com", "encore-dance-app.vercel.app", "encore-app.vercel.app"]

    static func url(_ path: String) -> URL? {
        URL(string: "https://\(host)\(path)")
    }

    static func isOwn(_ url: URL) -> Bool {
        guard let urlHost = url.host?.lowercased() else { return false }
        return ownHosts.contains(urlHost)
    }
}
