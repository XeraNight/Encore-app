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
    /// Turns a recording made with the iPhone on its side into a landscape video (the app itself stays portrait).
    private var rotation: AVCaptureDevice.RotationCoordinator?
    /// The device zoom factor of 1× on a virtual camera: its own 1 is the ultra wide, the main lens starts at 2.
    private var wideZoomFactor: CGFloat = 1

    /// What the lens can do, for the zoom buttons.
    struct Lens: Sendable {
        var hasUltraWide: Bool
        var maxZoom: Double
    }

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
        if let camera = Self.camera(front: false),
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
        prepareCurrentCamera(front: false)
    }

    /// The back camera that films a whole couple best: a virtual camera with the ultra wide (0.5×) when the
    /// iPhone has one, then the main lens alone.
    private static func camera(front: Bool) -> AVCaptureDevice? {
        let types: [AVCaptureDevice.DeviceType] = front
            ? [.builtInWideAngleCamera]
            : [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera]
        for type in types {
            if let device = AVCaptureDevice.default(type, for: .video, position: front ? .front : .back) { return device }
        }
        return nil
    }

    /// 1080p at up to 60 frames a second (smooth for slow motion, a third of 4K's size), HEVC, stabilised, with
    /// smooth focus so a moving couple does not make the picture "breathe".
    private func prepareCurrentCamera(front: Bool) {
        guard let device = videoInput?.device else { return }
        let ultraWide = device.constituentDevices.contains { $0.deviceType == .builtInUltraWideCamera }
        wideZoomFactor = ultraWide ? device.virtualDeviceSwitchOverVideoZoomFactors.first.map { CGFloat(truncating: $0) } ?? 2 : 1
        rotation = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            if let format = Self.videoFormat(of: device) {
                device.activeFormat = format
                device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 60)
                // Down to 30 frames in a dim hall, for a brighter picture.
                device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
            }
            if device.isSmoothAutoFocusSupported { device.isSmoothAutoFocusEnabled = true }
            if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
            if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
            device.videoZoomFactor = min(max(wideZoomFactor, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
        } catch {
            Logger.camera.error("Camera setup failed: \(error.localizedDescription, privacy: .public)")
        }
        guard let connection = movieOutput.connection(with: .video) else { return }
        if connection.isVideoStabilizationSupported { connection.preferredVideoStabilizationMode = .auto }
        // The front camera records mirrored, like a dance-studio mirror.
        if connection.isVideoMirroringSupported { connection.isVideoMirrored = front }
        if movieOutput.availableVideoCodecTypes.contains(.hevc) {
            movieOutput.setOutputSettings([AVVideoCodecKey: AVVideoCodecType.hevc], for: connection)
        }
    }

    private static func videoFormat(of device: AVCaptureDevice) -> AVCaptureDevice.Format? {
        let eightBit: Set<FourCharCode> = [kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        return device.formats.first { format in
            let size = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            return size.width == 1920 && size.height == 1080
                && eightBit.contains(CMFormatDescriptionGetMediaSubType(format.formatDescription))
                && format.videoSupportedFrameRateRanges.contains { $0.maxFrameRate >= 60 }
        }
    }

    func lens() -> Lens {
        guard let device = videoInput?.device else { return Lens(hasUltraWide: false, maxZoom: 1) }
        let limit = min(device.maxAvailableVideoZoomFactor / wideZoomFactor, 10)
        return Lens(hasUltraWide: wideZoomFactor > 1, maxZoom: Double(limit))
    }

    func switchCamera(front: Bool) {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        let previous = videoInput
        if let previous { session.removeInput(previous) }
        guard let camera = Self.camera(front: front),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else {
            if let previous, session.canAddInput(previous) { session.addInput(previous) }
            return
        }
        session.addInput(input)
        videoInput = input
        prepareCurrentCamera(front: front)
    }

    /// `level` as dancers read it: 1 is the main lens, 0.5 the ultra wide. A button glides there, a pinch follows
    /// the fingers.
    func setZoom(_ level: Double, smoothly: Bool) {
        guard let device = videoInput?.device else { return }
        let factor = min(max(CGFloat(level) * wideZoomFactor, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
        do {
            try device.lockForConfiguration()
            if smoothly {
                device.ramp(toVideoZoomFactor: factor, withRate: 8)
            } else {
                device.cancelVideoZoomRamp()
                device.videoZoomFactor = factor
            }
            device.unlockForConfiguration()
        } catch {
            Logger.camera.error("Zoom failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Focuses and exposes where the dancer tapped (a point in the camera's own 0–1 coordinates). After a tap,
    /// the camera follows the whole picture again when the scene changes; a long press (`lock`) keeps it, for a
    /// camera on a tripod and a couple dancing at the same distance.
    func focus(at point: CGPoint, lock: Bool) {
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
            device.isSubjectAreaChangeMonitoringEnabled = !lock
            device.unlockForConfiguration()
        } catch {
            Logger.camera.error("Focus failed: \(error.localizedDescription, privacy: .public)")
        }
        subjectAreaWatch?.cancel()
        if !lock { watchSubjectArea(of: device) }
    }

    /// After a tap the focus holds until the picture changes (the couple moves away); then it follows again.
    private func watchSubjectArea(of device: AVCaptureDevice) {
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
        if let connection = movieOutput.connection(with: .video),
           let angle = rotation?.videoRotationAngleForHorizonLevelCapture,
           connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
        // The movie output writes QuickTime, so the file says .mov.
        let url = URL.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mov")
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
    /// The zoom as dancers read it: 1 is the main lens, 0.5 the ultra wide.
    private(set) var zoom: Double = 1
    /// Until the camera reports its lens; the front camera has no ultra wide.
    private(set) var hasUltraWide = false
    private(set) var maxZoom: Double = 2
    /// A long press holds focus and exposure where it was; a tap lets them follow again.
    private(set) var isFocusLocked = false
    private(set) var isTorchOn = false
    private(set) var isFront = false

    @ObservationIgnored private let capture = CaptureService()
    @ObservationIgnored private var clock: Task<Void, Never>?
    @ObservationIgnored private var countdownTask: Task<Void, Never>?
    @ObservationIgnored private var metronomeChanges: AnyCancellable?
    @ObservationIgnored private var pinchStartZoom: Double = 1

    nonisolated var session: AVCaptureSession { capture.session }

    /// "01:05" for 65 seconds.
    static func clockText(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    func start() {
        Task {
            await capture.start()
            await readLens()
        }
    }

    private func readLens() async {
        let lens = await capture.lens()
        hasUltraWide = lens.hasUltraWide
        maxZoom = lens.maxZoom
        zoom = 1
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

    func setZoom(_ preset: CameraZoomFactor) {
        zoom = preset.rawValue
        Task { await capture.setZoom(preset.rawValue, smoothly: true) }
    }

    func pinchBegan() {
        pinchStartZoom = zoom
    }

    func pinchChanged(scale: CGFloat) {
        let level = min(max(pinchStartZoom * Double(scale), hasUltraWide ? 0.5 : 1), maxZoom)
        zoom = level
        Task { await capture.setZoom(level, smoothly: false) }
    }

    func focus(at point: CGPoint, lock: Bool) {
        isFocusLocked = lock
        Task { await capture.focus(at: point, lock: lock) }
    }

    func toggleTorch() {
        isTorchOn.toggle()
        let on = isTorchOn
        Task { await capture.setTorch(on) }
    }

    func flipCamera() {
        isFront.toggle()
        isFocusLocked = false
        let front = isFront
        Task {
            await capture.switchCamera(front: front)
            await readLens()
        }
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
