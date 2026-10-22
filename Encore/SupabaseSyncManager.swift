import Foundation
import SwiftData
import Supabase
import Combine
import OSLog

nonisolated struct DBFigureRow: Codable, Sendable {
    let id: UUID
    let name: String
    let dance_name: String
    let rhythm: String
    let technique_notes: String
    let image_path: String?
    let video_path: String?
    let is_custom: Bool
}

nonisolated struct DBRoutineRow: Codable, Sendable {
    let id: UUID
    let name: String
    let dance_name: String
    let dance_category: String
    let created_at: Date
    let updated_at: Date
    let last_modified_by: String?
}

nonisolated struct DBCanvasNodeRow: Identifiable, Codable, Sendable {
    let id: UUID
    let routine_id: UUID
    let x: Double
    let y: Double
    let figure_name: String
    let rhythm: String
    let notes: String
    let video_path: String?
    let order_index: Int
    let transition_notes: String
    // Written only by the student's coach (the database ignores them from anyone else).
    var coach_notes: String? = nil
    var coach_notes_by_name: String? = nil
    var coach_notes_at: String? = nil
    var bars: Int? = nil

    /// As synthesized, except that `bars` always goes up, empty as null. The upload names its columns after the
    /// keys it sends, so bars cleared on every figure would otherwise keep their old values on the server.
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(routine_id, forKey: .routine_id)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
        try container.encode(figure_name, forKey: .figure_name)
        try container.encode(rhythm, forKey: .rhythm)
        try container.encode(notes, forKey: .notes)
        try container.encodeIfPresent(video_path, forKey: .video_path)
        try container.encode(order_index, forKey: .order_index)
        try container.encode(transition_notes, forKey: .transition_notes)
        try container.encodeIfPresent(coach_notes, forKey: .coach_notes)
        try container.encodeIfPresent(coach_notes_by_name, forKey: .coach_notes_by_name)
        try container.encodeIfPresent(coach_notes_at, forKey: .coach_notes_at)
        try container.encode(bars, forKey: .bars)
    }
}

/// What a routine upload sends, copied on the main actor so the upload can run elsewhere.
nonisolated struct RoutineSnapshot: Sendable {
    let id: UUID
    let name: String
    let danceName: String
    let category: String
    let createdAt: Date
    let updatedAt: Date
    let lastModifiedBy: String?
    let nodes: [DBCanvasNodeRow]

    @MainActor
    init(_ routine: Routine) {
        id = routine.id
        name = routine.name
        danceName = routine.danceName
        category = routine.danceCategory
        createdAt = routine.createdAt
        updatedAt = routine.updatedAt
        lastModifiedBy = routine.lastModifiedBy
        let routineId = routine.id
        nodes = routine.canvasNodes.map { node in
            DBCanvasNodeRow(
                id: node.id,
                routine_id: routineId,
                x: node.x,
                y: node.y,
                figure_name: node.figureName,
                rhythm: node.rhythm,
                notes: node.notes,
                // Only a shared copy goes up; the original works on this iPhone only.
                video_path: SharedVideoStore.serverValue(node.sharedVideoPath),
                order_index: node.orderIndex,
                transition_notes: node.transitionNotes,
                bars: node.bars
            )
        }
    }
}

extension CanvasNode {
    /// A figure that arrived from the server (realtime or refresh).
    convenience init(row: DBCanvasNodeRow) {
        self.init(
            id: row.id, x: row.x, y: row.y,
            figureName: row.figure_name, rhythm: row.rhythm, notes: row.notes,
            orderIndex: row.order_index, transitionNotes: row.transition_notes
        )
        apply(row: row, includingPosition: true)
    }

    /// Takes the shared fields from a server row. Local-only fields (the original video, its rotation,
    /// formatted notes, mastery, the video vault) are never touched, so a sync cannot wipe them.
    func apply(row: DBCanvasNodeRow, includingPosition: Bool) {
        figureName = row.figure_name
        rhythm = row.rhythm
        notes = row.notes
        replaceSharedVideoPath(row.video_path)
        orderIndex = row.order_index
        transitionNotes = row.transition_notes
        bars = row.bars
        applyCoachNotes(from: row)
        if includingPosition {
            x = row.x
            y = row.y
        }
    }

    /// Sets the shared copy; the cached file of a replaced or withdrawn copy is dropped.
    func replaceSharedVideoPath(_ newValue: String?) {
        guard newValue != sharedVideoPath else { return }
        let old = sharedVideoPath
        sharedVideoPath = newValue
        Task.detached(priority: .utility) { SharedVideoStore.evict(old) }
    }

    /// Copies the trainer's note from a server row.
    func applyCoachNotes(from row: DBCanvasNodeRow) {
        let text = row.coach_notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        coachNotes = text.isEmpty ? nil : text
        coachNotesAuthor = text.isEmpty ? nil : row.coach_notes_by_name
        if let at = row.coach_notes_at {
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            coachNotesAt = fractional.date(from: at) ?? ISO8601DateFormatter().date(from: at)
        } else {
            coachNotesAt = nil
        }
    }
}

