//
//  AdvancedInsights.swift
//  FlashForge
//

import Foundation

enum Daypart: Int, CaseIterable, Sendable {
    case morning
    case afternoon
    case evening
    case night

    init(hour: Int) {
        switch hour {
        case 5 ..< 12:
            self = .morning
        case 12 ..< 18:
            self = .afternoon
        case 18 ..< 23:
            self = .evening
        default:
            self = .night
        }
    }
}

struct DaypartPerformance: Equatable, Sendable {
    let daypart: Daypart
    let reviewCount: Int
    let recallRate: Double?
}

struct DeckPerformance: Equatable, Sendable, Identifiable {
    let id: UUID
    let title: String
    let reviewCount: Int
    let recallRate: Double?
}

struct ForecastWeek: Equatable, Sendable {
    let startDate: Date
    let count: Int
}

// Pro analysis built from the graded review log. Recall means a review-stage
// card that was not graded Again; learning steps are left out because they are
// seen again within minutes.
struct AdvancedInsights: Equatable, Sendable {
    static let windowDays = 30
    static let forecastWeeks = 13
    // Below this many reviews a rate is noise, so it is reported as unknown.
    static let minimumSample = 5

    let dayparts: [DaypartPerformance]
    let decks: [DeckPerformance]
    let forecast: [ForecastWeek]

    var forecastTotal: Int {
        forecast.reduce(0) { $0 + $1.count }
    }

    static func build(decks: [Deck], now: Date, calendar: Calendar) -> AdvancedInsights {
        let today = calendar.startOfDay(for: now)
        let windowStart = calendar.date(byAdding: .day, value: -(windowDays - 1), to: today) ?? today

        var daypartTotals = [Daypart: (reviews: Int, recalled: Int)]()
        var deckResults: [DeckPerformance] = []

        for deck in decks {
            var reviews = 0
            var recalled = 0
            for card in deck.cards {
                for entry in card.schedule.reviewLog where entry.stateBefore == .review && entry.date >= windowStart {
                    let didRecall = entry.grade != .again
                    reviews += 1
                    recalled += didRecall ? 1 : 0
                    let daypart = Daypart(hour: calendar.component(.hour, from: entry.date))
                    var total = daypartTotals[daypart] ?? (0, 0)
                    total.reviews += 1
                    total.recalled += didRecall ? 1 : 0
                    daypartTotals[daypart] = total
                }
            }
            deckResults.append(
                DeckPerformance(id: deck.id, title: deck.title, reviewCount: reviews, recallRate: rate(recalled, of: reviews))
            )
        }

        let dayparts = Daypart.allCases.map { daypart -> DaypartPerformance in
            let total = daypartTotals[daypart] ?? (0, 0)
            return DaypartPerformance(
                daypart: daypart,
                reviewCount: total.reviews,
                recallRate: rate(total.recalled, of: total.reviews)
            )
        }

        // Overdue cards count toward the first week.
        let dueDates = decks.flatMap(\.cards).map(\.schedule.dueDate)
        let forecast = (0 ..< forecastWeeks).compactMap { week -> ForecastWeek? in
            guard let start = calendar.date(byAdding: .day, value: week * 7, to: today),
                  let end = calendar.date(byAdding: .day, value: 7, to: start)
            else {
                return nil
            }
            let count = dueDates.filter { week == 0 ? $0 < end : ($0 >= start && $0 < end) }.count
            return ForecastWeek(startDate: start, count: count)
        }

        return AdvancedInsights(
            dayparts: dayparts,
            decks: deckResults.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending },
            forecast: forecast
        )
    }

    private static func rate(_ recalled: Int, of reviews: Int) -> Double? {
        reviews >= minimumSample ? Double(recalled) / Double(reviews) : nil
    }
}
