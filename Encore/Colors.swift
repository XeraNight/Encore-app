import SwiftUI

extension Color {
    // MARK: - Ellegance.sk Official Palette
    static let obsidian900 = Color(red: 5/255, green: 5/255, blue: 5/255)             // #050505 Canvas Base
    static let obsidian800 = Color(red: 10/255, green: 10/255, blue: 10/255)         // #0A0A0A Sub-canvas
    static let obsidian700 = Color(red: 20/255, green: 20/255, blue: 24/255)         // #141418 Smoked Glass Card
    static let gold300     = Color(red: 249/255, green: 241/255, blue: 204/255)       // #F9F1CC Light Champagne
    static let gold400     = Color(red: 255/255, green: 224/255, blue: 136/255)       // #FFE088 Bevel Specular
    static let gold500     = Color(red: 212/255, green: 175/255, blue: 55/255)        // #D4AF37 Core Gold
    
    // MARK: - Encore Official Rebrand Palette (Crimson Velvet & Gold)
    static let encoreCrimson      = Color(red: 120/255, green: 5/255, blue: 20/255)   // #780514 Deep Crimson Velvet
    static let encoreCrimsonLight = Color(red: 154/255, green: 13/255, blue: 31/255)  // #9A0D1F Bright Crimson
    static let encoreBurgundy     = Color(red: 82/255, green: 2/255, blue: 13/255)    // #52020D Deep Burgundy Shadow
    static let encoreGold         = Color(red: 220/255, green: 165/255, blue: 30/255) // #DCA51E Satin Gold
    
    // MARK: - Theme Aliases (Dark Obsidian Luxury Default)
    static let themeBg = Color(red: 5/255, green: 5/255, blue: 5/255)                 // #050505 Pure Obsidian
    static let themeCard = Color(red: 18/255, green: 18/255, blue: 22/255)           // #121216 Smoked Glass Card
    static let themeDark = Color(white: 0.96)                                         // #F5F5F5 Crisp Luminous White (Primary Text)
    static let themeAccent = Color(red: 212/255, green: 175/255, blue: 55/255)       // #D4AF37 Champagne Gold
    static let themeBorder = Color(red: 255/255, green: 224/255, blue: 136/255).opacity(0.20) // Gold 400 Bevel
    /// Muted secondary text. 74 % white keeps at least 4.5:1 on the bright centre of the velvet (60 % did not).
    static let textSecondary = Color.white.opacity(0.74)
    /// Hint text inside an empty field: quieter than secondary text, so it never reads as something written.
    static let textPlaceholder = Color.white.opacity(0.5)
    static let textPrimary = Color.white                                               // Primary Luminous Text
    static let obsidian950 = Color(red: 7/255, green: 7/255, blue: 9/255)              // #070709 Deep Obsidian Accent
    static let themeBgCard = Color(red: 18/255, green: 18/255, blue: 22/255)
    
    // MARK: - Gradient Presets
    static let goldLinearGradient = LinearGradient(
        colors: [Color.gold400, Color.gold500],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // MARK: - Discipline & Status Vibrance
    static let standardBlue = Color(red: 59/255, green: 130/255, blue: 246/255)      // #3B82F6 Vibrant Royal Blue
    static let latinPink = Color(red: 244/255, green: 63/255, blue: 94/255)          // #F43F5E Latin Rose
    static let latinRed = Color(red: 225/255, green: 29/255, blue: 72/255)            // #E11D48 Latin Crimson / REC
    static let latinCrimson = Color(red: 225/255, green: 29/255, blue: 72/255)        // #E11D48 Latin Crimson / REC
    static let amberGold = Color(red: 212/255, green: 175/255, blue: 55/255)          // #D4AF37 Core Gold
    static let syncEmerald = Color(red: 16/255, green: 185/255, blue: 129/255)        // #10B981 Sync Emerald
    
    // Classic Aliases
    static let obsidianBlack = Color(red: 5/255, green: 5/255, blue: 5/255)
    static let champagneGold = Color(red: 212/255, green: 175/255, blue: 55/255)
    static let silkIvory = Color(red: 251/255, green: 249/255, blue: 245/255)
}
