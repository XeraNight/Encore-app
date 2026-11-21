import Testing
import Foundation
import LocalAuthentication
@testable import Encore

/// The unlock question: one at a time, a new one dismisses the waiting one, and an answer that was dismissed can never
/// open anything. The system sheet is replaced by a stand-in that the test answers by hand.
@MainActor
struct OwnerCheckTests {
    final class FakeEvaluator: OwnerEvaluating, @unchecked Sendable {
        private var continuation: CheckedContinuation<Bool, Error>?
        private(set) var invalidated = false
        var isAsking: Bool { continuation != nil }

        func evaluate(reason: String) async throws -> Bool {
            try await withCheckedThrowingContinuation { continuation = $0 }
        }
        /// Like the real context: a dismissed question ends with `appCancel`.
        func invalidate() { invalidated = true; finish(.failure(LAError(.appCancel))) }
        func finish(_ result: Result<Bool, Error>) { continuation?.resume(with: result); continuation = nil }
    }

    private final class Sheets {
        var all: [FakeEvaluator] = []
        func make() -> OwnerEvaluating { let sheet = FakeEvaluator(); all.append(sheet); return sheet }
    }

    /// Waits until question number `index` has reached its sheet (the question runs in its own task).
    private func waitUntilAsking(_ sheets: Sheets, _ index: Int) async {
        for _ in 0..<400 where !(sheets.all.count > index && sheets.all[index].isAsking) {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }

    @Test func aYesFromFaceIDIsConfirmed() async {
        let sheets = Sheets()
        let check = OwnerCheck(makeContext: sheets.make)
        let question = Task { await check.verify(reason: "x") }
        await waitUntilAsking(sheets, 0)
        sheets.all[0].finish(.success(true))
        #expect(await question.value == .confirmed)
    }

    @Test func aFalseAnswerIsAFailureNeverAYes() async {
        let sheets = Sheets()
        let check = OwnerCheck(makeContext: sheets.make)
        let question = Task { await check.verify(reason: "x") }
        await waitUntilAsking(sheets, 0)
        sheets.all[0].finish(.success(false))
        #expect(await question.value == .failed(code: 0))
    }

    @Test func aTapWhileASheetWaitsDismissesItAndOnlyTheNewAnswerCounts() async {
        let sheets = Sheets()
        let check = OwnerCheck(makeContext: sheets.make)
        let first = Task { await check.verify(reason: "first") }
        await waitUntilAsking(sheets, 0)
        let second = Task { await check.verify(reason: "second") }
        await waitUntilAsking(sheets, 1)

        #expect(sheets.all.count == 2 && sheets.all[0].invalidated)
        #expect(await first.value == .superseded)
        sheets.all[1].finish(.success(true))
        #expect(await second.value == .confirmed)
    }

    @Test func leavingTheForegroundDismissesTheSheetAndALateYesChangesNothing() async {
        let sheets = Sheets()
        let check = OwnerCheck(makeContext: sheets.make)
        let waiting = Task { await check.verify(reason: "x") }
        await waitUntilAsking(sheets, 0)
        check.cancelPending()
        sheets.all[0].finish(.success(true)) // too late: the question already ended with appCancel
        #expect(await waiting.value == .superseded)
    }

    @Test func theScreenSwitchedOffUnderTheSheetIsACancelAndTheNextQuestionStartsFresh() async {
        // The reported bug: Face ID was waiting, the screen went off, and the lock never asked again.
        let sheets = Sheets()
        let check = OwnerCheck(makeContext: sheets.make)
        let first = Task { await check.verify(reason: "x") }
        await waitUntilAsking(sheets, 0)
        sheets.all[0].finish(.failure(LAError(.systemCancel)))
        #expect(await first.value == .cancelled)

        let again = Task { await check.verify(reason: "x") }
        await waitUntilAsking(sheets, 1)
        #expect(sheets.all.count == 2, "a new question uses a new context, never the dead one")
        sheets.all[1].finish(.success(true))
        #expect(await again.value == .confirmed)
    }

    @Test func errorsAreSortedIntoWhatTheLockDoesNext() {
        func verdict(_ code: LAError.Code) -> OwnerCheck.Verdict { OwnerCheck.verdict(for: LAError(code)) }
        // Nothing to verify with is the only error that passes.
        #expect(verdict(.passcodeNotSet) == .noPasscode)
        // Dismissed by the user or the system: the lock stays, no note.
        #expect(verdict(.userCancel) == .cancelled)
        #expect(verdict(.systemCancel) == .cancelled)
        #expect(verdict(.appCancel) == .cancelled)
        #expect(verdict(.userFallback) == .cancelled)
        // Everything else keeps the lock closed and carries its code for the note and the log.
        #expect(verdict(.authenticationFailed) == .failed(code: -1))
        #expect(verdict(.biometryLockout) == .failed(code: -8))
        #expect(verdict(.notInteractive) == .failed(code: -1004))
        #expect(OwnerCheck.verdict(for: NSError(domain: "x", code: -1000)) == .failed(code: -1000))
    }
}
