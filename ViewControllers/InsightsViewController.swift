//
//  InsightsViewController.swift
//  FlashForge
//

import UIKit
import SnapKit

final class InsightsViewController: UIViewController {
    private let repository: CardRepository

    private let backgroundGradientLayer = CAGradientLayer()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let stackView = UIStackView()
    private let heroView = InsightsHeroView()
    private let metricRow = UIStackView()
    private let reviewedTodayCard = InsightMetricCardView()
    private let streakCard = InsightMetricCardView()
    private let retentionCard = InsightMetricCardView()
    private let heatmapView = ReviewHeatmapView()
    private let stateBreakdownView = CardStateBreakdownView()
    private let dueForecastView = DueForecastView()
    private let daypartBlock = ProInsightBlockView(title: FlashForgeStrings.Insights.Pro.Daypart.title, color: AppTheme.sky)
    private let deckBlock = ProInsightBlockView(title: FlashForgeStrings.Insights.Pro.Decks.title, color: AppTheme.peach)
    private let forecastBlock = ProInsightBlockView(title: FlashForgeStrings.Insights.Pro.Forecast.title, color: AppTheme.lilac)
    private var advancedInsights: AdvancedInsights?
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    private let errorLabel = UILabel()

    init(repository: CardRepository) {
        self.repository = repository
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        configureNotifications()
        loadInsights()
        AppTelemetry.log(.insightsViewed, parameters: ["range": "all"])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backgroundGradientLayer.frame = view.bounds
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.hasDifferentColorAppearance(comparedTo: traitCollection) == true else {
            return
        }
        AppTheme.applyGradient(to: backgroundGradientLayer, traitCollection: traitCollection)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func configureUI() {
        title = FlashForgeStrings.Insights.title
        navigationItem.largeTitleDisplayMode = .always
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: AppIcon.image("gear-six", size: 22),
            style: .plain,
            target: self,
            action: #selector(didTapSettings)
        )
        navigationItem.rightBarButtonItem?.tintColor = AppTheme.textPrimary
        navigationItem.rightBarButtonItem?.accessibilityLabel =
            FlashForgeStrings.Insights.Settings.accessibility
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "insights.settingsButton"

        view.layer.insertSublayer(backgroundGradientLayer, at: 0)
        AppTheme.applyGradient(to: backgroundGradientLayer, traitCollection: traitCollection)
        view.backgroundColor = .clear

        scrollView.alwaysBounceVertical = true
        scrollView.backgroundColor = .clear
        scrollView.showsVerticalScrollIndicator = false
        contentView.backgroundColor = .clear

        stackView.axis = .vertical
        stackView.spacing = 12

        configureMetricRow()

        errorLabel.font = AppTypography.font(size: 15, weight: .medium, textStyle: .body)
        errorLabel.textColor = AppTheme.textSecondary
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.text = FlashForgeStrings.Insights.error
        errorLabel.isHidden = true

        loadingIndicator.color = AppTheme.textPrimary
        loadingIndicator.hidesWhenStopped = true

        view.addSubview(scrollView)
        view.addSubview(loadingIndicator)
        scrollView.addSubview(contentView)
        contentView.addSubview(stackView)

        [
            heroView,
            metricRow,
            heatmapView,
            stateBreakdownView,
            dueForecastView,
            daypartBlock,
            deckBlock,
            forecastBlock,
            errorLabel
        ].forEach(stackView.addArrangedSubview)
        stackView.setCustomSpacing(20, after: heroView)
        stackView.setCustomSpacing(20, after: metricRow)

        [daypartBlock, deckBlock, forecastBlock].forEach { block in
            block.addAction(UIAction { [weak self] _ in
                self?.present(PaywallViewController(context: .proFeature), animated: true)
            }, for: .touchUpInside)
        }

        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        contentView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
        }
        stackView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(12)
            make.leading.trailing.equalToSuperview().inset(20)
            make.bottom.equalToSuperview().inset(32)
        }
        loadingIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }

    private func configureMetricRow() {
        reviewedTodayCard.configure(title: FlashForgeStrings.Insights.Metric.reviewedToday, icon: "check.bold")
        streakCard.configure(title: FlashForgeStrings.Insights.Metric.currentStreak, icon: "fire")
        retentionCard.configure(title: FlashForgeStrings.Insights.Metric.lastSevenDays, icon: "clock")

        metricRow.axis = .horizontal
        metricRow.distribution = .fillEqually
        metricRow.alignment = .fill
        metricRow.spacing = 0
        [reviewedTodayCard, streakCard, retentionCard].forEach(metricRow.addArrangedSubview)
        reviewedTodayCard.showsLeadingRule = false
    }

    private func configureNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDeckDataDidChange),
            name: .deckDataDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEntitlementDidChange),
            name: .entitlementDidChange,
            object: nil
        )
    }

    @objc
    private func handleEntitlementDidChange() {
        renderAdvancedInsights()
    }

    @objc
    private func handleDeckDataDidChange() {
        loadInsights()
    }

    @objc
    private func didTapSettings() {
        let settings = MoreViewController(repository: repository)
        settings.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(
            settings,
            animated: true
        )
    }

    private func loadInsights() {
        loadingIndicator.startAnimating()
        errorLabel.isHidden = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.loadingIndicator.stopAnimating() }

            do {
                try await self.repository.prepare()
                let snapshot = try await self.repository.insightsSnapshot()
                self.advancedInsights = try await self.repository.advancedInsights()
                self.render(snapshot)
                self.renderAdvancedInsights()
            } catch {
                CrashReporter.record(error: error, context: "InsightsViewController.loadInsights")
                self.errorLabel.isHidden = false
            }
        }
    }

    private func render(_ snapshot: InsightsSnapshot) {
        heroView.render(
            retention: snapshot.estimatedRetention,
            summary: FlashForgeStrings.Insights.summary(
                snapshot.deckCount,
                snapshot.cardCount,
                snapshot.dueNowCount
            )
        )
        reviewedTodayCard.setValue("\(snapshot.reviewedTodayCount)")
        streakCard.setValue(FlashForgeStrings.Insights.Value.days(snapshot.currentStreakDays))
        retentionCard.setValue("\(snapshot.reviewedLastSevenDaysCount)")

        heatmapView.update(reviewCountByDate: snapshot.reviewCountByDate)
        stateBreakdownView.render(snapshot.stateCounts)
        dueForecastView.render(snapshot.dueForecast)
    }

    // Without Pro the blocks chart fixed sample shapes, never the customer's
    // own numbers, so nothing real sits under the blur.
    private func renderAdvancedInsights() {
        let isLocked = EntitlementService.shared.snapshot.tier != .pro
        let insights = isLocked ? Self.sampleInsights : advancedInsights
        guard let insights else {
            return
        }
        let window = FlashForgeStrings.Insights.Pro.window
        let collecting = FlashForgeStrings.Insights.Pro.collecting

        let daypartBars = insights.dayparts.map { item in
            InsightBarChartView.Bar(
                label: Self.title(for: item.daypart),
                value: item.recallRate ?? 0,
                caption: item.recallRate.map { FlashForgeStrings.Insights.Value.percent(Int(($0 * 100).rounded())) }
                    ?? FlashForgeStrings.Insights.Value.unavailable
            )
        }
        daypartBlock.render(
            content: InsightBarChartView(bars: daypartBars, height: 64),
            caption: window,
            isLocked: isLocked,
            message: insights.dayparts.contains { $0.recallRate != nil } ? nil : collecting
        )

        let deckRows = insights.decks.map { deck in
            InsightDeckListView.Row(
                title: deck.title,
                value: deck.recallRate.map { FlashForgeStrings.Insights.Value.percent(Int(($0 * 100).rounded())) }
                    ?? FlashForgeStrings.Insights.Value.unavailable,
                detail: FlashForgeStrings.Insights.Pro.Decks.row(deck.reviewCount),
                fraction: deck.recallRate
            )
        }
        deckBlock.render(
            content: InsightDeckListView(rows: deckRows),
            caption: window,
            isLocked: isLocked,
            message: insights.decks.contains { $0.recallRate != nil } ? nil : collecting
        )

        let labelled: Set<Int> = [0, 6, AdvancedInsights.forecastWeeks - 1]
        let forecastBars = insights.forecast.enumerated().map { index, week in
            InsightBarChartView.Bar(
                label: labelled.contains(index) ? FlashForgeStrings.Insights.Pro.Forecast.week(index + 1) : nil,
                value: Double(week.count),
                caption: nil
            )
        }
        forecastBlock.render(
            content: InsightBarChartView(bars: forecastBars, height: 72),
            caption: isLocked ? nil : FlashForgeStrings.Insights.Pro.Forecast.caption(insights.forecastTotal),
            isLocked: isLocked
        )
    }

    private static func title(for daypart: Daypart) -> String {
        switch daypart {
        case .morning:
            return FlashForgeStrings.Insights.Pro.Daypart.morning
        case .afternoon:
            return FlashForgeStrings.Insights.Pro.Daypart.afternoon
        case .evening:
            return FlashForgeStrings.Insights.Pro.Daypart.evening
        case .night:
            return FlashForgeStrings.Insights.Pro.Daypart.night
        }
    }

    private static let sampleInsights = AdvancedInsights(
        dayparts: zip(Daypart.allCases, [0.91, 0.84, 0.88, 0.72]).map {
            DaypartPerformance(daypart: $0, reviewCount: 40, recallRate: $1)
        },
        decks: [0.9, 0.78].map { DeckPerformance(id: UUID(), title: "————————", reviewCount: 40, recallRate: $0) },
        forecast: [9, 14, 6, 11, 8, 5, 12, 7, 4, 9, 6, 3, 5].map { ForecastWeek(startDate: .distantPast, count: $0) }
    )
}

