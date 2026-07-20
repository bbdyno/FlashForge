import ActivityKit
import SharedResources
import SwiftUI
import WidgetKit

private enum WidgetText {
    static var title: String { localized("widget.today.title", fallback: "Today's Study") }
    static var noDeck: String { localized("widget.deck.none", fallback: "All Decks") }
    static var remaining: String { localized("widget.remaining", fallback: "Remaining") }
    static var completed: String { localized("widget.completed", fallback: "Completed") }
    static var liveLabel: String { localized("live.label", fallback: "Studying") }
    static var doneShort: String { localized("live.done_short", fallback: "Done") }
    static var leftShort: String { localized("live.left_short", fallback: "Left") }
    static var syncIdle: String { localized("live.sync.idle", fallback: "Idle") }
    static var syncing: String { localized("live.sync.syncing", fallback: "Syncing") }
    static var synced: String { localized("live.sync.synced", fallback: "Synced") }
    static var syncFailed: String { localized("live.sync.failed", fallback: "Sync Failed") }
    static var complete: String { localized("live.complete", fallback: "Completed") }

    static func localized(_ key: String, fallback: String) -> String {
        SharedL10n.localized(key, fallback: fallback)
    }
}

private func syncStatusText(for state: StudySyncState) -> String {
    switch state {
    case .idle:
        return WidgetText.syncIdle
    case .syncing:
        return WidgetText.syncing
    case .synced:
        return WidgetText.synced
    case .failed:
        return WidgetText.syncFailed
    }
}

private func syncStatusIcon(for state: StudySyncState) -> String {
    switch state {
    case .idle:
        return "pause.circle.fill"
    case .syncing:
        return "arrow.triangle.2.circlepath.circle.fill"
    case .synced:
        return "checkmark.circle.fill"
    case .failed:
        return "exclamationmark.triangle.fill"
    }
}

private func progressRatio(completedCount: Int, goalCount: Int, remainingCount: Int) -> Double {
    if goalCount <= 0 {
        return remainingCount == 0 ? 1 : 0
    }
    return min(1, max(0, Double(completedCount) / Double(goalCount)))
}

private func progressPercentText(completedCount: Int, goalCount: Int, remainingCount: Int) -> String {
    let ratio = progressRatio(completedCount: completedCount, goalCount: goalCount, remainingCount: remainingCount)
    return "\(Int((ratio * 100).rounded()))%"
}

private func goalBaselineCount(goalCount: Int, completedCount: Int) -> Int {
    max(goalCount, completedCount)
}

private func completionText(completedCount: Int, goalCount: Int) -> String {
    "\(completedCount)/\(goalBaselineCount(goalCount: goalCount, completedCount: completedCount))"
}

private struct StudyStatusEntry: TimelineEntry {
    let date: Date
    let snapshot: StudyStatusSnapshot
}

private struct StudyStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> StudyStatusEntry {
        StudyStatusEntry(date: .now, snapshot: sampleSnapshot())
    }

    func getSnapshot(in context: Context, completion: @escaping (StudyStatusEntry) -> Void) {
        let snapshot = StudyStatusSharedStore.loadSnapshot() ?? sampleSnapshot()
        completion(StudyStatusEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StudyStatusEntry>) -> Void) {
        let snapshot = StudyStatusSharedStore.loadSnapshot() ?? sampleSnapshot()
        let entry = StudyStatusEntry(date: .now, snapshot: snapshot)
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }

    private func sampleSnapshot() -> StudyStatusSnapshot {
        StudyStatusSnapshot(
            dayStart: Calendar.current.startOfDay(for: .now),
            goalCount: 40,
            completedCount: 14,
            dueLearningCount: 9,
            dueReviewCount: 17,
            selectedDeckTitle: "Core Deck",
            sessionState: .studying,
            syncState: .synced,
            lastSyncedAt: .now,
            updatedAt: .now
        )
    }
}

private struct WidgetCardBackground: View {
    var body: some View {
        ContainerRelativeShape()
            .fill(WidgetTheme.background)
            .overlay(
                ContainerRelativeShape()
                    .stroke(WidgetTheme.border, lineWidth: 0.5)
            )
    }
}

private struct WidgetProgressBar: View {
    let value: Double
    let height: CGFloat

    private var clampedValue: Double {
        min(1, max(0, value))
    }

    var body: some View {
        GeometryReader { proxy in
            let fillWidth = proxy.size.width * clampedValue
            let minimumVisibleWidth = min(proxy.size.width, 8)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(WidgetTheme.border)
                Capsule()
                    .fill(WidgetTheme.accent)
                    .frame(width: clampedValue == 0 ? 0 : max(minimumVisibleWidth, fillWidth))
            }
        }
        .frame(height: height)
    }
}

private struct WidgetStatusBadge: View {
    let state: StudySyncState

    var body: some View {
        Label(syncStatusText(for: state), systemImage: syncStatusIcon(for: state))
            .font(WidgetTypography.font(size: 9, weight: .semibold, relativeTo: .caption2))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .foregroundStyle(WidgetTheme.accent)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(WidgetTheme.accentSoft, in: Capsule())
    }
}

