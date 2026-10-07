//
//  EntitlementService.swift
//  FlashForge
//

import StoreKit
import UIKit

@MainActor
final class EntitlementService {
    static let shared = EntitlementService()

    private enum Key {
        static let snapshot = "entitlement.snapshot"
    }

    private(set) var snapshot: EntitlementSnapshot
    private let defaults: UserDefaults
    private let notificationCenter: NotificationCenter
    private var updatesTask: Task<Void, Never>?

    init(
        defaults: UserDefaults = .standard,
        notificationCenter: NotificationCenter = .default
    ) {
        self.defaults = defaults
        self.notificationCenter = notificationCenter
        // Start from the last known state so a returning customer never sees
        // the free tier flash while StoreKit is still answering.
        if let data = defaults.data(forKey: Key.snapshot),
           let cached = try? JSONDecoder().decode(EntitlementSnapshot.self, from: data) {
            snapshot = cached
        } else {
            snapshot = .free
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func start() {
        guard updatesTask == nil else {
            return
        }
        updatesTask = Task { [weak self] in
            await self?.refresh()
            for await update in Transaction.updates {
                if case let .verified(transaction) = update {
                    await transaction.finish()
                }
                await self?.refresh()
            }
        }
    }

    func refresh() async {
        var ownedProductIDs = Set<String>()
        for await entitlement in Transaction.currentEntitlements {
            guard case let .verified(transaction) = entitlement,
                  transaction.revocationDate == nil
            else {
                continue
            }
            ownedProductIDs.insert(transaction.productID)
        }

        // Having bought the paid app is permanent, so a failed lookup (offline,
        // signed out) keeps the cached answer instead of revoking Core.
        let isLegacyPurchaser = await resolveLegacyPurchase() ?? snapshot.isLegacyPurchaser
        apply(
            EntitlementSnapshot(
                tier: .resolve(ownedProductIDs: ownedProductIDs, isLegacyPurchaser: isLegacyPurchaser),
                isLegacyPurchaser: isLegacyPurchaser
            )
        )
    }

    func products() async throws -> [Product] {
        try await Product.products(for: StoreProduct.allIDs)
    }

    @discardableResult
    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        guard case let .success(verification) = result,
              case let .verified(transaction) = verification
        else {
            return false
        }
        await transaction.finish()
        await refresh()
        return true
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
        await refresh()
    }

    func presentLegacyOfferRedemption(in scene: UIWindowScene) async throws {
        try await AppStore.presentOfferCodeRedeemSheet(in: scene)
        await refresh()
    }

    private func resolveLegacyPurchase() async -> Bool? {
        guard let lastPaidBuild = Bundle.main.object(
            forInfoDictionaryKey: LegacyPurchasePolicy.lastPaidBuildInfoKey
        ) as? String else {
            return false
        }
        guard let result = try? await AppTransaction.shared,
              case let .verified(appTransaction) = result
        else {
            return nil
        }
        // Sandbox and TestFlight always report "1.0" as the original version,
        // which would make every tester a legacy buyer.
        guard appTransaction.environment == .production else {
            return false
        }
        return LegacyPurchasePolicy.isLegacyPurchaser(
            originalAppVersion: appTransaction.originalAppVersion,
            lastPaidBuild: lastPaidBuild
        )
    }

    private func apply(_ next: EntitlementSnapshot) {
        guard next != snapshot else {
            return
        }
        snapshot = next
        if let data = try? JSONEncoder().encode(next) {
            defaults.set(data, forKey: Key.snapshot)
        }
        notificationCenter.post(name: .entitlementDidChange, object: nil)
    }
}
