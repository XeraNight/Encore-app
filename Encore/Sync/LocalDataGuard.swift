import Foundation
import SwiftData
import OSLog

/// Gives non-view code (the auth layer) access to the app's SwiftData container.
@MainActor
enum AppContainer {
    static var shared: ModelContainer?
}

/// Wipes the open account's data on this iPhone when the account is deleted; switching accounts deletes nothing
/// (AccountStore).
@MainActor
enum LocalDataGuard {
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
        // What went up from this store was the previous account's; an empty store may be filled back from the cloud.
        DeviceBackup.reset()

        let toRemove = files
        Task.detached(priority: .utility) {
            for name in toRemove { MediaStorageManager.removeFile(named: name) }
        }
    }
}
