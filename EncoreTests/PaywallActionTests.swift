import Testing
@testable import Encore

/// What the paywall offers for the plan picked: the product decides, not the plan level.
@MainActor
struct PaywallActionTests {
    private let plusMonthly = SubscriptionManager.ProductID.plusMonthly
    private let plusAnnual = SubscriptionManager.ProductID.plusAnnual
    private let premiumMonthly = SubscriptionManager.ProductID.premiumMonthly

    private func action(owner: Bool = false, holds: String?, picks: String?) -> PaywallAction {
        SubscriptionPaywallView.action(isOwner: owner, activeProductID: holds, selectedProductID: picks)
    }

    @Test func theOwnerHasEverythingWhateverIsPicked() {
        #expect(action(owner: true, holds: nil, picks: plusAnnual) == .owner)
    }

    @Test func theProductThatIsAlreadyHeldIsNotSoldAgain() {
        #expect(action(holds: plusMonthly, picks: plusMonthly) == .alreadyHave)
    }

    @Test func aMonthlySubscriberCanSwitchToAnnual() {
        #expect(action(holds: plusMonthly, picks: plusAnnual) == .buy)
    }

    @Test func aHigherPlanCanBeBought() {
        #expect(action(holds: plusMonthly, picks: premiumMonthly) == .buy)
    }

    @Test func withoutASubscriptionOrWithoutLoadedProductsNothingCountsAsHeld() {
        #expect(action(holds: nil, picks: plusMonthly) == .buy)
        #expect(action(holds: plusMonthly, picks: nil) == .buy, "products not loaded yet: the button reports it on tap")
        #expect(action(holds: nil, picks: nil) == .buy)
    }
}
