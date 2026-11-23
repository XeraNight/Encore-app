import Auth
import Foundation
import OSLog
import SwiftData

// MARK: - Voice notes in the cloud
/// A voice note is a file on the iPhone: Fotky keeps videos, not sound. So every recording also goes to Encore's
/// private storage (Cloudflare R2 through `media-share`), and a recording missing on this iPhone (a new iPhone, a
/// reinstall) comes back from there when its note is shown or played. Only the owner can reach it: the server builds
/// its place from the signed-in account. When the note is deleted, its copy goes too.
///
/// What must hold, whatever the network or the dancer does:
/// - A recording the cloud will never take (too big, a name it does not know) is left out and the others go on. A bad
///   moment (no network, a busy server, the plan's space full) stops the run, and what is left waits for the next one.
/// - A recording is asked for again after a bad moment; only the cloud saying "no copy" is remembered, and only until the
///   app is closed.
/// - Every step checks that the account whose data is open is still the one signed in, so a recording never goes up
///   under another account.
/// - A copy is removed only after this account's backup of the notes was brought back to this iPhone (DeviceBackup): a
///   database that was rebuilt empty must not look like every note was deleted.
@MainActor
final class VoiceBackup {
    static let shared = VoiceBackup()

    /// What the backup asks of the cloud. The live one is `media-share` and the private storage; tests bring their own.
    struct Cloud {
        /// What went wrong, as far as the backup has to tell: the recording has no copy, the cloud will never take it,
        /// or it is only a bad moment.
        enum Failure: Error { case notFound, refused, later }

        var upload: (_ name: String, _ file: URL, _ size: Int) async throws -> Void
        var download: (_ name: String, _ file: URL) async throws -> Void
        var remove: (_ name: String) async throws -> Void
    }

    private let cloud: Cloud
    /// The account the backup may act for: the one signed in, when its data is the one open on this iPhone.
    private let currentAccount: @MainActor () -> UUID?
    private let folder: URL

    private var isSyncing = false
    private var downloads: [String: Task<Bool?, Never>] = [:]
    /// Recordings the storage has no copy of (made before the copies began): asked once per run, not on every look.
    private var withoutCopy: Set<String> = []
    /// Recordings the storage refused for good: left out until the app is opened again.
    private var refused: Set<String> = []

    init(cloud: Cloud = .live, currentAccount: @escaping @MainActor () -> UUID? = VoiceBackup.signedInOpenAccount,
         folder: URL = MediaStorageManager.documentsDirectory) {
        self.cloud = cloud
        self.currentAccount = currentAccount
        self.folder = folder
    }

    /// The recordings in the cloud for an account, as this iPhone knows them: sent from here or brought back.
    static func savedKey(for account: UUID) -> String { "encore.voiceBackup.saved." + account.uuidString }

    static func signedInOpenAccount() -> UUID? {
        guard AuthManager.shared.isAuthenticated, let signedIn = AuthManager.shared.currentUser?.id,
              AccountStore.shared.accountId == signedIn else { return nil }
        return signedIn
    }

    // MARK: Up
    /// Sends the recordings not in the cloud yet and removes the copies of deleted notes. Runs with the other
    /// changes waiting to go up (PendingSyncRunner); what fails is tried on the next run.
    func sync(in context: ModelContext) async {
        guard !isSyncing, let account = currentAccount() else { return }
        isSyncing = true
        defer { isSyncing = false }
        let key = Self.savedKey(for: account)
        let (referenced, isComplete) = Self.recordings(in: context)
        var saved = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
        for name in referenced.subtracting(saved).subtracting(refused).sorted() where exists(name) {
            guard currentAccount() == account else { return }
            do {
                try await upload(name)
                saved.insert(name)
                UserDefaults.standard.set(Array(saved), forKey: key)
            } catch Cloud.Failure.refused {
                refused.insert(name)
            } catch {
                return
            }
        }
        // A copy goes only when every note was read (a note that could not be read may still hold its recording) and
        // the notes were brought back from their backup (an empty database may only be one that was just rebuilt).
        guard isComplete, hasRestored(account) else { return }
        for name in saved.subtracting(referenced).sorted() {
            guard currentAccount() == account else { return }
            do {
                try await cloud.remove(name)
            } catch Cloud.Failure.refused {
                // A name the cloud never took has no copy to remove.
            } catch {
                return
            }
            saved.remove(name)
            UserDefaults.standard.set(Array(saved), forKey: key)
        }
    }

