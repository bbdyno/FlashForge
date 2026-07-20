//
//  HomeViewModel.swift
//  FlashForge
//
//  Created by bbdyno on 2/11/26.
//

import Foundation

@MainActor
final class HomeViewModel {
    enum Input {
        case viewDidLoad
        case didTapReload
        case didSelectDeck(UUID)
        case didSelectGrade(UserGrade)
        case didReceiveExternalDataChange
    }

    struct Output {
        var didChangeLoading: @MainActor (Bool) -> Void
        var didUpdateDeckSummaries: @MainActor ([DeckSummary], UUID?) -> Void
        var didUpdateQueueCounts: @MainActor (QueueDueCounts) -> Void
        var didUpdateCard: @MainActor (StudyCard) -> Void
        var didShowEmptyState: @MainActor (String) -> Void
        var didReceiveError: @MainActor (String) -> Void

        init(
            didChangeLoading: @escaping @MainActor (Bool) -> Void = { _ in },
            didUpdateDeckSummaries: @escaping @MainActor ([DeckSummary], UUID?) -> Void = { _, _ in },
            didUpdateQueueCounts: @escaping @MainActor (QueueDueCounts) -> Void = { _ in },
            didUpdateCard: @escaping @MainActor (StudyCard) -> Void = { _ in },
            didShowEmptyState: @escaping @MainActor (String) -> Void = { _ in },
            didReceiveError: @escaping @MainActor (String) -> Void = { _ in }
        ) {
            self.didChangeLoading = didChangeLoading
            self.didUpdateDeckSummaries = didUpdateDeckSummaries
            self.didUpdateQueueCounts = didUpdateQueueCounts
            self.didUpdateCard = didUpdateCard
            self.didShowEmptyState = didShowEmptyState
            self.didReceiveError = didReceiveError
        }
    }

    private let repository: CardRepository
    private let studyStatusService: StudyStatusService
    private var output: Output

    private var selectedDeckID: UUID?
    private var currentCardID: UUID?
    private var latestDeckSummaries: [DeckSummary] = []
    private var studySessionStartedAt: Date?
    private var studySessionReviewCount = 0

    init(
        repository: CardRepository,
        studyStatusService: StudyStatusService = .shared,
        output: Output = .init()
    ) {
        self.repository = repository
        self.studyStatusService = studyStatusService
        self.output = output
    }

    func bind(output: Output) {
        self.output = output
    }

    func send(_ input: Input) async {
        switch input {
        case .viewDidLoad:
            await bootstrap()
        case .didTapReload, .didReceiveExternalDataChange:
            await reloadDecksAndCurrentCard(resetDeckSelection: false)
        case let .didSelectDeck(deckID):
            finishStudySession(completionState: "deck_changed")
            selectedDeckID = deckID
            await refreshCurrentDeckState()
        case let .didSelectGrade(grade):
            await applyGrade(grade)
        }
    }

    private func bootstrap() async {
        output.didChangeLoading(true)
        defer { output.didChangeLoading(false) }

        do {
            try await repository.prepare()
            await reloadDecksAndCurrentCard(resetDeckSelection: true)
        } catch {
            CrashReporter.record(error: error, context: "HomeViewModel.bootstrap")
            output.didReceiveError(Self.userFacingMessage(from: error))
        }
    }

    private func reloadDecksAndCurrentCard(resetDeckSelection: Bool) async {
        output.didChangeLoading(true)
        defer { output.didChangeLoading(false) }

        do {
            let summaries = try await repository.deckSummaries()
            if summaries.isEmpty {
                latestDeckSummaries = []
                selectedDeckID = nil
                currentCardID = nil
                output.didUpdateDeckSummaries([], nil)
                output.didUpdateQueueCounts(QueueDueCounts(learning: 0, review: 0))
                output.didShowEmptyState("Create a deck and add your first card to begin.")
                studyStatusService.updateStudyProgress(
                    counts: QueueDueCounts(learning: 0, review: 0),
                    completedCount: 0,
                    selectedDeckTitle: nil,
                    hasCurrentCard: false
                )
                return
            }

            latestDeckSummaries = summaries
            if resetDeckSelection || selectedDeckID == nil || !summaries.contains(where: { $0.id == selectedDeckID }) {
                selectedDeckID = summaries.first?.id
            }

            output.didUpdateDeckSummaries(summaries, selectedDeckID)
            await refreshCurrentDeckState()
        } catch {
            CrashReporter.record(error: error, context: "HomeViewModel.reloadDecksAndCurrentCard")
            output.didReceiveError(Self.userFacingMessage(from: error))
        }
    }

