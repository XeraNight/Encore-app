import Testing
import Foundation
@testable import Encore

/// Saved times read in Slovak time wherever the iPhone is.
struct EncoreTimeTests {
    @Test func aMomentReadsInSlovakTime() throws {
        // 22 Oct 2026 12:00 UTC is 14:00 in Bratislava (summer time until 25 Oct), 08:00 in New York.
        let moment = try #require(ISO8601DateFormatter().date(from: "2026-10-22T12:00:00Z"))
        #expect(EncoreTime.clock(moment).hasPrefix("14:00"))
        #expect(EncoreTime.clock(moment).hasSuffix("(čas SR)") == EncoreTime.isAway(at: moment))
    }

    @Test func winterTimeIsFollowed() throws {
        // After the clocks go back: 12:00 UTC is 13:00 in Bratislava.
        let moment = try #require(ISO8601DateFormatter().date(from: "2026-11-02T12:00:00Z"))
        #expect(EncoreTime.clock(moment).hasPrefix("13:00"))
    }
}
