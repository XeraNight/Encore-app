import Testing
import Foundation
import SwiftData
@testable import Encore

/// Which trainings a day shows: a forgotten training from the last days stays to be filled in, older days
/// show only what was recorded, and a reflection stays on its day when its training is deleted or moved.
@MainActor
struct TrainingOccurrenceTests {
    private let cal = PlannerCalendar.calendar

    private func makeContext() throws -> (ModelContainer, ModelContext) {
        let schema = Schema([TrainingCadence.self, TrainingLogEntry.self, PlannedSession.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        return (container, container.mainContext)
    }

    private func daysAgo(_ days: Int) throws -> Date {
        try #require(cal.date(byAdding: .day, value: -days, to: PlannerCalendar.startOfDay(Date())))
    }

    private func cadence(on day: Date, createdDaysAgo: Int, in context: ModelContext) throws -> TrainingCadence {
        let cadence = TrainingCadence(weekday: PlannerCalendar.isoWeekday(of: day), title: "Vedený tréning", startMinutes: 6 * 60)
        cadence.createdAt = try daysAgo(createdDaysAgo)
        context.insert(cadence)
        return cadence
    }

    private func entry(_ status: TrainingStatus, cadenceId: UUID?, day: Date, in context: ModelContext) -> TrainingLogEntry {
        let entry = TrainingLogEntry(day: day, cadenceId: cadenceId, title: "Vedený tréning")
        entry.status = status
        context.insert(entry)
        return entry
    }

    @Test func forgottenTrainingFromYesterdayStillShows() throws {
        let (container, context) = try makeContext()
        _ = container
        let yesterday = try daysAgo(1)
        let weekly = try cadence(on: yesterday, createdDaysAgo: 30, in: context)

        let list = TrainingOccurrence.on(yesterday, cadences: [weekly], sessions: [], logs: [])
        #expect(list.map(\.title) == ["Vedený tréning"])
    }

    @Test func olderDaysShowOnlyWhatWasRecorded() throws {
        let (container, context) = try makeContext()
        _ = container
        let old = try daysAgo(14)
        let weekly = try cadence(on: old, createdDaysAgo: 60, in: context)
        #expect(TrainingOccurrence.on(old, cadences: [weekly], sessions: [], logs: []).isEmpty)

        let attended = entry(.attended, cadenceId: weekly.id, day: old, in: context)
        #expect(TrainingOccurrence.on(old, cadences: [weekly], sessions: [], logs: [attended]).count == 1)
    }

    @Test func trainingAddedTodayDoesNotAppearInThePast() throws {
        let (container, context) = try makeContext()
        _ = container
        let yesterday = try daysAgo(1)
        let weekly = try cadence(on: yesterday, createdDaysAgo: 0, in: context)
        #expect(TrainingOccurrence.on(yesterday, cadences: [weekly], sessions: [], logs: []).isEmpty)
    }

    @Test func reflectionStaysWhenItsTrainingIsDeleted() throws {
        let (container, context) = try makeContext()
        _ = container
        let day = try daysAgo(20)
        let attended = entry(.attended, cadenceId: UUID(), day: day, in: context)
        let skipped = entry(.skipped, cadenceId: UUID(), day: day, in: context)

        let list = TrainingOccurrence.on(day, cadences: [], sessions: [], logs: [attended, skipped])
        #expect(list.map(\.id) == ["r\(attended.id.uuidString)"])
        #expect(list.first?.hasTime == false)
    }

    @Test func reflectionStaysOnItsDayWhenTheTrainingMovesToAnotherWeekday() throws {
        let (container, context) = try makeContext()
        _ = container
        let day = try daysAgo(3)
        let weekly = try cadence(on: day, createdDaysAgo: 30, in: context)
        let attended = entry(.attended, cadenceId: weekly.id, day: day, in: context)
        weekly.weekday = weekly.weekday % 7 + 1

        let list = TrainingOccurrence.on(day, cadences: [weekly], sessions: [], logs: [attended])
        #expect(list.map(\.id) == ["r\(attended.id.uuidString)"])
    }
}
