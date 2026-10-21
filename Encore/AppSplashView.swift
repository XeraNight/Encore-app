import SwiftUI

// MARK: - Animated Splash Screen
// Ultra-fast 0.35s entrance — dark obsidian gold luxury aesthetic.
// Instantly dismisses so user actions respond in < 0.3s.
struct AppSplashView: View {
    var onComplete: () -> Void

    @ObservedObject private var authManager = AuthManager.shared
    @AppStorage("profileName") private var userName = "Tanečník"
    @State private var isAnimatingLogo = false
    @State private var rotationDegrees: Double = 0.0
    @State private var opacity: Double = 1.0
    @State private var scale: CGFloat = 1.0
    @State private var nameOpacity: Double = 0.0

    var body: some View {
        ZStack {
            EllegancePageBackground()

            VStack(spacing: 20) {
                Spacer()

                // Luxury Gold Logo Ring
                ZStack {
                    Circle()
                        .stroke(Color.gold400.opacity(0.20), lineWidth: 1.5)
                        .frame(width: 140, height: 140)

                    Circle()
                        .stroke(Color.gold500.opacity(0.60), lineWidth: 2)
                        .frame(width: 124, height: 124)

                    // Spinning gradient arc
                    Circle()
                        .trim(from: 0.15, to: 0.75)
                        .stroke(
                            LinearGradient(
                                colors: [Color.gold500, Color.gold400],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 136, height: 136)
                        .rotationEffect(.degrees(rotationDegrees))

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.encoreCrimson, Color.encoreBurgundy],
                                center: .center,
                                startRadius: 5,
                                endRadius: 52
                            )
                        )
                        .frame(width: 104, height: 104)
                        .overlay(Circle().stroke(Color.gold400.opacity(0.45), lineWidth: 1.5))
                        .shadow(color: Color.encoreCrimson.opacity(0.50), radius: 14, x: 0, y: 4)
                        .shadow(color: Color.black.opacity(0.60), radius: 10, x: 0, y: 5)

                    Image("EncoreLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .scaleEffect(isAnimatingLogo ? 1.05 : 0.95)
                }

                // Name / Brand fade-in
                VStack(spacing: 4) {
                    if authManager.isAuthenticated, !userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, userName != "Tanečník" {
                        Text("Vítaj späť")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.textSecondary)

                        Text(userName)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.gold400, Color.gold300, Color.white],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: Color.gold500.opacity(0.30), radius: 8, x: 0, y: 3)
                    } else {
                        Text("Vítaj v")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.textSecondary)

                        Text("Encore")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.gold400, Color.gold300, Color.white],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: Color.gold500.opacity(0.30), radius: 8, x: 0, y: 3)
                    }
                }
                .opacity(nameOpacity)

                Spacer()
            }
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .task {
            // Logo pulse
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                isAnimatingLogo = true
            }
            // Arc spin
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                rotationDegrees = 360
            }
            // Name instant fade-in
            withAnimation(.easeOut(duration: 0.2)) {
                nameOpacity = 1.0
            }
            // Short branded flash; the app must feel instant.
            try? await Task.sleep(for: .milliseconds(150))

            // Wait for auth check to finish resolving if still pending (cap at 800ms)
            var waitCount = 0
            while authManager.isCheckingInitialAuth && waitCount < 16 {
                try? await Task.sleep(for: .milliseconds(50))
                waitCount += 1
            }

            // Smooth exit animation
            withAnimation(.easeOut(duration: 0.15)) {
                scale = 1.02
                opacity = 0.0
            }
            try? await Task.sleep(for: .milliseconds(150))
            onComplete()
        }
    }
}
