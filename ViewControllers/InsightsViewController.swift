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
        metricRow.layer.borderColor = AppTheme.resolved(AppTheme.cardBorder, for: traitCollection).cgColor
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func configureUI() {
        title = FlashForgeStrings.Insights.title
        navigationItem.largeTitleDisplayMode = .always
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "gearshape"),
            style: .plain,
            target: self,
            action: #selector(didTapSettings)
        )
        navigationItem.rightBarButtonItem?.tintColor = AppTheme.accent
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

        loadingIndicator.color = AppTheme.accent
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
            errorLabel
        ].forEach(stackView.addArrangedSubview)

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
        reviewedTodayCard.configure(
            title: FlashForgeStrings.Insights.Metric.reviewedToday,
            symbolName: "checkmark",
            tint: AppTheme.accent,
            fill: AppTheme.accentSoft
        )
        streakCard.configure(
            title: FlashForgeStrings.Insights.Metric.currentStreak,
            symbolName: "flame.fill",
            tint: AppTheme.accent,
            fill: AppTheme.accentSoft
        )
        retentionCard.configure(
            title: FlashForgeStrings.Insights.Metric.retention,
            symbolName: "brain.head.profile",
            tint: AppTheme.accent,
            fill: AppTheme.accentSoft
        )

        metricRow.axis = .horizontal
        metricRow.distribution = .fillEqually
        metricRow.alignment = .fill
        metricRow.spacing = 0
        AppTheme.styleSurface(metricRow, radius: 18)
        [reviewedTodayCard, streakCard, retentionCard].forEach(metricRow.addArrangedSubview)
    }

    private func configureNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDeckDataDidChange),
            name: .deckDataDidChange,
            object: nil
        )
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
                self.render(snapshot)
            } catch {
                CrashReporter.record(error: error, context: "InsightsViewController.loadInsights")
                self.errorLabel.isHidden = false
            }
        }
    }

    private func render(_ snapshot: InsightsSnapshot) {
        heroView.render(
            reviewCount: snapshot.reviewedLastSevenDaysCount,
            summary: FlashForgeStrings.Insights.summary(
                snapshot.deckCount,
                snapshot.cardCount,
                snapshot.dueNowCount
            )
        )
        reviewedTodayCard.setValue("\(snapshot.reviewedTodayCount)")
        streakCard.setValue(
            FlashForgeStrings.Insights.Value.days(snapshot.currentStreakDays)
        )

        if let retention = snapshot.estimatedRetention {
            retentionCard.setValue(
                FlashForgeStrings.Insights.Value.percent(Int((retention * 100).rounded()))
            )
        } else {
            retentionCard.setValue(FlashForgeStrings.Insights.Value.unavailable)
        }

        heatmapView.update(reviewCountByDate: snapshot.reviewCountByDate)
        stateBreakdownView.render(snapshot.stateCounts)
        dueForecastView.render(snapshot.dueForecast)
    }
}

private final class InsightsHeroView: UIView {
    private let eyebrowLabel = UILabel()
    private let valueLabel = UILabel()
    private let unitLabel = UILabel()
    private let summaryLabel = UILabel()
    private let markContainer = UIView()
    private let markView = UIImageView(image: UIImage(systemName: "chart.line.uptrend.xyaxis"))

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func render(reviewCount: Int, summary: String) {
        valueLabel.text = "\(reviewCount)"
        summaryLabel.text = summary
        accessibilityValue = "\(reviewCount), \(summary)"
    }

