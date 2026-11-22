import Testing
import Foundation
@testable import Encore

/// How far an update from KSIS has got, as the panel tells it.
struct KSISReadingProgressTests {

    @Test func aStepHasNoFractionUntilItsPagesAreKnown() {
        var progress = KSISReadingProgress(stage: .marks)
        #expect(progress.fraction == nil)
        progress.done = 3
        progress.total = 12
        #expect(progress.fraction == 0.25)
        progress.done = 20
        #expect(progress.fraction == 1, "never more than full")
        progress.total = 0
        #expect(progress.fraction == nil)
    }

    @Test func theTimeLeftNeedsTwoPagesToShowAPace() {
        let start = Date(timeIntervalSince1970: 1_000)
        var progress = KSISReadingProgress(stage: .marks, done: 1, total: 12, stageStartedAt: start)
        #expect(progress.secondsLeft(now: start.addingTimeInterval(5)) == nil)
        progress.done = 2
        // Two pages in ten seconds: five seconds a page, ten pages to go.
        #expect(progress.secondsLeft(now: start.addingTimeInterval(10)) == 50)
        progress.done = 12
        #expect(progress.secondsLeft(now: start.addingTimeInterval(60)) == nil, "nothing is left")
    }

    @Test func theWaitIsRoundedBecauseACountdownWouldPromiseTooMuch() {
        #expect(KSISReadingProgress.waitText(4) == "pár sekúnd")
        #expect(KSISReadingProgress.waitText(22) == "asi 20 s")
        #expect(KSISReadingProgress.waitText(45) == "asi 45 s")
        #expect(KSISReadingProgress.waitText(50) == "asi 1 min")
        #expect(KSISReadingProgress.waitText(130) == "asi 2 min")
    }

    @Test func everyKindOfUpdateHasItsOwnSteps() {
        #expect(KSISReadingProgress.stages(for: .everything) == [.couples, .history, .marks, .cup, .calendar])
        #expect(KSISReadingProgress.stages(for: .calendar) == [.calendar])
        #expect(KSISReadingProgress.stages(for: .marks) == [.marks])
    }
}