private struct WidgetHeader: View {
    let deckTitle: String
    let syncState: StudySyncState
    let compact: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(WidgetText.title)
                    .font(WidgetTypography.font(size: 9, weight: .semibold, relativeTo: .caption2))
                    .foregroundStyle(WidgetTheme.textSecondary)
                    .lineLimit(1)
                Text(deckTitle)
                    .font(
                        WidgetTypography.font(
                            size: compact ? 12 : 14,
                            weight: .semibold,
                            relativeTo: compact ? .footnote : .subheadline
                        )
                    )
                    .foregroundStyle(WidgetTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 4)

            if !compact {
                WidgetStatusBadge(state: syncState)
            }
        }
    }
}

private struct WidgetProgressSummary: View {
    let progressText: String
    let completedGoalText: String
    let progressValue: Double
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 5 : 7) {
            HStack(alignment: .lastTextBaseline, spacing: 7) {
                Text(progressText)
                    .font(
                        WidgetTypography.font(
                            size: compact ? 28 : 32,
                            weight: .bold,
                            relativeTo: .largeTitle
                        )
                    )
                    .monospacedDigit()
                    .foregroundStyle(WidgetTheme.textPrimary)
                Text(completedGoalText)
                    .font(
                        WidgetTypography.font(
                            size: compact ? 9 : 10,
                            weight: .semibold,
                            relativeTo: .caption
                        )
                    )
                    .monospacedDigit()
                    .foregroundStyle(WidgetTheme.textSecondary)
                Spacer(minLength: 0)
            }

            WidgetProgressBar(value: progressValue, height: compact ? 4 : 5)
        }
    }
}

private struct WidgetMetric: View {
    let title: String
    let value: Int
    let systemImage: String
    let compact: Bool

