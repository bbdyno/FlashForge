//
//  DecksViewController.swift
//  FlashForge
//
//  Created by bbdyno on 2/11/26.
//

import UIKit
import SnapKit
import UniformTypeIdentifiers

final class DecksViewController: UIViewController {
    private static let deckImportFileExtension = "ffdeck"

    private let repository: CardRepository

    private let backgroundGradientLayer = CAGradientLayer()
    private let topGlowView = UIView()
    private let bottomGlowView = UIView()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyContainer = UIView()
    private let emptyIconView = UIImageView(image: AppIcon.image("stack-plus", size: 22))
    private let limitFooterView = FreeLimitFooterView()
    private var entitlementObserver: NSObjectProtocol?
    private let emptyLabel = UILabel()
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)

    private var deckSummaries: [DeckSummary] = [] {
        didSet { deckColors = AppTheme.fieldColors(for: deckSummaries.map(\.id)) }
    }
    private var deckColors: [UUID: UIColor] = [:]
    private var isPickingExternalDeck = false

    private lazy var viewModel: DecksViewModel = {
        let viewModel = DecksViewModel(repository: repository)
        viewModel.bind(output: makeOutput())
        return viewModel
    }()

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
        if let entitlementObserver {
            NotificationCenter.default.removeObserver(entitlementObserver)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        configureObserver()
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.viewModel.send(.viewDidLoad)
        }
    }

    private func makeOutput() -> DecksViewModel.Output {
        DecksViewModel.Output(
            didChangeLoading: { [weak self] isLoading in
                if isLoading {
                    self?.loadingIndicator.startAnimating()
                } else {
                    self?.loadingIndicator.stopAnimating()
                }
            },
            didUpdateDecks: { [weak self] decks in
                self?.deckSummaries = decks
                self?.tableView.reloadData()
                self?.emptyContainer.isHidden = !decks.isEmpty
                self?.updateLimitFooter()
            },
            didReceiveError: { [weak self] message in
                self?.presentError(message)
            }
        )
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backgroundGradientLayer.frame = view.bounds
        topGlowView.layer.cornerRadius = topGlowView.bounds.height / 2
        bottomGlowView.layer.cornerRadius = bottomGlowView.bounds.height / 2
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.hasDifferentColorAppearance(comparedTo: traitCollection) == true else {
            return
        }
        applyTheme()
        tableView.reloadData()
    }

    private func configureUI() {
        title = FlashForgeStrings.Decks.title
        navigationItem.largeTitleDisplayMode = .automatic

        view.layer.insertSublayer(backgroundGradientLayer, at: 0)
        AppTheme.applyGradient(to: backgroundGradientLayer, traitCollection: traitCollection)
        view.backgroundColor = .clear

        topGlowView.isHidden = true
        bottomGlowView.isHidden = true

        view.addSubview(topGlowView)
        view.addSubview(bottomGlowView)

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: AppIcon.image("plus.bold", size: 20),
            style: .plain,
            target: self,
            action: #selector(didTapAddDeck)
        )
        navigationItem.rightBarButtonItem?.tintColor = AppTheme.textPrimary
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "decks.addButton"

        tableView.register(DeckSummaryCell.self, forCellReuseIdentifier: DeckSummaryCell.reuseIdentifier)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 126
        tableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 24, right: 0)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.accessibilityIdentifier = "decks.table"
        view.addSubview(tableView)

        emptyLabel.text = FlashForgeStrings.Decks.empty
        AppTheme.styleSurface(emptyContainer, radius: 22)
        emptyContainer.isHidden = true
        view.addSubview(emptyContainer)

        emptyIconView.tintColor = AppTheme.studyInk
        emptyIconView.backgroundColor = AppTheme.lime
        emptyIconView.contentMode = .center
        AppTheme.styleOutline(emptyIconView, radius: 23, color: AppTheme.studyLine)
        emptyContainer.addSubview(emptyIconView)

        emptyLabel.textAlignment = .left
        emptyLabel.numberOfLines = 2
        emptyLabel.numberOfLines = 0
        emptyLabel.textColor = AppTheme.textPrimary
        emptyLabel.font = AppTypography.display(size: 22, textStyle: .title2)
        emptyContainer.addSubview(emptyLabel)

        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.color = AppTheme.textPrimary
        view.addSubview(loadingIndicator)

        topGlowView.snp.makeConstraints { make in
            make.size.equalTo(280)
            make.top.equalTo(view.safeAreaLayoutGuide).offset(-120)
            make.trailing.equalToSuperview().offset(120)
        }

        bottomGlowView.snp.makeConstraints { make in
            make.size.equalTo(240)
            make.leading.equalToSuperview().offset(-120)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(90)
        }

        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        emptyContainer.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(24)
        }

        emptyIconView.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().inset(20)
            make.size.equalTo(46)
        }

        emptyLabel.snp.makeConstraints { make in
            make.top.equalTo(emptyIconView.snp.bottom).offset(18)
            make.leading.trailing.bottom.equalToSuperview().inset(20)
        }

        loadingIndicator.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(8)
            make.centerX.equalToSuperview()
        }

        applyTheme()
    }

    private func applyTheme() {
        AppTheme.applyGradient(to: backgroundGradientLayer, traitCollection: traitCollection)

        navigationItem.rightBarButtonItem?.tintColor = AppTheme.textPrimary
        emptyContainer.backgroundColor = AppTheme.cardBackground
        emptyContainer.layer.borderColor = AppTheme.resolved(AppTheme.cardBorder, for: traitCollection).cgColor
        emptyLabel.textColor = AppTheme.textPrimary
        loadingIndicator.color = AppTheme.textPrimary
    }

    private func configureObserver() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleDeckDataDidChange), name: .deckDataDidChange, object: nil)
        entitlementObserver = NotificationCenter.default.addObserver(
            forName: .entitlementDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateLimitFooter()
            }
        }
        limitFooterView.addAction(UIAction { [weak self] _ in
            self?.presentPaywall()
        }, for: .touchUpInside)
    }

    private func updateLimitFooter() {
        guard EntitlementService.shared.snapshot.tier == .free, !deckSummaries.isEmpty else {
            tableView.tableFooterView = nil
            return
        }
        limitFooterView.configure(used: deckSummaries.count, limit: FreeTierLimits.maxDecks)
        limitFooterView.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 84)
        tableView.tableFooterView = limitFooterView
    }

    private func presentPaywall() {
        present(PaywallViewController(context: .deckLimit), animated: true)
    }

    @objc
    private func handleDeckDataDidChange() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.viewModel.send(.didTapReload)
        }
    }

    @objc
    private func didTapAddDeck() {
        guard FeatureGate.canCreateDeck(
            existingDeckCount: deckSummaries.count,
            tier: EntitlementService.shared.snapshot.tier
        ) else {
            presentPaywall()
            return
        }

        let actionSheet = UIAlertController(
            title: FlashForgeStrings.Decks.Add.title,
            message: FlashForgeStrings.Decks.Add.message,
            preferredStyle: .actionSheet
        )
        actionSheet.addAction(UIAlertAction(title: FlashForgeStrings.Decks.Add.manual, style: .default, handler: { [weak self] _ in
            self?.presentCreateDeckPrompt()
        }))
        actionSheet.addAction(UIAlertAction(title: FlashForgeStrings.Decks.Add.`import`, style: .default, handler: { [weak self] _ in
            self?.presentDeckImportPicker()
        }))
        actionSheet.addAction(UIAlertAction(title: FlashForgeStrings.Import.option, style: .default, handler: { [weak self] _ in
            self?.presentExternalImportPicker()
        }))
        actionSheet.addAction(UIAlertAction(title: FlashForgeStrings.More.Common.cancel, style: .cancel))
        actionSheet.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
        present(actionSheet, animated: true)
    }

    private func presentCreateDeckPrompt() {
        let alert = UIAlertController(
            title: FlashForgeStrings.Decks.Create.title,
            message: FlashForgeStrings.Decks.Create.message,
            preferredStyle: .alert
        )
        alert.addTextField { textField in
            textField.placeholder = FlashForgeStrings.Decks.Create.placeholder
        }
        alert.addAction(UIAlertAction(title: FlashForgeStrings.More.Common.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: FlashForgeStrings.Decks.Create.action, style: .default, handler: { [weak self, weak alert] _ in
            guard let self else { return }
            let title = alert?.textFields?.first?.text ?? ""
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.viewModel.send(.createDeck(title))
            }
        }))
        present(alert, animated: true)
    }

    private func presentExternalImportPicker() {
        guard EntitlementService.shared.snapshot.tier == .pro else {
            present(PaywallViewController(context: .proFeature), animated: true)
            return
        }
        let ankiTypes = ["apkg", "colpkg"].compactMap { UTType(filenameExtension: $0) }
        let types = ankiTypes + [.commaSeparatedText, .tabSeparatedText, .plainText]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        isPickingExternalDeck = true
        present(picker, animated: true)
    }

    private func importExternalDeck(at fileURL: URL) async {
        do {
            let decks = try await Task.detached(priority: .userInitiated) {
                try DeckImportService.importFile(at: fileURL)
            }.value
            let result = try await repository.importDecks(decks)
            NotificationCenter.default.post(name: .deckDataDidChange, object: nil)
            let alert = UIAlertController(
                title: FlashForgeStrings.Import.Done.title,
                message: FlashForgeStrings.Import.Done.message(result.decks, result.cards),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: FlashForgeStrings.Home.Error.close, style: .cancel))
            present(alert, animated: true)
        } catch {
            presentError((error as? LocalizedError)?.errorDescription ?? FlashForgeStrings.Decks.Import.readError)
        }
    }

    private func presentDeckImportPicker() {
        let importType = UTType(filenameExtension: Self.deckImportFileExtension) ?? .json
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [importType, .json])
        picker.delegate = self
        picker.allowsMultipleSelection = false
        isPickingExternalDeck = false
        present(picker, animated: true)
    }

    private func presentRenamePrompt(for deck: DeckSummary) {
        let alert = UIAlertController(title: FlashForgeStrings.Decks.Rename.title, message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.text = deck.title
        }
        alert.addAction(UIAlertAction(title: FlashForgeStrings.More.Common.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: FlashForgeStrings.Decks.Rename.action, style: .default, handler: { [weak self, weak alert] _ in
            guard let self else { return }
            let newTitle = alert?.textFields?.first?.text ?? ""
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.viewModel.send(.renameDeck(deckID: deck.id, title: newTitle))
            }
        }))
        present(alert, animated: true)
    }

    private func presentError(_ message: String) {
        guard presentedViewController == nil else {
            return
        }
        let alert = UIAlertController(title: FlashForgeStrings.Home.Error.title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: FlashForgeStrings.Home.Error.close, style: .cancel))
        present(alert, animated: true)
    }
}

