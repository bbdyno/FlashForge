//
//  PersistenceModels.swift
//  FlashForge
//
//  Created by bbdyno on 2/12/26.
//

import Foundation
import SwiftData

@Model
final class DeckEntity {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var cards: [CardEntryEntity]

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = .now,
        cards: [CardEntryEntity] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.cards = cards
    }
}

@Model
final class CardEntryEntity {
    @Attribute(.unique) var id: UUID

    var contentID: UUID
    var contentTitle: String
    var contentSubtitle: String
    var contentDetail: String
    var contentImageName: String

    var scheduleStateRaw: String
    var scheduleStepIndex: Int?
    var scheduleEaseFactor: Double
    var scheduleInterval: Int
    var scheduleDueDate: Date
    var scheduleReviewHistoryData: Data
    var scheduleFSRSStateData: Data?
    var scheduleReviewLogData: Data?

    var deck: DeckEntity?

    init(
        id: UUID,
        contentID: UUID,
        contentTitle: String,
        contentSubtitle: String,
        contentDetail: String,
        contentImageName: String,
        scheduleStateRaw: String,
        scheduleStepIndex: Int?,
        scheduleEaseFactor: Double,
        scheduleInterval: Int,
        scheduleDueDate: Date,
        scheduleReviewHistoryData: Data,
        scheduleFSRSStateData: Data?,
        scheduleReviewLogData: Data? = nil,
        deck: DeckEntity? = nil
    ) {
        self.id = id
        self.contentID = contentID
        self.contentTitle = contentTitle
        self.contentSubtitle = contentSubtitle
        self.contentDetail = contentDetail
        self.contentImageName = contentImageName
        self.scheduleStateRaw = scheduleStateRaw
        self.scheduleStepIndex = scheduleStepIndex
        self.scheduleEaseFactor = scheduleEaseFactor
        self.scheduleInterval = scheduleInterval
        self.scheduleDueDate = scheduleDueDate
        self.scheduleReviewHistoryData = scheduleReviewHistoryData
        self.scheduleFSRSStateData = scheduleFSRSStateData
        self.scheduleReviewLogData = scheduleReviewLogData
        self.deck = deck
    }
}

@Model
final class AppSettingsEntity {
    @Attribute(.unique) var key: String
    var schedulerModeRaw: String
    var fsrsProfileData: Data?

    init(key: String, schedulerModeRaw: String, fsrsProfileData: Data? = nil) {
        self.key = key
        self.schedulerModeRaw = schedulerModeRaw
        self.fsrsProfileData = fsrsProfileData
    }
}
