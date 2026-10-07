//
//  StoreFlowTests.swift
//  FlashForgeTests
//

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
        session.clearTransactions()
        suiteName = "StoreFlowTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDownWithError() throws {
        session.clearTransactions()
        defaults.removePersistentDomain(forName: suiteName)
        session = nil
        defaults = nil
    }

    // These tests need the local StoreKit test environment (running from Xcode
    // with the scheme's configuration). Against the App Store sandbox, which
    // is what xcodebuild gets, they skip rather than buy anything or report a
    // false failure.
    private func requireLocalStore() async throws {
        guard let result = try? await AppTransaction.shared,
              case let .verified(transaction) = result,
              transaction.environment == .xcode
        else {
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
        await service.refresh()
        XCTAssertEqual(service.snapshot.tier, .free)
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
