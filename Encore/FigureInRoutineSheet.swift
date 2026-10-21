import SwiftUI

// MARK: - A figure in this routine
/// Name, rhythm and bars of a figure in this routine (BRAND_GUIDELINES §1A). The library stays as it is. The bars
/// give the figure's length with the dance's tempo. Removing the figure is here too, not only behind a long press.
struct FigureInRoutineSheet: View {
    @Bindable var node: CanvasNode
    /// The dance's tempo; nil when the dancer has none, then only the bars show.
    let barsPerMinute: Double?
    let onSave: () -> Void
    /// Nil where the figure cannot be removed from here (opened outside the canvas).
    let onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var rhythm = ""
    /// 0 = not set.
    @State private var bars = 0
    @State private var confirmDelete = false

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        PlannerTextField(placeholder: "Názov figúry", text: $name, systemImage: "figure.dance")
                        PlannerTextField(placeholder: "Rytmus, napr. 1, 2, 3 alebo S, Q, Q", text: $rhythm, systemImage: "metronome")

                        VStack(alignment: .leading, spacing: 8) {
                            GoldValueStepper(title: "Takty", systemImage: "music.note", value: $bars,
                                             range: 0...RoutineTiming.barRange.upperBound,
                                             lessLabel: "Menej taktov", moreLabel: "Viac taktov",
                                             valueText: { $0 == 0 ? "–" : "\($0)" },
                                             spokenText: { $0 == 0 ? "nezadané" : RoutineTiming.barsText($0) })
                            Text(lengthHint)
                                .font(.caption)
                                .foregroundColor(Color.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .contentTransition(.opacity)
                                .animation(.easeOut(duration: 0.2), value: bars)
                        }
                        .padding(14)
                        .homeCard(cornerRadius: 18)

                        Text("Zmena platí len v tejto zostave, knižnica figúr ostane bez zmeny.")
                            .font(.caption)
                            .foregroundColor(Color.textSecondary)

                        if onDelete != nil {
                            Button(role: .destructive) { confirmDelete = true } label: {
                                Label("Vymazať figúru zo zostavy", systemImage: "trash")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(Color.latinRed)
                                    .frame(maxWidth: .infinity, minHeight: 48)
                                    .background(Color.latinRed.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.pressable)
                            .padding(.top, 8)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Figúra v tejto zostave")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Zrušiť") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Uložiť", action: save).disabled(trimmedName.isEmpty)
                }
            }
            .confirmationDialog("Vymazať túto figúru zo zostavy?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Vymazať", role: .destructive) {
                    dismiss()
                    onDelete?()
                }
                Button("Zrušiť", role: .cancel) {}
            } message: {
                Text("Na pár sekúnd sa dá vrátiť.")
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
        .onAppear {
            name = node.figureName
            rhythm = node.rhythm
            bars = node.bars ?? 0
        }
    }

    private var lengthHint: String {
        guard bars > 0 else {
            return "Koľko taktov figúru tancuješ. Encore z toho vypočíta dĺžku figúry aj celej zostavy."
        }
        guard let barsPerMinute else {
            return "\(RoutineTiming.barsText(bars)). Dĺžku vypočítam, keď má tanec zadané tempo."
        }
        let seconds = RoutineTiming.seconds(bars: bars, barsPerMinute: barsPerMinute)
        return "\(RoutineTiming.barsText(bars)) ≈ \(RoutineTiming.text(seconds)) pri tempe \(Int(barsPerMinute.rounded())) taktov za minútu."
    }

    private func save() {
        let newName = String(trimmedName.prefix(80))
        let newRhythm = String(rhythm.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        let newBars = bars == 0 ? nil : bars
        dismiss()
        guard newName != node.figureName || newRhythm != node.rhythm || newBars != node.bars else { return }
        node.figureName = newName
        node.rhythm = newRhythm
        node.bars = newBars
        onSave()
    }
}
