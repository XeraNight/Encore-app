import SwiftUI
import SwiftData

/// "Súťaže" part of the planner: competitions the dancer tracks (entered by hand for now).
struct PlannerCompetitionsView: View {
    let competitions: [PlannedCompetition]

    @Environment(\.modelContext) private var modelContext
    @State private var editing: PlannedCompetition?
    @State private var showNew = false

    private var today: Date { PlannerCalendar.startOfDay(Date()) }
    private var upcoming: [PlannedCompetition] {
        competitions.filter { PlannerCalendar.startOfDay($0.date) >= today }
    }
    private var past: [PlannedCompetition] {
        competitions.filter { PlannerCalendar.startOfDay($0.date) < today }.reversed()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            plannerSectionTitle("NADCHÁDZAJÚCE SÚŤAŽE")

            if upcoming.isEmpty {
                Text("Pridaj súťaž a nastav Idem. Appka ti pripomenie uzávierku prihlášok a deň pred súťažou.")
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .plannerCard()
            }

            ForEach(upcoming) { card($0) }

            Button { showNew = true } label: {
                Label("Pridať súťaž", systemImage: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.obsidian900)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(Color.gold400, in: Capsule())
            }
            .buttonStyle(.pressable)

            if !past.isEmpty {
                plannerSectionTitle("MINULÉ")
                    .padding(.top, 8)
                ForEach(past) { card($0) }
            }

            Text("Zoznam turnajov priamo z KSIS a sledovanie bodov pribudnú neskôr.")
                .font(.system(size: 11))
                .foregroundColor(Color.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: competitions.map(\.id))
        .sheet(isPresented: $showNew) { CompetitionEditorSheet(competition: nil) }
        .sheet(item: $editing) { CompetitionEditorSheet(competition: $0) }
    }

    private func card(_ comp: PlannedCompetition) -> some View {
        Button { editing = comp } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(PlannerCalendar.daysText(until: comp.date))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(Color.gold400)
                    if comp.isTargetCompetition {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color.gold300)
                    }
                    Spacer()
                    Text(comp.intent.title)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(chipText(comp.intent))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(chipFill(comp.intent), in: Capsule())
                }
                Text(comp.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text("\(comp.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))\(comp.city.isEmpty ? "" : " · \(comp.city)")")
                    .font(.system(size: 12))
                    .foregroundColor(Color.white.opacity(0.6))
                if !comp.targetCategories.isEmpty {
                    Text(comp.targetCategories.joined(separator: " · "))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.gold300.opacity(0.85))
                }
                if let deadline = comp.entryDeadline {
                    Label("Uzávierka: \(deadline.formatted(.dateTime.day().month()))", systemImage: "clock")
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .plannerCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .contextMenu {
            ForEach(CompetitionIntent.allCases) { intent in
                Button(intent.title) {
                    comp.intent = intent
                    try? modelContext.save()
                }
            }
            Button(role: .destructive) {
                modelContext.delete(comp)
                try? modelContext.save()
            } label: { Label("Zmazať", systemImage: "trash") }
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

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var city = ""
    @State private var date = Date()
    @State private var hasDeadline = false
    @State private var deadline = Date()
    @State private var categories = ""
    @State private var intent: CompetitionIntent = .interested
    @State private var isTarget = false
    @State private var inCalendar = false
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Súťaž") {
                    TextField("Názov (napr. Grand Prix Žilina)", text: $name)
                    TextField("Mesto", text: $city)
                    DatePicker("Dátum", selection: $date, displayedComponents: .date)
                    TextField("Kategórie (oddelené čiarkou)", text: $categories)
                }

                Section("Prihlášky") {
                    Toggle("Uzávierka prihlášok", isOn: $hasDeadline)
                    if hasDeadline {
                        DatePicker("Uzávierka", selection: $deadline, displayedComponents: .date)
                    }
                }

                Section("Môj plán") {
                    Picker("Idem?", selection: $intent) {
                        ForEach(CompetitionIntent.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Toggle("Hlavná súťaž sezóny", isOn: $isTarget)
                }

                Section {
                    Toggle("V Apple Kalendári", isOn: $inCalendar)
                }

                if competition != nil {
                    Section {
                        Button("Zmazať súťaž", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(EllegancePageBackground())
            .navigationTitle(competition == nil ? "Nová súťaž" : "Upraviť súťaž")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Zrušiť") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Uložiť", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .confirmationDialog("Zmazať súťaž?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Zmazať", role: .destructive) {
                    if let competition {
                        if let eventId = competition.calendarEventId {
                            Task { _ = await CalendarExporter.shared.removeEvent(id: eventId) }
                        }
                        modelContext.delete(competition)
                    }
                    try? modelContext.save()
                    dismiss()
                }
            }
            .onAppear(perform: load)
        }
        .preferredColorScheme(.dark)
    }

    private func load() {
        guard let competition else { return }
        name = competition.name
        city = competition.city
        date = competition.date
        hasDeadline = competition.entryDeadline != nil
        deadline = competition.entryDeadline ?? competition.date
        categories = competition.targetCategories.joined(separator: ", ")
        intent = competition.intent
        isTarget = competition.isTargetCompetition
        inCalendar = competition.calendarEventId != nil
    }

    private func save() {
        let eventBefore = competition.map { [$0.name, $0.city, "\($0.date)", $0.targetCategories.joined()] }
        let target: PlannedCompetition
        if let competition {
            target = competition
        } else {
            target = PlannedCompetition(name: name, city: city, date: date)
            modelContext.insert(target)
        }
        target.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        target.city = city.trimmingCharacters(in: .whitespacesAndNewlines)
        target.date = date
        target.entryDeadline = hasDeadline ? deadline : nil
        target.targetCategories = categories
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        target.intent = intent
        target.isTargetCompetition = isTarget
        try? modelContext.save()

        let wantsCalendar = inCalendar
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
