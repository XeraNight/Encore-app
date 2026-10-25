import CryptoKit
import Foundation
import OSLog
import Supabase
import SwiftData

// MARK: - Backup of what lives only on this iPhone
/// The diary, the plan and the notes live on the iPhone (local-first). Their text and the links to their media go to
/// `device_records`, so a new iPhone, or this one after another account used it, gets them back. Media stay where they
/// are: videos in Fotky, voice notes and photos on the iPhone.
///
/// - What went up is remembered as a fingerprint per record, so only what changed goes, in batches, when the app opens,
///   goes to the background or the network comes back (PendingSyncRunner). A failure keeps it for the next try.
/// - A record deleted here goes up as deleted.
/// - Only an iPhone that never sent anything and holds none of these is filled from the cloud, so nothing here is ever
///   overwritten. Wiping the store for another account forgets the fingerprints too (LocalDataGuard).
@MainActor
enum DeviceBackup {
    private static let fingerprintsKey = "encore.deviceBackup.v1"
    /// The account whose empty backup was already looked for: an empty cloud is not asked again on every launch.
    private static let checkedKey = "encore.deviceBackup.checkedUser"
    private static let batchSize = 200
    private static let pageSize = 1000
    private static var isUploading = false
    /// Bumped by `reset()`: work that started before it remembers nothing.
    private static var generation = 0

    static let types: [any BackedUp.Type] = [
        TrainingLogEntry.self, PlannedSession.self, PlannedCompetition.self,
        TrainingCadence.self, LessonPriority.self, InstantNote.self,
    ]

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private struct Row: Codable {
        let user_id: UUID
        let kind: String
        let id: UUID
        let payload: AnyJSON
        let updated_at: Date
        let deleted: Bool
    }

    private struct Record {
        let kind: String
        let id: UUID
        let payload: Data
        var key: String { DeviceBackup.key(kind, id) }
    }

    // MARK: Up
    /// Sends what changed since it last went up and what was deleted here.
    static func upload(in context: ModelContext) async {
        guard !isUploading, let userId = SupabaseConfig.client.auth.currentUser?.id else { return }
        isUploading = true
        defer { isUploading = false }
        let startedIn = generation
        var fingerprints = storedFingerprints()
        let records = localRecords(in: context)
        let present = Set(records.map(\.key))
        let now = Date()

        var pending: [(key: String, row: Row, fingerprint: String?)] = []
        for record in records where fingerprints[record.key] != fingerprint(record.payload) {
            guard let payload = try? JSONDecoder().decode(AnyJSON.self, from: record.payload) else { continue }
            let row = Row(user_id: userId, kind: record.kind, id: record.id, payload: payload, updated_at: now, deleted: false)
            pending.append((record.key, row, fingerprint(record.payload)))
        }
        for key in fingerprints.keys where !present.contains(key) {
            guard let (kind, id) = split(key) else { continue }
            pending.append((key, Row(user_id: userId, kind: kind, id: id, payload: .object([:]), updated_at: now, deleted: true), nil))
        }

        for start in stride(from: 0, to: pending.count, by: batchSize) {
            let batch = pending[start..<min(start + batchSize, pending.count)]
            do {
                try await SupabaseConfig.client
                    .from("device_records")
                    .upsert(batch.map(\.row), onConflict: "user_id,kind,id")
                    .execute()
            } catch {
                Logger.sync.error("Device backup failed, kept for the next try: \(error.localizedDescription, privacy: .public)")
                return
            }
            guard generation == startedIn else { return }
            for item in batch { fingerprints[item.key] = item.fingerprint }
            UserDefaults.standard.set(fingerprints, forKey: fingerprintsKey)
        }
    }

