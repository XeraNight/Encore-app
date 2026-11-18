import SwiftUI
import SwiftData

// MARK: - Kalendár súťaží
/// The KSIS calendar: what is coming, filtered as on KSIS, as a list or with the map of Slovakia above it, where a
/// town picks its competitions for the list. Reading only: the competitions the dancer goes to live in Kalendár, sent
/// there with Idem. The last read stays on the iPhone.
struct KSISCalendarView: View {
    @ObservedObject private var store = KSISCalendarStore.shared
    @ObservedObject private var manager = CompetitionManager.shared
    @Query private var planned: [PlannedCompetition]

    @State private var filter = KSISCalendarFilter()
    @State private var selected: KSISEvent?
    @State private var job: KSISUpdateJob?
    @AppStorage("ksisCalendarAsMap") private var showsMap = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var spring: Animation? { reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82) }

    /// The couple whose categories can be told: before its class is saved, "Moja kategória" would hide everything.
    private var couple: UserCouple? {
        manager.activeCouple.flatMap { $0.stt.className != nil || $0.lat.className != nil ? $0 : nil }
    }

    /// Competitions from today on: the cached read goes stale day by day.
    private var upcoming: [KSISEvent] {
        let today = PlannerCalendar.startOfDay(Date())
        return store.events.filter { ($0.dateValue ?? today) >= today }
    }

    /// Everything but the town: the map shows where the other filters leave something.
    private var beforeCity: [KSISEvent] {
        var others = filter
        others.city = nil
        return upcoming.filter { others.matches($0, couple: couple) }
    }

    private var cityCounts: [String: Int] {
        Dictionary(grouping: beforeCity.compactMap(\.city)) { $0 }.mapValues(\.count)
    }

    private var shown: [KSISEvent] { beforeCity.filter { filter.city == nil || $0.city == filter.city } }

    /// Months in calendar order, as KSIS lists them.
    private var months: [(title: String, events: [KSISEvent])] {
        let groups = Dictionary(grouping: shown) { String($0.date.prefix(7)) }
        return groups.keys.sorted().map { key in
            let events = (groups[key] ?? []).sorted { $0.date < $1.date }
            let title = events.first?.dateValue?.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "sk"))) ?? key
            return (title.uppercased(), events)
        }
    }

    var body: some View {
        ZStack {
            EllegancePageBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if store.readAt == nil {
                        firstRead
                    } else {
                        statusLine
                        filters
                        resultLine
                        if showsMap { map }
                        list
                    }
                    Text("Zdroj: KSIS (szts.ksis.eu). Propozície, prihlášky a termíny vždy over v KSIS.")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.45))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 120)
                .animation(spring, value: filter)
                .animation(spring, value: showsMap)
            }
            .softTopEdge()
        }
        .navigationTitle("Kalendár súťaží")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $job) { KSISUpdateSheet(job: $0) }
        .sheet(item: $selected) { event in
            KSISEventSheet(event: event, couple: couple)
        }

        .preferredColorScheme(.dark)
    }

    // MARK: First read
    private var firstRead: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Súťaže sa načítajú z KSIS. Ostanú v iPhone, takže kalendár potom otvoríš hneď a aj bez internetu.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            PrimarySheetButton(title: "Načítať kalendár z KSIS", isLoading: false, isEnabled: true) { job = .calendar }
        }
        .padding(16)
        .homeCard(cornerRadius: 20)
    }

    // MARK: Status
    private var statusLine: some View {
        HStack(spacing: 10) {
            if let readAt = store.readAt {
                Text("Načítané \(EncoreTime.dayAndClock(readAt))")
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)
            }
            Spacer(minLength: 8)
            Button { job = .calendar } label: {
                Label("Aktualizovať", systemImage: "arrow.clockwise")
                    .font(.caption.weight(.bold))
                    .foregroundColor(Color.gold400)
                    .frame(minHeight: 34)
            }
            .buttonStyle(.pressable)
            GoldModeSwitch(isSecond: $showsMap, first: ("list.bullet", "Zoznam"), second: ("map", "Mapa"))
        }
    }

    // MARK: Filters
    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if couple != nil {
                    Button {
                        filter.onlyMine.toggle()
                    } label: {
                        FilterChip(title: "Moja kategória", isOn: filter.onlyMine)
                    }
                    .buttonStyle(.pressable)
                }
                menu("Vek", selection: $filter.age, options: KSISCalendarFilter.ages.map { ($0, $0) })
                menu("Trieda", selection: $filter.className, options: KSISCalendarFilter.classes.map { ($0, $0) })
                menu("ŠTT / LAT", selection: $filter.discipline, options: KSISCalendarFilter.disciplines.map { ($0, $0) })
                menu("Typ", selection: kindFilter, options: [(.slovakCup, "Slovenský pohár"), (.championship, "MSR"), (.wdsf, "WDSF")])
                // On the map a town is picked on the map itself.
                if !showsMap {
                    menu("Mesto", selection: $filter.city, options: cityCounts.keys.sorted { $0.compare($1, locale: Locale(identifier: "sk")) == .orderedAscending }.map { ($0, $0) })
                }
            }
        }
        .scrollClipDisabled()
        .sensoryFeedback(.selection, trigger: filter)
    }

    /// How many competitions the filters leave, and the way back.
    private var resultLine: some View {
        HStack(spacing: 8) {
            Text(slovakCount(shown.count, one: "súťaž", few: "súťaže", many: "súťaží"))
                .font(.footnote.weight(.semibold))
                .foregroundColor(.white.opacity(0.8))
                .contentTransition(.numericText())
            Spacer(minLength: 8)
            if filter != KSISCalendarFilter() {
                Button { filter = KSISCalendarFilter() } label: {
                    Label("Zrušiť filtre", systemImage: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundColor(Color.gold400)
                        .frame(minHeight: 30)
                }
                .buttonStyle(.pressable)
                .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .trailing)))
            }
        }
    }

    /// A type is its own list: who may start at MSR or WDSF is in the rules, not in the couple's class.
    private var kindFilter: Binding<KSISEvent.Kind?> {
        Binding {
            filter.kind
        } set: { kind in
            filter.kind = kind
            if kind != nil { filter.onlyMine = false }
        }
    }

    private func menu<Value: Hashable>(_ title: String, selection: Binding<Value?>, options: [(value: Value, title: String)]) -> some View {
        Menu {
            Button("Všetko") { selection.wrappedValue = nil }
            ForEach(options, id: \.value) { option in
                Button(option.title) { selection.wrappedValue = option.value }
            }
        } label: {
            FilterChip(title: options.first { $0.value == selection.wrappedValue }?.title ?? title,
                       isOn: selection.wrappedValue != nil, hasMenu: true)
        }
    }

    // MARK: Map
    /// The map above the list: a town picks its competitions for the list, another tap or Všetky mestá steps back.
    private var map: some View {
        VStack(alignment: .leading, spacing: 8) {
            SlovakiaMapView(counts: cityCounts, selected: $filter.city)
                .homeCard(cornerRadius: 20)
            if let town = filter.city {
                TownPickedRow(town: town, count: cityCounts[town] ?? 0) { filter.city = nil }
            } else {
                let unplaced = beforeCity.count - cityCounts.values.reduce(0, +)
                Text(unplaced > 0 ? "Ťukni na mesto a zoznam ukáže jeho súťaže. Bez miesta na mape: \(unplaced)."
                                  : "Ťukni na mesto a zoznam ukáže jeho súťaže.")
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
    }

    // MARK: List
    @ViewBuilder
    private var list: some View {
        if shown.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Pre tento výber KSIS nemá žiadnu súťaž.")
                    .font(.footnote)
                    .foregroundColor(Color.textSecondary)
                if filter != KSISCalendarFilter(onlyMine: false) {
                    Button("Zobraziť všetky súťaže") { filter = KSISCalendarFilter(onlyMine: false) }
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(Color.gold400)
                        .frame(minHeight: 44)
                        .buttonStyle(.pressable)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .homeCard(cornerRadius: 20)
        } else {
            ForEach(months, id: \.title) { month in
                VStack(alignment: .leading, spacing: 10) {
                    HomeSectionHeader(title: month.title, count: month.events.count)
                    VStack(spacing: 0) {
                        ForEach(month.events) { event in
                            Button { selected = event } label: {
                                KSISEventRow(event: event, couple: couple, isGoing: isGoing(to: event))
                            }
                            .buttonStyle(.pressable(scale: 0.98))
                            .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                            if event.id != month.events.last?.id { HomeRowDivider() }
                        }
                    }
                    .homeCard(cornerRadius: 20)
                }
                .transition(.opacity)
            }
        }
    }

    private func isGoing(to event: KSISEvent) -> Bool {
        planned.contains { $0.ksisPropId != nil && $0.ksisPropId == event.propId && $0.intent == .going }
    }
}

// MARK: - One competition in the list
private struct KSISEventRow: View {
    let event: KSISEvent
    let couple: UserCouple?
    let isGoing: Bool

    private var myCategories: [String] { couple.map(event.categories(for:)) ?? [] }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Text(event.dateValue?.formatted(.dateTime.day()) ?? "")
                    .font(.system(.headline, design: .rounded).weight(.heavy))
                    .foregroundColor(.white)
                Text(event.dateValue?.formatted(.dateTime.month(.abbreviated).locale(Locale(identifier: "sk"))) ?? "")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(Color.textSecondary)
            }
            .frame(width: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(event.isCancelled ? .white.opacity(0.5) : .white)
                    .strikethrough(event.isCancelled)
                    .multilineTextAlignment(.leading)
                Text(event.city ?? event.venue)
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)
                    .lineLimit(1)
                if !myCategories.isEmpty {
                    Text(myCategories.joined(separator: " · "))
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Color.gold300)
                }
                if event.isCancelled {
                    Text("Zrušené")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.white.opacity(0.75))
                } else if let note = event.note {
                    KSISEventNote(text: note)
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 6)

            if isGoing {
                Text("Idem")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(Color.obsidian900)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.gold400, in: Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// KSIS's warning on a competition. Red in KSIS, gold here: red text is lost on the crimson background.
struct KSISEventNote: View {
    let text: String

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
        }
        .foregroundColor(Color.gold300)
    }
}

