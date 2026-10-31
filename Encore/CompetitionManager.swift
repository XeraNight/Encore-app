import Foundation
import SwiftUI
import Combine
import Supabase
import OSLog

// MARK: - KSIS in the app
/// Who the user is in KSIS, their couples (the current one and the ones before) and results. Everything comes from a
/// KSIS page the user has open in the app (`KSISBrowserView`): the server function `ksis-page` reads it and stores only
/// the user's own data.
/// Our server never contacts KSIS itself (docs/KSIS_SAMPLES_NEEDED.md §1).
@MainActor
final class CompetitionManager: ObservableObject {
    static let shared = CompetitionManager()

    @Published private(set) var couples: [UserCouple] = []
    @Published private(set) var results: [CompetitionResult] = []
    @Published private(set) var isLoading = false
    @Published private(set) var loadFailed = false

    /// Who the user picked in the KSIS members list; nil until they do.
    @Published private(set) var dancer: KSISDancer?
    /// Someone waits to be confirmed as the partner of the user's current couple (only a verified dancer sees it).
    @Published private(set) var partnerWaiting: KSISPartnerWaiting?

    var activeCouple: UserCouple? { couples.first(where: \.isCurrent) }
    var previousCouples: [UserCouple] { couples.filter { !$0.isCurrent } }

    enum ActionError: LocalizedError {
        case server(String)
        /// The user has not picked themselves in the members list yet.
        case needsDancer(String)
        case network

        var errorDescription: String? {
            switch self {
            case .server(let message), .needsDancer(let message): return message
            case .network: return "Nepodarilo sa spojiť so serverom. Skontroluj internet a skús to znova."
            }
        }
    }

    private var cancellables = Set<AnyCancellable>()

    private init() {
        AuthManager.shared.$currentUser
            .receive(on: RunLoop.main)
            .sink { [weak self] user in
                if user != nil {
                    Task { await self?.loadAllData() }
                } else {
                    self?.resetState()
                }
            }
            .store(in: &cancellables)
    }

    func resetState() {
        dancer = nil
        partnerWaiting = nil
        couples = []
        results = []
        loadFailed = false
    }

