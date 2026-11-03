import SwiftUI

// MARK: - Camera controls that follow the metronome
// Each view below observes the metronome itself, so a beat redraws only it; the camera screen never does, and a
// tap on its menus is never lost to a redraw.

/// The metronome chip: the dance styles, the tempo and the full metronome.
struct CameraMetronomeChip: View {
    @ObservedObject private var metronome = DanceMetronomeEngine.shared
    let openFullMetronome: () -> Void

    var body: some View {
        let isOn = metronome.selectedPreset != .off
        Menu {
            Section {
                Button(action: openFullMetronome) {
                    Label("Metronóm a zvuky", systemImage: "metronome")
                }
            }
            Section("Tanečné štýly") {
                ForEach(DanceMetronomePreset.allCases) { preset in
                    Button {
                        if preset == .off {
                            metronome.stop()
                            metronome.selectedPreset = .off
                        } else {
                            metronome.start(preset: preset)
                        }
                    } label: {
                        HStack {
                            Text(preset.rawValue)
                            if metronome.selectedPreset == preset {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            if isOn {
                Section("Tempo: \(metronome.effectiveBpm) BPM (\(metronome.effectiveMpm) MPM)") {
                    Button("Svižnejšie (+5%)") {
                        metronome.start(multiplier: min(1.3, metronome.tempoMultiplier + 0.05))
                    }
                    Button("Pomalšie (-5%)") {
                        metronome.start(multiplier: max(0.7, metronome.tempoMultiplier - 0.05))
                    }
                    Button("Pôvodné tempo (100%)") {
                        metronome.start(multiplier: 1.0)
                    }
                    Button("Vypnúť metronóm", role: .destructive) {
                        metronome.stop()
                        metronome.selectedPreset = .off
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                if isOn {
                    CameraBeatDot()
                    Text("\(metronome.selectedPreset.shortCode) • \(metronome.effectiveBpm)")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                } else {
                    Image(systemName: "metronome.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text("Metronóm")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .black))
                    .opacity(0.65)
            }
            .foregroundColor(isOn ? Color.amberGold : .white)
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(isOn ? Color.amberGold.opacity(0.24) : Color.black.opacity(0.68))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(
                        isOn ? (metronome.currentBeat == 1 ? Color.amberGold : Color.amberGold.opacity(0.55)) : Color.white.opacity(0.22),
                        lineWidth: isOn ? 1.5 : 1
                    )
            )
            .shadow(color: isOn ? Color.amberGold.opacity(0.35) : Color.black.opacity(0.4), radius: 6, y: 2)
        }
    }
}

/// The beat: gold on the downbeat, bigger on each pulse.
struct CameraBeatDot: View {
    @ObservedObject private var metronome = DanceMetronomeEngine.shared

    var body: some View {
        let downbeat = metronome.currentBeat == 1
        Circle()
            .fill(downbeat ? Color.amberGold : Color.white)
            .frame(width: metronome.isPulse ? 10 : 7, height: metronome.isPulse ? 10 : 7)
            .shadow(color: downbeat ? Color.amberGold : Color.clear, radius: metronome.isPulse ? 6 : 0)
    }
}

/// "W • 84 BPM • Doba 1/3" above the controls while the metronome plays.
struct CameraMetronomeStatusPill: View {
    @ObservedObject private var metronome = DanceMetronomeEngine.shared
    let isRecording: Bool

    var body: some View {
        if metronome.selectedPreset != .off {
            HStack(spacing: 7) {
                CameraBeatDot()
                Text("\(metronome.selectedPreset.shortCode) • \(metronome.effectiveBpm) BPM • Doba \(metronome.currentBeat)/\(metronome.beatsPerMeasure)")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(metronome.currentBeat == 1 ? Color.amberGold : .white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Color.black.opacity(0.65))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(metronome.currentBeat == 1 ? Color.amberGold.opacity(0.6) : Color.white.opacity(0.18), lineWidth: 1))
            .opacity(isRecording ? 0.75 : 1.0)
            .transition(.scale.combined(with: .opacity))
        }
    }
}

/// The recording clock, with the tempo when the metronome plays.
struct CameraRecordingPill: View {
    @ObservedObject private var metronome = DanceMetronomeEngine.shared
    let camera: DanceCameraModel

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
            Text(DanceCameraModel.clockText(camera.recordingDuration))
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .foregroundColor(.white)
            if metronome.selectedPreset != .off {
                Divider()
                    .frame(height: 14)
                    .overlay(Color.white.opacity(0.25))
                CameraBeatDot()
                Text("\(metronome.effectiveBpm) BPM")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(metronome.currentBeat == 1 ? Color.amberGold : .white)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.68))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.red.opacity(0.55), lineWidth: 1))
    }
}

/// A short gold flash over the whole preview on each downbeat.
struct CameraBeatFlash: View {
    @ObservedObject private var metronome = DanceMetronomeEngine.shared
    @State private var opacity: Double = 0

    var body: some View {
        Color.amberGold
            .opacity(opacity)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .onChange(of: metronome.isPulse) { _, pulsing in
                guard pulsing, metronome.currentBeat == 1, metronome.selectedPreset != .off else { return }
                opacity = 0.13
                withAnimation(.easeOut(duration: 0.18).delay(0.08)) {
                    opacity = 0
                }
            }
    }
}
