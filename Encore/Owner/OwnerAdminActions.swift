import Foundation
import Supabase

// MARK: - Admin Actions (exclusively for the app owner)
/// What the owner console can do to other accounts. Every action is checked on the server again (the RPC functions test
/// `is_app_owner()`); the `isAppOwner` guard here only keeps anybody else from sending the request at all.
extension SubscriptionManager {
    /// Udeliť používateľovi bezplatný tier (VIP / Partner / Tréner)
    public func grantEntitlementAsOwner(
        targetUserId: UUID,
        tier: SubscriptionTier,
        durationMonths: Int?, // nil = lifetime
        notes: String
    ) async throws {
        guard isAppOwner else { throw NSError(domain: "EncoreAdmin", code: 403, userInfo: [NSLocalizedDescriptionKey: "Nemáš oprávnenie majiteľa aplikácie."]) }
        struct GrantParams: Encodable {
            let p_user: UUID
            let p_tier: String
            let p_duration_months: Int?
            let p_note: String

            /// "Navždy" and taking a plan away have no length. The server function has no default for it, so it
            /// goes as null: left out, the server does not find the function at all.
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(p_user, forKey: .p_user)
                try container.encode(p_tier, forKey: .p_tier)
                try container.encode(p_duration_months, forKey: .p_duration_months)
                try container.encode(p_note, forKey: .p_note)
            }

            private enum CodingKeys: String, CodingKey { case p_user, p_tier, p_duration_months, p_note }
        }
        // The server sets the expiry and writes the gift to the owner record.
        try await SupabaseConfig.client
            .rpc("owner_grant_plan", params: GrantParams(
                p_user: targetUserId, p_tier: tier.serverValue, p_duration_months: durationMonths, p_note: notes))
            .execute()
    }
    
    /// Priame udelenie predplatného na základe e-mailu používateľa (cez Supabase RPC)
    public func grantEntitlementByEmailAsOwner(
        targetEmail: String,
        tier: SubscriptionTier,
        durationMonths: Int?,
        notes: String
    ) async throws -> String {
        guard isAppOwner else {
            throw NSError(domain: "EncoreAdmin", code: 403, userInfo: [NSLocalizedDescriptionKey: "Nemáš oprávnenie majiteľa aplikácie."])
        }
        
        let client = SupabaseConfig.client
        struct GrantParams: Encodable {
            let p_email: String
            let p_tier: String
            let p_duration_months: Int?
            let p_note: String
        }
        struct GrantResponse: Decodable {
            let success: Bool
            let message: String?
            let error_code: String?
        }
        
        let cleanEmail = targetEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let res: GrantResponse = try await client
            .rpc("admin_grant_entitlement_by_email", params: GrantParams(
                p_email: cleanEmail,
                p_tier: tier.serverValue,
                p_duration_months: durationMonths,
                p_note: notes
            ))
            .execute()
            .value
            
        if !res.success {
            throw NSError(domain: "EncoreAdmin", code: 400, userInfo: [NSLocalizedDescriptionKey: res.message ?? "Nepodarilo sa udeliť predplatné."])
        }
        return res.message ?? "Plán bol úspešne udelený."
    }
    
    /// Zablokovať alebo odblokovať používateľský účet
    /// Zablokovať alebo odblokovať používateľský účet (cez RPC funkciu majiteľa)
    public func setAccountBanStatusAsOwner(
        targetUserId: UUID,
        isBanned: Bool,
        reason: String
    ) async throws {
        guard isAppOwner else {
            throw NSError(domain: "EncoreAdmin", code: 403, userInfo: [NSLocalizedDescriptionKey: "Nemáš oprávnenie majiteľa aplikácie."])
        }
        let client = SupabaseConfig.client
        
        struct BanParams: Encodable {
            let p_user: UUID
            let p_banned: Bool
            let p_reason: String?
        }
        struct BanResponse: Decodable {
            let success: Bool
            let error_code: String?
            let message: String?
        }
        
        let res: BanResponse = try await client
            .rpc("admin_set_account_status", params: BanParams(
                p_user: targetUserId,
                p_banned: isBanned,
                p_reason: isBanned ? reason : nil
            ))
            .execute()
            .value
            
        if !res.success {
            throw NSError(domain: "EncoreAdmin", code: 400, userInfo: [NSLocalizedDescriptionKey: res.message ?? "Zmena stavu účtu zlyhala."])
        }
    }
}