extension DecksViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let fileURL = urls.first else {
            presentError(FlashForgeStrings.Decks.Import.selectError)
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }

            let didStartAccessing = fileURL.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    fileURL.stopAccessingSecurityScopedResource()
                }
            }

            if self.isPickingExternalDeck {
                self.isPickingExternalDeck = false
                await self.importExternalDeck(at: fileURL)
                return
            }

            do {
                let data = try Data(contentsOf: fileURL)
                await self.viewModel.send(.importDeckData(data))
            } catch {
                CrashReporter.record(error: error, context: "DecksViewController.documentPicker")
                self.presentError(FlashForgeStrings.Decks.Import.readError)
            }
        }
    }
}

extension DecksViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        deckSummaries.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: DeckSummaryCell.reuseIdentifier,
            for: indexPath
        ) as? DeckSummaryCell else {
            return UITableViewCell()
        }
        let deck = deckSummaries[indexPath.row]

        let dueToday = deck.dueCounts.total
        let remaining = max(0, deck.totalCardCount - dueToday)
        cell.configure(
            title: deck.title,
            subtitle: FlashForgeStrings.Decks.Row.cards(deck.totalCardCount),
            dueCount: dueToday,
            color: deckColors[deck.id] ?? AppTheme.lilac,
            accessibilityDetail: FlashForgeStrings.Decks.Row.subtitle(
                dueToday,
                deck.dueCounts.learning,
                deck.dueCounts.review,
                remaining
            )
        )
        return cell
    }
}

