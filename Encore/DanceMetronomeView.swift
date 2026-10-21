import SwiftUI

// MARK: - Metronóm
/// Beats for a dance at its basic tempo, slower or faster for practice (BRAND_GUIDELINES §1A).
/// Opens on the dance used last time, so one tap starts it.
public struct DanceMetronomeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var engine = DanceMetronomeEngine.shared
    @AppStorage("metronome.lastDance") private var lastDance = DanceMetronomePreset.waltz.rawValue
    @State private var tapCount = 0

    private static let standard: [DanceMetronomePreset] = [.waltz, .tango, .vienneseWaltz, .slowfox, .quickstep]
    private static let latin: [DanceMetronomePreset] = [.samba, .chacha, .rumba, .pasoDoble, .jive]
    private static let speeds: [Double] = [0.8, 0.9, 1.0, 1.05, 1.1]

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        tempoDisplay
                        beatRow
                        playButton
                        speedCard
                        danceSection("ŠTANDARD", Self.standard)
                        danceSection("LATINA", Self.latin)
                        settingsCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Metronóm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hotovo") { dismiss() }
                        .foregroundColor(Color.gold400)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: engine.selectedPreset)
        .sensoryFeedback(.impact(weight: .light), trigger: tapCount)
        .onAppear {
            if engine.selectedPreset == .off {
                engine.selectedPreset = DanceMetronomePreset(rawValue: lastDance) ?? .waltz
            }
        }
        .onDisappear {
            // A metronome that is not playing does not follow you into the camera.
            if !engine.isPlaying { engine.selectedPreset = .off }
        }
    }

    // MARK: Display
    private var tempoDisplay: some View {
        VStack(spacing: 6) {
            Text(engine.selectedPreset.chipName.uppercased())
                .font(.system(.caption, design: .rounded).weight(.black))
                .tracking(1.4)
                .foregroundColor(Color.gold400)
                .contentTransition(.opacity)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(engine.effectiveBpm)")
                    .font(.system(size: 76, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                    .shadow(color: engine.isPlaying && engine.isPulse ? Color.gold400.opacity(0.45) : .clear, radius: 16)
                Text("BPM")
                    .font(.headline.weight(.bold))
                    .foregroundColor(Color.textSecondary)
            }
            .scaleEffect(engine.isPlaying && engine.isPulse && !reduceMotion ? 1.03 : 1)
            .animation(.spring(response: 0.12, dampingFraction: 0.6), value: engine.isPulse)

            if engine.effectiveMpm > 0 {
                Text("\(engine.effectiveMpm) taktov za minútu · \(engine.beatsPerMeasure) doby v takte")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.65))
                    .contentTransition(.numericText())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: engine.effectiveBpm)
        .accessibilityElement(children: .combine)
    }

    private var beatRow: some View {
        HStack(spacing: 12) {
            ForEach(1...max(engine.beatsPerMeasure, 1), id: \.self) { beat in
                let isCurrent = engine.isPlaying && engine.currentBeat == beat
                Text("\(beat)")
                    .font(.system(.headline, design: .rounded).weight(.black))
                    .foregroundColor(isCurrent ? Color.obsidian900 : .white.opacity(0.6))
                    .frame(maxWidth: 64, minHeight: isCurrent ? 46 : 40)
                    .background(
                        isCurrent ? (beat == 1 ? Color.gold400 : Color.white) : Color.white.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(beat == 1 ? Color.gold400.opacity(0.45) : Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .animation(.spring(response: 0.14, dampingFraction: 0.6), value: engine.currentBeat)
            }
        }
        .frame(height: 48)
        .accessibilityHidden(true)
    }

    private var playButton: some View {
        Button {
            tapCount += 1
            engine.toggle()
        } label: {
            Label(engine.isPlaying ? "Zastaviť" : "Spustiť", systemImage: engine.isPlaying ? "stop.fill" : "play.fill")
                .font(.headline.weight(.bold))
                .foregroundColor(engine.isPlaying ? .white : Color.obsidian900)
                .contentTransition(.symbolEffect(.replace))
                .frame(maxWidth: .infinity, minHeight: 54)
                .background {
                    if engine.isPlaying {
                        RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.12))
                    } else {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(LinearGradient(colors: [Color.gold400, Color.gold500], startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.gold400.opacity(engine.isPlaying ? 0.45 : 0), lineWidth: 1)
                )
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("metronome.play")
    }

    // MARK: Speed
    private var speedCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HomeSectionHeader(title: "RÝCHLOSŤ", systemImage: "gauge.with.dots.needle.67percent")

            HStack(spacing: 16) {
                LiquidGlassCircleButton(icon: "minus", label: "Pomalšie o 1 úder", size: 44) { nudge(by: -1) }
                VStack(spacing: 2) {
                    Text("\(Int((engine.tempoMultiplier * 100).rounded())) %")
                        .font(.system(.title2, design: .rounded).weight(.heavy))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                    Text("základného tempa")
                        .font(.caption)
                        .foregroundColor(Color.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: engine.tempoMultiplier)
                LiquidGlassCircleButton(icon: "plus", label: "Rýchlejšie o 1 úder", size: 44) { nudge(by: 1) }
            }

            HStack(spacing: 8) {
                ForEach(Self.speeds, id: \.self) { speed in
                    let isSelected = abs(engine.tempoMultiplier - speed) < 0.005
                    Button {
                        engine.tempoMultiplier = speed
                        restartIfPlaying()
                    } label: {
                        Text("\(Int(speed * 100)) %")
                            .font(.footnote.weight(isSelected ? .bold : .semibold))
                            .foregroundColor(isSelected ? Color.obsidian900 : .white.opacity(0.85))
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(isSelected ? Color.gold400 : Color.white.opacity(0.08), in: Capsule())
                    }
                    .buttonStyle(.pressable)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
        .padding(16)
        .homeCard(cornerRadius: 20)
    }

    // MARK: Dances
    private func danceSection(_ title: String, _ presets: [DanceMetronomePreset]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HomeSectionHeader(title: title)
            FlowLayout(spacing: 8) {
                ForEach(presets) { preset in
                    let isSelected = engine.selectedPreset == preset
                    Button {
                        lastDance = preset.rawValue
                        engine.tempoMultiplier = 1
                        if engine.isPlaying { engine.start(preset: preset) } else { engine.selectedPreset = preset }
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(preset.category == "Standard" ? Color.standardBlue : Color.latinCrimson)
                                .frame(width: 7, height: 7)
                            Text(preset.chipName)
                        }
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(isSelected ? Color.obsidian900 : .white.opacity(0.9))
                        .padding(.horizontal, 14)
                        .frame(minHeight: 36)
                        .background(isSelected ? Color.gold400 : Color.white.opacity(0.08), in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(isSelected ? 0 : 0.1), lineWidth: 1))
                    }
                    .buttonStyle(.pressable)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
                }
            }
        }
    }

    // MARK: Settings
    private var settingsCard: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $engine.isSoundEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Zvuk", systemImage: "speaker.wave.2.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                    Text("Hrá aj v tichom režime a cez hudbu v sále.")
                        .font(.caption)
                        .foregroundColor(Color.textSecondary)
                }
            }
            .padding(.vertical, 12)
            Divider().overlay(Color.white.opacity(0.1))
            Toggle(isOn: $engine.isHapticEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Vibrácie", systemImage: "hand.tap.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                    Text("Rytmus cítiš v ruke aj bez zvuku.")
                        .font(.caption)
                        .foregroundColor(Color.textSecondary)
                }
            }
            .padding(.vertical, 12)
        }
        .tint(Color.gold500)
        .padding(.horizontal, 16)
        .homeCard(cornerRadius: 20)
    }

    // MARK: Actions
    /// One beat per minute slower or faster than now.
    private func nudge(by delta: Int) {
        let bpm = max(40, min(260, engine.effectiveBpm + delta))
        guard engine.selectedPreset.bpm > 0 else { return }
        engine.tempoMultiplier = Double(bpm) / engine.selectedPreset.bpm
        restartIfPlaying()
    }

    private func restartIfPlaying() {
        if engine.isPlaying { engine.start() }
    }
}

// MARK: - Xcode Canvas Preview
#Preview("Metronóm") {
    DanceMetronomeView()
        .preferredColorScheme(.dark)
}