// MARK: - One competition
/// Everything KSIS says about a competition, Idem, and its pages. Idem sends it to Kalendár, the one place for
/// the competitions the dancer goes to.
struct KSISEventSheet: View {
    let event: KSISEvent
    let couple: UserCouple?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var planned: [PlannedCompetition]
    @State private var browser: KSISBrowserTarget?
    @State private var goingTick = 0
    @State private var declineTick = 0

    private var plannedHere: PlannedCompetition? { planned.first { $0.ksisPropId != nil && $0.ksisPropId == event.propId } }
    private var isGoing: Bool { plannedHere?.intent == .going }
    private var myCategories: [String] { couple.map(event.categories(for:)) ?? [] }

    var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        facts
                        if !event.isCancelled, event.dateValue != nil { goingButton }
                        KSISEventLinks(propId: event.propId, registered: event.registered, hasTimetable: event.hasTimetable,
                                       venue: event.venue) { browser = KSISBrowserTarget(url: $0) }
                        categories
                    }
                    .padding(20)
                    // Idem and Neidem move the same way: the button grows into the row (or back), and what is below makes
                    // room with it instead of jumping.
                    .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.72), value: isGoing)
                }
                .softTopEdge()
            }
            .navigationTitle(event.dateValue?.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "sk"))) ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zavrieť") { dismiss() }
                        .foregroundColor(Color.gold400)
                }
            }
        }
        .sensoryFeedback(.success, trigger: goingTick)
        .sensoryFeedback(.impact(weight: .light), trigger: declineTick)
        .fullScreenCover(item: $browser) { KSISBrowserView(startURL: $0.url) }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(event.name)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundColor(.white)
                .strikethrough(event.isCancelled)
            if event.isCancelled {
                Text("Zrušené")
                    .font(.footnote.weight(.bold))
                    .foregroundColor(.white.opacity(0.75))
            } else if let note = event.note {
                KSISEventNote(text: note)
                    .font(.footnote.weight(.semibold))
            }
        }
    }

    private var facts: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !event.venue.isEmpty { fact("mappin.and.ellipse", event.venue) }
            if !event.organizer.isEmpty { fact("person.2", event.organizer) }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .homeCard(cornerRadius: 18)
    }

    private func fact(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(Color.gold400)
                .frame(width: 22)
                .accessibilityHidden(true)
            Text(text)
                .foregroundColor(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.footnote)
    }

    @ViewBuilder
    private var goingButton: some View {
        if isGoing {
            GoingConfirmation(decline: decline)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
        } else {
            PrimarySheetButton(title: "Idem", isLoading: false, isEnabled: true, action: go)
                .transition(.scale(scale: 0.96).combined(with: .opacity))
        }
    }

    private func go() {
        guard let date = event.dateValue else { return }
        PlannedCompetition.goingFromKSIS(name: event.name, venue: event.venue, date: date, categories: myCategories,
                                         propId: event.propId, context: modelContext)
        goingTick += 1
    }

    private func decline() {
        plannedHere?.setIntent(.declined, context: modelContext)
        declineTick += 1
    }

    private var categories: some View {
        VStack(alignment: .leading, spacing: 8) {
            HomeSectionHeader(title: "KATEGÓRIE", systemImage: "list.bullet", count: event.categories.count)
            if !myCategories.isEmpty {
                Text(myCategories.joined(separator: " · "))
                    .font(.footnote.weight(.bold))
                    .foregroundColor(Color.gold300)
            }
            Text(event.categories.filter { !myCategories.contains($0) }.joined(separator: ", "))
                .font(.footnote)
                .foregroundColor(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// What Idem did, in words: where the competition went and what it has there. The check pops and a gold line draws
/// round the row as it arrives.
private struct GoingConfirmation: View {
    let decline: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var arrived = false

    var body: some View {
        // Reduce Motion shows the finished row at once.
        let shown = arrived || reduceMotion
        HStack(spacing: 12) {
            Image(systemName: "checkmark")
                .font(.footnote.weight(.black))
                .foregroundColor(Color.obsidian900)
                .frame(width: 30, height: 30)
                .background(Color.gold400, in: Circle())
                .scaleEffect(shown ? 1 : 0.3)
                .animation(.spring(response: 0.45, dampingFraction: 0.5).delay(0.08), value: arrived)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Súťaž je v tvojom Kalendári")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(Color.gold300)
                Text("Nájdeš ju tam aj s Propozíciami, zoznamom prihlásených a Mapou.")
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button("Neidem", action: decline)
                .font(.footnote.weight(.semibold))
                .foregroundColor(.white.opacity(0.7))
                .frame(minHeight: 44)
                .buttonStyle(.pressable)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.gold500.opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .trim(from: 0, to: shown ? 1 : 0)
                .stroke(Color.gold400.opacity(0.4), lineWidth: 1)
                .animation(.easeOut(duration: 0.6), value: arrived)
        )
        .accessibilityElement(children: .contain)
        .onAppear { arrived = true }
    }
}

// MARK: - Pages of a competition
/// Propozície, entries, the timetable once KSIS has it, and the place in Google Maps. Also on the competition in Kalendár.
struct KSISEventLinks: View {
    /// Nil until KSIS publishes the propositions; the place is known before that.
    let propId: Int?
    let registered: Int?
    let hasTimetable: Bool
    let venue: String
    let open: (URL) -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible())], spacing: 8) {
            if let propId {
                link("Propozície", icon: "doc.text", url: KSISEvent.propositionsURL(propId))
                link(registered.map { "Prihlásení (\($0))" } ?? "Prihlásení", icon: "person.3", url: KSISEvent.entriesURL(propId))
                if hasTimetable {
                    link("Harmonogram", icon: "clock", url: KSISEvent.timetableURL(propId))
                }
            }
            if !venue.isEmpty, let maps = KSISEvent.mapsURL(venue: venue) {
                Button { openURL(maps) } label: { KSISLinkChip(title: "Mapa", icon: "map", fills: true) }
                    .buttonStyle(.pressable)
            }
        }
    }

    private func link(_ title: String, icon: String, url: URL?) -> some View {
        Button {
            if let url { open(url) }
        } label: {
            KSISLinkChip(title: title, icon: icon, fills: true)
        }
        .buttonStyle(.pressable)
    }
}

