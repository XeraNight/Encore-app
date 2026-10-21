import SwiftUI
import SwiftData

/// "Súťaže" part of the planner: competitions the dancer tracks (entered by hand for now).
struct PlannerCompetitionsView: View {
    let competitions: [PlannedCompetition]

    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var ksis = CompetitionManager.shared
    @State private var editing: PlannedCompetition?
    @State private var showNew = false
    @State private var pendingDelete: PlannedCompetition?
    @State private var showsOlderSeasons = false

    private var today: Date { PlannerCalendar.startOfDay(Date()) }
    private var upcoming: [PlannedCompetition] {
        competitions.filter { PlannerCalendar.startOfDay($0.date) >= today }
    }
    private var past: [PlannedCompetition] {
        competitions.filter { PlannerCalendar.startOfDay($0.date) < today }.reversed()
    }
    /// Past competitions of this season; older seasons only on request, so the list does not grow forever.
    private var pastShown: [PlannedCompetition] {
        let seasonStart = PlannerCalendar.seasonStart()
        return showsOlderSeasons ? past : past.filter { $0.date >= seasonStart }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            plannerSectionTitle("NADCHÁDZAJÚCE SÚŤAŽE")

            if upcoming.isEmpty {
                Text("Pridaj súťaž a nastav Idem. Appka ti pripomenie uzávierku prihlášok a deň pred súťažou.")
                    .font(.footnote)
                    .foregroundColor(Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .plannerCard()
            }

            ForEach(upcoming) { card($0) }

            Button { showNew = true } label: {
                Label("Pridať súťaž", systemImage: "plus")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(Color.obsidian900)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(Color.gold400, in: Capsule())
            }
            .buttonStyle(.pressable)

            if !past.isEmpty {
                plannerSectionTitle("MINULÉ")
                    .padding(.top, 8)
                ForEach(pastShown) { card($0) }
                if past.count > pastShown.count {
                    Button("Staršie sezóny (\(past.count - pastShown.count))") {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showsOlderSeasons = true }
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Color.gold400)
                    .frame(minHeight: 44)
                    .buttonStyle(.pressable)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: competitions.map(\.id))
        .sheet(isPresented: $showNew) { CompetitionEditorSheet(competition: nil) }
        .sheet(item: $editing) { CompetitionEditorSheet(competition: $0) }
        .confirmationDialog("Zmazať súťaž?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                            titleVisibility: .visible, presenting: pendingDelete) { competition in
            Button("Zmazať „\(competition.name)“", role: .destructive) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { competition.delete(in: modelContext) }
            }
        } message: { _ in
            Text("Zmizne z Encore aj z Apple Kalendára.")
        }
    }

    private func card(_ comp: PlannedCompetition) -> some View {
        Button { editing = comp } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(PlannerCalendar.daysText(until: comp.date))
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundColor(Color.gold400)
                    if comp.isTargetCompetition {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(Color.gold300)
                    }
                    Spacer()
                    if let place = comp.dancedPlaceLine(in: ksis.results) {
                        DancedPlaceChip(place: place)
                    } else {
                        Text(comp.intent.title)
                            .font(.caption2.weight(.bold))
                            .foregroundColor(chipText(comp.intent))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(chipFill(comp.intent), in: Capsule())
                    }
                }
                Text(comp.name)
                    .font(.callout.weight(.bold))
                    .foregroundColor(.white)
                Text("\(comp.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))\(comp.city.isEmpty ? "" : " · \(comp.city)")")
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)
                if !comp.targetCategories.isEmpty {
                    Text(comp.targetCategories.joined(separator: " · "))
                        .font(.caption2.weight(.medium))
                        .foregroundColor(Color.gold300.opacity(0.85))
                }
                if let deadline = comp.entryDeadline {
                    Label("Uzávierka: \(deadline.formatted(.dateTime.day().month()))", systemImage: "clock")
                        .font(.caption2)
                        .foregroundColor(Color.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .plannerCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .contextMenu {
            ForEach(CompetitionIntent.allCases) { intent in
                Button(intent.title) { comp.setIntent(intent, context: modelContext) }
            }
            Button(role: .destructive) { pendingDelete = comp } label: { Label("Zmazať", systemImage: "trash") }
        }
    }

    private func chipFill(_ intent: CompetitionIntent) -> Color {
        switch intent {
        case .going: return Color.gold400
        case .interested: return Color.gold500.opacity(0.14)
        case .declined: return Color.white.opacity(0.08)
        }
    }

    private func chipText(_ intent: CompetitionIntent) -> Color {
        switch intent {
        case .going: return Color.obsidian900
        case .interested: return Color.gold300
        case .declined: return Color.white.opacity(0.5)
        }
    }
}