extension DecksViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let deck = deckSummaries[indexPath.row]
        let detail = DeckDetailViewController(repository: repository, deckID: deck.id)
        navigationController?.pushViewController(detail, animated: true)
    }

    func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        let deck = deckSummaries[indexPath.row]

        let rename = UIContextualAction(style: .normal, title: FlashForgeStrings.Decks.Action.rename) { [weak self] _, _, completion in
            self?.presentRenamePrompt(for: deck)
            completion(true)
        }
        rename.backgroundColor = .systemBlue

        let delete = UIContextualAction(style: .destructive, title: FlashForgeStrings.Decks.Action.delete) { [weak self] _, _, completion in
            guard let self else {
                completion(false)
                return
            }
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.viewModel.send(.deleteDeck(deck.id))
                completion(true)
            }
        }

        let config = UISwipeActionsConfiguration(actions: [delete, rename])
        config.performsFirstActionWithFullSwipe = false
        return config
    }
}

private final class DeckSummaryCell: UITableViewCell {
    static let reuseIdentifier = "DeckSummaryCell"

    private let cardView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let dueCountLabel = UILabel()
    private let dueCaptionLabel = UILabel()
    private let chevronImageView = UIImageView(image: AppIcon.image("caret-right.bold", size: 16))

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configureUI()
        configureLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        // Pressing pushes the block into its hard shadow.
        let offset: CGFloat = highlighted ? 3 : 0
        UIView.animate(withDuration: 0.12, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction]) { [self] in
            cardView.transform = CGAffineTransform(translationX: offset, y: offset)
            cardView.layer.shadowOffset = CGSize(width: 3 - offset, height: 3 - offset)
        }
    }

    func configure(title: String, subtitle: String, dueCount: Int, color: UIColor, accessibilityDetail: String) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        dueCountLabel.text = String(dueCount)
        cardView.backgroundColor = color
        accessibilityLabel = "\(title), \(accessibilityDetail)"
    }

    private func configureUI() {
        backgroundColor = .clear
        selectionStyle = .none
        contentView.backgroundColor = .clear
        isAccessibilityElement = true
        accessibilityTraits = .button

        // Deck blocks are colour fields in both appearances, so their text uses
        // the fixed study inks.
        AppTheme.styleOutline(cardView, radius: 22, color: AppTheme.studyLine)
        cardView.layer.shadowColor = AppTheme.studyLine.cgColor
        cardView.layer.shadowOpacity = 1
        cardView.layer.shadowRadius = 0
        cardView.layer.shadowOffset = CGSize(width: 3, height: 3)

        titleLabel.font = AppTypography.display(size: 23, textStyle: .title2)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = AppTheme.studyInk
        titleLabel.numberOfLines = 2

        subtitleLabel.font = AppTypography.font(size: 13, weight: .semibold, textStyle: .footnote)
        subtitleLabel.textColor = AppTheme.studyInk.withAlphaComponent(0.7)

        dueCountLabel.font = AppTypography.display(size: 30, textStyle: .title1)
        dueCountLabel.textColor = AppTheme.studyInk
        dueCountLabel.textAlignment = .right
        dueCountLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        dueCaptionLabel.text = FlashForgeStrings.Decks.Row.today
        dueCaptionLabel.font = AppTypography.font(size: 12, weight: .semibold, textStyle: .caption1)
        dueCaptionLabel.textColor = AppTheme.studyInk.withAlphaComponent(0.7)
        dueCaptionLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        chevronImageView.tintColor = AppTheme.studyInk
        chevronImageView.contentMode = .center

        contentView.addSubview(cardView)
        [titleLabel, subtitleLabel, dueCountLabel, dueCaptionLabel, chevronImageView].forEach(cardView.addSubview)
    }

    private func configureLayout() {
        cardView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(6)
            make.bottom.equalToSuperview().inset(8)
            make.leading.equalToSuperview().inset(20)
            make.trailing.equalToSuperview().inset(23)
        }

        chevronImageView.snp.makeConstraints { make in
            make.top.trailing.equalToSuperview().inset(16)
            make.size.equalTo(18)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(14)
            make.leading.equalToSuperview().inset(18)
            make.trailing.lessThanOrEqualTo(chevronImageView.snp.leading).offset(-12)
        }

        subtitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.bottom.equalToSuperview().inset(15)
            make.trailing.lessThanOrEqualTo(dueCountLabel.snp.leading).offset(-12)
        }

        dueCaptionLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(18)
            make.lastBaseline.equalTo(subtitleLabel)
        }

        dueCountLabel.snp.makeConstraints { make in
            make.trailing.equalTo(dueCaptionLabel.snp.leading).offset(-5)
            make.lastBaseline.equalTo(subtitleLabel)
        }
    }
}

