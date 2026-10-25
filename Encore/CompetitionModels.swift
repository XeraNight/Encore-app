import Foundation

// MARK: - Linked couple (`user_couples`)
/// The couple the dancer linked from KSIS. Class, points and finals are exactly what KSIS shows; the app
/// never computes or guesses them (CLAUDE.md, Domain).
struct UserCouple: Identifiable, Decodable, Equatable, Sendable {
    struct Standing: Equatable, Sendable {
        let className: String?
        let points: Int?
        let finals: Int?
        /// "Posledná zmena" from the couple detail, yyyy-MM-dd.
        let lastChange: String?

        var isEmpty: Bool { className == nil && points == nil && finals == nil }
    }

    let id: UUID
    let pairNumber: Int?
    /// KSIS couple page id (`par.php?id=`), known after the first saved result.
    let coupleId: Int?
    /// "Priezvisko Meno - Priezvisko Meno", as KSIS writes the couple.
    let partnerNames: String?
    let club: String?
    let ageCategory: String?
    let stt: Standing
    let lat: Standing
    let refreshedAt: String?
    /// The couple that dances now; the ones before stay as the history.
    let isCurrent: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case isCurrent = "is_current"
        case pairNumber = "pair_number"
        case coupleId = "couple_id"
        case partnerNames = "partner_names"
        case club
        case ageCategory = "age_category"
        case sttClass = "stt_class", sttPoints = "stt_points", sttFinals = "stt_finals", sttLastChange = "stt_last_change"
        case latClass = "lat_class", latPoints = "lat_points", latFinals = "lat_finals", latLastChange = "lat_last_change"
        case refreshedAt = "ksis_refreshed_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        pairNumber = try c.decodeIfPresent(Int.self, forKey: .pairNumber)
        coupleId = try c.decodeIfPresent(Int.self, forKey: .coupleId)
        partnerNames = try c.decodeIfPresent(String.self, forKey: .partnerNames)
        club = try c.decodeIfPresent(String.self, forKey: .club)
        ageCategory = try c.decodeIfPresent(String.self, forKey: .ageCategory)
        stt = Standing(
            className: try c.decodeIfPresent(String.self, forKey: .sttClass),
            points: try c.decodeIfPresent(Int.self, forKey: .sttPoints),
            finals: try c.decodeIfPresent(Int.self, forKey: .sttFinals),
            lastChange: try c.decodeIfPresent(String.self, forKey: .sttLastChange)
        )
        lat = Standing(
            className: try c.decodeIfPresent(String.self, forKey: .latClass),
            points: try c.decodeIfPresent(Int.self, forKey: .latPoints),
            finals: try c.decodeIfPresent(Int.self, forKey: .latFinals),
            lastChange: try c.decodeIfPresent(String.self, forKey: .latLastChange)
        )
        refreshedAt = try c.decodeIfPresent(String.self, forKey: .refreshedAt)
        isCurrent = try c.decodeIfPresent(Bool.self, forKey: .isCurrent) ?? true
    }

    /// "Tanečný Adam & Tanečná Eva"
    var title: String {
        guard let partnerNames, !partnerNames.isEmpty else { return pairNumber.map { "Pár \($0)" } ?? "Pár" }
        return partnerNames.replacingOccurrences(of: " - ", with: " & ")
    }

    /// "ŠTT D · 89 b · 5 F · LAT D · 91 b · 5 F", only what KSIS shows.
    var standingsLine: String {
        [("ŠTT", stt), ("LAT", lat)]
            .filter { !$0.1.isEmpty }
            .map { label, standing in
                var parts = ["\(label) \(standing.className ?? "–")"]
                if let points = standing.points { parts.append("\(points) b") }
                if let finals = standing.finals { parts.append("\(finals) F") }
                return parts.joined(separator: " · ")
            }
            .joined(separator: " · ")
    }
}

// MARK: - One competition (`competition_results`)
struct CompetitionResult: Identifiable, Decodable, Equatable, Sendable {
    let id: UUID
    let sutazId: Int
    let coupleId: Int
    let eventName: String
    let categoryName: String
    /// "STT" or "LAT".
    let discipline: String
    /// yyyy-MM-dd
    let date: String
    let coupleCount: Int
    let placementText: String
    let placement: Int?
    /// "Body": points from this competition.
    let pointsEarned: Int
    /// "Body po" / "Celkom": points and finals after this competition.
    let cumulativeStats: String?
    let startNumber: String?
    let rounds: [KSISRound]?
    let judges: [KSISJudge]?