@globalActor
actor SyncActor {
    static let shared = SyncActor()
}

private actor RoutineSyncDebouncer {
    private var tasks: [UUID: Task<Void, Never>] = [:]
    
    func schedule(routineId: UUID, delay: Duration = .milliseconds(700), operation: @escaping @Sendable () async -> Void) {
        tasks[routineId]?.cancel()
        tasks[routineId] = Task(priority: .background) { [weak self] in
            do {
                try await Task.sleep(for: delay)
                guard !Task.isCancelled else { return }
                await operation()
                await self?.clear(routineId)
            } catch {
                await self?.clear(routineId)
            }
        }
    }
    
    private func clear(_ routineId: UUID) {
        tasks[routineId] = nil
    }
}

final class SupabaseSyncManager: Sendable {
    static let shared = SupabaseSyncManager()

    // Uses the shared SupabaseConfig.client singleton — no separate instantiation.
    nonisolated private var client: SupabaseClient? { SupabaseConfig.client }
    private let routineSyncDebouncer = RoutineSyncDebouncer()

    private init() {}

    nonisolated var isEnabled: Bool { true }

    // MARK: - Database Synchronisation
    
    @SyncActor
    func syncFigure(_ figureId: UUID, name: String, danceName: String, rhythm: String, notes: String, imagePath: String?, videoPath: String?, isCustom: Bool) async {
        guard let client else { return }
        
        let row = DBFigureRow(
            id: figureId,
            name: name,
            dance_name: danceName,
            rhythm: rhythm,
            technique_notes: notes,
            image_path: imagePath,
            video_path: videoPath,
            is_custom: isCustom
        )
        
        do {
            try await client
                .from("figure_library_items")
                .upsert(row)
                .execute()
            Logger.sync.info("Synced figure '\(name, privacy: .public)'")
        } catch {
            Logger.sync.error("Failed to sync figure '\(name, privacy: .public)': \(error.localizedDescription, privacy: .public)")
        }
    }
    
