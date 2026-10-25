import Foundation
import Testing
@testable import Encore

@MainActor
struct DanceRadarTests {
    private func day(_ month: Int, _ day: Int) throws -> Date {
        try #require(PlannerCalendar.calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 18)))
    }

    private func log(_ date: Date, dance: String?, moments: [TrainingMoment] = []) -> TrainingLogEntry {
        let entry = TrainingLogEntry(day: date, cadenceId: nil, title: "Tréning")
        entry.danceName = dance
        entry.moments = moments
        return entry
    }

    private func logs() throws -> [TrainingLogEntry] {
        [
            log(try day(9, 10), dance: "Waltz"),
            log(try day(9, 12), dance: "Waltz"),
            log(try day(9, 14), dance: "Tango"),
            log(try day(10, 20), dance: "Waltz", moments: [TrainingMoment(feelingRaw: "great", danceName: "Tango", note: "")]),
            log(try day(10, 22), dance: nil, moments: [TrainingMoment(feelingRaw: "tired", danceName: "Quickstep", note: "")]),
        ]
    }

    @Test func trainingCountsEachHalfOfTheSeasonAgainstTheBusiestDance() throws {
        let radar = DanceRadar.make(.training, .standard, logs: try logs(), priorities: [], results: [], today: try day(10, 25))
        #expect(radar.dances == ["Waltz", "Tango", "Viennese Waltz", "Slowfoxtrot", "Quickstep"])
        // The dance of a feeling counts too (Tango on 20. 10., Quickstep on 22. 10.).
        #expect(radar.before == [1, 0.5, 0, 0, 0])
        #expect(radar.now == [0.5, 0.5, 0, 0, 0.5])
    }

    @Test func feelingsDrawGoodMomentsHighAndTirednessLow() throws {
        let radar = DanceRadar.make(.feelings, .standard, logs: try logs(), priorities: [], results: [], today: try day(10, 25))
        #expect(radar.before.allSatisfy { $0 == nil })
        #expect(radar.now == [nil, 1, nil, nil, 0])
        #expect(radar.hasData)
    }

    @Test func noRecordsMeansNoShape() throws {
        let radar = DanceRadar.make(.corrections, .latin, logs: [], priorities: [], results: [], today: try day(10, 25))
        #expect(!radar.hasData)
    }
}
