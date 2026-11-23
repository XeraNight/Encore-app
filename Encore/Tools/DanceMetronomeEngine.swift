import Foundation
import AVFoundation
import UIKit
import SwiftUI
import Combine
import OSLog

// MARK: - Dance Metronome Preset
/// A tempo against the one SZTŠ prescribes, in takty za minútu.
public enum CompetitionTempo: Equatable {
    case slower(by: Int)
    case within
    case faster(by: Int)
}

public enum DanceMetronomePreset: String, CaseIterable, Identifiable {
    case off = "Vypnuté"
    case waltz = "Waltz (29 MPM)"
    case tango = "Tango (32 MPM)"
    case vienneseWaltz = "Viedenský valčík (59 MPM)"
    case slowfox = "Slowfox (29 MPM)"
    case quickstep = "Quickstep (51 MPM)"
    case samba = "Samba (51 MPM)"
    case chacha = "Cha-Cha (31 MPM)"
    case rumba = "Rumba (26 MPM)"
    case pasoDoble = "Paso Doble (61 MPM)"
    case jive = "Jive (43 MPM)"
    
    public var id: String { rawValue }
    
    public var shortCode: String {
        switch self {
        case .off: return "Vypnuté"
        case .waltz: return "Waltz"
        case .tango: return "Tango"
        case .vienneseWaltz: return "V. valčík"
        case .slowfox: return "Slowfox"
        case .quickstep: return "Quickstep"
        case .samba: return "Samba"
        case .chacha: return "Cha-cha-cha"
        case .rumba: return "Rumba"
        case .pasoDoble: return "Paso doble"
        case .jive: return "Jive"
        }
    }

    /// The name on a dance chip: full, as dancers say it.
    public var chipName: String {
        switch self {
        case .vienneseWaltz: return "Viedenský valčík"
        default: return shortCode
        }
    }
    
    public var danceName: String {
        switch self {
        case .off: return "Žiadny"
        case .waltz: return "Pomalý Waltz"
        case .tango: return "Tango"
        case .vienneseWaltz: return "Viedenský valčík"
        case .slowfox: return "Slowfox"
        case .quickstep: return "Quickstep"
        case .samba: return "Samba"
        case .chacha: return "Cha-Cha"
        case .rumba: return "Rumba"
        case .pasoDoble: return "Paso Doble"
        case .jive: return "Jive"
        }
    }
    
    public var category: String {
        switch self {
        case .waltz, .tango, .vienneseWaltz, .slowfox, .quickstep:
            return "Standard"
        case .samba, .chacha, .rumba, .pasoDoble, .jive:
            return "Latina"
        default:
            return "Všeobecné"
        }
    }
    
    /// The tempo SZTŠ prescribes, in takty za minútu (Súťažný poriadok SZTŠ 2023, čl. 8 bod 2: "podľa pravidiel WDSF").
    /// The one table the other numbers come from.
    public var competitionMeasures: ClosedRange<Int>? {
        switch self {
        case .waltz: return 28...30
        case .tango: return 31...33
        case .vienneseWaltz: return 58...60
        case .slowfox: return 28...30
        case .quickstep: return 50...52
        case .samba: return 50...52
        case .chacha: return 30...32
        case .rumba: return 25...27
        case .pasoDoble: return 60...62
        case .jive: return 42...44
        case .off: return nil
        }
    }

    /// The tempo as the dance library writes it: "28–30 taktov za minútu (84–90 úderov)". The numbers in the brackets
    /// are the clicks; `RoutineTiming` reads the takty before them.
    public var tempoText: String? {
        guard let range = competitionMeasures else { return nil }
        let beats = beatsPerMeasure
        return "\(range.lowerBound)–\(range.upperBound) taktov za minútu (\(range.lowerBound * beats)–\(range.upperBound * beats) úderov)"
    }

    /// The preset of a dance as the library names it ("Slowfoxtrot", "Cha-Cha-Cha"); nil for any other name.
    public static func forLibraryDance(_ name: String) -> DanceMetronomePreset? {
        switch name {
        case "Waltz": return .waltz
        case "Tango": return .tango
        case "Viennese Waltz": return .vienneseWaltz
        case "Slowfoxtrot": return .slowfox
        case "Quickstep": return .quickstep
        case "Samba": return .samba
        case "Cha-Cha-Cha": return .chacha
        case "Rumba": return .rumba
        case "Paso Doble": return .pasoDoble
        case "Jive": return .jive
        default: return nil
        }
    }

