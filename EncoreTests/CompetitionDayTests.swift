import Testing
import Foundation
import SwiftData
@testable import Encore

/// Súťažný deň: the competition's dances in competition order, only those with open Top 3 items.
@MainActor
struct CompetitionDayTests {
    private func makeContext() throws -> (ModelContainer, ModelContext) {
        let schema = Schema([LessonPriority.self, PlannedCompetition.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        return (container, container.mainContext)
    }

    private func competition(_ categories: [String], in context: ModelContext) -> PlannedCompetition {
        let competition = PlannedCompetition(name: "GP", city: "Žilina", date: Date())
        competition.targetCategories = categories
        context.insert(competition)
        return competition
    }

    @Test func showsOnlyDancesWithOpenPrioritiesInCompetitionOrder() throws {
        let (container, context) = try makeContext()
        _ = container
        LessonPriorities.save(["Ramená dole"], danceName: "Quickstep", in: context)
        LessonPriorities.save(["Hlava doľava", "Zdvih"], danceName: "Waltz", in: context)
        LessonPriorities.save(["Boky"], danceName: "Rumba", in: context)
        let all = try context.fetch(FetchDescriptor<LessonPriority>())

        let plan = CompetitionDayPlan(competition: competition(["Dospelí D ŠTT"], in: context), priorities: all, results: [])
        #expect(plan.dances.map(\.danceName) == ["Waltz", "Quickstep"])
        #expect(plan.dances.first?.priorities == ["Hlava doľava", "Zdvih"])
        #expect(plan.otherDances == ["Tango", "Viennese Waltz", "Slowfoxtrot"])
    }

    @Test func bothDisciplinesAndTickedItems() throws {
        let (container, context) = try makeContext()
        _ = container
        let saved = LessonPriorities.save(["Boky", "Ruky"], danceName: "Rumba", in: context)
        saved[0].doneAt = Date()
        let all = try context.fetch(FetchDescriptor<LessonPriority>())

        let plan = CompetitionDayPlan(competition: competition(["Štandard", "Latina"], in: context), priorities: all, results: [])
        #expect(plan.dances.map(\.danceName) == ["Rumba"])
        #expect(plan.dances.first?.priorities == ["Ruky"])
    }
}
