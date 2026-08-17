//
//  HomeViewController.swift
//  FlashForge
//
//  Created by bbdyno on 2/11/26.
//

import UIKit
import SnapKit

final class HomeViewController: UIViewController {
    private let repository: CardRepository

    private let backgroundGradientLayer = CAGradientLayer()
    private let topGlowView = UIView()
    private let bottomGlowView = UIView()

    private let brandRow = UIStackView()
    private let brandMarkView = UIImageView()
    private let brandLabel = UILabel()
    private let headerSpacer = UIView()
    private let dateLabel = UILabel()
    private let settingsButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let deckButton = UIButton(type: .system)
    private let deckChevronView = UIImageView()
    private let deckRuleView = UIView()
    private let dueSummaryContainer = UIView()
    private let dueSummaryIconView = UIImageView()
    private let dueSummaryTextLabel = UILabel()
    private let learningCountLabel = UILabel()
    private let learningCaptionLabel = UILabel()
    private let reviewCountLabel = UILabel()
    private let reviewCaptionLabel = UILabel()
    private let statsSeparatorView = UIView()
    private let cardSecondBackdropView = UIView()
    private let cardBackdropView = UIView()
    private let glassCardView = GlassCardView()
    private let revealAnswerButton = UIButton(type: .system)
    private let gradePromptLabel = UILabel()
    private let gradeStackView = UIStackView()
    private let emptyStateContainer = UIView()
    private let emptyStateIconView = UIImageView()
    private let emptyStateLabel = UILabel()
    private let reloadButton = UIButton(type: .system)
    private let loadingIndicator = UIActivityIndicatorView(style: .large)

    private lazy var viewModel: HomeViewModel = {
        let viewModel = HomeViewModel(repository: repository)
        viewModel.bind(output: makeOutput())
        return viewModel
    }()

    private var isAnswerRevealed = false
    private var selectedDeckID: UUID?
    private var deckSummaries: [DeckSummary] = []
    private var latestQueueCounts = QueueDueCounts(learning: 0, review: 0)
    private var cardHeightConstraint: Constraint?

