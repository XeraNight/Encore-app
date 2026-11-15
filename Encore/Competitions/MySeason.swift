import Foundation

// MARK: - Season numbers
/// One season (September to August), or all of them, of the couple's saved KSIS results, counted from the published judges'
/// marks only: how often judges gave a cross in each dance, how judges placed the couple per dance in finals,
/// and how the share of crosses moved from competition to competition. Dances are rated, never judges, and
/// nothing about classes or promotion is computed (that is SZTŠ's job).
struct SeasonStats: Equatable {
    struct DanceRate: Identifiable, Equatable {
        /// Stored dance name ("Viennese Waltz"), shown through `DanceNames.display`.
        let dance: String
        let crosses: Int
        let marks: Int
        var id: String { dance }
        var rate: Double { marks > 0 ? Double(crosses) / Double(marks) : 0 }
    }

    struct FinalPlacing: Identifiable, Equatable {
        let dance: String
        /// Average of the judges' placings in finals; lower is better.
        let average: Double
        let marks: Int
        var id: String { dance }
    }

    struct Discipline: Identifiable, Equatable {
        /// "STT", "LAT" or "10T".
        let code: String
        let dances: [DanceRate]
        let finals: [FinalPlacing]
        var id: String { code }
        var title: String { CompetitionResult.disciplineTitle(of: code) }

        /// The dance with the fewest crosses, worth the most practice; nil when all are equal.
        var weakest: DanceRate? {
            guard let low = dances.min(by: { $0.rate < $1.rate }),
                  let high = dances.max(by: { $0.rate < $1.rate }), high.rate - low.rate >= 0.05 else { return nil }
            return low
        }
    }

    struct Competition: Identifiable, Equatable {
        let id: UUID
        let date: Date
        let name: String
        let discipline: String
        /// Share of crosses over all dances and rounds; nil when the result has no crosses saved.
        let rate: Double?
        let placeLine: String
    }

    /// Year the season starts in (2026 = season 2026/27); nil for every season.
    let seasonStartYear: Int?
    let competitions: Int
    let finals: Int
    let bestPlaceLine: String?
    let disciplines: [Discipline]
    let timeline: [Competition]

    var hasCrosses: Bool { disciplines.contains { !$0.dances.isEmpty } }

    /// "2026/27"
    static func seasonTitle(_ startYear: Int) -> String { "\(startYear)/\(String(format: "%02d", (startYear + 1) % 100))" }

    /// Seasons that have at least one saved result, newest first.
    static func seasons(in results: [CompetitionResult]) -> [Int] {
        Set(results.compactMap { result in result.dateValue.map { seasonStartYear(of: $0) } }).sorted(by: >)
    }

    static func seasonStartYear(of date: Date) -> Int {
        PlannerCalendar.calendar.component(.year, from: PlannerCalendar.seasonStart(of: date))
    }

    init(results: [CompetitionResult], seasonStartYear: Int?) {
        self.seasonStartYear = seasonStartYear
        let season = results
            .filter { result in
                seasonStartYear == nil || result.dateValue.map { Self.seasonStartYear(of: $0) } == seasonStartYear
            }
            .sorted { ($0.dateValue ?? .distantPast) < ($1.dateValue ?? .distantPast) }

        competitions = season.count
        finals = season.filter { $0.rounds?.contains(where: \.isFinal) == true }.count
        bestPlaceLine = season
            .filter { $0.placement != nil }
            .min { ($0.placement ?? .max, -$0.coupleCount) < ($1.placement ?? .max, -$1.coupleCount) }?
            .placeLine

        var crosses: [String: [String: (x: Int, all: Int)]] = [:]
        var placings: [String: [String: (sum: Int, count: Int)]] = [:]
        var timeline: [Competition] = []

        for result in season {
            var resultX = 0, resultAll = 0
            for round in result.rounds ?? [] {
                for dance in round.dances {
                    let name = DanceNames.stored(fromKSIS: dance.dance)
                    if round.isFinal {
                        let places = dance.marks.compactMap { Int($0.mark) }
                        var entry = placings[result.discipline, default: [:]][name, default: (0, 0)]
                        entry.sum += places.reduce(0, +)
                        entry.count += places.count
                        placings[result.discipline, default: [:]][name] = entry
                    } else {
                        // Only marks KSIS publishes: "X" is a cross, "." is none. Hidden judges are not counted.
                        let marks = dance.marks.map { $0.mark.trimmingCharacters(in: .whitespaces).uppercased() }
                            .filter { $0 == "X" || $0 == "." }
                        let x = marks.filter { $0 == "X" }.count
                        var entry = crosses[result.discipline, default: [:]][name, default: (0, 0)]
                        entry.x += x
                        entry.all += marks.count
                        crosses[result.discipline, default: [:]][name] = entry
                        resultX += x
                        resultAll += marks.count
                    }
                }
            }
            if let date = result.dateValue {
                timeline.append(Competition(
                    id: result.id, date: date, name: result.eventName, discipline: result.discipline,
                    rate: resultAll > 0 ? Double(resultX) / Double(resultAll) : nil, placeLine: result.placeLine
                ))
            }
        }

        let codes = Set(crosses.keys).union(placings.keys).sorted { $0 == "STT" && $1 != "STT" }
        disciplines = codes.map { code in
            Discipline(
                code: code,
                dances: (crosses[code] ?? [:])
                    .filter { $0.value.all > 0 }
                    .map { DanceRate(dance: $0.key, crosses: $0.value.x, marks: $0.value.all) }
                    .sorted { DanceNames.rank($0.dance) < DanceNames.rank($1.dance) },
                finals: (placings[code] ?? [:])
                    .filter { $0.value.count > 0 }
                    .map { FinalPlacing(dance: $0.key, average: Double($0.value.sum) / Double($0.value.count), marks: $0.value.count) }
                    .sorted { DanceNames.rank($0.dance) < DanceNames.rank($1.dance) }
            )
        }
        self.timeline = timeline
    }
}

extension DanceNames {
    /// KSIS writes dances in capitals ("VIENNESE WALTZ", "CHA-CHA-CHA", sometimes "SLOWFOX"); Encore stores
    /// them as in `order`. Unknown names come back as KSIS wrote them.
    static func stored(fromKSIS name: String) -> String {
        func key(_ text: String) -> String { text.uppercased().filter { $0.isLetter } }
        let wanted = key(name)
        guard !wanted.isEmpty else { return name }
        return order.first { key($0) == wanted || key($0).hasPrefix(wanted) || wanted.hasPrefix(key($0)) } ?? name
    }
}
