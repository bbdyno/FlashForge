//
//  FSRSParameters.swift
//  FlashForge
//
//  Created by bbdyno on 2/11/26.
//

import Foundation

struct FSRSParameters: Sendable, Codable, Equatable {
    static let defaultWeights: [Double] = [
        0.4, 0.6, 2.4, 5.8, 4.93, 0.94, 0.86, 0.01, 1.49, 0.14, 0.94, 2.18, 0.05, 0.34, 1.26, 0.29, 2.61
    ]
    static let defaultRetention = 0.9
    static let retentionRange: ClosedRange<Double> = 0.7...0.97

    let w: [Double]
    let requestRetention: Double

    init(
        w: [Double] = FSRSParameters.defaultWeights,
        requestRetention: Double = FSRSParameters.defaultRetention
    ) {
        self.w = w
        self.requestRetention = requestRetention
    }
}

extension FSRSParameters {
    static let `default` = FSRSParameters()
}

// What Pro personalisation has learned for this library. It travels with
// backups and iCloud snapshots.
struct FSRSProfile: Sendable, Codable, Equatable {
    var parameters: FSRSParameters
    var optimizedAt: Date?
    var trainedReviewCount: Int
    var baselineLoss: Double?
    var optimizedLoss: Double?

    static let `default` = FSRSProfile(
        parameters: .default,
        optimizedAt: nil,
        trainedReviewCount: 0,
        baselineLoss: nil,
        optimizedLoss: nil
    )
}

struct FSRSPersonalizationStatus: Sendable, Equatable {
    let profile: FSRSProfile
    let usableReviewCount: Int

    var hasEnoughReviews: Bool {
        usableReviewCount >= FSRSOptimizer.minimumReviewCount
    }
}
