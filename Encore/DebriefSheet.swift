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

    private var canSave: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || feeling != nil || prioritiesChanged || goalOutcome != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Čo kľúčové ste dnes vylepšili?")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

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
                        .font(.system(size: 16))

                        Button(action: toggleDictation) {
                            Label(speech.isRecording ? "Zastaviť diktovanie" : "Diktovať",
                                  systemImage: speech.isRecording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(speech.isRecording ? .white : Color.obsidian900)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(speech.isRecording ? Color.latinCrimson : Color.gold400, in: Capsule())
                        }
                        .buttonStyle(.pressable)
                    }
                    .plannerCard()

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
                                        Text(item.emoji).font(.system(size: 26))
                                        Text(item.title)
                                            .font(.system(size: 11, weight: .semibold))
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
                            .font(.system(size: 16, weight: .bold))
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
                    Button("Zrušiť") { dismiss() }
                }
            }
            .onChange(of: speech.transcript) { _, newValue in
                if !newValue.isEmpty { text = newValue }
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
                        .foregroundColor(.white.opacity(0.6))
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
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.55))
                }
            } else {
                Button {
                    showPaywall = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "lock.fill")
                            .foregroundColor(Color.gold400)
                        Text("Zapíš si 3 hlavné korekcie trénera pre tanec. Budú na Domove, kým ich nezvládneš.")
                            .font(.system(size: 13))
                            .foregroundColor(Color.white.opacity(0.8))
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        Text("PLUS")
                            .font(.system(size: 10, weight: .black, design: .rounded))
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
                .font(.system(size: 12, weight: .semibold))
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
            if !captured.isEmpty { text = captured }
        } else {
            speech.requestPermissions()
            speech.transcript = ""
            speech.startTranscribing()
        }
    }

    private func save() {
        if speech.isRecording {
            let captured = speech.stopTranscribing()
            if !captured.isEmpty { text = captured }
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        entry.reflectionNote = trimmed
        entry.danceName = danceName
        entry.feeling = feeling
        entry.status = .attended

        if let session = sessionWithGoal {
            session.goalOutcome = goalOutcome
            if goalOutcome == .done, let priorityId = session.goalPriorityId,
               let priority = priorities.first(where: { $0.id == priorityId }), priority.isOpen {
                priority.doneAt = Date()
            }
        }

        if prioritiesChanged, let danceName {
            LessonPriorities.save(priorityTexts, danceName: danceName, logEntryId: entry.id, in: modelContext)
        }

        if !trimmed.isEmpty {
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
