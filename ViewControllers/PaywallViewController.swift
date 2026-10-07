//
//  PaywallViewController.swift
//  FlashForge
//

import SnapKit
import StoreKit
import UIKit

final class PaywallViewController: UIViewController {
    enum Context {
        case proFeature
        case deckLimit
        case cardLimit
    }

    private enum Plan: CaseIterable {
        case yearly
        case monthly
        case core

        var productID: String {
            switch self {
            case .yearly:
                return StoreProduct.proYearly
            case .monthly:
                return StoreProduct.proMonthly
            case .core:
                return StoreProduct.core
            }
        }
    }

    private enum Link {
        static let terms = URL(string: "https://bbdyno.github.io/FlashForge/terms.html")
        static let privacy = URL(string: "https://bbdyno.github.io/FlashForge/privacy.html")
    }

    private static let legacyOfferCodeInfoKey = "FFLegacyOfferCode"

    private let context: Context
    private let entitlements: EntitlementService

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let badgeLabel = PaywallBadgeLabel()
    private let closeButton = UIButton(type: .system)
    private let artworkView = PaywallArtworkView()
    private let headlineLabel = UILabel()
    private let benefitsStack = UIStackView()
    private let plansStack = UIStackView()
    private let purchaseButton = UIButton(type: .system)
    private let legacyNoteLabel = UILabel()
    private let legacyRedeemButton = UIButton(type: .system)
    private let statusLabel = UILabel()
    private let retryButton = UIButton(type: .system)
    private let footerStack = UIStackView()
    private let legalLabel = UILabel()
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)

    private var products: [String: Product] = [:]
    private var planControls: [Plan: PaywallPlanControl] = [:]
    private var selectedPlan: Plan
    private var trialEligiblePlans: Set<Plan> = []
    private var entitlementObserver: NSObjectProtocol?

    init(context: Context, entitlements: EntitlementService = .shared) {
        self.context = context
        self.entitlements = entitlements
        // Someone who hit a free limit needs Core, not a subscription, so that
        // is what is preselected for them.
        selectedPlan = context == .proFeature || entitlements.snapshot.tier >= .core ? .yearly : .core
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let entitlementObserver {
            NotificationCenter.default.removeObserver(entitlementObserver)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        configureLayout()
        renderStaticContent()
        loadProducts()

        entitlementObserver = NotificationCenter.default.addObserver(
            forName: .entitlementDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleEntitlementChange()
            }
        }
    }

    // MARK: - Layout

    private func configureUI() {
        // The sheet is a lime colour field in both appearances, so everything
        // on it uses the fixed study inks.
        view.backgroundColor = AppTheme.lime

        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = 16
        scrollView.addSubview(contentStack)

        badgeLabel.text = FlashForgeStrings.Paywall.badge
        closeButton.setImage(AppIcon.image("x.bold", size: 16), for: .normal)
        closeButton.tintColor = AppTheme.studyInk
        closeButton.accessibilityLabel = FlashForgeStrings.Paywall.close
        AppTheme.styleOutline(closeButton, radius: 20, color: AppTheme.studyLine)
        closeButton.addAction(UIAction { [weak self] _ in self?.dismiss(animated: true) }, for: .touchUpInside)

        let headerRow = UIStackView(arrangedSubviews: [badgeLabel, UIView(), closeButton])
        headerRow.alignment = .center
        closeButton.snp.makeConstraints { $0.size.equalTo(40) }

        artworkView.isAccessibilityElement = false

        headlineLabel.font = AppTypography.display(size: 30, textStyle: .title1, maximumPointSize: 38)
        headlineLabel.adjustsFontForContentSizeCategory = true
        headlineLabel.textColor = AppTheme.studyInk
        headlineLabel.numberOfLines = 0

        benefitsStack.axis = .vertical
        benefitsStack.spacing = 12

        plansStack.axis = .vertical
        plansStack.spacing = 10

        purchaseButton.titleLabel?.font = AppTypography.font(size: 16, weight: .bold, textStyle: .headline)
        purchaseButton.titleLabel?.adjustsFontForContentSizeCategory = true
        purchaseButton.setTitleColor(AppTheme.onInk, for: .normal)
        purchaseButton.backgroundColor = AppTheme.studyInk
        purchaseButton.layer.cornerRadius = 27
        purchaseButton.layer.cornerCurve = .continuous
        purchaseButton.accessibilityIdentifier = "paywall.purchaseButton"
        purchaseButton.addAction(UIAction { [weak self] _ in self?.purchaseSelectedPlan() }, for: .touchUpInside)

        [legacyNoteLabel, statusLabel, legalLabel].forEach { label in
            label.font = AppTypography.font(size: 12, weight: .semibold, textStyle: .caption1)
            label.adjustsFontForContentSizeCategory = true
            label.textColor = AppTheme.studyInk.withAlphaComponent(0.7)
            label.textAlignment = .center
            label.numberOfLines = 0
        }
        legacyNoteLabel.text = FlashForgeStrings.Paywall.Legacy.note
        legalLabel.text = FlashForgeStrings.Paywall.legal
        statusLabel.isHidden = true

        configureTextButton(legacyRedeemButton, title: "", underlined: true)
        legacyRedeemButton.addAction(UIAction { [weak self] _ in self?.redeemLegacyOffer() }, for: .touchUpInside)

        configureTextButton(retryButton, title: FlashForgeStrings.Paywall.retry, underlined: true)
        retryButton.isHidden = true
        retryButton.addAction(UIAction { [weak self] _ in self?.loadProducts() }, for: .touchUpInside)

        let restoreButton = UIButton(type: .system)
        configureTextButton(restoreButton, title: FlashForgeStrings.Paywall.restore, underlined: false)
        restoreButton.addAction(UIAction { [weak self] _ in self?.restorePurchases() }, for: .touchUpInside)
        let termsButton = UIButton(type: .system)
        configureTextButton(termsButton, title: FlashForgeStrings.Paywall.terms, underlined: false)
        termsButton.addAction(UIAction { _ in Link.terms.map { UIApplication.shared.open($0) } }, for: .touchUpInside)
        let privacyButton = UIButton(type: .system)
        configureTextButton(privacyButton, title: FlashForgeStrings.Paywall.privacy, underlined: false)
        privacyButton.addAction(UIAction { _ in Link.privacy.map { UIApplication.shared.open($0) } }, for: .touchUpInside)
        footerStack.axis = .horizontal
        footerStack.distribution = .equalCentering
        [restoreButton, termsButton, privacyButton].forEach(footerStack.addArrangedSubview)

        loadingIndicator.color = AppTheme.studyInk
        loadingIndicator.hidesWhenStopped = true

        [
            headerRow, artworkView, headlineLabel, benefitsStack, plansStack, loadingIndicator, statusLabel,
            retryButton, purchaseButton, legacyRedeemButton, legacyNoteLabel, footerStack, legalLabel
        ].forEach(contentStack.addArrangedSubview)
        contentStack.setCustomSpacing(4, after: headerRow)
        contentStack.setCustomSpacing(8, after: artworkView)
        contentStack.setCustomSpacing(22, after: benefitsStack)
        contentStack.setCustomSpacing(8, after: legacyRedeemButton)
    }

    private func configureLayout() {
        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
        contentStack.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide).inset(UIEdgeInsets(top: 16, left: 22, bottom: 20, right: 22))
            make.width.equalTo(scrollView.frameLayoutGuide).offset(-44)
        }
        artworkView.snp.makeConstraints { $0.height.equalTo(112) }
        purchaseButton.snp.makeConstraints { $0.height.equalTo(54) }
    }

    private func configureTextButton(_ button: UIButton, title: String, underlined: Bool) {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: AppTypography.font(size: 12.5, weight: .bold, textStyle: .caption1),
            .foregroundColor: AppTheme.studyInk
        ]
        if underlined {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        button.setAttributedTitle(NSAttributedString(string: title, attributes: attributes), for: .normal)
        button.titleLabel?.numberOfLines = 0
        button.titleLabel?.textAlignment = .center
    }

    // MARK: - Content

    private var legacyOfferCode: String? {
        let code = Bundle.main.object(forInfoDictionaryKey: Self.legacyOfferCodeInfoKey) as? String
        return (code?.isEmpty == false) ? code : nil
    }

    private var availablePlans: [Plan] {
        // Core is already owned by Core and Pro customers, so it is not offered again.
        entitlements.snapshot.tier >= .core ? [.yearly, .monthly] : Plan.allCases
    }

    private func renderStaticContent() {
        let snapshot = entitlements.snapshot
        if snapshot.showsLegacyProOffer, legacyOfferCode != nil {
            headlineLabel.text = FlashForgeStrings.Paywall.Headline.legacy
        } else {
            switch context {
            case .proFeature:
                headlineLabel.text = FlashForgeStrings.Paywall.Headline.pro
            case .deckLimit:
                headlineLabel.text = FlashForgeStrings.Paywall.Headline.deckLimit(FreeTierLimits.maxDecks)
            case .cardLimit:
                headlineLabel.text = FlashForgeStrings.Paywall.Headline.cardLimit(FreeTierLimits.maxCardsPerDeck)
            }
        }

        legacyNoteLabel.isHidden = !snapshot.isLegacyPurchaser
        if snapshot.showsLegacyProOffer, let code = legacyOfferCode {
            configureTextButton(legacyRedeemButton, title: FlashForgeStrings.Paywall.Legacy.redeem(code), underlined: true)
            legacyRedeemButton.isHidden = false
        } else {
            legacyRedeemButton.isHidden = true
        }
        renderBenefits()
    }

    private func renderBenefits() {
        benefitsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let rows: [(icon: String, title: String, detail: String)]
        if selectedPlan == .core {
            rows = [
                ("stack", FlashForgeStrings.Paywall.Benefit.Unlimited.title, FlashForgeStrings.Paywall.Benefit.Unlimited.detail),
                ("check-circle", FlashForgeStrings.Paywall.Benefit.Once.title, FlashForgeStrings.Paywall.Benefit.Once.detail)
            ]
        } else {
            rows = [
                ("brain", FlashForgeStrings.Paywall.Benefit.Fsrs.title, FlashForgeStrings.Paywall.Benefit.Fsrs.detail),
                ("chart-line-up", FlashForgeStrings.Paywall.Benefit.Insights.title, FlashForgeStrings.Paywall.Benefit.Insights.detail),
                ("download-simple", FlashForgeStrings.Paywall.Benefit.Import.title, FlashForgeStrings.Paywall.Benefit.Import.detail)
            ]
        }
        rows.forEach { benefitsStack.addArrangedSubview(PaywallBenefitRow(icon: $0.icon, title: $0.title, detail: $0.detail)) }
    }

    private func renderPlans() {
        plansStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        planControls.removeAll()

        let plans = availablePlans.filter { products[$0.productID] != nil }
        if !plans.contains(selectedPlan), let first = plans.first {
            selectedPlan = first
        }

        plans.forEach { plan in
            guard let product = products[plan.productID] else {
                return
            }
            let control = PaywallPlanControl()
            control.configure(
                title: title(for: plan),
                detail: detail(for: plan),
                price: product.displayPrice,
                badge: plan == .yearly ? yearlySavingsBadge() : nil
            )
            control.addAction(UIAction { [weak self] _ in self?.select(plan) }, for: .touchUpInside)
            plansStack.addArrangedSubview(control)
            planControls[plan] = control
        }

        let hasPlans = !plans.isEmpty
        purchaseButton.isHidden = !hasPlans
        statusLabel.isHidden = hasPlans
        retryButton.isHidden = hasPlans
        statusLabel.text = FlashForgeStrings.Paywall.unavailable
        updateSelection()
    }

    private func title(for plan: Plan) -> String {
        switch plan {
        case .yearly:
            return FlashForgeStrings.Paywall.Plan.yearly
        case .monthly:
            return FlashForgeStrings.Paywall.Plan.monthly
        case .core:
            return FlashForgeStrings.Paywall.Plan.core
        }
    }

    private func detail(for plan: Plan) -> String {
        switch plan {
        case .yearly:
            return FlashForgeStrings.Paywall.Plan.Yearly.detail
        case .monthly:
            return FlashForgeStrings.Paywall.Plan.Monthly.detail
        case .core:
            return FlashForgeStrings.Paywall.Plan.Core.detail
        }
    }

    private func yearlySavingsBadge() -> String? {
        guard let yearly = products[StoreProduct.proYearly]?.price,
              let monthly = products[StoreProduct.proMonthly]?.price,
              monthly > 0
        else {
            return nil
        }
        let ratio = NSDecimalNumber(decimal: yearly / (monthly * 12)).doubleValue
        let percent = Int(((1 - ratio) * 100).rounded())
        return percent >= 5 ? FlashForgeStrings.Paywall.Plan.save(percent) : nil
    }

    private func select(_ plan: Plan) {
        guard plan != selectedPlan else {
            return
        }
        selectedPlan = plan
        UISelectionFeedbackGenerator().selectionChanged()
        updateSelection()
        renderBenefits()
    }

    private func updateSelection() {
        planControls.forEach { plan, control in
            control.isSelected = plan == selectedPlan
        }
        let title: String
        if selectedPlan == .core {
            title = FlashForgeStrings.Paywall.Cta.core
        } else if trialEligiblePlans.contains(selectedPlan) {
            title = FlashForgeStrings.Paywall.Cta.trial
        } else {
            title = FlashForgeStrings.Paywall.Cta.subscribe
        }
        purchaseButton.setTitle(title, for: .normal)
    }

    // MARK: - Store

    private func loadProducts() {
        loadingIndicator.startAnimating()
        statusLabel.isHidden = true
        retryButton.isHidden = true
        purchaseButton.isHidden = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            let loaded = (try? await self.entitlements.products()) ?? []
            self.products = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })

            var eligible = Set<Plan>()
            for plan in [Plan.yearly, .monthly] {
                guard let subscription = self.products[plan.productID]?.subscription,
                      subscription.introductoryOffer?.paymentMode == .freeTrial,
                      await subscription.isEligibleForIntroOffer
                else {
                    continue
                }
                eligible.insert(plan)
            }
            self.trialEligiblePlans = eligible

            self.loadingIndicator.stopAnimating()
            self.renderPlans()
        }
    }

    private func purchaseSelectedPlan() {
        guard let product = products[selectedPlan.productID] else {
            return
        }
        setBusy(true)
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let purchased = try await self.entitlements.purchase(product)
                self.setBusy(false)
                if purchased {
                    self.dismiss(animated: true)
                }
            } catch {
                self.setBusy(false)
                self.presentError(error)
            }
        }
    }

    private func restorePurchases() {
        setBusy(true)
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.entitlements.restorePurchases()
                self.setBusy(false)
            } catch {
                self.setBusy(false)
                self.presentError(error)
            }
        }
    }

    private func redeemLegacyOffer() {
        guard let code = legacyOfferCode, let scene = view.window?.windowScene else {
            return
        }
        // The App Store sheet has no way to prefill a code, so it is put on the
        // clipboard for the customer to paste.
        UIPasteboard.general.string = code
        statusLabel.text = FlashForgeStrings.Paywall.Legacy.copied
        statusLabel.isHidden = false
        Task { @MainActor [weak self] in
            do {
                try await self?.entitlements.presentLegacyOfferRedemption(in: scene)
            } catch {
                self?.presentError(error)
            }
        }
    }

    private func handleEntitlementChange() {
        let tier = entitlements.snapshot.tier
        let isSatisfied = tier == .pro || (context != .proFeature && tier >= .core)
        if isSatisfied {
            dismiss(animated: true)
            return
        }
        renderStaticContent()
        renderPlans()
    }

    private func setBusy(_ isBusy: Bool) {
        purchaseButton.isEnabled = !isBusy
        purchaseButton.alpha = isBusy ? 0.6 : 1
        plansStack.isUserInteractionEnabled = !isBusy
        if isBusy {
            loadingIndicator.startAnimating()
        } else {
            loadingIndicator.stopAnimating()
        }
    }

    private func presentError(_ error: Error) {
        let alert = UIAlertController(
            title: FlashForgeStrings.Paywall.Error.title,
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: FlashForgeStrings.Paywall.close, style: .cancel))
        present(alert, animated: true)
    }
}

