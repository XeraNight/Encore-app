import Foundation
import SwiftUI
import StoreKit
import Combine
import OSLog
import Supabase


// MARK: - Where a check gets its answers
/// What the server said about the account's standing.
struct BanAnswer: Equatable {
    let isBanned: Bool
    let reason: String
}

/// What StoreKit says the dancer subscribes to: the plan and the product (monthly or annual) behind it.
struct StoreKitPlan: Equatable {
    var tier: SubscriptionTier = .free
    var productID: String?
}

/// The four questions a check asks, as plain closures: the app passes the real ones, a test passes its own, so a slow
/// check overtaken by a newer one, or an account switch in the middle of a check, can be played back exactly.
/// A nil answer means "could not be asked" (offline, an error), which is not the same as "no".
struct EntitlementSources {
    var userId: @MainActor () -> UUID?
    var storeKit: () async -> StoreKitPlan
    var isOwner: () async -> Bool?
    var ban: () async -> BanAnswer?
    var grant: () async -> SubscriptionManager.GrantLookup
}

extension EntitlementSources {
    /// The real questions: StoreKit on this iPhone and the Supabase server.
    static let live = EntitlementSources(
        userId: { AuthManager.shared.currentUser?.id },
        storeKit: { await SubscriptionManager.currentStoreKitPlan() },
        isOwner: { await SubscriptionManager.fetchIsAppOwner() },
        ban: { await SubscriptionManager.fetchBanAnswer() },
        grant: { await SubscriptionManager.fetchSupabaseEntitlement() }
    )
}

