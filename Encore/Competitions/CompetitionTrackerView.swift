import SwiftUI
import SwiftData

// MARK: - Súťaže
/// The current couple with class, points and finals, the couples before when there are any, every competition with
/// the crosses of each judge, and one tap to bring it all up to date from KSIS (BRAND_GUIDELINES §1A). The competitions
/// the dancer goes to stay in Kalendár; here they only tie in: "Postupujete?" on their day, a reminder when one is
/// not saved yet. Free for everyone. Numbers come only from KSIS; the only thresholds shown are the Slovenský pohár
/// places from the competition rules (SlovakCup).
struct CompetitionTrackerView: View {
    @ObservedObject private var manager = CompetitionManager.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @ObservedObject private var cupStore = SlovakCupStore.shared
    @Query(sort: \PlannedCompetition.date, order: .reverse) private var planned: [PlannedCompetition]
    @State private var showPaywall = false

    @State private var browser: KSISBrowserTarget?
    @State private var updateJob: KSISUpdateJob?
    @State private var resultsFilter: ResultsFilter?
    @State private var searchText = ""
    @State private var selectedResult: CompetitionResult?
    @State private var coupleToUnlink: UserCouple?
    @State private var errorText: String?
    @State private var refreshCount = 0
    @AppStorage("competitionResultsAsCalendar") private var showsCalendar = false
    @FocusState private var searchFocused: Bool

    private enum ResultsFilter: Hashable {
        case discipline(String)
        case category(String)
    }

