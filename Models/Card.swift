//
//  Card.swift
//  FlashForge
//
//  Created by bbdyno on 2/11/26.
//

import Foundation

enum CardState: String, Codable, Sendable {
    case new
    case learning
    case review
    case relearning
}

enum UserGrade: Int, CaseIterable, Codable, Sendable {
    case again = 1
    case hard = 2
    case good = 3
    case easy = 4
}

struct FSRSReviewState: Sendable, Identifiable, Codable {
    let id: UUID
    var stability: Double
    var difficulty: Double
    var reps: Int
    var scheduledDays: Int
    var lastReview: Date

    init(
        id: UUID,
        stability: Double = 0.4,
        difficulty: Double = 5.0,
        reps: Int = 0,
        scheduledDays: Int = 0,
        lastReview: Date = .now
    ) {
        self.id = id
        self.stability = stability
        self.difficulty = difficulty
        self.reps = reps
        self.scheduledDays = scheduledDays
        self.lastReview = lastReview
    }
}

struct ReviewLogEntry: Sendable, Hashable, Codable {
    let date: Date
    let grade: UserGrade
    let stateBefore: CardState
    let elapsedDays: Int
    let scheduledDays: Int
}

struct Card: Sendable, Identifiable, Codable {
    let id: UUID
    var state: CardState
    var stepIndex: Int?
    var easeFactor: Double
    var interval: Int
    var dueDate: Date
    var reviewHistory: [Date]
    // Graded log, recorded from 2.0 onward. Older reviews exist only as dates in
    // `reviewHistory`, so this can be shorter than the history.
    var reviewLog: [ReviewLogEntry]
    var fsrsState: FSRSReviewState?

    init(
        id: UUID = UUID(),
        state: CardState = .new,
        stepIndex: Int? = nil,
        easeFactor: Double = 2.5,
        interval: Int = 0,
        dueDate: Date = Date(),
        reviewHistory: [Date] = [],
        reviewLog: [ReviewLogEntry] = [],
        fsrsState: FSRSReviewState? = nil
    ) {
        self.id = id
        self.state = state
        self.stepIndex = stepIndex
        self.easeFactor = easeFactor
        self.interval = interval
        self.dueDate = dueDate
        self.reviewHistory = reviewHistory
        self.reviewLog = reviewLog
        self.fsrsState = fsrsState
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        state = try container.decode(CardState.self, forKey: .state)
        stepIndex = try container.decodeIfPresent(Int.self, forKey: .stepIndex)
        easeFactor = try container.decode(Double.self, forKey: .easeFactor)
        interval = try container.decode(Int.self, forKey: .interval)
        dueDate = try container.decode(Date.self, forKey: .dueDate)
        reviewHistory = try container.decode([Date].self, forKey: .reviewHistory)
        reviewLog = try container.decodeIfPresent([ReviewLogEntry].self, forKey: .reviewLog) ?? []
        fsrsState = try container.decodeIfPresent(FSRSReviewState.self, forKey: .fsrsState)
    }
}
