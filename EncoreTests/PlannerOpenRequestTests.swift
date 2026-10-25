import Testing
import Foundation
@testable import Encore

/// The training card on the Lock Screen opens the right reflection: its link reads back as the same training.
@MainActor
struct PlannerOpenRequestTests {
    @Test func aWeeklyTrainingComesBackFromItsLink() throws {
        let day = Date(timeIntervalSince1970: 1_792_000_000)
        let request = PlannerOpenRequest(target: .weekly(cadenceId: UUID(), day: day))
        let url = try #require(request.url)
        #expect(PlannerOpenRequest(url: url) == request)
    }

    @Test func aSessionComesBackFromItsLink() throws {
        let request = PlannerOpenRequest(target: .session(UUID()))
        let url = try #require(request.url)
        #expect(PlannerOpenRequest(url: url) == request)
    }

    @Test func otherLinksAreNotTrainings() throws {
        #expect(PlannerOpenRequest(url: try #require(URL(string: "encore://quick/video"))) == nil)
        #expect(PlannerOpenRequest(url: try #require(URL(string: "https://encore-sk.com/plan?session=\(UUID())"))) == nil)
        #expect(PlannerOpenRequest(url: try #require(URL(string: "encore://plan?session=nie-je-id"))) == nil)
    }
}
