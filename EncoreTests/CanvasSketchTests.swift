import Testing
import Foundation
import CoreGraphics
@testable import Encore

/// The floor drawing survives leaving the canvas: strokes with their colour round-trip through `sketchData`.
@MainActor
struct CanvasSketchTests {
    @Test func strokesRoundTripAndAnEmptyDrawingStoresNothing() {
        let strokes = [
            SketchStroke(points: [CGPoint(x: 10, y: 20), CGPoint(x: 30, y: 40)], color: .gold),
            SketchStroke(points: [CGPoint(x: 5, y: 5)], color: .white),
        ]
        let data = CanvasSketch(strokes: strokes).data
        #expect(CanvasSketch(data: data).strokes == strokes)
        #expect(CanvasSketch(strokes: []).data == nil)
        #expect(CanvasSketch(data: Data("nonsense".utf8)).strokes.isEmpty)
    }
}
