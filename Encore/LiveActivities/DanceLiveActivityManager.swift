import Foundation
import ActivityKit
import Combine
import OSLog

// MARK: - Dance Live Activity Manager
@MainActor
final class DanceLiveActivityManager: ObservableObject {
    static let shared = DanceLiveActivityManager()
    
    private var currentActivity: Activity<DanceFinalActivityAttributes>? = nil
    
    private init() {}
    
    // Check if Live Activities are enabled by system & user
    var isLiveActivityEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }
    
    // MARK: - Start Live Activity
    func startLiveActivity(
        discipline: String,
        routineName: String,
        firstDance: String,
        totalDances: Int,
        durationSeconds: Int,
        firstFigure: String = "Základný nášľap"
    ) {
        guard isLiveActivityEnabled else {
            Logger.camera.notice("Live Activities are disabled on this device")
            return
        }
        
        // End any previous leftover activity
        endLiveActivity()
        
        let attributes = DanceFinalActivityAttributes(
            disciplineName: discipline,
            routineName: routineName
        )
        
        let initialContentState = DanceFinalActivityAttributes.ContentState(
            currentDanceName: firstDance,
            currentDanceIndex: 0,
            totalDances: totalDances,
            timeRemainingSeconds: durationSeconds,
            isResting: false,
            currentFigureName: firstFigure
        )
        
        do {
            let activity = try Activity<DanceFinalActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: initialContentState, staleDate: nil),
                pushType: nil
            )
            self.currentActivity = activity
            Logger.camera.info("Started Live Activity \(activity.id, privacy: .public)")
        } catch {
            Logger.camera.error("Starting Live Activity failed: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    // MARK: - Update Live Activity State
    func updateLiveActivity(
        danceName: String,
        danceIndex: Int,
        totalDances: Int,
        timeRemaining: Int,
        isResting: Bool,
        currentFigure: String
    ) {
        guard let activity = currentActivity else { return }
        
        let updatedState = DanceFinalActivityAttributes.ContentState(
            currentDanceName: danceName,
            currentDanceIndex: danceIndex,
            totalDances: totalDances,
            timeRemainingSeconds: timeRemaining,
            isResting: isResting,
            currentFigureName: currentFigure
        )
        
        Task {
            await activity.update(.init(state: updatedState, staleDate: nil))
        }
    }
    
    // MARK: - End Live Activity
    func endLiveActivity() {
        guard let activity = currentActivity else { return }
        
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            await MainActor.run {
                self.currentActivity = nil
            }
        }
    }
}
