import SwiftUI

/// Two thin light lines that run down the left and right edges of a field at the same time and
/// disappear once they have passed its whole height. Plays once every time `trigger` changes.
struct FieldEdgeSweep: View {
    let trigger: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let width = geo.size.width
            let length = min(110, height * 0.55)
            let tint = Color.gold400

            Color.clear
                .keyframeAnimator(initialValue: 0.0, trigger: reduceMotion ? 0 : trigger) { _, progress in
                    let y = -length + progress * (height + length)
                    ZStack(alignment: .topLeading) {
                        bar(length, tint: tint).offset(x: 0, y: y)
                        bar(length, tint: tint).offset(x: width - 2, y: y)
                    }
                    .frame(width: width, height: height, alignment: .topLeading)
                    .clipped()
                    .opacity(progress > 0 && progress < 1 ? 1 : 0)
                } keyframes: { _ in
                    CubicKeyframe(1.0, duration: 0.65)
                }
        }
        .allowsHitTesting(false)
    }

    nonisolated private func bar(_ length: CGFloat, tint: Color) -> some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [.clear, tint.opacity(0.9), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 2, height: length)
    }
}
