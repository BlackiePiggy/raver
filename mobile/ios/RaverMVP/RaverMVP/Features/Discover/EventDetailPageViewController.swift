import UIKit
import SwiftUI

final class EventDetailPageViewController: UIViewController,
    UIPageViewControllerDataSource,
    UIPageViewControllerDelegate,
    UIScrollViewDelegate
{
    var onPageChange: ((Int) -> Void)?
    var onPageProgress: ((CGFloat) -> Void)?
    var onActivePageVerticalOffsetChanged: ((CGFloat) -> Void)?

    private var pageViewController: UIPageViewController!
    private var pages: [EventDetailHostingController] = []
    private var currentIndex: Int = 0
    private weak var pagingScrollView: UIScrollView?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupPageViewController()
        ensureInitialPageIfNeeded()
    }

    func configure(with rootViews: [AnyView]) {
        if pages.count == rootViews.count, !pages.isEmpty {
            for (index, rootView) in rootViews.enumerated() {
                pages[index].updateRootView(rootView)
            }
            return
        }

        pages = rootViews.map { EventDetailHostingController(rootView: $0) }
        for (index, page) in pages.enumerated() {
            page.onVerticalOffsetChanged = { [weak self] offset in
                self?.handleVerticalOffset(offset, forPageAt: index)
            }
        }

        currentIndex = max(0, min(currentIndex, max(0, pages.count - 1)))

        if isViewLoaded {
            ensureInitialPageIfNeeded(force: true)
        }
    }

    func updatePage(at index: Int, rootView: AnyView) {
        guard pages.indices.contains(index) else { return }
        pages[index].updateRootView(rootView)
    }

    func setContentInsets(top: CGFloat, bottom: CGFloat) {
        for page in pages {
            page.setContentInsets(top: top, bottom: bottom)
        }
        emitActivePageOffset()
    }

    func setSelectedIndex(_ index: Int, animated: Bool) {
        guard pages.indices.contains(index) else { return }
        guard index != currentIndex else {
            emitActivePageOffset()
            return
        }

        guard isViewLoaded else {
            currentIndex = index
            return
        }

        let previousIndex = currentIndex
        let direction: UIPageViewController.NavigationDirection = index > currentIndex ? .forward : .reverse
        currentIndex = index
        pageViewController.setViewControllers(
            [pages[index]],
            direction: direction,
            animated: animated
        ) { [weak self] _ in
            guard let self else { return }
            self.onPageProgress?(CGFloat(self.currentIndex))
            self.resetPageIfNeeded(at: previousIndex, excluding: self.currentIndex)
            self.emitActivePageOffset()
        }

        if !animated {
            onPageProgress?(CGFloat(index))
            resetPageIfNeeded(at: previousIndex, excluding: index)
            emitActivePageOffset()
        }
    }

    func currentActiveOffset() -> CGFloat {
        guard pages.indices.contains(currentIndex) else { return 0 }
        return pages[currentIndex].currentLogicalOffset()
    }

    private func setupPageViewController() {
        pageViewController = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal
        )
        pageViewController.dataSource = self
        pageViewController.delegate = self
        pageViewController.view.backgroundColor = .clear

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

        if let internalScrollView = pageViewController.view.subviews.first(where: { $0 is UIScrollView }) as? UIScrollView {
            internalScrollView.delegate = self
            internalScrollView.scrollsToTop = false
            internalScrollView.showsHorizontalScrollIndicator = false
            pagingScrollView = internalScrollView
        }
    }

    private func ensureInitialPageIfNeeded(force: Bool = false) {
        guard !pages.isEmpty else { return }
        guard force || pageViewController.viewControllers?.isEmpty ?? true else { return }

        let safeIndex = max(0, min(currentIndex, pages.count - 1))
        currentIndex = safeIndex
        pageViewController.setViewControllers([pages[safeIndex]], direction: .forward, animated: false)
        onPageProgress?(CGFloat(safeIndex))
        emitActivePageOffset()
    }

    private func handleVerticalOffset(_ offset: CGFloat, forPageAt index: Int) {
        guard index == currentIndex else { return }
        onActivePageVerticalOffsetChanged?(offset)
    }

    private func emitActivePageOffset() {
        onActivePageVerticalOffsetChanged?(currentActiveOffset())
    }

    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerBefore viewController: UIViewController
    ) -> UIViewController? {
        guard let current = viewController as? EventDetailHostingController,
              let index = pages.firstIndex(where: { $0 === current }),
              index > 0 else {
            return nil
        }
        return pages[index - 1]
    }

    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerAfter viewController: UIViewController
    ) -> UIViewController? {
        guard let current = viewController as? EventDetailHostingController,
              let index = pages.firstIndex(where: { $0 === current }),
              index < pages.count - 1 else {
            return nil
        }
        return pages[index + 1]
    }

    func pageViewController(
        _ pageViewController: UIPageViewController,
        didFinishAnimating finished: Bool,
        previousViewControllers: [UIViewController],
        transitionCompleted completed: Bool
    ) {
        guard completed,
              let current = pageViewController.viewControllers?.first as? EventDetailHostingController,
              let index = pages.firstIndex(where: { $0 === current }) else {
            return
        }

        currentIndex = index
        onPageChange?(index)
        onPageProgress?(CGFloat(index))
        for previous in previousViewControllers {
            resetScrollPosition(of: previous)
        }
        emitActivePageOffset()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === pagingScrollView else { return }
        guard pages.count > 1 else { return }

        let width = scrollView.bounds.width
        guard width > 0 else { return }

        let relative = (scrollView.contentOffset.x - width) / width
        let rawProgress = CGFloat(currentIndex) + relative
        let clampedProgress = min(max(rawProgress, 0), CGFloat(pages.count - 1))
        onPageProgress?(clampedProgress)
    }

    private func resetPageIfNeeded(at index: Int, excluding excludedIndex: Int) {
        guard index != excludedIndex else { return }
        guard pages.indices.contains(index) else { return }
        pages[index].resetScrollToTop()
    }

    private func resetScrollPosition(of viewController: UIViewController) {
        if let hosting = viewController as? EventDetailHostingController {
            hosting.resetScrollToTop()
        }
    }
}
