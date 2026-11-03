import SwiftUI
import SwiftData
import AVFoundation
import AVKit
import OSLog

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
        case .threeSeconds: return "3 s"
        case .fiveSeconds: return "5 s"
        case .tenSeconds: return "10 s"
        }
    }

    /// The timer chip steps Vypnuté → 3 s → 5 s → 10 s → Vypnuté, like the system camera.
    var next: CountdownDuration {
        let all = Self.allCases
        let index = all.firstIndex(of: self) ?? 0
        return all[(index + 1) % all.count]
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
        case .wide: return "0,5×"
        case .standard: return "1×"
        case .telephoto: return "2×"
        }
    }

    /// "1,7×" during a pinch, "2×" on a whole number.
    static func text(_ zoom: Double) -> String {
        let rounded = (zoom * 10).rounded() / 10
        let number = rounded == rounded.rounded() ? String(Int(rounded)) : String(format: "%.1f", rounded).replacingOccurrences(of: ".", with: ",")
        return number + "×"
    }
}

// MARK: - DanceCameraView
/// The dance camera. It only lays out the screen: the camera's state is in `DanceCameraModel`, the level in
/// `HorizonLevel`, and the controls that follow the metronome in CameraControls.swift.
struct DanceCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var ghostVideoPath: String? = nil
    /// The finished clip goes into Fotky (album "Encore") and the callback gets a `photos:` reference.
    /// Without access to Fotky it stays in the app as before.
    var savesToPhotos = false
    /// The main button after a take: where the clip goes ("Uložiť do Denníka", "Uložiť k figúre").
    var saveTitle = "Uložiť video"
    var onRecordComplete: (String) -> Void

    @State private var camera = DanceCameraModel()
    @State private var level = HorizonLevel()

    @State private var bookmarkToastText: String? = nil
    @State private var focusMark: FocusMark? = nil
    @State private var showGridAndLevel: Bool = true

    // Ghost / Onion Skinning
    @State private var showGhostOverlay: Bool = false
    @State private var ghostOpacity: Double = 0.45
    @State private var ghostPlayer: AVPlayer? = nil

    // After a take: play, trim, save or discard
    @State private var rawRecordedURL: URL? = nil
    @State private var showSaveDetailsSheet: Bool = false
    @State private var showTrimmerSheet: Bool = false
    @State private var showFullMetronomeSheet: Bool = false
    @State private var showMetronomeTray: Bool = false

    @Namespace private var zoomSelection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreviewRepresentable(session: camera.session) { devicePoint, screenPoint, lock in
                camera.focus(at: devicePoint, lock: lock)
                focusMark = FocusMark(point: screenPoint, isLock: lock)
            } onPinch: { began, scale in
                began ? camera.pinchBegan() : camera.pinchChanged(scale: scale)
            }
            .ignoresSafeArea()
            
            if let focusMark {
                CameraFocusSquare(mark: focusMark)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            if showGhostOverlay, let player = ghostPlayer {
                GhostPlayerRepresentable(player: player)
                    .opacity(ghostOpacity)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            if showGridAndLevel {
                CameraGridAndLevelOverlay(level: level)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            if camera.isCountingDown {
                Text("\(camera.countdownRemaining)")
                    .font(.system(size: 110, weight: .heavy, design: .rounded))
                    .foregroundColor(Color.amberGold)
                    .shadow(color: .black.opacity(0.8), radius: 10, x: 0, y: 4)
                    .transition(.scale.combined(with: .opacity))
                    .id(camera.countdownRemaining)
            }

            CameraBeatFlash()

            if let toast = bookmarkToastText {
                VStack {
                    HStack(spacing: 8) {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color.amberGold)
                        Text(toast)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .cameraGlass(in: Capsule())
                    .overlay(Capsule().stroke(Color.amberGold.opacity(0.45), lineWidth: 1))
                    .transition(.move(edge: .top).combined(with: .opacity))

                    Spacer()
                }
                .padding(.top, 56)
                .zIndex(100)
            }

            // Top: only the recording clock. Everything else is in one glass deck in the thumb's reach.
            VStack(spacing: 0) {
                if camera.isRecording {
                    CameraRecordingPill(camera: camera)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                Spacer()
                
                CameraMetronomeStatusPill(isRecording: camera.isRecording)
                    .padding(.bottom, 10)
                
                if showGhostOverlay && ghostVideoPath != nil {
                    ghostControlsBar
                        .padding(.horizontal, 24)
                        .padding(.bottom, 10)
                }
                
                controlDeck
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
            }
            .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85), value: camera.isRecording)
        }
        .statusBarHidden()
        // The Lock Screen's recording buttons (RecordingLiveActivityIntent runs in the app).
        .onReceive(NotificationCenter.default.publisher(for: .stopRecordingFromLiveActivity)) { _ in
            camera.stopRecording()
        }
        .onReceive(NotificationCenter.default.publisher(for: .bookmarkRecordingFromLiveActivity)) { _ in
            saveInstantMemoryBookmark()
        }
        .onAppear {
            camera.start()
            if showGridAndLevel { level.start() }
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
            DanceMetronomeEngine.shared.stop()
            ghostPlayer?.pause()
            ghostPlayer = nil
            level.stop()
            camera.stop()
        }
        .onChange(of: showGridAndLevel) { _, shown in
            shown ? level.start() : level.stop()
        }
        .onChange(of: camera.isRecording) { _, recording in
            // The ghost starts over with each take and stops with it.
            if recording && showGhostOverlay {
                ghostPlayer?.seek(to: .zero)
                ghostPlayer?.play()
            } else if !recording {
                ghostPlayer?.pause()
            }
        }
        .onChange(of: camera.recordedVideoURL) { _, newURL in
            guard let url = newURL else { return }
            rawRecordedURL = url
            camera.recordedVideoURL = nil
            showSaveDetailsSheet = true
        }
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
            onRecordComplete(try MediaStorageManager.moveIntoDocuments(from: url, fileExtension: "mov"))
            dismiss()
        } catch {
            Logger.camera.error("Saving the clip failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Control deck
    /// The chips, the zoom and the shutter row in one glass panel; while recording only the shutter stays, so
    /// the picture is clear and nothing closes the camera mid-take.
    private var controlDeck: some View {
        VStack(spacing: 14) {
            if !camera.isRecording {
                if showMetronomeTray {
                    CameraMetronomeTray { showFullMetronomeSheet = true }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                chipRow
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                zoomPicker
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
            shutterRow
        }
        .padding(.horizontal, 10)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity)
        .cameraGlass(in: RoundedRectangle(cornerRadius: 30, style: .continuous))
    }
    
    /// One row of chips: with names when they fit, icons only on a narrower iPhone, scrolling as the last resort.
    private var chipRow: some View {
        ViewThatFits(in: .horizontal) {
            chips(named: true)
            chips(named: false)
            ScrollView(.horizontal, showsIndicators: false) { chips(named: false) }
        }
    }
    
    private func chips(named: Bool) -> some View {
        HStack(spacing: 8) {
            CameraMetronomeChip(isOpen: showMetronomeTray) {
                withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85)) {
                    showMetronomeTray.toggle()
                }
            }
            
            Button {
                showGridAndLevel.toggle()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "grid")
                    if named { Text("Mriežka") }
                }
                .cameraChip(isOn: showGridAndLevel)
            }
            .accessibilityLabel(showGridAndLevel ? "Skryť mriežku a vodováhu" : "Ukázať mriežku a vodováhu")
            .buttonStyle(.pressable)
            .sensoryFeedback(.selection, trigger: showGridAndLevel)
            
            Button {
                camera.countdown = camera.countdown.next
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "timer")
                    if camera.countdown != .off {
                        Text(camera.countdown.title)
                            .contentTransition(.numericText())
                    } else if named {
                        Text("Spúšť")
                    }
                }
                .cameraChip(isOn: camera.countdown != .off)
            }
            .buttonStyle(.pressable)
            .sensoryFeedback(.selection, trigger: camera.countdown)
            .accessibilityLabel("Samospúšť: \(camera.countdown.title)")
            
            Button(action: camera.toggleTorch) {
                Image(systemName: camera.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                    .contentTransition(.symbolEffect(.replace))
                    .cameraChip(isOn: camera.isTorchOn)
            }
            .buttonStyle(.pressable)
            .sensoryFeedback(.impact(weight: .light), trigger: camera.isTorchOn)
            .accessibilityLabel(camera.isTorchOn ? "Vypnúť svetlo" : "Zapnúť svetlo")
            
            if ghostVideoPath != nil {
                Button {
                    showGhostOverlay.toggle()
                    if showGhostOverlay {
                        ghostPlayer?.play()
                    } else {
                        ghostPlayer?.pause()
                    }
                } label: {
                    Image(systemName: "person.2.wave.2.fill")
                        .cameraChip(isOn: showGhostOverlay)
                }
                .buttonStyle(.pressable)
                .sensoryFeedback(.selection, trigger: showGhostOverlay)
                .accessibilityLabel(showGhostOverlay ? "Skryť porovnávacie video" : "Ukázať porovnávacie video")
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
        .padding(.vertical, 8)
        .cameraGlass(in: Capsule())
    }

    // MARK: - Zoom
    /// The gold fill slides to the nearest zoom (BRAND_GUIDELINES §1A mode switcher); during a pinch it shows the
    /// exact value, like the system camera.
    private var zoomPicker: some View {
        let presets = CameraZoomFactor.allCases.filter { $0 != .wide || camera.hasUltraWide }
        let nearest = presets.min { abs($0.rawValue - camera.zoom) < abs($1.rawValue - camera.zoom) } ?? .standard
        return HStack(spacing: 4) {
            ForEach(presets) { zoom in
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8)) {
                        camera.setZoom(zoom)
                    }
                } label: {
                    Text(zoom == nearest ? CameraZoomFactor.text(camera.zoom) : zoom.label)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(zoom == nearest ? Color.obsidian900 : .white)
                        .contentTransition(.numericText())
                        .frame(width: 56, height: 36)
                        .background {
                            if zoom == nearest {
                                Capsule()
                                    .fill(Color.amberGold)
                                    .matchedGeometryEffect(id: "zoom", in: zoomSelection)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Priblíženie \(zoom.label)")
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.12), in: Capsule())
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: nearest)
        .sensoryFeedback(.selection, trigger: nearest)
    }
    
    // MARK: - Shutter row
    /// Close, shutter, flip. While recording only the shutter, so a take is never lost to a stray tap.
    private var shutterRow: some View {
        HStack {
            if camera.isRecording {
                Color.clear.frame(width: 48, height: 48)
            } else {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(Color.white.opacity(0.12), in: Circle())
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Zavrieť kameru")
            }
            
            Spacer()
            
            Button(action: camera.shutter) {
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 76, height: 76)
                    // The red circle becomes a stop square, the way the system camera does it.
                    RoundedRectangle(cornerRadius: camera.isRecording ? 8 : 31, style: .continuous)
                        .fill(camera.isCountingDown ? Color.amberGold : Color.red)
                        .frame(width: camera.isRecording ? 32 : 62, height: camera.isRecording ? 32 : 62)
                }
                .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.7), value: camera.isRecording)
            }
            .buttonStyle(.pressable(scale: 0.92))
            .sensoryFeedback(.impact(weight: .medium), trigger: camera.isRecording)
            .accessibilityLabel(camera.isRecording ? "Zastaviť nahrávanie" : (camera.isCountingDown ? "Zrušiť odpočet" : "Nahrávať"))
            
            Spacer()
            
            if camera.isRecording {
                Color.clear.frame(width: 48, height: 48)
            } else {
                // The front camera records mirrored, like a dance-studio mirror.
                Button(action: camera.flipCamera) {
                    Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .symbolEffect(.rotate, value: camera.isFront)
                        .frame(width: 48, height: 48)
                        .background(Color.white.opacity(0.12), in: Circle())
                }
                .buttonStyle(.pressable)
                .disabled(camera.isCountingDown)
                .sensoryFeedback(.impact(weight: .medium), trigger: camera.isFront)
                .accessibilityLabel("Otočiť kameru")
            }
        }
    }
    
    // MARK: - Bookmark from the Lock Screen
    private func saveInstantMemoryBookmark() {
        let metronome = DanceMetronomeEngine.shared
        let durationString = DanceCameraModel.clockText(camera.recordingDuration)
        let text = metronome.selectedPreset != .off
            ? "Značka \(durationString) – \(metronome.selectedPreset.shortCode) tréning"
            : "Značka v nahrávke \(durationString)"
        modelContext.insert(InstantNote(text: text))
        try? modelContext.save()

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            bookmarkToastText = "Značka \(durationString) je v Denníku"
        }
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            withAnimation(.easeInOut(duration: 0.25)) {
                bookmarkToastText = nil
            }
        }
    }
}
