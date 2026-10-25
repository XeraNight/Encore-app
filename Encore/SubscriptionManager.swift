import Foundation
import SwiftUI
import StoreKit
import Combine
import OSLog
import Supabase

// MARK: - Subscription & Entitlements Manager
@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    // Published State
    @Published var currentTier: SubscriptionTier = .free
    @Published var entitlementSource: EntitlementSource = .none
    @Published var isAccountBanned: Bool = false
    @Published var banReason: String = ""
    @Published var isCheckingEntitlements: Bool = false
    @Published var availableProducts: [Product] = []
    @Published var isPurchasing: Bool = false
    /// Comes only from the server (`is_app_owner()`), so nobody can become the owner by changing the app
    /// and the owner's e-mail is not stored in the app.
    @Published private(set) var isAppOwner: Bool = false
    /// The dancer whose plan is known (set when a check finishes). At launch the tier reads Free for a
    /// moment, so nothing bought is taken away before this matches the signed-in dancer.
    @Published private(set) var checkedUserId: UUID?
    
    // Product IDs for Apple App Store (StoreKit 2)
    public enum ProductID {
        static let plusMonthly = "com.jakub.encore.plus.monthly"
        static let plusAnnual = "com.jakub.encore.plus.annual"
        static let premiumMonthly = "com.jakub.encore.premium.monthly"
        static let premiumAnnual = "com.jakub.encore.premium.annual"
        
        static let all: [String] = [plusMonthly, plusAnnual, premiumMonthly, premiumAnnual]
    }
    
    private var transactionListener: Task<Void, Error>? = nil
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Start listening to StoreKit 2 transactions
        transactionListener = listenForTransactions()
        
        // React to auth changes to immediately refresh entitlements
        // Only a real user change (not every token refresh) re-checks entitlements.
        AuthManager.shared.$currentUser
            .map { $0?.id }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.refreshEntitlements()
                }
            }
            .store(in: &cancellables)
        
        Task {
            await refreshEntitlements()
            await loadProducts()
        }
    }
    
    deinit {
        transactionListener?.cancel()
    }
    
    // MARK: - Owner Check
    /// Asks the server. Every owner action is checked there again, this flag only shows the owner UI.
    /// On a network error the last answer for the same user is kept.
    private func refreshOwnerStatus() async {
        guard AuthManager.shared.currentUser != nil else {
            isAppOwner = false
            return
        }
        do {
            isAppOwner = try await SupabaseConfig.client.rpc("is_app_owner").execute().value
        } catch {
            Logger.general.notice("is_app_owner check failed: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    // MARK: - Capability Matrix
    /// Tanečník si môže sledovať svoje vlastné body a históriu zo súťaží (Plus & Premium)
    public var canTrackOwnPoints: Bool {
        isAppOwner || currentTier == .plus || currentTier == .premium
    }
    
    /// Tréner / pokročilý môže sledovať body a súťaže cudzích párov a zverencov (Iba Premium)
    public var canTrackRosterPoints: Bool {
        isAppOwner || currentTier == .premium
    }
    
    /// Prístup k trénerskej sekcii Štúdio (Roster párov, hromadné figúry, video anotácie)
    public var canAccessStudioRoster: Bool {
        isAppOwner || currentTier == .premium
    }
    
    /// Maximálny počet vytvorených zostáv na jeden tanec (Free = 1 na tanec, Plus/Premium = neobmedzene)
    public var maxRoutinesPerDanceAllowed: Int {
        (isAppOwner || currentTier == .plus || currentTier == .premium) ? 9999 : 1
    }
    
    /// Kontrola, či používateľ môže vytvoriť novú zostavu pre daný tanec.
    /// Free tier: 1 zostava na každý konkrétny tanec (1x Waltz, 1x Tango, 1x Samba...).
    /// Plus & Premium: Neobmedzený počet verzií/zostáv pre každý tanec.
    public func canCreateRoutine(existingCountForDance: Int) -> Bool {
        if isAppOwner || currentTier == .plus || currentTier == .premium {
            return true
        }
        return existingCountForDance < 1
    }
    
    /// Kontrola na základe zoznamu existujúcich zostáv používateľa
    public func canCreateRoutine(forDance danceName: String, existingRoutines: [Routine]) -> Bool {
        if isAppOwner || currentTier == .plus || currentTier == .premium {
            return true
        }
        let normalized = danceName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let matchingCount = existingRoutines.filter {
            $0.danceName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized
        }.count
        return matchingCount < 1
    }
    
    // MARK: - Entitlements Refresh & Verification
    // MARK: - Entitlements Refresh & Verification
    public func refreshEntitlements() async {
        isCheckingEntitlements = true
        let checkedFor = AuthManager.shared.currentUser?.id
        defer {
            isCheckingEntitlements = false
            // A check that started for another dancer (account switch) says nothing about this one.
            if let checkedFor, checkedFor == AuthManager.shared.currentUser?.id {
                checkedUserId = checkedFor
                AppearanceStore.shared.applyFreeLookIfNeeded()
            }
        }
        
        // 1. Priorita: Majiteľ aplikácie (overené na serveri)
        await refreshOwnerStatus()
        if isAppOwner {
            currentTier = .premium
            entitlementSource = .appOwner
            isAccountBanned = false
            saveCachedEntitlement(tier: .premium, source: .appOwner)
            return
        }
        
        // 2. Skontrolovať moderátorský stav účtu (Ban status)
        await checkAccountBanStatus()
        if isAccountBanned {
            currentTier = .free
            entitlementSource = .none
            saveCachedEntitlement(tier: .free, source: .none)
            return
        }
        
        // 3. Paralelné overenie Apple StoreKit 2 a manuálneho VIP grantu zo Supabase
        let storeKitTier = await checkStoreKitEntitlements()
        let supabaseGrant = await fetchSupabaseEntitlement()
        
        var effectiveTier: SubscriptionTier = .free
        var effectiveSource: EntitlementSource = .none
        
        // StoreKit aktívne predplatné
        if storeKitTier > .free {
            effectiveTier = storeKitTier
            effectiveSource = .storeKit
        }
        
        // Darovanie od majiteľa. A row marked "storekit" proves nothing (a client could write it); a paid plan is
        // proven only by StoreKit above, which Apple signs.
        if let grant = supabaseGrant, grant.isValid, grant.tier > .free, grant.source == .ownerGrant {
            if grant.tier >= effectiveTier {
                effectiveTier = grant.tier
                effectiveSource = grant.source
            }
        }
        
        if effectiveTier > .free {
            currentTier = effectiveTier
            entitlementSource = effectiveSource
            saveCachedEntitlement(tier: effectiveTier, source: effectiveSource)
            return
        }
        
        // 4. Offline Fallback (ak je zariadenie offline a malo platnú licenciu)
        if supabaseGrant == nil, let cached = loadCachedEntitlement(), cached.tier > .free {
            currentTier = cached.tier
            entitlementSource = cached.source
            return
        }
        
        // 5. Fallback na Free plán
        currentTier = .free
        entitlementSource = .none
        saveCachedEntitlement(tier: .free, source: .none)
    }
    
    // MARK: - Offline Entitlements Cache
    private func saveCachedEntitlement(tier: SubscriptionTier, source: EntitlementSource) {
        let uid = AuthManager.shared.currentUser?.id.uuidString ?? "guest"
        UserDefaults.standard.set(tier.rawValue, forKey: "encore_cached_tier_\(uid)")
        UserDefaults.standard.set(source.rawValue, forKey: "encore_cached_source_\(uid)")
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "encore_cached_time_\(uid)")
    }
    
    private func loadCachedEntitlement() -> (tier: SubscriptionTier, source: EntitlementSource)? {
        let uid = AuthManager.shared.currentUser?.id.uuidString ?? "guest"
        guard let tierRaw = UserDefaults.standard.string(forKey: "encore_cached_tier_\(uid)"),
              let tier = SubscriptionTier(serverValue: tierRaw),
              let sourceRaw = UserDefaults.standard.string(forKey: "encore_cached_source_\(uid)"),
              let source = EntitlementSource(rawValue: sourceRaw) else {
            return nil
        }
        let timestamp = UserDefaults.standard.double(forKey: "encore_cached_time_\(uid)")
        let daysOffline = (Date().timeIntervalSince1970 - timestamp) / 86400
        if daysOffline < 30 {
            return (tier, source)
        }
        return nil
    }
    
    // MARK: - StoreKit 2 Transactions Listener
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached { [weak self] in
            for await result in Transaction.updates {
                do {
                    let transaction = try Self.checkVerified(result)
                    if let self = self {
                        await self.refreshEntitlements()
                    }
                    await transaction.finish()
                } catch {
                    Logger.auth.error("StoreKit transaction update failed verification: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }
    
    nonisolated private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Check StoreKit 2 Entitlements (Returns highest active tier)
    private func checkStoreKitEntitlements() async -> SubscriptionTier {
        var highestTier: SubscriptionTier = .free
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? Self.checkVerified(result) else { continue }
            
            // Check if transaction is still active / not revoked
            if transaction.revocationDate == nil {
                let pid = transaction.productID
                if pid == ProductID.premiumMonthly || pid == ProductID.premiumAnnual {
                    return .premium // Premium is the highest
                } else if pid == ProductID.plusMonthly || pid == ProductID.plusAnnual {
                    highestTier = .plus
                }
            }
        }
        return highestTier
    }
    
    // MARK: - Load Products
    public func loadProducts() async {
        do {
            let products = try await Product.products(for: ProductID.all)
            self.availableProducts = products.sorted { $0.price < $1.price }
        } catch {
            Logger.auth.warning("Failed to load StoreKit products: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    // MARK: - Purchase
    public func purchase(product: Product) async throws -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }
        
        var options: Set<Product.PurchaseOption> = []
        if let userUUID = AuthManager.shared.currentUser?.id {
            options.insert(.appAccountToken(userUUID))
        }
        
        let result = try await product.purchase(options: options)
        switch result {
        case .success(let verification):
            let transaction = try Self.checkVerified(verification)
            await transaction.finish()
            await refreshEntitlements()
            return true
        case .userCancelled:
            return false
        case .pending:
            return false
        @unknown default:
            return false
        }
    }
    
    // MARK: - Restore Purchases
    public func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            Logger.auth.warning("StoreKit restorePurchases failed: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    // MARK: - Supabase Entitlement Verification (VIP / Comped)
    private func fetchSupabaseEntitlement() async -> UserEntitlementRecord? {
        guard let userUUID = AuthManager.shared.currentUser?.id else { return nil }
        let client = SupabaseConfig.client
        
        do {
            struct EntitlementDTO: Decodable {
                let user_id: UUID
                let tier: String
                let source: String
                let expires_at: String?
                let granted_by: UUID?
                let notes: String?
            }
            
            let res: EntitlementDTO = try await client
                .from("user_entitlements")
                .select()
                .eq("user_id", value: userUUID)
                .single()
                .execute()
                .value
            
            let tier = SubscriptionTier(serverValue: res.tier) ?? .free
            let source = EntitlementSource(rawValue: res.source) ?? .none
            var expiresDate: Date? = nil
            if let exp = res.expires_at {
                let iso = ISO8601DateFormatter()
                iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                expiresDate = iso.date(from: exp) ?? ISO8601DateFormatter().date(from: exp)
            }
            
            return UserEntitlementRecord(
                userId: res.user_id,
                tier: tier,
                source: source,
                expiresAt: expiresDate,
                grantedBy: res.granted_by,
                notes: res.notes
            )
        } catch {
            return nil
        }
    }
    
    // MARK: - Check Account Moderation / Ban Status
    private func checkAccountBanStatus() async {
        guard let userUUID = AuthManager.shared.currentUser?.id else { return }
        let client = SupabaseConfig.client
        
        do {
            struct ProfileStatusDTO: Decodable {
                let account_status: String?
                let ban_reason: String?
            }
            
            let res: ProfileStatusDTO = try await client
                .from("profiles")
                .select("account_status, ban_reason")
                .eq("id", value: userUUID)
                .single()
                .execute()
                .value
            
            if let status = res.account_status, (status == "banned" || status == "suspended") {
                self.isAccountBanned = true
                self.banReason = res.ban_reason ?? "Porušenie pravidiel komunity a Podmienok používania aplikácie."
            } else {
                self.isAccountBanned = false
                self.banReason = ""
            }
        } catch {
            // Offline or table column not yet created -> default to active
        }
    }
    
    // MARK: - Admin Actions (Exclusively for App Owner)
    
    /// Udeliť používateľovi bezplatný tier (VIP / Partner / Tréner)
    public func grantEntitlementAsOwner(
        targetUserId: UUID,
        tier: SubscriptionTier,
        durationMonths: Int?, // nil = lifetime
        notes: String
    ) async throws {
        guard isAppOwner else { throw NSError(domain: "EncoreAdmin", code: 403, userInfo: [NSLocalizedDescriptionKey: "Nemáš oprávnenie majiteľa aplikácie."]) }
        let client = SupabaseConfig.client
        
        var expiresAtString: String? = nil
        if let months = durationMonths, months > 0 {
            let future = Calendar.current.date(byAdding: .month, value: months, to: Date()) ?? Date()
            let iso = ISO8601DateFormatter()
            expiresAtString = iso.string(from: future)
        }
        
        struct UpsertPayload: Encodable {
            let user_id: UUID
            let tier: String
            let source: String
            let expires_at: String?
            let granted_by: UUID?
            let notes: String
            let updated_at: String
        }
        
        let payload = UpsertPayload(
            user_id: targetUserId,
            tier: tier.serverValue,
            source: EntitlementSource.ownerGrant.rawValue,
            expires_at: expiresAtString,
            granted_by: AuthManager.shared.currentUser?.id,
            notes: notes,
            updated_at: ISO8601DateFormatter().string(from: Date())
        )
        
        try await client
            .from("user_entitlements")
            .upsert(payload)
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
