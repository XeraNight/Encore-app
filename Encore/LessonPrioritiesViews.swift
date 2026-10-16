import SwiftUI
import SwiftData

// MARK: - Top 3 section (Home and Plán)
/// "TOP 3 PRIORITY": the coach's main corrections per dance, ticked off one by one. Writing a new Top 3
/// is Plus; ticking off what is already there always works.
struct LessonPrioritiesSection: View {
    /// Home shows the section only when something is open; Plán always shows it, with an invitation.
    var showsWhenEmpty = true

    @Query(sort: \LessonPriority.createdAt, order: .reverse) private var priorities: [LessonPriority]
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.modelContext) private var modelContext

    @State private var editor: LessonPriorityEditorTarget?
    @State private var showPaywall = false
    @State private var tickCount = 0
    @State private var finishedCount = 0

    private var sets: [LessonPrioritySet] { LessonPriorities.activeSets(priorities) }
    private var canWrite: Bool { subscriptionManager.currentTier >= .plus }

    var body: some View {
        let sets = sets
        if !sets.isEmpty || showsWhenEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HomeSectionHeader(
                    title: "TOP 3 PRIORITY",
                    systemImage: "target",
                    count: sets.reduce(0) { $0 + $1.openCount }
                ) {
                    Button {
                        openEditor(dance: nil)
                    } label: {
                        Label("Pridať", systemImage: canWrite ? "plus" : "lock.fill")
                            .font(.caption.weight(.bold))
                            .foregroundColor(Color.gold400)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.pressable)
                }

                if sets.isEmpty {
                    emptyCard
                } else {
                    ForEach(sets) { set in
                        setCard(set)
                            .transition(.asymmetric(insertion: .scale(scale: 0.96).combined(with: .opacity),
                                                    removal: .opacity.combined(with: .move(edge: .trailing))))
                    }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.82), value: sets.map(\.id))
            .sensoryFeedback(.selection, trigger: tickCount)
            .sensoryFeedback(.success, trigger: finishedCount)
            .sheet(item: $editor) { target in
                LessonPrioritiesSheet(initialDance: target.dance)
            }
            .sheet(isPresented: $showPaywall) {
                SubscriptionPaywallView(initialTier: .plus)
            }
        }
    }

    private var emptyCard: some View {
        Button {
            openEditor(dance: nil)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "target")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(Color.gold400)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Po lekcii si zapíš 3 hlavné korekcie")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.white)
                    Text("Pre každý tanec. Budeš ich mať tu a v Kalendári, kým ich nezvládneš.")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if !canWrite {
                    Text("PLUS")
                        .font(.system(.caption2, design: .rounded).weight(.black))
                        .foregroundColor(Color.obsidian900)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.gold400, in: Capsule())
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .homeCard()
        }
        .buttonStyle(.pressable)
    }

    private func setCard(_ set: LessonPrioritySet) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(DanceNames.display(set.danceName).uppercased())
                    .font(.system(.caption, design: .rounded).weight(.black))
                    .tracking(1.2)
                    .foregroundColor(Color.gold400)
                Spacer()
                Text(set.createdAt, format: .dateTime.day().month(.abbreviated))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.45))
                Button {
                    openEditor(dance: set.danceName)
                } label: {
                    Image(systemName: canWrite ? "pencil" : "lock.fill")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 44, height: 32)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Upraviť Top 3 pre \(DanceNames.display(set.danceName))")
            }

            ForEach(set.items) { item in
                priorityRow(item, in: set)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .homeCard()
    }

    private func priorityRow(_ item: LessonPriority, in set: LessonPrioritySet) -> some View {
        let isDone = item.doneAt != nil
        return Button {
            toggle(item, in: set)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "\(item.rank).circle")
                    .font(.title3)
                    .foregroundColor(isDone ? Color.syncEmerald : Color.gold400)
                    .contentTransition(.symbolEffect(.replace))
                Text(item.text)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(isDone ? .white.opacity(0.45) : .white)
                    .strikethrough(isDone, color: .white.opacity(0.45))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable(scale: 0.98))
        .accessibilityAddTraits(isDone ? .isSelected : [])
        .accessibilityHint(isDone ? "Ťukni, ak ešte nie je zvládnutá" : "Ťukni, keď ju zvládneš")
    }

    private func toggle(_ item: LessonPriority, in set: LessonPrioritySet) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            item.doneAt = item.doneAt == nil ? Date() : nil
        }
        try? modelContext.save()
        tickCount += 1
        if set.items.allSatisfy({ $0.doneAt != nil }) { finishedCount += 1 }
    }

    private func openEditor(dance: String?) {
        if canWrite {
            editor = LessonPriorityEditorTarget(dance: dance)
        } else {
            showPaywall = true
        }
    }
}

