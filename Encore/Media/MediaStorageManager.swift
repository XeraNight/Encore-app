import Foundation
import UIKit
import ImageIO
import OSLog
import SwiftData

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

    /// A figure's own copy of a Denník photo (same reason as the voice note) and its orientation for the block.
    nonisolated static func copyPhoto(_ filename: String) async -> (name: String, isPortrait: Bool)? {
        await Task.detached(priority: .userInitiated) {
            let copy = "note_photo_\(UUID().uuidString).jpg"
            do {
                try FileManager.default.copyItem(at: MediaStorageManager.url(for: filename), to: MediaStorageManager.url(for: copy))
            } catch {
                Logger.camera.error("Photo copy failed: \(error.localizedDescription, privacy: .public)")
                return nil
            }
            // Upright as the picture is shown: sideways orientations (5 to 8) swap width and height.
            let url = MediaStorageManager.url(for: copy)
            let properties = CGImageSourceCreateWithURL(url as CFURL, nil)
                .flatMap { CGImageSourceCopyPropertiesAtIndex($0, 0, nil) as? [CFString: Any] }
            var width = properties?[kCGImagePropertyPixelWidth] as? Int ?? 0
            var height = properties?[kCGImagePropertyPixelHeight] as? Int ?? 0
            if let orientation = properties?[kCGImagePropertyOrientation] as? Int, (5...8).contains(orientation) {
                swap(&width, &height)
            }
            return (copy, height > width)
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
    
    /// Everything Encore keeps in its own folder: videos and photos kept in the app, voice notes, the profile
    /// photo. Videos in Fotky are not here.
    nonisolated static func documentsSize() -> Int64 {
        let keys: [URLResourceKey] = [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
        guard let files = FileManager.default.enumerator(at: documentsDirectory, includingPropertiesForKeys: keys) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in files {
            guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true else { continue }
            total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        return total
    }
}

extension MediaStorageManager {
    /// Deletes a video file kept in Encore unless something else still shows it (`isVideoInUse`). A video put into a
    /// figure from Denník must not vanish from Denník when the figure or its video is deleted, and the other way round.
    /// A Fotky link is not a file here. True when the file was deleted.
    @MainActor
    @discardableResult
    static func removeVideoIfUnused(_ path: String?, in context: ModelContext, ignoring nodeId: UUID? = nil) -> Bool {
        guard let path, !path.isEmpty, !PhotoLibraryVideoStore.isReference(path) else { return false }
        guard !isVideoInUse(path, in: context, ignoring: nodeId) else { return false }
        removeFile(named: path)
        return true
    }

    /// True when anything in Encore still shows the video file: a Denník note, a figure (its video, its target video,
    /// its vault or the notes written in it), a routine, a library figure, a dance. `ignoring` is a figure that is being
    /// deleted or is losing its video itself: what it and its own vault entries hold does not count. A look that fails
    /// counts as "in use": a file is never deleted on a guess. Call it after the model that held the video is deleted
    /// and saved.
    @MainActor
    static func isVideoInUse(_ path: String, in context: ModelContext, ignoring nodeId: UUID? = nil) -> Bool {
        let target: String? = path
        if has(FetchDescriptor<InstantNote>(predicate: #Predicate { $0.videoPath == target }), in: context) { return true }
        if has(FetchDescriptor<Routine>(predicate: #Predicate { $0.videoPath == target || $0.activeTargetVideoPath == target }), in: context) { return true }
        if has(FetchDescriptor<FigureLibraryItem>(predicate: #Predicate { $0.videoPath == target }), in: context) { return true }
        if has(FetchDescriptor<Dance>(predicate: #Predicate { $0.videoPath == target }), in: context) { return true }

        guard let nodes = try? context.fetch(FetchDescriptor<CanvasNode>(
            predicate: #Predicate { $0.videoPath == target || $0.activeTargetVideoPath == target })),
              let entries = try? context.fetch(FetchDescriptor<VideoMediaEntry>(predicate: #Predicate { $0.filePath == path })),
              let written = try? context.fetch(FetchDescriptor<CanvasNode>(predicate: #Predicate { $0.notesRichData != nil }))
        else { return true }
        if nodes.contains(where: { $0.id != nodeId }) { return true }
        if entries.contains(where: { nodeId == nil || $0.canvasNode?.id != nodeId }) { return true }
        // A video put into a figure's notes is named inside the written notes.
        let name = Data(path.utf8)
        return written.contains { $0.id != nodeId && $0.notesRichData?.range(of: name) != nil }
    }

    @MainActor
    private static func has<Model: PersistentModel>(_ descriptor: FetchDescriptor<Model>, in context: ModelContext) -> Bool {
        guard let count = try? context.fetchCount(descriptor) else { return true }
        return count > 0
    }
}