    var body: some View {
        HStack(spacing: compact ? 6 : 8) {
            Image(systemName: systemImage)
                .font(.system(size: compact ? 10 : 11, weight: .semibold))
                .foregroundStyle(WidgetTheme.accent)
                .frame(width: compact ? 14 : 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(
                        WidgetTypography.font(
                            size: compact ? 8 : 9,
                            weight: .medium,
                            relativeTo: .caption2
                        )
                    )
                    .foregroundStyle(WidgetTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(value.formatted())
                    .font(
                        WidgetTypography.font(
                            size: compact ? 15 : 17,
                            weight: .bold,
                            relativeTo: .headline
                        )
                    )
                    .monospacedDigit()
                    .foregroundStyle(WidgetTheme.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WidgetMetricStrip: View {
    let completedCount: Int
    let remainingCount: Int
    let compact: Bool

    var body: some View {
        HStack(spacing: compact ? 8 : 12) {
            WidgetMetric(
                title: WidgetText.completed,
                value: completedCount,
                systemImage: "checkmark",
                compact: compact
            )

            Rectangle()
                .fill(WidgetTheme.border)
                .frame(width: 0.5)

            WidgetMetric(
                title: WidgetText.remaining,
                value: remainingCount,
                systemImage: "clock",
                compact: compact
            )
        }
        .padding(.top, compact ? 1 : 2)
    }
}

private struct StudyStatusCard: View {
    let snapshot: StudyStatusSnapshot
    let compact: Bool

    private var deckTitle: String {
        snapshot.selectedDeckTitle.isEmpty ? WidgetText.noDeck : snapshot.selectedDeckTitle
    }

    private var progressValue: Double {
        snapshot.progress
    }

    private var progressText: String {
        progressPercentText(
            completedCount: snapshot.completedCount,
            goalCount: snapshot.goalCount,
            remainingCount: snapshot.remainingCount
        )
    }

    private var completedGoalText: String {
        completionText(completedCount: snapshot.completedCount, goalCount: snapshot.goalCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 9 : 10) {
            WidgetHeader(deckTitle: deckTitle, syncState: snapshot.syncState, compact: compact)
            WidgetProgressSummary(
                progressText: progressText,
                completedGoalText: completedGoalText,
                progressValue: progressValue,
                compact: compact
            )
            WidgetMetricStrip(
                completedCount: snapshot.completedCount,
                remainingCount: snapshot.remainingCount,
                compact: compact
            )
        }
        .padding(compact ? 14 : 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) {
            WidgetCardBackground()
        }
    }
}

struct StudyStatusWidget: Widget {
    private let kind = "StudyStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StudyStatusProvider()) { entry in
            StudyStatusWidgetView(entry: entry)
        }
        .configurationDisplayName(WidgetText.localized("widget.config.title", fallback: "Today's Study"))
        .description(
            WidgetText.localized(
                "widget.config.description",
                fallback: "Quick glance at your learning progress and remaining cards."
            )
        )
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}

private struct StudyStatusWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StudyStatusEntry

    var body: some View {
        switch family {
        case .systemSmall:
            StudyStatusCard(snapshot: entry.snapshot, compact: true)
        case .systemMedium:
            StudyStatusCard(snapshot: entry.snapshot, compact: false)
        case .accessoryRectangular:
            StudyAccessoryStatusView(snapshot: entry.snapshot)
        default:
            StudyStatusCard(snapshot: entry.snapshot, compact: true)
        }
    }
}

private struct StudyAccessoryStatusView: View {
    let snapshot: StudyStatusSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(snapshot.selectedDeckTitle.isEmpty ? WidgetText.noDeck : snapshot.selectedDeckTitle)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(
                    progressPercentText(
                        completedCount: snapshot.completedCount,
                        goalCount: snapshot.goalCount,
                        remainingCount: snapshot.remainingCount
                    )
                )
                .font(.caption2)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            }

            ProgressView(value: snapshot.progress)
                .progressViewStyle(.linear)
                .tint(WidgetTheme.accent)

            HStack(spacing: 10) {
                Label(snapshot.completedCount.formatted(), systemImage: "checkmark.circle.fill")
                    .lineLimit(1)
                Spacer(minLength: 8)
                Label(snapshot.remainingCount.formatted(), systemImage: "clock.fill")
                    .lineLimit(1)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }
}

struct StudySessionLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StudySessionActivityAttributes.self) { context in
            let ratio = progressRatio(
                completedCount: context.state.completedCount,
                goalCount: context.state.goalCount,
                remainingCount: context.state.remainingCount
            )
            let ratioText = progressPercentText(
                completedCount: context.state.completedCount,
                goalCount: context.state.goalCount,
                remainingCount: context.state.remainingCount
            )
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(context.state.remainingCount == 0 ? WidgetText.complete : WidgetText.liveLabel)
                            .font(WidgetTypography.font(size: 10, weight: .semibold, relativeTo: .caption))
                            .foregroundStyle(WidgetTheme.textSecondary)
                        Text(context.state.deckTitle)
                            .font(WidgetTypography.font(size: 17, weight: .semibold, relativeTo: .headline))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .foregroundStyle(WidgetTheme.textPrimary)
                    }
                    Spacer(minLength: 8)
                    WidgetStatusBadge(state: context.state.syncState)
                }

                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(ratioText)
                        .font(WidgetTypography.font(size: 32, weight: .bold, relativeTo: .largeTitle))
                        .monospacedDigit()
                        .foregroundStyle(WidgetTheme.textPrimary)
                    Text(
                        completionText(
                            completedCount: context.state.completedCount,
                            goalCount: context.state.goalCount
                        )
                    )
                    .font(WidgetTypography.font(size: 13, weight: .semibold, relativeTo: .subheadline))
                    .monospacedDigit()
                    .foregroundStyle(WidgetTheme.textSecondary)
                }

                WidgetProgressBar(value: ratio, height: 7)

                WidgetMetricStrip(
                    completedCount: context.state.completedCount,
                    remainingCount: context.state.remainingCount,
                    compact: false
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .activityBackgroundTint(WidgetTheme.background)
            .activitySystemActionForegroundColor(WidgetTheme.textPrimary)
        } dynamicIsland: { context in
            let ratio = progressRatio(
                completedCount: context.state.completedCount,
                goalCount: context.state.goalCount,
                remainingCount: context.state.remainingCount
            )
            let ratioText = progressPercentText(
                completedCount: context.state.completedCount,
                goalCount: context.state.goalCount,
                remainingCount: context.state.remainingCount
            )
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label {
                            Text(context.state.completedCount.formatted())
                                .monospacedDigit()
                        } icon: {
                            Image(systemName: "checkmark.circle.fill")
                        }
                            .font(.headline)
                            .fontWeight(.bold)
                        Text(WidgetText.doneShort)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Label {
                            Text(context.state.remainingCount.formatted())
                                .monospacedDigit()
                        } icon: {
                            Image(systemName: "clock.fill")
                        }
                            .font(.headline)
                            .fontWeight(.bold)
                            .labelStyle(.titleAndIcon)
                        Text(WidgetText.leftShort)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.deckTitle.isEmpty ? WidgetText.noDeck : context.state.deckTitle)
                        .font(.caption)
                        .lineLimit(1)
                        .padding(.vertical, 2)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(value: ratio)
                            .tint(WidgetTheme.accent)
                        HStack {
                            Text(ratioText)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                            Spacer()
                            Label(
                                syncStatusText(for: context.state.syncState),
                                systemImage: syncStatusIcon(for: context.state.syncState)
                            )
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                Label {
                    Text(context.state.completedCount.formatted())
                        .monospacedDigit()
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                }
                    .font(.caption2)
            } compactTrailing: {
                Label {
                    Text(context.state.remainingCount.formatted())
                        .monospacedDigit()
                } icon: {
                    Image(systemName: "clock.fill")
                }
                    .font(.caption2)
            } minimal: {
                Text(ratioText)
                    .font(.caption2)
                    .monospacedDigit()
            }
            .keylineTint(WidgetTheme.accent)
        }
    }

}
