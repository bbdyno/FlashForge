import XCTest
@testable import FlashForge

final class CardRepositoryInsightsTests: XCTestCase {
    private var sandboxRootURL: URL!

    override func setUpWithError() throws {
        sandboxRootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlashForgeInsightsTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: sandboxRootURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let sandboxRootURL {
            try? FileManager.default.removeItem(at: sandboxRootURL)
        }
        sandboxRootURL = nil
    }

    func testInsightsSnapshotAggregatesReviewsAndStreakAcrossDecks() async throws {
        let repository = CardRepository(appSupportDirectoryOverride: sandboxRootURL)
        try await repository.prepare()

        let firstDeck = try await repository.createDeck(title: "Languages")
        let firstCard = try await repository.addCard(
            to: firstDeck.id,
            front: "Bonjour",
            back: "Hello",
            note: ""
        )
        let secondDeck = try await repository.createDeck(title: "Science")
        let secondCard = try await repository.addCard(
            to: secondDeck.id,
            front: "H2O",
            back: "Water",
            note: ""
        )

        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let yesterday = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: now))

        _ = try await repository.review(
            deckID: firstDeck.id,
            cardID: firstCard.id,
            grade: .good,
            now: yesterday
        )
        _ = try await repository.review(
            deckID: secondDeck.id,
            cardID: secondCard.id,
            grade: .hard,
            now: yesterday
        )
        _ = try await repository.review(
            deckID: firstDeck.id,
            cardID: firstCard.id,
            grade: .good,
            now: now
        )

        let snapshot = try await repository.insightsSnapshot(now: now.addingTimeInterval(1))

        XCTAssertEqual(snapshot.deckCount, 2)
        XCTAssertEqual(snapshot.cardCount, 2)
        XCTAssertEqual(snapshot.reviewedTodayCount, 1)
        XCTAssertEqual(snapshot.reviewedLastSevenDaysCount, 3)
        XCTAssertEqual(snapshot.currentStreakDays, 2)
        XCTAssertEqual(snapshot.stateCounts.total, 2)
        XCTAssertEqual(snapshot.dueForecast.count, 7)
    }

    func testInsightsSnapshotSupportsEmptyLibrary() async throws {
        let repository = CardRepository(appSupportDirectoryOverride: sandboxRootURL)
        try await repository.prepare()

        let snapshot = try await repository.insightsSnapshot()

        XCTAssertEqual(snapshot.deckCount, 0)
        XCTAssertEqual(snapshot.cardCount, 0)
        XCTAssertEqual(snapshot.reviewedTodayCount, 0)
        XCTAssertEqual(snapshot.currentStreakDays, 0)
        XCTAssertNil(snapshot.estimatedRetention)
    }

    func testReadingInsightsDoesNotMutatePersistedOrSyncedData() async throws {
        let repository = CardRepository(appSupportDirectoryOverride: sandboxRootURL)
        try await repository.prepare()

        let deck = try await repository.createDeck(title: "Immutable Insights")
        let card = try await repository.addCard(
            to: deck.id,
            front: "Question",
            back: "Answer",
            note: "Note"
        )
        _ = try await repository.review(
            deckID: deck.id,
            cardID: card.id,
            grade: .good,
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let before = try await repository.exportBackupData()
        _ = try await repository.insightsSnapshot(
            now: Date(timeIntervalSince1970: 1_700_000_001)
        )
        let after = try await repository.exportBackupData()

        XCTAssertEqual(after, before)
    }
}
