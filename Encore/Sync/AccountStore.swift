import Combine
import Foundation
import OSLog
import SwiftData

// MARK: - Each account's own data on this iPhone
/// Every account that signs in on this iPhone keeps its own database (Application Support/Accounts/<id>/). Signing in
/// as someone else closes one and opens the other: nothing is deleted, so switching back finds everything as it was,
/// also what lives only here (voice notes, the formatting of notes, changes not sent yet). The cloud is not used for
/// this; a new iPhone fills an empty database from it (routines, DeviceBackup).
@MainActor
final class AccountStore: ObservableObject {
    static let shared = AccountStore()

    static let schema = Schema([
        Dance.self,
        FigureLibraryItem.self,
        Routine.self,
        CanvasNode.self,
        InstantNote.self,
        VideoMediaEntry.self,
        TrainingCadence.self,
        TrainingLogEntry.self,
        PlannedCompetition.self,
        PlannedSession.self,
        LessonPriority.self,
    ])

    /// The open account's database; views get it through `.modelContainer`.
    @Published private(set) var container: ModelContainer
    /// Whose database is open; nil before anyone signed in on this iPhone.
    @Published private(set) var accountId: UUID?

    /// The account whose data was open last. The key is the one LocalDataGuard kept for the single database before.
    private static let accountKey = "encore.localDataOwnerId"

    private init() {
        let last = UserDefaults.standard.string(forKey: Self.accountKey).flatMap(UUID.init(uuidString:))
        accountId = last
        if let last { SyncLedger.open(account: last) }
        container = Self.makeContainer(for: last, sharedStoreOwner: last)
        AppContainer.shared = container
    }

    /// Opens the account's own data; before anything of a newly signed-in account is shown or synced.
    func open(_ userId: UUID) {
        let previous = UserDefaults.standard.string(forKey: Self.accountKey).flatMap(UUID.init(uuidString:))
        UserDefaults.standard.set(userId.uuidString, forKey: Self.accountKey)
        guard userId != accountId else { return }

        // Reminders and caches outside the database belong to the account before; its data stays in its database.
        Task { await PlannerNotifications.cancelAll() }
        ConnectionManager.shared.reset()
        SlovakCupStore.shared.clear()

        SyncLedger.open(account: userId)
        DeviceBackup.accountChanged()
        accountId = userId
        container = Self.makeContainer(for: userId, sharedStoreOwner: previous)
        AppContainer.shared = container
        Task { await PlannerNotifications.rescheduleFromStore() }
        Logger.auth.notice("[AccountStore] Opened the data of the signed-in account.")
    }

    /// The account was deleted: its database and what kept its place go too, the iPhone is left as before any sign-in.
    func close(deleting userId: UUID) {
        let folder = Self.folder(for: userId)
        accountId = nil
        container = Self.makeContainer(for: nil, sharedStoreOwner: nil)
        AppContainer.shared = container
        UserDefaults.standard.removeObject(forKey: Self.accountKey)
        SyncLedger.forget(account: userId)
        do {
            try FileManager.default.removeItem(at: folder)
        } catch {
            Logger.auth.error("[AccountStore] Deleted account's folder not removed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: Databases
    private static func folder(for account: UUID) -> URL {
        URL.applicationSupportDirectory.appending(path: "Accounts", directoryHint: .isDirectory)
            .appending(path: account.uuidString, directoryHint: .isDirectory)
    }

    /// The account's database, made on first use; nobody signed in yet gets one in memory that is never kept.
    private static func makeContainer(for account: UUID?, sharedStoreOwner: UUID?) -> ModelContainer {
        guard let account else {
            do {
                return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
            } catch {
                fatalError("Could not create the in-memory store: \(error)")
            }
        }
        let folder = folder(for: account)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: "default.store")
        if sharedStoreOwner == nil || sharedStoreOwner == account { adoptSharedStore(at: url) }

        let config = ModelConfiguration(schema: schema, url: url)
        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            Logger.general.error("ModelContainer init failed: \(error.localizedDescription, privacy: .public). Attempting recovery.")
            do {
                container = try DatabaseRecoveryManager.recoverContainer(schema: schema, configuration: config)
            } catch {
                fatalError("Could not initialize ModelContainer after recovery: \(error)")
            }
        }
        // Built-in dances and library figures, off the main thread.
        Task.detached(priority: .background) { await EncoreApp.seedIfNeeded(container: container) }
        return container
    }

    /// One database served every account before this: it belongs to the account that used it last (or, when that
    /// was never known, to the first to sign in) and moves into that account's folder once, with its side files.
    private static func adoptSharedStore(at url: URL) {
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: url.path) else { return }
        let shared = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false).url
        guard fileManager.fileExists(atPath: shared.path) else { return }
        let folder = url.deletingLastPathComponent()
        let sharedFolder = shared.deletingLastPathComponent()
        let name = shared.lastPathComponent
        // The store, its journal, and the folder SwiftData keeps large attributes in (sketches).
        for item in [name, "\(name)-wal", "\(name)-shm", ".\(shared.deletingPathExtension().lastPathComponent)_SUPPORT"] {
            let from = sharedFolder.appending(path: item)
            guard fileManager.fileExists(atPath: from.path) else { continue }
            let to = folder.appending(path: item == name ? url.lastPathComponent : item)
            do {
                try fileManager.moveItem(at: from, to: to)
            } catch {
                Logger.general.error("Moving the shared store failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        // Its fingerprints were the shared store's; the account's own ones start from what the cloud already has.
        UserDefaults.standard.removeObject(forKey: "encore.deviceBackup.v1")
        UserDefaults.standard.removeObject(forKey: "encore.deviceBackup.checkedUser.v2")
        Logger.general.notice("[AccountStore] The shared store moved into the account's folder.")
    }
}
