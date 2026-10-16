import SwiftUI

// MARK: - Correction model
/// Ready-made tags, so a correction takes two taps and reads the same for partner and coach.
enum CorrectionTag: String, CaseIterable, Identifiable {
    case bodyBack = "Telo dozadu"
    case frameDrops = "Rám padá"
    case leftElbow = "Ľavý lakeť"
    case head = "Hlava"
    case knees = "Kolená"
    case feet = "Chodidlá"
    case timing = "Načasovanie"

    var id: String { rawValue }
}

/// One correction found in the comparison. It is added to the figure's notes as a single line, so it
/// syncs with the routine and partner and coach see it without anything new on the server.
struct FigureCorrection: Equatable {
    var tags: Set<CorrectionTag> = []
    var note = ""
    /// Tilt read from the level line, when the line was shown.
    var tilt: Int?
    var date = Date()

    var trimmedNote: String { note.trimmingCharacters(in: .whitespacesAndNewlines) }
    var isEmpty: Bool { tags.isEmpty && trimmedNote.isEmpty }

    /// "Korekcia 9. 10.: Telo dozadu, Rám padá · sklon 6° · pomalšie do otočky"
    var noteLine: String {
        var parts: [String] = []
        let ordered = CorrectionTag.allCases.filter(tags.contains)
        if !ordered.isEmpty { parts.append(ordered.map(\.rawValue).joined(separator: ", ")) }
        if let tilt, tilt > 0 { parts.append("sklon \(tilt)°") }
        if !trimmedNote.isEmpty { parts.append(trimmedNote) }
        let day = Calendar.current.dateComponents([.day, .month], from: date)
        return "Korekcia \(day.day ?? 0). \(day.month ?? 0).: " + parts.joined(separator: " · ")
    }
}

extension RichNote {
    /// The figure's notes with one more line at the end, keeping the existing formatting.
    static func appending(_ line: String, to node: CanvasNode) -> (plain: String, rich: Data?) {
        var text = attributed(for: node)
        let existing = plain(text)
        if !existing.isEmpty {
            text.append(AttributedString(existing.hasSuffix("\n") ? "\n" : "\n\n"))
        }
        text.append(AttributedString(line))
        return (plain(text), node.notesRichData == nil ? nil : encode(text))
    }
}

// MARK: - Save sheet
/// Snapshot, tags, optional note. "Uložiť k figúre" hands the correction to the caller.
struct FigureCorrectionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let figureName: String
    let snapshot: UIImage?
    let tilt: Int?
    let onSave: (FigureCorrection, _ alsoToPhotos: Bool) -> Void

    @State private var correction = FigureCorrection()
    @State private var alsoToPhotos = true
    @State private var tagTaps = 0
    @FocusState private var noteFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        if let snapshot {
                            Image(uiImage: snapshot)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: 260)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .padding(8)
                                .homeCard()
                                .accessibilityLabel("Snímka s čiarami")
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            HomeSectionHeader(title: "ČO OPRAVIŤ", systemImage: "tag.fill", count: correction.tags.count)
                            FlowLayout(spacing: 8) {
                                ForEach(CorrectionTag.allCases) { tag in
                                    tagChip(tag)
                                }
                            }
                            if let tilt, tilt > 0 {
                                Label("Pridá sa aj sklon \(tilt)° z čiary.", systemImage: "level")
                                    .font(.footnote)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            HomeSectionHeader(title: "POZNÁMKA", systemImage: "text.bubble.fill")
                            TextField("", text: $correction.note,
                                      prompt: Text("Napríklad: pomalšie do otočky").foregroundColor(.white.opacity(0.4)),
                                      axis: .vertical)
                                .lineLimit(2...5)
                                .focused($noteFocused)
                                .foregroundColor(.white)
                                .padding(14)
                                .homeCard(cornerRadius: 14)
                        }

                        Toggle(isOn: $alsoToPhotos) {
                            Label("Uložiť aj snímku do Fotiek", systemImage: "photo.on.rectangle")
                                .foregroundColor(.white)
                        }
                        .tint(Color.gold500)
                        .padding(14)
                        .homeCard(cornerRadius: 14)
                        .disabled(snapshot == nil)

                        Text(AppFeatures.coachTools
                         ? "Korekcia sa pridá do poznámok figúry. Uvidia ju aj partner a tréner, s ktorými máš zostavu zdieľanú."
                         : "Korekcia sa pridá do poznámok figúry. Uvidí ju aj partner, s ktorým máš zostavu zdieľanú.")
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 110)
                }
                .scrollDismissesKeyboard(.interactively)

                VStack {
                    Spacer()
                    PrimarySheetButton(title: "Uložiť k figúre", isLoading: false, isEnabled: !correction.isEmpty) {
                        correction.tilt = tilt
                        correction.date = Date()
                        onSave(correction, alsoToPhotos && snapshot != nil)
                        dismiss()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle("Korekcia: \(figureName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zrušiť") { dismiss() }
                        .foregroundColor(Color.gold400)
                }
            }
            .sensoryFeedback(.selection, trigger: tagTaps)
        }
    }

    private func tagChip(_ tag: CorrectionTag) -> some View {
        let isOn = correction.tags.contains(tag)
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                if isOn { correction.tags.remove(tag) } else { correction.tags.insert(tag) }
            }
            tagTaps += 1
        } label: {
            Text(tag.rawValue)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(isOn ? Color.obsidian900 : .white)
                .padding(.horizontal, 14)
                .frame(minHeight: 40)
                .background(isOn ? AnyShapeStyle(Color.gold400) : AnyShapeStyle(Color.white.opacity(0.08)), in: Capsule())
                .overlay(Capsule().stroke(isOn ? Color.gold400 : Color.white.opacity(0.15), lineWidth: 1))
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
