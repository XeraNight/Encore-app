import SwiftUI

/// A gold light that runs round the edge of the screen while the app works on something that takes a while.
/// It stays on the very edge, over nothing a person needs to read or tap, and takes no touches.
struct EncoreEdgeGlow: View {
    var isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if isActive {
                glow.transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.6), value: isActive)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var glow: some View {
        if reduceMotion {
            // The line is centred on the screen's edge, so half of it is off the screen: twice the width shows once.
            ConcentricRectangle()
                .stroke(Color.gold400.opacity(0.4), lineWidth: 4)
        } else {
            TimelineView(.animation) { timeline in
                let lap = (timeline.date.timeIntervalSinceReferenceDate / 6).truncatingRemainder(dividingBy: 1)
                ZStack {
                    ConcentricRectangle()
                        .stroke(Self.light(lap), lineWidth: 30)
                        .blur(radius: 12)
                        .opacity(0.8)
                    ConcentricRectangle()
                        .stroke(Self.light(lap), lineWidth: 6)
                }
            }
        }
    }

    /// Faint all round, with one bright stretch that turns once every six seconds.
    private static func light(_ lap: Double) -> AngularGradient {
        AngularGradient(
            stops: [
                .init(color: Color.gold400.opacity(0.0), location: 0),
                .init(color: Color.gold400.opacity(0.12), location: 0.5),
                .init(color: Color.gold400, location: 0.82),
                .init(color: .white, location: 0.92),
                .init(color: Color.gold400.opacity(0.0), location: 1)
            ],
            center: .center,
            angle: .degrees(lap * 360)
        )
    }
}
