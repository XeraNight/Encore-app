import SwiftUI
import SwiftData

// MARK: - One-off training editor
/// Adds or edits a samotréning or an extra lesson on one day. The goal is optional: a Top 3 priority, an own
/// sentence, or nothing yet (it can be decided on the floor and written in the reflection afterwards).
struct SessionEditorSheet: View {
    let session: PlannedSession?
    /// Day to start from when adding (a day tapped in the calendar).
    var initialDate: Date? = nil
    var initialKind: SessionKind = .solo

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \LessonPriority.createdAt, order: .reverse) private var priorities: [LessonPriority]

    @State private var kind: SessionKind = .solo
    @State private var title = ""
    @State private var location = ""
    @State private var category = "Standard"
    @State private var day = Date()
    @State private var startTime = PlannerCalendar.date(on: Date(), minutes: 17 * 60)
    @State private var duration = 60
    @State private var goal = ""
    @State private var goalPriorityId: UUID?
    @State private var inCalendar = false
    @State private var saveTick = 0
    @State private var loaded: String?

    private var signature: String {
        [kind.rawValue, title, location, category, "\(day.timeIntervalSince1970)", "\(startTime.timeIntervalSince1970)",
         "\(duration)", goal, goalPriorityId?.uuidString ?? "", "\(inCalendar)"].joined(separator: "|")
    }

    private var openPriorities: [LessonPriority] {
        LessonPriorities.activeSets(priorities).flatMap { $0.items.filter(\.isOpen) }
    }

    /// The own-goal field shows only a goal that is not a priority.
    private var ownGoal: Binding<String> {
        Binding(
            get: { goalPriorityId == nil ? goal : "" },
            set: { text in
                goal = text
                goalPriorityId = nil
            }
        )
    }

    var body: some View {
        PlannerEditorScaffold(
            title: session == nil ? "Nový tréning" : "Upraviť tréning",
            canSave: true,
            hasChanges: loaded.map { $0 != signature } ?? false,
            onSave: save,
            delete: session.map { session -> PlannerEditorDelete in
                let written = TrainingLogEntry.written(after: session.id, in: modelContext)
                return PlannerEditorDelete(
                    buttonTitle: "Zmazať tréning",
                    question: "Zmazať tréning?",
                    message: written.isEmpty
                        ? "Zmizne z Encore aj z Apple Kalendára."
                        : "Zmizne z Encore aj z Apple Kalendára. Reflexia z neho môže ostať v Denníku, alebo ju zmaž s ním.",
                    actions: written.isEmpty
                        ? [.init(title: "Zmazať") { session.delete(in: modelContext) }]
                        : [.init(title: "Zmazať, reflexia ostane") { session.delete(in: modelContext) },
                           .init(title: "Zmazať aj reflexiu") {
                               written.forEach { modelContext.delete($0) }
                               session.delete(in: modelContext)
                           }]
                )
            }
        ) {
            PlannerFormSection(title: "TRÉNING", systemImage: "figure.dance") {
                PlannerChoice(options: SessionKind.allCases.map { ($0, $0.title) }, selection: $kind)
                PlannerTextField(placeholder: "Názov (nepovinné)", text: $title, systemImage: "textformat")
                PlannerTextField(placeholder: "Miesto (napr. Sála 2)", text: $location, systemImage: "mappin.and.ellipse")
                PlannerChoice(options: PlannerDisciplineChoice.training, selection: $category)
            }

            PlannerFormSection(title: "KEDY", systemImage: "calendar") {
                PlannerDateRow(title: "Deň", systemImage: "calendar", date: $day)
                PlannerDateRow(title: "Začiatok", systemImage: "clock", date: $startTime, components: .hourAndMinute)
                PlannerDurationStepper(minutes: $duration)
            }

            goalSection

            PlannerFormSection(title: "PRIPOMIENKY", systemImage: "bell.fill") {
                PlannerCalendarToggle(subtitle: "Udalosť s pripomienkou 30 minút vopred.", isOn: $inCalendar)
            }
        }
        .sensoryFeedback(.success, trigger: saveTick)
        .sensoryFeedback(.selection, trigger: goalPriorityId)
        .onAppear(perform: load)
    }

    private var goalSection: some View {
        PlannerFormSection(title: "CIEĽ", systemImage: "target") {
            Text("Nemusíš mať plán. Cieľ môžeš doplniť aj po tréningu a v reflexii napísať, čo ste nakoniec riešili.")
                .font(.footnote)
                .foregroundColor(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(openPriorities) { priority in
                priorityRow(priority)
            }

            PlannerTextField(placeholder: "Vlastný cieľ (napr. chassé v rytme)", text: ownGoal, systemImage: "pencil")
        }
    }

    private func priorityRow(_ priority: LessonPriority) -> some View {
        let isOn = goalPriorityId == priority.id
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                if isOn {
                    goalPriorityId = nil
                    goal = ""
                } else {
                    goalPriorityId = priority.id
                    goal = priority.text
                }
            }
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(DanceNames.display(priority.danceName).uppercased())
                        .font(.system(.caption2, design: .rounded).weight(.black))
                        .foregroundColor(Color.gold400)
                        .tracking(1)
                    Text(priority.text)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isOn ? Color.gold400 : .white.opacity(0.3))
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(12)
            .background(isOn ? Color.gold400.opacity(0.12) : Color.white.opacity(0.04),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isOn ? Color.gold400.opacity(0.45) : Color.white.opacity(0.08), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable(scale: 0.97))
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func load() {
        defer { loaded = signature }
        guard let session else {
            if let initialDate { day = initialDate }
            kind = initialKind
            return
        }
        kind = session.kind
        title = session.title
        location = session.location
        category = session.danceCategory
        day = session.start
        startTime = session.start
        duration = session.durationMinutes
        goal = session.goal
        goalPriorityId = session.goalPriorityId
        inCalendar = session.calendarEventId != nil
    }

    private func save() {
        let cal = PlannerCalendar.calendar
        let time = cal.dateComponents([.hour, .minute], from: startTime)
        let start = PlannerCalendar.date(on: day, minutes: (time.hour ?? 17) * 60 + (time.minute ?? 0))
        let eventBefore = session.map { [$0.displayTitle, $0.location, "\($0.start)", "\($0.durationMinutes)", $0.goal] }

        let target: PlannedSession
        if let session {
            target = session
        } else {
            target = PlannedSession(start: start)
            modelContext.insert(target)
        }
        target.kind = kind
        target.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        target.location = location.trimmingCharacters(in: .whitespacesAndNewlines)
        target.danceCategory = category
        target.start = start
        target.durationMinutes = duration
        target.goal = goal.trimmingCharacters(in: .whitespacesAndNewlines)
        target.goalPriorityId = goalPriorityId
        // A training moved to another day takes its going / cancelled / reflection along.
        let sessionId = target.id
        if let entry = try? modelContext.fetch(FetchDescriptor<TrainingLogEntry>(predicate: #Predicate { $0.sessionId == sessionId })).first {
            entry.day = PlannerCalendar.startOfDay(start)
            entry.title = target.displayTitle
        }
        try? modelContext.save()
        saveTick += 1

        let wantsCalendar = inCalendar
        let oldEventId = target.calendarEventId
        let eventChanged = eventBefore != [target.displayTitle, target.location, "\(target.start)", "\(target.durationMinutes)", target.goal]
        Task {
            if !NotificationManager.shared.isAuthorized {
                _ = await NotificationManager.shared.requestAuthorization()
            }
            if let oldEventId {
                guard !wantsCalendar || eventChanged else { return }
                guard await CalendarExporter.shared.removeEvent(id: oldEventId) else { return }
                target.calendarEventId = nil
            }
            if wantsCalendar, let id = await CalendarExporter.shared.export(session: target) {
                target.calendarEventId = id
            }
            try? modelContext.save()
        }
        dismiss()
    }
}

extension TrainingLogEntry {
    /// What was written after a one-off training, or after any day of a weekly one (the ids never clash).
    static func written(after trainingId: UUID, in context: ModelContext) -> [TrainingLogEntry] {
        ((try? context.fetch(FetchDescriptor<TrainingLogEntry>())) ?? [])
            .filter { $0.sessionId == trainingId || $0.cadenceId == trainingId }
    }
}

extension PlannedSession {
    /// Deletes the training here and its event in Apple Calendar. A written reflection stays unless it goes too.
    func delete(in context: ModelContext) {
        if let eventId = calendarEventId {
            Task { _ = await CalendarExporter.shared.removeEvent(id: eventId) }
        }
        context.delete(self)
        try? context.save()
    }
}
