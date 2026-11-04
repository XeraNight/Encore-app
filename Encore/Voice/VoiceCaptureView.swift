import SwiftUI

/// Voice notes on Home. Records the real audio in full quality; the dancer listens to it later and
/// writes down what matters. Owns the recorder so the fast-changing level only redraws this view.
struct VoiceCaptureView: View {
    /// Set by the Lock Screen button: start recording right away (it resets itself).
    @Binding var startNow: Bool
    /// Called with the saved file name and its length when the recording is kept.
    let onSave: (String, TimeInterval) -> Void

    @StateObject private var recorder = VoiceNoteRecorder()

    init(startNow: Binding<Bool> = .constant(false), onSave: @escaping (String, TimeInterval) -> Void) {
        _startNow = startNow
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            waveform

            switch recorder.state {
            case .idle:
                Text(recorder.errorMessage ?? "Klepni na mikrofón a nahraj poznámku. Zvuk sa uloží v plnej kvalite, vypočuješ si ho neskôr.")
                    .font(.system(size: 14))
                    .foregroundColor(recorder.errorMessage == nil ? .white.opacity(0.45) : Color.latinRed)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 20)
            case .recording:
                Text(voiceTimeString(recorder.elapsed))
                    .font(.system(size: 34, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
            case .recorded:
                if let fileName = recorder.fileName {
                    VoiceNotePlayerView(fileName: fileName)
                        .padding(14)
                        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal, 8)
                }
            }

            Spacer()

            controls
                .padding(.bottom, 22)
                .animation(.spring(response: 0.3, dampingFraction: 0.75), value: recorder.state)
        }
        .onDisappear(perform: keepWhatWasRecorded)
        .sensoryFeedback(.impact(flexibility: .rigid), trigger: recorder.state)
        .onChange(of: startNow, initial: true) { _, start in
            guard start else { return }
            startNow = false
            guard recorder.state == .idle else { return }
            Task { await recorder.start() }
        }
    }

    // MARK: Controls
    @ViewBuilder
    private var controls: some View {
        switch recorder.state {
        case .idle, .recording:
            micButton
        case .recorded:
            HStack(spacing: 14) {
                Button("Zahodiť") { recorder.discard() }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.7))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(Color.white.opacity(0.08), in: Capsule())
                    .buttonStyle(.pressable)

                Button(action: save) {
                    Text("Uložiť nahrávku")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.obsidian900)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(
                            LinearGradient(colors: [Color.gold500, Color.gold400], startPoint: .leading, endPoint: .trailing),
                            in: Capsule()
                        )
                }
                .buttonStyle(.pressable)
            }
            .transition(.scale.combined(with: .opacity))
        }
    }

    private var micButton: some View {
        let isRecording = recorder.state == .recording
        return Button {
            if isRecording { recorder.stop() } else { Task { await recorder.start() } }
        } label: {
            ZStack {
                Circle()
                    .fill(isRecording ? Color.latinCrimson.opacity(0.20) : Color.gold500.opacity(0.15))
                    .frame(width: 76, height: 76)
                    .scaleEffect(isRecording ? 1.0 + min(recorder.level, 1.0) * 0.35 : 1.0)
                    .animation(.easeOut(duration: 0.1), value: recorder.level)

                Circle()
                    .fill(isRecording ? Color.latinCrimson : Color.gold500)
                    .frame(width: 60, height: 60)

                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(isRecording ? .white : Color.obsidian900)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .buttonStyle(.pressable(scale: 0.9))
        .accessibilityLabel(isRecording ? "Zastaviť nahrávanie" : "Nahrať hlasovú poznámku")
    }

    private var waveform: some View {
        let isRecording = recorder.state == .recording
        return HStack(spacing: 4) {
            ForEach(0..<20, id: \.self) { index in
                let waveFactor = sin(Double(index) / 20.0 * .pi)
                let barHeight: CGFloat = isRecording
                    ? max(6, 10 + recorder.level * 50 * CGFloat(waveFactor))
                    : 6
                Capsule()
                    .fill(
                        isRecording
                        ? LinearGradient(colors: [Color.latinCrimson, Color.gold400], startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [Color.white.opacity(0.18), Color.white.opacity(0.08)], startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: 4, height: barHeight)
                    .animation(.easeOut(duration: 0.08), value: barHeight)
            }
        }
        .frame(height: 70)
    }

    // MARK: Saving
    private func save() {
        guard let result = recorder.takeResult() else { return }
        onSave(result.fileName, result.duration)
    }

    /// Leaving the screen never loses a recording: what was captured goes to the inbox.
    private func keepWhatWasRecorded() {
        if recorder.state == .recording { recorder.stop() }
        if recorder.state == .recorded { save() }
    }
}
