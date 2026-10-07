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

    private let headerRow = UIStackView()
    private let headerSpacer = UIView()
    private let deckButton = UIButton(type: .system)
    private let settingsButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let dueSummaryTextLabel = UILabel()
    private let queueSummaryLabel = UILabel()
    private let progressTrackView = UIView()
    private let progressFillView = UIView()
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
    private var completedToday = 0
    private var cardHeightConstraint: Constraint?
    private var progressFillConstraint: Constraint?
    private let contentGuide = UILayoutGuide()
    private static let maximumContentWidth: CGFloat = 620

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
            didUpdateCompletedToday: { [weak self] count in
                self?.completedToday = count
                self?.updateProgress(animated: true)
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
        view.addSubview(headerRow)
        headerRow.addArrangedSubview(deckButton)
        headerRow.addArrangedSubview(headerSpacer)
        headerRow.addArrangedSubview(settingsButton)
        view.addSubview(titleLabel)
        view.addSubview(dueSummaryTextLabel)
        view.addSubview(queueSummaryLabel)
        view.addSubview(progressTrackView)
        progressTrackView.addSubview(progressFillView)
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
        headerRow.axis = .horizontal
        headerRow.alignment = .center
        headerRow.spacing = 12

        var deckButtonConfiguration = UIButton.Configuration.filled()
        deckButtonConfiguration.image = AppIcon.image("caret-down.bold", size: 12)
        deckButtonConfiguration.imagePlacement = .trailing
        deckButtonConfiguration.imagePadding = 7
        deckButtonConfiguration.cornerStyle = .capsule
        deckButtonConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 15, bottom: 10, trailing: 14)
        deckButtonConfiguration.titleLineBreakMode = .byTruncatingTail
        deckButtonConfiguration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var updated = attributes
            updated.font = AppTypography.font(size: 14, weight: .bold, textStyle: .subheadline)
            return updated
        }
        deckButtonConfiguration.background.strokeWidth = AppTheme.outlineWidth
        deckButton.configuration = deckButtonConfiguration
        deckButton.showsMenuAsPrimaryAction = true
        deckButton.accessibilityIdentifier = "home.deckButton"
        deckButton.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setDeckButtonTitle(FlashForgeStrings.Home.Deck.select)

        settingsButton.setImage(AppIcon.image("sliders-horizontal", size: 20), for: .normal)
        settingsButton.accessibilityLabel = FlashForgeStrings.More.title
        settingsButton.addTarget(self, action: #selector(didTapSettings), for: .touchUpInside)

        titleLabel.text = "0"
        titleLabel.font = AppTypography.display(size: 64, textStyle: .largeTitle, maximumPointSize: 76)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 1

        dueSummaryTextLabel.font = AppTypography.font(size: 13, weight: .semibold, textStyle: .footnote)
        dueSummaryTextLabel.adjustsFontForContentSizeCategory = true
        dueSummaryTextLabel.numberOfLines = 1
        dueSummaryTextLabel.adjustsFontSizeToFitWidth = true
        dueSummaryTextLabel.minimumScaleFactor = 0.85
        dueSummaryTextLabel.text = FlashForgeStrings.Home.Due.caption

        queueSummaryLabel.font = AppTypography.font(size: 13, weight: .semibold, textStyle: .footnote)
        queueSummaryLabel.adjustsFontForContentSizeCategory = true
        queueSummaryLabel.textAlignment = .right
        queueSummaryLabel.numberOfLines = 1

        progressTrackView.layer.cornerRadius = 5
        progressTrackView.layer.cornerCurve = .continuous
        progressTrackView.isAccessibilityElement = false
        progressFillView.backgroundColor = AppTheme.lime
        progressFillView.layer.cornerRadius = 3.5
        progressFillView.layer.cornerCurve = .continuous

        [(cardSecondBackdropView, AppTheme.studyPaperTertiary), (cardBackdropView, AppTheme.studyPaperSecondary)].forEach { view, color in
            view.backgroundColor = color
            AppTheme.styleOutline(view, radius: 24, color: AppTheme.studyLine)
            view.isUserInteractionEnabled = false
        }

        revealAnswerButton.setTitle(FlashForgeStrings.Home.reveal, for: .normal)
        revealAnswerButton.titleLabel?.font = AppTypography.font(size: 16, weight: .bold, textStyle: .headline)
        revealAnswerButton.titleLabel?.adjustsFontForContentSizeCategory = true
        revealAnswerButton.layer.cornerRadius = 27
        revealAnswerButton.layer.cornerCurve = .continuous
        revealAnswerButton.addTarget(self, action: #selector(didTapRevealAnswer), for: .touchUpInside)
        revealAnswerButton.accessibilityIdentifier = "home.revealButton"
        revealAnswerButton.isHidden = true

        gradePromptLabel.text = FlashForgeStrings.Home.Grade.prompt
        gradePromptLabel.font = AppTypography.font(size: 13, weight: .semibold, textStyle: .footnote)
        gradePromptLabel.adjustsFontForContentSizeCategory = true
        gradePromptLabel.textAlignment = .center
        gradePromptLabel.numberOfLines = 2
        gradePromptLabel.isHidden = true

        gradeStackView.axis = .horizontal
        gradeStackView.alignment = .fill
        gradeStackView.distribution = .fillEqually
        gradeStackView.spacing = 8
        gradeStackView.isHidden = true

        emptyStateContainer.backgroundColor = AppTheme.studyPaper
        AppTheme.styleOutline(emptyStateContainer, radius: 24, color: AppTheme.studyLine)
        emptyStateContainer.clipsToBounds = true
        emptyStateContainer.isHidden = true

        emptyStateIconView.image = AppIcon.image("check.bold", size: 20)
        emptyStateIconView.tintColor = AppTheme.studyInk
        emptyStateIconView.backgroundColor = AppTheme.lime
        emptyStateIconView.contentMode = .center
        AppTheme.styleOutline(emptyStateIconView, radius: 22, color: AppTheme.studyLine)

        emptyStateLabel.textAlignment = .left
        emptyStateLabel.numberOfLines = 4
        emptyStateLabel.font = AppTypography.display(size: 24, textStyle: .title2)
        emptyStateLabel.adjustsFontForContentSizeCategory = true
        emptyStateLabel.textColor = AppTheme.studyInk
        emptyStateLabel.isHidden = true

        reloadButton.setTitle(FlashForgeStrings.Home.reload, for: .normal)
        reloadButton.titleLabel?.font = AppTypography.font(size: 15, weight: .bold, textStyle: .headline)
        reloadButton.titleLabel?.adjustsFontForContentSizeCategory = true
        reloadButton.setTitleColor(AppTheme.onInk, for: .normal)
        reloadButton.backgroundColor = AppTheme.studyInk
        reloadButton.layer.cornerRadius = 25
        reloadButton.layer.cornerCurve = .continuous
        reloadButton.isHidden = true
        reloadButton.addTarget(self, action: #selector(didTapReloadButton), for: .touchUpInside)

        loadingIndicator.hidesWhenStopped = true

        applyTheme()
    }

    private func applyTheme() {
        updateCanvasColor()

        if var configuration = deckButton.configuration {
            configuration.baseForegroundColor = AppTheme.textPrimary
            configuration.baseBackgroundColor = AppTheme.cardBackground
            configuration.background.strokeColor = AppTheme.cardBorder
            deckButton.configuration = configuration
        }
        settingsButton.tintColor = AppTheme.textPrimary
        settingsButton.layer.cornerRadius = 20
        settingsButton.layer.borderWidth = AppTheme.outlineWidth
        settingsButton.layer.borderColor = AppTheme.resolved(AppTheme.cardBorder, for: traitCollection).cgColor

        titleLabel.textColor = AppTheme.textPrimary
        // Secondary grey loses contrast on a colour field, so captions use the
        // primary ink at reduced strength instead.
        dueSummaryTextLabel.textColor = AppTheme.textPrimary.withAlphaComponent(0.66)
        queueSummaryLabel.textColor = AppTheme.textPrimary.withAlphaComponent(0.66)
        gradePromptLabel.textColor = AppTheme.textPrimary.withAlphaComponent(0.66)
        progressTrackView.backgroundColor = AppTheme.inkSurface

        revealAnswerButton.setTitleColor(AppTheme.onEmphasis, for: .normal)
        revealAnswerButton.backgroundColor = AppTheme.emphasisFill

        gradeStackView.arrangedSubviews.compactMap { $0 as? UIButton }.forEach(applyGradeButtonTheme)
        loadingIndicator.color = AppTheme.studyInk
        updateDueSummaryDisplay(with: latestQueueCounts)
    }

    private func configureLayout() {
        // On iPad the study column keeps a phone-like measure instead of
        // stretching the card across the whole screen.
        view.addLayoutGuide(contentGuide)
        contentGuide.snp.makeConstraints { make in
            make.top.bottom.centerX.equalToSuperview()
            make.width.lessThanOrEqualTo(Self.maximumContentWidth)
            make.width.equalToSuperview().priority(.high)
        }

        headerRow.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(12)
            make.leading.trailing.equalTo(contentGuide).inset(20)
            make.height.equalTo(40)
        }

        settingsButton.snp.makeConstraints { make in
            make.size.equalTo(40)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(headerRow.snp.bottom).offset(18)
            make.leading.equalTo(contentGuide).inset(22)
        }

        dueSummaryTextLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(-6)
            make.leading.equalTo(contentGuide).inset(24)
        }

        queueSummaryLabel.snp.makeConstraints { make in
            make.firstBaseline.equalTo(dueSummaryTextLabel)
            make.trailing.equalTo(contentGuide).inset(24)
            make.leading.greaterThanOrEqualTo(dueSummaryTextLabel.snp.trailing).offset(12)
        }

        progressTrackView.snp.makeConstraints { make in
            make.top.equalTo(dueSummaryTextLabel.snp.bottom).offset(12)
            make.leading.trailing.equalTo(contentGuide).inset(22)
            make.height.equalTo(10)
        }

        progressFillView.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview().inset(1.5)
            progressFillConstraint = make.width.equalTo(0).constraint
        }

        glassCardView.snp.makeConstraints { make in
            make.top.equalTo(progressTrackView.snp.bottom).offset(34)
            make.leading.trailing.equalTo(contentGuide).inset(24)
            cardHeightConstraint = make.height.equalTo(292).constraint
        }

        cardSecondBackdropView.snp.makeConstraints { make in
            make.edges.equalTo(glassCardView)
        }

        cardBackdropView.snp.makeConstraints { make in
            make.edges.equalTo(glassCardView)
        }

        revealAnswerButton.snp.makeConstraints { make in
            make.top.equalTo(glassCardView.snp.bottom).offset(22)
            make.leading.trailing.equalTo(contentGuide).inset(24)
            make.height.equalTo(54)
        }

        gradePromptLabel.snp.makeConstraints { make in
            make.top.equalTo(glassCardView.snp.bottom).offset(12)
            make.leading.trailing.equalTo(contentGuide).inset(24)
        }

        gradeStackView.snp.makeConstraints { make in
            make.top.equalTo(gradePromptLabel.snp.bottom).offset(8)
            make.leading.trailing.equalTo(contentGuide).inset(20)
            make.height.equalTo(60)
            make.bottom.lessThanOrEqualTo(view.safeAreaLayoutGuide).inset(8)
        }

        emptyStateContainer.snp.makeConstraints { make in
            make.edges.equalTo(glassCardView)
        }

        emptyStateIconView.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().inset(20)
            make.size.equalTo(44)
        }

        emptyStateLabel.snp.makeConstraints { make in
            make.top.equalTo(emptyStateIconView.snp.bottom).offset(18)
            make.leading.trailing.equalToSuperview().inset(20)
        }

        reloadButton.snp.makeConstraints { make in
            make.top.greaterThanOrEqualTo(emptyStateLabel.snp.bottom).offset(16)
            make.leading.trailing.bottom.equalToSuperview().inset(16)
            make.height.equalTo(50)
        }

        loadingIndicator.snp.makeConstraints { make in
            make.center.equalTo(glassCardView)
        }
    }

    private func configureGradeButtons() {
        let configs: [(title: String, subtitle: String, grade: UserGrade)] = [
            (FlashForgeStrings.Home.Grade.Again.title, FlashForgeStrings.Home.Grade.Again.subtitle, .again),
            (FlashForgeStrings.Home.Grade.Hard.title, FlashForgeStrings.Home.Grade.Hard.subtitle, .hard),
            (FlashForgeStrings.Home.Grade.Good.title, FlashForgeStrings.Home.Grade.Good.subtitle, .good),
            (FlashForgeStrings.Home.Grade.Easy.title, FlashForgeStrings.Home.Grade.Easy.subtitle, .easy)
        ]

        configs.forEach { config in
            let button = UIButton(type: .system)
            var buttonConfig = UIButton.Configuration.filled()
            buttonConfig.title = config.title
            buttonConfig.subtitle = config.subtitle
            buttonConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var updated = attributes
                updated.font = AppTypography.font(size: 14, weight: .bold, textStyle: .subheadline, maximumPointSize: 18)
                return updated
            }
            buttonConfig.subtitleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var updated = attributes
                updated.font = AppTypography.font(size: 10.5, weight: .semibold, textStyle: .caption2, maximumPointSize: 13)
                return updated
            }
            buttonConfig.titleAlignment = .center
            buttonConfig.titleLineBreakMode = .byTruncatingTail
            buttonConfig.subtitleLineBreakMode = .byTruncatingTail
            buttonConfig.titlePadding = 1
            buttonConfig.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4)
            buttonConfig.background.cornerRadius = 18
            buttonConfig.background.strokeWidth = AppTheme.outlineWidth
            buttonConfig.cornerStyle = .fixed
            button.configuration = buttonConfig
            button.tag = config.grade.rawValue
            button.accessibilityIdentifier = "home.grade.\(config.grade.rawValue)"
            button.addTarget(self, action: #selector(didTapGradeButton(_:)), for: .touchUpInside)
            applyGradeButtonTheme(button)
            gradeStackView.addArrangedSubview(button)
        }

        glassCardView.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapRevealAnswer))
        glassCardView.addGestureRecognizer(tap)
    }

    // "Good" is the expected answer, so it is the one filled button in the row.
    private func applyGradeButtonTheme(_ button: UIButton) {
        guard var configuration = button.configuration else {
            return
        }
        let isDefault = button.tag == UserGrade.good.rawValue
        configuration.baseBackgroundColor = isDefault ? AppTheme.emphasisFill : AppTheme.studyPaper
        configuration.baseForegroundColor = isDefault ? AppTheme.onEmphasis : AppTheme.studyInk
        configuration.background.strokeColor = AppTheme.studyLine
        button.configuration = configuration
    }

    private func updateCanvasColor() {
        let colors = AppTheme.fieldColors(for: deckSummaries.map(\.id))
        view.backgroundColor = AppTheme.canvasColor(for: selectedDeckID.flatMap { colors[$0] })
    }

    private func updateProgress(animated: Bool) {
        let total = completedToday + latestQueueCounts.total
        let fraction = total > 0 ? CGFloat(completedToday) / CGFloat(total) : 0
        let available = max(0, progressTrackView.bounds.width - 3)
        progressFillConstraint?.update(offset: available * fraction)
        progressFillView.isHidden = fraction == 0
        guard animated, !UIAccessibility.isReduceMotionEnabled else {
            return
        }
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseOut, .beginFromCurrentState]) { [weak self] in
            self?.progressTrackView.layoutIfNeeded()
        }
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

    // The two sheets behind the card sit slightly askew, like a loose pile.
    private static let secondBackdropTransform = CGAffineTransform(rotationAngle: 3.2 * .pi / 180)
        .translatedBy(x: 0, y: -10)
    private static let firstBackdropTransform = CGAffineTransform(rotationAngle: -2.4 * .pi / 180)
        .translatedBy(x: 0, y: -6)

    private func updateCardHeightIfNeeded(animated: Bool = false) {
        let availableHeight = view.safeAreaLayoutGuide.layoutFrame.height
        let cardWidth = max(220, min(view.bounds.width, Self.maximumContentWidth) - 48)
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
        updateCanvasColor()

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
                    self.updateCanvasColor()
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
        let secondBackdropTransform = Self.secondBackdropTransform
        let restingBackdropTransform = Self.firstBackdropTransform
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
        let secondBackdropTransform = Self.secondBackdropTransform
        let firstBackdropTransform = Self.firstBackdropTransform
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
        emptyStateIconView.image = AppIcon.image(deckSummaries.isEmpty ? "stack-plus" : "check.bold", size: 20)
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
        queueSummaryLabel.text = [
            "\(FlashForgeStrings.StudyCard.Badge.learning) \(counts.learning)",
            "\(FlashForgeStrings.StudyCard.Badge.review) \(counts.review)"
        ].joined(separator: " · ")
        updateProgress(animated: false)
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
