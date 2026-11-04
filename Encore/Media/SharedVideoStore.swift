import Foundation
import AVFoundation
import Supabase
import OSLog

// MARK: - Videos shared with partner and coach (Cloudflare R2)
/// The owner's original stays in Fotky. Sharing makes a 720p copy, uploads it through the `media-share`
/// Edge Function straight to R2 and stores `r2:<key>` as the figure's `sharedVideoPath`.
/// Whoever watches downloads the copy once into Caches; the server checks who may watch.
enum SharedVideoStore {
    nonisolated static let referencePrefix = "r2:"

    nonisolated static func isReference(_ path: String) -> Bool { path.hasPrefix(referencePrefix) }

    /// Only shared copies may go to the server; anything else works on one iPhone only.
    nonisolated static func serverValue(_ path: String?) -> String? {
        guard let path, isReference(path) else { return nil }
        return path
    }

    struct Usage: Sendable {
        let usedBytes: Int64
        let quotaBytes: Int64

        var text: String {
            let used = ByteCountFormatter.string(fromByteCount: usedBytes, countStyle: .file)
            let quota = ByteCountFormatter.string(fromByteCount: quotaBytes, countStyle: .file)
            return "\(used) z \(quota)"
        }
    }

    enum Stage: Sendable { case compressing, uploading }

    enum ShareError: LocalizedError {
        case noOriginal, compression, uploadFailed, server(String), network

        var errorDescription: String? {
            switch self {
            case .noOriginal: return "Video sa nenašlo. Pridaj ho znova a skús to ešte raz."
            case .compression: return "Video sa nepodarilo pripraviť na zdieľanie."
            case .uploadFailed: return "Nahrávanie sa prerušilo. Skontroluj pripojenie a skús to znova."
            case .server(let message): return message
            case .network: return "Bez pripojenia sa video nedá zdieľať. Skús to znova."
            }
        }
    }

    // MARK: Share and stop sharing

    /// Makes the 720p copy of the original, uploads it and returns the new shared path with the
    /// storage used. A previous copy of the same figure is deleted on the server.
    static func share(originalPath: String, nodeId: UUID, onStage: (Stage) -> Void) async throws -> (videoPath: String, usage: Usage) {
        guard let source = await MediaResolver.videoURL(path: originalPath) else { throw ShareError.noOriginal }

        onStage(.compressing)
        let copy: URL
        do {
            copy = try await ShareableVideoEncoder.encode(source)
        } catch {
            Logger.sync.error("Share copy failed: \(error.localizedDescription, privacy: .public)")
            throw ShareError.compression
        }
        defer { try? FileManager.default.removeItem(at: copy) }
        let size = (try? copy.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0

        onStage(.uploading)
        let ticket: UploadTicket = try await call(.init(action: "upload", nodeId: nodeId.uuidString.lowercased(), sizeBytes: size))
        var request = URLRequest(url: ticket.uploadUrl)
        request.httpMethod = "PUT"
        request.setValue("video/mp4", forHTTPHeaderField: "Content-Type")
        do {
            let (_, response) = try await URLSession.shared.upload(for: request, fromFile: copy)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw ShareError.uploadFailed }
        } catch let error as ShareError {
            throw error
        } catch {
            throw ShareError.uploadFailed
        }

        let confirmed: Confirmation = try await call(.init(action: "confirm", key: ticket.key))
        return (confirmed.videoPath, Usage(usedBytes: confirmed.usedBytes, quotaBytes: confirmed.quotaBytes))
    }

    /// Deletes the shared copy for everyone (partner and coach included).
    static func stopSharing(_ reference: String) async throws {
        let _: Removal = try await call(.init(action: "remove", key: key(of: reference)))
        evict(reference)
    }

    // MARK: Watching

