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
    private let titleLabel = UILabel()
    private let deckButton = UIButton(type: .system)
    private let dueSummaryContainer = UIView()
    private let dueSummaryIconView = UIImageView()
    private let dueSummaryTextLabel = UILabel()
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
        brandRow.addArrangedSubview(brandMarkView)
        brandRow.addArrangedSubview(brandLabel)
        view.addSubview(titleLabel)
        view.addSubview(deckButton)
        view.addSubview(dueSummaryContainer)
        dueSummaryContainer.addSubview(dueSummaryIconView)
        dueSummaryContainer.addSubview(dueSummaryTextLabel)
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

        topGlowView.isHidden = false
        bottomGlowView.isHidden = false
        topGlowView.backgroundColor = AppTheme.accent.withAlphaComponent(0.12)
        topGlowView.layer.shadowColor = AppTheme.resolved(AppTheme.accent, for: traitCollection).cgColor
        topGlowView.layer.shadowOpacity = 0.18
        topGlowView.layer.shadowRadius = 64
        bottomGlowView.backgroundColor = AppTheme.accentTeal.withAlphaComponent(0.08)
        bottomGlowView.layer.shadowColor = AppTheme.resolved(AppTheme.accentTeal, for: traitCollection).cgColor
        bottomGlowView.layer.shadowOpacity = 0.14
        bottomGlowView.layer.shadowRadius = 64

        brandRow.axis = .horizontal
        brandRow.alignment = .center
        brandRow.spacing = 8

        brandMarkView.image = UIImage(systemName: "sparkles")
        brandMarkView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 13, weight: .bold)
        brandMarkView.tintColor = AppTheme.accent
        brandMarkView.contentMode = .scaleAspectFit

        brandLabel.text = FlashForgeStrings.Home.eyebrow
        brandLabel.font = AppTypography.font(size: 12, weight: .bold, textStyle: .caption1)
        brandLabel.textColor = AppTheme.accent
        AppTypography.applyTracking(1.8, to: brandLabel)

        titleLabel.text = FlashForgeStrings.Home.title
        titleLabel.font = AppTypography.font(
            size: 32,
            weight: .bold,
            textStyle: .largeTitle,
            maximumPointSize: 42
        )
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = AppTheme.textPrimary
        titleLabel.numberOfLines = 2

        var deckButtonConfiguration = UIButton.Configuration.plain()
        deckButtonConfiguration.image = UIImage(systemName: "chevron.down")
        deckButtonConfiguration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 10, weight: .bold)
        deckButtonConfiguration.imagePlacement = .trailing
        deckButtonConfiguration.imagePadding = 5
        deckButtonConfiguration.baseForegroundColor = AppTheme.textPrimary
        deckButtonConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 8)
        deckButtonConfiguration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var updated = attributes
            updated.font = AppTypography.font(size: 13, weight: .semibold, textStyle: .subheadline)
            return updated
        }
        deckButton.configuration = deckButtonConfiguration
        deckButton.layer.cornerRadius = 14
        deckButton.layer.cornerCurve = .continuous
        deckButton.layer.borderWidth = 1
        deckButton.layer.borderColor = AppTheme.cardBorder.cgColor
        deckButton.backgroundColor = AppTheme.cardBackground.withAlphaComponent(0.82)
        deckButton.showsMenuAsPrimaryAction = true
        deckButton.accessibilityIdentifier = "home.deckButton"
        setDeckButtonTitle(FlashForgeStrings.Home.Deck.select)

        dueSummaryContainer.backgroundColor = AppTheme.tealSoft
        dueSummaryContainer.layer.cornerRadius = 13
        dueSummaryContainer.layer.cornerCurve = .continuous
        dueSummaryContainer.layer.borderWidth = 0
        dueSummaryContainer.isUserInteractionEnabled = false

        dueSummaryIconView.image = UIImage(systemName: "clock.fill")
        dueSummaryIconView.tintColor = AppTheme.textSecondary
        dueSummaryIconView.contentMode = .scaleAspectFit

        dueSummaryTextLabel.font = AppTypography.font(size: 12, weight: .semibold, textStyle: .caption1)
        dueSummaryTextLabel.adjustsFontForContentSizeCategory = true
        dueSummaryTextLabel.textColor = AppTheme.textSecondary
        dueSummaryTextLabel.textAlignment = .left
        dueSummaryTextLabel.numberOfLines = 1
        dueSummaryTextLabel.lineBreakMode = .byTruncatingTail
        dueSummaryTextLabel.adjustsFontSizeToFitWidth = true
        dueSummaryTextLabel.minimumScaleFactor = 0.85
        dueSummaryTextLabel.text = FlashForgeStrings.Home.Due.none
        dueSummaryTextLabel.isUserInteractionEnabled = false

        cardBackdropView.backgroundColor = AppTheme.accentSoft.withAlphaComponent(0.78)
        cardBackdropView.layer.cornerRadius = 28
        cardBackdropView.layer.cornerCurve = .continuous
        cardBackdropView.layer.borderWidth = 1
        cardBackdropView.layer.borderColor = AppTheme.cardBorder.cgColor
        cardBackdropView.layer.shadowColor = AppTheme.shadowColor.cgColor
        cardBackdropView.layer.shadowOpacity = 0
        cardBackdropView.isUserInteractionEnabled = false

        revealAnswerButton.setTitle(FlashForgeStrings.Home.reveal, for: .normal)
        revealAnswerButton.setTitleColor(.white, for: .normal)
        revealAnswerButton.titleLabel?.font = AppTypography.font(size: 16, weight: .bold, textStyle: .headline)
        revealAnswerButton.titleLabel?.adjustsFontForContentSizeCategory = true
        revealAnswerButton.backgroundColor = AppTheme.buttonFill(from: AppTheme.accent, for: traitCollection)
        revealAnswerButton.layer.cornerRadius = 16
        revealAnswerButton.layer.cornerCurve = .continuous
        revealAnswerButton.layer.borderWidth = 0
        revealAnswerButton.layer.shadowColor = AppTheme.resolved(AppTheme.accent, for: traitCollection).cgColor
        revealAnswerButton.layer.shadowOpacity = 0.22
        revealAnswerButton.layer.shadowRadius = 14
        revealAnswerButton.layer.shadowOffset = CGSize(width: 0, height: 7)
        revealAnswerButton.addTarget(self, action: #selector(didTapRevealAnswer), for: .touchUpInside)
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

        AppTheme.styleSurface(emptyStateContainer, radius: 24, shadow: true)
        emptyStateContainer.isHidden = true

        emptyStateIconView.image = UIImage(systemName: "sparkles")
        emptyStateIconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 26, weight: .semibold)
        emptyStateIconView.tintColor = AppTheme.accent
        emptyStateIconView.backgroundColor = AppTheme.accentSoft
        emptyStateIconView.contentMode = .center
        emptyStateIconView.layer.cornerRadius = 24
        emptyStateIconView.layer.cornerCurve = .continuous

        emptyStateLabel.textAlignment = .left
        emptyStateLabel.numberOfLines = 4
        emptyStateLabel.font = AppTypography.font(size: 20, weight: .bold, textStyle: .title3)
        emptyStateLabel.adjustsFontForContentSizeCategory = true
        emptyStateLabel.textColor = AppTheme.textPrimary
        emptyStateLabel.isHidden = true

        reloadButton.setTitle(FlashForgeStrings.Home.reload, for: .normal)
        reloadButton.titleLabel?.font = AppTypography.font(size: 14, weight: .bold, textStyle: .headline)
        reloadButton.titleLabel?.adjustsFontForContentSizeCategory = true
        reloadButton.setTitleColor(.white, for: .normal)
        reloadButton.backgroundColor = AppTheme.inkSurface
        reloadButton.layer.cornerRadius = 14
        reloadButton.layer.cornerCurve = .continuous
        reloadButton.layer.borderWidth = 0
        reloadButton.isHidden = true
        reloadButton.addTarget(self, action: #selector(didTapReloadButton), for: .touchUpInside)

        loadingIndicator.color = AppTheme.textPrimary
        loadingIndicator.hidesWhenStopped = true

        applyTheme()
    }

    private func applyTheme() {
        AppTheme.applyGradient(to: backgroundGradientLayer, traitCollection: traitCollection)

        topGlowView.backgroundColor = AppTheme.accent.withAlphaComponent(0.12)
        topGlowView.layer.shadowColor = AppTheme.resolved(AppTheme.accent, for: traitCollection).cgColor
        bottomGlowView.backgroundColor = AppTheme.accentTeal.withAlphaComponent(0.08)
        bottomGlowView.layer.shadowColor = AppTheme.resolved(AppTheme.accentTeal, for: traitCollection).cgColor

        brandMarkView.tintColor = AppTheme.accent
        brandLabel.textColor = AppTheme.accent
        titleLabel.textColor = AppTheme.textPrimary

        if var configuration = deckButton.configuration {
            configuration.baseForegroundColor = AppTheme.textPrimary
            deckButton.configuration = configuration
        }
        deckButton.backgroundColor = AppTheme.cardBackground.withAlphaComponent(0.82)
        deckButton.layer.borderColor = AppTheme.resolved(AppTheme.cardBorder, for: traitCollection).cgColor

        dueSummaryIconView.tintColor = AppTheme.textSecondary
        dueSummaryTextLabel.textColor = AppTheme.textSecondary

        dueSummaryContainer.backgroundColor = AppTheme.tealSoft
        cardBackdropView.backgroundColor = AppTheme.accentSoft.withAlphaComponent(0.78)
        cardBackdropView.layer.borderColor = AppTheme.resolved(AppTheme.cardBorder, for: traitCollection).cgColor
        cardBackdropView.layer.shadowColor = AppTheme.resolved(AppTheme.shadowColor, for: traitCollection).cgColor

        revealAnswerButton.setTitleColor(.white, for: .normal)
        revealAnswerButton.backgroundColor = AppTheme.buttonFill(from: AppTheme.accent, for: traitCollection)
        revealAnswerButton.layer.shadowColor = AppTheme.resolved(AppTheme.accent, for: traitCollection).cgColor

        gradePromptLabel.textColor = AppTheme.textSecondary
        emptyStateLabel.textColor = AppTheme.textPrimary
        emptyStateContainer.backgroundColor = AppTheme.cardBackground
        emptyStateContainer.layer.borderColor = AppTheme.resolved(AppTheme.cardBorder, for: traitCollection).cgColor
        emptyStateContainer.layer.shadowColor = AppTheme.resolved(AppTheme.shadowColor, for: traitCollection).cgColor
        emptyStateIconView.backgroundColor = AppTheme.accentSoft
        emptyStateIconView.tintColor = AppTheme.accent

        reloadButton.setTitleColor(.white, for: .normal)
        reloadButton.backgroundColor = AppTheme.inkSurface

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
            make.top.equalTo(view.safeAreaLayoutGuide).offset(14)
            make.leading.equalToSuperview().inset(24)
            make.trailing.lessThanOrEqualToSuperview().inset(24)
        }

        brandMarkView.snp.makeConstraints { make in
            make.size.equalTo(18)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(brandRow.snp.bottom).offset(7)
            make.leading.equalToSuperview().inset(24)
            make.trailing.lessThanOrEqualToSuperview().inset(24)
        }

        deckButton.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(12)
            make.leading.equalToSuperview().inset(24)
            make.height.equalTo(34)
            make.width.greaterThanOrEqualTo(120)
            make.trailing.lessThanOrEqualToSuperview().inset(24)
        }

        dueSummaryContainer.snp.makeConstraints { make in
            make.top.equalTo(deckButton.snp.bottom).offset(8)
            make.leading.equalToSuperview().inset(24)
            make.trailing.lessThanOrEqualToSuperview().inset(24)
            make.height.equalTo(28)
        }

        dueSummaryIconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(10)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(11)
        }

        dueSummaryTextLabel.snp.makeConstraints { make in
            make.leading.equalTo(dueSummaryIconView.snp.trailing).offset(6)
            make.trailing.equalToSuperview().inset(10)
            make.centerY.equalTo(dueSummaryIconView.snp.centerY)
        }

        glassCardView.snp.makeConstraints { make in
            make.top.equalTo(dueSummaryContainer.snp.bottom).offset(14)
            make.leading.trailing.equalToSuperview().inset(24)
            cardHeightConstraint = make.height.equalTo(280).constraint
        }

        cardBackdropView.snp.makeConstraints { make in
            make.top.equalTo(glassCardView).offset(-8)
            make.leading.trailing.equalTo(glassCardView).inset(-6)
            make.bottom.equalTo(glassCardView).offset(10)
        }

        revealAnswerButton.snp.makeConstraints { make in
            make.top.equalTo(glassCardView.snp.bottom).offset(14)
            make.leading.trailing.equalToSuperview().inset(24)
            make.height.equalTo(52)
        }

        gradeStackView.snp.makeConstraints { make in
            make.top.equalTo(gradePromptLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(24)
            make.height.equalTo(96)
            make.bottom.lessThanOrEqualTo(view.safeAreaLayoutGuide).inset(12)
        }

        gradePromptLabel.snp.makeConstraints { make in
            make.top.equalTo(revealAnswerButton.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(24)
        }

        emptyStateContainer.snp.makeConstraints { make in
            make.top.equalTo(dueSummaryContainer.snp.bottom).offset(24)
            make.leading.trailing.equalToSuperview().inset(24)
            make.bottom.lessThanOrEqualTo(view.safeAreaLayoutGuide).inset(24)
        }

        emptyStateIconView.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().inset(22)
            make.size.equalTo(48)
        }

        emptyStateLabel.snp.makeConstraints { make in
            make.top.equalTo(emptyStateIconView.snp.bottom).offset(22)
            make.leading.trailing.equalToSuperview().inset(22)
        }

        reloadButton.snp.makeConstraints { make in
            make.top.equalTo(emptyStateLabel.snp.bottom).offset(22)
            make.leading.trailing.bottom.equalToSuperview().inset(22)
            make.height.equalTo(46)
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
        let widthBased = cardWidth * (isAnswerRevealed ? 0.95 : 0.86)
        let heightCap = max(isAnswerRevealed ? 292 : 250, availableHeight * (isAnswerRevealed ? 0.56 : 0.44))
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

        cardBackdropView.alpha = 0
        cardBackdropView.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
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
            self?.cardBackdropView.alpha = 1
            self?.cardBackdropView.transform = .identity
            self?.glassCardView.alpha = 1
            self?.glassCardView.transform = .identity
        }
    }

    private func showEmptyState(_ message: String) {
        cardBackdropView.isHidden = true
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
        dueSummaryIconView.image = UIImage(systemName: counts.total == 0 ? "checkmark.circle.fill" : "clock.fill")
        dueSummaryIconView.tintColor = counts.total == 0 ? AppTheme.accentTeal.withAlphaComponent(0.9) : AppTheme.textSecondary

        if counts.total == 0 {
            dueSummaryTextLabel.text = FlashForgeStrings.Home.Due.none
            return
        }

        if view.bounds.width <= 360 {
            dueSummaryTextLabel.text = FlashForgeStrings.Home.Due.Inline.compact(
                counts.total,
                counts.learning,
                counts.review
            )
        } else {
            dueSummaryTextLabel.text = FlashForgeStrings.Home.Due.inline(
                counts.total,
                counts.learning,
                counts.review
            )
        }
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
