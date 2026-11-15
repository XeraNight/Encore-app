import Foundation
import SwiftUI
import Combine
import Supabase
import OSLog

// MARK: - What KSIS had nothing for
/// Competitions KSIS had nothing for when asked (no crosses, no place), each with the day it was asked. An update does not
/// ask again at once, but KSIS may publish later, so after a month it asks once more.
struct KSISAskedAbout: Equatable {
    static let askAgainAfterDays = 30

    /// KSIS competition number → the day it was asked, counted from 1970.
    private var days: [Int: Int] = [:]

    init() {}

    /// As kept in preferences: string keys. A key that is not a number is left out, never a stop.
    init(stored: [String: Int]?) {
        days = Dictionary((stored ?? [:]).compactMap { key, day in Int(key).map { ($0, day) } }, uniquingKeysWith: { first, _ in first })
    }

    var stored: [String: Int] { Dictionary(uniqueKeysWithValues: days.map { (String($0.key), $0.value) }) }

    func contains(_ id: Int, on date: Date = Date()) -> Bool {
        guard let asked = days[id] else { return false }
        return Self.day(of: date) - asked < Self.askAgainAfterDays
    }

    mutating func note(_ id: Int, on date: Date = Date()) {
        days[id] = Self.day(of: date)
    }

    private static func day(of date: Date) -> Int { Int(date.timeIntervalSince1970 / 86_400) }
}

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

    /// Competitions whose crosses KSIS did not have for the couple when asked: the update waits a month before it asks again.
    @Published private(set) var askedAboutMarks = KSISAskedAbout()
    /// Competitions whose page gave no place ("Miesto:") when asked: the same.
    @Published private(set) var askedAboutVenue = KSISAskedAbout()
    /// Per account, so after switching accounts and back the pages KSIS had nothing on are not read at once again.
    private static func askedAboutMarksKey(_ user: UUID?) -> String { "encore.ksisAskedAboutMarks." + (user?.uuidString ?? "none") }
    private static func askedAboutVenueKey(_ user: UUID?) -> String { "encore.ksisAskedAboutVenue." + (user?.uuidString ?? "none") }
    private static func savedAsked(_ key: String) -> KSISAskedAbout {
        KSISAskedAbout(stored: UserDefaults.standard.dictionary(forKey: key) as? [String: Int])
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
        /// Too many calls in a short time: the run stops instead of hammering the server.
        case rateLimited(String)
        case network

        var errorDescription: String? {
            switch self {
            case .server(let message), .notFound(let message), .needsDancer(let message), .rateLimited(let message): return message
            case .network: return "Nepodarilo sa spojiť so serverom. Skontroluj internet a skús to znova."
            }
        }
    }

    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Only a real user change reloads: a token refresh (every hour) sends the same user again.
        AuthManager.shared.$currentUser
            .map { $0?.id }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] userId in
                if let userId {
                    // The lists kept before the ask-again-after-a-month rule: plain arrays of numbers.
                    UserDefaults.standard.removeObject(forKey: "encore.ksisCompetitionsWithoutMarks." + userId.uuidString)
                    UserDefaults.standard.removeObject(forKey: "encore.ksisCompetitionsWithoutVenue." + userId.uuidString)
                    self?.cachedUser = userId
                    self?.askedAboutMarks = Self.savedAsked(Self.askedAboutMarksKey(userId))
                    self?.askedAboutVenue = Self.savedAsked(Self.askedAboutVenueKey(userId))
                    Task {
                        await self?.restoreFromDisk(for: userId)
                        await self?.loadAllData()
                    }
                } else {
                    self?.resetState()
                }
            }
            .store(in: &cancellables)
    }

    func resetState() {
        dropLoadsInFlight()   // an answer still on its way belongs to the account that left
        dropKeptCopy()
        cachedUser = nil
        dancer = nil
        couples = []
        results = []
        loadFailed = false
        askedAboutMarks = KSISAskedAbout()
        askedAboutVenue = KSISAskedAbout()
    }

    /// Each load takes a number; only the newest answer is kept, so a slow older one never overwrites what a save
    /// has just reloaded, and an answer for an account that has since signed out is dropped.
    private var loadNumber = 0

    // MARK: Kept on the iPhone
    /// What one load gives, decoded.
    private struct Loaded: Sendable {
        let dancer: KSISDancer?
        let couples: [UserCouple]
        let results: [CompetitionResult]
        let skipped: Int
    }

    /// The three answers of the server as they came. The same bytes are read again after a start without internet.
    private struct Answers: Sendable {
        let dancers: Data
        let couples: Data
        let results: Data
    }

    /// The last answers of one account, kept in files so the diary shows at once and also without internet.
    private struct Cache: Sendable {
        private let dancers: LocalFile
        private let couples: LocalFile
        private let results: LocalFile

        init(user: UUID) {
            let id = user.uuidString.lowercased()
            dancers = LocalFile("ksis-\(id)-dancers.json")
            couples = LocalFile("ksis-\(id)-couples.json")
            results = LocalFile("ksis-\(id)-results.json")
        }

        func read() -> Answers? {
            guard let dancers = dancers.read(), let couples = couples.read(), let results = results.read() else { return nil }
            return Answers(dancers: dancers, couples: couples, results: results)
        }

        func write(_ answers: Answers) {
            dancers.write(answers.dancers)
            couples.write(answers.couples)
            results.write(answers.results)
        }

        func remove() {
            dancers.remove()
            couples.remove()
            results.remove()
        }
    }

    nonisolated private static func decode(_ answers: Answers) throws -> Loaded {
        let decoder = JSONDecoder()
        let dancers = try decoder.decode([KSISDancer].self, from: answers.dancers)
        let couples = try decoder.decode([UserCouple].self, from: answers.couples)
        let results = try decoder.decode(LossyList<CompetitionResult>.self, from: answers.results)
        return Loaded(dancer: dancers.first, couples: couples, results: results.elements, skipped: results.skipped)
    }

    /// An answer still on its way is dropped: it was asked for before something changed.
    private func dropLoadsInFlight() {
        loadNumber += 1
        isLoading = false
    }

    /// The account whose answers are kept; its files go when it signs out or the copy stops matching.
    private var cachedUser: UUID?

    private func apply(_ loaded: Loaded) {
        dancer = loaded.dancer
        couples = loaded.couples
        results = loaded.results
        if loaded.skipped > 0 {
            Logger.sync.error("KSIS diary: \(loaded.skipped, privacy: .public) unreadable result rows left out")
        }
    }

    /// The last load of this account: the results show at once, also in a hall without a signal. The server's answer
    /// follows and replaces it; a load already finished is never overwritten by this older copy.
    private func restoreFromDisk(for userId: UUID) async {
        let started = loadNumber
        let cache = Cache(user: userId)
        let kept = await Task.detached(priority: .userInitiated) { () -> Loaded? in
            guard let answers = cache.read() else { return nil }
            return try? Self.decode(answers)
        }.value
        guard let kept, loadNumber == started, AuthManager.shared.currentUser?.id == userId else { return }
        apply(kept)
    }

    /// The kept copy no longer matches (a result was deleted, the account left); the next load writes a new one.
    private func dropKeptCopy() {
        guard let user = cachedUser else { return }
        let cache = Cache(user: user)
        Task.detached(priority: .utility) { cache.remove() }
    }

    /// Own rows only. RLS also lets connections see each other's couple, so the query names the user itself.
    func loadAllData() async {
        guard AuthManager.shared.isAuthenticated, let myId = AuthManager.shared.currentUser?.id else { return }
        loadNumber += 1
        let mine = loadNumber
        isLoading = true
        defer { if mine == loadNumber { isLoading = false } }
        do {
            let client = SupabaseConfig.client
            async let dancersAnswer = client
                .from("ksis_dancers")
                .select("person_number, name, club")
                .eq("user_id", value: myId)
                .execute()
                .data
            async let couplesAnswer = client
                .from("user_couples")
                .select("id, is_current, pair_number, couple_id, partner_names, club, age_category, stt_class, stt_points, stt_finals, stt_last_change, lat_class, lat_points, lat_finals, lat_last_change, ksis_refreshed_at")
                .eq("user_id", value: myId)
                // Also the rows without a pair number: a couple found by name (an earlier couple, or the second
                // KSIS id of a couple KSIS keeps twice) has only its id, and its history is read by that id.
                .order("is_current", ascending: false)
                .order("created_at", ascending: false)
                .execute()
                .data
            async let resultsAnswer = client
                .from("competition_results")
                .select("id, sutaz_id, couple_id, event_name, category_name, discipline, date, couple_count, placement_text, placement, points_earned, cumulative_stats, start_number, venue, rounds, judges")
                .eq("user_id", value: myId)
                .eq("is_deleted", value: false)
                .order("date", ascending: false)
                .execute()
                .data
            let answers = try await Answers(dancers: dancersAnswer, couples: couplesAnswer, results: resultsAnswer)
            // Decoded off the main thread: the marks of a hundred competitions are about a megabyte.
            let loaded = try await Task.detached { try Self.decode(answers) }.value
            guard mine == loadNumber, AuthManager.shared.currentUser?.id == myId else { return }
            apply(loaded)
            let cache = Cache(user: myId)
            Task.detached(priority: .utility) { cache.write(answers) }
            loadFailed = false
        } catch {
            guard mine == loadNumber else { return }
            loadFailed = true
            Logger.sync.error("Loading KSIS diary failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// The couple's competitions under each of its KSIS ids.
    func results(for couple: UserCouple) -> [CompetitionResult] {
        let ids = Set(couples.filter { $0.sameCoupleKey == couple.sameCoupleKey }.compactMap(\.coupleId))
        return results.filter { ids.contains($0.coupleId) }
    }

    /// The result has no crosses yet and KSIS may still have them (a WDSF result has no KSIS page to ask).
    func isMissingMarks(_ result: CompetitionResult) -> Bool {
        result.hasKSISPage && result.rounds?.isEmpty != false && !askedAboutMarks.contains(result.sutazId)
    }

    /// KSIS had no crosses for this result. A competition of the last 14 days is asked again at the next update, and an
    /// older one after a month: organisers can be late.
    func noteNoMarks(_ result: CompetitionResult) {
        let recent = PlannerCalendar.calendar.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        guard let date = result.dateValue, date < recent else { return }
        askedAboutMarks.note(result.sutazId)
        UserDefaults.standard.set(askedAboutMarks.stored, forKey: Self.askedAboutMarksKey(AuthManager.shared.currentUser?.id))
    }

    /// The result has no place yet and KSIS may give one: a competition saved from the couple's history comes
    /// without it, the place is on the competition's own pages (a WDSF result has its place from the history).
    func isMissingVenue(_ result: CompetitionResult) -> Bool {
        result.hasKSISPage && result.venue == nil && !askedAboutVenue.contains(result.sutazId)
    }

    /// The competition's pages were read and gave no place.
    func noteNoVenue(_ result: CompetitionResult) {
        askedAboutVenue.note(result.sutazId)
        UserDefaults.standard.set(askedAboutVenue.stored, forKey: Self.askedAboutVenueKey(AuthManager.shared.currentUser?.id))
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

    /// Removes the couple with its results: every row of it, as KSIS keeps some couples under two ids.
    func unlink(_ couple: UserCouple) async throws {
        // Reloaded also when one row fails midway: what was removed must not still show.
        defer { Task { await loadAllData() } }
        for row in couples where row.sameCoupleKey == couple.sameCoupleKey {
            let _: KSISOkReply = try await call(KSISPageRequest(action: "unlink", coupleId: row.id.uuidString.lowercased()))
        }
    }

    func delete(_ result: CompetitionResult) async throws {
        let _: KSISOkReply = try await call(KSISPageRequest(action: "delete_result", resultId: result.id.uuidString.lowercased()))
        dropLoadsInFlight()   // a load that started before cannot bring the deleted result back
        results.removeAll { $0.id == result.id }
        dropKeptCopy()
    }

    private func call<Reply: Decodable>(_ request: KSISPageRequest) async throws -> Reply {
        do {
            return try await EdgeFunctionClient.call("ksis-page", request)
        } catch EdgeFunctionClient.Failure.server(let code, let message) {
            let text = message ?? (code == "rate_limited" ? "Čítaš príliš rýchlo. Počkaj chvíľu a skús to znova." : "Nepodarilo sa to. Skús to znova.")
            switch code {
            case "needs_dancer": throw ActionError.needsDancer(text)
            case "not_found": throw ActionError.notFound(text)
            case "rate_limited": throw ActionError.rateLimited(text)
            default: throw ActionError.server(text)
            }
        } catch {
            throw ActionError.network
        }
    }
}
