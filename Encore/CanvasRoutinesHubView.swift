import SwiftUI
import SwiftData

// MARK: - Canvas tab: my routines
/// The user's routines in the Home style (BRAND_GUIDELINES §1A). Tapping a card opens its canvas.
public struct CanvasRoutinesHubView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Routine.updatedAt, order: .reverse) private var routines: [Routine]

    @State private var searchText = ""
    @State private var filter: CategoryFilter = .all
    @State private var selectedRoutineForCanvas: Routine?
    @State private var showNewRoutineSheet = false
    @State private var routineForQRExport: Routine?
    @State private var routinePendingDelete: Routine?
    @State private var routineToRename: Routine?
    @State private var renameText = ""
    @AppStorage("profileName") private var userName = "Tanečník"
    @State private var deleteCount = 0
    @State private var sweepTrigger = 0
    @FocusState private var isSearching: Bool
    @Namespace private var filterNamespace

    private enum CategoryFilter: String, CaseIterable, Identifiable {
        case all = "Všetky", standard = "Štandard", latin = "Latina"

        var id: String { rawValue }

        var icon: String? {
            switch self {
            case .all: return nil
            case .standard: return "drop.fill"
            case .latin: return "flame.fill"
            }
        }

        func matches(_ routine: Routine) -> Bool {
            let category = routine.danceCategory.lowercased()
            switch self {
            case .all: return true
            case .standard: return category == "standard"
            case .latin: return category == "latin" || category == "latina"
            }
        }
    }

    private var filteredRoutines: [Routine] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return routines.filter { routine in
            filter.matches(routine)
                && (query.isEmpty
                    || routine.name.lowercased().contains(query)
                    || routine.danceName.lowercased().contains(query))
        }
    }

    private var statsText: String {
        let figures = routines.reduce(0) { $0 + $1.canvasNodes.count }
        return slovakCount(routines.count, one: "zostava", few: "zostavy", many: "zostáv")
            + " · " + slovakCount(figures, one: "figúra", few: "figúry", many: "figúr")
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        searchField
                        filterBar

                        if filteredRoutines.isEmpty {
                            emptyState
                        } else {
                            LazyVStack(spacing: 14) {
                                ForEach(filteredRoutines) { routine in
                                    RoutineCard(routine: routine, onShareQR: { shareQR(routine) }) {
                                        selectedRoutineForCanvas = routine
                                    }
                                    .contextMenu { menu(for: routine) }
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                                        removal: .scale(scale: 0.9).combined(with: .opacity)
                                    ))
                                }
                            }
                        }

                        // Room for the tab bar
                        Spacer().frame(height: 120)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .background {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { isSearching = false }
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.85), value: filteredRoutines.map(\.id))
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedRoutineForCanvas) { routine in
                RoutineCanvasView(routine: routine, isPresentedInTab: true)
            }
            .sheet(isPresented: $showNewRoutineSheet) {
                NavigationStack {
                    DanceCategorySelectionSheet(isPresented: $showNewRoutineSheet)
                }
            }
            .sheet(item: $routineForQRExport) { routine in
                QRExportSheet(routine: routine)
            }
            .confirmationDialog(
                "Zmazať zostavu?",
                isPresented: Binding(get: { routinePendingDelete != nil }, set: { if !$0 { routinePendingDelete = nil } }),
                titleVisibility: .visible,
                presenting: routinePendingDelete
            ) { routine in
                Button("Zmazať „\(routine.name)“", role: .destructive) { delete(routine) }
            } message: { _ in
                Text("Zostava aj jej figúry sa zmažú z tohto iPhonu aj z cloudu. Nedá sa to vrátiť.")
            }
            .alert("Premenovať zostavu", isPresented: Binding(
                get: { routineToRename != nil },
                set: { if !$0 { routineToRename = nil } }
            )) {
                TextField("Názov zostavy", text: $renameText)
                Button("Uložiť") { routineToRename?.rename(to: renameText, by: userName) }
                Button("Zrušiť", role: .cancel) {}
            }
            .onChange(of: isSearching) { _, focused in
                if focused { sweepTrigger += 1 }
            }
            .sensoryFeedback(.selection, trigger: filter)
            .sensoryFeedback(.warning, trigger: deleteCount)
        }
    }

    // MARK: Header
    private var header: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("CHOREOGRAFIE")
                    .font(.system(.caption, design: .rounded).weight(.black))
                    .foregroundColor(Color.gold400)
                    .tracking(1.4)
                Text("Moje zostavy")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .accessibilityAddTraits(.isHeader)
            }

            Spacer(minLength: 8)

            Button { showNewRoutineSheet = true } label: {
                Label("Nová", systemImage: "plus")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(Color.obsidian900)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 40)
                    .background(
                        LinearGradient(colors: [Color.gold400, Color.gold500], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: Capsule()
                    )
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Nová zostava")
        }
    }

    // MARK: Search
    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline.weight(.medium))
                .foregroundColor(Color.gold400)
                .accessibilityHidden(true)

            TextField("", text: $searchText, prompt: Text("Hľadať zostavu alebo tanec").foregroundColor(Color.white.opacity(0.5)))
                .font(.subheadline)
                .foregroundColor(.white)
                .focused($isSearching)
                .submitLabel(.search)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { searchText = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color.white.opacity(0.55))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Vymazať hľadanie")
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 46)
        .homeCard(cornerRadius: 14)
        .overlay { FieldEdgeSweep(trigger: sweepTrigger) }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: searchText.isEmpty)
    }

    // MARK: Filters
    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach(CategoryFilter.allCases) { item in
                    let isSelected = filter == item
                    Button {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.78)) { filter = item }
                    } label: {
                        HStack(spacing: 5) {
                            if let icon = item.icon {
                                Image(systemName: icon)
                                    .foregroundColor(item == .standard ? Color.standardBlue : Color.latinCrimson)
                            }
                            Text(item.rawValue)
                        }
                        .font(.footnote.weight(isSelected ? .bold : .medium))
                        .foregroundColor(isSelected ? .white : Color.white.opacity(0.75))
                        .lineLimit(1)
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity)
                        .background {
                            ZStack {
                                Capsule().fill(Color.white.opacity(0.05))
                                if isSelected {
                                    Capsule()
                                        .fill(Color.white.opacity(0.14))
                                        .matchedGeometryEffect(id: "routineFilter", in: filterNamespace)
                                }
                            }
                        }
                        .overlay(
                            Capsule().stroke(isSelected ? Color.gold400.opacity(0.45) : Color.white.opacity(0.08), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.pressable)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }

            if !routines.isEmpty {
                Text(statsText)
                    .font(.caption.weight(.medium))
                    .foregroundColor(Color.white.opacity(0.6))
                    .contentTransition(.numericText())
            }
        }
    }

    // MARK: Empty state
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.dance")
                .font(.largeTitle)
                .foregroundColor(Color.gold400)
                .frame(width: 80, height: 80)
                .background(Color.gold500.opacity(0.14), in: Circle())
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text(routines.isEmpty ? "Zatiaľ nemáš žiadnu zostavu" : "Nič sa nenašlo")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundColor(.white)
                Text(routines.isEmpty
                     ? "Vytvor si prvú choreografiu a rozlož figúry po parkete."
                     : "Skús iné slovo alebo iný filter.")
                    .font(.footnote)
                    .foregroundColor(Color.white.opacity(0.65))
                    .multilineTextAlignment(.center)
            }

            if routines.isEmpty {
                Button { showNewRoutineSheet = true } label: {
                    Label("Vytvoriť prvú zostavu", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(Color.obsidian900)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(colors: [Color.gold400, Color.gold500], startPoint: .leading, endPoint: .trailing),
                            in: Capsule()
                        )
                }
                .buttonStyle(.pressable)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .transition(.opacity)
    }

    // MARK: Actions
    @ViewBuilder
    private func menu(for routine: Routine) -> some View {
        Button { selectedRoutineForCanvas = routine } label: {
            Label("Otvoriť plátno", systemImage: "square.grid.2x2")
        }
        Button {
            renameText = routine.name
            routineToRename = routine
        } label: {
            Label("Premenovať", systemImage: "pencil")
        }
        Button { shareQR(routine) } label: {
            Label("Zdieľať QR kód", systemImage: "qrcode")
        }
        Button(role: .destructive) { routinePendingDelete = routine } label: {
            Label("Zmazať zostavu", systemImage: "trash")
        }
    }

    private func shareQR(_ routine: Routine) {
        routineForQRExport = routine
    }

    private func delete(_ routine: Routine) {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
            routine.deleteEverywhere(in: modelContext)
        }
        deleteCount += 1
    }
}

extension Routine {
    static let maxNameLength = 60

    /// Renames the routine; empty names are ignored. Saves and syncs (the partner gets it with the next refresh).
    func rename(to newName: String, by userName: String) {
        let clean = String(newName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxNameLength))
        guard !clean.isEmpty, clean != name else { return }
        name = clean
        updatedAt = Date()
        lastModifiedBy = userName
        try? modelContext?.save()
        SupabaseSyncManager.shared.syncRoutineOnBackground(self)
    }

    /// Deletes the routine here and in the cloud, with the figure videos it kept in Encore
    /// (a video from Fotky stays in Fotky).
    @MainActor
    func deleteEverywhere(in context: ModelContext) {
        let routineId = id
        for node in canvasNodes {
            FigureVideoPlayback.shared.stop(nodeId: node.id)
            MediaStorageManager.removeFile(named: node.videoPath)
        }
        context.delete(self)
        try? context.save()
        Task { await SupabaseSyncManager.shared.deleteRoutine(routineId) }
    }
}
