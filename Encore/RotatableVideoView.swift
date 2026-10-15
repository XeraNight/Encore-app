import SwiftUI
import AVFoundation

/// Plain video layer (no system controls) so the picture can be turned in quarter steps like in Photos
/// without turning the controls with it. Tap pauses / resumes; a thin line shows the progress.
struct RotatableVideoView: View {
    let player: AVPlayer
    let rotation: Int
    let size: CGSize

    @State private var isPlaying = true
    @State private var progress: Double = 0
    @State private var timeObserver: Any?
    @State private var taps = 0

    private var isSideways: Bool { rotation % 180 != 0 }

    var body: some View {
        ZStack(alignment: .bottom) {
            PlayerLayerView(player: player)
                .frame(width: isSideways ? size.height : size.width,
                       height: isSideways ? size.width : size.height)
                .rotationEffect(.degrees(Double(rotation)))
                .frame(width: size.width, height: size.height)

            Rectangle()
                .fill(Color.white.opacity(0.18))
                .frame(height: 3)
                .overlay(alignment: .leading) {
                    Rectangle().fill(Color.gold400).frame(width: size.width * progress)
                }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            taps += 1
            if player.timeControlStatus == .paused { player.play() } else { player.pause() }
        }
        .overlay {
            if !isPlaying {
                Image(systemName: "play.fill")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .glassEffect(.regular, in: .circle)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPlaying)
        .sensoryFeedback(.impact(weight: .light), trigger: taps)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(isPlaying ? "Pozastaviť video" : "Prehrať video")
        .onAppear {
            timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { time in
                let total = player.currentItem?.duration.seconds ?? 0
                progress = total.isFinite && total > 0 ? min(max(time.seconds / total, 0), 1) : 0
                isPlaying = player.timeControlStatus != .paused
            }
        }
        .onDisappear {
            if let timeObserver { player.removeTimeObserver(timeObserver) }
            timeObserver = nil
        }
    }
}

private struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        if uiView.playerLayer.player !== player { uiView.playerLayer.player = player }
    }
}

private final class PlayerContainerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