    /// Takty za minútu in the middle of the competition range: the basic tempo of the dance.
    public var mpm: Double {
        competitionMeasures.map { Double($0.lowerBound + $0.upperBound) / 2 } ?? 0
    }

    /// Údery za minútu (what a metronome clicks): takty × doby v takte.
    public var bpm: Double {
        self == .off ? 0 : mpm * Double(beatsPerMeasure)
    }

    /// How `measures` (takty za minútu) compares with the tempo SZTŠ prescribes for this dance; nil without one.
    public func compare(measures: Int) -> CompetitionTempo? {
        guard let range = competitionMeasures else { return nil }
        if measures < range.lowerBound { return .slower(by: range.lowerBound - measures) }
        if measures > range.upperBound { return .faster(by: measures - range.upperBound) }
        return .within
    }
    
    public var beatsPerMeasure: Int {
        switch self {
        case .waltz, .vienneseWaltz: return 3
        case .samba, .pasoDoble: return 2
        default: return 4
        }
    }
}

// MARK: - Bulletproof Dance Metronome Engine
@MainActor
public final class DanceMetronomeEngine: ObservableObject {
    public static let shared = DanceMetronomeEngine()
    
    // Published UI State
    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var currentBeat: Int = 1
    @Published public private(set) var isPulse: Bool = false
    @Published public var selectedPreset: DanceMetronomePreset = .off
    @Published public var tempoMultiplier: Double = 1.0
    @Published public var isSoundEnabled: Bool = true { didSet { updateAudioVolume() } }
    @Published public var isHapticEnabled: Bool = true
    @Published public var volume: Float = 1.0 { didSet { updateAudioVolume() } }
    
    /// Údery za minútu at the tempo now playing: what the metronome clicks, whole numbers.
    public var effectiveBpm: Int {
        selectedPreset == .off ? 0 : Int((selectedPreset.bpm * tempoMultiplier).rounded())
    }

    /// Takty za minútu at the tempo now playing, the number dancers speak in.
    public var effectiveMpm: Int {
        guard selectedPreset != .off, beatsPerMeasure > 0 else { return 0 }
        return Int((Double(effectiveBpm) / Double(beatsPerMeasure)).rounded())
    }

    /// The tempo now playing against the one SZTŠ prescribes for the dance; nil for no dance.
    public var againstCompetition: CompetitionTempo? {
        selectedPreset.compare(measures: effectiveMpm)
    }
    
    public var beatsPerMeasure: Int {
        selectedPreset.beatsPerMeasure
    }
    
    // Internal Audio & Timing
    /// The clicks: one measure looped by an audio engine (MetronomeAudio), so the tempo is the audio clock's and the
    /// app keeps playing with the screen locked. The timer below only drives the haptic and the pulse.
    private let audio = MetronomeAudio()
    private var timerSource: DispatchSourceTimer?
    private let timerQueue = DispatchQueue(label: "dance.encore.metronome.timer", qos: .userInteractive)
    
    private init() {}

    private func updateAudioVolume() {
        audio.volume = isSoundEnabled ? volume : 0
    }
    
    // MARK: - Playback Session Activation
    private static let sessionQueue = DispatchQueue(label: "dance.encore.metronome.session", qos: .userInitiated)
    /// Each start and stop gets a number, so a start whose audio session got ready after a stop never ticks.
    private var startNumber = 0

