//
//  InsightsSnapshot.swift
//  FlashForge
//

import Foundation

struct CardStateCounts: Equatable, Sendable {
    let new: Int
    let learning: Int
    let review: Int
    let relearning: Int

    var total: Int {
        new + learning + review + relearning
    }
}

struct DueForecastDay: Equatable, Sendable {
    let date: Date
    let count: Int
}

struct InsightsSnapshot: Equatable, Sendable {
    let deckCount: Int
    let cardCount: Int
    let dueNowCount: Int
    let reviewedTodayCount: Int
    let reviewedLastSevenDaysCount: Int
    let currentStreakDays: Int
    let estimatedRetention: Double?
    let stateCounts: CardStateCounts
    let reviewCountByDate: [Date: Int]
    let dueForecast: [DueForecastDay]
}
