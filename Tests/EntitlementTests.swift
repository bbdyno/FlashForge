//
//  EntitlementTests.swift
//  FlashForgeTests
//

import XCTest
@testable import FlashForge

final class EntitlementTests: XCTestCase {
    private let lastPaid = "2026.08.18.1"
    private let paidAgain = PaidDownloadPolicy.paidAgainSince(from: "2026-11-16")!

    private func owns(_ build: String, on day: String, paidAgainSince: Date?? = nil) -> Bool {
        let formatter = ISO8601DateFormatter()
        return PaidDownloadPolicy.ownsPaidDownload(
            originalAppVersion: build,
            originalPurchaseDate: formatter.date(from: day)!,
            lastPaidBuild: lastPaid,
            paidAgainSince: paidAgainSince ?? paidAgain
        )
    }

    func testOneXBuyersOwnThePaidDownload() {
        XCTAssertTrue(owns("2026.08.18.1", on: "2026-08-20T00:00:00Z"))
        XCTAssertTrue(owns("2026.02.11.3", on: "2026-02-12T00:00:00Z"))
        XCTAssertTrue(owns("2026.8.18", on: "2026-08-19T00:00:00Z"))
        XCTAssertTrue(owns("1", on: "2026-02-12T00:00:00Z"))
    }

    func testFreePeriodDownloadsDoNotOwnThePaidDownload() {
        XCTAssertFalse(owns("2026.10.12.1", on: "2026-10-20T00:00:00Z"))
        // The 2.1 build downloaded before the price change took effect.
        XCTAssertFalse(owns("2026.11.09.1", on: "2026-11-14T12:00:00Z"))
    }

    func testDownloadsFromThePaidAgainDayOwnThePaidDownload() {
        // The App Store can still serve the 2.0 build right after the price change.
        XCTAssertTrue(owns("2026.10.12.1", on: "2026-11-16T00:00:00Z"))
        XCTAssertTrue(owns("2026.11.09.1", on: "2027-01-01T00:00:00Z"))
    }

    func testThePaidAgainDayStartsInTheEarliestTimeZone() {
        // 2026-11-16 00:00 at UTC+14 is 2026-11-15 10:00 UTC.
        XCTAssertFalse(owns("2026.11.09.1", on: "2026-11-15T09:59:59Z"))
        XCTAssertTrue(owns("2026.11.09.1", on: "2026-11-15T10:00:00Z"))
    }

    func testWithoutAPaidAgainDayOnlyOneXBuyersOwnIt() {
        XCTAssertTrue(owns("2026.08.18.1", on: "2026-08-20T00:00:00Z", paidAgainSince: .some(nil)))
        XCTAssertFalse(owns("2026.11.09.1", on: "2027-01-01T00:00:00Z", paidAgainSince: .some(nil)))
    }

    func testUnparseableInputs() {
        XCTAssertFalse(PaidDownloadPolicy.isAtOrBefore("", lastPaid))
        XCTAssertFalse(PaidDownloadPolicy.isAtOrBefore("2.0-beta", lastPaid))
        XCTAssertNil(PaidDownloadPolicy.paidAgainSince(from: ""))
        XCTAssertNil(PaidDownloadPolicy.paidAgainSince(from: "2026-13-01"))
    }

    func testTierResolution() {
        XCTAssertEqual(AccessTier.resolve(ownedProductIDs: [], ownsPaidDownload: false), .free)
        XCTAssertEqual(AccessTier.resolve(ownedProductIDs: [], ownsPaidDownload: true), .full)
        XCTAssertEqual(AccessTier.resolve(ownedProductIDs: [StoreProduct.unlock], ownsPaidDownload: false), .full)
        for subscription in StoreProduct.retiredSubscriptionIDs {
            XCTAssertEqual(AccessTier.resolve(ownedProductIDs: [subscription], ownsPaidDownload: false), .full)
        }
        XCTAssertEqual(AccessTier.resolve(ownedProductIDs: ["something.else"], ownsPaidDownload: false), .free)
    }

    func testSnapshotsCachedBy2Point0ReadBack() throws {
        func decode(_ json: String) throws -> EntitlementSnapshot {
            try JSONDecoder().decode(EntitlementSnapshot.self, from: Data(json.utf8))
        }
        XCTAssertEqual(try decode(#"{"tier":0,"isLegacyPurchaser":false}"#), .free)
        XCTAssertEqual(try decode(#"{"tier":1,"isLegacyPurchaser":true}"#), EntitlementSnapshot(tier: .full, ownsPaidDownload: true))
        XCTAssertEqual(try decode(#"{"tier":2,"isLegacyPurchaser":false}"#).tier, .full)

        let roundTrip = EntitlementSnapshot(tier: .full, ownsPaidDownload: true)
        XCTAssertEqual(try JSONDecoder().decode(EntitlementSnapshot.self, from: JSONEncoder().encode(roundTrip)), roundTrip)
    }

    func testFreeTierBlocksOnlyNewContentBeyondTheLimit() {
        XCTAssertTrue(FeatureGate.canCreateDeck(existingDeckCount: FreeTierLimits.maxDecks - 1, tier: .free))
        XCTAssertFalse(FeatureGate.canCreateDeck(existingDeckCount: FreeTierLimits.maxDecks, tier: .free))
        XCTAssertTrue(FeatureGate.canCreateDeck(existingDeckCount: 500, tier: .full))
        XCTAssertTrue(FeatureGate.canAddCard(existingCardCount: FreeTierLimits.maxCardsPerDeck - 1, tier: .free))
        XCTAssertFalse(FeatureGate.canAddCard(existingCardCount: FreeTierLimits.maxCardsPerDeck, tier: .free))
        XCTAssertTrue(FeatureGate.canAddCard(existingCardCount: 5000, tier: .full))
    }
}
