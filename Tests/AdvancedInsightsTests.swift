//
//  AdvancedInsightsTests.swift
//  FlashForgeTests
//

import XCTest
@testable import FlashForge

final class AdvancedInsightsTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }()

    // 2026-06-15 12:00 UTC
    private let now = Date(timeIntervalSince1970: 1_781_524_800)

    func testRecallIsGroupedByDeckAndDaypartFromReviewStageLogs() {
        let morning = date(daysAgo: 2, hour: 8)
        let evening = date(daysAgo: 1, hour: 20)
        var entries = (0 ..< 8).map { entry(morning, $0 < 6 ? .good : .again) }
        entries += (0 ..< 5).map { _ in entry(evening, .again) }
        // Ignored: a learning step, and a review older than the 30-day window.
        entries.append(ReviewLogEntry(date: morning, grade: .again, stateBefore: .learning, elapsedDays: 0, scheduledDays: 0))
        entries.append(entry(date(daysAgo: 45, hour: 8), .again))

        let decks = [
            deck("Biology", logs: [entries]),
            deck("Chemistry", logs: [[entry(morning, .good)]])
        ]
        let insights = AdvancedInsights.build(decks: decks, now: now, calendar: calendar)

        XCTAssertEqual(insights.decks.map(\.title), ["Biology", "Chemistry"])
        XCTAssertEqual(insights.decks[0].reviewCount, 13)
        XCTAssertEqual(try XCTUnwrap(insights.decks[0].recallRate), 6.0 / 13.0, accuracy: 0.0001)
        // One review is too few to call a rate.
        XCTAssertEqual(insights.decks[1].reviewCount, 1)
        XCTAssertNil(insights.decks[1].recallRate)

        let byDaypart = Dictionary(uniqueKeysWithValues: insights.dayparts.map { ($0.daypart, $0) })
        XCTAssertEqual(byDaypart[.morning]?.reviewCount, 9)
        XCTAssertEqual(try XCTUnwrap(byDaypart[.morning]?.recallRate), 7.0 / 9.0, accuracy: 0.0001)
        XCTAssertEqual(byDaypart[.evening]?.recallRate, 0)
        XCTAssertNil(byDaypart[.night]?.recallRate)
        XCTAssertEqual(byDaypart[.afternoon]?.reviewCount, 0)
    }

    func testForecastBucketsDueCardsIntoThirteenWeeks() {
        let dueOffsets = [-3, 0, 6, 7, 20, 90, 91, 400]
        let cards = dueOffsets.map { offset in
            DeckCard(content: content(), schedule: Card(dueDate: date(daysAgo: -offset, hour: 9)))
        }
        let insights = AdvancedInsights.build(decks: [Deck(title: "Deck", cards: cards)], now: now, calendar: calendar)

        XCTAssertEqual(insights.forecast.count, AdvancedInsights.forecastWeeks)
        XCTAssertEqual(insights.forecast[0].count, 3)
        XCTAssertEqual(insights.forecast[1].count, 1)
        XCTAssertEqual(insights.forecast[2].count, 1)
        XCTAssertEqual(insights.forecast[12].count, 1)
        XCTAssertEqual(insights.forecastTotal, 6)
    }

    func testDaypartBoundaries() {
        XCTAssertEqual(Daypart(hour: 4), .night)
        XCTAssertEqual(Daypart(hour: 5), .morning)
        XCTAssertEqual(Daypart(hour: 12), .afternoon)
        XCTAssertEqual(Daypart(hour: 18), .evening)
        XCTAssertEqual(Daypart(hour: 23), .night)
    }

    private func date(daysAgo: Int, hour: Int) -> Date {
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now)) ?? now
        return calendar.date(byAdding: .hour, value: hour, to: day) ?? day
    }

    private func entry(_ date: Date, _ grade: UserGrade) -> ReviewLogEntry {
        ReviewLogEntry(date: date, grade: grade, stateBefore: .review, elapsedDays: 3, scheduledDays: 3)
    }

    private func content() -> FlashCard {
        FlashCard(title: "Q", subtitle: "", detail: "A", imageName: "")
    }

    private func deck(_ title: String, logs: [[ReviewLogEntry]]) -> Deck {
        Deck(title: title, cards: logs.map { DeckCard(content: content(), schedule: Card(reviewLog: $0)) })
    }
}
