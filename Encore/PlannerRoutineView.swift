import SwiftUI
import SwiftData

/// "Režim" part of the planner: the permanent weekly training rhythm.
struct PlannerRoutineView: View {
    let cadences: [TrainingCadence]

    @Environment(\.modelContext) private var modelContext
    @State private var editing: TrainingCadence?
    @State private var showNew = false
    @State private var confirmRemoveFromCalendar = false
    @State private var calendarMessage: String?
    @State private var isRemovingFromCalendar = false
    @State private var isSelecting = false
    @State private var selected: Set<UUID> = []
    @State private var confirmDeleteSelected = false

    private var sorted: [TrainingCadence] {
        cadences.sorted { ($0.weekday, $0.startMinutes) < ($1.weekday, $1.startMinutes) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HomeSectionHeader(title: "MÔJ TÝŽDENNÝ REŽIM", systemImage: "repeat") {
                if !sorted.isEmpty {
                    Button(isSelecting ? "Hotovo" : "Vybrať") {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            isSelecting.toggle()
                            selected = []
                        }
                    }
                    .font(.caption.weight(.bold))
                    .foregroundColor(Color.gold400)
                    .frame(minHeight: 44)
                    .buttonStyle(.pressable)
                }
            }

            if sorted.isEmpty {
                Text("Zatiaľ tu nič nie je. Pridaj tréningy, ktoré máš každý týždeň, a appka ti v daný deň ponúkne Idem / Nejdem a po tréningu reflexiu.")
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .plannerCard()
            }

            ForEach(sorted) { cadence in
                row(cadence)
            }

            if isSelecting {
                Button { confirmDeleteSelected = true } label: {
                    Label(selected.isEmpty ? "Označ tréningy na zmazanie" : "Zmazať vybrané (\(selected.count))", systemImage: "trash")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(selected.isEmpty ? .white.opacity(0.5) : .white)
                        .contentTransition(.numericText())
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(selected.isEmpty ? Color.white.opacity(0.06) : Color.latinRed,
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.pressable)
                .disabled(selected.isEmpty)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                Button { showNew = true } label: {
                    Label("Pridať tréning", systemImage: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.obsidian900)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(Color.gold400, in: Capsule())
                }
                .buttonStyle(.pressable)

                if !sorted.isEmpty {
                    calendarCleanup
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: sorted.map(\.id))
        .confirmationDialog(
            "Odstrániť tréningy z Apple Kalendára?",
            isPresented: $confirmRemoveFromCalendar,
            titleVisibility: .visible
        ) {
            Button("Odstrániť všetky budúce tréningy", role: .destructive) { removeAllFromCalendar() }
        } message: {
            Text("Zmažú sa len udalosti, ktoré vytvorila Encore. Tvoj týždenný režim v aplikácii ostane.")
        }
        .confirmationDialog(
            "Zmazať \(slovakCount(selected.count, one: "tréning", few: "tréningy", many: "tréningov"))?",
            isPresented: $confirmDeleteSelected,
            titleVisibility: .visible
        ) {
            Button("Zmazať všetky budúce", role: .destructive, action: deleteSelected)
        } message: {
            Text("Zmiznú z Plánu a ich budúce termíny aj z Apple Kalendára. Zapísané reflexie ostanú.")
        }
        .sensoryFeedback(.selection, trigger: selected)
        .sheet(isPresented: $showNew) { CadenceEditorSheet(cadence: nil) }
        .sheet(item: $editing) { CadenceEditorSheet(cadence: $0) }
    }

    private func deleteSelected() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            for cadence in cadences where selected.contains(cadence.id) {
                cadence.delete(in: modelContext)
            }
            selected = []
            isSelecting = false
        }
    }

