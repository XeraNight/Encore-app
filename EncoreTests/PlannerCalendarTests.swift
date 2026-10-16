import Testing
import Foundation
@testable import Encore

/// Training times are wall-clock times: 18:00 stays 18:00 on the days the clocks change.
struct PlannerCalendarTests {

    private func day(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        try #require(PlannerCalendar.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)))
    }

    private func hourAndMinute(_ date: Date) -> [Int] {
        let parts = PlannerCalendar.calendar.dateComponents([.hour, .minute], from: date)
        return [parts.hour ?? -1, parts.minute ?? -1]
    }

    @Test(arguments: [(2026, 10, 25), (2027, 3, 28), (2026, 10, 27)])
    func keepsTheClockTimeOnDaylightSavingDays(year: Int, month: Int, dayOfMonth: Int) throws {
        let date = PlannerCalendar.date(on: try day(year, month, dayOfMonth), minutes: 18 * 60)
        #expect(hourAndMinute(date) == [18, 0])
        #expect(PlannerCalendar.calendar.component(.day, from: date) == dayOfMonth)
    }

    @Test func endPastMidnightIsTheNextDay() throws {
        let sunday = try day(2026, 10, 25)
        let end = PlannerCalendar.date(on: sunday, minutes: 22 * 60 + 30 + 120)
        #expect(hourAndMinute(end) == [0, 30])
        #expect(PlannerCalendar.calendar.component(.day, from: end) == 26)
    }

    @Test func notificationCarriesTheTrainingItOpens() throws {
        let day = try day(2026, 10, 20)
        let weekly = PlannerOpenRequest(target: .weekly(cadenceId: UUID(), day: PlannerCalendar.startOfDay(day)))
        let session = PlannerOpenRequest(target: .session(UUID()))

        #expect(PlannerOpenRequest(userInfo: weekly.userInfo) == weekly)
        #expect(PlannerOpenRequest(userInfo: session.userInfo) == session)
        #expect(PlannerOpenRequest(userInfo: ["partner": "x"]) == nil)
    }
}
