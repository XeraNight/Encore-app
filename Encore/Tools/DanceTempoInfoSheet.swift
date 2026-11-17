import SwiftUI

// MARK: - Takty alebo údery?
/// Why the metronome says "29" for a waltz and clicks 87 times a minute. The numbers come from the metronome's own table
/// (`DanceMetronomePreset.competitionMeasures`), so this page can never disagree with it.
struct DanceTempoInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    private static let dances = DanceMetronomePreset.allCases.filter { $0.competitionMeasures != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        paragraph("Tempo tanca sa v pravidlách SZTŠ aj WDSF udáva v taktoch za minútu. Samba má 50 až 52 taktov za minútu.")
                        paragraph("Metronóm a hudobníci počítajú údery (BPM). Údery sú takty × doby v takte, takže samba s 2 dobami v takte má 100 až 104 úderov za minútu.")
                        paragraph("Na nahrávkach (Spotify, CD) býva pri tanci napísané „BPM 50–52“. Myslí sa tým počet taktov. Metronóm v Encore ukazuje takty a tiká po dobách.")
                        table
                        Text("Tempá podľa Súťažného poriadku SZTŠ 2023, čl. 8. Doby v takte sú bežné metrum (valčík 3, samba a paso doble 2, ostatné 4), pravidlá ich neuvádzajú.")
                            .font(.caption)
                            .foregroundColor(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(20)
                }
                .softTopEdge()
            }
            .navigationTitle("Takty alebo údery?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hotovo") { dismiss() }
                        .foregroundColor(Color.gold400)
                }
            }
        }
        .presentationDetents([.large])
        .preferredColorScheme(.dark)
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(.white.opacity(0.88))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var table: some View {
        VStack(spacing: 0) {
            row("Tanec", "Takty", "Doby", "Údery", isHeader: true)
            ForEach(Self.dances) { dance in
                if let range = dance.competitionMeasures {
                    Divider().overlay(Color.white.opacity(0.08))
                    row(dance.chipName, "\(range.lowerBound)–\(range.upperBound)", "\(dance.beatsPerMeasure)",
                        "\(range.lowerBound * dance.beatsPerMeasure)–\(range.upperBound * dance.beatsPerMeasure)")
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .homeCard(cornerRadius: 16)
    }

    private func row(_ name: String, _ measures: String, _ beats: String, _ clicks: String, isHeader: Bool = false) -> some View {
        HStack(spacing: 8) {
            Text(name).frame(maxWidth: .infinity, alignment: .leading)
            Text(measures).frame(width: 64, alignment: .trailing)
            Text(beats).frame(width: 40, alignment: .trailing)
            Text(clicks).frame(width: 72, alignment: .trailing)
        }
        .font(isHeader ? .caption.weight(.bold) : .footnote.weight(.semibold))
        .foregroundColor(isHeader ? Color.gold400 : .white.opacity(0.9))
        .frame(minHeight: 34)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Takty alebo údery") {
    DanceTempoInfoSheet()
}
