import Testing
import Foundation
import SwiftData
@testable import Encore

/// A voice note must come back whatever happens on the way: a dropped network, a file the cloud refuses, another account
/// opened in the middle of a run, a database rebuilt empty, a new iPhone. The cloud here is a stand-in that keeps every
/// account's recordings in a place of its own, as the real one does.
@MainActor
struct VoiceBackupTests {
    typealias Failure = VoiceBackup.Cloud.Failure

    /// One iPhone and the cloud: who is signed in, the folder with the recordings, a database for each account.
    @MainActor
    final class Rig {
        var account: UUID?
        /// "<account>/<name>" -> bytes: what the cloud holds, in each account's own place.
        var place: [String: Data] = [:]
        var tried: [String] = []
        var uploads: [String] = []
        var downloads: [String] = []
        var removals: [String] = []
        /// Makes the upload of a name fail (for good, or for a bad moment); nil lets it through.
        var uploadFails: (String) -> Failure? = { _ in nil }
        var downloadFails: Failure?
        var holdDownloads = false
        /// Runs right after a recording went up: a test can open another account in the middle of a run.
        var afterUpload: (String) -> Void = { _ in }

        let folder: URL
        private var containers: [UUID: ModelContainer] = [:]
        private var accounts: [UUID] = []
        lazy var backup = VoiceBackup(cloud: cloud, currentAccount: { [unowned self] in self.account }, folder: folder)

