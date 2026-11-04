import SwiftUI
import SwiftData
import UIKit

// MARK: - Library from Home
/// The command palette on Home opens the same figure library as Profile, as a sheet.
struct GlobalLibraryView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ProfileFiguresListView()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Zavrieť") { dismiss() }
                            .foregroundColor(Color.gold400)
                    }
                }
        }
    }
}

// MARK: - Figure sync
/// One place that sends a library figure to the cloud and pulls the library back.
/// Videos and photos stay on the phone (Fotky); the cloud only keeps the text and the file names
/// (docs/VIDEO_STORAGE_AND_SHARING.md).
enum FigureLibrarySync {
    static func push(_ figure: FigureLibraryItem) {
        let id = figure.id
        let name = figure.name
        let dance = figure.danceName
        let rhythm = figure.rhythm
        let notes = figure.techniqueNotes
        let imagePath = figure.imagePath
        let videoPath = figure.videoPath
        let isCustom = figure.isCustom
        Task.detached(priority: .background) {
            await SupabaseSyncManager.shared.syncFigure(
                id, name: name, danceName: dance, rhythm: rhythm, notes: notes,
                imagePath: imagePath, videoPath: videoPath, isCustom: isCustom
            )
        }
    }

    static func delete(_ id: UUID) {
        Task.detached(priority: .background) {
            await SupabaseSyncManager.shared.deleteFigure(id)
        }
    }

    /// Cloud wins for figures it knows; figures only on this phone stay.
    static func pull(into context: ModelContext) async {
        guard let cloudFigures = await SupabaseSyncManager.shared.fetchFigures() else { return }
        let localFigures = (try? context.fetch(FetchDescriptor<FigureLibraryItem>())) ?? []
        let localMap = Dictionary(localFigures.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for cloud in cloudFigures {
            if let existing = localMap[cloud.id] {
                existing.name = cloud.name
                existing.danceName = cloud.dance_name
                existing.rhythm = cloud.rhythm
                existing.techniqueNotes = cloud.technique_notes
                existing.imagePath = cloud.image_path
                existing.videoPath = cloud.video_path
                existing.isCustom = cloud.is_custom
            } else {
                context.insert(FigureLibraryItem(
                    id: cloud.id,
                    name: cloud.name,
                    danceName: cloud.dance_name,
                    rhythm: cloud.rhythm,
                    techniqueNotes: cloud.technique_notes,
                    imagePath: cloud.image_path,
                    videoPath: cloud.video_path,
                    isCustom: cloud.is_custom
                ))
            }
        }
        try? context.save()
    }
}

// MARK: - New figure
/// The one form for an own figure. From a dance's page the dance is already chosen.
struct NewFigureSheet: View {
    var fixedDance: String? = nil
    var onSaved: ((FigureLibraryItem) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var name = ""
    @State private var dance: String?
    @State private var rhythm = ""
    @State private var notes = ""
    @FocusState private var focus: Field?

    private enum Field { case name, rhythm, notes }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var chosenDance: String? { fixedDance ?? dance }
    private var canSave: Bool { !trimmedName.isEmpty && chosenDance != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        labeled("NÁZOV") {
                            TextField("", text: $name, prompt: Text("napr. Double Reverse Spin").foregroundColor(Color.textPlaceholder))
                                .focused($focus, equals: .name)
                                .submitLabel(.next)
                                .onSubmit { focus = .rhythm }
                                .authFieldChrome()
                        }
                        if fixedDance == nil {
                            labeled("TANEC") {
                                DanceMenuCapsule(selection: $dance, emptyTitle: "Vyber tanec", clearTitle: "Bez tanca")
                            }
                        }
                        labeled("RYTMUS") {
                            TextField("", text: $rhythm, prompt: Text("napr. S Q Q S alebo 1, 2, 3").foregroundColor(Color.textPlaceholder))
                                .focused($focus, equals: .rhythm)
                                .submitLabel(.next)
                                .onSubmit { focus = .notes }
                                .authFieldChrome()
                        }
                        labeled("TECHNIKA") {
                            TextEditor(text: $notes)
                                .focused($focus, equals: .notes)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 110)
                                .authFieldChrome()
                        }

                        VStack(spacing: 8) {
                            PrimarySheetButton(title: "Uložiť do knižnice", isLoading: false, isEnabled: canSave, action: save)
                            if !canSave {
                                Text(trimmedName.isEmpty ? "Napíš názov figúry." : "Vyber tanec.")
                                    .font(.footnote)
                                    .foregroundColor(Color.textSecondary)
                            }
                        }
                        .padding(.top, 4)
                    }
                    .padding(20)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Nová figúra")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zrušiť") { dismiss() }
                        .foregroundColor(Color.gold400)
                }
            }
            .onAppear { focus = .name }
        }
    }

    private func labeled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HomeSectionHeader(title: title)
            content()
        }
    }

    private func save() {
        guard canSave, let chosenDance else { return }
        let figure = FigureLibraryItem(
            name: trimmedName,
            danceName: chosenDance,
            rhythm: rhythm.trimmingCharacters(in: .whitespacesAndNewlines),
            techniqueNotes: notes,
            isCustom: true
        )
        modelContext.insert(figure)
        try? modelContext.save()
        FigureLibrarySync.push(figure)
        onSaved?(figure)
        dismiss()
    }
}