    /// A local file for the shared copy: from the cache, or downloaded once when the viewer may watch it.
    static func localURL(for reference: String) async -> URL? {
        let file = cacheURL(for: reference)
        if FileManager.default.fileExists(atPath: file.path) { return file }
        do {
            let link: DownloadLink = try await call(.init(action: "download", key: key(of: reference)))
            let (temporary, response) = try await URLSession.shared.download(from: link.downloadUrl)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: file)
            try FileManager.default.moveItem(at: temporary, to: file)
            return file
        } catch {
            Logger.sync.notice("Shared video unavailable: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Drops the cached copy, for example when the owner replaced or stopped sharing it.
    nonisolated static func evict(_ reference: String?) {
        guard let reference, isReference(reference) else { return }
        try? FileManager.default.removeItem(at: cacheURL(for: reference))
    }

    // MARK: Private

    nonisolated private static func key(of reference: String) -> String { String(reference.dropFirst(referencePrefix.count)) }

    nonisolated private static var cacheDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("SharedVideos", isDirectory: true)
    }

    nonisolated private static func cacheURL(for reference: String) -> URL {
        cacheDirectory.appendingPathComponent(key(of: reference).replacingOccurrences(of: "/", with: "_"))
    }

    private struct Request: Encodable {
        let action: String
        var nodeId: String? = nil
        var sizeBytes: Int? = nil
        var key: String? = nil
    }

    private struct UploadTicket: Decodable { let key: String; let uploadUrl: URL }
    private struct Confirmation: Decodable { let videoPath: String; let usedBytes: Int64; let quotaBytes: Int64 }
    private struct DownloadLink: Decodable { let downloadUrl: URL }
    private struct Removal: Decodable { let ok: Bool }
    private static func call<T: Decodable>(_ request: Request) async throws -> T {
        do {
            return try await EdgeFunctionClient.call("media-share", request)
        } catch EdgeFunctionClient.Failure.server(_, let message) {
            throw ShareError.server(message ?? "Zdieľanie videa sa nepodarilo. Skús to znova.")
        } catch {
            throw ShareError.network
        }
    }
}

// MARK: - 720p copy for sharing
/// HEVC at about 2.5 Mbit/s with AAC sound: roughly 10 MB per 30 seconds instead of ~30 MB for the
/// 1080p original. Orientation and frame rate stay as recorded.
nonisolated enum ShareableVideoEncoder {
    enum Failure: Error { case noVideoTrack, cannotStart, failed }

    @concurrent
    static func encode(_ source: URL) async throws -> URL {
        let asset = AVURLAsset(url: source)
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else { throw Failure.noVideoTrack }
        let (naturalSize, transform) = try await videoTrack.load(.naturalSize, .preferredTransform)
        let audioTrack = try await asset.loadTracks(withMediaType: .audio).first
        let audioFormat = try await audioTrack?.load(.formatDescriptions).first

        // Longest side 1280 px (never upscaled), even numbers for the encoder.
        let scale = min(1, 1280 / max(naturalSize.width, naturalSize.height, 1))
        let width = Int((naturalSize.width * scale / 2).rounded()) * 2
        let height = Int((naturalSize.height * scale / 2).rounded()) * 2

        let output = FileManager.default.temporaryDirectory.appendingPathComponent("share-\(UUID().uuidString).mp4")
        let reader = try AVAssetReader(asset: asset)
        let writer = try AVAssetWriter(outputURL: output, fileType: .mp4)
        writer.shouldOptimizeForNetworkUse = true

        let videoOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        ])
        videoOutput.alwaysCopiesSampleData = false
        reader.add(videoOutput)
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 2_500_000]
        ])
        videoInput.transform = transform
        videoInput.expectsMediaDataInRealTime = false
        writer.add(videoInput)

        var pairs: [(AVAssetReaderTrackOutput, AVAssetWriterInput)] = [(videoOutput, videoInput)]
        if let audioTrack {
            let source = audioFormat.flatMap { CMAudioFormatDescriptionGetStreamBasicDescription($0)?.pointee }
            let channels = min(max(Int(source?.mChannelsPerFrame ?? 1), 1), 2)
            let sampleRate = source.map { $0.mSampleRate > 0 ? $0.mSampleRate : 44_100 } ?? 44_100
            let audioOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM])
            reader.add(audioOutput)
            let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVNumberOfChannelsKey: channels,
                AVSampleRateKey: sampleRate,
                AVEncoderBitRateKey: channels == 1 ? 64_000 : 96_000
            ])
            audioInput.expectsMediaDataInRealTime = false
            writer.add(audioInput)
            pairs.append((audioOutput, audioInput))
        }

        guard reader.startReading(), writer.startWriting() else {
            try? FileManager.default.removeItem(at: output)
            throw Failure.cannotStart
        }
        writer.startSession(atSourceTime: .zero)

        // Video and sound are fed at the same time: the writer interleaves them and would stall otherwise.
        await withCheckedContinuation { (finished: CheckedContinuation<Void, Never>) in
            let group = DispatchGroup()
            for (index, pair) in pairs.enumerated() {
                // From here on each pair is touched only on its own serial queue.
                nonisolated(unsafe) let trackOutput = pair.0
                nonisolated(unsafe) let input = pair.1
                group.enter()
                input.requestMediaDataWhenReady(on: DispatchQueue(label: "encore.share-copy.\(index)")) {
                    while input.isReadyForMoreMediaData {
                        guard let buffer = trackOutput.copyNextSampleBuffer(), input.append(buffer) else {
                            input.markAsFinished()
                            group.leave()
                            return
                        }
                    }
                }
            }
            group.notify(queue: .global(qos: .userInitiated)) { finished.resume() }
        }

        if reader.status == .failed {
            writer.cancelWriting()
            try? FileManager.default.removeItem(at: output)
            throw reader.error ?? Failure.failed
        }
        await writer.finishWriting()
        guard writer.status == .completed else {
            try? FileManager.default.removeItem(at: output)
            throw writer.error ?? Failure.failed
        }
        return output
    }
}
