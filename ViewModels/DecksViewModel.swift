//
//  DecksViewModel.swift
//  FlashForge
//
//  Created by bbdyno on 2/11/26.
//

import Foundation

@MainActor
final class DecksViewModel {
    enum Input {
        case viewDidLoad
        case didTapReload
        case createDeck(String)
        case importDeckData(Data)
        case renameDeck(deckID: UUID, title: String)
        case deleteDeck(UUID)
    }

    struct Output {
        var didChangeLoading: @MainActor (Bool) -> Void
        var didUpdateDecks: @MainActor ([DeckSummary]) -> Void
        var didReceiveError: @MainActor (String) -> Void

        init(
            didChangeLoading: @escaping @MainActor (Bool) -> Void = { _ in },
            didUpdateDecks: @escaping @MainActor ([DeckSummary]) -> Void = { _ in },
            didReceiveError: @escaping @MainActor (String) -> Void = { _ in }
        ) {
            self.didChangeLoading = didChangeLoading
            self.didUpdateDecks = didUpdateDecks
            self.didReceiveError = didReceiveError
        }
    }

    private let repository: CardRepository
    private var output: Output

    init(repository: CardRepository, output: Output = .init()) {
        self.repository = repository
        self.output = output
    }

    func bind(output: Output) {
        self.output = output
    }

    func send(_ input: Input) async {
        switch input {
        case .viewDidLoad, .didTapReload:
            await refreshDecks()
        case let .createDeck(title):
            await createDeck(title)
        case let .importDeckData(data):
            await importDeckData(data)
        case let .renameDeck(deckID, title):
            await renameDeck(deckID: deckID, title: title)
        case let .deleteDeck(deckID):
            await deleteDeck(deckID)
        }
    }

    private func refreshDecks() async {
        output.didChangeLoading(true)
        defer { output.didChangeLoading(false) }

        do {
            try await repository.prepare()
            let summaries = try await repository.deckSummaries()
            output.didUpdateDecks(summaries)
        } catch {
            CrashReporter.record(error: error, context: "DecksViewModel.refreshDecks")
            output.didReceiveError(Self.userFacingMessage(from: error))
        }
    }

    private func createDeck(_ title: String) async {
        do {
            _ = try await repository.createDeck(title: title)
            AppTelemetry.log(.deckCreated, parameters: ["creation_method": "manual"])
            notifyDeckDataChanged()
            await refreshDecks()
        } catch {
            CrashReporter.record(error: error, context: "DecksViewModel.createDeck")
            output.didReceiveError(Self.userFacingMessage(from: error))
        }
    }

    private func renameDeck(deckID: UUID, title: String) async {
        do {
            try await repository.renameDeck(deckID: deckID, title: title)
            notifyDeckDataChanged()
            await refreshDecks()
        } catch {
            CrashReporter.record(error: error, context: "DecksViewModel.renameDeck")
            output.didReceiveError(Self.userFacingMessage(from: error))
        }
    }

    private func importDeckData(_ data: Data) async {
        do {
            _ = try await repository.importDeckData(data)
            AppTelemetry.log(.deckCreated, parameters: ["creation_method": "import"])
            notifyDeckDataChanged()
            await refreshDecks()
        } catch {
            CrashReporter.record(error: error, context: "DecksViewModel.importDeckData")
            output.didReceiveError(Self.userFacingMessage(from: error))
        }
    }

    private func deleteDeck(_ deckID: UUID) async {
        do {
            try await repository.deleteDeck(deckID: deckID)
            notifyDeckDataChanged()
            await refreshDecks()
        } catch {
            CrashReporter.record(error: error, context: "DecksViewModel.deleteDeck")
            output.didReceiveError(Self.userFacingMessage(from: error))
        }
    }

    private func notifyDeckDataChanged() {
        NotificationCenter.default.post(name: .deckDataDidChange, object: nil)
    }

    private static func userFacingMessage(from error: Error) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription,
           !description.isEmpty {
            return description
        }
        return "An error occurred while processing decks."
    }
}