    init(repository: CardRepository) {
        self.repository = repository
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .deckDataDidChange, object: nil)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        traitCollection.userInterfaceStyle == .dark ? .lightContent : .darkContent
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureHierarchy()
        configureStyle()
        configureLayout()
        configureGradeButtons()
        configureNotifications()
        requestInitialData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.viewModel.send(.didTapReload)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backgroundGradientLayer.frame = view.bounds
        topGlowView.layer.cornerRadius = topGlowView.bounds.height / 2
        bottomGlowView.layer.cornerRadius = bottomGlowView.bounds.height / 2
        updateCardHeightIfNeeded()
        updateDueSummaryDisplay(with: latestQueueCounts)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.hasDifferentColorAppearance(comparedTo: traitCollection) == true else {
            return
        }
        applyTheme()
        setNeedsStatusBarAppearanceUpdate()
    }

    private func makeOutput() -> HomeViewModel.Output {
        HomeViewModel.Output(
            didChangeLoading: { [weak self] isLoading in
                self?.updateLoadingState(isLoading)
            },
            didUpdateDeckSummaries: { [weak self] summaries, selectedDeckID in
                self?.applyDeckSummaries(summaries, selectedDeckID: selectedDeckID)
            },
            didUpdateQueueCounts: { [weak self] counts in
                self?.applyDueSummary(counts)
            },
            didUpdateCard: { [weak self] card in
                self?.render(card: card)
            },
            didShowEmptyState: { [weak self] message in
                self?.showEmptyState(message)
            },
            didReceiveError: { [weak self] message in
                self?.presentErrorAlert(message: message)
            }
        )
    }

    private func configureHierarchy() {
        view.layer.insertSublayer(backgroundGradientLayer, at: 0)

        view.addSubview(topGlowView)
        view.addSubview(bottomGlowView)
        view.addSubview(brandRow)
        brandRow.addArrangedSubview(brandLabel)
        brandRow.addArrangedSubview(headerSpacer)
        brandRow.addArrangedSubview(dateLabel)
        brandRow.addArrangedSubview(settingsButton)
        view.addSubview(titleLabel)
        view.addSubview(deckButton)
        view.addSubview(deckChevronView)
        view.addSubview(deckRuleView)
        view.addSubview(dueSummaryContainer)
        dueSummaryContainer.addSubview(dueSummaryIconView)
        dueSummaryContainer.addSubview(learningCountLabel)
        dueSummaryContainer.addSubview(learningCaptionLabel)
        dueSummaryContainer.addSubview(reviewCountLabel)
        dueSummaryContainer.addSubview(reviewCaptionLabel)
        dueSummaryContainer.addSubview(statsSeparatorView)
        view.addSubview(dueSummaryTextLabel)
        view.addSubview(cardSecondBackdropView)
        view.addSubview(cardBackdropView)
        view.addSubview(glassCardView)
        view.addSubview(revealAnswerButton)
        view.addSubview(gradePromptLabel)
        view.addSubview(gradeStackView)
        view.addSubview(emptyStateContainer)
        emptyStateContainer.addSubview(emptyStateIconView)
        emptyStateContainer.addSubview(emptyStateLabel)
        emptyStateContainer.addSubview(reloadButton)
        view.addSubview(loadingIndicator)
    }

    private func configureStyle() {
        AppTheme.applyGradient(to: backgroundGradientLayer, traitCollection: traitCollection)

        topGlowView.isHidden = true
        bottomGlowView.isHidden = true

        brandRow.axis = .horizontal
        brandRow.alignment = .center
        brandRow.spacing = 12

        brandLabel.text = "FlashForge"
        brandLabel.font = AppTypography.font(size: 24, weight: .bold, textStyle: .title2)
        brandLabel.textColor = AppTheme.textPrimary

        let dateFormatter = DateFormatter()
        dateFormatter.locale = .autoupdatingCurrent
        dateFormatter.setLocalizedDateFormatFromTemplate("MMM d")
        dateLabel.text = dateFormatter.string(from: .now).uppercased(with: .autoupdatingCurrent)
        dateLabel.font = AppTypography.font(size: 11, weight: .bold, textStyle: .caption1)
        dateLabel.textColor = AppTheme.textSecondary
        AppTypography.applyTracking(1.2, to: dateLabel)

        settingsButton.setImage(UIImage(systemName: "slider.horizontal.3"), for: .normal)
        settingsButton.setPreferredSymbolConfiguration(
            UIImage.SymbolConfiguration(pointSize: 17, weight: .medium),
            forImageIn: .normal
        )
        settingsButton.tintColor = AppTheme.textPrimary
        settingsButton.accessibilityLabel = FlashForgeStrings.More.title
        settingsButton.addTarget(self, action: #selector(didTapSettings), for: .touchUpInside)

        titleLabel.text = "0"
        titleLabel.font = AppTypography.font(
            size: 82,
            weight: .bold,
            textStyle: .largeTitle,
            maximumPointSize: 92
        )
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = AppTheme.textPrimary
        titleLabel.numberOfLines = 1

        var deckButtonConfiguration = UIButton.Configuration.plain()
        deckButtonConfiguration.baseForegroundColor = AppTheme.textPrimary
        deckButtonConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 1, bottom: 8, trailing: 1)
        deckButtonConfiguration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var updated = attributes
            updated.font = AppTypography.font(size: 13, weight: .semibold, textStyle: .subheadline)
            return updated
        }
        deckButton.configuration = deckButtonConfiguration
        deckButton.contentHorizontalAlignment = .leading
        deckButton.layer.cornerRadius = 0
        deckButton.layer.borderWidth = 0
        deckButton.backgroundColor = .clear
        deckButton.showsMenuAsPrimaryAction = true
        deckButton.accessibilityIdentifier = "home.deckButton"
        setDeckButtonTitle(FlashForgeStrings.Home.Deck.select)
        deckChevronView.image = UIImage(systemName: "chevron.right")
        deckChevronView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)
        deckChevronView.tintColor = AppTheme.textSecondary
        deckChevronView.contentMode = .scaleAspectFit
        deckChevronView.isUserInteractionEnabled = false
        deckRuleView.backgroundColor = AppTheme.cardBorder

        dueSummaryContainer.backgroundColor = .clear
        dueSummaryContainer.layer.cornerRadius = 0
        dueSummaryContainer.layer.cornerCurve = .continuous
        dueSummaryContainer.layer.borderWidth = 0
        dueSummaryContainer.isUserInteractionEnabled = false

        dueSummaryIconView.backgroundColor = AppTheme.cardBorder

        dueSummaryTextLabel.font = AppTypography.font(size: 13, weight: .medium, textStyle: .footnote)
        dueSummaryTextLabel.adjustsFontForContentSizeCategory = true
        dueSummaryTextLabel.textColor = AppTheme.textSecondary
        dueSummaryTextLabel.textAlignment = .left
        dueSummaryTextLabel.numberOfLines = 1
        dueSummaryTextLabel.lineBreakMode = .byTruncatingTail
        dueSummaryTextLabel.adjustsFontSizeToFitWidth = true
        dueSummaryTextLabel.minimumScaleFactor = 0.85
        dueSummaryTextLabel.text = FlashForgeStrings.Home.Due.caption
        dueSummaryTextLabel.isUserInteractionEnabled = false

        [learningCountLabel, reviewCountLabel].forEach { label in
            label.font = AppTypography.font(size: 25, weight: .bold, textStyle: .title2)
            label.textColor = AppTheme.textPrimary
            label.textAlignment = .left
        }
        [learningCaptionLabel, reviewCaptionLabel].forEach { label in
            label.font = AppTypography.font(size: 10, weight: .bold, textStyle: .caption2)
            label.textColor = AppTheme.textSecondary
            label.textAlignment = .left
        }
        learningCountLabel.text = "0"
        reviewCountLabel.text = "0"
        learningCaptionLabel.text = FlashForgeStrings.StudyCard.Badge.learning
        reviewCaptionLabel.text = FlashForgeStrings.StudyCard.Badge.review
        statsSeparatorView.backgroundColor = AppTheme.cardBorder

        [(cardSecondBackdropView, AppTheme.studyPaperTertiary), (cardBackdropView, AppTheme.studyPaperSecondary)].forEach { view, color in
            view.backgroundColor = color
            view.layer.cornerRadius = 22
            view.layer.cornerCurve = .continuous
            view.layer.borderWidth = 1.0 / UIScreen.main.scale
            view.layer.borderColor = AppTheme.studyLine.withAlphaComponent(0.45).cgColor
            view.layer.shadowOpacity = 0
            view.isUserInteractionEnabled = false
        }

        revealAnswerButton.setTitle(FlashForgeStrings.Home.reveal, for: .normal)
        revealAnswerButton.setTitleColor(.white, for: .normal)
        revealAnswerButton.titleLabel?.font = AppTypography.font(size: 16, weight: .bold, textStyle: .headline)
        revealAnswerButton.titleLabel?.adjustsFontForContentSizeCategory = true
        revealAnswerButton.backgroundColor = AppTheme.buttonFill(from: AppTheme.accent, for: traitCollection)
        revealAnswerButton.layer.cornerRadius = 22
        revealAnswerButton.layer.cornerCurve = .continuous
        revealAnswerButton.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        revealAnswerButton.layer.borderWidth = 0
        revealAnswerButton.layer.shadowOpacity = 0
        revealAnswerButton.addTarget(self, action: #selector(didTapRevealAnswer), for: .touchUpInside)
        revealAnswerButton.accessibilityIdentifier = "home.revealButton"
        revealAnswerButton.isHidden = true

        gradePromptLabel.text = FlashForgeStrings.Home.Grade.prompt
        gradePromptLabel.textColor = AppTheme.textSecondary
        gradePromptLabel.font = AppTypography.font(size: 14, weight: .semibold, textStyle: .subheadline)
        gradePromptLabel.adjustsFontForContentSizeCategory = true
        gradePromptLabel.textAlignment = .center
        gradePromptLabel.numberOfLines = 2
        gradePromptLabel.isHidden = true

        gradeStackView.axis = .horizontal
        gradeStackView.alignment = .fill
        gradeStackView.distribution = .fillEqually
        gradeStackView.spacing = 10
        gradeStackView.isHidden = true

        emptyStateContainer.backgroundColor = AppTheme.studyPaper
        emptyStateContainer.layer.cornerRadius = 22
        emptyStateContainer.layer.cornerCurve = .continuous
        emptyStateContainer.layer.borderWidth = 1.0 / UIScreen.main.scale
        emptyStateContainer.layer.borderColor = AppTheme.studyLine.withAlphaComponent(0.45).cgColor
        emptyStateContainer.clipsToBounds = true
        emptyStateContainer.isHidden = true

        emptyStateIconView.image = UIImage(systemName: "checkmark")
        emptyStateIconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        emptyStateIconView.tintColor = AppTheme.accent
        emptyStateIconView.backgroundColor = AppTheme.accent.withAlphaComponent(0.12)
        emptyStateIconView.contentMode = .center
        emptyStateIconView.layer.cornerRadius = 20
        emptyStateIconView.layer.cornerCurve = .continuous

        emptyStateLabel.textAlignment = .left
        emptyStateLabel.numberOfLines = 4
        emptyStateLabel.font = AppTypography.font(size: 20, weight: .bold, textStyle: .title3)
        emptyStateLabel.adjustsFontForContentSizeCategory = true
        emptyStateLabel.textColor = AppTheme.studyInk
        emptyStateLabel.isHidden = true

        reloadButton.setTitle(FlashForgeStrings.Home.reload, for: .normal)
        reloadButton.titleLabel?.font = AppTypography.font(size: 14, weight: .bold, textStyle: .headline)
        reloadButton.titleLabel?.adjustsFontForContentSizeCategory = true
        reloadButton.setTitleColor(.white, for: .normal)
        reloadButton.backgroundColor = AppTheme.accent
        reloadButton.layer.cornerRadius = 22
        reloadButton.layer.cornerCurve = .continuous
        reloadButton.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        reloadButton.layer.borderWidth = 0
        reloadButton.isHidden = true
        reloadButton.addTarget(self, action: #selector(didTapReloadButton), for: .touchUpInside)

        loadingIndicator.color = AppTheme.textPrimary
        loadingIndicator.hidesWhenStopped = true

        applyTheme()
    }

    private func applyTheme() {
        AppTheme.applyGradient(to: backgroundGradientLayer, traitCollection: traitCollection)

        brandLabel.textColor = AppTheme.textPrimary
        dateLabel.textColor = AppTheme.textSecondary
        settingsButton.tintColor = AppTheme.textPrimary
        titleLabel.textColor = AppTheme.textPrimary

        if var configuration = deckButton.configuration {
            configuration.baseForegroundColor = AppTheme.textPrimary
            deckButton.configuration = configuration
        }
        deckButton.backgroundColor = .clear
        deckRuleView.backgroundColor = AppTheme.cardBorder
        deckChevronView.tintColor = AppTheme.textSecondary

        dueSummaryIconView.backgroundColor = AppTheme.cardBorder
        dueSummaryTextLabel.textColor = AppTheme.textSecondary
        learningCountLabel.textColor = AppTheme.textPrimary
        reviewCountLabel.textColor = AppTheme.textPrimary
        learningCaptionLabel.textColor = AppTheme.textSecondary
        reviewCaptionLabel.textColor = AppTheme.textSecondary
        statsSeparatorView.backgroundColor = AppTheme.cardBorder

        dueSummaryContainer.backgroundColor = .clear
        cardSecondBackdropView.backgroundColor = AppTheme.studyPaperTertiary
        cardSecondBackdropView.layer.borderColor = AppTheme.studyLine.withAlphaComponent(0.45).cgColor
        cardBackdropView.backgroundColor = AppTheme.studyPaperSecondary
        cardBackdropView.layer.borderColor = AppTheme.studyLine.withAlphaComponent(0.45).cgColor

        revealAnswerButton.setTitleColor(.white, for: .normal)
        revealAnswerButton.backgroundColor = AppTheme.buttonFill(from: AppTheme.accent, for: traitCollection)

        gradePromptLabel.textColor = AppTheme.textSecondary
        emptyStateLabel.textColor = AppTheme.studyInk
        emptyStateContainer.backgroundColor = AppTheme.studyPaper
        emptyStateContainer.layer.borderColor = AppTheme.studyLine.withAlphaComponent(0.45).cgColor
        emptyStateIconView.backgroundColor = AppTheme.accent.withAlphaComponent(0.12)
        emptyStateIconView.tintColor = AppTheme.accent

        reloadButton.setTitleColor(.white, for: .normal)
        reloadButton.backgroundColor = AppTheme.accent

        loadingIndicator.color = AppTheme.textPrimary
        updateDueSummaryDisplay(with: latestQueueCounts)
    }

    private func configureLayout() {
        topGlowView.snp.makeConstraints { make in
            make.size.equalTo(280)
            make.top.equalTo(view.safeAreaLayoutGuide).offset(-110)
            make.trailing.equalToSuperview().offset(120)
        }

        bottomGlowView.snp.makeConstraints { make in
            make.size.equalTo(240)
            make.leading.equalToSuperview().offset(-120)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(90)
        }

        brandRow.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            make.leading.equalToSuperview().inset(24)
            make.trailing.equalToSuperview().inset(20)
            make.height.greaterThanOrEqualTo(32)
        }

        settingsButton.snp.makeConstraints { make in
            make.size.equalTo(32)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(brandRow.snp.bottom).offset(10)
            make.leading.equalToSuperview().inset(24)
            make.width.greaterThanOrEqualTo(118)
            make.height.equalTo(92)
        }

        dueSummaryTextLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(-9)
            make.leading.equalToSuperview().inset(24)
            make.trailing.lessThanOrEqualTo(dueSummaryContainer.snp.leading).offset(-16)
        }

        dueSummaryContainer.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.top).offset(5)
            make.leading.equalTo(view.snp.centerX).offset(14)
            make.trailing.equalToSuperview().inset(24)
            make.height.equalTo(92)
        }

        dueSummaryIconView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.top.bottom.equalToSuperview()
            make.width.equalTo(1.0 / UIScreen.main.scale)
        }

        learningCountLabel.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.equalTo(dueSummaryIconView.snp.trailing).offset(18)
        }

        learningCaptionLabel.snp.makeConstraints { make in
            make.leading.equalTo(learningCountLabel)
            make.top.equalTo(learningCountLabel.snp.bottom).offset(-1)
        }

        statsSeparatorView.snp.makeConstraints { make in
            make.leading.equalTo(dueSummaryIconView.snp.trailing).offset(18)
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
            make.height.equalTo(1.0 / UIScreen.main.scale)
        }

        reviewCountLabel.snp.makeConstraints { make in
            make.top.equalTo(statsSeparatorView.snp.bottom).offset(7)
            make.leading.equalTo(learningCountLabel)
        }

        reviewCaptionLabel.snp.makeConstraints { make in
            make.leading.equalTo(reviewCountLabel)
            make.top.equalTo(reviewCountLabel.snp.bottom).offset(-1)
        }

        deckButton.snp.makeConstraints { make in
            make.top.equalTo(dueSummaryContainer.snp.bottom).offset(14)
            make.leading.trailing.equalToSuperview().inset(24)
            make.height.equalTo(44)
        }

        deckRuleView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalTo(deckButton)
            make.height.equalTo(1.0 / UIScreen.main.scale)
        }

        deckChevronView.snp.makeConstraints { make in
            make.trailing.equalTo(deckButton)
            make.centerY.equalTo(deckButton)
            make.size.equalTo(18)
        }

        glassCardView.snp.makeConstraints { make in
            make.top.equalTo(deckButton.snp.bottom).offset(34)
            make.leading.trailing.equalToSuperview().inset(24)
            cardHeightConstraint = make.height.equalTo(292).constraint
        }

        cardSecondBackdropView.snp.makeConstraints { make in
            make.edges.equalTo(glassCardView)
        }

        cardBackdropView.snp.makeConstraints { make in
            make.edges.equalTo(glassCardView)
        }

        revealAnswerButton.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalTo(glassCardView)
            make.height.equalTo(56)
        }

        gradeStackView.snp.makeConstraints { make in
            make.top.equalTo(gradePromptLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(24)
            make.height.equalTo(96)
            make.bottom.lessThanOrEqualTo(view.safeAreaLayoutGuide).inset(12)
        }

        gradePromptLabel.snp.makeConstraints { make in
            make.top.equalTo(glassCardView.snp.bottom).offset(10)
            make.leading.trailing.equalToSuperview().inset(24)
        }

        emptyStateContainer.snp.makeConstraints { make in
            make.edges.equalTo(glassCardView)
        }

        emptyStateIconView.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().inset(20)
            make.size.equalTo(40)
        }

        emptyStateLabel.snp.makeConstraints { make in
            make.top.equalTo(emptyStateIconView.snp.bottom).offset(20)
            make.leading.trailing.equalToSuperview().inset(20)
        }

        reloadButton.snp.makeConstraints { make in
            make.top.greaterThanOrEqualTo(emptyStateLabel.snp.bottom).offset(20)
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(56)
        }

        loadingIndicator.snp.makeConstraints { make in
            make.center.equalTo(glassCardView)
        }
    }

    private func configureGradeButtons() {
        let configs: [(title: String, subtitle: String, grade: UserGrade, tint: UIColor)] = [
            (FlashForgeStrings.Home.Grade.Again.title, FlashForgeStrings.Home.Grade.Again.subtitle, .again, AppTheme.gradeAgain),
            (FlashForgeStrings.Home.Grade.Hard.title, FlashForgeStrings.Home.Grade.Hard.subtitle, .hard, AppTheme.gradeHard),
            (FlashForgeStrings.Home.Grade.Good.title, FlashForgeStrings.Home.Grade.Good.subtitle, .good, AppTheme.gradeGood),
            (FlashForgeStrings.Home.Grade.Easy.title, FlashForgeStrings.Home.Grade.Easy.subtitle, .easy, AppTheme.gradeEasy)
        ]

        let topRow = UIStackView()
        topRow.axis = .horizontal
        topRow.alignment = .fill
        topRow.distribution = .fillEqually
        topRow.spacing = 10

        let bottomRow = UIStackView()
        bottomRow.axis = .horizontal
        bottomRow.alignment = .fill
        bottomRow.distribution = .fillEqually
        bottomRow.spacing = 10

        gradeStackView.axis = .vertical
        gradeStackView.alignment = .fill
        gradeStackView.distribution = .fillEqually
        gradeStackView.spacing = 10
        gradeStackView.addArrangedSubview(topRow)
        gradeStackView.addArrangedSubview(bottomRow)

        configs.forEach { config in
            let button = UIButton(type: .system)
            var buttonConfig = UIButton.Configuration.filled()
            buttonConfig.title = config.title
            buttonConfig.subtitle = config.subtitle
            buttonConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var updated = attributes
                updated.font = AppTypography.font(size: 15, weight: .bold, textStyle: .headline)
                return updated
            }
            buttonConfig.subtitleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var updated = attributes
                updated.font = AppTypography.font(size: 11, weight: .medium, textStyle: .caption1)
                return updated
            }
            buttonConfig.titleAlignment = .center
            buttonConfig.titlePadding = 2
            buttonConfig.baseForegroundColor = .white
            buttonConfig.baseBackgroundColor = config.tint
            buttonConfig.cornerStyle = .medium
            buttonConfig.contentInsets = NSDirectionalEdgeInsets(top: 9, leading: 8, bottom: 9, trailing: 8)
            buttonConfig.background.strokeWidth = 1
            buttonConfig.background.strokeColor = UIColor.white.withAlphaComponent(0.16)
            button.configuration = buttonConfig
            button.tag = config.grade.rawValue
            button.accessibilityIdentifier = "home.grade.\(config.grade.rawValue)"
            button.addTarget(self, action: #selector(didTapGradeButton(_:)), for: .touchUpInside)
            if config.grade == .again || config.grade == .hard {
                topRow.addArrangedSubview(button)
            } else {
                bottomRow.addArrangedSubview(button)
            }
        }

        glassCardView.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapRevealAnswer))
        glassCardView.addGestureRecognizer(tap)
    }

    private func configureNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleDeckDataDidChange), name: .deckDataDidChange, object: nil)
    }

    private func requestInitialData() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.viewModel.send(.viewDidLoad)
        }
    }

    private func updateCardHeightIfNeeded(animated: Bool = false) {
        let availableHeight = view.safeAreaLayoutGuide.layoutFrame.height
        let cardWidth = max(220, view.bounds.width - 48)
        let widthBased = cardWidth * (isAnswerRevealed ? 0.96 : 0.86)
        let heightCap = max(isAnswerRevealed ? 314 : 286, availableHeight * (isAnswerRevealed ? 0.45 : 0.39))
        let targetHeight = min(widthBased, heightCap)
        cardHeightConstraint?.update(offset: targetHeight)

        guard animated else {
            return
        }
        UIView.animate(
            withDuration: 0.22,
            delay: 0,
            options: [.allowUserInteraction, .curveEaseInOut]
        ) { [weak self] in
            self?.view.layoutIfNeeded()
        }
    }

    @objc
    private func handleDeckDataDidChange() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.viewModel.send(.didReceiveExternalDataChange)
        }
    }

    private func applyDeckSummaries(_ summaries: [DeckSummary], selectedDeckID: UUID?) {
        deckSummaries = summaries
        self.selectedDeckID = selectedDeckID

        if let selectedDeckID,
           let summary = summaries.first(where: { $0.id == selectedDeckID }) {
            setDeckButtonTitle(summary.title)
        } else {
            setDeckButtonTitle(FlashForgeStrings.Home.Deck.select)
        }

        rebuildDeckMenu()
    }

    private func rebuildDeckMenu() {
        guard !deckSummaries.isEmpty else {
            deckButton.menu = nil
            return
        }

        let actions = deckSummaries.map { summary in
            UIAction(title: summary.title, state: summary.id == selectedDeckID ? .on : .off) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.selectedDeckID = summary.id
                    self.setDeckButtonTitle(summary.title)
                    self.rebuildDeckMenu()
                    await self.viewModel.send(.didSelectDeck(summary.id))
                }
            }
        }
        deckButton.menu = UIMenu(title: FlashForgeStrings.Home.Deck.select, children: actions)
    }

    private func render(card: StudyCard) {
        glassCardView.configure(with: card)
        glassCardView.setFace(.front, animated: false)
        setDeckButtonTitle(card.deckTitle)
        isAnswerRevealed = false
        updateCardHeightIfNeeded()

        cardBackdropView.isHidden = false
        cardSecondBackdropView.isHidden = false
        glassCardView.isHidden = false
        revealAnswerButton.isHidden = false
        revealAnswerButton.alpha = 1
        gradePromptLabel.isHidden = true
        gradePromptLabel.alpha = 0
        gradeStackView.isHidden = true
        gradeStackView.alpha = 0
        emptyStateContainer.isHidden = true
        emptyStateLabel.isHidden = true
        reloadButton.isHidden = true

        cardSecondBackdropView.alpha = 0
        cardBackdropView.alpha = 0
        let secondBackdropTransform = CGAffineTransform(translationX: 0, y: -22)
            .scaledBy(x: 0.88, y: 1)
        let restingBackdropTransform = CGAffineTransform(translationX: 0, y: -11)
            .scaledBy(x: 0.94, y: 1)
        cardSecondBackdropView.transform = secondBackdropTransform.scaledBy(x: 0.98, y: 0.98)
        cardBackdropView.transform = restingBackdropTransform.scaledBy(x: 0.98, y: 0.98)
        glassCardView.alpha = 0
        glassCardView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        glassCardView.layer.transform = CATransform3DIdentity

        UIView.animate(
            withDuration: 0.42,
            delay: 0,
            usingSpringWithDamping: 0.84,
            initialSpringVelocity: 0.9,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) { [weak self] in
            self?.cardSecondBackdropView.alpha = 1
            self?.cardSecondBackdropView.transform = secondBackdropTransform
            self?.cardBackdropView.alpha = 1
            self?.cardBackdropView.transform = restingBackdropTransform
            self?.glassCardView.alpha = 1
            self?.glassCardView.transform = .identity
        }
    }

    private func showEmptyState(_ message: String) {
        let secondBackdropTransform = CGAffineTransform(translationX: 0, y: -22)
            .scaledBy(x: 0.88, y: 1)
        let firstBackdropTransform = CGAffineTransform(translationX: 0, y: -11)
            .scaledBy(x: 0.94, y: 1)
        cardSecondBackdropView.isHidden = false
        cardSecondBackdropView.alpha = 1
        cardSecondBackdropView.transform = secondBackdropTransform
        cardBackdropView.isHidden = false
        cardBackdropView.alpha = 1
        cardBackdropView.transform = firstBackdropTransform
        glassCardView.isHidden = true
        revealAnswerButton.isHidden = true
        gradeStackView.isHidden = true
        gradePromptLabel.isHidden = true
        emptyStateContainer.isHidden = false
        emptyStateLabel.isHidden = false
        reloadButton.isHidden = false
        emptyStateLabel.text = message
        reloadButton.setTitle(
            deckSummaries.isEmpty ? FlashForgeStrings.Home.openLibrary : FlashForgeStrings.Home.reload,
            for: .normal
        )
        emptyStateIconView.image = UIImage(
            systemName: deckSummaries.isEmpty ? "rectangle.stack.badge.plus" : "checkmark"
        )
    }

    private func updateLoadingState(_ isLoading: Bool) {
        if isLoading {
            loadingIndicator.startAnimating()
            gradeStackView.isUserInteractionEnabled = false
            revealAnswerButton.isEnabled = false
            deckButton.isEnabled = false
        } else {
            loadingIndicator.stopAnimating()
            gradeStackView.isUserInteractionEnabled = true
            revealAnswerButton.isEnabled = true
            deckButton.isEnabled = true
        }
    }

    private func setDeckButtonTitle(_ title: String) {
        var configuration = deckButton.configuration ?? .plain()
        configuration.title = title
        deckButton.configuration = configuration
    }

    private func applyDueSummary(_ counts: QueueDueCounts) {
        latestQueueCounts = counts
        updateDueSummaryDisplay(with: counts)
    }

    private func updateDueSummaryDisplay(with counts: QueueDueCounts) {
        titleLabel.text = String(counts.total)
        dueSummaryTextLabel.text = FlashForgeStrings.Home.Due.caption
        learningCountLabel.text = String(counts.learning)
        reviewCountLabel.text = String(counts.review)
    }

    private func presentErrorAlert(message: String) {
        guard presentedViewController == nil else {
            return
        }

        let alert = UIAlertController(title: FlashForgeStrings.Home.Error.title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: FlashForgeStrings.Home.Error.close, style: .cancel))
        alert.addAction(UIAlertAction(title: FlashForgeStrings.Home.Error.retry, style: .default, handler: { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.viewModel.send(.didTapReload)
            }
        }))
        present(alert, animated: true)
    }

    @objc
    private func didTapReloadButton() {
        if deckSummaries.isEmpty {
            tabBarController?.selectedIndex = 1
            return
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.viewModel.send(.didTapReload)
        }
    }

    @objc
    private func didTapSettings() {
        let settings = MoreViewController(repository: repository)
        let navigationController = UINavigationController(rootViewController: settings)
        let navigationAppearance = AppTheme.makeNavigationAppearance()
        navigationController.navigationBar.standardAppearance = navigationAppearance
        navigationController.navigationBar.scrollEdgeAppearance = navigationAppearance
        navigationController.navigationBar.tintColor = AppTheme.textPrimary
        settings.navigationItem.leftBarButtonItem = UIBarButtonItem(
            systemItem: .close,
            primaryAction: UIAction { [weak navigationController] _ in
                navigationController?.dismiss(animated: true)
            }
        )
        navigationController.modalPresentationStyle = .pageSheet
        present(navigationController, animated: true)
    }

    @objc
    private func didTapGradeButton(_ sender: UIButton) {
        guard isAnswerRevealed, let grade = UserGrade(rawValue: sender.tag) else {
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.viewModel.send(.didSelectGrade(grade))
        }
    }

    @objc
    private func didTapRevealAnswer() {
        guard !glassCardView.isHidden, !isAnswerRevealed else {
            return
        }
        isAnswerRevealed = true
        glassCardView.setFace(.back, animated: true)
        gradePromptLabel.isHidden = false
        gradeStackView.isHidden = false
        updateCardHeightIfNeeded(animated: true)

        UIView.animate(
            withDuration: 0.18,
            delay: 0,
            options: [.curveEaseOut, .allowUserInteraction]
        ) { [weak self] in
            self?.revealAnswerButton.alpha = 0
        } completion: { [weak self] _ in
            self?.revealAnswerButton.isHidden = true
        }

        UIView.animate(
            withDuration: 0.24,
            delay: 0.06,
            options: [.curveEaseOut, .allowUserInteraction]
        ) { [weak self] in
            self?.gradePromptLabel.alpha = 1
            self?.gradeStackView.alpha = 1
        }
    }

}
