import SwiftUI
import SwiftData

// MARK: - Capture modes
enum CaptureInputMode: String, CaseIterable, Identifiable {
    case text = "Text"
    case voice = "Hlas"
    case camera = "Kamera"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .text: return "square.and.pencil"
        case .voice: return "waveform"
        case .camera: return "video.fill"
        }
    }
}

// MARK: - Home capture workspace
/// The note capture area on Home: the field (text / voice / camera), the mode switch right under it
/// and one dance choice that applies to every kind of note.
struct HomeCaptureWorkspace: View {
    let fieldHeight: CGFloat
    /// True while the text field is focused. Home sets it to false to close the keyboard.
    @Binding var isTyping: Bool
    /// Home's command palette can open the camera too, so the request lives in Home.
    @Binding var isCameraPresented: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var mode: CaptureInputMode = .text
    @State private var draft = ""
    @State private var selectedDance: String?
    @State private var savedCounter = 0
    @State private var showSaved = false
    @State private var sweepTrigger = 0
    @State private var capturedVideoPath: String?
    @FocusState private var isTextFocused: Bool
    @Namespace private var modeNamespace
    @ObservedObject private var quickActions = QuickActionRouter.shared
    @State private var startVoiceNow = false

    var body: some View {
        VStack(spacing: 14) {
            captureArea
                .frame(height: fieldHeight)
                .padding(.horizontal, 4)
            modeSwitcher
            DanceMenuCapsule(selection: $selectedDance)
        }
        .fullScreenCover(isPresented: $isCameraPresented) {
            DanceCameraView(savesToPhotos: true) { localPath in
                capturedVideoPath = localPath
                // No text: Denník names a clip "Tréningové video" itself, and a stored label landed in figure notes.
                save(InstantNote(videoPath: localPath, danceName: selectedDance))
                isCameraPresented = false
            }
            .ignoresSafeArea()
        }
        .onChange(of: isTextFocused) { _, focused in
            if focused { sweepTrigger += 1 }
            isTyping = focused
        }
        .onChange(of: isTyping) { _, typing in
            if !typing { isTextFocused = false }
        }
        .task(id: savedCounter) {
            // Short "Uložené" confirmation after each save.
            guard savedCounter > 0 else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showSaved = true }
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.easeOut(duration: 0.3)) { showSaved = false }
        }
        .sensoryFeedback(.success, trigger: savedCounter)
        .sensoryFeedback(.selection, trigger: mode)
        .onChange(of: quickActions.pending, initial: true) { _, action in
            guard let action, [.video, .voice, .text].contains(action) else { return }
            quickActions.pending = nil
            open(action)
        }
    }

    /// A Lock Screen button: the camera, a voice note that records right away, or the text field ready to type.
    private func open(_ action: QuickAction) {
        switch action {
        case .video:
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { mode = .camera }
            isCameraPresented = true
        case .voice:
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { mode = .voice }
            startVoiceNow = true
        case .text:
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { mode = .text }
            Task {
                // After the tab switch and the mode change, so the keyboard comes up on the visible field.
                try? await Task.sleep(for: .milliseconds(400))
                isTextFocused = true
            }
        case .ksis, .results:
            break
        }
    }

    // MARK: Field
    private var captureArea: some View {
        ZStack(alignment: .top) {
            switch mode {
            case .text:
                textCapture.transition(.opacity)
            case .voice:
                VoiceCaptureView(startNow: $startVoiceNow) { fileName, duration in
                    save(InstantNote(audioPath: fileName, audioDuration: duration, danceName: selectedDance))
                }
                .transition(.opacity)
            case .camera:
                cameraCapture.transition(.opacity)
            }

            if showSaved {
                Label("Uložené", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundColor(Color.syncEmerald)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .transition(.opacity.combined(with: .scale))
                    .accessibilityAddTraits(.isStaticText)
            }
        }
    }

    private var textCapture: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topLeading) {
                if draft.isEmpty {
                    Text("Zadaj myšlienku, figúru, technickú pripomienku alebo postreh z tréningu...")
                        .font(.callout)
                        .foregroundColor(Color.textPlaceholder)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }

                TextEditor(text: $draft)
                    .focused($isTextFocused)
                    .scrollContentBackground(.hidden)
                    .font(.callout.weight(.medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel("Nová poznámka")
            }
            .contentShape(Rectangle())
            .onTapGesture { isTextFocused = true }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay { FieldEdgeSweep(trigger: sweepTrigger) }

            if !trimmedDraft.isEmpty {
                HStack {
                    Button("Vymazať") { draft = "" }
                        .font(.footnote.weight(.medium))
                        .foregroundColor(Color.textSecondary)
                        .frame(minHeight: 44)

                    Spacer()

                    Button(action: saveText) {
                        Label("Uložiť poznámku", systemImage: "arrow.up.circle.fill")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(Color.obsidian900)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(colors: [Color.gold500, Color.gold400], startPoint: .leading, endPoint: .trailing),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.pressable)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.85), value: trimmedDraft.isEmpty)
    }

    private var cameraCapture: some View {
        VStack(spacing: 14) {
            if let videoPath = capturedVideoPath {
                LoopingVideoPlayer(videoPath: videoPath, rate: 1.0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.gold400.opacity(0.35), lineWidth: 1.2)
                    )
                    .overlay(alignment: .topTrailing) {
                        // The clip is already saved in Denník; this only hides the preview.
                        LiquidGlassCircleButton(icon: "xmark", label: "Skryť náhľad", size: 36) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { capturedVideoPath = nil }
                        }
                        .padding(10)
                    }
                    .transition(.scale(scale: 0.96).combined(with: .opacity))

                Button { isCameraPresented = true } label: {
                    Label("Natočiť ďalšie", systemImage: "record.circle")
                        .font(.footnote.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.pressable)
            } else {
                Spacer(minLength: 0)

                // Icon beside the title, so the text always has room for both lines.
                HStack(spacing: 12) {
                    Image(systemName: "video.fill")
                        .font(.title3)
                        .foregroundColor(Color.gold400)
                        .frame(width: 48, height: 48)
                        .overlay(Circle().stroke(Color.gold400.opacity(0.4), lineWidth: 1.5))
                        .background(Color.gold500.opacity(0.12), in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Tanečná kamera")
                            .font(.callout.weight(.bold))
                            .foregroundColor(.white)
                        Text("Video sa uloží do Denníka, k figúre ho dáš neskôr.")
                            .font(.caption)
                            .foregroundColor(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 12)

                Spacer(minLength: 0)

                Button { isCameraPresented = true } label: {
                    Label("Otvoriť kameru", systemImage: "record.circle")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(Color.obsidian900)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(colors: [Color.gold500, Color.gold400], startPoint: .leading, endPoint: .trailing),
                            in: Capsule()
                        )
                }
                .buttonStyle(.pressable)
                .padding(.bottom, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Mode switch
    private var modeSwitcher: some View {
        HStack(spacing: 12) {
            ForEach(CaptureInputMode.allCases) { item in
                let isSelected = mode == item
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.78)) { mode = item }
                } label: {
                    Label(item.rawValue, systemImage: item.iconName)
                        .font(.footnote.weight(isSelected ? .bold : .medium))
                        .foregroundColor(isSelected ? .white : Color.white.opacity(0.75))
                        .padding(.vertical, 9)
                        .padding(.horizontal, 16)
                        .background {
                            ZStack {
                                Capsule().fill(Color.white.opacity(0.05))
                                if isSelected {
                                    Capsule()
                                        .fill(Color.white.opacity(0.14))
                                        .matchedGeometryEffect(id: "modeSelection", in: modeNamespace)
                                }
                            }
                        }
                        .overlay(
                            Capsule().stroke(
                                isSelected ? Color.gold400.opacity(0.45) : Color.white.opacity(0.08),
                                lineWidth: 1
                            )
                        )
                }
                .buttonStyle(.pressable)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Saving
    private var trimmedDraft: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func saveText() {
        guard !trimmedDraft.isEmpty else { return }
        save(InstantNote(text: trimmedDraft, danceName: selectedDance))
        draft = ""
        isTextFocused = false
    }

    private func save(_ note: InstantNote) {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
            modelContext.insert(note)
        }
        try? modelContext.save()
        savedCounter += 1
    }
}
