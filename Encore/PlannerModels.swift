import Foundation
import SwiftData
import SwiftUI

// MARK: - Weekly rhythm
/// One permanent weekly training slot ("Utorok 18:00, vedený tréning Štandard").
@Model
final class TrainingCadence {
    @Attribute(.unique) var id: UUID
    /// ISO weekday: 1 = pondelok … 7 = nedeľa.
    var weekday: Int = 1
    var title: String = ""
    /// Start time as minutes after midnight (18:00 = 1080).
    var startMinutes: Int = 18 * 60
    var durationMinutes: Int = 90
    var location: String = ""
    /// "Standard", "Latin", "Mixed" or "Free".
    var danceCategory: String = "Mixed"
    var isEnabled: Bool = true
    /// Identifier of the recurring Apple Calendar event, if exported.
    var calendarEventId: String? = nil
    /// The dancer wants it in Apple Calendar. Kept while the training is paused (then it has no series),
    /// so switching it back on brings the series back.
    var inAppleCalendar: Bool = false
    /// Past days show this training only from here on (it did not exist before).
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        weekday: Int,
        title: String,
        startMinutes: Int,
        durationMinutes: Int = 90,
        location: String = "",
        danceCategory: String = "Mixed"
    ) {
        self.id = id
        self.weekday = weekday
        self.title = title
        self.startMinutes = startMinutes
        self.durationMinutes = durationMinutes
        self.location = location
        self.danceCategory = danceCategory
    }

    var endMinutes: Int { startMinutes + durationMinutes }
}

// MARK: - One day of training
enum TrainingStatus: String, CaseIterable {
    case planned, going, skipped, attended
}

enum TrainingFeeling: String, CaseIterable, Identifiable {
    case great, tired, breakthrough
    var id: String { rawValue }

    /// SF Symbol for the feeling (no emoji in the interface).
    var symbol: String {
        switch self {
        case .great: return "flame.fill"
        case .tired: return "battery.25percent"
        case .breakthrough: return "scope"
        }
    }

    var title: String {
        switch self {
        case .great: return "Skvelý pocit"
        case .tired: return "Únava"
        case .breakthrough: return "Prelom v technike"
        }
    }

    /// The prompt for the note under the feeling: where it happened.
    var notePrompt: String {
        switch self {
        case .great: return "Čo išlo, napr. Rumba konečne s hudbou"
        case .tired: return "Kde, napr. na konci Jive nohy nestíhali"
        case .breakthrough: return "Čo sa podarilo, napr. otočka v Tangu"
        }
    }
}

/// One feeling of a training with where it happened: "Únava · Jive · nohy nestíhali na konci".
nonisolated struct TrainingMoment: Codable, Equatable, Sendable {
    var feelingRaw: String
    var danceName: String?
    var note: String

    var feeling: TrainingFeeling? { TrainingFeeling(rawValue: feelingRaw) }
}

/// What happened on one concrete day for one cadence (going / skipped / reflection).
@Model
final class TrainingLogEntry {
    @Attribute(.unique) var id: UUID
    /// Start of the day this entry belongs to.
    var day: Date = Date()
    var cadenceId: UUID? = nil
    var title: String = ""
    var statusRaw: String = TrainingStatus.planned.rawValue
    var reflectionNote: String = ""
    var feelingRaw: String? = nil
    /// Every feeling of the training with its dance and note (JSON of `[TrainingMoment]`).
    var momentsData: Data? = nil
    var danceName: String? = nil
    /// The `InstantNote` created from the reflection, so it can be edited later.
    var noteId: UUID? = nil
    var associatedRoutineId: UUID? = nil
    /// The one-off training (`PlannedSession`) this entry belongs to; nil for weekly trainings.
    var sessionId: UUID? = nil
    /// Apple Calendar link of this one day. Weekly training: the single event of a cancelled day that was
    /// restored (a deleted occurrence of a series cannot come back). One-off training: the event it had when
    /// it was cancelled, so undoing the cancel puts it back.
    var calendarEventId: String? = nil

    init(id: UUID = UUID(), day: Date, cadenceId: UUID?, title: String) {
        self.id = id
        self.day = day
        self.cadenceId = cadenceId
        self.title = title
    }

    var status: TrainingStatus {
        get { TrainingStatus(rawValue: statusRaw) ?? .planned }
        set { statusRaw = newValue.rawValue }
    }

    var feeling: TrainingFeeling? {
        get { feelingRaw.flatMap(TrainingFeeling.init(rawValue:)) }
        set { feelingRaw = newValue?.rawValue }
    }

    /// The feelings in order, each with its dance and note. A reflection from before has only `feeling`, which
    /// becomes one moment; `feeling` keeps the first moment for the places that read one feeling.
    var moments: [TrainingMoment] {
        get {
            if let momentsData, let saved = try? JSONDecoder().decode([TrainingMoment].self, from: momentsData), !saved.isEmpty {
                return saved
            }
            return feeling.map { [TrainingMoment(feelingRaw: $0.rawValue, danceName: nil, note: "")] } ?? []
        }
        set {
            momentsData = newValue.isEmpty ? nil : try? JSONEncoder().encode(newValue)
            feelingRaw = newValue.first?.feelingRaw
        }
    }
}

