//
//  PersonalizationCardView.swift
//  FlashForge
//

import SnapKit
import UIKit

final class PersonalizationCardView: UIView {
    var onOptimize: (() -> Void)?
    var onRetentionChanged: ((Double) -> Void)?
    // Called instead of the two above when the customer does not have Pro.
    var onLockedTap: (() -> Void)?

    private static let sliderRange: ClosedRange<Float> = 0.80...0.95

    private let titleLabel = UILabel()
    private let proBadge = UILabel()
    private let descriptionLabel = UILabel()
    private let statusLabel = UILabel()
    private let optimizeButton = UIButton(type: .system)
    private let retentionTitleLabel = UILabel()
    private let retentionValueLabel = UILabel()
    private let retentionSlider = UISlider()
    private let retentionHintLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    private var isPro = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
        configureLayout()
        applyTheme()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.hasDifferentColorAppearance(comparedTo: traitCollection) == true else {
            return
        }
        applyTheme()
    }

    func render(status: FSRSPersonalizationStatus, isPro: Bool, isBusy: Bool) {
        self.isPro = isPro
        proBadge.isHidden = isPro
        statusLabel.text = isBusy ? FlashForgeStrings.Personalization.Status.working : Self.statusText(for: status)

        isBusy ? activityIndicator.startAnimating() : activityIndicator.stopAnimating()
        optimizeButton.isEnabled = !isBusy && (status.hasEnoughReviews || !isPro)
        optimizeButton.alpha = optimizeButton.isEnabled ? 1 : 0.45

        let retention = Float(isPro ? status.profile.parameters.requestRetention : FSRSParameters.defaultRetention)
        retentionSlider.value = min(max(retention, Self.sliderRange.lowerBound), Self.sliderRange.upperBound)
        retentionSlider.isEnabled = !isBusy
        updateRetentionLabel()
    }

    private static func statusText(for status: FSRSPersonalizationStatus) -> String {
        let profile = status.profile
        guard let optimizedAt = profile.optimizedAt else {
            if status.hasEnoughReviews {
                return FlashForgeStrings.Personalization.Status.ready(status.usableReviewCount)
            }
            return FlashForgeStrings.Personalization.Status.collecting(
                status.usableReviewCount,
                FSRSOptimizer.minimumReviewCount
            )
        }

        let date = optimizedAt.formatted(date: .abbreviated, time: .omitted)
        if let baseline = profile.baselineLoss, let optimized = profile.optimizedLoss, baseline > 0, optimized < baseline {
            let percent = max(1, Int(((1 - optimized / baseline) * 100).rounded()))
            return FlashForgeStrings.Personalization.Status.optimized(date, profile.trainedReviewCount, percent)
        }
        return FlashForgeStrings.Personalization.Status.unchanged(date, profile.trainedReviewCount)
    }

    private func configureUI() {
        titleLabel.text = FlashForgeStrings.Personalization.title
        titleLabel.font = AppTypography.display(size: 21, textStyle: .headline)
        titleLabel.numberOfLines = 0

        proBadge.text = "  \(FlashForgeStrings.Personalization.pro)  "
        proBadge.font = AppTypography.font(size: 11, weight: .bold, textStyle: .caption2)
        proBadge.textColor = AppTheme.studyInk
        proBadge.backgroundColor = AppTheme.lime
        proBadge.clipsToBounds = true
        proBadge.setContentHuggingPriority(.required, for: .horizontal)
        proBadge.setContentCompressionResistancePriority(.required, for: .horizontal)

        descriptionLabel.text = FlashForgeStrings.Personalization.description
        [descriptionLabel, statusLabel, retentionHintLabel].forEach { label in
            label.font = AppTypography.font(size: 14, weight: .medium, textStyle: .subheadline)
            label.adjustsFontForContentSizeCategory = true
            label.numberOfLines = 0
        }
        statusLabel.font = AppTypography.font(size: 13, weight: .semibold, textStyle: .footnote)
        retentionHintLabel.font = AppTypography.font(size: 12.5, weight: .medium, textStyle: .caption1)
        retentionHintLabel.text = FlashForgeStrings.Personalization.Retention.hint

        var configuration = UIButton.Configuration.plain()
        configuration.title = FlashForgeStrings.Personalization.optimize
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 13, leading: 16, bottom: 13, trailing: 16)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var updated = attributes
            updated.font = AppTypography.font(size: 15, weight: .bold, textStyle: .subheadline)
            return updated
        }
        optimizeButton.configuration = configuration
        optimizeButton.accessibilityIdentifier = "personalization.optimizeButton"
        optimizeButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.isPro ? self.onOptimize?() : self.onLockedTap?()
        }, for: .touchUpInside)

        retentionTitleLabel.text = FlashForgeStrings.Personalization.Retention.title
        retentionTitleLabel.font = AppTypography.font(size: 15, weight: .bold, textStyle: .subheadline)
        retentionValueLabel.font = AppTypography.display(size: 22, textStyle: .title3)
        retentionValueLabel.textAlignment = .right

        retentionSlider.minimumValue = Self.sliderRange.lowerBound
        retentionSlider.maximumValue = Self.sliderRange.upperBound
        retentionSlider.accessibilityLabel = FlashForgeStrings.Personalization.Retention.title
        retentionSlider.addAction(UIAction { [weak self] _ in
            self?.snapRetention()
            self?.updateRetentionLabel()
        }, for: .valueChanged)
        retentionSlider.addAction(UIAction { [weak self] _ in
            self?.commitRetention()
        }, for: [.touchUpInside, .touchUpOutside, .touchCancel])

        activityIndicator.hidesWhenStopped = true

        let titleRow = UIStackView(arrangedSubviews: [titleLabel, proBadge])
        titleRow.alignment = .center
        titleRow.spacing = 8
        let statusRow = UIStackView(arrangedSubviews: [statusLabel, activityIndicator])
        statusRow.alignment = .center
        statusRow.spacing = 8
        let retentionRow = UIStackView(arrangedSubviews: [retentionTitleLabel, retentionValueLabel])
        retentionRow.alignment = .firstBaseline

        let stack = UIStackView(arrangedSubviews: [
            titleRow, descriptionLabel, statusRow, optimizeButton, retentionRow, retentionSlider, retentionHintLabel
        ])
        stack.axis = .vertical
        stack.spacing = 10
        stack.setCustomSpacing(18, after: optimizeButton)
        stack.setCustomSpacing(4, after: retentionRow)
        addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview().inset(16) }
    }

    private func configureLayout() {
        proBadge.snp.makeConstraints { $0.height.equalTo(22) }
        proBadge.layer.cornerRadius = 11
        proBadge.layer.cornerCurve = .continuous
    }

    private func applyTheme() {
        AppTheme.styleSurface(self, radius: 18)
        titleLabel.textColor = AppTheme.textPrimary
        descriptionLabel.textColor = AppTheme.textSecondary
        statusLabel.textColor = AppTheme.textPrimary
        retentionTitleLabel.textColor = AppTheme.textPrimary
        retentionValueLabel.textColor = AppTheme.textPrimary
        retentionHintLabel.textColor = AppTheme.textSecondary
        retentionSlider.minimumTrackTintColor = AppTheme.textPrimary
        retentionSlider.maximumTrackTintColor = AppTheme.inputBackground
        activityIndicator.color = AppTheme.textPrimary
        proBadge.layer.borderWidth = AppTheme.outlineWidth
        proBadge.layer.borderColor = AppTheme.studyLine.cgColor

        if var configuration = optimizeButton.configuration {
            configuration.baseForegroundColor = AppTheme.textPrimary
            configuration.background.backgroundColor = AppTheme.inputBackground
            configuration.background.strokeColor = AppTheme.cardBorder
            configuration.background.strokeWidth = AppTheme.outlineWidth
            configuration.background.cornerRadius = 14
            optimizeButton.configuration = configuration
        }
    }

    private func snapRetention() {
        retentionSlider.value = (retentionSlider.value * 100).rounded() / 100
    }

    private func updateRetentionLabel() {
        let percent = Int((retentionSlider.value * 100).rounded())
        retentionValueLabel.text = "\(percent)%"
        retentionSlider.accessibilityValue = retentionValueLabel.text
    }

    private func commitRetention() {
        guard isPro else {
            retentionSlider.value = Float(FSRSParameters.defaultRetention)
            updateRetentionLabel()
            onLockedTap?()
            return
        }
        onRetentionChanged?(Double(retentionSlider.value))
    }
}
