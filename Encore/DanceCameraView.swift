import SwiftUI
import SwiftData
import AVFoundation
import AVKit
import Combine
import CoreMotion
import AudioToolbox
import OSLog
#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
import ActivityKit
#endif



// MARK: - Samospúšť (Countdown Timer) Enum
enum CountdownDuration: Int, CaseIterable, Identifiable {
    case off = 0
    case threeSeconds = 3
    case fiveSeconds = 5
    case tenSeconds = 10
    
    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .off: return "Vypnuté"
        case .threeSeconds: return "3s"
        case .fiveSeconds: return "5s"
        case .tenSeconds: return "10s"
        }
    }
}

// MARK: - Zoom Factor Options
enum CameraZoomFactor: Double, CaseIterable, Identifiable {
    case wide = 0.5
    case standard = 1.0
    case telephoto = 2.0
    
    var id: Double { rawValue }
    
    var label: String {
        switch self {
        case .wide: return "0.5x"
        case .standard: return "1x"
        case .telephoto: return "2x"
        }
    }
}

// MARK: - DanceCameraView (Powered by DanceMetronomeEngine)
struct DanceCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // Callbacks
    var ghostVideoPath: String? = nil
    /// The finished clip goes into Fotky (album "Encore") and the callback gets a `photos:` reference.
    /// Without access to Fotky it stays in the app as before.
    var savesToPhotos = false
    /// The main button after a take: where the clip goes ("Uložiť do Denníka", "Uložiť k figúre").
    var saveTitle = "Uložiť video"
    var onRecordComplete: (String) -> Void
    
    // Camera Controller State
    @StateObject private var camera = DanceCameraManager()
    
    @State private var bookmarkToastText: String? = nil
    @State private var lastLiveActivityUpdate: Date = .distantPast
    @State private var lastReportedAudioLevel: Float = 0.0
    
    // UI Feature States (Funkcie 1 - 5)
    @State private var countdownDuration: CountdownDuration = .off
    @State private var countdownRemaining: Int = 0
    @State private var isCountingDown: Bool = false
    @State private var countdownTimer: Timer? = nil
    
    @State private var showGridAndLevel: Bool = true
    @State private var selectedZoom: CameraZoomFactor = .standard
    @State private var isFrontMirrorMode: Bool = false
    
    // Ghost / Onion Skinning State (Funkcia 4)
    @State private var showGhostOverlay: Bool = false
    @State private var ghostOpacity: Double = 0.45
    @State private var ghostPlayer: AVPlayer? = nil
    
    // Torch state
    @State private var isTorchOn: Bool = false
    
    // Metronome State (Funkcia 9 - Powered by DanceMetronomeEngine)
    @ObservedObject private var metronome = DanceMetronomeEngine.shared
    @State private var beatFlashOpacity: Double = 0.0
    
    // Post-Recording Quick Tag & Trim Modal (Funkcia 8 & 10)
    @State private var rawRecordedURL: URL? = nil
    @State private var showSaveDetailsSheet: Bool = false
    @State private var showTrimmerSheet: Bool = false
    @State private var showFullMetronomeSheet: Bool = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // 1. Live Camera Preview Viewport
            CameraPreviewRepresentable(session: camera.session)
                .ignoresSafeArea()
                .onTapGesture { location in
                    camera.focus(at: location)
                }
            
            // 2. Ghosting Video Overlay (Funkcia 4: Cibuľová koža / Onion Skinning)
            if showGhostOverlay, let player = ghostPlayer {
                GhostPlayerRepresentable(player: player)
                    .opacity(ghostOpacity)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            
            // 3. Gyroscope Level & 3x3 Composition Grid (Funkcia 1 & 2)
            if showGridAndLevel {
                CameraGridAndLevelOverlay(
                    tiltAngle: camera.deviceRollAngle,
                    isLevel: camera.isDeviceLevel,
                    isFlat: camera.isDeviceFlat,
                    flatOffset: camera.flatOffset
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
            
            // 4. Large Samospúšť Countdown Overlay
            if isCountingDown {
                Text("\(countdownRemaining)")
                    .font(.system(size: 110, weight: .heavy, design: .rounded))
                    .foregroundColor(Color.amberGold)
                    .shadow(color: .black.opacity(0.8), radius: 10, x: 0, y: 4)
                    .transition(.scale.combined(with: .opacity))
                    .id(countdownRemaining)
            }
            
            // 4b. Metronome downbeat flash overlay (subtle golden screen pulse)
            if beatFlashOpacity > 0 {
                Color.amberGold
                    .opacity(beatFlashOpacity)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .animation(.easeOut(duration: 0.12), value: beatFlashOpacity)
            }
            
            // 5. Instant Memory Toast Banner
            if let toast = bookmarkToastText {
                VStack {
                    HStack(spacing: 8) {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color(red: 0.98, green: 0.88, blue: 0.20))
                        Text(toast)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Color.black.opacity(0.88))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color(red: 0.98, green: 0.88, blue: 0.20).opacity(0.5), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.6), radius: 10, x: 0, y: 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    
                    Spacer()
                }
                .padding(.top, 56)
                .zIndex(100)
            }
            
            // 6. Camera Controls Deck UI (Header + Ambient VU Meter + Lower Controls Deck)
            VStack(spacing: 0) {
                // Top Header Bar (Dismiss 'X' and Flash 'bolt' - clear from Dynamic Island)
                topHeaderBar
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                
                Spacer()
                
                // ── Lower Thumb Zone Deck (Ergonomic One-Handed Access) ──
                VStack(spacing: 8) {
                    // Metronome Live Measure & Beat Status Pill
                    if metronome.selectedPreset != .off {
                        metronomeStatusPill
                            .opacity(camera.isRecording ? 0.75 : 1.0)
                            .transition(.scale.combined(with: .opacity))
                    }
                    
                    // Action Control Strip (Metronome + Mriežka + Samospúšť + Ghost)
                    actionControlStrip
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
                
                // Ghost / Onion Skinning Opacity Slider
                if showGhostOverlay && ghostVideoPath != nil {
                    ghostControlsBar
                        .padding(.horizontal, 24)
                        .padding(.bottom, 6)
                }
                
                // Recording Status Pill
                if camera.isRecording {
                    recordingStatusPill
                        .padding(.bottom, 8)
                }
                
                // Zoom Quick Switcher (Funkcia 3: 0.5x, 1x, 2x)
                zoomSwitcherBar
                    .padding(.bottom, 12)
                
                // Bottom Camera Shutter Deck
                bottomControlsDeck
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)
            }
        }
        .statusBarHidden()
        .onReceive(NotificationCenter.default.publisher(for: .stopRecordingFromLiveActivity)) { _ in
            stopRecordingFromLiveActivity()
        }
        .onReceive(NotificationCenter.default.publisher(for: .bookmarkRecordingFromLiveActivity)) { _ in
            saveInstantMemoryBookmark()
        }
        .onAppear {
            camera.start()
            
            // Setup Darwin notification listener for Lock Screen & Dynamic Island Bookmark / Stop intents
            let observer = Unmanaged.passUnretained(self as AnyObject).toOpaque()
            CFNotificationCenterAddObserver(
                CFNotificationCenterGetDarwinNotifyCenter(),
                observer,
                { _, _, name, _, _ in
                    guard let name = name?.rawValue as String? else { return }
                    if name == "com.encore.bookmark" {
                        NotificationCenter.default.post(name: .bookmarkRecordingFromLiveActivity, object: nil)
                    } else if name == "com.encore.stopRecording" {
                        NotificationCenter.default.post(name: .stopRecordingFromLiveActivity, object: nil)
                    }
                },
                nil,
                nil,
                .deliverImmediately
            )
        }
        .task(id: ghostVideoPath) {
            // The ghost video may live in Fotky, so it is looked up asynchronously; leaving cancels the task.
            guard let ghostPath = ghostVideoPath,
                  let url = await MediaResolver.videoURL(path: ghostPath),
                  !Task.isCancelled else { return }
            let item = AVPlayerItem(url: url)
            let player = AVPlayer(playerItem: item)
            player.actionAtItemEnd = .none
            NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { _ in
                player.seek(to: .zero)
                player.play()
            }
            self.ghostPlayer = player
        }
        .onDisappear {
            stopCountdown()
            stopMetronome()
            endRecordingLiveActivity()
            ghostPlayer?.pause()
            ghostPlayer = nil
            camera.stop()
        }
        .onChange(of: camera.recordedVideoURL) { _, newURL in
            if let url = newURL {
                rawRecordedURL = url
                showSaveDetailsSheet = true
            }
        }
        .onChange(of: metronome.selectedPreset) { _, _ in
            updateRecordingLiveActivity(force: true)
        }
        .onChange(of: metronome.tempoMultiplier) { _, _ in
            updateRecordingLiveActivity(force: true)
        }
        .onChange(of: metronome.isPulse) { _, pulsing in
            // Golden screen flash only on downbeat (beat 1) when metronome is active
            if pulsing && metronome.currentBeat == 1 && metronome.selectedPreset != .off {
                beatFlashOpacity = 0.13
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    withAnimation(.easeOut(duration: 0.18)) {
                        beatFlashOpacity = 0.0
                    }
                }
            }
        }
        // After a take: play, trim, save or discard
        .sheet(isPresented: $showSaveDetailsSheet) {
            if let url = rawRecordedURL {
                QuickSaveVideoSheet(
                    videoURL: url,
                    saveTitle: saveTitle,
                    savesToPhotos: savesToPhotos,
                    onTrimRequest: { showTrimmerSheet = true },
                    onSave: { await storeRecording(at: url) },
                    onDiscard: {
                        try? FileManager.default.removeItem(at: url)
                        rawRecordedURL = nil
                        showSaveDetailsSheet = false
                    }
                )
            }
        }
        .sheet(isPresented: $showTrimmerSheet) {
            if let url = rawRecordedURL {
                VideoTrimView(originalVideoURL: url) { trimmedURL in
                    rawRecordedURL = trimmedURL
                }
            }
        }
        .sheet(isPresented: $showFullMetronomeSheet) {
            DanceMetronomeView()
        }
    }
    
    // MARK: - Saving the clip
    private func storeRecording(at url: URL) async {
        if savesToPhotos, await PhotoLibraryVideoStore.requestAccess() {
            do {
                onRecordComplete(try await PhotoLibraryVideoStore.save(videoAt: url))
                dismiss()
                return
            } catch {
                Logger.camera.error("Saving to Fotky failed, keeping the clip in the app: \(error.localizedDescription, privacy: .public)")
            }
        }
        do {
            onRecordComplete(try MediaStorageManager.moveIntoDocuments(from: url, fileExtension: "mp4"))
            dismiss()
        } catch {
            Logger.camera.error("Saving the clip failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Top Header Bar (Safe from Dynamic Island)
    private var topHeaderBar: some View {
        HStack {
            // Dismiss Button (44pt HIG Target)
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
            }
            
            Spacer()
            
            // Flash / Torch Toggle Button
            Button {
                isTorchOn.toggle()
                camera.toggleTorch(on: isTorchOn)
                let gen = UIImpactFeedbackGenerator(style: .light)
                gen.impactOccurred()
            } label: {
                Image(systemName: isTorchOn ? "bolt.fill" : "bolt.slash.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(isTorchOn ? Color.amberGold : .white)
                    .frame(width: 42, height: 42)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(isTorchOn ? Color.amberGold : Color.white.opacity(0.18), lineWidth: 1))
            }
        }
    }
    
    private var recordingStatusPill: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
            
            Text(formatDuration(camera.recordingDuration))
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .foregroundColor(.white)
            
            if metronome.selectedPreset != .off {
                Divider()
                    .frame(height: 14)
                    .overlay(Color.white.opacity(0.25))
                
                beatIndicator
                
                Text("\(metronome.effectiveBpm) BPM")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(metronome.currentBeat == 1 ? Color.amberGold : .white)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.68))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.red.opacity(0.55), lineWidth: 1))
    }
    
    private var metronomeStatusPill: some View {
        HStack(spacing: 7) {
            beatIndicator
            
            Text("\(metronome.selectedPreset.shortCode) • \(metronome.effectiveBpm) BPM • Doba \(metronome.currentBeat)/\(metronome.beatsPerMeasure)")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(metronome.currentBeat == 1 ? Color.amberGold : .white)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.65))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(metronome.currentBeat == 1 ? Color.amberGold.opacity(0.6) : Color.white.opacity(0.18), lineWidth: 1))
    }
    
    private var beatIndicator: some View {
        Circle()
            .fill(metronome.currentBeat == 1 ? Color.amberGold : Color.white)
            .frame(width: metronome.isPulse ? 10 : 7, height: metronome.isPulse ? 10 : 7)
            .shadow(color: metronome.currentBeat == 1 ? Color.amberGold : Color.clear, radius: metronome.isPulse ? 6 : 0)
    }
    
    // MARK: - Action Control Strip (Always Accessible Below Dynamic Island - Waze Style)
    private var actionControlStrip: some View {
        HStack(spacing: 8) {
            // Metronome Menu with Tempo Adjuster & BPM Trainer Sheet
            Menu {
                Section {
                    Button {
                        showFullMetronomeSheet = true
                    } label: {
                        Label("🎛️ Otvoriť BPM Tréner & Zvuky", systemImage: "slider.vertical.3")
                    }
                }
                
                Section("Tanečné štýly") {
                    ForEach(DanceMetronomePreset.allCases) { preset in
                        Button {
                            if preset == .off {
                                metronome.stop()
                                metronome.selectedPreset = .off
                            } else {
                                metronome.start(preset: preset)
                            }
                        } label: {
                            HStack {
                                Text(preset.rawValue)
                                if metronome.selectedPreset == preset {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
                
                if metronome.selectedPreset != .off {
                    Section("Tempo: \(metronome.effectiveBpm) BPM (\(metronome.effectiveMpm) MPM)") {
                        Button("Svižnejšie (+5%)") {
                            let newMult = min(1.3, metronome.tempoMultiplier + 0.05)
                            metronome.start(multiplier: newMult)
                        }
                        Button("Pomalšie (-5%)") {
                            let newMult = max(0.7, metronome.tempoMultiplier - 0.05)
                            metronome.start(multiplier: newMult)
                        }
                        Button("Pôvodné tempo (100%)") {
                            metronome.start(multiplier: 1.0)
                        }
                        Button("Vypnúť metronóm", role: .destructive) {
                            metronome.stop()
                            metronome.selectedPreset = .off
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    if metronome.selectedPreset != .off {
                        beatIndicator
                        Text("\(metronome.selectedPreset.shortCode) • \(metronome.effectiveBpm)")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                    } else {
                        Image(systemName: "metronome.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("Metronóm")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .black))
                        .opacity(0.65)
                }
                .foregroundColor(metronome.selectedPreset != .off ? Color.amberGold : .white)
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background(
                    metronome.selectedPreset != .off
                        ? Color.amberGold.opacity(0.24)
                        : Color.black.opacity(0.68)
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            metronome.selectedPreset != .off
                                ? (metronome.currentBeat == 1 ? Color.amberGold : Color.amberGold.opacity(0.55))
                                : Color.white.opacity(0.22),
                            lineWidth: metronome.selectedPreset != .off ? 1.5 : 1
                        )
                )
                .shadow(color: metronome.selectedPreset != .off ? Color.amberGold.opacity(0.35) : Color.black.opacity(0.4), radius: 6, y: 2)
            }
            
            // Grid & Horizon Level Button (Funkcia 2 - Waze-style Pill)
            Button {
                showGridAndLevel.toggle()
                let gen = UIImpactFeedbackGenerator(style: .light)
                gen.impactOccurred()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: showGridAndLevel ? "grid" : "grid.slash")
                        .font(.system(size: 13, weight: .bold))
                    Text("Mriežka")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .foregroundColor(showGridAndLevel ? Color.amberGold : .white.opacity(0.85))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(showGridAndLevel ? Color.amberGold.opacity(0.24) : Color.black.opacity(0.68))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(showGridAndLevel ? Color.amberGold : Color.white.opacity(0.22), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 6, y: 2)
            }
            
            // Samospúšť / Countdown Duration Selector (Funkcia 1 - Waze-style Pill)
            Menu {
                ForEach(CountdownDuration.allCases) { dur in
                    Button {
                        countdownDuration = dur
                    } label: {
                        HStack {
                            Text(dur.title)
                            if countdownDuration == dur {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "timer")
                        .font(.system(size: 13, weight: .bold))
                    Text(countdownDuration == .off ? "Spúšť" : countdownDuration.title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .black))
                        .opacity(0.65)
                }
                .foregroundColor(countdownDuration != .off ? Color.amberGold : .white.opacity(0.85))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(countdownDuration != .off ? Color.amberGold.opacity(0.24) : Color.black.opacity(0.68))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(countdownDuration != .off ? Color.amberGold : Color.white.opacity(0.22), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 6, y: 2)
            }
            
            // Ghost / Onion Skinning Button (Funkcia 4 - Waze-style Pill)
            if ghostVideoPath != nil {
                Button {
                    showGhostOverlay.toggle()
                    if showGhostOverlay {
                        ghostPlayer?.play()
                    } else {
                        ghostPlayer?.pause()
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "person.2.wave.2.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("Ghost")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(showGhostOverlay ? Color.amberGold : .white.opacity(0.85))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(showGhostOverlay ? Color.amberGold.opacity(0.24) : Color.black.opacity(0.68))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(showGhostOverlay ? Color.amberGold : Color.white.opacity(0.22), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.4), radius: 6, y: 2)
                }
            }
        }
    }
    
    // MARK: - Ghost Controls Bar
    private var ghostControlsBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "circle.lefthalf.filled")
                .foregroundColor(.amberGold)
                .font(.system(size: 12))
            
            Slider(value: $ghostOpacity, in: 0.15...0.85)
                .tint(.amberGold)
            
            Text("\(Int(ghostOpacity * 100))%")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.65))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.15), lineWidth: 1))
    }
    
    // MARK: - Zoom Switcher Bar (Funkcia 3: 0.5x, 1x, 2x)
    private var zoomSwitcherBar: some View {
        HStack(spacing: 6) {
            ForEach(CameraZoomFactor.allCases) { zoom in
                Button {
                    selectedZoom = zoom
                    camera.setZoom(zoom.rawValue)
                    let gen = UIImpactFeedbackGenerator(style: .light)
                    gen.impactOccurred()
                } label: {
                    Text(zoom.label)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(selectedZoom == zoom ? Color.black : Color.white)
                        .frame(width: 44, height: 32)
                        .background(selectedZoom == zoom ? Color.amberGold : Color.clear)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(4)
        .background(Color.black.opacity(0.6))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
    }
    
    // MARK: - Bottom Controls Deck
    private var bottomControlsDeck: some View {
        HStack {
            // Left Balance Spacer
            Color.clear
                .frame(width: 52, height: 52)
            
            Spacer()
            
            // Main Shutter Button with Countdown & Morphing Record Icon
            Button(action: handleShutterTap) {
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 76, height: 76)
                    
                    if camera.isRecording {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red)
                            .frame(width: 32, height: 32)
                    } else if isCountingDown {
                        Circle()
                            .fill(Color.amberGold)
                            .frame(width: 62, height: 62)
                    } else {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 62, height: 62)
                    }
                }
            }
            
            Spacer()
            
            // Flip Front / Back Camera with Mirror Mode (Funkcia 5)
            Button {
                isFrontMirrorMode.toggle()
                camera.switchCamera(isFront: isFrontMirrorMode)
                let gen = UIImpactFeedbackGenerator(style: .medium)
                gen.impactOccurred()
            } label: {
                Image(systemName: "camera.rotate.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
            }
            .disabled(camera.isRecording || isCountingDown)
        }
    }
    
    // MARK: - Shutter Action & Countdown Handler
    private func handleShutterTap() {
        if camera.isRecording {
            stopActiveRecording()
        } else if isCountingDown {
            stopCountdown()
        } else {
            if countdownDuration != .off {
                startCountdown(seconds: countdownDuration.rawValue)
            } else {
                startRecordingNow()
            }
        }
    }
    
    private func stopActiveRecording() {
        camera.stopRecording()
        endRecordingLiveActivity()
        ghostPlayer?.pause()
    }
    
    private func stopRecordingFromLiveActivity() {
        guard camera.isRecording else { return }
        stopActiveRecording()
    }
    
    private func startCountdown(seconds: Int) {
        isCountingDown = true
        countdownRemaining = seconds
        playBeep()
        
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if countdownRemaining > 1 {
                countdownRemaining -= 1
                playBeep()
            } else {
                timer.invalidate()
                countdownTimer = nil
                isCountingDown = false
                playStartBeep()
                startRecordingNow()
            }
        }
    }
    
    private func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        isCountingDown = false
    }
    
    private func startRecordingNow() {
        camera.startRecording()
        startRecordingLiveActivity()
        if showGhostOverlay {
            ghostPlayer?.seek(to: .zero)
            ghostPlayer?.play()
        }
    }
    
    // MARK: - Metronome Logic (Funkcia 9 - Powered by DanceMetronomeEngine)
    private func restartMetronome() {
        if metronome.selectedPreset != .off {
            metronome.start()
        }
    }
    
    private func stopMetronome() {
        metronome.stop()
    }
    
    private func saveInstantMemoryBookmark() {
        let durationString = formatDuration(camera.recordingDuration)
        let danceName = metronome.selectedPreset != .off ? "\(metronome.selectedPreset.shortCode) Tréning" : "Dance Training Hall 4"
        let noteText = "📌 Značka [\(durationString)] — \(danceName)"
        
        let newNote = InstantNote(text: noteText)
        modelContext.insert(newNote)
        try? modelContext.save()
        
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            bookmarkToastText = "Značka [\(durationString)] uložená do Instant Memory"
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeInOut(duration: 0.25)) {
                bookmarkToastText = nil
            }
        }
    }
    
    #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
    private func startRecordingLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        let state = RecordingActivityAttributes.ContentState(
            startDate: Date(),
            sessionTitle: metronome.selectedPreset != .off ? "\(metronome.selectedPreset.shortCode) Tréning" : "Dance Training Hall 4",
            metronomeName: metronome.selectedPreset == .off ? "" : metronome.selectedPreset.shortCode,
            bpm: metronome.effectiveBpm,
            beatsPerMeasure: metronome.selectedPreset == .off ? 0 : metronome.beatsPerMeasure,
            audioLevel: camera.audioLevel
        )
        
        Task {
            for activity in Activity<RecordingActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            
            do {
                _ = try Activity.request(
                    attributes: RecordingActivityAttributes(recordingName: "Tanečné nahrávanie"),
                    content: .init(state: state, staleDate: nil, relevanceScore: 100),
                    pushType: nil
                )
            } catch {
                Logger.camera.error("Failed to start recording Live Activity: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
    
    private func updateRecordingLiveActivity(force: Bool = false) {
        guard camera.isRecording else { return }
        let now = Date()
        guard force || now.timeIntervalSince(lastLiveActivityUpdate) >= 0.7 else { return }
        lastLiveActivityUpdate = now
        
        let state = RecordingActivityAttributes.ContentState(
            startDate: Date().addingTimeInterval(-Double(camera.recordingDuration)),
            sessionTitle: metronome.selectedPreset != .off ? "\(metronome.selectedPreset.shortCode) Tréning" : "Dance Training Hall 4",
            metronomeName: metronome.selectedPreset == .off ? "" : metronome.selectedPreset.shortCode,
            bpm: metronome.effectiveBpm,
            beatsPerMeasure: metronome.selectedPreset == .off ? 0 : metronome.beatsPerMeasure,
            audioLevel: camera.audioLevel
        )
        
        Task {
            for activity in Activity<RecordingActivityAttributes>.activities {
                await activity.update(.init(state: state, staleDate: nil, relevanceScore: 100))
            }
        }
    }
    
    private func endRecordingLiveActivity() {
        Task {
            for activity in Activity<RecordingActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
    #else
    private func startRecordingLiveActivity() {}
    private func updateRecordingLiveActivity(force: Bool = false) {}
    private func endRecordingLiveActivity() {}
    #endif
    
    private func playBeep() {
        AudioServicesPlaySystemSound(1057) // Native camera countdown tick
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.warning)
    }
    
    private func playStartBeep() {
        AudioServicesPlaySystemSound(1117) // Begin recording beep
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}
