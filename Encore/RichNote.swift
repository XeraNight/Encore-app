import SwiftUI

/// Saving and loading formatted figure notes.
///
/// The formatted text is stored as JSON in `CanvasNode.notesRichData`. The plain text in
/// `CanvasNode.notes` remains the source of truth for everything else (cloud sync, QR, the
/// coach). If the two ever disagree (someone changed the plain text from another place), the
/// plain text wins and the formatting is dropped, so the screen can never show stale text.
enum RichNote {
    static func plain(_ text: AttributedString) -> String {
        String(text.characters)
    }

    static func encode(_ text: AttributedString) -> Data? {
        try? JSONEncoder().encode(text, configuration: AttributeScopes.SwiftUIAttributes.self)
    }

    static func decode(_ data: Data) -> AttributedString? {
        try? JSONDecoder().decode(AttributedString.self, from: data, configuration: AttributeScopes.SwiftUIAttributes.self)
    }

    /// The text to show for a node: formatted when the stored formatting still matches the plain text.
    static func attributed(for node: CanvasNode) -> AttributedString {
        if let data = node.notesRichData, let rich = decode(data), plain(rich) == node.notes {
            return readableOnDark(rich)
        }
        return AttributedString(node.notes)
    }

    /// Notes used to sit on a white sheet; black ink chosen there would vanish on the dark card,
    /// so very dark text colours fall back to the default light ink.
    static func readableOnDark(_ text: AttributedString) -> AttributedString {
        var result = text
        let environment = EnvironmentValues()
        for run in text.runs {
            guard let color = run.foregroundColor else { continue }
            let resolved = color.resolve(in: environment)
            let luminance = 0.2126 * resolved.red + 0.7152 * resolved.green + 0.0722 * resolved.blue
            if luminance < 0.2 { result[run.range].foregroundColor = nil }
        }
        return result
    }
}

/// Default look of note text: light ink on the dark glass notes card.
enum NoteStyle {
    static let ink = Color.white.opacity(0.95)
    static let sizes: [CGFloat] = [14, 16, 18, 22, 28, 34]
    static let defaultSize: CGFloat = 18
}
