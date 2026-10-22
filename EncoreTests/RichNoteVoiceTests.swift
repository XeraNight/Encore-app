import Testing
import Foundation
import SwiftUI
import SwiftData
@testable import Encore

/// Voice notes and videos inside a figure's notes: the partner reads a marker in the synced text, the recording
/// or video comes back when the notes are opened again, and survives the partner editing the text around it.
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
        var piece = AttributedString(RichNote.attachmentCharacter)
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
        var voice = AttributedString(RichNote.attachmentCharacter)
        voice.voiceNote = VoiceNoteRef(fileName: "voice_d.m4a", duration: 5)
        text.append(voice)
        text.append(AttributedString(" celý čas."))

        // Shown in the editor and read back without a single keystroke: nothing may change.
        let shown = NoteTextBridge.attributed(text, controller: NoteEditorController())
        #expect(NoteTextBridge.model(from: shown) == text)
    }

    @Test func voiceNoteIsALiveViewRightAfterItsWords() throws {
        var text = AttributedString("Hlava vľavo ")
        var voice = AttributedString(RichNote.attachmentCharacter)
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

    @Test func voiceNoteTouchesNoTextAroundIt() throws {
        var text = AttributedString("Prvý riadok textu\nHlava vľavo ")
        var voice = AttributedString(RichNote.attachmentCharacter)
        voice.voiceNote = VoiceNoteRef(fileName: "voice_g.m4a", duration: 7)
        text.append(voice)
        text.append(AttributedString(" ďalej\nTretí riadok"))

        let view = NotesTextView.make()
        view.frame = CGRect(x: 0, y: 0, width: 360, height: 400)
        view.attributedText = NoteTextBridge.attributed(text, controller: NoteEditorController())
        view.layoutIfNeeded()
        let token = try #require(view.subviews.first { $0.accessibilityIdentifier == NotesTextView.voiceTokenIdentifier })

        let layout = view.layoutManager
        let font = UIFont.systemFont(ofSize: NoteStyle.defaultSize)
        let string = view.textStorage.string as NSString
        func baseline(ofCharacterAt index: Int) -> CGFloat {
            let glyph = layout.glyphIndexForCharacter(at: index)
            return view.textContainerInset.top + layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil).minY
                + layout.location(forGlyphAt: glyph).y
        }
        let voiceIndex = string.range(of: RichNote.attachmentCharacter).location
        let lettersAbove = baseline(ofCharacterAt: 0) - font.descender   // lowest point of "Prvý riadok"
        let lettersBelow = baseline(ofCharacterAt: string.length - 1) - font.capHeight
        let ownLine = baseline(ofCharacterAt: voiceIndex - 2) - font.capHeight / 2

        #expect(token.frame.minY - lettersAbove >= 6)
        #expect(lettersBelow - token.frame.maxY >= 6)
        #expect(abs(token.frame.midY - ownLine) < 1)   // centred on the words beside it
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

    // MARK: From Denník outside the figure

    @Test func denníkVoiceNoteArrivesAsAVoiceNoteNotADate() throws {
        let (container, node) = try makeNode(notes: "Rám hore")
        _ = container
        let voice = VoiceNoteRef(fileName: "voice_h.m4a", duration: 7)
        let updated = RichNote.appending([NoteMedia.voice(voice).piece], to: node)
        node.notes = updated.plain
        node.notesRichData = updated.rich

        #expect(node.notes == "Rám hore\n[hlasovka 0:07]")
        #expect(RichNote.voiceNotes(in: RichNote.attributed(for: node)) == [voice])
    }

    @Test func eachPartGetsItsOwnLineAndPlainTextStaysPlain() throws {
        let (container, node) = try makeNode(notes: "")
        _ = container
        let onlyText = RichNote.appending([AttributedString("Zdvih až na 3")], to: node)
        #expect(onlyText.plain == "Zdvih až na 3")
        #expect(onlyText.rich == nil)

        let video = VideoNoteRef(path: "clip.mov", isPortrait: false)
        let both = RichNote.appending([AttributedString("Hlava"), NoteMedia.video(video).piece], to: node)
        #expect(both.plain == "Hlava\n[video]")
        #expect(both.rich != nil)
    }

    // MARK: Videos

    private func layoutBlock(isPortrait: Bool) throws -> CGRect {
        var text = AttributedString("Rám hore\n")
        text.append(NoteMedia.video(VideoNoteRef(path: "clip.mov", isPortrait: isPortrait)).piece)
        text.append(AttributedString("\nPotom zdvih."))
        let view = NotesTextView.make()
        view.frame = CGRect(x: 0, y: 0, width: 360, height: 600)
        view.attributedText = NoteTextBridge.attributed(text, controller: NoteEditorController())
        view.layoutIfNeeded()
        #expect(view.textLayoutManager == nil)
        let block = try #require(view.subviews.first { $0.accessibilityIdentifier == NotesTextView.videoBlockIdentifier })
        return block.frame
    }

    @Test func videoAndVoiceComeBackAfterThePartnerEdits() throws {
        let voice = VoiceNoteRef(fileName: "voice_f.m4a", duration: 3)
        let video = VideoNoteRef(path: "journal_clip.mov", isPortrait: true)
        var text = AttributedString("Hlava ")
        text.append(NoteMedia.voice(voice).piece)
        text.append(AttributedString("\n"))
        text.append(NoteMedia.video(video).piece)
        text.append(AttributedString("\nZdvih."))
        #expect(RichNote.plain(text) == "Hlava [hlasovka 0:03]\n[video]\nZdvih.")

        let (container, node) = try makeNode(notes: RichNote.plain(text))
        _ = container
        node.notesRichData = RichNote.encode(text)
        node.notes = "Pozor! Hlava [hlasovka 0:03]\n[video]\nZdvih až na 3."
        let reopened = RichNote.attributed(for: node)
        #expect(RichNote.media(in: reopened) == [.voice(voice), .video(video)])
        #expect(RichNote.plain(reopened) == node.notes)
    }

    @Test func editorKeepsVideosUnchanged() {
        var text = AttributedString("Rám\n")
        text.append(NoteMedia.video(VideoNoteRef(path: "clip.mov", isPortrait: false)).piece)
        text.append(AttributedString("\nhore"))
        let shown = NoteTextBridge.attributed(text, controller: NoteEditorController())
        #expect(NoteTextBridge.model(from: shown) == text)
    }

    @Test func landscapeVideoIsABlockAcrossTheText() throws {
        let frame = try layoutBlock(isPortrait: false)
        let width: CGFloat = 360 - 2 * 5   // minus the line padding on both sides
        #expect(abs(frame.width - width) < 1)
        #expect(abs(frame.height - (width * 9 / 16 + 2 * VideoTextAttachment.gap)) < 1)
        #expect(frame.minY > 20)   // below "Rám hore", on a line of its own
    }

    @Test func uprightVideoIsTallAndNarrow() throws {
        let frame = try layoutBlock(isPortrait: true)
        #expect(abs(frame.height - (VideoTextAttachment.maxHeight + 2 * VideoTextAttachment.gap)) < 1)
        let video = VideoTextAttachment.videoSize(isPortrait: true, width: frame.width)
        #expect(video.width < frame.width / 2)
    }
}
