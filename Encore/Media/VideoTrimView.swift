import SwiftUI
import AVFoundation
import AVKit
import OSLog

// MARK: - VideoTrimView
struct VideoTrimView: View {
    @Environment(\.dismiss) private var dismiss
    
    let originalVideoURL: URL
    let onTrimCompleted: (URL) -> Void
    
    @State private var player: AVPlayer?
    @State private var totalDuration: Double = 0.0
    @State private var startTime: Double = 0.0
    @State private var endTime: Double = 1.0
    @State private var currentTime: Double = 0.0
    @State private var isPlaying: Bool = false
    @State private var thumbnails: [UIImage] = []
    @State private var isExporting: Bool = false
    @State private var exportErrorMessage: String? = nil
    
    @State private var timeObserverToken: Any?
    
    var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()
                
                VStack(spacing: 16) {
                    // Video Preview Player
                    ZStack {
                        if let player = player {
                            VideoTrimPlayerRepresentable(player: player)
                                .aspectRatio(16/9, contentMode: .fit)
                                .cornerRadius(16)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.15), lineWidth: 1))
                                .shadow(color: Color.black.opacity(0.6), radius: 12, y: 4)
                        } else {
                            Rectangle()
                                .fill(Color.obsidian800)
                                .aspectRatio(16/9, contentMode: .fit)
                                .cornerRadius(16)
                                .overlay(ProgressView().tint(Color.gold400))
                        }
                        
                        // Play / Pause Overlay Button
                        Button {
                            togglePlay()
                        } label: {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 52))
                                .foregroundColor(Color.gold400.opacity(0.9))
                                .shadow(radius: 8)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    
                    // Time Range Indicator
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("ZAČIATOK")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(Color.textSecondary)
                            Text(formatTime(startTime))
                                .font(.system(size: 14, weight: .heavy, design: .monospaced))
                                .foregroundColor(Color.gold400)
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 2) {
                            Text("DĹŽKA VÝBERU")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(Color.textSecondary)
                            Text(formatTime(max(0, endTime - startTime)))
                                .font(.system(size: 14, weight: .black, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("KONIEC")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(Color.textSecondary)
                            Text(formatTime(endTime))
                                .font(.system(size: 14, weight: .heavy, design: .monospaced))
                                .foregroundColor(Color.gold400)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Timeline Scrubber with Thumbnails & Handles
                    timelineTrimmerView
                        .padding(.horizontal, 16)
                    
                    Spacer()
                    
                    if let err = exportErrorMessage {
                        Text(err)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.red)
                            .padding(.horizontal, 16)
                    }
                    
                    // Bottom Action Bar
                    HStack(spacing: 12) {
                        Button("Zrušiť") {
                            dismiss()
                        }
                        .disabled(isExporting)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 24)
                        .background(Color.white.opacity(0.12), in: Capsule())
                        
                        Button {
                            exportTrimmedVideo()
                        } label: {
                            HStack(spacing: 8) {
                                if isExporting {
                                    InfinityLoopView(width: 40, color: Color.obsidian900, period: 1.4, glow: false)
                                } else {
                                    Image(systemName: "scissors")
                                    Text("Použiť orezané video")
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 50)
                        }
                        .buttonStyle(.encorePrimary(dimsWhenDisabled: false))
                        // The loader stays bright while it exports; a clip that is too short only dims the button.
                        .opacity(isExporting || (endTime - startTime) >= 0.2 ? 1 : 0.4)
                        .disabled(isExporting || (endTime - startTime) < 0.2)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle("Orezanie videa")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Zavrieť") { dismiss() }
                        .foregroundColor(Color.gold400)
                        .disabled(isExporting)
                }
            }
        }
        // Closed during the export, it would still hand the trimmed file over and replace the take.
        .interactiveDismissDisabled(isExporting)
        .onAppear {
            setupTrimmer()
        }
        .onDisappear {
            cleanUp()
        }
    }
    
    // MARK: - Timeline Trimmer View with Thumbnails
    private var timelineTrimmerView: some View {
        GeometryReader { geo in
            let totalW = geo.size.width
            
            ZStack(alignment: .leading) {
                // 1. Filmstrip Thumbnails
                HStack(spacing: 0) {
                    if thumbnails.isEmpty {
                        Rectangle()
                            .fill(Color.obsidian800)
                            .frame(height: 54)
                    } else {
                        ForEach(0..<thumbnails.count, id: \.self) { idx in
                            Image(uiImage: thumbnails[idx])
                                .resizable()
                                .scaledToFill()
                                .frame(width: totalW / CGFloat(thumbnails.count), height: 54)
                                .clipped()
                        }
                    }
                }
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
                )
                
                // 2. Dimmed regions outside the trimmed range
                if totalDuration > 0 {
                    let leftW = (startTime / totalDuration) * totalW
                    let rightW = ((totalDuration - endTime) / totalDuration) * totalW
                    
                    // Left Dimmer
                    Rectangle()
                        .fill(Color.black.opacity(0.65))
                        .frame(width: max(0, leftW), height: 54)
                    
                    // Right Dimmer
                    Rectangle()
                        .fill(Color.black.opacity(0.65))
                        .frame(width: max(0, rightW), height: 54)
                        .offset(x: totalW - rightW)
                    
                    // Trim Active Box Border
                    Rectangle()
                        .stroke(Color.gold400, lineWidth: 2.5)
                        .frame(width: max(10, ((endTime - startTime) / totalDuration) * totalW), height: 54)
                        .offset(x: leftW)
                    
                    // Current Playback Scrubber Line
                    let playHeadX = (currentTime / totalDuration) * totalW
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 3, height: 60)
                        .offset(x: max(0, min(playHeadX, totalW - 3)))
                        .shadow(radius: 2)
                }
                
                // 3. Left / Right Draggable Handles
                if totalDuration > 0 {
                    let leftX = (startTime / totalDuration) * totalW
                    let rightX = (endTime / totalDuration) * totalW
                    
                    // Left Handle
                    Circle()
                        .fill(Color.gold400)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Image(systemName: "chevron.left")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(Color.obsidian900)
                        )
                        .offset(x: max(0, leftX - 11), y: 0)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let newRatio = value.location.x / totalW
                                    let newStart = max(0, min(newRatio * totalDuration, endTime - 0.3))
                                    startTime = newStart
                                    seek(to: startTime)
                                }
                        )
                    
                    // Right Handle
                    Circle()
                        .fill(Color.gold400)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(Color.obsidian900)
                        )
                        .offset(x: min(totalW - 22, rightX - 11), y: 0)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let newRatio = value.location.x / totalW
                                    let newEnd = min(totalDuration, max(newRatio * totalDuration, startTime + 0.3))
                                    endTime = newEnd
                                    seek(to: endTime)
                                }
                        )
                }
            }
        }
        .frame(height: 60)
    }
    
    // MARK: - Setup & Thumbnail Generation
    private func setupTrimmer() {
        let asset = AVURLAsset(url: originalVideoURL)
        let item = AVPlayerItem(asset: asset)
        let p = AVPlayer(playerItem: item)
        self.player = p
        
        Task {
            if let dur = try? await asset.load(.duration) {
                let seconds = CMTimeGetSeconds(dur)
                await MainActor.run {
                    self.totalDuration = seconds
                    self.startTime = 0.0
                    self.endTime = seconds
                    self.currentTime = 0.0
                }
                generateThumbnails(for: asset, duration: seconds)
            }
        }
        
        let interval = CMTime(seconds: 0.05, preferredTimescale: 600)
        timeObserverToken = p.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak p] time in
            let current = CMTimeGetSeconds(time)
            self.currentTime = current
            // Back to the start only while playing: dragging the right handle seeks to the end, and the end frame must stay.
            if current >= self.endTime && self.isPlaying {
                p?.seek(to: CMTime(seconds: self.startTime, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
            }
        }
    }
    
    private func generateThumbnails(for asset: AVAsset, duration: Double) {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 120, height: 120)
        
        let count = 8
        var times: [CMTime] = []
        for i in 0..<count {
            let timeSec = (duration / Double(count)) * Double(i)
            times.append(CMTime(seconds: timeSec, preferredTimescale: 600))
        }
        
        Task {
            var generated: [UIImage] = []
            for t in times {
                if let result = try? await generator.image(at: t) {
                    generated.append(UIImage(cgImage: result.image))
                }
            }
            await MainActor.run {
                self.thumbnails = generated
            }
        }
    }
    
    // MARK: - Playback Helpers
    private func togglePlay() {
        guard let p = player else { return }
        if isPlaying {
            p.pause()
            isPlaying = false
        } else {
            if currentTime >= endTime {
                seek(to: startTime)
            }
            p.play()
            isPlaying = true
        }
    }
    
    private func seek(to seconds: Double) {
        player?.seek(to: CMTime(seconds: seconds, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    private func cleanUp() {
        player?.pause()
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        player = nil
    }
    
    // MARK: - Export Trimmed Video
    private func exportTrimmedVideo() {
        isExporting = true
        exportErrorMessage = nil
        player?.pause()
        isPlaying = false
        
        let asset = AVURLAsset(url: originalVideoURL)
        let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality)
        
        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("trimmed_\(UUID().uuidString).mp4")
        exportSession?.outputURL = outputURL
        exportSession?.outputFileType = .mp4
        
        let startCM = CMTime(seconds: startTime, preferredTimescale: 600)
        let durationCM = CMTime(seconds: max(0.1, endTime - startTime), preferredTimescale: 600)
        exportSession?.timeRange = CMTimeRange(start: startCM, duration: durationCM)
        
        guard let session = exportSession else {
            self.isExporting = false
            self.exportErrorMessage = "Nepodarilo sa vytvoriť exportnú reláciu."
            return
        }
        
        Task {
            // Only a finished export replaces the take. A failed one (a full disk) may leave half a file, which is not a video.
            var isExported = false
            do {
                try await session.export(to: outputURL, as: .mp4)
                isExported = true
            } catch {
                Logger.camera.error("Video trim export failed: \(error.localizedDescription, privacy: .public)")
                try? FileManager.default.removeItem(at: outputURL)
            }

            await MainActor.run {
                self.isExporting = false
                if isExported {
                    self.onTrimCompleted(outputURL)
                    self.dismiss()
                } else {
                    self.exportErrorMessage = "Nepodarilo sa vytvoriť orezané video. Pôvodné ostalo, ako bolo."
                }
            }
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        let ms = Int((seconds.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", m, s, ms)
    }
}

// MARK: - VideoTrimPlayerRepresentable
struct VideoTrimPlayerRepresentable: UIViewControllerRepresentable {
    let player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        // The whole picture: a take filmed upright keeps its head and feet (the frame is 16:9, bars fill the rest).
        controller.videoGravity = .resizeAspect
        controller.view.backgroundColor = .black
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}