// MARK: - Editor
struct CompetitionEditorSheet: View {
    let competition: PlannedCompetition?
    /// Day to start from when adding (a day tapped in the calendar).
    var initialDate: Date? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var city = ""
    @State private var date = Date()
    @State private var discipline = "Štandard"
    @State private var hasDeadline = false
    @State private var deadline = Date()
    @State private var intent: CompetitionIntent = .interested
    @State private var isTarget = false
    @State private var inCalendar = false
    @State private var saveTick = 0
    @State private var loaded: String?
    /// Categories from KSIS ("Dospelí D ŠTT") stay as they are unless the discipline is changed here.
    @State private var loadedDiscipline: String?

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var deadlineIsValid: Bool {
        !hasDeadline || PlannerCalendar.startOfDay(deadline) <= PlannerCalendar.startOfDay(date)
    }

    private var signature: String {
        [name, city, "\(date.timeIntervalSince1970)", discipline, "\(hasDeadline)", "\(deadline.timeIntervalSince1970)",
         intent.rawValue, "\(isTarget)", "\(inCalendar)"].joined(separator: "|")
    }

    var body: some View {
        PlannerEditorScaffold(
            title: competition == nil ? "Nová súťaž" : "Upraviť súťaž",
            canSave: !trimmedName.isEmpty && deadlineIsValid,
            disabledHint: trimmedName.isEmpty ? "Doplň názov súťaže." : "Uzávierka musí byť najneskôr v deň súťaže.",
            hasChanges: loaded.map { $0 != signature } ?? false,
            onSave: save,
            delete: competition.map { competition in
                PlannerEditorDelete(
                    buttonTitle: "Zmazať súťaž",
                    question: "Zmazať súťaž?",
                    message: "Zmizne z Encore aj z Apple Kalendára.",
                    actions: [.init(title: "Zmazať") { competition.delete(in: modelContext) }]
                )
            }
        ) {
            PlannerFormSection(title: "SÚŤAŽ", systemImage: "trophy.fill") {
                PlannerTextField(placeholder: "Názov (napr. Grand Prix Žilina)", text: $name, systemImage: "textformat")
                PlannerTextField(placeholder: "Mesto", text: $city, systemImage: "mappin.and.ellipse")
                PlannerDateRow(title: "Dátum", systemImage: "calendar", date: $date)
                PlannerChoice(options: PlannerDisciplineChoice.competition, selection: $discipline)
            }

            PlannerFormSection(title: "PRIHLÁŠKY", systemImage: "envelope.fill") {
                PlannerToggleRow(
                    title: "Uzávierka prihlášok",
                    subtitle: "Pripomenieme ti ju 3 dni a 1 deň vopred.",
                    systemImage: "clock.badge.exclamationmark",
                    isOn: $hasDeadline
                )
                if hasDeadline {
                    PlannerDateRow(title: "Uzávierka", systemImage: "calendar.badge.clock", date: $deadline)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }

            PlannerFormSection(title: "MOJA ÚČASŤ", systemImage: "flag.fill") {
                PlannerChoice(
                    options: CompetitionIntent.allCases.map { ($0, $0.title) },
                    selection: $intent
                )
                PlannerToggleRow(title: "Hlavná súťaž sezóny", systemImage: "star.fill", isOn: $isTarget)
                PlannerCalendarToggle(
                    subtitle: intent == .declined
                        ? "Pri Neidem súťaž v Apple Kalendári nebude."
                        : "Celodenná udalosť s pripomienkou deň vopred.",
                    isOn: $inCalendar
                )
                .disabled(intent == .declined)
                .opacity(intent == .declined ? 0.5 : 1)
            }
        }
        .sensoryFeedback(.success, trigger: saveTick)
        .onAppear(perform: load)
    }

    private func load() {
        defer { loaded = signature }
        guard let competition else {
            if let initialDate { date = initialDate }
            return
        }
        name = competition.name
        city = competition.city
        date = competition.date
        discipline = PlannerDisciplineChoice.competitionValue(from: competition.targetCategories)
        hasDeadline = competition.entryDeadline != nil
        deadline = competition.entryDeadline ?? competition.date
        intent = competition.intent
        isTarget = competition.isTargetCompetition
        inCalendar = competition.calendarEventId != nil
        loadedDiscipline = discipline
    }

    private func save() {
        let eventBefore = competition.map { [$0.name, $0.city, "\($0.date)", $0.targetCategories.joined()] }
        let target: PlannedCompetition
        if let competition {
            target = competition
        } else {
            target = PlannedCompetition(name: trimmedName, city: city, date: date)
            modelContext.insert(target)
        }
        target.name = trimmedName
        target.city = city.trimmingCharacters(in: .whitespacesAndNewlines)
        target.date = date
        target.entryDeadline = hasDeadline ? deadline : nil
        if discipline != loadedDiscipline {
            target.targetCategories = PlannerDisciplineChoice.competitionCategories(for: discipline)
        }
        target.intent = intent
        target.isTargetCompetition = isTarget
        try? modelContext.save()
        saveTick += 1

        // Neidem takes the competition out of Apple Calendar, like Nejdem does with a training.
        let wantsCalendar = inCalendar && intent != .declined
        let oldEventId = target.calendarEventId
        let eventChanged = eventBefore != [target.name, target.city, "\(target.date)", target.targetCategories.joined()]
        Task {
            if !NotificationManager.shared.isAuthorized {
                _ = await NotificationManager.shared.requestAuthorization()
            }
            if let oldEventId {
                // Unchanged and still wanted: keep the event as it is.
                guard !wantsCalendar || eventChanged else { return }
                // Changed or no longer wanted: remove it (a changed one is created again below).
                guard await CalendarExporter.shared.removeEvent(id: oldEventId) else { return }
                target.calendarEventId = nil
            }
            if wantsCalendar, let id = await CalendarExporter.shared.export(competition: target) {
                target.calendarEventId = id
            }
            try? modelContext.save()
        }
        dismiss()
    }
}

/// "🏆 3. z 12" on a planned competition that was danced and saved from KSIS.
struct DancedPlaceChip: View {
    let place: String

