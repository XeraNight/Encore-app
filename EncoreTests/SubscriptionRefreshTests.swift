import Testing
import Foundation
@testable import Encore

/// A check played against fake answers: what shows first, what a slow or overtaken check may publish, and what a
/// missing answer leaves in place. The real StoreKit and server are replaced by `World`.
@MainActor
struct SubscriptionRefreshTests {
    /// Stands in for StoreKit and the server. A held server answers only after `release()`, like a slow network; every
    /// answer is the one that was current when the question was asked.
    final class World: @unchecked Sendable {
        var user: UUID? = UUID()
        var storeKit: SubscriptionTier = .free
        var owner: Bool? = false
        var ban: BanAnswer? = BanAnswer(isBanned: false, reason: "")
        var grant: SubscriptionManager.GrantLookup = .none

        private let lock = NSLock()
        private var holds = false
        private var waiting: [CheckedContinuation<Void, Never>] = []

        var holdsServer: Bool {
            get { lock.withLock { holds } }
            set { lock.withLock { holds = newValue } }
        }
        var waitingCount: Int { lock.withLock { waiting.count } }

        func pause() async {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                lock.lock()
                if holds {
                    waiting.append(continuation)
                    lock.unlock()
                } else {
                    lock.unlock()
                    continuation.resume()
                }
            }
        }

        func release() {
            let all: [CheckedContinuation<Void, Never>] = lock.withLock {
                holds = false
                defer { waiting = [] }
                return waiting
            }
            for continuation in all { continuation.resume() }
        }

        var sources: EntitlementSources {
            EntitlementSources(
                userId: { self.user },
                storeKit: { self.storeKit },
                isOwner: { let answer = self.owner; await self.pause(); return answer },
                ban: { let answer = self.ban; await self.pause(); return answer },
                grant: { let answer = self.grant; await self.pause(); return answer }
            )
        }
    }

    private func gift(_ tier: SubscriptionTier) -> SubscriptionManager.GrantLookup {
        .granted(UserEntitlementRecord(userId: UUID(), tier: tier, source: .ownerGrant, expiresAt: nil, grantedBy: nil, notes: nil))
    }

    private func waitUntil(_ condition: @MainActor () -> Bool) async {
        for _ in 0..<400 where !condition() { try? await Task.sleep(nanoseconds: 5_000_000) }
    }

    // MARK: What shows first

    @Test func aPlanBoughtInTheAppStoreShowsBeforeTheServerAnswers() async {
        let world = World()
        world.storeKit = .plus
        world.holdsServer = true
        let manager = SubscriptionManager(sources: world.sources)
        let check = Task { await manager.refreshEntitlements() }
        await waitUntil { manager.currentTier == .plus }
        #expect(manager.currentTier == .plus && manager.entitlementSource == .storeKit)
        #expect(manager.checkedUserId == nil, "the server has not answered, so the check is not finished")

        world.release()
        await check.value
        #expect(manager.currentTier == .plus && manager.checkedUserId == world.user)
    }

    @Test func theOwnersGiftRaisesThePlanOnceTheServerAnswers() async {
        let world = World()
        world.storeKit = .plus
        world.grant = gift(.premium)
        let manager = SubscriptionManager(sources: world.sources)
        await manager.refreshEntitlements()
        #expect(manager.currentTier == .premium && manager.entitlementSource == .ownerGrant)
    }

    @Test func theOwnerIsPremiumAndNeverBanned() async {
        let world = World()
        world.owner = true
        world.ban = BanAnswer(isBanned: true, reason: "x")
        let manager = SubscriptionManager(sources: world.sources)
        await manager.refreshEntitlements()
        #expect(manager.currentTier == .premium && manager.entitlementSource == .appOwner)
        #expect(!manager.isAccountBanned)
    }

    @Test func aBannedAccountIsFreeWhateverItPaid() async {
        let world = World()
        world.storeKit = .premium
        world.ban = BanAnswer(isBanned: true, reason: "pravidlá")
        let manager = SubscriptionManager(sources: world.sources)
        await manager.refreshEntitlements()
        #expect(manager.currentTier == .free && manager.isAccountBanned && manager.banReason == "pravidlá")
    }

    @Test func anEndedSubscriptionDropsToFreeOnTheNextCheck() async {
        let world = World()
        world.storeKit = .plus
        let manager = SubscriptionManager(sources: world.sources)
        await manager.refreshEntitlements()
        #expect(manager.currentTier == .plus)

        world.storeKit = .free
        await manager.refreshEntitlements()
        #expect(manager.currentTier == .free && manager.entitlementSource == .none)
    }

    // MARK: Slow checks and account switches

    @Test func aSlowCheckThatANewerOneOvertookChangesNothing() async {
        let world = World()
        world.grant = gift(.premium)
        world.holdsServer = true
        let manager = SubscriptionManager(sources: world.sources)
        let slow = Task { await manager.refreshEntitlements() }
        await waitUntil { world.waitingCount == 3 }

        // The owner took the gift back and a newer check runs, its answers come at once.
        world.grant = .none
        world.holdsServer = false
        await manager.refreshEntitlements()
        #expect(manager.currentTier == .free)

        world.release() // the slow check finally gets its old answers
        await slow.value
        #expect(manager.currentTier == .free, "an old answer never overwrites a newer one")
    }

    @Test func anAccountSwitchInTheMiddleOfACheckPublishesNothingForTheOldAccount() async {
        let world = World()
        world.grant = gift(.premium)
        world.holdsServer = true
        let manager = SubscriptionManager(sources: world.sources)
        let check = Task { await manager.refreshEntitlements() }
        await waitUntil { world.waitingCount == 3 }

        world.user = UUID() // another dancer signs in while the first check waits
        world.release()
        await check.value
        #expect(manager.currentTier == .free && manager.checkedUserId == nil)
    }

    // MARK: A missing answer

    @Test func aMissingAnswerKeepsTheLastOneForTheSameDancerOnly() async {
        let world = World()
        world.owner = true
        let manager = SubscriptionManager(sources: world.sources)
        await manager.refreshEntitlements()
        #expect(manager.isAppOwner)

        world.owner = nil // offline
        await manager.refreshEntitlements()
        #expect(manager.isAppOwner, "offline, the owner is still the owner")

        world.user = UUID() // someone else signs in on this iPhone, still offline
        await manager.refreshEntitlements()
        #expect(!manager.isAppOwner, "another dancer inherits nothing")
    }

    @Test func aGiftSurvivesAMissingAnswerFromTheServer() async {
        let world = World()
        world.grant = gift(.premium)
        let manager = SubscriptionManager(sources: world.sources)
        await manager.refreshEntitlements()
        #expect(manager.currentTier == .premium)

        world.grant = .unavailable
        await manager.refreshEntitlements()
        #expect(manager.currentTier == .premium && manager.entitlementSource == .ownerGrant)
    }

    // MARK: Products

    @Test func everyProductStandsForItsPlan() {
        #expect(SubscriptionManager.tier(forProductID: SubscriptionManager.ProductID.plusMonthly) == .plus)
        #expect(SubscriptionManager.tier(forProductID: SubscriptionManager.ProductID.plusAnnual) == .plus)
        #expect(SubscriptionManager.tier(forProductID: SubscriptionManager.ProductID.premiumMonthly) == .premium)
        #expect(SubscriptionManager.tier(forProductID: SubscriptionManager.ProductID.premiumAnnual) == .premium)
        #expect(SubscriptionManager.tier(forProductID: "com.somebody.else") == .free)
    }
}
