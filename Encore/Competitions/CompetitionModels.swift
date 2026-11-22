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

    /// One couple whatever KSIS's order of names and diacritics: KSIS keeps some couples twice, as "Kalina Jakub -
    /// Kissova Nikoletta" and "Jakub Kalina - Nikoletta Kissová". A couple without names is only itself.
    var sameCoupleKey: String {
        guard let partnerNames, !partnerNames.isEmpty else { return id.uuidString }
        return partnerNames.components(separatedBy: " - ").map { side in
            side.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "sk"))
                .split(separator: " ").sorted().joined(separator: " ")
        }.joined(separator: "|")
    }

    /// The other dancer of the couple, for telling a dancer's couples apart; the whole couple when that is unclear.
    func partnerName(besides dancer: String?) -> String {
        let names = title.components(separatedBy: " & ")
        guard names.count == 2, let dancer else { return title }
        let others = names.filter { $0.compare(dancer, options: [.caseInsensitive, .diacriticInsensitive]) != .orderedSame }
        return others.count == 1 ? others[0] : title
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
    /// "STT", "LAT" or "10T".
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
    /// "Miesto:" from KSIS's results or marks page, the hall and its town; nil until one of them is read.
    let venue: String?
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
        case venue
        case rounds
        case judges
    }

    /// Marks and judges are stored as JSON: one that cannot be read (an older shape, a hand edit) takes only its
    /// own marks away, never the result, and a result never takes the others with it (`LossyList`).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        sutazId = try c.decode(Int.self, forKey: .sutazId)
        coupleId = try c.decode(Int.self, forKey: .coupleId)
        eventName = try c.decode(String.self, forKey: .eventName)
        categoryName = try c.decode(String.self, forKey: .categoryName)
        discipline = try c.decode(String.self, forKey: .discipline)
        date = try c.decode(String.self, forKey: .date)
        coupleCount = try c.decode(Int.self, forKey: .coupleCount)
        placementText = try c.decode(String.self, forKey: .placementText)
        placement = try c.decodeIfPresent(Int.self, forKey: .placement)
        pointsEarned = try c.decode(Int.self, forKey: .pointsEarned)
        cumulativeStats = try c.decodeIfPresent(String.self, forKey: .cumulativeStats)
        startNumber = try c.decodeIfPresent(String.self, forKey: .startNumber)
        venue = try c.decodeIfPresent(String.self, forKey: .venue)
        rounds = try? c.decodeIfPresent([KSISRound].self, forKey: .rounds)
        judges = try? c.decodeIfPresent([KSISJudge].self, forKey: .judges)
    }

    var dateValue: Date? { Self.isoDay.date(from: date) }

    /// "3. z 13", "12. – 13. z 16"
    var placeLine: String {
        let place = placementText.isEmpty ? placement.map { "\($0)." } ?? "–" : placementText
        return coupleCount > 0 ? "\(place) z \(coupleCount)" : place
    }

    var disciplineTitle: String { Self.disciplineTitle(of: discipline) }

    /// "STT", "LAT" or "10T" (the ten-dance of the Slovak championship).
    static func disciplineTitle(of code: String) -> String {
        switch code {
        case "LAT": return "Latina"
        case "10T": return "Desaťtance"
        default: return "Štandard"
        }
    }

    /// False for a WDSF result: KSIS lists it on the couple's page with the place and the number of couples only, so
    /// it has no results page and no crosses to read, and its number is made up here (negative).
    var hasKSISPage: Bool { sutazId > 0 }

    /// False in the ten-dance: KSIS gives no points for it (its "Body" is empty), so "+0 b" would claim the couple
    /// earned nothing.
    var givesPoints: Bool { discipline != "10T" }

    private static let isoDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

extension CompetitionResult {
    /// Made-up competitions for a loading skeleton, which draws the real row as blocks. They are never shown as data.
    static let placeholders: [CompetitionResult] = [
        "Pohár mesta Nitra", "Majstrovstvá Slovenska", "Vianočný turnaj", "Jarný pohár"
    ].map { CompetitionResult(placeholderName: $0) }

