import Foundation
import UserNotifications
import SwiftUI
import Combine
import OSLog

// MARK: - Notification Manager
/// Permission for local notifications and what a tapped one opens. The reminders are planned in `PlannerNotifications`.
@MainActor
final class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    @Published var isAuthorized = false
    @AppStorage("notificationsEnabled") var notificationsEnabled = true

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        Task { await checkAuthorizationStatus() }
    }

    // MARK: - Check Status
    func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = (settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional)
    }

    // MARK: - Request Authorization
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            isAuthorized = granted
            notificationsEnabled = granted
            return granted
        } catch {
            Logger.general.error("Notification permission request failed: \(error.localizedDescription, privacy: .public)")
            isAuthorized = false
            return false
        }
    }

    // MARK: - UNUserNotificationCenterDelegate
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner even when app is open in foreground
        completionHandler([.banner, .sound, .badge])
    }

    /// "Tréning skončil" opens the reflection of that training.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let request = PlannerOpenRequest(userInfo: response.notification.request.content.userInfo) {
            Task { @MainActor in PlannerRouter.shared.pending = request }
        }
        completionHandler()
    }
}
