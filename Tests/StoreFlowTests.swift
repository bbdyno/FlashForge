//
//  StoreFlowTests.swift
//  FlashForgeTests
//

import SharedResources
import StoreKit
import StoreKitTest
import XCTest
@testable import FlashForge

@MainActor
final class StoreFlowTests: XCTestCase {
    private var session: SKTestSession!
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        session = try SKTestSession(configurationFileNamed: "FlashForge")
        session.disableDialogs = true
        // These are stored per app, not per session, so a test that turns one
        // on would otherwise change every test after it.
        session.askToBuyEnabled = false
        session.failTransactionsEnabled = false
        session.clearTransactions()
        session.storefront = Self.localStorefront
        suiteName = "StoreFlowTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDownWithError() throws {
        session.clearTransactions()
        defaults.removePersistentDomain(forName: suiteName)
        session = nil
        defaults = nil
    }

    // Only the local test session can move the storefront, so seeing it change
    // proves purchases stay on this machine. Where the session cannot attach
    // (xcodebuild on an older simulator runtime falls through to the App Store
    // sandbox) the tests skip rather than buy anything or report a false failure.
    private static let localStorefront = "KOR"

    private func requireLocalStore() async throws {
        guard await Storefront.current?.countryCode == Self.localStorefront else {
            throw XCTSkip("Local StoreKit test environment is not available")
        }
    }

    private func loadProducts(_ service: EntitlementService) async throws -> [Product] {
        try await requireLocalStore()
        return try await service.products()
    }

    func testAllProductsAreAvailable() async throws {
        let service = EntitlementService(defaults: defaults)
        let products = try await loadProducts(service)
        XCTAssertEqual(Set(products.map(\.id)), StoreProduct.allIDs)
    }

    func testBuyingCoreThenProRaisesTheTier() async throws {
        let service = EntitlementService(defaults: defaults)
        let products = try await loadProducts(service)
        await service.refresh()
        XCTAssertEqual(service.snapshot.tier, .free)

        let core = try XCTUnwrap(products.first { $0.id == StoreProduct.core })
        let purchasedCore = try await service.purchase(core)
        XCTAssertTrue(purchasedCore)
        XCTAssertEqual(service.snapshot.tier, .core)

        let yearly = try XCTUnwrap(products.first { $0.id == StoreProduct.proYearly })
        let purchasedPro = try await service.purchase(yearly)
        XCTAssertTrue(purchasedPro)
        XCTAssertEqual(service.snapshot.tier, .pro)

        // A fresh launch starts from the cached tier instead of free.
        XCTAssertEqual(EntitlementService(defaults: defaults).snapshot.tier, .pro)
    }

    func testRefundingCoreDropsBackToFree() async throws {
        let service = EntitlementService(defaults: defaults)
        let products = try await loadProducts(service)
        let core = try XCTUnwrap(products.first { $0.id == StoreProduct.core })
        try await service.purchase(core)
        XCTAssertEqual(service.snapshot.tier, .core)

        let transaction = try XCTUnwrap(session.allTransactions().first)
        try session.refundTransaction(identifier: transaction.identifier)
        try await waitForTier(.free, in: service, refreshing: true)
    }

    func testMonthlyPlanUnlocksPro() async throws {
        let service = EntitlementService(defaults: defaults)
        let products = try await loadProducts(service)
        let monthly = try XCTUnwrap(products.first { $0.id == StoreProduct.proMonthly })
        let purchased = try await service.purchase(monthly)
        XCTAssertTrue(purchased)
        XCTAssertEqual(service.snapshot.tier, .pro)
    }

    func testRestoreRecoversPurchasesOnAFreshInstall() async throws {
        try await requireLocalStore()
        try await session.buyProduct(identifier: StoreProduct.core)
        try await session.buyProduct(identifier: StoreProduct.proYearly)

        // Nothing cached, as after a reinstall or on a second device.
        let service = EntitlementService(defaults: defaults)
        XCTAssertEqual(service.snapshot.tier, .free)
        try await service.restorePurchases()
        XCTAssertEqual(service.snapshot.tier, .pro)
    }

    func testRestoreWithNothingBoughtStaysFree() async throws {
        try await requireLocalStore()
        let service = EntitlementService(defaults: defaults)
        try await service.restorePurchases()
        XCTAssertEqual(service.snapshot.tier, .free)
    }

    func testExpiredSubscriptionFallsBackToCore() async throws {
        let service = EntitlementService(defaults: defaults)
        let products = try await loadProducts(service)
        let core = try XCTUnwrap(products.first { $0.id == StoreProduct.core })
        let yearly = try XCTUnwrap(products.first { $0.id == StoreProduct.proYearly })
        try await service.purchase(core)
        try await service.purchase(yearly)
        XCTAssertEqual(service.snapshot.tier, .pro)

        try expireWithoutRenewal(StoreProduct.proYearly)
        try await waitForTier(.core, in: service, refreshing: true)
    }

    func testExpiredSubscriptionWithoutCoreFallsBackToFree() async throws {
        let service = EntitlementService(defaults: defaults)
        let products = try await loadProducts(service)
        let monthly = try XCTUnwrap(products.first { $0.id == StoreProduct.proMonthly })
        try await service.purchase(monthly)
        XCTAssertEqual(service.snapshot.tier, .pro)

        try expireWithoutRenewal(StoreProduct.proMonthly)
        try await waitForTier(.free, in: service, refreshing: true)
    }

    func testFailedPurchaseLeavesTheTierAlone() async throws {
        let service = EntitlementService(defaults: defaults)
        let products = try await loadProducts(service)
        let core = try XCTUnwrap(products.first { $0.id == StoreProduct.core })
        session.failTransactionsEnabled = true
        session.failureError = .unknown

        do {
            let purchased = try await service.purchase(core)
            XCTAssertFalse(purchased)
        } catch {
            // A thrown error is what the paywall turns into an alert.
        }
        XCTAssertEqual(service.snapshot.tier, .free)

        session.failTransactionsEnabled = false
        let retried = try await service.purchase(core)
        XCTAssertTrue(retried)
        XCTAssertEqual(service.snapshot.tier, .core)
    }

    func testAskToBuyUnlocksOnlyAfterApproval() async throws {
        let service = EntitlementService(defaults: defaults)
        let products = try await loadProducts(service)
        let core = try XCTUnwrap(products.first { $0.id == StoreProduct.core })
        service.start()
        session.askToBuyEnabled = true

        let purchased = try await service.purchase(core)
        XCTAssertFalse(purchased)
        XCTAssertEqual(service.snapshot.tier, .free)

        let pending = try XCTUnwrap(session.allTransactions().first)
        try session.approveAskToBuyTransaction(identifier: pending.identifier)
        try await waitForTier(.core, in: service, refreshing: true)
    }

    func testPurchaseMadeOutsideTheAppArrivesThroughUpdates() async throws {
        try await requireLocalStore()
        let service = EntitlementService(defaults: defaults)
        service.start()
        try await session.buyProduct(identifier: StoreProduct.proMonthly)
        try await waitForTier(.pro, in: service)
    }

    func testPaywallPurchaseButtonBuysTheSelectedPlan() async throws {
        try await requireLocalStore()
        let service = EntitlementService(defaults: defaults)
        // The deck limit paywall preselects Core.
        let paywall = PaywallViewController(context: .deckLimit, entitlements: service)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.rootViewController = paywall
        window.makeKeyAndVisible()

        let purchaseButton = try await waitForPurchaseButton(in: paywall)
        let button = try XCTUnwrap(purchaseButton as? UIControl)
        button.sendActions(for: .touchUpInside)
        try await waitForTier(.core, in: service)
        XCTAssertEqual(Set(session.allTransactions().map(\.productIdentifier)), [StoreProduct.core])
    }

    func testPaywallRestoreButtonRestores() async throws {
        try await requireLocalStore()
        try await session.buyProduct(identifier: StoreProduct.core)
        let service = EntitlementService(defaults: defaults)
        let paywall = PaywallViewController(context: .deckLimit, entitlements: service)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.rootViewController = paywall
        window.makeKeyAndVisible()
        _ = try await waitForPurchaseButton(in: paywall)

        let restore = try XCTUnwrap(findButton(in: paywall.view, title: FlashForgeStrings.Paywall.restore))
        restore.sendActions(for: .touchUpInside)
        try await waitForTier(.core, in: service)
    }

    func testPaywallRendersPlans() async throws {
        try await requireLocalStore()
        let service = EntitlementService(defaults: defaults)
        let paywall = PaywallViewController(context: .deckLimit, entitlements: service)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.rootViewController = paywall
        window.makeKeyAndVisible()

        let button = try? await waitForPurchaseButton(in: paywall)

        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        if let path = ProcessInfo.processInfo.environment["PAYWALL_SNAPSHOT_PATH"], let data = image.pngData() {
            try data.write(to: URL(fileURLWithPath: path))
        }
        try XCTSkipIf(button == nil, "Local StoreKit test environment is not available")
    }

    private func waitForPurchaseButton(in controller: UIViewController) async throws -> UIView {
        for _ in 0 ..< 30 {
            if let button = findView(in: controller.view, identifier: "paywall.purchaseButton"), !button.isHidden {
                return button
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        throw XCTSkip("Local StoreKit test environment is not available")
    }

    // Left renewing, the test store answers an expiry with a renewal.
    private func expireWithoutRenewal(_ productID: String) throws {
        let transaction = try XCTUnwrap(session.allTransactions().last { $0.productIdentifier == productID })
        try session.disableAutoRenewForTransaction(identifier: transaction.identifier)
        try session.expireSubscription(productIdentifier: productID)
    }

    // The store applies refunds and expirations a moment after the call
    // returns, so those tests re-read the entitlements until it has.
    private func waitForTier(
        _ tier: AccessTier,
        in service: EntitlementService,
        refreshing: Bool = false
    ) async throws {
        for _ in 0 ..< 50 {
            if refreshing {
                await service.refresh()
            }
            if service.snapshot.tier == tier {
                return
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTFail("Expected \(tier), still \(service.snapshot.tier)")
    }

    private func findButton(in view: UIView, title: String) -> UIButton? {
        if let button = view as? UIButton,
           (button.configuration?.title ?? button.attributedTitle(for: .normal)?.string ?? button.title(for: .normal)) == title {
            return button
        }
        for subview in view.subviews {
            if let match = findButton(in: subview, title: title) {
                return match
            }
        }
        return nil
    }

    private func findView(in view: UIView, identifier: String) -> UIView? {
        if view.accessibilityIdentifier == identifier {
            return view
        }
        for subview in view.subviews {
            if let match = findView(in: subview, identifier: identifier) {
                return match
            }
        }
        return nil
    }
}
