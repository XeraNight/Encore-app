import Foundation
import EventKit
import OSLog
import UserNotifications

// MARK: - Local notifications for the planner
/// Plans notifications for the next two weeks (not a repeating weekly trigger) so that a day the
/// user skipped can be left out. Everything is local, so it works without a connection.
@MainActor
enum PlannerNotifications {
    private static let prefix = "plan."
    private static let horizonDays = 14

    static func reschedule(
        cadences: [TrainingCadence],
        logs: [TrainingLogEntry],
        competitions: [PlannedCompetition]
    ) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let old = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: old)

        guard NotificationManager.shared.isAuthorized, NotificationManager.shared.notificationsEnabled else { return }

        let cal = PlannerCalendar.calendar
        let now = Date()
        let today = PlannerCalendar.startOfDay(now)
        let skipped = Set(logs.filter { $0.status == .skipped }.map { key(cadence: $0.cadenceId, day: $0.day) })

        for offset in 0..<horizonDays {
            guard let day = cal.date(byAdding: .day, value: offset, to: today) else { continue }
            let weekday = PlannerCalendar.isoWeekday(of: day)

            for cadence in cadences where cadence.isEnabled && cadence.weekday == weekday {
                if skipped.contains(key(cadence: cadence.id, day: day)) { continue }
                // Ask for the reflection 5 minutes after the session ends.
                let fire = PlannerCalendar.date(on: day, minutes: cadence.endMinutes + 5)
                guard fire > now else { continue }
                add(
                    id: "\(prefix)debrief.\(cadence.id.uuidString).\(offset)",
                    title: "Tréning skončil",
                    body: "Čo kľúčové ste dnes vylepšili? Zapíš to za 20 sekúnd.",
                    at: fire,
                    center: center
                )
            }
        }

        for comp in competitions where comp.intent != .declined {
            if let deadline = comp.entryDeadline {
                for daysBefore in [3, 1] {
                    if let base = cal.date(byAdding: .day, value: -daysBefore, to: PlannerCalendar.startOfDay(deadline)) {
                        let fire = PlannerCalendar.date(on: base, minutes: 9 * 60)
                        if fire > now {
                            add(
                                id: "\(prefix)deadline.\(comp.id.uuidString).\(daysBefore)",
                                title: "Uzávierka prihlášok",
                                body: "\(comp.name): \(PlannerCalendar.daysText(until: deadline, from: fire).lowercased()) je uzávierka.",
                                at: fire,
                                center: center
                            )
                        }
                    }
                }
            }
            if comp.intent == .going,
               let eve = cal.date(byAdding: .day, value: -1, to: PlannerCalendar.startOfDay(comp.date)) {
                let fire = PlannerCalendar.date(on: eve, minutes: 18 * 60)
                if fire > now {
                    add(
                        id: "\(prefix)eve.\(comp.id.uuidString)",
                        title: "Zajtra súťaž",
                        body: "\(comp.name)\(comp.city.isEmpty ? "" : ", \(comp.city)"). Skontroluj tašku a štartové číslo.",
                        at: fire,
                        center: center
                    )
                }
            }
        }
    }

    private static func key(cadence: UUID?, day: Date) -> String {
        "\(cadence?.uuidString ?? "-")|\(Int(PlannerCalendar.startOfDay(day).timeIntervalSince1970))"
    }

    private static func add(id: String, title: String, body: String, at date: Date, center: UNUserNotificationCenter) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let comps = PlannerCalendar.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}

// MARK: - Apple Calendar export (EventKit)
/// Creates events in the system calendar. Uses write-only access, so the app never reads the
/// user's calendars.
@MainActor
final class CalendarExporter {
    static let shared = CalendarExporter()
    private let store = EKEventStore()
    private init() {}

    /// Every event the app creates carries this line, so it can find and remove only its own events later.
    private static let trainingMarker = "Encore · týždenný tréning"
    private static let competitionMarker = "Encore · súťaž"

    private func requestAccess() async -> Bool {
        (try? await store.requestWriteOnlyAccessToEvents()) ?? false
    }

    /// Removing needs full access. The app only touches events it created itself (by stored id or by the
    /// marker line above) and never reads or changes any other event.
    private func requestFullAccess() async -> Bool {
        (try? await store.requestFullAccessToEvents()) ?? false
    }

