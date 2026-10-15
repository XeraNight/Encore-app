import SwiftUI
import AVKit

// MARK: - Round glass button
/// Floating icon action on the canvas (BRAND_GUIDELINES §1A: secondary icon action, 36–44 pt glass circle).
public struct LiquidGlassCircleButton: View {
    public let icon: String
    public let label: String
    public var isActive: Bool = false
    public var activeColor: Color = LuxuryTheme.gold400
    public var size: CGFloat = 44
    public let action: () -> Void

    @State private var tapCount = 0

    public init(
        icon: String,
        label: String,
        isActive: Bool = false,
        activeColor: Color = LuxuryTheme.gold400,
        size: CGFloat = 44,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.label = label
        self.isActive = isActive
        self.activeColor = activeColor
        self.size = size
        self.action = action
    }

    public var body: some View {
        Button {
            tapCount += 1
            action()
        } label: {
            GlassCircleLabel(icon: icon, size: size, isActive: isActive, activeColor: activeColor)
        }
        .buttonStyle(.pressable(scale: 0.9))
        .sensoryFeedback(.impact(weight: .medium), trigger: tapCount)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

/// The glass circle itself, also used as the label of a `Menu`.
/// The glass is only a picture (not `.interactive()`): touches belong to the button or menu around it,
/// so the glass can never swallow a tap. Press feedback comes from `.pressable`.
public struct GlassCircleLabel: View {
    public let icon: String
    public var size: CGFloat = 44
    public var isActive: Bool = false
    public var activeColor: Color = LuxuryTheme.gold400

    public init(icon: String, size: CGFloat = 44, isActive: Bool = false, activeColor: Color = LuxuryTheme.gold400) {
        self.icon = icon
        self.size = size
        self.isActive = isActive
        self.activeColor = activeColor
    }

    public var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.38, weight: .bold))
            .foregroundStyle(isActive ? activeColor : .white)
            .contentTransition(.symbolEffect(.replace))
            .frame(width: size, height: size)
            .glassEffect(isActive ? .regular.tint(activeColor.opacity(0.28)) : .regular, in: .circle)
            .contentShape(Circle())
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isActive)
    }
}

// MARK: - AirPlay button
public struct AirPlayPickerButton: View {
    @ObservedObject private var airPlayManager = StudioAirPlayManager.shared
    public var size: CGFloat = 44

    public init(size: CGFloat = 44) {
        self.size = size
    }

    public var body: some View {
        AirPlayRoutePickerRepresentable(
            tintColor: airPlayManager.isExternalScreenConnected ? UIColor(LuxuryTheme.gold400) : .white,
            activeTintColor: UIColor(LuxuryTheme.gold400)
        )
        .frame(width: size - 14, height: size - 14)
        .frame(width: size, height: size)
        .glassEffect(
            airPlayManager.isExternalScreenConnected ? .regular.tint(LuxuryTheme.gold500.opacity(0.3)) : .regular,
            in: .circle
        )
        .overlay(alignment: .topTrailing) {
            if airPlayManager.isExternalScreenConnected {
                Circle()
                    .fill(Color.syncEmerald)
                    .frame(width: 9, height: 9)
                    .offset(x: -3, y: 3)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: airPlayManager.isExternalScreenConnected)
        .accessibilityLabel(airPlayManager.isExternalScreenConnected ? "Premietanie zapnuté" : "Premietať na obrazovku")
    }
}

// MARK: - Live status
/// Small pill under the title: live / offline / refreshing. Tapping it reconnects (offline) or
/// refreshes the routine from the server (live), so a separate refresh button is not needed.
public struct RealtimeStatusPill: View {
    public var isConnected: Bool
    public var isSyncing: Bool = false
    public var onTap: () -> Void

    public init(isConnected: Bool, isSyncing: Bool = false, onTap: @escaping () -> Void) {
        self.isConnected = isConnected
        self.isSyncing = isSyncing
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                if isSyncing {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(statusColor)
                } else {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(statusColor)
                        .symbolEffect(.pulse, options: .repeating, isActive: isConnected)
                }
                Text(statusText)
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                    .foregroundStyle(.white.opacity(0.92))
                    .contentTransition(.opacity)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 28)
            .glassEffect(.regular, in: .capsule)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: statusText)
        .sensoryFeedback(.selection, trigger: isConnected)
        .accessibilityLabel(statusText)
        .accessibilityHint(isConnected ? "Načíta najnovšiu verziu zostavy" : "Skúsi sa znova pripojiť")
    }

    private var statusColor: Color {
        if isSyncing { return LuxuryTheme.gold400 }
        return isConnected ? Color.syncEmerald : Color.orange
    }

    private var statusText: String {
        if isSyncing { return "Obnovujem…" }
        return isConnected ? "Naživo" : "Offline · ťukni"
    }
}
