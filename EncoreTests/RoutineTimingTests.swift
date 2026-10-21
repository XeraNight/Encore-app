import Testing
@testable import Encore

/// Figure and routine length from bars and the dance's own tempo.
struct RoutineTimingTests {
    @Test func tempoIsTheMiddleOfTheBarsRange() {
        #expect(RoutineTiming.barsPerMinute(fromTempo: "28–30 MPM (84–90 BPM)") == 29)
        #expect(RoutineTiming.barsPerMinute(fromTempo: "28–30 taktov za minútu") == 29)
        #expect(RoutineTiming.barsPerMinute(fromTempo: "50 MPM") == 50)
        #expect(RoutineTiming.barsPerMinute(fromTempo: "") == nil)
        #expect(RoutineTiming.barsPerMinute(fromTempo: "rýchlo") == nil)
    }

    @Test func lengthReadsLikeAClock() {
        let waltz = 29.0
        #expect(RoutineTiming.text(RoutineTiming.seconds(bars: 2, barsPerMinute: waltz)) == "4 s")
        #expect(RoutineTiming.text(RoutineTiming.seconds(bars: 46, barsPerMinute: waltz)) == "1:35")
        #expect(RoutineTiming.text(60) == "1:00")
    }

    @Test func barsInSlovak() {
        #expect(RoutineTiming.barsText(1) == "1 takt")
        #expect(RoutineTiming.barsText(3) == "3 takty")
        #expect(RoutineTiming.barsText(12) == "12 taktov")
    }
}
