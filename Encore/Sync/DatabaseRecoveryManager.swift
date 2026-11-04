import Foundation
import SwiftData

enum DatabaseRecoveryManager {
    static func recoverContainer(schema: Schema, configuration: ModelConfiguration) throws -> ModelContainer {
        let storeURL = configuration.url
        let backupDirectory = try makeBackupDirectory()
        
        for url in sqliteStoreURLs(for: storeURL) where FileManager.default.fileExists(atPath: url.path) {
            let backupURL = backupDirectory.appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.copyItem(at: url, to: backupURL)
        }
        
        for url in sqliteStoreURLs(for: storeURL) {
            try? FileManager.default.removeItem(at: url)
        }
        
        return try ModelContainer(for: schema, configurations: configuration)
    }
    
    private static func makeBackupDirectory() throws -> URL {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        let timestamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backupDirectory = MediaStorageManager.documentsDirectory
            .appendingPathComponent("DatabaseBackups", isDirectory: true)
            .appendingPathComponent(timestamp, isDirectory: true)
        try FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        return backupDirectory
    }
    
    private static func sqliteStoreURLs(for storeURL: URL) -> [URL] {
        [
            storeURL,
            URL(fileURLWithPath: storeURL.path + "-wal"),
            URL(fileURLWithPath: storeURL.path + "-shm")
        ]
    }
}
