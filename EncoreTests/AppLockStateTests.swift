import Testing
import Foundation
@testable import Encore

/// The lock's lifecycle without a phone: when it closes, and when it owes the user an unlock question.
struct AppLockStateTests {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)
    private func later(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    /// Takes the owed question, if there is one, and says whether there was.
    private func asked(_ state: inout AppLockState) -> Bool { state.takeQuestion() }

    private func openedAfterLaunch() -> AppLockState {
        var state = AppLockState()
        state.launched(canLock: true)
        _ = state.takeQuestion()
        state.unlocked()
        return state
    }

    // MARK: Launch

    @Test func aRestoredSessionOpensLockedAndOwesOneQuestion() {
        var state = AppLockState()
        state.launched(canLock: true)
        #expect(state.isLocked)
        let owed1 = asked(&state)
        #expect(owed1)
        let owed2 = asked(&state)
        #expect(!owed2, "one owed question is asked once")
    }

    @Test func aFreshSignInNeverLocks() {
        var state = AppLockState()
        state.launched(canLock: false)
        let owed3 = asked(&state)
        #expect(!state.isLocked && !owed3)
    }

    @Test func theSlowNetworkCheckDoesNotLockAUserWhoAlreadyUnlocked() {
        var state = openedAfterLaunch()
        state.launched(canLock: true) // the check that ends after the network answered
        #expect(!state.isLocked)
    }

    @Test func aLockThatWasNeverInFrontAsksWhenEncoreFirstIs() {
        // Launched in the background (a widget, a notification): nobody could be asked, so the question is still owed.
        var state = AppLockState()
        state.launched(canLock: true)
        state.didBecomeActive(at: t0, canLock: true)
        let owed4 = asked(&state)
        #expect(state.isLocked && owed4)
    }

    // MARK: Trips to the background

    @Test func aShortTripKeepsEncoreOpen() {
        var state = openedAfterLaunch()
        state.didEnterBackground(at: t0)
        state.didBecomeActive(at: later(AppLockState.gracePeriod), canLock: true) // exactly the grace period is still fine
        #expect(!state.isLocked)
    }

    @Test func aLongTripLocksAndOwesAQuestion() {
        var state = openedAfterLaunch()
        state.didEnterBackground(at: t0)
        state.didBecomeActive(at: later(AppLockState.gracePeriod + 1), canLock: true)
        let owed5 = asked(&state)
        #expect(state.isLocked && owed5)
    }

    @Test func theTripIsCountedFromTheFirstBackgroundEvent() {
        var state = openedAfterLaunch()
        state.didEnterBackground(at: t0)
        state.didEnterBackground(at: later(240))
        state.didBecomeActive(at: later(AppLockState.gracePeriod + 1), canLock: true)
        #expect(state.isLocked)
    }

    @Test func theFaceIDSheetOrControlCenterIsNotATrip() {
        // "inactive" then "active" with no background in between: nothing closes the lock, however often it happens.
        var state = openedAfterLaunch()
        for step in 1...3 { state.didBecomeActive(at: later(Double(step) * 1000), canLock: true) }
        #expect(!state.isLocked)
    }

    @Test func withFaceIDSignInOffNothingEverLocks() {
        var state = AppLockState()
        state.didEnterBackground(at: t0)
        state.didBecomeActive(at: later(3600), canLock: false)
        #expect(!state.isLocked)
    }

    // MARK: The question

    @Test func aCancelledQuestionIsNotAskedAgainUntilEncoreHasBeenAway() {
        var state = AppLockState()
        state.launched(canLock: true)
        let owed6 = asked(&state)
        #expect(owed6)  // asked, the user cancels
        state.didBecomeActive(at: t0, canLock: true) // the sheet closing passes through "active"
        let owed7 = asked(&state)
        #expect(!owed7, "no loop of questions the user keeps cancelling")

        state.didEnterBackground(at: t0)
        state.didBecomeActive(at: later(5), canLock: true)
        let owed8 = asked(&state)
        #expect(owed8, "after a trip it is owed again")
    }

    @Test func theScreenSwitchedOffWhileTheSheetWaitsAsksAgainOnWaking() {
        // The reported bug: Face ID was showing, the screen went off, and nothing asked again.
        var state = AppLockState()
        state.launched(canLock: true)
        let owed9 = asked(&state)
        #expect(owed9)  // the sheet is up
        state.didEnterBackground(at: t0)             // screen off: the sheet is gone
        state.didBecomeActive(at: later(20), canLock: true)
        let owed10 = asked(&state)
        #expect(state.isLocked && owed10)
    }

    @Test func aLockedAppStaysLockedAcrossATrip() {
        var state = AppLockState()
        state.launched(canLock: true)
        state.didEnterBackground(at: t0)
        state.didBecomeActive(at: later(3600), canLock: true)
        #expect(state.isLocked)
    }

    @Test func unlockingOrSigningOutForgetsTheOwedQuestion() {
        var state = AppLockState()
        state.launched(canLock: true)
        state.unlocked()
        let owed11 = asked(&state)
        #expect(!state.isLocked && !owed11)
    }
}
