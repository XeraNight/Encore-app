import Testing
import Foundation
import SwiftData
@testable import Encore

/// A reflection after a training and the note that carries its words into Denník are one text written twice. Taking
/// the dance off the note must take it off the reflection too (the plan and the trends read the reflection), and the
/// words changed in the note must not be undone by the next save of the reflection.
@MainActor
struct ReflectionMirrorTests {
    private func makeContext() throws -> (ModelContainer, ModelContext) {
        let schema = Schema([TrainingLogEntry.self, InstantNote.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        return (container, container.mainContext)
    }

    /// What the debrief makes: a reflection about Cha-cha and its note, linked by `noteId`.
    private func reflectionWithNote(in context: ModelContext) -> (TrainingLogEntry, InstantNote) {
        let note = InstantNote(text: "Panva dopredu rovno ako idem na stojnu nohu", danceName: "Cha-Cha-Cha")
        let entry = TrainingLogEntry(day: Date(), cadenceId: UUID(), title: "LAT")
        entry.reflectionNote = note.text
        entry.danceName = "Cha-Cha-Cha"
        entry.noteId = note.id
        context.insert(note)
        context.insert(entry)
        return (entry, note)
    }

    @Test func aReflectionIsFoundByItsNote() throws {
        let (container, context) = try makeContext()
        _ = container
        let (entry, note) = reflectionWithNote(in: context)
        let ownNote = InstantNote(text: "Poznámka sama o sebe")
        context.insert(ownNote)
        try context.save()

        #expect(note.reflection(in: context)?.id == entry.id)
        #expect(ownNote.reflection(in: context) == nil)
    }

    /// The reported case: "Bez tanca" on the note, "Hotovo", and the reflection still said Cha-cha-cha.
    @Test func takingTheDanceOffTheNoteTakesItOffTheReflection() throws {
        let (container, context) = try makeContext()
        _ = container
        let (entry, note) = reflectionWithNote(in: context)

        note.danceName = nil
        entry.follow(note)

        #expect(entry.danceName == nil)
    }

    @Test func anotherDanceOnTheNoteIsTheDanceOfTheReflection() throws {
        let (container, context) = try makeContext()
        _ = container
        let (entry, note) = reflectionWithNote(in: context)

        note.danceName = "Rumba"
        entry.follow(note)

        #expect(entry.danceName == "Rumba")
    }

    @Test func theWordsChangedInTheNoteAreTheWordsOfTheReflection() throws {
        let (container, context) = try makeContext()
        _ = container
        let (entry, note) = reflectionWithNote(in: context)

        note.text = "Panva dopredu, nie potom.\n"
        entry.follow(note)

        #expect(entry.reflectionNote == "Panva dopredu, nie potom.")
    }

    @Test func aNoteLeftEmptyLeavesTheReflectionEmptyToo() throws {
        let (container, context) = try makeContext()
        _ = container
        let (entry, note) = reflectionWithNote(in: context)

        note.text = "  \n"
        entry.follow(note)

        #expect(entry.reflectionNote.isEmpty)
    }

    /// Nothing else of the reflection is touched: its feelings, its day, its training stay as they were.
    @Test func onlyTheWordsAndTheDanceFollow() throws {
        let (container, context) = try makeContext()
        _ = container
        let (entry, note) = reflectionWithNote(in: context)
        entry.statusRaw = TrainingStatus.attended.rawValue
        entry.feelingRaw = TrainingFeeling.tired.rawValue
        let day = entry.day

        note.danceName = nil
        note.text = "Nové slová"
        entry.follow(note)

        #expect(entry.title == "LAT")
        #expect(entry.day == day)
        #expect(entry.status == .attended)
        #expect(entry.feeling == .tired)
        #expect(entry.noteId == note.id)
    }

    // MARK: Deleting

    @Test func theNoteOfAReflectionIsFoundThroughTheReflection() throws {
        let (container, context) = try makeContext()
        _ = container
        let (entry, note) = reflectionWithNote(in: context)
        let withoutNote = TrainingLogEntry(day: Date(), cadenceId: UUID(), title: "STD")
        context.insert(withoutNote)
        try context.save()

        #expect(entry.note(in: context)?.id == note.id)
        #expect(withoutNote.note(in: context) == nil)
    }

    /// Deleting a reflection used to leave its note in Denník, with the same words and the old dance.
    @Test func deletingAReflectionDeletesItsNoteToo() throws {
        let (container, context) = try makeContext()
        _ = container
        let (entry, _) = reflectionWithNote(in: context)
        let ownNote = InstantNote(text: "Poznámka sama o sebe")
        let ownId = ownNote.id
        context.insert(ownNote)
        try context.save()

        entry.delete(in: context)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<TrainingLogEntry>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<InstantNote>()).map(\.id) == [ownId])
    }

    @Test func aReflectionWhoseNoteIsAlreadyGoneIsDeletedAlone() throws {
        let (container, context) = try makeContext()
        _ = container
        let entry = TrainingLogEntry(day: Date(), cadenceId: UUID(), title: "LAT")
        entry.reflectionNote = "Slová"
        entry.noteId = UUID()
        context.insert(entry)
        try context.save()

        entry.delete(in: context)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<TrainingLogEntry>()).isEmpty)
    }

    /// Deleting only the note in Denník used to leave the reflection behind, and the next save of the reflection made the
    /// note again.
    @Test func deletingTheNoteOfAReflectionDeletesTheReflectionToo() throws {
        let (container, context) = try makeContext()
        _ = container
        let (_, note) = reflectionWithNote(in: context)
        let ownNote = InstantNote(text: "Poznámka sama o sebe")
        let ownId = ownNote.id
        context.insert(ownNote)
        try context.save()

        note.delete(in: context)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<TrainingLogEntry>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<InstantNote>()).map(\.id) == [ownId])
    }

    @Test func deletingANoteOfItsOwnLeavesTheReflectionsAlone() throws {
        let (container, context) = try makeContext()
        _ = container
        let (entry, note) = reflectionWithNote(in: context)
        let ownNote = InstantNote(text: "Poznámka sama o sebe")
        context.insert(ownNote)
        try context.save()

        ownNote.delete(in: context)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<TrainingLogEntry>()).map(\.id) == [entry.id])
        #expect(try context.fetch(FetchDescriptor<InstantNote>()).map(\.id) == [note.id])
    }

    @Test func deletingANoteRemovesItsRecordingAndPhoto() throws {
        let (container, context) = try makeContext()
        _ = container
        let audio = "test_note_\(UUID().uuidString).m4a"
        let photo = "test_note_\(UUID().uuidString).jpg"
        for name in [audio, photo] { try Data([1]).write(to: MediaStorageManager.url(for: name)) }
        defer { for name in [audio, photo] { MediaStorageManager.removeFile(named: name) } }
        let note = InstantNote(imagePath: photo, audioPath: audio, audioDuration: 3)
        context.insert(note)
        try context.save()

        note.delete(in: context)
        try context.save()

        #expect(!MediaStorageManager.fileExists(audio))
        #expect(!MediaStorageManager.fileExists(photo))
    }
}