// MARK: - Subscription & Entitlements Manager
@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager(sources: .live, listensToStore: true)

    // Published State
    @Published var currentTier: SubscriptionTier = .free
    @Published var entitlementSource: EntitlementSource = .none
    @Published var isAccountBanned: Bool = false
    @Published var banReason: String = ""
    @Published var availableProducts: [Product] = []
    @Published var isPurchasing: Bool = false
    /// Comes only from the server (`is_app_owner()`), so nobody can become the owner by changing the app
    /// and the owner's e-mail is not stored in the app.
    @Published private(set) var isAppOwner: Bool = false
    /// The dancer whose plan is known (set when a check finishes). At launch the tier reads Free for a
    /// moment, so nothing bought is taken away before this matches the signed-in dancer.
    @Published private(set) var checkedUserId: UUID?
    /// The App Store product the dancer subscribes to right now (nil without one): the paywall tells "you have this" and
    /// "switch to annual" apart by it, and Profile shows "change or cancel" for it.
    @Published private(set) var activeProductID: String?

    // Product IDs for Apple App Store (StoreKit 2)
    public nonisolated enum ProductID {
        static let plusMonthly = "com.jakub.encore.sub.plus.monthly"
        static let plusAnnual = "com.jakub.encore.sub.plus.annual"
        static let premiumMonthly = "com.jakub.encore.sub.premium.monthly"
        static let premiumAnnual = "com.jakub.encore.sub.premium.annual"

        static let all: [String] = [plusMonthly, plusAnnual, premiumMonthly, premiumAnnual]
    }

    /// The plan a product stands for; Free for anything that is not one of ours.
    nonisolated static func tier(forProductID id: String) -> SubscriptionTier {
        switch id {
        case ProductID.premiumMonthly, ProductID.premiumAnnual: return .premium
        case ProductID.plusMonthly, ProductID.plusAnnual: return .plus
        default: return .free
        }
    }

    private let sources: EntitlementSources
    private var cancellables = Set<AnyCancellable>()

    /// `listensToStore` is off in tests: no StoreKit listeners, no sign-in observer, no first check.
    init(sources: EntitlementSources, listensToStore: Bool = false) {
        self.sources = sources
        guard listensToStore else { return }
        listenForStoreChanges()

        // Fires at once with the current dancer (the first check) and again only on a real user change,
        // not on every token refresh.
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

        Task { await loadProducts() }
    }

    // MARK: - Capability Matrix
    /// Prístup k trénerskej sekcii Štúdio (Roster párov, hromadné figúry, video anotácie)
    public var canAccessStudioRoster: Bool {
        isAppOwner || currentTier == .premium
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

    // MARK: - Entitlements Refresh & Verification
    /// When the plan was last checked on the server.
    private var lastCheck: Date?
    /// Counts the checks: only the newest one may publish what it found.
    private var latestCheck = 0

    /// The plan is checked again when the app comes back, so a gift from the owner, or its end, shows without
    /// quitting the app. Not more often than every 10 minutes: the plan rarely changes.
    public func refreshEntitlementsAfterBackground() async {
        if let lastCheck, Date().timeIntervalSince(lastCheck) < 600 { return }
        await refreshEntitlements()
    }

    public func refreshEntitlements() async {
        lastCheck = Date()
        latestCheck += 1
        let ticket = latestCheck
        let user = sources.userId()
        // A check that a newer one overtook, or that began for another dancer, says nothing about the one on screen.
        func isCurrent() -> Bool { ticket == latestCheck && user == sources.userId() }

        // The server is asked all at once. Apple answers by itself (offline too), so it is read first and what was
        // bought in the App Store shows at once, without waiting for the network.
        async let ownerAnswer = sources.isOwner()
        async let banAnswer = sources.ban()
        async let grantAnswer = sources.grant()
        let storeKit = await sources.storeKit()
        guard isCurrent() else { return }
        activeProductID = storeKit.productID
        if storeKit.tier > currentTier {
            currentTier = storeKit.tier
            entitlementSource = .storeKit
        }

        let owner = await ownerAnswer
        let ban = await banAnswer
        let grant = await grantAnswer
        guard isCurrent() else { return }

        // An answer the server could not give leaves the last one in place, but only for the same dancer.
        let sameDancer = checkedUserId == user
        if let owner {
            isAppOwner = owner
        } else if !sameDancer {
            isAppOwner = false
        }
        if let ban {
            isAccountBanned = ban.isBanned
            banReason = ban.reason
        } else if !sameDancer {
            isAccountBanned = false
            banReason = ""
        }

        if isAppOwner {
            currentTier = .premium
            entitlementSource = .appOwner
            isAccountBanned = false
            saveCachedEntitlement(tier: .premium, source: .appOwner)
        } else if isAccountBanned {
            currentTier = .free
            entitlementSource = .none
            saveCachedEntitlement(tier: .free, source: .none)
        } else {
            let resolved = Self.resolve(storeKit: storeKit.tier, grant: grant, cached: loadCachedEntitlement())
            currentTier = resolved.tier
            entitlementSource = resolved.source
            // A kept gift is not saved again: its 30 days run from the last real answer.
            if !resolved.isKept { saveCachedEntitlement(tier: resolved.tier, source: resolved.source) }
        }

        if let user {
            checkedUserId = user
            AppearanceStore.shared.applyFreeLookIfNeeded()
        }
    }

    /// What the server said about a plan the owner gave: a row, no row at all, or no answer (offline, an error).
    enum GrantLookup {
        case granted(UserEntitlementRecord)
        case none
        case unavailable
    }

    /// The plan from what Apple, the server and the last answer say. Apple answers by itself, offline too, so a plan
    /// bought in the App Store is never kept from an old answer: when it ended, it ended. A row marked "storekit" on
    /// the server proves nothing (a client could write it), only the owner's gift counts there. The gift is known only
    /// to the server, so when the server cannot be asked it is kept for up to 30 days.
    nonisolated static func resolve(storeKit: SubscriptionTier, grant: GrantLookup,
                                    cached: (tier: SubscriptionTier, source: EntitlementSource)?
    ) -> (tier: SubscriptionTier, source: EntitlementSource, isKept: Bool) {
        var tier = SubscriptionTier.free
        var source = EntitlementSource.none
        if storeKit > .free {
            tier = storeKit
            source = .storeKit
        }
        if case .granted(let gift) = grant, gift.isValid, gift.tier > .free, gift.source == .ownerGrant, gift.tier >= tier {
            tier = gift.tier
            source = gift.source
        }
        if tier > .free { return (tier, source, false) }
        if case .unavailable = grant, let cached, cached.tier > .free, cached.source == .ownerGrant {
            return (cached.tier, cached.source, true)
        }
        return (.free, .none, false)
    }

    // MARK: - Offline Entitlements Cache
    private func saveCachedEntitlement(tier: SubscriptionTier, source: EntitlementSource) {
        let uid = sources.userId()?.uuidString ?? "guest"
        UserDefaults.standard.set(tier.rawValue, forKey: "encore_cached_tier_\(uid)")
        UserDefaults.standard.set(source.rawValue, forKey: "encore_cached_source_\(uid)")
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "encore_cached_time_\(uid)")
    }

    private func loadCachedEntitlement() -> (tier: SubscriptionTier, source: EntitlementSource)? {
        let uid = sources.userId()?.uuidString ?? "guest"
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

    // MARK: - StoreKit 2 listeners
    /// Apple tells the app when a plan changes while it runs: a purchase or a renewal arrives as a transaction, an expiry or
    /// a change of renewal as a status. Neither is guaranteed to arrive (an expiry often brings no transaction), so the
    /// plan is also checked when the app comes back.
    private func listenForStoreChanges() {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let transaction = try? Self.checkVerified(result) else {
                    Logger.auth.error("StoreKit transaction update failed verification")
                    continue
                }
                await self?.refreshEntitlements()
                await transaction.finish()
            }
        }
        Task.detached { [weak self] in
            for await _ in Product.SubscriptionInfo.Status.updates {
                await self?.refreshEntitlements()
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
    /// How a purchase ended. "Pending" is Ask to Buy (or a payment that is still being approved): the plan arrives later by
    /// itself through the transaction listener.
    enum PurchaseOutcome: Equatable {
        case purchased, pending, cancelled
    }

    public func purchase(product: Product) async throws -> PurchaseOutcome {
        // A second tap while the sheet is open starts nothing.
        guard !isPurchasing else { return .cancelled }
        isPurchasing = true
        defer { isPurchasing = false }

        var options: Set<Product.PurchaseOption> = []
        if let userUUID = sources.userId() {
            options.insert(.appAccountToken(userUUID))
        }

        let result = try await product.purchase(options: options)
        switch result {
        case .success(let verification):
            let transaction = try Self.checkVerified(verification)
            await transaction.finish()
            await refreshEntitlements()
            return .purchased
        case .userCancelled:
            return .cancelled
        case .pending:
            return .pending
        @unknown default:
            return .cancelled
        }
    }

    // MARK: - Restore Purchases
    enum RestoreOutcome: Equatable {
        case restored(SubscriptionTier), nothingToRestore, cancelled, failed
    }

    /// Asks the App Store for the dancer's purchases and checks the plan again.
    public func restorePurchases() async -> RestoreOutcome {
        do {
            try await AppStore.sync()
        } catch StoreKitError.userCancelled {
            return .cancelled
        } catch {
            Logger.auth.warning("StoreKit restorePurchases failed: \(error.localizedDescription, privacy: .public)")
            return .failed
        }
        await refreshEntitlements()
        guard let activeProductID else { return .nothingToRestore }
        return .restored(Self.tier(forProductID: activeProductID))
    }

    // MARK: - The real answers
    /// The highest plan among the subscriptions StoreKit says are active on this iPhone, with its product.
    fileprivate static func currentStoreKitPlan() async -> StoreKitPlan {
        var best = StoreKitPlan()
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result), transaction.revocationDate == nil else { continue }
            let tier = tier(forProductID: transaction.productID)
            if tier > best.tier { best = StoreKitPlan(tier: tier, productID: transaction.productID) }
        }
        return best
    }

    /// Asks the server. Every owner action is checked there again, this flag only shows the owner UI.
    fileprivate static func fetchIsAppOwner() async -> Bool? {
        guard AuthManager.shared.currentUser != nil else { return false }
        do {
            let isOwner: Bool = try await SupabaseConfig.client.rpc("is_app_owner").execute().value
            return isOwner
        } catch {
            Logger.general.notice("is_app_owner check failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    fileprivate static func fetchBanAnswer() async -> BanAnswer? {
        guard let userUUID = AuthManager.shared.currentUser?.id else { return nil }
        do {
            struct ProfileStatusDTO: Decodable {
                let account_status: String?
                let ban_reason: String?
            }

            let res: ProfileStatusDTO = try await SupabaseConfig.client
                .from("profiles")
                .select("account_status, ban_reason")
                .eq("id", value: userUUID)
                .single()
                .execute()
                .value

            if let status = res.account_status, status == "banned" || status == "suspended" {
                return BanAnswer(isBanned: true, reason: res.ban_reason ?? String(localized: "Porušenie pravidiel komunity a Podmienok používania aplikácie."))
            }
            return BanAnswer(isBanned: false, reason: "")
        } catch {
            // Offline, or the column is not there yet: no answer
            return nil
        }
    }

    /// The plan the owner gave this dancer (VIP / partner / trainer), read from the server.
    fileprivate static func fetchSupabaseEntitlement() async -> GrantLookup {
        guard let userUUID = AuthManager.shared.currentUser?.id else { return .none }

        do {
            struct EntitlementDTO: Decodable {
                let user_id: UUID
                let tier: String
                let source: String
                let expires_at: String?
                let granted_by: UUID?
                let notes: String?
            }

            // A list, not `.single()`: nobody has a row unless the owner gave a plan, and "no row" is an answer, not an error.
            let rows: [EntitlementDTO] = try await SupabaseConfig.client
                .from("user_entitlements")
                .select()
                .eq("user_id", value: userUUID)
                .limit(1)
                .execute()
                .value
            guard let res = rows.first else { return .none }

            let tier = SubscriptionTier(serverValue: res.tier) ?? .free
            let source = EntitlementSource(rawValue: res.source) ?? .none
            var expiresDate: Date? = nil
            if let exp = res.expires_at {
                let iso = ISO8601DateFormatter()
                iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                expiresDate = iso.date(from: exp) ?? ISO8601DateFormatter().date(from: exp)
            }

            return .granted(UserEntitlementRecord(
                userId: res.user_id,
                tier: tier,
                source: source,
                expiresAt: expiresDate,
                grantedBy: res.granted_by,
                notes: res.notes
            ))
        } catch {
            return .unavailable
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
