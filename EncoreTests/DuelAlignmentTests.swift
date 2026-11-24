import Testing
@testable import Encore

/// Two videos aligned in the duel: B's moment is A's moment plus an offset. A negative offset at the start of A used to
/// start B too early and pull it back a moment later.
struct DuelAlignmentTests {
    @Test func withoutAnOffsetBIsWhereAIs() {
        let place = DuelAlignment.placeOfB(whenAIsAt: 4, offset: 0, rate: 1)
        #expect(place.position == 4)
        #expect(place.wait == 0)
    }

    @Test func aPositiveOffsetPutsBAhead() {
        let place = DuelAlignment.placeOfB(whenAIsAt: 1, offset: 2, rate: 0.5)
        #expect(place.position == 3)
        #expect(place.wait == 0)
    }

    @Test func aNegativeOffsetMakesBWaitOnItsFirstFrame() {
        let place = DuelAlignment.placeOfB(whenAIsAt: 0.5, offset: -2, rate: 1)
        #expect(place.position == 0)
        #expect(place.wait == 1.5)
    }

    @Test func theWaitIsLongerWhenAPlaysSlower() {
        let place = DuelAlignment.placeOfB(whenAIsAt: 0, offset: -2, rate: 0.5)
        #expect(place.position == 0)
        #expect(place.wait == 4)
    }

    @Test func onceAHasCaughtUpBStartsAtItsOwnMoment() {
        let place = DuelAlignment.placeOfB(whenAIsAt: 3, offset: -2, rate: 1)
        #expect(place.position == 1)
        #expect(place.wait == 0)
    }

    @Test func aStandstillRateNeverDividesByZero() {
        let place = DuelAlignment.placeOfB(whenAIsAt: 0, offset: -1, rate: 0)
        #expect(place.wait.isFinite)
    }
}
