//
//  CardEditorViewController.swift
//  FlashForge
//
//  Created by bbdyno on 2/11/26.
//

import UIKit
import SnapKit

final class CardEditorViewController: UIViewController {
    enum Mode {
        case create
        case edit(DeckCard)
    }

    private let mode: Mode
    private let onSave: @MainActor (DeckDetailViewModel.CardDraft) -> Void

    private let backgroundGradientLayer = CAGradientLayer()
    private let topGlowView = UIView()
    private let bottomGlowView = UIView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let stackView = UIStackView()

    private let introCard = UIView()
    private let introTitleLabel = UILabel()
    private let introDescriptionLabel = UILabel()
    private let frontCard = UIView()
    private let backCard = UIView()
    private let noteCard = UIView()

    private let frontField = UITextField()
    private let backTextView = UITextView()
    private let noteField = UITextField()
    private let backPlaceholder = UILabel()

    init(
        mode: Mode,
        onSave: @escaping @MainActor (DeckDetailViewModel.CardDraft) -> Void
    ) {
        self.mode = mode
        self.onSave = onSave
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        applyInitialValues()
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
    }

    private func configureUI() {
        view.layer.insertSublayer(backgroundGradientLayer, at: 0)
        AppTheme.applyGradient(to: backgroundGradientLayer, traitCollection: traitCollection)
        view.backgroundColor = .clear
        title = modeTitle

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
            title: FlashForgeStrings.CardEditor.save,
            style: .done,
            target: self,
            action: #selector(didTapSave)
        )
        navigationItem.rightBarButtonItem?.tintColor = AppTheme.accent

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(stackView)

        scrollView.keyboardDismissMode = .interactive
        scrollView.backgroundColor = .clear
        contentView.backgroundColor = .clear
        stackView.axis = .vertical
        stackView.spacing = 14

        configureCard(introCard)
        configureCard(frontCard)
        configureCard(backCard)
        configureCard(noteCard)

        introTitleLabel.text = FlashForgeStrings.CardEditor.Intro.title
        introTitleLabel.font = AppTypography.font(size: 20, weight: .bold, textStyle: .title3)
        introTitleLabel.textColor = AppTheme.textPrimary

        introDescriptionLabel.text = FlashForgeStrings.CardEditor.Intro.description
        introDescriptionLabel.numberOfLines = 0
        introDescriptionLabel.font = AppTypography.font(size: 14, weight: .medium, textStyle: .subheadline)
        introDescriptionLabel.textColor = AppTheme.textSecondary

        backTextView.font = UIFont.systemFont(ofSize: 16)
        backTextView.textColor = AppTheme.textPrimary
        backTextView.backgroundColor = AppTheme.inputBackground
        backTextView.layer.borderColor = AppTheme.cardBorder.cgColor
        backTextView.layer.borderWidth = 1
        backTextView.layer.cornerRadius = 12
        backTextView.layer.cornerCurve = .continuous
        backTextView.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        backTextView.delegate = self

        backPlaceholder.text = FlashForgeStrings.CardEditor.Back.placeholder
        backPlaceholder.textColor = AppTheme.textSecondary
        backPlaceholder.font = UIFont.systemFont(ofSize: 15)

        styleTextField(
            frontField,
            placeholder: FlashForgeStrings.CardEditor.Front.placeholder,
            keyboardType: .default
        )
        styleTextField(
            noteField,
            placeholder: FlashForgeStrings.CardEditor.Note.placeholder,
            keyboardType: .default
        )

        frontField.autocapitalizationType = .sentences
        noteField.autocapitalizationType = .sentences

        let backContainer = UIView()
        backContainer.addSubview(backTextView)
        backContainer.addSubview(backPlaceholder)

        let frontHeader = makeSectionHeader(title: FlashForgeStrings.CardEditor.Section.front)
        let backHeader = makeSectionHeader(title: FlashForgeStrings.CardEditor.Section.back)
        let noteHeader = makeSectionHeader(title: FlashForgeStrings.CardEditor.Section.note)

        introCard.addSubview(introTitleLabel)
        introCard.addSubview(introDescriptionLabel)

        frontCard.addSubview(frontHeader)
        frontCard.addSubview(frontField)

        backCard.addSubview(backHeader)
        backCard.addSubview(backContainer)

        noteCard.addSubview(noteHeader)
        noteCard.addSubview(noteField)

