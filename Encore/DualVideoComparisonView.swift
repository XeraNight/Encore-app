import SwiftUI
import AVKit
import Combine
import OSLog

// MARK: - Layout, sound, slots
enum DualLayoutMode: String, CaseIterable, Identifiable {
    case stacked = "Nad sebou"
    case sideBySide = "Vedľa seba"
    case singleSwitch = "Prepínanie"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .stacked: return "rectangle.split.1x2"
        case .sideBySide: return "rectangle.split.2x1"
        case .singleSwitch: return "arrow.left.arrow.right.square"
        }
    }
}

enum DualAudioSource: String, CaseIterable, Identifiable {
    case slotA = "Zvuk z môjho videa"
    case slotB = "Zvuk zo vzoru"
    case mute = "Bez zvuku"

    var id: String { rawValue }
}

enum DualSlot: String, Identifiable {
    case a = "Moje video alebo fotka"
    case b = "Vzor"

    var id: String { rawValue }
}

// MARK: - Porovnanie
/// My video next to (or under) a model video (BRAND_GUIDELINES §1A, docs/V1_UI_FEATURE_REVIEW.md §4).
/// A calm screen: the videos, playback and three tools.
/// - Zarovnať: find the same moment in both videos once; then they play together.
/// - Prekrytie: the model lies see-through over my video; two fingers fit it to my body.
/// - Čiary: plumb line and level line with the tilt.
/// "Uložiť" turns the moment into a correction in the figure's notes (overlay, lines and corrections are Premium).
struct DualVideoComparisonView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    @Binding var pathA: String?
    @Binding var pathB: String?
    var titleA: String = "Ja"
    var titleB: String = "Vzor"
    /// The figure this comparison belongs to. With `onSaveCorrection` the save button adds a correction
    /// to its notes; without a figure it saves the snapshot to Fotky.
    var figureName: String? = nil
    var onSaveCorrection: ((FigureCorrection) -> Void)? = nil

    // Players
    @State private var playerA: AVPlayer?
    @State private var playerB: AVPlayer?
    @State private var loopToken: Any?
    @State private var timeObserverToken: Any?
    @State private var timeObserverPlayer: AVPlayer?
    @State private var setupGeneration = 0
    @State private var resolvedURLA: URL?
    @State private var resolvedURLB: URL?
    @State private var isResolving = false
    @State private var imageA: UIImage?
    @State private var imageB: UIImage?
    @State private var frameDurationA = 1.0 / 30
    @State private var frameDurationB = 1.0 / 30
    @State private var durationB = 1.0

    // Playback
    @State private var isPlaying = false
    @State private var currentTime = 0.0
    @State private var duration = 1.0
    @State private var isScrubbing = false
    /// A drift correction is under way (the follower video is being put back on the leader's time).
    @State private var isResyncing = false
    @State private var playbackRate: Float = 1.0
    @State private var isLooping = true
    /// How far the model video is ahead of mine once "Zarovnať" found the same moment in both.
    @State private var offsetB = 0.0
    @State private var layoutMode: DualLayoutMode = .stacked
    @State private var userPickedLayout = false
    @State private var showsSlotB = false
    @State private var audioSource: DualAudioSource = .slotA

    // Tools
    @State private var isAligning = false
    @State private var alignTimeB = 0.0
    @State private var isOverlayOn = false
    @State private var overlayOpacity = 0.5
    @State private var overlayMirrored = false
    @State private var overlayScale: CGFloat = 1
    @State private var overlayOffset: CGSize = .zero
    @State private var overlayScaleBase: CGFloat?
    @State private var overlayOffsetBase: CGSize?
    @State private var showsGuides = false
    @State private var guides = AnalysisGuides()
    @State private var analysisSize: CGSize = .zero

    // Sheets and feedback
    @State private var pickerSlot: DualSlot?
    @State private var showPaywall = false
    @State private var correctionSnapshot: UIImage?
    @State private var showCorrectionSheet = false
    @State private var isPreparingSnapshot = false
    @State private var toast: String?
    @State private var toolTaps = 0
    @State private var successTaps = 0

    private var hasA: Bool { playerA != nil || imageA != nil }
    private var hasB: Bool { playerB != nil || imageB != nil }
    private var hasVideo: Bool { playerA != nil || playerB != nil }
    private var canCompareBoth: Bool { hasA && hasB }
    private var isPremium: Bool { subscriptionManager.currentTier >= .premium }
    private var isAligned: Bool { abs(offsetB) > 0.001 }
    private var isOverlayShown: Bool { isOverlayOn && canCompareBoth }

    /// The slot that gets the lines and the snapshot.
    private var analysisSlot: DualSlot {
        if layoutMode == .singleSwitch { return showsSlotB ? .b : .a }
        return hasA || !hasB ? .a : .b
    }

    var body: some View {
        ZStack {
            EllegancePageBackground()

            VStack(spacing: 12) {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                viewport
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 12)

                Group {
                    if isAligning { alignDeck } else { controlDeck }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if let toast {
                VStack {
                    Text(toast)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .glassEffect(.regular, in: Capsule())
                        .padding(.top, 64)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityAddTraits(.isStaticText)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isAligning)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isOverlayShown)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: layoutMode)
        .sheet(item: $pickerSlot) { slot in
            UniversalMediaPickerSheet(
                slotTitle: slot.rawValue,
                currentPath: slot == .a ? pathA : pathB,
                onSelectMedia: { selectedPath in
                    if slot == .a { pathA = selectedPath } else { pathB = selectedPath }
                },
                onClearMedia: {
                    if slot == .a { pathA = nil } else { pathB = nil }
                }
            )
        }
        .sheet(isPresented: $showPaywall) {
            SubscriptionPaywallView(initialTier: .premium)
        }
        .sheet(isPresented: $showCorrectionSheet) {
            FigureCorrectionSheet(
                figureName: figureName ?? "",
                snapshot: correctionSnapshot,
                tilt: showsGuides && guides.showsLevel ? guides.roundedAngle : nil
            ) { correction, alsoToPhotos in
                onSaveCorrection?(correction)
                successTaps += 1
                showToast("Korekcia je v poznámkach figúry")
                if alsoToPhotos, let snapshot = correctionSnapshot {
                    Task { await saveToPhotos(snapshot, announce: false) }
                }
            }
        }
        .onChange(of: pathA) { setupPlayers() }
        .onChange(of: pathB) { setupPlayers() }
        .onChange(of: audioSource) { applyAudioVolumes() }
        .onAppear { setupPlayers() }
        .onDisappear { tearDownPlayers() }
        .sensoryFeedback(.impact(weight: .light), trigger: toolTaps)
        .sensoryFeedback(.success, trigger: successTaps)
        .preferredColorScheme(.dark)
    }

    // MARK: - Top bar
    private var topBar: some View {
        HStack(spacing: 12) {
            LiquidGlassCircleButton(icon: "xmark", label: "Zavrieť") {
                tearDownPlayers()
                dismiss()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Porovnanie")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundColor(.white)
                if let figureName, !figureName.isEmpty {
                    Text(figureName)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Color.gold400)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if hasA || hasB {
                LiquidGlassCircleButton(
                    icon: isPreparingSnapshot ? "hourglass" : "square.and.arrow.down",
                    label: onSaveCorrection == nil ? "Uložiť snímku do Fotiek" : "Uložiť korekciu",
                    isActive: true
                ) {
                    requirePremium { Task { await startSaving() } }
                }
                .disabled(isPreparingSnapshot)
            }

            Menu {
                moreMenu
            } label: {
                GlassCircleLabel(icon: "ellipsis")
            }
            .accessibilityLabel("Ďalšie možnosti")
        }
    }

    @ViewBuilder
    private var moreMenu: some View {
        Picker(selection: Binding(
            get: { layoutMode },
            set: { layoutMode = $0; userPickedLayout = true }
        )) {
            ForEach(DualLayoutMode.allCases) { mode in
                Label(mode.rawValue, systemImage: mode.iconName).tag(mode)
            }
        } label: {
            Label("Rozloženie", systemImage: "rectangle.3.group")
        }
        .pickerStyle(.menu)

        if hasVideo {
            Picker(selection: $audioSource) {
                ForEach(DualAudioSource.allCases) { source in
                    Text(source.rawValue).tag(source)
                }
            } label: {
                Label("Zvuk", systemImage: "speaker.wave.2")
            }
            .pickerStyle(.menu)

            Toggle(isOn: $isLooping) {
                Label("Opakovať", systemImage: "repeat")
            }
        }

        if showsGuides {
            Toggle(isOn: $guides.showsPlumb) {
                Label("Olovnica", systemImage: "arrow.up.and.down")
            }
            Toggle(isOn: $guides.showsLevel) {
                Label("Vodorovná čiara", systemImage: "level")
            }
        }

        if canCompareBoth {
            Button {
                swapSlots()
            } label: {
                Label("Prehodiť videá", systemImage: "arrow.left.arrow.right")
            }
        }

        if isAligned {
            Button(role: .destructive) {
                offsetB = 0
                seekPlayers(to: currentTime)
            } label: {
                Label("Zrušiť zarovnanie", systemImage: "arrow.uturn.backward")
            }
        }
    }

    // MARK: - Videos
    @ViewBuilder
    private var viewport: some View {
        if isOverlayShown {
            overlayViewport
        } else {
            switch layoutMode {
            case .stacked:
                VStack(spacing: 8) {
                    slotView(.a)
                    slotView(.b)
                }
            case .sideBySide:
                HStack(spacing: 8) {
                    slotView(.a)
                    slotView(.b)
                }
            case .singleSwitch:
                VStack(spacing: 8) {
                    Picker("Zobraziť", selection: $showsSlotB) {
                        Text(titleA).tag(false)
                        Text(titleB).tag(true)
                    }
                    .pickerStyle(.segmented)
                    slotView(showsSlotB ? .b : .a)
                }
            }
        }
    }

    private func slotView(_ slot: DualSlot) -> some View {
        let isAnalysis = slot == analysisSlot
        let hasMedia = slot == .a ? hasA : hasB
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.55))

            media(for: slot)

            if showsGuides && isAnalysis && hasMedia {
                AnalysisGuidesOverlay(guides: $guides)
                    .transition(.opacity)
            }

            slotHeader(slot)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
            if isAnalysis { analysisSize = size }
        }
    }

    @ViewBuilder
    private func media(for slot: DualSlot) -> some View {
        let path = slot == .a ? pathA : pathB
        if let image = slot == .a ? imageA : imageB {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let player = slot == .a ? playerA : playerB {
            CustomAVPlayerRepresentable(player: player, gravity: .resizeAspect)
        } else if path != nil && isResolving {
            ProgressView()
                .tint(Color.gold400)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if path != nil {
            missingMediaView(slot)
        } else {
            emptySlotButton(slot)
        }
    }

    private func slotHeader(_ slot: DualSlot) -> some View {
        let isA = slot == .a
        return HStack(spacing: 6) {
            Text(isA ? titleA : titleB)
                .font(.system(.caption, design: .rounded).weight(.heavy))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isA ? Color.latinRed : Color.gold400, in: Capsule())
                .foregroundColor(isA ? .white : Color.obsidian900)

            Spacer(minLength: 0)

            if (isA ? pathA : pathB) != nil {
                Menu {
                    Button {
                        pickerSlot = slot
                    } label: {
                        Label("Zmeniť", systemImage: "arrow.triangle.2.circlepath")
                    }
                    Button(role: .destructive) {
                        if isA { pathA = nil } else { pathB = nil }
                    } label: {
                        Label("Odstrániť z porovnania", systemImage: "xmark")
                    }
                } label: {
                    GlassCircleLabel(icon: "ellipsis", size: 32)
                }
                .accessibilityLabel(isA ? "Moje video: možnosti" : "Vzor: možnosti")
            }
        }
        .padding(8)
    }

    private func emptySlotButton(_ slot: DualSlot) -> some View {
        Button {
            pickerSlot = slot
            toolTaps += 1
        } label: {
            VStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(slot == .a ? Color.latinRed : Color.gold400)
                    .frame(width: 52, height: 52)
                    .glassEffect(.regular, in: .circle)
                Text(slot == .a ? "Vyber svoje video alebo fotku" : "Vyber vzor")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
                Text("Z knižnice, z Fotiek alebo natoč nové")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
    }

    /// The slot has a video or photo, but it is not on this iPhone or cannot be played.
    private func missingMediaView(_ slot: DualSlot) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "video.slash.fill")
                .font(.title2)
                .foregroundColor(Color.gold400)
            Text("Video sa nenašlo")
                .font(.subheadline.weight(.bold))
                .foregroundColor(.white)
            Text("Nie je v tomto iPhone alebo sa nedá prehrať.")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.65))
                .multilineTextAlignment(.center)
            Button {
                pickerSlot = slot
            } label: {
                Text("Vybrať iné")
                    .font(.footnote.weight(.bold))
                    .foregroundColor(Color.obsidian900)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 36)
                    .background(Color.gold400, in: Capsule())
            }
            .buttonStyle(.pressable)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Overlay
    private var overlayViewport: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.55))

            media(for: .a)

            media(for: .b)
                .scaleEffect(x: overlayMirrored ? -overlayScale : overlayScale, y: overlayScale)
                .offset(overlayOffset)
                .opacity(overlayOpacity)
                .allowsHitTesting(false)

            if showsGuides {
                AnalysisGuidesOverlay(guides: $guides)
                    .transition(.opacity)
            }

            VStack(spacing: 0) {
                HStack {
                    Text("\(titleA) + \(titleB.lowercased())")
                        .font(.system(.caption, design: .rounded).weight(.heavy))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.gold400, in: Capsule())
                        .foregroundColor(Color.obsidian900)
                    if !showsGuides {
                        Text("Dvoma prstami prispôsob vzor")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.white.opacity(0.75))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    Spacer(minLength: 0)
                }
                .padding(8)
                Spacer()
                overlayControls
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.gold400.opacity(0.35), lineWidth: 1)
        )
        .contentShape(Rectangle())
        // With the lines shown, touches belong to the lines; the model stays where it was fitted.
        .gesture(overlayTransformGesture, including: showsGuides ? .subviews : .all)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { analysisSize = $0 }
    }

    private var overlayControls: some View {
        HStack(spacing: 10) {
            Image(systemName: "circle.lefthalf.filled")
                .foregroundColor(.white.opacity(0.8))
                .accessibilityHidden(true)
            Slider(value: $overlayOpacity, in: 0.15...0.85)
                .tint(Color.gold400)
                .accessibilityLabel("Priehľadnosť vzoru")
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { overlayMirrored.toggle() }
                toolTaps += 1
            } label: {
                Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(overlayMirrored ? Color.obsidian900 : .white)
                    .frame(width: 36, height: 36)
                    .background(overlayMirrored ? Color.gold400 : Color.white.opacity(0.12), in: Circle())
            }
            .buttonStyle(.pressable(scale: 0.9))
            .accessibilityLabel("Zrkadliť vzor")
            .accessibilityAddTraits(overlayMirrored ? .isSelected : [])

            if overlayScale != 1 || overlayOffset != .zero {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        overlayScale = 1
                        overlayOffset = .zero
                    }
                    toolTaps += 1
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.12), in: Circle())
                }
                .buttonStyle(.pressable(scale: 0.9))
                .accessibilityLabel("Vrátiť vzor na pôvodné miesto")
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
        .glassEffect(.regular, in: Capsule())
        .padding(10)
    }

    private var overlayTransformGesture: some Gesture {
        SimultaneousGesture(
            MagnifyGesture()
                .onChanged { value in
                    let base = overlayScaleBase ?? overlayScale
                    overlayScaleBase = base
                    overlayScale = min(max(base * value.magnification, 0.5), 3)
                }
                .onEnded { _ in overlayScaleBase = nil },
            DragGesture()
                .onChanged { value in
                    let base = overlayOffsetBase ?? overlayOffset
                    overlayOffsetBase = base
                    overlayOffset = CGSize(width: base.width + value.translation.width,
                                           height: base.height + value.translation.height)
                }
                .onEnded { _ in overlayOffsetBase = nil }
        )
    }

    // MARK: - Control deck
    private var controlDeck: some View {
        VStack(spacing: 14) {
            if hasVideo {
                VStack(spacing: 4) {
                    Slider(
                        value: Binding(get: { currentTime }, set: { newTime in
                            currentTime = newTime
                            seekPlayers(to: newTime)
                        }),
                        in: 0...max(duration, 0.1),
                        onEditingChanged: { editing in
                            // Both stand still while dragging and start together again on release.
                            isScrubbing = editing
                            if editing {
                                playerA?.pause()
                                playerB?.pause()
                            } else if isPlaying {
                                Task { await playTogether(from: currentTime) }
                            }
                        }
                    )
                    .tint(Color.gold400)
                    .accessibilityLabel("Čas")
                    .accessibilityValue(formatTime(currentTime))

                    HStack {
                        Text(formatTime(currentTime))
                        Spacer()
                        Text(formatTime(duration))
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.white.opacity(0.6))
                }

                HStack(spacing: 28) {
                    LiquidGlassCircleButton(icon: "backward.frame.fill", label: "O snímku späť") { stepFrame(by: -1) }
                    playButton
                    LiquidGlassCircleButton(icon: "forward.frame.fill", label: "O snímku dopredu") { stepFrame(by: 1) }
                }
            } else if canCompareBoth {
                Text("Obe sú fotky: porovnaj polohu tela, rúk a ťažisko.")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            if hasA || hasB {
                toolRow
            }
        }
        .padding(14)
        .homeCard(cornerRadius: 22)
    }

    private var playButton: some View {
        Button(action: togglePlayPause) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color.obsidian900)
                .contentTransition(.symbolEffect(.replace))
                .offset(x: isPlaying ? 0 : 1.5)
                .frame(width: 60, height: 60)
                .background(
                    LinearGradient(colors: [Color.gold400, Color.gold500], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: Circle()
                )
                .shadow(color: Color.gold500.opacity(0.35), radius: 10, y: 4)
        }
        .buttonStyle(.pressable(scale: 0.9))
        .sensoryFeedback(.impact(weight: .medium), trigger: isPlaying)
        .accessibilityLabel(isPlaying ? "Pozastaviť" : "Prehrať")
    }

    private var toolRow: some View {
        HStack(spacing: 8) {
            if hasVideo {
                Menu {
                    ForEach(Self.rates, id: \.self) { rate in
                        Button(Self.rateText(rate)) { setRate(rate) }
                    }
                } label: {
                    toolChip(Self.rateText(playbackRate), icon: "tortoise.fill", isOn: playbackRate < 1)
                }
                .accessibilityLabel("Rýchlosť \(Self.rateText(playbackRate))")
            }

            if hasVideo && canCompareBoth {
                Button {
                    startAligning()
                } label: {
                    toolChip("Zarovnať", icon: "arrow.left.and.right", isOn: isAligned)
                }
                .buttonStyle(.pressable)
            }

            if canCompareBoth {
                Button {
                    requirePremium {
                        isOverlayOn.toggle()
                        toolTaps += 1
                    }
                } label: {
                    toolChip("Prekrytie", icon: "square.on.square", isOn: isOverlayOn, locked: !isPremium)
                }
                .buttonStyle(.pressable)
            }

            Button {
                requirePremium {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showsGuides.toggle() }
                    toolTaps += 1
                }
            } label: {
                toolChip("Čiary", icon: "ruler", isOn: showsGuides, locked: !isPremium)
            }
            .buttonStyle(.pressable)
        }
    }

    private func toolChip(_ title: String, icon: String, isOn: Bool, locked: Bool = false) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .symbolEffect(.bounce, value: isOn)
            Text(title)
                .font(.caption2.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundColor(isOn ? Color.obsidian900 : .white)
        .frame(maxWidth: .infinity, minHeight: 54)
        .background(isOn ? AnyShapeStyle(Color.gold400) : AnyShapeStyle(Color.white.opacity(0.07)),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isOn ? Color.gold400 : Color.white.opacity(0.12), lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            if locked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color.gold400)
                    .padding(6)
                    .accessibilityLabel("Premium")
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.75), value: isOn)
    }

    // MARK: - Align deck
    private var alignDeck: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeader(title: "ZAROVNAŤ VZOR", systemImage: "arrow.left.and.right")
            Text("Tvoje video stojí na \(formatTime(currentTime, precise: true)). Posuň vzor na ten istý moment, napríklad na prvý krok figúry.")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)

            Slider(
                value: Binding(get: { alignTimeB }, set: { newTime in
                    alignTimeB = newTime
                    seekB(to: newTime)
                }),
                in: 0...max(durationB, 0.1)
            )
            .tint(Color.gold400)
            .accessibilityLabel("Čas vzoru")
            .accessibilityValue(formatTime(alignTimeB, precise: true))

            HStack(spacing: 20) {
                LiquidGlassCircleButton(icon: "backward.frame.fill", label: "Vzor o snímku späť") { stepAlign(by: -1) }
                Text(formatTime(alignTimeB, precise: true))
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                LiquidGlassCircleButton(icon: "forward.frame.fill", label: "Vzor o snímku dopredu") { stepAlign(by: 1) }
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 10) {
                Button {
                    cancelAligning()
                } label: {
                    Text("Zrušiť")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.pressable)

                PrimarySheetButton(title: "Hotovo", isLoading: false, isEnabled: true) { finishAligning() }
            }
        }
        .padding(14)
        .homeCard(cornerRadius: 22)
    }

    private func startAligning() {
        if isPlaying { togglePlayPause() }
        if layoutMode == .singleSwitch { showsSlotB = true }
        alignTimeB = min(max(currentTime + offsetB, 0), durationB)
        seekB(to: alignTimeB)
        isAligning = true
        toolTaps += 1
    }

    private func finishAligning() {
        offsetB = alignTimeB - currentTime
        isAligning = false
        seekPlayers(to: currentTime)
        successTaps += 1
        showToast("Videá sú zarovnané a hrajú spolu")
    }

    private func cancelAligning() {
        isAligning = false
        seekPlayers(to: currentTime)
    }

    private func stepAlign(by frames: Int) {
        alignTimeB = min(max(alignTimeB + Double(frames) * frameDurationB, 0), durationB)
        seekB(to: alignTimeB)
    }

    // MARK: - Saving
    private func requirePremium(_ action: () -> Void) {
        if isPremium {
            action()
        } else {
            showPaywall = true
        }
    }

    private func startSaving() async {
        if isPlaying { togglePlayPause() }
        isPreparingSnapshot = true
        let snapshot = await makeSnapshot()
        isPreparingSnapshot = false

        if onSaveCorrection != nil {
            correctionSnapshot = snapshot
            showCorrectionSheet = true
        } else if let snapshot {
            await saveToPhotos(snapshot, announce: true)
        } else {
            showToast("Snímku sa nepodarilo pripraviť")
        }
    }

    /// What the user sees in the analysed slot: the frame, the model over it and the lines.
    private func makeSnapshot() async -> UIImage? {
        let size = analysisSize
        guard size.width > 0, size.height > 0 else { return nil }
        let overlay = isOverlayShown
        guard let base = await still(of: overlay ? .a : analysisSlot) else { return nil }
        let top = overlay ? await still(of: .b) : nil

        let composition = CorrectionSnapshotView(
            base: base,
            overlay: top,
            overlayOpacity: overlayOpacity,
            overlayMirrored: overlayMirrored,
            overlayScale: overlayScale,
            overlayOffset: overlayOffset,
            guides: showsGuides ? guides : nil
        )
        .frame(width: size.width, height: size.height)
        let renderer = ImageRenderer(content: composition)
        renderer.scale = displayScale
        return renderer.uiImage
    }

    private func still(of slot: DualSlot) async -> UIImage? {
        if let image = slot == .a ? imageA : imageB { return image }
        guard let url = slot == .a ? resolvedURLA : resolvedURLB else { return nil }
        let time = slot == .a ? currentTime : currentTime + offsetB
        return await VideoStill.frame(of: url, at: max(0, time))
    }

    private func saveToPhotos(_ image: UIImage, announce: Bool) async {
        var allowed = PhotoLibraryVideoStore.hasAccess
        if !allowed { allowed = await PhotoLibraryVideoStore.requestAccess() }
        guard allowed, let data = image.jpegData(compressionQuality: 0.9) else {
            showToast("Povoľ Encore prístup k Fotkám v Nastaveniach")
            return
        }
        do {
            try await PhotoLibraryVideoStore.save(imageData: data)
            if announce {
                successTaps += 1
                showToast("Snímka je vo Fotkách v albume Encore")
            }
        } catch {
            Logger.camera.error("Saving comparison snapshot failed: \(error.localizedDescription, privacy: .public)")
            showToast("Snímku sa nepodarilo uložiť")
        }
    }

    private func showToast(_ text: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { toast = text }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.2))
            guard toast == text else { return }
            withAnimation(.easeOut(duration: 0.25)) { toast = nil }
        }
    }

    // MARK: - Player setup
    private func setupPlayers() {
        tearDownPlayers()

        // Videos in Fotky are looked up asynchronously. Only the newest request builds players:
        // closing the comparison or changing a slot meanwhile bumps the generation.
        let generation = setupGeneration
        let requestedA = pathA
        let requestedB = pathB
        isResolving = requestedA != nil || requestedB != nil
        Task { @MainActor in
            let urlA = await videoURL(for: requestedA)
            let urlB = await videoURL(for: requestedB)
            let frameA = await VideoStill.frameDuration(of: urlA)
            let frameB = await VideoStill.frameDuration(of: urlB)
            let lengthB = await VideoStill.duration(of: urlB)
            let portraitA = await VideoStill.isPortrait(urlA)
            let portraitB = await VideoStill.isPortrait(urlB)
            guard generation == setupGeneration else { return }
            isResolving = false
            frameDurationA = frameA
            frameDurationB = frameB
            durationB = lengthB
            buildPlayers(urlA: urlA, urlB: urlB)
            chooseLayout(portraitA: portraitA ?? imageA.map(Self.isPortrait),
                         portraitB: portraitB ?? imageB.map(Self.isPortrait))
        }
    }

    /// Upright videos sit next to each other (stacked they would fill a third of each window),
    /// wide ones under each other. A layout picked in the menu wins.
    private func chooseLayout(portraitA: Bool?, portraitB: Bool?) {
        guard !userPickedLayout else { return }
        let shapes = [portraitA, portraitB].compactMap { $0 }
        guard !shapes.isEmpty else { return }
        layoutMode = shapes.allSatisfy { $0 } ? .sideBySide : .stacked
    }

    private static func isPortrait(_ image: UIImage) -> Bool { image.size.height > image.size.width }

    /// nil for an empty slot, a photo, or a video that is missing or cannot be played
    /// (the slot then says so instead of showing a crossed-out player).
    private func videoURL(for path: String?) async -> URL? {
        guard let path, !MediaResolver.isImagePath(path: path),
              let url = await MediaResolver.videoURL(path: path) else { return nil }
        let playable = (try? await AVURLAsset(url: url).load(.isPlayable)) ?? false
        return playable ? url : nil
    }

    private func buildPlayers(urlA: URL?, urlB: URL?) {
        resolvedURLA = urlA
        resolvedURLB = urlB
        (playerA, imageA) = makeMedia(path: pathA, url: urlA)
        (playerB, imageB) = makeMedia(path: pathB, url: urlB)
        applyAudioVolumes()

        // My video leads; without it the model does.
        guard let leader = playerA ?? playerB else { return }
        loopToken = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: leader.currentItem,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { leaderDidReachEnd() }
        }
        let interval = CMTime(seconds: 0.05, preferredTimescale: 600)
        timeObserverToken = leader.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            MainActor.assumeIsolated {
                guard !isScrubbing, !isAligning else { return }
                currentTime = time.seconds
                if let total = leader.currentItem?.duration.seconds, total.isFinite, total > 0 {
                    duration = total
                }
                correctDrift(leader: leader, at: time.seconds)
            }
        }
        timeObserverPlayer = leader

        Task {
            try? await AudioSessionCoordinator.shared.activate(.player)
        }
    }

    private func makeMedia(path: String?, url: URL?) -> (AVPlayer?, UIImage?) {
        guard let path else { return (nil, nil) }
        if MediaResolver.isImagePath(path: path) { return (nil, MediaResolver.resolveImage(path: path)) }
        if let url {
            let player = AVPlayer(playerItem: AVPlayerItem(url: url))
            // Needed for starting both at one clock time (setRate(_:time:atHostTime:)).
            player.automaticallyWaitsToMinimizeStalling = false
            return (player, nil)
        }
        return (nil, MediaResolver.resolveImage(path: path))
    }

    private func leaderDidReachEnd() {
        guard isLooping else {
            isPlaying = false
            return
        }
        Task { await playTogether(from: 0) }
    }

    /// Both videos start at the same instant of the iPhone clock, after both have finished seeking.
    /// Two separate play() calls start a few frames apart, and the comparison is then not frame-true.
    private func playTogether(from time: Double) async {
        playerA?.pause()
        playerB?.pause()
        await seek(playerA, to: time)
        await seek(playerB, to: time + offsetB)
        guard isPlaying, !isScrubbing else { return }
        let start = CMTimeAdd(CMClockGetTime(CMClockGetHostTimeClock()), CMTime(value: 1, timescale: 20))
        playerA?.setRate(playbackRate, time: .invalid, atHostTime: start)
        playerB?.setRate(playbackRate, time: .invalid, atHostTime: start)
    }

    private func seek(_ player: AVPlayer?, to seconds: Double) async {
        guard let player else { return }
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            player.seek(to: CMTime(seconds: max(0, seconds), preferredTimescale: 600),
                        toleranceBefore: .zero, toleranceAfter: .zero) { _ in done.resume() }
        }
    }

    /// The model video follows mine; when it is off by more than about three frames (long videos, a
    /// stall) both start together again from where mine is.
    private func correctDrift(leader: AVPlayer, at time: Double) {
        guard isPlaying, !isResyncing, leader === playerA, let follower = playerB else { return }
        let expected = time + offsetB
        guard expected > 0.2, expected < durationB - 0.2,
              abs(follower.currentTime().seconds - expected) > 0.12 else { return }
        isResyncing = true
        Task {
            await playTogether(from: time)
            isResyncing = false
        }
    }

    private func tearDownPlayers() {
        setupGeneration += 1
        if let loopToken {
            NotificationCenter.default.removeObserver(loopToken)
            self.loopToken = nil
        }
        if let timeObserverToken, let timeObserverPlayer {
            timeObserverPlayer.removeTimeObserver(timeObserverToken)
        }
        timeObserverToken = nil
        timeObserverPlayer = nil

        playerA?.pause()
        playerB?.pause()
        playerA = nil
        playerB = nil
        isPlaying = false

        Task {
            await AudioSessionCoordinator.shared.deactivate(.player)
        }
    }

    // MARK: - Playback
    private func togglePlayPause() {
        if isPlaying {
            playerA?.pause()
            playerB?.pause()
            isPlaying = false
        } else {
            Task { @MainActor in
                try? await AudioSessionCoordinator.shared.activate(.player)
                isPlaying = true
                await playTogether(from: currentTime)
            }
        }
    }

    private func setRate(_ rate: Float) {
        playbackRate = rate
        if isPlaying { Task { await playTogether(from: currentTime) } }
        toolTaps += 1
    }

    /// While playing, a jump restarts both together; standing still (or dragging the slider) it only seeks.
    private func seekPlayers(to time: Double) {
        if isPlaying && !isScrubbing {
            Task { await playTogether(from: time) }
            return
        }
        playerA?.seek(to: CMTime(seconds: max(0, time), preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        seekB(to: time + offsetB)
    }

    private func seekB(to time: Double) {
        playerB?.seek(to: CMTime(seconds: max(0, time), preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func stepFrame(by frames: Int) {
        if isPlaying { togglePlayPause() }
        let target = max(0, min(duration, currentTime + Double(frames) * frameDurationA))
        currentTime = target
        seekPlayers(to: target)
    }

    private func applyAudioVolumes() {
        playerA?.volume = audioSource == .slotA ? 1 : 0
        playerB?.volume = audioSource == .slotB ? 1 : 0
    }

    private func swapSlots() {
        let previousA = pathA
        pathA = pathB
        pathB = previousA
        offsetB = 0
    }

    /// Slow motion steps, shared with the duel on the figure screen.
    static let rates: [Float] = [0.25, 0.5, 0.75, 1]

    static func rateText(_ rate: Float) -> String {
        Double(rate).formatted(.number.precision(.fractionLength(0...2)).locale(Locale(identifier: "sk_SK"))) + "×"
    }

    private func formatTime(_ seconds: Double, precise: Bool = false) -> String {
        guard seconds.isFinite else { return "0:00" }
        let total = max(0, seconds)
        let minutes = Int(total) / 60
        let rest = total - Double(minutes * 60)
        if precise {
            return String(format: "%d:%05.2f", minutes, rest).replacingOccurrences(of: ".", with: ",")
        }
        return String(format: "%d:%02d", minutes, Int(rest))
    }
}

// MARK: - Snapshot
/// The analysed moment as a picture: my frame, the fitted model over it, the lines.
private struct CorrectionSnapshotView: View {
    let base: UIImage
    let overlay: UIImage?
    let overlayOpacity: Double
    let overlayMirrored: Bool
    let overlayScale: CGFloat
    let overlayOffset: CGSize
    let guides: AnalysisGuides?

    var body: some View {
        ZStack {
            Color.black
            Image(uiImage: base)
                .resizable()
                .scaledToFit()
            if let overlay {
                Image(uiImage: overlay)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(x: overlayMirrored ? -overlayScale : overlayScale, y: overlayScale)
                    .offset(overlayOffset)
                    .opacity(overlayOpacity)
            }
            if let guides {
                AnalysisGuidesDrawing(guides: guides)
            }
        }
        .clipped()
    }
}

// MARK: - Still frames
nonisolated enum VideoStill {
    /// The exact frame at a moment, upright, at most 1600 px on the long side.
    @concurrent
    static func frame(of url: URL, at seconds: Double) async -> UIImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        generator.maximumSize = CGSize(width: 1600, height: 1600)
        guard let result = try? await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600)) else { return nil }
        return UIImage(cgImage: result.image)
    }

    /// Length in seconds; 1 when there is no video, so sliders always have a range.
    @concurrent
    static func duration(of url: URL?) async -> Double {
        guard let url, let time = try? await AVURLAsset(url: url).load(.duration),
              time.seconds.isFinite, time.seconds > 0 else { return 1 }
        return time.seconds
    }

    /// True for a video filmed upright (taller than wide once rotated), nil when unknown.
    @concurrent
    static func isPortrait(_ url: URL?) async -> Bool? {
        guard let url,
              let track = try? await AVURLAsset(url: url).loadTracks(withMediaType: .video).first,
              let geometry = try? await track.load(.naturalSize, .preferredTransform) else { return nil }
        let upright = CGRect(origin: .zero, size: geometry.0).applying(geometry.1)
        return abs(upright.height) > abs(upright.width)
    }

    /// One frame of the video in seconds (1/30 when unknown), so frame steps land on real frames.
    @concurrent
    static func frameDuration(of url: URL?) async -> Double {
        guard let url,
              let track = try? await AVURLAsset(url: url).loadTracks(withMediaType: .video).first,
              let rate = try? await track.load(.nominalFrameRate), rate > 0 else { return 1.0 / 30 }
        return 1.0 / Double(rate)
    }
}

// MARK: - Native AVPlayer layer
struct CustomAVPlayerRepresentable: UIViewControllerRepresentable {
    let player: AVPlayer
    var gravity: AVLayerVideoGravity = .resizeAspectFill

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = gravity
        controller.view.backgroundColor = .clear
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        if uiViewController.player !== player {
            uiViewController.player = player
        }
        uiViewController.videoGravity = gravity
    }
}
