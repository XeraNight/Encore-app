import Foundation
import UIKit
import OSLog

enum MediaStorageManager {
    nonisolated static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    nonisolated static func url(for filename: String) -> URL {
        documentsDirectory.appendingPathComponent(filename)
    }
    
    nonisolated static func fileExists(_ filename: String?) -> Bool {
        guard let filename else { return false }
        return FileManager.default.fileExists(atPath: url(for: filename).path)
    }
    
    /// A figure's own copy of a Denník voice note, so deleting the note in Denník keeps the figure's recording.
    /// Off the main thread; it stays in the iPhone backup like every voice note.
    nonisolated static func copyVoiceNote(_ filename: String) async -> String? {
        await Task.detached(priority: .userInitiated) {
            let copy = "voice_\(UUID().uuidString).m4a"
            do {
                try FileManager.default.copyItem(at: MediaStorageManager.url(for: filename), to: MediaStorageManager.url(for: copy))
                return copy
            } catch {
                Logger.audio.error("Voice note copy failed: \(error.localizedDescription, privacy: .public)")
                return nil
            }
        }.value
    }

    nonisolated static func removeFile(named filename: String?) {
        guard let filename else { return }
        try? FileManager.default.removeItem(at: url(for: filename))
    }
    
    /// Check available disk space on device
    nonisolated static func getFreeDiskSpaceMB() -> Int64 {
        do {
            let values = try documentsDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let capacity = values.volumeAvailableCapacityForImportantUsage {
                return capacity / (1024 * 1024)
            }
        } catch {
            Logger.general.error("Free disk space query failed: \(error.localizedDescription, privacy: .public)")
        }
        return 1024 // Fallback 1GB
    }
    
    nonisolated static func hasAvailableDiskSpace(minMB: Int64 = 200) -> Bool {
        return getFreeDiskSpaceMB() >= minMB
    }
    
    nonisolated static func excludeFromBackup(url: URL) {
        var mutableURL = url
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try? mutableURL.setResourceValues(resourceValues)
    }
    
    nonisolated static func store(data: Data, prefix: String, fileExtension: String) throws -> String {
        let filename = "\(prefix)_\(UUID().uuidString).\(fileExtension)"
        let targetURL = url(for: filename)
        try data.write(to: targetURL, options: .atomic)
        excludeFromBackup(url: targetURL)
        return filename
    }
    
    nonisolated static func copyIntoDocuments(from sourceURL: URL, fileExtension: String) throws -> String {
        let filename = "\(UUID().uuidString).\(fileExtension)"
        let destinationURL = url(for: filename)
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        excludeFromBackup(url: destinationURL)
        return filename
    }
    
    nonisolated static func moveIntoDocuments(from sourceURL: URL, fileExtension: String) throws -> String {
        let filename = "\(UUID().uuidString).\(fileExtension)"
        let destinationURL = url(for: filename)
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
        excludeFromBackup(url: destinationURL)
        return filename
    }
    
    nonisolated static func totalSize(for filenames: [String]) -> Int64 {
        filenames.reduce(0) { total, filename in
            let fileURL = url(for: filename)
            let size = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? NSNumber)?.int64Value ?? 0
            return total + size
        }
    }
}