    var body: some View {
        Label(place, systemImage: "trophy.fill")
            .font(.caption2.weight(.bold))
            .foregroundColor(Color.obsidian900)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.gold400, in: Capsule())
            .transition(.scale.combined(with: .opacity))
    }
}

extension PlannedCompetition {
    /// KSIS results danced on the day of this competition. The name is not compared: what the dancer typed
    /// rarely matches the KSIS title.
    func dancedResults(in results: [CompetitionResult]) -> [CompetitionResult] {
        results.filter { result in
            guard let date = result.dateValue else { return false }
            return PlannerCalendar.calendar.isDate(date, inSameDayAs: self.date)
        }
    }

    /// The best place of the day ("3. z 12"), shown instead of Idem once the competition is danced.
    func dancedPlaceLine(in results: [CompetitionResult]) -> String? {
        dancedResults(in: results).min { ($0.placement ?? Int.max) < ($1.placement ?? Int.max) }?.placeLine
    }

    /// Links past competitions to the KSIS competition saved for the same day (`ksisCompetitionId`).
    static func linkDanced(_ competitions: [PlannedCompetition], to results: [CompetitionResult], context: ModelContext) {
        let today = PlannerCalendar.startOfDay(Date())
        var changed = false
        for competition in competitions where competition.ksisCompetitionId == nil && competition.date < today {
            guard let result = competition.dancedResults(in: results).first else { continue }
            competition.ksisCompetitionId = String(result.sutazId)
            changed = true
        }
        if changed { try? context.save() }
    }

    /// Neidem also takes the competition out of Apple Calendar; switching back does not add it again on its own.
    func setIntent(_ newIntent: CompetitionIntent, context: ModelContext) {
        intent = newIntent
        try? context.save()
        guard newIntent == .declined, let eventId = calendarEventId else { return }
        Task {
            guard await CalendarExporter.shared.removeEvent(id: eventId) else { return }
            calendarEventId = nil
            try? context.save()
        }
    }

    /// Deletes the competition here and its event in Apple Calendar.
    func delete(in context: ModelContext) {
        if let eventId = calendarEventId {
            Task { _ = await CalendarExporter.shared.removeEvent(id: eventId) }
        }
        context.delete(self)
        try? context.save()
    }
}
