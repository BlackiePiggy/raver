import UIKit
import SwiftUI

final class EventDetailHostingController: UIViewController, UIScrollViewDelegate {
    private let scrollView: UIScrollView = {
        let view = UIScrollView()
        view.backgroundColor = .clear
        view.showsVerticalScrollIndicator = false
        view.showsHorizontalScrollIndicator = false
        view.alwaysBounceVertical = true
        view.alwaysBounceHorizontal = false
        view.contentInsetAdjustmentBehavior = .never
        view.keyboardDismissMode = .interactive
        view.scrollsToTop = false
        return view
    }()

    private let hostingController: UIHostingController<AnyView>
    private var topInset: CGFloat = 0
    private var bottomInset: CGFloat = 0
    private var hasAppliedInitialOffset = false

    var onVerticalOffsetChanged: ((CGFloat) -> Void)?

    init(rootView: AnyView) {
        hostingController = UIHostingController(rootView: rootView)
        if #available(iOS 16.0, *) {
            hostingController.sizingOptions = [.preferredContentSize, .intrinsicContentSize]
        }
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        hostingController.view.backgroundColor = .clear
        setupScrollView()
        setupHostingController()
    }

    func updateRootView(_ rootView: AnyView) {
        hostingController.rootView = rootView
    }

    func setContentInsets(top: CGFloat, bottom: CGFloat) {
        let normalizedTop = max(0, top)
        let normalizedBottom = max(0, bottom)
        let oldTop = topInset

        topInset = normalizedTop
        bottomInset = normalizedBottom

        scrollView.contentInset = UIEdgeInsets(top: normalizedTop, left: 0, bottom: normalizedBottom, right: 0)
        scrollView.scrollIndicatorInsets = UIEdgeInsets(top: normalizedTop, left: 0, bottom: normalizedBottom, right: 0)

        if !hasAppliedInitialOffset {
            scrollView.contentOffset = CGPoint(x: 0, y: -normalizedTop)
            hasAppliedInitialOffset = true
            emitOffset()
            return
        }

        let logicalOffset = scrollView.contentOffset.y + oldTop
        scrollView.contentOffset = CGPoint(x: 0, y: logicalOffset - normalizedTop)
        emitOffset()
    }

    func currentLogicalOffset() -> CGFloat {
        max(0, scrollView.contentOffset.y + topInset)
    }

    func resetScrollToTop() {
        let targetOffset = CGPoint(x: 0, y: -topInset)
        scrollView.setContentOffset(targetOffset, animated: false)
        emitOffset()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        emitOffset()
    }

    private func setupScrollView() {
        scrollView.delegate = self
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func setupHostingController() {
        addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(hostingController.view)

        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            hostingController.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])

        hostingController.didMove(toParent: self)
    }

    private func emitOffset() {
        onVerticalOffsetChanged?(currentLogicalOffset())
    }
}