        stackView.addArrangedSubview(introCard)
        stackView.addArrangedSubview(frontCard)
        stackView.addArrangedSubview(backCard)
        stackView.addArrangedSubview(noteCard)

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

        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }

        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
        }

        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(20)
        }

        introTitleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(16)
            make.leading.trailing.equalToSuperview().inset(16)
        }

        introDescriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(introTitleLabel.snp.bottom).offset(6)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().inset(16)
        }

        frontHeader.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(14)
            make.leading.trailing.equalToSuperview().inset(16)
        }

        frontField.snp.makeConstraints { make in
            make.top.equalTo(frontHeader.snp.bottom).offset(10)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(46)
            make.bottom.equalToSuperview().inset(14)
        }

        backHeader.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(14)
            make.leading.trailing.equalToSuperview().inset(16)
        }

        backContainer.snp.makeConstraints { make in
            make.top.equalTo(backHeader.snp.bottom).offset(10)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(180)
            make.bottom.equalToSuperview().inset(14)
        }

        backTextView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        backPlaceholder.snp.makeConstraints { make in
            make.top.equalTo(backTextView).offset(13)
            make.leading.equalTo(backTextView).offset(15)
        }

        noteHeader.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(14)
            make.leading.trailing.equalToSuperview().inset(16)
        }

        noteField.snp.makeConstraints { make in
            make.top.equalTo(noteHeader.snp.bottom).offset(10)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(46)
            make.bottom.equalToSuperview().inset(14)
        }

        applyTheme()
    }

    private func applyInitialValues() {
        guard case let .edit(card) = mode else {
            return
        }

        frontField.text = CardTextSanitizer.normalizeSingleLine(card.content.title)
        backTextView.text = CardTextSanitizer.normalizeMultiline(card.content.detail)
        let note = CardTextSanitizer.normalizeSingleLine(card.content.subtitle)
        noteField.text = CardTextSanitizer.isLegacyNoNote(note) ? "" : note
        backPlaceholder.isHidden = !CardTextSanitizer.normalizeMultiline(backTextView.text ?? "").isEmpty
    }

    private var modeTitle: String {
        switch mode {
        case .create:
            return FlashForgeStrings.CardEditor.Mode.add
        case .edit:
            return FlashForgeStrings.CardEditor.Mode.edit
        }
    }

    private func configureCard(_ view: UIView) {
        view.backgroundColor = AppTheme.cardBackground
        view.layer.borderWidth = 1
        view.layer.borderColor = AppTheme.cardBorder.cgColor
        view.layer.cornerRadius = 16
        view.layer.cornerCurve = .continuous
    }

    private func makeSectionHeader(title: String) -> UILabel {
        let label = UILabel()
        label.text = title
        label.font = AppTypography.font(size: 14, weight: .semibold, textStyle: .subheadline)
        label.textColor = AppTheme.textSecondary
        return label
    }

    private func styleTextField(_ field: UITextField, placeholder: String, keyboardType: UIKeyboardType) {
        field.placeholder = placeholder
        field.keyboardType = keyboardType
        field.clearButtonMode = .whileEditing
        field.font = .systemFont(ofSize: 16, weight: .medium)
        field.textColor = AppTheme.textPrimary
        field.backgroundColor = AppTheme.inputBackground
        field.layer.borderWidth = 1
        field.layer.borderColor = AppTheme.cardBorder.cgColor
        field.layer.cornerRadius = 12
        field.layer.cornerCurve = .continuous
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        field.leftViewMode = .always
        field.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: AppTheme.textSecondary]
        )
    }

    private func applyTheme() {
        AppTheme.applyGradient(to: backgroundGradientLayer, traitCollection: traitCollection)

        topGlowView.backgroundColor = AppTheme.accent.withAlphaComponent(0.22)
        topGlowView.layer.shadowColor = AppTheme.resolved(AppTheme.accent, for: traitCollection).cgColor

        bottomGlowView.backgroundColor = AppTheme.accentTeal.withAlphaComponent(0.16)
        bottomGlowView.layer.shadowColor = AppTheme.resolved(AppTheme.accentTeal, for: traitCollection).cgColor

        navigationItem.rightBarButtonItem?.tintColor = AppTheme.accent

        [introCard, frontCard, backCard, noteCard].forEach { card in
            card.backgroundColor = AppTheme.cardBackground
            card.layer.borderColor = AppTheme.resolved(AppTheme.cardBorder, for: traitCollection).cgColor
        }

        introTitleLabel.textColor = AppTheme.textPrimary
        introDescriptionLabel.textColor = AppTheme.textSecondary

        [frontField, noteField].forEach { field in
            field.textColor = AppTheme.textPrimary
            field.backgroundColor = AppTheme.inputBackground
            field.layer.borderColor = AppTheme.resolved(AppTheme.cardBorder, for: traitCollection).cgColor
            field.attributedPlaceholder = NSAttributedString(
                string: field.placeholder ?? "",
                attributes: [.foregroundColor: AppTheme.textSecondary]
            )
        }

        backTextView.textColor = AppTheme.textPrimary
        backTextView.backgroundColor = AppTheme.inputBackground
        backTextView.layer.borderColor = AppTheme.resolved(AppTheme.cardBorder, for: traitCollection).cgColor
        backPlaceholder.textColor = AppTheme.textSecondary
    }

    private func presentValidationError() {
        guard presentedViewController == nil else {
            return
        }
        let alert = UIAlertController(
            title: FlashForgeStrings.CardEditor.Validation.title,
            message: FlashForgeStrings.CardEditor.Validation.message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: FlashForgeStrings.Common.ok, style: .default))
        present(alert, animated: true)
    }

    @objc
    private func didTapSave() {
        let normalizedFront = CardTextSanitizer.normalizeMultiline(frontField.text ?? "")
        let normalizedBack = CardTextSanitizer.normalizeMultiline(backTextView.text ?? "")
        let normalizedNote = CardTextSanitizer.normalizeSingleLine(noteField.text ?? "")

        guard !normalizedFront.isEmpty, !normalizedBack.isEmpty else {
            presentValidationError()
            return
        }

        frontField.text = normalizedFront
        backTextView.text = normalizedBack
        noteField.text = normalizedNote
        backPlaceholder.isHidden = true

        let draft = DeckDetailViewModel.CardDraft(
            front: normalizedFront,
            back: normalizedBack,
            note: normalizedNote
        )
        onSave(draft)
        navigationController?.popViewController(animated: true)
    }
}

extension CardEditorViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        backPlaceholder.isHidden = !CardTextSanitizer.normalizeMultiline(textView.text ?? "").isEmpty
    }
}
