import Foundation
import LocalAuthentication

/// Anything that can ask the owner of the iPhone (Face ID, Touch ID or the passcode). `LAContext` is the real one.
protocol OwnerEvaluating: AnyObject {
    func evaluate(reason: String) async throws -> Bool
    func invalidate()
}

extension LAContext: OwnerEvaluating {
    func evaluate(reason: String) async throws -> Bool {
        try await evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
    }
}

/// The one place Encore asks "is this the owner of the iPhone?". One question at a time: a new question dismisses the
/// waiting one (so a tap is never swallowed by an old, stuck one) and the answer of a dismissed question is ignored.
@MainActor
final class OwnerCheck {
    enum Verdict: Equatable {
        /// Face ID or the passcode said yes.
        case confirmed
        /// The iPhone has no passcode: nothing to verify with, and the only case that passes without a check.
        case noPasscode
        /// The user, or the system (the screen was switched off), dismissed the question.
        case cancelled
        /// Anything else, with the system's error code for the short note and the log.
        case failed(code: Int)
        /// A newer question or `cancelPending()` dismissed this one: its answer must change nothing.
        case superseded
    }

    private let makeContext: () -> OwnerEvaluating
    private var current: (id: Int, context: OwnerEvaluating)?
    private var counter = 0

    init(makeContext: @escaping () -> OwnerEvaluating = { LAContext() }) {
        self.makeContext = makeContext
    }

    func verify(reason: String) async -> Verdict {
        cancelPending()
        counter += 1
        let id = counter
        let context = makeContext()
        current = (id, context)
        let verdict: Verdict
        do {
            verdict = try await context.evaluate(reason: reason) ? .confirmed : .failed(code: 0)
        } catch {
            verdict = Self.verdict(for: error)
        }
        guard current?.id == id else { return .superseded }
        current = nil
        return verdict
    }

    /// Dismisses the waiting question, if any. Used when Encore leaves the foreground: the sheet is gone with it.
    func cancelPending() {
        current?.context.invalidate()
        current = nil
    }

    nonisolated static func verdict(for error: Error) -> Verdict {
        guard let laError = error as? LAError else { return .failed(code: (error as NSError).code) }
        switch laError.code {
        case .passcodeNotSet: return .noPasscode
        case .userCancel, .systemCancel, .appCancel, .userFallback: return .cancelled
        default: return .failed(code: laError.errorCode)
        }
    }
}
