import SwiftUI
import SwiftData
import PhotosUI
import AVFoundation
import OSLog

// MARK: - Choose a video or photo
/// Picks media for one slot (my video or the model): record now, pick from Fotky, or reuse anything already
/// in Encore (BRAND_GUIDELINES §1A). A video picked from Fotky is referenced, not copied, so the iPhone keeps
/// one copy; a photo is copied, because photos are small and must open without Fotky access.
struct UniversalMediaPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let slotTitle: String
    let currentPath: String?
    let onSelectMedia: (String) -> Void
    var onClearMedia: (() -> Void)? = nil

    @Query(sort: \VideoMediaEntry.createdAt, order: .reverse) private var allVaultEntries: [VideoMediaEntry]
    @Query(sort: \Routine.createdAt, order: .reverse) private var allRoutines: [Routine]
    @Query(sort: \InstantNote.createdAt, order: .reverse) private var allNotes: [InstantNote]
    @Query(sort: \Dance.name) private var allDances: [Dance]

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showCameraModal = false
    @State private var filter: MediaFilter = .all
    @State private var searchText = ""
    @State private var isImporting = false
    @State private var importFailed = false

    enum MediaFilter: String, CaseIterable, Identifiable {
        case all = "Všetko"
        case videos = "Videá"
        case photos = "Fotky"
        case models = "Vzory"
        case mine = "Moje"

        var id: String { rawValue }
    }

    struct MediaItemRecord: Identifiable {
        let id: String
        let title: String
        let path: String
        let role: String
        let isImage: Bool
        /// A model to compare against (dance model, routine target, vault "Idol / Vzor").
        let isModel: Bool
    }

    private var aggregatedItems: [MediaItemRecord] {
        var items: [MediaItemRecord] = []
        var seenPaths = Set<String>()
        func add(_ id: String, _ title: String, _ path: String?, _ role: String, isImage: Bool, isModel: Bool) {
            guard let path, !path.isEmpty, seenPaths.insert(path).inserted else { return }
            items.append(MediaItemRecord(id: id, title: title, path: path, role: role, isImage: isImage, isModel: isModel))
        }

        for entry in allVaultEntries {
            add(entry.id.uuidString, entry.title.isEmpty ? "Záznam" : entry.title, entry.filePath, entry.role.displayName,
                isImage: MediaResolver.isImagePath(path: entry.filePath), isModel: entry.role == .targetIdol)
        }
        for routine in allRoutines {
            add("rt_v_\(routine.id)", routine.name, routine.videoPath, "Zostava",
                isImage: routine.videoPath.map { MediaResolver.isImagePath(path: $0) } ?? false, isModel: false)
            add("rt_tgt_\(routine.id)", routine.name, routine.activeTargetVideoPath, "Vzor zostavy",
                isImage: routine.activeTargetVideoPath.map { MediaResolver.isImagePath(path: $0) } ?? false, isModel: true)
        }
        for note in allNotes {
            add("note_v_\(note.id)", note.text.isEmpty ? "Video z poznámky" : note.text, note.videoPath, "Poznámka",
                isImage: false, isModel: false)
            add("note_img_\(note.id)", note.text.isEmpty ? "Fotka z poznámky" : note.text, note.imagePath, "Poznámka",
                isImage: true, isModel: false)
        }
        for dance in allDances {
            add("dance_v_\(dance.id)", dance.name, dance.videoPath, "Vzor tanca", isImage: false, isModel: true)
            add("dance_img_\(dance.id)", dance.name, dance.imagePath, "Fotka tanca", isImage: true, isModel: true)
        }
        return items
    }

    private var filteredItems: [MediaItemRecord] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return aggregatedItems.filter { item in
            if !query.isEmpty,
               !item.title.localizedCaseInsensitiveContains(query),
               !item.role.localizedCaseInsensitiveContains(query) {
                return false
            }
            switch filter {
            case .all: return true
            case .videos: return !item.isImage
            case .photos: return item.isImage
            case .models: return item.isModel
            case .mine: return !item.isModel
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        sourceButtons
                        searchField
                        filterChips

                        if filteredItems.isEmpty {
                            emptyState
                        } else {
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                                ForEach(filteredItems) { item in
                                    mediaCard(item)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
                .scrollDismissesKeyboard(.interactively)

                if isImporting {
                    Color.black.opacity(0.55).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView().tint(Color.gold400).controlSize(.large)
                        Text("Pripravujem…")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                    }
                    .padding(24)
                    .homeCard(cornerRadius: 20)
                }
            }
            .navigationTitle(slotTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zrušiť") { dismiss() }
                        .foregroundColor(Color.gold400)
                }
                if currentPath != nil, let onClearMedia {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Odstrániť") {
                            onClearMedia()
                            dismiss()
                        }
                        .foregroundColor(Color.latinRed)
                    }
                }
            }
            .fullScreenCover(isPresented: $showCameraModal) {
                DanceCameraView(savesToPhotos: true) { path in
                    onSelectMedia(path)
                    dismiss()
                }
                .ignoresSafeArea()
            }
            .onChange(of: selectedPhotoItem) { _, item in
                importFromPhotos(item)
            }
            .alert("Nepodarilo sa načítať", isPresented: $importFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Toto video alebo fotku sa nedá otvoriť. Skús iné.")
            }
            .sensoryFeedback(.selection, trigger: filter)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Sources
    private var sourceButtons: some View {
        HStack(spacing: 10) {
            Button {
                showCameraModal = true
            } label: {
                Label("Natočiť", systemImage: "video.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(Color.obsidian900)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(
                        LinearGradient(colors: [Color.gold400, Color.gold500], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
            }
            .buttonStyle(.pressable)

            PhotosPicker(selection: $selectedPhotoItem, matching: .any(of: [.videos, .images]), photoLibrary: .shared()) {
                Label("Z Fotiek", systemImage: "photo.on.rectangle")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .homeCard(cornerRadius: 16)
            }
            .buttonStyle(.pressable)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color.gold400)
            TextField("", text: $searchText, prompt: Text("Hľadať v Encore").foregroundColor(.white.opacity(0.4)))
                .foregroundColor(.white)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.4))
                }
                .accessibilityLabel("Vymazať hľadanie")
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 46)
        .homeCard(cornerRadius: 14)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MediaFilter.allCases) { option in
                    let isOn = filter == option
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) { filter = option }
                    } label: {
                        Text(option.rawValue)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(isOn ? Color.obsidian900 : .white.opacity(0.85))
                            .padding(.horizontal, 14)
                            .frame(minHeight: 36)
                            .background(isOn ? AnyShapeStyle(Color.gold400) : AnyShapeStyle(Color.white.opacity(0.07)), in: Capsule())
                    }
                    .buttonStyle(.pressable)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
        }
        .scrollClipDisabled()
    }

    // MARK: Items
    private func mediaCard(_ item: MediaItemRecord) -> some View {
        let isSelected = currentPath == item.path
        return Button {
            onSelectMedia(item.path)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                MediaThumbnailView(path: item.path, placeholderIcon: item.isImage ? "photo" : "film", cornerRadius: 12)
                    .aspectRatio(16 / 11, contentMode: .fit)
                    .overlay(alignment: .topTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(Color.obsidian900, Color.gold400)
                                .padding(6)
                        }
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.footnote.weight(.bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(item.role)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(item.isModel ? Color.gold400 : .white.opacity(0.55))
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
            }
            .padding(6)
            .homeCard(cornerRadius: 16)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.gold400 : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.pressable(scale: 0.97))
        .accessibilityLabel("\(item.title), \(item.role)\(isSelected ? ", vybraté" : "")")
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.stack")
                .font(.system(size: 38))
                .foregroundColor(Color.gold400.opacity(0.5))
            Text(searchText.isEmpty ? "Tu zatiaľ nič nie je" : "Nič sa nenašlo")
                .font(.subheadline.weight(.bold))
                .foregroundColor(.white)
            Text("Natoč video alebo vyber fotku či video z Fotiek tlačidlami hore.")
                .font(.footnote)
                .foregroundColor(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: Import from Fotky
    private func importFromPhotos(_ item: PhotosPickerItem?) {
        guard let item else { return }
        selectedPhotoItem = nil
        isImporting = true
        Task {
            defer { isImporting = false }
            if let path = await PhotosImport.storedPath(for: item) {
                onSelectMedia(path)
                dismiss()
            } else {
                importFailed = true
            }
        }
    }
}

// MARK: - Picking from Fotky
/// The path Encore stores for an item picked in Fotky. Used by the media picker and by Denník (`FotkyVideoPicker`).
enum PhotosImport {
    /// A video stays in Fotky and is referenced; a photo (or a video Encore may not read) is copied.
    static func storedPath(for item: PhotosPickerItem) async -> String? {
        let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .movie) }
        if isVideo {
            if let identifier = item.itemIdentifier {
                var allowed = PhotoLibraryVideoStore.hasAccess
                if !allowed { allowed = await PhotoLibraryVideoStore.requestAccess() }
                if allowed { return PhotoLibraryVideoStore.referencePrefix + identifier }
            }
            do {
                if let movie = try await item.loadTransferable(type: MovieTransferable.self) {
                    return try MediaStorageManager.copyIntoDocuments(from: movie.url, fileExtension: "mp4")
                }
            } catch {
                Logger.camera.error("Copying a video from Photos failed: \(error.localizedDescription, privacy: .public)")
            }
            return nil
        }
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                return try MediaStorageManager.store(data: data, prefix: "import_photo", fileExtension: "jpg")
            }
        } catch {
            Logger.camera.error("Copying a photo from Photos failed: \(error.localizedDescription, privacy: .public)")
        }
        return nil
    }
}
