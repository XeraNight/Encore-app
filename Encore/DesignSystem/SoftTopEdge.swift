import SwiftUI

// MARK: - Soft top edge
/// Content scrolling up under the title fades into the velvet background a little more with every point nearer the
/// top edge, with no band and no line. It replaces the system edge effect, which on the velvet background reads as
/// a red bar with an edge. A fade, not a blur: blur materials grey the crimson, and public API has no variable blur.
/// At rest nothing fades; the edge comes in over the first points of scrolling.
struct SoftTopEdge: ViewModifier {
    /// How far below the title the content is fully visible again.
    var fade: CGFloat = 44

    @State private var topInset: CGFloat = 0
    /// 0 at the top of the content, 1 once it has scrolled under the title.
    @State private var strength: CGFloat = 0

    private static let rampIn: CGFloat = 24

    func body(content: Content) -> some View {
        content
            .scrollEdgeEffectHidden(true, for: .top)
            .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.top } action: { topInset = $0 }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                min(max((geometry.contentOffset.y + geometry.contentInsets.top) / Self.rampIn, 0), 1)
            } action: { _, value in
                strength = value
            }
            .mask {
                VStack(spacing: 0) {
                    LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
                        .frame(height: topInset + fade)
                    Color.black
                }
                .ignoresSafeArea()
            }
    }

    /// Gone under the status bar, faint under the title, whole again below it; eased, so no line shows.
    private var stops: [Gradient.Stop] {
        let title = topInset / max(topInset + fade, 1)
        let points: [(opacity: CGFloat, location: CGFloat)] = [
            (0, 0), (0.04, title * 0.55), (0.22, title), (0.75, title + (1 - title) * 0.55), (1, 1),
        ]
        return points.map { .init(color: .black.opacity(1 - strength * (1 - $0.opacity)), location: $0.location) }
    }
}

extension View {
    /// The soft top edge of a scrolling screen (§1A); on the screen's top-level scroll view.
    func softTopEdge() -> some View {
        modifier(SoftTopEdge())
    }
}
