import Photos
import AVFoundation
import UIKit
import os

// MARK: - Training videos in the user's Fotky
/// Videos recorded in Encore are moved into Fotky (album "Encore"). The app keeps only a reference,
/// `photos:<localIdentifier>`, in the same `videoPath` fields as before: one video, no copy, and it is
/// backed up with the user's iCloud Photos. Without access to Fotky the caller keeps the file in the app.
///
/// A reference works only on this iPhone. Sharing with a partner or coach uploads a copy to Supabase.
nonisolated enum PhotoLibraryVideoStore {
    static let referencePrefix = "photos:"
    private static let albumTitle = "Encore"

    enum SaveError: Error { case noAsset }

    static func isReference(_ path: String) -> Bool { path.hasPrefix(referencePrefix) }

    /// Read and write access. Videos Encore created stay visible even when the user allows only selected photos.
    static var hasAccess: Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return status == .authorized || status == .limited
    }

    /// Asks once; later calls return the saved answer.
    static func requestAccess() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return status == .authorized || status == .limited
    }

    /// Moves the recorded file into the "Encore" album and returns the reference to store.
    static func save(videoAt url: URL) async throws -> String {
        try await createInEncoreAlbum { request in
            let options = PHAssetResourceCreationOptions()
            options.shouldMoveFile = true   // the temporary recording is consumed, nothing stays in the app
            request.addResource(with: .video, fileURL: url, options: options)
        }
    }

    /// Saves a still, such as a correction snapshot with its helper lines, into the "Encore" album.
    static func save(imageData: Data) async throws {
        _ = try await createInEncoreAlbum { request in
            request.addResource(with: .photo, data: imageData, options: nil)
        }
    }

    private static func createInEncoreAlbum(_ addResource: @escaping @Sendable (PHAssetCreationRequest) -> Void) async throws -> String {
        let created = OSAllocatedUnfairLock<String?>(initialState: nil)
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            addResource(request)
            guard let placeholder = request.placeholderForCreatedAsset else { return }
            created.withLock { $0 = placeholder.localIdentifier }

            let assets = [placeholder] as NSArray
            if let album = encoreAlbum() {
                PHAssetCollectionChangeRequest(for: album)?.addAssets(assets)
            } else {
                PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumTitle).addAssets(assets)
            }
        }
        guard let identifier = created.withLock({ $0 }) else { throw SaveError.noAsset }
        return referencePrefix + identifier
    }

    /// A file URL the players can open. nil when the video was deleted from Fotky or access was taken away.
    /// With iCloud "Optimalizovať úložisko" the full video is downloaded first.
    @concurrent
    static func playableURL(for reference: String) async -> URL? {
        guard let asset = asset(for: reference) else { return nil }
        if let url = await fileURL(of: asset, version: .current) { return url }
        // A slow-motion edit comes back as a composition without a file; the original always has one.
        return await fileURL(of: asset, version: .original)
    }

    @concurrent
    static func thumbnail(for reference: String, maxPixelSize: CGFloat) async -> UIImage? {
        guard let asset = asset(for: reference) else { return nil }
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat   // one callback, no blurry first image
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        let size = CGSize(width: maxPixelSize, height: maxPixelSize)
        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: options) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    /// When the video was filmed, for a `photos:` reference (nil for app files or a missing asset).
    static func creationDate(of path: String) -> Date? {
        guard isReference(path), hasAccess else { return nil }
        return asset(for: path)?.creationDate
    }

    // MARK: Private
    private static func asset(for reference: String) -> PHAsset? {
        let identifier = String(reference.dropFirst(referencePrefix.count))
        return PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject
    }

    private static func fileURL(of asset: PHAsset, version: PHVideoRequestOptionsVersion) async -> URL? {
        let options = PHVideoRequestOptions()
        options.version = version
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                continuation.resume(returning: (avAsset as? AVURLAsset)?.url)
            }
        }
    }

    private static func encoreAlbum() -> PHAssetCollection? {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "title = %@", albumTitle)
        return PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: options).firstObject
    }
}
