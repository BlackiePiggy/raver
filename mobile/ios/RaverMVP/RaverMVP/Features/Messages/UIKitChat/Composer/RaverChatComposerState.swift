import Combine
import Foundation

@MainActor
final class RaverChatComposerState: ObservableObject {
    @Published var selectionRange = NSRange(location: 0, length: 0)
    @Published var isShowingEmojiPanel = false
    @Published var isShowingAttachmentPanel = false
    @Published var selectedEmojiPackID = "tencent-default"

    var isTextViewFocused = false

    func clampSelection(for text: String) {
        let textLength = (text as NSString).length
        let clampedLocation = min(max(0, selectionRange.location), textLength)
        let maxLength = max(0, textLength - clampedLocation)
        let clampedLength = min(max(0, selectionRange.length), maxLength)
        let clampedRange = NSRange(location: clampedLocation, length: clampedLength)
        guard selectionRange != clampedRange else { return }
        selectionRange = clampedRange
    }

    func updateSelectionRange(_ newValue: NSRange, in text: String) {
        let textLength = (text as NSString).length
        let clampedLocation = min(max(0, newValue.location), textLength)
        let maxLength = max(0, textLength - clampedLocation)
        let clampedLength = min(max(0, newValue.length), maxLength)
        let clampedRange = NSRange(location: clampedLocation, length: clampedLength)
        guard selectionRange != clampedRange else { return }
        selectionRange = clampedRange
    }
}
