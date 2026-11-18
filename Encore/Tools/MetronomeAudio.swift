import AVFoundation
import Foundation
import OSLog

// MARK: - What the metronome plays
/// One measure as one buffer (a click on each beat, silence between) that an audio engine loops. The tempo is kept by
/// the audio clock, not by a timer and the main thread, and the app keeps playing sound all the time, so with the
/// screen locked iOS does not take it for silent between two clicks and suspend it (UIBackgroundModes audio).
@MainActor
final class MetronomeAudio {
    static let sampleRate = 44_100.0
    /// A tick is softer than the downbeat.
    private static let tickGain: Float = 0.85

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: MetronomeAudio.sampleRate, channels: 1)!
    private var playing: (bpm: Int, beatsPerMeasure: Int)?
    private var configurationObserver: NSObjectProtocol?

    /// 0 to 1.
    var volume: Float = 1 {
        didSet { player.volume = volume }
    }

    init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        // A new route (AirPods, AirPlay, a speaker) stops the engine on its own: it goes on where it was.
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.resumeAfterRouteChange() }
        }
    }

    deinit {
        if let configurationObserver { NotificationCenter.default.removeObserver(configurationObserver) }
    }

    /// Starts the measure from its downbeat, or starts it again at another tempo.
    func play(bpm: Int, beatsPerMeasure: Int) {
        guard bpm > 0, beatsPerMeasure > 0 else { return stop() }
        playing = (bpm, beatsPerMeasure)
        schedule()
    }

    /// Stops the engine too, so the app does not go on playing silence once the metronome is off.
    func stop() {
        playing = nil
        player.stop()
        engine.stop()
    }

    private func schedule() {
        guard let playing else { return }
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                Logger.audio.error("Metronome engine did not start: \(error.localizedDescription, privacy: .public)")
                return
            }
        }
        player.stop()
        player.volume = volume
        player.scheduleBuffer(Self.measureBuffer(bpm: playing.bpm, beatsPerMeasure: playing.beatsPerMeasure, format: format),
                              at: nil, options: .loops)
        player.play()
    }

    private func resumeAfterRouteChange() {
        guard playing != nil else { return }
        schedule()
    }

    // MARK: Samples
    /// One measure: the downbeat first, a tick on every other beat, nothing in between. Each beat starts at the sample
    /// nearest to where the tempo puts it, so rounding never adds up.
    static func measureBuffer(bpm: Int, beatsPerMeasure: Int, format: AVAudioFormat) -> AVAudioPCMBuffer {
        let frames = frame(ofBeat: beatsPerMeasure, bpm: bpm)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames))!
        buffer.frameLength = AVAudioFrameCount(frames)
        let samples = buffer.floatChannelData![0]
        samples.update(repeating: 0, count: frames)
        for beat in 0..<beatsPerMeasure {
            let click = beat == 0 ? downbeatClick : tickClick
            let gain = beat == 0 ? 1 : tickGain
            let begin = frame(ofBeat: beat, bpm: bpm)
            for (offset, sample) in click.enumerated() where begin + offset < frames {
                samples[begin + offset] = sample * gain
            }
        }
        return buffer
    }

    /// The sample where beat number `beat` (from 0) begins; `beatsPerMeasure` gives the length of the measure.
    static func frame(ofBeat beat: Int, bpm: Int) -> Int {
        Int((Double(beat) * 60.0 / Double(bpm) * sampleRate).rounded())
    }

    static let downbeatClick = click(frequency: 1450, duration: 0.026, isDownbeat: true)
    static let tickClick = click(frequency: 920, duration: 0.018, isDownbeat: false)

    /// A woodblock click: a tone, with a fifth above it on the downbeat, a 1 ms attack so it does not pop, then a decay.
    static func click(frequency: Double, duration: Double, isDownbeat: Bool) -> [Float] {
        let count = Int(sampleRate * duration)
        let attack = Int(sampleRate * 0.001)
        let decay = Double(count - attack)
        return (0..<count).map { index in
            let time = Double(index) / sampleRate
            let envelope = index < attack ? Double(index) / Double(attack) : exp(-6.0 * Double(index - attack) / decay)
            let tone = sin(2 * .pi * frequency * time) + (isDownbeat ? 0.35 * sin(2 * .pi * frequency * 1.5 * time) : 0)
            return Float(max(-1, min(1, tone * envelope * 0.90)))
        }
    }
}
