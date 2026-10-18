import SwiftUI
import AVFoundation
import UIKit
import Combine

// MARK: - Zrkadlo (Nástroje)
/// Full-screen front camera for checking hold, posture, hair and make-up. Sharp enough for brows and lips (4K),
/// pinch or double tap to look closer. The light is a soft glow from the screen edges with an adjustable colour
/// (make-up looks different in warm and cool light) and strength. No microphone, so music keeps playing,
/// and the screen stays on while the mirror is open.
public struct DanceMirrorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var cameraManager = DanceMirrorCameraManager()

    @State private var isLightOn = false
    @State private var showsLightPanel = false
    @State private var brightnessBeforeLight: CGFloat?
    @State private var showsHint = true
    @State private var zoomAtPinchStart: CGFloat?
    @State private var showsZoomLabel = false
    @State private var zoomTaps = 0
    /// 0 = warm (tungsten), 0.5 = neutral daylight, 1 = cool.
    @AppStorage("mirror.lightWarmth") private var warmth = 0.45
    /// 0 = a thin glow at the edge, 1 = a wide one.
    @AppStorage("mirror.lightIntensity") private var intensity = 0.4

    public init() {}

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if cameraManager.isCameraAvailable {
                GeometryReader { geo in
                    DanceMirrorPreviewRepresentable(session: cameraManager.session)
                        .ignoresSafeArea()
                        .onTapGesture(count: 2) {
                            zoomTaps += 1
                            cameraManager.toggleZoom()
                            flashZoomLabel()
                        }
                        .onTapGesture(count: 1) { location in
                            guard geo.size.width > 0 && geo.size.height > 0 else { return }
                            cameraManager.focusAndExpose(at: CGPoint(
                                x: max(0, min(1, location.x / geo.size.width)),
                                y: max(0, min(1, location.y / geo.size.height))
                            ))
                        }
                        .gesture(pinchToZoom)
                }
                .ignoresSafeArea()
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.largeTitle)
                        .foregroundColor(Color.gold400)
                    Text("Zrkadlo")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundColor(.white)
                    Text("Predná kamera nie je dostupná. Povoľ Encore prístup ku kamere v Nastaveniach iPhonu.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 36)
                }
            }

            if isLightOn {
                MirrorEdgeLight(color: MirrorEdgeLight.color(warmth: warmth), intensity: intensity)
                    .transition(.opacity)
            }

            VStack(spacing: 12) {
                topBar
                if showsZoomLabel {
                    Text(Double(cameraManager.currentZoom).formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "sk"))) + "×")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .glassEffect(.regular, in: .capsule)
                        .contentTransition(.numericText())
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
                Spacer()
                if showsHint && cameraManager.isCameraAvailable {
                    Text("Ťukni pre zaostrenie · roztiahni prsty alebo ťukni dvakrát pre priblíženie")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .glassEffect(.regular, in: .capsule)
                        .padding(.horizontal, 24)
                        .transition(.opacity)
                }
                lightControls
                if isLightOn && showsLightPanel {
                    lightPanel
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .statusBarHidden(true)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: isLightOn)
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85), value: showsLightPanel)
        .animation(.easeOut(duration: 0.25), value: showsZoomLabel)
        .animation(.easeOut(duration: 0.4), value: showsHint)
        .sensoryFeedback(.selection, trigger: isLightOn)
        .sensoryFeedback(.impact(weight: .light), trigger: zoomTaps)
        .task {
            try? await Task.sleep(for: .seconds(4))
            showsHint = false
        }
        .onAppear {
            cameraManager.start()
            // Nobody touches a mirror: without this the screen dims and locks after a minute.
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            setLight(false)
            cameraManager.stop()
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: scenePhase) { _, phase in
            guard isLightOn else { return }
            // Away from Encore the user's own brightness comes back; on return the light is full again.
            setScreenBrightness(full: phase == .active)
        }
    }

    // MARK: Top bar
    private var topBar: some View {
        HStack {
            LiquidGlassCircleButton(icon: "xmark", label: "Zavrieť") { dismiss() }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: Light controls
    /// At the bottom, in reach of the thumb. They rise above the light settings while those are open and
    /// drop back when they close (the VStack moves them, animated by `showsLightPanel`).
    private var lightControls: some View {
        HStack(spacing: 14) {
            LiquidGlassCircleButton(
                icon: isLightOn ? "sun.max.fill" : "sun.max",
                label: isLightOn ? "Vypnúť svetlo" : "Zapnúť svetlo",
                isActive: isLightOn
            ) {
                setLight(!isLightOn)
                showsLightPanel = isLightOn
            }
            if isLightOn {
                LiquidGlassCircleButton(
                    icon: "slider.horizontal.3",
                    label: showsLightPanel ? "Skryť nastavenie svetla" : "Nastaviť svetlo",
                    isActive: showsLightPanel
                ) { showsLightPanel.toggle() }
                .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .padding(.bottom, isLightOn && showsLightPanel ? 0 : 28)
    }

    // MARK: Light settings
    private var lightPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            lightSlider(
                title: "Farba svetla",
                value: $warmth,
                left: ("Teplé", "sun.horizon.fill", MirrorEdgeLight.color(warmth: 0)),
                right: ("Studené", "snowflake", MirrorEdgeLight.color(warmth: 1))
            )
            lightSlider(
                title: "Sila",
                value: $intensity,
                left: ("Jemné", "light.min", .white.opacity(0.7)),
                right: ("Silné", "light.max", .white)
            )
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }

    private func lightSlider(title: String, value: Binding<Double>,
                             left: (String, String, Color), right: (String, String, Color)) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(.caption2, design: .rounded).weight(.black))
                .tracking(1.2)
                .foregroundColor(Color.gold400)
            HStack(spacing: 10) {
                Image(systemName: left.1)
                    .foregroundStyle(left.2)
                    .accessibilityHidden(true)
                Slider(value: value, in: 0...1)
                    .tint(Color.gold400)
                    .accessibilityLabel(title)
                    .accessibilityValue(value.wrappedValue < 0.34 ? left.0 : value.wrappedValue > 0.66 ? right.0 : "Stredné")
                Image(systemName: right.1)
                    .foregroundStyle(right.2)
                    .accessibilityHidden(true)
            }
            .font(.subheadline.weight(.semibold))
            // A soft tick every tenth, so the change is felt as well as seen.
            .sensoryFeedback(.selection, trigger: Int(value.wrappedValue * 10))
        }
    }

    // MARK: Zoom
    private var pinchToZoom: some Gesture {
        MagnifyGesture()
            .onChanged { gesture in
                let start = zoomAtPinchStart ?? cameraManager.currentZoom
                zoomAtPinchStart = start
                cameraManager.setZoom(start * gesture.magnification)
                showsZoomLabel = true
            }
            .onEnded { _ in
                zoomAtPinchStart = nil
                flashZoomLabel()
            }
    }

    private func flashZoomLabel() {
        showsZoomLabel = true
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            if zoomAtPinchStart == nil { showsZoomLabel = false }
        }
    }

    // MARK: Brightness
    /// Full brightness while the light is on; the previous brightness comes back afterwards.
    private func setLight(_ on: Bool) {
        guard on != isLightOn else { return }
        if on {
            brightnessBeforeLight = currentScreen?.brightness
            isLightOn = true
            setScreenBrightness(full: true)
        } else {
            setScreenBrightness(full: false)
            brightnessBeforeLight = nil
            isLightOn = false
        }
    }

    private func setScreenBrightness(full: Bool) {
        guard let screen = currentScreen else { return }
        if full {
            screen.brightness = 1.0
        } else if let previous = brightnessBeforeLight {
            screen.brightness = previous
        }
    }

    private var currentScreen: UIScreen? {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen
    }
}

