//
//  AppWalkthroughViewController.swift
//  FlashForge
//
//  Created by bbdyno on 2/18/26.
//

import UIKit
import SnapKit
import SharedResources

private struct WalkthroughPage {
    let artwork: WalkthroughArtworkKind
    let title: String
    let description: String
}

final class AppWalkthroughViewController: UIViewController {
    private lazy var pages: [WalkthroughPage] = [
        WalkthroughPage(
            artwork: .memory,
            title: FlashForgeStrings.Walkthrough.Page.Intro.title,
            description: FlashForgeStrings.Walkthrough.Page.Intro.description
        ),
        WalkthroughPage(
            artwork: .study,
            title: FlashForgeStrings.Walkthrough.Page.Study.title,
            description: FlashForgeStrings.Walkthrough.Page.Study.description
        ),
        WalkthroughPage(
            artwork: .privacy,
            title: FlashForgeStrings.Walkthrough.Page.Data.title,
            description: FlashForgeStrings.Walkthrough.Page.Data.description
        )
    ]

    var onFinished: (() -> Void)?

    private let backgroundGradientLayer = CAGradientLayer()
    private let pageViewController = UIPageViewController(
        transitionStyle: .scroll,
        navigationOrientation: .horizontal
    )
    private let pageControl = UIPageControl()
    private let primaryButton = UIButton(type: .system)
    private let skipButton = UIButton(type: .system)

    private lazy var pageControllers: [WalkthroughPageContentViewController] = {
        pages.map { WalkthroughPageContentViewController(page: $0) }
    }()

    private var currentIndex = 0 {
        didSet {
            updateControls()
        }
    }
    private var didFinish = false

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
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

        addChild(pageViewController)
        view.addSubview(pageViewController.view)
        pageViewController.didMove(toParent: self)

        view.addSubview(pageControl)
        view.addSubview(primaryButton)
        view.addSubview(skipButton)

        pageViewController.dataSource = self
        pageViewController.delegate = self

        if let first = pageControllers.first {
            pageViewController.setViewControllers([first], direction: .forward, animated: false, completion: nil)
        }

        pageControl.numberOfPages = pages.count
        pageControl.currentPage = 0
        pageControl.addTarget(self, action: #selector(didChangePage(_:)), for: .valueChanged)

        primaryButton.addTarget(self, action: #selector(didTapPrimaryButton), for: .touchUpInside)
        primaryButton.layer.cornerRadius = 14
        primaryButton.layer.cornerCurve = .continuous
        primaryButton.titleLabel?.font = AppTypography.font(size: 17, weight: .bold, textStyle: .headline)

        skipButton.addTarget(self, action: #selector(didTapSkipButton), for: .touchUpInside)
        skipButton.titleLabel?.font = AppTypography.font(size: 14, weight: .semibold, textStyle: .subheadline)

        pageViewController.view.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(22)
            make.leading.trailing.equalToSuperview().inset(20)
            make.bottom.equalTo(pageControl.snp.top).offset(-22)
        }

        pageControl.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(primaryButton.snp.top).offset(-20)
        }

        primaryButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(24)
            make.bottom.equalTo(skipButton.snp.top).offset(-10)
            make.height.equalTo(52)
        }

        skipButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide).inset(14)
            make.height.equalTo(22)
        }

        applyTheme()
        updateControls()
    }

    private func applyTheme() {
        AppTheme.applyGradient(to: backgroundGradientLayer, traitCollection: traitCollection)

        pageControl.currentPageIndicatorTintColor = AppTheme.accent
        pageControl.pageIndicatorTintColor = AppTheme.resolved(AppTheme.cardBorder, for: traitCollection)

        primaryButton.setTitleColor(.white, for: .normal)
        primaryButton.backgroundColor = AppTheme.buttonFill(from: AppTheme.accent, for: traitCollection)
        primaryButton.layer.borderWidth = 0

        skipButton.setTitleColor(AppTheme.textSecondary, for: .normal)
    }

    private func updateControls() {
        pageControl.currentPage = currentIndex

        let primaryTitle = isLastPage
            ? FlashForgeStrings.Walkthrough.Action.start
            : FlashForgeStrings.Walkthrough.Action.next
        primaryButton.setTitle(primaryTitle, for: .normal)

        skipButton.setTitle(FlashForgeStrings.Walkthrough.Action.skip, for: .normal)
        skipButton.isHidden = isLastPage
    }

    private var isLastPage: Bool {
        currentIndex == pageControllers.count - 1
    }

    private func finishWalkthrough() {
        guard !didFinish else {
            return
        }
        didFinish = true
        onFinished?()
    }

    private func controller(at index: Int) -> WalkthroughPageContentViewController? {
        guard pageControllers.indices.contains(index) else {
            return nil
        }
        return pageControllers[index]
    }

    private func index(of viewController: UIViewController) -> Int? {
        pageControllers.firstIndex { $0 === viewController }
    }

    private func moveToPage(index: Int, animated: Bool) {
        guard index != currentIndex else {
            return
        }
        guard let target = controller(at: index) else {
            return
        }

        let direction: UIPageViewController.NavigationDirection = index >= currentIndex ? .forward : .reverse
        pageViewController.setViewControllers([target], direction: direction, animated: animated, completion: nil)
        currentIndex = index
    }

    @objc
    private func didTapPrimaryButton() {
        if isLastPage {
            finishWalkthrough()
            return
        }

        moveToPage(index: currentIndex + 1, animated: true)
    }

    @objc
    private func didTapSkipButton() {
        finishWalkthrough()
    }

    @objc
    private func didChangePage(_ sender: UIPageControl) {
        moveToPage(index: sender.currentPage, animated: true)
    }
}

extension AppWalkthroughViewController: UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerBefore viewController: UIViewController
    ) -> UIViewController? {
        guard let index = index(of: viewController) else {
            return nil
        }
        return controller(at: index - 1)
    }

    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerAfter viewController: UIViewController
    ) -> UIViewController? {
        guard let index = index(of: viewController) else {
            return nil
        }
        return controller(at: index + 1)
    }

    func pageViewController(
        _ pageViewController: UIPageViewController,
        didFinishAnimating finished: Bool,
        previousViewControllers: [UIViewController],
        transitionCompleted completed: Bool
    ) {
        guard completed,
              let visible = pageViewController.viewControllers?.first,
              let index = index(of: visible) else {
            return
        }
        currentIndex = index
    }
}

private final class WalkthroughPageContentViewController: UIViewController {
    private let page: WalkthroughPage

    private let cardView = UIView()
    private lazy var artworkView = WalkthroughArtworkView(kind: page.artwork)
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()

    init(page: WalkthroughPage) {
        self.page = page
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

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.hasDifferentColorAppearance(comparedTo: traitCollection) == true else {
            return
        }
        applyTheme()
    }

    private func configureUI() {
        view.backgroundColor = .clear

        view.addSubview(cardView)
        cardView.addSubview(artworkView)
        cardView.addSubview(titleLabel)
        cardView.addSubview(descriptionLabel)

        titleLabel.text = page.title
        titleLabel.font = AppTypography.font(size: 32, weight: .bold, textStyle: .title1)
        titleLabel.textAlignment = .left
        titleLabel.numberOfLines = 2

        descriptionLabel.text = page.description
        descriptionLabel.font = AppTypography.font(size: 16, weight: .medium, textStyle: .body)
        descriptionLabel.textAlignment = .left
        descriptionLabel.numberOfLines = 0

        cardView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        artworkView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.leading.trailing.equalToSuperview().inset(4)
            make.height.equalTo(270)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(artworkView.snp.bottom).offset(28)
            make.leading.trailing.equalToSuperview().inset(10)
        }

        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(16)
            make.leading.trailing.equalTo(titleLabel)
            make.bottom.lessThanOrEqualToSuperview().inset(32)
        }

        applyTheme()
    }

    private func applyTheme() {
        cardView.backgroundColor = .clear
        cardView.layer.borderWidth = 0

        titleLabel.textColor = AppTheme.textPrimary
        descriptionLabel.textColor = AppTheme.textSecondary
    }
}
