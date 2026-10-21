import Foundation
import UIKit
import ImageIO
import AVFoundation
import CoreGraphics
import SwiftUI

public struct MediaResolver {
    // In-memory hardware thumbnail cache (max 150 items, 50MB budget)
    private static let imageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 150
        cache.totalCostLimit = 50 * 1024 * 1024
        return cache
    }()
    
    /// Vráti cestu k lokálnemu adresáru dokumentov aplikácie
    public static func getDocumentsDirectory() -> URL {
        MediaStorageManager.documentsDirectory
    }
    
    /// Overí, či cesta reprezentuje obrázok (podľa prípony)
    public static func isImagePath(path: String) -> Bool {
        let ext = (path as NSString).pathExtension.lowercased()
        return ["jpg", "jpeg", "png", "heic", "heif", "webp", "gif"].contains(ext)
    }
    
    /// Any video path, also a video in Fotky (`photos:`) or a shared copy (`r2:`), looked up asynchronously.
    /// Players use this one; `resolveVideoURL` covers only files stored in the app.
    public static func videoURL(path: String) async -> URL? {
        if PhotoLibraryVideoStore.isReference(path) {
            return await PhotoLibraryVideoStore.playableURL(for: path)
        }
        if SharedVideoStore.isReference(path) {
            return await SharedVideoStore.localURL(for: path)
        }
        return resolveVideoURL(path: path)
    }

    /// A video file stored in the app, or nil when it is not on this iPhone. There is no online fallback:
    /// the storage bucket is private, and videos from other people arrive as shared copies (`r2:`).
    public static func resolveVideoURL(path: String) -> URL? {
        guard !PhotoLibraryVideoStore.isReference(path), !SharedVideoStore.isReference(path),
              MediaStorageManager.fileExists(path) else { return nil }
        return MediaStorageManager.url(for: path)
    }
    
    /// Získa náhľad pre video alebo fotku z pamäťovej keše (alebo okamžite dekóduje statický obrázok)
    @MainActor
    public static func resolveThumbnail(path: String, maxPixelSize: CGFloat = 400) -> UIImage? {
        let cacheKey = "thumb_\(path)_\(Int(maxPixelSize))" as NSString
        if let cached = imageCache.object(forKey: cacheKey) {
            return cached
        }
        
        if isImagePath(path: path) {
            if let img = resolveImage(path: path, maxPixelSize: maxPixelSize) {
                imageCache.setObject(img, forKey: cacheKey)
                return img
            }
        }
        return nil
    }
    
    /// Asynchrónne získa náhľad pre video alebo fotku (cez moderné AVAssetImageGenerator API bez blokovania UI)
    @MainActor
    public static func resolveThumbnailAsync(path: String, maxPixelSize: CGFloat = 400) async -> UIImage? {
        let cacheKey = "thumb_\(path)_\(Int(maxPixelSize))" as NSString
        if let cached = imageCache.object(forKey: cacheKey) {
            return cached
        }
        
        if isImagePath(path: path) {
            if let img = resolveImage(path: path, maxPixelSize: maxPixelSize) {
                imageCache.setObject(img, forKey: cacheKey)
                return img
            }
            return nil
        }
        
        // Fotky keep their own thumbnails; no need to download a video from iCloud for one frame.
        if PhotoLibraryVideoStore.isReference(path) {
            let thumb = await PhotoLibraryVideoStore.thumbnail(for: path, maxPixelSize: maxPixelSize)
            if let thumb { imageCache.setObject(thumb, forKey: cacheKey) }
            return thumb
        }

        // Extrakcia náhľadu z videa cez moderné AVAssetImageGenerator API
        guard let videoURL = resolveVideoURL(path: path) else { return nil }
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxPixelSize, height: maxPixelSize)
        
        let time = CMTime(seconds: 0.1, preferredTimescale: 600)
        do {
            let (cgImage, _) = try await generator.image(at: time)
            let thumb = UIImage(cgImage: cgImage)
            imageCache.setObject(thumb, forKey: cacheKey)
            return thumb
        } catch {
            return nil
        }
    }
    
    /// Hardvérovo akcelerovaný dekóder obrázkov (CGImageSource / ImageIO bez preťaženia RAM)
    @MainActor
    public static func resolveImage(path: String, maxPixelSize: CGFloat = 1200) -> UIImage? {
        let cacheKey = "\(path)_\(Int(maxPixelSize))" as NSString
        if let cached = imageCache.object(forKey: cacheKey) {
            return cached
        }
        
        let localURL = MediaStorageManager.url(for: path)
        guard MediaStorageManager.fileExists(path) else { return nil }
        
        // Hardvérové dekódovanie priamo z disku do požadovaného rozlíšenia
        guard let source = CGImageSourceCreateWithURL(localURL as CFURL, nil) else {
            return nil
        }
        
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        
        let image = UIImage(cgImage: cgImage)
        let memoryCost = cgImage.bytesPerRow * cgImage.height
        imageCache.setObject(image, forKey: cacheKey, cost: memoryCost)
        return image
    }
}

// MARK: - Reusable Media Thumbnail View
public struct MediaThumbnailView: View {
    public let path: String?
    public var placeholderIcon: String
    public var cornerRadius: CGFloat
    /// The small video / photo mark in the corner; off where the picture is too small for it.
    public var showsFormatBadge: Bool
    
    @State private var thumbnail: UIImage? = nil
    
    public init(path: String?, placeholderIcon: String = "film", cornerRadius: CGFloat = 10, showsFormatBadge: Bool = true) {
        self.path = path
        self.placeholderIcon = placeholderIcon
        self.cornerRadius = cornerRadius
        self.showsFormatBadge = showsFormatBadge
    }
    
    public init(filePath: String?, placeholderIcon: String = "film", cornerRadius: CGFloat = 10) {
        self.path = filePath
        self.placeholderIcon = placeholderIcon
        self.cornerRadius = cornerRadius
        self.showsFormatBadge = true
    }
    
    public var body: some View {
        // The container decides the size; the picture only fills it. Otherwise a large photo would
        // size the view itself and spill over its neighbours in a grid.
        Color.obsidian800
            .overlay {
                if let thumb = thumbnail {
                    Image(uiImage: thumb)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: placeholderIcon)
                        .font(.title2)
                        .foregroundColor(Color.white.opacity(0.4))
                }
            }
            .overlay(alignment: .bottomTrailing) {
                // Format icon indicator (Video vs Photo)
                if showsFormatBadge, let path = path, !path.isEmpty {
                    Image(systemName: MediaResolver.isImagePath(path: path) ? "photo.fill" : "play.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Color.black.opacity(0.65), in: Circle())
                        .padding(6)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .onAppear {
            loadThumb()
        }
        .onChange(of: path) { _, _ in
            loadThumb()
        }
    }
    
    private func loadThumb() {
        guard let path = path, !path.isEmpty else {
            thumbnail = nil
            return
        }
        if let cached = MediaResolver.resolveThumbnail(path: path) {
            self.thumbnail = cached
            return
        }
        Task {
            let thumb = await MediaResolver.resolveThumbnailAsync(path: path)
            self.thumbnail = thumb
        }
    }
}

