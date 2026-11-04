import SwiftUI

// MARK: - Radial Hub Actions
public enum RadialHubAction: String, CaseIterable, Identifiable {
    case newRoutine
    case mirror
    case metronome
    case compare

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .newRoutine:    return "Nová zostava"
        case .mirror:        return "Zrkadlo"
        case .metronome:     return "Metronóm"
        case .compare:       return "Porovnanie videí"
        }
    }

    public var shortTitle: String {
        switch self {
        case .newRoutine:    return "Nová zostava"
        case .mirror:        return "Zrkadlo"
        case .metronome:     return "Metronóm"
        case .compare:       return "Porovnať"
        }
    }

    public var iconName: String {
        switch self {
        case .newRoutine:    return "plus"
        case .mirror:        return "figure.stand.line.dotted.figure.stand"
        case .metronome:     return "metronome.fill"
        case .compare:       return "person.line.dotted.person.fill"
        }
    }

    /// The main action is solid gold; the tools are glass.
    var isPrimary: Bool { self == .newRoutine }

    /// Position around the logo.
    public var offset: CGSize {
        switch self {
        case .newRoutine:    return CGSize(width: -86, height: -82)
        case .mirror:        return CGSize(width: 86,  height: -82)
        case .metronome:     return CGSize(width: -86, height: 82)
        case .compare:       return CGSize(width: 86,  height: 82)
        }
    }

    /// Order in which the buttons step out: counter-clockwise, like couples move along the line of dance.
    var entranceOrder: Int {
        switch self {
        case .newRoutine:    return 0
        case .metronome:     return 1
        case .compare:       return 2
        case .mirror:        return 3
        }
    }
}

// MARK: - Gold emblem
/// The logo with a stage light behind it and a light sweep across the gold.
/// It bows (tilts forward) like a dancer before the music starts, and leans toward the finger while dragging.
public struct EncoreGoldenEmblemView: View {
    let size: CGFloat
    let bowDegrees: Double
    let pitchDegrees: Double
    let yawDegrees: Double
    let sheenProgress: CGFloat
    let spotlight: Double
    let glowIntensity: Double
    let scale: CGFloat
    let offset: CGSize

