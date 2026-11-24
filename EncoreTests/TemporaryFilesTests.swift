import Testing
import Foundation
@testable import Encore

/// A video import closed halfway left its file in the temporary folder for good.
struct TemporaryFilesTests {
    private func makeFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("test_tmp_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private func write(_ name: String, in folder: URL, daysAgo: Double) throws -> URL {
        let url = folder.appendingPathComponent(name)
        try Data([1]).write(to: url)
        let date = Date().addingTimeInterval(-daysAgo * 86_400)
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
        return url
    }

    @Test func whatIsOlderThanADayGoesAndWhatIsNewerStays() throws {
        let folder = try makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let old = try write("import.mov", in: folder, daysAgo: 3)
        let yesterday = try write("trim.mov", in: folder, daysAgo: 1.5)
        let fresh = try write("share.mp4", in: folder, daysAgo: 0.1)

        MediaStorageManager.removeOldTemporaryFiles(in: folder)

        #expect(!FileManager.default.fileExists(atPath: old.path))
        #expect(!FileManager.default.fileExists(atPath: yesterday.path))
        #expect(FileManager.default.fileExists(atPath: fresh.path))
    }

    @Test func aFolderThatIsNotThereIsNoError() {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("test_tmp_missing_\(UUID().uuidString)")
        MediaStorageManager.removeOldTemporaryFiles(in: missing)
    }
}