    var body: some View {
        ZStack {
            EllegancePageBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    dancerSection
                    if let couple = manager.activeCouple {
                        coupleSection(couple)
                    }
                    if !manager.previousCouples.isEmpty {
                        previousCouplesSection
                    }
                    unsavedSection
                    if let competition = todaysCompetition {
                        competitionDaySection(competition)
                    }
                    if let couple = manager.activeCouple {
                        slovakCupSection(couple)
                    }
                    quickLinks
                    if !manager.results.isEmpty {
                        mySeasonCard
                    }

                    if !manager.couples.isEmpty {
                        resultsSection
                    }

                    Text("Zdroj: KSIS (szts.ksis.eu). Oficiálne výsledky a body eviduje Slovenský zväz tanečného športu.")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.45))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 120)   // clear of the tab bar
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: manager.couples.map(\.id))
            }
            .scrollDismissesKeyboard(.interactively)
            .refreshable {
                refreshCount += 1
                await manager.loadAllData()
            }
        }
        .navigationTitle("Súťaže")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.impact(weight: .medium), trigger: refreshCount)
        .fullScreenCover(item: $browser) { target in
            KSISBrowserView(startURL: target.url)
        }
        .fullScreenCover(item: $updateJob) { KSISUpdateSheet(job: $0) }
        .sheet(item: $selectedResult) { result in
            KSISResultDetailView(result: result) { url in
                selectedResult = nil
                browser = KSISBrowserTarget(url: url)
            }
        }
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
        .task { await manager.loadAllData() }
        .sheet(isPresented: $showPaywall) { SubscriptionPaywallView(initialTier: .plus) }
        .preferredColorScheme(.dark)
    }

    // MARK: Moja sezóna (Plus)
    /// The saved results stay free; the analysis of them is Plus (docs/V1_PAYWALL_FEATURES_PLAN.md).
    @ViewBuilder
    private var mySeasonCard: some View {
        let hasPlus = subscriptionManager.currentTier >= .plus
        let row = HomeRow(
            icon: "chart.bar.xaxis",
            title: "Moja sezóna",
            subtitle: "Krížiky podľa tancov, finále a vývoj počas sezóny",
            badge: hasPlus ? nil : "PLUS"
        )
        .padding(.vertical, 4)
        .homeCard(cornerRadius: 20)

        if hasPlus {
            NavigationLink { MySeasonView(results: manager.results) } label: { row }
                .buttonStyle(.pressable(scale: 0.98))
        } else {
            Button { showPaywall = true } label: { row }
                .buttonStyle(.pressable(scale: 0.98))
        }
    }

    // MARK: Slovenský pohár
    /// The official KSIS table, read live in the KSIS browser; the last one read stays here until the next read.
    /// Only for couples in the cup, by their KSIS age category and class (SlovakCup.disciplines).
    @ViewBuilder
    private func slovakCupSection(_ couple: UserCouple) -> some View {
        let disciplines = SlovakCup.disciplines(for: couple)
        if let group = SlovakCup.Group(ageCategory: couple.ageCategory), !disciplines.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HomeSectionHeader(title: "SLOVENSKÝ POHÁR", systemImage: "trophy.fill")
                ForEach(disciplines) { discipline in
                    cupCard(couple, group: group, discipline: discipline)
                }
            }
        }
    }

    private func cupCard(_ couple: UserCouple, group: SlovakCup.Group, discipline: SlovakCup.Discipline) -> some View {
        let saved = cupStore.standings(group: group, discipline: discipline)
        let entry = saved.flatMap { SlovakCup.entry(in: $0.standings, for: couple) }
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(discipline.title)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                if let saved {
                    Text("Načítané \(EncoreTime.dayAndClock(saved.readAt))")
                        .font(.caption)
                        .foregroundColor(Color.textSecondary)
                }
            }
            if let saved, let entry {
                SlovakCupStatusView(status: SlovakCup.status(of: entry, in: saved.standings, group: group),
                                    showsChampionship: group == .adults || (couple.ageCategory ?? "").contains("II"))
            } else if saved != nil {
                Text("V tomto poradí zatiaľ nie ste.")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.7))
            }
            Button { openCupStandings(group: group, discipline: discipline) } label: {
                Label("Poradie v KSIS", systemImage: "list.number")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color.gold400)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.pressable)
        }
        .padding(14)
        .homeCard(cornerRadius: 20)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: saved?.readAt)
    }

    private func openCupStandings(group: SlovakCup.Group, discipline: SlovakCup.Discipline) {
        let year = Calendar.current.component(.year, from: Date())
        if let url = SlovakCup.standingsURL(year: year, group: group, discipline: discipline) {
            browser = KSISBrowserTarget(url: url)
        }
    }

    // MARK: Dancer
    /// Who the user is in KSIS: found by name or the personal number. One line once the couples are saved.
    @ViewBuilder
    private var dancerSection: some View {
        if let dancer = manager.dancer {
            if manager.couples.isEmpty {
                findCouplesSection(dancer)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "person.text.rectangle")
                        .font(.caption.weight(.bold))
                        .foregroundColor(Color.gold400)
                        .accessibilityHidden(true)
                    Text(dancer.name)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.white)
                    Text("č. \(dancer.personNumber)")
                        .font(.caption)
                        .foregroundColor(Color.textSecondary)
                }
                .accessibilityElement(children: .combine)
            }
        } else {
            findYourselfSection
        }
    }

    private func findCouplesSection(_ dancer: KSISDancer) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeader(title: "TANEČNÍK V KSIS", systemImage: "person.text.rectangle")
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(dancer.name)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundColor(.white)
                    Text([dancer.club, "č. \(dancer.personNumber)"].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.footnote)
                        .foregroundColor(Color.textSecondary)
                }
                Label("Ďalej ulož svoje páry, aj tie skončené.", systemImage: "lightbulb.fill")
                    .font(.footnote)
                    .foregroundColor(Color.gold300)
                Button { openCouples(of: dancer) } label: {
                    Label("Moje páry v KSIS", systemImage: "person.2.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color.obsidian900)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Color.gold400, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.pressable)
            }
            .padding(16)
            .homeCard(cornerRadius: 20)
        }
    }

    private func openCouples(of dancer: KSISDancer) {
        if let url = KSISBrowserView.couplesURL(surname: KSISBrowserView.surname(of: dancer.name)) {
            browser = KSISBrowserTarget(url: url)
        }
    }

    private var findYourselfSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeader(title: "NÁJDI SA V KSIS", systemImage: "magnifyingglass")
            VStack(alignment: .leading, spacing: 14) {
                Text("Vyhľadaj sa v zozname členov KSIS a ťukni Som to ja. Appka potom spozná tvoje páry, aj tie skončené, a uvidíš triedu, body, finále a výsledky s krížikmi od každého porotcu.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)

                TextField("", text: $searchText,
                          prompt: Text("Priezvisko alebo číslo z preukazu").foregroundColor(.white.opacity(0.4)))
                    .focused($searchFocused)
                    .submitLabel(.search)
                    .onSubmit(search)
                    .autocorrectionDisabled()
                    .foregroundColor(.white)
                    .padding(14)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                PrimarySheetButton(title: "Hľadať v KSIS", isLoading: false, isEnabled: true, action: search)
            }
            .padding(16)
            .homeCard(cornerRadius: 20)
        }
    }

    private func search() {
        searchFocused = false
        if let url = KSISBrowserView.membersSearchURL(for: searchText) {
            browser = KSISBrowserTarget(url: url)
        }
    }

    // MARK: Couples before
    private var previousCouplesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeader(title: "PREDCHÁDZAJÚCE PÁRY", systemImage: "clock.arrow.circlepath", count: manager.previousCouples.count)
            VStack(spacing: 0) {
                ForEach(manager.previousCouples) { couple in
                    previousCoupleRow(couple)
                    if couple.id != manager.previousCouples.last?.id {
                        HomeRowDivider()
                    }
                }
            }
            .homeCard(cornerRadius: 20)
        }
    }

    private func previousCoupleRow(_ couple: UserCouple) -> some View {
        let saved = manager.results(for: couple).count
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(couple.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
                Text(([couple.club, couple.ageCategory].compactMap { $0 } + [saved > 0 ? "\(saved) súťaží" : "bez uložených súťaží"])
                    .filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)
            }
            Spacer(minLength: 8)
            Menu {
                if let coupleId = couple.coupleId {
                    Button {
                        if let url = URL(string: "https://\(KSISBrowserView.host)/par.php?id=\(coupleId)") {
                            browser = KSISBrowserTarget(url: url)
                        }
                    } label: {
                        Label("História v KSIS", systemImage: "list.bullet.rectangle")
                    }
                }
                Button(role: .destructive) {
                    coupleToUnlink = couple
                } label: {
                    Label("Odstrániť z Encore", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.footnote.weight(.bold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Možnosti páru \(couple.title)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: Couple
    private func coupleSection(_ couple: UserCouple) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeader(title: "NÁŠ PÁR", systemImage: "person.2.fill") {
                Menu {
                    if let dancer = manager.dancer {
                        Button { openCouples(of: dancer) } label: {
                            Label("Moje páry v KSIS", systemImage: "person.2.fill")
                        }
                    }
                    Button(role: .destructive) {
                        coupleToUnlink = couple
                    } label: {
                        Label("Odstrániť z Encore", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.footnote.weight(.bold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 44, height: 32)
                }
                .accessibilityLabel("Možnosti páru")
            }

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(couple.title)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundColor(.white)
                    Text([couple.club, couple.ageCategory].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.footnote)
                        .foregroundColor(Color.textSecondary)
                }

                HStack(spacing: 10) {
                    standingTile("ŠTANDARD", couple.stt)
                    standingTile("LATINA", couple.lat)
                }

                if couple.coupleId == nil {
                    Label("Ulož históriu: otvor v KSIS výsledky ktorejkoľvek vašej súťaže a ťukni na svoje meno.",
                          systemImage: "lightbulb.fill")
                        .font(.footnote)
                        .foregroundColor(Color.gold300)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    Button { updateJob = .everything } label: {
                        Label("Aktualizovať z KSIS", systemImage: "arrow.clockwise")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Color.obsidian900)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Color.gold400, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.pressable)

                    Button {
                        if let coupleId = couple.coupleId, let url = URL(string: "https://\(KSISBrowserView.host)/par.php?id=\(coupleId)") {
                            browser = KSISBrowserTarget(url: url)
                        } else if let url = URL(string: "https://\(KSISBrowserView.host)/") {
                            browser = KSISBrowserTarget(url: url)
                        }
                    } label: {
                        Label(couple.coupleId == nil ? "KSIS" : "História", systemImage: "list.bullet.rectangle")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.pressable)
                }

                if let refreshed = couple.refreshedAt.flatMap(Self.parseTimestamp) {
                    Text("Z KSIS \(refreshed.formatted(.dateTime.day().month(.wide).hour().minute().locale(Locale(identifier: "sk"))))")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.45))
                }
            }
            .padding(16)
            .homeCard(cornerRadius: 20)
        }
    }

    private func standingTile(_ title: String, _ standing: UserCouple.Standing) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.caption2, design: .rounded).weight(.black))
                .tracking(1.2)
                .foregroundColor(Color.gold400)
            Text(standing.className ?? "–")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .contentTransition(.numericText())
            VStack(alignment: .leading, spacing: 4) {
                Label(standing.points.map { slovakCount($0, one: "bod", few: "body", many: "bodov") } ?? "– bodov",
                      systemImage: "star.fill")
                Label("\(standing.finals.map(String.init) ?? "–") finále", systemImage: "rosette")
            }
            .font(.caption.weight(.bold))
            .foregroundColor(.white.opacity(0.8))
            .labelStyle(.titleAndIcon)
            if let change = standing.lastChange.flatMap({ KSISBrowserView.displayDate($0, numeric: true) }) {
                Text("Zmena \(change)")
                    .font(.caption2)
                    .foregroundColor(Color.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // MARK: Competition day
    /// A competition set to Idem for today. "Postupujete?" belongs to it; on any other day it has nothing to say.
    private var todaysCompetition: PlannedCompetition? {
        planned.first { $0.intent == .going && PlannerCalendar.calendar.isDate($0.date, inSameDayAs: Date()) }
    }

    private func competitionDaySection(_ competition: PlannedCompetition) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeader(title: "DNES SÚŤAŽÍTE", systemImage: "dot.radiowaves.left.and.right")
            Button {
                if let url = KSISBrowserView.page("menu.php?akcia=S") {
                    browser = KSISBrowserTarget(url: url)
                }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "arrow.down.circle.dotted")
                        .font(.title2)
                        .foregroundColor(Color.gold400)
                        .symbolEffect(.pulse)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Postupujete? \(competition.name)")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                        Text("Otvor v KSIS hodnotenie svojej kategórie a potiahni stránku nadol. Encore ukáže, či postupujete, a krížiky od každého porotcu.")
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.65))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.bold))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(16)
                .homeCard(cornerRadius: 20)
            }
            .buttonStyle(.pressable(scale: 0.98))
        }
    }

    // MARK: What is not saved yet
    /// Idem competitions of the last month with no result saved for their day.
    private var unsavedCompetitions: [PlannedCompetition] {
        guard !manager.couples.isEmpty, !manager.loadFailed else { return [] }
        let today = PlannerCalendar.startOfDay(Date())
        let monthAgo = PlannerCalendar.calendar.date(byAdding: .day, value: -30, to: today) ?? today
        return planned.filter {
            $0.intent == .going && $0.date < today && $0.date >= monthAgo && $0.dancedResults(in: manager.results).isEmpty
        }
    }

    @ViewBuilder
    private var unsavedSection: some View {
        if let latest = unsavedCompetitions.first {
            let others = unsavedCompetitions.count - 1
            Button { updateJob = .everything } label: {
                HStack(spacing: 12) {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .foregroundColor(Color.gold400)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(latest.name) ešte nie je uložená")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                        Text(others > 0 ? "Aktualizovať · čakajú ďalšie: \(others)" : "Aktualizovať")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Color.gold300)
                    }
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
    }

    // MARK: Quick links
    private var quickLinks: some View {
        HStack(spacing: 10) {
            NavigationLink { KSISCalendarView() } label: { quickLink("Kalendár súťaží", icon: "calendar") }
                .buttonStyle(.pressable(scale: 0.96))
            Button {
                if let url = KSISBrowserView.page("menu.php?akcia=S") { browser = KSISBrowserTarget(url: url) }
            } label: {
                quickLink("Výsledky", icon: "trophy.fill")
            }
            .buttonStyle(.pressable(scale: 0.96))
            Button(action: openCup) { quickLink("Pohár", icon: "rosette") }
                .buttonStyle(.pressable(scale: 0.96))
        }
    }

    private func quickLink(_ title: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundColor(Color.gold400)
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, minHeight: 76)
        .padding(.horizontal, 6)
        .homeCard(cornerRadius: 18)
    }

    /// The couple's table when it is in the cup, otherwise the year's page with all the tables.
    private func openCup() {
        let year = Calendar.current.component(.year, from: Date())
        if let couple = manager.activeCouple, let group = SlovakCup.Group(ageCategory: couple.ageCategory),
           let discipline = SlovakCup.disciplines(for: couple).first {
            openCupStandings(group: group, discipline: discipline)
        } else if let url = SlovakCup.overviewURL(year: year) {
            browser = KSISBrowserTarget(url: url)
        }
    }

    // MARK: Results
    private var filteredResults: [CompetitionResult] {
        switch resultsFilter {
        case nil: return manager.results
        case .discipline(let discipline): return manager.results.filter { $0.discipline == discipline }
        case .category(let category): return manager.results.filter { $0.categoryName == category }
        }
    }

    /// The dancer's categories, the latest first.
    private var resultCategories: [String] {
        var seen = Set<String>()
        return manager.results.map(\.categoryName).filter { seen.insert($0).inserted }
    }

    private var resultsFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                resultsChip("Všetko", nil)
                resultsChip("ŠTT", .discipline("STT"))
                resultsChip("LAT", .discipline("LAT"))
                ForEach(resultCategories, id: \.self) { resultsChip($0, .category($0)) }
            }
        }
        .scrollClipDisabled()
        .sensoryFeedback(.selection, trigger: resultsFilter)
    }

    private func resultsChip(_ title: String, _ value: ResultsFilter?) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { resultsFilter = value }
        } label: {
            FilterChip(title: title, isOn: resultsFilter == value)
        }
        .buttonStyle(.pressable)
    }

    /// One line for the crosses still to come, so it is clear what the empty mark in the rows means.
    @ViewBuilder
    private var missingMarksLine: some View {
        let missing = manager.results.filter(manager.isMissingMarks).count
        if missing > 0 {
            Button { updateJob = .everything } label: {
                Label("Krížiky chýbajú: \(missing) · Aktualizovať", systemImage: "square.dashed")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Color.gold300)
                    .frame(minHeight: 34)
            }
            .buttonStyle(.pressable)
        }
    }

    private var resultsSection: some View {
        let results = filteredResults
        let years = Dictionary(grouping: results) { String($0.date.prefix(4)) }
        let sortedYears = years.keys.sorted(by: >)
        return VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeader(title: "VÝSLEDKY", systemImage: "trophy.fill", count: results.count) {
                if !manager.results.isEmpty {
                    GoldModeSwitch(isSecond: $showsCalendar, first: ("list.bullet", "Zoznam"), second: ("calendar", "Kalendár"))
                }
            }
            if !manager.results.isEmpty {
                resultsFilters
                missingMarksLine
            }

            if manager.results.isEmpty {
                Text(manager.loadFailed
                     ? "Výsledky sa nepodarilo načítať. Potiahni obrazovku nadol a skús znova."
                     : "Zatiaľ žiadne. Ťukni Aktualizovať z KSIS a uložia sa všetky vaše súťaže.")
                    .font(.footnote)
                    .foregroundColor(Color.textSecondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .homeCard(cornerRadius: 20)
            } else if showsCalendar {
                CompetitionCalendarView(results: results) { selectedResult = $0 }
                    .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
            } else {
                ForEach(sortedYears, id: \.self) { year in
                    Text(year)
                        .font(.system(.footnote, design: .rounded).weight(.heavy))
                        .foregroundColor(Color.textSecondary)
                        .padding(.top, 4)
                    VStack(spacing: 0) {
                        ForEach(years[year] ?? []) { result in
                            Button {
                                selectedResult = result
                            } label: {
                                CompetitionResultRow(result: result, isMissingMarks: manager.isMissingMarks(result))
                            }
                            .buttonStyle(.pressable(scale: 0.98))
                            if result.id != years[year]?.last?.id {
                                HomeRowDivider()
                            }
                        }
                    }
                    .homeCard(cornerRadius: 20)
                }
            }
        }
    }

    private func unlink(_ couple: UserCouple) {
        Task {
            do {
                try await manager.unlink(couple)
            } catch {
                errorText = error.localizedDescription
            }
        }
    }

    nonisolated private static func parseTimestamp(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text)
    }
}

