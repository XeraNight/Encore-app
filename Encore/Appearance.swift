import Auth
import Combine
import OSLog
import PostgREST
import Supabase
import SwiftUI

// MARK: - Vzhľad (Plus)
/// The look of the member card, the same in Encore and in Apple Wallet: dark leathers so the gold lettering
/// stays readable. Free has Karmín; Plus has all of them.
enum CardTheme: String, CaseIterable, Identifiable, Codable {
    case carmine, obsidian, midnight, emerald, mahogany

    var id: String { rawValue }
    var isFree: Bool { self == .carmine }

    var title: String {
        switch self {
        case .carmine: return "Karmín"
        case .obsidian: return "Obsidián"
        case .midnight: return "Polnoc"
        case .emerald: return "Smaragd"
        case .mahogany: return "Mahagón"
        }
    }

    /// Leather from light to dark: (red, green, blue) 0…1.
    private var palette: [(Double, Double, Double)] {
        switch self {
        case .carmine: return [(0.52, 0.05, 0.11), (0.35, 0.02, 0.07), (0.20, 0.01, 0.04)]
        case .obsidian: return [(0.21, 0.20, 0.21), (0.11, 0.10, 0.11), (0.04, 0.04, 0.05)]
        case .midnight: return [(0.11, 0.17, 0.38), (0.06, 0.10, 0.25), (0.02, 0.04, 0.12)]
        case .emerald: return [(0.05, 0.32, 0.24), (0.02, 0.20, 0.15), (0.01, 0.09, 0.07)]
        case .mahogany: return [(0.42, 0.19, 0.09), (0.28, 0.11, 0.05), (0.14, 0.05, 0.02)]
        }
    }

    var light: Color { Self.color(palette[0]) }
    var middle: Color { Self.color(palette[1]) }
    var dark: Color { Self.color(palette[2]) }

    /// The Apple Wallet background, as PassKit wants it ("rgb(102, 3, 18)").
    var walletBackground: String {
        let (r, g, b) = palette[1]
        return "rgb(\(Int(r * 255)), \(Int(g * 255)), \(Int(b * 255)))"
    }

    private static func color(_ rgb: (Double, Double, Double)) -> Color {
        Color(red: rgb.0, green: rgb.1, blue: rgb.2)
    }
}

/// A frame around the profile photo. Free has none; Plus has all.
enum AvatarFrame: String, CaseIterable, Identifiable, Codable {
    case none, gold, deco, carmine

    var id: String { rawValue }
    var isFree: Bool { self == .none }

    var title: String {
        switch self {
        case .none: return "Bez rámika"
        case .gold: return "Zlatý"
        case .deco: return "Art Deco"
        case .carmine: return "Karmínový"
        }
    }
}

/// The chosen look. A choice is kept when Plus ends, but the free look is shown until Plus is back.
@MainActor
final class AppearanceStore: ObservableObject {
    static let shared = AppearanceStore()

    @Published private(set) var chosenTheme: CardTheme
    @Published private(set) var chosenFrame: AvatarFrame

    private static let themeKey = "appearance.cardTheme"
    private static let frameKey = "appearance.avatarFrame"

    private init() {
        let defaults = UserDefaults.standard
        chosenTheme = defaults.string(forKey: Self.themeKey).flatMap(CardTheme.init(rawValue:)) ?? .carmine
        chosenFrame = defaults.string(forKey: Self.frameKey).flatMap(AvatarFrame.init(rawValue:)) ?? .none
    }

    private var hasPlus: Bool { SubscriptionManager.shared.currentTier >= .plus }

    var theme: CardTheme { hasPlus || chosenTheme.isFree ? chosenTheme : .carmine }
    var frame: AvatarFrame { hasPlus || chosenFrame.isFree ? chosenFrame : .none }

    func select(_ theme: CardTheme) {
        chosenTheme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: Self.themeKey)
        syncToServer()
    }

    func select(_ frame: AvatarFrame) {
        chosenFrame = frame
        UserDefaults.standard.set(frame.rawValue, forKey: Self.frameKey)
        syncToServer()
    }

    /// The Apple Wallet card is made on the server from `profiles.card_theme`, so the look that is
    /// actually shown (free look without Plus) goes there.
    func syncToServer() {
        guard let userId = AuthManager.shared.currentUser?.id else { return }
        let payload = CardThemeUpdate(card_theme: .init(
            theme_id: theme.rawValue,
            background_color: theme.walletBackground,
            foreground_color: "rgb(255, 230, 153)",
            label_color: "rgb(212, 175, 55)",
            logo_text: "ENCORE",
            avatar_frame: frame.rawValue
        ))
        Task {
            do {
                try await SupabaseConfig.client.from("profiles").update(payload).eq("id", value: userId).execute()
            } catch {
                Logger.general.error("Card theme sync failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private struct CardThemeUpdate: Encodable {
        struct Theme: Encodable {
            let theme_id: String
            let background_color: String
            let foreground_color: String
            let label_color: String
            let logo_text: String
            let avatar_frame: String
        }
        let card_theme: Theme
    }
}

// MARK: - Frame drawing
extension View {
    /// Draws the frame around a round profile photo of the given size.
    func avatarFrame(_ frame: AvatarFrame, size: CGFloat) -> some View {
        overlay { AvatarFrameShape(frame: frame, size: size).allowsHitTesting(false) }
    }
}

private struct AvatarFrameShape: View {
    let frame: AvatarFrame
    let size: CGFloat

    private var gold: LinearGradient {
        LinearGradient(colors: [Color.gold300, Color.gold500, Color.gold300], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Frames sit outside the photo's own thin ring, with a small gap, so each one reads at a glance.
    var body: some View {
        let ring = max(2.5, size * 0.04)
        let gap = size * 0.09
        let outer = size + gap * 2
        Group {
            switch frame {
            case .none:
                EmptyView()
            case .gold:
                Circle().strokeBorder(gold, lineWidth: ring * 1.3)
                    .shadow(color: Color.gold500.opacity(0.55), radius: ring * 2.5)
            case .carmine:
                ZStack {
                    Circle().strokeBorder(Color.latinCrimson, lineWidth: ring * 1.6)
                    Circle().strokeBorder(Color.gold400, lineWidth: 1).padding(ring * 1.6)
                    Circle().strokeBorder(Color.gold400.opacity(0.7), lineWidth: 1)
                }
            case .deco:
                ZStack {
                    Circle().strokeBorder(gold, lineWidth: ring * 0.8)
                    // A sunburst of short rays between the four diamonds, Art Deco style.
                    ForEach(0..<16, id: \.self) { index in
                        Capsule()
                            .fill(gold)
                            .frame(width: 1.5, height: index % 4 == 2 ? gap * 0.9 : gap * 0.5)
                            .offset(y: -outer / 2 - (index % 4 == 2 ? gap * 0.45 : gap * 0.25))
                            .rotationEffect(.degrees(Double(index) * 22.5))
                    }
                    ForEach(0..<4, id: \.self) { index in
                        Rectangle()
                            .fill(gold)
                            .frame(width: ring * 2.4, height: ring * 2.4)
                            .rotationEffect(.degrees(45))
                            .offset(y: -outer / 2 + ring * 0.4)
                            .rotationEffect(.degrees(Double(index) * 90))
                    }
                }
            }
        }
        .frame(width: outer, height: outer)
    }
}
