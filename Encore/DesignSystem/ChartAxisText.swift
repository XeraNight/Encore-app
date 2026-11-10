import SwiftUI

// MARK: - Chart axes
/// One look for the labels and grid of every chart (§1A): small rounded digits in the secondary colour on a faint
/// grid, values on the trailing side. New charts use the same, so their numbers line up from screen to screen.
struct ChartAxisText: View {
    let text: String

    init(_ text: String) { self.text = text }

    static let grid = Color.white.opacity(0.08)

    var body: some View {
        Text(text)
            .font(.system(.caption2, design: .rounded).weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(Color.textSecondary)
    }
}