    private init(placeholderName: String) {
        id = UUID()
        sutazId = 0
        coupleId = 0
        eventName = placeholderName
        categoryName = "Dospelí Open · Štandard"
        discipline = "STT"
        date = "2026-01-01"
        coupleCount = 12
        placementText = "3."
        placement = 3
        pointsEarned = 0
        cumulativeStats = nil
        startNumber = nil
        venue = nil
        rounds = nil
        judges = nil
    }
}

/// A list read row by row: a row that cannot be read is left out instead of failing the whole list.
struct LossyList<Element: Decodable>: Decodable {
    let elements: [Element]
    /// Rows that were left out.
    let skipped: Int

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var kept: [Element] = []
        var skipped = 0
        while !container.isAtEnd {
            if let element = try? container.decode(Element.self) {
                kept.append(element)
            } else {
                skipped += 1
                _ = try? container.decode(AnyDecodable.self)
            }
        }
        elements = kept
        self.skipped = skipped
    }

    /// Steps over one value of any shape.
    private struct AnyDecodable: Decodable {
        init(from decoder: Decoder) throws {}
    }
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
        // Int(sum) stops the app for a number beyond Int: marks of a connection are read from their own saved page.
        return sum.rounded() == sum && abs(sum) < 1e9 ? String(Int(sum)) : sum.formatted(.number.precision(.fractionLength(1)))
    }

    static func scoreText(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(3)))
    }
}

struct KSISJudge: Codable, Equatable, Sendable, Identifiable {
    let letter: String
    let name: String?
    let city: String?
    /// Counted in "Suma" and in the final, but KSIS publishes neither the name nor the marks.
    let hidden: Bool
    /// "Tieňová porota": listed by KSIS with its own letters, but its marks are neither published nor in "Suma".
    var shadow: Bool? = nil

    var isShadow: Bool { shadow == true }
    var id: String { (isShadow ? "shadow-" : "") + letter }
}

// MARK: - `ksis-page` function
struct KSISPageRequest: Encodable, Sendable {
    let action: String
    var url: String? = nil
    var html: String? = nil
    var consent: Bool? = nil
    /// "Toto som ja" on the members list.
    var personNumber: Int? = nil
    /// The new couples ticked on the KSIS search; the dancer's other couples there are saved without asking.
    var parIds: [Int]? = nil
    /// Another name the dancer danced as ("Priezvisko Meno", a maiden name), for the KSIS search.
    var otherName: String? = nil
    /// The saved couple to unlink (`user_couples.id`).
    var coupleId: String? = nil
    var resultId: String? = nil
}

/// What the server read on the open KSIS page. Fields depend on `kind`.
struct KSISPageReply: Decodable, Sendable {
    enum Kind: String, Decodable, Sendable {
        case membersList = "members_list"
        case couplesList = "couples_list"
        case search
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

    /// One of the dancer's couples on the KSIS search, the ended ones too, with its KSIS id.
    struct FoundCouple: Decodable, Sendable, Identifiable {
        let parId: Int
        let partner: String
        let partnerka: String
        let club: String
        let competitions: Int
        let side: String
        /// "known", "claim" (saved, the id is new), "same" (a second id of a saved couple) or "new".
        let status: String

        var id: Int { parId }
        /// Not saved yet: needs the partner's yes, and a namesake abroad looks the same.
        var isNew: Bool { status == "new" }
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
        /// "Miesto:" of the page; nil when KSIS gives none.
        let venue: String?
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
    /// Search: the dancer's couples.
    let found: [FoundCouple]?
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
/// Picked in the members list, without verification: the owner unlinks a fake account on a report.
struct KSISDancer: Decodable, Equatable, Sendable {
    let personNumber: Int
    /// "Priezvisko Meno" as KSIS writes it.
    let name: String
    let club: String?

    enum CodingKeys: String, CodingKey {
        case name, club
        case personNumber = "person_number"
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
