//
//  DeckDetailViewController.swift
//  FlashForge
//
//  Created by bbdyno on 2/11/26.
//

import UIKit
import SnapKit

final class DeckDetailViewController: UIViewController {
    private let repository: CardRepository
    private let deckID: UUID

    private let backgroundGradientLayer = CAGradientLayer()
    private let topGlowView = UIView()
    private let bottomGlowView = UIView()
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let emptyLabel = UILabel()
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)

    private var cards: [DeckCard] = []

    private lazy var viewModel: DeckDetailViewModel = {
        let viewModel = DeckDetailViewModel(repository: repository, deckID: deckID)
        viewModel.bind(output: makeOutput())
        return viewModel
    }()

    init(repository: CardRepository, deckID: UUID) {
        self.repository = repository
        self.deckID = deckID
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.viewModel.send(.viewDidLoad)
        }
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

    private func makeOutput() -> DeckDetailViewModel.Output {
        DeckDetailViewModel.Output(
            didChangeLoading: { [weak self] isLoading in
                if isLoading {
                    self?.loadingIndicator.startAnimating()
                } else {
                    self?.loadingIndicator.stopAnimating()
                }
            },
            didUpdateDeckTitle: { [weak self] title in
                self?.title = title
            },
            didUpdateCards: { [weak self] cards in
                self?.cards = cards
                self?.tableView.reloadData()
                self?.emptyLabel.isHidden = !cards.isEmpty
            },
            didReceiveError: { [weak self] message in
                self?.presentError(message)
            }
        )
    }

    private func configureUI() {
        view.layer.insertSublayer(backgroundGradientLayer, at: 0)
        AppTheme.applyGradient(to: backgroundGradientLayer, traitCollection: traitCollection)
        view.backgroundColor = .clear

        topGlowView.backgroundColor = AppTheme.accent.withAlphaComponent(0.22)
        topGlowView.layer.shadowColor = AppTheme.accent.cgColor
        topGlowView.layer.shadowOpacity = 0.28
        topGlowView.layer.shadowRadius = 52
        topGlowView.layer.shadowOffset = .zero

        bottomGlowView.backgroundColor = AppTheme.accentTeal.withAlphaComponent(0.16)
        bottomGlowView.layer.shadowColor = AppTheme.accentTeal.cgColor
        bottomGlowView.layer.shadowOpacity = 0.28
        bottomGlowView.layer.shadowRadius = 52
        bottomGlowView.layer.shadowOffset = .zero

        view.addSubview(topGlowView)
        view.addSubview(bottomGlowView)

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "plus"),
            style: .plain,
            target: self,
            action: #selector(didTapAddCard)
        )
        navigationItem.rightBarButtonItem?.tintColor = AppTheme.textPrimary

        tableView.register(DeckCardCell.self, forCellReuseIdentifier: DeckCardCell.reuseIdentifier)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 104
        tableView.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 20, right: 0)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        view.addSubview(tableView)

        emptyLabel.text = FlashForgeStrings.DeckDetail.empty
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 2
        emptyLabel.textColor = AppTheme.textSecondary
        emptyLabel.font = AppTypography.font(size: 15, weight: .medium, textStyle: .body)
        emptyLabel.isHidden = true
        view.addSubview(emptyLabel)

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

        emptyLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(24)
        }

        loadingIndicator.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(8)
            make.centerX.equalToSuperview()
        }

        applyTheme()
    }

    private func applyTheme() {
        AppTheme.applyGradient(to: backgroundGradientLayer, traitCollection: traitCollection)

        topGlowView.backgroundColor = AppTheme.accent.withAlphaComponent(0.22)
        topGlowView.layer.shadowColor = AppTheme.resolved(AppTheme.accent, for: traitCollection).cgColor

        bottomGlowView.backgroundColor = AppTheme.accentTeal.withAlphaComponent(0.16)
        bottomGlowView.layer.shadowColor = AppTheme.resolved(AppTheme.accentTeal, for: traitCollection).cgColor

        navigationItem.rightBarButtonItem?.tintColor = AppTheme.textPrimary
        emptyLabel.textColor = AppTheme.textSecondary
        loadingIndicator.color = AppTheme.textPrimary
    }

    @objc
    private func didTapAddCard() {
        let editor = CardEditorViewController(mode: .create) { [weak self] draft in
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.viewModel.send(.addCard(draft))
            }
        }
        navigationController?.pushViewController(editor, animated: true)
    }

    private func presentEditor(for card: DeckCard) {
        let editor = CardEditorViewController(mode: .edit(card)) { [weak self] draft in
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.viewModel.send(.updateCard(cardID: card.id, draft: draft))
            }
        }
        navigationController?.pushViewController(editor, animated: true)
    }

    private func presentError(_ message: String) {
        guard presentedViewController == nil else {
            return
        }
        let alert = UIAlertController(title: FlashForgeStrings.Home.Error.title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: FlashForgeStrings.Home.Error.close, style: .cancel))
        present(alert, animated: true)
    }

    private func stateText(for card: DeckCard) -> String {
        switch card.schedule.state {
        case .new:
            return FlashForgeStrings.DeckDetail.State.new
        case .learning:
            return FlashForgeStrings.DeckDetail.State.learning
        case .review:
            return FlashForgeStrings.DeckDetail.State.review
        case .relearning:
            return FlashForgeStrings.DeckDetail.State.relearning
        }
    }

    private func dueText(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return FlashForgeStrings.DeckDetail.Due.today
        }
        if calendar.isDateInTomorrow(date) {
            return FlashForgeStrings.DeckDetail.Due.tomorrow
        }
        return FlashForgeStrings.DeckDetail.Due.date(DateFormatter.deckDueDate.string(from: date))
    }

    private func frontPreview(for card: DeckCard) -> String {
        CardTextSanitizer.previewLine(
            from: card.content.title,
            emptyFallback: FlashForgeStrings.DeckDetail.Preview.frontEmpty
        )
    }

    private func backPreview(for card: DeckCard) -> String {
        CardTextSanitizer.previewLine(
            from: card.content.detail,
            emptyFallback: FlashForgeStrings.DeckDetail.Preview.backEmpty
        )
    }
}

