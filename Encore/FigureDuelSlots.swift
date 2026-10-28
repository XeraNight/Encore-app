import AVKit
import Combine
import SwiftUI

// MARK: - Duel on the figure screen
/// My video and the model's side by side (BRAND_GUIDELINES §1A). Each plays on its own, or both start at
/// the same instant ("Prehrať obe") to compare right here; sound comes from one of them at most, two would
/// play the same music twice. A slot without a video offers to add one; "Naplno" opens the full comparison
/// (alignment, overlay, lines).
struct FigureDuelSlots: View {
    let myPath: String?
    let modelPath: String?
    let height: CGFloat
    let onAddMine: () -> Void
    let onAddModel: () -> Void
    let onCompare: () -> Void

    @StateObject private var duel = DuelPlayback()

    private var hasBoth: Bool { myPath != nil && modelPath != nil }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                DuelSlot(side: .mine, title: "Ja", path: myPath, addTitle: "Pridať moje", duel: duel, onAdd: onAddMine)
                DuelSlot(side: .model, title: "Vzor", path: modelPath, addTitle: "Pridať vzor", duel: duel, onAdd: onAddModel)
            }
            .frame(height: height)

            if hasBoth {
                controls.transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: hasBoth)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: duel.canPlayTogether)
        .onDisappear { duel.stopAll() }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            if duel.canPlayTogether {
                Button { duel.toggleTogether() } label: {
                    Label(duel.isTogether ? "Pozastaviť" : "Prehrať obe",
                          systemImage: duel.isTogether ? "pause.fill" : "play.fill")
                        .font(.footnote.weight(.bold))
                        .foregroundColor(Color.obsidian900)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .background(Color.gold400, in: Capsule())
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.pressable)

                Menu {
                    Picker("Rýchlosť", selection: $duel.rate) {
                        ForEach(DualVideoComparisonView.rates, id: \.self) { rate in
                            Text(DualVideoComparisonView.rateText(rate)).tag(rate)
                        }
                    }
                } label: {
                    Label(DualVideoComparisonView.rateText(duel.rate), systemImage: "tortoise.fill")
                        .font(.footnote.weight(.bold))
                        .foregroundColor(duel.rate < 1 ? Color.obsidian900 : .white)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .background(duel.rate < 1 ? Color.gold400 : Color.white.opacity(0.1), in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(duel.rate < 1 ? 0 : 0.14), lineWidth: 1))
                }
                .accessibilityLabel("Rýchlosť \(DualVideoComparisonView.rateText(duel.rate))")

                Menu {
                    Picker("Zvuk", selection: $duel.sound) {
                        Label("Bez zvuku", systemImage: "speaker.slash.fill").tag(DuelPlayback.Sound.off)
                        Label("Zvuk z môjho videa", systemImage: "person.fill").tag(DuelPlayback.Sound.mine)
                        Label("Zvuk zo vzoru", systemImage: "star.fill").tag(DuelPlayback.Sound.model)
                    }
                } label: {
                    Image(systemName: duel.sound == .off ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(duel.sound == .off ? .white : Color.gold400)
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.1), in: Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 1))
                        .contentTransition(.symbolEffect(.replace))
                }
                .accessibilityLabel(duel.sound.title)
            }

            Spacer(minLength: 0)

            LiquidGlassCircleButton(icon: "arrow.up.left.and.arrow.down.right", label: "Porovnať naplno") {
                duel.stopAll()
                onCompare()
            }
        }
        .sensoryFeedback(.selection, trigger: duel.sound)
        .sensoryFeedback(.selection, trigger: duel.rate)
    }
}

/// The two players of the duel. Started together they begin at the same instant of the iPhone clock (after
/// both seeks), so the comparison is frame-true; when the longer one ends, both start again together.
@MainActor
final class DuelPlayback: ObservableObject {
    enum Side: Hashable { case mine, model }
    enum Sound: Hashable {
        case off, mine, model
        var title: String {
            switch self {
            case .off: return "Bez zvuku"
            case .mine: return "Zvuk z môjho videa"
            case .model: return "Zvuk zo vzoru"
            }
        }
    }

    @Published private(set) var players: [Side: AVPlayer] = [:]
    @Published private(set) var playing: Set<Side> = []
    @Published private(set) var isTogether = false
    @Published var sound: Sound = .off { didSet { applySound() } }
    @Published var rate: Float = 1 { didSet { applyRate() } }

