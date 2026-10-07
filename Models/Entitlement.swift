//
//  Entitlement.swift
//  FlashForge
//

import Foundation

enum AccessTier: Int, Comparable, Codable, Sendable {
    case free
    case core
    case pro

    static func < (lhs: AccessTier, rhs: AccessTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    // Pro always includes Core. Buyers of the paid app (1.x) own Core without a
    // StoreKit transaction for it.
    static func resolve(ownedProductIDs: Set<String>, isLegacyPurchaser: Bool) -> AccessTier {
        if !ownedProductIDs.isDisjoint(with: StoreProduct.proIDs) {
            return .pro
        }
        if isLegacyPurchaser || ownedProductIDs.contains(StoreProduct.core) {
            return .core
        }
        return .free
    }
}

enum StoreProduct {
    static let core = "com.bbdyno.app.flashFlow.core"
    static let proMonthly = "com.bbdyno.app.flashFlow.pro.monthly"
    static let proYearly = "com.bbdyno.app.flashFlow.pro.yearly"

    static let proIDs: Set<String> = [proMonthly, proYearly]
    static let allIDs: Set<String> = proIDs.union([core])
}

struct EntitlementSnapshot: Equatable, Codable, Sendable {
    var tier: AccessTier
    var isLegacyPurchaser: Bool

    static let free = EntitlementSnapshot(tier: .free, isLegacyPurchaser: false)

    // The first-year Pro discount for 1.x buyers is an App Store offer code;
    // the App Store itself rejects it for anyone who has subscribed before.
    var showsLegacyProOffer: Bool {
        isLegacyPurchaser && tier < .pro
    }
}

enum FreeTierLimits {
    static let maxDecks = 3
    static let maxCardsPerDeck = 50
}

// Limits only ever block creating something new. Content that already exists
// (restored from a backup, synced, or made before a downgrade) stays usable.
enum FeatureGate {
    static func canCreateDeck(existingDeckCount: Int, tier: AccessTier) -> Bool {
        tier >= .core || existingDeckCount < FreeTierLimits.maxDecks
    }

    static func canAddCard(existingCardCount: Int, tier: AccessTier) -> Bool {
        tier >= .core || existingCardCount < FreeTierLimits.maxCardsPerDeck
    }
}

enum LegacyPurchasePolicy {
    static let lastPaidBuildInfoKey = "FFLastPaidBuild"

    // `AppTransaction.originalAppVersion` is the CFBundleVersion of the build
    // the customer first downloaded, so this compares build numbers
    // ("2026.08.18.1"), not marketing versions.
    static func isLegacyPurchaser(originalAppVersion: String, lastPaidBuild: String) -> Bool {
        guard let original = components(of: originalAppVersion),
              let lastPaid = components(of: lastPaidBuild)
        else {
            return false
        }

        let count = max(original.count, lastPaid.count)
        for index in 0 ..< count {
            let lhs = index < original.count ? original[index] : 0
            let rhs = index < lastPaid.count ? lastPaid[index] : 0
            if lhs != rhs {
                return lhs < rhs
            }
        }
        return true
    }

    private static func components(of version: String) -> [Int]? {
        let parts = version.split(separator: ".", omittingEmptySubsequences: false)
        guard !parts.isEmpty else {
            return nil
        }
        let numbers = parts.compactMap { Int($0) }
        return numbers.count == parts.count ? numbers : nil
    }
}
