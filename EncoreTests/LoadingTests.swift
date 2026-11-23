import Testing
import Foundation
@testable import Encore

/// The path the loader's light runs on.
struct LoadingTests {
    // MARK: The figure of eight

    @Test func theLightStartsOnTheRightAndHalfWayRoundItIsOnTheLeft() {
        let start = InfinityCurve.point(at: 0)
        #expect(abs(start.x - 1) < 0.001 && abs(start.y) < 0.001)
        let half = InfinityCurve.point(at: 0.5)
        #expect(abs(half.x + 1) < 0.01 && abs(half.y) < 0.01)
    }

    @Test func theLightCrossesTheMiddleOnceOnEachHalf() {
        for progress in [0.25, 0.75] {
            let crossing = InfinityCurve.point(at: progress)
            #expect(abs(crossing.x) < 0.001 && abs(crossing.y) < 0.001)
        }
    }

    @Test func theFigureStaysInsideItsBox() {
        for i in 0...200 {
            let point = InfinityCurve.point(at: Double(i) / 200)
            #expect(abs(point.x) <= 1.0001)
            #expect(abs(point.y) <= InfinityCurve.heightRatio + 0.0001)
        }
    }

    @Test func theFigureHasNoCornerAnywhere() throws {
        // Round edges: at each small step the line turns by a few degrees, never by a sudden angle.
        let steps = 500
        let points = (0...steps).map { InfinityCurve.point(at: Double($0) / Double(steps)) }
        let headings = (0..<steps).map { atan2(points[$0 + 1].y - points[$0].y, points[$0 + 1].x - points[$0].x) }
        var sharpest = 0.0
        for i in 0..<steps {
            var turn = headings[(i + 1) % steps] - headings[i]
            while turn > .pi { turn -= 2 * .pi }
            while turn < -.pi { turn += 2 * .pi }
            sharpest = max(sharpest, abs(turn))
        }
        // It measures about 4.6 degrees; a corner of even 30 degrees would be 0.52.
        #expect(sharpest < 0.15, "the sharpest turn is \(sharpest * 180 / .pi) degrees")
    }

    @Test func progressBeyondOneOrBelowZeroWrapsRound() {
        let a = InfinityCurve.point(at: 0.25)
        for other in [1.25, -0.75] {
            let b = InfinityCurve.point(at: other)
            #expect(abs(a.x - b.x) < 0.0001 && abs(a.y - b.y) < 0.0001)
        }
    }

    @Test func theLightRunsAtAnEvenPaceAlsoThroughTheCrossing() throws {
        let step = 0.01
        let chords = stride(from: 0.0, to: 1.0, by: step).map { s -> Double in
            let a = InfinityCurve.point(at: s)
            let b = InfinityCurve.point(at: s + step)
            return hypot(a.x - b.x, a.y - b.y)
        }
        let longest = try #require(chords.max())
        let shortest = try #require(chords.min())
        #expect(longest / shortest < 1.1)
    }
}
