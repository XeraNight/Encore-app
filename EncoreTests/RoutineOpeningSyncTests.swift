import Testing
import Foundation
@testable import Encore

/// What a routine takes from the cloud when it opens: the newer version, a routine that came down empty, and the
/// figures this iPhone lacks even when its own version looks newer (opened offline first, given a figure there).
struct RoutineOpeningSyncTests {
    private let earlier = Date(timeIntervalSince1970: 1_800_000_000)
    private let later = Date(timeIntervalSince1970: 1_800_001_000)
    private let a = UUID(), b = UUID(), c = UUID()

    @Test func aNewerCloudVersionWins() {
        let plan = SupabaseSyncManager.openingPlan(cloudUpdatedAt: later, localUpdatedAt: earlier, localFigureIds: [a], cloudFigureIds: [a, b])
        #expect(plan.adoptsCloud && plan.reconcilesFigures)
    }

    @Test func aRoutineThatCameDownWithoutFiguresGetsThem() {
        // Same date (the list brought the cloud's), no figures here: the date alone would keep it empty.
        let plan = SupabaseSyncManager.openingPlan(cloudUpdatedAt: earlier, localUpdatedAt: earlier, localFigureIds: [], cloudFigureIds: [a, b])
        #expect(plan.adoptsCloud && plan.reconcilesFigures)
    }

    @Test func aFigureAddedOfflineDoesNotKeepTheRestOfTheCloudAway() {
        // This iPhone looks newer (a figure was added offline before the first open), the cloud has two it lacks.
        let plan = SupabaseSyncManager.openingPlan(cloudUpdatedAt: earlier, localUpdatedAt: later, localFigureIds: [c], cloudFigureIds: [a, b, c])
        #expect(!plan.adoptsCloud)
        #expect(plan.reconcilesFigures)
    }

    @Test func nothingChangesWhenBothHoldTheSameFigures() {
        let plan = SupabaseSyncManager.openingPlan(cloudUpdatedAt: earlier, localUpdatedAt: later, localFigureIds: [a, b], cloudFigureIds: [b, a])
        #expect(!plan.adoptsCloud && !plan.reconcilesFigures)
    }

    @Test func anEmptyCloudAnswerTakesNothingFromThisIPhone() {
        let plan = SupabaseSyncManager.openingPlan(cloudUpdatedAt: earlier, localUpdatedAt: later, localFigureIds: [a, b], cloudFigureIds: [])
        #expect(!plan.adoptsCloud && !plan.reconcilesFigures)
    }
}
