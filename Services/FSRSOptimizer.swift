//
//  FSRSOptimizer.swift
//  FlashForge
//

import Foundation

// Fits the FSRS weights that drive review-stage scheduling to a library's own
// graded review log. Pure and synchronous so it can run off the main actor.
enum FSRSOptimizer {
    static let minimumReviewCount = 200
    private static let maximumReviewCount = 20000

    struct Outcome: Sendable, Equatable {
        let weights: [Double]
        let reviewCount: Int
        let baselineLoss: Double
        let optimizedLoss: Double
        // False when the fitted weights predict held-out reviews no better
        // than the defaults; the defaults are kept in that case.
        let improved: Bool
    }

    // Weights the review stage actually reads, with the FSRS v4 bounds.
    private static let tunable: [(index: Int, range: ClosedRange<Double>)] = [
        (6, 0.1...5.0), (7, 0.0...0.5), (8, 0.0...3.0), (9, 0.1...0.8), (10, 0.01...2.5),
        (11, 0.5...5.0), (12, 0.01...0.2), (13, 0.01...0.9), (14, 0.01...2.0), (15, 0.0...1.0), (16, 1.0...4.0)
    ]

    private struct Sample {
        let grades: [UserGrade]
        let elapsed: [Int]
        let seedInterval: Int
    }

    static func usableReviewCount(in logs: [[ReviewLogEntry]]) -> Int {
        samples(from: logs).reduce(0) { $0 + $1.elapsed.filter { $0 >= 1 }.count }
    }

    static func optimize(logs: [[ReviewLogEntry]], base: [Double] = FSRSParameters.defaultWeights) -> Outcome? {
        var all = samples(from: logs)
        let total = all.reduce(0) { $0 + $1.elapsed.filter { $0 >= 1 }.count }
        guard total >= minimumReviewCount else {
            return nil
        }
        if total > maximumReviewCount {
            all = Array(all.suffix(max(1, all.count * maximumReviewCount / total)))
        }

        // Every fifth card is held out to check that the fit generalises.
        var training: [Sample] = []
        var validation: [Sample] = []
        for (offset, sample) in all.enumerated() {
            if offset % 5 == 4 {
                validation.append(sample)
            } else {
                training.append(sample)
            }
        }
        guard !training.isEmpty, !validation.isEmpty else {
            return nil
        }

        let trainingCount = Double(training.reduce(0) { $0 + $1.elapsed.count })
        let penalty = 10.0 / max(1.0, trainingCount)
        func objective(_ weights: [Double]) -> Double {
            var regularisation = 0.0
            for (index, range) in tunable {
                let deviation = (weights[index] - base[index]) / (range.upperBound - range.lowerBound)
                regularisation += deviation * deviation
            }
            return logLoss(weights, training) + penalty * regularisation
        }

        var weights = base
        var best = weights
        var bestObjective = objective(weights)
        var firstMoment = [Double](repeating: 0, count: tunable.count)
        var secondMoment = [Double](repeating: 0, count: tunable.count)
        let learningRate = 0.02
        var stalled = 0

        for step in 1...160 {
            for (slot, entry) in tunable.enumerated() {
                let span = entry.range.upperBound - entry.range.lowerBound
                let delta = span * 1e-3
                var upper = weights
                var lower = weights
                upper[entry.index] = min(entry.range.upperBound, weights[entry.index] + delta)
                lower[entry.index] = max(entry.range.lowerBound, weights[entry.index] - delta)
                let width = upper[entry.index] - lower[entry.index]
                // Gradient in units of the weight's own range, so one learning
                // rate suits weights of very different magnitude.
                let gradient = width > 0 ? (objective(upper) - objective(lower)) / width * span : 0

                firstMoment[slot] = 0.9 * firstMoment[slot] + 0.1 * gradient
                secondMoment[slot] = 0.999 * secondMoment[slot] + 0.001 * gradient * gradient
                let correctedFirst = firstMoment[slot] / (1 - pow(0.9, Double(step)))
                let correctedSecond = secondMoment[slot] / (1 - pow(0.999, Double(step)))
                let update = learningRate * span * correctedFirst / (correctedSecond.squareRoot() + 1e-8)
                weights[entry.index] = min(entry.range.upperBound, max(entry.range.lowerBound, weights[entry.index] - update))
            }

            let current = objective(weights)
            if current < bestObjective - 1e-6 {
                bestObjective = current
                best = weights
                stalled = 0
            } else {
                stalled += 1
                if stalled >= 20 {
                    break
                }
            }
        }

        let baselineLoss = logLoss(base, validation)
        let optimizedLoss = logLoss(best, validation)
        let improved = optimizedLoss < baselineLoss
        return Outcome(
            weights: improved ? best : base,
            reviewCount: total,
            baselineLoss: baselineLoss,
            optimizedLoss: improved ? optimizedLoss : baselineLoss,
            improved: improved
        )
    }

    // Review-stage reviews of one card, replayed the way CardRepository
    // schedules them: FSRS state is seeded from the graduating interval the
    // first time a card is reviewed in the review stage.
    private static func samples(from logs: [[ReviewLogEntry]]) -> [Sample] {
        logs.compactMap { log in
            let reviews = log.filter { $0.stateBefore == .review }
            guard let first = reviews.first else {
                return nil
            }
            return Sample(
                grades: reviews.map(\.grade),
                elapsed: reviews.map(\.elapsedDays),
                seedInterval: first.scheduledDays
            )
        }
    }

    private static func logLoss(_ weights: [Double], _ samples: [Sample]) -> Double {
        let scheduler = FSRSScheduler(parameters: FSRSParameters(w: weights))
        var sum = 0.0
        var count = 0
        for sample in samples {
            var state = FSRSCard(
                stability: max(0.4, Double(max(1, sample.seedInterval))),
                difficulty: 5.0,
                scheduledDays: max(0, sample.seedInterval),
                reps: 1,
                state: .review
            )
            for (grade, elapsed) in zip(sample.grades, sample.elapsed) {
                if elapsed >= 1 {
                    let predicted = scheduler.retrievability(stability: state.stability, elapsedDays: elapsed)
                    let clamped = min(1 - 1e-6, max(1e-6, predicted))
                    sum -= grade == .again ? log(1 - clamped) : log(clamped)
                    count += 1
                }
                state.elapsedDays = elapsed
                state.state = .review
                state = scheduler.schedule(card: state, grade: grade)
            }
        }
        return count > 0 ? sum / Double(count) : 0
    }
}