    public var body: some View {
        ZStack {
            // Stage light behind the logo.
            RadialGradient(
                colors: [Color.gold400.opacity(0.55 * spotlight), Color.gold500.opacity(0.18 * spotlight), .clear],
                center: .center,
                startRadius: size * 0.05,
                endRadius: size * 1.05
            )
            .frame(width: size * 2.2, height: size * 2.2)
            .blur(radius: 6)
            .allowsHitTesting(false)

            Image("EncoreLogo")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: size, height: size)

            // Light sweep across the gold.
            if sheenProgress > -0.4 && sheenProgress < 1.4 {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: Color.gold300.opacity(0.40), location: 0.35),
                        .init(color: Color.white.opacity(0.95), location: 0.50),
                        .init(color: Color.gold300.opacity(0.40), location: 0.65),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: size * 0.60, height: size * 1.6)
                .rotationEffect(.degrees(25))
                .offset(x: (sheenProgress - 0.5) * (size * 2.0))
                .mask(
                    Image("EncoreLogo")
                        .resizable()
                        .renderingMode(.original)
                        .scaledToFit()
                        .frame(width: size, height: size)
                )
                .blendMode(.screen)
            }

            if glowIntensity > 0.01 {
                Image("EncoreLogo")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundColor(Color.gold300)
                    .frame(width: size, height: size)
                    .blur(radius: 5)
                    .opacity(glowIntensity)
                    .blendMode(.screen)
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(scale)
        .offset(offset)
        // The bow: forward around the bottom edge, as a dancer bends from the hips.
        .rotation3DEffect(.degrees(bowDegrees), axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.5)
        .rotation3DEffect(.degrees(yawDegrees), axis: (x: 0, y: 1, z: 0), perspective: 0.35)
        .rotation3DEffect(.degrees(pitchDegrees), axis: (x: 1, y: 0, z: 0), perspective: 0.35)
        .shadow(color: Color.black.opacity(0.65), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Orbit entrance
/// Moves a satellite along an arc around the logo into its place (and back when it leaves).
/// The satellite already sits at `target`; this only adds the way there, so at the end it adds nothing.
private struct OrbitEffect: GeometryEffect {
    var progress: CGFloat
    let target: CGSize

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        // Start 70° short of the place and travel counter-clockwise into it, growing out of the logo.
        let angle = Double(1 - progress) * 70 * .pi / 180
        let radiusScale = 0.25 + 0.75 * progress
        let x = (target.width * cos(angle) - target.height * sin(angle)) * radiusScale
        let y = (target.width * sin(angle) + target.height * cos(angle)) * radiusScale
        return ProjectionTransform(CGAffineTransform(translationX: x - target.width, y: y - target.height))
    }
}

// MARK: - Radial hub
public struct EncoreRadialHubView: View {
    @Binding var isOpen: Bool
    var logoSize: CGFloat
    var onSelectAction: (RadialHubAction) -> Void
    var onTogglePaletteFallback: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Emblem
    @State private var bowDegrees: Double = 0
    @State private var pitchDegrees: Double = 0
    @State private var yawDegrees: Double = 0
    @State private var sheenProgress: CGFloat = -0.5
    @State private var spotlight: Double = 0
    @State private var glowBurst: Double = 0
    @State private var goldScale: CGFloat = 1
    @State private var goldOffset: CGSize = .zero
    @State private var isAnimatingOpen = false

    // Drag to select
    @State private var hoveredAction: RadialHubAction?
    @State private var triggeringAction: RadialHubAction?
    @State private var isDragging = false

    public init(
        isOpen: Binding<Bool>,
        logoSize: CGFloat = 110,
        onSelectAction: @escaping (RadialHubAction) -> Void,
        onTogglePaletteFallback: @escaping () -> Void = {}
    ) {
        self._isOpen = isOpen
        self.logoSize = logoSize
        self.onSelectAction = onSelectAction
        self.onTogglePaletteFallback = onTogglePaletteFallback
    }

    public var body: some View {
        ZStack {
            if isOpen {
                ForEach(RadialHubAction.allCases) { action in
                    satelliteButton(for: action)
                        .offset(position(for: action))
                        .transition(entrance(for: action))
                        .zIndex(Double(4 - action.entranceOrder))
                }
            }

            centerEmblem
        }
        // Open height must equal the header frame in ContentView, so nothing overflows onto the field below.
        .frame(
            width: isOpen ? max(logoSize + 195, 310) : (logoSize + 30),
            height: isOpen ? max(logoSize + 185, 300) : (logoSize + 20)
        )
        .contentShape(isOpen ? AnyShape(Rectangle()) : AnyShape(Circle()))
        .animation(.spring(response: 0.36, dampingFraction: 0.78), value: isOpen)
        .animation(.spring(response: 0.20, dampingFraction: 0.68), value: hoveredAction)
        .animation(.spring(response: 0.18, dampingFraction: 0.65), value: goldScale)
        .animation(.spring(response: 0.22, dampingFraction: 0.65), value: goldOffset)
        .onChange(of: isOpen) { _, open in
            guard !open else { return }
            hoveredAction = nil
            triggeringAction = nil
            withAnimation(.easeOut(duration: 0.3)) {
                goldScale = 1
                goldOffset = .zero
                pitchDegrees = 0
                yawDegrees = 0
                bowDegrees = 0
                glowBurst = 0
                spotlight = 0
            }
            sheenProgress = -0.5
        }
    }

    private func entrance(for action: RadialHubAction) -> AnyTransition {
        if reduceMotion { return .opacity }
        let orbit = AnyTransition.modifier(
            active: OrbitEffect(progress: 0, target: action.offset),
            identity: OrbitEffect(progress: 1, target: action.offset)
        )
        let delay = Double(action.entranceOrder) * 0.05
        return .asymmetric(
            insertion: orbit.combined(with: .scale(scale: 0.4)).combined(with: .opacity)
                .animation(.spring(response: 0.46, dampingFraction: 0.74).delay(delay)),
            removal: orbit.combined(with: .scale(scale: 0.4)).combined(with: .opacity)
                .animation(.spring(response: 0.3, dampingFraction: 0.9))
        )
    }

    // MARK: Emblem
    private var centerEmblem: some View {
        VStack(spacing: 8) {
            EncoreGoldenEmblemView(
                size: logoSize * 0.88,
                bowDegrees: bowDegrees,
                pitchDegrees: pitchDegrees,
                yawDegrees: yawDegrees,
                sheenProgress: sheenProgress,
                spotlight: spotlight,
                glowIntensity: glowBurst,
                scale: goldScale,
                offset: goldOffset
            )

            HStack(spacing: 4) {
                EncoreWordmark()
                Image(systemName: isOpen ? "xmark" : "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color.gold400.opacity(0.85))
                    .contentTransition(.symbolEffect(.replace))
            }
            .opacity(isOpen ? 0.95 : 0.75)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged(handleDragChanged)
                .onEnded(handleDragEnded)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Encore, rýchle akcie")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { isOpen ? close() : open() }
    }

    /// Its place around the logo; a hovered one is pulled a little toward the logo.
    private func position(for action: RadialHubAction) -> CGSize {
        var base = action.offset
        if hoveredAction == action {
            base.width += base.width > 0 ? -4 : 4
            base.height += base.height > 0 ? -4 : 4
        }
        return base
    }

    // MARK: Satellite
    private func satelliteButton(for action: RadialHubAction) -> some View {
        let isHovered = hoveredAction == action
        let isAnyHovered = hoveredAction != nil
        let isTriggering = triggeringAction == action
        let scale: CGFloat = isTriggering ? 0.9 : (isHovered ? 1.18 : (isAnyHovered ? 0.94 : 1))
        let gold = LinearGradient(colors: [Color.gold300, Color.gold500], startPoint: .top, endPoint: .bottom)

        return Button {
            executeAction(action)
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    if isHovered {
                        Circle()
                            .fill(Color.gold400.opacity(0.45))
                            .frame(width: 74, height: 74)
                            .blur(radius: 12)
                    }

                    if action.isPrimary {
                        Circle()
                            .fill(LinearGradient(colors: [Color.gold400, Color.gold500], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 58, height: 58)
                    } else {
                        // Glass is only the picture here; the Button takes the touch.
                        Circle()
                            .fill(Color.encoreBurgundy.opacity(0.35))
                            .frame(width: 58, height: 58)
                            .glassEffect(.regular.tint(Color.encoreBurgundy.opacity(0.45)), in: .circle)
                    }

                    Circle()
                        .stroke(gold.opacity(isHovered ? 0.95 : 0.5), lineWidth: isHovered ? 1.8 : 1)
                        .frame(width: 58, height: 58)

                    Image(systemName: action.iconName)
                        .font(.system(size: action.isPrimary ? 24 : 21, weight: action.isPrimary ? .bold : .semibold))
                        .foregroundStyle(action.isPrimary ? AnyShapeStyle(Color.obsidian900) : AnyShapeStyle(gold))
                        .symbolEffect(.bounce, value: isHovered)
                }
                .shadow(color: isHovered ? Color.gold400.opacity(0.6) : Color.black.opacity(0.45), radius: isHovered ? 14 : 6, y: 3)

                Text(action.shortTitle)
                    .font(.system(.caption, design: .rounded).weight(isHovered ? .bold : .semibold))
                    .foregroundColor(.white.opacity(isHovered ? 1 : 0.9))
                    .shadow(color: .black.opacity(0.6), radius: 3)
            }
            .scaleEffect(scale)
            .opacity(isAnyHovered && !isHovered ? 0.55 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.68), value: scale)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(action.title)
    }

    // MARK: Open and close
    /// The bow: dip forward, rise with the light on, then the buttons step out.
    private func open() {
        guard !isAnimatingOpen else { return }
        if reduceMotion {
            isOpen = true
            spotlight = 0.6
            return
        }
        isAnimatingOpen = true
        HapticFeedback.light()

        withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
            goldScale = 0.92
            bowDegrees = 24
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            withAnimation(.spring(response: 0.48, dampingFraction: 0.6)) {
                goldScale = 1
                bowDegrees = 0
                spotlight = 1
            }
            withAnimation(.easeInOut(duration: 0.65)) {
                sheenProgress = 1.35
            }
            isOpen = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                sheenProgress = -0.5
                withAnimation(.easeOut(duration: 0.5)) { spotlight = 0.6 }
                isAnimatingOpen = false
            }
        }
    }

    private func close() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            isOpen = false
        }
        HapticFeedback.light()
    }

    // MARK: Drag
    private func handleDragChanged(_ value: DragGesture.Value) {
        let translation = value.translation
        let distance = hypot(translation.width, translation.height)

        if !isDragging {
            isDragging = true
            if !isOpen {
                open()
            } else {
                withAnimation(.spring(response: 0.12, dampingFraction: 0.6)) { goldScale = 0.92 }
            }
        }

        // The logo leans a little toward the finger.
        let maxPull: CGFloat = 10
        goldOffset = CGSize(
            width: max(-maxPull, min(maxPull, translation.width * 0.08)),
            height: max(-maxPull, min(maxPull, translation.height * 0.08))
        )
        withAnimation(.spring(response: 0.16, dampingFraction: 0.7)) {
            pitchDegrees = max(-10, min(10, Double(-translation.height * 0.1)))
            yawDegrees = max(-12, min(12, Double(translation.width * 0.1)))
        }

        if isOpen && distance > 32 {
            let target = resolveTargetAction(translation: translation, distance: distance)
            if hoveredAction != target {
                hoveredAction = target
                if target != nil { HapticFeedback.light() }
            }
        } else if distance <= 32 {
            hoveredAction = nil
        }
    }

    private func resolveTargetAction(translation: CGSize, distance: CGFloat) -> RadialHubAction? {
        guard distance >= 34 && distance <= 220 else { return nil }
        let dx = translation.width
        let dy = translation.height
        if dx < 0 && dy < 0 { return .newRoutine }
        if dx >= 0 && dy < 0 { return .mirror }
        if dx < 0 { return .metronome }
        return .compare
    }

    private func handleDragEnded(_ value: DragGesture.Value) {
        let distance = hypot(value.translation.width, value.translation.height)
        isDragging = false

        withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) {
            pitchDegrees = 0
            yawDegrees = 0
            goldOffset = .zero
        }

        // Swiped onto a button and let go: that button is pressed.
        if let selected = hoveredAction {
            executeAction(selected)
            return
        }

        // A tap on the logo: closes an open hub (opening already happened on touch down).
        if distance < 18 {
            if isOpen && !isAnimatingOpen { close() }
            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) { goldScale = 1 }
            return
        }

        // Swiped into empty space: put everything back.
        close()
    }

    private func executeAction(_ action: RadialHubAction) {
        triggeringAction = action
        HapticFeedback.notify(.success)

        withAnimation(.spring(response: 0.12, dampingFraction: 0.55)) {
            goldScale = 0.94
            glowBurst = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                isOpen = false
                goldScale = 1
                glowBurst = 0
            }
            onSelectAction(action)
        }
    }
}

// MARK: - Preview
#Preview("Rýchle akcie") {
    @Previewable @State var isOpen = false
    ZStack {
        EllegancePageBackground()
        EncoreRadialHubView(isOpen: $isOpen, logoSize: 92, onSelectAction: { _ in })
    }
}
