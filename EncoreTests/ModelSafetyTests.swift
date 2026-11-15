import Foundation
import SwiftData
import Testing
@testable import Encore

/// A model changed after an `await` may have been deleted meanwhile (a competition deleted while Apple Calendar
/// answers): such a model must be recognised without touching its data.
@MainActor
struct ModelSafetyTests {
    private func makeContext() throws -> (ModelContainer, ModelContext) {
        let schema = Schema([PlannedCompetition.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        return (container, container.mainContext)
    }

    @Test func aStoredModelIsThereAndADeletedOneIsGone() throws {
        let (store, context) = try makeContext()
        defer { withExtendedLifetime(store) {} }
        let competition = PlannedCompetition(name: "GP", city: "", date: Date())
        #expect(competition.isGone)   // not stored yet
        context.insert(competition)
        try context.save()
        #expect(!competition.isGone)
        context.delete(competition)
        try context.save()
        #expect(competition.isGone)
    }

    @Test func aModelDeletedButNotSavedYetIsGone() throws {
        let (store, context) = try makeContext()
        defer { withExtendedLifetime(store) {} }
        let competition = PlannedCompetition(name: "GP", city: "", date: Date())
        context.insert(competition)
        try context.save()
        context.delete(competition)
        #expect(competition.isGone)
    }

    @Test func savingAnEmptyContextWritesNothingAndSaysNothing() throws {
        let (store, context) = try makeContext()
        defer { withExtendedLifetime(store) {} }
        context.saveOrLog()
        #expect(!context.hasChanges)
    }
}
