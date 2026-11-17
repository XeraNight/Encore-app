import Charts
import SwiftUI

// MARK: - Štandard / Latina / Desaťtance
/// One couple in one discipline: class and points as KSIS has them, the Slovenský pohár, and with Plus where the
/// couple placed, how each dance fared and who judged it. Only what KSIS publishes is counted: dances are rated,
/// judges are listed by how often they judged the couple, never ranked. The ten-dance has no class, points or cup in
/// KSIS, so it shows none of the three.
struct DisciplineStatsView: View {
    let couple: UserCouple
    /// "STT", "LAT" or "10T".
    let discipline: String

    @ObservedObject private var manager = CompetitionManager.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @ObservedObject private var cupStore = SlovakCupStore.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Everything by default; a season picked stays picked.
    @AppStorage("disciplineStatsScope") private var scope = Scope.all
    @State private var chartShowsCrosses = false
    @State private var pickedDate: Date?
    @State private var pickedId: UUID?
    @State private var openJudge: String?
    /// The town picked on the map of where the couple danced.
    @State private var pickedTown: String?
    @State private var showsAllJudges = false
    @State private var selectedResult: CompetitionResult?
    @State private var browser: KSISBrowserTarget?
    @State private var showPaywall = false
    @State private var appeared = false

    private enum Scope: String, CaseIterable {
        case all, season, previous

        var title: String {
            switch self {
            case .all: return "Celkovo"
            case .season: return "Táto sezóna"
            case .previous: return "Minulá sezóna"
            }
        }
    }

    /// " · 2026/27" on every section while one season is picked, so a short list never looks like all of them.
    private var scopeSuffix: String {
        seasonYear.map { " · \(SeasonStats.seasonTitle($0))" } ?? ""
    }

    /// One point in the chart: a competition with its place or its share of crosses.
    private struct Point: Identifiable {
        let id: UUID
        let date: Date
        let value: Double
    }