struct LessonPriorityEditorTarget: Identifiable {
    let dance: String?
    var id: String { dance ?? "" }
}

// MARK: - Fields (shared by the sheet and the reflection)
/// Three numbered lines. The keyboard's microphone works for dictation.
struct LessonPriorityFields: View {
    @Binding var texts: [String]
    var isEnabled = true

    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<LessonPriorities.maxCount, id: \.self) { index in
                HStack(spacing: 10) {
                    Text("\(index + 1).")
                        .font(.system(.subheadline, design: .rounded).weight(.black))
                        .foregroundColor(Color.gold400)
                        .frame(width: 22, alignment: .leading)
                    TextField("", text: binding(index),
                              prompt: Text(placeholder(index)).foregroundColor(.white.opacity(0.35)),
                              axis: .vertical)
                        .lineLimit(1...3)
                        .foregroundColor(.white)
                        .submitLabel(.next)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }

    private func binding(_ index: Int) -> Binding<String> {
        Binding(
            get: { texts.indices.contains(index) ? texts[index] : "" },
            set: { newValue in
                while texts.count <= index { texts.append("") }
                texts[index] = newValue
            }
        )
    }

    private func placeholder(_ index: Int) -> String {
        ["Napríklad: ramená dole v otočke", "Druhá korekcia", "Tretia korekcia"][index]
    }
}

// MARK: - Editor sheet
struct LessonPrioritiesSheet: View {
    let initialDance: String?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Dance.name) private var dances: [Dance]
    @Query private var priorities: [LessonPriority]

    @State private var danceName: String?
    @State private var texts = ["", "", ""]

    private var canSave: Bool {
        danceName != nil && texts.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Tri najdôležitejšie veci, ktoré ti tréner dnes povedal. Budeš ich mať na očiach, kým ich nezvládneš.")
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(alignment: .leading, spacing: 10) {
                            HomeSectionHeader(title: "TANEC", systemImage: "music.note")
                            DanceChoiceChips(dances: dances.map(\.name), selection: $danceName)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            HomeSectionHeader(title: "TOP 3", systemImage: "target")
                            LessonPriorityFields(texts: $texts, isEnabled: danceName != nil)
                            if danceName == nil {
                                Text("Najprv vyber tanec.")
                                    .font(.footnote)
                                    .foregroundColor(.white.opacity(0.55))
                            }
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 90)
                }
                .scrollDismissesKeyboard(.interactively)

                VStack {
                    Spacer()
                    PrimarySheetButton(title: "Uložiť Top 3", isLoading: false, isEnabled: canSave, action: save)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                }
            }
            .navigationTitle("Top 3 po lekcii")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zrušiť") { dismiss() }
                        .foregroundColor(Color.gold400)
                }
            }
            .onAppear {
                if danceName == nil { danceName = initialDance }
            }
            .onChange(of: danceName, initial: true) { _, dance in
                guard let dance else { return }
                let open = LessonPriorities.openTexts(for: dance, in: priorities)
                texts = open + Array(repeating: "", count: max(0, LessonPriorities.maxCount - open.count))
            }
        }
        .preferredColorScheme(.dark)
    }

    private func save() {
        guard let danceName else { return }
        LessonPriorities.save(texts, danceName: danceName, in: modelContext)
        dismiss()
    }
}

// MARK: - Dance chips
struct DanceChoiceChips: View {
    let dances: [String]
    @Binding var selection: String?
    @State private var taps = 0

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(dances, id: \.self) { name in
                let isOn = selection == name
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                        selection = isOn ? nil : name
                    }
                    taps += 1
                } label: {
                    Text(name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(isOn ? Color.obsidian900 : .white.opacity(0.9))
                        .padding(.horizontal, 14)
                        .frame(minHeight: 38)
                        .background(isOn ? AnyShapeStyle(Color.gold400) : AnyShapeStyle(Color.white.opacity(0.07)), in: Capsule())
                }
                .buttonStyle(.pressable)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: taps)
    }
}
