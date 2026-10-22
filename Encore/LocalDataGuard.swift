import Foundation
import SwiftData
import OSLog

/// Gives non-view code (the auth layer) access to the app's SwiftData container.
@MainActor
enum AppContainer {
    static var shared: ModelContainer?
}

/// Keeps one account's local data (routines, notes, videos, plans) away from the next account
/// that signs in on the same iPhone.
///
/// The local database is not tied to a user id, so without this a second person signing in would
/// see the first person's routines and could upload them to their own cloud account. We remember
/// which account the local data belongs to and clear it when a different one signs in. Signing
/// out and back in as the same account keeps everything (local videos are not in the cloud).
@MainActor
enum LocalDataGuard {
    private static let ownerKey = "encore.localDataOwnerId"

    /// Call whenever a (different) user becomes the active user, before any data is shown or synced.
    static func claim(for userId: UUID) {
        let defaults = UserDefaults.standard
        if let stored = defaults.string(forKey: ownerKey), stored != userId.uuidString {
            Logger.auth.notice("[LocalDataGuard] Local data belongs to another account, clearing it.")
            wipeAll()
            // Nothing the previous account left unsent may go up under this one.
            Task { await SyncLedger.shared.reset() }
            ConnectionManager.shared.reset()
        }
        // No stored owner (data from before this feature): adopt it for the current user.
        defaults.set(userId.uuidString, forKey: ownerKey)
    }

    static func forgetOwner() {
        UserDefaults.standard.removeObject(forKey: ownerKey)
    }

    /// Removes user-created data. Built-in dances and library figures are kept.
    static func wipeAll() {
        guard let container = AppContainer.shared else {
            Logger.auth.warning("[LocalDataGuard] No container available, nothing wiped.")
            return
        }
        let context = ModelContext(container)
        var files = Set<String>()
        func collect(_ path: String?) {
            if let path, !path.isEmpty { files.insert(path) }
        }

        do {
            for node in try context.fetch(FetchDescriptor<CanvasNode>()) {
                collect(node.videoPath)
                collect(node.activeTargetVideoPath)
                context.delete(node)
            }
            for routine in try context.fetch(FetchDescriptor<Routine>()) {
                collect(routine.videoPath)
                collect(routine.activeTargetVideoPath)
                context.delete(routine)
            }
            for entry in try context.fetch(FetchDescriptor<VideoMediaEntry>()) {
                collect(entry.filePath)
                context.delete(entry)
            }
            for note in try context.fetch(FetchDescriptor<InstantNote>()) {
                collect(note.videoPath)
                collect(note.imagePath)
                collect(note.audioPath)
                context.delete(note)
            }
            let customFigures = FetchDescriptor<FigureLibraryItem>(predicate: #Predicate { $0.isCustom })
            for figure in try context.fetch(customFigures) {
                collect(figure.imagePath)
                collect(figure.videoPath)
                context.delete(figure)
            }
            for item in try context.fetch(FetchDescriptor<TrainingCadence>()) { context.delete(item) }
            for item in try context.fetch(FetchDescriptor<TrainingLogEntry>()) { context.delete(item) }
            for item in try context.fetch(FetchDescriptor<PlannedCompetition>()) { context.delete(item) }
            for item in try context.fetch(FetchDescriptor<PlannedSession>()) { context.delete(item) }
            for item in try context.fetch(FetchDescriptor<LessonPriority>()) { context.delete(item) }
            try context.save()
        } catch {
            Logger.auth.error("[LocalDataGuard] Wipe failed: \(error.localizedDescription, privacy: .public)")
        }

        // Reminders of the previous account's trainings and competitions must not keep coming.
        Task { await PlannerNotifications.cancelAll() }

        let toRemove = files
        Task.detached(priority: .utility) {
            for name in toRemove { MediaStorageManager.removeFile(named: name) }
        }
    }
}