        init() throws {
            folder = FileManager.default.temporaryDirectory.appending(path: "voice-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }

        private var cloud: VoiceBackup.Cloud {
            VoiceBackup.Cloud(
                upload: { [self] name, file, _ in
                    tried.append(name)
                    if let failure = uploadFails(name) { throw failure }
                    guard let account else { throw Failure.later }
                    place["\(account)/\(name)"] = try Data(contentsOf: file)
                    uploads.append(name)
                    afterUpload(name)
                },
                download: { [self] name, file in
                    downloads.append(name)
                    while holdDownloads { try await Task.sleep(for: .milliseconds(5)) }
                    if let downloadFails { throw downloadFails }
                    guard let account else { throw Failure.later }
                    guard let bytes = place["\(account)/\(name)"] else { throw Failure.notFound }
                    try bytes.write(to: file)
                },
                remove: { [self] name in
                    guard let account else { throw Failure.later }
                    removals.append(name)
                    place["\(account)/\(name)"] = nil
                }
            )
        }

        /// A new account with its own empty database; its backup of the notes was brought back already.
        func newAccount(restored: Bool = true) throws -> UUID {
            let id = UUID()
            accounts.append(id)
            let schema = AccountStore.schema
            containers[id] = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
            if restored { markRestored(id) }
            return id
        }

        func markRestored(_ id: UUID) {
            UserDefaults.standard.set(id.uuidString, forKey: DeviceBackup.checkedKey(for: id))
        }

        func context(of id: UUID) -> ModelContext { containers[id]!.mainContext }

        /// A recording in the folder; with `note` the account's Denník has a note for it.
        @discardableResult
        func record(_ content: String = "hlas", for id: UUID? = nil, inFolder: Bool = true) throws -> String {
            let name = "voice_\(UUID().uuidString).m4a"
            if inFolder { try Data(content.utf8).write(to: folder.appending(path: name)) }
            if let id {
                context(of: id).insert(InstantNote(audioPath: name, audioDuration: 5))
                try context(of: id).save()
            }
            return name
        }

        func hasFile(_ name: String) -> Bool { FileManager.default.fileExists(atPath: folder.appending(path: name).path) }

        func saved(of id: UUID) -> Set<String> {
            Set(UserDefaults.standard.stringArray(forKey: VoiceBackup.savedKey(for: id)) ?? [])
        }

        /// False when the run asks to be tried again soon.
        @discardableResult
        func sync(_ id: UUID) async -> Bool { await backup.sync(in: context(of: id)) }

        func cleanUp() {
            for id in accounts {
                UserDefaults.standard.removeObject(forKey: VoiceBackup.savedKey(for: id))
                UserDefaults.standard.removeObject(forKey: DeviceBackup.checkedKey(for: id))
            }
            try? FileManager.default.removeItem(at: folder)
        }
    }

    // MARK: Up

    @Test func aNewRecordingGoesUpOnceAndIsRemembered() async throws {
        let rig = try Rig()
        defer { rig.cleanUp() }
        let a = try rig.newAccount()
        rig.account = a
        let name = try rig.record("tvoj hlas", for: a)

        await rig.sync(a)
        #expect(rig.place["\(a)/\(name)"] == Data("tvoj hlas".utf8))
        #expect(rig.saved(of: a) == [name])

        await rig.sync(a)
        #expect(rig.uploads == [name])
    }

    @Test func nothingGoesUpWhenNobodyIsSignedIn() async throws {
        let rig = try Rig()
        defer { rig.cleanUp() }
        let a = try rig.newAccount()
        try rig.record(for: a)

        await rig.sync(a)
        #expect(rig.tried.isEmpty)
        #expect(rig.saved(of: a).isEmpty)
    }

    @Test func aRecordingThatIsNotOnThisIPhoneIsLeftAlone() async throws {
        let rig = try Rig()
        defer { rig.cleanUp() }
        let a = try rig.newAccount()
        rig.account = a
        let missing = try rig.record(for: a, inFolder: false)

        await rig.sync(a)
        #expect(rig.tried.isEmpty)
        #expect(!rig.saved(of: a).contains(missing))
    }

    @Test func anEmptyFileIsNotAskedAboutAndNotAskedAgain() async throws {
        let rig = try Rig()
        defer { rig.cleanUp() }
        let a = try rig.newAccount()
        rig.account = a
        try rig.record("", for: a)

        await rig.sync(a)
        await rig.sync(a)
        #expect(rig.tried.isEmpty)
    }

    /// No network, a busy server or a full plan: the run stops at once, nothing is marked sent, the next run sends it all.
    @Test func aBadMomentStopsTheRunAndKeepsEverythingForTheNextOne() async throws {
        let rig = try Rig()
        defer { rig.cleanUp() }
        let a = try rig.newAccount()
        rig.account = a
        let names = try (0..<3).map { _ in try rig.record(for: a) }
        rig.uploadFails = { _ in .later }

        await rig.sync(a)
        #expect(rig.tried.count == 1)
        #expect(rig.saved(of: a).isEmpty)

        rig.uploadFails = { _ in nil }
        await rig.sync(a)
        #expect(Set(rig.uploads) == Set(names))
        #expect(rig.saved(of: a) == Set(names))
    }

    /// One file the cloud will never take must not keep every recording after it from going up.
    @Test func aFileTheCloudRefusesDoesNotBlockTheOthers() async throws {
        let rig = try Rig()
        defer { rig.cleanUp() }
        let a = try rig.newAccount()
        rig.account = a
        let bad = try rig.record(for: a)
        let others = try (0..<3).map { _ in try rig.record(for: a) }
        rig.uploadFails = { $0 == bad ? .refused : nil }

        await rig.sync(a)
        #expect(Set(rig.uploads) == Set(others))
        #expect(rig.saved(of: a) == Set(others))

        // It is not asked about again and again while the app stays open.
        await rig.sync(a)
        #expect(rig.tried.filter { $0 == bad }.count == 1)
    }

    // MARK: Retry

    /// A bad moment is the only thing that asks PendingSyncRunner to try again soon.
    @Test func aBadMomentAsksForARetry() async throws {
        let rig = try Rig()
        defer { rig.cleanUp() }
        let a = try rig.newAccount()
        rig.account = a
        try rig.record(for: a)
        rig.uploadFails = { _ in .later }

        #expect(await rig.sync(a) == false)

        rig.uploadFails = { _ in nil }
        #expect(await rig.sync(a) == true)
    }

    @Test func nothingToSendAndNobodySignedInNeedNoRetry() async throws {
        let rig = try Rig()
        defer { rig.cleanUp() }
        let a = try rig.newAccount()

        #expect(await rig.sync(a) == true)
        rig.account = a
        try rig.record(for: a)
        rig.account = nil
        #expect(await rig.sync(a) == true)
        #expect(rig.tried.isEmpty)
    }

    @Test func aRefusedFileNeedsNoRetry() async throws {
        let rig = try Rig()
        defer { rig.cleanUp() }
        let a = try rig.newAccount()
        rig.account = a
        let bad = try rig.record(for: a)
        try rig.record(for: a)
        rig.uploadFails = { $0 == bad ? .refused : nil }

        #expect(await rig.sync(a) == true)
        #expect(rig.uploads.count == 1)
    }

    /// A full plan stops the sending but a retry every few minutes would not help; the copies of deleted notes still go.
    @Test func aFullPlanNeedsNoRetryAndStillFreesTheSpace() async throws {
        let rig = try Rig()
        defer { rig.cleanUp() }
        let a = try rig.newAccount()
        rig.account = a
        let gone = try rig.record(for: a)
        await rig.sync(a)
        let context = rig.context(of: a)
        for note in try context.fetch(FetchDescriptor<InstantNote>()) { context.delete(note) }
        try context.save()
        let waiting = try rig.record(for: a)
        rig.uploadFails = { _ in .full }

        #expect(await rig.sync(a) == true)
        #expect(rig.uploads == [gone])
        #expect(rig.removals == [gone])
        #expect(!rig.saved(of: a).contains(waiting))
    }

    @Test func anotherAccountOpenedMeanwhileNeedsNoRetry() async throws {
        let rig = try Rig()
        defer { rig.cleanUp() }
        let a = try rig.newAccount()
        let b = try rig.newAccount()
        rig.account = a
        try (0..<2).forEach { _ in try rig.record(for: a) }
        rig.afterUpload = { _ in rig.account = b }

        #expect(await rig.sync(a) == true)
        #expect(rig.uploads.count == 1)
    }

    // MARK: Accounts

    /// Another account opened in the middle of a run: what is left of the first account never goes up under the second.
    @Test func aRecordingNeverGoesUpUnderAnotherAccount() async throws {
        let rig = try Rig()
        defer { rig.cleanUp() }
        let a = try rig.newAccount()
        let b = try rig.newAccount()
        rig.account = a
        let names = try (0..<3).map { _ in try rig.record(for: a) }
        rig.afterUpload = { _ in rig.account = b }

        await rig.sync(a)
        #expect(rig.uploads.count == 1)
        #expect(rig.place.keys.allSatisfy { $0.hasPrefix("\(a)/") })
        #expect(rig.saved(of: a).count == 1)
        #expect(rig.saved(of: b).isEmpty)

        // Back to the first account, the rest goes up where it belongs.
        rig.account = a
        rig.afterUpload = { _ in }
        await rig.sync(a)
        #expect(Set(rig.uploads) == Set(names))
        #expect(rig.place.keys.allSatisfy { $0.hasPrefix("\(a)/") })
    }

    /// Signing in as someone else and back deletes nothing, here or in the cloud, and sends nothing twice.
    @Test func switchingAccountsAndBackLosesNothing() async throws {
        let rig = try Rig()
        defer { rig.cleanUp() }
        let a = try rig.newAccount()
        let b = try rig.newAccount()
        rig.account = a
        let mine = try (0..<2).map { _ in try rig.record(for: a) }
        await rig.sync(a)
        #expect(rig.place.count == 2)

        rig.account = b
        let theirs = try rig.record(for: b)
        await rig.sync(b)
        #expect(rig.place["\(b)/\(theirs)"] != nil)

        rig.account = a
        await rig.sync(a)
        #expect(rig.removals.isEmpty)
        #expect(rig.uploads.count == 3)
        #expect(mine.allSatisfy { rig.hasFile($0) && rig.place["\(a)/\($0)"] != nil })
        #expect(rig.saved(of: a) == Set(mine))
        #expect(rig.saved(of: b) == [theirs])
    }

    // MARK: Removal

    @Test func theCopyOfADeletedNoteIsRemovedFromTheCloud() async throws {
        let rig = try Rig()
        defer { rig.cleanUp() }
        let a = try rig.newAccount()
        rig.account = a
        let kept = try rig.record(for: a)
        let gone = try rig.record(for: a)
        await rig.sync(a)

        let context = rig.context(of: a)
        for note in try context.fetch(FetchDescriptor<InstantNote>()) where note.audioPath == gone { context.delete(note) }
        try context.save()
        await rig.sync(a)

        #expect(rig.removals == [gone])
        #expect(rig.place["\(a)/\(gone)"] == nil)
        #expect(rig.place["\(a)/\(kept)"] != nil)
        #expect(rig.saved(of: a) == [kept])
    }

    /// A database rebuilt empty looks like every note was deleted; the copies stay until the notes came back from their backup.
    @Test func aRebuiltDatabaseDoesNotEraseTheCopies() async throws {
        let rig = try Rig()
        defer { rig.cleanUp() }
        let a = try rig.newAccount()
        rig.account = a
        let names = try (0..<2).map { _ in try rig.record(for: a) }
        await rig.sync(a)
        #expect(rig.place.count == 2)

        // The store is rebuilt empty (AccountStore) and its backup of the notes is not brought back yet.
        DeviceBackup.storeWasRebuilt(for: a)
        let rebuilt = try newEmptyContext()
        await rig.backup.sync(in: rebuilt.context)
        #expect(rig.removals.isEmpty)
        #expect(rig.place.count == 2)

        // The notes come back from their backup: still nothing removed, nothing sent again.
        rig.markRestored(a)
        for name in names { rebuilt.context.insert(InstantNote(audioPath: name, audioDuration: 5)) }
        try rebuilt.context.save()
        await rig.backup.sync(in: rebuilt.context)
        #expect(rig.removals.isEmpty)
        #expect(rig.uploads.count == 2)
    }

    /// A figure's note that cannot be read may still hold a recording: no copy is removed then.
    @Test func aNoteThatCannotBeReadKeepsEveryCopy() async throws {
        let rig = try Rig()
        defer { rig.cleanUp() }
        let a = try rig.newAccount()
        rig.account = a
        let name = try rig.record(for: a)
        await rig.sync(a)

        let context = rig.context(of: a)
        for note in try context.fetch(FetchDescriptor<InstantNote>()) { context.delete(note) }
        let node = CanvasNode(x: 0, y: 0, figureName: "Telemark", rhythm: "SQQ", notes: "", orderIndex: 0)
        node.notesRichData = Data("not a formatted note".utf8)
        context.insert(node)
        try context.save()
        await rig.sync(a)

        #expect(rig.removals.isEmpty)
        #expect(rig.place["\(a)/\(name)"] != nil)
    }

    @Test func aCopyThatCouldNotBeRemovedIsTriedAgainNextTime() async throws {
        let rig = try Rig()
        defer { rig.cleanUp() }
        let a = try rig.newAccount()
        rig.account = a
        try rig.record(for: a)
        await rig.sync(a)

        let context = rig.context(of: a)
        for note in try context.fetch(FetchDescriptor<InstantNote>()) { context.delete(note) }
        try context.save()
        let saved = rig.saved(of: a)
        #expect(saved.count == 1)

        // The cloud answers "later" to the removal: nothing is forgotten here.
        let flaky = VoiceBackup(cloud: VoiceBackup.Cloud(
            upload: { _, _, _ in }, download: { _, _ in }, remove: { _ in throw Failure.later }
        ), currentAccount: { rig.account }, folder: rig.folder)
        #expect(await flaky.sync(in: context) == false)
        #expect(rig.saved(of: a) == saved)

        await rig.sync(a)
        #expect(rig.saved(of: a).isEmpty)
        #expect(rig.place.isEmpty)
    }

    // MARK: Down

    /// A new iPhone: the notes came back from their backup, the recordings come back from the cloud when they are played.
    @Test func aNewIPhoneGetsTheRecordingsBack() async throws {
        let first = try Rig()
        defer { first.cleanUp() }
        let a = try first.newAccount()
        first.account = a
        let name = try first.record("tvoj hlas", for: a)
        await first.sync(a)
        #expect(first.place["\(a)/\(name)"] != nil)

        // The other iPhone knows nothing of the first one's list of what went up.
        UserDefaults.standard.removeObject(forKey: VoiceBackup.savedKey(for: a))
        let second = try Rig()
        defer { second.cleanUp() }
        second.account = a
        second.place = first.place
        #expect(!second.hasFile(name))

        #expect(await second.backup.download(name))
        #expect(second.hasFile(name))
        #expect(try Data(contentsOf: second.folder.appending(path: name)) == Data("tvoj hlas".utf8))
        #expect(second.saved(of: a) == [name])
    }

    @Test func aRecordingAlreadyHereIsNotAskedFor() async throws {
        let rig = try Rig()
        defer { rig.cleanUp() }
        let a = try rig.newAccount()
        rig.account = a
        let name = try rig.record()

        #expect(await rig.backup.download(name))
        #expect(rig.downloads.isEmpty)
    }

    /// The cloud saying "no copy" is asked once while the app stays open, not on every look at the note.
    @Test func aRecordingWithNoCopyIsAskedForOnce() async throws {
        let rig = try Rig()
        defer { rig.cleanUp() }
        let a = try rig.newAccount()
        rig.account = a
        let name = try rig.record(inFolder: false)

        #expect(await rig.backup.download(name) == false)
        #expect(await rig.backup.download(name) == false)
        #expect(rig.downloads.count == 1)
    }

    /// Only "no copy" is remembered. A dropped network, a busy server or a sign-in not finished yet is a bad moment:
    /// the next look asks again, and the recording comes back.
    @Test func aBadMomentIsNotRememberedAsNoCopy() async throws {
        let rig = try Rig()
        defer { rig.cleanUp() }
        let a = try rig.newAccount()
        rig.account = a
        let name = try rig.record("tvoj hlas", for: a)
        await rig.sync(a)
        try FileManager.default.removeItem(at: rig.folder.appending(path: name))

        rig.downloadFails = .later
        #expect(await rig.backup.download(name) == false)
        #expect(!rig.hasFile(name))

        rig.downloadFails = nil
        #expect(await rig.backup.download(name))
        #expect(rig.hasFile(name))
        #expect(rig.downloads.count == 2)
    }

    @Test func nothingIsAskedWhileNobodyIsSignedInAndItIsAskedAfterwards() async throws {
        let rig = try Rig()
        defer { rig.cleanUp() }
        let a = try rig.newAccount()
        rig.account = a
        let name = try rig.record("tvoj hlas", for: a)
        await rig.sync(a)
        try FileManager.default.removeItem(at: rig.folder.appending(path: name))

        rig.account = nil
        #expect(await rig.backup.download(name) == false)
        #expect(rig.downloads.isEmpty)

        rig.account = a
        #expect(await rig.backup.download(name))
    }

    /// The same recording asked for twice at once (a row and its waveform) is fetched once.
    @Test func twoAsksForTheSameRecordingAreOneDownload() async throws {
        let rig = try Rig()
        defer { rig.cleanUp() }
        let a = try rig.newAccount()
        rig.account = a
        let name = try rig.record("tvoj hlas", for: a)
        await rig.sync(a)
        try FileManager.default.removeItem(at: rig.folder.appending(path: name))

        rig.holdDownloads = true
        async let first = rig.backup.download(name)
        async let second = rig.backup.download(name)
        try await Task.sleep(for: .milliseconds(100))
        rig.holdDownloads = false

        let results = await [first, second]
        #expect(results == [true, true])
        #expect(rig.downloads.count == 1)
    }

    // MARK: What the data points to

    @Test func theRecordingsAreThoseOfTheDiaryAndOfTheFiguresNotes() throws {
        let rig = try Rig()
        defer { rig.cleanUp() }
        let a = try rig.newAccount()
        let context = rig.context(of: a)

        let inDiary = try rig.record(for: a)
        context.insert(InstantNote(text: "bez hlasu"))

        let inFigure = "voice_\(UUID().uuidString).m4a"
        var text = AttributedString("Rám ")
        text.append(NoteMedia.voice(VoiceNoteRef(fileName: inFigure, duration: 8)).piece)
        let node = CanvasNode(x: 0, y: 0, figureName: "Telemark", rhythm: "SQQ", notes: RichNote.plain(text), orderIndex: 0)
        node.notesRichData = RichNote.encode(text)
        context.insert(node)
        try context.save()

        let found = VoiceBackup.recordings(in: context)
        #expect(found.names == [inDiary, inFigure])
        #expect(found.isComplete)
    }

    @Test func aNoteThatCannotBeDecodedMakesTheListIncomplete() throws {
        let rig = try Rig()
        defer { rig.cleanUp() }
        let a = try rig.newAccount()
        let context = rig.context(of: a)
        let node = CanvasNode(x: 0, y: 0, figureName: "Telemark", rhythm: "SQQ", notes: "", orderIndex: 0)
        node.notesRichData = Data("garbage".utf8)
        context.insert(node)
        try context.save()

        #expect(VoiceBackup.recordings(in: context).isComplete == false)
    }

    // MARK: Helpers

    private func newEmptyContext() throws -> (container: ModelContainer, context: ModelContext) {
        let schema = AccountStore.schema
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        return (container, container.mainContext)
    }
}
