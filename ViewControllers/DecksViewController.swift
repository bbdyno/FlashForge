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
    private let emptyIconView = UIImageView(image: UIImage(systemName: "rectangle.stack.badge.plus"))
    private let emptyLabel = UILabel()
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)

    private var deckSummaries: [DeckSummary] = []

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
            image: UIImage(systemName: "plus"),
            style: .plain,
            target: self,
            action: #selector(didTapAddDeck)
        )
        navigationItem.rightBarButtonItem?.tintColor = AppTheme.accent
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "decks.addButton"

        tableView.register(DeckSummaryCell.self, forCellReuseIdentifier: DeckSummaryCell.reuseIdentifier)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 92
        tableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 24, right: 0)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.accessibilityIdentifier = "decks.table"
        view.addSubview(tableView)

        emptyLabel.text = FlashForgeStrings.Decks.empty
        AppTheme.styleSurface(emptyContainer, radius: 18)
        emptyContainer.isHidden = true
        view.addSubview(emptyContainer)

        emptyIconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
        emptyIconView.tintColor = AppTheme.accent
        emptyIconView.backgroundColor = AppTheme.accentSoft
        emptyIconView.contentMode = .center
        emptyIconView.layer.cornerRadius = 20
        emptyIconView.layer.cornerCurve = .continuous
        emptyContainer.addSubview(emptyIconView)

        emptyLabel.textAlignment = .left
        emptyLabel.numberOfLines = 2
        emptyLabel.textColor = AppTheme.textSecondary
        emptyLabel.font = AppTypography.font(size: 18, weight: .bold, textStyle: .headline)
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

        navigationItem.rightBarButtonItem?.tintColor = AppTheme.accent
        emptyContainer.backgroundColor = AppTheme.cardBackground
        emptyContainer.layer.borderColor = AppTheme.resolved(AppTheme.cardBorder, for: traitCollection).cgColor
        emptyIconView.backgroundColor = AppTheme.accentSoft
        emptyIconView.tintColor = AppTheme.accent
        emptyLabel.textColor = AppTheme.textSecondary
        loadingIndicator.color = AppTheme.textPrimary
    }

    private func configureObserver() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleDeckDataDidChange), name: .deckDataDidChange, object: nil)
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

    private func presentDeckImportPicker() {
        let importType = UTType(filenameExtension: Self.deckImportFileExtension) ?? .json
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [importType, .json])
        picker.delegate = self
        picker.allowsMultipleSelection = false
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
            subtitle: FlashForgeStrings.Decks.Row.subtitle(
                dueToday,
                deck.dueCounts.learning,
                deck.dueCounts.review,
                remaining
            ),
            dueBadge: FlashForgeStrings.Decks.Row.DueBadge.value(dueToday)
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
    private let iconContainer = UIView()
    private let iconImageView = UIImageView(image: UIImage(systemName: "rectangle.stack.fill"))
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let dueBadgeLabel = UILabel()
    private let chevronImageView = UIImageView(image: UIImage(systemName: "chevron.right"))

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configureUI()
        configureLayout()
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

    func configure(title: String, subtitle: String, dueBadge: String) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        dueBadgeLabel.text = dueBadge
    }

    private func configureUI() {
        backgroundColor = .clear
        selectionStyle = .none
        contentView.backgroundColor = .clear

        AppTheme.styleSurface(cardView, radius: 16)

        iconContainer.backgroundColor = AppTheme.inputBackground
        iconContainer.layer.cornerRadius = 12
        iconContainer.layer.cornerCurve = .continuous
        iconImageView.tintColor = AppTheme.accent
        iconImageView.contentMode = .scaleAspectFit

        titleLabel.font = AppTypography.font(size: 16, weight: .semibold, textStyle: .headline)
        titleLabel.textColor = AppTheme.textPrimary

        subtitleLabel.font = AppTypography.font(size: 12, weight: .medium, textStyle: .caption1)
        subtitleLabel.textColor = AppTheme.textSecondary
        subtitleLabel.numberOfLines = 1

        dueBadgeLabel.font = AppTypography.font(size: 10.5, weight: .semibold, textStyle: .caption1)
        dueBadgeLabel.textColor = AppTheme.accent
        dueBadgeLabel.backgroundColor = AppTheme.accentSoft
        dueBadgeLabel.layer.cornerRadius = 9
        dueBadgeLabel.layer.cornerCurve = .continuous
        dueBadgeLabel.clipsToBounds = true
        dueBadgeLabel.textAlignment = .center
        dueBadgeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        chevronImageView.tintColor = AppTheme.textSecondary
        chevronImageView.contentMode = .scaleAspectFit

        contentView.addSubview(cardView)
        cardView.addSubview(iconContainer)
        iconContainer.addSubview(iconImageView)
        cardView.addSubview(titleLabel)
        cardView.addSubview(subtitleLabel)
        cardView.addSubview(dueBadgeLabel)
        cardView.addSubview(chevronImageView)

        applyTheme()
    }

    private func applyTheme() {
        cardView.backgroundColor = AppTheme.cardBackground
        cardView.layer.borderColor = AppTheme.resolved(AppTheme.cardBorder, for: traitCollection).cgColor
        iconContainer.backgroundColor = AppTheme.inputBackground
        iconImageView.tintColor = AppTheme.accent
        titleLabel.textColor = AppTheme.textPrimary
        subtitleLabel.textColor = AppTheme.textSecondary
        dueBadgeLabel.textColor = AppTheme.accent
        dueBadgeLabel.backgroundColor = AppTheme.accentSoft
        chevronImageView.tintColor = AppTheme.textSecondary
    }

    private func configureLayout() {
        cardView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(5)
            make.leading.trailing.equalToSuperview().inset(20)
        }

        iconContainer.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(12)
            make.centerY.equalToSuperview()
            make.size.equalTo(40)
        }

        iconImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(18)
        }

        chevronImageView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().inset(12)
            make.width.equalTo(10)
            make.height.equalTo(16)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(14)
            make.leading.equalTo(iconContainer.snp.trailing).offset(12)
            make.trailing.lessThanOrEqualTo(dueBadgeLabel.snp.leading).offset(-8)
        }

        dueBadgeLabel.snp.makeConstraints { make in
            make.centerY.equalTo(titleLabel)
            make.trailing.equalTo(chevronImageView.snp.leading).offset(-10)
            make.height.equalTo(18)
            make.width.greaterThanOrEqualTo(48)
        }

        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(6)
            make.leading.equalTo(titleLabel)
            make.trailing.lessThanOrEqualTo(chevronImageView.snp.leading).offset(-10)
            make.bottom.lessThanOrEqualToSuperview().inset(14)
        }
    }
}
