import Testing
import Foundation
import SwiftData
@testable import Encore

/// One video file can show in several places (a Denník note, a figure, a library figure, a vault). Deleting it from one
/// of them used to delete the file and leave a black picture in the others; now the file goes only when nothing else
/// shows it.
@MainActor
struct VideoInUseTests {
    private func makeContext() throws -> (ModelContainer, ModelContext) {
        let schema = AccountStore.schema
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        return (container, container.mainContext)
    }

    /// A small file in Documents, removed at the end of the test whatever happens.
    private func makeVideoFile() throws -> String {
        let name = "test_video_\(UUID().uuidString).mp4"
        try Data([1, 2, 3]).write(to: MediaStorageManager.url(for: name))
        return name
    }

    @Test func aVideoNothingElseShowsIsDeleted() throws {
        let (container, context) = try makeContext()
        _ = container
        let name = try makeVideoFile()
        defer { MediaStorageManager.removeFile(named: name) }
        let node = CanvasNode(x: 0, y: 0, figureName: "Telemark", videoPath: name)
        context.insert(node)
        try context.save()

        #expect(MediaStorageManager.removeVideoIfUnused(name, in: context, ignoring: node.id))
        #expect(!MediaStorageManager.fileExists(name))
    }

    @Test func aVideoADennikNoteShowsStays() throws {
        let (container, context) = try makeContext()
        _ = container
        let name = try makeVideoFile()
        defer { MediaStorageManager.removeFile(named: name) }
        let node = CanvasNode(x: 0, y: 0, figureName: "Telemark", videoPath: name)
        context.insert(node)
        context.insert(InstantNote(videoPath: name))
        try context.save()

        #expect(!MediaStorageManager.removeVideoIfUnused(name, in: context, ignoring: node.id))
        #expect(MediaStorageManager.fileExists(name))
    }

    @Test func aVideoAnotherFigureShowsStaysAlsoAsItsTargetVideo() throws {
        let (container, context) = try makeContext()
        _ = container
        let name = try makeVideoFile()
        defer { MediaStorageManager.removeFile(named: name) }
        let node = CanvasNode(x: 0, y: 0, figureName: "Telemark", videoPath: name)
        let other = CanvasNode(x: 0, y: 0, figureName: "Spin", activeTargetVideoPath: name)
        context.insert(node)
        context.insert(other)
        try context.save()

        #expect(MediaStorageManager.isVideoInUse(name, in: context, ignoring: node.id))
        #expect(MediaStorageManager.fileExists(name))
    }

    /// The reported case: the same video in a library figure and in a note; deleting the figure took the note's video.
    @Test func deletingALibraryFigureKeepsAVideoANoteShowsUntilTheNoteGoesToo() throws {
        let (container, context) = try makeContext()
        _ = container
        let name = try makeVideoFile()
        defer { MediaStorageManager.removeFile(named: name) }
        let figure = FigureLibraryItem(name: "Spin", danceName: "Waltz", rhythm: "SQQ", videoPath: name, isCustom: true)
        let note = InstantNote(videoPath: name)
        context.insert(figure)
        context.insert(note)
        try context.save()

        context.delete(figure)
        try context.save()
        #expect(!MediaStorageManager.removeVideoIfUnused(name, in: context))
        #expect(MediaStorageManager.fileExists(name))

        context.delete(note)
        try context.save()
        #expect(MediaStorageManager.removeVideoIfUnused(name, in: context))
        #expect(!MediaStorageManager.fileExists(name))
    }

    @Test func aLibraryFigureARoutineAndADanceEachKeepTheFile() throws {
        for holder in 0..<3 {
            let (container, context) = try makeContext()
            _ = container
            let name = try makeVideoFile()
            defer { MediaStorageManager.removeFile(named: name) }
            switch holder {
            case 0: context.insert(FigureLibraryItem(name: "Spin", danceName: "Waltz", rhythm: "SQQ", videoPath: name, isCustom: true))
            case 1: context.insert(Routine(name: "Valčík", danceName: "Waltz", danceCategory: "Standard", videoPath: name))
            default: context.insert(Dance(name: "Waltz", category: "Standard", tempo: "30", info: "", videoPath: name))
            }
            try context.save()

            #expect(!MediaStorageManager.removeVideoIfUnused(name, in: context), "holder \(holder)")
            #expect(MediaStorageManager.fileExists(name), "holder \(holder)")
        }
    }