    // MARK: Down
    /// Fills an empty iPhone that never sent anything: a new iPhone, or this one after another account used it.
    static func restoreIfNeeded() async {
        guard let context = AppContainer.shared?.mainContext,
              let userId = SupabaseConfig.client.auth.currentUser?.id,
              UserDefaults.standard.string(forKey: checkedKey) != userId.uuidString,
              storedFingerprints().isEmpty, localRecords(in: context).isEmpty else { return }
        let startedIn = generation

        var rows: [Row] = []
        do {
            while true {
                let page: [Row] = try await SupabaseConfig.client
                    .from("device_records")
                    .select("user_id, kind, id, payload, updated_at, deleted")
                    .eq("user_id", value: userId)
                    .eq("deleted", value: false)
                    .order("kind")
                    .order("id")
                    .range(from: rows.count, to: rows.count + pageSize - 1)
                    .execute()
                    .value
                rows += page
                if page.count < pageSize { break }
            }
        } catch {
            Logger.sync.error("Device backup download failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        // Something written meanwhile, or another account: nothing comes down over it.
        guard generation == startedIn, localRecords(in: context).isEmpty else { return }
        UserDefaults.standard.set(userId.uuidString, forKey: checkedKey)
        guard !rows.isEmpty else { return }

        for row in rows {
            guard let type = types.first(where: { $0.backupKind == row.kind }),
                  let data = try? JSONEncoder().encode(row.payload) else { continue }
            insert(type, from: data, into: context)
        }
        try? context.save()
        // What came down is what the cloud holds: it does not go up again.
        var fingerprints: [String: String] = [:]
        for record in localRecords(in: context) { fingerprints[record.key] = fingerprint(record.payload) }
        UserDefaults.standard.set(fingerprints, forKey: fingerprintsKey)
        Logger.sync.info("Device backup restored \(rows.count) records.")
        await PlannerNotifications.rescheduleFromStore()
    }

    /// The local store was wiped for another account: what went up from it belonged to the previous one.
    static func reset() {
        generation += 1
        UserDefaults.standard.removeObject(forKey: fingerprintsKey)
        UserDefaults.standard.removeObject(forKey: checkedKey)
    }

    // MARK: Records
    private static func localRecords(in context: ModelContext) -> [Record] {
        types.flatMap { records(of: $0, in: context) }
    }

    private static func records<M: BackedUp>(of type: M.Type, in context: ModelContext) -> [Record] {
        ((try? context.fetch(FetchDescriptor<M>())) ?? []).compactMap { model in
            (try? encoder.encode(model.backup)).map { Record(kind: M.backupKind, id: model.id, payload: $0) }
        }
    }

    private static func insert<M: BackedUp>(_ type: M.Type, from data: Data, into context: ModelContext) {
        guard let backup = try? decoder.decode(M.Backup.self, from: data) else { return }
        context.insert(M(backup: backup))
    }

    private static func storedFingerprints() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: fingerprintsKey) as? [String: String] ?? [:]
    }

    private static func fingerprint(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func key(_ kind: String, _ id: UUID) -> String { "\(kind)|\(id.uuidString)" }

    private static func split(_ key: String) -> (String, UUID)? {
        let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2, let id = UUID(uuidString: parts[1]) else { return nil }
        return (parts[0], id)
    }
}

// MARK: - What each kind keeps
/// The fields that are the user's own; Apple Calendar event ids and the calendar switch belong to one iPhone and stay.
protocol BackedUp: PersistentModel {
    associatedtype Backup: Codable
    static var backupKind: String { get }
    var id: UUID { get }
    var backup: Backup { get }
    init(backup: Backup)
}

extension TrainingLogEntry: BackedUp {
    nonisolated struct Backup: Codable {
        let id: UUID
        let day: Date
        let cadenceId: UUID?
        let title: String
        let statusRaw: String
        let reflectionNote: String
        let feelingRaw: String?
        let momentsData: Data?
        let danceName: String?
        let noteId: UUID?
        let associatedRoutineId: UUID?
        let sessionId: UUID?
    }

    static var backupKind: String { "training_log" }

    var backup: Backup {
        Backup(id: id, day: day, cadenceId: cadenceId, title: title, statusRaw: statusRaw, reflectionNote: reflectionNote,
               feelingRaw: feelingRaw, momentsData: momentsData, danceName: danceName, noteId: noteId,
               associatedRoutineId: associatedRoutineId, sessionId: sessionId)
    }

    convenience init(backup b: Backup) {
        self.init(id: b.id, day: b.day, cadenceId: b.cadenceId, title: b.title)
        statusRaw = b.statusRaw
        reflectionNote = b.reflectionNote
        feelingRaw = b.feelingRaw
        momentsData = b.momentsData
        danceName = b.danceName
        noteId = b.noteId
        associatedRoutineId = b.associatedRoutineId
        sessionId = b.sessionId
    }
}

extension PlannedSession: BackedUp {
    nonisolated struct Backup: Codable {
        let id: UUID
        let start: Date
        let durationMinutes: Int
        let title: String
        let kindRaw: String
        let location: String
        let danceCategory: String
        let goal: String
        let goalPriorityId: UUID?
        let goalOutcomeRaw: String?
    }

    static var backupKind: String { "planned_session" }

    var backup: Backup {
        Backup(id: id, start: start, durationMinutes: durationMinutes, title: title, kindRaw: kindRaw, location: location,
               danceCategory: danceCategory, goal: goal, goalPriorityId: goalPriorityId, goalOutcomeRaw: goalOutcomeRaw)
    }

