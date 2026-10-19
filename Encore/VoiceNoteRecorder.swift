import AVFoundation
import Combine
import SwiftUI

/// Records a voice note as a high quality AAC file (48 kHz, 128 kbps, mono) into Documents.
/// The recording itself is what gets saved; nothing is transcribed.
@MainActor
final class VoiceNoteRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    enum State { case idle, recording, recorded }

    static let maxDuration: TimeInterval = 600

    @Published private(set) var state: State = .idle
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var level: CGFloat = 0
    @Published private(set) var errorMessage: String?
    private(set) var fileName: String?

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var interruptionObserver: (any NSObjectProtocol)?

    func start() async {
        errorMessage = nil
        guard await AVAudioApplication.requestRecordPermission() else {
            errorMessage = "Povoľ mikrofón v Nastaveniach iPhonu (Encore → Mikrofón)."
            return
        }
        guard MediaStorageManager.hasAvailableDiskSpace(minMB: 50) else {
            errorMessage = "V iPhone je málo miesta na nahrávanie."
            return
        }
        do {
            try await AudioSessionCoordinator.shared.activate(.voiceNote)
            let name = "voice_\(UUID().uuidString).m4a"
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 48_000,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 128_000,
                AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue
            ]
            let newRecorder = try AVAudioRecorder(url: MediaStorageManager.url(for: name), settings: settings)
            newRecorder.delegate = self
            newRecorder.isMeteringEnabled = true
            guard newRecorder.record(forDuration: Self.maxDuration) else {
                throw CocoaError(.fileWriteUnknown)
            }
            recorder = newRecorder
            fileName = name
            elapsed = 0
            state = .recording
            startTimer()
            observeInterruptions()
        } catch {
            errorMessage = "Nahrávanie sa nepodarilo spustiť. Skús to znova."
            await AudioSessionCoordinator.shared.deactivate(.voiceNote)
        }
    }

    func stop() {
        guard state == .recording, let recorder else { return }
        elapsed = recorder.currentTime
        recorder.stop()
        finish()
        if let fileName, elapsed >= 0.5, MediaStorageManager.fileExists(fileName) {
            // Kept in the iPhone backup: Fotky cannot hold audio, so this file is the only copy (~1 MB a minute).
            state = .recorded
        } else {
            discard()
        }
    }

    /// Throws the recording away (also the file).
    func discard() {
        recorder?.stop()
        finish()
        MediaStorageManager.removeFile(named: fileName)
        fileName = nil
        elapsed = 0
        state = .idle
    }

    /// Hands the finished file over to the caller, who now owns it.
    func takeResult() -> (fileName: String, duration: TimeInterval)? {
        guard state == .recorded, let fileName else { return nil }
        let result = (fileName, elapsed)
        self.fileName = nil
        elapsed = 0
        state = .idle
        return result
    }

    private func finish() {
        timer?.invalidate()
        timer = nil
        recorder = nil
        level = 0
        if let interruptionObserver { NotificationCenter.default.removeObserver(interruptionObserver) }
        interruptionObserver = nil
        Task { await AudioSessionCoordinator.shared.deactivate(.voiceNote) }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let recorder = self.recorder, recorder.isRecording else { return }
                recorder.updateMeters()
                self.elapsed = recorder.currentTime
                self.level = CGFloat(max(0, min(1, (recorder.averagePower(forChannel: 0) + 50) / 50)))
            }
        }
    }

    /// A phone call or Siri ends the recording; what was captured so far is kept.
    private func observeInterruptions() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }
            MainActor.assumeIsolated { self?.stop() }
        }
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        // The time limit ended the recording on its own.
        Task { @MainActor in
            if self.state == .recording { self.stop() }
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            self.errorMessage = "Pri nahrávaní nastala chyba. Nahrávka sa uložila, len ak je dostatočne dlhá."
            if self.state == .recording { self.stop() }
        }
    }
}

/// Plays saved voice notes: play / pause, a slider to jump around and the speed. The journal plays one
/// note after another (`onFinish`) with the same player, so only one note ever sounds.
@MainActor
final class VoiceNotePlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    /// The loaded voice note.
    @Published private(set) var fileName: String?
    /// 1×, 1,5× or 2×.
    @Published var rate: Float = 1 {
        didSet { player?.rate = rate }
    }
    /// Called when a note played to its end; the audio session stays active for the next one, so the
    /// caller stops the player when nothing follows.
    var onFinish: (() -> Void)?

    private var player: AVAudioPlayer?
    private var timer: Timer?

    func load(fileName: String) {
        guard self.fileName != fileName, MediaStorageManager.fileExists(fileName) else { return }
        halt()
        player = try? AVAudioPlayer(contentsOf: MediaStorageManager.url(for: fileName))
        player?.delegate = self
        player?.enableRate = true
        player?.rate = rate
        player?.prepareToPlay()
        self.fileName = fileName
        duration = player?.duration ?? 0
        currentTime = 0
    }

    /// Loads the note when it is another one and plays it.
    func play(fileName: String) {
        load(fileName: fileName)
        if !isPlaying { toggle() }
    }

    func toggle() {
        guard let player else { return }
        if isPlaying {
            pause()
        } else {
            Task {
                try? await AudioSessionCoordinator.shared.activate(.voiceNote)
                player.play()
                isPlaying = true
                timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                    MainActor.assumeIsolated { self?.currentTime = self?.player?.currentTime ?? 0 }
                }
            }
        }
    }

    func seek(to time: TimeInterval) {
        player?.currentTime = time
        currentTime = time
    }

    func pause() {
        halt()
        Task { await AudioSessionCoordinator.shared.deactivate(.voiceNote) }
    }

    /// Stops the sound and the clock but keeps the audio session for the next note.
    private func halt() {
        player?.pause()
        isPlaying = false
        timer?.invalidate()
        timer = nil
    }

    func stop() {
        player?.stop()
        pause()
        currentTime = 0
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            if let onFinish = self.onFinish {
                self.halt()
                self.player?.currentTime = 0
                self.currentTime = 0
                onFinish()
            } else {
                self.pause()
                self.player?.currentTime = 0
                self.currentTime = 0
            }
        }
    }
}

func voiceTimeString(_ seconds: TimeInterval) -> String {
    let total = Int(seconds.rounded(.down))
    return String(format: "%d:%02d", total / 60, total % 60)
}

struct VoiceNotePlayerView: View {
    let fileName: String
    @StateObject private var player = VoiceNotePlayer()

    var body: some View {
        HStack(spacing: 12) {
            Button { player.toggle() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.obsidian900)
                    .frame(width: 44, height: 44)
                    .background(Color.gold400, in: Circle())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(player.isPlaying ? "Pozastaviť" : "Prehrať")

            VStack(spacing: 2) {
                Slider(
                    value: Binding(get: { player.currentTime }, set: { player.seek(to: $0) }),
                    in: 0...max(player.duration, 0.1)
                )
                .tint(Color.gold400)
                HStack {
                    Text(voiceTimeString(player.currentTime))
                    Spacer()
                    Text(voiceTimeString(player.duration))
                }
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.55))
            }
        }
        .onAppear { player.load(fileName: fileName) }
        .onDisappear { player.stop() }
    }
}