    @Test func aVaultEntryOfARoutineKeepsTheFileButTheFiguresOwnEntryDoesNot() throws {
        let (container, context) = try makeContext()
        _ = container
        let name = try makeVideoFile()
        defer { MediaStorageManager.removeFile(named: name) }
        let node = CanvasNode(x: 0, y: 0, figureName: "Telemark", videoPath: name)
        let own = VideoMediaEntry(filePath: name, title: "Môj záber")
        own.canvasNode = node
        context.insert(node)
        context.insert(own)
        try context.save()
        // Only the figure's own vault entry holds it besides the figure: it goes with the figure's video.
        #expect(!MediaStorageManager.isVideoInUse(name, in: context, ignoring: node.id))

        let routine = Routine(name: "Valčík", danceName: "Waltz", danceCategory: "Standard")
        let kept = VideoMediaEntry(filePath: name, title: "Zo zostavy")
        kept.routine = routine
        context.insert(routine)
        context.insert(kept)
        try context.save()
        #expect(MediaStorageManager.isVideoInUse(name, in: context, ignoring: node.id))
    }

    @Test func notesWrittenInAFigureThatNameTheFileKeepIt() throws {
        let (container, context) = try makeContext()
        _ = container
        let name = try makeVideoFile()
        defer { MediaStorageManager.removeFile(named: name) }
        let losing = CanvasNode(x: 0, y: 0, figureName: "Telemark")
        let writer = CanvasNode(x: 0, y: 0, figureName: "Spin")
        writer.notesRichData = Data("{\"video\":\"\(name)\"}".utf8)
        context.insert(losing)
        context.insert(writer)
        try context.save()

        // Another figure's written notes name the file.
        #expect(MediaStorageManager.isVideoInUse(name, in: context, ignoring: losing.id))
        // Only the figure that is being changed names it itself: that does not count.
        #expect(!MediaStorageManager.isVideoInUse(name, in: context, ignoring: writer.id))
    }

    /// The video of a deleted note used to stay on the iPhone for good (it can be a gigabyte); a figure that shows it keeps it.
    @Test func deletingANoteDeletesItsVideoOnlyWhenNothingElseShowsIt() throws {
        let (container, context) = try makeContext()
        _ = container
        let alone = try makeVideoFile()
        let shared = try makeVideoFile()
        defer { [alone, shared].forEach { MediaStorageManager.removeFile(named: $0) } }
        let noteAlone = InstantNote(videoPath: alone)
        let noteShared = InstantNote(videoPath: shared)
        let figure = CanvasNode(x: 0, y: 0, figureName: "Telemark", videoPath: shared)
        [noteAlone, noteShared].forEach { context.insert($0) }
        context.insert(figure)
        try context.save()

        noteAlone.delete(in: context)
        noteShared.delete(in: context)
        try context.save()

        #expect(!MediaStorageManager.fileExists(alone))
        #expect(MediaStorageManager.fileExists(shared))
    }

    @Test func aNoteWithAFotkyVideoHasNoFileToDelete() throws {
        let (container, context) = try makeContext()
        _ = container
        let note = InstantNote(videoPath: "photos:ABC")
        context.insert(note)
        try context.save()

        note.delete(in: context)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<InstantNote>()).isEmpty)
    }

    @Test func aFotkyLinkIsNeverAFileHere() throws {
        let (container, context) = try makeContext()
        _ = container
        #expect(!MediaStorageManager.removeVideoIfUnused("photos:ABC", in: context))
        #expect(!MediaStorageManager.removeVideoIfUnused(nil, in: context))
        #expect(!MediaStorageManager.removeVideoIfUnused("", in: context))
    }
}