    /// Returns the event identifier, or nil when access was denied or saving failed.
    func export(competition: PlannedCompetition) async -> String? {
        guard await requestAccess() else { return nil }
        let event = EKEvent(eventStore: store)
        event.calendar = store.defaultCalendarForNewEvents
        event.title = "🏆 \(competition.name)"
        event.location = competition.city.isEmpty ? nil : competition.city
        event.isAllDay = true
        event.startDate = PlannerCalendar.startOfDay(competition.date)
        event.endDate = event.startDate
        var notes = [Self.competitionMarker]
        if !competition.targetCategories.isEmpty {
            notes.append("Kategórie: " + competition.targetCategories.joined(separator: ", "))
        }
        event.notes = notes.joined(separator: "\n")
        event.addAlarm(EKAlarm(relativeOffset: -24 * 60 * 60))
        return save(event)
    }

    /// Creates a weekly recurring event starting with the next occurrence.
    func export(cadence: TrainingCadence) async -> String? {
        guard await requestAccess() else { return nil }
        let cal = PlannerCalendar.calendar
        let today = PlannerCalendar.startOfDay(Date())
        var first = today
        for offset in 0..<8 {
            guard let day = cal.date(byAdding: .day, value: offset, to: today) else { continue }
            if PlannerCalendar.isoWeekday(of: day) == cadence.weekday,
               PlannerCalendar.date(on: day, minutes: cadence.startMinutes) > Date() {
                first = day
                break
            }
        }

        let event = EKEvent(eventStore: store)
        event.calendar = store.defaultCalendarForNewEvents
        event.title = cadence.title.isEmpty ? "Tréning" : cadence.title
        event.location = cadence.location.isEmpty ? nil : cadence.location
        event.notes = Self.trainingMarker
        event.startDate = PlannerCalendar.date(on: first, minutes: cadence.startMinutes)
        event.endDate = PlannerCalendar.date(on: first, minutes: cadence.endMinutes)
        // EKWeekday: 1 = nedeľa … 7 = sobota.
        let ekDay = EKWeekday(rawValue: cadence.weekday == 7 ? 1 : cadence.weekday + 1) ?? .monday
        event.addRecurrenceRule(EKRecurrenceRule(
            recurrenceWith: .weekly,
            interval: 1,
            daysOfTheWeek: [EKRecurrenceDayOfWeek(ekDay)],
            daysOfTheMonth: nil,
            monthsOfTheYear: nil,
            weeksOfTheYear: nil,
            daysOfTheYear: nil,
            setPositions: nil,
            end: nil
        ))
        event.addAlarm(EKAlarm(relativeOffset: -30 * 60))
        return save(event)
    }

    enum RemovalResult {
        case removed(Int)
        case accessDenied
    }

    /// Removes the weekly series of the given trainings from Apple Calendar (all future occurrences).
    /// Already deleted events count as done. Past occurrences stay in the calendar history.
    func removeTrainings(eventIds: [String], includeUnknownSeries: Bool = false) async -> RemovalResult {
        guard await requestFullAccess() else { return .accessDenied }
        var removed = Set<String>()

        for id in eventIds {
            guard let event = store.event(withIdentifier: id) else { continue }
            if remove(event) { removed.insert(event.calendarItemIdentifier) }
        }

        // Safety net for series whose id was lost (reinstall, other device): the marker line finds them.
        guard includeUnknownSeries else { return .removed(removed.count) }
        let cal = PlannerCalendar.calendar
        let start = cal.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let end = cal.date(byAdding: .year, value: 2, to: Date()) ?? Date()
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        for event in store.events(matching: predicate)
        where event.notes?.contains(Self.trainingMarker) == true
            && !removed.contains(event.calendarItemIdentifier) {
            if remove(event) { removed.insert(event.calendarItemIdentifier) }
        }
        return .removed(removed.count)
    }

    /// Removes one event the app created (a competition or a one-off training). An event that is already
    /// gone counts as removed; false means access was denied or removing failed.
    func removeEvent(id: String) async -> Bool {
        guard await requestFullAccess() else { return false }
        guard let event = store.event(withIdentifier: id) else { return true }
        return remove(event)
    }

    private func remove(_ event: EKEvent) -> Bool {
        do {
            try store.remove(event, span: .futureEvents)
            return true
        } catch {
            Logger.general.warning("Calendar removal failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func save(_ event: EKEvent) -> String? {
        do {
            try store.save(event, span: .futureEvents)
            return event.eventIdentifier
        } catch {
            Logger.general.warning("Calendar export failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
