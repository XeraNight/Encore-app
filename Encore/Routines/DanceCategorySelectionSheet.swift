import SwiftUI
import SwiftData

// MARK: - Nová zostava: choose the dance
/// Both disciplines on one screen in competition order; a dance opens its page with routines and figures.
struct DanceCategorySelectionSheet: View {
    @Binding var isPresented: Bool
    @Query private var dances: [Dance]
    @Query private var routines: [Routine]

    private func dances(standard: Bool) -> [Dance] {
        dances
            .filter { ($0.category.lowercased() == "standard") == standard }
            .sorted { DanceNames.rank($0.name) < DanceNames.rank($1.name) }
    }

    var body: some View {
        ZStack {
            EllegancePageBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Vyber tanec a založ v ňom zostavu.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))

                    section("ŠTANDARD", dances(standard: true), dot: Color.standardBlue)
                    section("LATINA", dances(standard: false), dot: Color.latinCrimson)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Nová zostava")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Zavrieť") { isPresented = false }
                    .foregroundColor(Color.gold400)
            }
        }
    }

    private func section(_ title: String, _ list: [Dance], dot: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HomeSectionHeader(title: title)
                .padding(.horizontal, 4)
            ForEach(list) { dance in
                NavigationLink {
                    DanceDetailView(dance: dance)
                } label: {
                    row(dance, dot: dot)
                }
                .buttonStyle(.pressable(scale: 0.97))
            }
        }
    }

    private func row(_ dance: Dance, dot: Color) -> some View {
        let count = routines.filter { $0.danceName == dance.name }.count
        return HStack(spacing: 12) {
            Circle().fill(dot).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 3) {
                Text(DanceNames.display(dance.name))
                    .font(.headline)
                    .foregroundColor(.white)
                Text(dance.tempo)
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)
            }
            Spacer(minLength: 8)
            if count > 0 {
                Text(slovakCount(count, one: "zostava", few: "zostavy", many: "zostáv"))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Color.gold300)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(16)
        .homeCard(cornerRadius: 16)
        .accessibilityElement(children: .combine)
    }
}
