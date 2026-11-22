import Foundation

/// How long the KSIS update waits for one page, and how often it tries a page again.
enum KSISWaitPolicy {
    enum Wait: Equatable {
        case normal
        /// Taking long: the panel says so and keeps waiting.
        case slow
        /// Too long: the page is given up on.
        case timedOut
    }

    /// After this many seconds a page counts as slow.
    static let slowAfter: TimeInterval = 20
    /// After this many seconds the page is given up on.
    static let giveUpAfter: TimeInterval = 75
    /// A page lost to the network is tried again this many times before the update stops.
    static let retries = 2
    /// How long a lost connection is waited for before the update stops.
    static let offlineWait: TimeInterval = 120

    /// What the wait for one page has become after `seconds`.
    static func wait(after seconds: TimeInterval, slowAfter: TimeInterval = KSISWaitPolicy.slowAfter,
                     giveUpAfter: TimeInterval = KSISWaitPolicy.giveUpAfter) -> Wait {
        if seconds >= giveUpAfter { return .timedOut }
        return seconds >= slowAfter ? .slow : .normal
    }
}
