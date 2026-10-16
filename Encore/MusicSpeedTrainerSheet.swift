import SwiftUI
import AVFoundation
import Combine
import OSLog

// MARK: - Hudba
/// Your own song slower or faster without changing its key (BRAND_GUIDELINES §1A).
/// With a dance chosen it also says what tempo the song is at, assuming it was at the basic tempo.
struct MusicSpeedTrainerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var player = MusicSpeedTrainerEngine()
    @State private var showDocumentPicker = false
    @State private var dance: DanceMetronomePreset?

    private static let dances: [DanceMetronomePreset] = [
        .waltz, .tango, .vienneseWaltz, .slowfox, .quickstep, .samba, .chacha, .rumba, .pasoDoble, .jive
    ]
    private static let speeds: [Float] = [0.8, 0.9, 1.0, 1.1]

    var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        Text("Pusti si vlastnú skladbu pomalšie alebo rýchlejšie. Tónina sa nemení.")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)

                        trackCard
                        speedCard
                        danceCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
            .safeAreaInset(edge: .bottom) {
                PrimarySheetButton(
                    title: player.hasTrack ? (player.isPlaying ? "Pozastaviť" : "Prehrať") : "Vybrať skladbu",
                    isLoading: false,
                    isEnabled: true
                ) {
                    if player.hasTrack { player.togglePlayPause() } else { showDocumentPicker = true }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
            .navigationTitle("Hudba")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hotovo") { dismiss() }
                        .foregroundColor(Color.gold400)
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                AudioDocumentPicker { url in player.loadTrack(url: url) }
            }
            .alert("Skladbu sa nepodarilo otvoriť", isPresented: Binding(
                get: { player.loadError != nil },
                set: { if !$0 { player.loadError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(player.loadError ?? "")
            }
        }
        .sensoryFeedback(.selection, trigger: player.playbackRate)
        .sensoryFeedback(.selection, trigger: dance)
        .sensoryFeedback(.impact(weight: .medium), trigger: player.isPlaying)
        .onDisappear { player.stop() }
    }

    // MARK: Track
    private var trackCard: some View {
        HStack(spacing: 14) {
            Image(systemName: player.isPlaying ? "waveform" : "music.note")
                .font(.title3.weight(.semibold))
                .foregroundColor(Color.gold400)
                .symbolEffect(.variableColor.iterative, isActive: player.isPlaying)
                .frame(width: 44, height: 44)
                .background(Color.gold500.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(player.trackTitle ?? "Žiadna skladba")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(player.hasTrack ? (player.isPlaying ? "Hrá" : "Pozastavené") : "Vyber skladbu zo Súborov")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer(minLength: 8)

            if player.hasTrack {
                Button("Zmeniť") { showDocumentPicker = true }
                    .font(.footnote.weight(.bold))
                    .foregroundColor(Color.gold400)
                    .buttonStyle(.pressable)
                    .frame(minHeight: 44)
            }
        }
        .padding(16)
        .homeCard(cornerRadius: 20)
    }

    // MARK: Speed
    private var speedCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HomeSectionHeader(title: "RÝCHLOSŤ", systemImage: "gauge.with.dots.needle.67percent") {
                if abs(player.playbackRate - 1) > 0.001 {
                    Button("Pôvodná") { player.setRate(1) }
                        .font(.footnote.weight(.bold))
                        .foregroundColor(Color.gold400)
                        .buttonStyle(.pressable)
                }
            }

            Text("\(percent(player.playbackRate)) %")
                .font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .contentTransition(.numericText())
                .frame(maxWidth: .infinity)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: player.playbackRate)

            Slider(
                value: Binding(get: { Double(player.playbackRate) }, set: { player.setRate(Float($0)) }),
                in: 0.7...1.3,
                step: 0.01
            ) {
                Text("Rýchlosť")
            } minimumValueLabel: {
                Text("70 %").font(.caption2).foregroundColor(.white.opacity(0.6))
            } maximumValueLabel: {
                Text("130 %").font(.caption2).foregroundColor(.white.opacity(0.6))
            }
            .tint(Color.gold400)

            HStack(spacing: 8) {
                ForEach(Self.speeds, id: \.self) { speed in
                    let isSelected = abs(player.playbackRate - speed) < 0.005
                    Button { player.setRate(speed) } label: {
                        Text("\(percent(speed)) %")
                            .font(.footnote.weight(isSelected ? .bold : .semibold))
                            .foregroundColor(isSelected ? Color.obsidian900 : .white.opacity(0.85))
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(isSelected ? Color.gold400 : Color.white.opacity(0.08), in: Capsule())
                    }
                    .buttonStyle(.pressable)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
        .padding(16)
        .homeCard(cornerRadius: 20)
    }

    // MARK: Dance tempo
    private var danceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeader(title: "TEMPO TANCA", systemImage: "metronome")

            FlowLayout(spacing: 8) {
                ForEach(Self.dances) { preset in
                    let isSelected = dance == preset
                    Button { dance = isSelected ? nil : preset } label: {
                        Text(preset.chipName)
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(isSelected ? Color.obsidian900 : .white.opacity(0.9))
                            .padding(.horizontal, 14)
                            .frame(minHeight: 34)
                            .background(isSelected ? Color.gold400 : Color.white.opacity(0.08), in: Capsule())
                    }
                    .buttonStyle(.pressable)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }

            Group {
                if let dance {
                    let tempo = Int((dance.mpm * Double(player.playbackRate)).rounded())
                    Text("Ak skladba hrá základným tempom \(Int(dance.mpm)) taktov za minútu, teraz hrá **\(tempo)**.")
                        .contentTransition(.numericText())
                } else {
                    Text("Vyber tanec a uvidíš, koľko taktov za minútu skladba hrá pri tejto rýchlosti.")
                }
            }
            .font(.footnote)
            .foregroundColor(.white.opacity(0.75))
            .fixedSize(horizontal: false, vertical: true)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: player.playbackRate)
        }
        .padding(16)
        .homeCard(cornerRadius: 20)
    }

    private func percent(_ rate: Float) -> Int { Int((rate * 100).rounded()) }
}

