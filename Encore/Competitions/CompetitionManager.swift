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

    /// Competitions whose crosses KSIS does not have for the couple: the update stops asking for them.
    @Published private(set) var competitionsWithoutMarks: Set<Int> = []
    /// Per account, so after switching accounts and back the pages KSIS has no crosses on are not read again.
    private static func withoutMarksKey(_ user: UUID?) -> String {
        "encore.ksisCompetitionsWithoutMarks" + (user.map { ".\($0.uuidString)" } ?? "")
    }

    var activeCouple: UserCouple? { couples.first(where: \.isCurrent) }
    /// The couples before the current one, each once: KSIS keeps some couples under two ids.
    var previousCouples: [UserCouple] {
        var seen = Set(activeCouple.map { [$0.sameCoupleKey] } ?? [])
        return couples.filter { !$0.isCurrent && seen.insert($0.sameCoupleKey).inserted }
    }

    enum ActionError: LocalizedError {
        case server(String)
        /// KSIS's page does not have what was asked for, for example the couple's crosses.
        case notFound(String)
        /// The user has not picked themselves in the members list yet.
        case needsDancer(String)
        case network

        var errorDescription: String? {
            switch self {
            case .server(let message), .notFound(let message), .needsDancer(let message): return message
            case .network: return "Nepodarilo sa spojiť so serverom. Skontroluj internet a skús to znova."
            }
        }
    }

    private var cancellables = Set<AnyCancellable>()

    private init() {
        // The one list kept before it was per account; a competition in it is asked once more.
        UserDefaults.standard.removeObject(forKey: Self.withoutMarksKey(nil))
        AuthManager.shared.$currentUser
            .receive(on: RunLoop.main)
            .sink { [weak self] user in
                if let user {
                    self?.competitionsWithoutMarks = Set(UserDefaults.standard.array(forKey: Self.withoutMarksKey(user.id)) as? [Int] ?? [])
                    Task { await self?.loadAllData() }
                } else {
                    self?.resetState()
                }
            }
            .store(in: &cancellables)
    }

    func resetState() {
        dancer = nil
        couples = []
        results = []
        loadFailed = false
        competitionsWithoutMarks = []
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
                .select("person_number, name, club")
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
                .select("id, sutaz_id, couple_id, event_name, category_name, discipline, date, couple_count, placement_text, placement, points_earned, cumulative_stats, start_number, venue, rounds, judges")
                .eq("user_id", value: myId)
                .eq("is_deleted", value: false)
                .order("date", ascending: false)
                .execute()
                .value
            dancer = try await loadedDancers.first
            couples = try await loadedCouples
            results = try await loadedResults
            loadFailed = false
        } catch {
            loadFailed = true
            Logger.sync.error("Loading KSIS diary failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// The couple's competitions under each of its KSIS ids.
    func results(for couple: UserCouple) -> [CompetitionResult] {
        let ids = Set(couples.filter { $0.sameCoupleKey == couple.sameCoupleKey }.compactMap(\.coupleId))
        return results.filter { ids.contains($0.coupleId) }
    }

    /// The result has no crosses yet and KSIS may still have them.
    func isMissingMarks(_ result: CompetitionResult) -> Bool {
        result.rounds?.isEmpty != false && !competitionsWithoutMarks.contains(result.sutazId)
    }

    /// KSIS has no crosses for this result. A recent competition is asked again: KSIS may publish them later.
    func noteNoMarks(_ result: CompetitionResult) {
        let recent = PlannerCalendar.calendar.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        guard let date = result.dateValue, date < recent else { return }
        competitionsWithoutMarks.insert(result.sutazId)
        UserDefaults.standard.set(Array(competitionsWithoutMarks), forKey: Self.withoutMarksKey(AuthManager.shared.currentUser?.id))
    }

    // MARK: Pages
    /// What the open page says about the user's couple. Nothing is stored.
    func read(url: URL, html: String, otherName: String? = nil) async throws -> KSISPageReply {
        try await call(KSISPageRequest(action: "read", url: url.absoluteString, html: html, otherName: otherName))
    }

    /// Stores what the open page says about the user (who they are, their couples, a result), then reloads the diary.
    /// `reloads` is false while an update saves many pages: it reloads once after them.
    func save(url: URL, html: String, consent: Bool = false, personNumber: Int? = nil, parIds: [Int]? = nil,
              otherName: String? = nil, reloads: Bool = true) async throws -> KSISPageReply {
        let reply: KSISPageReply = try await call(
            KSISPageRequest(action: "save", url: url.absoluteString, html: html, consent: consent, personNumber: personNumber,
                            parIds: parIds, otherName: otherName)
        )
        if reloads { await loadAllData() }
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
            switch code {
            case "needs_dancer": throw ActionError.needsDancer(text)
            case "not_found": throw ActionError.notFound(text)
            default: throw ActionError.server(text)
            }
        } catch {
            throw ActionError.network
        }
    }
}
