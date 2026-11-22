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

/// The main gold button: a gold face on a darker gold lip. Pressed, the face sinks into the lip, and on release it comes
/// back with a small bounce. The touch area keeps its full size, lip included, so a tap at the edge is not lost.
struct EncorePrimaryButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 16
    /// How far the face sinks: the height of the lip.
    var lip: CGFloat = 5

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        configuration.label
            .background(
                LinearGradient(colors: [Color.gold400, Color.gold500], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: shape
            )
            .offset(y: pressed ? lip : 0)
            // The lip is drawn behind the face, one lip lower; it stays where it is when the face sinks.
            .background(alignment: .top) { shape.fill(Color.gold700).offset(y: lip) }
            .padding(.bottom, lip)
            .shadow(color: .black.opacity(0.22), radius: pressed ? 4 : 12, y: pressed ? 2 : 8)
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
}
