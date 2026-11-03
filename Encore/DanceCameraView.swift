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

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreviewRepresentable(session: camera.session)
                .ignoresSafeArea()
                .onTapGesture { location in
                    camera.focus(at: location)
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

            VStack(spacing: 0) {
                topHeaderBar
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                Spacer()

                VStack(spacing: 8) {
                    CameraMetronomeStatusPill(isRecording: camera.isRecording)
                    actionControlStrip
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 6)

                if showGhostOverlay && ghostVideoPath != nil {
                    ghostControlsBar
                        .padding(.horizontal, 24)
                        .padding(.bottom, 6)
                }

                if camera.isRecording {
                    CameraRecordingPill(camera: camera)
                        .padding(.bottom, 8)
                }

                zoomSwitcherBar
                    .padding(.bottom, 12)

                bottomControlsDeck
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)
            }
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
            onRecordComplete(try MediaStorageManager.moveIntoDocuments(from: url, fileExtension: "mp4"))
            dismiss()
        } catch {
            Logger.camera.error("Saving the clip failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Top Header Bar (Safe from Dynamic Island)
    private var topHeaderBar: some View {
        HStack {
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

            Button {
                camera.toggleTorch()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: camera.isTorchOn ? "bolt.fill" : "bolt.slash.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(camera.isTorchOn ? Color.amberGold : .white)
                    .frame(width: 42, height: 42)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(camera.isTorchOn ? Color.amberGold : Color.white.opacity(0.18), lineWidth: 1))
            }
        }
    }

    // MARK: - Action Control Strip
    private var actionControlStrip: some View {
        HStack(spacing: 8) {
            CameraMetronomeChip { showFullMetronomeSheet = true }

            Button {
                showGridAndLevel.toggle()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
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

            Menu {
                ForEach(CountdownDuration.allCases) { duration in
                    Button {
                        camera.countdown = duration
                    } label: {
                        HStack {
                            Text(duration.title)
                            if camera.countdown == duration {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "timer")
                        .font(.system(size: 13, weight: .bold))
                    Text(camera.countdown == .off ? "Spúšť" : camera.countdown.title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .black))
                        .opacity(0.65)
                }
                .foregroundColor(camera.countdown != .off ? Color.amberGold : .white.opacity(0.85))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(camera.countdown != .off ? Color.amberGold.opacity(0.24) : Color.black.opacity(0.68))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(camera.countdown != .off ? Color.amberGold : Color.white.opacity(0.22), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 6, y: 2)
            }

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

    // MARK: - Zoom Switcher Bar (0.5x, 1x, 2x)
    private var zoomSwitcherBar: some View {
        HStack(spacing: 6) {
            ForEach(CameraZoomFactor.allCases) { zoom in
                Button {
                    camera.setZoom(zoom)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Text(zoom.label)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(camera.zoom == zoom ? Color.black : Color.white)
                        .frame(width: 44, height: 32)
                        .background(camera.zoom == zoom ? Color.amberGold : Color.clear)
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
            Color.clear
                .frame(width: 52, height: 52)

            Spacer()

            Button(action: camera.shutter) {
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 76, height: 76)

                    if camera.isRecording {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red)
                            .frame(width: 32, height: 32)
                    } else if camera.isCountingDown {
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

            // Front camera records mirrored, like a dance-studio mirror.
            Button {
                camera.flipCamera()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                Image(systemName: "camera.rotate.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
            }
            .disabled(camera.isRecording || camera.isCountingDown)
        }
    }

    // MARK: - Bookmark from the Lock Screen
    private func saveInstantMemoryBookmark() {
        let metronome = DanceMetronomeEngine.shared
        let durationString = DanceCameraModel.clockText(camera.recordingDuration)
        let danceName = metronome.selectedPreset != .off ? "\(metronome.selectedPreset.shortCode) Tréning" : "Dance Training Hall 4"
        modelContext.insert(InstantNote(text: "Značka \(durationString) – \(danceName)"))
        try? modelContext.save()

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            bookmarkToastText = "Značka [\(durationString)] uložená do Instant Memory"
        }
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            withAnimation(.easeInOut(duration: 0.25)) {
                bookmarkToastText = nil
            }
        }
    }
}
