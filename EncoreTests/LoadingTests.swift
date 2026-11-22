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
