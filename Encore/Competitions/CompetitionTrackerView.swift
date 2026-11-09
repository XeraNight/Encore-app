import SwiftUI
import SwiftData

// MARK: - Súťaže
/// The dancer, the current couple with Štandard and Latina (each opens its own statistics and the Slovenský pohár), and
/// the latest results (all of them and the couples before in Výsledky). Reminders only when there is something to do:
/// an unsaved competition, the competition day, crosses still to read. Aktualizovať z KSIS is the small button in the
/// corner (BRAND_GUIDELINES §1A). Numbers come only from KSIS; the only thresholds shown are the Slovenský pohár
/// places from the competition rules (SlovakCup).
struct CompetitionTrackerView: View {
    @ObservedObject private var manager = CompetitionManager.shared
    @ObservedObject private var cupStore = SlovakCupStore.shared
    @Query(sort: \PlannedCompetition.date, order: .reverse) private var planned: [PlannedCompetition]

    @State private var browser: KSISBrowserTarget?
    @State private var updateJob: KSISUpdateJob?
    @State private var searchText = ""
    @State private var selectedResult: CompetitionResult?
    @State private var coupleToUnlink: UserCouple?
    @State private var errorText: String?
    @State private var refreshCount = 0
    @FocusState private var searchFocused: Bool