    private func toggleSelection(_ cadence: TrainingCadence) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if selected.contains(cadence.id) { selected.remove(cadence.id) } else { selected.insert(cadence.id) }
        }
    }

    private var calendarCleanup: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button { confirmRemoveFromCalendar = true } label: {
                Label("Odstrániť tréningy z Apple Kalendára", systemImage: "calendar.badge.minus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.75))
                    .padding(.vertical, 6)
            }
            .buttonStyle(.pressable)
            .disabled(isRemovingFromCalendar)

            if let calendarMessage {
                Text(calendarMessage)
                    .font(.system(size: 12))
                    .foregroundColor(Color.white.opacity(0.55))
            }
        }
        .padding(.top, 4)
    }

    private func removeAllFromCalendar() {
        isRemovingFromCalendar = true
        let ids = cadences.compactMap(\.calendarEventId)
        Task {
            let result = await CalendarExporter.shared.removeTrainings(eventIds: ids, includeUnknownSeries: true)
            switch result {
            case .removed(let count):
                for cadence in cadences {
                    cadence.calendarEventId = nil
                    cadence.inAppleCalendar = false
                }
                try? modelContext.save()
                calendarMessage = count == 0
                    ? "V kalendári sa nenašiel žiadny tréning z Encore."
                    : "Odstránené z kalendára: \(count)."
            case .accessDenied:
                calendarMessage = "Chýba prístup ku kalendáru. Povoľ ho v Nastaveniach iPhonu."
            }
            isRemovingFromCalendar = false
        }
    }

    private func row(_ cadence: TrainingCadence) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if isSelecting {
                Image(systemName: selected.contains(cadence.id) ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(selected.contains(cadence.id) ? Color.latinRed : .white.opacity(0.35))
                    .contentTransition(.symbolEffect(.replace))
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityHidden(true)
            }
            Button { isSelecting ? toggleSelection(cadence) : (editing = cadence) } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(PlannerCalendar.weekdayName(iso: cadence.weekday)) · \(PlannerCalendar.timeRange(of: cadence))")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(Color.gold400)
                    Text(cadence.title.isEmpty ? "Tréning" : cadence.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    if !cadence.location.isEmpty {
                        Label(cadence.location, systemImage: "mappin.and.ellipse")
                            .font(.system(size: 12))
                            .foregroundColor(Color.white.opacity(0.55))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)

            if !isSelecting {
                // Paused (e.g. summer): no reminders and no future dates in Apple Calendar until it is back on.
                Toggle("", isOn: Binding(
                    get: { cadence.isEnabled },
                    set: { isOn in
                        cadence.isEnabled = isOn
                        cadence.inAppleCalendar = cadence.inAppleCalendar || cadence.calendarEventId != nil
                        try? modelContext.save()
                        Task { await cadence.syncAppleCalendar(changed: false, context: modelContext) }
                    }
                ))
                .accessibilityLabel(cadence.isEnabled ? "Pozastaviť tréning" : "Zapnúť tréning")
                .labelsHidden()
                .tint(Color.gold500)
            }
        }
        .plannerCard()
        .opacity(cadence.isEnabled ? 1 : 0.55)
        .contextMenu {
            Button { editing = cadence } label: { Label("Upraviť", systemImage: "pencil") }
            if cadence.calendarEventId != nil {
                Button {
                    cadence.inAppleCalendar = false
                    Task { await cadence.syncAppleCalendar(changed: false, context: modelContext) }
                } label: { Label("Odstrániť z kalendára", systemImage: "calendar.badge.minus") }
            }
            Button(role: .destructive) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { cadence.delete(in: modelContext) }
            } label: { Label("Zmazať", systemImage: "trash") }
        }
    }
}

// MARK: - Editor
struct CadenceEditorSheet: View {
    let cadence: TrainingCadence?
    /// Day of the week to start from when adding (a day tapped in the calendar).
    var initialWeekday: Int? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var weekday = 2
    @State private var startDate = PlannerCalendar.date(on: Date(), minutes: 18 * 60)
    @State private var duration = 90
    @State private var location = ""
    @State private var category = "Standard"
    @State private var inCalendar = false
    @State private var saveTick = 0

    private var weekdays: [(value: Int, title: String)] {
        let symbols = PlannerCalendar.calendar.shortStandaloneWeekdaySymbols
        return (1...7).map { iso in
            let name = symbols[iso % 7]
            return (iso, name.prefix(1).uppercased() + name.dropFirst())
        }
    }

    var body: some View {
        PlannerEditorScaffold(
            title: cadence == nil ? "Nový tréning" : "Upraviť tréning",
            canSave: true,
            onSave: save,
            delete: cadence.map { cadence in
                PlannerEditorDelete(
                    buttonTitle: "Zmazať tréning",
                    question: "Zmazať týždenný tréning?",
                    message: "Zmizne z Plánu a všetky budúce termíny aj z Apple Kalendára. Zapísané reflexie ostanú.",
                    actions: [.init(title: "Zmazať všetky budúce") { cadence.delete(in: modelContext) }]
                )
            }
        ) {
            PlannerFormSection(title: "TRÉNING", systemImage: "figure.dance") {
                PlannerTextField(placeholder: "Názov (napr. Vedený tréning)", text: $title, systemImage: "textformat")
                PlannerTextField(placeholder: "Miesto (napr. Sála 1)", text: $location, systemImage: "mappin.and.ellipse")
                PlannerChoice(options: PlannerDisciplineChoice.training, selection: $category)
            }

            PlannerFormSection(title: "KAŽDÝ TÝŽDEŇ", systemImage: "repeat") {
                PlannerChoice(options: weekdays, selection: $weekday)
                PlannerDateRow(title: "Začiatok", systemImage: "clock", date: $startDate, components: .hourAndMinute)
                PlannerDurationStepper(minutes: $duration)
            }

            PlannerFormSection(title: "PRIPOMIENKY", systemImage: "bell.fill") {
                PlannerCalendarToggle(
                    subtitle: "Opakovaná udalosť každý týždeň s pripomienkou 30 minút vopred.",
                    isOn: $inCalendar
                )
            }
        }
        .sensoryFeedback(.success, trigger: saveTick)
        .onAppear(perform: load)
    }

