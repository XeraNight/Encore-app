import Foundation
import SwiftData
import Supabase
import OSLog

// MARK: - "Stiahnuť moje dáta" (GDPR art. 15 and 20)
/// One JSON file with everything the server keeps about the user (`export_my_data` RPC) and the data
/// that lives only on this iPhone (notes, Plán, dances, own figures, routines on the phone).
/// Internal file paths are left out; the file says only whether a note has a video, photo or recording.
enum MyDataExport {
    enum Failure: LocalizedError {
        case server, file

        var errorDescription: String? {
            switch self {
            case .server: return "Dáta zo servera sa nepodarilo načítať. Skontroluj pripojenie a skús to znova."
            case .file: return "Súbor sa nepodarilo vytvoriť. Skús to znova."
            }
        }
    }

    /// Builds the file and returns its URL in the temporary folder (the share sheet takes it from there).
    static func makeFile(context: ModelContext) async throws -> URL {
        let device = DeviceData(context: context)

        let server: Data
        do {
            server = try await SupabaseConfig.client.rpc("export_my_data").execute().data
        } catch {
            Logger.sync.error("export_my_data failed: \(error.localizedDescription, privacy: .public)")
            throw Failure.server
        }

        do {
            return try await Task.detached(priority: .userInitiated) {
                try write(server: server, device: device)
            }.value
        } catch {
            Logger.general.error("Data export file failed: \(error.localizedDescription, privacy: .public)")
            throw Failure.file
        }
    }

    nonisolated private static func write(server: Data, device: DeviceData) throws -> URL {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601

        let root: [String: Any] = [
            "about": "Encore – kópia tvojich údajov (GDPR čl. 15 a 20)",
            "exported_at": ISO8601DateFormatter().string(from: .now),
            "server": try JSONSerialization.jsonObject(with: server),
            "this_iphone": try JSONSerialization.jsonObject(with: encoder.encode(device))
        ]
        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])

        let day = Date.now.formatted(.iso8601.year().month().day())
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Encore-moje-data-\(day).json")
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }
}

// MARK: - Data that lives only on this iPhone
private nonisolated struct DeviceData: Encodable, Sendable {
    struct Settings: Encodable, Sendable {
        let danceRole: String
        let faceIdLogin: Bool
        let trainingNotifications: Bool
        let libraryVideoSpeed: Double
    }

    struct Note: Encodable, Sendable {
        let createdAt: Date
        let text: String
        let dance: String?
        let isPinned: Bool
        let addedToFigureAt: Date?
        let hasVideo: Bool
        let hasPhoto: Bool
        let voiceRecordingSeconds: Double?
    }

    struct WeeklyTraining: Encodable, Sendable {
        let weekday: Int
        let title: String
        let start: String
        let durationMinutes: Int
        let location: String
        let category: String
        let isEnabled: Bool
    }

    struct TrainingDay: Encodable, Sendable {
        let day: Date
        let title: String
        let status: String
        let reflection: String
        let feeling: String?
        /// Every feeling with its dance and note (Ako to bolo).
        let moments: [TrainingMoment]
        let dance: String?
    }

    struct LessonPriorityCopy: Encodable, Sendable {
        let dance: String
        let text: String
        let rank: Int
        let createdAt: Date
        let doneAt: Date?
        let replacedAt: Date?
    }

    struct Competition: Encodable, Sendable {
        let name: String
        let city: String
        let date: Date
        let entryDeadline: Date?
        let categories: [String]
        let intent: String
        let isTarget: Bool
        let ksisCompetitionId: String?
    }

    struct OneOffTraining: Encodable, Sendable {
        let start: Date
        let durationMinutes: Int
        let kind: String
        let title: String
        let location: String
        let category: String
        let goal: String
        let goalOutcome: String?
    }

    struct DanceNotes: Encodable, Sendable {
        let name: String
        let category: String
        let tempo: String
        let notes: String
        let hasVideo: Bool
    }

    struct Figure: Encodable, Sendable {
        let name: String
        let dance: String
        let rhythm: String
        let techniqueNotes: String
        let mastery: Int
        let isOwnFigure: Bool
        let hasVideo: Bool
    }

    struct RoutineCopy: Encodable, Sendable {
        struct Step: Encodable, Sendable {
            let order: Int
            let figure: String
            let rhythm: String
            let notes: String
            let transition: String
            let coachNotes: String?
            let coachNotesBy: String?
            let mastery: Int
            let hasVideo: Bool
        }

        let name: String
        let dance: String
        let category: String
        let createdAt: Date
        let updatedAt: Date
        let figures: [Step]
    }

    let settings: Settings
    let notes: [Note]
    let weeklyTrainings: [WeeklyTraining]
    let trainingDiary: [TrainingDay]
    let lessonPriorities: [LessonPriorityCopy]
    let plannedCompetitions: [Competition]
    let oneOffTrainings: [OneOffTraining]
    let danceNotes: [DanceNotes]
    let figureLibrary: [Figure]
    let routines: [RoutineCopy]
}

