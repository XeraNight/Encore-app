import SwiftUI

// MARK: - Súťaže
/// The linked couple with class, points and finals from KSIS, every competition with the crosses of each
/// judge, and KSIS in the app for linking, saving and following a competition live (BRAND_GUIDELINES §1A).
/// Free for everyone. Numbers come only from KSIS; the only thresholds shown are the Slovenský pohár places from
/// the competition rules (SlovakCup).
struct CompetitionTrackerView: View {
    @ObservedObject private var manager = CompetitionManager.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @ObservedObject private var cupStore = SlovakCupStore.shared
    @State private var showPaywall = false

    @State private var browser: KSISBrowserTarget?
    @State private var searchText = ""
    @State private var selectedResult: CompetitionResult?
    @State private var coupleToUnlink: UserCouple?
    @State private var errorText: String?
    @State private var refreshCount = 0
    @AppStorage("competitionResultsAsCalendar") private var showsCalendar = false
    @Namespace private var resultsModeNamespace
    @FocusState private var searchFocused: Bool

    var body: some View {
        ZStack {
            EllegancePageBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if manager.couples.isEmpty {
                        linkSection
                    } else {
                        ForEach(manager.couples) { couple in
                            coupleSection(couple)
                            slovakCupSection(couple)
                        }
                        if !manager.results.isEmpty {
                            mySeasonCard
                        }
                    }

                    liveSection

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
        .sheet(item: $selectedResult) { result in
            KSISResultDetailView(result: result) { url in
                selectedResult = nil
                browser = KSISBrowserTarget(url: url)
            }
        }
        .confirmationDialog("Odpojiť pár?", isPresented: Binding(
            get: { coupleToUnlink != nil },
            set: { if !$0 { coupleToUnlink = nil } }
        ), titleVisibility: .visible) {
            Button("Odpojiť a zmazať výsledky", role: .destructive) {
                if let couple = coupleToUnlink { unlink(couple) }
            }
        } message: {
            Text("Z Encore zmizne pár aj jeho uložené výsledky. V KSIS sa nič nezmení.")
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
    @ViewBuilder
    private func slovakCupSection(_ couple: UserCouple) -> some View {
        if let group = SlovakCup.Group(ageCategory: couple.ageCategory) {
            VStack(alignment: .leading, spacing: 12) {
                HomeSectionHeader(title: "SLOVENSKÝ POHÁR", systemImage: "trophy.fill")
                ForEach(SlovakCup.Discipline.allCases) { discipline in
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
                Label(saved == nil ? "Pozrieť poradie v KSIS" : "Aktualizovať z KSIS", systemImage: "arrow.clockwise")
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

    // MARK: Link
    private var linkSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeader(title: "PREPOJ SA S KSIS", systemImage: "link")
            VStack(alignment: .leading, spacing: 14) {
                Text("Vyhľadaj svoj pár v KSIS. Uvidíš triedu, body a finále a všetky výsledky s krížikmi od každého porotcu.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)

                TextField("", text: $searchText,
                          prompt: Text("Priezvisko alebo číslo preukazu partnera").foregroundColor(.white.opacity(0.4)))
                    .focused($searchFocused)
                    .submitLabel(.search)
                    .onSubmit(search)
                    .autocorrectionDisabled()
                    .foregroundColor(.white)
                    .padding(14)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                PrimarySheetButton(title: "Hľadať v KSIS", isLoading: false, isEnabled: true, action: search)

                Text("Číslo páru v KSIS je číslo preukazu partnera. Partnerka nájde pár podľa priezviska.")
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)
            }
            .padding(16)
            .homeCard(cornerRadius: 20)
        }
    }

    private func search() {
        searchFocused = false
        if let url = KSISBrowserView.searchURL(for: searchText) {
            browser = KSISBrowserTarget(url: url)
        }
    }

    // MARK: Couple
    private func coupleSection(_ couple: UserCouple) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeader(title: "NÁŠ PÁR", systemImage: "person.2.fill") {
                Menu {
                    Button(role: .destructive) {
                        coupleToUnlink = couple
                    } label: {
                        Label("Odpojiť pár", systemImage: "link.badge.minus")
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
                    Button {
                        if let pair = couple.pairNumber, let url = URL(string: "https://\(KSISBrowserView.host)/detail_paru.php?cp=\(pair)") {
                            browser = KSISBrowserTarget(url: url)
                        }
                    } label: {
                        Label("Aktualizovať", systemImage: "arrow.clockwise")
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
                        Label(couple.coupleId == nil ? "Otvoriť KSIS" : "História", systemImage: "list.bullet.rectangle")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 44)
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

    // MARK: Live
    private var liveSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeader(title: "V DEŇ SÚŤAŽE", systemImage: "dot.radiowaves.left.and.right")
            Button {
                if let url = URL(string: "https://\(KSISBrowserView.host)/") {
                    browser = KSISBrowserTarget(url: url)
                }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "arrow.down.circle.dotted")
                        .font(.title2)
                        .foregroundColor(Color.gold400)
                        .symbolEffect(.pulse)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Postupujete? Pozri hneď")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.white)
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

    // MARK: Results
    private var resultsSection: some View {
        let years = Dictionary(grouping: manager.results) { String($0.date.prefix(4)) }
        let sortedYears = years.keys.sorted(by: >)
        return VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeader(title: "VÝSLEDKY", systemImage: "trophy.fill", count: manager.results.count) {
                if !manager.results.isEmpty { resultsModeSwitch }
            }

            if manager.results.isEmpty {
                Text(manager.loadFailed
                     ? "Výsledky sa nepodarilo načítať. Potiahni obrazovku nadol a skús znova."
                     : "Zatiaľ žiadne. Otvor v KSIS stránku svojho páru a ulož históriu jedným ťuknutím.")
                    .font(.footnote)
                    .foregroundColor(Color.textSecondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .homeCard(cornerRadius: 20)
            } else if showsCalendar {
                CompetitionCalendarView(results: manager.results) { selectedResult = $0 }
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
                                CompetitionResultRow(result: result)
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

    private var resultsModeSwitch: some View {
        HStack(spacing: 2) {
            ForEach([false, true], id: \.self) { asCalendar in
                let isOn = showsCalendar == asCalendar
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) { showsCalendar = asCalendar }
                } label: {
                    Image(systemName: asCalendar ? "calendar" : "list.bullet")
                        .font(.caption.weight(.bold))
                        .foregroundColor(isOn ? Color.obsidian900 : .white.opacity(0.6))
                        .frame(width: 34, height: 26)
                        .background {
                            if isOn {
                                Capsule()
                                    .fill(Color.gold400)
                                    .matchedGeometryEffect(id: "resultsMode", in: resultsModeNamespace)
                            }
                        }
                }
                .buttonStyle(.pressable(scale: 0.9))
                .accessibilityLabel(asCalendar ? "Kalendár" : "Zoznam")
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(2)
        .background(Color.white.opacity(0.07), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
        .sensoryFeedback(.selection, trigger: showsCalendar)
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
