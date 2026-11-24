import Testing
import Foundation
import SwiftData
@testable import Encore

/// What the cloud says about the library, and what it must not undo: a change that has not gone up yet, and a deletion on
/// its way.
@MainActor
struct FigureLibraryMergeTests {
    private func makeContext() throws -> (ModelContainer, ModelContext) {
        let schema = Schema([FigureLibraryItem.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        return (container, container.mainContext)
    }

    private func cloud(_ id: UUID, name: String) -> DBFigureRow {
        DBFigureRow(id: id, name: name, dance_name: "Waltz", rhythm: "SQQ", technique_notes: "z cloudu",
                    image_path: nil, video_path: nil, is_custom: true)
    }

    private func figures(in context: ModelContext) throws -> [UUID: FigureLibraryItem] {
        Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<FigureLibraryItem>()).map { ($0.id, $0) })
    }

    @Test func theCloudUpdatesAFigureThatHasNothingWaiting() throws {
        let (container, context) = try makeContext()
        _ = container
        let id = UUID()
        context.insert(FigureLibraryItem(id: id, name: "Stará", danceName: "Waltz", rhythm: "SQQ", isCustom: true))
        try context.save()

        FigureLibrarySync.merge([cloud(id, name: "Nová")], into: context, waiting: [], deleted: [])

        #expect(try figures(in: context)[id]?.name == "Nová")
    }

    /// The reported gap: a figure edited with no signal was overwritten by the cloud's older copy.
    @Test func aChangeThatHasNotGoneUpIsNotOverwrittenByTheCloud() throws {
        let (container, context) = try makeContext()
        _ = container
        let id = UUID()
        context.insert(FigureLibraryItem(id: id, name: "Moja nová", danceName: "Waltz", rhythm: "SQQ", isCustom: true))
        try context.save()

        FigureLibrarySync.merge([cloud(id, name: "Stará z cloudu")], into: context, waiting: [id], deleted: [])

        #expect(try figures(in: context)[id]?.name == "Moja nová")
    }

    @Test func aFigureDeletedHereIsNotBroughtBackWhileItsDeletionIsOnTheWay() throws {
        let (container, context) = try makeContext()
        _ = container
        let id = UUID()

        FigureLibrarySync.merge([cloud(id, name: "Zmazaná")], into: context, waiting: [], deleted: [id])

        #expect(try figures(in: context).isEmpty)
    }

    @Test func aFigureTheCloudKnowsAndThisIPhoneDoesNotIsAdded() throws {
        let (container, context) = try makeContext()
        _ = container
        let id = UUID()

        FigureLibrarySync.merge([cloud(id, name: "Z nového iPhonu")], into: context, waiting: [], deleted: [])

        #expect(try figures(in: context)[id]?.techniqueNotes == "z cloudu")
    }

    @Test func aFigureOnlyOnThisIPhoneStays() throws {
        let (container, context) = try makeContext()
        _ = container
        let mine = UUID()
        context.insert(FigureLibraryItem(id: mine, name: "Len tu", danceName: "Waltz", rhythm: "SQQ", isCustom: true))
        try context.save()

        FigureLibrarySync.merge([cloud(UUID(), name: "Iná")], into: context, waiting: [], deleted: [])

        #expect(try figures(in: context)[mine] != nil)
    }
}
