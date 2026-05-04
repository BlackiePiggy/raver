import ExyteChat
import SwiftUI

struct RaverChatMentionCandidate: Identifiable, Hashable {
    let username: String
    let displayName: String?

    var id: String { username.lowercased() }

    var title: String {
        let trimmed = displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty || trimmed.caseInsensitiveCompare(username) == .orderedSame {
            return "@\(username)"
        }
        return "@\(username) · \(trimmed)"
    }
}

struct RaverChatComposerView: View {
    private struct MentionContext {
        let replacementRange: NSRange
        let query: String
    }

    private struct EmojiPackDescriptor: Identifiable, Hashable {
        let id: String
        let title: String
        let iconSystemName: String
        let items: [TencentEmojiItem]
    }

    @Environment(\.chatTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    let parameters: InputViewBuilderParameters
    let mentionCandidates: [RaverChatMentionCandidate]

    @StateObject private var composerState = RaverChatComposerState()

    private var isMessageStyle: Bool {
        parameters.inputViewStyle == .message
    }

    private var placeholderText: String {
        if isMessageStyle {
            return L("发消息...", "Message...")
        }
        return L("添加说明...", "Add a caption...")
    }

    private var sendEnabled: Bool {
        !parameters.text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !parameters.attachments.medias.isEmpty ||
            parameters.attachments.recording != nil ||
            parameters.attachments.giphyMedia != nil
    }

    private var isMediaAvailable: Bool {
        true
    }

    private var isAudioAvailable: Bool {
        true
    }

    private var currentMentionContext: MentionContext? {
        mentionContext(
            in: parameters.text.wrappedValue,
            selectionRange: composerState.selectionRange
        )
    }

    private var filteredMentionCandidates: [RaverChatMentionCandidate] {
        guard let context = currentMentionContext else { return [] }
        let query = context.query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty {
            return Array(mentionCandidates.prefix(8))
        }
        return mentionCandidates
            .filter {
                $0.username.lowercased().contains(query) ||
                ($0.displayName?.lowercased().contains(query) ?? false)
            }
            .prefix(8)
            .map { $0 }
    }

    var body: some View {
        VStack(spacing: 0) {
            composerTopView
                .padding(.top, 6)

            HStack(alignment: .bottom, spacing: 10) {
                HStack(alignment: .bottom, spacing: 0) {
                    leftView
                    middleView
                    rightOutsideButton
                }
                .background {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(isMessageStyle ? theme.colors.inputBG : theme.colors.inputSignatureBG)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            bottomAccessory
                .padding(.top, 4)
        }
        .background(isMessageStyle ? theme.colors.mainBG : theme.colors.inputSignatureBG)
        .onAppear {
            composerState.clampSelection(for: parameters.text.wrappedValue)
        }
        .onChange(of: parameters.text.wrappedValue) { _, newValue in
            composerState.clampSelection(for: newValue)
            if !filteredMentionCandidates.isEmpty, composerState.isShowingEmojiPanel {
                composerState.isShowingEmojiPanel = false
            }
        }
    }

    @ViewBuilder
    private var composerTopView: some View {
        VStack(spacing: 10) {
            if isMessageStyle, let replyMessage = parameters.attachments.replyMessage {
                replyBar(replyMessage)
            }
        }
    }

    @ViewBuilder
    private var leftView: some View {
        if isMessageStyle, isMediaAvailable {
            attachButton
        }
    }

    private var middleView: some View {
        RaverChatComposerTextViewRepresentable(
            text: parameters.text,
            state: composerState,
            isFocused: parameters.isFocused,
            placeholder: placeholderText,
            placeholderColor: UIColor(
                isMessageStyle ? theme.colors.inputPlaceholderText : theme.colors.inputSignaturePlaceholderText
            ),
            textColor: UIColor(
                isMessageStyle ? theme.colors.inputText : theme.colors.inputSignatureText
            ),
            accentColor: UIColor(
                isMessageStyle ? theme.colors.sendButtonBackground : theme.colors.inputSignatureText
            ),
            horizontalInset: isMediaAvailable ? 0 : 12,
            onSend: {
                guard sendEnabled else { return }
                parameters.inputViewActionClosure(.send)
            },
            onFocusChange: { shouldFocus in
                parameters.setFocusedClosure(shouldFocus)
            }
        )
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
    }

    @ViewBuilder
    private var rightOutsideButton: some View {
        HStack(alignment: .center, spacing: 4) {
            if isMessageStyle, isAudioAvailable {
                voiceEntryButton
            }

            if isMessageStyle {
                emojiToggleButton
            }

            sendButton
        }
        .fixedSize(horizontal: true, vertical: false)
        .frame(height: 48)
    }

    @ViewBuilder
    private var bottomAccessory: some View {
        if isMessageStyle {
            if !filteredMentionCandidates.isEmpty {
                mentionPanel
            } else if composerState.isShowingEmojiPanel {
                emojiPanel
            } else if composerState.isShowingAttachmentPanel {
                attachmentPanel
            }
        }
    }

    private var attachButton: some View {
        Button {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.92)) {
                composerState.isShowingEmojiPanel = false
                composerState.isShowingAttachmentPanel.toggle()
            }
            parameters.dismissKeyboardClosure()
        } label: {
            theme.images.inputView.add
                .renderingMode(.template)
                .foregroundColor(theme.colors.sendButtonBackground)
                .frame(width: 24, height: 24)
                .padding(EdgeInsets(top: 12, leading: 8, bottom: 12, trailing: 6))
        }
        .buttonStyle(.plain)
    }

    private var voiceEntryButton: some View {
        Button {
            parameters.inputViewActionClosure(.recordAudioTap)
        } label: {
            theme.images.inputView.microphone
                .renderingMode(.template)
                .foregroundColor(theme.colors.sendButtonBackground)
                .frame(width: 22, height: 22)
                .padding(EdgeInsets(top: 12, leading: 6, bottom: 12, trailing: 6))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var emojiToggleButton: some View {
        Button {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.92)) {
                composerState.isShowingAttachmentPanel = false
                if filteredMentionCandidates.isEmpty {
                    composerState.isShowingEmojiPanel.toggle()
                }
            }
            if composerState.isShowingEmojiPanel {
                parameters.dismissKeyboardClosure()
            } else {
                parameters.setFocusedClosure(true)
            }
        } label: {
            Group {
                if composerState.isShowingEmojiPanel {
                    Image(systemName: "keyboard")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 24, height: 24)
                } else {
                    theme.images.inputView.sticker
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 24, height: 24)
                }
            }
            .foregroundColor(theme.colors.sendButtonBackground)
            .padding(EdgeInsets(top: 12, leading: 6, bottom: 12, trailing: 6))
        }
        .buttonStyle(.plain)
    }

    private var sendButton: some View {
        Button {
            guard sendEnabled else { return }
            composerState.isShowingAttachmentPanel = false
            composerState.isShowingEmojiPanel = false
            parameters.inputViewActionClosure(.send)
        } label: {
            theme.images.inputView.arrowSend
                .renderingMode(.template)
                .foregroundColor(.white)
                .frame(width: 18, height: 18)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(sendButtonFillColor)
                )
        }
        .buttonStyle(.plain)
        .disabled(!sendEnabled)
    }

    private func replyBar(_ replyMessage: ReplyMessage) -> some View {
        VStack(spacing: 8) {
            Rectangle()
                .foregroundColor(theme.colors.messageFriendBG)
                .frame(height: 2)

            HStack {
                theme.images.reply.replyToMessage
                Capsule()
                    .foregroundColor(theme.colors.messageMyBG)
                    .frame(width: 2)
                VStack(alignment: .leading) {
                    Text("回复 \(replyMessage.user.name)")
                        .font(.caption2)
                        .foregroundColor(theme.colors.mainCaptionText)
                    Text(replyPreviewText(for: replyMessage))
                        .font(.caption2)
                        .lineLimit(1)
                        .foregroundColor(theme.colors.mainText)
                }
                .padding(.vertical, 2)

                Spacer()

                if let _ = replyMessage.recording {
                    theme.images.inputView.microphone
                        .renderingMode(.template)
                        .foregroundColor(theme.colors.mainTint)
                }

                Button {
                    parameters.clearReplyClosure()
                    parameters.setFocusedClosure(true)
                } label: {
                    theme.images.reply.cancelReply
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 26)
        }
    }

    private func replyPreviewText(for replyMessage: ReplyMessage) -> String {
        let text = replyMessage.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            return text
        }
        if replyMessage.recording != nil {
            return L("[语音]", "[Voice]")
        }
        if !replyMessage.attachments.isEmpty {
            return L("[附件]", "[Attachment]")
        }
        return L("[消息]", "[Message]")
    }

    private var emojiPacks: [EmojiPackDescriptor] {
        [
            EmojiPackDescriptor(
                id: "tencent-default",
                title: L("默认", "Default"),
                iconSystemName: "face.smiling",
                items: TencentEmojiCatalog.items
            )
        ]
    }

    private var selectedEmojiPack: EmojiPackDescriptor {
        emojiPacks.first(where: { $0.id == composerState.selectedEmojiPackID }) ?? emojiPacks[0]
    }

    private var emojiPanel: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: true) {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(minimum: 24, maximum: 40), spacing: 8), count: 8),
                    spacing: 12
                ) {
                    ForEach(selectedEmojiPack.items) { item in
                        emojiItemButton(item)
                    }
                    emojiDeleteButton
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 12)
            }
            .frame(height: 216)

            Divider()
                .overlay(theme.colors.mainCaptionText.opacity(0.12))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(emojiPacks) { pack in
                        emojiPackTab(pack)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 6)
            }
            .frame(height: 44)
        }
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(isMessageStyle ? theme.colors.inputBG : theme.colors.inputSignatureBG)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(theme.colors.mainCaptionText.opacity(0.10), lineWidth: 1)
        )
        .padding(.horizontal, 12)
    }

    private var mentionPanel: some View {
        VStack(spacing: 0) {
            ForEach(filteredMentionCandidates) { candidate in
                Button {
                    applyMentionCandidate(candidate)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "at")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(theme.colors.sendButtonBackground)
                            .frame(width: 24, height: 24)
                            .background(
                                Circle()
                                    .fill(theme.colors.mainBG.opacity(colorScheme == .dark ? 0.7 : 1))
                            )

                        Text(candidate.title)
                            .font(.system(size: 14))
                            .foregroundStyle(theme.colors.mainText)
                            .lineLimit(1)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if candidate.id != filteredMentionCandidates.last?.id {
                    Divider()
                        .padding(.leading, 46)
                }
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(isMessageStyle ? theme.colors.inputBG : theme.colors.inputSignatureBG)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(theme.colors.mainCaptionText.opacity(0.10), lineWidth: 1)
        )
        .padding(.horizontal, 12)
    }

    private func emojiPackTab(_ pack: EmojiPackDescriptor) -> some View {
        Button {
            composerState.selectedEmojiPackID = pack.id
        } label: {
            VStack(spacing: 4) {
                Image(systemName: pack.iconSystemName)
                    .font(.system(size: 18, weight: .medium))
                Text(pack.title)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(
                composerState.selectedEmojiPackID == pack.id ? theme.colors.sendButtonBackground : theme.colors.mainCaptionText
            )
            .frame(width: 56, height: 36)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        composerState.selectedEmojiPackID == pack.id
                            ? theme.colors.mainBG.opacity(colorScheme == .dark ? 0.95 : 1)
                            : Color.clear
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func emojiItemButton(_ item: TencentEmojiItem) -> some View {
        Button {
            insertEmoji(item)
        } label: {
            emojiImage(for: item)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 28, height: 28)
                .frame(maxWidth: .infinity, minHeight: 42)
                .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private var emojiDeleteButton: some View {
        Button {
            let result = TencentEmojiCatalog.delete(
                in: parameters.text.wrappedValue,
                selectedSourceRange: composerState.selectionRange
            )
            parameters.text.wrappedValue = result.text
            composerState.selectionRange = result.selectedRange
            parameters.setFocusedClosure(true)
        } label: {
            Image(systemName: "delete.left")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(theme.colors.sendButtonBackground)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme.colors.mainBG.opacity(colorScheme == .dark ? 0.7 : 1))
                )
                .frame(maxWidth: .infinity, minHeight: 42)
                .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func emojiImage(for item: TencentEmojiItem) -> Image {
        let bundle = Bundle.main.url(forResource: "TUIChatFace", withExtension: "bundle").flatMap(Bundle.init(url:))
        let image = UIImage(named: "\(item.fileName)@2x", in: bundle, with: nil)
            ?? UIImage(named: item.fileName, in: bundle, with: nil)
            ?? bundle?.path(forResource: "\(item.fileName)@2x", ofType: "png", inDirectory: "emoji").flatMap(UIImage.init(contentsOfFile:))
            ?? bundle?.path(forResource: item.fileName, ofType: "png", inDirectory: "emoji").flatMap(UIImage.init(contentsOfFile:))

        if let image {
            return Image(uiImage: image)
        }
        return Image(systemName: "face.smiling")
    }

    private func insertEmoji(_ item: TencentEmojiItem) {
        let result = TencentEmojiCatalog.replace(
            item.token,
            in: parameters.text.wrappedValue,
            selectedSourceRange: composerState.selectionRange
        )
        parameters.text.wrappedValue = result.text
        composerState.selectionRange = result.selectedRange
        parameters.setFocusedClosure(true)
    }

    private var attachmentPanel: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                attachmentPanelItem(title: "图片", systemImage: "photo") {
                    composerState.isShowingAttachmentPanel = false
                    parameters.inputViewActionClosure(.photo)
                }
                attachmentPanelItem(title: "视频", systemImage: "video") {
                    composerState.isShowingAttachmentPanel = false
                    parameters.inputViewActionClosure(.video)
                }
                attachmentPanelItem(title: "拍摄", systemImage: "camera") {
                    composerState.isShowingAttachmentPanel = false
                    parameters.inputViewActionClosure(.camera)
                }
                attachmentPanelItem(title: "音频", systemImage: "waveform", enabled: false) {}
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(isMessageStyle ? theme.colors.inputBG : theme.colors.inputSignatureBG)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(theme.colors.mainCaptionText.opacity(0.10), lineWidth: 1)
        )
        .padding(.horizontal, 12)
    }

    private func attachmentPanelItem(
        title: String,
        systemImage: String,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(theme.colors.sendButtonBackground)
                    .frame(width: 48, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(theme.colors.mainBG)
                    )
                Text(title)
                    .font(.caption2)
                    .foregroundColor(theme.colors.mainCaptionText)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1.0 : 0.55)
    }

    private var sendButtonFillColor: Color {
        if sendEnabled {
            return theme.colors.sendButtonBackground
        }
        switch colorScheme {
        case .dark:
            return Color.white.opacity(0.18)
        default:
            return Color.gray.opacity(0.28)
        }
    }

    private func mentionContext(in text: String, selectionRange: NSRange) -> MentionContext? {
        guard selectionRange.length == 0 else { return nil }

        let nsText = text as NSString
        let cursor = min(max(0, selectionRange.location), nsText.length)
        guard cursor <= nsText.length else { return nil }

        let prefix = nsText.substring(to: cursor)
        guard let atIndex = prefix.lastIndex(of: "@") else { return nil }

        let queryStart = prefix.index(after: atIndex)
        let query = String(prefix[queryStart...])
        if query.contains(where: { $0.isWhitespace || $0.isNewline }) {
            return nil
        }

        if atIndex > prefix.startIndex {
            let previous = prefix[prefix.index(before: atIndex)]
            let allowedPrefixes = CharacterSet.whitespacesAndNewlines
            let scalar = String(previous).unicodeScalars
            if scalar.allSatisfy({ !allowedPrefixes.contains($0) }) {
                return nil
            }
        }

        let location = prefix.distance(from: prefix.startIndex, to: atIndex)
        return MentionContext(
            replacementRange: NSRange(location: location, length: cursor - location),
            query: query
        )
    }

    private func applyMentionCandidate(_ candidate: RaverChatMentionCandidate) {
        guard let context = currentMentionContext else { return }
        let result = TencentEmojiCatalog.replace(
            "@\(candidate.username) ",
            in: parameters.text.wrappedValue,
            selectedSourceRange: context.replacementRange
        )
        parameters.text.wrappedValue = result.text
        composerState.selectionRange = result.selectedRange
        parameters.setFocusedClosure(true)
    }
}
