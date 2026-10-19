import SwiftUI

// MARK: - Voice note inside a text
/// A voice note inside a sentence (BRAND_GUIDELINES §1A): small and always the same size, however long the
/// recording. The waveform runs through it like a carousel: while recording, new parts come in from the
/// right and old ones leave on the left; while playing, the recording passes a fixed line in the middle and
/// the played part turns gold. Used in Denník and in a figure's notes.
struct InlineVoiceToken: View {
    /// nil while recording.
    let ref: VoiceNoteRef?
    @ObservedObject var player: VoiceNotePlayer
    var liveLevels: [CGFloat] = []
    var elapsed: TimeInterval = 0
    var onStopRecording: (() -> Void)? = nil

    static let size = CGSize(width: 112, height: 28)

    @State private var levels: [CGFloat] = []

    private var isRecording: Bool { ref == nil }
    private var isMine: Bool { ref.map { player.fileName == $0.fileName } ?? false }
    private var isPlaying: Bool { isMine && player.isPlaying }
    private var progress: Double { isMine && player.duration > 0 ? player.currentTime / player.duration : 0 }

    var body: some View {
        HStack(spacing: 5) {
            icon
            CarouselWave(levels: isRecording ? liveLevels : levels, progress: progress,
                         mode: isRecording ? .recording : (isMine && progress > 0 ? .playing : .overview))
                .frame(width: 52, height: 18)
            Text(voiceTimeString(timeShown))
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
                .foregroundColor(isRecording ? .white : Color.gold300)
                .frame(width: 30, alignment: .trailing)
        }
        .padding(.leading, 4)
        .padding(.trailing, 7)
        .frame(width: Self.size.width, height: Self.size.height)
        .background(background, in: Capsule())
        .scaleEffect(isPlaying ? 1.05 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPlaying)
        .contentShape(Capsule())
        .onTapGesture { tap() }
        .task(id: ref) { await loadLevels() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isRecording ? "Nahrávam hlasovku, \(voiceTimeString(elapsed))" : "Hlasovka \(voiceTimeString(ref?.duration ?? 0))")
        .accessibilityHint(isRecording ? "Ťuknutím nahrávanie zastavíš" : (isPlaying ? "Ťuknutím pozastavíš" : "Ťuknutím prehráš"))
        .accessibilityAddTraits(.isButton)
    }

    private var timeShown: TimeInterval {
        if isRecording { return elapsed }
        let duration = ref?.duration ?? 0
        return isMine ? max(0, duration - player.currentTime) : duration
    }

    private var background: Color {
        if isRecording { return Color.latinRed.opacity(0.24) }
        return Color.gold500.opacity(isPlaying ? 0.32 : 0.18)
    }

    @ViewBuilder
    private var icon: some View {
        if isRecording {
            Image(systemName: "stop.fill")
                .font(.system(size: 8, weight: .black))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.latinRed, in: Circle())
                .phaseAnimator([1.0, 0.45]) { dot, phase in dot.opacity(phase) } animation: { _ in .easeInOut(duration: 0.6) }
        } else {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 9, weight: .black))
                .foregroundColor(Color.obsidian900)
                .frame(width: 20, height: 20)
                .background(Color.gold400, in: Circle())
                .contentTransition(.symbolEffect(.replace))
        }
    }

    private func tap() {
        guard let ref else {
            onStopRecording?()
            return
        }
        if isPlaying { player.pause() } else { player.play(fileName: ref.fileName) }
    }

    /// Four bars a second, so a long note scrolls past and a short one fits as it is.
    private func loadLevels() async {
        guard let ref else { return }
        let count = max(CarouselWave.visibleBars, min(400, Int(ref.duration * 4)))
        levels = await VoiceWaveformLoader.levels(for: ref.fileName, count: count)
    }
}

/// The waveform window of a voice token.
private struct CarouselWave: View {
    enum Mode { case recording, playing, overview }

    let levels: [CGFloat]
    let progress: Double
    let mode: Mode

    static let visibleBars = 13
    private let step: CGFloat = 4   // a 2 pt bar and a 2 pt gap

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            switch mode {
            case .recording:
                // The newest part on the right; older parts leave on the left.
                HStack(spacing: 2) {
                    ForEach(Array(levels.suffix(Self.visibleBars).enumerated()), id: \.offset) { _, level in
                        bar(level, height: height, color: .white, lit: true)
                    }
                }
                .frame(width: geo.size.width, height: height, alignment: .trailing)
            case .overview:
                HStack(spacing: 2) {
                    ForEach(Array(overview.enumerated()), id: \.offset) { _, level in
                        bar(level, height: height, color: Color.gold400, lit: false)
                    }
                }
                .frame(width: geo.size.width, height: height, alignment: .leading)
            case .playing:
                // The played part passes the line in the middle and turns gold.
                let played = Int(progress * Double(levels.count))
                HStack(spacing: 2) {
                    ForEach(Array(levels.enumerated()), id: \.offset) { index, level in
                        bar(level, height: height, color: Color.gold400, lit: index < played)
                    }
                }
                .offset(x: geo.size.width / 2 - CGFloat(progress) * CGFloat(levels.count) * step)
                .frame(width: geo.size.width, height: height, alignment: .leading)
                .overlay {
                    Capsule().fill(Color.white).frame(width: 2, height: height + 2)
                }
                .animation(.linear(duration: 0.05), value: progress)
            }
        }
        .clipped()
    }

    /// The whole note squeezed into the window, so its shape shows before playing.
    private var overview: [CGFloat] {
        guard levels.count > Self.visibleBars else { return levels }
        let chunk = Double(levels.count) / Double(Self.visibleBars)
        return (0..<Self.visibleBars).map { index in
            let slice = levels[Int(Double(index) * chunk)..<min(levels.count, Int(Double(index + 1) * chunk))]
            return slice.max() ?? 0.15
        }
    }

    private func bar(_ level: CGFloat, height: CGFloat, color: Color, lit: Bool) -> some View {
        Capsule()
            .fill(color.opacity(lit ? 1 : 0.4))
            .frame(width: 2, height: max(3, level * height))
    }
}
