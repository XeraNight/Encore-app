import SwiftUI
import AVFoundation
import AVKit

// MARK: - Grid & Gyroscope Level Overlay (Apple Camera & Measure Style)
struct CameraGridAndLevelOverlay: View {
    /// Read only here, so the level's readings redraw the overlay alone.
    let level: HorizonLevel

    private var tiltAngle: Double { level.rollAngle }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var isLevel: Bool { level.isLevel }
    private var isFlat: Bool { level.isFlat }
    private var flatOffset: CGPoint { level.flatOffset }

    var body: some View {
        ZStack {
            // 3x3 Composition Grid
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                
                Path { path in
                    // Vertical lines
                    path.move(to: CGPoint(x: w / 3, y: 0))
                    path.addLine(to: CGPoint(x: w / 3, y: h))
                    path.move(to: CGPoint(x: 2 * w / 3, y: 0))
                    path.addLine(to: CGPoint(x: 2 * w / 3, y: h))
                    
                    // Horizontal lines
                    path.move(to: CGPoint(x: 0, y: h / 3))
                    path.addLine(to: CGPoint(x: w, y: h / 3))
                    path.move(to: CGPoint(x: 0, y: 2 * h / 3))
                    path.addLine(to: CGPoint(x: w, y: 2 * h / 3))
                }
                .stroke(Color.white.opacity(0.20), lineWidth: 0.75)
            }
            
            // Apple-Style Center Horizon Level
            if !isFlat {
                ZStack {
                    // Fixed Reference Reticle (Notches on Left and Right)
                    HStack(spacing: 50) {
                        Rectangle()
                            .fill(Color.white.opacity(0.35))
                            .frame(width: 24, height: 1.5)
                        
                        Rectangle()
                            .fill(Color.white.opacity(0.35))
                            .frame(width: 24, height: 1.5)
                    }
                    // Along the edge the phone is held by, upright or on its side.
                    .rotationEffect(.degrees(-level.reference))

                    // Dynamic Rotating Horizon Line
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(isLevel ? Color.amberGold : Color.white.opacity(0.9))
                            .frame(width: 36, height: isLevel ? 2.5 : 1.5)
                        
                        Circle()
                            .fill(isLevel ? Color.amberGold : Color.white.opacity(0.9))
                            .frame(width: isLevel ? 6 : 4, height: isLevel ? 6 : 4)
                        
                        Rectangle()
                            .fill(isLevel ? Color.amberGold : Color.white.opacity(0.9))
                            .frame(width: 36, height: isLevel ? 2.5 : 1.5)
                    }
                    .rotationEffect(.degrees(-tiltAngle))
                    .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.85), value: tiltAngle)
                    
                    // Angle Badge Readout (e.g. 0° / 1.5°)
                    VStack {
                        Spacer()
                            .frame(height: 52)
                        
                        // Turned with the phone, so it reads the right way up on its side too.
                        Text(isLevel ? "0°" : HorizonLevel.text(-level.tilt))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(isLevel ? .black : .white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(isLevel ? Color.amberGold : Color.black.opacity(0.6))
                            .cornerRadius(6)
                            .animation(.easeInOut(duration: 0.2), value: isLevel)
                    }
                    .rotationEffect(.degrees(-level.reference))
                    .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8), value: level.reference)
                }
            } else {
                // Flat Table / Bullseye Measure Mode
                ZStack {
                    // Outer fixed ring
                    Circle()
                        .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 46, height: 46)
                    
                    // Center crosshair
                    Path { p in
                        p.move(to: CGPoint(x: 23, y: 17))
                        p.addLine(to: CGPoint(x: 23, y: 29))
                        p.move(to: CGPoint(x: 17, y: 23))
                        p.addLine(to: CGPoint(x: 29, y: 23))
                    }
                    .stroke(Color.white.opacity(0.4), lineWidth: 1)
                    .frame(width: 46, height: 46)
                    
                    // Inner floating bubble
                    Circle()
                        .fill(isLevel ? Color.amberGold : Color.white.opacity(0.85))
                        .frame(width: 14, height: 14)
                        .offset(x: flatOffset.x, y: flatOffset.y)
                        .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.85), value: flatOffset)
                }
            }
        }
    }
}

// MARK: - Quick Save Details & Tagging Sheet (Funkcia 10 & Waze-Inspired UI)
/// After a take (BRAND_GUIDELINES §1A): it plays on a loop, can be trimmed, and is saved where the camera was
/// opened from (Denník, the figure). Until then the clip exists only here, so closing never throws it away
/// without asking.
struct QuickSaveVideoSheet: View {
    let videoURL: URL
    let saveTitle: String
    let savesToPhotos: Bool
    let onTrimRequest: () -> Void
    let onSave: () async -> Void
    let onDiscard: () -> Void

    @State private var isSaving = false
    @State private var confirmDiscard = false

