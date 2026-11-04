#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
import ActivityKit
import Foundation

struct EncoreAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamické dáta, ktoré sa menia počas tréningu
        var currentFigureName: String
        var nextFigureName: String
        var currentFigureIndex: Int
        var totalFigures: Int
        var lastUpdated: Date
    }

    // Statické vlastnosti, ktoré sa počas tréningu nemenia
    var routineName: String
    var danceName: String
}

struct RecordingActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var startDate: Date
        var sessionTitle: String
        var metronomeName: String
        var bpm: Int
        var beatsPerMeasure: Int
        var audioLevel: Float
    }

    var recordingName: String
}

/// The next training on the Lock Screen: scheduled to appear an hour before it starts, stale when it ends.
struct TrainingActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var start: Date
        var end: Date
        /// "Zameraj sa na: …", or empty.
        var focus: String
    }

    /// The training and its start, so a moved training is a new card.
    var key: String
    var title: String
    /// Opens this training's reflection in the app (encore://plan?…).
    var reflectionURL: String
}
#endif
