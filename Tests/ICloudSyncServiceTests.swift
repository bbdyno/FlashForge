import XCTest
@testable import FlashForge

final class ICloudSyncServiceTests: XCTestCase {
    private var sandboxRootURL: URL!

    override func setUpWithError() throws {
        sandboxRootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlashForgeICloudSyncTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: sandboxRootURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let sandboxRootURL {
            try? FileManager.default.removeItem(at: sandboxRootURL)
        }
        sandboxRootURL = nil
    }

    func testBootstrapPullsRemoteSnapshotWhenLocalIsEmpty() async throws {
        let cloudURL = sandboxRootURL.appendingPathComponent("cloud", isDirectory: true)

        let sourceRepositoryURL = sandboxRootURL.appendingPathComponent("source", isDirectory: true)
        let sourceRepository = CardRepository(appSupportDirectoryOverride: sourceRepositoryURL)
        try await sourceRepository.prepare()
        let sourceDeck = try await sourceRepository.createDeck(title: "Cloud Deck")
        _ = try await sourceRepository.addCard(
            to: sourceDeck.id,
            front: "Q",
            back: "A",
            note: "N"
        )

        let sourceDefaults = UserDefaults(suiteName: "ICloudSyncSource-\(UUID().uuidString)")!
        let sourceService = ICloudSyncService(
            repository: sourceRepository,
            userDefaults: sourceDefaults,
            containerURLOverride: cloudURL
        )
        await sourceService.bootstrap()
        await sourceService.handleLocalDataDidChange()

        let targetRepositoryURL = sandboxRootURL.appendingPathComponent("target", isDirectory: true)
        let targetRepository = CardRepository(appSupportDirectoryOverride: targetRepositoryURL)
        try await targetRepository.prepare()

        let targetDefaults = UserDefaults(suiteName: "ICloudSyncTarget-\(UUID().uuidString)")!
        let targetService = ICloudSyncService(
            repository: targetRepository,
            userDefaults: targetDefaults,
            containerURLOverride: cloudURL
        )
        await targetService.bootstrap()

        let summaries = try await targetRepository.deckSummaries()
        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(summaries.first?.title, "Cloud Deck")
    }

    func testSyncFromCloudNowAppliesRemoteReset() async throws {
        let cloudURL = sandboxRootURL.appendingPathComponent("cloud-reset", isDirectory: true)

        let sourceRepositoryURL = sandboxRootURL.appendingPathComponent("source-reset", isDirectory: true)
        let sourceRepository = CardRepository(appSupportDirectoryOverride: sourceRepositoryURL)
        try await sourceRepository.prepare()
        let sourceDeck = try await sourceRepository.createDeck(title: "To Reset")
        _ = try await sourceRepository.addCard(
            to: sourceDeck.id,
            front: "Front",
            back: "Back",
            note: ""
        )

        let sourceDefaults = UserDefaults(suiteName: "ICloudSyncResetSource-\(UUID().uuidString)")!
        let sourceService = ICloudSyncService(
            repository: sourceRepository,
            userDefaults: sourceDefaults,
            containerURLOverride: cloudURL
        )
        await sourceService.bootstrap()
        await sourceService.handleLocalDataDidChange()

        let targetRepositoryURL = sandboxRootURL.appendingPathComponent("target-reset", isDirectory: true)
        let targetRepository = CardRepository(appSupportDirectoryOverride: targetRepositoryURL)
        try await targetRepository.prepare()
        let targetDefaults = UserDefaults(suiteName: "ICloudSyncResetTarget-\(UUID().uuidString)")!
        let targetService = ICloudSyncService(
            repository: targetRepository,
            userDefaults: targetDefaults,
            containerURLOverride: cloudURL
        )
        await targetService.bootstrap()

        try await sourceRepository.resetAllData()
        await sourceService.handleLocalDataDidChange()
        await targetService.syncFromCloudNow()

        let hasDecks = try await targetRepository.hasAnyDecks()
        XCTAssertFalse(hasDecks)
    }

