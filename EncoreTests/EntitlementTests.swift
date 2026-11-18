import Testing
import Foundation
@testable import Encore

/// The plan from Apple, the server and the last answer: a plan that ended is over, the owner's gift survives a missing
/// signal, and "the server has no row for me" is an answer, not a missing signal.
struct EntitlementTests {
    private func gift(_ tier: SubscriptionTier, source: EntitlementSource = .ownerGrant,
                      expires: Date? = nil) -> SubscriptionManager.GrantLookup {
        .granted(UserEntitlementRecord(userId: UUID(), tier: tier, source: source, expiresAt: expires, grantedBy: nil, notes: nil))
    }

    private func resolve(storeKit: SubscriptionTier = .free, _ grant: SubscriptionManager.GrantLookup,
                         cached: (SubscriptionTier, EntitlementSource)? = nil) -> (tier: SubscriptionTier, source: EntitlementSource, isKept: Bool) {
        SubscriptionManager.resolve(storeKit: storeKit, grant: grant, cached: cached.map { (tier: $0.0, source: $0.1) })
    }

    @Test func aPlanBoughtInTheAppStoreCountsWithoutAnyRowOnTheServer() {
        let plan = resolve(storeKit: .plus, .none)
        #expect(plan.tier == .plus && plan.source == .storeKit && !plan.isKept)
    }

    @Test func anEndedSubscriptionIsNotKeptFromTheLastAnswer() {
        // The server has no row for a paying dancer: that is an answer, so nothing is kept for 30 days.
        let plan = resolve(.none, cached: (.plus, .storeKit))
        #expect(plan.tier == .free && plan.source == .none && !plan.isKept)
    }

    @Test func anEndedSubscriptionIsNotKeptOfflineEither() {
        // Apple answers by itself without a signal, so there is nothing to bridge.
        #expect(resolve(.unavailable, cached: (.premium, .storeKit)).tier == .free)
    }

    @Test func theOwnersGiftSurvivesAMissingSignalButNotAnAnswer() {
        let kept = resolve(.unavailable, cached: (.premium, .ownerGrant))
        #expect(kept.tier == .premium && kept.source == .ownerGrant && kept.isKept)
        // The owner took it back: the server says there is no row.
        #expect(resolve(.none, cached: (.premium, .ownerGrant)).tier == .free)
    }

    @Test func aGiftCountsOnlyWhileItLasts() {
        let ended = gift(.premium, expires: Date().addingTimeInterval(-60))
        #expect(resolve(ended).tier == .free)
        let lasting = gift(.premium, expires: Date().addingTimeInterval(3600))
        #expect(resolve(lasting).tier == .premium)
    }

    @Test func aRowThatSaysStoreKitProvesNothing() {
        // A client could write such a row; a paid plan is proven only by what Apple signs.
        #expect(resolve(gift(.premium, source: .storeKit)).tier == .free)
    }

    @Test func theHigherOfTheTwoWins() {
        let giftWins = resolve(storeKit: .plus, gift(.premium))
        #expect(giftWins.tier == .premium && giftWins.source == .ownerGrant)
        let paidWins = resolve(storeKit: .premium, gift(.plus))
        #expect(paidWins.tier == .premium && paidWins.source == .storeKit)
    }

    @Test func nobodyGetsAPlanFromNothing() {
        #expect(resolve(.none).tier == .free)
        #expect(resolve(.unavailable).tier == .free)
    }
}