    var body: some View {
        ZStack {
            EllegancePageBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    dancerSection
                    if let couple = manager.activeCouple {
                        coupleSection(couple)
                    }
                    unsavedSection
                    if let competition = todaysCompetition {
                        competitionDaySection(competition)
                    }
                    marksReminder

                    if showsLatestResults {
                        latestResultsSection
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
        .toolbar {
            if manager.dancer != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { updateJob = .everything } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(Color.gold400)
                    }
                    .accessibilityLabel("Aktualizovať z KSIS")
                }
            }
        }
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
        .preferredColorScheme(.dark)
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
                    if let coupleId = couple.coupleId, let url = KSISBrowserView.page("par.php?id=\(coupleId)") {
                        Button { browser = KSISBrowserTarget(url: url) } label: {
                            Label("Stránka páru v KSIS", systemImage: "list.bullet.rectangle")
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
                    disciplineLink(couple, "STT")
                    disciplineLink(couple, "LAT")
                }

                if couple.coupleId == nil {
                    Label("Históriu súťaží uloží Aktualizovať z KSIS, šípka v pravom hornom rohu.",
                          systemImage: "lightbulb.fill")
                        .font(.footnote)
                        .foregroundColor(Color.gold300)
                        .fixedSize(horizontal: false, vertical: true)
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

    /// Štandard or Latina: class, points and the cup place; a tap opens the discipline's statistics.
    private func disciplineLink(_ couple: UserCouple, _ discipline: String) -> some View {
        NavigationLink {
            DisciplineStatsView(couple: couple, discipline: discipline)
        } label: {
            standingTile(discipline == "LAT" ? "LATINA" : "ŠTANDARD",
                         discipline == "LAT" ? couple.lat : couple.stt,
                         cupPlace: cupPlace(couple, discipline == "LAT" ? .latin : .standard))
        }
        .buttonStyle(.pressable(scale: 0.96))
    }

    /// "Pohár 5." from the last table read; nil outside the cup or before a table was read.
    private func cupPlace(_ couple: UserCouple, _ discipline: SlovakCup.Discipline) -> String? {
        guard let group = SlovakCup.Group(ageCategory: couple.ageCategory),
              SlovakCup.disciplines(for: couple).contains(discipline),
              let saved = cupStore.standings(group: group, discipline: discipline),
              let entry = SlovakCup.entry(in: saved.standings, for: couple) else { return nil }
        return "Pohár \(entry.place?.display ?? "–")"
    }

    private func standingTile(_ title: String, _ standing: UserCouple.Standing, cupPlace: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(.caption2, design: .rounded).weight(.black))
                    .tracking(1.2)
                    .foregroundColor(Color.gold400)
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.white.opacity(0.45))
            }
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
            if let cupPlace {
                Text(cupPlace)
                    .font(.caption.weight(.bold))
                    .foregroundColor(Color.gold300)
            } else if let change = standing.lastChange.flatMap({ KSISBrowserView.displayDate($0, numeric: true) }) {
                Text("Zmena \(change)")
                    .font(.caption2)
                    .foregroundColor(Color.textSecondary)
                    .lineLimit(1)
            }
        }
        .contentShape(Rectangle())
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
            // Only one sent from the KSIS calendar: KSIS has its results, a competition added by hand may not exist there.
            $0.intent == .going && $0.ksisPropId != nil && $0.date < today && $0.date >= monthAgo
                && $0.dancedResults(in: manager.results).isEmpty
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

    // MARK: Crosses still to read
    /// KSIS has one page per competition for the crosses and an update reads 30; until all are read, this says so.
    @ViewBuilder
    private var marksReminder: some View {
        let missing = manager.results.filter(manager.isMissingMarks).count
        if missing > 0 {
            Button { updateJob = .marks } label: {
                HStack(spacing: 12) {
                    Image(systemName: "square.dashed")
                        .foregroundColor(Color.gold400)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dočítaj krížiky z KSIS")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.white)
                        Text("Zostáva \(slovakCount(missing, one: "súťaž", few: "súťaže", many: "súťaží"))")
                            .font(.caption)
                            .foregroundColor(Color.textSecondary)
                            .contentTransition(.numericText())
                    }
                    Spacer(minLength: 8)
                    Text("Čítať ďalej")
                        .font(.caption.weight(.bold))
                        .foregroundColor(Color.gold400)
                }
                .padding(14)
                .homeCard(cornerRadius: 20)
            }
            .buttonStyle(.pressable(scale: 0.98))
        }
    }

    // MARK: Latest results
    /// Before a couple's history is saved, the hint on its card says what to do and an empty list would add nothing.
    private var showsLatestResults: Bool {
        !manager.results.isEmpty || manager.loadFailed || manager.activeCouple?.coupleId != nil
    }

    /// The latest of the current couple, so this screen stays short; everything is in Moje výsledky.
    private var latestResults: [CompetitionResult] {
        let current = manager.activeCouple.map(manager.results(for:)) ?? []
        return Array((current.isEmpty ? manager.results : current).prefix(3))
    }

    private var latestResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeader(title: "VÝSLEDKY", systemImage: "trophy.fill") {
                if !manager.results.isEmpty {
                    NavigationLink { MyResultsView() } label: {
                        HStack(spacing: 3) {
                            Text("Všetky \(manager.results.count)")
                            Image(systemName: "chevron.right")
                        }
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(Color.gold400)
                        .frame(minHeight: 32)
                    }
                    .buttonStyle(.pressable)
                }
            }

            if manager.results.isEmpty {
                Text(manager.loadFailed
                     ? "Výsledky sa nepodarilo načítať. Potiahni obrazovku nadol a skús znova."
                     : "Zatiaľ žiadne. Ťukni šípku v pravom hornom rohu a uložia sa všetky vaše súťaže.")
                    .font(.footnote)
                    .foregroundColor(Color.textSecondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .homeCard(cornerRadius: 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(latestResults) { result in
                        Button {
                            selectedResult = result
                        } label: {
                            CompetitionResultRow(result: result, isMissingMarks: manager.isMissingMarks(result))
                        }
                        .buttonStyle(.pressable(scale: 0.98))
                        if result.id != latestResults.last?.id {
                            HomeRowDivider()
                        }
                    }
                }
                .homeCard(cornerRadius: 20)
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
                if let number = result.startNumber, !number.isEmpty {
                    Text("č. \(number)")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(Color.gold300)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .overlay(Capsule().stroke(Color.gold400.opacity(0.5), lineWidth: 0.5))
                        .accessibilityLabel("Štartové číslo \(number)")
                }
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
