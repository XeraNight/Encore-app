import SwiftUI

/// A voice note inside the text of a figure's notes. The recording stays on this phone (Documents);
/// in the text it is one character (U+FFFC) carrying this reference.
nonisolated struct VoiceNoteRef: Codable, Hashable, Sendable {
    let fileName: String
    let duration: TimeInterval

    /// How the voice note reads in the synced plain text, for the partner, the coach and the QR code.
    var marker: String {
        let total = Int(duration.rounded(.down))
        return "[hlasovka \(total / 60):\(String(format: "%02d", total % 60))]"
    }
}

nonisolated enum VoiceNoteAttribute: CodableAttributedStringKey {
    typealias Value = VoiceNoteRef
    static let name = "encoreVoiceNote"
}

extension AttributeScopes {
    /// The SwiftUI formatting of notes plus Encore's voice notes.
    nonisolated struct EncoreNoteAttributes: AttributeScope {
        let voiceNote: VoiceNoteAttribute
        let swiftUI: SwiftUIAttributes
    }
}

extension AttributeDynamicLookup {
    subscript<T: AttributedStringKey>(dynamicMember keyPath: KeyPath<AttributeScopes.EncoreNoteAttributes, T>) -> T {
        self[T.self]
    }
}

/// Saving and loading formatted figure notes.
///
/// The formatted text is stored as JSON in `CanvasNode.notesRichData`. The plain text in
/// `CanvasNode.notes` remains the source of truth for everything else (cloud sync, QR, the
/// coach). If the two ever disagree (someone changed the plain text from another place), the
/// plain text wins and the formatting is dropped, so the screen can never show stale text.
/// Voice notes are kept even then: their markers in the new text get their recordings back.
enum RichNote {
    /// The object replacement character a voice note occupies in the text.
    static let voiceCharacter = "\u{FFFC}"

    static func plain(_ text: AttributedString) -> String {
        text.runs.reduce(into: "") { result, run in
            if let voice = run.voiceNote {
                result += voice.marker
            } else {
                result += String(text[run.range].characters)
            }
        }
    }

    static func encode(_ text: AttributedString) -> Data? {
        try? JSONEncoder().encode(text, configuration: AttributeScopes.EncoreNoteAttributes.self)
    }

    static func decode(_ data: Data) -> AttributedString? {
        try? JSONDecoder().decode(AttributedString.self, from: data, configuration: AttributeScopes.EncoreNoteAttributes.self)
    }

    /// The voice notes in a text, in order.
    static func voiceNotes(in text: AttributedString) -> [VoiceNoteRef] {
        text.runs.compactMap(\.voiceNote)
    }

    /// The text to show for a node: formatted when the stored formatting still matches the plain text.
    static func attributed(for node: CanvasNode) -> AttributedString {
        guard let data = node.notesRichData, let rich = decode(data) else { return AttributedString(node.notes) }
        if plain(rich) == node.notes { return readableOnDark(rich) }
        return restoringVoiceNotes(voiceNotes(in: rich), in: node.notes)
    }

    /// Plain text changed elsewhere: each voice marker that is still there gets its recording back.
    private static func restoringVoiceNotes(_ voices: [VoiceNoteRef], in plain: String) -> AttributedString {
        var result = AttributedString()
        var rest = Substring(plain)
        for ref in voices {
            guard let range = rest.range(of: ref.marker) else { continue }
            result.append(AttributedString(String(rest[..<range.lowerBound])))
            var voice = AttributedString(voiceCharacter)
            voice.voiceNote = ref
            result.append(voice)
            rest = rest[range.upperBound...]
        }
        result.append(AttributedString(String(rest)))
        return result
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