    private func load() {
        guard let cadence else {
            if let initialWeekday { weekday = initialWeekday }
            return
        }
        title = cadence.title
        weekday = cadence.weekday
        startDate = PlannerCalendar.date(on: Date(), minutes: cadence.startMinutes)
        duration = cadence.durationMinutes
        location = cadence.location
        category = cadence.danceCategory
        inCalendar = cadence.inAppleCalendar || cadence.calendarEventId != nil
    }

    private func save() {
        let comps = PlannerCalendar.calendar.dateComponents([.hour, .minute], from: startDate)
        let minutes = (comps.hour ?? 18) * 60 + (comps.minute ?? 0)
        let eventBefore = cadence.map { [$0.title, $0.location, "\($0.weekday)", "\($0.startMinutes)", "\($0.durationMinutes)"] }

        let target: TrainingCadence
        if let cadence {
            target = cadence
        } else {
            target = TrainingCadence(weekday: weekday, title: title, startMinutes: minutes)
            modelContext.insert(target)
        }
        target.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        target.weekday = weekday
        target.startMinutes = minutes
        target.durationMinutes = duration
        target.location = location.trimmingCharacters(in: .whitespacesAndNewlines)
        target.danceCategory = category
        try? modelContext.save()
        saveTick += 1

        target.inAppleCalendar = inCalendar
        try? modelContext.save()
        let eventChanged = eventBefore != [target.title, target.location, "\(target.weekday)", "\(target.startMinutes)", "\(target.durationMinutes)"]
        let context = modelContext
        Task {
            // Ask for notification permission in context, the first time a session exists.
            if !NotificationManager.shared.isAuthorized {
                _ = await NotificationManager.shared.requestAuthorization()
            }
            await target.syncAppleCalendar(changed: eventChanged, context: context)
        }
        dismiss()
    }
}

@MainActor
extension TrainingCadence {
    /// Deletes the weekly training here and its future dates in Apple Calendar (past ones stay there).
    func delete(in context: ModelContext) {
        let seriesId = calendarEventId
        let restored = Self.restoredDaysAhead(cadenceId: id, context: context)
        Task {
            if let seriesId { _ = await CalendarExporter.shared.retireSeries(id: seriesId) }
            for entry in restored { await Self.removeRestoredEvent(of: entry) }
            try? context.save()
        }
        context.delete(self)
        try? context.save()
    }

    /// Brings Apple Calendar in step with the training. A change gets a new series from the next date (the old
    /// one ends yesterday, so its history stays); a paused or unwanted training has no future dates; days
    /// cancelled ahead (Nejdem) stay out of the new series.
    func syncAppleCalendar(changed: Bool, context: ModelContext) async {
        let exporter = CalendarExporter.shared
        if let seriesId = calendarEventId, changed || !inAppleCalendar || !isEnabled {
            guard await exporter.retireSeries(id: seriesId) else { return }
            calendarEventId = nil
            // A restored single date would double the new series or outlive the pause.
            for entry in Self.restoredDaysAhead(cadenceId: id, context: context) {
                await Self.removeRestoredEvent(of: entry)
            }
        }
        if inAppleCalendar, isEnabled, calendarEventId == nil, let seriesId = await exporter.export(cadence: self) {
            calendarEventId = seriesId
            for day in cancelledDaysAhead(context: context) {
                _ = await exporter.removeOccurrence(seriesId: seriesId, on: day)
            }
        }
        try? context.save()
    }

    private func cancelledDaysAhead(context: ModelContext) -> [Date] {
        let cadenceId = id
        let skipped = TrainingStatus.skipped.rawValue
        let today = PlannerCalendar.startOfDay(Date())
        let entries = (try? context.fetch(FetchDescriptor<TrainingLogEntry>(predicate: #Predicate {
            $0.cadenceId == cadenceId && $0.statusRaw == skipped && $0.day >= today
        }))) ?? []
        return entries.map(\.day)
    }

    /// Days ahead that were cancelled and restored: each has its own single event.
    private static func restoredDaysAhead(cadenceId: UUID, context: ModelContext) -> [TrainingLogEntry] {
        let today = PlannerCalendar.startOfDay(Date())
        let entries = (try? context.fetch(FetchDescriptor<TrainingLogEntry>(predicate: #Predicate {
            $0.cadenceId == cadenceId && $0.day >= today
        }))) ?? []
        return entries.filter { $0.calendarEventId != nil && $0.status != .skipped }
    }

    private static func removeRestoredEvent(of entry: TrainingLogEntry) async {
        guard let eventId = entry.calendarEventId else { return }
        if await CalendarExporter.shared.removeEvent(id: eventId) { entry.calendarEventId = nil }
    }
}