// MARK: - Edit figure
struct LibraryFigureDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var figure: FigureLibraryItem

    @State private var nameText = ""
    @State private var rhythmText = ""
    @State private var notesText = ""

    @State private var confirmDeleteFigure = false
    @State private var savedCount = 0

    var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        fields
                        AttachedVideoSection(videoPath: $figure.videoPath, onChange: changed)
                        AttachedPhotoSection(imagePath: $figure.imagePath, filePrefix: "fig_img", onChange: changed)
                        notesSection
                        InstantNotesInboxSection(
                            onImportText: { text in
                                notesText = notesText.isEmpty ? text : notesText + "\n" + text
                            },
                            onImportVideo: { videoPath in
                                figure.videoPath = videoPath
                                changed()
                            }
                        )
                        deleteButton
                    }
                    .padding(20)
                    .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85), value: figure.videoPath)
                    .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85), value: figure.imagePath)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(figure.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zrušiť") { dismiss() }
                        .foregroundColor(Color.gold400)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Uložiť") {
                        saveChanges()
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundColor(Color.gold400)
                    .disabled(nameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .confirmationDialog("Odstrániť figúru z knižnice?", isPresented: $confirmDeleteFigure, titleVisibility: .visible) {
                Button("Odstrániť figúru", role: .destructive) { deleteFigure() }
            } message: {
                Text("Zmizne z knižnice na všetkých tvojich zariadeniach. Zostavy, v ktorých je, ostanú bez zmeny.")
            }
            .onAppear {
                nameText = figure.name
                rhythmText = figure.rhythm
                notesText = figure.techniqueNotes
            }
            .sensoryFeedback(.success, trigger: savedCount)
        }
    }

    // MARK: Sections
    private var fields: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HomeSectionHeader(title: "NÁZOV")
                TextField("", text: $nameText, prompt: Text("Názov figúry").foregroundColor(Color.textPlaceholder))
                    .authFieldChrome()
            }
            VStack(alignment: .leading, spacing: 8) {
                HomeSectionHeader(title: "RYTMUS")
                TextField("", text: $rhythmText, prompt: Text("napr. S Q Q S").foregroundColor(Color.textPlaceholder))
                    .authFieldChrome()
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HomeSectionHeader(title: "TECHNIKA", systemImage: "text.alignleft")
            TextEditor(text: $notesText)
                .scrollContentBackground(.hidden)
                .font(.callout)
                .foregroundColor(.white)
                .frame(minHeight: 120)
                .padding(10)
                .homeCard(cornerRadius: 16)
        }
    }

    private var deleteButton: some View {
        Button { confirmDeleteFigure = true } label: {
            Label("Odstrániť figúru z knižnice", systemImage: "trash")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Color.latinRed)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.pressable)
        .padding(.top, 8)
    }

    // MARK: Actions
    private func changed() {
        try? modelContext.save()
        FigureLibrarySync.push(figure)
        savedCount += 1
    }

    private func saveChanges() {
        figure.name = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
        figure.rhythm = rhythmText.trimmingCharacters(in: .whitespacesAndNewlines)
        figure.techniqueNotes = notesText
        changed()
    }

    private func deleteFigure() {
        let id = figure.id
        MediaStorageManager.removeFile(named: figure.imagePath)
        MediaStorageManager.removeFile(named: figure.videoPath)
        modelContext.delete(figure)
        try? modelContext.save()
        FigureLibrarySync.delete(id)
        dismiss()
    }
}

// MARK: - Xcode Canvas Preview
#Preview("Knižnica") {
    GlobalLibraryView()
        .previewWithSampleData()
}
