//
//  EntitlementService.swift
//  FlashForge
//

import Foundation
import StoreKit

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

        // Having bought the app is permanent, so a failed lookup (offline,
        // signed out) keeps the cached answer instead of locking the app.
        let ownsPaidDownload = await resolvePaidDownload() ?? snapshot.ownsPaidDownload
        apply(
            EntitlementSnapshot(
                tier: .resolve(ownedProductIDs: ownedProductIDs, ownsPaidDownload: ownsPaidDownload),
                ownsPaidDownload: ownsPaidDownload
            )
        )
    }

    func products() async throws -> [Product] {
        try await Product.products(for: [StoreProduct.unlock])
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

    private func resolvePaidDownload() async -> Bool? {
        guard let lastPaidBuild = Bundle.main.object(
            forInfoDictionaryKey: PaidDownloadPolicy.lastPaidBuildInfoKey
        ) as? String else {
            return false
        }
        let paidAgainSince = (Bundle.main.object(
            forInfoDictionaryKey: PaidDownloadPolicy.paidAgainSinceInfoKey
        ) as? String).flatMap(PaidDownloadPolicy.paidAgainSince(from:))
        guard let result = try? await AppTransaction.shared,
              case let .verified(appTransaction) = result
        else {
            return nil
        }
        // Sandbox and TestFlight report "1.0" as the original version and a
        // download date that means nothing, so testers always see the free
        // tier and can try the unlock.
        guard appTransaction.environment == .production else {
            return false
        }
        return PaidDownloadPolicy.ownsPaidDownload(
            originalAppVersion: appTransaction.originalAppVersion,
            originalPurchaseDate: appTransaction.originalPurchaseDate,
            lastPaidBuild: lastPaidBuild,
            paidAgainSince: paidAgainSince
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