private final class InsightsHeroView: UIView {
    private let valueLabel = UILabel()
    private let unitLabel = UILabel()
    private let captionLabel = UILabel()
    private let summaryLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func render(retention: Double?, summary: String) {
        if let retention {
            valueLabel.text = "\(Int((retention * 100).rounded()))"
            unitLabel.isHidden = false
        } else {
            valueLabel.text = FlashForgeStrings.Insights.Value.unavailable
            unitLabel.isHidden = true
        }
        summaryLabel.text = summary
        accessibilityLabel = [captionLabel.text, valueLabel.text.map { $0 + (unitLabel.isHidden ? "" : "%") }, summary]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    private func configureUI() {
        isAccessibilityElement = true

        valueLabel.font = AppTypography.display(size: 84, textStyle: .largeTitle, maximumPointSize: 96)
        valueLabel.textColor = AppTheme.textPrimary
        unitLabel.text = "%"
        unitLabel.font = AppTypography.display(size: 34, textStyle: .title1, maximumPointSize: 40)
        unitLabel.textColor = AppTheme.textPrimary

        captionLabel.text = FlashForgeStrings.Insights.Metric.retention
        captionLabel.font = AppTypography.font(size: 14, weight: .bold, textStyle: .subheadline)
        captionLabel.textColor = AppTheme.textPrimary
        summaryLabel.font = AppTypography.font(size: 13, weight: .semibold, textStyle: .footnote)
        summaryLabel.textColor = AppTheme.textSecondary
        summaryLabel.numberOfLines = 0

        [valueLabel, unitLabel, captionLabel, summaryLabel].forEach(addSubview)
        valueLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(-10)
            make.leading.equalToSuperview()
        }
        unitLabel.snp.makeConstraints { make in
            make.leading.equalTo(valueLabel.snp.trailing).offset(2)
            make.lastBaseline.equalTo(valueLabel)
        }
        captionLabel.snp.makeConstraints { make in
            make.top.equalTo(valueLabel.snp.bottom).offset(-10)
            make.leading.trailing.equalToSuperview()
        }
        summaryLabel.snp.makeConstraints { make in
            make.top.equalTo(captionLabel.snp.bottom).offset(3)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
}

// One column of the stats strip: ruled above and below, divided by hairlines,
// with no card around it.
private final class InsightMetricCardView: UIView {
    var showsLeadingRule = true {
        didSet { leadingRule.isHidden = !showsLeadingRule }
    }

    private let valueLabel = UILabel()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let topRule = UIView()
    private let bottomRule = UIView()
    private let leadingRule = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String, icon: String) {
        titleLabel.text = title
        iconView.image = AppIcon.image(icon, size: 14)
    }

    func setValue(_ value: String) {
        valueLabel.text = value
        accessibilityLabel = [titleLabel.text, value].compactMap { $0 }.joined(separator: ", ")
    }

    private func configureUI() {
        isAccessibilityElement = true

        valueLabel.font = AppTypography.display(size: 28, textStyle: .title2, maximumPointSize: 34)
        valueLabel.textColor = AppTheme.textPrimary
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.7
        iconView.tintColor = AppTheme.textSecondary
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.font = AppTypography.font(size: 12, weight: .semibold, textStyle: .caption1)
        titleLabel.textColor = AppTheme.textSecondary
        titleLabel.numberOfLines = 2
        [topRule, bottomRule, leadingRule].forEach { $0.backgroundColor = AppTheme.cardBorder }

        let captionRow = UIStackView(arrangedSubviews: [iconView, titleLabel])
        captionRow.alignment = .top
        captionRow.spacing = 4

        [valueLabel, captionRow, topRule, bottomRule, leadingRule].forEach(addSubview)
        topRule.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(AppTheme.outlineWidth)
        }
        bottomRule.snp.makeConstraints { make in
            make.bottom.leading.trailing.equalToSuperview()
            make.height.equalTo(AppTheme.outlineWidth)
        }
        leadingRule.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.width.equalTo(AppTheme.outlineWidth)
        }
        valueLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(12)
            make.leading.trailing.equalToSuperview().inset(12)
        }
        captionRow.snp.makeConstraints { make in
            make.top.equalTo(valueLabel.snp.bottom).offset(2)
            make.leading.trailing.equalToSuperview().inset(12)
            make.bottom.equalToSuperview().inset(12)
        }
    }
}

