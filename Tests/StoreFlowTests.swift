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
    private var retainedWindow: UIWindow?

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
        retainedWindow = nil
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

    func testTheUnlockIsTheOnlyProductOnSale() async throws {
        let service = EntitlementService(defaults: defaults)
        let products = try await loadProducts(service)
        XCTAssertEqual(products.map(\.id), [StoreProduct.unlock])
        XCTAssertEqual(products.first?.type, .nonConsumable)
    }

    func testBuyingTheUnlockOpensEverything() async throws {
        let service = EntitlementService(defaults: defaults)
        let products = try await loadProducts(service)
        await service.refresh()
        XCTAssertEqual(service.snapshot.tier, .free)

        let unlock = try XCTUnwrap(products.first)
        let purchased = try await service.purchase(unlock)
        XCTAssertTrue(purchased)
        XCTAssertEqual(service.snapshot.tier, .full)

        // A fresh launch starts from the cached tier instead of free.
        XCTAssertEqual(EntitlementService(defaults: defaults).snapshot.tier, .full)
    }

    func testRefundingTheUnlockDropsBackToFree() async throws {
        let service = EntitlementService(defaults: defaults)
        let products = try await loadProducts(service)
        try await service.purchase(try XCTUnwrap(products.first))
        XCTAssertEqual(service.snapshot.tier, .full)

        let transaction = try XCTUnwrap(session.allTransactions().first)
        try session.refundTransaction(identifier: transaction.identifier)
        try await waitForTier(.free, in: service, refreshing: true)
    }

    func testRestoreRecoversTheUnlockOnAFreshInstall() async throws {
        try await requireLocalStore()
        try await session.buyProduct(identifier: StoreProduct.unlock)

        // Nothing cached, as after a reinstall or on a second device.
        let service = EntitlementService(defaults: defaults)
        XCTAssertEqual(service.snapshot.tier, .free)
        try await service.restorePurchases()
        XCTAssertEqual(service.snapshot.tier, .full)
    }

    func testRestoreWithNothingBoughtStaysFree() async throws {
        try await requireLocalStore()
        let service = EntitlementService(defaults: defaults)
        try await service.restorePurchases()
        XCTAssertEqual(service.snapshot.tier, .free)
    }

    func testFailedPurchaseLeavesTheTierAlone() async throws {
        let service = EntitlementService(defaults: defaults)
        let products = try await loadProducts(service)
        let unlock = try XCTUnwrap(products.first)
        session.failTransactionsEnabled = true
        session.failureError = .unknown

        do {
            let purchased = try await service.purchase(unlock)
            XCTAssertFalse(purchased)
        } catch {
            // A thrown error is what the paywall turns into an alert.
        }
        XCTAssertEqual(service.snapshot.tier, .free)

        session.failTransactionsEnabled = false
        let retried = try await service.purchase(unlock)
        XCTAssertTrue(retried)
        XCTAssertEqual(service.snapshot.tier, .full)
    }

    func testAskToBuyUnlocksOnlyAfterApproval() async throws {
        let service = EntitlementService(defaults: defaults)
        let products = try await loadProducts(service)
        let unlock = try XCTUnwrap(products.first)
        service.start()
        session.askToBuyEnabled = true

        let purchased = try await service.purchase(unlock)
        XCTAssertFalse(purchased)
        XCTAssertEqual(service.snapshot.tier, .free)

        let pending = try XCTUnwrap(session.allTransactions().first)
        try session.approveAskToBuyTransaction(identifier: pending.identifier)
        try await waitForTier(.full, in: service, refreshing: true)
    }

    func testPurchaseMadeOutsideTheAppArrivesThroughUpdates() async throws {
        try await requireLocalStore()
        let service = EntitlementService(defaults: defaults)
        service.start()
        try await session.buyProduct(identifier: StoreProduct.unlock)
        try await waitForTier(.full, in: service)
    }

    func testPaywallPurchaseButtonBuysTheUnlock() async throws {
        try await requireLocalStore()
        let service = EntitlementService(defaults: defaults)
        let paywall = try await presentedPaywall(context: .deckLimit, service: service)

        let purchaseButton = try await waitForPurchaseButton(in: paywall)
        let button = try XCTUnwrap(purchaseButton as? UIControl)
        button.sendActions(for: .touchUpInside)
        try await waitForTier(.full, in: service)
        XCTAssertEqual(Set(session.allTransactions().map(\.productIdentifier)), [StoreProduct.unlock])
    }

    func testPaywallRestoreButtonRestores() async throws {
        try await requireLocalStore()
        try await session.buyProduct(identifier: StoreProduct.unlock)
        let service = EntitlementService(defaults: defaults)
        let paywall = try await presentedPaywall(context: .lockedFeature, service: service)

        let restore = try XCTUnwrap(findButton(in: paywall.view, title: FlashForgeStrings.Paywall.restore))
        restore.sendActions(for: .touchUpInside)
        try await waitForTier(.full, in: service)
    }

    func testPaywallRestoreSaysWhenThereIsNothingToRestore() async throws {
        try await requireLocalStore()
        let service = EntitlementService(defaults: defaults)
        let paywall = try await presentedPaywall(context: .deckLimit, service: service)

        let restore = try XCTUnwrap(findButton(in: paywall.view, title: FlashForgeStrings.Paywall.restore))
        restore.sendActions(for: .touchUpInside)
        let alert = try await waitForAlert(over: paywall)
        XCTAssertEqual(alert.title, FlashForgeStrings.Paywall.Restore.Empty.title)
        XCTAssertEqual(service.snapshot.tier, .free)
    }

    func testPaywallRendersTheOffer() async throws {
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

    // The store applies refunds and approvals a moment after the call
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

    private func presentedPaywall(
        context: PaywallViewController.Context,
        service: EntitlementService
    ) async throws -> PaywallViewController {
        let paywall = PaywallViewController(context: context, entitlements: service)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.rootViewController = paywall
        window.makeKeyAndVisible()
        retainedWindow = window
        _ = try await waitForPurchaseButton(in: paywall)
        return paywall
    }

    private func waitForAlert(over controller: UIViewController) async throws -> UIAlertController {
        for _ in 0 ..< 50 {
            if let alert = controller.presentedViewController as? UIAlertController {
                return alert
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTFail("No alert was presented")
        throw CancellationError()
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
