import Testing
@testable import Encore

/// The app switcher keeps a picture of Encore. With the Face ID lock on, that picture is the logo.
@MainActor
struct PrivacyCoverTests {
    @Test func theCoverGoesUpWhenEncoreIsNotInFrontAndTheLockIsOn() {
        #expect(PrivacyCoverWindow.shouldCover(isActive: false, lockIsOn: true, isSignedIn: true, isLocked: false))
    }

    @Test func noCoverWhileEncoreIsInFront() {
        #expect(!PrivacyCoverWindow.shouldCover(isActive: true, lockIsOn: true, isSignedIn: true, isLocked: false))
    }

    @Test func noCoverWithoutTheFaceIDLock() {
        #expect(!PrivacyCoverWindow.shouldCover(isActive: false, lockIsOn: false, isSignedIn: true, isLocked: false))
    }

    @Test func noCoverOnTheLoginScreen() {
        #expect(!PrivacyCoverWindow.shouldCover(isActive: false, lockIsOn: true, isSignedIn: false, isLocked: false))
    }

    @Test func noCoverOverTheLockItself() {
        #expect(!PrivacyCoverWindow.shouldCover(isActive: false, lockIsOn: true, isSignedIn: true, isLocked: true))
    }
}
