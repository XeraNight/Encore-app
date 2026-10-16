import Testing
import Foundation
import SwiftData
@testable import Encore

/// Vývoj: done and cancelled trainings per month of the season, hours per week with samotréning apart.
@MainActor
struct TrainingTrendsTests {
    private let cal = PlannerCalendar.calendar

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0) throws -> Date {
        try #require(cal.date(from: DateComponents(year: y, month: m, day: d, hour: h)))
    }

    @Test func countsMonthsAndWeeksSinceTheTrainingWasAdded() throws {
        let schema = Schema([TrainingCadence.self, TrainingLogEntry.self, PlannedSession.self, LessonPriority.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = container.mainContext

        // Tuesdays 6:00–7:00 from 1 Sep 2026; 8 Sep cancelled; a samotréning on Wed 14 Oct.
        let weekly = TrainingCadence(weekday: 2, title: "Vedený", startMinutes: 6 * 60, durationMinutes: 60)
        weekly.createdAt = try date(2026, 9, 1)
        context.insert(weekly)
        let cancelled = TrainingLogEntry(day: try date(2026, 9, 8), cadenceId: weekly.id, title: "Vedený")
        cancelled.status = .skipped
        context.insert(cancelled)
        let solo = PlannedSession(start: try date(2026, 10, 14, 7), durationMinutes: 60, kind: .solo)
        context.insert(solo)

        let trends = TrainingTrends(cadences: [weekly], sessions: [solo], logs: [cancelled], priorities: [],
                                    now: try date(2026, 10, 16, 12))

        #expect(trends.months.map(\.done) == [4, 3])
        #expect(trends.months.map(\.cancelled) == [1, 0])
        #expect(trends.weeks.count == TrainingTrends.weekCount)
        let lastWeek = try #require(trends.weeks.last)
        #expect(lastWeek.otherMinutes == 60)
        #expect(lastWeek.soloMinutes == 60)
        #expect(trends.weeks.filter { $0.otherMinutes > 0 }.count == 6)
    }
}
