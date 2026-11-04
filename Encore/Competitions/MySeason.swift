import Charts
import SwiftUI

// MARK: - Moja sezóna (Plus)
/// One season (September to August) of the couple's saved KSIS results, counted from the published judges'
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
        /// "STT" or "LAT".
        let code: String
        let dances: [DanceRate]
        let finals: [FinalPlacing]
        var id: String { code }
        var title: String { code == "LAT" ? "Latina" : "Štandard" }

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

    /// Year the season starts in (2026 = season 2026/27).
    let seasonStartYear: Int
    let competitions: Int
    let finals: Int
    let bestPlaceLine: String?
    let disciplines: [Discipline]
    let timeline: [Competition]

    var hasCrosses: Bool { disciplines.contains { !$0.dances.isEmpty } }

    /// "2026/27"
    var seasonTitle: String { "\(seasonStartYear)/\(String(format: "%02d", (seasonStartYear + 1) % 100))" }

    /// Seasons that have at least one saved result, newest first.
    static func seasons(in results: [CompetitionResult]) -> [Int] {
        Set(results.compactMap { result in result.dateValue.map { seasonStartYear(of: $0) } }).sorted(by: >)
    }

    static func seasonStartYear(of date: Date) -> Int {
        PlannerCalendar.calendar.component(.year, from: PlannerCalendar.seasonStart(of: date))
    }

    init(results: [CompetitionResult], seasonStartYear: Int) {
        self.seasonStartYear = seasonStartYear
        let season = results
            .filter { result in result.dateValue.map { Self.seasonStartYear(of: $0) } == seasonStartYear }
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

// MARK: - Screen
struct MySeasonView: View {
    let results: [CompetitionResult]

    @State private var season: Int

    init(results: [CompetitionResult]) {
        self.results = results
        _season = State(initialValue: SeasonStats.seasons(in: results).first
                        ?? SeasonStats.seasonStartYear(of: Date()))
    }

    var body: some View {
        ZStack {
            EllegancePageBackground()
            ScrollView {
                MySeasonContent(results: results, season: $season)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 120)
            }
        }
        .navigationTitle("Moja sezóna")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .sensoryFeedback(.selection, trigger: season)
    }
}

/// The season's numbers, dances and timeline; the bars grow in when the screen opens.
struct MySeasonContent: View {
    let results: [CompetitionResult]
    @Binding var season: Int
    var animatesIn = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private var seasons: [Int] { SeasonStats.seasons(in: results) }

    var body: some View {
        let stats = SeasonStats(results: results, seasonStartYear: season)
        VStack(alignment: .leading, spacing: 22) {
            seasonSwitcher(stats)
            tiles(stats)

            if stats.competitions == 0 {
                emptyCard("V tejto sezóne zatiaľ nemáš uložený žiadny výsledok.")
            } else if !stats.hasCrosses && stats.disciplines.allSatisfy({ $0.finals.isEmpty }) {
                emptyCard("Pri týchto súťažiach nemáš uložené krížiky. Otvor výsledok v KSIS a ulož ich, Moja sezóna sa dopočíta sama.")
            } else {
                ForEach(stats.disciplines) { discipline in
                    disciplineSection(discipline)
                }
                if stats.timeline.contains(where: { $0.rate != nil }) {
                    timelineSection(stats)
                }
            }

            Text("Počítané len z krížikov, ktoré KSIS zverejňuje. Skrytí porotcovia sa nerátajú. Hodnotíme tance, nie porotcov.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.45))
                .fixedSize(horizontal: false, vertical: true)
        }
        .onAppear {
            guard animatesIn else { appeared = true; return }
            withAnimation(reduceMotion ? nil : .spring(response: 0.8, dampingFraction: 0.85).delay(0.1)) { appeared = true }
        }
    }

    // MARK: Season
    private func seasonSwitcher(_ stats: SeasonStats) -> some View {
        HStack(spacing: 10) {
            seasonArrow("chevron.left", label: "Staršia sezóna", target: seasons.first { $0 < season })
            Spacer()
            VStack(spacing: 2) {
                Text("SEZÓNA")
                    .font(.system(.caption2, design: .rounded).weight(.black))
                    .tracking(1.4)
                    .foregroundColor(Color.gold400)
                Text(stats.seasonTitle)
                    .font(.system(.title, design: .rounded).weight(.heavy))
                    .foregroundColor(.white)
                    .contentTransition(.numericText(value: Double(season)))
            }
            Spacer()
            seasonArrow("chevron.right", label: "Novšia sezóna", target: seasons.last { $0 > season })
        }
    }

    private func seasonArrow(_ icon: String, label: String, target: Int?) -> some View {
        Button {
            guard let target else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { season = target }
        } label: {
            Image(systemName: icon)
                .font(.footnote.weight(.bold))
                .foregroundColor(Color.gold400)
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.07), in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressable(scale: 0.88))
        .opacity(target == nil ? 0.3 : 1)
        .disabled(target == nil)
        .accessibilityLabel(label)
    }

