import Foundation

/// When the app lock closes and when it owes the user an unlock question. Plain values and no iOS calls, so every
/// lifecycle (screen off under the Face ID sheet, a short trip to another app, a slow start) is a unit test.
struct AppLockState: Equatable {
    /// Back in Encore within this time, nothing is asked.
    static let gracePeriod: TimeInterval = 5 * 60

    private(set) var isLocked = false
    /// Set by every new lock and by every trip to the background while locked, cleared when the question is asked.
    /// A question the user cancelled is therefore not asked again until Encore has been away.
    private(set) var isQuestionOwed = false
    private var backgroundedAt: Date?
    private var launchDecided = false

    /// A restored session opens locked when Face ID sign-in is on; a fresh sign-in never does. Decided once per launch:
    /// the slower network check ends later and must not lock a user who has already unlocked.
    mutating func launched(canLock: Bool) {
        guard canLock, !launchDecided else { return }
        launchDecided = true
        lock()
    }

    mutating func didEnterBackground(at now: Date) {
        if backgroundedAt == nil { backgroundedAt = now }
        // The question that was waiting is gone with the screen: it is owed again when Encore is back in front.
        if isLocked { isQuestionOwed = true }
    }

    /// Back in front. Only a real trip to the background can close the lock, and only when it was longer than the grace
    /// period; the Face ID sheet, Control Center and the like pass through "inactive" and are not trips.
    mutating func didBecomeActive(at now: Date, canLock: Bool) {
        guard let since = backgroundedAt else { return }
        backgroundedAt = nil
        if canLock, !isLocked, now.timeIntervalSince(since) > Self.gracePeriod { lock() }
    }

    /// True once per owed question: the caller asks when it gets true.
    mutating func takeQuestion() -> Bool {
        guard isLocked, isQuestionOwed else { return false }
        isQuestionOwed = false
        return true
    }

    /// The owner was verified, or the account was signed out.
    mutating func unlocked() {
        isLocked = false
        isQuestionOwed = false
    }

    private mutating func lock() {
        isLocked = true
        isQuestionOwed = true
    }
}
