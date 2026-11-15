import Foundation
import OSLog
import SwiftData

extension ModelContext {
    /// Saves, and writes a failure (a full disk, a model that cannot be stored) to the log instead of dropping it.
    nonisolated func saveOrLog(_ place: String = #function) {
        do {
            try save()
        } catch {
            Logger.sync.error("Save failed in \(place, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}

extension PersistentModel {
    /// True once the model was deleted (or never stored). After an `await` the model in hand may be gone, and
    /// touching a deleted model stops the app: check this before changing it.
    nonisolated var isGone: Bool { modelContext == nil || isDeleted }
}
