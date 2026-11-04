import SwiftUI

// MARK: - Porovnanie: choose the two videos
/// Picks "Ja" and "Vzor" before the comparison opens (BRAND_GUIDELINES §1A).
struct CompareHubView: View {
    @Binding var pathA: String?
    @Binding var pathB: String?
    @Binding var isPresented: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showDirectComparison = false
    @State private var pickerSlot: DualSlot?

    private var hasAny: Bool { pathA != nil || pathB != nil }

    var body: some View {
        ZStack {
            EllegancePageBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Porovnanie")
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundColor(.white)
                            .accessibilityAddTraits(.isHeader)
                        Text("Pusti si svoje video vedľa vzoru, nájdi ten istý moment a uvidíš, čo robíš inak.")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(alignment: .top, spacing: 12) {
                        slotCard(.a, title: "JA", path: pathA) { pathA = nil }
                        slotCard(.b, title: "VZOR", path: pathB) { pathB = nil }
                    }

                    VStack(spacing: 8) {
                        PrimarySheetButton(title: "Spustiť porovnanie", isLoading: false, isEnabled: hasAny) {
                            showDirectComparison = true
                        }
                        if !hasAny {
                            Text("Vyber aspoň jedno video.")
                                .font(.footnote)
                                .foregroundColor(Color.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
                .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85), value: pathA)
                .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85), value: pathB)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Zavrieť") { isPresented = false }
                    .foregroundColor(Color.gold400)
            }
        }
        .sensoryFeedback(.selection, trigger: pathA)
        .sensoryFeedback(.selection, trigger: pathB)
        .fullScreenCover(isPresented: $showDirectComparison) {
            DualVideoComparisonView(pathA: $pathA, pathB: $pathB)
        }
        .sheet(item: $pickerSlot) { slot in
            UniversalMediaPickerSheet(
                slotTitle: slot.rawValue,
                currentPath: slot == .a ? pathA : pathB,
                onSelectMedia: { path in
                    if slot == .a { pathA = path } else { pathB = path }
                    pickerSlot = nil
                },
                onClearMedia: {
                    if slot == .a { pathA = nil } else { pathB = nil }
                    pickerSlot = nil
                }
            )
        }
    }

    // MARK: Slot
    private func slotCard(_ slot: DualSlot, title: String, path: String?, onClear: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(.caption, design: .rounded).weight(.black))
                .tracking(1.4)
                .foregroundColor(Color.gold400)

            Button { pickerSlot = slot } label: {
                Group {
                    if let path {
                        MediaThumbnailView(path: path, placeholderIcon: "film", cornerRadius: 14)
                            .transition(.scale(scale: 0.96).combined(with: .opacity))
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.title3.weight(.bold))
                                .foregroundColor(Color.gold400)
                            Text(slot == .a ? "Moje video" : "Video vzoru")
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(.white.opacity(0.85))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.gold400.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                        )
                    }
                }
                .aspectRatio(3 / 4, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(path == nil ? "Vybrať: \(slot.rawValue)" : "Zmeniť: \(slot.rawValue)")

            if path != nil {
                HStack {
                    Button("Zmeniť") { pickerSlot = slot }
                        .font(.footnote.weight(.bold))
                        .foregroundColor(Color.gold400)
                    Spacer()
                    // Only empties the slot; the video stays where it is.
                    Button(action: onClear) {
                        Image(systemName: "xmark")
                            .font(.footnote.weight(.bold))
                            .foregroundColor(Color.textSecondary)
                            .frame(width: 32, height: 32)
                    }
                    .accessibilityLabel("Odobrať z porovnania")
                }
                .buttonStyle(.pressable)
                .frame(minHeight: 32)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .homeCard(cornerRadius: 18)
    }
}