    private func configureUI() {
        backgroundColor = AppTheme.cardBackground
        layer.cornerRadius = 18
        layer.cornerCurve = .continuous
        layer.borderWidth = 0.5
        layer.borderColor = AppTheme.cardBorder.cgColor
        isAccessibilityElement = true
        accessibilityLabel = FlashForgeStrings.Insights.Metric.lastSevenDays

        eyebrowLabel.text = FlashForgeStrings.Insights.Metric.lastSevenDays.uppercased()
        eyebrowLabel.font = AppTypography.font(size: 11, weight: .bold, textStyle: .caption1)
        eyebrowLabel.textColor = AppTheme.textSecondary
        AppTypography.applyTracking(1.4, to: eyebrowLabel)

        valueLabel.text = "—"
        valueLabel.font = AppTypography.font(
            size: 50,
            weight: .bold,
            textStyle: .largeTitle,
            maximumPointSize: 60
        )
        valueLabel.textColor = AppTheme.textPrimary

        unitLabel.text = FlashForgeStrings.Insights.Hero.reviews
        unitLabel.font = AppTypography.font(size: 14, weight: .semibold, textStyle: .subheadline)
        unitLabel.textColor = AppTheme.textSecondary

        summaryLabel.font = AppTypography.font(size: 13, weight: .medium, textStyle: .footnote)
        summaryLabel.textColor = AppTheme.textSecondary
        summaryLabel.numberOfLines = 2

        markContainer.backgroundColor = AppTheme.accentSoft
        markContainer.layer.cornerRadius = 18
        markContainer.layer.cornerCurve = .continuous
        markView.tintColor = AppTheme.accent
        markView.contentMode = .scaleAspectFit
        markView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 21, weight: .bold)

        addSubview(eyebrowLabel)
        addSubview(valueLabel)
        addSubview(unitLabel)
        addSubview(summaryLabel)
        addSubview(markContainer)
        markContainer.addSubview(markView)

        eyebrowLabel.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().inset(20)
            make.trailing.lessThanOrEqualTo(markContainer.snp.leading).offset(-12)
        }
        markContainer.snp.makeConstraints { make in
            make.top.trailing.equalToSuperview().inset(18)
            make.size.equalTo(36)
        }
        markView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(18)
        }
        valueLabel.snp.makeConstraints { make in
            make.top.equalTo(eyebrowLabel.snp.bottom).offset(8)
            make.leading.equalTo(eyebrowLabel)
        }
        unitLabel.snp.makeConstraints { make in
            make.leading.equalTo(valueLabel.snp.trailing).offset(8)
            make.firstBaseline.equalTo(valueLabel).offset(-3)
            make.trailing.lessThanOrEqualToSuperview().inset(20)
        }
        summaryLabel.snp.makeConstraints { make in
            make.top.equalTo(valueLabel.snp.bottom).offset(6)
            make.leading.trailing.bottom.equalToSuperview().inset(20)
        }
        snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(168)
        }
    }
}

private final class InsightMetricCardView: UIView {
    private let iconContainer = UIView()
    private let iconView = UIImageView()
    private let valueLabel = UILabel()
    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String, symbolName: String, tint: UIColor, fill: UIColor) {
        titleLabel.text = title
        iconView.image = UIImage(systemName: symbolName)
        iconView.tintColor = tint
        iconContainer.backgroundColor = fill
        accessibilityLabel = title
    }

    func setValue(_ value: String) {
        valueLabel.text = value
        accessibilityValue = value
    }

    private func configureUI() {
        backgroundColor = .clear
        isAccessibilityElement = true

        iconContainer.layer.cornerRadius = 11
        iconContainer.layer.cornerCurve = .continuous
        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 13, weight: .bold)

        valueLabel.font = AppTypography.font(size: 22, weight: .bold, textStyle: .title2)
        valueLabel.textColor = AppTheme.textPrimary
        valueLabel.text = "—"
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.72

        titleLabel.font = AppTypography.font(size: 10.5, weight: .medium, textStyle: .caption2)
        titleLabel.textColor = AppTheme.textSecondary
        titleLabel.numberOfLines = 2

        addSubview(iconContainer)
        iconContainer.addSubview(iconView)
        addSubview(valueLabel)
        addSubview(titleLabel)

        iconContainer.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().inset(12)
            make.size.equalTo(24)
        }
        iconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(12)
        }
        valueLabel.snp.makeConstraints { make in
            make.top.equalTo(iconContainer.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(12)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(valueLabel.snp.bottom).offset(4)
            make.leading.trailing.bottom.equalToSuperview().inset(12)
        }
        snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(116)
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
        barView.backgroundColor = AppTheme.accent
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