// MARK: - Competitions
enum CompetitionIntent: String, CaseIterable, Identifiable {
    case interested, going, declined
    var id: String { rawValue }

    var title: String {
        switch self {
        case .interested: return "Zvažujem"
        case .going: return "Idem"
        case .declined: return "Neidem"
        }
    }
}

/// A competition the dancer tracks. Entered by hand until a KSIS source is available.
@Model
final class PlannedCompetition {
    @Attribute(.unique) var id: UUID
    /// Reserved for the future KSIS link; nil for manually entered competitions.
    var ksisCompetitionId: String? = nil
    var name: String = ""
    var city: String = ""
    var date: Date = Date()
    var entryDeadline: Date? = nil
    var targetCategories: [String] = []
    var intentRaw: String = CompetitionIntent.interested.rawValue
    /// Main peak of the season.
    var isTargetCompetition: Bool = false
    var calendarEventId: String? = nil

    init(id: UUID = UUID(), name: String, city: String, date: Date) {
        self.id = id
        self.name = name
        self.city = city
        self.date = date
    }

    var intent: CompetitionIntent {
        get { CompetitionIntent(rawValue: intentRaw) ?? .interested }
        set { intentRaw = newValue.rawValue }
    }
}

// MARK: - One-off training
enum SessionKind: String, CaseIterable, Identifiable {
    case solo, lesson
    var id: String { rawValue }

    var title: String {
        switch self {
        case .solo: return "Samotréning"
        case .lesson: return "Lekcia"
        }
    }
}

/// How the goal of a one-off training turned out, answered in the reflection.
enum SessionGoalOutcome: String, CaseIterable, Identifiable {
    case done, partly, other
    var id: String { rawValue }

    var title: String {
        switch self {
        case .done: return "Splnené"
        case .partly: return "Čiastočne"
        case .other: return "Riešili sme iné"
        }
    }
}

/// A single training on one day (samotréning or an extra lesson), unlike the weekly `TrainingCadence`.
/// Going / cancelled and the reflection live in a `TrainingLogEntry` with `sessionId`.
@Model
final class PlannedSession {
    @Attribute(.unique) var id: UUID
    var start: Date = Date()
    var durationMinutes: Int = 60
    var title: String = ""
    var kindRaw: String = SessionKind.solo.rawValue
    var location: String = ""
    /// "Standard", "Latin", "Mixed" or "Free", as `TrainingCadence.danceCategory`.
    var danceCategory: String = "Standard"
    /// What to work on. Empty = no plan yet (it can be added later, also in the reflection).
    var goal: String = ""
    /// Set when the goal is one of the Top 3 priorities.
    var goalPriorityId: UUID? = nil
    var goalOutcomeRaw: String? = nil
    var calendarEventId: String? = nil

    init(id: UUID = UUID(), start: Date, durationMinutes: Int = 60, kind: SessionKind = .solo) {
        self.id = id
        self.start = start
        self.durationMinutes = durationMinutes
        self.kindRaw = kind.rawValue
    }

    var kind: SessionKind {
        get { SessionKind(rawValue: kindRaw) ?? .solo }
        set { kindRaw = newValue.rawValue }
    }

    var goalOutcome: SessionGoalOutcome? {
        get { goalOutcomeRaw.flatMap(SessionGoalOutcome.init(rawValue:)) }
        set { goalOutcomeRaw = newValue?.rawValue }
    }

    var end: Date { start.addingTimeInterval(TimeInterval(durationMinutes * 60)) }
    var displayTitle: String { title.isEmpty ? kind.title : title }
}

// MARK: - Top 3 after a lesson
/// One of the three main corrections a coach gave for one dance. Shown on Home and in Plán until the
/// dancer ticks it off. A new Top 3 for the same dance replaces the open ones of the old.
@Model
final class LessonPriority {
    @Attribute(.unique) var id: UUID
    var danceName: String = ""
    var text: String = ""
    /// 1…3, in the order the coach gave them.
    var rank: Int = 1
    /// Priorities saved together share this moment; that is how one Top 3 is recognised.
    var createdAt: Date = Date()
    var doneAt: Date? = nil
    /// Set when a newer Top 3 for the same dance replaced this one before it was done.
    var replacedAt: Date? = nil
    /// The training it came from, when it was written in the reflection.
    var logEntryId: UUID? = nil

    init(id: UUID = UUID(), danceName: String, text: String, rank: Int, createdAt: Date, logEntryId: UUID? = nil) {
        self.id = id
        self.danceName = danceName
        self.text = text
        self.rank = rank
        self.createdAt = createdAt
        self.logEntryId = logEntryId
    }

    var isOpen: Bool { doneAt == nil && replacedAt == nil }
}

