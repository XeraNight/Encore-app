import SwiftUI

// MARK: - Camera look
extension View {
    /// The camera's glass: Liquid Glass over the Lock Screen activity's red. A picture only, never interactive, so
    /// it never takes a tap from the buttons on it (BRAND_GUIDELINES §1A).
    func cameraGlass<S: Shape>(in shape: S) -> some View {
        glassEffect(.regular.tint(Color.activityRed.opacity(0.5)), in: shape)
    }

    /// A camera chip: white 12 % like the Lock Screen activity's buttons, gold when on, never under 44 pt.
    func cameraChip(isOn: Bool) -> some View {
        font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(isOn ? Color.amberGold : .white)
            .padding(.horizontal, 11)
            .frame(minWidth: 44, minHeight: 44)
            .background(isOn ? Color.amberGold.opacity(0.22) : Color.white.opacity(0.12), in: Capsule())
            .overlay(Capsule().stroke(isOn ? Color.amberGold.opacity(0.45) : Color.white.opacity(0.1), lineWidth: 1))
            .contentShape(Capsule())
    }
}

// MARK: - Camera controls that follow the metronome
// Each view below observes the metronome itself, so a beat redraws only it; the camera screen never does, and a
// tap on its menus is never lost to a redraw.

/// The metronome chip: opens the metronome tray in the camera's panel. No system menu: on the camera screen a
/// menu often did not open at all.
struct CameraMetronomeChip: View {
    @ObservedObject private var metronome = DanceMetronomeEngine.shared
    let isOpen: Bool
    let toggle: () -> Void

    var body: some View {
        let isOn = metronome.selectedPreset != .off
        // The label changes with the dance and the tempo only, never with the beat.
        Button(action: toggle) {
            HStack(spacing: 5) {
                Image(systemName: "metronome.fill")
                Text(isOn ? "\(metronome.selectedPreset.shortCode) • \(metronome.effectiveBpm)" : "Metronóm")
                    .contentTransition(.numericText())
                Image(systemName: "chevron.up")
                    .font(.system(size: 9, weight: .black))
                    .rotationEffect(.degrees(isOpen ? 180 : 0))
                    .opacity(0.65)
            }
            .cameraChip(isOn: isOn || isOpen)
        }
        .buttonStyle(.pressable)
        .sensoryFeedback(.selection, trigger: isOpen)
        .accessibilityLabel(isOn ? "Metronóm, \(metronome.selectedPreset.shortCode), \(metronome.effectiveBpm) úderov za minútu" : "Metronóm")
    }
}

/// The metronome inside the camera's panel: the dances in one row, then the tempo and the full metronome.
struct CameraMetronomeTray: View {
    @ObservedObject private var metronome = DanceMetronomeEngine.shared
    let openFullMetronome: () -> Void

    private let dances = DanceMetronomePreset.allCases.filter { $0 != .off && $0 != .custom }

    var body: some View {
        let isOn = metronome.selectedPreset != .off
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(dances) { preset in
                        Button {
                            if metronome.selectedPreset == preset {
                                metronome.stop()
                                metronome.selectedPreset = .off
                            } else {
                                metronome.start(preset: preset)
                            }
                        } label: {
                            Text(preset.chipName)
                                .cameraChip(isOn: metronome.selectedPreset == preset)
                        }
                        .buttonStyle(.pressable)
                    }
                }
            }
            .scrollClipDisabled()
            .sensoryFeedback(.selection, trigger: metronome.selectedPreset)

            HStack(spacing: 8) {
                if isOn {
                    tempoButton("minus", label: "Pomalšie o 5 %") {
                        metronome.start(multiplier: max(0.7, metronome.tempoMultiplier - 0.05))
                    }
                    VStack(spacing: 1) {
                        Text("\(metronome.effectiveBpm) BPM")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .contentTransition(.numericText())
                        Text("\(Int((metronome.tempoMultiplier * 100).rounded())) % tempa")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .foregroundStyle(.white)
                    .frame(minWidth: 84)
                    .animation(.snappy, value: metronome.effectiveBpm)
                    tempoButton("plus", label: "Svižnejšie o 5 %") {
                        metronome.start(multiplier: min(1.3, metronome.tempoMultiplier + 0.05))
                    }
                } else {
                    Text("Vyber tanec a metronóm začne hrať.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                }
                Spacer(minLength: 0)
                Button(action: openFullMetronome) {
                    Image(systemName: "slider.horizontal.3")
                        .cameraChip(isOn: false)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Celý metronóm a zvuky")
            }
            .sensoryFeedback(.selection, trigger: metronome.tempoMultiplier)
        }
    }

    private func tempoButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .cameraChip(isOn: false)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(label)
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
            .padding(.vertical, 8)
            .cameraGlass(in: Capsule())
            .overlay(Capsule().stroke(metronome.currentBeat == 1 ? Color.amberGold.opacity(0.6) : Color.white.opacity(0.1), lineWidth: 1))
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
                .contentTransition(.numericText())
                .animation(.snappy, value: camera.recordingDuration)
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
        .padding(.vertical, 8)
        .cameraGlass(in: Capsule())
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

// MARK: - Focus
/// Where the last focus tap was; each tap gets a new id, so the square starts over.
struct FocusMark: Equatable {
    let id = UUID()
    let point: CGPoint
    /// A long press: focus and exposure stay put until the next tap.
    var isLock = false
}

/// The gold focus square: lands a little big, settles with a spring, then fades.
struct CameraFocusSquare: View {
    let mark: FocusMark
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settled = false
    @State private var visible = true

    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(Color.amberGold, lineWidth: 1.5)
            .frame(width: 76, height: 76)
            .scaleEffect(settled || reduceMotion ? 1 : 1.35)
            .overlay(alignment: .top) {
                if mark.isLock {
                    Text("ZÁMOK ZAOSTRENIA")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(Color.obsidian900)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.amberGold, in: Capsule())
                        .fixedSize()
                        .offset(y: -26)
                }
            }
            .opacity(visible ? 1 : 0)
            .position(mark.point)
            .sensoryFeedback(.impact(weight: mark.isLock ? .heavy : .light), trigger: mark.id)
            .task(id: mark.id) {
                settled = false
                visible = true
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { settled = true }
                // A lock stays on screen a while longer, so it is read.
                try? await Task.sleep(for: .seconds(mark.isLock ? 2.5 : 1.2))
                withAnimation(.easeOut(duration: 0.3)) { visible = false }
            }
    }
}
