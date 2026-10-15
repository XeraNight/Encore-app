import SwiftUI
import SwiftData

// MARK: - Dance page
/// One dance: its tempo and tips, your routines in it and its figures (BRAND_GUIDELINES §1A).
/// A new routine opens straight on the canvas.
struct DanceDetailView: View {
    let dance: Dance
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var allRoutines: [Routine]
    @Query private var allFigures: [FigureLibraryItem]
    @AppStorage("profileName") private var userName = "Tanečník"

    @State private var showCreateRoutineSheet = false
    @State private var showPaywallSheet = false
    @State private var showAddCustomFigure = false
    @State private var showEditDance = false
    @State private var routineToDelete: Routine?
    @State private var routineToOpen: Routine?
    @State private var figureToEdit: FigureLibraryItem?
    @State private var deleteCount = 0

    private var routinesForDance: [Routine] {
        allRoutines
            .filter { $0.danceName.caseInsensitiveCompare(dance.name) == .orderedSame }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var figuresForDance: [FigureLibraryItem] {
        allFigures
            .filter { $0.danceName.caseInsensitiveCompare(dance.name) == .orderedSame }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var canCreateRoutine: Bool {
        SubscriptionManager.shared.canCreateRoutine(existingCountForDance: routinesForDance.count)
    }

    var body: some View {
        ZStack {
            EllegancePageBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    infoCard
                    routinesSection
                    figuresSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
                .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85), value: routinesForDance.map(\.id))
            }
        }
        .navigationTitle(DanceNames.display(dance.name))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Upraviť") { showEditDance = true }
                    .foregroundColor(Color.gold400)
            }
        }
        .navigationDestination(item: $routineToOpen) { RoutineCanvasView(routine: $0) }
        .sheet(isPresented: $showCreateRoutineSheet) {
            NewRoutineSheet(danceName: DanceNames.display(dance.name)) { name in
                createRoutine(named: name)
            }
        }
        .sheet(isPresented: $showAddCustomFigure) {
            NewFigureSheet(fixedDance: dance.name)
        }
        .sheet(item: $figureToEdit) { LibraryFigureDetailSheet(figure: $0) }
        .sheet(isPresented: $showEditDance) {
            EditDanceSheet(dance: dance)
        }
        .sheet(isPresented: $showPaywallSheet) {
            SubscriptionPaywallView(initialTier: .plus)
        }
        .confirmationDialog(
            "Zmazať zostavu?",
            isPresented: Binding(get: { routineToDelete != nil }, set: { if !$0 { routineToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Zmazať zostavu", role: .destructive) {
                if let routine = routineToDelete { deleteRoutine(routine) }
                routineToDelete = nil
            }
        } message: {
            Text("Zmaže sa celé plátno zostavy na všetkých tvojich zariadeniach. Videá vo Fotkách ti ostanú.")
        }
        .sensoryFeedback(.success, trigger: deleteCount)
    }

    // MARK: Info
    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let imagePath = dance.imagePath, let image = MediaResolver.resolveImage(path: imagePath) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 170)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else if let videoPath = dance.videoPath {
                LoopingVideoPlayer(videoPath: videoPath, rate: 1.0)
                    .frame(height: 170)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(dance.category.lowercased() == "standard" ? Color.standardBlue : Color.latinCrimson)
                    .frame(width: 8, height: 8)
                Text(dance.tempo)
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Color.gold300)
            }
            if !dance.info.isEmpty {
                Text(dance.info)
                    .font(.callout)
                    .foregroundColor(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .homeCard(cornerRadius: 20)
    }

    // MARK: Routines
    private var routinesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HomeSectionHeader(title: "ZOSTAVY", systemImage: "square.grid.2x2.fill", count: routinesForDance.count) {
                Button {
                    if canCreateRoutine {
                        showCreateRoutineSheet = true
                    } else {
                        AnalyticsManager.shared.routineLimitHit(danceName: dance.name)
                        showPaywallSheet = true
                    }
                } label: {
                    Label("Nová", systemImage: "plus")
                        .font(.footnote.weight(.bold))
                        .foregroundColor(Color.gold400)
                }
                .buttonStyle(.pressable)
            }
            .padding(.horizontal, 4)

            if !canCreateRoutine {
                HStack(spacing: 10) {
                    Image(systemName: "crown.fill")
                        .foregroundColor(Color.gold400)
                    Text("Vo Free máš 1 zostavu na tanec. Viac ich máš s Plus.")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.85))
                    Spacer(minLength: 4)
                    Button("Plus") {
                        AnalyticsManager.shared.paywallViewed(source: "dance_detail_limit_banner", initialTier: "Plus")
                        showPaywallSheet = true
                    }
                    .font(.footnote.weight(.bold))
                    .foregroundColor(Color.obsidian900)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 32)
                    .background(Color.gold400, in: Capsule())
                    .buttonStyle(.pressable)
                }
                .padding(12)
                .homeCard(cornerRadius: 14)
            }

            if routinesForDance.isEmpty {
                Button { showCreateRoutineSheet = true } label: {
                    Label("Založ prvú zostavu", systemImage: "plus")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(Color.gold400)
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.gold400.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                        )
                }
                .buttonStyle(.pressable)
                .disabled(!canCreateRoutine)
            } else {
                ForEach(routinesForDance) { routine in
                    RoutineCard(routine: routine) { routineToOpen = routine }
                        .contextMenu {
                            Button(role: .destructive) { routineToDelete = routine } label: {
                                Label("Zmazať zostavu", systemImage: "trash")
                            }
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                }
            }
        }
    }

    // MARK: Figures
    private var figuresSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HomeSectionHeader(title: "FIGÚRY", systemImage: "book.closed.fill", count: figuresForDance.count) {
                Button { showAddCustomFigure = true } label: {
                    Label("Figúra", systemImage: "plus")
                        .font(.footnote.weight(.bold))
                        .foregroundColor(Color.gold400)
                }
                .buttonStyle(.pressable)
            }
            .padding(.horizontal, 4)

            ForEach(figuresForDance) { figure in
                Button { figureToEdit = figure } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(figure.name)
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.leading)
                            if !figure.rhythm.isEmpty {
                                Text(figure.rhythm)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.65))
                                    .lineLimit(1)
                            }
                        }
                        Spacer(minLength: 8)
                        if figure.isCustom {
                            Text("Moja")
                                .font(.caption2.weight(.bold))
                                .foregroundColor(Color.obsidian900)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.gold400, in: Capsule())
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .homeCard(cornerRadius: 16)
                }
                .buttonStyle(.pressable(scale: 0.97))
            }
        }
    }

    // MARK: Actions
    private func createRoutine(named name: String) {
        let routine = Routine(name: name, danceName: dance.name, danceCategory: dance.category)
        routine.lastModifiedBy = userName
        modelContext.insert(routine)
        try? modelContext.save()
        SupabaseSyncManager.shared.syncRoutineOnBackground(routine)
        showCreateRoutineSheet = false
        routineToOpen = routine
    }

    /// Same as deleting from the Canvas tab: gone here and in the cloud.
    private func deleteRoutine(_ routine: Routine) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.85)) {
            routine.deleteEverywhere(in: modelContext)
        }
        deleteCount += 1
    }
}

// MARK: - New routine
struct NewRoutineSheet: View {
    let danceName: String
    let onCreate: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @FocusState private var isFocused: Bool

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()
                VStack(alignment: .leading, spacing: 16) {
                    HomeSectionHeader(title: "NÁZOV ZOSTAVY")
                    TextField("", text: $name, prompt: Text("napr. Súťažná 2026").foregroundColor(.white.opacity(0.5)))
                        .focused($isFocused)
                        .submitLabel(.done)
                        .onSubmit { if !trimmed.isEmpty { onCreate(trimmed) } }
                        .authFieldChrome()
                    PrimarySheetButton(title: "Založiť a otvoriť plátno", isLoading: false, isEnabled: !trimmed.isEmpty) {
                        onCreate(trimmed)
                    }
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Nová zostava · \(danceName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zrušiť") { dismiss() }
                        .foregroundColor(Color.gold400)
                }
            }
            .onAppear { isFocused = true }
        }
        .presentationDetents([.medium])
    }
}