// MARK: - Edge light
/// Light from the screen edges like a ring light: brightest at the very edge, fading softly inward,
/// never a hard frame over the picture.
private struct MirrorEdgeLight: View {
    let color: Color
    /// 0…1
    let intensity: Double

    /// Warm tungsten (0) through neutral daylight (0.5) to cool (1).
    static func color(warmth: Double) -> Color {
        let warm = (r: 1.0, g: 0.80, b: 0.58)
        let neutral = (r: 1.0, g: 0.97, b: 0.92)
        let cool = (r: 0.86, g: 0.93, b: 1.0)
        let (from, to, t) = warmth < 0.5 ? (warm, neutral, warmth * 2) : (neutral, cool, (warmth - 0.5) * 2)
        return Color(red: from.r + (to.r - from.r) * t,
                     green: from.g + (to.g - from.g) * t,
                     blue: from.b + (to.b - from.b) * t)
    }

    var body: some View {
        GeometryReader { geo in
            let short = min(geo.size.width, geo.size.height)
            // From 3 % to 12 % of the short side of the screen: a glow at the edge, the face stays clear.
            let band = short * (0.03 + 0.09 * intensity)
            let shape = RoundedRectangle(cornerRadius: 56, style: .continuous)
            ZStack {
                shape
                    .strokeBorder(color.opacity(0.85), lineWidth: band)
                    .blur(radius: band * 0.35)
                shape
                    .strokeBorder(color, lineWidth: band * 0.4)
                    .blur(radius: band * 0.06)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Front Camera Preview UIKit Wrapper
private struct DanceMirrorPreviewRepresentable: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> DanceMirrorPreviewUIView {
        let view = DanceMirrorPreviewUIView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        if let connection = view.videoPreviewLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
        return view
    }
    
    func updateUIView(_ uiView: DanceMirrorPreviewUIView, context: Context) {
        if let connection = uiView.videoPreviewLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
    }
}

private final class DanceMirrorPreviewUIView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

// MARK: - Camera Manager (Dedicated to Front Camera, No Mic / Audio Session)
final class DanceMirrorCameraManager: NSObject, ObservableObject, @unchecked Sendable {
    let session = AVCaptureSession()
    private var videoInput: AVCaptureDeviceInput?
    private let sessionQueue = DispatchQueue(label: "com.encore.mirror.sessionQueue")
    
    @Published var isRunning = false
    @Published var isCameraAvailable = true
    @Published var currentZoom: CGFloat = 1.0
    
    override init() {
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.session.beginConfiguration()

            // Acquire front camera device
            if let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
               let input = try? AVCaptureDeviceInput(device: frontCamera),
               self.session.canAddInput(input) {
                self.session.addInput(input)
                self.videoInput = input
                self.configureForBestPicture(frontCamera)
                DispatchQueue.main.async {
                    self.isCameraAvailable = true
                }
            } else {
                DispatchQueue.main.async {
                    self.isCameraAvailable = false
                }
            }
            
            self.session.commitConfiguration()
        }
    }
    
    /// The sharpest live picture the front camera offers (4K when supported, otherwise 1080p) for make-up
    /// details, with automatic HDR and low-light boost.
    private func configureForBestPicture(_ device: AVCaptureDevice) {
        if session.canSetSessionPreset(.hd4K3840x2160) {
            session.sessionPreset = .hd4K3840x2160
        } else if session.canSetSessionPreset(.hd1920x1080) {
            session.sessionPreset = .hd1920x1080
        } else {
            session.sessionPreset = .high
        }

        guard (try? device.lockForConfiguration()) != nil else { return }
        defer { device.unlockForConfiguration() }
        if device.activeFormat.isVideoHDRSupported {
            device.automaticallyAdjustsVideoHDREnabled = true
        }
        if device.isLowLightBoostSupported {
            device.automaticallyEnablesLowLightBoostWhenAvailable = true
        }
        // 30 frames per second: smooth enough for a mirror, and the phone stays cooler than at 60.
        if device.activeFormat.videoSupportedFrameRateRanges.contains(where: { $0.minFrameRate <= 30 && $0.maxFrameRate >= 30 }) {
            let frame = CMTime(value: 1, timescale: 30)
            device.activeVideoMinFrameDuration = frame
            device.activeVideoMaxFrameDuration = frame
        }
    }

    func start() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            guard !self.session.isRunning else { return }
            self.session.startRunning()
            DispatchQueue.main.async {
                self.isRunning = self.session.isRunning
            }
        }
    }
    
