import Foundation
import SwiftUI
import Combine
import Supabase
import OSLog

// MARK: - KSIS in the app
/// Linked couples and results from KSIS. Everything comes from a KSIS page the user has open in the app
/// (`KSISBrowserView`): the server function `ksis-page` reads it and stores only the user's own couple.
/// Our server never contacts KSIS itself (docs/KSIS_SAMPLES_NEEDED.md §1).
@MainActor
final class CompetitionManager: ObservableObject {
    static let shared = CompetitionManager()

    @Published private(set) var couples: [UserCouple] = []
    @Published private(set) var results: [CompetitionResult] = []
    @Published private(set) var isLoading = false
    @Published private(set) var loadFailed = false

    var activeCouple: UserCouple? { couples.first }

    enum ActionError: LocalizedError {
        case server(String)
        case network

        var errorDescription: String? {
            switch self {
            case .server(let message): return message
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
            async let loadedCouples: [UserCouple] = client
                .from("user_couples")
                .select("id, pair_number, couple_id, partner_names, club, age_category, stt_class, stt_points, stt_finals, stt_last_change, lat_class, lat_points, lat_finals, lat_last_change, ksis_refreshed_at")
                .eq("user_id", value: myId)
                .not("pair_number", operator: .is, value: "null")
                .order("created_at")
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
            couples = try await loadedCouples
            results = try await loadedResults
            loadFailed = false
        } catch {
            loadFailed = true
            Logger.sync.error("Loading KSIS diary failed: \(error.localizedDescription, privacy: .public)")
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

    /// Stores what the open page says about the user's couple, then reloads the diary.
    func save(url: URL, html: String, consent: Bool = false) async throws -> KSISPageReply {
        let reply: KSISPageReply = try await call(
            KSISPageRequest(action: "save", url: url.absoluteString, html: html, consent: consent)
        )
        await loadAllData()
        return reply
    }

    func unlink(_ couple: UserCouple) async throws {
        guard let pairNumber = couple.pairNumber else { return }
        let _: KSISOkReply = try await call(KSISPageRequest(action: "unlink", pairNumber: pairNumber))
        await loadAllData()
    }

    func delete(_ result: CompetitionResult) async throws {
        let _: KSISOkReply = try await call(KSISPageRequest(action: "delete_result", resultId: result.id.uuidString.lowercased()))
        results.removeAll { $0.id == result.id }
    }

    private func call<Reply: Decodable>(_ request: KSISPageRequest) async throws -> Reply {
        do {
            return try await EdgeFunctionClient.call("ksis-page", request)
        } catch EdgeFunctionClient.Failure.server(_, let message) {
            throw ActionError.server(message ?? "Nepodarilo sa to. Skús to znova.")
        } catch {
            throw ActionError.network
        }
    }
}