    var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        LoopingPlayback(videoURL: videoURL, rate: 1)
                            .id(videoURL)   // a trimmed take is a new file
                            .frame(height: 380)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.gold400.opacity(0.3), lineWidth: 1))

                        Button(action: onTrimRequest) {
                            HomeRow(icon: "scissors", title: "Orezať začiatok a koniec",
                                    subtitle: "Bez príchodu k partnerke a odchodu")
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .homeCard(cornerRadius: 18)
                        }
                        .buttonStyle(.pressable(scale: 0.98))

                        Text(savesToPhotos
                             ? "Video sa uloží do tvojich Fotiek v plnej kvalite, v albume Encore."
                             : "Video sa uloží v Encore v tomto iPhone.")
                            .font(.caption)
                            .foregroundColor(Color.textSecondary)
                    }
                    .padding(20)
                }
            }
            .safeAreaBar(edge: .bottom) {
                VStack(spacing: 10) {
                    PrimarySheetButton(title: saveTitle, isLoading: isSaving, isEnabled: !isSaving) {
                        isSaving = true
                        Task {
                            await onSave()
                            isSaving = false
                        }
                    }
                    Button("Zahodiť video", role: .destructive) { confirmDiscard = true }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color.latinRed)
                        .frame(minHeight: 44)
                        .disabled(isSaving)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
            .navigationTitle("Nové video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zavrieť") { confirmDiscard = true }
                        .disabled(isSaving)
                }
            }
            .confirmationDialog("Zahodiť toto video?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Zahodiť", role: .destructive, action: onDiscard)
                Button("Nechať", role: .cancel) {}
            } message: {
                Text("Ešte nie je uložené, nedá sa vrátiť.")
            }
        }
        .preferredColorScheme(.dark)
        // A swipe down would lose the take silently.
        .interactiveDismissDisabled()
    }
}

// MARK: - FlowLayout Helper for Tag Chips
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 300
        var height: CGFloat = 0
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowMaxH: CGFloat = 0
        
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if currentX + size.width > width && currentX > 0 {
                currentX = 0
                currentY += rowMaxH + spacing
                rowMaxH = 0
            }
            currentX += size.width + spacing
            rowMaxH = max(rowMaxH, size.height)
        }
        height = currentY + rowMaxH
        return CGSize(width: width, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowMaxH: CGFloat = 0
        
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentX = bounds.minX
                currentY += rowMaxH + spacing
                rowMaxH = 0
            }
            view.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            currentX += size.width + spacing
            rowMaxH = max(rowMaxH, size.height)
        }
    }
}

// MARK: - AVCapture Video Preview Layer Representable
/// The live picture and its gestures, in UIKit on the preview alone: a tap focuses, a long press locks focus and
/// exposure, a pinch zooms. The preview layer turns a touch into the camera's own coordinates (0 to 1, rotated
/// and cropped like the picture), which a point on the screen is not.
struct CameraPreviewRepresentable: UIViewRepresentable {
    let session: AVCaptureSession
    /// The touch in the camera's coordinates, where it is on the screen (for the focus square), and whether
    /// it was a long press.
    var onFocus: (_ devicePoint: CGPoint, _ screenPoint: CGPoint, _ lock: Bool) -> Void = { _, _, _ in }
    /// `began` at the start of a pinch, then the scale since it began.
    var onPinch: (_ began: Bool, _ scale: CGFloat) -> Void = { _, _ in }

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        let coordinator = context.coordinator
        view.addGestureRecognizer(UITapGestureRecognizer(target: coordinator, action: #selector(Coordinator.tapped(_:))))
        let press = UILongPressGestureRecognizer(target: coordinator, action: #selector(Coordinator.pressed(_:)))
        press.minimumPressDuration = 0.5
        view.addGestureRecognizer(press)
        view.addGestureRecognizer(UIPinchGestureRecognizer(target: coordinator, action: #selector(Coordinator.pinched(_:))))
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject {
        var parent: CameraPreviewRepresentable

        init(parent: CameraPreviewRepresentable) {
            self.parent = parent
        }

        @objc func tapped(_ gesture: UITapGestureRecognizer) {
            focus(from: gesture, lock: false)
        }

        @objc func pressed(_ gesture: UILongPressGestureRecognizer) {
            if gesture.state == .began { focus(from: gesture, lock: true) }
        }

        @objc func pinched(_ gesture: UIPinchGestureRecognizer) {
            switch gesture.state {
            case .began: parent.onPinch(true, 1)
            case .changed: parent.onPinch(false, gesture.scale)
            default: break
            }
        }

        private func focus(from gesture: UIGestureRecognizer, lock: Bool) {
            guard let view = gesture.view as? CameraPreviewUIView else { return }
            let point = gesture.location(in: view)
            parent.onFocus(view.videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: point), point, lock)
        }
    }
}

class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

// MARK: - Ghost Video Layer Representable
struct GhostPlayerRepresentable: UIViewControllerRepresentable {
    let player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspectFill
        controller.view.backgroundColor = .clear
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}

typealias GhostVideoPlayerView = GhostPlayerRepresentable

