//
//  ProInsightViews.swift
//  FlashForge
//

import SnapKit
import UIKit

// A colour-field block for one Pro analysis. Without Pro it shows sample
// shapes under a blur and acts as a button to the Pro screen.
final class ProInsightBlockView: UIControl {
    private let titleLabel = UILabel()
    private let captionLabel = UILabel()
    private let proBadge = UILabel()
    private let contentContainer = UIView()
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
    private let lockRow = UIStackView()
    private let messageLabel = UILabel()

    init(title: String, color: UIColor) {
        super.init(frame: .zero)
        backgroundColor = color
        AppTheme.styleOutline(self, radius: 22, color: AppTheme.studyLine)
        clipsToBounds = true

        titleLabel.text = title
        titleLabel.font = AppTypography.display(size: 20, textStyle: .headline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = AppTheme.studyInk
        titleLabel.numberOfLines = 0

        captionLabel.font = AppTypography.font(size: 12, weight: .semibold, textStyle: .caption1)
        captionLabel.textColor = AppTheme.studyInk.withAlphaComponent(0.7)
        captionLabel.setContentHuggingPriority(.required, for: .horizontal)

        proBadge.text = "  \(FlashForgeStrings.Personalization.pro)  "
        proBadge.font = AppTypography.font(size: 11, weight: .bold, textStyle: .caption2)
        proBadge.textColor = AppTheme.studyInk
        proBadge.backgroundColor = AppTheme.studyPaper
        proBadge.clipsToBounds = true
        AppTheme.styleOutline(proBadge, radius: 11, color: AppTheme.studyLine)
        proBadge.setContentHuggingPriority(.required, for: .horizontal)
        proBadge.setContentCompressionResistancePriority(.required, for: .horizontal)

        let header = UIStackView(arrangedSubviews: [titleLabel, captionLabel, proBadge])
        header.alignment = .center
        header.spacing = 8
        header.isUserInteractionEnabled = false

        contentContainer.isUserInteractionEnabled = false
        blurView.isUserInteractionEnabled = false
        blurView.alpha = 0.92

        let lockIcon = UIImageView(image: AppIcon.image("lock-simple.bold", size: 16))
        lockIcon.tintColor = AppTheme.studyInk
        let lockLabel = UILabel()
        lockLabel.text = FlashForgeStrings.Insights.Pro.locked
        lockLabel.font = AppTypography.font(size: 14, weight: .bold, textStyle: .subheadline)
        lockLabel.textColor = AppTheme.studyInk
        lockRow.addArrangedSubview(lockIcon)
        lockRow.addArrangedSubview(lockLabel)
        lockRow.spacing = 6
        lockRow.alignment = .center
        lockRow.isUserInteractionEnabled = false

        messageLabel.font = AppTypography.font(size: 13, weight: .semibold, textStyle: .footnote)
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.textColor = AppTheme.studyInk.withAlphaComponent(0.75)
        messageLabel.numberOfLines = 0
        messageLabel.isHidden = true

        addSubview(header)
        addSubview(contentContainer)
        addSubview(messageLabel)
        addSubview(blurView)
        addSubview(lockRow)

        header.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(16)
        }
        proBadge.snp.makeConstraints { $0.height.equalTo(22) }
        contentContainer.snp.makeConstraints { make in
            make.top.equalTo(header.snp.bottom).offset(12)
            make.leading.trailing.bottom.equalToSuperview().inset(16)
        }
        messageLabel.snp.makeConstraints { make in
            make.top.equalTo(header.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.lessThanOrEqualToSuperview().inset(16)
        }
        blurView.snp.makeConstraints { make in
            make.top.equalTo(header.snp.bottom).offset(6)
            make.leading.trailing.bottom.equalToSuperview()
        }
        lockRow.snp.makeConstraints { $0.center.equalTo(blurView) }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // `message` replaces the content when there is nothing to chart yet.
    func render(content: UIView, caption: String?, isLocked: Bool, message: String? = nil) {
        contentContainer.subviews.forEach { $0.removeFromSuperview() }
        contentContainer.addSubview(content)
        content.snp.makeConstraints { $0.edges.equalToSuperview() }

        let showsMessage = !isLocked && message != nil
        contentContainer.alpha = showsMessage ? 0 : 1
        messageLabel.isHidden = !showsMessage
        messageLabel.text = message

        captionLabel.text = caption
        captionLabel.isHidden = caption == nil || isLocked
        proBadge.isHidden = !isLocked
        blurView.isHidden = !isLocked
        lockRow.isHidden = !isLocked
        isUserInteractionEnabled = isLocked

        isAccessibilityElement = isLocked
        accessibilityTraits = .button
        accessibilityLabel = [titleLabel.text, FlashForgeStrings.Insights.Pro.locked].compactMap { $0 }.joined(separator: ", ")
    }
}

final class InsightBarChartView: UIView {
    struct Bar {
        let label: String?
        let value: Double
        let caption: String?
    }

    init(bars: [Bar], height: CGFloat) {
        super.init(frame: .zero)
        let maximum = max(bars.map(\.value).max() ?? 0, 0.0001)

        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .bottom
        row.distribution = .fillEqually
        row.spacing = bars.count > 8 ? 5 : 12
        addSubview(row)
        row.snp.makeConstraints { $0.edges.equalToSuperview() }

        for bar in bars {
            let column = UIStackView()
            column.axis = .vertical
            column.alignment = .fill
            column.spacing = 5

            let captionLabel = UILabel()
            captionLabel.text = bar.caption ?? " "
            captionLabel.font = AppTypography.font(size: 12, weight: .bold, textStyle: .caption1, maximumPointSize: 15)
            captionLabel.textColor = AppTheme.studyInk
            captionLabel.textAlignment = .center
            captionLabel.adjustsFontSizeToFitWidth = true
            captionLabel.minimumScaleFactor = 0.7

            let barView = UIView()
            barView.backgroundColor = AppTheme.studyInk
            barView.layer.cornerRadius = 5
            barView.layer.cornerCurve = .continuous
            barView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            barView.alpha = bar.value > 0 ? 1 : 0.18

            let labelView = UILabel()
            labelView.text = bar.label ?? " "
            labelView.font = AppTypography.font(size: 11, weight: .semibold, textStyle: .caption2, maximumPointSize: 14)
            labelView.textColor = AppTheme.studyInk.withAlphaComponent(0.7)
            labelView.textAlignment = .center
            labelView.adjustsFontSizeToFitWidth = true
            labelView.minimumScaleFactor = 0.7

            if bars.contains(where: { $0.caption != nil }) {
                column.addArrangedSubview(captionLabel)
            }
            column.addArrangedSubview(barView)
            column.addArrangedSubview(labelView)
            row.addArrangedSubview(column)

            let fraction = CGFloat(bar.value / maximum)
            barView.snp.makeConstraints { $0.height.equalTo(max(3, height * fraction)) }

            column.isAccessibilityElement = true
            column.accessibilityLabel = [bar.label, bar.caption].compactMap { $0 }.joined(separator: ", ")
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class InsightDeckListView: UIView {
    struct Row {
        let title: String
        let value: String
        let detail: String
        let fraction: Double?
    }

    init(rows: [Row]) {
        super.init(frame: .zero)
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview() }

        for row in rows {
            let titleLabel = UILabel()
            titleLabel.text = row.title
            titleLabel.font = AppTypography.font(size: 14, weight: .bold, textStyle: .subheadline)
            titleLabel.textColor = AppTheme.studyInk

            let detailLabel = UILabel()
            detailLabel.text = row.detail
            detailLabel.font = AppTypography.font(size: 12, weight: .semibold, textStyle: .caption1)
            detailLabel.textColor = AppTheme.studyInk.withAlphaComponent(0.7)

            let valueLabel = UILabel()
            valueLabel.text = row.value
            valueLabel.font = AppTypography.display(size: 22, textStyle: .title3)
            valueLabel.textColor = AppTheme.studyInk
            valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
            valueLabel.setContentHuggingPriority(.required, for: .horizontal)

            let textStack = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
            textStack.axis = .vertical
            textStack.spacing = 1
            let line = UIStackView(arrangedSubviews: [textStack, valueLabel])
            line.alignment = .center
            line.spacing = 10

            let track = UIView()
            track.backgroundColor = AppTheme.studyInk.withAlphaComponent(0.14)
            track.layer.cornerRadius = 2.5
            let fill = UIView()
            fill.backgroundColor = AppTheme.studyInk
            fill.layer.cornerRadius = 2.5
            track.addSubview(fill)
            track.snp.makeConstraints { $0.height.equalTo(5) }
            fill.snp.makeConstraints { make in
                make.leading.top.bottom.equalToSuperview()
                make.width.equalToSuperview().multipliedBy(max(0.001, min(1, row.fraction ?? 0)))
            }

            let rowStack = UIStackView(arrangedSubviews: [line, track])
            rowStack.axis = .vertical
            rowStack.spacing = 7
            rowStack.isAccessibilityElement = true
            rowStack.accessibilityLabel = "\(row.title), \(row.value), \(row.detail)"
            stack.addArrangedSubview(rowStack)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
