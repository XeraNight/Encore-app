import Foundation
import OSLog

/// A small file in Application Support/Cache for what the app reads from outside and must show again without
/// internet (the KSIS calendar, the Slovak Cup table, the diary of results). It is written whole and in one step, so
/// an app killed in the middle leaves the old file or the new one, never half. Not backed up: it can be read again.
nonisolated struct LocalFile: Sendable {
    let url: URL?

    init(_ name: String) {
        url = try? FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appending(path: "Cache", directoryHint: .isDirectory)
            .appending(path: name)
    }

    func read() -> Data? {
        guard let url else { return nil }
        return try? Data(contentsOf: url)
    }

    func write(_ data: Data) {
        guard let url else { return }
        do {
            var folder = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? folder.setResourceValues(values)
            try data.write(to: url, options: .atomic)
        } catch {
            Logger.sync.error("Cache file not written: \(error.localizedDescription, privacy: .public)")
        }
    }

    func remove() {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
