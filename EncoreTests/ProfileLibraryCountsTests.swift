import Testing
import SwiftData
@testable import Encore

/// "Videá a poznámky" on Profile counts only what the dancer made.
@MainActor
struct ProfileLibraryCountsTests {
    @Test func builtInDanceTipsAreNotTheDancersNotes() throws {
        let schema = Schema([Routine.self, CanvasNode.self, VideoMediaEntry.self, Dance.self, FigureLibraryItem.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = container.mainContext
        context.insert(Dance(name: "Waltz", category: "Standard", tempo: "28–30 MPM", info: "Sústreď sa na Rise & Fall."))
        context.insert(Dance(name: "Tango", category: "Standard", tempo: "31–33 MPM", info: "Bez Rise & Fall.", videoPath: "tango.mov"))
        context.insert(FigureLibraryItem(name: "Natural Turn", danceName: "Waltz", rhythm: "1, 2, 3"))
        context.insert(CanvasNode(x: 0, y: 0, figureName: "Whisk", notes: "Hlava vľavo"))
        context.insert(CanvasNode(x: 0, y: 0, figureName: "Chassé"))
        try context.save()

        let counts = ProfileLibraryCounts(context: context)
        #expect(counts.figures == 1)
        #expect(counts.media == 2)   // the figure with a note and the dance with a video
    }
}
