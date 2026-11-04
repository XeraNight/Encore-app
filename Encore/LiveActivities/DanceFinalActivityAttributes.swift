import Foundation
import ActivityKit

// MARK: - Dance Final Activity Attributes (ActivityKit Model)
public struct DanceFinalActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var currentDanceName: String
        public var currentDanceIndex: Int
        public var totalDances: Int
        public var timeRemainingSeconds: Int
        public var isResting: Bool
        public var currentFigureName: String
        
        public init(
            currentDanceName: String,
            currentDanceIndex: Int,
            totalDances: Int,
            timeRemainingSeconds: Int,
            isResting: Bool,
            currentFigureName: String
        ) {
            self.currentDanceName = currentDanceName
            self.currentDanceIndex = currentDanceIndex
            self.totalDances = totalDances
            self.timeRemainingSeconds = timeRemainingSeconds
            self.isResting = isResting
            self.currentFigureName = currentFigureName
        }
    }
    
    public var disciplineName: String
    public var routineName: String
    
    public init(disciplineName: String, routineName: String) {
        self.disciplineName = disciplineName
        self.routineName = routineName
    }
}
