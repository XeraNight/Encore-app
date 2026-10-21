import SwiftUI
import SwiftData

/// The 20-second reflection after a training: dictate or type, pick the dance and how it felt, and (Plus)
/// the coach's Top 3 for that dance. The text is saved as an `InstantNote` (tag #Reflexia) so it lands in
/// the same inbox as every note; the Top 3 stays on Home and in Plán until ticked off.
struct DebriefSheet: View {
    let entry: TrainingLogEntry

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Dance.name) private var dances: [Dance]
    @Query private var priorities: [LessonPriority]
    @Query private var sessions: [PlannedSession]
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    @StateObject private var speech = SpeechRecognizerHelper()
    @State private var text = ""
    @State private var danceName: String?
    @State private var feeling: TrainingFeeling?
    @State private var saveTick = 0
    @State private var priorityTexts = ["", "", ""]
    @State private var showPaywall = false
    @State private var goalOutcome: SessionGoalOutcome?
    /// What was written before dictation started; the dictated words are added after it.
    @State private var dictationBase = ""
    @State private var confirmDiscard = false
    @State private var isSaving = false

    /// The one-off training this reflection is for, when it had a goal.
    private var sessionWithGoal: PlannedSession? {
        guard let id = entry.sessionId, let session = sessions.first(where: { $0.id == id }), !session.goal.isEmpty else { return nil }
        return session
    }

    private var canWritePriorities: Bool { subscriptionManager.currentTier >= .plus }

    private var cleanedPriorities: [String] {
        priorityTexts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    /// Only a real change makes a new Top 3; opening and saving the reflection keeps the old one as it is.
    private var prioritiesChanged: Bool {
        guard let danceName, canWritePriorities, !cleanedPriorities.isEmpty else { return false }
        return cleanedPriorities != LessonPriorities.openTexts(for: danceName, in: priorities)
    }

    private var hasChanges: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines) != entry.reflectionNote
            || danceName != entry.danceName || feeling != entry.feeling
            || goalOutcome != sessionWithGoal?.goalOutcome || prioritiesChanged
    }

    /// "dnes" only on the day of the training; a reflection written the next morning asks without it.
    private var question: String {
        PlannerCalendar.calendar.isDateInToday(entry.day) ? "Čo kľúčové ste dnes vylepšili?" : "Čo kľúčové ste vylepšili?"
    }

    private var canSave: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || feeling != nil || prioritiesChanged || goalOutcome != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(question)
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundColor(.white)
                        if !PlannerCalendar.calendar.isDateInToday(entry.day) {
                            Text(entry.day.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "sk"))))
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(Color.gold400)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        ZStack(alignment: .topLeading) {
                            if text.isEmpty {
                                Text("Napíš alebo nadiktuj pár viet…")
                                    .foregroundColor(Color.white.opacity(0.35))
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: $text)
                                .scrollContentBackground(.hidden)
                                .foregroundColor(.white)
                                .frame(minHeight: 130)
                        }
                        .font(.callout)

                        Button(action: toggleDictation) {
                            Label(speech.isRecording ? "Zastaviť diktovanie" : "Diktovať",
                                  systemImage: speech.isRecording ? "stop.fill" : "mic.fill")
                                .font(.footnote.weight(.bold))
                                .foregroundColor(speech.isRecording ? .white : Color.obsidian900)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(speech.isRecording ? Color.latinCrimson : Color.gold400, in: Capsule())
                        }
                        .buttonStyle(.pressable)

                        if let error = speech.errorMessage {
                            Text(error)
                                .font(.footnote)
                                .foregroundColor(Color.latinRed)
                                .fixedSize(horizontal: false, vertical: true)
                                .transition(.opacity)
                        }
                    }
                    .plannerCard()
                    .animation(.easeOut(duration: 0.2), value: speech.errorMessage)

                    if let session = sessionWithGoal {
                        goalSection(session)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        plannerSectionTitle("TANEC")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(dances) { dance in
                                    chip(dance.name, isOn: danceName == dance.name) {
                                        danceName = (danceName == dance.name) ? nil : dance.name
                                    }
                                }
                            }
                        }
                        .scrollClipDisabled()
                    }

                    prioritiesSection

                    VStack(alignment: .leading, spacing: 10) {
                        plannerSectionTitle("AKO TO BOLO")
                        HStack(spacing: 10) {
                            ForEach(TrainingFeeling.allCases) { item in
                                Button {
                                    feeling = (feeling == item) ? nil : item
                                } label: {
                                    VStack(spacing: 4) {
                                        Text(item.emoji).font(.title)
                                        Text(item.title)
                                            .font(.caption2.weight(.semibold))
                                            .foregroundColor(.white.opacity(0.85))
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        feeling == item ? Color.gold400.opacity(0.22) : Color.white.opacity(0.06),
                                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(feeling == item ? Color.gold400 : Color.white.opacity(0.08), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.pressable)
                            }
                        }
                    }

                    Button(action: save) {
                        Text("Uložiť reflexiu")
                            .font(.callout.weight(.bold))
                            .foregroundColor(Color.obsidian900)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(canSave ? Color.gold400 : Color.white.opacity(0.15), in: Capsule())
                    }
                    .buttonStyle(.pressable)
                    .disabled(!canSave)
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(EllegancePageBackground())
            .navigationTitle(entry.title.isEmpty ? "Tréning" : entry.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zrušiť") {
                        if hasChanges { confirmDiscard = true } else { dismiss() }
                    }
                }
            }
            .onChange(of: speech.transcript) { _, newValue in
                if !newValue.isEmpty { text = afterDictation(newValue) }
            }
            .interactiveDismissDisabled(hasChanges)
            .confirmationDialog("Zahodiť reflexiu?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Zahodiť", role: .destructive) { dismiss() }
                Button("Písať ďalej", role: .cancel) {}
            } message: {
                Text("Napísaný text sa neuloží.")
            }
            .onAppear {
                text = entry.reflectionNote
                danceName = entry.danceName
                feeling = entry.feeling
                goalOutcome = sessionWithGoal?.goalOutcome
            }
            .onDisappear { _ = speech.stopTranscribing() }
            .onChange(of: danceName, initial: true) { _, dance in
                guard let dance else { return }
                let open = LessonPriorities.openTexts(for: dance, in: priorities)
                priorityTexts = open + Array(repeating: "", count: max(0, LessonPriorities.maxCount - open.count))
            }
            .sheet(isPresented: $showPaywall) {
                SubscriptionPaywallView(initialTier: .plus)
            }
            .sensoryFeedback(.success, trigger: saveTick)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Goal of a one-off training
    /// The plan and the floor often differ: the goal can be met, half met, or the training went elsewhere.
    private func goalSection(_ session: PlannedSession) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            plannerSectionTitle("CIEĽ")
            VStack(alignment: .leading, spacing: 12) {
                Label(session.goal, systemImage: "target")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color.gold300)
                PlannerChoice(
                    options: SessionGoalOutcome.allCases.map { (Optional($0), $0.title) },
                    selection: $goalOutcome
                )
                if let hint = goalHint(session) {
                    Text(hint)
                        .font(.footnote)
                        .foregroundColor(Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                }
            }
            .plannerCard()
            .animation(.easeOut(duration: 0.2), value: goalOutcome)
        }
    }

    private func goalHint(_ session: PlannedSession) -> String? {
        switch goalOutcome {
        case .done: return session.goalPriorityId == nil ? nil : "Priorita sa v Top 3 odškrtne."
        case .partly: return "Cieľ ostáva otvorený na ďalší tréning."
        case .other: return "Napíš hore, čo ste riešili namiesto toho. Cieľ ostáva otvorený."
        case nil: return nil
        }
    }

    // MARK: Top 3
    @ViewBuilder
    private var prioritiesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            plannerSectionTitle("TOP 3 OD TRÉNERA")
            if canWritePriorities {
                LessonPriorityFields(texts: $priorityTexts, isEnabled: danceName != nil)
                if danceName == nil {
                    Text("Vyber tanec a zapíš 3 hlavné korekcie. Uvidíš ich na Domove, kým ich nezvládneš.")
                        .font(.caption)
                        .foregroundColor(Color.textSecondary)
                }
            } else {
                Button {
                    showPaywall = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "lock.fill")
                            .foregroundColor(Color.gold400)
                        Text("Zapíš si 3 hlavné korekcie trénera pre tanec. Budú na Domove, kým ich nezvládneš.")
                            .font(.footnote)
                            .foregroundColor(Color.white.opacity(0.8))
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        Text("PLUS")
                            .font(.system(.caption2, design: .rounded).weight(.black))
                            .foregroundColor(Color.obsidian900)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.gold400, in: Capsule())
                    }
                    .plannerCard(cornerRadius: 14)
                }
                .buttonStyle(.pressable)
            }
        }
    }

    private func chip(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .foregroundColor(isOn ? Color.obsidian900 : Color.white.opacity(0.85))
                .background(isOn ? Color.gold400 : Color.white.opacity(0.07), in: Capsule())
        }
        .buttonStyle(.pressable)
    }

    private func toggleDictation() {
        if speech.isRecording {
            let captured = speech.stopTranscribing()
            if !captured.isEmpty { text = afterDictation(captured) }
        } else {
            dictationBase = text
            speech.requestPermissions()
            speech.transcript = ""
            speech.startTranscribing()
        }
    }

    /// Dictation adds to what is written, it never replaces it.
    private func afterDictation(_ spoken: String) -> String {
        let base = dictationBase.trimmingCharacters(in: .whitespacesAndNewlines)
        return base.isEmpty ? spoken : "\(base) \(spoken)"
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        if speech.isRecording {
            let captured = speech.stopTranscribing()
            if !captured.isEmpty { text = afterDictation(captured) }
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        entry.reflectionNote = trimmed
        entry.danceName = danceName
        entry.feeling = feeling
        entry.status = .attended

        if let session = sessionWithGoal {
            let wasDone = session.goalOutcome == .done
            session.goalOutcome = goalOutcome
            if let priorityId = session.goalPriorityId,
               let priority = priorities.first(where: { $0.id == priorityId }), priority.replacedAt == nil {
                // Splnené ticks the Top 3 item off; changing it back later opens it again.
                if goalOutcome == .done, priority.doneAt == nil {
                    priority.doneAt = Date()
                } else if wasDone, goalOutcome != .done {
                    priority.doneAt = nil
                }
            }
        }

        if prioritiesChanged, let danceName {
            LessonPriorities.save(priorityTexts, danceName: danceName, logEntryId: entry.id, in: modelContext)
        }

        if trimmed.isEmpty {
            // Text deleted: the note in Poznámky goes too, it would keep the old words.
            if let noteId = entry.noteId, let existing = fetchNote(noteId) { modelContext.delete(existing) }
            entry.noteId = nil
        } else {
            if let noteId = entry.noteId, let existing = fetchNote(noteId) {
                existing.text = trimmed
                existing.danceName = danceName
            } else {
                let note = InstantNote(text: trimmed, danceName: danceName)
                modelContext.insert(note)
                entry.noteId = note.id
            }
        }

        try? modelContext.save()
        saveTick += 1
        dismiss()
    }

    private func fetchNote(_ id: UUID) -> InstantNote? {
        var descriptor = FetchDescriptor<InstantNote>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }
}