    /// Own rows only. RLS also lets connections see each other's couple, so the query names the user itself.
    func loadAllData() async {
        guard AuthManager.shared.isAuthenticated, let myId = AuthManager.shared.currentUser?.id else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let client = SupabaseConfig.client
            async let loadedDancers: [KSISDancer] = client
                .from("ksis_dancers")
                .select("user_id, person_number, name, club, status, created_at")
                .eq("user_id", value: myId)
                .execute()
                .value
            async let loadedCouples: [UserCouple] = client
                .from("user_couples")
                .select("id, is_current, pair_number, couple_id, partner_names, club, age_category, stt_class, stt_points, stt_finals, stt_last_change, lat_class, lat_points, lat_finals, lat_last_change, ksis_refreshed_at")
                .eq("user_id", value: myId)
                .not("pair_number", operator: .is, value: "null")
                .order("is_current", ascending: false)
                .order("created_at", ascending: false)
                .execute()
                .value
            async let loadedResults: [CompetitionResult] = client
                .from("competition_results")
                .select("id, sutaz_id, couple_id, event_name, category_name, discipline, date, couple_count, placement_text, placement, points_earned, cumulative_stats, start_number, rounds, judges")
                .eq("user_id", value: myId)
                .eq("is_deleted", value: false)
                .order("date", ascending: false)
                .execute()
                .value
            dancer = try await loadedDancers.first
            couples = try await loadedCouples
            results = try await loadedResults
            partnerWaiting = dancer?.isVerified == true ? await waitingPartner() : nil
            loadFailed = false
        } catch {
            loadFailed = true
            Logger.sync.error("Loading KSIS diary failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Extra: the diary still shows when this fails.
    private func waitingPartner() async -> KSISPartnerWaiting? {
        let rows: [KSISPartnerWaiting]? = try? await SupabaseConfig.client.rpc("my_partner_waiting").execute().value
        return rows?.first
    }

    /// The verified dancer confirms the partner of their current couple; the server checks both sides of the couple.
    func confirmPartner(_ waiting: KSISPartnerWaiting) async throws {
        struct Params: Encodable { let p_partner: UUID }
        do {
            try await SupabaseConfig.client.rpc("confirm_partner", params: Params(p_partner: waiting.userId)).execute()
        } catch {
            throw ActionError.server("Potvrdenie sa nepodarilo. Skús to znova.")
        }
        partnerWaiting = nil
    }

    // MARK: Verification in person
    /// A new verification QR for the pending dancer; it replaces the one before.
    func openVerifyCode() async throws -> KSISVerifyCode {
        do {
            return try await SupabaseConfig.client.rpc("open_verify_code").execute().value
        } catch {
            throw Self.verificationError(error)
        }
    }

    /// Whom the scanned code asks for; the server already says here when the scanner may not vouch.
    func peekVerifyCode(_ code: String) async throws -> KSISVouchPreview {
        struct Params: Encodable { let p_code: String }
        do {
            return try await SupabaseConfig.client.rpc("peek_verify_code", params: Params(p_code: code)).execute().value
        } catch {
            throw Self.verificationError(error)
        }
    }

    func vouch(_ code: String) async throws {
        struct Params: Encodable { let p_code: String }
        do {
            try await SupabaseConfig.client.rpc("vouch_dancer", params: Params(p_code: code)).execute()
        } catch {
            throw Self.verificationError(error)
        }
    }

    /// The server names each refusal (20261029b_ksis_vouch_in_person.sql).
    private static func verificationError(_ error: Error) -> ActionError {
        guard let error = error as? PostgrestError else { return .network }
        if error.code == "23505" { return .server("Tohto tanečníka už má overený iný účet.") }
        switch error.message {
        case "not_pending": return .server("Kód si otvoríš, len kým čakáš na overenie.")
        case "not_verified": return .server("Overovať môže len overený tanečník. Najprv sa over sám.")
        case "expired": return .server("Kód už neplatí. Nech si otvorí nový.")
        case "already_verified": return .server("Tento tanečník je už overený.")
        case "not_eligible": return .server("Overiť ho môže len overený tanečník z jeho klubu podľa KSIS alebo jeho partner.")
        case "limit": return .server("Za 30 dní si overil už 10 ľudí. Ďalšieho over neskôr.")
        default: return .server("Overenie sa nepodarilo. Skús to znova.")
        }
    }

    func results(for couple: UserCouple) -> [CompetitionResult] {
        guard let coupleId = couple.coupleId else { return [] }
        return results.filter { $0.coupleId == coupleId }
    }

    // MARK: Pages
    /// What the open page says about the user's couple. Nothing is stored.
    func read(url: URL, html: String) async throws -> KSISPageReply {
        try await call(KSISPageRequest(action: "read", url: url.absoluteString, html: html))
    }

    /// Stores what the open page says about the user (who they are, their couples, a result), then reloads the diary.
    func save(url: URL, html: String, consent: Bool = false, personNumber: Int? = nil) async throws -> KSISPageReply {
        let reply: KSISPageReply = try await call(
            KSISPageRequest(action: "save", url: url.absoluteString, html: html, consent: consent, personNumber: personNumber)
        )
        await loadAllData()
        return reply
    }

    func unlink(_ couple: UserCouple) async throws {
        let _: KSISOkReply = try await call(KSISPageRequest(action: "unlink", coupleId: couple.id.uuidString.lowercased()))
        await loadAllData()
    }

    func delete(_ result: CompetitionResult) async throws {
        let _: KSISOkReply = try await call(KSISPageRequest(action: "delete_result", resultId: result.id.uuidString.lowercased()))
        results.removeAll { $0.id == result.id }
    }

    private func call<Reply: Decodable>(_ request: KSISPageRequest) async throws -> Reply {
        do {
            return try await EdgeFunctionClient.call("ksis-page", request)
        } catch EdgeFunctionClient.Failure.server(let code, let message) {
            let text = message ?? "Nepodarilo sa to. Skús to znova."
            throw code == "needs_dancer" ? ActionError.needsDancer(text) : ActionError.server(text)
        } catch {
            throw ActionError.network
        }
    }
}