    private func tiles(_ stats: SeasonStats) -> some View {
        HStack(spacing: 10) {
            tile("\(stats.competitions)", "súťaží")
            tile("\(stats.finals)", "finále")
            tile(stats.bestPlaceLine ?? "–", "najlepšie")
        }
        .padding(14)
        .homeCard(cornerRadius: 20)
    }

    private func tile(_ value: String, _ caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.heavy))
                .foregroundColor(Color.gold300)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
            Text(caption)
                .font(.caption2.weight(.semibold))
                .foregroundColor(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: Dances
    private func disciplineSection(_ discipline: SeasonStats.Discipline) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if !discipline.dances.isEmpty {
                HomeSectionHeader(title: "\(discipline.title.uppercased()) · KRÍŽIKY", systemImage: "xmark.circle")
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(discipline.dances) { dance in
                        crossBar(dance, isWeakest: dance.id == discipline.weakest?.id)
                    }
                    if let weakest = discipline.weakest {
                        Label("Najviac rezerv: \(DanceNames.display(weakest.dance)). Tu dostávaš najmenej krížikov.",
                              systemImage: "target")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(Color.gold300)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)
                    }
                }
                .padding(14)
                .homeCard(cornerRadius: 20)
            }

            if !discipline.finals.isEmpty {
                HomeSectionHeader(title: "\(discipline.title.uppercased()) · VO FINÁLE", systemImage: "trophy.fill")
                    .padding(.top, 6)
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(discipline.finals) { final in
                        HStack {
                            Text(DanceNames.display(final.dance))
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                            Spacer()
                            Text(final.average.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "sk"))))
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                .monospacedDigit()
                                .foregroundColor(Color.gold300)
                        }
                        .accessibilityElement(children: .combine)
                    }
                    Text("Priemerné miesto, na ktoré ťa porotcovia vo finále dali. Menej je lepšie.")
                        .font(.caption)
                        .foregroundColor(Color.textSecondary)
                }
                .padding(14)
                .homeCard(cornerRadius: 20)
            }
        }
    }

    private func crossBar(_ dance: SeasonStats.DanceRate, isWeakest: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(DanceNames.display(dance.dance))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(Int((dance.rate * 100).rounded())) %")
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .monospacedDigit()
                    .foregroundColor(isWeakest ? Color.latinRed : Color.gold300)
                    .contentTransition(.numericText())
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(isWeakest
                              ? AnyShapeStyle(Color.latinRed)
                              : AnyShapeStyle(LinearGradient(colors: [Color.gold400, Color.gold500], startPoint: .leading, endPoint: .trailing)))
                        .frame(width: geo.size.width * (appeared ? dance.rate : 0))
                }
            }
            .frame(height: 8)
            .animation(.spring(response: 0.6, dampingFraction: 0.85), value: dance.rate)
            Text("\(dance.crosses) z \(dance.marks) krížikov")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.45))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(DanceNames.display(dance.dance)): \(Int((dance.rate * 100).rounded())) percent krížikov, \(dance.crosses) z \(dance.marks)")
    }

    // MARK: Timeline
    private func timelineSection(_ stats: SeasonStats) -> some View {
        let points = stats.timeline.filter { $0.rate != nil }
        return VStack(alignment: .leading, spacing: 10) {
            HomeSectionHeader(title: "VÝVOJ KRÍŽIKOV", systemImage: "chart.line.uptrend.xyaxis")
            VStack(alignment: .leading, spacing: 8) {
                Chart(points) { point in
                    LineMark(x: .value("Dátum", point.date), y: .value("Krížiky", (point.rate ?? 0) * 100))
                        .foregroundStyle(Color.gold400)
                        .interpolationMethod(.monotone)
                    PointMark(x: .value("Dátum", point.date), y: .value("Krížiky", (point.rate ?? 0) * 100))
                        .foregroundStyle(point.discipline == "LAT" ? Color.latinCrimson : Color.gold300)
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(values: [0, 50, 100]) { value in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                        AxisValueLabel { Text("\(value.as(Int.self) ?? 0) %").foregroundStyle(Color.textSecondary) }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).locale(Locale(identifier: "sk")))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                .frame(height: 180)
                .opacity(appeared ? 1 : 0)

                Text("Podiel krížikov na každej súťaži zo všetkých tancov a kôl.")
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)
            }
            .padding(14)
            .homeCard(cornerRadius: 20)
        }
    }

    private func emptyCard(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(.white.opacity(0.7))
            .fixedSize(horizontal: false, vertical: true)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .homeCard(cornerRadius: 20)
    }
}
