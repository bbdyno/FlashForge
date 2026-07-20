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
    private var hasCheckedInitialFlow = false
    private var isPresentingWalkthrough = false
    private var isPresentingOnboarding = false

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
        configureTabs()
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

    private func configureTabs() {
        let study = HomeViewController(repository: repository)
        let studyNavigation = UINavigationController(rootViewController: study)
        studyNavigation.navigationBar.isHidden = true
        studyNavigation.tabBarItem = UITabBarItem(
            title: FlashForgeStrings.Tab.study,
            image: UIImage(systemName: "sparkles"),
            selectedImage: UIImage(systemName: "sparkles")
        )
        studyNavigation.tabBarItem.accessibilityIdentifier = "tab.study"

        let decks = DecksViewController(repository: repository)
        let decksNavigation = UINavigationController(rootViewController: decks)
        decksNavigation.navigationBar.prefersLargeTitles = true
        decksNavigation.tabBarItem = UITabBarItem(
            title: FlashForgeStrings.Tab.decks,
            image: UIImage(systemName: "rectangle.stack"),
            selectedImage: UIImage(systemName: "rectangle.stack.fill")
        )
        decksNavigation.tabBarItem.accessibilityIdentifier = "tab.decks"

        let insights = InsightsViewController(repository: repository)
        let insightsNavigation = UINavigationController(rootViewController: insights)
        insightsNavigation.navigationBar.prefersLargeTitles = true
        insightsNavigation.tabBarItem = UITabBarItem(
            title: FlashForgeStrings.Tab.insights,
            image: UIImage(systemName: "chart.xyaxis.line"),
            selectedImage: UIImage(systemName: "chart.xyaxis.line")
        )
        insightsNavigation.tabBarItem.accessibilityIdentifier = "tab.insights"

        viewControllers = [studyNavigation, decksNavigation, insightsNavigation]
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
                .font: AppTypography.font(size: 10, weight: .semibold, textStyle: .caption2)
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