    private var title: String { CompetitionResult.disciplineTitle(of: discipline) }
    private var isTenDance: Bool { discipline == "10T" }
    /// The discipline as the "in …" of a sentence.
    private var inDiscipline: String { isTenDance ? "desaťtancoch" : discipline == "LAT" ? "latine" : "štandarde" }
    private var standing: UserCouple.Standing { discipline == "LAT" ? couple.lat : couple.stt }
    private var hasPlus: Bool { subscriptionManager.currentTier >= .plus }
    private var spring: Animation? { reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85) }

    private var seasonYear: Int? {
        let now = SeasonStats.seasonStartYear(of: Date())
        switch scope {
        case .season: return now
        case .previous: return now - 1
        case .all: return nil
        }
    }

    /// The discipline's competitions in the scope, newest first.
    private var results: [CompetitionResult] {
        manager.results(for: couple)
            .filter { $0.discipline == discipline }
            .filter { result in seasonYear == nil || result.dateValue.map { SeasonStats.seasonStartYear(of: $0) } == seasonYear }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        let results = results
        let stats = SeasonStats(results: results, seasonStartYear: nil)
        ZStack {
            EllegancePageBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if !isTenDance { standingCard }
                    scopePicker
                    tiles(results, stats)
                    if !isTenDance { cupSection }
                    if results.isEmpty {
                        note("V tomto období nemáte v \(inDiscipline) uloženú žiadnu súťaž.")
                    } else if hasPlus {
                        chartCard(results, stats)
                        dancesSection(stats)
                        judgesSection(results)
                        placesSection(results)
                    } else {
                        plusCard
                    }
                    if !results.isEmpty { competitionsSection(results) }
                    footnote(results)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 120)
                .animation(spring, value: scope)
                .animation(spring, value: chartShowsCrosses)
            }
            .softTopEdge()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: scope)
        .sensoryFeedback(.selection, trigger: pickedId)
        .onChange(of: scope) { _, _ in
            pickedId = nil
            pickedTown = nil
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.8, dampingFraction: 0.85).delay(0.1)) { appeared = true }
        }
        .sheet(item: $selectedResult) { result in
            KSISResultDetailView(result: result) { url in
                selectedResult = nil
                browser = KSISBrowserTarget(url: url)
            }
        }
        .fullScreenCover(item: $browser) { KSISBrowserView(startURL: $0.url) }
        .sheet(isPresented: $showPaywall) { SubscriptionPaywallView(initialTier: .plus) }
        .preferredColorScheme(.dark)
    }

    // MARK: Class and points
    private var standingCard: some View {
        HStack(alignment: .center, spacing: 16) {
            Text(standing.className ?? "–")
                .font(.system(size: 52, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .frame(minWidth: 56)
            VStack(alignment: .leading, spacing: 5) {
                Text(couple.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                HStack(spacing: 12) {
                    Label(standing.points.map { slovakCount($0, one: "bod", few: "body", many: "bodov") } ?? "– bodov",
                          systemImage: "star.fill")
                    Label("\(standing.finals.map(String.init) ?? "–") finále", systemImage: "rosette")
                }
                .font(.caption.weight(.bold))
                .foregroundColor(.white.opacity(0.8))
                if let change = standing.lastChange.flatMap({ KSISBrowserView.displayDate($0, numeric: true) }) {
                    Text("Zmena triedy alebo bodov \(change)")
                        .font(.caption2)
                        .foregroundColor(Color.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .homeCard(cornerRadius: 20)
        .accessibilityElement(children: .combine)
    }

    // MARK: Period
    private var scopePicker: some View {
        HStack(spacing: 8) {
            ForEach(Scope.allCases, id: \.self) { item in
                Button { scope = item } label: { FilterChip(title: item.title, isOn: scope == item) }
                    .buttonStyle(.pressable)
            }
        }
    }

    private func tiles(_ results: [CompetitionResult], _ stats: SeasonStats) -> some View {
        HStack(spacing: 10) {
            tile("\(results.count)", "súťaží")
            tile("\(results.filter { ($0.placement ?? .max) <= 3 }.count)", "na pódiu")
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

    // MARK: Slovenský pohár
    /// The last table read from KSIS, with the couple's row; only for couples in the cup in this discipline.
    @ViewBuilder
    private var cupSection: some View {
        let cupDiscipline: SlovakCup.Discipline = discipline == "LAT" ? .latin : .standard
        if let group = SlovakCup.Group(ageCategory: couple.ageCategory),
           SlovakCup.disciplines(for: couple).contains(cupDiscipline) {
            let saved = cupStore.standings(group: group, discipline: cupDiscipline)
            let entry = saved.flatMap { SlovakCup.entry(in: $0.standings, for: couple) }
            VStack(alignment: .leading, spacing: 10) {
                HomeSectionHeader(title: "SLOVENSKÝ POHÁR", systemImage: "trophy.fill")
                VStack(alignment: .leading, spacing: 12) {
                    if let saved, let entry {
                        SlovakCupStatusView(status: SlovakCup.status(of: entry, in: saved.standings, group: group),
                                            showsChampionship: group == .adults || (couple.ageCategory ?? "").contains("II"))
                        SlovakCupTable(standings: saved.standings, own: entry.parId)
                    } else {
                        Text(saved == nil ? "Poradie sa načíta pri Aktualizovať z KSIS." : "V tomto poradí zatiaľ nie ste.")
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    HStack {
                        if let saved {
                            Text("Načítané \(EncoreTime.dayAndClock(saved.readAt))")
                                .font(.caption)
                                .foregroundColor(Color.textSecondary)
                        }
                        Spacer(minLength: 8)
                        Button {
                            if let url = SlovakCup.standingsURL(group: group, discipline: cupDiscipline) {
                                browser = KSISBrowserTarget(url: url)
                            }
                        } label: {
                            Label("Poradie v KSIS", systemImage: "list.number")
                                .font(.caption.weight(.bold))
                                .foregroundColor(Color.gold400)
                                .frame(minHeight: 36)
                        }
                        .buttonStyle(.pressable)
                    }
                }
                .padding(14)
                .homeCard(cornerRadius: 20)
            }
        }
    }

    // MARK: Plus
    private var plusCard: some View {
        Button { showPaywall = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.title3)
                    .foregroundColor(Color.gold400)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Grafy, krížiky a porotcovia")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.white)
                    Text("Umiestnenia v čase, krížiky podľa tancov a kto vás hodnotil.")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Text("PLUS")
                    .font(.caption2.weight(.black))
                    .foregroundColor(Color.obsidian900)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.gold400, in: Capsule())
            }
            .padding(16)
            .homeCard(cornerRadius: 20)
        }
        .buttonStyle(.pressable(scale: 0.98))
    }

    // MARK: Chart
    private func chartCard(_ results: [CompetitionResult], _ stats: SeasonStats) -> some View {
        let points: [Point] = chartShowsCrosses
            ? stats.timeline.compactMap { item in item.rate.map { Point(id: item.id, date: item.date, value: $0 * 100) } }
            : results.compactMap { result in
                guard let date = result.dateValue, let place = result.placement else { return nil }
                return Point(id: result.id, date: date, value: Double(place))
            }
        let picked = results.first { $0.id == pickedId }
        return VStack(alignment: .leading, spacing: 10) {
            HomeSectionHeader(title: (chartShowsCrosses ? "KRÍŽIKY" : "UMIESTNENIA") + scopeSuffix, systemImage: "chart.xyaxis.line") {
                GoldModeSwitch(isSecond: $chartShowsCrosses, first: ("list.number", "Miesto"), second: ("xmark.square", "Krížiky"))
            }
            VStack(alignment: .leading, spacing: 10) {
                if points.isEmpty {
                    Text(chartShowsCrosses ? "Krížiky zatiaľ nie sú uložené." : "Pri týchto súťažiach chýba umiestnenie.")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.7))
                } else {
                    chart(points)
                        .opacity(appeared ? 1 : 0)
                    if let picked {
                        Button { selectedResult = picked } label: {
                            CompetitionResultRow(result: picked, isMissingMarks: manager.isMissingMarks(picked))
                                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.pressable(scale: 0.98))
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    } else {
                        Text(chartShowsCrosses ? "Podiel krížikov zo všetkých tancov a kôl. Ťukni na bod a uvidíš súťaž."
                             : "Ťukni na bod a uvidíš súťaž.")
                            .font(.caption)
                            .foregroundColor(Color.textSecondary)
                    }
                }
            }
            .padding(14)
            .homeCard(cornerRadius: 20)
            .animation(spring, value: pickedId)
        }
    }

    private func chart(_ points: [Point]) -> some View {
        Chart(points) { point in
            LineMark(x: .value("Dátum", point.date), y: .value("Hodnota", point.value))
                .foregroundStyle(Color.gold400.opacity(0.55))
                .interpolationMethod(.monotone)
            PointMark(x: .value("Dátum", point.date), y: .value("Hodnota", point.value))
                .foregroundStyle(point.id == pickedId ? Color.encoreCrimsonLight : Color.gold300)
                .symbolSize(point.id == pickedId ? 140 : 50)
        }
        .chartYScale(domain: chartShowsCrosses ? .automatic(includesZero: true) : .automatic(includesZero: false, reversed: true))
        .chartYAxis {
            AxisMarks(position: .trailing, values: yTicks(points)) { value in
                AxisGridLine().foregroundStyle(ChartAxisText.grid)
                AxisValueLabel {
                    let number = value.as(Double.self).map { Int($0.rounded()) } ?? 0
                    ChartAxisText(chartShowsCrosses ? "\(number) %" : "\(number).")
                }
            }
        }
        .chartXAxis {
            let dates = Set([points.map(\.date).min(), points.map(\.date).max()].compactMap { $0 }).sorted()
            let spansYear = (dates.last?.timeIntervalSince(dates.first ?? .now) ?? 0) > 300 * 24 * 3600
            AxisMarks(values: dates) { value in
                // The first date starts at its point and the last one ends at its point, so neither runs off the card.
                AxisValueLabel(anchor: dates.count == 1 ? .top : value.index == 0 ? .topLeading : .topTrailing) {
                    if let date = value.as(Date.self) { ChartAxisText(Self.axisDate(date, withYear: spansYear)) }
                }
            }
        }
        .chartXScale(range: .plotDimension(padding: 18))
        .chartXSelection(value: $pickedDate)
        .onChange(of: pickedDate) { _, date in
            guard let date else { return }
            pickedId = points.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }?.id
        }
        .frame(height: 190)
        .accessibilityLabel(chartShowsCrosses ? "Podiel krížikov v čase" : "Umiestnenia v čase")
    }

    /// Whole places only, a few of them, best at the top; the share of crosses at 0, 50 and 100 %.
    private func yTicks(_ points: [Point]) -> [Double] {
        if chartShowsCrosses { return [0, 50, 100] }
        let places = points.map { Int($0.value) }
        guard let best = places.min(), let worst = places.max() else { return [] }
        let step = max(1, Int((Double(worst - best) / 3).rounded(.up)))
        var ticks = Array(stride(from: best, through: worst, by: step))
        if ticks.last != worst { ticks.append(worst) }
        return ticks.map(Double.init)
    }

    /// "7. 9." within a year, "9/24" over a longer time: short enough for the first and last date to fit.
    private static func axisDate(_ date: Date, withYear: Bool) -> String {
        let parts = PlannerCalendar.calendar.dateComponents([.day, .month, .year], from: date)
        let day = parts.day ?? 0, month = parts.month ?? 0, year = (parts.year ?? 0) % 100
        return withYear ? "\(month)/\(String(format: "%02d", year))" : "\(day). \(month)."
    }

    // MARK: Dances
    @ViewBuilder
    private func dancesSection(_ stats: SeasonStats) -> some View {
        if let rated = stats.disciplines.first {
            if !rated.dances.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HomeSectionHeader(title: "KRÍŽIKY PODĽA TANCOV" + scopeSuffix, systemImage: "xmark.circle")
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(rated.dances) { dance in
                            crossBar(dance, isWeakest: dance.id == rated.weakest?.id)
                        }
                        if let weakest = rated.weakest {
                            Label("Najviac rezerv: \(DanceNames.display(weakest.dance)). Tu dostávate najmenej krížikov.",
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
            }
            if !rated.finals.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HomeSectionHeader(title: "VO FINÁLE" + scopeSuffix, systemImage: "trophy.fill")
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(rated.finals) { final in
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
                        Text("Priemerné miesto, na ktoré vás porotcovia vo finále dali. Menej je lepšie.")
                            .font(.caption)
                            .foregroundColor(Color.textSecondary)
                    }
                    .padding(14)
                    .homeCard(cornerRadius: 20)
                }
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

    // MARK: Judges
    @ViewBuilder
    private func judgesSection(_ results: [CompetitionResult]) -> some View {
        let judges = JudgeStat.all(in: results)
        if !judges.isEmpty {
            let shown = showsAllJudges ? judges : Array(judges.prefix(8))
            VStack(alignment: .leading, spacing: 10) {
                HomeSectionHeader(title: "POROTCOVIA" + scopeSuffix, systemImage: "person.3.fill", count: judges.count)
                VStack(spacing: 0) {
                    ForEach(shown) { judge in
                        judgeRow(judge)
                        if judge.id != shown.last?.id { HomeRowDivider() }
                    }
                    if judges.count > shown.count {
                        HomeRowDivider()
                        Button {
                            withAnimation(spring) { showsAllJudges = true }
                        } label: {
                            Text("Všetci porotcovia (\(judges.count))")
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(Color.gold400)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.pressable)
                    }
                }
                .homeCard(cornerRadius: 20)
                Text("Každý porotca, ktorý vás hodnotil, podľa toho, koľkokrát. Ťukni a uvidíš kde a ako, ako to KSIS zverejňuje.")
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func judgeRow(_ judge: JudgeStat) -> some View {
        let isOpen = openJudge == judge.id
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(spring) { openJudge = isOpen ? nil : judge.id }
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(judge.name)
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.white)
                        if let city = judge.city, !city.isEmpty {
                            Text(city)
                                .font(.caption)
                                .foregroundColor(Color.textSecondary)
                        }
                    }
                    Spacer(minLength: 8)
                    Text("\(judge.competitions.count)×")
                        .font(.system(.subheadline, design: .rounded).weight(.heavy))
                        .monospacedDigit()
                        .foregroundColor(Color.gold300)
                        .accessibilityLabel("Hodnotil vás \(judge.competitions.count)×")
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white.opacity(0.4))
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressable(scale: 0.98))
            .accessibilityHint(isOpen ? "Skryť súťaže" : "Ukázať súťaže")

            if isOpen {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(judge.competitions) { judged in
                        Button { selectedResult = judged.result } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text(judged.result.dateValue?.formatted(.dateTime.day().month(.defaultDigits).year(.twoDigits)) ?? "")
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(Color.textSecondary)
                                    .frame(width: 62, alignment: .leading)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(judged.result.eventName)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.85))
                                        .lineLimit(1)
                                    if let town = ResultPlacesMap.town(of: judged.result) {
                                        Text(town)
                                            .font(.caption2)
                                            .foregroundColor(Color.textSecondary)
                                    }
                                }
                                Spacer(minLength: 6)
                                VStack(alignment: .trailing, spacing: 1) {
                                    if judged.marks > 0 {
                                        Text("\(judged.crosses) z \(judged.marks) ✕")
                                    }
                                    if let final = judged.finalAverage {
                                        Text("finále Ø \(final.formatted(.number.precision(.fractionLength(0...1)).locale(Locale(identifier: "sk"))))")
                                    }
                                }
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundColor(Color.gold300)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.pressable(scale: 0.98))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: Places
    /// Where the couple danced, from KSIS's "Miesto:", which comes with the results and crosses pages. A tap on a town
    /// picks its competitions in the list below.
    @ViewBuilder
    private func placesSection(_ results: [CompetitionResult]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HomeSectionHeader(title: "KDE STE TANCOVALI" + scopeSuffix, systemImage: "map")
            ResultPlacesMap(results: results, town: $pickedTown)
        }
        .animation(spring, value: pickedTown)
        .sensoryFeedback(.selection, trigger: pickedTown)
    }

    // MARK: Competitions
    private func competitionsSection(_ all: [CompetitionResult]) -> some View {
        let results = pickedTown.map { town in all.filter { ResultPlacesMap.town(of: $0) == town } } ?? all
        return VStack(alignment: .leading, spacing: 10) {
            HomeSectionHeader(title: (pickedTown.map { "SÚŤAŽE · \($0.uppercased())" } ?? "SÚŤAŽE") + scopeSuffix,
                              systemImage: "list.bullet", count: results.count)
            VStack(spacing: 0) {
                ForEach(results) { result in
                    Button { selectedResult = result } label: {
                        CompetitionResultRow(result: result, isMissingMarks: manager.isMissingMarks(result))
                    }
                    .buttonStyle(.pressable(scale: 0.98))
                    if result.id != results.last?.id { HomeRowDivider() }
                }
            }
            .homeCard(cornerRadius: 20)
        }
    }

    private func footnote(_ results: [CompetitionResult]) -> some View {
        let missing = results.filter(manager.isMissingMarks).count
        var text = "Počítané len z toho, čo KSIS zverejňuje. Skrytí porotcovia sa nerátajú."
        if missing > 0 {
            text += " Krížiky chýbajú pri \(slovakCount(missing, one: "súťaži", few: "súťažiach", many: "súťažiach")), dočítaš ich cez Aktualizovať z KSIS."
        }
        return Text(text)
            .font(.caption)
            .foregroundColor(.white.opacity(0.45))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(.white.opacity(0.7))
            .fixedSize(horizontal: false, vertical: true)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .homeCard(cornerRadius: 20)
    }
}

// MARK: - Who judged the couple
/// Every judge who gave the couple a mark, in any round, as KSIS publishes it: how often and where, never who was
/// kind. The shadow jury and judges KSIS keeps hidden have no marks, so they are not here.
struct JudgeStat: Identifiable {
    struct Judged: Identifiable {
        let result: CompetitionResult
        /// Crosses and marks from the rounds before the final.
        let crosses: Int
        let marks: Int
        /// The judge's places for the couple in the final, one per dance; empty when the couple was not in it.
        let finalPlaces: [Int]
        var id: UUID { result.id }

        var finalAverage: Double? {
            finalPlaces.isEmpty ? nil : Double(finalPlaces.reduce(0, +)) / Double(finalPlaces.count)
        }
    }

    let name: String
    let city: String?
    var competitions: [Judged]

    var id: String { name }

    /// Most competitions first, then by name.
    static func all(in results: [CompetitionResult]) -> [JudgeStat] {
        var byName: [String: JudgeStat] = [:]
        for result in results {
            let published = (result.judges ?? []).filter { !$0.hidden && !$0.isShadow }
            let names = Dictionary(published.compactMap { judge in judge.name.map { (judge.letter, $0) } },
                                   uniquingKeysWith: { first, _ in first })
            var tallies: [String: (crosses: Int, marks: Int, places: [Int])] = [:]
            for round in result.rounds ?? [] where !round.isScores {
                for dance in round.dances {
                    for mark in dance.marks {
                        guard let name = mark.name ?? mark.letter.flatMap({ names[$0] }) else { continue }
                        let value = mark.mark.trimmingCharacters(in: .whitespaces).uppercased()
                        var tally = tallies[name, default: (0, 0, [])]
                        if round.isFinal {
                            guard let place = Int(value) else { continue }
                            tally.places.append(place)
                        } else {
                            guard value == "X" || value == "." else { continue }
                            tally.marks += 1
                            if value == "X" { tally.crosses += 1 }
                        }
                        tallies[name] = tally
                    }
                }
            }
            for (name, tally) in tallies {
                let city = published.first { $0.name == name }?.city
                byName[name, default: JudgeStat(name: name, city: city, competitions: [])].competitions
                    .append(Judged(result: result, crosses: tally.crosses, marks: tally.marks, finalPlaces: tally.places))
            }
        }
        return byName.values.sorted { first, second in
            first.competitions.count != second.competitions.count
                ? first.competitions.count > second.competitions.count
                : first.name.localizedCompare(second.name) == .orderedAscending
        }
    }
}

// MARK: - Slovenský pohár table
/// The leaders and the couple's own row, as KSIS ranks them.
struct SlovakCupTable: View {
    let standings: SlovakCupStandings
    let own: Int

    private static let leaders = 10

    var body: some View {
        let top = Array(standings.entries.prefix(Self.leaders))
        let ownEntry = standings.entries.first { $0.parId == own }
        VStack(spacing: 0) {
            ForEach(top) { row($0) }
            if let ownEntry, !top.contains(where: { $0.parId == own }) {
                Text("…")
                    .font(.caption.weight(.bold))
                    .foregroundColor(Color.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 20)
                row(ownEntry)
            }
        }
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func row(_ entry: SlovakCupStandings.Entry) -> some View {
        let isOwn = entry.parId == own
        return HStack(spacing: 10) {
            Text(entry.place?.display ?? "–")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundColor(isOwn ? Color.obsidian900 : Color.textSecondary)
                .frame(width: 44, alignment: .leading)
            Text("\(entry.partner) & \(entry.partnerka)")
                .font(.caption.weight(isOwn ? .bold : .regular))
                .foregroundColor(isOwn ? Color.obsidian900 : .white.opacity(0.85))
                .lineLimit(1)
            Spacer(minLength: 6)
            Text("\(entry.total)")
                .font(.caption.weight(.heavy).monospacedDigit())
                .foregroundColor(isOwn ? Color.obsidian900 : Color.gold300)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background {
            if isOwn { RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.gold400) }
        }
        .accessibilityElement(children: .combine)
    }
}
