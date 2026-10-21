import SwiftUI
import SwiftData

// MARK: - My library (opened from Profile)

/// All routines, newest first, as the same cards as on Home and in the Canvas tab.
struct ProfileRoutinesListView: View {
    let routines: [Routine]
    @State private var routineToOpen: Routine?

    var body: some View {
        ZStack {
            EllegancePageBackground()
            ScrollView {
                LazyVStack(spacing: 14) {
                    if routines.isEmpty {
                        ProfileEmptyState(icon: "rectangle.dashed", text: "Zatiaľ nemáš žiadne zostavy.")
                    }
                    ForEach(routines) { routine in
                        RoutineCard(routine: routine) { routineToOpen = routine }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Zostavy")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $routineToOpen) { RoutineCanvasView(routine: $0) }
    }
}

/// The figure library: search, one dance or all, grouped by dance in competition order.
struct ProfileFiguresListView: View {
    @Query private var figures: [FigureLibraryItem]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedFigure: FigureLibraryItem?
    @State private var showNewFigure = false
    @State private var refreshCount = 0
    @State private var query = ""
    @State private var danceFilter: String?

    private var groups: [(dance: String, figures: [FigureLibraryItem])] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let matching = figures.filter { figure in
            (danceFilter == nil || figure.danceName == danceFilter)
                && (needle.isEmpty || figure.name.localizedStandardContains(needle))
        }
        return Dictionary(grouping: matching, by: \.danceName)
            .map { (dance: $0.key, figures: $0.value.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) }
            .sorted { DanceNames.rank($0.dance) < DanceNames.rank($1.dance) }
    }

    var body: some View {
        ZStack {
            EllegancePageBackground()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10, pinnedViews: []) {
                    HStack(spacing: 10) {
                        searchField
                        DanceMenuCapsule(selection: $danceFilter, emptyTitle: "Všetky", clearTitle: "Všetky tance")
                    }
                    .padding(.bottom, 6)

                    if figures.isEmpty {
                        ProfileEmptyState(icon: "book.closed", text: "Knižnica je zatiaľ prázdna.")
                    } else if groups.isEmpty {
                        ProfileEmptyState(icon: "magnifyingglass", text: "Žiadna figúra s týmto názvom.")
                    }

                    ForEach(groups, id: \.dance) { group in
                        HomeSectionHeader(title: DanceNames.display(group.dance).uppercased(), count: group.figures.count)
                            .padding(.top, 12)
                            .padding(.horizontal, 4)
                        ForEach(group.figures) { figure in
                            Button { selectedFigure = figure } label: { figureRow(figure) }
                                .buttonStyle(.pressable(scale: 0.97))
                                .transition(.opacity.combined(with: .scale(scale: 0.97)))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 120)   // clear of the tab bar
                .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85), value: danceFilter)
            }
            .scrollDismissesKeyboard(.interactively)
            .refreshable {
                refreshCount += 1
                await FigureLibrarySync.pull(into: modelContext)
            }
        }
        .navigationTitle("Knižnica figúr")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showNewFigure = true } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Nová figúra")
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: refreshCount)
        .sheet(item: $selectedFigure) { LibraryFigureDetailSheet(figure: $0) }
        .sheet(isPresented: $showNewFigure) { NewFigureSheet() }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color.textSecondary)
            TextField("", text: $query, prompt: Text("Hľadať figúru").foregroundColor(Color.textPlaceholder))
                .foregroundColor(.white)
                .submitLabel(.search)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(Color.textSecondary)
                }
                .accessibilityLabel("Vymazať hľadanie")
            }
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .frame(minHeight: 40)
        .background(Color.white.opacity(0.08), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    private func figureRow(_ figure: FigureLibraryItem) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(figure.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if !figure.rhythm.isEmpty {
                    Text(figure.rhythm)
                        .font(.caption)
                        .foregroundColor(Color.white.opacity(0.65))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if figure.videoPath != nil {
                Image(systemName: "video.fill")
                    .font(.caption)
                    .foregroundColor(Color.gold400)
                    .accessibilityLabel("Má video")
            }
            if figure.isCustom {
                Text("Moja")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(Color.obsidian900)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.gold400, in: Capsule())
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundColor(.white.opacity(0.35))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .homeCard(cornerRadius: 16)
        .accessibilityElement(children: .combine)
    }
}

/// Every video and note across routines, figures and dances.
struct ProfileMediaListView: View {
    let dances: [Dance]
    let figures: [FigureLibraryItem]
    let nodes: [CanvasNode]

    @State private var selectedNode: CanvasNode?
    @State private var selectedFigure: FigureLibraryItem?
    @State private var selectedDance: Dance?

    private func hasText(_ text: String) -> Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private var nodesWithMedia: [CanvasNode] { nodes.filter { $0.videoPath != nil || hasText($0.notes) } }
    private var figuresWithMedia: [FigureLibraryItem] { figures.filter { $0.videoPath != nil || hasText($0.techniqueNotes) } }
    private var dancesWithMedia: [Dance] { dances.filter { $0.videoPath != nil || hasText($0.info) } }

    var body: some View {
        ZStack {
            EllegancePageBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if nodesWithMedia.isEmpty && figuresWithMedia.isEmpty && dancesWithMedia.isEmpty {
                        ProfileEmptyState(icon: "tray", text: "Zatiaľ tu nie sú videá ani poznámky.")
                    }
                    if !nodesWithMedia.isEmpty {
                        HomeRowGroup(title: "Z MOJICH ZOSTÁV") {
                            ForEach(Array(nodesWithMedia.enumerated()), id: \.element.id) { index, node in
                                if index > 0 { HomeRowDivider() }
                                Button { selectedNode = node } label: {
                                    mediaRow(node.figureName, node.routine?.name ?? "Zostava", video: node.videoPath != nil, note: hasText(node.notes))
                                }
                                .buttonStyle(.pressable(scale: 0.98))
                            }
                        }
                    }
                    if !figuresWithMedia.isEmpty {
                        HomeRowGroup(title: "FIGÚRY") {
                            ForEach(Array(figuresWithMedia.enumerated()), id: \.element.id) { index, figure in
                                if index > 0 { HomeRowDivider() }
                                Button { selectedFigure = figure } label: {
                                    mediaRow(figure.name, figure.danceName, video: figure.videoPath != nil, note: hasText(figure.techniqueNotes))
                                }
                                .buttonStyle(.pressable(scale: 0.98))
                            }
                        }
                    }
                    if !dancesWithMedia.isEmpty {
                        HomeRowGroup(title: "TANCE") {
                            ForEach(Array(dancesWithMedia.enumerated()), id: \.element.id) { index, dance in
                                if index > 0 { HomeRowDivider() }
                                Button { selectedDance = dance } label: {
                                    mediaRow(dance.name, dance.category == "Standard" ? "Štandard" : "Latina", video: dance.videoPath != nil, note: hasText(dance.info))
                                }
                                .buttonStyle(.pressable(scale: 0.98))
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Videá a poznámky")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $selectedNode) { FigureDetailCard(node: $0) }
        .sheet(item: $selectedFigure) { LibraryFigureDetailSheet(figure: $0) }
        .sheet(item: $selectedDance) { EditDanceSheet(dance: $0) }
    }

    private func mediaRow(_ title: String, _ subtitle: String, video: Bool, note: Bool) -> some View {
        HomeRow(
            icon: video ? "video.fill" : "text.alignleft",
            title: title,
            subtitle: subtitle,
            detail: [video ? "video" : nil, note ? "poznámka" : nil].compactMap { $0 }.joined(separator: " + ")
        )
    }
}

/// Empty list message in the library screens.
struct ProfileEmptyState: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(Color.gold400.opacity(0.8))
            Text(text)
                .font(.footnote.weight(.semibold))
                .foregroundColor(Color.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .homeCard()
    }
}
