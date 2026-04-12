import UIKit
import SwiftUI

final class EventDetailScrollViewController: UIViewController {
    var onTabIndexChange: ((Int) -> Void)?
    var onPageProgressChange: ((CGFloat) -> Void)?

    private let heroHeight: CGFloat = 360
    private let tabBarHeight: CGFloat = 52
    private let topBarHeight: CGFloat = 44

    private let pageViewController = EventDetailPageViewController()
    private let heroViewController = UIHostingController(rootView: AnyView(EmptyView()))
    private let tabBarViewController = UIHostingController(rootView: AnyView(EmptyView()))
    private let tabBarContainer = UIView()
    private let topOverlayView = UIView()
    private let titleLabel = UILabel()

    private var heroTopConstraint: NSLayoutConstraint!
    private var tabBarTopConstraint: NSLayoutConstraint!
    private var topOverlayHeightConstraint: NSLayoutConstraint!
    private var didSetupHierarchy = false

    private var pendingHeroView: AnyView?
    private var pendingTitle: String = ""
    private var pendingTabTitles: [String] = []
    private var pendingTabBarView: AnyView?
    private var pendingPageViews: [AnyView] = []
    private var pendingSelectedIndex: Int = 0
    private var pendingProgress: CGFloat = 0
    private var currentSelectedIndex: Int = 0
    private var isApplyingProgrammaticSelection = false
    private var didApplyInitialPosition = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(RaverTheme.background)
        heroViewController.view.backgroundColor = .clear
        tabBarViewController.view.backgroundColor = .clear
        pageViewController.view.backgroundColor = .clear
        tabBarContainer.backgroundColor = UIColor(RaverTheme.background)
        setupHierarchyIfNeeded()
        if #available(iOS 16.4, *) {
            heroViewController.safeAreaRegions = []
            tabBarViewController.safeAreaRegions = []
        }
        wireCallbacks()
        applyPendingState(animatedSelection: false)
        applyTopOverlayAppearance()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyPageInsets()
        if !didApplyInitialPosition {
            didApplyInitialPosition = true
            updatePinnedHeader(forOffset: 0)
        } else {
            updatePinnedHeader(forOffset: pageViewController.currentActiveOffset())
        }
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        applyPageInsets()
        updatePinnedHeader(forOffset: pageViewController.currentActiveOffset())
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyTopOverlayAppearance()
    }

    func update(
        heroView: AnyView,
        eventTitle: String,
        tabTitles: [String],
        tabBarView: AnyView,
        tabPageViews: [AnyView],
        selectedIndex: Int,
        pageProgress: CGFloat,
        animatedSelection: Bool
    ) {
        pendingHeroView = heroView
        pendingTitle = eventTitle
        pendingTabTitles = tabTitles
        pendingTabBarView = tabBarView
        pendingPageViews = tabPageViews
        pendingSelectedIndex = selectedIndex
        pendingProgress = pageProgress

        guard isViewLoaded else { return }
        applyPendingState(animatedSelection: animatedSelection)
    }

    private func setupHierarchyIfNeeded() {
        guard !didSetupHierarchy else { return }
        didSetupHierarchy = true

        addChild(pageViewController)
        pageViewController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pageViewController.view)
        NSLayoutConstraint.activate([
            pageViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            pageViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        pageViewController.didMove(toParent: self)

        addChild(heroViewController)
        heroViewController.view.translatesAutoresizingMaskIntoConstraints = false
        heroViewController.view.clipsToBounds = true
        view.addSubview(heroViewController.view)
        heroTopConstraint = heroViewController.view.topAnchor.constraint(equalTo: view.topAnchor)
        NSLayoutConstraint.activate([
            heroTopConstraint,
            heroViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            heroViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            heroViewController.view.heightAnchor.constraint(equalToConstant: heroHeight),
        ])
        heroViewController.didMove(toParent: self)

        tabBarContainer.translatesAutoresizingMaskIntoConstraints = false
        tabBarContainer.clipsToBounds = true
        view.addSubview(tabBarContainer)

        addChild(tabBarViewController)
        tabBarViewController.view.translatesAutoresizingMaskIntoConstraints = false
        tabBarContainer.addSubview(tabBarViewController.view)
        tabBarTopConstraint = tabBarContainer.topAnchor.constraint(equalTo: view.topAnchor, constant: heroHeight)
        NSLayoutConstraint.activate([
            tabBarTopConstraint,
            tabBarContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabBarContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabBarContainer.heightAnchor.constraint(equalToConstant: tabBarHeight),

            tabBarViewController.view.topAnchor.constraint(equalTo: tabBarContainer.topAnchor),
            tabBarViewController.view.leadingAnchor.constraint(equalTo: tabBarContainer.leadingAnchor),
            tabBarViewController.view.trailingAnchor.constraint(equalTo: tabBarContainer.trailingAnchor),
            tabBarViewController.view.bottomAnchor.constraint(equalTo: tabBarContainer.bottomAnchor),
        ])
        tabBarViewController.didMove(toParent: self)

        setupTopOverlay()
    }

    private func wireCallbacks() {
        pageViewController.onPageChange = { [weak self] index in
            guard let self else { return }
            currentSelectedIndex = index
            if !isApplyingProgrammaticSelection {
                onTabIndexChange?(index)
            }
        }

        pageViewController.onPageProgress = { [weak self] progress in
            self?.onPageProgressChange?(progress)
        }

        pageViewController.onActivePageVerticalOffsetChanged = { [weak self] offset in
            self?.updatePinnedHeader(forOffset: offset)
        }
    }

    private func applyPendingState(animatedSelection: Bool) {
        if let hero = pendingHeroView {
            heroViewController.rootView = hero
        }
        if let tabBar = pendingTabBarView {
            tabBarViewController.rootView = tabBar
        }

        titleLabel.text = pendingTitle
        _ = pendingTabTitles
        pageViewController.configure(with: pendingPageViews)
        applyPageInsets()

        if pendingSelectedIndex != currentSelectedIndex {
            currentSelectedIndex = pendingSelectedIndex
            isApplyingProgrammaticSelection = true
            pageViewController.setSelectedIndex(pendingSelectedIndex, animated: animatedSelection)
            let releaseDelay = animatedSelection ? 0.4 : 0
            DispatchQueue.main.asyncAfter(deadline: .now() + releaseDelay) { [weak self] in
                self?.isApplyingProgrammaticSelection = false
            }
        } else {
            isApplyingProgrammaticSelection = false
        }

        onPageProgressChange?(pendingProgress)
        if didApplyInitialPosition {
            updatePinnedHeader(forOffset: pageViewController.currentActiveOffset())
        }
    }

    private func applyPageInsets() {
        let topInset = heroHeight + tabBarHeight
        let bottomInset = view.safeAreaInsets.bottom + 20
        pageViewController.setContentInsets(top: topInset, bottom: bottomInset)
        topOverlayHeightConstraint.constant = pinnedTabTopLimit()
    }

    private func updatePinnedHeader(forOffset offset: CGFloat) {
        let clamped = min(max(offset, 0), heroHeight)
        heroTopConstraint.constant = -clamped

        let topLimit = pinnedTabTopLimit()
        let desiredTop = heroHeight - clamped
        tabBarTopConstraint.constant = max(topLimit, desiredTop)

        let pinStart = max(0, heroHeight - topLimit)
        let overlayProgress = min(max((offset - pinStart + 8) / 20, 0), 1)
        topOverlayView.alpha = overlayProgress
        titleLabel.alpha = overlayProgress
    }

    private func pinnedTabTopLimit() -> CGFloat {
        view.safeAreaInsets.top + topBarHeight
    }

    private func setupTopOverlay() {
        topOverlayView.translatesAutoresizingMaskIntoConstraints = false
        topOverlayView.alpha = 0
        topOverlayView.isUserInteractionEnabled = false
        view.addSubview(topOverlayView)

        topOverlayHeightConstraint = topOverlayView.heightAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            topOverlayView.topAnchor.constraint(equalTo: view.topAnchor),
            topOverlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topOverlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topOverlayHeightConstraint,
        ])

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.alpha = 0
        topOverlayView.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: topOverlayView.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            titleLabel.widthAnchor.constraint(equalToConstant: 176),
        ])
    }

    private func applyTopOverlayAppearance() {
        let isDark = traitCollection.userInterfaceStyle != .light
        topOverlayView.backgroundColor = isDark
            ? .black
            : UIColor(RaverTheme.background)
        titleLabel.textColor = isDark
            ? .white
            : UIColor.black.withAlphaComponent(0.88)
    }
}
