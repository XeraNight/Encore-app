import Foundation
import Observation

/// One KSIS page as the web view read it.
struct KSISPage {
    let url: URL
    let html: String
}

/// Waits for one KSIS page and never for ever: a page that takes long is called slow, one that takes too long is given
/// up on. While `isPaused` (the dancer is passing KSIS's check) there is no limit.
@MainActor
@Observable
final class KSISPageWaiter {
    enum Failure: LocalizedError {
        case network
        case timedOut

        var errorDescription: String? {
            switch self {
            case .network: return CompetitionManager.ActionError.network.localizedDescription
            case .timedOut: return "KSIS neodpovedá. Skús to o chvíľu znova."
            }
        }
    }

    struct Limits {
        /// How often the wait looks at the clock.
        var tick: TimeInterval = 1
        var slowAfter = KSISWaitPolicy.slowAfter
        var giveUpAfter = KSISWaitPolicy.giveUpAfter
    }

    /// The page being waited for is taking long.
    private(set) var isSlow = false
    /// True from the moment a page is asked for until it, a failure or a cancel comes.
    var isWaiting: Bool { continuation != nil }

    @ObservationIgnored var isPaused: () -> Bool = { false }
    @ObservationIgnored private let limits: Limits
    @ObservationIgnored private var continuation: CheckedContinuation<KSISPage, Error>?

    init(limits: Limits? = nil) {
        self.limits = limits ?? Limits()
    }

    /// Starts the page (`start`) and waits for `deliver`. When it takes too long, `stop` is called and
    /// `Failure.timedOut` is thrown.
    func page(start: () -> Void, stop: @escaping () -> Void) async throws -> KSISPage {
        let watchdog = Task { [weak self, limits] in
            var since = ContinuousClock.now
            while !Task.isCancelled {
                try await Task.sleep(for: .seconds(limits.tick))
                guard let self else { return }
                if self.isPaused() {
                    since = .now
                    self.isSlow = false
                    continue
                }
                let waited = since.duration(to: .now)
                let seconds = Double(waited.components.seconds) + Double(waited.components.attoseconds) / 1e18
                switch KSISWaitPolicy.wait(after: seconds, slowAfter: limits.slowAfter, giveUpAfter: limits.giveUpAfter) {
                case .normal: break
                case .slow: self.isSlow = true
                case .timedOut:
                    stop()
                    self.fail(.timedOut)
                    return
                }
            }
        }
        defer {
            watchdog.cancel()
            isSlow = false
        }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            start()
        }
    }

    func deliver(_ page: KSISPage) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(returning: page)
    }

    func fail(_ failure: Failure) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(throwing: failure)
    }

    /// The window was closed.
    func cancel() {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(throwing: CancellationError())
    }
}
