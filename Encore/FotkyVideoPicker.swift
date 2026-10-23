import PhotosUI
import SwiftData
import SwiftUI

// MARK: - A video from Fotky into Denník
/// Picks a video in Fotky and puts it into Denník like a recorded clip: it stays in Fotky, Denník keeps a link.
/// Used in Denník and in a figure's "Z denníka", where the video can be placed in the notes right away.
struct FotkyVideoPicker<Label: View>: View {
    var danceName: String? = nil
    let onImported: (InstantNote) -> Void
    @ViewBuilder let label: (_ isImporting: Bool) -> Label

    @Environment(\.modelContext) private var modelContext
    @State private var item: PhotosPickerItem?
    @State private var isImporting = false
    @State private var failed = false

    var body: some View {
        PhotosPicker(selection: $item, matching: .videos, photoLibrary: .shared()) {
            label(isImporting)
        }
        .disabled(isImporting)
        .onChange(of: item) { _, picked in importVideo(picked) }
        .alert("Video sa nepodarilo pridať", isPresented: $failed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Skús ho vybrať znova.")
        }
    }

    private func importVideo(_ picked: PhotosPickerItem?) {
        guard let picked else { return }
        item = nil
        isImporting = true
        Task {
            defer { isImporting = false }
            guard let path = await PhotosImport.storedPath(for: picked) else {
                failed = true
                return
            }
            let note = InstantNote(videoPath: path, danceName: danceName)
            modelContext.insert(note)
            try? modelContext.save()
            onImported(note)
        }
    }
}
