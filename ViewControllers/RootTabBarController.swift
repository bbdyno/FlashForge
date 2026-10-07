//
//  RootTabBarController.swift
//  FlashForge
//
//  Created by bbdyno on 2/11/26.
//

import UIKit

final class RootTabBarController: UITabBarController {
    private enum UITestLaunchArgument {
        static let skipOnboarding = "UITEST_SKIP_ONBOARDING"
    }

    private enum OnboardingDefaultsKey {
        static let hasCompletedWalkthrough = "hasCompletedWalkthrough"
    }

    private let repository: CardRepository
    private lazy var editorialTabBar = EditorialTabBarView(
        items: [
            (FlashForgeStrings.Tab.study, "cards", "tab.study"),
            (FlashForgeStrings.Tab.decks, "stack", "tab.decks"),
            (FlashForgeStrings.Tab.insights, "chart-bar", "tab.insights")
        ]
    )
    private var hasCheckedInitialFlow = false
    private var isPresentingWalkthrough = false
    private var isPresentingOnboarding = false

    init(repository: CardRepository) {
        self.repository = repository
        super.init(nibName: nil, bundle: nil)
        if #available(iOS 18.0, *) {
            // iPadOS otherwise promotes UITabBarController's hidden native
            // tab bar into a second floating control above our editorial bar.
            traitOverrides.horizontalSizeClass = .compact
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureTabs()
        configureEditorialTabBar()
        applyChromeAppearance()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.hasDifferentColorAppearance(comparedTo: traitCollection) == true else {
            return
        }
        applyChromeAppearance()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasCheckedInitialFlow else {
            return
        }
        hasCheckedInitialFlow = true
        presentInitialFlowIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // UIKit may reveal its native tab bar again after a
        // hidesBottomBarWhenPushed transition. Keep it fully out of the visual
        // and accessibility trees; the editorial bar below owns navigation.
        tabBar.isHidden = true
        tabBar.alpha = 0
    }

    private func configureTabs() {
        let study = HomeViewController(repository: repository)
        let studyNavigation = UINavigationController(rootViewController: study)
        studyNavigation.delegate = self
        studyNavigation.navigationBar.isHidden = true
        studyNavigation.tabBarItem = UITabBarItem(
            title: FlashForgeStrings.Tab.study,
            image: UIImage(systemName: "square.grid.2x2"),
            selectedImage: UIImage(systemName: "square.grid.2x2.fill")
        )

        let decks = DecksViewController(repository: repository)
        let decksNavigation = UINavigationController(rootViewController: decks)
        decksNavigation.delegate = self
        decksNavigation.navigationBar.prefersLargeTitles = true
        decksNavigation.tabBarItem = UITabBarItem(
            title: FlashForgeStrings.Tab.decks,
            image: UIImage(systemName: "rectangle.stack"),
            selectedImage: UIImage(systemName: "rectangle.stack.fill")
        )

        let insights = InsightsViewController(repository: repository)
        let insightsNavigation = UINavigationController(rootViewController: insights)
        insightsNavigation.delegate = self
        insightsNavigation.navigationBar.prefersLargeTitles = true
        insightsNavigation.tabBarItem = UITabBarItem(
            title: FlashForgeStrings.Tab.insights,
            image: UIImage(systemName: "chart.bar"),
            selectedImage: UIImage(systemName: "chart.bar.fill")
        )

        viewControllers = [studyNavigation, decksNavigation, insightsNavigation]
    }

