//
//  GlassCardView.swift
//  FlashForge
//
//  Created by bbdyno on 2/11/26.
//

import UIKit
import SnapKit

final class GlassCardView: UIView {
    enum Face {
        case front
        case back
    }

    private let glassContainer = UIView()
    private let blurView = UIVisualEffectView(effect: nil)
    private let highlightView = GradientOverlayView()
    private let accentRuleView = UIView()
    private let stateBadgeLabel = BadgeLabel()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let detailLabel = UILabel()
    private let helperLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureHierarchy()
        configureStyle()
        configureLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 18).cgPath
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.hasDifferentColorAppearance(comparedTo: traitCollection) == true else {
            return
        }
        applyTheme()
    }

    func configure(with studyCard: StudyCard) {
        let card = studyCard.content
        let title = CardTextSanitizer.normalizeMultiline(card.title)
        titleLabel.text = title

        let deckTitle = CardTextSanitizer.normalizeSingleLine(studyCard.deckTitle)
        let note = CardTextSanitizer.normalizeSingleLine(card.subtitle)
        let subtitle: String
        if note.isEmpty || CardTextSanitizer.isLegacyNoNote(note) {
            subtitle = deckTitle
        } else {
            subtitle = "\(deckTitle) · \(note)"
        }
        subtitleLabel.text = subtitle

        let detail = CardTextSanitizer.normalizeMultiline(card.detail)
        detailLabel.text = detail

        titleLabel.font = titleFont(for: title)
        subtitleLabel.font = subtitleFont(for: subtitle)
        detailLabel.font = detailFont(for: detail)
        stateBadgeLabel.text = badgeText(for: studyCard.schedule.state)

        setFace(.front, animated: false)
    }

    func setFace(_ face: Face, animated: Bool) {
        let applyState = {
            switch face {
            case .front:
                self.detailLabel.isHidden = true
                self.helperLabel.isHidden = false
            case .back:
                self.detailLabel.isHidden = false
                self.helperLabel.isHidden = true
            }
        }

        if animated {
            UIView.transition(
                with: glassContainer,
                duration: 0.24,
                options: [.transitionCrossDissolve, .allowUserInteraction]
            ) {
                applyState()
            }
        } else {
            applyState()
        }
    }

    func applyDragTranslation(_ translation: CGPoint, in bounds: CGRect) {
        let normalizedX = max(min(translation.x / bounds.width, 1.0), -1.0)
        let normalizedY = max(min(translation.y / bounds.height, 1.0), -1.0)

        var transform3D = CATransform3DIdentity
        transform3D.m34 = -1.0 / 650.0
        transform3D = CATransform3DRotate(transform3D, normalizedX * 0.35, 0, 1, 0)
        transform3D = CATransform3DRotate(transform3D, -normalizedY * 0.22, 1, 0, 0)

        layer.transform = transform3D
        transform = CGAffineTransform(translationX: translation.x, y: translation.y * 0.30)
    }

    func resetTransformWithSpring(velocity: CGPoint, completion: (() -> Void)? = nil) {
        let normalizedVelocity = min(max(abs(velocity.x) / 1_200.0, 0.15), 2.0)

        UIView.animate(
            withDuration: 0.72,
            delay: 0,
            usingSpringWithDamping: 0.82,
            initialSpringVelocity: normalizedVelocity,
            options: [.allowUserInteraction, .beginFromCurrentState, .curveEaseOut]
        ) { [weak self] in
            guard let self else { return }
            self.transform = .identity
            self.layer.transform = CATransform3DIdentity
        } completion: { _ in
            completion?()
        }
    }

    private func configureHierarchy() {
        addSubview(glassContainer)
        glassContainer.addSubview(blurView)
        glassContainer.addSubview(highlightView)
        glassContainer.addSubview(accentRuleView)
        glassContainer.addSubview(stateBadgeLabel)
        glassContainer.addSubview(titleLabel)
        glassContainer.addSubview(subtitleLabel)
        glassContainer.addSubview(detailLabel)
        glassContainer.addSubview(helperLabel)
    }

    private func configureStyle() {
        layer.shadowOpacity = 0

        AppTheme.styleOutline(glassContainer, radius: 24, color: AppTheme.studyLine)
        glassContainer.clipsToBounds = true

        blurView.contentView.backgroundColor = AppTheme.studyPaper

        highlightView.gradientLayer.needsDisplayOnBoundsChange = true
        highlightView.gradientLayer.colors = [UIColor.clear.cgColor, UIColor.clear.cgColor]
        highlightView.gradientLayer.locations = [0.0, 0.56]
        highlightView.gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        highlightView.gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        highlightView.isUserInteractionEnabled = false

        accentRuleView.isHidden = true

        stateBadgeLabel.font = AppTypography.font(size: 10.5, weight: .bold, textStyle: .caption2)
        stateBadgeLabel.textColor = AppTheme.studyInk
        stateBadgeLabel.backgroundColor = .clear
        AppTheme.styleOutline(stateBadgeLabel, radius: 11, color: AppTheme.studyLine)
        stateBadgeLabel.clipsToBounds = true
        stateBadgeLabel.textAlignment = .center

        titleLabel.font = AppTypography.display(size: 36, textStyle: .title1)
        titleLabel.textColor = AppTheme.studyInk
        titleLabel.numberOfLines = 0
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        titleLabel.setContentHuggingPriority(.defaultHigh, for: .vertical)

        subtitleLabel.font = AppTypography.displayItalic(size: 15)
        subtitleLabel.textColor = AppTheme.studyMuted
        subtitleLabel.numberOfLines = 1
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        detailLabel.font = AppTypography.font(size: 17, weight: .medium, textStyle: .body)
        detailLabel.textColor = AppTheme.studyInk
        detailLabel.numberOfLines = 0
        detailLabel.lineBreakMode = .byWordWrapping
        detailLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        detailLabel.setContentHuggingPriority(.defaultHigh, for: .vertical)

        helperLabel.font = AppTypography.font(size: 13, weight: .medium, textStyle: .footnote)
        helperLabel.textColor = AppTheme.studyMuted
        helperLabel.textAlignment = .left
        helperLabel.numberOfLines = 1
        helperLabel.lineBreakMode = .byTruncatingTail
        helperLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        helperLabel.text = FlashForgeStrings.StudyCard.helper

        applyTheme()
    }

    private func applyTheme() {
        glassContainer.layer.borderColor = AppTheme.studyLine.cgColor
        blurView.contentView.backgroundColor = AppTheme.studyPaper

        highlightView.gradientLayer.colors = [UIColor.clear.cgColor, UIColor.clear.cgColor]

        stateBadgeLabel.textColor = AppTheme.studyInk
        stateBadgeLabel.layer.borderColor = AppTheme.studyLine.cgColor

        titleLabel.textColor = AppTheme.studyInk
        subtitleLabel.textColor = AppTheme.studyMuted
        detailLabel.textColor = AppTheme.studyInk
        helperLabel.textColor = AppTheme.studyMuted
    }

    private func configureLayout() {
        glassContainer.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        blurView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        highlightView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        accentRuleView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(25)
            make.leading.equalToSuperview().inset(22)
            make.width.equalTo(3)
            make.height.equalTo(18)
        }

        stateBadgeLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(20)
            make.leading.equalToSuperview().inset(20)
            make.trailing.lessThanOrEqualToSuperview().inset(22)
            make.height.equalTo(22)
        }

        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(stateBadgeLabel.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(22)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(22)
        }

        detailLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(18)
            make.leading.trailing.equalTo(titleLabel)
            make.bottom.lessThanOrEqualToSuperview().inset(24)
        }

        helperLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(18)
            make.leading.trailing.equalTo(titleLabel)
            make.bottom.lessThanOrEqualToSuperview().inset(76)
        }
    }

    private func badgeText(for state: CardState) -> String {
        switch state {
        case .new:
            return FlashForgeStrings.StudyCard.Badge.new
        case .learning:
            return FlashForgeStrings.StudyCard.Badge.learning
        case .review:
            return FlashForgeStrings.StudyCard.Badge.review
        case .relearning:
            return FlashForgeStrings.StudyCard.Badge.relearning
        }
    }

    private func lineCount(in text: String) -> Int {
        let count = text
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .count
        return max(1, count)
    }

    private func titleFont(for text: String) -> UIFont {
        let length = text.count
        let lines = lineCount(in: text)
        let size: CGFloat

        if lines >= 6 || length >= 180 {
            size = 21
        } else if lines >= 5 || length >= 140 {
            size = 22
        } else if lines >= 4 || length >= 110 {
            size = 24
        } else if lines >= 3 || length >= 80 {
            size = 25
        } else if lines >= 2 || length >= 50 {
            size = 30
        } else {
            size = 38
        }

        return AppTypography.display(size: size, textStyle: .title1)
    }

    private func subtitleFont(for text: String) -> UIFont {
        let length = text.count
        let size: CGFloat = length >= 55 ? 14 : 15
        return AppTypography.displayItalic(size: size + 1)
    }

    private func detailFont(for text: String) -> UIFont {
        let length = text.count
        let lines = lineCount(in: text)
        let size: CGFloat

        if lines >= 12 || length >= 420 {
            size = 12
        } else if lines >= 9 || length >= 320 {
            size = 13
        } else if lines >= 7 || length >= 240 {
            size = 14
        } else if lines >= 5 || length >= 170 {
            size = 15
        } else if lines >= 3 || length >= 110 {
            size = 16
        } else {
            size = 17
        }

        return AppTypography.font(size: size, weight: .medium, textStyle: .body)
    }
}

private final class GradientOverlayView: UIView {
    override static var layerClass: AnyClass {
        CAGradientLayer.self
    }

    var gradientLayer: CAGradientLayer {
        guard let gradientLayer = layer as? CAGradientLayer else {
            fatalError("Unexpected layer type: \(type(of: layer))")
        }
        return gradientLayer
    }
}

private final class BadgeLabel: UILabel {
    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + 18, height: size.height)
    }
}
