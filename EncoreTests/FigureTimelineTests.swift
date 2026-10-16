import Testing
import Foundation
import SwiftData
@testable import Encore

/// Časová os figúry: a replaced video stays as a take, takes are ordered by date, no duplicates.
@MainActor
struct FigureTimelineTests {
    @Test func keepsEveryTakeOnceInDateOrder() throws {
        let schema = Schema([Routine.self, CanvasNode.self, VideoMediaEntry.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = container.mainContext
        let node = CanvasNode(x: 0, y: 0, figureName: "Natural Turn", rhythm: "123", notes: "", orderIndex: 0)
        context.insert(node)

        node.videoPath = "old.mov"
        #expect(node.timelineTakeCount == 1)          // the current video counts before it is recorded
        node.recordTake("old.mov", in: context)
        node.recordTake("old.mov", in: context)       // a second call adds nothing
        node.videoPath = "new.mov"
        node.recordTake("new.mov", in: context)

        #expect(node.timelineTakeCount == 2)
        #expect(node.timelineTakes.map(\.path) == ["old.mov", "new.mov"])
        #expect(node.timelineTakes.last?.date != nil)
    }
}
