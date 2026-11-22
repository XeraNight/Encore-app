import SwiftUI

/// Springy press feedback for buttons: shrinks slightly while pressed and bounces back.
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.95

    /// With Reduce Motion the button does not shrink; it only dims a little.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
            // The touch area stays full size while the picture shrinks. Without this a finger near the
            // edge ends up "outside" the shrunken button on release and the tap is silently lost.
            .contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
    static func pressable(scale: CGFloat) -> PressableButtonStyle { PressableButtonStyle(scale: scale) }
}

/// The main gold button: a soft, round gold face on a darker gold lip, with the rounded type of the brand. Pressed, the
/// face sinks into the lip, and on release it comes back with a small bounce. The touch area keeps its full size, lip
/// included, so a tap at the edge is not lost. The corners are as round as the label's height allows: a pill when the
/// button is a line high, a soft rounded shape when it is taller.
struct EncorePrimaryButtonStyle: ButtonStyle {
    /// A small pill with a short label inside a row has a thinner lip than a full-width button.
    var compact = false
    /// Dims itself when the button is disabled. Off where the caller dims the button on its own.
    var dimsWhenDisabled = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let lip: CGFloat = compact ? 3.5 : 5
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
        configuration.label
            .font(.system(compact ? .subheadline : .headline, design: .rounded, weight: .bold))
            .foregroundStyle(Color.obsidian900)
            .background(
                LinearGradient(colors: [Color.gold400, Color.gold500], startPoint: .top, endPoint: .bottom),
                in: shape
            )
            // A soft light along the top edge makes the face look round and a little raised.
            .overlay {
                shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0)], startPoint: .top, endPoint: .center), lineWidth: 1.2)
            }
            .offset(y: pressed ? lip : 0)
            // The lip is drawn behind the face, one lip lower; it stays where it is when the face sinks.
            .background(alignment: .top) { shape.fill(Color.gold700).offset(y: lip) }
            .padding(.bottom, lip)
            .shadow(color: .black.opacity(0.22), radius: pressed ? 4 : (compact ? 8 : 12), y: pressed ? 2 : (compact ? 5 : 8))
            .opacity(dimsWhenDisabled && !isEnabled ? 0.4 : 1)
            .animation(motion(pressed: pressed), value: pressed)
            .contentShape(Rectangle())
    }

    /// Quick down, slower and bouncier up. With Reduce Motion a plain short ease.
    private func motion(pressed: Bool) -> Animation {
        if reduceMotion { return .easeOut(duration: 0.08) }
        return pressed ? .spring(response: 0.16, dampingFraction: 0.8) : .spring(response: 0.36, dampingFraction: 0.5)
    }
}

extension ButtonStyle where Self == EncorePrimaryButtonStyle {
    static var encorePrimary: EncorePrimaryButtonStyle { EncorePrimaryButtonStyle() }
    static func encorePrimary(compact: Bool = false, dimsWhenDisabled: Bool = true) -> EncorePrimaryButtonStyle {
        EncorePrimaryButtonStyle(compact: compact, dimsWhenDisabled: dimsWhenDisabled)
    }
}
