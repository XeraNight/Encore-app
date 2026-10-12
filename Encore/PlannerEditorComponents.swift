import SwiftUI

// MARK: - Plán editors (BRAND_GUIDELINES §1A)
/// The frame shared by every Plán editor (competition, weekly training, one-off training): velvet background,
/// a close button and title on top, glass sections, the gold save button pinned at the bottom and an optional
/// destructive action with confirmation.
struct PlannerEditorScaffold<Content: View>: View {
    let title: String
    var saveTitle = "Uložiť"
    let canSave: Bool
    /// Shown under the dimmed save button: why it cannot be tapped yet.
    var disabledHint: String? = nil
    let onSave: () -> Void
    var delete: PlannerEditorDelete? = nil
    @ViewBuilder let content: Content

    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false

    var body: some View {
        ZStack {
            EllegancePageBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    content
                    if let delete {
                        Button { confirmDelete = true } label: {
                            Label(delete.buttonTitle, systemImage: "trash")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(Color.latinRed)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.pressable)
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: canSave)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .top, spacing: 0) { header }
            .safeAreaInset(edge: .bottom, spacing: 0) { saveBar }
        }
        .environment(\.locale, Locale(identifier: "sk"))
        .preferredColorScheme(.dark)
        .confirmationDialog(delete?.question ?? "", isPresented: $confirmDelete, titleVisibility: .visible) {
            if let delete {
                ForEach(delete.actions) { action in
                    Button(action.title, role: .destructive) {
                        action.perform()
                        dismiss()
                    }
                }
            }
        } message: {
            if let message = delete?.message { Text(message) }
        }
    }

    private var header: some View {
        ZStack {
            Text(title)
                .font(.system(.headline, design: .rounded).weight(.heavy))
                .foregroundColor(.white)
                .accessibilityAddTraits(.isHeader)
            HStack {
                LiquidGlassCircleButton(icon: "xmark", label: "Zrušiť", size: 40) { dismiss() }
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private var saveBar: some View {
        VStack(spacing: 6) {
            PrimarySheetButton(title: saveTitle, isLoading: false, isEnabled: canSave, action: onSave)
                .accessibilityIdentifier("plan.editor.save")
            if !canSave, let disabledHint {
                Text(disabledHint)
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.6))
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
}

/// What the destructive button at the bottom of an editor asks and does. More than one action gives a choice
/// (e.g. "Zrušiť len tento termín" / "Zmazať všetky budúce").
struct PlannerEditorDelete {
    struct Action: Identifiable {
        let title: String
        let perform: () -> Void
        var id: String { title }
    }

    let buttonTitle: String
    let question: String
    var message: String? = nil
    let actions: [Action]
}

/// Gold caps header over one glass card of fields.
struct PlannerFormSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HomeSectionHeader(title: title, systemImage: systemImage)
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .homeCard(cornerRadius: 20)
        }
    }
}

/// One-line text field with an icon; gold edge sweep when it gets focus.
struct PlannerTextField: View {
    let placeholder: String
    @Binding var text: String
    var systemImage: String? = nil

    @FocusState private var isFocused: Bool
    @State private var sweepTrigger = 0

    var body: some View {
        HStack(spacing: 10) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color.gold400.opacity(isFocused ? 1 : 0.7))
                    .frame(width: 22)
                    .accessibilityHidden(true)
            }
            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.5)))
                .focused($isFocused)
                .font(.body)
                .foregroundColor(.white)
                .submitLabel(.done)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isFocused ? Color.gold400.opacity(0.45) : Color.white.opacity(0.08), lineWidth: 1)
        )
        .overlay { FieldEdgeSweep(trigger: sweepTrigger) }
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
        .onChange(of: isFocused) { _, focused in
            if focused { sweepTrigger += 1 }
        }
        .animation(.easeOut(duration: 0.2), value: isFocused)
    }
}

