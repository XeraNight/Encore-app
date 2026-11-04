import SwiftUI

// MARK: - All routines (from Home's quick search)
/// The same routine cards as on Home and in the Canvas tab.
struct AllRoutinesSheetView: View {
    @Environment(\.dismiss) private var dismiss
    let routines: [Routine]
    let onSelectRoutine: (Routine) -> Void
    let onNewRoutine: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        HomeSectionHeader(title: "ZOSTAVY", systemImage: "square.grid.2x2.fill", count: routines.count) {
                            Button(action: onNewRoutine) {
                                Label("Nová", systemImage: "plus")
                                    .font(.footnote.weight(.bold))
                                    .foregroundColor(Color.gold400)
                            }
                            .buttonStyle(.pressable)
                        }
                        .padding(.horizontal, 4)

                        if routines.isEmpty {
                            ProfileEmptyState(icon: "rectangle.dashed", text: "Zatiaľ nemáš žiadne zostavy.")
                        }
                        ForEach(routines) { routine in
                            RoutineCard(routine: routine) { onSelectRoutine(routine) }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Zostavy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zavrieť") { dismiss() }
                        .foregroundColor(Color.gold400)
                }
            }
        }
    }
}
