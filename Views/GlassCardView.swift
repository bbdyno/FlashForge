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
    private let iconImageView = UIImageView()
    private let stateBadgeLabel = UILabel()
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

        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
        iconImageView.image = UIImage(systemName: card.imageName, withConfiguration: symbolConfig)
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
        glassContainer.addSubview(iconImageView)
        glassContainer.addSubview(stateBadgeLabel)
        glassContainer.addSubview(titleLabel)
        glassContainer.addSubview(subtitleLabel)
        glassContainer.addSubview(detailLabel)
        glassContainer.addSubview(helperLabel)
    }

    private func configureStyle() {
        layer.shadowColor = AppTheme.resolved(AppTheme.shadowColor, for: traitCollection).cgColor
        layer.shadowOpacity = 0.05
        layer.shadowRadius = 14
        layer.shadowOffset = CGSize(width: 0, height: 8)

        glassContainer.layer.cornerRadius = 18
        glassContainer.layer.cornerCurve = .continuous
        glassContainer.layer.borderWidth = 0.5
        glassContainer.layer.borderColor = AppTheme.resolved(AppTheme.glassBorder, for: traitCollection).cgColor
        glassContainer.clipsToBounds = true

        blurView.contentView.backgroundColor = AppTheme.glassFill

        highlightView.gradientLayer.needsDisplayOnBoundsChange = true
        highlightView.gradientLayer.colors = [UIColor.clear.cgColor, UIColor.clear.cgColor]
        highlightView.gradientLayer.locations = [0.0, 0.56]
        highlightView.gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        highlightView.gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        highlightView.isUserInteractionEnabled = false

        iconImageView.tintColor = AppTheme.accent
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.backgroundColor = AppTheme.inputBackground
        iconImageView.layer.cornerRadius = 13
        iconImageView.layer.cornerCurve = .continuous

        stateBadgeLabel.font = AppTypography.font(size: 11, weight: .bold, textStyle: .caption1)
        stateBadgeLabel.textColor = AppTheme.accent
        stateBadgeLabel.backgroundColor = AppTheme.badgeBackground
        stateBadgeLabel.layer.cornerRadius = 10
        stateBadgeLabel.layer.cornerCurve = .continuous
        stateBadgeLabel.layer.borderWidth = 0
        stateBadgeLabel.clipsToBounds = true
        stateBadgeLabel.textAlignment = .center

        titleLabel.font = AppTypography.font(size: 29, weight: .bold, textStyle: .title1)
        titleLabel.textColor = AppTheme.textPrimary
        titleLabel.numberOfLines = 0
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        titleLabel.setContentHuggingPriority(.defaultHigh, for: .vertical)

        subtitleLabel.font = AppTypography.font(size: 13, weight: .medium, textStyle: .subheadline)
        subtitleLabel.textColor = AppTheme.textSecondary.withAlphaComponent(0.95)
        subtitleLabel.numberOfLines = 1
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        detailLabel.font = AppTypography.font(size: 17, weight: .medium, textStyle: .body)
        detailLabel.textColor = AppTheme.textPrimary
        detailLabel.numberOfLines = 0
        detailLabel.lineBreakMode = .byWordWrapping
        detailLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        detailLabel.setContentHuggingPriority(.defaultHigh, for: .vertical)

        helperLabel.font = AppTypography.font(size: 13, weight: .medium, textStyle: .footnote)
        helperLabel.textColor = AppTheme.textSecondary.withAlphaComponent(0.95)
        helperLabel.textAlignment = .left
        helperLabel.numberOfLines = 1
        helperLabel.lineBreakMode = .byTruncatingTail
        helperLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        helperLabel.text = FlashForgeStrings.StudyCard.helper

        applyTheme()
    }

    private func applyTheme() {
        layer.shadowColor = AppTheme.resolved(AppTheme.shadowColor, for: traitCollection).cgColor
        glassContainer.layer.borderColor = AppTheme.resolved(AppTheme.glassBorder, for: traitCollection).cgColor
        blurView.contentView.backgroundColor = AppTheme.glassFill

        highlightView.gradientLayer.colors = [UIColor.clear.cgColor, UIColor.clear.cgColor]

        iconImageView.tintColor = AppTheme.accent
        iconImageView.backgroundColor = AppTheme.inputBackground

        stateBadgeLabel.textColor = AppTheme.accent
        stateBadgeLabel.backgroundColor = AppTheme.badgeBackground

        titleLabel.textColor = AppTheme.textPrimary
        subtitleLabel.textColor = AppTheme.textSecondary.withAlphaComponent(0.95)
        detailLabel.textColor = AppTheme.textPrimary
        helperLabel.textColor = AppTheme.textSecondary.withAlphaComponent(0.95)
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

        iconImageView.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().inset(22)
            make.size.equalTo(48)
        }

        stateBadgeLabel.snp.makeConstraints { make in
            make.centerY.equalTo(iconImageView)
            make.trailing.equalToSuperview().inset(22)
            make.width.greaterThanOrEqualTo(88)
            make.height.equalTo(22)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconImageView.snp.bottom).offset(26)
            make.leading.trailing.equalToSuperview().inset(22)
        }

        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(10)
            make.leading.trailing.equalTo(titleLabel)
        }

        detailLabel.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(18)
            make.leading.trailing.equalTo(titleLabel)
            make.bottom.lessThanOrEqualToSuperview().inset(24)
        }

        helperLabel.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(18)
            make.leading.trailing.equalTo(titleLabel)
            make.bottom.lessThanOrEqualToSuperview().inset(24)
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
            size = 27
        } else {
            size = 30
        }

        return AppTypography.font(size: size, weight: .bold, textStyle: .title1)
    }

    private func subtitleFont(for text: String) -> UIFont {
        let length = text.count
        let size: CGFloat = length >= 55 ? 14 : 15
        return AppTypography.font(size: size, weight: .semibold, textStyle: .subheadline)
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
