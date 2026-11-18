import Testing
import AVFoundation
@testable import Encore

/// The measure the metronome loops: as long as its beats, a click at the start of each, silence in between, the
/// downbeat louder. The clock is the audio engine's, so these samples are the tempo.
@MainActor
struct MetronomeAudioTests {
    private let format = AVAudioFormat(standardFormatWithSampleRate: MetronomeAudio.sampleRate, channels: 1)!

    private func samples(_ bpm: Int, _ beats: Int) -> [Float] {
        let buffer = MetronomeAudio.measureBuffer(bpm: bpm, beatsPerMeasure: beats, format: format)
        return Array(UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength)))
    }

    @Test func aMeasureIsAsLongAsItsBeats() {
        #expect(samples(120, 4).count == 88_200)   // four beats of half a second
        #expect(samples(120, 3).count == 66_150)
        // A beat of 87 údery is 30 413.8 samples long: the measure ends at the sample nearest to its beats.
        #expect(samples(87, 3).count == Int((3 * 60.0 / 87 * MetronomeAudio.sampleRate).rounded()))
    }

    @Test func eachBeatStartsWithAClickAndIsSilentAfterIt() {
        let bpm = 120
        let data = samples(bpm, 4)
        for beat in 0..<4 {
            let begin = MetronomeAudio.frame(ofBeat: beat, bpm: bpm)
            #expect(data[begin..<begin + 400].contains { abs($0) > 0.3 })
            let next = beat == 3 ? data.count : MetronomeAudio.frame(ofBeat: beat + 1, bpm: bpm)
            // The downbeat click is 26 ms (1 146 samples), a tick 18 ms: nothing after that until the next beat.
            #expect(data[begin + 1_200..<next].allSatisfy { $0 == 0 })
        }
    }

    @Test func theDownbeatIsLouderThanATick() {
        let bpm = 100
        let data = samples(bpm, 4)
        func peak(_ beat: Int) -> Float {
            let begin = MetronomeAudio.frame(ofBeat: beat, bpm: bpm)
            return data[begin..<begin + 1_200].map { abs($0) }.max() ?? 0
        }
        #expect(peak(0) > peak(1))
        #expect(peak(1) == peak(2) && peak(2) == peak(3))
    }

    @Test func theQuickestTempoStillLeavesRoomForTheClick() {
        // Jive, 172 údery, at the 130 % the camera allows.
        let bpm = Int((172.0 * 1.3).rounded())
        #expect(MetronomeAudio.frame(ofBeat: 1, bpm: bpm) > MetronomeAudio.downbeatClick.count)
    }

    @Test func playingAgainAtAnotherTempoAndStoppingDoNotTrap() {
        let audio = MetronomeAudio()
        audio.volume = 0
        audio.play(bpm: 120, beatsPerMeasure: 4)
        audio.play(bpm: 90, beatsPerMeasure: 3)
        audio.stop()
        audio.stop()
    }
}