struct KSISBrowserTarget: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

/// One saved competition: date, category, event, place and points. Used in the list and in the calendar.
struct CompetitionResultRow: View {
    let result: CompetitionResult
    /// Crosses not saved yet that KSIS may still have.
    var isMissingMarks = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 0) {
                Text(result.dateValue?.formatted(.dateTime.day()) ?? "")
                    .font(.system(.headline, design: .rounded).weight(.heavy))
                    .foregroundColor(.white)
                Text(result.dateValue?.formatted(.dateTime.month(.abbreviated).locale(Locale(identifier: "sk"))) ?? "")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(Color.textSecondary)
            }
            .frame(width: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(result.categoryName)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
                Text(result.eventName)
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(result.placeLine)
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .foregroundColor(Color.gold300)
                HStack(spacing: 4) {
                    if result.rounds?.isEmpty == false {
                        Image(systemName: "xmark.square.fill")
                            .font(.caption2)
                            .foregroundColor(Color.gold400)
                            .accessibilityLabel("Krížiky uložené")
                    } else if isMissingMarks {
                        Image(systemName: "square.dashed")
                            .font(.caption2)
                            .foregroundColor(Color.gold300)
                            .accessibilityLabel("Krížiky chýbajú")
                    }
                    Text("+\(result.pointsEarned) b")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
