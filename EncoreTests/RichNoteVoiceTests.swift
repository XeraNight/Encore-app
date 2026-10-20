import Testing
import Foundation
import SwiftUI
import SwiftData
@testable import Encore

/// Voice notes inside a figure's notes: the partner reads a marker in the synced text, the recording comes
/// back when the notes are opened again, and survives the partner editing the text around it.
@MainActor
struct RichNoteVoiceTests {
    private func makeNode(notes: String) throws -> (ModelContainer, CanvasNode) {
        let schema = Schema([Routine.self, CanvasNode.self, VideoMediaEntry.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let node = CanvasNode(x: 0, y: 0, figureName: "Telemark", rhythm: "SQQ", notes: notes, orderIndex: 0)
        container.mainContext.insert(node)
        return (container, node)
    }

    private func note(before: String, voice: VoiceNoteRef, after: String) -> AttributedString {
        var text = AttributedString(before)
        var piece = AttributedString(RichNote.voiceCharacter)
        piece.voiceNote = voice
        text.append(piece)
        text.append(AttributedString(after))
        return text
    }

    @Test func plainTextShowsAMarkerForThePartner() {
        let text = note(before: "Hlava vľavo ", voice: VoiceNoteRef(fileName: "voice_a.m4a", duration: 14.6), after: " celý čas.")
        #expect(RichNote.plain(text) == "Hlava vľavo [hlasovka 0:14] celý čas.")
    }

    @Test func voiceNoteComesBackWhenTheNotesOpenAgain() throws {
        let voice = VoiceNoteRef(fileName: "voice_b.m4a", duration: 75)
        let text = note(before: "Rám ", voice: voice, after: " drž.")
        let (container, node) = try makeNode(notes: RichNote.plain(text))
        _ = container
        node.notesRichData = RichNote.encode(text)

        let reopened = RichNote.attributed(for: node)
        #expect(RichNote.voiceNotes(in: reopened) == [voice])
        #expect(RichNote.plain(reopened) == "Rám [hlasovka 1:15] drž.")
    }

    @Test func partnerEditKeepsTheRecordingWhereItsMarkerStays() throws {
        let voice = VoiceNoteRef(fileName: "voice_c.m4a", duration: 8)
        let text = note(before: "Telemark ", voice: voice, after: " hlava.")
        let (container, node) = try makeNode(notes: RichNote.plain(text))
        _ = container
        node.notesRichData = RichNote.encode(text)

        // The partner adds a line; the marker is still there.
        node.notes = "Telemark [hlasovka 0:08] hlava.\nZdvih až na 3."
        let reopened = RichNote.attributed(for: node)
        #expect(RichNote.voiceNotes(in: reopened) == [voice])
        #expect(RichNote.plain(reopened) == node.notes)
    }

    @Test func editorKeepsFormattingAndVoiceNotesUnchanged() {
        var text = AttributedString("Hlava ")
        text.font = .system(size: 22, weight: .bold, design: .serif)
        text.foregroundColor = Color.gold400
        var marked = AttributedString("vľavo")
        marked.backgroundColor = Color.yellow.opacity(0.35)
        marked.underlineStyle = .single
        text.append(marked)
        var voice = AttributedString(RichNote.voiceCharacter)
        voice.voiceNote = VoiceNoteRef(fileName: "voice_d.m4a", duration: 5)
        text.append(voice)
        text.append(AttributedString(" celý čas."))

        // Shown in the editor and read back without a single keystroke: nothing may change.
        let shown = NoteTextBridge.attributed(text, controller: NoteEditorController())
        #expect(NoteTextBridge.model(from: shown) == text)
    }

    @Test func voiceNoteIsALiveViewRightAfterItsWords() throws {
        var text = AttributedString("Hlava vľavo ")
        var voice = AttributedString(RichNote.voiceCharacter)
        voice.voiceNote = VoiceNoteRef(fileName: "voice_e.m4a", duration: 9)
        text.append(voice)
        text.append(AttributedString(" celý čas."))

        let view = NotesTextView.make()
        view.frame = CGRect(x: 0, y: 0, width: 360, height: 300)
        view.attributedText = NoteTextBridge.attributed(text, controller: NoteEditorController())
        view.layoutIfNeeded()

        // TextKit 1 throughout (TextKit 2 fell back with attachments and drew a blank file icon).
        #expect(view.textLayoutManager == nil)
        let token = try #require(view.subviews.first { $0.accessibilityIdentifier == NotesTextView.voiceTokenIdentifier })
        #expect(token.frame.size == InlineVoiceToken.size)
        #expect(token.frame.minX > 60)   // after "Hlava vľavo ", on the first line
        #expect(token.frame.minY < 30)
    }

    @Test func notesWrittenBeforeVoiceNotesStillOpen() throws {
        // Data saved by the old editor (SwiftUI attributes only) decodes with the new scope.
        var old = AttributedString("Rám drž hore")
        old.font = .system(size: 22, weight: .bold)
        let data = try JSONEncoder().encode(old, configuration: AttributeScopes.SwiftUIAttributes.self)
        let decoded = try #require(RichNote.decode(data))
        #expect(RichNote.plain(decoded) == "Rám drž hore")
        #expect(decoded.runs.first?.font == .system(size: 22, weight: .bold))
    }
}
