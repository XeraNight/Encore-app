import AudioToolbox
import AVFoundation
import Combine
import Foundation
import Observation
import OSLog
import UIKit
#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
import ActivityKit
#endif

// MARK: - Capture pipeline
/// The camera pipeline: session, lens, focus, zoom, torch and recording. An actor whose executor is the session
/// queue, so no AVFoundation call runs on the main thread (as in Apple's AVCam).
actor CaptureService {
    /// The preview layer shows this session; only the actor configures it.
    nonisolated let session = AVCaptureSession()
    private let queue = DispatchSerialQueue(label: "com.encore.camera.session")
    nonisolated var unownedExecutor: UnownedSerialExecutor { queue.asUnownedSerialExecutor() }

    private let movieOutput = AVCaptureMovieFileOutput()
    private var videoInput: AVCaptureDeviceInput?
    private var isConfigured = false
    private var recordingDelegate: RecordingDelegate?
    private var subjectAreaWatch: Task<Void, Never>?

    func start() {
        configureAudioSession()
        if !isConfigured {
            configure()
            isConfigured = true
        }
        if !session.isRunning { session.startRunning() }
    }

    func stop() {
        if session.isRunning { session.stopRunning() }
    }

    /// One audio session for the camera and the metronome, set before the camera starts, so the two never fight
    /// over the category (err -19224 / -17281).
    private func configureAudioSession() {
        do {
            let audio = AVAudioSession.sharedInstance()
            try audio.setCategory(
                .playAndRecord,
                mode: .videoRecording,
                options: [.defaultToSpeaker, .mixWithOthers, .allowBluetoothHFP, .allowBluetoothA2DP]
            )
            try audio.setActive(true)
        } catch {
            Logger.camera.warning("Audio session setup failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func configure() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .high
        if let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let input = try? AVCaptureDeviceInput(device: camera),
           session.canAddInput(input) {
            session.addInput(input)
            videoInput = input
        }
        if let microphone = AVCaptureDevice.default(for: .audio),
           let input = try? AVCaptureDeviceInput(device: microphone),
           session.canAddInput(input) {
            session.addInput(input)
        }
        if session.canAddOutput(movieOutput) { session.addOutput(movieOutput) }
    }

    func switchCamera(front: Bool) {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        if let current = videoInput { session.removeInput(current) }
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: front ? .front : .back),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else { return }
        session.addInput(input)
        videoInput = input
        // The front camera records mirrored, like a dance-studio mirror.
        if let connection = movieOutput.connection(with: .video), connection.isVideoMirroringSupported {
            connection.isVideoMirrored = front
        }
    }

    func setZoom(_ factor: Double) {
        guard let device = videoInput?.device else { return }
        do {
            try device.lockForConfiguration()
            let clamped = max(1.0, min(factor, device.activeFormat.videoMaxZoomFactor))
            device.ramp(toVideoZoomFactor: CGFloat(clamped), withRate: 4.0)
            device.unlockForConfiguration()
        } catch {
            Logger.camera.error("Zoom failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Focuses and exposes where the dancer tapped (a point in the camera's own 0–1 coordinates). When the
    /// scene changes, the camera goes back to following the whole picture by itself.
    func focus(at point: CGPoint) {
        guard let device = videoInput?.device else { return }
        do {
            try device.lockForConfiguration()
            if device.isFocusPointOfInterestSupported, device.isFocusModeSupported(.autoFocus) {
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
            }
            if device.isExposurePointOfInterestSupported, device.isExposureModeSupported(.autoExpose) {
                device.exposurePointOfInterest = point
                device.exposureMode = .autoExpose
            }
            device.isSubjectAreaChangeMonitoringEnabled = true
            device.unlockForConfiguration()
        } catch {
            Logger.camera.error("Focus failed: \(error.localizedDescription, privacy: .public)")
        }
        watchSubjectArea(of: device)
    }

    /// After a tap the focus holds until the picture changes (the couple moves away); then it follows again.
    private func watchSubjectArea(of device: AVCaptureDevice) {
        subjectAreaWatch?.cancel()
        subjectAreaWatch = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: AVCaptureDevice.subjectAreaDidChangeNotification, object: device) {
                await self?.followWholePicture(device)
                return
            }
        }
    }

    private func followWholePicture(_ device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            let center = CGPoint(x: 0.5, y: 0.5)
            if device.isFocusPointOfInterestSupported, device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusPointOfInterest = center
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposurePointOfInterestSupported, device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposurePointOfInterest = center
                device.exposureMode = .continuousAutoExposure
            }
            device.isSubjectAreaChangeMonitoringEnabled = false
            device.unlockForConfiguration()
        } catch {
            Logger.camera.error("Resetting focus failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func setTorch(_ on: Bool) {
        guard let device = videoInput?.device, device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        } catch {
            Logger.camera.error("Torch failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Records to a temporary file; `finished` gets it when the recording stops, or nil when it failed.
    func startRecording(finished: @escaping @Sendable (URL?) -> Void) {
        guard !movieOutput.isRecording else { return }
        let url = URL.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mp4")
        let delegate = RecordingDelegate(finished: finished)
        recordingDelegate = delegate
        movieOutput.startRecording(to: url, recordingDelegate: delegate)
    }

    func stopRecording() {
        if movieOutput.isRecording { movieOutput.stopRecording() }
    }
}

/// AVFoundation calls this on its own queue when a recording ends.
nonisolated private final class RecordingDelegate: NSObject, AVCaptureFileOutputRecordingDelegate {
    private let finished: @Sendable (URL?) -> Void

    init(finished: @escaping @Sendable (URL?) -> Void) {
        self.finished = finished
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error {
            Logger.camera.error("Recording failed: \(error.localizedDescription, privacy: .public)")
        }
        finished(error == nil ? outputFileURL : nil)
    }
}

// MARK: - Camera screen state
/// What the camera screen shows and does. Views read only the properties they draw (Observation), so the
/// recording clock or a metronome beat never redraws the whole screen and a tap is never lost to a redraw.
@Observable
final class DanceCameraModel {
    private(set) var isRecording = false
    private(set) var recordingDuration = 0
    private(set) var countdownRemaining = 0
    var isCountingDown: Bool { countdownRemaining > 0 }
    /// The finished take, until the screen picks it up.
    var recordedVideoURL: URL?
    var countdown: CountdownDuration = .off
    private(set) var zoom: CameraZoomFactor = .standard
    private(set) var isTorchOn = false
    private(set) var isFront = false

    @ObservationIgnored private let capture = CaptureService()
    @ObservationIgnored private var clock: Task<Void, Never>?
    @ObservationIgnored private var countdownTask: Task<Void, Never>?
    @ObservationIgnored private var metronomeChanges: AnyCancellable?

    nonisolated var session: AVCaptureSession { capture.session }

    /// "01:05" for 65 seconds.
    static func clockText(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    func start() {
        Task { await capture.start() }
    }

    func stop() {
        cancelCountdown()
        clock?.cancel()
        metronomeChanges = nil
        RecordingActivity.end()
        Task { await capture.stop() }
    }

    /// The shutter: stops a recording, cancels a countdown, or starts one (with the self-timer, after it).
    func shutter() {
        if isRecording {
            stopRecording()
        } else if isCountingDown {
            cancelCountdown()
        } else if countdown == .off {
            startRecording()
        } else {
            startCountdown(seconds: countdown.rawValue)
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        clock?.cancel()
        metronomeChanges = nil
        RecordingActivity.end()
        Task { await capture.stopRecording() }
    }

    func setZoom(_ factor: CameraZoomFactor) {
        zoom = factor
        Task { await capture.setZoom(factor.rawValue) }
    }

    func focus(at point: CGPoint) {
        Task { await capture.focus(at: point) }
    }

    func toggleTorch() {
        isTorchOn.toggle()
        let on = isTorchOn
        Task { await capture.setTorch(on) }
    }

    func flipCamera() {
        isFront.toggle()
        let front = isFront
        Task { await capture.switchCamera(front: front) }
    }

    private func startRecording() {
        isRecording = true
        recordingDuration = 0
        clock = Task { [weak self] in
            while true {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self else { return }
                self.recordingDuration += 1
            }
        }
        RecordingActivity.start()
        // The Lock Screen shows the tempo; it follows a change made while recording.
        let metronome = DanceMetronomeEngine.shared
        metronomeChanges = metronome.$selectedPreset.combineLatest(metronome.$tempoMultiplier)
            .dropFirst()
            .sink { [weak self] _, _ in
                guard let self else { return }
                RecordingActivity.update(elapsed: self.recordingDuration)
            }
        Task {
            await capture.startRecording { url in
                Task { @MainActor [weak self] in self?.recordedVideoURL = url }
            }
        }
    }

    private func startCountdown(seconds: Int) {
        countdownRemaining = seconds
        CameraSounds.tick()
        countdownTask = Task { [weak self] in
            while true {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self else { return }
                if self.countdownRemaining > 1 {
                    self.countdownRemaining -= 1
                    CameraSounds.tick()
                } else {
                    self.countdownRemaining = 0
                    CameraSounds.start()
                    self.startRecording()
                    return
                }
            }
        }
    }

    private func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        countdownRemaining = 0
    }
}

/// The self-timer: the system camera's tick and start sounds, with a haptic.
private enum CameraSounds {
    static func tick() {
        AudioServicesPlaySystemSound(1057)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func start() {
        AudioServicesPlaySystemSound(1117)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - The recording on the Lock Screen and in the Dynamic Island
private enum RecordingActivity {
    #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
    static func start() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = state(elapsed: 0)
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
                Logger.camera.error("Recording Live Activity failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    static func update(elapsed: Int) {
        let state = state(elapsed: elapsed)
        Task {
            for activity in Activity<RecordingActivityAttributes>.activities {
                await activity.update(.init(state: state, staleDate: nil, relevanceScore: 100))
            }
        }
    }

    static func end() {
        Task {
            for activity in Activity<RecordingActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private static func state(elapsed: Int) -> RecordingActivityAttributes.ContentState {
        let metronome = DanceMetronomeEngine.shared
        let on = metronome.selectedPreset != .off
        return RecordingActivityAttributes.ContentState(
            startDate: Date().addingTimeInterval(-Double(elapsed)),
            // Empty: the Lock Screen says "Nahrávam".
            sessionTitle: on ? "\(metronome.selectedPreset.shortCode) tréning" : "",
            metronomeName: on ? metronome.selectedPreset.shortCode : "",
            bpm: metronome.effectiveBpm,
            beatsPerMeasure: on ? metronome.beatsPerMeasure : 0,
            audioLevel: 0
        )
    }
    #else
    static func start() {}
    static func update(elapsed: Int) {}
    static func end() {}
    #endif
}