// MARK: - Pieces

private final class PaywallBadgeLabel: UIView {
    var text: String? {
        get { label.text }
        set { label.text = newValue }
    }

    private let label = UILabel()

    init() {
        super.init(frame: .zero)
        backgroundColor = AppTheme.studyInk
        layer.cornerRadius = 16
        layer.cornerCurve = .continuous

        let iconView = UIImageView(image: AppIcon.image("crown.fill", size: 14))
        iconView.tintColor = AppTheme.lime
        label.font = AppTypography.font(size: 13, weight: .bold, textStyle: .footnote, maximumPointSize: 17)
        label.textColor = AppTheme.lime

        let stack = UIStackView(arrangedSubviews: [iconView, label])
        stack.spacing = 6
        stack.alignment = .center
        addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 8, left: 13, bottom: 8, right: 14))
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class PaywallBenefitRow: UIView {
    init(icon: String, title: String, detail: String) {
        super.init(frame: .zero)
        isAccessibilityElement = true
        accessibilityLabel = "\(title), \(detail)"

        let iconBox = UIView()
        iconBox.backgroundColor = AppTheme.studyPaper
        AppTheme.styleOutline(iconBox, radius: 13, color: AppTheme.studyLine)
        let iconView = UIImageView(image: AppIcon.image(icon, size: 21))
        iconView.tintColor = AppTheme.studyInk
        iconBox.addSubview(iconView)

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = AppTypography.font(size: 15, weight: .bold, textStyle: .subheadline)
        titleLabel.textColor = AppTheme.studyInk
        titleLabel.numberOfLines = 0

        let detailLabel = UILabel()
        detailLabel.text = detail
        detailLabel.font = AppTypography.font(size: 12.5, weight: .semibold, textStyle: .caption1)
        detailLabel.textColor = AppTheme.studyInk.withAlphaComponent(0.68)
        detailLabel.numberOfLines = 0

        let textStack = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        textStack.axis = .vertical
        textStack.spacing = 1

        addSubview(iconBox)
        addSubview(textStack)
        iconBox.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
            make.size.equalTo(42)
            make.top.greaterThanOrEqualToSuperview()
        }
        iconView.snp.makeConstraints { $0.center.equalToSuperview() }
        textStack.snp.makeConstraints { make in
            make.leading.equalTo(iconBox.snp.trailing).offset(12)
            make.trailing.top.bottom.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class PaywallPlanControl: UIControl {
    override var isSelected: Bool {
        didSet { applySelection() }
    }

    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let priceLabel = UILabel()
    private let badgeLabel = UILabel()
    private let badgeContainer = UIView()

    init() {
        super.init(frame: .zero)
        isAccessibilityElement = true
        accessibilityTraits = .button
        AppTheme.styleOutline(self, radius: 18, color: AppTheme.studyLine)
        layer.shadowColor = AppTheme.studyLine.cgColor
        layer.shadowRadius = 0
        layer.shadowOffset = CGSize(width: 3, height: 3)

        titleLabel.font = AppTypography.font(size: 15, weight: .bold, textStyle: .subheadline)
        detailLabel.font = AppTypography.font(size: 12, weight: .semibold, textStyle: .caption1)
        priceLabel.font = AppTypography.display(size: 23, textStyle: .title3)
        priceLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        [titleLabel, detailLabel, priceLabel].forEach { $0.textColor = AppTheme.studyInk }
        detailLabel.textColor = AppTheme.studyInk.withAlphaComponent(0.68)

        badgeLabel.font = AppTypography.font(size: 10.5, weight: .bold, textStyle: .caption2, maximumPointSize: 14)
        badgeLabel.textColor = .white
        badgeContainer.backgroundColor = AppTheme.tomato
        AppTheme.styleOutline(badgeContainer, radius: 10, color: AppTheme.studyLine)
        badgeContainer.addSubview(badgeLabel)
        badgeLabel.snp.makeConstraints { $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 2, left: 8, bottom: 2, right: 8)) }

        let textStack = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        textStack.axis = .vertical
        textStack.spacing = 1
        textStack.isUserInteractionEnabled = false
        priceLabel.isUserInteractionEnabled = false
        badgeContainer.isUserInteractionEnabled = false

        addSubview(textStack)
        addSubview(priceLabel)
        addSubview(badgeContainer)
        textStack.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.top.bottom.equalToSuperview().inset(12)
            make.trailing.lessThanOrEqualTo(priceLabel.snp.leading).offset(-10)
        }
        priceLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
        }
        badgeContainer.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(14)
            make.centerY.equalTo(snp.top)
        }
        applySelection()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String, detail: String, price: String, badge: String?) {
        titleLabel.text = title
        detailLabel.text = detail
        priceLabel.text = price
        badgeLabel.text = badge
        badgeContainer.isHidden = badge == nil
        accessibilityLabel = [title, price, detail, badge].compactMap { $0 }.joined(separator: ", ")
    }

    private func applySelection() {
        backgroundColor = isSelected ? AppTheme.studyPaper : .clear
        layer.shadowOpacity = isSelected ? 1 : 0
        accessibilityTraits = isSelected ? [.button, .selected] : .button
    }
}

