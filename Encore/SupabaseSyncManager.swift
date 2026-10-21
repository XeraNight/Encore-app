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

// MARK: - Sync Status (S2-4 — Observable by UI for offline/failure feedback)

enum SyncStatus: Equatable, Sendable {
    case idle
    case syncing
    case success
    case failed(String)   // associated error description

    var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }
}

final class SupabaseSyncManager: Sendable {
    static let shared = SupabaseSyncManager()

    // Uses the shared SupabaseConfig.client singleton — no separate instantiation.
    nonisolated private var client: SupabaseClient? { SupabaseConfig.client }
    private let routineSyncDebouncer = RoutineSyncDebouncer()

    private init() {}

    nonisolated var isEnabled: Bool { true }

    // MARK: - Sync Status (published for UI consumption)
    // Updated on @MainActor so SwiftUI views can observe without wrapping.
    @MainActor static var syncStatus: SyncStatus = .idle
    
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
    
    @SyncActor
    func syncRoutine(_ routineId: UUID, name: String, danceName: String, category: String, createdAt: Date, updatedAt: Date, lastModifiedBy: String?, nodes: [DBCanvasNodeRow]) async {
        guard let client else { return }
        
        let routineRow = DBRoutineRow(
            id: routineId,
            name: name,
            dance_name: danceName,
            dance_category: category,
            created_at: createdAt,
            updated_at: updatedAt,
            last_modified_by: lastModifiedBy
        )
        
        do {
            // 1. Upsert Routine (create or update)
            try await client
                .from("routines")
                .upsert(routineRow)
                .execute()
            
            if nodes.isEmpty {
                // 2a. No nodes – delete everything for this routine
                try await client
                    .from("canvas_nodes")
                    .delete()
                    .eq("routine_id", value: routineId)
                    .execute()
            } else {
                // 2b. Upsert all nodes – UPDATE existing, INSERT new ones
                // onConflict: "id" = ak node už existuje, updatuje; inak vytvorí
                try await client
                    .from("canvas_nodes")
                    .upsert(nodes, onConflict: "id")
                    .execute()
                
                // 3. Vymaž osirotené nodes (existujú v DB ale nie lokálne)
                // Toto nespustí false DELETE eventy pre existujúce figury
                let ids = nodes.map { $0.id.uuidString.lowercased() }
                let idsString = ids.joined(separator: ",")
                try await client
                    .from("canvas_nodes")
                    .delete()
                    .eq("routine_id", value: routineId)
                    .not("id", operator: .in, value: "(\(idsString))")
                    .execute()
            }
            
            Logger.sync.info("Synced routine '\(name, privacy: .public)' (\(nodes.count) nodes)")
            await MainActor.run { SupabaseSyncManager.syncStatus = .success }
        } catch {
            Logger.sync.error("Failed to sync routine '\(name, privacy: .public)': \(error.localizedDescription, privacy: .public)")
            await MainActor.run { SupabaseSyncManager.syncStatus = .failed(error.localizedDescription) }
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
    func deleteRoutine(_ routineId: UUID) async {
        guard let client else { return }
        
        do {
            try await client
                .from("routines")
                .delete()
                .eq("id", value: routineId)
                .execute()
            Logger.sync.info("Deleted routine \(routineId.uuidString, privacy: .public)")
        } catch {
            Logger.sync.error("Failed to delete routine: \(error.localizedDescription, privacy: .public)")
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
    
    /// Pull-to-refresh: adds routines created elsewhere and updates ones changed elsewhere (newer wins).
    @MainActor
    func pullRoutines(into context: ModelContext) async {
        guard let cloudRoutines = await fetchAllRoutines() else { return }
        let local = (try? context.fetch(FetchDescriptor<Routine>())) ?? []
        let localById = Dictionary(local.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        for row in cloudRoutines {
            if let existing = localById[row.id] {
                guard row.updated_at > existing.updatedAt else { continue }
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
    
    /// Waits a moment and merges quick edits into one upload.
    func syncRoutineOnBackground(_ routine: Routine) {
        guard isEnabled else { return }
        let snapshot = RoutineSnapshot(routine)
        Task(priority: .background) {
            await self.routineSyncDebouncer.schedule(routineId: snapshot.id) {
                await self.push(snapshot)
            }
        }
    }

    func syncRoutineImmediatelyOnBackground(_ routine: Routine) {
        guard isEnabled else { return }
        let snapshot = RoutineSnapshot(routine)
        Task(priority: .background) { await self.push(snapshot) }
    }

    /// Uploads now and returns when done, for steps that need the routine on the server first
    /// (sharing a figure video checks there that the figure is yours).
    func syncRoutineNow(_ routine: Routine) async {
        guard isEnabled else { return }
        await push(RoutineSnapshot(routine))
    }

    private func push(_ snapshot: RoutineSnapshot) async {
        await syncRoutine(
            snapshot.id,
            name: snapshot.name,
            danceName: snapshot.danceName,
            category: snapshot.category,
            createdAt: snapshot.createdAt,
            updatedAt: snapshot.updatedAt,
            lastModifiedBy: snapshot.lastModifiedBy,
            nodes: snapshot.nodes
        )
    }
}
