import Testing
import Foundation
import SwiftUI
import SwiftData
@testable import Encore

/// A photo inside a figure's notes, the diary filter and the one QR entry: what must keep holding.
@MainActor
struct NotePhotoAndFilterTests {
    private func makeNode(notes: String) throws -> (ModelContainer, CanvasNode) {
        let schema = Schema([Routine.self, CanvasNode.self, VideoMediaEntry.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let node = CanvasNode(x: 0, y: 0, figureName: "Telemark", rhythm: "SQQ", notes: notes, orderIndex: 0)
        container.mainContext.insert(node)
        return (container, node)
    }

    private func notes(withPhoto ref: PhotoNoteRef) -> AttributedString {
        var text = AttributedString("Rám ")
        text.append(NoteMedia.photo(ref).piece)
        text.append(AttributedString(" drž."))
        return text
    }

    @Test func plainTextShowsAPhotoMarkerForThePartner() {
        let text = notes(withPhoto: PhotoNoteRef(path: "note_photo_a.jpg", isPortrait: true))
        #expect(RichNote.plain(text) == "Rám [fotka] drž.")
    }

    @Test func photoSurvivesSavingAndOpeningAgain() throws {
        let ref = PhotoNoteRef(path: "note_photo_b.jpg", isPortrait: false)
        let text = notes(withPhoto: ref)
        let (container, node) = try makeNode(notes: RichNote.plain(text))
        _ = container
        node.notesRichData = RichNote.encode(text)
        #expect(RichNote.photos(in: RichNote.attributed(for: node)) == [ref])
    }

    @Test func photoComesBackWhenThePartnerEditsTheTextAroundIt() throws {
        let ref = PhotoNoteRef(path: "note_photo_c.jpg", isPortrait: true)
        let text = notes(withPhoto: ref)
        let (container, node) = try makeNode(notes: "Rám [fotka] drž pevne.")
        _ = container
        node.notesRichData = RichNote.encode(text)
        let reopened = RichNote.attributed(for: node)
        #expect(RichNote.photos(in: reopened) == [ref])
        #expect(RichNote.plain(reopened) == "Rám [fotka] drž pevne.")
    }

    @Test func aPhotoAndAVideoAreKeptInTheirOrder() {
        var text = AttributedString("a ")
        text.append(NoteMedia.video(VideoNoteRef(path: "v.mp4", isPortrait: false)).piece)
        text.append(AttributedString(" b "))
        text.append(NoteMedia.photo(PhotoNoteRef(path: "p.jpg", isPortrait: true)).piece)
        let kinds = RichNote.media(in: text).map { media -> String in
            switch media {
            case .voice: return "voice"
            case .video: return "video"
            case .photo: return "photo"
            }
        }
        #expect(kinds == ["video", "photo"])
    }

    @Test func diaryFilterSeparatesTheKindsOfNotes() {
        let text = InstantNote(text: "Rám")
        let voice = InstantNote(audioPath: "a.m4a", audioDuration: 3)
        let video = InstantNote(videoPath: "v.mp4")
        let photo = InstantNote(imagePath: "p.jpg")
        typealias Filter = TrainingJournalView.JournalFilter
        #expect(Filter.text.matches(text) && !Filter.text.matches(voice))
        #expect(Filter.voice.matches(voice) && !Filter.voice.matches(video))
        #expect(Filter.video.matches(video) && !Filter.video.matches(photo))
        #expect(Filter.photo.matches(photo) && !Filter.photo.matches(text))
        #expect([text, voice, video, photo].allSatisfy(Filter.all.matches))
    }

    @Test func unassignedMeansNotYetInAFigure() {
        let free = InstantNote(text: "Rám")
        let linked = InstantNote(text: "Rám")
        linked.linkedFigureId = UUID()
        let imported = InstantNote(text: "Rám")
        imported.importedAt = Date()
        let filter = TrainingJournalView.JournalFilter.unassigned
        #expect(filter.matches(free))
        #expect(!filter.matches(linked))
        #expect(!filter.matches(imported))
    }

    @Test func aPhotoNoteReadsAsAPhoto() {
        #expect(InstantNote(imagePath: "p.jpg").previewText == "Fotka")
        #expect(InstantNote(imagePath: "p.jpg").kindIcon == "photo.fill")
    }

    @Test func anUnknownQRCodeIsToldToTheDancer() {
        let manager = FriendManager.shared
        manager.inviteErrorMessage = nil
        #expect(manager.handleScanned("https://example.com/not-encore") == false)
        #expect(manager.inviteErrorMessage == "Tento QR kód Encore nepozná.")
        manager.inviteErrorMessage = nil
        #expect(manager.handleScanned("  plain text, not a link  ") == false)
        #expect(manager.inviteErrorMessage != nil)
        manager.inviteErrorMessage = nil
    }
}