// MARK: - Engine (AVAudioEngine + AVAudioUnitTimePitch)
final class MusicSpeedTrainerEngine: ObservableObject, @unchecked Sendable {
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let timePitch = AVAudioUnitTimePitch()

    @Published private(set) var isPlaying = false
    @Published private(set) var playbackRate: Float = 1.0
    @Published private(set) var trackTitle: String?
    @Published var loadError: String?

    private var audioFile: AVAudioFile?
    /// The song must be scheduled again after it played to the end or was stopped.
    private var needsSchedule = true
    /// Only the newest scheduling may report the end of the song.
    private var scheduleID = 0

    var hasTrack: Bool { audioFile != nil }

    init() {
        audioEngine.attach(playerNode)
        audioEngine.attach(timePitch)
        audioEngine.connect(playerNode, to: timePitch, format: nil)
        audioEngine.connect(timePitch, to: audioEngine.mainMixerNode, format: nil)
        timePitch.pitch = 0
        timePitch.rate = 1
    }

    func setRate(_ rate: Float) {
        playbackRate = max(0.5, min(rate, 2.0))
        timePitch.rate = playbackRate
    }

    func loadTrack(url: URL) {
        do {
            let file = try AVAudioFile(forReading: url)
            stopPlayback()
            audioFile = file
            trackTitle = url.deletingPathExtension().lastPathComponent
            needsSchedule = true
        } catch {
            Logger.audio.error("Loading audio file failed: \(error.localizedDescription, privacy: .public)")
            loadError = "Tento súbor sa nedá prehrať. Skús skladbu vo formáte MP3, M4A alebo WAV."
        }
    }

    func togglePlayPause() {
        if isPlaying {
            playerNode.pause()
            isPlaying = false
            return
        }
        guard let audioFile else { return }
        Task { @MainActor in
            try? await AudioSessionCoordinator.shared.activate(.player)
            if !audioEngine.isRunning {
                do { try audioEngine.start() } catch {
                    Logger.audio.error("Starting the audio engine failed: \(error.localizedDescription, privacy: .public)")
                    return
                }
            }
            if needsSchedule { schedule(audioFile) }
            playerNode.play()
            isPlaying = true
        }
    }

    func stop() {
        stopPlayback()
        audioEngine.stop()
        Task { await AudioSessionCoordinator.shared.deactivate(.player) }
    }

    private func stopPlayback() {
        scheduleID += 1
        playerNode.stop()
        isPlaying = false
        needsSchedule = true
    }

    private func schedule(_ file: AVAudioFile) {
        scheduleID += 1
        let id = scheduleID
        needsSchedule = false
        playerNode.scheduleFile(file, at: nil, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.scheduleID == id else { return }
                // Played to the end: the next tap starts the song from the beginning.
                self.playerNode.stop()
                self.isPlaying = false
                self.needsSchedule = true
            }
        }
    }
}

// MARK: - Audio Document Picker
struct AudioDocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.audio], asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let first = urls.first {
                onPick(first)
            }
        }
    }
}

// MARK: - Xcode Canvas Preview
#Preview("Hudba") {
    MusicSpeedTrainerSheet()
        .preferredColorScheme(.dark)
}
