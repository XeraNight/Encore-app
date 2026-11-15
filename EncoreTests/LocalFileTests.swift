import Foundation
import Testing
@testable import Encore

/// What the app reads from outside is kept in a small file and shown again without internet.
@MainActor
struct LocalFileTests {
    @Test func whatIsWrittenIsReadBackReplacedWholeAndRemoved() {
        let file = LocalFile("test-\(UUID().uuidString).json")
        defer { file.remove() }
        #expect(file.read() == nil)
        file.write(Data("one".utf8))
        #expect(file.read() == Data("one".utf8))
        file.write(Data("two, longer".utf8))
        file.write(Data("2".utf8))
        #expect(file.read() == Data("2".utf8))
        file.remove()
        #expect(file.read() == nil)
        file.remove()   // taking away what is not there is fine
    }

    @Test func twoFilesNeverShareContent() {
        let first = LocalFile("test-\(UUID().uuidString).json")
        let second = LocalFile("test-\(UUID().uuidString).json")
        defer { first.remove(); second.remove() }
        first.write(Data("a".utf8))
        #expect(second.read() == nil)
    }
}
