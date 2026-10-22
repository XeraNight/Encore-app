import Testing
import Foundation
@testable import Encore

/// Offline changes, partner edits and deletions: what goes up and what never may.
struct SyncLedgerTests {
    private func makeLedger() throws -> (SyncLedger, UserDefaults) {
        let defaults = try #require(UserDefaults(suiteName: "SyncLedgerTests-\(UUID().uuidString)"))
        return (SyncLedger(defaults: defaults), defaults)
    }

    private func row(_ id: UUID, routine: UUID, name: String, x: Double = 100) -> DBCanvasNodeRow {
        DBCanvasNodeRow(id: id, routine_id: routine, x: x, y: 200, figure_name: name, rhythm: "1, 2, 3", notes: "",
                        video_path: nil, order_index: 0, transition_notes: "")
    }

    @Test func onlyFiguresChangedHereGoUp() async throws {
        let (ledger, _) = try makeLedger()
        let routine = UUID(), a = UUID(), b = UUID()
        await ledger.downloaded([row(a, routine: routine, name: "Whisk"), row(b, routine: routine, name: "Natural Turn")])

        // The partner's figure A is untouched here, so the old copy of it is not sent over their changes.
        let changed = await ledger.changedRows([row(a, routine: routine, name: "Whisk"), row(b, routine: routine, name: "Natural Turn", x: 300)])
        #expect(changed.map(\.id) == [b])
    }

    @Test func aChangeDuringAnUploadKeepsTheRoutineWaiting() async throws {
        let (ledger, _) = try makeLedger()
        let routine = UUID()
        let first = await ledger.markChanged(routine)
        let second = await ledger.markChanged(routine)

        await ledger.uploaded(routine: routine, version: first, rows: [], deletedNodes: [])
        #expect(await ledger.isPending(routine))
        await ledger.uploaded(routine: routine, version: second, rows: [], deletedNodes: [])
        #expect(await !ledger.isPending(routine))
    }

    @Test func deletionsSurviveARestartUntilTheServerHasThem() async throws {
        let (ledger, defaults) = try makeLedger()
        let routine = UUID(), figure = UUID()
        await ledger.recordDeletion(node: figure, in: routine)

        // The app was closed on the plane: a new start still knows.
        let restarted = SyncLedger(defaults: defaults)
        #expect(await restarted.deletedNodes(in: routine) == [figure])
        #expect(await restarted.pendingRoutineIds == [routine])

        let version = await restarted.version(of: routine)
        await restarted.uploaded(routine: routine, version: version, rows: [], deletedNodes: [figure])
        #expect(await restarted.deletedNodes(in: routine).isEmpty)
        #expect(await !restarted.isPending(routine))
    }

    @Test func aRoutineDeletedOfflineStaysDeletedUntilConfirmed() async throws {
        let (ledger, _) = try makeLedger()
        let routine = UUID()
        await ledger.markChanged(routine)
        await ledger.recordDeletion(routine: routine)
        #expect(await ledger.deletedRoutineIds == [routine])
        #expect(await !ledger.isPending(routine))

        await ledger.routineDeletedOnServer(routine)
        #expect(await ledger.deletedRoutineIds.isEmpty)
    }

    @Test func theCoachsNoteIsNotAChangeOfOurs() async throws {
        let (ledger, _) = try makeLedger()
        let routine = UUID(), figure = UUID()
        var fromServer = row(figure, routine: routine, name: "Whisk")
        fromServer.coach_notes = "Hlava vľavo"
        await ledger.downloaded([fromServer])
        #expect(await ledger.changedRows([row(figure, routine: routine, name: "Whisk")]).isEmpty)
    }

    @Test func anotherAccountStartsWithNothingToSend() async throws {
        let (ledger, _) = try makeLedger()
        let routine = UUID()
        await ledger.recordDeletion(node: UUID(), in: routine)
        await ledger.reset()
        #expect(await ledger.pendingRoutineIds.isEmpty)
    }
}
