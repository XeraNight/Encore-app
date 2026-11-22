import SwiftUI

// MARK: - Skeleton
extension View {
    /// While `isActive`, draws this view as a skeleton: its text as soft blocks, with a gold light passing over it.
    /// Give it made-up data of the same shape as the real data, so the skeleton is the real component and the
    /// rows do not jump when the data arrives. A skeleton takes no taps and says nothing to VoiceOver.
    func encoreSkeleton(_ isActive: Bool, cornerRadius: CGFloat = 14) -> some View {
        modifier(EncoreSkeleton(isActive: isActive, cornerRadius: cornerRadius))
    }
}

private struct EncoreSkeleton: ViewModifier {
    let isActive: Bool
    let cornerRadius: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if isActive {
            content
                .redacted(reason: .placeholder)
                .overlay {
                    if !reduceMotion {
                        SkeletonLight()
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        } else {
            content
        }
    }
}

// MARK: - A slow network
/// How long a load may take before the screen says so.
enum LoadWait {
    static let slowAfter: TimeInterval = 8
}

/// A calm line under a loading list once the load takes longer than a person expects, so a weak network does not
/// look like a frozen app.
struct SlowLoadNotice: View {
    let isLoading: Bool

    @State private var isSlow = false

    var body: some View {
        Group {
            if isLoading, isSlow {
                Label("Slabé pripojenie, skúšam ďalej.", systemImage: "wifi.exclamationmark")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Color.gold300)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isSlow)
        .task(id: isLoading) {
            isSlow = false
            guard isLoading else { return }
            try? await Task.sleep(for: .seconds(LoadWait.slowAfter))
            if !Task.isCancelled { isSlow = true }
        }
    }
}

/// A band of gold light that crosses a block from left to right, a little later on each row further down the
/// screen, so a list shows one slow wave and not many flashes.
private struct SkeletonLight: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let top = proxy.frame(in: .global).minY
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate / 1.8 - top / 1500
                let phase = time - time.rounded(.down)
                LinearGradient(colors: [.clear, Color.gold400.opacity(0.20), .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: width * 0.55, height: proxy.size.height)
                    .offset(x: -width * 0.55 + width * 1.55 * phase)
                    .blendMode(.plusLighter)
            }
        }
        .allowsHitTesting(false)
    }
}