    private func refreshCurrentDeckState() async {
        guard let selectedDeckID else {
            currentCardID = nil
            output.didUpdateQueueCounts(QueueDueCounts(learning: 0, review: 0))
            output.didShowEmptyState("Please select a deck.")
            studyStatusService.updateStudyProgress(
                counts: QueueDueCounts(learning: 0, review: 0),
                completedCount: 0,
                selectedDeckTitle: nil,
                hasCurrentCard: false
            )
            return
        }

        do {
            let counts = try await repository.queueDueCounts(deckID: selectedDeckID)
            let nextCard = try await nextDueCard(deckID: selectedDeckID)
            let completedToday = try await repository.reviewCountToday(deckID: selectedDeckID)

            output.didUpdateQueueCounts(counts)

            if let nextCard {
                currentCardID = nextCard.id
                beginStudySessionIfNeeded(counts: counts)
                output.didUpdateCard(nextCard)
            } else {
                currentCardID = nil
                output.didShowEmptyState(emptyMessage())
                finishStudySession(completionState: "queue_completed")
            }

            studyStatusService.updateStudyProgress(
                counts: counts,
                completedCount: completedToday,
                selectedDeckTitle: selectedDeckTitle(for: selectedDeckID),
                hasCurrentCard: nextCard != nil
            )
        } catch {
            CrashReporter.record(error: error, context: "HomeViewModel.refreshCurrentDeckState")
            output.didReceiveError(Self.userFacingMessage(from: error))
        }
    }

    private func nextDueCard(deckID: UUID) async throws -> StudyCard? {
        if let learning = try await repository.nextDueCard(deckID: deckID, queue: .learning) {
            return learning
        }
        return try await repository.nextDueCard(deckID: deckID, queue: .review)
    }

    private func applyGrade(_ grade: UserGrade) async {
        guard let selectedDeckID, let currentCardID else {
            return
        }

        do {
            try await repository.review(deckID: selectedDeckID, cardID: currentCardID, grade: grade)
            studySessionReviewCount += 1
            AppTelemetry.logFirstStudyCompletedIfNeeded()
            await refreshCurrentDeckState()
        } catch {
            CrashReporter.record(error: error, context: "HomeViewModel.applyGrade")
            output.didReceiveError(Self.userFacingMessage(from: error))
        }
    }

    private func emptyMessage() -> String {
        "No cards due today."
    }

    private func selectedDeckTitle(for deckID: UUID) -> String? {
        latestDeckSummaries.first(where: { $0.id == deckID })?.title
    }

    private func beginStudySessionIfNeeded(counts: QueueDueCounts) {
        guard studySessionStartedAt == nil else {
            return
        }
        studySessionStartedAt = .now
        studySessionReviewCount = 0

        let queueType: String
        if counts.learning > 0, counts.review > 0 {
            queueType = "mixed"
        } else if counts.learning > 0 {
            queueType = "learning"
        } else {
            queueType = "review"
        }

        AppTelemetry.log(
            .studySessionStarted,
            parameters: [
                "deck_scope": "single",
                "queue_type": queueType
            ]
        )
    }

    private func finishStudySession(completionState: String) {
        guard let studySessionStartedAt else {
            return
        }

        AppTelemetry.log(
            .studySessionCompleted,
            parameters: [
                "review_count_bucket": reviewCountBucket(studySessionReviewCount),
                "duration_bucket": durationBucket(Date.now.timeIntervalSince(studySessionStartedAt)),
                "completion_state": completionState
            ]
        )
        self.studySessionStartedAt = nil
        studySessionReviewCount = 0
    }

    private func reviewCountBucket(_ count: Int) -> String {
        switch count {
        case ...0: return "0"
        case 1...4: return "1_4"
        case 5...14: return "5_14"
        default: return "15_plus"
        }
    }

    private func durationBucket(_ duration: TimeInterval) -> String {
        switch duration {
        case ..<60: return "under_1m"
        case ..<300: return "1_5m"
        case ..<900: return "5_15m"
        default: return "15m_plus"
        }
    }

    private static func userFacingMessage(from error: Error) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription,
           !description.isEmpty {
            return description
        }
        return "We couldn't process your request. Please try again."
    }
}
