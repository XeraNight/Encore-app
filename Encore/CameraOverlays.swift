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
struct QuickSaveVideoSheet: View {
    @Environment(\.dismiss) private var dismiss
    let videoURL: URL
    let onTrimRequest: () -> Void
    let onSaveCompleted: (URL) -> Void
    
    @State private var selectedRole: VideoMediaRole = .myTake
    @State private var selectedTags: Set<String> = []
    @State private var videoTitle: String = "Záznam z tréningu"
    
    let availableTags = ["🦶 Chodidlá", "💃 Postúra & Rám", "🔄 Rotácia", "⏱️ Rytmus & Timing", "👔 Trénerov komentár", "⭐ Najlepší pokus"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        // Quick Trim Action Bar (Funkcia 8: Waze-Style Action Card)
                        Button {
                            HapticFeedback.light()
                            onTrimRequest()
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.amberGold.opacity(0.18))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "scissors")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(Color.amberGold)
                                }
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Orezať začiatok a koniec")
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                    Text("Odstrániť príchod k partnerke a odchod")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundColor(Color.textSecondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white.opacity(0.35))
                            }
                            .padding(14)
                            .background(Color(white: 0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        
                        // Role Selector (Waze-style 3 Segment Cards)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("ROLA ZÁZNAMU")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundColor(Color.amberGold)
                                .tracking(1.2)
                            
                            HStack(spacing: 10) {
                                roleButton(role: .myTake, title: "Moje video", icon: "person.fill", accentColor: Color(red: 0.95, green: 0.22, blue: 0.40))
                                roleButton(role: .targetIdol, title: "Vzor / Idol", icon: "star.fill", accentColor: Color.amberGold)
                                roleButton(role: .coach, title: "Tréner", icon: "figure.walk", accentColor: Color(red: 0.22, green: 0.55, blue: 0.96))
                            }
                        }
                        
                        // Quick Tag Chips (Waze-style filter pills)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("RÝCHLE ŠTÍTKY")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundColor(Color.amberGold)
                                .tracking(1.2)
                            
                            FlowLayout(spacing: 8) {
                                ForEach(availableTags, id: \.self) { tag in
                                    let isSelected = selectedTags.contains(tag)
                                    Button {
                                        HapticFeedback.light()
                                        if isSelected {
                                            selectedTags.remove(tag)
                                        } else {
                                            selectedTags.insert(tag)
                                        }
                                    } label: {
                                        Text(tag)
                                            .font(.system(size: 13, weight: isSelected ? .heavy : .semibold, design: .rounded))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(
                                                isSelected
                                                    ? Color.amberGold
                                                    : Color(white: 0.14)
                                            )
                                            .foregroundColor(isSelected ? .black : .white)
                                            .clipShape(Capsule())
                                            .overlay(
                                                Capsule()
                                                    .stroke(isSelected ? Color.amberGold : Color.white.opacity(0.14), lineWidth: 1)
                                            )
                                            .shadow(color: isSelected ? Color.amberGold.opacity(0.3) : Color.clear, radius: 6, y: 2)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        // Title Input (Waze-style Clean Input Card)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("NÁZOV")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundColor(Color.amberGold)
                                .tracking(1.2)
                            
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.white.opacity(0.10))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "pencil.line")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(Color.amberGold)
                                }
                                
                                TextField("", text: $videoTitle, prompt: Text("Zadaj názov videa...").foregroundColor(Color.white.opacity(0.45)))
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                    .accentColor(Color.amberGold)
                            }
                            .padding(12)
                            .background(Color(white: 0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                        }
                        
                        // Save Button (Waze-style Big Rounded CTA)
                        Button {
                            HapticFeedback.medium()
                            onSaveCompleted(videoURL)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18, weight: .bold))
                                Text("Uložiť do inventára")
                                    .font(.system(size: 16, weight: .black, design: .rounded))
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color.amberGold, Color(red: 0.95, green: 0.72, blue: 0.0)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.amberGold, lineWidth: 1)
                            )
                            .shadow(color: Color.amberGold.opacity(0.45), radius: 12, y: 4)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 10)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Detaily nového videa")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(LuxuryTheme.obsidian900, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        HapticFeedback.light()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.85))
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                }
            }
        }
    }
    
    private func roleButton(role: VideoMediaRole, title: String, icon: String, accentColor: Color) -> some View {
        let isSelected = (selectedRole == role)
        
        return Button {
            HapticFeedback.light()
            selectedRole = role
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? (role == .targetIdol ? Color.black.opacity(0.25) : Color.white.opacity(0.25)) : accentColor.opacity(0.18))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(isSelected ? (role == .targetIdol ? .black : .white) : accentColor)
                }
                
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .heavy : .bold, design: .rounded))
                    .foregroundColor(isSelected ? (role == .targetIdol ? .black : .white) : .white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                isSelected
                    ? accentColor
                    : Color(white: 0.12)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? accentColor : Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: isSelected ? accentColor.opacity(0.35) : Color.clear, radius: 8, y: 3)
        }
        .buttonStyle(.plain)
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