    enum CodingKeys: String, CodingKey {
        case id
        case sutazId = "sutaz_id"
        case coupleId = "couple_id"
        case eventName = "event_name"
        case categoryName = "category_name"
        case discipline
        case date
        case coupleCount = "couple_count"
        case placementText = "placement_text"
        case placement
        case pointsEarned = "points_earned"
        case cumulativeStats = "cumulative_stats"
        case startNumber = "start_number"
        case rounds
        case judges
    }

    var dateValue: Date? { Self.isoDay.date(from: date) }

    /// "3. z 13", "12. – 13. z 16"
    var placeLine: String {
        let place = placementText.isEmpty ? placement.map { "\($0)." } ?? "–" : placementText
        return coupleCount > 0 ? "\(place) z \(coupleCount)" : place
    }

    var disciplineTitle: String { discipline == "LAT" ? "Latina" : "Štandard" }

    private static let isoDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

// MARK: - Marks by judge (stored in `competition_results.rounds`, shown live from the open page)
nonisolated struct KSISPlace: Codable, Equatable, Sendable {
    let from: Int
    let to: Int
    let text: String

    /// "3." or "1. – 2." for a shared place.
    var display: String { from == to ? "\(from)." : "\(from). – \(to)." }
}

struct KSISJudgeMark: Codable, Equatable, Sendable {
    let letter: String?
    let name: String?
    /// "X" or "." in a round, the judge's placing in the final.
    let mark: String
}

struct KSISDanceMarks: Codable, Equatable, Sendable {
    let dance: String
    /// Every published judge's mark; empty in a scores round.
    let marks: [KSISJudgeMark]
    let crosses: Int?
    /// The dance's score in a scores round (WDSF absolute judging); nil elsewhere and in rounds saved before.
    let score: Double?
}

struct KSISRound: Codable, Equatable, Sendable, Identifiable {
    let round: String
    /// "crosses", "final", or "scores" (WDSF absolute judging: one score per dance).
    let kind: String
    let dances: [KSISDanceMarks]
    /// "Suma" exactly as KSIS shows it.
    let sum: Double
    let place: KSISPlace?
    let advanced: Bool?
    let couplesInRound: Int
    let advancedCount: Int?
    let visibleCrosses: Int?
    /// Crosses from judges KSIS does not publish (Suma − published crosses); nil when unknown.
    let hiddenCrosses: Int?

    var id: String { round }
    var isFinal: Bool { kind == "final" }
    var isScores: Bool { kind == "scores" }

    /// "28" for crosses, "15" or "9,5" for the final sum, "139,043" for scores.
    var sumText: String {
        if isScores { return Self.scoreText(sum) }
        return sum.rounded() == sum ? String(Int(sum)) : sum.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "sk_SK")))
    }

    static func scoreText(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(3)).locale(Locale(identifier: "sk_SK")))
    }
}

struct KSISJudge: Codable, Equatable, Sendable, Identifiable {
    let letter: String
    let name: String?
    let city: String?
    /// Counted in "Suma" and in the final, but KSIS publishes neither the name nor the marks.
    let hidden: Bool

    var id: String { letter }
}

// MARK: - `ksis-page` function
struct KSISPageRequest: Encodable, Sendable {
    let action: String
    var url: String? = nil
    var html: String? = nil
    var consent: Bool? = nil
    /// "Toto som ja" on the members list.
    var personNumber: Int? = nil
    /// The saved couple to unlink (`user_couples.id`).
    var coupleId: String? = nil
    var resultId: String? = nil
}

/// What the server read on the open KSIS page. Fields depend on `kind`.
struct KSISPageReply: Decodable, Sendable {
    enum Kind: String, Decodable, Sendable {
        case membersList = "members_list"
        case couplesList = "couples_list"
        case coupleDetail = "couple_detail"
        case couplePage = "couple_page"
        case results
        case marks
        case registrations
        case slpStandings = "slp_standings"
        case blocked
        case unsupported