extension DeckDetailViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        cards.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: DeckCardCell.reuseIdentifier,
            for: indexPath
        ) as? DeckCardCell else {
            return UITableViewCell()
        }
        let card = cards[indexPath.row]
        cell.configure(
            front: frontPreview(for: card),
            back: backPreview(for: card),
            state: stateText(for: card),
            due: dueText(for: card.schedule.dueDate)
        )
        return cell
    }
}

extension DeckDetailViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        presentEditor(for: cards[indexPath.row])
    }

    func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        let card = cards[indexPath.row]
        let delete = UIContextualAction(style: .destructive, title: FlashForgeStrings.DeckDetail.Action.delete) { [weak self] _, _, completion in
            guard let self else {
                completion(false)
                return
            }
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.viewModel.send(.deleteCard(card.id))
                completion(true)
            }
        }
        return UISwipeActionsConfiguration(actions: [delete])
    }
}

private extension DateFormatter {
    static let deckDueDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

private final class DeckCardCell: UITableViewCell {
    static let reuseIdentifier = "DeckCardCell"

    private let cardView = UIView()
    private let frontLabel = UILabel()
    private let backLabel = UILabel()
    private let statePillLabel = UILabel()
    private let dueLabel = UILabel()
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

    func configure(front: String, back: String, state: String, due: String) {
        frontLabel.text = front
        backLabel.text = back
        statePillLabel.text = state
        dueLabel.text = due
    }

    private func configureUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        cardView.backgroundColor = AppTheme.cardBackground
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = AppTheme.cardBorder.cgColor
        cardView.layer.cornerRadius = 14
        cardView.layer.cornerCurve = .continuous

        frontLabel.font = AppTypography.font(size: 16, weight: .semibold, textStyle: .headline)
        frontLabel.textColor = AppTheme.textPrimary
        frontLabel.numberOfLines = 1

        backLabel.font = AppTypography.font(size: 13, weight: .medium, textStyle: .footnote)
        backLabel.textColor = AppTheme.textSecondary
        backLabel.numberOfLines = 1

        statePillLabel.font = AppTypography.font(size: 11, weight: .bold, textStyle: .caption1)
        statePillLabel.textColor = AppTheme.textPrimary
        statePillLabel.backgroundColor = UIColor.white.withAlphaComponent(0.14)
        statePillLabel.layer.cornerRadius = 10
        statePillLabel.layer.cornerCurve = .continuous
        statePillLabel.layer.borderWidth = 1
        statePillLabel.layer.borderColor = AppTheme.cardBorder.cgColor
        statePillLabel.clipsToBounds = true
        statePillLabel.textAlignment = .center

        dueLabel.font = AppTypography.font(size: 12, weight: .medium, textStyle: .caption1)
        dueLabel.textColor = AppTheme.textSecondary

        chevronImageView.tintColor = AppTheme.textSecondary
        chevronImageView.contentMode = .scaleAspectFit

        contentView.addSubview(cardView)
        cardView.addSubview(frontLabel)
        cardView.addSubview(backLabel)
        cardView.addSubview(statePillLabel)
        cardView.addSubview(dueLabel)
        cardView.addSubview(chevronImageView)

        applyTheme()
    }

    private func applyTheme() {
        cardView.backgroundColor = AppTheme.cardBackground
        cardView.layer.borderColor = AppTheme.resolved(AppTheme.cardBorder, for: traitCollection).cgColor
        frontLabel.textColor = AppTheme.textPrimary
        backLabel.textColor = AppTheme.textSecondary

        statePillLabel.textColor = AppTheme.textPrimary
        statePillLabel.backgroundColor = AppTheme.badgeBackground
        statePillLabel.layer.borderColor = AppTheme.resolved(AppTheme.badgeBorder, for: traitCollection).cgColor

        dueLabel.textColor = AppTheme.textSecondary
        chevronImageView.tintColor = AppTheme.textSecondary
    }

    private func configureLayout() {
        cardView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(6)
            make.leading.trailing.equalToSuperview().inset(16)
        }

        chevronImageView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().inset(14)
            make.width.equalTo(10)
            make.height.equalTo(16)
        }

        frontLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(12)
            make.leading.equalToSuperview().inset(14)
            make.trailing.lessThanOrEqualTo(chevronImageView.snp.leading).offset(-10)
        }

        backLabel.snp.makeConstraints { make in
            make.top.equalTo(frontLabel.snp.bottom).offset(4)
            make.leading.equalTo(frontLabel)
            make.trailing.lessThanOrEqualTo(chevronImageView.snp.leading).offset(-10)
        }

        statePillLabel.snp.makeConstraints { make in
            make.top.equalTo(backLabel.snp.bottom).offset(10)
            make.leading.equalTo(frontLabel)
            make.height.equalTo(20)
            make.width.greaterThanOrEqualTo(94)
            make.bottom.equalToSuperview().inset(12)
        }

        dueLabel.snp.makeConstraints { make in
            make.centerY.equalTo(statePillLabel)
            make.trailing.lessThanOrEqualTo(chevronImageView.snp.leading).offset(-10)
            make.leading.greaterThanOrEqualTo(statePillLabel.snp.trailing).offset(8)
        }
    }
}