/// One Top 3 as the screens show it: a dance and its priorities in the coach's order.
struct LessonPrioritySet: Identifiable {
    let danceName: String
    let createdAt: Date
    let items: [LessonPriority]

    var id: String { "\(danceName)|\(createdAt.timeIntervalSinceReferenceDate)" }
    var openCount: Int { items.filter(\.isOpen).count }
}

enum LessonPriorities {
    static let maxCount = 3

    /// Top 3s with something still to do, newest first. Ticked items stay visible in their set.
    static func activeSets(_ all: [LessonPriority]) -> [LessonPrioritySet] {
        let live = all.filter { $0.replacedAt == nil }
        let grouped = Dictionary(grouping: live) { "\($0.danceName)|\($0.createdAt.timeIntervalSinceReferenceDate)" }
        return grouped.values
            .compactMap { items -> LessonPrioritySet? in
                guard let first = items.first, items.contains(where: \.isOpen) else { return nil }
                return LessonPrioritySet(danceName: first.danceName, createdAt: first.createdAt,
                                         items: items.sorted { $0.rank < $1.rank })
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// The open texts for a dance, so the editor starts from what is there.
    static func openTexts(for danceName: String, in all: [LessonPriority]) -> [String] {
        all.filter { $0.danceName == danceName && $0.isOpen }
            .sorted { $0.rank < $1.rank }
            .map(\.text)
    }

    /// Saves a new Top 3 for a dance. Empty lines are skipped, at most three are kept, and the open
    /// priorities of that dance are replaced. Returns what was saved (empty when every line was empty).
    @discardableResult
    static func save(_ texts: [String], danceName: String, logEntryId: UUID? = nil,
                     now: Date = Date(), in context: ModelContext) -> [LessonPriority] {
        let cleaned = texts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(maxCount)
        guard !cleaned.isEmpty else { return [] }

        let open = (try? context.fetch(FetchDescriptor<LessonPriority>(
            predicate: #Predicate { $0.danceName == danceName && $0.doneAt == nil && $0.replacedAt == nil }
        ))) ?? []
        for old in open { old.replacedAt = now }

        let saved = cleaned.enumerated().map { index, text in
            LessonPriority(danceName: danceName, text: text, rank: index + 1, createdAt: now, logEntryId: logEntryId)
        }
        saved.forEach(context.insert)
        try? context.save()
        return saved
    }
}

// MARK: - Date helpers (ISO weekdays, Slovak labels)
enum PlannerCalendar {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "sk")
        c.firstWeekday = 2
        return c
    }()

    /// 1 = pondelok … 7 = nedeľa (Calendar itself uses 1 = nedeľa).
    static func isoWeekday(of date: Date) -> Int {
        let w = calendar.component(.weekday, from: date)
        return w == 1 ? 7 : w - 1
    }

    static func startOfDay(_ date: Date) -> Date { calendar.startOfDay(for: date) }

    /// The wall-clock time `minutes` after midnight of `day` (1470 = 0:30 the next day). Set as hour and minute,
    /// not added as a duration: on the days the clocks change, 18:00 has to stay 18:00.
    static func date(on day: Date, minutes: Int) -> Date {
        let minutes = max(0, minutes)
        guard let target = calendar.date(byAdding: .day, value: minutes / 1440, to: startOfDay(day)) else { return day }
        let inDay = minutes % 1440
        return calendar.date(bySettingHour: inDay / 60, minute: inDay % 60, second: 0, of: target) ?? target
    }

    static func weekdayName(iso: Int) -> String {
        let symbols = calendar.standaloneWeekdaySymbols
        let name = symbols[iso % 7]
        return name.prefix(1).uppercased() + name.dropFirst()
    }

    static func timeString(minutes: Int) -> String {
        String(format: "%d:%02d", (minutes / 60) % 24, minutes % 60)
    }

    static func timeRange(of cadence: TrainingCadence) -> String {
        "\(timeString(minutes: cadence.startMinutes)) – \(timeString(minutes: cadence.endMinutes))"
    }

    /// The dance season runs from September to August.
    static func seasonStart(of date: Date = Date()) -> Date {
        let parts = calendar.dateComponents([.year, .month], from: date)
        let year = (parts.year ?? 2000) - ((parts.month ?? 9) >= 9 ? 0 : 1)
        return calendar.date(from: DateComponents(year: year, month: 9, day: 1)) ?? startOfDay(date)
    }

    /// "Dnes", "Zajtra", "O 2 dni", "O 11 dní", "Pred 3 dňami".
    static func daysText(until date: Date, from now: Date = Date()) -> String {
        let days = calendar.dateComponents([.day], from: startOfDay(now), to: startOfDay(date)).day ?? 0
        switch days {
        case 0: return "Dnes"
        case 1: return "Zajtra"
        case 2...4: return "O \(days) dni"
        case 5...: return "O \(days) dní"
        case -1: return "Včera"
        default: return "Pred \(-days) dňami"
        }
    }
}
