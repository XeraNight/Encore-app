import SwiftUI

// MARK: - Moje výsledky
/// Every competition saved from KSIS, readable here without internet. With more couples the current one comes first:
/// "Aktuálny pár" stays on until the dancer turns it off, then the results split by partner. One tap saves all that
/// KSIS has for the dancer, and KSIS's own results are one tap away.
struct MyResultsView: View {
    @ObservedObject private var manager = CompetitionManager.shared
    @AppStorage("resultsCurrentCoupleOnly") private var currentCoupleOnly = true
    @AppStorage("competitionResultsAsCalendar") private var showsCalendar = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The partner picked while "Aktuálny pár" is off; nil means all couples.
    @State private var pickedCouple: UUID?
    @State private var resultsFilter: ResultsFilter?
    @State private var selectedResult: CompetitionResult?
    @State private var browser: KSISBrowserTarget?
    @State private var updateJob: KSISUpdateJob?

    private enum ResultsFilter: Hashable {
        case discipline(String)
        case category(String)
    }

    private var spring: Animation? { reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82) }

    private var hasSeveralCouples: Bool { manager.couples.count > 1 }
    private var showsCurrentCoupleOnly: Bool { hasSeveralCouples && currentCoupleOnly && manager.activeCouple != nil }

    private var coupleResults: [CompetitionResult] {
        if showsCurrentCoupleOnly, let couple = manager.activeCouple { return manager.results(for: couple) }
        if hasSeveralCouples, let couple = manager.couples.first(where: { $0.id == pickedCouple }) {
            return manager.results(for: couple)
        }
        return manager.results
    }

    private var shown: [CompetitionResult] {
        switch resultsFilter {
        case nil: return coupleResults
        case .discipline(let discipline): return coupleResults.filter { $0.discipline == discipline }
        case .category(let category): return coupleResults.filter { $0.categoryName == category }
        }
    }

    /// The categories danced, the latest first.
    private var categories: [String] {
        var seen = Set<String>()
        return coupleResults.map(\.categoryName).filter { seen.insert($0).inserted }
    }

    private var couplesWithoutHistory: [UserCouple] { manager.couples.filter { $0.coupleId == nil } }

    var body: some View {
        ZStack {
            EllegancePageBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if hasSeveralCouples { couplePicker }
                    if !manager.results.isEmpty { summary }
                    actions
                    if !couplesWithoutHistory.isEmpty { missingHistory }
                    if !coupleResults.isEmpty { filters }
                    results
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 120)
                .animation(spring, value: resultsFilter)
                .animation(spring, value: currentCoupleOnly)
                .animation(spring, value: pickedCouple)
                .animation(spring, value: showsCalendar)
            }
            .refreshable { await manager.loadAllData() }
        }
        .navigationTitle("Moje výsledky")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: resultsFilter)
        .sensoryFeedback(.selection, trigger: pickedCouple)
        .sensoryFeedback(.impact(weight: .light), trigger: currentCoupleOnly)
        .fullScreenCover(item: $browser) { KSISBrowserView(startURL: $0.url) }
        .fullScreenCover(item: $updateJob) { KSISUpdateSheet(job: $0) }
        .sheet(item: $selectedResult) { result in
            KSISResultDetailView(result: result) { url in
                selectedResult = nil
                browser = KSISBrowserTarget(url: url)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Couples
    private var couplePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let current = manager.activeCouple {
                Toggle(isOn: $currentCoupleOnly) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Aktuálny pár")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.white)
                        Text(current.partnerName(besides: manager.dancer?.name))
                            .font(.caption)
                            .foregroundColor(Color.textSecondary)
                    }
                }
                .tint(Color.gold500)
                .onChange(of: currentCoupleOnly) { _, _ in resetFilters() }
            }
            if !showsCurrentCoupleOnly {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        coupleChip("Všetky páry", id: nil)
                        ForEach(manager.couples) { couple in
                            coupleChip(couple.partnerName(besides: manager.dancer?.name), id: couple.id)
                        }
                    }
                }
                .scrollClipDisabled()
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .homeCard(cornerRadius: 20)
    }

    private func coupleChip(_ title: String, id: UUID?) -> some View {
        Button {
            pickedCouple = id
            resetFilters()
        } label: {
            FilterChip(title: title, isOn: pickedCouple == id)
        }
        .buttonStyle(.pressable)
    }

    /// A category of one couple may not exist at another.
    private func resetFilters() {
        resultsFilter = nil
    }

    // MARK: Summary
    private var summary: some View {
        HStack(spacing: 10) {
            stat(shown.count, caption: "súťaží")
            stat(shown.filter { ($0.placement ?? .max) <= 3 }.count, caption: "na pódiu")
            stat(shown.map(\.pointsEarned).reduce(0, +), caption: "získané body")
        }
    }

    private func stat(_ value: Int, caption: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(.title3, design: .rounded).weight(.heavy))
                .foregroundColor(.white)
                .contentTransition(.numericText())
            Text(caption)
                .font(.caption2)
                .foregroundColor(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .homeCard(cornerRadius: 16)
        .accessibilityElement(children: .combine)
    }

    // MARK: Saving and KSIS
    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 8) {
            if manager.dancer != nil {
                PrimarySheetButton(title: "Uložiť všetky moje výsledky", isLoading: false, isEnabled: true) { updateJob = .everything }
            } else {
                Text("Najprv sa nájdi v KSIS na obrazovke Súťaže. Potom sa tu uložia všetky tvoje výsledky.")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.75))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button {
                if let url = KSISBrowserView.page("menu.php?akcia=S") { browser = KSISBrowserTarget(url: url) }
            } label: {
                Label("Všetky výsledky v KSIS", systemImage: "safari")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color.gold400)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.pressable)
            let missing = manager.results.filter(manager.isMissingMarks).count
            if missing > 0 {
                Label("Krížiky chýbajú pri \(slovakCount(missing, one: "súťaži", few: "súťažiach", many: "súťažiach"))", systemImage: "square.dashed")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Color.gold300)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// KSIS links a couple's page only from its results, so one competition has to be opened first.
    private var missingHistory: some View {
        Button {
            if let url = KSISBrowserView.page("menu.php?akcia=S") { browser = KSISBrowserTarget(url: url) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "clock.badge.questionmark")
                    .foregroundColor(Color.gold400)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Chýba história: \(couplesWithoutHistory.map { $0.partnerName(besides: manager.dancer?.name) }.joined(separator: ", "))")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.white)
                    Text("Otvor v KSIS jednu súťaž tohto páru a ťukni Uložiť všetky súťaže páru.")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(14)
            .homeCard(cornerRadius: 20)
        }
        .buttonStyle(.pressable(scale: 0.98))
    }

    // MARK: Filters
    private var filters: some View {
        HStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip("Všetko", nil)
                    chip("ŠTT", .discipline("STT"))
                    chip("LAT", .discipline("LAT"))
                    ForEach(categories, id: \.self) { chip($0, .category($0)) }
                }
            }
            .scrollClipDisabled()
            GoldModeSwitch(isSecond: $showsCalendar, first: ("list.bullet", "Zoznam"), second: ("calendar", "Kalendár"))
        }
    }

    private func chip(_ title: String, _ value: ResultsFilter?) -> some View {
        Button {
            resultsFilter = value
        } label: {
            FilterChip(title: title, isOn: resultsFilter == value)
        }
        .buttonStyle(.pressable)
    }

    // MARK: Results
    @ViewBuilder
    private var results: some View {
        if shown.isEmpty {
            // With a couple missing its history, the card above already says what to do.
            if couplesWithoutHistory.isEmpty || manager.loadFailed {
                Text(manager.loadFailed
                     ? "Výsledky sa nepodarilo načítať. Potiahni obrazovku nadol a skús znova."
                     : "Zatiaľ žiadne. Ťukni Uložiť všetky moje výsledky.")
                    .font(.footnote)
                    .foregroundColor(Color.textSecondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .homeCard(cornerRadius: 20)
            }
        } else if showsCalendar {
            CompetitionCalendarView(results: shown) { selectedResult = $0 }
                .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
        } else {
            let years = Dictionary(grouping: shown) { String($0.date.prefix(4)) }
            ForEach(years.keys.sorted(by: >), id: \.self) { year in
                VStack(alignment: .leading, spacing: 8) {
                    HomeSectionHeader(title: year, count: years[year]?.count)
                    VStack(spacing: 0) {
                        ForEach(years[year] ?? []) { result in
                            Button {
                                selectedResult = result
                            } label: {
                                CompetitionResultRow(result: result, isMissingMarks: manager.isMissingMarks(result))
                            }
                            .buttonStyle(.pressable(scale: 0.98))
                            .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                            if result.id != years[year]?.last?.id {
                                HomeRowDivider()
                            }
                        }
                    }
                    .homeCard(cornerRadius: 20)
                }
                .transition(.opacity)
            }
        }
    }
}
