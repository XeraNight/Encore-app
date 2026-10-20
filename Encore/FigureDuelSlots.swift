import AVKit
import SwiftUI

// MARK: - Duel on the figure screen
/// My video and the model's side by side, each with its own play button (BRAND_GUIDELINES §1A). Usually only
/// one of them exists, so a slot without a video offers to add one. "Porovnať naplno" opens the full
/// comparison (both in step, overlay, lines).
struct FigureDuelSlots: View {
    let myPath: String?
    let modelPath: String?
    let height: CGFloat
    let onAddMine: () -> Void
    let onAddModel: () -> Void
    let onCompare: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                DuelSlot(title: "Ja", path: myPath, addTitle: "Pridať moje", onAdd: onAddMine)
                DuelSlot(title: "Vzor", path: modelPath, addTitle: "Pridať vzor", onAdd: onAddModel)
            }
            .frame(height: height)

            if myPath != nil && modelPath != nil {
                Button(action: onCompare) {
                    Label("Porovnať naplno", systemImage: "rectangle.split.2x1")
                        .font(.footnote.weight(.bold))
                        .foregroundColor(Color.obsidian900)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 40)
                        .background(Color.gold400, in: Capsule())
                }
                .buttonStyle(.pressable)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: modelPath)
    }
}

/// One video of the duel: plays muted in a loop when started, so music in the hall keeps playing.
private struct DuelSlot: View {
    let title: String
    let path: String?
    let addTitle: String
    let onAdd: () -> Void

    @State private var player: AVPlayer?
    @State private var image: UIImage?
    @State private var isPlaying = false
    @State private var isMissing = false
    @State private var loopObserver: (any NSObjectProtocol)?

    var body: some View {
        ZStack {
            Color.black.opacity(0.88)
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
            } else if let player {
                CustomAVPlayerRepresentable(player: player, gravity: .resizeAspect)
                    .contentShape(Rectangle())
                    .onTapGesture { toggle() }
            } else if path == nil {
                emptySlot
            } else if isMissing {
                Label("Video sa nenašlo", systemImage: "video.slash.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.75))
            } else {
                ProgressView().tint(.white)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(alignment: .topLeading) {
            Text(title.uppercased())
                .font(.system(.caption2, design: .rounded).weight(.black))
                .tracking(1.2)
                .foregroundColor(Color.gold400)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.45), in: Capsule())
                .padding(8)
        }
        .overlay(alignment: .bottom) {
            if player != nil {
                Button(action: toggle) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color.obsidian900)
                        .frame(width: 44, height: 44)
                        .background(Color.gold400, in: Circle())
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.pressable(scale: 0.88))
                .padding(.bottom, 10)
                .accessibilityLabel(isPlaying ? "Pozastaviť \(title)" : "Prehrať \(title)")
            }
        }
        .sensoryFeedback(.selection, trigger: isPlaying)
        .task(id: path) { await load() }
        .onDisappear { unload() }
    }

    private var emptySlot: some View {
        VStack(spacing: 10) {
            Image(systemName: "video.badge.plus")
                .font(.title2)
                .foregroundColor(Color.gold400)
            Button(action: onAdd) {
                Text(addTitle)
                    .font(.footnote.weight(.bold))
                    .foregroundColor(Color.obsidian900)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 40)
                    .background(Color.gold400, in: Capsule())
            }
            .buttonStyle(.pressable)
        }
        .padding(8)
    }

    private func toggle() {
        guard let player else { return }
        if isPlaying { player.pause() } else { player.play() }
        isPlaying.toggle()
    }

    private func load() async {
        unload()
        isMissing = false
        guard let path else { return }
        if MediaResolver.isImagePath(path: path) {
            image = MediaResolver.resolveImage(path: path)
            isMissing = image == nil
            return
        }
        guard let url = await MediaResolver.videoURL(path: path) else {
            isMissing = true
            return
        }
        let newPlayer = AVPlayer(url: url)
        newPlayer.isMuted = true
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: newPlayer.currentItem, queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                newPlayer.seek(to: .zero)
                newPlayer.play()
            }
        }
        player = newPlayer
    }

    private func unload() {
        player?.pause()
        if let loopObserver { NotificationCenter.default.removeObserver(loopObserver) }
        loopObserver = nil
        player = nil
        image = nil
        isPlaying = false
    }
}
