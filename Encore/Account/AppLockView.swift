import Combine
import SwiftUI
import UIKit

// MARK: - App lock
/// Shown over the app when Face ID sign-in is on and Encore was reopened. The session stays on the
/// phone; Face ID (or the passcode) only unlocks the screen. Signing out is always possible from here.
struct AppLockView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @State private var confirmSignOut = false
    @State private var taps = 0

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
                    if let note = authManager.lockNote {
                        Text(note)
                            .font(.footnote)
                            .foregroundColor(.gold400)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }
                }

                Spacer()

                PrimarySheetButton(
                    title: "Odomknúť cez \(authManager.biometryName)",
                    isLoading: false,
                    isEnabled: true
                ) {
                    taps += 1
                    Task { await authManager.unlockApp() }
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
        // The first question is asked by AuthManager when Encore is in front (see AppLockState); the button asks again.
        .confirmationDialog("Odhlásiť sa?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Odhlásiť sa", role: .destructive) {
                Task { await authManager.signOut() }
            }
        } message: {
            Text("Potom sa prihlásiš e-mailom a heslom alebo cez Google.")
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: taps)
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

// MARK: - Cover for the app switcher
/// What the app switcher keeps of Encore while the Face ID lock is on: the logo, not a page of the diary. iOS takes the
/// picture when the app stops being in front, so the cover goes up then and comes down when the app is back.
struct PrivacyCoverView: View {
    var body: some View {
        ZStack {
            EllegancePageBackground()
            VStack(spacing: 14) {
                Image("EncoreLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                EncoreWordmark(size: 15, color: .gold400)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// The cover in its own window above everything, like the lock: over a sheet or the camera a cover inside the app's own
/// view would leave them in the picture. It takes no touches and no focus, so the keyboard and the field stay as they
/// were. The lock itself still closes only after a real trip to the background (`AppLockState`).
@MainActor
final class PrivacyCoverWindow {
    static let shared = PrivacyCoverWindow()
    private var window: UIWindow?
    private var isShown = false

    private init() {}

    /// Only when the lock is on and there is something to hide: a signed-out iPhone shows a login screen, and a locked
    /// Encore is already covered by the lock.
    static func shouldCover(isActive: Bool, lockIsOn: Bool, isSignedIn: Bool, isLocked: Bool) -> Bool {
        !isActive && lockIsOn && isSignedIn && !isLocked
    }

    /// Builds the window ahead of time, so the cover is there the moment the app goes out of focus.
    func prepare() {
        coverWindow()?.rootViewController?.view.layoutIfNeeded()
    }

    func show() {
        isShown = true
        guard let window = coverWindow() else { return }
        window.layer.removeAllAnimations()
        window.alpha = 1
        window.isHidden = false
    }

    func hide() {
        guard isShown, let window else { return }
        isShown = false
        UIView.animate(withDuration: 0.15, animations: { window.alpha = 0 }, completion: { [weak self] _ in
            // The app went out of focus again before the cover was gone: it stays.
            if self?.isShown == false { window.isHidden = true }
        })
    }

    private func coverWindow() -> UIWindow? {
        if let window { return window }
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return nil }
        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.overrideUserInterfaceStyle = .dark
        window.isUserInteractionEnabled = false
        window.isHidden = true
        window.rootViewController = UIHostingController(rootView: PrivacyCoverView())
        self.window = window
        return window
    }
}
