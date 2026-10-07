//
//  EntitlementTests.swift
//  FlashForgeTests
//

import XCTest
@testable import FlashForge

final class EntitlementTests: XCTestCase {
    func testBuyersOfPaidBuildsAreLegacyPurchasers() {
        let lastPaid = "2026.08.18.1"
        XCTAssertTrue(LegacyPurchasePolicy.isLegacyPurchaser(originalAppVersion: "2026.08.18.1", lastPaidBuild: lastPaid))
        XCTAssertTrue(LegacyPurchasePolicy.isLegacyPurchaser(originalAppVersion: "2026.02.11.3", lastPaidBuild: lastPaid))
        XCTAssertTrue(LegacyPurchasePolicy.isLegacyPurchaser(originalAppVersion: "2026.8.18", lastPaidBuild: lastPaid))
        XCTAssertTrue(LegacyPurchasePolicy.isLegacyPurchaser(originalAppVersion: "1", lastPaidBuild: lastPaid))
    }

    func testDownloadsAfterTheLastPaidBuildAreNotLegacyPurchasers() {
        let lastPaid = "2026.08.18.1"
        XCTAssertFalse(LegacyPurchasePolicy.isLegacyPurchaser(originalAppVersion: "2026.08.18.2", lastPaidBuild: lastPaid))
        XCTAssertFalse(LegacyPurchasePolicy.isLegacyPurchaser(originalAppVersion: "2026.11.02.1", lastPaidBuild: lastPaid))
        XCTAssertFalse(LegacyPurchasePolicy.isLegacyPurchaser(originalAppVersion: "2027.01.01.1", lastPaidBuild: lastPaid))
    }

    func testUnparseableVersionsAreNotLegacyPurchasers() {
        XCTAssertFalse(LegacyPurchasePolicy.isLegacyPurchaser(originalAppVersion: "", lastPaidBuild: "2026.08.18.1"))
        XCTAssertFalse(LegacyPurchasePolicy.isLegacyPurchaser(originalAppVersion: "2.0-beta", lastPaidBuild: "2026.08.18.1"))
    }

    func testTierResolution() {
        XCTAssertEqual(AccessTier.resolve(ownedProductIDs: [], isLegacyPurchaser: false), .free)
        XCTAssertEqual(AccessTier.resolve(ownedProductIDs: [], isLegacyPurchaser: true), .core)
        XCTAssertEqual(AccessTier.resolve(ownedProductIDs: [StoreProduct.core], isLegacyPurchaser: false), .core)
        XCTAssertEqual(AccessTier.resolve(ownedProductIDs: [StoreProduct.proYearly], isLegacyPurchaser: false), .pro)
        XCTAssertEqual(AccessTier.resolve(ownedProductIDs: [StoreProduct.proMonthly], isLegacyPurchaser: true), .pro)
    }

    func testLegacyProOfferIsOnlyShownToLegacyBuyersWithoutPro() {
        XCTAssertTrue(EntitlementSnapshot(tier: .core, isLegacyPurchaser: true).showsLegacyProOffer)
        XCTAssertFalse(EntitlementSnapshot(tier: .pro, isLegacyPurchaser: true).showsLegacyProOffer)
        XCTAssertFalse(EntitlementSnapshot(tier: .core, isLegacyPurchaser: false).showsLegacyProOffer)
        XCTAssertFalse(EntitlementSnapshot.free.showsLegacyProOffer)
    }

    func testFreeTierBlocksOnlyNewContentBeyondTheLimit() {
        XCTAssertTrue(FeatureGate.canCreateDeck(existingDeckCount: FreeTierLimits.maxDecks - 1, tier: .free))
        XCTAssertFalse(FeatureGate.canCreateDeck(existingDeckCount: FreeTierLimits.maxDecks, tier: .free))
        XCTAssertTrue(FeatureGate.canCreateDeck(existingDeckCount: 500, tier: .core))
        XCTAssertTrue(FeatureGate.canAddCard(existingCardCount: FreeTierLimits.maxCardsPerDeck - 1, tier: .free))
        XCTAssertFalse(FeatureGate.canAddCard(existingCardCount: FreeTierLimits.maxCardsPerDeck, tier: .free))
        XCTAssertTrue(FeatureGate.canAddCard(existingCardCount: 5000, tier: .pro))
    }
}
