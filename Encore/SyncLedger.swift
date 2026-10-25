import CryptoKit
import Foundation
import Network
import OSLog
import SwiftData

// MARK: - What still has to reach the server
/// Kept on the iPhone, so it survives no network, a killed app and a restart:
/// - routines changed here and not yet uploaded (with a change counter, so a change made during an upload is
///   not forgotten when that upload finishes),
/// - figures and routines deleted here,
/// - a fingerprint of every figure as last uploaded or downloaded.
/// Only figures whose fingerprint changed are sent, so an old copy on this iPhone can never overwrite what a
/// partner changed meanwhile, and the server loses a figure only when it was deleted here.
actor SyncLedger {
    static let shared = SyncLedger()

    private struct State: Codable {
        var pending: [UUID: Int] = [:]
        var deletedNodes: [UUID: Set<UUID>] = [:]
        var deletedRoutines: Set<UUID> = []
        var fingerprints: [UUID: String] = [:]
    }

    private var state: State
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "encore.syncLedger.v1") {
        self.defaults = defaults
        self.key = key
        state = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(State.self, from: $0) } ?? State()
    }

    // MARK: Changes made here
    /// A routine changed on this iPhone; returns the change number its upload must reach.
    @discardableResult
    func markChanged(_ routineId: UUID) -> Int {
        let version = (state.pending[routineId] ?? 0) + 1
        state.pending[routineId] = version
        save()
        return version
    }

    func recordDeletion(node nodeId: UUID, in routineId: UUID) {
        state.deletedNodes[routineId, default: []].insert(nodeId)
        state.fingerprints[nodeId] = nil
        markChanged(routineId)
    }

    func recordDeletion(routine routineId: UUID) {
        state.deletedRoutines.insert(routineId)
        state.pending[routineId] = nil
        state.deletedNodes[routineId] = nil
        save()
    }

    // MARK: Reading
    func isPending(_ routineId: UUID) -> Bool {
        state.pending[routineId] != nil || !(state.deletedNodes[routineId] ?? []).isEmpty
    }

    func version(of routineId: UUID) -> Int { state.pending[routineId] ?? 0 }

    var pendingRoutineIds: [UUID] { Array(Set(state.pending.keys).union(state.deletedNodes.keys)) }
    var deletedRoutineIds: [UUID] { Array(state.deletedRoutines) }

    func deletedNodes(in routineId: UUID) -> Set<UUID> { state.deletedNodes[routineId] ?? [] }

    /// The figures that differ from what the server last had.
    func changedRows(_ rows: [DBCanvasNodeRow]) -> [DBCanvasNodeRow] {
        rows.filter { state.fingerprints[$0.id] != Self.fingerprint($0) }
    }

    // MARK: Server answers
    /// An upload went through. The routine stops waiting only if nothing changed since it was taken.
    func uploaded(routine routineId: UUID, version: Int, rows: [DBCanvasNodeRow], deletedNodes: Set<UUID>) {
        for row in rows { state.fingerprints[row.id] = Self.fingerprint(row) }
        if var left = state.deletedNodes[routineId] {
            left.subtract(deletedNodes)
            state.deletedNodes[routineId] = left.isEmpty ? nil : left
        }
        if state.pending[routineId] == version { state.pending[routineId] = nil }
        save()
    }

    /// Figures as the server has them now (a download): they are not changes of ours.
    func downloaded(_ rows: [DBCanvasNodeRow]) {
        for row in rows { state.fingerprints[row.id] = Self.fingerprint(row) }
        save()
    }

    func routineDeletedOnServer(_ routineId: UUID) {
        state.deletedRoutines.remove(routineId)
        save()
    }

    /// The routine no longer exists on this iPhone; there is nothing left to send.
    func forget(_ routineId: UUID) {
        state.pending[routineId] = nil
        state.deletedNodes[routineId] = nil
        save()
    }

    /// Another account on this iPhone: nothing of the previous one may be sent under it.
    func reset() {
        state = State()
        save()
    }

    // MARK: Fingerprint
    /// SHA-256 of the fields this app uploads (the coach's note is written by the coach only).
    nonisolated static func fingerprint(_ row: DBCanvasNodeRow) -> String {
        var row = row
        row.coach_notes = nil
        row.coach_notes_by_name = nil
        row.coach_notes_at = nil
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = (try? encoder.encode(row)) ?? Data()
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(state) { defaults.set(data, forKey: key) }
    }
}

// MARK: - Sending what waits
/// Sends what is still waiting whenever there is a chance: the app comes back, the network returns, or after a
/// failed try (1 s, 5 s, 30 s, then every 5 min while the app is open, each a little random, so thousands of
/// iPhones coming back online do not all retry in the same second).
@MainActor
final class PendingSyncRunner {
    static let shared = PendingSyncRunner()

    private var container: ModelContainer?
    private let monitor = NWPathMonitor()
    private var attempt = 0
    private var retryTask: Task<Void, Never>?
    private var isRunning = false

    private init() {}

    func start(container: ModelContainer) {
        self.container = container
        monitor.pathUpdateHandler = { path in
            guard path.status == .satisfied else { return }
            Task { @MainActor in PendingSyncRunner.shared.run() }
        }
        monitor.start(queue: DispatchQueue(label: "encore.network-path"))
    }

    /// Tries now; a try already running is enough.
    func run() {
        guard let container, !isRunning else { return }
        isRunning = true
        retryTask?.cancel()
        Task {
            let allSent = await SupabaseSyncManager.shared.sendPending(in: container.mainContext)
            // The diary, plan and notes: their own fingerprints, a failure waits for the next run.
            await DeviceBackup.upload(in: container.mainContext)
            isRunning = false
            if allSent { attempt = 0 } else { scheduleRetry() }
        }
    }

    func scheduleRetry() {
        let delays: [Double] = [1, 5, 30, 300]
        let delay = delays[min(attempt, delays.count - 1)] * Double.random(in: 0.8...1.2)
        attempt += 1
        retryTask?.cancel()
        retryTask = Task {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            run()
        }
    }
}
