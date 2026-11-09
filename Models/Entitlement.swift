//
//  Entitlement.swift
//  FlashForge
//

import Foundation

// FlashForge is a paid download. Everyone who paid for it gets every feature.
// The only people on the free tier are those whose first download fell in the
// stretch when 2.0 was free; they keep its limits until they buy the unlock.
enum AccessTier: Int, Comparable, Codable, Sendable {
    case free
    case full

    static func < (lhs: AccessTier, rhs: AccessTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    // 2.0 stored three tiers (free, core, pro). Anything above free was paid
    // for, so it reads back as full.
    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(Int.self)
        self = rawValue > 0 ? .full : .free
    }

    static func resolve(ownedProductIDs: Set<String>, ownsPaidDownload: Bool) -> AccessTier {
        if ownsPaidDownload || !ownedProductIDs.isDisjoint(with: StoreProduct.unlockingIDs) {
            return .full
        }
        return .free
    }
}

enum StoreProduct {
    // The one-time "Core" purchase from 2.0, now sold as the full unlock. The
    // ID stays so people who bought Core keep what they paid for.
    static let unlock = "com.bbdyno.app.flashFlow.core"

    // The 2.0 Pro subscriptions are no longer sold. A subscription that is
    // still running keeps the app unlocked until it ends.
    static let retiredSubscriptionIDs: Set<String> = [
        "com.bbdyno.app.flashFlow.pro.monthly",
        "com.bbdyno.app.flashFlow.pro.yearly"
    ]

    static let unlockingIDs: Set<String> = retiredSubscriptionIDs.union([unlock])
}

struct EntitlementSnapshot: Equatable, Codable, Sendable {
    var tier: AccessTier
    var ownsPaidDownload: Bool

    static let free = EntitlementSnapshot(tier: .free, ownsPaidDownload: false)

    // The key is the one 2.0 used for 1.x buyers, which is the same answer:
    // they paid for the download.
    private enum CodingKeys: String, CodingKey {
        case tier
        case ownsPaidDownload = "isLegacyPurchaser"
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
        tier == .full || existingDeckCount < FreeTierLimits.maxDecks
    }

    static func canAddCard(existingCardCount: Int, tier: AccessTier) -> Bool {
        tier == .full || existingCardCount < FreeTierLimits.maxCardsPerDeck
    }
}

enum PaidDownloadPolicy {
    static let lastPaidBuildInfoKey = "FFLastPaidBuild"
    static let paidAgainSinceInfoKey = "FFPaidAgainSince"

    // A download was paid for if it is a 1.x build (the first download was
    // this build or older) or if it happened once the price came back.
    //
    // The return to paid is a date, not a build: the App Store keeps serving
    // the newest build across a price change, so a build number cannot tell a
    // free download of it from a paid one.
    static func ownsPaidDownload(
        originalAppVersion: String,
        originalPurchaseDate: Date,
        lastPaidBuild: String,
        paidAgainSince: Date?
    ) -> Bool {
        if isAtOrBefore(originalAppVersion, lastPaidBuild) {
            return true
        }
        guard let paidAgainSince else {
            return false
        }
        return originalPurchaseDate >= paidAgainSince
    }

    // "2026-11-16" is the day the price change takes effect. It is read as the
    // first moment that day exists anywhere (UTC+14), so a paid download is
    // never mistaken for a free one; at worst someone who downloaded late on
    // the last free day gets the unlock.
    static func paidAgainSince(from string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 14 * 3600)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter.date(from: string)
    }

    // `AppTransaction.originalAppVersion` is the CFBundleVersion of the build
    // the customer first downloaded, so this compares build numbers
    // ("2026.08.18.1"), not marketing versions.
    static func isAtOrBefore(_ version: String, _ reference: String) -> Bool {
        guard let lhsParts = components(of: version),
              let rhsParts = components(of: reference)
        else {
            return false
        }

        let count = max(lhsParts.count, rhsParts.count)
        for index in 0 ..< count {
            let lhs = index < lhsParts.count ? lhsParts[index] : 0
            let rhs = index < rhsParts.count ? rhsParts[index] : 0
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