// Two loose cards and a pair of sparkles, drawn as ink lines.
private final class PaywallArtworkView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        contentMode = .redraw
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }
        let center = CGPoint(x: rect.midX, y: rect.midY + 2)
        let cardSize = CGSize(width: 104, height: 72)
        AppTheme.studyInk.setStroke()

        let back = CGPoint(x: center.x - 8, y: center.y + 4)
        let front = CGPoint(x: center.x + 6, y: center.y - 2)
        drawCard(in: context, center: back, size: cardSize, degrees: -9, fill: AppTheme.lilac)
        drawCard(in: context, center: front, size: cardSize, degrees: 4, fill: AppTheme.studyPaper, lines: true)
        drawSparkle(center: CGPoint(x: center.x + 72, y: center.y - 36), radius: 15)
        drawSparkle(center: CGPoint(x: center.x - 78, y: center.y + 22), radius: 9)

        let ground = UIBezierPath()
        ground.move(to: CGPoint(x: center.x - 92, y: center.y + 50))
        ground.addQuadCurve(
            to: CGPoint(x: center.x + 92, y: center.y + 50),
            controlPoint: CGPoint(x: center.x, y: center.y + 40)
        )
        ground.lineWidth = 2
        ground.lineCapStyle = .round
        ground.stroke()
    }

    private func drawCard(
        in context: CGContext,
        center: CGPoint,
        size: CGSize,
        degrees: CGFloat,
        fill: UIColor,
        lines: Bool = false
    ) {
        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: degrees * .pi / 180)
        let cardRect = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)
        let card = UIBezierPath(roundedRect: cardRect, cornerRadius: 10)
        fill.setFill()
        card.fill()
        card.lineWidth = 2
        card.stroke()
        if lines {
            let widths: [CGFloat] = [0.5, 0.7, 0.34]
            for (index, width) in widths.enumerated() {
                let y = cardRect.minY + 22 + CGFloat(index) * 14
                let line = UIBezierPath()
                line.move(to: CGPoint(x: cardRect.minX + 16, y: y))
                line.addLine(to: CGPoint(x: cardRect.minX + 16 + (size.width - 32) * width, y: y))
                line.lineWidth = 2
                line.lineCapStyle = .round
                line.stroke()
            }
        }
        context.restoreGState()
    }

    private func drawSparkle(center: CGPoint, radius: CGFloat) {
        let inner = radius * 0.28
        let path = UIBezierPath()
        for index in 0 ..< 8 {
            let angle = CGFloat(index) * .pi / 4 - .pi / 2
            let distance = index.isMultiple(of: 2) ? radius : inner
            let point = CGPoint(x: center.x + cos(angle) * distance, y: center.y + sin(angle) * distance)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.close()
        AppTheme.studyInk.setFill()
        path.fill()
    }
}