    private func configureEditorialTabBar() {
        tabBar.isHidden = true
        tabBar.alpha = 0
        tabBar.isUserInteractionEnabled = false
        tabBar.isAccessibilityElement = false
        tabBar.accessibilityElementsHidden = true
        viewControllers?.forEach { $0.additionalSafeAreaInsets.bottom = EditorialTabBarView.reservedHeight }

        view.addSubview(editorialTabBar)
        editorialTabBar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            editorialTabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            editorialTabBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            editorialTabBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            editorialTabBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -EditorialTabBarView.reservedHeight)
        ])
        editorialTabBar.onSelect = { [weak self] index in
            guard let self else { return }
            self.selectedIndex = index
            self.editorialTabBar.selectedIndex = index
            if let navigationController = self.selectedViewController as? UINavigationController {
                self.updateEditorialTabBar(for: navigationController.topViewController, in: navigationController)
            }
        }
        editorialTabBar.selectedIndex = selectedIndex
    }

    private func updateEditorialTabBar(
        for viewController: UIViewController?,
        in navigationController: UINavigationController
    ) {
        let shouldHide = viewController?.hidesBottomBarWhenPushed == true
        editorialTabBar.isHidden = shouldHide
        navigationController.additionalSafeAreaInsets.bottom = shouldHide ? 0 : EditorialTabBarView.reservedHeight
    }

    private func applyChromeAppearance() {
        let navigationAppearance = AppTheme.makeNavigationAppearance()
        viewControllers?
            .compactMap { $0 as? UINavigationController }
            .forEach { navigationController in
                navigationController.navigationBar.standardAppearance = navigationAppearance
                navigationController.navigationBar.scrollEdgeAppearance = navigationAppearance
                navigationController.navigationBar.compactAppearance = navigationAppearance
                navigationController.navigationBar.tintColor = AppTheme.textPrimary
            }

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = AppTheme.tabBarBackground
        tabAppearance.shadowColor = AppTheme.cardBorder.withAlphaComponent(0.45)

        let itemAppearances = [
            tabAppearance.stackedLayoutAppearance,
            tabAppearance.inlineLayoutAppearance,
            tabAppearance.compactInlineLayoutAppearance
        ]
        itemAppearances.forEach { appearance in
            appearance.normal.iconColor = AppTheme.textSecondary
            appearance.normal.titleTextAttributes = [
                .foregroundColor: AppTheme.textSecondary,
                .font: AppTypography.font(size: 10, weight: .medium, textStyle: .caption2)
            ]
            appearance.selected.iconColor = AppTheme.accent
            appearance.selected.titleTextAttributes = [
                .foregroundColor: AppTheme.accent,
                .font: AppTypography.font(size: 10, weight: .bold, textStyle: .caption2)
            ]
        }

        tabBar.standardAppearance = tabAppearance
        tabBar.scrollEdgeAppearance = tabAppearance
        tabBar.tintColor = AppTheme.accent
        tabBar.unselectedItemTintColor = AppTheme.textSecondary
        editorialTabBar.applyTheme()
    }

    private var hasCompletedWalkthrough: Bool {
        get {
            UserDefaults.standard.bool(forKey: OnboardingDefaultsKey.hasCompletedWalkthrough)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: OnboardingDefaultsKey.hasCompletedWalkthrough)
        }
    }

    private func presentInitialFlowIfNeeded() {
        if ProcessInfo.processInfo.arguments.contains(UITestLaunchArgument.skipOnboarding) {
            return
        }

        if !hasCompletedWalkthrough {
            presentWalkthrough()
            return
        }

        presentOnboardingIfNeeded()
    }

    private func presentWalkthrough() {
        guard !isPresentingWalkthrough else {
            return
        }
        guard presentedViewController == nil else {
            return
        }

        isPresentingWalkthrough = true
        let walkthrough = AppWalkthroughViewController()
        walkthrough.onFinished = { [weak self] in
            guard let self else { return }
            self.hasCompletedWalkthrough = true
            self.isPresentingWalkthrough = false
            self.dismiss(animated: true) { [weak self] in
                self?.presentOnboardingIfNeeded()
            }
        }

        let navigation = UINavigationController(rootViewController: walkthrough)
        navigation.modalPresentationStyle = .fullScreen
        navigation.isModalInPresentation = true
        present(navigation, animated: true)
    }

    private func presentOnboardingIfNeeded() {
        guard !isPresentingOnboarding else {
            return
        }
        guard presentedViewController == nil else {
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                try await self.repository.prepare()
                let hasAnyDeck = try await self.repository.hasAnyDecks()
                guard !hasAnyDeck else {
                    return
                }

                self.isPresentingOnboarding = true
                let onboarding = OnboardingViewController(repository: self.repository)
                onboarding.onCompleted = { [weak self] in
                    guard let self else { return }
                    NotificationCenter.default.post(name: .deckDataDidChange, object: nil)
                    self.isPresentingOnboarding = false
                }

                let navigation = UINavigationController(rootViewController: onboarding)
                navigation.modalPresentationStyle = .fullScreen
                self.present(navigation, animated: true)
            } catch {
                CrashReporter.record(error: error, context: "RootTabBarController.presentOnboardingIfNeeded")
                self.isPresentingOnboarding = false
            }
        }
    }
}

extension RootTabBarController: UINavigationControllerDelegate {
    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        updateEditorialTabBar(for: viewController, in: navigationController)
    }
}

