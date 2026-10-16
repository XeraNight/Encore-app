import Testing
import Foundation
@testable import Encore

/// Lock Screen buttons open https://www.encore-sk.com/quick/<action>; nothing else may be read as one.
@MainActor
struct QuickActionTests {
    private func action(_ text: String) -> QuickAction? {
        URL(string: text).flatMap(QuickAction.init(url:))
    }

    @Test func readsTheUniversalLinkOfEveryButton() {
        #expect(action("https://www.encore-sk.com/quick/video") == .video)
        #expect(action("https://www.encore-sk.com/quick/voice") == .voice)
        #expect(action("https://www.encore-sk.com/quick/text") == .text)
        #expect(action("https://www.encore-sk.com/quick/ksis") == .ksis)
        #expect(action("encore://quick/voice") == .voice)
    }

    @Test func ignoresOtherLinks() {
        #expect(action("https://www.encore-sk.com/add/ABC123") == nil)
        #expect(action("https://www.encore-sk.com/quick/unknown") == nil)
        #expect(action("https://example.com/quick/video") == nil)
        #expect(action("encore://auth-callback?code=x") == nil)
    }

    @Test func ksisOpensTheCompetitionCalendar() {
        #expect(QuickAction.ksisCalendarURL?.absoluteString == "https://szts.ksis.eu/menu.php?akcia=KS")
    }
}
