import SwiftUI

// MARK: - Výsledky
/// The couple's history, every competition saved from KSIS, readable here without internet. The current couple comes
/// first; the couples before are one pick away, only when KSIS has any. Aktualizovať z KSIS is the small button in the
/// corner, KSIS's own results a link at the end.
struct MyResultsView: View {
    @ObservedObject private var manager = CompetitionManager.shared
    @AppStorage("competitionResultsAsCalendar") private var showsCalendar = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var choice = CoupleChoice.current
    @State private var resultsFilter: ResultsFilter?
    @State private var selectedResult: CompetitionResult?
    @State private var browser: KSISBrowserTarget?
    @State private var updateJob: KSISUpdateJob?
    @State private var coupleToUnlink: UserCouple?
    @State private var errorText: String?

    private enum CoupleChoice: Hashable {
        case current
        case couple(UUID)
        case all
    }

    private enum ResultsFilter: Hashable {
        case discipline(String)
        case category(String)
    }

    private var spring: Animation? { reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82) }

    private var pickedCouple: UserCouple? {
        switch choice {
        case .current: return manager.activeCouple
        case .couple(let id): return manager.couples.first { $0.id == id }
        case .all: return nil
        }
    }

    private var coupleResults: [CompetitionResult] {
        pickedCouple.map(manager.results(for:)) ?? manager.results
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
                    if !manager.previousCouples.isEmpty { couplePicker }
                    if manager.dancer == nil { findYourselfNote }
                    if !manager.results.isEmpty { summary }
                    if !couplesWithoutHistory.isEmpty { missingHistory }
                    if !coupleResults.isEmpty { filters }
                    results
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 120)
                .animation(spring, value: resultsFilter)
                .animation(spring, value: choice)
                .animation(spring, value: showsCalendar)
            }
            .refreshable { await manager.loadAllData() }
        }
        .navigationTitle("Výsledky")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showsCalendar.toggle()
                } label: {
                    Image(systemName: showsCalendar ? "list.bullet" : "calendar")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(Color.gold400)
                        .contentTransition(.symbolEffect(.replace))
                }
                .accessibilityLabel(showsCalendar ? "Zoznam" : "Kalendár")
                if manager.dancer != nil {
                    Button { updateJob = .everything } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(Color.gold400)
                    }
                    .accessibilityLabel("Aktualizovať z KSIS")
                }
            }
        }
        .sensoryFeedback(.selection, trigger: resultsFilter)
        .sensoryFeedback(.selection, trigger: choice)
        .sensoryFeedback(.selection, trigger: showsCalendar)
        .confirmationDialog("Odstrániť pár z Encore?", isPresented: Binding(
            get: { coupleToUnlink != nil },
            set: { if !$0 { coupleToUnlink = nil } }
        ), titleVisibility: .visible) {
            Button("Odstrániť aj s výsledkami", role: .destructive) {
                if let couple = coupleToUnlink { unlink(couple) }
            }
        } message: {
            Text("Z Encore zmizne tento pár aj jeho uložené výsledky. Ostatné páry ostanú. V KSIS sa nič nezmení.")
        }
        .alert("Nepodarilo sa", isPresented: Binding(
            get: { errorText != nil },
            set: { if !$0 { errorText = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorText ?? "")
        }
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
        Menu {
            if let current = manager.activeCouple {
                pickerButton("Aktuálny pár: \(name(of: current))", .current)
            }
            Section("Bývalé páry") {
                ForEach(manager.previousCouples) { couple in
                    pickerButton(name(of: couple), .couple(couple.id))
                }
            }
            pickerButton("Všetky páry", .all)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.2.fill")
                    .foregroundColor(Color.gold400)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(pickedTitle)
                        .font(.caption2.weight(.black))
                        .tracking(1)
                        .foregroundColor(Color.gold400)
                    Text(pickedCouple.map(name(of:)) ?? "Všetky páry")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Text("Bývalé páry")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Color.textSecondary)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(14)
            .homeCard(cornerRadius: 20)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Pár: \(pickedCouple.map(name(of:)) ?? "Všetky páry")")
    }

    private var pickedTitle: String {
        switch choice {
        case .current: return "AKTUÁLNY PÁR"
        case .couple: return "BÝVALÝ PÁR"
        case .all: return "VŠETKY PÁRY"
        }
    }

    private func name(of couple: UserCouple) -> String {
        couple.partnerName(besides: manager.dancer?.name)
    }

    private func pickerButton(_ title: String, _ value: CoupleChoice) -> some View {
        Button {
            choice = value
            resetFilters()
        } label: {
            if choice == value { Label(title, systemImage: "checkmark") } else { Text(title) }
        }
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

    // MARK: Before KSIS
    private var findYourselfNote: some View {
        Text("Najprv sa nájdi v KSIS na obrazovke Súťaže. Potom sa tu uložia všetky tvoje výsledky.")
            .font(.footnote)
            .foregroundColor(.white.opacity(0.75))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// KSIS's own results, and removing a couple before that is not this dancer's.
    private var footer: some View {
        VStack(spacing: 8) {
            Button {
                if let url = KSISBrowserView.page("menu.php?akcia=S") { browser = KSISBrowserTarget(url: url) }
            } label: {
                Label("Všetky výsledky v KSIS", systemImage: "safari")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Color.gold400)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.pressable)
            if case .couple = choice, let couple = pickedCouple {
                Button(role: .destructive) { coupleToUnlink = couple } label: {
                    Label("Odstrániť tento pár z Encore", systemImage: "trash")
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.pressable)
            }
        }
    }

    private func unlink(_ couple: UserCouple) {
        Task {
            do {
                try await manager.unlink(couple)
                choice = .current
            } catch {
                errorText = error.localizedDescription
            }
        }
    }

    /// Aktualizovať z KSIS finds every couple's KSIS id by name and saves its history.
    private var missingHistory: some View {
        Button { updateJob = .everything } label: {
            HStack(spacing: 12) {
                Image(systemName: "clock.badge.questionmark")
                    .foregroundColor(Color.gold400)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Chýba história: \(couplesWithoutHistory.map { $0.partnerName(besides: manager.dancer?.name) }.joined(separator: ", "))")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.white)
                    Text("Ťukni sem: Aktualizovať z KSIS nájde páry podľa mena a uloží ich súťaže.")
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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("Všetko", nil)
                chip("ŠTT", .discipline("STT"))
                chip("LAT", .discipline("LAT"))
                ForEach(categories, id: \.self) { chip($0, .category($0)) }
            }
        }
        .scrollClipDisabled()
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
                     : "Zatiaľ žiadne. Ťukni šípku v pravom hornom rohu a uložia sa všetky vaše súťaže.")
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
            // Seasons run from September to August, as the dancers count them.
            let seasons = Dictionary(grouping: shown) { $0.dateValue.map(SeasonStats.seasonStartYear(of:)) ?? 0 }
            ForEach(seasons.keys.sorted(by: >), id: \.self) { season in
                VStack(alignment: .leading, spacing: 8) {
                    HomeSectionHeader(title: season > 0 ? "SEZÓNA \(SeasonStats.seasonTitle(season))" : "BEZ DÁTUMU",
                                      count: seasons[season]?.count)
                    VStack(spacing: 0) {
                        ForEach(seasons[season] ?? []) { result in
                            Button {
                                selectedResult = result
                            } label: {
                                CompetitionResultRow(result: result, isMissingMarks: manager.isMissingMarks(result))
                            }
                            .buttonStyle(.pressable(scale: 0.98))
                            .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                            if result.id != seasons[season]?.last?.id {
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