private final class EditorialTabBarView: UIView {
    static let reservedHeight: CGFloat = 68

    var onSelect: ((Int) -> Void)?
    var selectedIndex = 0 {
        didSet { updateSelection(animated: oldValue != selectedIndex) }
    }

    private let pillView = UIView()
    private let stack = UIStackView()
    private let items: [EditorialTabItemControl]

    init(items: [(title: String, symbol: String, accessibilityIdentifier: String)]) {
        self.items = items.enumerated().map { index, item in
            EditorialTabItemControl(
                index: index,
                title: item.title,
                symbol: item.symbol,
                accessibilityIdentifier: item.accessibilityIdentifier
            )
        }
        super.init(frame: .zero)

        addSubview(pillView)
        self.items.forEach(stack.addArrangedSubview)
        stack.axis = .horizontal
        stack.alignment = .fill
        stack.spacing = 4
        pillView.addSubview(stack)
        pillView.layer.cornerRadius = 27
        pillView.layer.cornerCurve = .continuous

        pillView.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pillView.centerXAnchor.constraint(equalTo: centerXAnchor),
            pillView.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            pillView.heightAnchor.constraint(equalToConstant: 54),
            stack.leadingAnchor.constraint(equalTo: pillView.leadingAnchor, constant: 5),
            stack.trailingAnchor.constraint(equalTo: pillView.trailingAnchor, constant: -5),
            stack.topAnchor.constraint(equalTo: pillView.topAnchor, constant: 5),
            stack.bottomAnchor.constraint(equalTo: pillView.bottomAnchor, constant: -5)
        ])

        self.items.forEach { item in
            item.addAction(UIAction { [weak self] _ in
                self?.onSelect?(item.index)
            }, for: .touchUpInside)
        }
        applyTheme()
        updateSelection(animated: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // The bar floats over content; only the pill itself takes touches.
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        pillView.frame.contains(point)
    }

    func applyTheme() {
        backgroundColor = .clear
        pillView.backgroundColor = AppTheme.inkSurface
        items.forEach { $0.setSelected($0.index == selectedIndex) }
    }

    private func updateSelection(animated: Bool) {
        let changes = { [self] in
            items.forEach { $0.setSelected($0.index == selectedIndex) }
            layoutIfNeeded()
        }
        guard animated, !UIAccessibility.isReduceMotionEnabled else {
            changes()
            return
        }
        UIView.animate(
            withDuration: 0.32,
            delay: 0,
            usingSpringWithDamping: 0.82,
            initialSpringVelocity: 0.4,
            options: [.allowUserInteraction, .beginFromCurrentState],
            animations: changes
        )
    }
}

private final class EditorialTabItemControl: UIControl {
    let index: Int

    private let symbol: String
    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    private let contentStack = UIStackView()

    init(index: Int, title: String, symbol: String, accessibilityIdentifier: String) {
        self.index = index
        self.symbol = symbol
        super.init(frame: .zero)

        self.accessibilityIdentifier = accessibilityIdentifier
        isAccessibilityElement = true
        accessibilityLabel = title
        accessibilityTraits = .button

        imageView.contentMode = .center
        titleLabel.text = title
        titleLabel.font = AppTypography.font(size: 13, weight: .bold, textStyle: .footnote, maximumPointSize: 16)

        contentStack.axis = .horizontal
        contentStack.alignment = .center
        contentStack.spacing = 6
        contentStack.isUserInteractionEnabled = false
        contentStack.addArrangedSubview(imageView)
        contentStack.addArrangedSubview(titleLabel)
        addSubview(contentStack)

        layer.cornerRadius = 22
        layer.cornerCurve = .continuous

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 15),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -15),
            widthAnchor.constraint(greaterThanOrEqualToConstant: 52),
            imageView.widthAnchor.constraint(equalToConstant: 22)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setSelected(_ isSelected: Bool) {
        imageView.image = AppIcon.image(isSelected ? "\(symbol).fill" : symbol, size: 22)
        imageView.tintColor = isSelected ? AppTheme.studyInk : AppTheme.onInk.withAlphaComponent(0.72)
        titleLabel.textColor = AppTheme.studyInk
        titleLabel.isHidden = !isSelected
        backgroundColor = isSelected ? AppTheme.lime : .clear
        accessibilityTraits = isSelected ? [.button, .selected] : .button
    }
}