    /// Every recording the open account's data points to: Denník notes and the voice notes inside figures' notes.
    /// Not complete when the data or a figure's note could not be read.
    static func recordings(in context: ModelContext) -> (names: Set<String>, isComplete: Bool) {
        let withNotes = FetchDescriptor<CanvasNode>(predicate: #Predicate { $0.notesRichData != nil })
        guard let notes = try? context.fetch(FetchDescriptor<InstantNote>()), let nodes = try? context.fetch(withNotes) else {
            return ([], false)
        }
        var names = Set(notes.compactMap(\.audioPath))
        var isComplete = true
        for node in nodes {
            guard let data = node.notesRichData, let text = RichNote.decode(data) else {
                isComplete = false
                continue
            }
            names.formUnion(RichNote.voiceNotes(in: text).map(\.fileName))
        }
        return (names, isComplete)
    }

    private func exists(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: folder.appending(path: name).path)
    }

    /// An empty file is not a recording: nothing to keep, nothing to ask the cloud.
    private func upload(_ name: String) async throws {
        let file = folder.appending(path: name)
        guard let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize, size > 0 else { return }
        try await cloud.upload(name, file, size)
    }

    /// This account's backup of the notes was already brought back to this iPhone (DeviceBackup).
    private func hasRestored(_ account: UUID) -> Bool {
        UserDefaults.standard.string(forKey: DeviceBackup.checkedKey(for: account)) == account.uuidString
    }

    // MARK: Down
    /// Brings a recording back from its copy when it is not on this iPhone; false without a copy or a network.
    func download(_ name: String) async -> Bool {
        let file = folder.appending(path: name)
        if FileManager.default.fileExists(atPath: file.path) { return true }
        if let running = downloads[name] { return await running.value == true }
        guard !withoutCopy.contains(name), let account = currentAccount() else { return false }
        let cloud = cloud
        // nil when the cloud says there is no copy; false for a bad moment, so the next look asks again.
        let task = Task { () -> Bool? in
            do {
                try await cloud.download(name, file)
                return true
            } catch Cloud.Failure.notFound {
                return nil
            } catch {
                return false
            }
        }
        downloads[name] = task
        let result = await task.value
        downloads[name] = nil
        if result == nil { withoutCopy.insert(name) }
        guard result == true else { return false }
        let key = Self.savedKey(for: account)
        var saved = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
        saved.insert(name)
        UserDefaults.standard.set(Array(saved), forKey: key)
        return true
    }
}

// MARK: - The live cloud
private struct VoiceRequest: Encodable {
    let action: String
    let name: String
    var sizeBytes: Int? = nil
}

private struct VoiceUploadTicket: Decodable { let uploadUrl: URL }
private struct VoiceDownloadLink: Decodable { let downloadUrl: URL }
private struct VoiceRemoval: Decodable { let ok: Bool }

extension VoiceBackup.Cloud {
    /// `media-share`: the function decides who may and hands out short-lived links; the bytes go straight to the storage.
    static let live = VoiceBackup.Cloud(
        upload: { name, file, size in
            let ticket: VoiceUploadTicket = try await ask(VoiceRequest(action: "voice_upload", name: name, sizeBytes: size))
            var request = URLRequest(url: ticket.uploadUrl)
            request.httpMethod = "PUT"
            request.setValue("audio/mp4", forHTTPHeaderField: "Content-Type")
            do {
                let (_, response) = try await URLSession.shared.upload(for: request, fromFile: file)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw Failure.later }
            } catch let failure as Failure {
                throw failure
            } catch {
                Logger.audio.notice("Voice note not backed up yet: \(error.localizedDescription, privacy: .public)")
                throw Failure.later
            }
        },
        download: { name, file in
            let link: VoiceDownloadLink = try await ask(VoiceRequest(action: "voice_download", name: name))
            do {
                let (temporary, response) = try await URLSession.shared.download(from: link.downloadUrl)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw Failure.later }
                try? FileManager.default.removeItem(at: file)
                try FileManager.default.moveItem(at: temporary, to: file)
            } catch let failure as Failure {
                throw failure
            } catch {
                Logger.audio.notice("Voice note not brought back: \(error.localizedDescription, privacy: .public)")
                throw Failure.later
            }
        },
        remove: { name in
            let _: VoiceRemoval = try await ask(VoiceRequest(action: "voice_remove", name: name))
        }
    )

    /// One call to `media-share`, its errors told as the backup needs them: no copy, refused for good, or a bad moment
    /// (no network, not signed in, too many calls, the plan's space full, a server error).
    private static func ask<Reply: Decodable>(_ request: VoiceRequest) async throws -> Reply {
        do {
            return try await EdgeFunctionClient.call("media-share", request)
        } catch EdgeFunctionClient.Failure.server(let code, _) {
            switch code {
            case "not_found": throw Failure.notFound
            case "invalid_input", "too_large": throw Failure.refused
            default: throw Failure.later
            }
        } catch {
            throw Failure.later
        }
    }
}