private final class CardStateBreakdownView: UIView {
    private let titleLabel = UILabel()
    private let stackView = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func render(_ counts: CardStateCounts) {
        stackView.arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let total = max(1, counts.total)
        let rows: [(String, Int, UIColor)] = [
            (FlashForgeStrings.Insights.States.new, counts.new, AppTheme.textSecondary),
            (FlashForgeStrings.Insights.States.learning, counts.learning, AppTheme.gradeHard),
            (FlashForgeStrings.Insights.States.review, counts.review, AppTheme.accentTeal),
            (FlashForgeStrings.Insights.States.relearning, counts.relearning, AppTheme.gradeAgain)
        ]

        rows.forEach { title, count, color in
            let row = InsightProgressRow()
            row.configure(
                title: title,
                count: count,
                progress: Float(count) / Float(total),
                color: color
            )
            stackView.addArrangedSubview(row)
        }
    }

    private func configureUI() {
        AppTheme.styleSurface(self, radius: 18)

        titleLabel.text = FlashForgeStrings.Insights.States.title
        titleLabel.font = AppTypography.font(size: 17, weight: .bold, textStyle: .headline)
        titleLabel.textColor = AppTheme.textPrimary

        stackView.axis = .vertical
        stackView.spacing = 14

        addSubview(titleLabel)
        addSubview(stackView)
        titleLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(18)
        }
        stackView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(18)
            make.leading.trailing.bottom.equalToSuperview().inset(18)
        }
    }
}

