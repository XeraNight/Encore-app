import ActivityKit
import Foundation
import OSLog

/// A training within the reminder window: either the Lock Screen card or the notification an hour before.
struct UpcomingTraining {
    let reminderId: String
    let title: String
    let start: Date
    let end: Date
    /// "Zameraj sa na: …", or empty.
    let focus: String
    let open: PlannerOpenRequest

    /// "Dnes 18:00 · Klubový tréning"
    var headline: String { "Dnes \(start.formatted(date: .omitted, time: .shortened)) · \(title)" }
}

// MARK: - The next training on the Lock Screen
/// The next training as a Live Activity in the Encore glass. iOS 26 lets the app schedule it, so it appears an hour
/// before the training even with the app closed, rings like a notification, counts down to the start and then the
/// time trained, and after the end asks how it went. Only the next training: the one after it is scheduled when the
/// app opens again. Where Live Activities are off, the usual notification goes instead.
@MainActor
enum TrainingActivity {
    /// Shows `training` (an identical card already there stays) and takes away every other training card.
    /// Returns whether the card is on its way, so the notification an hour before can stay out.
    @discardableResult
    static func show(_ training: UpcomingTraining?) async -> Bool {
        let key = training.map { "\($0.reminderId)|\(Int($0.start.timeIntervalSince1970))" }
        var isThere = false
        for activity in Activity<TrainingActivityAttributes>.activities {
            if activity.attributes.key == key, !isThere {
                isThere = true
            } else {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        guard let training, let key, let url = training.open.url else { return false }
        if isThere { return true }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return false }

        let attributes = TrainingActivityAttributes(key: key, title: training.title, reflectionURL: url.absoluteString)
        let content = ActivityContent(
            state: TrainingActivityAttributes.ContentState(start: training.start, end: training.end, focus: training.focus),
            staleDate: training.end
        )
        let appearsAt = training.start.addingTimeInterval(-60 * 60)
        do {
            if appearsAt > Date() {
                let alert = AlertConfiguration(
                    title: "\(training.headline)",
                    body: "\(training.focus.isEmpty ? "Tréning začína o hodinu." : training.focus)",
                    sound: .default
                )
                _ = try Activity.request(attributes: attributes, content: content, pushType: nil, style: .standard,
                                         alertConfiguration: alert, start: appearsAt)
            } else {
                // Already within the hour, or under way: the card shows now, quietly.
                _ = try Activity.request(attributes: attributes, content: content, pushType: nil)
            }
            return true
        } catch {
            Logger.general.error("Training card failed, the notification goes instead: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
