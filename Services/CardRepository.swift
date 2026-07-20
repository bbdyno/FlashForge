//
//  n.swift
//  FlashForge
//
//  Created by bbdyno on 2/11/26.
//

import Foundation
import SwiftData

// swiftlint:disable file_length
actor CardRepository {
    enum RepositoryError: LocalizedError, Sendable {
        case invalidTitle
        case invalidCardContent
        case deckNotFound
        case cardNotFound
        case persistenceFailed
        case invalidBackupFile
        case invalidDeckImportFile

        var errorDescription: String? {
            switch self {
            case .invalidTitle:
                return FlashForgeStrings.Repository.Error.invalidTitle
            case .invalidCardContent:
                return FlashForgeStrings.Repository.Error.invalidCardContent
            case .deckNotFound:
                return FlashForgeStrings.Repository.Error.deckNotFound
            case .cardNotFound:
                return FlashForgeStrings.Repository.Error.cardNotFound
            case .persistenceFailed:
                return FlashForgeStrings.Repository.Error.persistenceFailed
            case .invalidBackupFile:
                return FlashForgeStrings.Repository.Error.invalidBackupFile
            case .invalidDeckImportFile:
                return FlashForgeStrings.Repository.Error.invalidDeckImportFile
            }
        }
    }

    private struct PersistedStore: Codable, Sendable {
        var decks: [Deck]
        var schedulerMode: SchedulerMode

        init(
            decks: [Deck] = [],
            schedulerMode: SchedulerMode = .fsrs
        ) {
            self.decks = decks
            self.schedulerMode = schedulerMode
        }

        private enum CodingKeys: String, CodingKey {
            case decks
            case schedulerMode
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            decks = try container.decodeIfPresent([Deck].self, forKey: .decks) ?? []
            schedulerMode = try container.decodeIfPresent(SchedulerMode.self, forKey: .schedulerMode) ?? .fsrs
        }
    }

    private struct ImportedDeckPayload: Decodable, Sendable {
        struct ImportedCardPayload: Decodable, Sendable {
            let front: String
            let back: String
            let note: String

            private enum CodingKeys: String, CodingKey {
                case front
                case back
                case note
                case question
                case answer
                case hint
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let front = try container.decodeIfPresent(String.self, forKey: .front)
                    ?? container.decodeIfPresent(String.self, forKey: .question)
                let back = try container.decodeIfPresent(String.self, forKey: .back)
                    ?? container.decodeIfPresent(String.self, forKey: .answer)
                let note = try container.decodeIfPresent(String.self, forKey: .note)
                    ?? container.decodeIfPresent(String.self, forKey: .hint)
                    ?? ""

                guard let front, let back else {
                    throw RepositoryError.invalidDeckImportFile
                }

                self.front = front
                self.back = back
                self.note = note
            }
        }

        let title: String
        let cards: [ImportedCardPayload]

        private enum CodingKeys: String, CodingKey {
            case title
            case deckTitle
            case name
            case cards
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let title = try container.decodeIfPresent(String.self, forKey: .title)
                ?? container.decodeIfPresent(String.self, forKey: .deckTitle)
                ?? container.decodeIfPresent(String.self, forKey: .name)
            guard let title else {
                throw RepositoryError.invalidDeckImportFile
            }

            self.title = title
            self.cards = try container.decode([ImportedCardPayload].self, forKey: .cards)
        }
    }

    private static let settingsKey = "main"

    private var hasPrepared = false
    private var container: ModelContainer?

    private let sm2Scheduler: SM2Scheduler
    private let fsrsScheduler: FSRSScheduler
    private let calendar: Calendar
    private let fileManager: FileManager
    private let appSupportDirectoryOverride: URL?
    private let backupDecoder: JSONDecoder
    private let backupEncoder: JSONEncoder
    private let payloadDecoder: JSONDecoder
    private let payloadEncoder: JSONEncoder

    init(
        sm2Scheduler: SM2Scheduler = SM2Scheduler(),
        fsrsScheduler: FSRSScheduler = FSRSScheduler(parameters: .default),
        calendar: Calendar = .current,
        fileManager: FileManager = .default,
        appSupportDirectoryOverride: URL? = nil
    ) {
        self.sm2Scheduler = sm2Scheduler
        self.fsrsScheduler = fsrsScheduler
        self.calendar = calendar
        self.fileManager = fileManager
        self.appSupportDirectoryOverride = appSupportDirectoryOverride

        self.backupDecoder = JSONDecoder()
        self.backupDecoder.dateDecodingStrategy = .iso8601

        self.backupEncoder = JSONEncoder()
        self.backupEncoder.dateEncodingStrategy = .iso8601
        self.backupEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        self.payloadDecoder = JSONDecoder()
        self.payloadDecoder.dateDecodingStrategy = .iso8601

        self.payloadEncoder = JSONEncoder()
        self.payloadEncoder.dateEncodingStrategy = .iso8601
    }

    func prepare() throws {
        try ensurePrepared()
    }

    func hasAnyDecks() throws -> Bool {
        try ensurePrepared()
        let context = try makeContext()
        return try !fetchDecks(context: context).isEmpty
    }

    func schedulerMode() throws -> SchedulerMode {
        try ensurePrepared()
        let context = try makeContext()
        let settings = try fetchSettings(context: context)
        guard let settings else {
            return .fsrs
        }
        return SchedulerMode(rawValue: settings.schedulerModeRaw) ?? .fsrs
    }

    func updateSchedulerMode(_: SchedulerMode) throws {
        try ensurePrepared()
        let context = try makeContext()
        let settings = try fetchOrCreateSettings(context: context)
        guard settings.schedulerModeRaw != SchedulerMode.fsrs.rawValue else {
            return
        }

        settings.schedulerModeRaw = SchedulerMode.fsrs.rawValue
        try save(context: context)
    }

    func resetAllData() throws {
        try ensurePrepared()
        let context = try makeContext()
        try deleteAllData(context: context)
        context.insert(AppSettingsEntity(key: Self.settingsKey, schedulerModeRaw: SchedulerMode.fsrs.rawValue))
        try save(context: context)
    }

    func exportBackupData() throws -> Data {
        try ensurePrepared()
        let context = try makeContext()
        let store = try snapshotStore(context: context)
        do {
            return try backupEncoder.encode(store)
        } catch {
            CrashReporter.record(error: error, context: "CardRepository.exportBackupData.encode")
            throw RepositoryError.persistenceFailed
        }
    }

    func importBackupData(_ data: Data) throws {
        try ensurePrepared()
        let imported = try decodeBackupStore(data)
        let context = try makeContext()
        try replaceStore(with: imported, context: context)
    }

    func previewBackupData(_ data: Data) throws -> BackupPreview {
        let imported = try decodeBackupStore(data)
        let deckCount = imported.decks.count
        let cardCount = imported.decks.reduce(0) { $0 + $1.cards.count }
        let reviewCount = imported.decks.reduce(0) { sum, deck in
            sum + deck.cards.reduce(0) { $0 + $1.schedule.reviewHistory.count }
        }
        return BackupPreview(deckCount: deckCount, cardCount: cardCount, reviewCount: reviewCount)
    }

    @discardableResult
    func importDeckData(_ data: Data) throws -> Deck {
        try ensurePrepared()
        let payload = try decodeDeckPayload(data)

        let trimmedTitle = payload.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw RepositoryError.invalidTitle
        }

        let context = try makeContext()
        let deckEntity = DeckEntity(title: trimmedTitle)
        context.insert(deckEntity)

        for card in payload.cards {
            let normalized = try normalizedCardContent(front: card.front, back: card.back, note: card.note)
            let content = FlashCard(
                title: normalized.front,
                subtitle: normalized.note,
                detail: normalized.back,
                imageName: suggestedImageName(from: normalized.front)
            )
            let deckCard = DeckCard(content: content)
            let cardEntity = makeCardEntity(from: deckCard)
            cardEntity.deck = deckEntity
            deckEntity.cards.append(cardEntity)
        }

        try save(context: context)
        return domainDeck(from: deckEntity)
    }

    @discardableResult
    func createSampleDecksIfNeeded() throws -> Int {
        try ensurePrepared()
        let context = try makeContext()

        struct SampleCard {
            let front: String
            let back: String
            let note: String
        }

        struct SampleDeck {
            let title: String
            let cards: [SampleCard]
        }

        let samples: [SampleDeck] = [
            SampleDeck(
                title: "English Vocabulary",
                cards: [
                    SampleCard(front: "ubiquitous", back: "present or found everywhere", note: "adjective"),
                    SampleCard(front: "meticulous", back: "showing great attention to detail", note: "adjective"),
                    SampleCard(front: "mitigate", back: "to make less severe", note: "verb")
                ]
            ),
            SampleDeck(
                title: "iOS Basics",
                cards: [
                    SampleCard(front: "What is MVC?", back: "Model-View-Controller architecture pattern.", note: ""),
                    SampleCard(front: "What does Auto Layout do?", back: "It calculates view frames from constraints.", note: ""),
                    SampleCard(front: "Difference between struct and class?", back: "Struct is value type, class is reference type.", note: "Swift")
                ]
            )
        ]

        var createdDecks = 0
        var existingDecks = try fetchDecks(context: context)

        for sampleDeck in samples {
            if existingDecks.contains(where: { $0.title.caseInsensitiveCompare(sampleDeck.title) == .orderedSame }) {
                continue
            }

            let deckEntity = DeckEntity(title: sampleDeck.title)
            context.insert(deckEntity)

            for sampleCard in sampleDeck.cards {
                let content = FlashCard(
                    title: sampleCard.front,
                    subtitle: sampleCard.note,
                    detail: sampleCard.back,
                    imageName: suggestedImageName(from: sampleCard.front)
                )
                let deckCard = DeckCard(content: content)
                let cardEntity = makeCardEntity(from: deckCard)
                cardEntity.deck = deckEntity
                deckEntity.cards.append(cardEntity)
            }

            existingDecks.append(deckEntity)
            createdDecks += 1
        }

        if createdDecks > 0 {
            try save(context: context)
        }

        return createdDecks
    }

    func deckSummaries(now: Date = .now) throws -> [DeckSummary] {
        try ensurePrepared()
        let context = try makeContext()
        let decks = try fetchDecks(context: context)

        return decks.map { deckEntity in
            let deck = domainDeck(from: deckEntity)
            return DeckSummary(
                id: deck.id,
                title: deck.title,
                totalCardCount: deck.cards.count,
                dueCounts: dueCounts(for: deck, now: now)
            )
        }
        .sorted { lhs, rhs in
            lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    func createDeck(title: String) throws -> Deck {
        try ensurePrepared()

        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw RepositoryError.invalidTitle
        }

        let context = try makeContext()
        let deckEntity = DeckEntity(title: trimmed)
        context.insert(deckEntity)
        try save(context: context)
        return domainDeck(from: deckEntity)
    }

    func renameDeck(deckID: UUID, title: String) throws {
        try ensurePrepared()

        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw RepositoryError.invalidTitle
        }

        let context = try makeContext()
        guard let deckEntity = try fetchDeckEntity(deckID: deckID, context: context) else {
            throw RepositoryError.deckNotFound
        }

        deckEntity.title = trimmed
        try save(context: context)
    }

    func deleteDeck(deckID: UUID) throws {
        try ensurePrepared()
        let context = try makeContext()
        guard let deckEntity = try fetchDeckEntity(deckID: deckID, context: context) else {
            throw RepositoryError.deckNotFound
        }

        for card in deckEntity.cards {
            context.delete(card)
        }
        context.delete(deckEntity)
        try save(context: context)
    }

    func cards(in deckID: UUID) throws -> [DeckCard] {
        try ensurePrepared()
        let context = try makeContext()
        guard let deckEntity = try fetchDeckEntity(deckID: deckID, context: context) else {
            throw RepositoryError.deckNotFound
        }

        return deckEntity.cards
            .map(domainCard(from:))
            .sorted { lhs, rhs in
                lhs.content.title.localizedCaseInsensitiveCompare(rhs.content.title) == .orderedAscending
            }
    }

    func addCard(
        to deckID: UUID,
        front: String,
        back: String,
        note: String
    ) throws -> DeckCard {
        try ensurePrepared()

        let normalized = try normalizedCardContent(front: front, back: back, note: note)
        let context = try makeContext()

        guard let deckEntity = try fetchDeckEntity(deckID: deckID, context: context) else {
            throw RepositoryError.deckNotFound
        }

        let content = FlashCard(
            title: normalized.front,
            subtitle: normalized.note,
            detail: normalized.back,
            imageName: suggestedImageName(from: normalized.front)
        )
        let deckCard = DeckCard(content: content)
        let cardEntity = makeCardEntity(from: deckCard)
        cardEntity.deck = deckEntity
        deckEntity.cards.append(cardEntity)

        try save(context: context)
        return deckCard
    }

    func updateCard(
        deckID: UUID,
        cardID: UUID,
        front: String,
        back: String,
        note: String
    ) throws {
        try ensurePrepared()

        let normalized = try normalizedCardContent(front: front, back: back, note: note)
        let context = try makeContext()

        guard let deckEntity = try fetchDeckEntity(deckID: deckID, context: context) else {
            throw RepositoryError.deckNotFound
        }
        guard let cardEntity = deckEntity.cards.first(where: { $0.id == cardID }) else {
            throw RepositoryError.cardNotFound
        }

        cardEntity.contentTitle = normalized.front
        cardEntity.contentSubtitle = normalized.note
        cardEntity.contentDetail = normalized.back
        try save(context: context)
    }

    func deleteCard(deckID: UUID, cardID: UUID) throws {
        try ensurePrepared()
        let context = try makeContext()

        guard let deckEntity = try fetchDeckEntity(deckID: deckID, context: context) else {
            throw RepositoryError.deckNotFound
        }
        guard let cardEntity = deckEntity.cards.first(where: { $0.id == cardID }) else {
            throw RepositoryError.cardNotFound
        }

        if let index = deckEntity.cards.firstIndex(where: { $0.id == cardID }) {
            deckEntity.cards.remove(at: index)
        }
        context.delete(cardEntity)
        try save(context: context)
    }

    func queueDueCounts(deckID: UUID, now: Date = .now) throws -> QueueDueCounts {
        try ensurePrepared()
        let context = try makeContext()
        guard let deckEntity = try fetchDeckEntity(deckID: deckID, context: context) else {
            throw RepositoryError.deckNotFound
        }
        return dueCounts(for: domainDeck(from: deckEntity), now: now)
    }

    func reviewCountToday(deckID: UUID, now: Date = .now) throws -> Int {
        try ensurePrepared()
        let context = try makeContext()
        guard let deckEntity = try fetchDeckEntity(deckID: deckID, context: context) else {
            throw RepositoryError.deckNotFound
        }

        let deck = domainDeck(from: deckEntity)
        return deck.cards.reduce(0) { total, card in
            total + card.schedule.reviewHistory.filter { calendar.isDate($0, inSameDayAs: now) }.count
        }
    }

    func nextDueCard(deckID: UUID, queue: StudyQueue, now: Date = .now) throws -> StudyCard? {
        try ensurePrepared()
        let context = try makeContext()

        guard let deckEntity = try fetchDeckEntity(deckID: deckID, context: context) else {
            throw RepositoryError.deckNotFound
        }

        let deck = domainDeck(from: deckEntity)
        let candidates = deck.cards.filter { entry in
            entry.schedule.dueDate <= now && matches(queue: queue, state: entry.schedule.state)
        }

        guard let next = candidates.sorted(by: cardSort).first else {
            return nil
        }

        return StudyCard(
            deckID: deck.id,
            deckTitle: deck.title,
            schedule: next.schedule,
            content: next.content
        )
    }

    @discardableResult
    func review(deckID: UUID, cardID: UUID, grade: UserGrade, now: Date = .now) throws -> Card {
        try ensurePrepared()
        let context = try makeContext()

        guard let deckEntity = try fetchDeckEntity(deckID: deckID, context: context) else {
            throw RepositoryError.deckNotFound
        }
        guard let cardEntity = deckEntity.cards.first(where: { $0.id == cardID }) else {
            throw RepositoryError.cardNotFound
        }

        var card = domainCard(from: cardEntity)
        card.schedule.reviewHistory.append(now)
        card.schedule = scheduleCard(card.schedule, grade: grade, now: now)
        applySchedule(card.schedule, to: cardEntity)

        try save(context: context)
        return card.schedule
    }

    func reviewHeatmap(deckID: UUID, days: Int = 140, now: Date = .now) throws -> [Date: Int] {
        try ensurePrepared()
        let context = try makeContext()

        guard let deckEntity = try fetchDeckEntity(deckID: deckID, context: context) else {
            throw RepositoryError.deckNotFound
        }

        var summary: [Date: Int] = [:]
        for card in deckEntity.cards.map(domainCard(from:)) {
            for timestamp in card.schedule.reviewHistory {
                let date = calendar.startOfDay(for: timestamp)
                summary[date, default: 0] += 1
            }
        }

        let today = calendar.startOfDay(for: now)
        for offset in 0..<max(1, days) {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else {
                continue
            }
            summary[date, default: 0] += 0
        }
        return summary
    }

    func insightsSnapshot(
        activityDays: Int = 140,
        forecastDays: Int = 7,
        now: Date = .now
    ) throws -> InsightsSnapshot {
        try ensurePrepared()
        let context = try makeContext()
        let decks = try fetchDecks(context: context).map(domainDeck(from:))
        let cards = decks.flatMap(\.cards)
        let today = calendar.startOfDay(for: now)
        let activityDayCount = max(7, activityDays)
        let forecastDayCount = max(1, forecastDays)

        var reviewCountByDate: [Date: Int] = [:]
        cards.forEach { card in
            card.schedule.reviewHistory.forEach { timestamp in
                reviewCountByDate[calendar.startOfDay(for: timestamp), default: 0] += 1
            }
        }

        for offset in 0..<activityDayCount {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else {
                continue
            }
            reviewCountByDate[date, default: 0] += 0
        }

        let lastSevenDaysStart = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let reviewedLastSevenDaysCount = reviewCountByDate.reduce(into: 0) { result, item in
            if item.key >= lastSevenDaysStart, item.key <= today {
                result += item.value
            }
        }

        let stateCounts = CardStateCounts(
            new: cards.filter { $0.schedule.state == .new }.count,
            learning: cards.filter { $0.schedule.state == .learning }.count,
            review: cards.filter { $0.schedule.state == .review }.count,
            relearning: cards.filter { $0.schedule.state == .relearning }.count
        )

        let dueForecast = (0..<forecastDayCount).compactMap { offset -> DueForecastDay? in
            guard let dayStart = calendar.date(byAdding: .day, value: offset, to: today),
                  let nextDayStart = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                return nil
            }

            let count: Int
            if offset == 0 {
                count = cards.filter { $0.schedule.dueDate < nextDayStart }.count
            } else {
                count = cards.filter {
                    $0.schedule.dueDate >= dayStart && $0.schedule.dueDate < nextDayStart
                }.count
            }
            return DueForecastDay(date: dayStart, count: count)
        }

        let retentionValues = cards.compactMap { card -> Double? in
            guard card.schedule.state == .review,
                  let fsrsState = card.schedule.fsrsState,
                  fsrsState.stability > 0 else {
                return nil
            }
            let elapsed = max(0, now.timeIntervalSince(fsrsState.lastReview) / 86_400)
            let retrievability = pow(1 + (19.0 / 81.0) * elapsed / fsrsState.stability, -0.5)
            return min(1, max(0, retrievability))
        }

        let estimatedRetention: Double?
        if retentionValues.isEmpty {
            estimatedRetention = nil
        } else {
            estimatedRetention = retentionValues.reduce(0, +) / Double(retentionValues.count)
        }

        return InsightsSnapshot(
            deckCount: decks.count,
            cardCount: cards.count,
            dueNowCount: cards.filter { $0.schedule.dueDate <= now }.count,
            reviewedTodayCount: reviewCountByDate[today] ?? 0,
            reviewedLastSevenDaysCount: reviewedLastSevenDaysCount,
            currentStreakDays: currentStreakDays(
                reviewCountByDate: reviewCountByDate,
                today: today
            ),
            estimatedRetention: estimatedRetention,
            stateCounts: stateCounts,
            reviewCountByDate: reviewCountByDate,
            dueForecast: dueForecast
        )
    }

    private func ensurePrepared() throws {
        guard !hasPrepared else {
            return
        }

        let context = try makeContext()
        try migrateLegacyStoreIfNeeded(context: context)
        _ = try fetchOrCreateSettings(context: context)
        try save(context: context)
        hasPrepared = true
    }

    private func modelContainer() throws -> ModelContainer {
        if let container {
            return container
        }

        do {
            let configuration = ModelConfiguration(
                url: try swiftDataFileURL(),
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(
                for: DeckEntity.self,
                CardEntryEntity.self,
                AppSettingsEntity.self,
                configurations: configuration
            )
            self.container = container
            return container
        } catch {
            CrashReporter.record(error: error, context: "CardRepository.modelContainer")
            throw RepositoryError.persistenceFailed
        }
    }

    private func makeContext() throws -> ModelContext {
        let container = try modelContainer()
        return ModelContext(container)
    }

    private func save(context: ModelContext) throws {
        do {
            try context.save()
        } catch {
            CrashReporter.record(error: error, context: "CardRepository.save")
            throw RepositoryError.persistenceFailed
        }
    }

    private func migrateLegacyStoreIfNeeded(context: ModelContext) throws {
        let hasDecks = try !fetchDecks(context: context).isEmpty
        guard !hasDecks else {
            return
        }

        let legacyURL = try legacyStorageFileURL()
        guard fileManager.fileExists(atPath: legacyURL.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: legacyURL)
            let store = try decodeLegacyStore(data)
            try replaceStore(with: store, context: context)
            try? fileManager.removeItem(at: legacyURL)
        } catch let error as RepositoryError {
            throw error
        } catch {
            CrashReporter.record(error: error, context: "CardRepository.migrateLegacyStoreIfNeeded")
            throw RepositoryError.persistenceFailed
        }
    }

    private func snapshotStore(context: ModelContext) throws -> PersistedStore {
        let decks = try fetchDecks(context: context).map(domainDeck(from:))
        let mode = try schedulerModeRawValue(context: context)
        return PersistedStore(
            decks: decks,
            schedulerMode: SchedulerMode(rawValue: mode) ?? .fsrs
        )
    }

    private func replaceStore(with store: PersistedStore, context: ModelContext) throws {
        try deleteAllData(context: context)

        for deck in store.decks {
            let deckEntity = DeckEntity(
                id: deck.id,
                title: deck.title,
                createdAt: deck.createdAt
            )
            context.insert(deckEntity)

            for card in deck.cards {
                let cardEntity = makeCardEntity(from: card)
                cardEntity.deck = deckEntity
                deckEntity.cards.append(cardEntity)
            }
        }

        let mode = SchedulerMode.fsrs.rawValue
        context.insert(AppSettingsEntity(key: Self.settingsKey, schedulerModeRaw: mode))
        try save(context: context)
    }

    private func deleteAllData(context: ModelContext) throws {
        try context.fetch(FetchDescriptor<CardEntryEntity>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<DeckEntity>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<AppSettingsEntity>()).forEach { context.delete($0) }
    }

    private func decodeLegacyStore(_ data: Data) throws -> PersistedStore {
        do {
            var store = try backupDecoder.decode(PersistedStore.self, from: data)
            if store.schedulerMode != .fsrs {
                store.schedulerMode = .fsrs
            }
            return store
        } catch {
            CrashReporter.record(error: error, context: "CardRepository.decodeLegacyStore")
            throw RepositoryError.persistenceFailed
        }
    }

    private func decodeBackupStore(_ data: Data) throws -> PersistedStore {
        do {
            var store = try backupDecoder.decode(PersistedStore.self, from: data)
            if store.schedulerMode != .fsrs {
                store.schedulerMode = .fsrs
            }
            return store
        } catch {
            CrashReporter.record(error: error, context: "CardRepository.decodeBackupStore")
            throw RepositoryError.invalidBackupFile
        }
    }

    private func decodeDeckPayload(_ data: Data) throws -> ImportedDeckPayload {
        do {
            return try backupDecoder.decode(ImportedDeckPayload.self, from: data)
        } catch let repositoryError as RepositoryError {
            throw repositoryError
        } catch {
            CrashReporter.record(error: error, context: "CardRepository.decodeDeckPayload")
            throw RepositoryError.invalidDeckImportFile
        }
    }

    private func fetchDecks(context: ModelContext) throws -> [DeckEntity] {
        try context.fetch(FetchDescriptor<DeckEntity>())
    }

    private func fetchDeckEntity(deckID: UUID, context: ModelContext) throws -> DeckEntity? {
        try fetchDecks(context: context).first(where: { $0.id == deckID })
    }

    private func fetchSettings(context: ModelContext) throws -> AppSettingsEntity? {
        try context.fetch(FetchDescriptor<AppSettingsEntity>())
            .first(where: { $0.key == Self.settingsKey })
    }

    private func fetchOrCreateSettings(context: ModelContext) throws -> AppSettingsEntity {
        if let settings = try fetchSettings(context: context) {
            return settings
        }
        let settings = AppSettingsEntity(key: Self.settingsKey, schedulerModeRaw: SchedulerMode.fsrs.rawValue)
        context.insert(settings)
        return settings
    }

    private func schedulerModeRawValue(context: ModelContext) throws -> String {
        let settings = try fetchOrCreateSettings(context: context)
        return settings.schedulerModeRaw
    }

    private func domainDeck(from entity: DeckEntity) -> Deck {
        Deck(
            id: entity.id,
            title: entity.title,
            createdAt: entity.createdAt,
            cards: entity.cards.map(domainCard(from:))
        )
    }

    private func domainCard(from entity: CardEntryEntity) -> DeckCard {
        let content = FlashCard(
            id: entity.contentID,
            title: entity.contentTitle,
            subtitle: entity.contentSubtitle,
            detail: entity.contentDetail,
            imageName: entity.contentImageName
        )
        let schedule = Card(
            id: entity.id,
            state: CardState(rawValue: entity.scheduleStateRaw) ?? .new,
            stepIndex: entity.scheduleStepIndex,
            easeFactor: entity.scheduleEaseFactor,
            interval: entity.scheduleInterval,
            dueDate: entity.scheduleDueDate,
            reviewHistory: decodeReviewHistory(from: entity.scheduleReviewHistoryData),
            fsrsState: decodeFSRSState(from: entity.scheduleFSRSStateData)
        )
        return DeckCard(id: entity.id, content: content, schedule: schedule)
    }

    private func makeCardEntity(from card: DeckCard) -> CardEntryEntity {
        CardEntryEntity(
            id: card.id,
            contentID: card.content.id,
            contentTitle: card.content.title,
            contentSubtitle: card.content.subtitle,
            contentDetail: card.content.detail,
            contentImageName: card.content.imageName,
            scheduleStateRaw: card.schedule.state.rawValue,
            scheduleStepIndex: card.schedule.stepIndex,
            scheduleEaseFactor: card.schedule.easeFactor,
            scheduleInterval: card.schedule.interval,
            scheduleDueDate: card.schedule.dueDate,
            scheduleReviewHistoryData: encodeReviewHistory(card.schedule.reviewHistory),
            scheduleFSRSStateData: encodeFSRSState(card.schedule.fsrsState)
        )
    }

    private func applySchedule(_ schedule: Card, to entity: CardEntryEntity) {
        entity.scheduleStateRaw = schedule.state.rawValue
        entity.scheduleStepIndex = schedule.stepIndex
        entity.scheduleEaseFactor = schedule.easeFactor
        entity.scheduleInterval = schedule.interval
        entity.scheduleDueDate = schedule.dueDate
        entity.scheduleReviewHistoryData = encodeReviewHistory(schedule.reviewHistory)
        entity.scheduleFSRSStateData = encodeFSRSState(schedule.fsrsState)
    }

    private func decodeReviewHistory(from data: Data) -> [Date] {
        (try? payloadDecoder.decode([Date].self, from: data)) ?? []
    }

    private func encodeReviewHistory(_ history: [Date]) -> Data {
        (try? payloadEncoder.encode(history)) ?? Data("[]".utf8)
    }

    private func decodeFSRSState(from data: Data?) -> FSRSReviewState? {
        guard let data else {
            return nil
        }
        return try? payloadDecoder.decode(FSRSReviewState.self, from: data)
    }

    private func encodeFSRSState(_ state: FSRSReviewState?) -> Data? {
        guard let state else {
            return nil
        }
        return try? payloadEncoder.encode(state)
    }

    private func scheduleCard(_ card: Card, grade: UserGrade, now: Date) -> Card {
        scheduleWithFSRSHybrid(card: card, grade: grade, now: now)
    }

    private func scheduleWithFSRSHybrid(card: Card, grade: UserGrade, now: Date) -> Card {
        switch card.state {
        case .new, .learning, .relearning:
            var next = sm2Scheduler.schedule(card: card, grade: grade, now: now)
            if next.state == .review {
                next.fsrsState = seededFSRSState(from: next, now: now)
            }
            return next
        case .review:
            return scheduleReviewWithFSRS(card: card, grade: grade, now: now)
        }
    }

    private func scheduleReviewWithFSRS(card: Card, grade: UserGrade, now: Date) -> Card {
        let fsrsInput = makeFSRSCard(from: card, now: now)
        let fsrsOutput = fsrsScheduler.schedule(card: fsrsInput, grade: grade)

        if grade == .again {
            var relearning = sm2Scheduler.schedule(card: card, grade: grade, now: now)
            relearning.fsrsState = FSRSReviewState(
                id: card.id,
                stability: fsrsOutput.stability,
                difficulty: fsrsOutput.difficulty,
                reps: fsrsOutput.reps,
                scheduledDays: fsrsOutput.scheduledDays,
                lastReview: now
            )
            return relearning
        }

        var next = card
        next.state = .review
        next.stepIndex = nil
        next.interval = max(1, fsrsOutput.scheduledDays)
        next.dueDate = calendar.date(byAdding: .day, value: next.interval, to: now) ?? now
        next.fsrsState = FSRSReviewState(
            id: card.id,
            stability: fsrsOutput.stability,
            difficulty: fsrsOutput.difficulty,
            reps: fsrsOutput.reps,
            scheduledDays: fsrsOutput.scheduledDays,
            lastReview: now
        )
        return next
    }

    private func makeFSRSCard(from card: Card, now: Date) -> FSRSCard {
        let baseline = card.fsrsState ?? seededFSRSState(from: card, now: now)
        let elapsed = daysBetween(baseline.lastReview, and: now)

        return FSRSCard(
            stability: baseline.stability,
            difficulty: baseline.difficulty,
            elapsedDays: elapsed,
            scheduledDays: max(0, baseline.scheduledDays),
            reps: baseline.reps,
            state: card.state,
            lastReview: baseline.lastReview
        )
    }

    private func seededFSRSState(from card: Card, now: Date) -> FSRSReviewState {
        FSRSReviewState(
            id: card.id,
            stability: max(0.4, Double(max(1, card.interval))),
            difficulty: 5.0,
            reps: max(1, card.reviewHistory.count),
            scheduledDays: max(0, card.interval),
            lastReview: now
        )
    }

    private func daysBetween(_ start: Date, and end: Date) -> Int {
        let from = calendar.startOfDay(for: start)
        let to = calendar.startOfDay(for: end)
        return max(0, calendar.dateComponents([.day], from: from, to: to).day ?? 0)
    }

    private func dueCounts(for deck: Deck, now: Date) -> QueueDueCounts {
        let dueCards = deck.cards.filter { $0.schedule.dueDate <= now }
        let learning = dueCards.filter { matches(queue: .learning, state: $0.schedule.state) }.count
        let review = dueCards.filter { matches(queue: .review, state: $0.schedule.state) }.count
        return QueueDueCounts(learning: learning, review: review)
    }

    private func matches(queue: StudyQueue, state: CardState) -> Bool {
        switch queue {
        case .learning:
            return state == .new || state == .learning || state == .relearning
        case .review:
            return state == .review
        }
    }

    private func cardSort(lhs: DeckCard, rhs: DeckCard) -> Bool {
        if lhs.schedule.dueDate != rhs.schedule.dueDate {
            return lhs.schedule.dueDate < rhs.schedule.dueDate
        }

        let leftPriority = statePriority(lhs.schedule.state)
        let rightPriority = statePriority(rhs.schedule.state)
        if leftPriority != rightPriority {
            return leftPriority < rightPriority
        }

        return lhs.id.uuidString < rhs.id.uuidString
    }

    private func statePriority(_ state: CardState) -> Int {
        switch state {
        case .learning:
            return 0
        case .relearning:
            return 1
        case .review:
            return 2
        case .new:
            return 3
        }
    }

    private func currentStreakDays(
        reviewCountByDate: [Date: Int],
        today: Date
    ) -> Int {
        var cursor = today
        if (reviewCountByDate[cursor] ?? 0) == 0 {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor),
                  (reviewCountByDate[yesterday] ?? 0) > 0 else {
                return 0
            }
            cursor = yesterday
        }

        var streak = 0
        while (reviewCountByDate[cursor] ?? 0) > 0 {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previousDay
        }
        return streak
    }

    private func normalizedCardContent(front: String, back: String, note: String) throws -> (front: String, back: String, note: String) {
        let normalizedFront = CardTextSanitizer.normalizeMultiline(front)
        let normalizedBack = CardTextSanitizer.normalizeMultiline(back)
        let normalizedNote = CardTextSanitizer.normalizeSingleLine(note)
        guard !normalizedFront.isEmpty, !normalizedBack.isEmpty else {
            throw RepositoryError.invalidCardContent
        }
        return (normalizedFront, normalizedBack, normalizedNote)
    }

    private func suggestedImageName(from seed: String) -> String {
        let candidates = [
            "book.closed.fill",
            "brain.head.profile",
            "bolt.fill",
            "checkmark.seal.fill",
            "clock.arrow.circlepath",
            "sparkles",
            "graduationcap.fill"
        ]
        let sum = seed.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return candidates[sum % candidates.count]
    }

    private func appSupportDirectoryURL() throws -> URL {
        if let appSupportDirectoryOverride {
            if !fileManager.fileExists(atPath: appSupportDirectoryOverride.path) {
                try fileManager.createDirectory(at: appSupportDirectoryOverride, withIntermediateDirectories: true)
            }
            return appSupportDirectoryOverride
        }

        let rootURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = rootURL.appendingPathComponent("FlashForge", isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    private func legacyStorageFileURL() throws -> URL {
        try appSupportDirectoryURL().appendingPathComponent("storage.json")
    }

    private func swiftDataFileURL() throws -> URL {
        try appSupportDirectoryURL().appendingPathComponent("storage.store")
    }
}