/// A link to a KSIS page.
struct KSISLinkChip: View {
    let title: String
    let icon: String
    /// As wide as its place in a grid.
    var fills = false

    var body: some View {
        Label(title, systemImage: icon)
            .font(.caption.weight(.bold))
            .foregroundColor(.white)
            .lineLimit(1)
            // "Prihlásení" gets its count after a read: the new title replaces the old one, it does not blend with it.
            .contentTransition(.identity)
            .padding(.horizontal, 12)
            .frame(maxWidth: fills ? .infinity : nil, minHeight: 38)
            .background(Color.white.opacity(0.08), in: Capsule())
    }
}

// MARK: - Filter chip
/// One filter. Turning it on fills it with gold and gives a small bounce; a menu chip shows what is picked.
struct FilterChip: View {
    let title: String
    let isOn: Bool
    var hasMenu = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            if isOn && !hasMenu {
                Image(systemName: "checkmark")
                    .font(.caption2.weight(.black))
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
            }
            Text(title)
                .contentTransition(.interpolate)
            if hasMenu {
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
            }
        }
        .font(.caption.weight(.bold))
        .foregroundColor(isOn ? Color.obsidian900 : .white)
        .padding(.horizontal, 12)
        .frame(minHeight: 34)
        .background(isOn ? Color.gold400 : Color.white.opacity(0.08), in: Capsule())
        .contentShape(Capsule())
        .scaleEffect(isOn && !reduceMotion ? 1.03 : 1)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.6), value: isOn)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: title)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
