import Foundation
import Observation

/// What the screens show about sending. The ledger is the record (it survives a killed app and a restart); this only
/// mirrors which library figures still wait, so a row can show a clock like a message that has not gone yet. Refreshed
/// after every try of the pending sender.
@MainActor
@Observable
final class SyncStatus {
    static let shared = SyncStatus()

    private(set) var waitingFigureIds: Set<UUID> = []

    private init() {}

    func refresh() async {
        let ids = await SyncLedger.shared.pendingFigureIds
        if ids != waitingFigureIds { waitingFigureIds = ids }
    }
}
