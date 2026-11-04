import Foundation
import AppIntents

extension Notification.Name {
    static let stopRecordingFromLiveActivity = Notification.Name("stopRecordingFromLiveActivity")
    static let bookmarkRecordingFromLiveActivity = Notification.Name("bookmarkRecordingFromLiveActivity")
}

#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
import ActivityKit

struct StopRecordingIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop Recording"
    static var description = IntentDescription("Stops the active dance camera recording.")

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .stopRecordingFromLiveActivity, object: nil)
        let notificationName = "com.encore.stopRecording" as CFString
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(notificationName),
            nil,
            nil,
            true
        )

        for activity in Activity<RecordingActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        return .result()
    }
}

struct BookmarkRecordingIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Bookmark Moment"
    static var description = IntentDescription("Bookmarks a key dance moment into Instant Notes.")

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .bookmarkRecordingFromLiveActivity, object: nil)
        let notificationName = "com.encore.bookmark" as CFString
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(notificationName),
            nil,
            nil,
            true
        )
        return .result()
    }
}
#endif

