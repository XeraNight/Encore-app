import SwiftUI
import PhotosUI

// MARK: - Video attached to a figure or a dance
/// Plays the attached video with speed chips, or offers to film one or pick it from Fotky.
/// Removing asks first; a video from Fotky stays in Fotky.
struct AttachedVideoSection: View {
    @Binding var videoPath: String?
    var onChange: () -> Void

    @AppStorage("defaultPlaybackRate") private var defaultPlaybackRate = 1.0
    @State private var playbackRate: Float?
    @State private var showCamera = false
    @State private var showMediaPicker = false
    @State private var confirmDelete = false

    private static let speeds: [Float] = [0.5, 0.75, 1, 1.5]
    private var rate: Float { playbackRate ?? Float(defaultPlaybackRate) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HomeSectionHeader(title: "VIDEO", systemImage: "video.fill") {
                if videoPath != nil {
                    Button { confirmDelete = true } label: {
                        Label("Odstrániť", systemImage: "trash")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(Color.latinRed)
                    }
                    .buttonStyle(.pressable)
                }
            }

            if let videoPath {
                LoopingVideoPlayer(videoPath: videoPath, rate: rate)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    .transition(.scale(scale: 0.97).combined(with: .opacity))

                HStack(spacing: 8) {
                    ForEach(Self.speeds, id: \.self) { speed in
                        let isSelected = rate == speed
                        Button { playbackRate = speed } label: {
                            Text(Self.speedText(speed))
                                .font(.footnote.weight(isSelected ? .bold : .semibold))
                                .foregroundColor(isSelected ? Color.obsidian900 : .white.opacity(0.85))
                                .frame(maxWidth: .infinity, minHeight: 34)
                                .background(isSelected ? Color.gold400 : Color.white.opacity(0.08), in: Capsule())
                        }
                        .buttonStyle(.pressable)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .sensoryFeedback(.selection, trigger: playbackRate)
            } else {
                HStack(spacing: 10) {
                    Button { showCamera = true } label: { AttachmentTile(title: "Natočiť", icon: "record.circle") }
                        .buttonStyle(.pressable)
                    Button { showMediaPicker = true } label: { AttachmentTile(title: "Z Fotiek", icon: "photo.on.rectangle") }
                        .buttonStyle(.pressable)
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            DanceCameraView(savesToPhotos: true) { localPath in
                videoPath = localPath
                showCamera = false
                onChange()
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showMediaPicker) {
            UniversalMediaPickerSheet(
                slotTitle: "Video",
                currentPath: videoPath,
                onSelectMedia: { path in
                    videoPath = path
                    onChange()
                },
                onClearMedia: {}
            )
        }
        .confirmationDialog("Odstrániť video?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Odstrániť video", role: .destructive) {
                MediaStorageManager.removeFile(named: videoPath)   // a Fotky video stays in Fotky
                videoPath = nil
                onChange()
            }
        } message: {
            Text(videoPath.map(PhotoLibraryVideoStore.isReference) == true
                 ? "Video sa odstráni odtiaľto. Vo Fotkách ti ostane."
                 : "Video sa zmaže odtiaľto aj z telefónu.")
        }
    }

    private static func speedText(_ speed: Float) -> String {
        Double(speed).formatted(.number.precision(.fractionLength(0...2)).locale(Locale(identifier: "sk_SK"))) + "×"
    }
}

// MARK: - Photo attached to a figure or a dance
struct AttachedPhotoSection: View {
    @Binding var imagePath: String?
    /// File name prefix in the app's documents, e.g. "fig_img".
    let filePrefix: String
    var onChange: () -> Void

    @State private var selectedItem: PhotosPickerItem?
    @State private var confirmDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HomeSectionHeader(title: "FOTKA", systemImage: "photo") {
                if imagePath != nil {
                    Button { confirmDelete = true } label: {
                        Label("Odstrániť", systemImage: "trash")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(Color.latinRed)
                    }
                    .buttonStyle(.pressable)
                }
            }

            if let imagePath, let image = MediaResolver.resolveImage(path: imagePath) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .transition(.scale(scale: 0.97).combined(with: .opacity))
            } else {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    AttachmentTile(title: "Vybrať fotku", icon: "photo.badge.plus")
                }
                .buttonStyle(.pressable)
            }
        }
        .onChange(of: selectedItem) { _, item in
            guard let item else { return }
            Task { await store(item) }
        }
        .confirmationDialog("Odstrániť fotku?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Odstrániť fotku", role: .destructive) {
                MediaStorageManager.removeFile(named: imagePath)
                imagePath = nil
                onChange()
            }
        }
    }

    private func store(_ item: PhotosPickerItem) async {
        defer { selectedItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let filename = try? MediaStorageManager.store(data: data, prefix: filePrefix, fileExtension: "jpg") else { return }
        MediaStorageManager.removeFile(named: imagePath)
        imagePath = filename
        onChange()
    }
}

/// Dashed gold tile that invites adding something.
struct AttachmentTile: View {
    let title: String
    let icon: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.subheadline.weight(.bold))
            .foregroundColor(Color.gold400)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.gold400.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            )
    }
}
