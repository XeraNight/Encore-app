import Testing
import Foundation
import SwiftUI
import SwiftData
@testable import Encore

/// A new iPhone gets a figure with its plain text only. Its formatted notes (the voice notes inside, bold text) come back
/// from the backup, but only what can really be shown there: a voice note comes back from its private copy in the cloud, a
/// photo (a file on the old iPhone) and a video (a place in its Fotky) cannot, so they go back to their marker in the text and
/// no picture or recording is left that cannot be shown or played.
@MainActor
struct FigureNotesBackupTests {
    private let voice = VoiceNoteRef(fileName: "voice_\(UUID().uuidString).m4a", duration: 12)

    private func makeNode(notes: String) throws -> (ModelContainer, CanvasNode) {
        let schema = Schema([Routine.self, CanvasNode.self, VideoMediaEntry.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let node = CanvasNode(x: 0, y: 0, figureName: "Telemark", rhythm: "SQQ", notes: notes, orderIndex: 0)
        container.mainContext.insert(node)
        return (container, node)
    }

    /// "tučné" in red, a voice note, a photo and a video, all in one note.
    private func fullNote() -> AttributedString {
        var text = AttributedString("Rám ")
        var colored = AttributedString("tučné ")
        colored.foregroundColor = .red
        text.append(colored)
        text.append(NoteMedia.voice(voice).piece)
        text.append(AttributedString(" a "))
        text.append(NoteMedia.photo(PhotoNoteRef(path: "note_photo_a.jpg", isPortrait: true)).piece)
        text.append(AttributedString(" b "))
        text.append(NoteMedia.video(VideoNoteRef(path: "ph://ABC", isPortrait: false)).piece)
        text.append(AttributedString(" c"))
        return text
    }

    // MARK: What goes up

    @Test func formattedNotesGoUpAndComeBackTheSame() throws {
        let text = fullNote()
        let (container, node) = try makeNode(notes: RichNote.plain(text))
        _ = container
        node.notesRichData = RichNote.encode(text)

        let payload = try #require(DeviceBackup.figureNotesPayload(of: node))
        #expect(DeviceBackup.figureNotes(in: payload) == node.notesRichData)
    }

    @Test func aFigureWithoutFormattedNotesSendsNothing() throws {
        let (container, node) = try makeNode(notes: "Rám drž.")
        _ = container
        #expect(DeviceBackup.figureNotesPayload(of: node) == nil)
    }

    /// The database refuses a record of 64 KB, and one refused record would stop the whole batch: a longer note stays here.
    @Test func notesTooLongForARecordStayOnTheIPhone() throws {
        let (container, node) = try makeNode(notes: "x")
        _ = container

        node.notesRichData = Data(repeating: 7, count: DeviceBackup.figureNotesLimit)
        let atTheLimit = try #require(DeviceBackup.figureNotesPayload(of: node))
        #expect(atTheLimit.count < 65_536)

        node.notesRichData = Data(repeating: 7, count: DeviceBackup.figureNotesLimit + 1)
        #expect(DeviceBackup.figureNotesPayload(of: node) == nil)
    }

    // MARK: What comes back

    @Test func onlyTheVoiceNoteComesBackAndTheRestGoesBackToItsMarker() {
        let text = fullNote()
        let kept = RichNote.keepingOnlyVoice(text)

        #expect(RichNote.voiceNotes(in: kept) == [voice])
        #expect(RichNote.photos(in: kept).isEmpty)
        #expect(RichNote.media(in: kept).count == 1)
        #expect(RichNote.plain(kept) == RichNote.plain(text))
        #expect(RichNote.plain(kept).contains("[fotka]") && RichNote.plain(kept).contains("[video]"))
    }

    @Test func theFormattingComesBackToo() {
        let kept = RichNote.keepingOnlyVoice(fullNote())
        #expect(kept.runs.contains { $0.foregroundColor != nil })
    }

    /// A note that had only voice notes and formatting is the same note after the round trip.
    @Test func aNoteWithOnlyVoiceNotesIsUnchanged() {
        var text = AttributedString("Hlava ")
        text.append(NoteMedia.voice(voice).piece)
        text.append(AttributedString(" vľavo."))

        let kept = RichNote.keepingOnlyVoice(text)
        #expect(kept == text)
    }

    /// The figure on the new iPhone: its plain text from the routine sync, the formatted notes from the backup. The note
    /// shows the voice note, and the text is the one the partner and the coach read.
    @Test func theFigureOnTheNewIPhoneShowsTheVoiceNote() throws {
        let text = fullNote()
        let (container, node) = try makeNode(notes: RichNote.plain(text))
        _ = container
        #expect(RichNote.voiceNotes(in: RichNote.attributed(for: node)).isEmpty)

        node.notesRichData = RichNote.encode(RichNote.keepingOnlyVoice(text))

        let shown = RichNote.attributed(for: node)
        #expect(RichNote.voiceNotes(in: shown) == [voice])
        #expect(RichNote.plain(shown) == node.notes)
    }

    /// The recording inside the restored note is one the voice backup knows about, so it is not forgotten or removed.
    @Test func theRestoredVoiceNoteIsOneOfTheFiguresRecordings() throws {
        let text = fullNote()
        let (container, node) = try makeNode(notes: RichNote.plain(text))
        node.notesRichData = RichNote.encode(RichNote.keepingOnlyVoice(text))
        try container.mainContext.save()

        #expect(VoiceBackup.recordings(in: container.mainContext).names == [voice.fileName])
    }
}
