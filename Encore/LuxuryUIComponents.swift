import SwiftUI
import AudioToolbox

// MARK: - Luxury Design System Tokens (Ellegance.sk DNA)
public struct LuxuryTheme {
    public static let obsidian900 = Color(red: 5/255, green: 5/255, blue: 5/255)       // #050505
    public static let obsidian800 = Color(red: 10/255, green: 10/255, blue: 10/255)   // #0A0A0A
    public static let obsidian700 = Color(red: 20/255, green: 20/255, blue: 24/255)   // #141418
    public static let gold500     = Color(red: 212/255, green: 175/255, blue: 55/255)  // #D4AF37 Core Gold
    public static let gold400     = Color(red: 255/255, green: 224/255, blue: 136/255) // #FFE088 Bevel
    public static let gold300     = Color(red: 249/255, green: 241/255, blue: 204/255) // #F9F1CC
    
    // Discipline Colors
    public static let latinCrimson  = Color(red: 225/255, green: 29/255, blue: 72/255)   // #E11D48
    public static let standardBlue  = Color(red: 30/255, green: 64/255, blue: 175/255)   // #1E40AF
    public static let syncEmerald   = Color(red: 16/255, green: 185/255, blue: 129/255)  // #10B981
}

// MARK: - 0. Encore Velvet Background
/// Crimson velvet with grain and a soft stage light above the middle. The light and the dark edges are in
/// the picture itself (scripts/velvet_background.py), so nothing on top dulls the colour.
public struct EllegancePageBackground: View {
    public init() {}

    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                // Shown until the picture is decoded.
                Color(red: 0.16, green: 0.02, blue: 0.04)

                Image("EncoreVelvetBackground")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - 0A. Encore wordmark
/// The one way "ENCORE" is written next to the logo (Home header, login), so the brand reads the same everywhere.
public struct EncoreWordmark: View {
    var size: CGFloat = 13
    var color: Color = .white

    public var body: some View {
        Text("ENCORE")
            .font(.system(size: size, weight: .black, design: .rounded))
            .foregroundColor(color)
            .tracking(size * 0.2)
            .lineLimit(1)
            .fixedSize()
            .accessibilityLabel("Encore")
    }
}
