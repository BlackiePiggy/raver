import SwiftUI
import UIKit
import ExyteChat

final class RaverChatComposerTextView: UITextView {
    let placeholderLabel = UILabel()
    var renderModel: TencentEmojiRenderModel?

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setupPlaceholder()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let left = textContainerInset.left + textContainer.lineFragmentPadding
        let top = textContainerInset.top
        let availableWidth = bounds.width - left - textContainerInset.right - textContainer.lineFragmentPadding
        let fittingSize = placeholderLabel.sizeThatFits(
            CGSize(width: max(0, availableWidth), height: .greatestFiniteMagnitude)
        )
        placeholderLabel.frame = CGRect(
            x: left,
            y: top,
            width: max(0, availableWidth),
            height: fittingSize.height
        )
    }

    private func setupPlaceholder() {
        placeholderLabel.numberOfLines = 0
        placeholderLabel.backgroundColor = .clear
        addSubview(placeholderLabel)
    }
}

struct RaverChatComposerTextViewRepresentable: UIViewRepresentable {
    @Binding var text: String

    @ObservedObject var state: RaverChatComposerState

    let isFocused: Bool
    let placeholder: String
    let placeholderColor: UIColor
    let textColor: UIColor
    let accentColor: UIColor
    let horizontalInset: CGFloat
    let onSend: () -> Void
    let onFocusChange: (Bool) -> Void

    func makeCoordinator() -> RaverChatComposerCoordinator {
        RaverChatComposerCoordinator(
            text: $text,
            state: state,
            onSend: onSend,
            onFocusChange: onFocusChange
        )
    }

    func makeUIView(context: Context) -> RaverChatComposerTextView {
        let textView = RaverChatComposerTextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.textColor = textColor
        textView.tintColor = accentColor
        textView.returnKeyType = .send
        textView.isScrollEnabled = false
        textView.showsVerticalScrollIndicator = false
        textView.showsHorizontalScrollIndicator = false
        textView.autocorrectionType = .default
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = UIEdgeInsets(top: 10, left: horizontalInset, bottom: 10, right: 0)
        textView.placeholderLabel.font = textView.font
        textView.placeholderLabel.textColor = placeholderColor
        textView.placeholderLabel.text = placeholder
        context.coordinator.sync(textView: textView, text: text, isFocused: isFocused)
        return textView
    }

    func updateUIView(_ uiView: RaverChatComposerTextView, context: Context) {
        uiView.textColor = textColor
        uiView.tintColor = accentColor
        uiView.textContainerInset = UIEdgeInsets(top: 10, left: horizontalInset, bottom: 10, right: 0)
        uiView.placeholderLabel.text = placeholder
        uiView.placeholderLabel.textColor = placeholderColor
        context.coordinator.sync(textView: uiView, text: text, isFocused: isFocused)
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: RaverChatComposerTextView,
        context: Context
    ) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width
        let fitting = uiView.sizeThatFits(
            CGSize(width: width, height: .greatestFiniteMagnitude)
        )
        return CGSize(width: width, height: max(44, fitting.height))
    }
}
