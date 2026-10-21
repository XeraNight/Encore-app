import SwiftUI
import SwiftData
import UniformTypeIdentifiers

enum VaultFilter: String, CaseIterable, Identifiable {
    case all = "Všetky"
    case myTake = "Moje"
    case targetIdol = "Vzory"
    case coach = "Od trénera"
    case favorites = "Obľúbené"

    var id: String { rawValue }
}

struct IdentifiableURL: Identifiable, Sendable {
    let id: UUID
    let url: URL

    init(id: UUID = UUID(), url: URL) {
        self.id = id
        self.url = url
    }
}

// MARK: - Videá zostavy
/// The routine's videos and photos (BRAND_GUIDELINES §1A). Each one can go into the comparison as
/// "Ja" or "Vzor", be trimmed, renamed or removed. New videos are saved to Fotky like everywhere else.
struct VideoVaultView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Parent Context
    var routine: Routine?
    var node: CanvasNode?

    // Bindings to active comparison slots
    @Binding var activeSlotAPath: String?
    @Binding var activeSlotBPath: String?

    // Local State
    @State private var selectedFilter: VaultFilter = .all
    @State private var showCamera = false
    @State private var showMediaPicker = false
    @State private var showComparison = false
    @State private var showStorageAlert = false
    @State private var entryToDelete: VideoMediaEntry?
    @State private var changeCount = 0
    @Namespace private var filterNamespace

    // Trimming State
    @State private var trimmingItem: IdentifiableURL?
    @State private var trimmingEntry: VideoMediaEntry?

    @Query(sort: \VideoMediaEntry.createdAt, order: .reverse) private var allVaultEntries: [VideoMediaEntry]

    // Edit item sheet state
    @State private var editingEntry: VideoMediaEntry?
    @State private var editTitle = ""
    @State private var editRole: VideoMediaRole = .myTake

    var mediaItems: [VideoMediaEntry] {
        if let routine {
            return routine.mediaVault.sorted { $0.createdAt > $1.createdAt }
        } else if let node {
            return node.mediaVault.sorted { $0.createdAt > $1.createdAt }
        }
        return allVaultEntries
    }

    var filteredItems: [VideoMediaEntry] {
        mediaItems.filter { item in
            switch selectedFilter {
            case .all: return true
            case .myTake: return item.role == .myTake
            case .targetIdol: return item.role == .targetIdol
            case .coach: return item.role == .coach
            case .favorites: return item.isFavorite
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        comparisonCard
                        filterChipsBar

                        if filteredItems.isEmpty {
                            emptyVaultView
                        } else {
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 14) {
                                ForEach(filteredItems) { entry in
                                    videoCard(for: entry)
                                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                    .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85), value: selectedFilter)
                    .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85), value: mediaItems.map(\.id))
                }
                .safeAreaInset(edge: .bottom) { actionBar }
            }
            .navigationTitle("Videá zostavy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zavrieť") { dismiss() }
                        .foregroundColor(Color.gold400)
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                DanceCameraView(ghostVideoPath: activeSlotBPath, savesToPhotos: true) { localPath in
                    addNewVideoEntry(filePath: localPath, defaultRole: .myTake, defaultTitle: "Záznam z tréningu")
                    showCamera = false
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showMediaPicker) {
                UniversalMediaPickerSheet(
                    slotTitle: "Pridať do videí zostavy",
                    currentPath: nil,
                    onSelectMedia: { path in
                        addNewVideoEntry(filePath: path, defaultRole: .targetIdol,
                                         defaultTitle: MediaResolver.isImagePath(path: path) ? "Fotka" : "Vzor")
                    },
                    onClearMedia: {}
                )
            }
            .sheet(isPresented: $showComparison) {
                DualVideoComparisonView(pathA: $activeSlotAPath, pathB: $activeSlotBPath)
            }
            .sheet(item: $editingEntry) { entry in
                editEntrySheet(entry)
            }
            .fullScreenCover(item: $trimmingItem) { item in
                VideoTrimView(originalVideoURL: item.url) { trimmedURL in
                    if let entry = trimmingEntry,
                       let newFilename = try? MediaStorageManager.copyIntoDocuments(from: trimmedURL, fileExtension: "mp4") {
                        let oldPath = entry.filePath
                        entry.filePath = newFilename
                        if activeSlotAPath == oldPath { activeSlotAPath = newFilename }
                        if activeSlotBPath == oldPath { activeSlotBPath = newFilename }
                        saveChanges()
                    }
                    trimmingItem = nil
                    trimmingEntry = nil
                }
            }
            .confirmationDialog(
                entryToDelete.map { MediaResolver.isImagePath(path: $0.filePath) ? "Odstrániť fotku?" : "Odstrániť video?" } ?? "",
                isPresented: Binding(get: { entryToDelete != nil }, set: { if !$0 { entryToDelete = nil } }),
                titleVisibility: .visible
            ) {
                Button("Odstrániť", role: .destructive) {
                    if let entry = entryToDelete { deleteEntry(entry) }
                    entryToDelete = nil
                }
            } message: {
                Text(entryToDelete.map { PhotoLibraryVideoStore.isReference($0.filePath) } == true
                     ? "Zmizne z videí zostavy. Vo Fotkách ti ostane."
                     : "Zmaže sa zo zostavy aj z telefónu.")
            }
            .alert("Nedostatok miesta v úložisku", isPresented: $showStorageAlert) {
                Button("Rozumiem", role: .cancel) { }
            } message: {
                Text("V iPhone máš menej ako 100 MB voľného miesta. Na ďalšie videá uvoľni miesto.")
            }
            .sensoryFeedback(.selection, trigger: selectedFilter)
            .sensoryFeedback(.success, trigger: changeCount)
        }
    }

    // MARK: - Comparison
    private var comparisonCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeader(title: "POROVNANIE", systemImage: "rectangle.split.2x1")
            HStack(spacing: 10) {
                slotPill("Ja", path: activeSlotAPath) { activeSlotAPath = nil; saveChanges() }
                slotPill("Vzor", path: activeSlotBPath) { activeSlotBPath = nil; saveChanges() }
            }
            PrimarySheetButton(title: "Porovnať", isLoading: false,
                               isEnabled: activeSlotAPath != nil || activeSlotBPath != nil) {
                showComparison = true
            }
            if activeSlotAPath == nil && activeSlotBPath == nil {
                Text("Ťukni na video a vyber, či ide do porovnania ako Ja alebo Vzor.")
                    .font(.footnote)
                    .foregroundColor(Color.textSecondary)
            }
        }
        .padding(16)
        .homeCard(cornerRadius: 20)
    }

    private func slotPill(_ title: String, path: String?, onClear: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.system(.caption2, design: .rounded).weight(.black))
                    .tracking(1.2)
                    .foregroundColor(Color.gold400)
                Text(titleForPath(path) ?? "Nevybrané")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(path == nil ? .white.opacity(0.5) : .white)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if path != nil {
                Button(action: onClear) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundColor(Color.textSecondary)
                        .frame(width: 28, height: 28)
                }
                .accessibilityLabel("Odobrať z porovnania: \(title)")
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Filters
    private var filterChipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(VaultFilter.allCases) { filter in
                    let isSelected = selectedFilter == filter
                    Button {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.78)) { selectedFilter = filter }
                    } label: {
                        Text(filter.rawValue)
                            .font(.footnote.weight(isSelected ? .bold : .medium))
                            .foregroundColor(isSelected ? .white : .white.opacity(0.75))
                            .padding(.horizontal, 14)
                            .frame(minHeight: 34)
                            .background {
                                ZStack {
                                    Capsule().fill(Color.white.opacity(0.05))
                                    if isSelected {
                                        Capsule()
                                            .fill(Color.white.opacity(0.14))
                                            .matchedGeometryEffect(id: "vaultFilter", in: filterNamespace)
                                    }
                                }
                            }
                            .overlay(Capsule().stroke(isSelected ? Color.gold400.opacity(0.45) : Color.white.opacity(0.08), lineWidth: 1))
                    }
                    .buttonStyle(.pressable)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
        .scrollClipDisabled()
    }

    // MARK: - Card
    private func videoCard(for entry: VideoMediaEntry) -> some View {
        let isSlotA = activeSlotAPath == entry.filePath
        let isSlotB = activeSlotBPath == entry.filePath
        let isPhoto = MediaResolver.isImagePath(path: entry.filePath)

        return Menu {
            Button {
                activeSlotAPath = entry.filePath
                saveChanges()
            } label: {
                Label("Do porovnania ako Ja", systemImage: "person.fill")
            }
            Button {
                activeSlotBPath = entry.filePath
                saveChanges()
            } label: {
                Label("Do porovnania ako Vzor", systemImage: "star.fill")
            }
            Divider()
            Button {
                entry.isFavorite.toggle()
                saveChanges()
            } label: {
                Label(entry.isFavorite ? "Odobrať z obľúbených" : "Pridať k obľúbeným",
                      systemImage: entry.isFavorite ? "star.slash" : "star")
            }
            if !isPhoto {
                Button {
                    Task { await startTrimming(entry) }
                } label: {
                    Label("Orezať video", systemImage: "scissors")
                }
            }
            Button {
                editingEntry = entry
                editTitle = entry.title
                editRole = entry.role
            } label: {
                Label("Premenovať", systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive) {
                entryToDelete = entry
            } label: {
                Label(isPhoto ? "Odstrániť fotku" : "Odstrániť video", systemImage: "trash")
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                MediaThumbnailView(path: entry.filePath, placeholderIcon: isPhoto ? "photo" : "film", cornerRadius: 12)
                    .aspectRatio(4 / 3, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        Label(entry.role.displayName, systemImage: entry.role.iconName)
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.white)
                            .labelStyle(TintedIconLabelStyle(tint: entry.role.tagColor))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.55), in: Capsule())
                            .padding(6)
                    }
                    .overlay(alignment: .topTrailing) {
                        if entry.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(Color.gold400)
                                .padding(6)
                                .background(.black.opacity(0.55), in: Circle())
                                .padding(6)
                                .accessibilityLabel("Obľúbené")
                        }
                    }
                    .overlay(alignment: .bottomLeading) {
                        if isSlotA || isSlotB {
                            Text(isSlotA && isSlotB ? "JA · VZOR" : (isSlotA ? "JA" : "VZOR"))
                                .font(.system(.caption2, design: .rounded).weight(.black))
                                .tracking(1)
                                .foregroundColor(Color.obsidian900)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.gold400, in: Capsule())
                                .padding(6)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title)
                        .font(.footnote.weight(.bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(entry.createdAt, format: .dateTime.day().month(.abbreviated).hour().minute())
                        .font(.caption2)
                        .foregroundColor(Color.textSecondary)
                }
                .padding(.horizontal, 4)
            }
            .padding(8)
            .homeCard(cornerRadius: 16)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.gold400.opacity(isSlotA || isSlotB ? 0.6 : 0), lineWidth: 1.5)
            )
        }
        .buttonStyle(.pressable(scale: 0.97))
        .accessibilityHint("Možnosti videa")
    }

    // MARK: - Empty
    private var emptyVaultView: some View {
        VStack(spacing: 10) {
            Image(systemName: "film.stack")
                .font(.largeTitle)
                .foregroundColor(Color.gold400.opacity(0.7))
            Text(selectedFilter == .all ? "Zatiaľ tu nie sú žiadne videá" : "V tomto filtri nič nie je")
                .font(.subheadline.weight(.bold))
                .foregroundColor(.white)
            Text("Natoč tréning alebo pridaj video vzoru z Fotiek a porovnaj ich.")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.65))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 20)
        .homeCard(cornerRadius: 20)
    }

    // MARK: - Bottom actions
    private var actionBar: some View {
        HStack(spacing: 12) {
            Button {
                if MediaStorageManager.hasAvailableDiskSpace(minMB: 100) {
                    showCamera = true
                } else {
                    showStorageAlert = true
                }
            } label: {
                Label("Natočiť", systemImage: "record.circle")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(Color.obsidian900)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(
                        LinearGradient(colors: [Color.gold400, Color.gold500], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
            }
            .buttonStyle(.pressable)

            Button { showMediaPicker = true } label: {
                Label("Z Fotiek", systemImage: "photo.on.rectangle")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
            }
            .buttonStyle(.pressable)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - Rename
    private func editEntrySheet(_ entry: VideoMediaEntry) -> some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        HomeSectionHeader(title: "NÁZOV")
                        TextField("", text: $editTitle, prompt: Text("napr. Tréning 21. 8.").foregroundColor(Color.textPlaceholder))
                            .authFieldChrome()
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        HomeSectionHeader(title: "DRUH")
                        FlowLayout(spacing: 8) {
                            ForEach(VideoMediaRole.allCases) { role in
                                let isSelected = editRole == role
                                Button { editRole = role } label: {
                                    Label(role.displayName, systemImage: role.iconName)
                                        .font(.footnote.weight(.semibold))
                                        .foregroundColor(isSelected ? Color.obsidian900 : .white.opacity(0.9))
                                        .padding(.horizontal, 14)
                                        .frame(minHeight: 36)
                                        .background(isSelected ? Color.gold400 : Color.white.opacity(0.08), in: Capsule())
                                }
                                .buttonStyle(.pressable)
                                .accessibilityAddTraits(isSelected ? .isSelected : [])
                            }
                        }
                    }
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Upraviť")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zrušiť") { editingEntry = nil }
                        .foregroundColor(Color.gold400)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Uložiť") {
                        let trimmed = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        entry.title = trimmed.isEmpty ? "Záznam" : trimmed
                        entry.role = editRole
                        saveChanges()
                        editingEntry = nil
                    }
                    .fontWeight(.bold)
                    .foregroundColor(Color.gold400)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Helper Methods
    private func startTrimming(_ entry: VideoMediaEntry) async {
        guard let url = await MediaResolver.videoURL(path: entry.filePath) else { return }
        trimmingEntry = entry
        trimmingItem = IdentifiableURL(url: url)
    }

    private func addNewVideoEntry(filePath: String, defaultRole: VideoMediaRole, defaultTitle: String) {
        let entry = VideoMediaEntry(
            filePath: filePath,
            title: defaultTitle,
            role: defaultRole
        )

        if let routine {
            entry.routine = routine
            routine.mediaVault.append(entry)
            if routine.videoPath == nil && defaultRole == .myTake {
                routine.videoPath = filePath
                activeSlotAPath = filePath
            } else if routine.activeTargetVideoPath == nil && defaultRole == .targetIdol {
                routine.activeTargetVideoPath = filePath
                activeSlotBPath = filePath
            }
        } else if let node {
            entry.canvasNode = node
            node.mediaVault.append(entry)
            if node.videoPath == nil && defaultRole == .myTake {
                node.videoPath = filePath
                activeSlotAPath = filePath
            } else if node.activeTargetVideoPath == nil && defaultRole == .targetIdol {
                node.activeTargetVideoPath = filePath
                activeSlotBPath = filePath
            }
        } else {
            modelContext.insert(entry)
            if activeSlotAPath == nil && defaultRole == .myTake {
                activeSlotAPath = filePath
            } else if activeSlotBPath == nil && defaultRole == .targetIdol {
                activeSlotBPath = filePath
            }
        }

        saveChanges()
    }

    private func deleteEntry(_ entry: VideoMediaEntry) {
        if activeSlotAPath == entry.filePath { activeSlotAPath = nil }
        if activeSlotBPath == entry.filePath { activeSlotBPath = nil }

        MediaStorageManager.removeFile(named: entry.filePath)   // a Fotky video stays in Fotky

        if let routine {
            routine.mediaVault.removeAll { $0.id == entry.id }
            if routine.videoPath == entry.filePath { routine.videoPath = nil }
            if routine.activeTargetVideoPath == entry.filePath { routine.activeTargetVideoPath = nil }
        } else if let node {
            node.mediaVault.removeAll { $0.id == entry.id }
            if node.videoPath == entry.filePath { node.videoPath = nil }
            if node.activeTargetVideoPath == entry.filePath { node.activeTargetVideoPath = nil }
        }

        modelContext.delete(entry)
        saveChanges()
    }

    private func titleForPath(_ path: String?) -> String? {
        guard let path else { return nil }
        return mediaItems.first { $0.filePath == path }?.title ?? "Video figúry"
    }

    private func saveChanges() {
        try? modelContext.save()
        changeCount += 1
    }
}

/// A label whose icon has its own colour while the title stays white.
private struct TintedIconLabelStyle: LabelStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon.foregroundColor(tint)
            configuration.title
        }
    }
}

// MARK: - Movie Transferable for PhotosPicker
struct MovieTransferable: Transferable {
    let url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let copyURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(UUID().uuidString).mp4")
            try? FileManager.default.removeItem(at: copyURL)
            try FileManager.default.copyItem(at: received.file, to: copyURL)
            return MovieTransferable(url: copyURL)
        }
    }
}