private final class FreeLimitFooterView: UIControl {
    private let outlineLayer = CAShapeLayer()
    private let iconView = UIImageView(image: AppIcon.image("lock-simple", size: 20))
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let chevronView = UIImageView(image: AppIcon.image("caret-right.bold", size: 14))

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityIdentifier = "decks.limitFooter"

        outlineLayer.fillColor = UIColor.clear.cgColor
        outlineLayer.lineWidth = AppTheme.outlineWidth
        outlineLayer.lineDashPattern = [6, 5]
        layer.addSublayer(outlineLayer)

        titleLabel.font = AppTypography.font(size: 14, weight: .bold, textStyle: .subheadline)
        detailLabel.font = AppTypography.font(size: 12.5, weight: .semibold, textStyle: .caption1)
        detailLabel.text = FlashForgeStrings.Decks.Limit.detail

        let textStack = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        textStack.axis = .vertical
        textStack.spacing = 1
        let row = UIStackView(arrangedSubviews: [iconView, textStack, chevronView])
        row.alignment = .center
        row.spacing = 12
        row.isUserInteractionEnabled = false
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        chevronView.setContentHuggingPriority(.required, for: .horizontal)
        addSubview(row)
        row.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(38)
            make.centerY.equalToSuperview().offset(-4)
        }
        applyTheme()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let rect = bounds.inset(by: UIEdgeInsets(top: 6, left: 20, bottom: 14, right: 20))
        outlineLayer.path = UIBezierPath(roundedRect: rect, cornerRadius: 22).cgPath
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyTheme()
    }

    func configure(used: Int, limit: Int) {
        titleLabel.text = FlashForgeStrings.Decks.Limit.title(used, limit)
        accessibilityLabel = [titleLabel.text, detailLabel.text].compactMap { $0 }.joined(separator: ", ")
    }

    private func applyTheme() {
        outlineLayer.strokeColor = AppTheme.resolved(AppTheme.cardBorder, for: traitCollection).cgColor
        [iconView, chevronView].forEach { $0.tintColor = AppTheme.textPrimary }
        titleLabel.textColor = AppTheme.textPrimary
        detailLabel.textColor = AppTheme.textSecondary
    }
}