private extension DeviceData {
    @MainActor
    init(context: ModelContext) {
        func fetch<T: PersistentModel>(_ type: T.Type) -> [T] { (try? context.fetch(FetchDescriptor<T>())) ?? [] }
        func hasText(_ text: String) -> Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        settings = Settings(
            danceRole: UserProfileStore.shared.danceRole,
            faceIdLogin: AuthManager.shared.isBiometricsEnabled,
            trainingNotifications: NotificationManager.shared.notificationsEnabled,
            libraryVideoSpeed: UserProfileStore.shared.currentPlaybackRate
        )

        notes = fetch(InstantNote.self)
            .sorted { $0.createdAt > $1.createdAt }
            .map {
                Note(
                    createdAt: $0.createdAt,
                    text: $0.text,
                    dance: $0.danceName,
                    isPinned: $0.isPinned,
                    addedToFigureAt: $0.importedAt,
                    hasVideo: $0.videoPath != nil,
                    hasPhoto: $0.imagePath != nil,
                    voiceRecordingSeconds: $0.audioPath == nil ? nil : $0.audioDuration
                )
            }

        weeklyTrainings = fetch(TrainingCadence.self)
            .sorted { ($0.weekday, $0.startMinutes) < ($1.weekday, $1.startMinutes) }
            .map {
                WeeklyTraining(
                    weekday: $0.weekday,
                    title: $0.title,
                    start: String(format: "%02d:%02d", $0.startMinutes / 60, $0.startMinutes % 60),
                    durationMinutes: $0.durationMinutes,
                    location: $0.location,
                    category: $0.danceCategory,
                    isEnabled: $0.isEnabled
                )
            }

        trainingDiary = fetch(TrainingLogEntry.self)
            .sorted { $0.day > $1.day }
            .map {
                TrainingDay(day: $0.day, title: $0.title, status: $0.statusRaw, reflection: $0.reflectionNote, feeling: $0.feelingRaw, moments: $0.moments, dance: $0.danceName)
            }

        lessonPriorities = fetch(LessonPriority.self)
            .sorted { ($0.createdAt, $1.rank) > ($1.createdAt, $0.rank) }
            .map {
                LessonPriorityCopy(dance: $0.danceName, text: $0.text, rank: $0.rank,
                                   createdAt: $0.createdAt, doneAt: $0.doneAt, replacedAt: $0.replacedAt)
            }

        oneOffTrainings = fetch(PlannedSession.self)
            .sorted { $0.start > $1.start }
            .map {
                OneOffTraining(start: $0.start, durationMinutes: $0.durationMinutes, kind: $0.kindRaw, title: $0.title,
                               location: $0.location, category: $0.danceCategory, goal: $0.goal,
                               goalOutcome: $0.goalOutcomeRaw)
            }

        plannedCompetitions = fetch(PlannedCompetition.self)
            .sorted { $0.date < $1.date }
            .map {
                Competition(
                    name: $0.name,
                    city: $0.city,
                    date: $0.date,
                    entryDeadline: $0.entryDeadline,
                    categories: $0.targetCategories,
                    intent: $0.intentRaw,
                    isTarget: $0.isTargetCompetition,
                    ksisCompetitionId: $0.ksisCompetitionId
                )
            }

        danceNotes = fetch(Dance.self)
            .filter { hasText($0.info) || $0.videoPath != nil }
            .map { DanceNotes(name: $0.name, category: $0.category, tempo: $0.tempo, notes: $0.info, hasVideo: $0.videoPath != nil) }

        // Built-in figures are app content; only own figures and figures the user wrote about are theirs.
        figureLibrary = fetch(FigureLibraryItem.self)
            .filter { $0.isCustom || hasText($0.techniqueNotes) || $0.videoPath != nil }
            .map {
                Figure(
                    name: $0.name,
                    dance: $0.danceName,
                    rhythm: $0.rhythm,
                    techniqueNotes: $0.techniqueNotes,
                    mastery: $0.masteryRating,
                    isOwnFigure: $0.isCustom,
                    hasVideo: $0.videoPath != nil
                )
            }

        routines = fetch(Routine.self)
            .sorted { $0.updatedAt > $1.updatedAt }
            .map { routine in
                RoutineCopy(
                    name: routine.name,
                    dance: routine.danceName,
                    category: routine.danceCategory,
                    createdAt: routine.createdAt,
                    updatedAt: routine.updatedAt,
                    figures: routine.canvasNodes
                        .sorted { $0.orderIndex < $1.orderIndex }
                        .map {
                            RoutineCopy.Step(
                                order: $0.orderIndex + 1,
                                figure: $0.figureName,
                                rhythm: $0.rhythm,
                                notes: $0.notes,
                                transition: $0.transitionNotes,
                                coachNotes: $0.coachNotes,
                                coachNotesBy: $0.coachNotesAuthor,
                                mastery: $0.masteryRating,
                                hasVideo: $0.videoPath != nil
                            )
                        }
                )
            }
    }
}
