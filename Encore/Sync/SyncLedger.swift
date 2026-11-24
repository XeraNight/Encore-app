import CryptoKit
import Foundation
import Network
import OSLog
import SwiftData
import Synchronization

// MARK: - What still has to reach the server
/// Kept on the iPhone, so it survives no network, a killed app and a restart:
/// - routines changed here and not yet uploaded (with a change counter, so a change made during an upload is
///   not forgotten when that upload finishes),
/// - figures and routines deleted here,
/// - library figures added or changed here and not yet uploaded, and library figures deleted here,
/// - a fingerprint of every figure as last uploaded or downloaded.
/// Only figures whose fingerprint changed are sent, so an old copy on this iPhone can never overwrite what a
/// partner changed meanwhile, and the server loses a figure only when it was deleted here.
/// Each account on this iPhone has its own (AccountStore): what one left unsent waits for it and never goes up
/// under another.
actor SyncLedger {
    /// The open account's ledger.
    static var shared: SyncLedger { current.withLock { $0 } }
    private static let current = Mutex(SyncLedger())
    static let legacyKey = "encore.syncLedger.v1"

    private static func key(for account: UUID) -> String { "\(legacyKey).\(account.uuidString)" }

    /// When an account's data opens. The one ledger kept before accounts had their own belongs to the account that
    /// opens first after the update, the one that used it.
    static func open(account: UUID) {
        let defaults = UserDefaults.standard
        let key = key(for: account)
        if defaults.data(forKey: key) == nil, let legacy = defaults.data(forKey: legacyKey) {
            defaults.set(legacy, forKey: key)
        }
        defaults.removeObject(forKey: legacyKey)
        current.withLock { $0 = SyncLedger(key: key) }
    }

    /// The account was deleted: its ledger goes with it.
    static func forget(account: UUID) {
        UserDefaults.standard.removeObject(forKey: key(for: account))
    }

    private struct State: Codable {
        var pending: [UUID: Int] = [:]
        var deletedNodes: [UUID: Set<UUID>] = [:]
        var deletedRoutines: Set<UUID> = []
        var fingerprints: [UUID: String] = [:]
        /// Library figures changed here, with a change counter like the routines', and library figures deleted here.
        var pendingFigures: [UUID: Int] = [:]
        var deletedFigures: Set<UUID> = []

        init() {}

        /// A ledger written by an earlier version has no library figures; it must still open, or what waits in it is lost.
        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            pending = try values.decodeIfPresent([UUID: Int].self, forKey: .pending) ?? [:]
            deletedNodes = try values.decodeIfPresent([UUID: Set<UUID>].self, forKey: .deletedNodes) ?? [:]
            deletedRoutines = try values.decodeIfPresent(Set<UUID>.self, forKey: .deletedRoutines) ?? []
            fingerprints = try values.decodeIfPresent([UUID: String].self, forKey: .fingerprints) ?? [:]
            pendingFigures = try values.decodeIfPresent([UUID: Int].self, forKey: .pendingFigures) ?? [:]
            deletedFigures = try values.decodeIfPresent(Set<UUID>.self, forKey: .deletedFigures) ?? []
        }
    }

    private var state: State
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = legacyKey) {
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

    // MARK: Library figures
    /// A library figure was added or changed on this iPhone; returns the change number its upload must reach.
    @discardableResult
    func markFigureChanged(_ id: UUID) -> Int {
        let version = (state.pendingFigures[id] ?? 0) + 1
        state.pendingFigures[id] = version
        state.deletedFigures.remove(id)
        save()
        return version
    }

    /// A library figure was deleted here: what waited to go up is dropped and the deletion waits instead.
    func recordFigureDeletion(_ id: UUID) {
        state.pendingFigures[id] = nil
        state.deletedFigures.insert(id)
        save()
    }

    /// An upload went through. The figure stops waiting only if nothing changed since it was taken.
    func figureUploaded(_ id: UUID, version: Int) {
        if state.pendingFigures[id] == version { state.pendingFigures[id] = nil }
        save()
    }

    func figureDeletedOnServer(_ id: UUID) {
        state.deletedFigures.remove(id)
        save()
    }

    /// The figure no longer exists on this iPhone; there is nothing left to send.
    func forgetFigure(_ id: UUID) {
        state.pendingFigures[id] = nil
        save()
    }

    func isFigurePending(_ id: UUID) -> Bool { state.pendingFigures[id] != nil }
    func figureVersion(of id: UUID) -> Int { state.pendingFigures[id] ?? 0 }
    var pendingFigureIds: Set<UUID> { Set(state.pendingFigures.keys) }
    var deletedFigureIds: Set<UUID> { state.deletedFigures }

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

    private let monitor = NWPathMonitor()
    private var attempt = 0
    private var retryTask: Task<Void, Never>?
    private var isRunning = false
    /// Something changed while a try was running: the try that follows has to see it.
    private var isRunAgainRequested = false

    private init() {}

    /// Watches the network. Each run works on the open account's data (AccountStore).
    func start() {
        monitor.pathUpdateHandler = { path in
            guard path.status == .satisfied else { return }
            Task { @MainActor in PendingSyncRunner.shared.run() }
        }
        monitor.start(queue: DispatchQueue(label: "encore.network-path"))
    }

    /// Tries now. A try already running is not started twice, but one more follows it, because what was just changed may
    /// have come after that try looked.
    func run() {
        guard let container = AppContainer.shared else { return }
        guard !isRunning else {
            isRunAgainRequested = true
            return
        }
        isRunning = true
        retryTask?.cancel()
        Task {
            let routinesSent = await SupabaseSyncManager.shared.sendPending(in: container.mainContext)
            // The diary, plan and notes: their own fingerprints.
            let diarySent = await DeviceBackup.upload(in: container.mainContext)
            // Voice recordings: their copies in the cloud, so a new iPhone gets them back.
            let voiceSent = await VoiceBackup.shared.sync(in: container.mainContext)
            isRunning = false
            await SyncStatus.shared.refresh()
            if isRunAgainRequested {
                isRunAgainRequested = false
                run()
                return
            }
            // Anything that did not go up waits for a retry with the same growing pauses.
            if routinesSent && diarySent && voiceSent { attempt = 0 } else { scheduleRetry() }
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
