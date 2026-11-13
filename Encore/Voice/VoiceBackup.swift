import Foundation
import OSLog
import SwiftData

// MARK: - Voice notes in the cloud
/// A voice note is a file on the iPhone: Fotky keeps videos, not sound. So every recording also goes to Encore's
/// private storage (Cloudflare R2 through `media-share`), and a recording missing on this iPhone (a new iPhone, a
/// reinstall) comes back from there when its note is shown or played. Only the owner can reach it: the server builds
/// its place from the signed-in account. When the note is deleted, its copy goes too.
@MainActor
final class VoiceBackup {
    static let shared = VoiceBackup()

    private var isSyncing = false
    private var downloads: [String: Task<Bool?, Never>] = [:]
    /// Recordings the storage has no copy of (made before the copies began): asked once per run, not on every look.
    private var withoutCopy: Set<String> = []

    private init() {}

    /// The recordings in the cloud for the open account, as this iPhone knows them: sent from here or brought back.
    private var savedKey: String { "encore.voiceBackup.saved." + (AccountStore.shared.accountId?.uuidString ?? "none") }

    // MARK: Up
    /// Sends the recordings not in the cloud yet and removes the copies of deleted notes. Runs with the other
    /// changes waiting to go up (PendingSyncRunner); what fails is tried on the next run.
    func sync(in context: ModelContext) async {
        guard !isSyncing, AuthManager.shared.isAuthenticated else { return }
        isSyncing = true
        defer { isSyncing = false }
        let key = savedKey
        let (referenced, isComplete) = Self.recordings(in: context)
        var saved = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
        for name in referenced.subtracting(saved).sorted() where MediaStorageManager.fileExists(name) {
            guard await upload(name) else { return }
            saved.insert(name)
            UserDefaults.standard.set(Array(saved), forKey: key)
        }
        // A copy goes only when every note was read: a note that could not be read may still hold its recording.
        guard isComplete else { return }
        for name in saved.subtracting(referenced).sorted() {
            guard await remove(name) else { return }
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

    // MARK: Down
    /// Brings a recording back from its copy when it is not on this iPhone; false without a copy or a network.
    func download(_ name: String) async -> Bool {
        if MediaStorageManager.fileExists(name) { return true }
        if let running = downloads[name] { return await running.value == true }
        guard !withoutCopy.contains(name) else { return false }
        let key = savedKey
        // nil when the server says there is no copy.
        let task = Task { () -> Bool? in
            do {
                let link: Link = try await EdgeFunctionClient.call("media-share", Request(action: "voice_download", name: name))
                let (temporary, response) = try await URLSession.shared.download(from: link.downloadUrl)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { return false }
                let file = MediaStorageManager.url(for: name)
                try? FileManager.default.removeItem(at: file)
                try FileManager.default.moveItem(at: temporary, to: file)
                return true
            } catch EdgeFunctionClient.Failure.server {
                return nil
            } catch {
                Logger.audio.notice("Voice note not brought back: \(error.localizedDescription, privacy: .public)")
                return false
            }
        }
        downloads[name] = task
        let result = await task.value
        downloads[name] = nil
        if result == nil { withoutCopy.insert(name) }
        let isBack = result == true
        if isBack {
            var saved = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
            saved.insert(name)
            UserDefaults.standard.set(Array(saved), forKey: key)
        }
        return isBack
    }

    // MARK: Server
    private func upload(_ name: String) async -> Bool {
        let file = MediaStorageManager.url(for: name)
        guard let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize, size > 0 else { return true }
        do {
            let ticket: Ticket = try await EdgeFunctionClient.call(
                "media-share", Request(action: "voice_upload", name: name, sizeBytes: size)
            )
            var request = URLRequest(url: ticket.uploadUrl)
            request.httpMethod = "PUT"
            request.setValue("audio/mp4", forHTTPHeaderField: "Content-Type")
            let (_, response) = try await URLSession.shared.upload(for: request, fromFile: file)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            Logger.audio.notice("Voice note not backed up yet: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func remove(_ name: String) async -> Bool {
        do {
            let _: Removal = try await EdgeFunctionClient.call("media-share", Request(action: "voice_remove", name: name))
            return true
        } catch {
            Logger.audio.notice("Voice note copy not removed yet: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private struct Request: Encodable {
        let action: String
        let name: String
        var sizeBytes: Int? = nil
    }

    private struct Ticket: Decodable { let uploadUrl: URL }
    private struct Link: Decodable { let downloadUrl: URL }
    private struct Removal: Decodable { let ok: Bool }
}
