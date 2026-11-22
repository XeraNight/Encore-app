import Testing
import Foundation
@testable import Encore

/// What the update does when KSIS is slow or the network goes.
@MainActor
struct KSISWaitTests {
    @Test func aPageIsSlowAfterTwentySecondsAndGivenUpAfterSeventyFive() {
        #expect(KSISWaitPolicy.wait(after: 0) == .normal)
        #expect(KSISWaitPolicy.wait(after: 19.9) == .normal)
        #expect(KSISWaitPolicy.wait(after: 20) == .slow)
        #expect(KSISWaitPolicy.wait(after: 74.9) == .slow)
        #expect(KSISWaitPolicy.wait(after: 75) == .timedOut)
        #expect(KSISWaitPolicy.wait(after: 600) == .timedOut)
    }

    @Test func theLimitsAreOrderedSoTheSlowNoticeComesBeforeGivingUp() {
        #expect(KSISWaitPolicy.slowAfter < KSISWaitPolicy.giveUpAfter)
        #expect(KSISWaitPolicy.retries >= 1)
    }

    @Test func waitingEndsAtOnceWhenThereIsAlreadyAConnection() async {
        let back = await ConnectionWait.until({ true }, timeout: 5)
        #expect(back)
    }

    @Test func waitingEndsWhenTheConnectionComesBack() async {
        var looks = 0
        let back = await ConnectionWait.until({ looks += 1; return looks >= 3 }, timeout: 5, every: 0.01)
        #expect(back)
        #expect(looks == 3)
    }

    @Test func waitingGivesUpWhenTheConnectionNeverComesBack() async {
        let back = await ConnectionWait.until({ false }, timeout: 0.05, every: 0.01)
        #expect(!back)
    }

    @Test func aCancelledWaitStopsAtOnce() async {
        let wait = Task { await ConnectionWait.until({ false }, timeout: 30, every: 0.01) }
        wait.cancel()
        let back = await wait.value
        #expect(!back)
    }

    // MARK: One page

    private let somePage = KSISPage(url: URL(filePath: "/ksis/page"), html: "<html></html>")
    private let quick = KSISPageWaiter.Limits(tick: 0.01, slowAfter: 0.05, giveUpAfter: 0.2)

    @Test func aPageThatComesIsReturnedAndTheWaitEnds() async throws {
        let waiter = KSISPageWaiter(limits: quick)
        let wait = Task { try await waiter.page(start: {}, stop: {}) }
        try await Task.sleep(for: .milliseconds(20))
        #expect(waiter.isWaiting)
        waiter.deliver(somePage)
        let page = try await wait.value
        #expect(page.html == "<html></html>")
        #expect(!waiter.isWaiting)
    }

    @Test func aPageThatTakesLongIsCalledSlowAndOneThatTakesTooLongIsGivenUpOn() async throws {
        let waiter = KSISPageWaiter(limits: quick)
        var stopped = false
        let wait = Task { try await waiter.page(start: {}, stop: { stopped = true }) }
        try await Task.sleep(for: .milliseconds(100))
        #expect(waiter.isSlow, "slow after 0.05 s")
        await #expect(throws: KSISPageWaiter.Failure.self) { try await wait.value }
        #expect(stopped, "the page that was given up on is stopped")
        #expect(!waiter.isSlow)
        #expect(!waiter.isWaiting)
    }

    @Test func thereIsNoLimitWhileTheDancerPassesKSISCheck() async throws {
        let waiter = KSISPageWaiter(limits: quick)
        var passingTheCheck = true
        waiter.isPaused = { passingTheCheck }
        let wait = Task { try await waiter.page(start: {}, stop: {}) }
        try await Task.sleep(for: .milliseconds(400))
        #expect(waiter.isWaiting, "twice the limit has passed, and it still waits")
        #expect(!waiter.isSlow)
        passingTheCheck = false
        waiter.deliver(somePage)
        _ = try await wait.value
    }

    @Test func aFailureEndsTheWaitAtOnce() async throws {
        let waiter = KSISPageWaiter(limits: quick)
        let wait = Task { try await waiter.page(start: {}, stop: {}) }
        try await Task.sleep(for: .milliseconds(20))
        waiter.fail(.network)
        await #expect(throws: KSISPageWaiter.Failure.self) { try await wait.value }
        #expect(!waiter.isWaiting)
    }

    @Test func aClosedWindowCancelsTheWaitAtOnce() async throws {
        let waiter = KSISPageWaiter(limits: quick)
        let wait = Task { try await waiter.page(start: {}, stop: {}) }
        try await Task.sleep(for: .milliseconds(20))
        waiter.cancel()
        await #expect(throws: CancellationError.self) { try await wait.value }
        #expect(!waiter.isWaiting)
    }

    @Test func aPageThatArrivesAfterTheWaitEndedIsIgnored() {
        let waiter = KSISPageWaiter(limits: quick)
        waiter.deliver(somePage)
        waiter.fail(.timedOut)
        waiter.cancel()
        #expect(!waiter.isWaiting, "nothing waits, so nothing breaks")
    }
}