    func testCloudRoundTripPreservesHistoryUsedByInsights() async throws {
        let cloudURL = sandboxRootURL.appendingPathComponent("cloud-insights", isDirectory: true)
        let sourceRepository = CardRepository(
            appSupportDirectoryOverride: sandboxRootURL.appendingPathComponent("source-insights")
        )
        try await sourceRepository.prepare()

        let deck = try await sourceRepository.createDeck(title: "History")
        let card = try await sourceRepository.addCard(
            to: deck.id,
            front: "Front",
            back: "Back",
            note: ""
        )
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        _ = try await sourceRepository.review(
            deckID: deck.id,
            cardID: card.id,
            grade: .good,
            now: now
        )

        let sourceService = ICloudSyncService(
            repository: sourceRepository,
            userDefaults: UserDefaults(suiteName: "ICloudInsightsSource-\(UUID().uuidString)")!,
            containerURLOverride: cloudURL
        )
        await sourceService.bootstrap()

        let targetRepository = CardRepository(
            appSupportDirectoryOverride: sandboxRootURL.appendingPathComponent("target-insights")
        )
        let targetService = ICloudSyncService(
            repository: targetRepository,
            userDefaults: UserDefaults(suiteName: "ICloudInsightsTarget-\(UUID().uuidString)")!,
            containerURLOverride: cloudURL
        )
        await targetService.bootstrap()

        let sourceSnapshot = try await sourceRepository.insightsSnapshot(
            now: now.addingTimeInterval(1)
        )
        let targetSnapshot = try await targetRepository.insightsSnapshot(
            now: now.addingTimeInterval(1)
        )

        XCTAssertEqual(targetSnapshot.deckCount, sourceSnapshot.deckCount)
        XCTAssertEqual(targetSnapshot.cardCount, sourceSnapshot.cardCount)
        XCTAssertEqual(
            targetSnapshot.reviewedLastSevenDaysCount,
            sourceSnapshot.reviewedLastSevenDaysCount
        )
        XCTAssertEqual(targetSnapshot.stateCounts, sourceSnapshot.stateCounts)
    }

    func testNewerCloudFormatIsNotImportedOrOverwritten() async throws {
        let cloudURL = sandboxRootURL.appendingPathComponent("cloud-newer-version", isDirectory: true)
        try FileManager.default.createDirectory(at: cloudURL, withIntermediateDirectories: true)

        let remoteRepository = CardRepository(
            appSupportDirectoryOverride: sandboxRootURL.appendingPathComponent("newer-source")
        )
        try await remoteRepository.prepare()
        let remoteDeck = try await remoteRepository.createDeck(title: "Future Data")
        _ = try await remoteRepository.addCard(
            to: remoteDeck.id,
            front: "Future",
            back: "Format",
            note: ""
        )
        let backupData = try await remoteRepository.exportBackupData()

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let envelope: [String: Any] = [
            "version": 99,
            "updatedAt": formatter.string(from: .now),
            "backupData": backupData.base64EncodedString()
        ]
        let envelopeData = try JSONSerialization.data(
            withJSONObject: envelope,
            options: [.sortedKeys]
        )
        let snapshotURL = cloudURL.appendingPathComponent("flashforge-sync-v1.json")
        try envelopeData.write(to: snapshotURL, options: .atomic)

        let targetRepository = CardRepository(
            appSupportDirectoryOverride: sandboxRootURL.appendingPathComponent("newer-target")
        )
        let service = ICloudSyncService(
            repository: targetRepository,
            userDefaults: UserDefaults(suiteName: "ICloudNewerTarget-\(UUID().uuidString)")!,
            containerURLOverride: cloudURL
        )
        await service.bootstrap()

        let targetHasDecks = try await targetRepository.hasAnyDecks()
        XCTAssertFalse(targetHasDecks)
        let persistedEnvelope = try JSONSerialization.jsonObject(
            with: Data(contentsOf: snapshotURL)
        ) as? [String: Any]
        XCTAssertEqual(persistedEnvelope?["version"] as? Int, 99)
    }
}
