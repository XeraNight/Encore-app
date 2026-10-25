import Testing
import Foundation
import SwiftData
@testable import Encore

/// What goes to the cloud backup comes back the same: every kind, every field the user wrote, links to media
/// included. Calendar event ids belong to one iPhone and are not backed up.
@MainActor
struct DeviceBackupTests {
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    /// Backed up, restored as a new object, backed up again: the two copies are byte for byte the same.
    private func expectRoundTrip<M: BackedUp>(_ model: M) throws {
        let saved = try encoder.encode(model.backup)
        let restored = M(backup: try decoder.decode(M.Backup.self, from: saved))
        #expect(restored.id == model.id)
        #expect(try encoder.encode(restored.backup) == saved)
    }

    /// Whole seconds: the backup keeps dates to the second, so the copy and the original compare equal.
    private let day = Date(timeIntervalSince1970: 1_792_000_000)

    @Test func everyKindComesBackTheSame() throws {
        let schema = Schema(DeviceBackup.types.map { $0 as any PersistentModel.Type })
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = container.mainContext

        let entry = TrainingLogEntry(day: day, cadenceId: UUID(), title: "Vedený tréning")
        entry.statusRaw = TrainingStatus.attended.rawValue
        entry.reflectionNote = "Jive na konci, nohy nestíhali"
        entry.moments = [TrainingMoment(feelingRaw: TrainingFeeling.tired.rawValue, danceName: "Jive", note: "posledná zostava")]
        entry.danceName = "Jive"
        entry.noteId = UUID()
        entry.sessionId = UUID()

        let session = PlannedSession(start: day, durationMinutes: 45, kind: .solo)
        session.title = "Súkromná hodina"
        session.goal = "Waltz: rotácia"
        session.goalPriorityId = UUID()

        let competition = PlannedCompetition(name: "Košice GP", city: "Košice", date: day)
        competition.targetCategories = ["Dospelí D ŠTT", "Dospelí D LAT"]
        competition.entryDeadline = day
        competition.isTargetCompetition = true

        let cadence = TrainingCadence(weekday: 2, title: "Klubový tréning", startMinutes: 18 * 60, location: "Košice")
        cadence.createdAt = day
        cadence.isEnabled = false

        let priority = LessonPriority(danceName: "Tango", text: "Hlava doľava", rank: 2, createdAt: day, logEntryId: entry.id)
        priority.doneAt = day

        let note = InstantNote(createdAt: day, text: "Quickstep: lock step", videoPath: "ph://ABC", audioPath: "voice_1.m4a",
                               audioDuration: 12.5, danceName: "Quickstep")
        note.isPinned = true
        note.linkedRoutineId = UUID()

        context.insert(entry)
        context.insert(session)
        context.insert(competition)
        context.insert(cadence)
        context.insert(priority)
        context.insert(note)
        try context.save()

        try expectRoundTrip(entry)
        try expectRoundTrip(session)
        try expectRoundTrip(competition)
        try expectRoundTrip(cadence)
        try expectRoundTrip(priority)
        try expectRoundTrip(note)
    }

    @Test func eachKindHasItsOwnName() {
        let kinds = DeviceBackup.types.map { $0.backupKind }
        #expect(Set(kinds).count == kinds.count)
        // The names the database accepts (device_records.kind).
        #expect(Set(kinds) == ["training_log", "planned_session", "planned_competition",
                               "training_cadence", "lesson_priority", "instant_note"])
    }
}
