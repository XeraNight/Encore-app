import Foundation
import Testing
@testable import Encore

/// iOS keeps only the 64 soonest local notifications; the planner keeps its own below that and never loses a competition.
@MainActor
struct PlannerReminderQueueTests {
    private func hour(_ offset: Int) -> Date { Date(timeIntervalSince1970: 1_800_000_000 + Double(offset) * 3600) }

    @Test func aBusyPlanKeepsEveryCompetitionReminderAndTheSoonestTrainings() {
        var queue = PlannerReminderQueue()
        for index in 0..<100 { queue.add(id: "t\(index)", title: "T", body: "", at: hour(index)) }
        // A competition is far away, further than every training.
        for index in 0..<3 { queue.add(id: "c\(index)", title: "C", body: "", at: hour(1000 + index), isCompetition: true) }
        let kept = queue.kept
        #expect(kept.count == PlannerReminderQueue.limit)
        #expect(kept.filter(\.isCompetition).count == 3)
        let trainings = kept.filter { !$0.isCompetition }.map(\.id)
        #expect(trainings == (0..<(PlannerReminderQueue.limit - 3)).map { "t\($0)" })
    }

    @Test func aQuietPlanKeepsEverythingInOrder() {
        var queue = PlannerReminderQueue()
        queue.add(id: "later", title: "", body: "", at: hour(5))
        queue.add(id: "sooner", title: "", body: "", at: hour(1))
        #expect(queue.kept.map(\.id) == ["sooner", "later"])
        #expect(PlannerReminderQueue().kept.isEmpty)
    }
}
