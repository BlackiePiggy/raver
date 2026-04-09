import SwiftUI
import PhotosUI
import AVKit
import AVFoundation
import UIKit
import Photos
import CoreImage.CIFilterBuiltins
import MapKit
import CoreLocation
import CoreText

private extension UIView {
    func findEnclosingScrollView() -> UIScrollView? {
        var current: UIView? = superview
        while let view = current {
            if let sv = view as? UIScrollView, sv !== self {
                return sv
            }
            current = view.superview
        }
        return nil
    }
}


struct HorizontalAxisLockedScrollView<Content: View>: UIViewRepresentable {
    let showsIndicators: Bool
    let contentOffsetX: Binding<CGFloat>?
    let onDraggingChanged: ((Bool) -> Void)?
    let content: Content

    init(
        showsIndicators: Bool = false,
        contentOffsetX: Binding<CGFloat>? = nil,
        onDraggingChanged: ((Bool) -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.showsIndicators = showsIndicators
        self.contentOffsetX = contentOffsetX
        self.onDraggingChanged = onDraggingChanged
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            content: content,
            contentOffsetX: contentOffsetX,
            onDraggingChanged: onDraggingChanged
        )
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .clear
        scrollView.showsHorizontalScrollIndicator = showsIndicators
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bounces = true
        scrollView.alwaysBounceHorizontal = true
        scrollView.alwaysBounceVertical = false
        scrollView.delaysContentTouches = true
        scrollView.canCancelContentTouches = true
        scrollView.isDirectionalLockEnabled = true
        scrollView.clipsToBounds = true
        scrollView.delegate = context.coordinator

        DispatchQueue.main.async {
            if let parentScrollView = scrollView.findEnclosingScrollView() {
                parentScrollView.panGestureRecognizer.require(toFail: scrollView.panGestureRecognizer)
            }
        }

        let hostedView = context.coordinator.hostingController.view
        hostedView?.backgroundColor = .clear
        hostedView?.translatesAutoresizingMaskIntoConstraints = false

        if let hostedView {
            scrollView.addSubview(hostedView)
            NSLayoutConstraint.activate([
                hostedView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
                hostedView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
                hostedView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
                hostedView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
                hostedView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
            ])
        }

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        uiView.showsHorizontalScrollIndicator = showsIndicators
        context.coordinator.hostingController.rootView = content
        context.coordinator.contentOffsetX = contentOffsetX
        context.coordinator.onDraggingChanged = onDraggingChanged

        if let storedOffsetX = contentOffsetX?.wrappedValue,
           !uiView.isDragging,
           !uiView.isDecelerating,
           uiView.bounds.width > 0 {
            let minOffsetX = -uiView.adjustedContentInset.left
            let maxOffsetX = max(
                minOffsetX,
                uiView.contentSize.width - uiView.bounds.width + uiView.adjustedContentInset.right
            )
            let clampedOffsetX = min(max(storedOffsetX, minOffsetX), maxOffsetX)

            if abs(uiView.contentOffset.x - clampedOffsetX) > 0.5 {
                uiView.setContentOffset(CGPoint(x: clampedOffsetX, y: uiView.contentOffset.y), animated: false)
            }
        }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        let hostingController: UIHostingController<Content>
        var contentOffsetX: Binding<CGFloat>?
        var onDraggingChanged: ((Bool) -> Void)?
        private var isDraggingNotified = false

        init(
            content: Content,
            contentOffsetX: Binding<CGFloat>?,
            onDraggingChanged: ((Bool) -> Void)?
        ) {
            hostingController = UIHostingController(rootView: content)
            hostingController.view.backgroundColor = .clear
            self.contentOffsetX = contentOffsetX
            self.onDraggingChanged = onDraggingChanged
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            contentOffsetX?.wrappedValue = scrollView.contentOffset.x
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            guard !isDraggingNotified else { return }
            isDraggingNotified = true
            onDraggingChanged?(true)
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            guard !decelerate else { return }
            finishDragging()
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            finishDragging()
        }

        private func finishDragging() {
            guard isDraggingNotified else { return }
            isDraggingNotified = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
                self?.onDraggingChanged?(false)
            }
        }
    }
}

private struct JustifiedUILabelText: UIViewRepresentable {
    let text: String
    let font: UIFont
    let color: UIColor
    let lineSpacing: CGFloat

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.backgroundColor = .clear
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .vertical)
        return label
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        let targetWidth = proposal.width ?? UIScreen.main.bounds.width
        let fittingSize = uiView.sizeThatFits(
            CGSize(width: targetWidth, height: .greatestFiniteMagnitude)
        )
        return CGSize(width: targetWidth, height: ceil(fittingSize.height))
    }

    func updateUIView(_ uiView: UILabel, context: Context) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .justified
        paragraph.baseWritingDirection = .natural
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = lineSpacing

        uiView.attributedText = NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ]
        )
    }
}

func topSafeAreaInset() -> CGFloat {
    UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap { $0.windows }
        .first(where: { $0.isKeyWindow })?
        .safeAreaInsets.top ?? 0
}




