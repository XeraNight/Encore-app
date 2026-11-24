import AVKit
import UIKit

/// The whole screen is the iPhone's own player, as in Fotky: its controls, scrubbing, close and swipe down. The
/// picture is shown whole, upright or sideways. Used by the figure's video and by a video inside the notes.
@MainActor
enum FullScreenVideo {
    /// Shows a player that already exists (the figure's video keeps its place and its own audio session).
    static func present(_ player: AVPlayer) {
        _ = show(player)
    }

    /// Shows a video by its path (Denník, Fotky, a shared copy), with sound, and returns once it is closed. It takes the
    /// audio session while it plays and gives it back at the end, so music that was playing (Spotify in the hall) goes on.
    static func present(path: String) async {
        guard let url = await MediaResolver.videoURL(path: path) else { return }
        try? await AudioSessionCoordinator.shared.activate(.player)
        let player = AVPlayer(url: url)
        if let controller = show(player) { await untilClosed(controller) }
        player.pause()
        await AudioSessionCoordinator.shared.deactivate(.player)
    }

    /// The player's screen, or nil when there is no screen to show it on.
    private static func show(_ player: AVPlayer) -> AVPlayerViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              var top = scene.keyWindow?.rootViewController else { return nil }
        while let presented = top.presentedViewController { top = presented }
        let controller = AVPlayerViewController()
        controller.player = player
        controller.modalPresentationStyle = .fullScreen
        top.present(controller, animated: true) { player.play() }
        return controller
    }

    /// UIKit says nothing when the iPhone's own player is closed (it cannot be subclassed, and its dismissal delegate calls
    /// are unavailable on iOS), so this looks twice a second for as long as the video is open.
    private static func untilClosed(_ controller: AVPlayerViewController) async {
        while controller.presentingViewController != nil {
            do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
        }
    }
}