    func stop() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            guard self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async {
                self.isRunning = false
            }
        }
    }
    
    /// Closest zoom: with a 4K picture brows and lashes stay sharp up to about 4×.
    private static let maxZoom: CGFloat = 4

    func toggleZoom() {
        guard let device = videoInput?.device else { return }
        let target: CGFloat = currentZoom > 1.2 ? 1.0 : 2.0
        let clamped = max(1.0, min(target, device.activeFormat.videoMaxZoomFactor, Self.maxZoom))
        guard (try? device.lockForConfiguration()) != nil else { return }
        device.ramp(toVideoZoomFactor: clamped, withRate: 4.0)
        device.unlockForConfiguration()
        currentZoom = clamped
    }

    /// Follows the fingers while pinching.
    func setZoom(_ factor: CGFloat) {
        guard let device = videoInput?.device else { return }
        let clamped = max(1.0, min(factor, device.activeFormat.videoMaxZoomFactor, Self.maxZoom))
        guard (try? device.lockForConfiguration()) != nil else { return }
        device.videoZoomFactor = clamped
        device.unlockForConfiguration()
        currentZoom = clamped
    }
    
    func focusAndExpose(at point: CGPoint) {
        guard let device = videoInput?.device else { return }
        do {
            try device.lockForConfiguration()
            if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
            }
            if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.autoExpose) {
                device.exposurePointOfInterest = point
                device.exposureMode = .autoExpose
            }
            device.unlockForConfiguration()
        } catch {
            // Silently ignore configuration errors
        }
    }
}