/// Row of capsules; the gold fill slides to the chosen one.
struct PlannerChoice<Value: Hashable>: View {
    let options: [(value: Value, title: String)]
    @Binding var selection: Value

    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.value) { option in
                let isOn = option.value == selection
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) { selection = option.value }
                } label: {
                    Text(option.title)
                        .font(.subheadline.weight(isOn ? .bold : .medium))
                        .foregroundColor(isOn ? Color.obsidian900 : .white.opacity(0.75))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 4)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background {
                            ZStack {
                                Capsule().fill(Color.white.opacity(0.05))
                                if isOn {
                                    Capsule()
                                        .fill(Color.gold400)
                                        .matchedGeometryEffect(id: "choice", in: namespace)
                                }
                            }
                        }
                        .overlay(Capsule().stroke(isOn ? Color.gold400.opacity(0.45) : Color.white.opacity(0.08), lineWidth: 1))
                }
                .buttonStyle(.pressable(scale: 0.94))
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// Icon, title, optional explanation and a gold switch.
struct PlannerToggleRow: View {
    let title: String
    var subtitle: String? = nil
    let systemImage: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn.animation(.spring(response: 0.35, dampingFraction: 0.85))) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color.gold400)
                    .frame(width: 22)
                    .symbolEffect(.bounce, value: isOn)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                    if let subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .tint(Color.gold500)
        .frame(minHeight: 44)
        .sensoryFeedback(.selection, trigger: isOn)
    }
}

/// Icon and title on the left, the system date or time picker on the right.
struct PlannerDateRow: View {
    let title: String
    let systemImage: String
    @Binding var date: Date
    var components: DatePickerComponents = .date

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Color.gold400)
                .frame(width: 22)
                .accessibilityHidden(true)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            Spacer(minLength: 8)
            DatePicker(title, selection: $date, displayedComponents: components)
                .labelsHidden()
                .tint(Color.gold400)
        }
        .frame(minHeight: 44)
    }
}

/// "Dĺžka  −  90 min  +" in steps of 15 minutes; the number rolls.
struct PlannerDurationStepper: View {
    @Binding var minutes: Int
    var range: ClosedRange<Int> = 15...300
    var step = 15

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "timer")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Color.gold400)
                .frame(width: 22)
                .accessibilityHidden(true)
            Text("Dĺžka")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            Spacer(minLength: 8)
            stepButton("minus", label: "Kratšie", delta: -step)
            Text("\(minutes) min")
                .font(.system(.subheadline, design: .rounded).weight(.heavy))
                .foregroundColor(Color.gold300)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(minutes)))
                .frame(minWidth: 64)
            stepButton("plus", label: "Dlhšie", delta: step)
        }
        .frame(minHeight: 44)
        .sensoryFeedback(.selection, trigger: minutes)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Dĺžka \(minutes) minút")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: change(by: step)
            case .decrement: change(by: -step)
            @unknown default: break
            }
        }
    }

    private func stepButton(_ systemImage: String, label: String, delta: Int) -> some View {
        Button { change(by: delta) } label: {
            Image(systemName: systemImage)
                .font(.footnote.weight(.bold))
                .foregroundColor(Color.gold400)
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.07), in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressable(scale: 0.88))
        .accessibilityLabel(label)
    }

    private func change(by delta: Int) {
        let next = min(range.upperBound, max(range.lowerBound, minutes + delta))
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { minutes = next }
    }
}

// MARK: - Discipline choices
/// What the dancer picks instead of typing categories.
enum PlannerDisciplineChoice {
    /// Planned competition: stored in `targetCategories`.
    static let competition: [(value: String, title: String)] = [
        ("Štandard", "Štandard"), ("Latina", "Latina"), ("Obe", "Obe"),
    ]

    /// Trainings: stored in `danceCategory`.
    static let training: [(value: String, title: String)] = [
        ("Standard", "Štandard"), ("Latin", "Latina"), ("Mixed", "Obe"), ("Free", "Voľný"),
    ]

    /// Reads older free-text categories ("Dospelí D ŠTT, Dospelí D LAT") too.
    static func competitionValue(from categories: [String]) -> String {
        let text = categories.joined(separator: " ").lowercased()
        let standard = ["štandard", "standard", "štt", "stt"].contains { text.contains($0) }
        let latin = text.contains("lat")
        switch (standard, latin) {
        case (true, false): return "Štandard"
        case (false, true): return "Latina"
        default: return categories.isEmpty ? "Štandard" : "Obe"
        }
    }

    static func competitionCategories(for value: String) -> [String] {
        value == "Obe" ? ["Štandard", "Latina"] : [value]
    }
}
