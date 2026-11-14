import AVKit
import UIKit

/// The whole screen is the iPhone's own player, as in Fotky: its controls, scrubbing, close and swipe down. The
/// picture is shown whole, upright or sideways. Used by the figure's video and by a video inside the notes.
@MainActor
enum FullScreenVideo {
    /// Shows a player that already exists (the figure's video keeps its place).
    static func present(_ player: AVPlayer) {
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              var top = scene.keyWindow?.rootViewController else { return }
        while let presented = top.presentedViewController { top = presented }
        let controller = AVPlayerViewController()
        controller.player = player
        controller.modalPresentationStyle = .fullScreen
        top.present(controller, animated: true) { player.play() }
    }

    /// Shows a video by its path (Denník, Fotky, a shared copy), with sound.
    static func present(path: String) async {
        guard let url = await MediaResolver.videoURL(path: path) else { return }
        try? await AudioSessionCoordinator.shared.activate(.player)
        present(AVPlayer(url: url))
    }
}
