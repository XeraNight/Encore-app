import SwiftUI

/// The iPhone has no network. Like a message that waits: what is written stays on this iPhone and goes up by itself when
/// the connection is back, so the dancer is asked for nothing. The line only says why nothing arrives elsewhere.
struct OfflinePill: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isOffline: Bool { !NetworkMonitor.shared.isOnline }

    var body: some View {
        ZStack {
            if isOffline {
                HStack(spacing: 8) {
                    Image(systemName: "icloud.slash")
                        .font(.caption.weight(.bold))
                        .foregroundColor(Color.gold400)
                    Text("Bez internetu · odošle sa po pripojení")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 32)
                .background(Color.white.opacity(0.1), in: Capsule())
                .overlay(Capsule().stroke(Color.gold400.opacity(0.4), lineWidth: 1))
                .padding(.top, 6)
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Bez internetu. Zmeny sa odošlú po pripojení.")
            }
        }
        .frame(maxWidth: .infinity)
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85), value: isOffline)
        .sensoryFeedback(.warning, trigger: isOffline) { _, offline in offline }
        .allowsHitTesting(false)
    }
}
