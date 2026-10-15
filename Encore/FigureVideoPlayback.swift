import AVFoundation
import Combine
import MediaPlayer
import SwiftUI

// MARK: - Figure video playback
/// Plays the video of one figure. It lives outside the figure card, so once the sound is on the video keeps
/// playing when the dancer leaves the canvas: a mini player above the tab bar, and Lock Screen, Control Center
/// and the Dynamic Island while Encore is in the background.
/// A video starts muted, so music already playing in the hall keeps going; sound is one tap away.
@MainActor
final class FigureVideoPlayback: ObservableObject {
    static let shared = FigureVideoPlayback()

    @Published private(set) var player: AVQueuePlayer?
    @Published private(set) var nodeId: UUID?
    @Published private(set) var title = ""
    @Published private(set) var subtitle = ""
    @Published private(set) var isPlaying = false
    @Published private(set) var isMuted = true
    /// The figure card with this video is on screen; the mini player waits until it closes.
    @Published private(set) var isShownInCard = false

    private var looper: AVPlayerLooper?
    private var url: URL?
    private var statusObservation: NSKeyValueObservation?
    private var remoteCommandsReady = false

    private init() {}

    /// A video with sound plays on after its card closed.
    var showsMiniPlayer: Bool { player != nil && !isShownInCard && !isMuted }

    /// The card of this figure is opening: the mini player hides right away, before the video is looked up.
    func cardDidOpen(nodeId: UUID) {
        if self.nodeId == nodeId { isShownInCard = true }
    }

    /// The card shows this figure's video. The same video keeps playing (sound and position included).
    func show(url: URL, nodeId: UUID, title: String, subtitle: String) {
        isShownInCard = true
        self.title = title
        self.subtitle = subtitle
        if self.nodeId == nodeId, self.url == url, player != nil { return }

        stop()
        let queue = AVQueuePlayer()
        queue.isMuted = true
        // Keeps the sound going when Encore goes to the background (needs the audio background mode).
        queue.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible
        looper = AVPlayerLooper(player: queue, templateItem: AVPlayerItem(url: url))
        statusObservation = queue.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            let playing = player.timeControlStatus != .paused
            Task { @MainActor in self?.playbackChanged(playing) }
        }
        player = queue
        self.url = url
        self.nodeId = nodeId
        isMuted = true
        Task {
            try? await AudioSessionCoordinator.shared.activate(.mutedVideo)
            guard player === queue else { return }
            queue.play()
        }
    }

    /// The card closed: a silent video stops, a video with sound plays on in the mini player.
    /// Without the mini player (iOS 26.0) the video always stops, so sound never plays with no way to stop it.
    func cardDidClose(nodeId: UUID) {
        guard self.nodeId == nodeId else { return }
        isShownInCard = false
        if isMuted || !Self.hasMiniPlayer { stop() }
    }

    private static var hasMiniPlayer: Bool {
        if #available(iOS 26.1, *) { true } else { false }
    }

    func togglePlay() {
        guard let player else { return }
        if player.timeControlStatus == .paused { player.play() } else { player.pause() }
    }

    func toggleSound() {
        guard let player else { return }
        let muted = !isMuted
        isMuted = muted
        player.isMuted = muted
        Task {
            // Sound on takes the speaker (stopping other music, like any video app); sound off gives it back.
            try? await AudioSessionCoordinator.shared.activate(muted ? .mutedVideo : .player)
        }
        if muted {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        } else {
            prepareRemoteCommands()
            updateNowPlaying()
        }
    }

    /// Stops only when this figure is the one playing (closed, deleted, video replaced).
    func stop(nodeId: UUID) {
        if self.nodeId == nodeId { stop() }
    }

    func stop() {
        statusObservation = nil
        player?.pause()
        looper = nil
        player = nil
        url = nil
        nodeId = nil
        isPlaying = false
        isMuted = true
        isShownInCard = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        Task {
            await AudioSessionCoordinator.shared.deactivate(.player)
            await AudioSessionCoordinator.shared.deactivate(.mutedVideo)
        }
    }

    private func playbackChanged(_ playing: Bool) {
        guard isPlaying != playing else { return }
        isPlaying = playing
        if !isMuted { updateNowPlaying() }
    }

    // MARK: Lock Screen, Control Center, Dynamic Island

    /// No duration or elapsed time: the clip loops, so a progress bar would only jump back.
    private func updateNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: subtitle,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.video.rawValue,
        ]
    }

    private func prepareRemoteCommands() {
        guard !remoteCommandsReady else { return }
        remoteCommandsReady = true
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.player?.play() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.player?.pause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlay() }
            return .success
        }
        center.nextTrackCommand.isEnabled = false
        center.previousTrackCommand.isEnabled = false
    }
}

// MARK: - Mini player above the tab bar
/// Figure name, play / pause and close, like the mini player in Music.
struct FigureMiniPlayer: View {
    @ObservedObject private var playback = FigureVideoPlayback.shared

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.dance")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.gold400)
                .symbolEffect(.bounce, options: .repeating.speed(0.4), isActive: playback.isPlaying)
                .frame(width: 32, height: 32)
                .background(Color.gold500.opacity(0.16), in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(playback.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(playback.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            Button(action: playback.togglePlay) {
                Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.pressable(scale: 0.85))
            .accessibilityLabel(playback.isPlaying ? "Pozastaviť" : "Prehrať")

            Button(action: playback.stop) {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.pressable(scale: 0.85))
            .accessibilityLabel("Zastaviť video")
        }
        .padding(.horizontal, 12)
        .sensoryFeedback(.selection, trigger: playback.isPlaying)
    }
}

extension View {
    /// Shows the figure mini player above the tab bar while a figure video with sound plays elsewhere.
    @ViewBuilder
    func figureMiniPlayer() -> some View {
        if #available(iOS 26.1, *) {
            modifier(FigureMiniPlayerAccessory())
        } else {
            self
        }
    }
}

@available(iOS 26.1, *)
private struct FigureMiniPlayerAccessory: ViewModifier {
    @ObservedObject private var playback = FigureVideoPlayback.shared

    func body(content: Content) -> some View {
        content.tabViewBottomAccessory(isEnabled: playback.showsMiniPlayer) {
            FigureMiniPlayer()
        }
    }
}
