import Foundation
import SwiftUI
import UIKit
import ExyteChat

@MainActor
final class RaverChatComposerCoordinator: NSObject, UITextViewDelegate {
    private var text: Binding<String>
    private let state: RaverChatComposerState
    private let onSend: () -> Void
    private let onFocusChange: (Bool) -> Void

    private var isApplyingProgrammaticChange = false
    private weak var scheduledFocusTextView: RaverChatComposerTextView?
    private var scheduledFocusState: Bool?

    init(
        text: Binding<String>,
        state: RaverChatComposerState,
        onSend: @escaping () -> Void,
        onFocusChange: @escaping (Bool) -> Void
    ) {
        self.text = text
        self.state = state
        self.onSend = onSend
        self.onFocusChange = onFocusChange
    }

    func sync(
        textView: RaverChatComposerTextView,
        text sourceText: String,
        isFocused: Bool
    ) {
        let hasMarkedText = !(textView.markedTextRange?.isEmpty ?? true)
        if !hasMarkedText || !textView.isFirstResponder {
            applyTextIfNeeded(sourceText, to: textView)
            applySelectionIfNeeded(to: textView, text: sourceText)
        }

        scheduleFocusUpdateIfNeeded(for: textView, isFocused: isFocused)

        textView.placeholderLabel.isHidden = !sourceText.isEmpty
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        state.isTextViewFocused = true
        onFocusChange(true)
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        state.isTextViewFocused = false
        onFocusChange(false)
    }

    func textViewDidChange(_ textView: UITextView) {
        guard !isApplyingProgrammaticChange else { return }
        let updatedText = sourceText(from: textView)
        if text.wrappedValue != updatedText {
            text.wrappedValue = updatedText
        }
        state.updateSelectionRange(
            sourceSelectionRange(from: textView, sourceText: updatedText),
            in: updatedText
        )
        (textView as? RaverChatComposerTextView)?.placeholderLabel.isHidden = !updatedText.isEmpty
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
        guard !isApplyingProgrammaticChange else { return }
        let sourceText = self.text.wrappedValue
        state.updateSelectionRange(
            sourceSelectionRange(from: textView, sourceText: sourceText),
            in: sourceText
        )
    }

    func textView(
        _ textView: UITextView,
        shouldChangeTextIn range: NSRange,
        replacementText text: String
    ) -> Bool {
        if text == "\n" {
            let composed = (textView.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !composed.isEmpty {
                onSend()
            }
            return false
        }
        return true
    }

    private func applyTextIfNeeded(_ sourceText: String, to textView: UITextView) {
        if let textView = textView as? RaverChatComposerTextView {
            let needsEmojiRendering = TencentEmojiCatalog.containsRenderableEmoji(in: sourceText)

            if needsEmojiRendering {
                let font = textView.font ?? UIFont.preferredFont(forTextStyle: .body)
                let textColor = textView.textColor ?? UIColor.label
                let renderModel = TencentEmojiCatalog.renderModel(
                    for: sourceText,
                    font: font,
                    textColor: textColor
                )
                let shouldSkip = textView.renderModel?.sourceText == sourceText &&
                    textView.attributedText.isEqual(to: renderModel.attributedString)
                guard !shouldSkip else { return }

                isApplyingProgrammaticChange = true
                textView.renderModel = renderModel
                textView.attributedText = renderModel.attributedString
                textView.typingAttributes = [
                    .font: font,
                    .foregroundColor: textColor
                ]
                isApplyingProgrammaticChange = false
                return
            }

            textView.renderModel = nil
        }

        guard textView.text != sourceText else { return }
        isApplyingProgrammaticChange = true
        textView.text = sourceText
        textView.typingAttributes = [
            .font: textView.font ?? UIFont.preferredFont(forTextStyle: .body),
            .foregroundColor: textView.textColor ?? UIColor.label
        ]
        isApplyingProgrammaticChange = false
    }

    private func applySelectionIfNeeded(to textView: UITextView, text: String) {
        state.clampSelection(for: text)
        let targetRange = displaySelectionRange(for: state.selectionRange, in: textView)
        guard textView.selectedRange != targetRange else { return }
        isApplyingProgrammaticChange = true
        textView.selectedRange = targetRange
        isApplyingProgrammaticChange = false
    }

    private func scheduleFocusUpdateIfNeeded(
        for textView: RaverChatComposerTextView,
        isFocused: Bool
    ) {
        let currentlyFocused = textView.isFirstResponder
        guard currentlyFocused != isFocused else {
            scheduledFocusTextView = nil
            scheduledFocusState = nil
            return
        }
        guard scheduledFocusTextView !== textView || scheduledFocusState != isFocused else {
            return
        }

        scheduledFocusTextView = textView
        scheduledFocusState = isFocused

        DispatchQueue.main.async { [weak self, weak textView] in
            guard let self, let textView else { return }
            guard self.scheduledFocusTextView === textView,
                  self.scheduledFocusState == isFocused else { return }

            self.scheduledFocusTextView = nil
            self.scheduledFocusState = nil

            if isFocused, !textView.isFirstResponder {
                textView.becomeFirstResponder()
            } else if !isFocused, textView.isFirstResponder {
                textView.resignFirstResponder()
            }
        }
    }

    private func sourceText(from textView: UITextView) -> String {
        guard let textView = textView as? RaverChatComposerTextView,
              textView.renderModel != nil else {
            return textView.text ?? ""
        }
        return TencentEmojiCatalog.sourceText(from: textView.attributedText)
    }

    private func sourceSelectionRange(from textView: UITextView, sourceText: String) -> NSRange {
        guard let textView = textView as? RaverChatComposerTextView,
              let renderModel = textView.renderModel else {
            return textView.selectedRange
        }
        let sourceRange = renderModel.sourceRange(forDisplayRange: textView.selectedRange)
        let textLength = (sourceText as NSString).length
        let location = min(max(0, sourceRange.location), textLength)
        let length = min(max(0, sourceRange.length), max(0, textLength - location))
        return NSRange(location: location, length: length)
    }

    private func displaySelectionRange(for sourceRange: NSRange, in textView: UITextView) -> NSRange {
        guard let textView = textView as? RaverChatComposerTextView,
              let renderModel = textView.renderModel else {
            return sourceRange
        }

        let start = renderModel.displayLocation(forSourceLocation: sourceRange.location)
        let end = renderModel.displayLocation(forSourceLocation: sourceRange.location + sourceRange.length)
        return NSRange(location: start, length: max(0, end - start))
    }
}
