//
//  DeckImportTests.swift
//  FlashForgeTests
//

import XCTest
@testable import FlashForge

final class DeckImportTests: XCTestCase {
    func testCSVWithHeaderQuotesAndExtraColumns() {
        let csv = """
        Front,Back,Hint
        "hello, world","line one
        line two",greeting
        \"\"\"quoted\"\"\",answer,
        no back,,
        """
        let cards = DelimitedTextReader.cards(from: csv)

        XCTAssertEqual(cards.count, 2)
        XCTAssertEqual(cards[0], ImportedDeck.Card(front: "hello, world", back: "line one\nline two", note: "greeting"))
        XCTAssertEqual(cards[1], ImportedDeck.Card(front: "\"quoted\"", back: "answer", note: ""))
    }

    func testAnkiTextExportUsesTabsAndSkipsMetadata() {
        let text = "#separator:tab\n#html:true\nhola\t<b>hello</b><br>hi\tgreeting\ngracias\tthank&nbsp;you\n"
        let cards = DelimitedTextReader.cards(from: text)

        XCTAssertEqual(cards.map(\.front), ["hola", "gracias"])
        XCTAssertEqual(cards[0].back, "hello\nhi")
        XCTAssertEqual(cards[0].note, "greeting")
        XCTAssertEqual(cards[1].back, "thank you")
    }

    func testEmptyTextIsRejected() {
        XCTAssertThrowsError(try DelimitedTextReader.deck(from: Data("just one column\n".utf8), title: "Deck")) { error in
            XCTAssertEqual(error as? DeckImportError, .empty)
        }
    }

    func testAnkiPackageIsReadPerDeckWithMarkupRemoved() throws {
        let data = try XCTUnwrap(Data(base64Encoded: Self.legacyPackage.joined()))
        let decks = try AnkiPackageReader.decks(from: data, fallbackTitle: "Fallback")

        XCTAssertEqual(decks.map(\.title), ["Languages / Spanish", "Capitals"])
        // The note with two cards is imported once; the note with no back is skipped.
        XCTAssertEqual(decks[0].cards, [
            ImportedDeck.Card(front: "hola", back: "hello\nhi", note: "greeting"),
            ImportedDeck.Card(front: "gracias", back: "thank you", note: "")
        ])
        XCTAssertEqual(decks[1].cards, [ImportedDeck.Card(front: "France", back: "Paris", note: "")])
    }

    func testNewerAnkiPackageReportsTheFormatProblem() throws {
        let data = try XCTUnwrap(Data(base64Encoded: Self.zstdPackage.joined()))
        XCTAssertThrowsError(try AnkiPackageReader.decks(from: data, fallbackTitle: "Deck")) { error in
            XCTAssertEqual(error as? DeckImportError, .unsupportedAnkiFormat)
        }
    }

    func testImportedDecksAreStoredAsNewCards() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("FlashForgeTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = CardRepository(appSupportDirectoryOverride: root)
        try await repository.prepare()

        let data = try XCTUnwrap(Data(base64Encoded: Self.legacyPackage.joined()))
        let result = try await repository.importDecks(try AnkiPackageReader.decks(from: data, fallbackTitle: "Deck"))
        XCTAssertEqual(result.decks, 2)
        XCTAssertEqual(result.cards, 3)

        let summaries = try await repository.deckSummaries()
        XCTAssertEqual(summaries.map(\.title), ["Capitals", "Languages / Spanish"])
        let cards = try await repository.cards(in: try XCTUnwrap(summaries.last?.id))
        XCTAssertEqual(cards.count, 2)
        XCTAssertTrue(cards.allSatisfy { $0.schedule.state == .new })
    }

    // Built with Python's sqlite3 and zipfile: three decks, four notes, deflated.
    private static let legacyPackage = [
        "UEsDBBQAAAAIAFlyR11kMJAp4gEAAABAAAAQAAAAY29sbGVjdGlvbi5hbmtpMu3XPW/TQBgH8DufHepI6IpaKaoYfLLES6WqULIlUdRSwpQBaD",
        "dUwTm52Fadc2SfJaoqQ8Z+ACYkPgJfgg0kdmZ2ZkZs00qYhQnR4f/T+e557uXxrXf0fBwbJWZpNpdGdMk6oZTsC0EIsS+/K+yPnJK/s8nu2083",
        "q8PcJ/wjX5UDAAAAAAAAwDV0wm50Oh262jIySNREZtO87uzDF6OD45E4Png8Hol6StyPpyLWRoUq2xH692TaSAp1lWzvW62qvKyr69SovO5Yo3",
        "o91aw+S8r/GfXGbPdpq7OxQV/9ul+alM1q3i1NmmenanJ6ebh6m1P+npQNAAAAAAAAAP6L19R2V6Nzf8/viXNfy7kqA/+JmskiMf5yR/h7DxtL",
        "Y6nDQoYq7/WOFlLHeVTvetTcdSgXsZFJ7i+X1fvf5heEf+Yf+LsyAAAAAAAAAIB/Z91m9I6d6uRMzLJUG8+7xRi9x55mUk+U90xmce7dthjtW2",
        "EmJ7HMPRNJfXpXB/mif5YWXpcydx6lifQGwTBSSZIOHgTDQZANo9h7maeFnvaq5d35onsSZkqZWIfV+9/hXwj/wb/zb/xrGQIAAAAAAADAteY6",
        "Di059qa1Zleha7NNl9WTzGqzNcuhLqVW22pRx3Wp2/4JUEsDBBQAAAAIAFlyR11Dv6ajBAAAAAIAAAAFAAAAbWVkaWGrrgUAUEsBAhQDFAAAAA",
        "gAWXJHXWQwkCniAQAAAEAAABAAAAAAAAAAAAAAAKSBAAAAAGNvbGxlY3Rpb24uYW5raTJQSwECFAMUAAAACABZckddQ7+mowQAAAACAAAABQAA",
        "AAAAAAAAAAAAgAEQAgAAbWVkaWFQSwUGAAAAAAIAAgBxAAAANwIAAAAA"
    ]

    // A package holding only the zstd-compressed collection of Anki 2.1.50+.
    private static let zstdPackage = [
        "UEsDBBQAAAAAAFlyR11eUP1yBAAAAAQAAAASAAAAY29sbGVjdGlvbi5hbmtpMjFienN0ZFBLAwQUAAAAAABZckddQ7+mowIAAAACAAAABQAAAG",
        "1lZGlhe31QSwECFAMUAAAAAABZckddXlD9cgQAAAAEAAAAEgAAAAAAAAAAAAAAgAEAAAAAY29sbGVjdGlvbi5hbmtpMjFiUEsBAhQDFAAAAAAA",
        "WXJHXUO/pqMCAAAAAgAAAAUAAAAAAAAAAAAAAIABNAAAAG1lZGlhUEsFBgAAAAACAAIAcwAAAFkAAAAAAA=="
    ]
}
