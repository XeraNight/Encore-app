import SwiftUI

// MARK: - App lock
/// Shown over the app when Face ID sign-in is on and Encore was reopened. The session stays on the
/// phone; Face ID (or the passcode) only unlocks the screen. Signing out is always possible from here.
struct AppLockView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @State private var confirmSignOut = false
    @State private var attempt = 0

    var body: some View {
        ZStack {
            EllegancePageBackground()

            VStack(spacing: 18) {
                Spacer()

                Image("EncoreLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .accessibilityHidden(true)
                EncoreWordmark(size: 15, color: .gold400)

                VStack(spacing: 6) {
                    Text("Encore je zamknutá")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundColor(.white)
                    Text(authManager.userEmail)
                        .font(.footnote)
                        .foregroundColor(Color.white.opacity(0.65))
                }

                Spacer()

                PrimarySheetButton(
                    title: "Odomknúť cez \(authManager.biometryName)",
                    isLoading: false,
                    isEnabled: true
                ) {
                    attempt += 1
                }

                Button("Odhlásiť sa") { confirmSignOut = true }
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Color.white.opacity(0.7))
                    .frame(minHeight: 44)
                    .buttonStyle(.pressable)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        // Asks right away when the lock appears, and again on every tap of the button.
        .task(id: attempt) { await authManager.unlockApp() }
        .confirmationDialog("Odhlásiť sa?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Odhlásiť sa", role: .destructive) {
                Task { await authManager.signOut() }
            }
        } message: {
            Text("Potom sa prihlásiš e-mailom a heslom alebo cez Google.")
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: attempt)
    }
}
