import Foundation
import Testing
@testable import Encore

@MainActor
struct TrainingMomentTests {
    @Test func aReflectionFromBeforeReadsItsOneFeelingAsAMoment() {
        let entry = TrainingLogEntry(day: Date(), cadenceId: nil, title: "Tréning")
        entry.feeling = .tired
        #expect(entry.moments == [TrainingMoment(feelingRaw: "tired", danceName: nil, note: "")])
    }

    @Test func momentsKeepTheirDanceAndNoteAndTheFirstFeelingStaysReadable() {
        let entry = TrainingLogEntry(day: Date(), cadenceId: nil, title: "Tréning")
        let moments = [
            TrainingMoment(feelingRaw: "great", danceName: "Rumba", note: "konečne s hudbou"),
            TrainingMoment(feelingRaw: "tired", danceName: "Jive", note: "na konci nohy nestíhali"),
        ]
        entry.moments = moments
        #expect(entry.moments == moments)
        #expect(entry.feeling == .great)
        entry.moments = []
        #expect(entry.feeling == nil)
        #expect(entry.momentsData == nil)
    }
}
