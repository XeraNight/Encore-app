import SwiftUI
import AVFoundation
import AVKit

// MARK: - Live Audio VU Meter (Funkcia 7)
struct CameraVUMeterView: View {
    let audioLevel: Float // 0.0 to 1.0
    
    var body: some View {
        HStack(spacing: 2.5) {
            Image(systemName: "mic.fill")
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.75))
                .padding(.trailing, 2)
            
            ForEach(0..<8, id: \.self) { idx in
                let threshold = Float(idx) / 8.0
                Rectangle()
                    .fill(barColor(for: idx, isActive: audioLevel > threshold))
                    .frame(width: 3, height: 9 + CGFloat(idx))
                    .cornerRadius(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.black.opacity(0.65))
        .cornerRadius(14)
        .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
    }
    
    private func barColor(for index: Int, isActive: Bool) -> Color {
        guard isActive else { return Color.white.opacity(0.18) }
        if index < 5 {
            return Color.green
        } else if index < 7 {
            return Color.amberGold
        } else {
            return Color.red
        }
    }
}

// MARK: - Grid & Gyroscope Level Overlay (Apple Camera & Measure Style)
struct CameraGridAndLevelOverlay: View {
    let tiltAngle: Double // in degrees
    let isLevel: Bool
    let isFlat: Bool
    let flatOffset: CGPoint
    
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
                        
                        Text(isLevel ? "0°" : String(format: "%+.1f°", -tiltAngle))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(isLevel ? .black : .white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(isLevel ? Color.amberGold : Color.black.opacity(0.6))
                            .cornerRadius(6)
                            .animation(.easeInOut(duration: 0.2), value: isLevel)
                    }
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
struct CameraPreviewRepresentable: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {}
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

