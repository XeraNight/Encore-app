import Combine
import Foundation

// MARK: - Lock Screen and Control Center buttons
/// What a control from the widget extension (`EncoreControls`) opens. A control opens
/// `https://www.encore-sk.com/quick/<action>`: Apple supports only universal links for opening an app from a
/// control. `encore://quick/<action>` works too. Without Encore installed the web sends the link to the download page.
enum QuickAction: String, CaseIterable {
    case video, voice, text, ksis

    init?(url: URL) {
        let parts = url.pathComponents.filter { $0 != "/" }
        let name: String?
        if url.scheme == "encore", url.host == "quick" {
            name = parts.first
        } else if AppWebsite.isOwn(url), parts.count == 2, parts[0] == "quick" {
            name = parts[1]
        } else {
            name = nil
        }
        guard let name, let action = QuickAction(rawValue: name) else { return nil }
        self = action
    }

    /// KSIS opens on the linked couple's page, otherwise on the KSIS home page.
    static func ksisStartURL(pairNumber: Int?) -> URL? {
        if let pairNumber, let url = URL(string: "https://\(KSISBrowserView.host)/detail_paru.php?cp=\(pairNumber)") {
            return url
        }
        return URL(string: "https://\(KSISBrowserView.host)/")
    }
}

/// Holds a tapped control until the screen that handles it is on (cold start, Face ID lock, signed out).
@MainActor
final class QuickActionRouter: ObservableObject {
    static let shared = QuickActionRouter()
    @Published var pending: QuickAction?
    private init() {}
}