    @SyncActor
    func deleteFigure(_ figureId: UUID) async {
        guard let client else { return }
        
        do {
            try await client
                .from("figure_library_items")
                .delete()
                .eq("id", value: figureId)
                .execute()
            Logger.sync.info("Deleted figure \(figureId.uuidString, privacy: .public)")
        } catch {
            Logger.sync.error("Failed to delete figure: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    /// Uploads what changed in a routine: the routine itself, the figures whose content differs from the last
    /// upload or download, and the figures deleted on this iPhone. Nothing else on the server is touched, so an
    /// old copy cannot overwrite a partner's figures or delete ones it never knew (a routine just downloaded to
    /// a new iPhone has no figures yet). True when the server has it all.
    @SyncActor
    private func push(_ snapshot: RoutineSnapshot, version: Int) async -> Bool {
        guard let client else { return false }
        let changed = await SyncLedger.shared.changedRows(snapshot.nodes)
        let deleted = await SyncLedger.shared.deletedNodes(in: snapshot.id)
        let routineRow = DBRoutineRow(
            id: snapshot.id,
            name: snapshot.name,
            dance_name: snapshot.danceName,
            dance_category: snapshot.category,
            created_at: snapshot.createdAt,
            updated_at: snapshot.updatedAt,
            last_modified_by: snapshot.lastModifiedBy
        )
        do {
            try await client.from("routines").upsert(routineRow).execute()
            if !changed.isEmpty {
                try await client.from("canvas_nodes").upsert(changed, onConflict: "id").execute()
            }
            if !deleted.isEmpty {
                try await client.from("canvas_nodes").delete()
                    .in("id", values: deleted.map { $0.uuidString.lowercased() })
                    .execute()
            }
            await SyncLedger.shared.uploaded(routine: snapshot.id, version: version, rows: changed, deletedNodes: deleted)
            Logger.sync.info("Synced routine '\(snapshot.name, privacy: .public)' (\(changed.count) changed, \(deleted.count) deleted)")
            return true
        } catch {
            Logger.sync.error("Routine upload failed, will retry: \(error.localizedDescription, privacy: .public)")
            await MainActor.run { PendingSyncRunner.shared.scheduleRetry() }
            return false
        }
    }

    @SyncActor
    func fetchRoutine(_ routineId: UUID) async -> (DBRoutineRow, [DBCanvasNodeRow])? {
        guard let client else { return nil }
        
        do {
            let routineRow: DBRoutineRow = try await client
                .from("routines")
                .select()
                .eq("id", value: routineId)
                .single()
                .execute()
                .value
            
            let nodes: [DBCanvasNodeRow] = try await client
                .from("canvas_nodes")
                .select()
                .eq("routine_id", value: routineId)
                .execute()
                .value
            
            return (routineRow, nodes)
        } catch {
            Logger.sync.error("Failed to fetch routine: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
    
    @SyncActor
    /// Deletes the routine on the server; offline it waits in the ledger and goes when the network is back,
    /// so a routine deleted on the plane does not come back with the next refresh.
    @discardableResult
    func deleteRoutine(_ routineId: UUID) async -> Bool {
        await SyncLedger.shared.recordDeletion(routine: routineId)
        guard let client else { return false }
        do {
            try await client
                .from("routines")
                .delete()
                .eq("id", value: routineId)
                .execute()
            await SyncLedger.shared.routineDeletedOnServer(routineId)
            Logger.sync.info("Deleted routine \(routineId.uuidString, privacy: .public)")
            return true
        } catch {
            Logger.sync.error("Routine delete failed, will retry: \(error.localizedDescription, privacy: .public)")
            await MainActor.run { PendingSyncRunner.shared.scheduleRetry() }
            return false
        }
    }
    
    @SyncActor
    func fetchAllRoutines() async -> [DBRoutineRow]? {
        guard let client else { return nil }
        do {
            let rows: [DBRoutineRow] = try await client
                .from("routines")
                .select()
                .order("updated_at", ascending: false)
                .execute()
                .value
            return rows
        } catch {
            Logger.sync.error("Failed to fetch routines from cloud: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
    
    /// Pull-to-refresh: what waits goes up first, then routines created elsewhere are added and ones changed
    /// elsewhere updated (newer wins). A routine still waiting here, or deleted here, is left alone.
    @MainActor
    func pullRoutines(into context: ModelContext) async {
        _ = await sendPending(in: context)
        guard let cloudRoutines = await fetchAllRoutines() else { return }
        let local = (try? context.fetch(FetchDescriptor<Routine>())) ?? []
        let localById = Dictionary(local.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let deletedHere = Set(await SyncLedger.shared.deletedRoutineIds)

        for row in cloudRoutines where !deletedHere.contains(row.id) {
            if let existing = localById[row.id] {
                guard row.updated_at > existing.updatedAt, !(await SyncLedger.shared.isPending(row.id)) else { continue }
                existing.name = row.name
                existing.danceName = row.dance_name
                existing.danceCategory = row.dance_category
                existing.updatedAt = row.updated_at
                existing.lastModifiedBy = row.last_modified_by
            } else {
                context.insert(Routine(
                    id: row.id,
                    name: row.name,
                    danceName: row.dance_name,
                    danceCategory: row.dance_category,
                    createdAt: row.created_at,
                    updatedAt: row.updated_at,
                    lastModifiedBy: row.last_modified_by
                ))
            }
        }
        try? context.save()
    }

    @SyncActor
    func fetchFigures() async -> [DBFigureRow]? {
        guard let client else { return nil }
        do {
            let rows: [DBFigureRow] = try await client
                .from("figure_library_items")
                .select()
                .order("name", ascending: true)
                .execute()
                .value
            return rows
        } catch {
            Logger.sync.error("Failed to fetch figures from cloud: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
    
    /// A routine changed here: it is marked as waiting at once (kept even if the app is closed), and quick
    /// edits are merged into one upload a moment later.
    func syncRoutineOnBackground(_ routine: Routine) {
        guard isEnabled else { return }
        let snapshot = RoutineSnapshot(routine)
        Task(priority: .background) {
            let version = await SyncLedger.shared.markChanged(snapshot.id)
            await self.routineSyncDebouncer.schedule(routineId: snapshot.id) {
                _ = await self.push(snapshot, version: version)
            }
        }
    }

    /// Uploads now and returns when done, for steps that need the routine on the server first
    /// (sharing a figure video checks there that the figure is yours).
    @discardableResult
    func syncRoutineNow(_ routine: Routine) async -> Bool {
        guard isEnabled else { return false }
        let snapshot = RoutineSnapshot(routine)
        let version = await SyncLedger.shared.markChanged(snapshot.id)
        return await push(snapshot, version: version)
    }

    /// Before a routine is downloaded: what waits goes up first, so the download cannot overwrite it.
    /// False when it could not be sent; then the download must wait too.
    @MainActor
    func sendIfPending(_ routine: Routine) async -> Bool {
        guard await SyncLedger.shared.isPending(routine.id) else { return true }
        let snapshot = RoutineSnapshot(routine)
        let version = await SyncLedger.shared.version(of: routine.id)
        return await push(snapshot, version: version)
    }

    /// Everything that waits: routines deleted or changed while offline. True when all of it went through.
    @MainActor
    func sendPending(in context: ModelContext) async -> Bool {
        // Signed out: nothing can go up now; it waits for the next sign-in of the same account.
        guard AuthManager.shared.isAuthenticated else { return true }
        var allSent = true
        for id in await SyncLedger.shared.deletedRoutineIds {
            allSent = await deleteRoutine(id) && allSent
        }
        for id in await SyncLedger.shared.pendingRoutineIds {
            let descriptor = FetchDescriptor<Routine>(predicate: #Predicate { $0.id == id })
            guard let routine = try? context.fetch(descriptor).first else {
                await SyncLedger.shared.forget(id)
                continue
            }
            allSent = await sendIfPending(routine) && allSent
        }
        return allSent
    }
}
