//
//  FSRSPersonalizationTests.swift
//  FlashForgeTests
//

import XCTest
@testable import FlashForge

final class FSRSPersonalizationTests: XCTestCase {
    private var sandboxRootURL: URL!

    override func setUpWithError() throws {
        sandboxRootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlashForgeTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: sandboxRootURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: sandboxRootURL)
    }

    // MARK: - Scheduler

    func testSuccessfulReviewsLengthenTheInterval() {
        let scheduler = FSRSScheduler(parameters: .default)
        var card = FSRSCard(stability: 10, difficulty: 5, elapsedDays: 10, scheduledDays: 10, reps: 3, state: .review)

        card = scheduler.schedule(card: card, grade: .good)
        XCTAssertGreaterThan(card.scheduledDays, 20)

        let previous = card.scheduledDays
        card.elapsedDays = previous
        card = scheduler.schedule(card: card, grade: .good)
        XCTAssertGreaterThan(card.scheduledDays, previous * 2)
    }

    func testGradesMoveDifficultyAndStabilityInTheRightDirection() {
        let scheduler = FSRSScheduler(parameters: .default)
        let card = FSRSCard(stability: 10, difficulty: 5, elapsedDays: 10, scheduledDays: 10, reps: 3, state: .review)

        let hard = scheduler.schedule(card: card, grade: .hard)
        let good = scheduler.schedule(card: card, grade: .good)
        let easy = scheduler.schedule(card: card, grade: .easy)
        let again = scheduler.schedule(card: card, grade: .again)

        XCTAssertGreaterThan(hard.difficulty, good.difficulty)
        XCTAssertLessThan(easy.difficulty, good.difficulty)
        XCTAssertLessThan(hard.stability, good.stability)
        XCTAssertGreaterThan(easy.stability, good.stability)
        XCTAssertLessThan(again.stability, card.stability)
        XCTAssertEqual(again.state, .relearning)
    }

    func testLowerTargetRetentionGivesLongerIntervals() {
        let card = FSRSCard(stability: 10, difficulty: 5, elapsedDays: 10, scheduledDays: 10, reps: 3, state: .review)
        let strict = FSRSScheduler(parameters: FSRSParameters(requestRetention: 0.95)).schedule(card: card, grade: .good)
        let relaxed = FSRSScheduler(parameters: FSRSParameters(requestRetention: 0.8)).schedule(card: card, grade: .good)
        XCTAssertGreaterThan(relaxed.scheduledDays, strict.scheduledDays)
    }

    // MARK: - Optimizer

    func testOptimizerNeedsEnoughReviews() {
        let logs = Self.simulatedLogs(cards: 10, reviewsPerCard: 4, weights: FSRSParameters.defaultWeights)
        XCTAssertLessThan(FSRSOptimizer.usableReviewCount(in: logs), FSRSOptimizer.minimumReviewCount)
        XCTAssertNil(FSRSOptimizer.optimize(logs: logs))
    }

    func testOptimizerFitsALearnerWhoForgetsFasterThanTheDefaults() throws {
        // This learner's memory grows much more slowly per review than the
        // default weights assume.
        var learner = FSRSParameters.defaultWeights
        learner[8] = 0.4
        learner[10] = 0.5
        let logs = Self.simulatedLogs(cards: 320, reviewsPerCard: 6, weights: learner)

        let outcome = try XCTUnwrap(FSRSOptimizer.optimize(logs: logs))
        XCTAssertTrue(outcome.improved)
        XCTAssertLessThan(outcome.optimizedLoss, outcome.baselineLoss)
        XCTAssertGreaterThanOrEqual(outcome.reviewCount, FSRSOptimizer.minimumReviewCount)
        // The fitted growth weight moves toward the learner's, away from the default.
        XCTAssertLessThan(outcome.weights[8], FSRSParameters.defaultWeights[8])
    }

    // MARK: - Repository

    func testPersonalisedRetentionAppliesOnlyWhileEnabled() async throws {
        let standard = try await reviewInterval(named: "standard", retention: 0.8, enabled: false)
        let personalised = try await reviewInterval(named: "personalised", retention: 0.8, enabled: true)
        let baseline = try await reviewInterval(named: "baseline", retention: nil, enabled: true)

        XCTAssertEqual(standard, baseline)
        XCTAssertGreaterThan(personalised, baseline)
    }

    func testProfileSurvivesBackupRoundTrip() async throws {
        let source = CardRepository(appSupportDirectoryOverride: sandboxRootURL.appendingPathComponent("profile-source"))
        try await source.prepare()
        _ = try await source.createDeck(title: "Deck")
        let outcome = FSRSOptimizer.Outcome(
            weights: FSRSParameters.defaultWeights.map { $0 * 1.01 },
            reviewCount: 250,
            baselineLoss: 0.4,
            optimizedLoss: 0.3,
            improved: true
        )
        _ = try await source.saveFSRSOptimization(outcome)
        let saved = try await source.updateDesiredRetention(0.85)

        let target = CardRepository(appSupportDirectoryOverride: sandboxRootURL.appendingPathComponent("profile-target"))
        try await target.prepare()
        try await target.importBackupData(try await source.exportBackupData())
        let restored = try await target.fsrsPersonalizationStatus().profile

        XCTAssertEqual(restored, saved)
        XCTAssertEqual(restored.parameters.requestRetention, 0.85)
        XCTAssertEqual(restored.trainedReviewCount, 250)
    }

    func testLapsedCardKeepsItsFSRSDifficultyAfterRelearning() async throws {
        let repository = CardRepository(appSupportDirectoryOverride: sandboxRootURL.appendingPathComponent("lapse"))
        try await repository.prepare()
        let deck = try await repository.createDeck(title: "Deck")
        let card = try await repository.addCard(to: deck.id, front: "Q", back: "A", note: "")
        var now = Date(timeIntervalSince1970: 1_780_000_000)

        var schedule = try await graduate(repository, deckID: deck.id, cardID: card.id, now: &now)
        now = schedule.dueDate
        schedule = try await repository.review(deckID: deck.id, cardID: card.id, grade: .hard, now: now)
        now = schedule.dueDate
        schedule = try await repository.review(deckID: deck.id, cardID: card.id, grade: .again, now: now)
        let lapsedDifficulty = try XCTUnwrap(schedule.fsrsState?.difficulty)
        XCTAssertNotEqual(lapsedDifficulty, 5.0, accuracy: 0.01)

        for _ in 0 ..< 8 where schedule.state != .review {
            now = max(schedule.dueDate, now.addingTimeInterval(60))
            schedule = try await repository.review(deckID: deck.id, cardID: card.id, grade: .good, now: now)
        }
        XCTAssertEqual(schedule.state, .review)
        XCTAssertEqual(try XCTUnwrap(schedule.fsrsState?.difficulty), lapsedDifficulty, accuracy: 0.0001)
    }

    // MARK: - Helpers

    private func reviewInterval(named name: String, retention: Double?, enabled: Bool) async throws -> Int {
        let repository = CardRepository(appSupportDirectoryOverride: sandboxRootURL.appendingPathComponent(name))
        try await repository.prepare()
        await repository.setPersonalizationEnabled(enabled)
        if let retention {
            _ = try await repository.updateDesiredRetention(retention)
        }
        let deck = try await repository.createDeck(title: "Deck")
        let card = try await repository.addCard(to: deck.id, front: "Q", back: "A", note: "")
        var now = Date(timeIntervalSince1970: 1_780_000_000)

        let graduated = try await graduate(repository, deckID: deck.id, cardID: card.id, now: &now)
        now = graduated.dueDate
        return try await repository.review(deckID: deck.id, cardID: card.id, grade: .good, now: now).interval
    }

    private func graduate(_ repository: CardRepository, deckID: UUID, cardID: UUID, now: inout Date) async throws -> Card {
        var schedule = try await repository.review(deckID: deckID, cardID: cardID, grade: .good, now: now)
        for _ in 0 ..< 8 where schedule.state != .review {
            now = max(schedule.dueDate, now.addingTimeInterval(60))
            schedule = try await repository.review(deckID: deckID, cardID: cardID, grade: .good, now: now)
        }
        XCTAssertEqual(schedule.state, .review)
        return schedule
    }

    // Review-stage logs for a learner whose memory follows `weights`, reviewed
    // on the dates the default scheduler would pick.
    private static func simulatedLogs(cards: Int, reviewsPerCard: Int, weights: [Double]) -> [[ReviewLogEntry]] {
        let learner = FSRSScheduler(parameters: FSRSParameters(w: weights))
        let planner = FSRSScheduler(parameters: .default)
        var generator = SplitMix64(seed: 42)
        let start = Date(timeIntervalSince1970: 1_780_000_000)

        return (0 ..< cards).map { _ in
            let seedInterval = 3
            var memory = FSRSCard(stability: 3, difficulty: 5, scheduledDays: seedInterval, reps: 1, state: .review)
            var plan = memory
            var date = start
            var entries: [ReviewLogEntry] = []

            for _ in 0 ..< reviewsPerCard {
                let elapsed = max(1, plan.scheduledDays)
                let recall = learner.retrievability(stability: memory.stability, elapsedDays: elapsed)
                let grade: UserGrade = Double.random(in: 0 ..< 1, using: &generator) < recall ? .good : .again
                date = date.addingTimeInterval(Double(elapsed) * 86400)
                entries.append(
                    ReviewLogEntry(
                        date: date,
                        grade: grade,
                        stateBefore: .review,
                        elapsedDays: elapsed,
                        scheduledDays: entries.isEmpty ? seedInterval : plan.scheduledDays
                    )
                )

                memory.elapsedDays = elapsed
                memory.state = .review
                memory = learner.schedule(card: memory, grade: grade)
                plan.elapsedDays = elapsed
                plan.state = .review
                plan = planner.schedule(card: plan, grade: grade)
                if plan.scheduledDays == 0 {
                    plan.scheduledDays = 1
                }
            }
            return entries
        }
    }
}

private struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
