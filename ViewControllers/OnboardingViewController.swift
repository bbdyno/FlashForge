//
//  OnboardingViewController.swift
//  FlashForge
//
//  Created by bbdyno on 2/11/26.
//

import UIKit
import SnapKit
import UniformTypeIdentifiers

final class OnboardingViewController: UIViewController {
    private static let backupFileExtension = "ffbackup"

    private struct OnboardingDraft {
        let deckTitle: String
        let front: String
        let back: String
        let note: String
    }

    private let repository: CardRepository
    var onCompleted: (() -> Void)?

    private let backgroundGradientLayer = CAGradientLayer()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    private let deckField = UITextField()
    private let frontField = UITextField()
    private let backField = UITextField()
    private let noteField = UITextField()
    private let startButton = UIButton(type: .system)
    private let importButton = UIButton(type: .system)
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)

    init(repository: CardRepository) {
        self.repository = repository
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backgroundGradientLayer.frame = view.bounds
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
        view.backgroundColor = .clear
        navigationItem.hidesBackButton = true

        AppTheme.applyGradient(to: backgroundGradientLayer, traitCollection: traitCollection)

        titleLabel.text = FlashForgeStrings.Onboarding.title
        titleLabel.textColor = AppTheme.textPrimary
        titleLabel.numberOfLines = 2
        titleLabel.font = AppTypography.font(size: 30, weight: .bold, textStyle: .title1)

        subtitleLabel.text = FlashForgeStrings.Onboarding.subtitle
        subtitleLabel.textColor = AppTheme.textSecondary
        subtitleLabel.numberOfLines = 2
        subtitleLabel.font = AppTypography.font(size: 16, weight: .medium, textStyle: .body)

        [deckField, frontField, backField, noteField].forEach { field in
            field.backgroundColor = AppTheme.inputBackground
            field.textColor = AppTheme.textPrimary
            field.font = AppTypography.font(size: 16, weight: .medium, textStyle: .body)
            field.autocapitalizationType = .sentences
            field.clearButtonMode = .whileEditing
            field.layer.borderWidth = 0.5
            field.layer.borderColor = AppTheme.cardBorder.cgColor
            field.layer.cornerRadius = 12
            field.layer.cornerCurve = .continuous
            field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
            field.leftViewMode = .always
        }

        deckField.placeholder = FlashForgeStrings.Onboarding.Field.Deck.placeholder
        frontField.placeholder = FlashForgeStrings.Onboarding.Field.Front.placeholder
        backField.placeholder = FlashForgeStrings.Onboarding.Field.Back.placeholder
        noteField.placeholder = FlashForgeStrings.Onboarding.Field.Note.placeholder

        [deckField, frontField, backField, noteField].forEach { field in
            field.attributedPlaceholder = NSAttributedString(
                string: field.placeholder ?? "",
                attributes: [.foregroundColor: AppTheme.textSecondary]
            )
        }

        startButton.setTitle(FlashForgeStrings.Onboarding.start, for: .normal)
        startButton.setTitleColor(.white, for: .normal)
        startButton.titleLabel?.font = AppTypography.font(size: 16, weight: .bold, textStyle: .headline)
        startButton.backgroundColor = AppTheme.buttonFill(from: AppTheme.accent, for: traitCollection)
        startButton.layer.cornerRadius = 14
        startButton.layer.cornerCurve = .continuous
        startButton.addTarget(self, action: #selector(didTapStart), for: .touchUpInside)

        importButton.setTitle(FlashForgeStrings.Onboarding.`import`, for: .normal)
        importButton.setTitleColor(AppTheme.textPrimary, for: .normal)
        importButton.titleLabel?.font = AppTypography.font(size: 15, weight: .semibold, textStyle: .subheadline)
        importButton.backgroundColor = AppTheme.inputBackground
        importButton.layer.cornerRadius = 12
        importButton.layer.cornerCurve = .continuous
        importButton.layer.borderWidth = 0.5
        importButton.layer.borderColor = AppTheme.cardBorder.cgColor
        importButton.addTarget(self, action: #selector(didTapImportBackup), for: .touchUpInside)

        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.color = AppTheme.textPrimary

        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(deckField)
        view.addSubview(frontField)
        view.addSubview(backField)
        view.addSubview(noteField)
        view.addSubview(startButton)
        view.addSubview(importButton)
        startButton.addSubview(loadingIndicator)

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(30)
            make.leading.trailing.equalToSuperview().inset(24)
        }

        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(10)
            make.leading.trailing.equalTo(titleLabel)
        }

        deckField.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(30)
            make.leading.trailing.equalToSuperview().inset(24)
            make.height.equalTo(48)
        }

        frontField.snp.makeConstraints { make in
            make.top.equalTo(deckField.snp.bottom).offset(12)
            make.leading.trailing.height.equalTo(deckField)
        }

        backField.snp.makeConstraints { make in
            make.top.equalTo(frontField.snp.bottom).offset(12)
            make.leading.trailing.height.equalTo(deckField)
        }

        noteField.snp.makeConstraints { make in
            make.top.equalTo(backField.snp.bottom).offset(12)
            make.leading.trailing.height.equalTo(deckField)
        }

        startButton.snp.makeConstraints { make in
            make.top.equalTo(noteField.snp.bottom).offset(20)
            make.leading.trailing.equalTo(deckField)
            make.height.equalTo(50)
        }

        importButton.snp.makeConstraints { make in
            make.top.equalTo(startButton.snp.bottom).offset(10)
            make.leading.trailing.equalTo(deckField)
            make.height.equalTo(44)
        }

        loadingIndicator.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().inset(16)
        }

        applyTheme()
    }

    private func applyTheme() {
        AppTheme.applyGradient(to: backgroundGradientLayer, traitCollection: traitCollection)

        titleLabel.textColor = AppTheme.textPrimary
        subtitleLabel.textColor = AppTheme.textSecondary

        [deckField, frontField, backField, noteField].forEach { field in
            field.backgroundColor = AppTheme.inputBackground
            field.textColor = AppTheme.textPrimary
            field.layer.borderColor = AppTheme.resolved(AppTheme.cardBorder, for: traitCollection).cgColor
            field.attributedPlaceholder = NSAttributedString(
                string: field.placeholder ?? "",
                attributes: [.foregroundColor: AppTheme.textSecondary]
            )
        }

        startButton.setTitleColor(.white, for: .normal)
        startButton.backgroundColor = AppTheme.buttonFill(from: AppTheme.accent, for: traitCollection)

        importButton.setTitleColor(AppTheme.textPrimary, for: .normal)
        importButton.backgroundColor = AppTheme.inputBackground
        importButton.layer.borderColor = AppTheme.resolved(AppTheme.cardBorder, for: traitCollection).cgColor

        loadingIndicator.color = AppTheme.textPrimary
    }

    @objc
    private func didTapStart() {
        guard let draft = normalizedDraft() else {
            return
        }

        setLoading(true)
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.setLoading(false) }

            do {
                try await self.repository.prepare()
                let deck = try await self.repository.createDeck(title: draft.deckTitle)
                _ = try await self.repository.addCard(
                    to: deck.id,
                    front: draft.front,
                    back: draft.back,
                    note: draft.note
                )
                AppTelemetry.log(.onboardingCompleted, parameters: ["entry_method": "created"])
                self.onCompleted?()
                self.dismiss(animated: true)
            } catch {
                CrashReporter.record(error: error, context: "OnboardingViewController.didTapStart")
                self.presentError(message: Self.userFacingMessage(from: error))
            }
        }
    }

    @objc
    private func didTapImportBackup() {
        let backupType = UTType(filenameExtension: Self.backupFileExtension) ?? .data
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [backupType])
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    private func normalizedDraft() -> OnboardingDraft? {
        let deckTitle = CardTextSanitizer.normalizeSingleLine(deckField.text ?? "")
        let front = CardTextSanitizer.normalizeMultiline(frontField.text ?? "")
        let back = CardTextSanitizer.normalizeMultiline(backField.text ?? "")
        let note = CardTextSanitizer.normalizeSingleLine(noteField.text ?? "")

        guard !deckTitle.isEmpty else {
            presentValidationError(
                title: FlashForgeStrings.Onboarding.Validation.Deck.title,
                message: FlashForgeStrings.Onboarding.Validation.Deck.message
            )
            return nil
        }

        guard !front.isEmpty, !back.isEmpty else {
            presentValidationError(
                title: FlashForgeStrings.Onboarding.Validation.Card.title,
                message: FlashForgeStrings.Onboarding.Validation.Card.message
            )
            return nil
        }

        deckField.text = deckTitle
        frontField.text = front
        backField.text = back
        noteField.text = note

        return OnboardingDraft(
            deckTitle: deckTitle,
            front: front,
            back: back,
            note: note
        )
    }

    private func setLoading(_ isLoading: Bool) {
        if isLoading {
            loadingIndicator.startAnimating()
        } else {
            loadingIndicator.stopAnimating()
        }

        [deckField, frontField, backField, noteField, startButton, importButton].forEach { $0.isUserInteractionEnabled = !isLoading }
    }

    private func presentError(message: String) {
        guard presentedViewController == nil else {
            return
        }

        let alert = UIAlertController(title: FlashForgeStrings.Home.Error.title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: FlashForgeStrings.Common.ok, style: .cancel))
        present(alert, animated: true)
    }

    private func presentValidationError(title: String, message: String) {
        guard presentedViewController == nil else {
            return
        }

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: FlashForgeStrings.Common.ok, style: .default))
        present(alert, animated: true)
    }

    private func presentImportConfirmation(data: Data, preview: BackupPreview) {
        guard presentedViewController == nil else {
            return
        }

        let message = FlashForgeStrings.Onboarding.Import.Confirm.message(
            preview.deckCount,
            preview.cardCount,
            preview.reviewCount
        )
        let alert = UIAlertController(
            title: FlashForgeStrings.Onboarding.Import.Confirm.title,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: FlashForgeStrings.More.Common.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: FlashForgeStrings.More.Data.Import.Confirm.action, style: .default, handler: { [weak self] _ in
            self?.importBackupData(data)
        }))
        present(alert, animated: true)
    }

    private func importBackupData(_ data: Data) {
        setLoading(true)
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.setLoading(false) }

            do {
                try await self.repository.importBackupData(data)
                AppTelemetry.log(.onboardingCompleted, parameters: ["entry_method": "imported"])
                AppTelemetry.log(.backupImported, parameters: ["result": "success"])
                NotificationCenter.default.post(name: .deckDataDidChange, object: nil)
                self.onCompleted?()
                self.dismiss(animated: true)
            } catch {
                CrashReporter.record(error: error, context: "OnboardingViewController.importBackupData")
                self.presentError(message: Self.userFacingMessage(from: error))
            }
        }
    }

    private static func userFacingMessage(from error: Error) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription,
           !description.isEmpty {
            return description
        }
        return FlashForgeStrings.Onboarding.Error.fallback
    }
}

extension OnboardingViewController: UIDocumentPickerDelegate {
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {}

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let fileURL = urls.first else {
            presentValidationError(
                title: FlashForgeStrings.Onboarding.Backup.Invalid.title,
                message: FlashForgeStrings.Onboarding.Backup.Invalid.selection
            )
            return
        }

        setLoading(true)
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.setLoading(false) }

            let didStartAccessing = fileURL.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    fileURL.stopAccessingSecurityScopedResource()
                }
            }

            do {
                guard fileURL.pathExtension.lowercased() == Self.backupFileExtension else {
                    self.presentValidationError(
                        title: FlashForgeStrings.Onboarding.Backup.Invalid.title,
                        message: FlashForgeStrings.Onboarding.Backup.Invalid.extension(Self.backupFileExtension)
                    )
                    return
                }

                let data = try Data(contentsOf: fileURL)
                let preview = try await self.repository.previewBackupData(data)
                self.presentImportConfirmation(data: data, preview: preview)
            } catch {
                CrashReporter.record(error: error, context: "OnboardingViewController.documentPicker")
                self.presentError(message: Self.userFacingMessage(from: error))
            }
        }
    }
}