        init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = Kind(rawValue: raw) ?? .unsupported
        }
    }

    struct ListedMember: Decodable, Sendable, Identifiable {
        let personNumber: Int
        /// "Priezvisko Meno" as KSIS writes it.
        let name: String
        let club: String
        let sttClass: String
        let latClass: String
        /// A member who stopped keeps the last classes.
        let active: Bool
        let isMe: Bool

        var id: Int { personNumber }
    }

    struct ListedCouple: Decodable, Sendable, Identifiable {
        let pairNumber: Int
        let partner: String
        let partnerka: String
        let club: String
        let ageCategory: String
        let sttClass: String
        let latClass: String
        /// "Aktívny" for the couple that dances now, empty for one that ended.
        let status: String
        /// Which of the two the signed-in dancer is; nil when the couple is not theirs.
        let side: String?
        let isLinked: Bool

        /// A partner who changes partnerka may keep the number.
        var id: String { "\(pairNumber)|\(partnerka)" }
        var isMine: Bool { side != nil }
        var isActive: Bool { status == "Aktívny" }
    }

    struct PageStanding: Decodable, Sendable {
        struct Inner: Decodable, Sendable {
            let points: Int
            let finals: Int
        }

        let className: String
        let points: Int?
        let finals: Int?
        let lastChange: String?
        let standing: Inner?

        var resolvedPoints: Int? { points ?? standing?.points }
        var resolvedFinals: Int? { finals ?? standing?.finals }
    }

    struct PageCouple: Decodable, Sendable {
        let pairNumber: Int?
        let parId: Int?
        let partner: String
        let partnerka: String
        let club: String?
        let ageCategory: String?
        let stt: PageStanding?
        let lat: PageStanding?
    }

    struct Competition: Decodable, Sendable {
        let sutazId: Int?
        let eventName: String
        let category: String
        let date: String?
        let couples: Int?
        let advancement: [Int]
    }

    struct Total: Decodable, Sendable {
        let points: Int
        let finals: Int
    }

    struct OwnResult: Decodable, Sendable {
        let parId: Int
        let round: String
        let place: KSISPlace?
        let startNumber: String
        let points: Int?
        let total: Total?
        /// Slovenský pohár round: the place among Slovak couples and this round's cup points.
        let slp: SlovakCupRound?
    }

    struct Event: Decodable, Sendable {
        let name: String
        let date: String?
        let venue: String?
    }

    let kind: Kind
    let members: [ListedMember]?
    let couples: [ListedCouple]?
    let couple: PageCouple?
    let isLinked: Bool?
    /// Couple detail: one of the signed-in dancer's couples.
    let isMine: Bool?
    let isOwn: Bool?
    let competitions: Int?
    let competition: Competition?
    let own: OwnResult?
    let dances: [String]?
    let judges: [KSISJudge]?
    let startNumber: String?
    let rounds: [KSISRound]?
    let needsDefaultView: Bool?
    let defaultUrl: String?
    let event: Event?
    let categories: [String]?
    let saved: Int?
    /// Results: "points", "slp" (Slovenský pohár) or "none" (WDSF, ordinary cups).
    let scoring: String?
    /// The official Slovenský pohár standings (slp_poradie.php).
    let standings: SlovakCupStandings?
}

// MARK: - Who the account is in KSIS (`ksis_dancers`)
/// Picked in the members list. Private until the owner or the verified partner confirms it.
struct KSISDancer: Decodable, Equatable, Sendable, Identifiable {
    let userId: UUID
    let personNumber: Int
    /// "Priezvisko Meno" as KSIS writes it.
    let name: String
    let club: String?
    let status: String
    let createdAt: Date

    var id: UUID { userId }
    var isVerified: Bool { status == "verified" }

    enum CodingKeys: String, CodingKey {
        case name, club, status
        case userId = "user_id", personNumber = "person_number", createdAt = "created_at"
    }
}

/// The account waiting to be confirmed as the partner of the verified dancer's current couple.
struct KSISPartnerWaiting: Decodable, Equatable, Sendable, Identifiable {
    let userId: UUID
    let accountName: String
    let ksisName: String

    var id: UUID { userId }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id", accountName = "account_name", ksisName = "ksis_name"
    }
}

// MARK: - Slovenský pohár standings (read live from KSIS, cached on the iPhone)
nonisolated struct SlovakCupRound: Codable, Equatable, Sendable {
    /// Among Slovak couples; "9-12" for a shared place.
    let place: KSISPlace?
    let points: Int?
}

nonisolated struct SlovakCupStandings: Codable, Equatable, Sendable {
    struct Round: Codable, Equatable, Sendable {
        let sutazId: Int?
        let venue: String
        let date: String?
    }

    struct Entry: Codable, Equatable, Sendable, Identifiable {
        let place: KSISPlace?
        let parId: Int
        let partner: String
        let partnerka: String
        let club: String
        /// One per round in `rounds`; nil where the couple did not dance.
        let rounds: [SlovakCupRound?]
        let total: Int

        var id: Int { parId }
    }

    let year: Int?
    /// As KSIS titles the table: "Dospelí Štandard", "Juniori Latin".
    let category: String
    /// How many best rounds count (KSIS: 4); nil when the page does not say.
    let countedRounds: Int?
    let rounds: [Round]
    let entries: [Entry]
}

struct KSISOkReply: Decodable, Sendable {
    let ok: Bool
}
