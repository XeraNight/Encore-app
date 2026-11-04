import SwiftUI
import SwiftData

// MARK: - Edit a dance
/// Your own tempo note, tips, photo and video for a dance. The dance's name cannot change:
/// routines and figures are tied to it.
struct EditDanceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var dance: Dance

    @State private var tempoText = ""
    @State private var infoText = ""
    @State private var savedCount = 0

    var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 8) {
                            HomeSectionHeader(title: "TEMPO")
                            TextField("", text: $tempoText, prompt: Text("napr. 28–30 taktov za minútu").foregroundColor(Color.textPlaceholder))
                                .authFieldChrome()
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HomeSectionHeader(title: "NA ČO SI DAŤ POZOR", systemImage: "text.alignleft")
                            TextEditor(text: $infoText)
                                .scrollContentBackground(.hidden)
                                .font(.callout)
                                .foregroundColor(.white)
                                .frame(minHeight: 120)
                                .padding(10)
                                .homeCard(cornerRadius: 16)
                        }

                        AttachedVideoSection(videoPath: $dance.videoPath, onChange: changed)
                        AttachedPhotoSection(imagePath: $dance.imagePath, filePrefix: "dance_img", onChange: changed)
                    }
                    .padding(20)
                    .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85), value: dance.videoPath)
                    .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85), value: dance.imagePath)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(DanceNames.display(dance.name))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zrušiť") { dismiss() }
                        .foregroundColor(Color.gold400)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Uložiť") {
                        dance.tempo = tempoText.trimmingCharacters(in: .whitespacesAndNewlines)
                        dance.info = infoText
                        changed()
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundColor(Color.gold400)
                }
            }
            .onAppear {
                tempoText = dance.tempo
                infoText = dance.info
            }
            .sensoryFeedback(.success, trigger: savedCount)
        }
    }

    private func changed() {
        try? modelContext.save()
        savedCount += 1
    }
}
