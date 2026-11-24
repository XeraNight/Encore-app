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

    @Test func eachAccountKeepsItsOwnChangesToSend() async throws {
        let (ledger, defaults) = try makeLedger()
        let routine = UUID()
        await ledger.recordDeletion(node: UUID(), in: routine)
        let otherAccount = SyncLedger(defaults: defaults, key: "encore.syncLedger.v1.other")
        #expect(await otherAccount.pendingRoutineIds.isEmpty)
        let sameAccountAgain = SyncLedger(defaults: defaults)
        #expect(await sameAccountAgain.pendingRoutineIds == [routine])
    }

    // MARK: Library figures (like a message that waits for the network)

    @Test func aLibraryFigureWaitsUntilItsUploadReachesItsLatestChange() async throws {
        let (ledger, _) = try makeLedger()
        let figure = UUID()
        let first = await ledger.markFigureChanged(figure)
        let second = await ledger.markFigureChanged(figure)

        await ledger.figureUploaded(figure, version: first)
        #expect(await ledger.isFigurePending(figure))
        await ledger.figureUploaded(figure, version: second)
        #expect(await !ledger.isFigurePending(figure))
    }

    @Test func aFigureDeletedHereDropsItsUploadAndWaitsForTheServer() async throws {
        let (ledger, _) = try makeLedger()
        let figure = UUID()
        await ledger.markFigureChanged(figure)

        await ledger.recordFigureDeletion(figure)
        #expect(await !ledger.isFigurePending(figure))
        #expect(await ledger.deletedFigureIds == [figure])

        await ledger.figureDeletedOnServer(figure)
        #expect(await ledger.deletedFigureIds.isEmpty)
    }

    @Test func aFigureChangedAgainAfterItsDeletionIsNotDeleted() async throws {
        let (ledger, _) = try makeLedger()
        let figure = UUID()
        await ledger.recordFigureDeletion(figure)
        await ledger.markFigureChanged(figure)

        #expect(await ledger.deletedFigureIds.isEmpty)
        #expect(await ledger.pendingFigureIds == [figure])
    }

    @Test func whatWaitsSurvivesARestart() async throws {
        let (ledger, defaults) = try makeLedger()
        let figure = UUID(), gone = UUID()
        await ledger.markFigureChanged(figure)
        await ledger.recordFigureDeletion(gone)

        let reopened = SyncLedger(defaults: defaults)
        #expect(await reopened.pendingFigureIds == [figure])
        #expect(await reopened.deletedFigureIds == [gone])
    }

    /// A ledger written before library figures were kept in it must still open: what waits in it is a dancer's work.
    @Test func aLedgerFromAnEarlierVersionStillOpensWithItsRoutines() async throws {
        let (ledger, defaults) = try makeLedger()
        let routine = UUID()
        await ledger.markChanged(routine)
        let key = "encore.syncLedger.v1"
        let data = try #require(defaults.data(forKey: key))
        var stored = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        stored.removeValue(forKey: "pendingFigures")
        stored.removeValue(forKey: "deletedFigures")
        defaults.set(try JSONSerialization.data(withJSONObject: stored), forKey: key)

        let reopened = SyncLedger(defaults: defaults)
        #expect(await reopened.isPending(routine))
        #expect(await reopened.pendingFigureIds.isEmpty)
    }
}