private final class InsightProgressRow: UIView {
    private let titleLabel = UILabel()
    private let countLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .default)

    override init(frame: CGRect) {
        super.init(frame: frame)

        titleLabel.font = AppTypography.font(size: 13, weight: .semibold, textStyle: .subheadline)
        titleLabel.textColor = AppTheme.textPrimary

        countLabel.font = AppTypography.font(size: 13, weight: .bold, textStyle: .subheadline)
        countLabel.textColor = AppTheme.textSecondary
        countLabel.textAlignment = .right

        progressView.trackTintColor = AppTheme.inputBackground
        progressView.layer.cornerRadius = 3
        progressView.clipsToBounds = true

        isAccessibilityElement = true
        addSubview(titleLabel)
        addSubview(countLabel)
        addSubview(progressView)

        titleLabel.snp.makeConstraints { make in
            make.top.leading.equalToSuperview()
        }
        countLabel.snp.makeConstraints { make in
            make.top.trailing.equalToSuperview()
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(8)
        }
        progressView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(6)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String, count: Int, progress: Float, color: UIColor) {
        titleLabel.text = title
        countLabel.text = "\(count)"
        progressView.progress = progress
        progressView.progressTintColor = color
        accessibilityLabel = title
        accessibilityValue = "\(count)"
    }
}

