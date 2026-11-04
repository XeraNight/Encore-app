import Combine
import SwiftUI
import UIKit

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

// MARK: - Lock window
/// The lock in its own window above everything. In the app's own view it sat under whatever was open when Encore
/// went to the background (a sheet, the camera, a reflection), which stayed readable and usable over the lock.
@MainActor
final class AppLockWindow {
    static let shared = AppLockWindow()
    private var window: UIWindow?
    private var lockChanges: AnyCancellable?

    private init() {}

    /// From the end of the splash on, the window follows `AuthManager.isAppLocked`.
    func start(in scene: UIWindowScene) {
        guard lockChanges == nil else { return }
        lockChanges = AuthManager.shared.$isAppLocked
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] locked in
                if locked { self?.show(in: scene) } else { self?.hide() }
            }
    }

    private func show(in scene: UIWindowScene) {
        guard window == nil else { return }
        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        // Dark like the app's own window, so the status bar reads white on the velvet.
        window.overrideUserInterfaceStyle = .dark
        window.rootViewController = UIHostingController(rootView: AppLockView())
        window.makeKeyAndVisible()
        self.window = window
    }

    private func hide() {
        guard let window else { return }
        self.window = nil
        UIView.animate(withDuration: 0.3, animations: { window.alpha = 0 }, completion: { _ in
            window.isHidden = true
            // The app's own window takes the keyboard again.
            window.windowScene?.windows.first { $0 !== window && !$0.isHidden }?.makeKey()
        })
    }
}
