import Testing
import Foundation
@testable import Encore

/// Vzhľad: Karmín and no frame are free; every theme gives Apple Wallet a plain rgb() colour.
@MainActor
struct AppearanceTests {
    @Test func onlyTheDefaultLookIsFree() {
        #expect(CardTheme.allCases.filter(\.isFree) == [.carmine])
        #expect(AvatarFrame.allCases.filter(\.isFree) == [.none])
    }

    @Test func walletColoursArePlainRGB() {
        #expect(CardTheme.carmine.walletBackground == "rgb(89, 5, 17)")
        for theme in CardTheme.allCases {
            #expect(theme.walletBackground.range(of: #"^rgb\(\d{1,3}, \d{1,3}, \d{1,3}\)$"#, options: .regularExpression) != nil)
        }
    }

    /// The picker shows every icon this build contains, each with a preview (alternate icons ship only
    /// with "Include All App Icon Assets" on the Encore target).
    @Test func everyIconIsOfferedWithAPreview() {
        #expect(AppIconChoice.available == AppIconChoice.allCases)
        #expect(AppIconChoice.allCases.allSatisfy { $0.preview != nil })
    }
}
