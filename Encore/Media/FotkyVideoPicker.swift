import PhotosUI
import SwiftData
import SwiftUI

// MARK: - A video or a photo from Fotky into Denník
/// Picks a video or a photo in Fotky and puts it into Denník like a recorded clip: a video stays in Fotky and Denník
/// keeps a link, a photo is copied. Used in Denník and in a figure's "Z denníka", where it can be placed in the
/// notes right away.
struct FotkyPicker<Label: View>: View {
    var danceName: String? = nil
    let onImported: (InstantNote) -> Void
    @ViewBuilder let label: (_ isImporting: Bool) -> Label

    @Environment(\.modelContext) private var modelContext
    @State private var item: PhotosPickerItem?
    @State private var isImporting = false
    @State private var failed = false

    var body: some View {
        PhotosPicker(selection: $item, matching: .any(of: [.videos, .images]), photoLibrary: .shared()) {
            label(isImporting)
        }
        .disabled(isImporting)
        .onChange(of: item) { _, picked in importMedia(picked) }
        .alert("Nepodarilo sa pridať", isPresented: $failed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Skús ho vybrať znova.")
        }
    }

    private func importMedia(_ picked: PhotosPickerItem?) {
        guard let picked else { return }
        item = nil
        isImporting = true
        Task {
            defer { isImporting = false }
            guard let path = await PhotosImport.storedPath(for: picked) else {
                failed = true
                return
            }
            let isVideo = picked.supportedContentTypes.contains { $0.conforms(to: .movie) }
            let note = isVideo ? InstantNote(videoPath: path, danceName: danceName) : InstantNote(imagePath: path, danceName: danceName)
            modelContext.insert(note)
            try? modelContext.save()
            onImported(note)
        }
    }
}