    convenience init(backup b: Backup) {
        self.init(id: b.id, start: b.start, durationMinutes: b.durationMinutes)
        title = b.title
        kindRaw = b.kindRaw
        location = b.location
        danceCategory = b.danceCategory
        goal = b.goal
        goalPriorityId = b.goalPriorityId
        goalOutcomeRaw = b.goalOutcomeRaw
    }
}

extension PlannedCompetition: BackedUp {
    nonisolated struct Backup: Codable {
        let id: UUID
        let ksisCompetitionId: String?
        let name: String
        let city: String
        let date: Date
        let entryDeadline: Date?
        let targetCategories: [String]
        let intentRaw: String
        let isTargetCompetition: Bool
    }

    static var backupKind: String { "planned_competition" }

    var backup: Backup {
        Backup(id: id, ksisCompetitionId: ksisCompetitionId, name: name, city: city, date: date, entryDeadline: entryDeadline,
               targetCategories: targetCategories, intentRaw: intentRaw, isTargetCompetition: isTargetCompetition)
    }

    convenience init(backup b: Backup) {
        self.init(id: b.id, name: b.name, city: b.city, date: b.date)
        ksisCompetitionId = b.ksisCompetitionId
        entryDeadline = b.entryDeadline
        targetCategories = b.targetCategories
        intentRaw = b.intentRaw
        isTargetCompetition = b.isTargetCompetition
    }
}

extension TrainingCadence: BackedUp {
    nonisolated struct Backup: Codable {
        let id: UUID
        let weekday: Int
        let title: String
        let startMinutes: Int
        let durationMinutes: Int
        let location: String
        let danceCategory: String
        let isEnabled: Bool
        let createdAt: Date
    }

    static var backupKind: String { "training_cadence" }

    var backup: Backup {
        Backup(id: id, weekday: weekday, title: title, startMinutes: startMinutes, durationMinutes: durationMinutes,
               location: location, danceCategory: danceCategory, isEnabled: isEnabled, createdAt: createdAt)
    }

    convenience init(backup b: Backup) {
        self.init(id: b.id, weekday: b.weekday, title: b.title, startMinutes: b.startMinutes, durationMinutes: b.durationMinutes,
                  location: b.location, danceCategory: b.danceCategory)
        isEnabled = b.isEnabled
        createdAt = b.createdAt
    }
}

extension LessonPriority: BackedUp {
    nonisolated struct Backup: Codable {
        let id: UUID
        let danceName: String
        let text: String
        let rank: Int
        let createdAt: Date
        let doneAt: Date?
        let replacedAt: Date?
        let logEntryId: UUID?
    }

    static var backupKind: String { "lesson_priority" }

    var backup: Backup {
        Backup(id: id, danceName: danceName, text: text, rank: rank, createdAt: createdAt, doneAt: doneAt,
               replacedAt: replacedAt, logEntryId: logEntryId)
    }

    convenience init(backup b: Backup) {
        self.init(id: b.id, danceName: b.danceName, text: b.text, rank: b.rank, createdAt: b.createdAt, logEntryId: b.logEntryId)
        doneAt = b.doneAt
        replacedAt = b.replacedAt
    }
}

extension InstantNote: BackedUp {
    /// The media are links only: on a new iPhone a video is found again in Fotky, a voice note or photo stays behind.
    nonisolated struct Backup: Codable {
        let id: UUID
        let createdAt: Date
        let text: String
        let videoPath: String?
        let imagePath: String?
        let audioPath: String?
        let audioDuration: Double?
        let danceName: String?
        let isPinned: Bool
        let linkedFigureId: UUID?
        let linkedRoutineId: UUID?
        let importedAt: Date?
    }

    static var backupKind: String { "instant_note" }

    var backup: Backup {
        Backup(id: id, createdAt: createdAt, text: text, videoPath: videoPath, imagePath: imagePath, audioPath: audioPath,
               audioDuration: audioDuration, danceName: danceName, isPinned: isPinned, linkedFigureId: linkedFigureId,
               linkedRoutineId: linkedRoutineId, importedAt: importedAt)
    }

    convenience init(backup b: Backup) {
        self.init(id: b.id, createdAt: b.createdAt, text: b.text, videoPath: b.videoPath, imagePath: b.imagePath,
                  audioPath: b.audioPath, audioDuration: b.audioDuration, danceName: b.danceName)
        isPinned = b.isPinned
        linkedFigureId = b.linkedFigureId
        linkedRoutineId = b.linkedRoutineId
        importedAt = b.importedAt
    }
}