    private var observers: [Side: any NSObjectProtocol] = [:]
    /// Played to the end while both run together.
    private var ended: Set<Side> = []

    var canPlayTogether: Bool { players[.mine] != nil && players[.model] != nil }

    func setPlayer(_ player: AVPlayer?, for side: Side) {
        if let old = players[side] { old.pause() }
        if let observer = observers[side] { NotificationCenter.default.removeObserver(observer) }
        observers[side] = nil
        playing.remove(side)
        isTogether = false
        players[side] = player
        guard let player else { return }
        player.automaticallyWaitsToMinimizeStalling = false
        player.defaultRate = rate
        observers[side] = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reachedEnd(side) }
        }
        applySound()
    }

    func toggle(_ side: Side) {
        guard let player = players[side] else { return }
        isTogether = false
        if playing.contains(side) {
            player.pause()
            playing.remove(side)
        } else {
            playing.insert(side)
            activateSession()
            player.play()
        }
    }

    func toggleTogether() {
        if isTogether {
            pauseAll()
        } else {
            Task { await playTogether(from: .zero) }
        }
    }

    func stopAll() {
        pauseAll()
        Task {
            await AudioSessionCoordinator.shared.deactivate(.player)
            await AudioSessionCoordinator.shared.deactivate(.mutedVideo)
        }
    }

    private func pauseAll() {
        players.values.forEach { $0.pause() }
        playing.removeAll()
        isTogether = false
    }

    /// Both from the same moment, starting at the same instant of the iPhone clock. Two play() calls start a
    /// few frames apart. A pause while seeking wins.
    private func playTogether(from time: CMTime) async {
        guard let mine = players[.mine], let model = players[.model] else { return }
        isTogether = true
        playing = [.mine, .model]
        ended = []
        mine.pause()
        model.pause()
        activateSession()
        await mine.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        await model.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        guard isTogether else { return }
        let start = CMTimeAdd(CMClockGetTime(CMClockGetHostTimeClock()), CMTime(value: 1, timescale: 20))
        mine.setRate(rate, time: .invalid, atHostTime: start)
        model.setRate(rate, time: .invalid, atHostTime: start)
    }

    private func reachedEnd(_ side: Side) {
        if isTogether {
            ended.insert(side)
            if ended.count == 2 { Task { await playTogether(from: .zero) } }
        } else if playing.contains(side), let player = players[side] {
            player.seek(to: .zero)
            player.play()
        }
    }

    /// Slower or faster without losing the moment; together they start again in step from where mine is.
    private func applyRate() {
        players.values.forEach { $0.defaultRate = rate }
        if isTogether, let mine = players[.mine] {
            Task { await playTogether(from: mine.currentTime()) }
        } else {
            playing.forEach { players[$0]?.rate = rate }
        }
    }

    /// One sound at most.
    private func applySound() {
        players[.mine]?.isMuted = sound != .mine
        players[.model]?.isMuted = sound != .model
        if !playing.isEmpty { activateSession() }
    }

    /// Sound on takes the speaker like any video app; silent videos never stop music already playing in the hall.
    private func activateSession() {
        let client: AudioSessionCoordinator.Client = sound == .off ? .mutedVideo : .player
        Task { try? await AudioSessionCoordinator.shared.activate(client) }
    }
}

/// One video of the duel, with its own play button.
private struct DuelSlot: View {
    let side: DuelPlayback.Side
    let title: String
    let path: String?
    let addTitle: String
    @ObservedObject var duel: DuelPlayback
    let onAdd: () -> Void

    @State private var image: UIImage?
    @State private var isMissing = false

    private var player: AVPlayer? { duel.players[side] }
    private var isPlaying: Bool { duel.playing.contains(side) }

    var body: some View {
        ZStack {
            // Glass like the figure's page (§1A), not a black screen.
            Color.white.opacity(0.07)
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
            } else if let player {
                CustomAVPlayerRepresentable(player: player, gravity: .resizeAspect)
                    .contentShape(Rectangle())
                    .onTapGesture { duel.toggle(side) }
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
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.10), lineWidth: 1))
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
                Button { duel.toggle(side) } label: {
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

    private func load() async {
        duel.setPlayer(nil, for: side)
        image = nil
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
        duel.setPlayer(AVPlayer(url: url), for: side)
    }
}
