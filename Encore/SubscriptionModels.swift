import Foundation
import SwiftUI

// MARK: - Subscription Tiers
public enum SubscriptionTier: String, CaseIterable, Codable, Sendable {
    case free = "Free"
    case plus = "Plus"
    case premium = "Premium"
    
    public var title: String { rawValue }

    /// The tier as `user_entitlements.tier` stores it ("free", "plus", "premium").
    public var serverValue: String { rawValue.lowercased() }

    /// Reads the server value. "studio" is the old name of Premium, kept so grants made before the rename still count.
    public init?(serverValue: String) {
        switch serverValue.lowercased() {
        case "free": self = .free
        case "plus": self = .plus
        case "premium", "studio": self = .premium
        default: return nil
        }
    }
    
    /// One line on the Profile card. Only what the plan really adds (same as `SubscriptionPaywallView.features`);
    /// features held back in `AppFeatures` are not promised.
    public var shortDescription: String {
        let coach = AppFeatures.coachTools
        let videos = AppFeatures.sharedVideos
        switch self {
        case .free:
            return ["Poznámky, plátno, výsledky z KSIS, 1 zostava na tanec", coach ? "1 kľúč pre trénera" : nil,
                    videos ? "1 GB na zdieľané videá" : nil].compactMap { $0 }.joined(separator: ", ")
        case .plus:
            return ["Neobmedzené zostavy, Top 3 priority po lekcii, Moja sezóna, vývoj tréningov, súťažný deň, strih lekcie na figúry, vzhľad", coach ? "kľúče pre trénerov až na 30 dní" : nil,
                    videos ? "10 GB na zdieľané videá" : nil].compactMap { $0 }.joined(separator: ", ")
        case .premium:
            return ["Všetko z Plus, porovnanie so vzorom a korekcie, časová os figúry", coach ? "zápis lekcií pre trénerov" : nil,
                    videos ? "50 GB na zdieľané videá" : nil].compactMap { $0 }.joined(separator: ", ")
        }
    }
    
    public var badgeColor: Color {
        switch self {
        case .free: return Color.gray
        case .plus: return Color.amberGold
        case .premium: return Color.gold400
        }
    }
    
    /// Space for videos shared with partner and coach. Must match `public.shared_video_quota_bytes`
    /// on the server, which enforces it.
    public var sharedVideoStorage: String {
        switch self {
        case .free: return "1 GB"
        case .plus: return "10 GB"
        case .premium: return "50 GB"
        }
    }

    public var iconName: String {
        switch self {
        case .free: return "sparkles"
        case .plus: return "crown.fill"
        case .premium: return "diamond.fill"
        }
    }
}

// MARK: - Comparable Conformance for Priority Comparison
extension SubscriptionTier: Comparable {
    public var rank: Int {
        switch self {
        case .free: return 0
        case .plus: return 1
        case .premium: return 2
        }
    }
    
    public static func < (lhs: SubscriptionTier, rhs: SubscriptionTier) -> Bool {
        lhs.rank < rhs.rank
    }
}

// MARK: - Entitlement Source
public enum EntitlementSource: String, Codable, Sendable {
    case storeKit = "storekit"         // Paid via Apple App Store
    case ownerGrant = "owner_grant"     // Gifted by app owner (Comped / VIP)
    case appOwner = "app_owner"         // Developer / Owner himself
    case none = "none"
}

// MARK: - User Entitlement Record (from Supabase or local cache)
public struct UserEntitlementRecord: Codable, Sendable {
    public let userId: UUID
    public let tier: SubscriptionTier
    public let source: EntitlementSource
    public let expiresAt: Date?
    public let grantedBy: UUID?
    public let notes: String?
    
    public var isValid: Bool {
        guard let exp = expiresAt else { return true } // nil means lifetime
        return exp > Date()
    }
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case tier
        case source
        case expiresAt = "expires_at"
        case grantedBy = "granted_by"
        case notes
    }
}

// MARK: - Account Moderation Status
public enum AccountModerationStatus: String, Codable, Sendable {
    case active = "active"
    case suspended = "suspended"
    case banned = "banned"
}