    /// Off the main thread: changing the audio session takes up to a second, more with headphones, and froze the
    /// camera on every dance and tempo tap. A session the camera already set for recording is left as it is, so the
    /// two never fight over it.
    private nonisolated static func prepareAudioSession() async {
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            sessionQueue.async {
                let session = AVAudioSession.sharedInstance()
                do {
                    // A voice note leaves .playAndRecord without .mixWithOthers: kept, the metronome would pause the hall's music.
                    if session.category != .playAndRecord || !session.categoryOptions.contains(.mixWithOthers) {
                        // .playAndRecord with .defaultToSpeaker plays next to the camera's microphone and past
                        // the mute switch; .mixWithOthers plays over the hall's music.
                        try session.setCategory(
                            .playAndRecord,
                            mode: .default,
                            options: [.defaultToSpeaker, .mixWithOthers, .allowBluetoothHFP, .allowBluetoothA2DP]
                        )
                    }
                    try session.setActive(true, options: .notifyOthersOnDeactivation)
                } catch {
                    Logger.audio.error("Metronome audio session setup failed: \(error.localizedDescription, privacy: .public)")
                }
                done.resume()
            }
        }
    }
    
    // MARK: - Start / Restart Metronome
    public func start(preset: DanceMetronomePreset? = nil, multiplier: Double? = nil) {
        if let preset = preset {
            self.selectedPreset = preset
        }
        if let multiplier = multiplier {
            self.tempoMultiplier = multiplier
        }
        
        guard selectedPreset != .off else {
            stop()
            return
        }
        
        let targetBpm = effectiveBpm
        guard targetBpm > 0 else {
            stop()
            return
        }
        
        // Stop any currently running timer cleanly
        stopTimerOnly()
        
        let wasPlaying = isPlaying
        isPlaying = true
        currentBeat = 1
        startNumber += 1
        let number = startNumber
        AnalyticsManager.shared.metronomeStarted(bpm: targetBpm, dance: selectedPreset.shortCode)

        // A tempo or dance change while it plays keeps the session it has.
        guard !wasPlaying else { return beginTicking(bpm: targetBpm) }
        Task {
            await Self.prepareAudioSession()
            guard number == startNumber, isPlaying else { return }
            beginTicking(bpm: targetBpm)
        }
    }

    private func beginTicking(bpm targetBpm: Int) {
        let intervalSeconds = 60.0 / Double(targetBpm)
        
        // The downbeat starts the looped measure; its haptic and pulse come with it.
        updateAudioVolume()
        audio.play(bpm: targetBpm, beatsPerMeasure: selectedPreset.beatsPerMeasure)
        triggerBeatTick(beatNumber: 1)
        
        // The beat for the haptic and the pulse, on a dedicated interactive queue
        let timer = DispatchSource.makeTimerSource(flags: .strict, queue: timerQueue)
        timer.schedule(
            deadline: .now() + intervalSeconds,
            repeating: intervalSeconds,
            leeway: .milliseconds(1)
        )
        
        timer.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self, self.isPlaying else { return }
                let nextBeat = (self.currentBeat % self.selectedPreset.beatsPerMeasure) + 1
                self.currentBeat = nextBeat
                self.triggerBeatTick(beatNumber: nextBeat)
            }
        }
        
        self.timerSource = timer
        timer.resume()
    }
    
    // MARK: - Stop Metronome
    public func stop() {
        stopTimerOnly()
        audio.stop()
        startNumber += 1
        isPlaying = false
        currentBeat = 1
        isPulse = false
    }
    
    public func toggle() {
        if isPlaying {
            stop()
        } else {
            if selectedPreset == .off {
                selectedPreset = .waltz
            }
            start()
        }
    }
    
    private func stopTimerOnly() {
        if let timer = timerSource {
            timer.cancel()
            timerSource = nil
        }
    }
    
    // MARK: - Trigger Beat Tick (Haptic + Visual Pulse)
    private func triggerBeatTick(beatNumber: Int) {
        let isDownbeat = (beatNumber == 1)
        
        // 1. Haptic Accent
        if isHapticEnabled {
            if isDownbeat {
                let gen = UIImpactFeedbackGenerator(style: .heavy)
                gen.prepare()
                gen.impactOccurred()
            } else {
                let gen = UIImpactFeedbackGenerator(style: .light)
                gen.prepare()
                gen.impactOccurred()
            }
        }
        
        // 2. UI Spring Pulse
        withAnimation(.spring(response: 0.12, dampingFraction: 0.55)) {
            self.isPulse = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.easeOut(duration: 0.15)) {
                self.isPulse = false
            }
        }
    }
}
