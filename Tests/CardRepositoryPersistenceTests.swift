//
//  CardRepositoryPersistenceTests.swift
//  FlashForgeTests
//
//  Created by bbdyno on 2/12/26.
//

import XCTest
@testable import FlashForge

final class CardRepositoryPersistenceTests: XCTestCase {
    private var sandboxRootURL: URL!

    override func setUpWithError() throws {
        sandboxRootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlashForgeTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: sandboxRootURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let sandboxRootURL {
            try? FileManager.default.removeItem(at: sandboxRootURL)
        }
        sandboxRootURL = nil
    }

    func testBackupExportImportReflectsIntoSwiftDataStore() async throws {
        let sourceURL = sandboxRootURL.appendingPathComponent("source", isDirectory: true)
        let targetURL = sandboxRootURL.appendingPathComponent("target", isDirectory: true)

        let sourceRepository = CardRepository(appSupportDirectoryOverride: sourceURL)
        try await sourceRepository.prepare()

        let deck = try await sourceRepository.createDeck(title: "Biology")
        _ = try await sourceRepository.addCard(
            to: deck.id,
            front: "What is ATP?",
            back: "Adenosine triphosphate\nEnergy currency of cells",
            note: "Cell biology"
        )

        let backupData = try await sourceRepository.exportBackupData()

        let targetRepository = CardRepository(appSupportDirectoryOverride: targetURL)
        try await targetRepository.prepare()
        let targetHasDecks = try await targetRepository.hasAnyDecks()
        XCTAssertFalse(targetHasDecks)

        try await targetRepository.importBackupData(backupData)

        let summaries = try await targetRepository.deckSummaries()
        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(summaries.first?.title, "Biology")

        guard let deckID = summaries.first?.id else {
            XCTFail("Imported deck id missing")
            return
        }

        let cards = try await targetRepository.cards(in: deckID)
        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards[0].content.title, "What is ATP?")
        XCTAssertEqual(cards[0].content.detail, "Adenosine triphosphate\nEnergy currency of cells")
        XCTAssertEqual(cards[0].content.subtitle, "Cell biology")
    }

    func testPrepareMigratesLegacyJsonStoreIntoSwiftData() async throws {
        struct LegacyStore: Codable {
            let decks: [Deck]
            let schedulerMode: SchedulerMode
        }

        let migrationURL = sandboxRootURL.appendingPathComponent("migration", isDirectory: true)
        try FileManager.default.createDirectory(at: migrationURL, withIntermediateDirectories: true)

        let legacyDeck = Deck(
            title: "Legacy Deck",
            cards: [
                DeckCard(
                    content: FlashCard(
                        title: "Legacy Front",
                        subtitle: "Legacy Note",
                        detail: "Legacy Back",
                        imageName: "book.closed.fill"
                    )
                )
            ]
        )

        let legacyStore = LegacyStore(decks: [legacyDeck], schedulerMode: .sm2)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let legacyData = try encoder.encode(legacyStore)

        let legacyStorageURL = migrationURL.appendingPathComponent("storage.json")
        try legacyData.write(to: legacyStorageURL, options: .atomic)

        let repository = CardRepository(appSupportDirectoryOverride: migrationURL)
        try await repository.prepare()

        let hasDecks = try await repository.hasAnyDecks()
        XCTAssertTrue(hasDecks)

        let schedulerMode = try await repository.schedulerMode()
        XCTAssertEqual(schedulerMode, .fsrs)

        let summaries = try await repository.deckSummaries()
        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(summaries.first?.title, "Legacy Deck")

        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyStorageURL.path))
    }

    func testImportDeckDataCreatesDeckWithCards() async throws {
        let repositoryURL = sandboxRootURL.appendingPathComponent("deck-import", isDirectory: true)
        let repository = CardRepository(appSupportDirectoryOverride: repositoryURL)
        try await repository.prepare()

        let payload = """
        {
          "title": "Imported Deck",
          "cards": [
            {
              "front": "Question 1",
              "back": "Answer 1",
              "note": "Note 1"
            },
            {
              "question": "Question 2",
              "answer": "Answer 2",
              "hint": "Hint 2"
            }
          ]
        }
        """

        _ = try await repository.importDeckData(Data(payload.utf8))

        let summaries = try await repository.deckSummaries()
        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(summaries.first?.title, "Imported Deck")
        XCTAssertEqual(summaries.first?.totalCardCount, 2)
    }

    func testImportDeckDataRejectsInvalidPayload() async throws {
        let repositoryURL = sandboxRootURL.appendingPathComponent("deck-import-invalid", isDirectory: true)
        let repository = CardRepository(appSupportDirectoryOverride: repositoryURL)
        try await repository.prepare()

        let payload = """
        {
          "title": "Broken Deck",
          "cards": [
            {
              "front": "Only front"
            }
          ]
        }
        """

        do {
            _ = try await repository.importDeckData(Data(payload.utf8))
            XCTFail("Expected invalid deck import file error")
        } catch let error as CardRepository.RepositoryError {
            guard case .invalidDeckImportFile = error else {
                XCTFail("Expected invalidDeckImportFile, got \(error)")
                return
            }
        }
    }

    func testReviewRecordsGradedLogThatSurvivesBackupRoundTrip() async throws {
        let sourceURL = sandboxRootURL.appendingPathComponent("log-source", isDirectory: true)
        let targetURL = sandboxRootURL.appendingPathComponent("log-target", isDirectory: true)
        let repository = CardRepository(appSupportDirectoryOverride: sourceURL)
        try await repository.prepare()

        let deck = try await repository.createDeck(title: "Chemistry")
        let card = try await repository.addCard(to: deck.id, front: "H2O", back: "Water", note: "")
        let firstReview = Date(timeIntervalSince1970: 1_780_000_000)
        let secondReview = firstReview.addingTimeInterval(3 * 24 * 60 * 60)

        try await repository.review(deckID: deck.id, cardID: card.id, grade: .good, now: firstReview)
        let reviewed = try await repository.review(deckID: deck.id, cardID: card.id, grade: .again, now: secondReview)

        XCTAssertEqual(reviewed.reviewLog.map(\.grade), [.good, .again])
        XCTAssertEqual(reviewed.reviewLog.first?.stateBefore, .new)
        XCTAssertEqual(reviewed.reviewLog.first?.elapsedDays, 0)
        XCTAssertEqual(reviewed.reviewLog.last?.elapsedDays, 3)
        XCTAssertEqual(reviewed.reviewHistory.count, 2)

        let target = CardRepository(appSupportDirectoryOverride: targetURL)
        try await target.prepare()
        try await target.importBackupData(try await repository.exportBackupData())
        let restored = try await target.cards(in: deck.id)
        XCTAssertEqual(restored.first?.schedule.reviewLog, reviewed.reviewLog)
    }
}
