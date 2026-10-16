import Foundation
import UserNotifications
import SwiftUI
import Combine
import OSLog

// MARK: - Notification Manager
// Správca lokálnych notifikácií, tréningových pripomenutí a upozornení o zmenách od partnera.
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

    // MARK: - Schedule Training Reminder
    func scheduleTrainingReminder(routineName: String, danceName: String, inTimeInterval interval: TimeInterval) {
        guard notificationsEnabled, isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Tréning zostavy: \(routineName)"
        content.subtitle = danceName
        content.body = "Je čas zopakovať si figúry a prechody v zostave \(routineName)."
        content.sound = .default
        content.badge = 1

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(5, interval), repeats: false)
        let request = UNNotificationRequest(
            identifier: "training_reminder_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Logger.general.error("Scheduling reminder failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - Partner Action Alert
    func notifyPartnerUpdate(senderName: String, actionDescription: String) {
        guard notificationsEnabled, isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Aktualizácia od partnera (\(senderName))"
        content.body = actionDescription
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "partner_update_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
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
