import SwiftUI

// MARK: - The light
/// The gold light itself, drawn along any shape: faint all round, with one bright stretch that turns once every
/// `period` seconds, a sharp line over a soft halo. A slow glow needs no more than 30 images a second; in Low Power Mode
/// or with Reduce Motion it stands still.
struct EncoreGlowRing<S: Shape>: View {
    let shape: S
    var lineWidth: CGFloat
    var haloWidth: CGFloat
    var period: Double = 6

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion || ProcessInfo.processInfo.isLowPowerModeEnabled {
            shape.stroke(Color.gold400.opacity(0.4), lineWidth: lineWidth)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                let lap = (timeline.date.timeIntervalSinceReferenceDate / period).truncatingRemainder(dividingBy: 1)
                ZStack {
                    shape.stroke(Self.light(lap), lineWidth: haloWidth)
                        .blur(radius: haloWidth * 0.4)
                        .opacity(0.8)
                    shape.stroke(Self.light(lap), lineWidth: lineWidth)
                }
            }
        }
    }

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

// MARK: - Round the screen
/// A gold light that runs round the edge of the screen while the app works on something that takes a while.
/// It stays on the very edge, over nothing a person needs to read or tap, and takes no touches.
struct EncoreEdgeGlow: View {
    var isActive: Bool

    var body: some View {
        ZStack {
            if isActive {
                // The line is centred on the screen's edge, so half of it is off the screen: twice the width shows once.
                EncoreGlowRing(shape: ConcentricRectangle(), lineWidth: 6, haloWidth: 30)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.6), value: isActive)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Round one view
extension View {
    /// A gold light that runs round this view's edge while `isActive`, for example a video's window while its video
    /// loads. It sits on the edge, takes no touches and says nothing to VoiceOver.
    func encoreGlowBorder(isActive: Bool, cornerRadius: CGFloat) -> some View {
        overlay {
            ZStack {
                if isActive {
                    EncoreGlowRing(shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous), lineWidth: 2.5, haloWidth: 12)
                        .transition(.opacity)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .animation(.easeInOut(duration: 0.5), value: isActive)
        }
    }
}