private final class DueForecastView: UIView {
    private let titleLabel = UILabel()
    private let chartStack = UIStackView()
    private let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter
    }()
    private let accessibilityDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func render(_ forecast: [DueForecastDay]) {
        chartStack.arrangedSubviews.forEach {
            chartStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let maximum = max(1, forecast.map(\.count).max() ?? 0)
        forecast.forEach { item in
            let column = DueForecastColumn()
            column.configure(
                weekday: weekdayFormatter.string(from: item.date),
                count: item.count,
                fraction: CGFloat(item.count) / CGFloat(maximum),
                accessibilityDate: accessibilityDateFormatter.string(from: item.date)
            )
            chartStack.addArrangedSubview(column)
        }
    }

    private func configureUI() {
        AppTheme.styleSurface(self, radius: 18)

        titleLabel.text = FlashForgeStrings.Insights.Forecast.title
        titleLabel.font = AppTypography.font(size: 17, weight: .bold, textStyle: .headline)
        titleLabel.textColor = AppTheme.textPrimary

        chartStack.axis = .horizontal
        chartStack.alignment = .fill
        chartStack.distribution = .fillEqually
        chartStack.spacing = 8

        addSubview(titleLabel)
        addSubview(chartStack)
        titleLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(18)
        }
        chartStack.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(18)
            make.leading.trailing.bottom.equalToSuperview().inset(18)
            make.height.equalTo(132)
        }
    }
}

private final class DueForecastColumn: UIView {
    private let countLabel = UILabel()
    private let barContainer = UIView()
    private let barView = UIView()
    private let weekdayLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        weekday: String,
        count: Int,
        fraction: CGFloat,
        accessibilityDate: String
    ) {
        countLabel.text = "\(count)"
        weekdayLabel.text = weekday
        barView.snp.remakeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(max(4, 76 * fraction))
        }
        accessibilityLabel = accessibilityDate
        accessibilityValue = "\(count)"
    }

    private func configureUI() {
        isAccessibilityElement = true

        countLabel.font = AppTypography.font(size: 10, weight: .bold, textStyle: .caption2)
        countLabel.textColor = AppTheme.textSecondary
        countLabel.textAlignment = .center

        barContainer.backgroundColor = AppTheme.inputBackground
        barContainer.layer.cornerRadius = 5
        barContainer.clipsToBounds = true
        barView.backgroundColor = AppTheme.textPrimary
        barView.layer.cornerRadius = 5
        barView.layer.cornerCurve = .continuous

        weekdayLabel.font = AppTypography.font(size: 10, weight: .semibold, textStyle: .caption2)
        weekdayLabel.textColor = AppTheme.textSecondary
        weekdayLabel.textAlignment = .center
        weekdayLabel.adjustsFontSizeToFitWidth = true

        addSubview(countLabel)
        addSubview(barContainer)
        addSubview(weekdayLabel)
        barContainer.addSubview(barView)

        countLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }
        barContainer.snp.makeConstraints { make in
            make.top.equalTo(countLabel.snp.bottom).offset(4)
            make.leading.trailing.equalToSuperview().inset(3)
            make.height.equalTo(80)
        }
        barView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(4)
        }
        weekdayLabel.snp.makeConstraints { make in
            make.top.equalTo(barContainer.snp.bottom).offset(7)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
}
