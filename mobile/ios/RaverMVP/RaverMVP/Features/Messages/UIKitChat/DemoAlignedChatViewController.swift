import Foundation
import UIKit
import UniformTypeIdentifiers
import AVFoundation

final class DemoAlignedChatViewController: UIViewController {
    private enum MessageRevealContext {
        case search
        case reply
    }

    private enum UIConstants {
        static let topPaginationTriggerOffset: CGFloat = 24
        static let nearBottomThreshold: CGFloat = 28
        static let maxBubbleWidthRatio: CGFloat = 0.64
        static let jumpButtonHorizontalInset: CGFloat = 16
        static let jumpButtonBottomInset: CGFloat = 12
        static let keyboardSettleDelayNs: UInt64 = 24_000_000
    }

    private var conversation: Conversation
    private var service: SocialService
    private var onNavigate: ((AppRoute) -> Void)?
    private var onLeaveConversation: (() -> Void)?
    private var pendingFocusTask: Task<Void, Never>?
    private var isMentionPickerPresented = false
    private var lastPresentedMentionQuery: String?
    private var isSendingVoice = false
    private var isHoldToTalkPressActive = false
    private var audioRecorder: AVAudioRecorder?
    private var recordingFileURL: URL?
    private var recordingWillCancel = false
    private var recordingStartedAt: Date?
    private var recordingTimer: Timer?
    private let holdToTalkFeedback = UIImpactFeedbackGenerator(style: .medium)

    private let chatController: RaverChatController
    private let chatLayout = CollectionViewChatLayout()
    private let collectionDataSource: RaverChatCollectionDataSource
    private let scrollCoordinator = RaverChatScrollCoordinator()
    private var collectionView: UICollectionView!
    private let composerContainer = UIView()
    private let replyDraftContainer = UIView()
    private let replyDraftLabel = UILabel()
    private let replyDraftCloseButton = UIButton(type: .system)
    private let mediaProgressContainer = UIView()
    private let mediaProgressView = UIProgressView(progressViewStyle: .default)
    private let mediaProgressLabel = UILabel()
    private let imageButton = UIButton(type: .system)
    private let videoButton = UIButton(type: .system)
    private let inputField = UITextField()
    private let sendButton = UIButton(type: .system)
    private let holdToTalkButton = UIButton(type: .system)
    private let recordingHUDContainer = UIView()
    private let recordingHUDTitleLabel = UILabel()
    private let recordingHUDDurationLabel = UILabel()
    private let jumpToBottomButton = UIButton(type: .system)
    private let olderLoadingIndicator = UIActivityIndicatorView(style: .medium)

    private var mediaProgressHeightConstraint: NSLayoutConstraint!
    private var sendFailureHintPresenter: DemoAlignedSendFailureHintPresenter?
    private var chatContextProvider: DemoAlignedChatContextProvider?
    private var messageFailureFeedbackCoordinator: DemoAlignedMessageFailureFeedbackCoordinator?
    private var failureFeedbackActions: DemoAlignedFailureFeedbackActions?
    private var mediaProgressPresenter: DemoAlignedMediaSendProgressPresenter?
    private var mediaMessageSendCoordinator: DemoAlignedMediaMessageSendCoordinator?
    private var mediaSendCoordinator: DemoAlignedMediaSendCoordinator?
    private var textSendCoordinator: DemoAlignedTextSendCoordinator?
    private var composerActionCoordinator: DemoAlignedComposerActionCoordinator?
    private var messageActionCoordinator: DemoAlignedMessageActionCoordinator?
    private var paginationCoordinator: DemoAlignedPaginationCoordinator?
    private var viewportCoordinator: DemoAlignedViewportCoordinator?
    private var chatRouteCoordinator: DemoAlignedChatRouteCoordinator?
    private var viewportScrollCoordinator: DemoAlignedMessageViewportScrollCoordinator?
    private var messageApplyCoordinator: DemoAlignedMessageApplyCoordinator?
    private var keyboardLifecycleCoordinator: DemoAlignedKeyboardLifecycleCoordinator?
    private var messageFlowCoordinator: DemoAlignedMessageFlowCoordinator?
    private var controllerBindingCoordinator: DemoAlignedControllerBindingCoordinator?
    private var chatScreenLifecycleCoordinator: DemoAlignedChatScreenLifecycleCoordinator?
    private var chatScreenAssemblyCoordinator: DemoAlignedChatScreenAssemblyCoordinator?
    private var conversationSearchCoordinator: DemoAlignedConversationSearchCoordinator?
    private lazy var conversationIDProvider = DemoAlignedWeakBinder.valueProvider(
        owner: self,
        DemoAlignedChatViewController.currentConversationID,
        fallback: "unknown"
    )
    private lazy var onSendSucceededCallback = DemoAlignedWeakBinder.callback(
        owner: self,
        DemoAlignedChatViewController.handleSendSucceeded
    )
    private lazy var onSendFailureHintCallback = DemoAlignedWeakBinder.callback(
        owner: self,
        DemoAlignedChatViewController.handleSendFailureHint
    )
    private lazy var assemblyDependencyResolver = DemoAlignedChatAssemblyDependencyResolver(
        conversationIDProvider: conversationIDProvider
    )
    private lazy var missingDependencyReporter = assemblyDependencyResolver.makeMissingDependencyReporter
    private lazy var assemblyDispatcherBundleDependencies = makeAssemblyDispatcherBundleDependencies()
    private lazy var assemblyConfigurationExecutor = DemoAlignedChatScreenAssemblyConfigurationExecutorFactory.make(
        dependencies: DemoAlignedChatScreenAssemblyConfigurationExecutorFactoryDependencies(
            dispatcherBundleDependencies: assemblyDispatcherBundleDependencies,
            onUnhandledAction: DemoAlignedWeakBinder.action(
                owner: self,
                DemoAlignedChatViewController.handleUnhandledAssemblyAction
            )
        )
    )

    init(
        conversation: Conversation,
        service: SocialService,
        onNavigate: ((AppRoute) -> Void)? = nil,
        onLeaveConversation: (() -> Void)? = nil
    ) {
        self.conversation = conversation
        self.service = service
        self.onNavigate = onNavigate
        self.onLeaveConversation = onLeaveConversation
        self.chatController = RaverChatController(
            dataProvider: RaverChatDataProvider(
                conversation: conversation,
                service: service
            )
        )
        self.collectionDataSource = RaverChatCollectionDataSource(
            conversationType: conversation.type,
            maxBubbleWidthRatio: UIConstants.maxBubbleWidthRatio
        )
        super.init(nibName: nil, bundle: nil)
        self.collectionDataSource.onReplyPreviewTapped = { [weak self] message in
            guard let self else { return }
            _ = self.tryRevealReplyTargetIfNeeded(from: message)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        pendingFocusTask?.cancel()
        let coordinator = messageActionCoordinator
        Task { @MainActor in
            coordinator?.stopVoicePlaybackIfNeeded()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = conversation.title
        view.backgroundColor = UIColor(RaverTheme.background)
        configureConversationSearchCoordinator()
        configureChatScreenAssemblyCoordinator()
        chatScreenAssemblyCoordinator?.assemble()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        IMChatStore.shared.activateConversation(conversation)
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.service.markConversationRead(conversationID: self.conversation.id)
            } catch {
                // Keep UX stable; unread will continue syncing from IM callbacks.
            }
        }
        let hasMessages = messageFlowCoordinator?.hasMessages ?? false
        let shouldScroll = chatScreenLifecycleCoordinator?.handleViewDidAppear(hasMessages: hasMessages) ?? hasMessages
        if shouldScroll {
            viewportScrollCoordinator?.scrollToBottom(animated: false)
        }
        consumePendingMessageFocusIfNeeded()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        IMChatStore.shared.deactivateConversation(conversation)
        messageActionCoordinator?.stopVoicePlaybackIfNeeded()
    }

    func updateConversation(
        _ conversation: Conversation,
        service: SocialService,
        onNavigate: ((AppRoute) -> Void)? = nil,
        onLeaveConversation: (() -> Void)? = nil
    ) {
        messageActionCoordinator?.stopVoicePlaybackIfNeeded()
        self.service = service
        self.onNavigate = onNavigate
        self.onLeaveConversation = onLeaveConversation
        if let chatScreenLifecycleCoordinator {
            self.conversation = chatScreenLifecycleCoordinator.updateConversation(
                currentConversation: self.conversation,
                nextConversation: conversation,
                service: service,
                onNavigate: onNavigate,
                onLeaveConversation: onLeaveConversation
            )
        } else {
            self.conversation = conversation
            title = conversation.title
        }
    }

    // MARK: - UI Assembly

    private func configureNavigationItems() {
        DemoAlignedChatUIAssemblyFactory.configureNavigationItems(
            DemoAlignedNavigationItemsAssemblyDependencies(
                navigationItem: navigationItem,
                actionTarget: self,
                settingsTappedAction: #selector(handleSettingsTapped),
                accessibilityLabel: L("聊天设置", "Chat Settings")
            )
        )
        let searchButton = UIBarButtonItem(
            image: UIImage(systemName: "magnifyingglass"),
            style: .plain,
            target: self,
            action: #selector(handleSearchTapped)
        )
        searchButton.accessibilityLabel = L("会话内搜索", "Search in Conversation")

        if let settingsButton = navigationItem.rightBarButtonItem {
            navigationItem.rightBarButtonItems = [settingsButton, searchButton]
        } else {
            navigationItem.rightBarButtonItems = [searchButton]
        }
    }

    private func configureLayout() {
        DemoAlignedChatUIAssemblyFactory.configureLayout(
            DemoAlignedChatLayoutAssemblyDependencies(
                chatLayout: chatLayout,
                interItemSpacing: 8,
                interSectionSpacing: 4,
                additionalInsets: UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
            )
        )
    }

    private func configureCollectionView() {
        collectionView = DemoAlignedChatUIAssemblyFactory.makeCollectionView(
            DemoAlignedCollectionViewAssemblyDependencies(
                hostView: view,
                chatLayout: chatLayout,
                delegate: self,
                dataSource: collectionDataSource,
                registerCells: DemoAlignedWeakBinder.action(
                    owner: self,
                    DemoAlignedChatViewController.registerCollectionCells
                )
            )
        )
    }

    private func registerCollectionCells(in collectionView: UICollectionView) {
        collectionDataSource.registerCells(in: collectionView)
    }

    private func configureComposer() {
        let keyboardTopAnchor: NSLayoutYAxisAnchor
        if #available(iOS 15.0, *) {
            keyboardTopAnchor = view.keyboardLayoutGuide.topAnchor
        } else {
            keyboardTopAnchor = view.safeAreaLayoutGuide.bottomAnchor
        }

        mediaProgressHeightConstraint = DemoAlignedChatUIAssemblyFactory.configureComposer(
            DemoAlignedComposerAssemblyDependencies(
                hostView: view,
                keyboardTopAnchor: keyboardTopAnchor,
                collectionView: collectionView,
                composerContainer: composerContainer,
                mediaProgressContainer: mediaProgressContainer,
                mediaProgressView: mediaProgressView,
                mediaProgressLabel: mediaProgressLabel,
                imageButton: imageButton,
                videoButton: videoButton,
                inputField: inputField,
                inputFieldDelegate: self,
                sendButton: sendButton,
                backgroundColor: UIColor(RaverTheme.background),
                dividerColor: UIColor(RaverTheme.cardBorder),
                accentColor: UIColor(RaverTheme.accent),
                secondaryTextColor: UIColor(RaverTheme.secondaryText),
                mediaProgressText: L("发送媒体 0%", "Sending media 0%"),
                inputPlaceholder: L("发消息...", "Message..."),
                sendButtonTitle: L("发送", "Send"),
                actionTarget: self,
                inputChangedAction: #selector(handleInputFieldEditingChanged),
                imageTappedAction: #selector(handleImageTapped(_:)),
                videoTappedAction: #selector(handleVideoTapped(_:)),
                sendTappedAction: #selector(handleSendTapped)
            )
        )
        configureReplyDraftBar()
        configureHoldToTalkButton()
        configureRecordingHUD()
    }

    private func configureReplyDraftBar() {
        replyDraftContainer.translatesAutoresizingMaskIntoConstraints = false
        replyDraftContainer.backgroundColor = UIColor(RaverTheme.card)
        replyDraftContainer.layer.borderWidth = 1
        replyDraftContainer.layer.borderColor = UIColor(RaverTheme.cardBorder).cgColor
        replyDraftContainer.layer.cornerRadius = 10
        replyDraftContainer.isHidden = true
        view.addSubview(replyDraftContainer)

        replyDraftLabel.translatesAutoresizingMaskIntoConstraints = false
        replyDraftLabel.font = .systemFont(ofSize: 12, weight: .medium)
        replyDraftLabel.textColor = UIColor(RaverTheme.secondaryText)
        replyDraftLabel.numberOfLines = 1
        replyDraftContainer.addSubview(replyDraftLabel)

        replyDraftCloseButton.translatesAutoresizingMaskIntoConstraints = false
        var closeConfig = UIButton.Configuration.plain()
        closeConfig.image = UIImage(systemName: "xmark.circle.fill")
        closeConfig.baseForegroundColor = UIColor(RaverTheme.secondaryText)
        closeConfig.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        replyDraftCloseButton.configuration = closeConfig
        replyDraftCloseButton.addTarget(self, action: #selector(handleReplyDraftCloseTapped), for: .touchUpInside)
        replyDraftContainer.addSubview(replyDraftCloseButton)

        NSLayoutConstraint.activate([
            replyDraftContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            replyDraftContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            replyDraftContainer.bottomAnchor.constraint(equalTo: composerContainer.topAnchor, constant: -6),
            replyDraftContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 34),

            replyDraftLabel.leadingAnchor.constraint(equalTo: replyDraftContainer.leadingAnchor, constant: 10),
            replyDraftLabel.centerYAnchor.constraint(equalTo: replyDraftContainer.centerYAnchor),

            replyDraftCloseButton.leadingAnchor.constraint(equalTo: replyDraftLabel.trailingAnchor, constant: 8),
            replyDraftCloseButton.trailingAnchor.constraint(equalTo: replyDraftContainer.trailingAnchor, constant: -8),
            replyDraftCloseButton.centerYAnchor.constraint(equalTo: replyDraftContainer.centerYAnchor),
            replyDraftCloseButton.widthAnchor.constraint(equalToConstant: 22),
            replyDraftCloseButton.heightAnchor.constraint(equalToConstant: 22)
        ])
    }

    private func configureHoldToTalkButton() {
        holdToTalkButton.translatesAutoresizingMaskIntoConstraints = false
        var config = UIButton.Configuration.filled()
        config.title = L("按住说话", "Hold to Talk")
        config.baseBackgroundColor = UIColor(RaverTheme.card)
        config.baseForegroundColor = UIColor(RaverTheme.secondaryText)
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        holdToTalkButton.configuration = config
        holdToTalkButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
        holdToTalkButton.layer.cornerCurve = .continuous
        composerContainer.addSubview(holdToTalkButton)

        NSLayoutConstraint.activate([
            holdToTalkButton.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8),
            holdToTalkButton.centerYAnchor.constraint(equalTo: sendButton.centerYAnchor)
        ])

        let gesture = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleHoldToTalkGesture(_:))
        )
        gesture.minimumPressDuration = 0.25
        holdToTalkButton.addGestureRecognizer(gesture)
    }

    private func configureRecordingHUD() {
        recordingHUDContainer.translatesAutoresizingMaskIntoConstraints = false
        recordingHUDContainer.backgroundColor = UIColor.black.withAlphaComponent(0.78)
        recordingHUDContainer.layer.cornerRadius = 14
        recordingHUDContainer.isHidden = true
        view.addSubview(recordingHUDContainer)

        recordingHUDTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        recordingHUDTitleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        recordingHUDTitleLabel.textColor = .white
        recordingHUDTitleLabel.text = L("上滑取消", "Slide Up to Cancel")
        recordingHUDContainer.addSubview(recordingHUDTitleLabel)

        recordingHUDDurationLabel.translatesAutoresizingMaskIntoConstraints = false
        recordingHUDDurationLabel.font = .monospacedDigitSystemFont(ofSize: 18, weight: .bold)
        recordingHUDDurationLabel.textColor = .white
        recordingHUDDurationLabel.text = "00:00"
        recordingHUDContainer.addSubview(recordingHUDDurationLabel)

        NSLayoutConstraint.activate([
            recordingHUDContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            recordingHUDContainer.bottomAnchor.constraint(equalTo: composerContainer.topAnchor, constant: -20),
            recordingHUDContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 160),

            recordingHUDDurationLabel.topAnchor.constraint(equalTo: recordingHUDContainer.topAnchor, constant: 14),
            recordingHUDDurationLabel.centerXAnchor.constraint(equalTo: recordingHUDContainer.centerXAnchor),

            recordingHUDTitleLabel.topAnchor.constraint(equalTo: recordingHUDDurationLabel.bottomAnchor, constant: 8),
            recordingHUDTitleLabel.leadingAnchor.constraint(equalTo: recordingHUDContainer.leadingAnchor, constant: 14),
            recordingHUDTitleLabel.trailingAnchor.constraint(equalTo: recordingHUDContainer.trailingAnchor, constant: -14),
            recordingHUDTitleLabel.bottomAnchor.constraint(equalTo: recordingHUDContainer.bottomAnchor, constant: -12)
        ])
    }

    private func configureJumpToBottomButton() {
        DemoAlignedChatUIAssemblyFactory.configureJumpToBottomButton(
            DemoAlignedJumpToBottomButtonAssemblyDependencies(
                hostView: view,
                composerContainer: composerContainer,
                jumpToBottomButton: jumpToBottomButton,
                horizontalInset: UIConstants.jumpButtonHorizontalInset,
                bottomInset: UIConstants.jumpButtonBottomInset,
                accentColor: UIColor(RaverTheme.accent),
                actionTarget: self,
                tappedAction: #selector(handleJumpToBottomTapped)
            )
        )
    }

    private func configureOlderLoadingIndicator() {
        DemoAlignedChatUIAssemblyFactory.configureOlderLoadingIndicator(
            DemoAlignedOlderLoadingIndicatorAssemblyDependencies(
                hostView: view,
                loadingIndicator: olderLoadingIndicator
            )
        )
    }

    // MARK: - Coordinator Assembly

    private func configureMessageApplyCoordinator() {
        messageApplyCoordinator = DemoAlignedMessageApplyCoordinatorFactory.make(
            dependencies: DemoAlignedMessageApplyCoordinatorFactoryDependencies(
                viewportScrollCoordinator: viewportScrollCoordinator,
                collectionView: collectionView,
                collectionDataSource: collectionDataSource,
                nearBottomThreshold: UIConstants.nearBottomThreshold,
                onMissingDependencies: missingDependencyReporter(.messageApplyCoordinator)
            )
        )
    }

    private func configureViewportScrollCoordinator() {
        viewportScrollCoordinator = DemoAlignedViewportScrollCoordinatorFactory.make(
            dependencies: DemoAlignedViewportScrollCoordinatorFactoryDependencies(
                collectionView: collectionView,
                scrollCoordinator: scrollCoordinator
            )
        )
    }

    private func configurePaginationCoordinator() {
        paginationCoordinator = DemoAlignedPaginationCoordinatorFactory.make(
            dependencies: DemoAlignedPaginationCoordinatorFactoryDependencies(
                loadingIndicator: olderLoadingIndicator,
                topTriggerOffset: UIConstants.topPaginationTriggerOffset,
                onLoadOlder: DemoAlignedWeakBinder.asyncCallback(
                    owner: self,
                    DemoAlignedChatViewController.loadOlderMessagesIfNeeded
                )
            )
        )
    }

    private func configureViewportCoordinator() {
        viewportCoordinator = DemoAlignedViewportCoordinatorFactory.make(
            dependencies: DemoAlignedViewportCoordinatorFactoryDependencies(
                hostView: view,
                jumpToBottomButton: jumpToBottomButton,
                keyboardSettleDelayNs: UIConstants.keyboardSettleDelayNs
            )
        )
    }

    private func configureChatRouteCoordinator() {
        chatRouteCoordinator = DemoAlignedChatRouteCoordinatorFactory.make(
            dependencies: DemoAlignedChatRouteCoordinatorFactoryDependencies(
                presenter: self,
                conversation: conversation,
                service: service,
                onNavigate: onNavigate,
                onLeaveConversation: onLeaveConversation
            )
        )
    }

    private func configureChatScreenLifecycleCoordinator() {
        chatScreenLifecycleCoordinator = DemoAlignedChatScreenLifecycleCoordinatorFactory.make(
            dependencies: DemoAlignedChatScreenLifecycleCoordinatorFactoryDependencies(
                chatController: chatController,
                titleHost: self,
                collectionDataSource: collectionDataSource,
                viewportScrollCoordinator: viewportScrollCoordinator,
                paginationCoordinator: paginationCoordinator,
                viewportCoordinator: viewportCoordinator,
                messageFlowCoordinator: messageFlowCoordinator,
                failureFeedbackActions: failureFeedbackActions,
                textSendCoordinator: textSendCoordinator,
                chatRouteCoordinator: chatRouteCoordinator
            )
        )
    }

    private func bindAssemblyConfiguration(
        _ method: @escaping (DemoAlignedChatViewController) -> () -> Void
    ) -> () -> Void {
        DemoAlignedWeakBinder.assemblyConfiguration(owner: self, method)
    }

    private func makeAssemblyDispatcherBundleDependencies()
        -> DemoAlignedChatScreenAssemblyActionDispatcherBundleDependencies {
        let bind = bindAssemblyConfiguration
        return DemoAlignedChatScreenAssemblyActionDispatcherBundleDependencies(
            layout: bind(DemoAlignedChatViewController.configureLayout),
            collectionView: bind(DemoAlignedChatViewController.configureCollectionView),
            composer: bind(DemoAlignedChatViewController.configureComposer),
            jumpToBottomButton: bind(DemoAlignedChatViewController.configureJumpToBottomButton),
            olderLoadingIndicator: bind(DemoAlignedChatViewController.configureOlderLoadingIndicator),
            navigationItems: bind(DemoAlignedChatViewController.configureNavigationItems),
            viewportScrollCoordinator: bind(DemoAlignedChatViewController.configureViewportScrollCoordinator),
            messageApplyCoordinator: bind(DemoAlignedChatViewController.configureMessageApplyCoordinator),
            sendFailureHintPresenter: bind(DemoAlignedChatViewController.configureSendFailureHintPresenter),
            chatContextProvider: bind(DemoAlignedChatViewController.configureChatContextProvider),
            messageFailureFeedbackCoordinator: bind(DemoAlignedChatViewController.configureMessageFailureFeedbackCoordinator),
            failureFeedbackActions: bind(DemoAlignedChatViewController.configureFailureFeedbackActions),
            mediaProgressPresenter: bind(DemoAlignedChatViewController.configureMediaProgressPresenter),
            textSendCoordinator: bind(DemoAlignedChatViewController.configureTextSendCoordinator),
            mediaMessageSendCoordinator: bind(DemoAlignedChatViewController.configureMediaMessageSendCoordinator),
            mediaSendCoordinator: bind(DemoAlignedChatViewController.configureMediaSendCoordinator),
            messageActionCoordinator: bind(DemoAlignedChatViewController.configureMessageActionCoordinator),
            paginationCoordinator: bind(DemoAlignedChatViewController.configurePaginationCoordinator),
            viewportCoordinator: bind(DemoAlignedChatViewController.configureViewportCoordinator),
            composerActionCoordinator: bind(DemoAlignedChatViewController.configureComposerActionCoordinator),
            keyboardLifecycleCoordinator: bind(DemoAlignedChatViewController.configureKeyboardLifecycleCoordinator),
            messageFlowCoordinator: bind(DemoAlignedChatViewController.configureMessageFlowCoordinator),
            controllerBindingCoordinator: bind(DemoAlignedChatViewController.configureControllerBindingCoordinator),
            chatRouteCoordinator: bind(DemoAlignedChatViewController.configureChatRouteCoordinator),
            chatScreenLifecycleCoordinator: bind(DemoAlignedChatViewController.configureChatScreenLifecycleCoordinator)
        )
    }

    private func currentConversationID() -> String {
        conversation.id
    }

    private func handleSendSucceeded() {
        let isNearBottom = viewportScrollCoordinator?.isNearBottom(
            threshold: UIConstants.nearBottomThreshold
        ) ?? true
        if isNearBottom {
            viewportScrollCoordinator?.scrollToBottom(animated: false)
        }
    }

    private func handleSendFailureHint() {
        failureFeedbackActions?.showSendFailureHint()
    }

    private func loadOlderMessagesIfNeeded() async {
        await messageFlowCoordinator?.loadOlderMessagesIfNeeded()
    }

    private func handleMediaPicked(_ picked: DemoAlignedPickedMedia) async {
        switch picked {
        case let .image(url):
            await mediaMessageSendCoordinator?.sendImage(fileURL: url)
        case let .video(url):
            await mediaMessageSendCoordinator?.sendVideo(fileURL: url)
        }
    }

    private func executeAssemblyConfigurationAction(_ action: DemoAlignedChatScreenAssemblyAction) {
        assemblyConfigurationExecutor.execute(action)
    }

    private func handleUnhandledAssemblyAction(_ action: DemoAlignedChatScreenAssemblyAction) {
        DemoAlignedChatLogger.assemblyActionUnhandled(
            conversationID: conversation.id,
            action: action.rawValue
        )
        #if DEBUG
        assertionFailure("Chat assembly action unhandled: \(action.rawValue)")
        #endif
    }

    private func startChatScreenLifecycleCoordinator() {
        chatScreenLifecycleCoordinator?.start()
    }

    private func configureChatScreenAssemblyCoordinator() {
        chatScreenAssemblyCoordinator = DemoAlignedChatScreenAssemblyCoordinatorFactory.make(
            dependencies: DemoAlignedChatScreenAssemblyCoordinatorFactoryDependencies(
                executeAssemblyConfigurationAction: DemoAlignedWeakBinder.action(
                    owner: self,
                    DemoAlignedChatViewController.executeAssemblyConfigurationAction
                ),
                onUnhandledAction: DemoAlignedWeakBinder.action(
                    owner: self,
                    DemoAlignedChatViewController.handleUnhandledAssemblyAction
                ),
                onAssembled: DemoAlignedWeakBinder.callback(
                    owner: self,
                    DemoAlignedChatViewController.startChatScreenLifecycleCoordinator
                )
            )
        )
    }

    private func configureConversationSearchCoordinator() {
        conversationSearchCoordinator = DemoAlignedConversationSearchCoordinator(
            presenter: self,
            searchExecutor: { [weak self] query in
                guard let self else { return [] }
                return try await self.chatController.searchMessages(query: query, limit: 50)
            },
            onSearchCompleted: { [weak self] query, results in
                self?.presentSearchResults(query: query, results: results)
            }
        )
    }

    private func configureSendFailureHintPresenter() {
        sendFailureHintPresenter = DemoAlignedSendFailureHintPresenterFactory.make(
            dependencies: DemoAlignedSendFailureHintPresenterFactoryDependencies(
                hostView: view,
                anchorView: composerContainer
            )
        )
    }

    private func configureChatContextProvider() {
        chatContextProvider = DemoAlignedChatContextProviderFactory.make(
            dependencies: DemoAlignedChatContextProviderFactoryDependencies(
                conversationIDResolver: conversationIDProvider
            )
        )
    }

    private func configureMessageFailureFeedbackCoordinator() {
        messageFailureFeedbackCoordinator = DemoAlignedMessageFailureFeedbackCoordinatorFactory.make(
            dependencies: DemoAlignedMessageFailureFeedbackCoordinatorFactoryDependencies(
                hintPresenter: sendFailureHintPresenter,
                chatContextProvider: chatContextProvider,
                onMissingDependencies: missingDependencyReporter(.messageFailureFeedbackCoordinator)
            )
        )
    }

    private func configureFailureFeedbackActions() {
        failureFeedbackActions = DemoAlignedFailureFeedbackActionsFactory.make(
            dependencies: DemoAlignedFailureFeedbackActionsFactoryDependencies(
                coordinator: messageFailureFeedbackCoordinator,
                onMissingDependencies: missingDependencyReporter(.failureFeedbackActions)
            )
        )
    }

    private func configureMediaSendCoordinator() {
        mediaSendCoordinator = DemoAlignedMediaSendCoordinatorFactory.make(
            dependencies: DemoAlignedMediaSendCoordinatorFactoryDependencies(
                presenter: self,
                chatContextProvider: chatContextProvider,
                failureFeedbackActions: failureFeedbackActions,
                onPicked: DemoAlignedWeakBinder.mainActorAsyncAction(
                    owner: self,
                    DemoAlignedChatViewController.handleMediaPicked
                ),
                onMissingDependencies: missingDependencyReporter(.mediaSendCoordinator)
            )
        )
    }

    private func configureMediaProgressPresenter() {
        mediaProgressPresenter = DemoAlignedMediaSendProgressPresenterFactory.make(
            dependencies: DemoAlignedMediaSendProgressPresenterFactoryDependencies(
                imageButton: imageButton,
                videoButton: videoButton,
                containerView: mediaProgressContainer,
                progressView: mediaProgressView,
                progressLabel: mediaProgressLabel,
                heightConstraint: mediaProgressHeightConstraint,
                hostView: view,
                onSendingStateChanged: DemoAlignedWeakBinder.action(
                    owner: self,
                    DemoAlignedChatViewController.handleMediaSendingStateChanged
                ),
                onMissingDependencies: missingDependencyReporter(.mediaProgressPresenter)
            )
        )
    }

    private func handleMediaSendingStateChanged(_: Bool) {
        textSendCoordinator?.refreshSendButtonState()
    }

    private func configureTextSendCoordinator() {
        textSendCoordinator = DemoAlignedTextSendCoordinatorFactory.make(
            dependencies: DemoAlignedTextSendCoordinatorFactoryDependencies(
                chatController: chatController,
                inputField: inputField,
                sendButton: sendButton,
                mediaProgressPresenter: mediaProgressPresenter,
                chatContextProvider: chatContextProvider,
                failureFeedbackActions: failureFeedbackActions,
                onSendSucceeded: onSendSucceededCallback,
                onMissingDependencies: missingDependencyReporter(.textSendCoordinator)
            )
        )
        textSendCoordinator?.refreshSendButtonState()
    }

    private func configureMediaMessageSendCoordinator() {
        mediaMessageSendCoordinator = DemoAlignedMediaMessageSendCoordinatorFactory.make(
            dependencies: DemoAlignedMediaMessageSendCoordinatorFactoryDependencies(
                chatController: chatController,
                mediaProgressPresenter: mediaProgressPresenter,
                chatContextProvider: chatContextProvider,
                failureFeedbackActions: failureFeedbackActions,
                onSendSucceeded: onSendSucceededCallback,
                onMissingDependencies: missingDependencyReporter(.mediaMessageSendCoordinator)
            )
        )
    }

    private func configureMessageActionCoordinator() {
        messageActionCoordinator = DemoAlignedMessageActionCoordinatorFactory.make(
            dependencies: DemoAlignedMessageActionCoordinatorFactoryDependencies(
                chatController: chatController,
                presenter: self,
                chatContextProvider: chatContextProvider,
                failureFeedbackActions: failureFeedbackActions,
                onMissingDependencies: missingDependencyReporter(.messageActionCoordinator)
            )
        )
    }

    private func configureComposerActionCoordinator() {
        composerActionCoordinator = DemoAlignedComposerActionCoordinatorFactory.make(
            dependencies: DemoAlignedComposerActionCoordinatorFactoryDependencies(
                nearBottomThreshold: UIConstants.nearBottomThreshold,
                textSendCoordinator: textSendCoordinator,
                currentInputText: { [weak inputField] in inputField?.text ?? "" },
                notifyInputChanged: { [weak chatController] text in
                    chatController?.handleComposerInputChanged(text)
                },
                mediaProgressPresenter: mediaProgressPresenter,
                mediaSendCoordinator: mediaSendCoordinator,
                viewportScrollCoordinator: viewportScrollCoordinator,
                viewportCoordinator: viewportCoordinator
            )
        )
    }

    private func configureKeyboardLifecycleCoordinator() {
        keyboardLifecycleCoordinator = DemoAlignedKeyboardLifecycleCoordinatorFactory.make(
            dependencies: DemoAlignedKeyboardLifecycleCoordinatorFactoryDependencies(
                hostView: view,
                inputField: inputField,
                nearBottomThreshold: UIConstants.nearBottomThreshold,
                viewportCoordinator: viewportCoordinator,
                viewportScrollCoordinator: viewportScrollCoordinator
            )
        )
        keyboardLifecycleCoordinator?.start()
    }

    private func configureMessageFlowCoordinator() {
        messageFlowCoordinator = DemoAlignedMessageFlowCoordinatorFactory.make(
            dependencies: DemoAlignedMessageFlowCoordinatorFactoryDependencies(
                chatController: chatController,
                messageApplyCoordinator: messageApplyCoordinator,
                viewportScrollCoordinator: viewportScrollCoordinator,
                viewportCoordinator: viewportCoordinator,
                onSendFailureHint: onSendFailureHintCallback,
                onMissingDependencies: missingDependencyReporter(.messageFlowCoordinator)
            )
        )
    }

    private func configureControllerBindingCoordinator() {
        controllerBindingCoordinator = DemoAlignedControllerBindingCoordinatorFactory.make(
            dependencies: DemoAlignedControllerBindingCoordinatorFactoryDependencies(
                chatController: chatController,
                messageFlowCoordinator: messageFlowCoordinator,
                paginationCoordinator: paginationCoordinator,
                onReplyDraftChanged: DemoAlignedWeakBinder.action(
                    owner: self,
                    DemoAlignedChatViewController.handleReplyDraftChanged
                )
            )
        )
        controllerBindingCoordinator?.start()
    }

    private func handleReplyDraftChanged(_ draft: ChatMessage?) {
        if let draft {
            let preview = replyDraftPreviewText(for: draft)
            inputField.placeholder = L("回复: ", "Reply: ") + String(preview.prefix(22))
            replyDraftLabel.text = L("正在回复: ", "Replying: ") + String(preview.prefix(44))
            replyDraftContainer.isHidden = false
        } else {
            inputField.placeholder = L("发消息...", "Message...")
            replyDraftLabel.text = nil
            replyDraftContainer.isHidden = true
        }
    }

    private func replyDraftPreviewText(for message: ChatMessage) -> String {
        let senderName: String = {
            if message.isMine { return L("我", "Me") }
            let shown = message.sender.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !shown.isEmpty { return shown }
            let username = message.sender.username.trimmingCharacters(in: .whitespacesAndNewlines)
            return username.isEmpty ? L("用户", "User") : username
        }()

        let body: String = {
            let content = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            if !content.isEmpty { return String(content.prefix(36)) }
            switch message.kind {
            case .image:
                return L("[图片]", "[Image]")
            case .video:
                return L("[视频]", "[Video]")
            case .voice:
                return L("[语音]", "[Voice]")
            case .file:
                if let fileName = message.media?.fileName?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !fileName.isEmpty {
                    return "[\(fileName)]"
                }
                return L("[文件]", "[File]")
            default:
                return L("[消息]", "[Message]")
            }
        }()

        return "\(senderName): \(body)"
    }

    // MARK: - User Actions

    @objc
    private func handleSendTapped() {
        composerActionCoordinator?.handleSendTapped()
    }

    @objc
    private func handleInputFieldEditingChanged() {
        composerActionCoordinator?.handleInputEditingChanged()
        presentMentionSuggestionsIfNeeded()
    }

    @objc
    private func handleReplyDraftCloseTapped() {
        chatController.clearReplyDraft()
    }

    @objc
    private func handleHoldToTalkGesture(_ gesture: UILongPressGestureRecognizer) {
        let location = gesture.location(in: holdToTalkButton)
        let shouldCancelBySlide = location.y < -36

        switch gesture.state {
        case .began:
            isHoldToTalkPressActive = true
            holdToTalkFeedback.impactOccurred()
            beginVoiceRecording()
        case .changed:
            recordingWillCancel = shouldCancelBySlide
            updateHoldToTalkButtonState(isRecording: true, willCancel: recordingWillCancel)
            updateRecordingHUDCancelState(willCancel: recordingWillCancel)
        case .ended:
            isHoldToTalkPressActive = false
            endVoiceRecording(send: !recordingWillCancel)
        case .cancelled, .failed:
            isHoldToTalkPressActive = false
            endVoiceRecording(send: false)
        default:
            break
        }
    }

    private func beginVoiceRecording() {
        guard audioRecorder == nil else { return }
        recordingWillCancel = false
        updateHoldToTalkButtonState(isRecording: true, willCancel: false)
        requestRecordPermission { [weak self] granted in
            guard let self else { return }
            Task { @MainActor in
                guard self.isHoldToTalkPressActive else {
                    self.updateHoldToTalkButtonState(isRecording: false, willCancel: false)
                    return
                }
                guard granted else {
                    self.updateHoldToTalkButtonState(isRecording: false, willCancel: false)
                    self.failureFeedbackActions?.showSendFailureHint()
                    return
                }
                do {
                    try self.startVoiceRecorder()
                    self.showRecordingHUD()
                } catch {
                    self.updateHoldToTalkButtonState(isRecording: false, willCancel: false)
                    self.failureFeedbackActions?.showSendFailureHint()
                }
            }
        }
    }

    private func endVoiceRecording(send: Bool) {
        defer {
            updateHoldToTalkButtonState(isRecording: false, willCancel: false)
            hideRecordingHUD()
            audioRecorder = nil
            recordingFileURL = nil
            recordingWillCancel = false
        }

        guard let recorder = audioRecorder else { return }
        recorder.stop()
        guard send, let url = recordingFileURL else { return }
        sendVoiceFile(url)
    }

    private func startVoiceRecorder() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try session.setActive(true, options: [])

        let url = URL(
            fileURLWithPath: NSTemporaryDirectory(),
            isDirectory: true
        ).appendingPathComponent("voice-record-\(UUID().uuidString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.prepareToRecord()
        recorder.record()
        audioRecorder = recorder
        recordingFileURL = url
        recordingStartedAt = Date()
        updateRecordingHUDDuration()
        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.updateRecordingHUDDuration()
        }
    }

    private func updateHoldToTalkButtonState(isRecording: Bool, willCancel: Bool) {
        var config = holdToTalkButton.configuration ?? .filled()
        if isRecording {
            config.title = willCancel ? L("松开取消", "Release to Cancel") : L("松开发送", "Release to Send")
            config.baseBackgroundColor = willCancel ? UIColor.systemRed.withAlphaComponent(0.85) : UIColor(RaverTheme.accent)
            config.baseForegroundColor = .white
            holdToTalkButton.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
            holdToTalkButton.alpha = 0.96
        } else {
            config.title = L("按住说话", "Hold to Talk")
            config.baseBackgroundColor = UIColor(RaverTheme.card)
            config.baseForegroundColor = UIColor(RaverTheme.secondaryText)
            holdToTalkButton.transform = .identity
            holdToTalkButton.alpha = 1
        }
        holdToTalkButton.configuration = config
    }

    private func requestRecordPermission(_ completion: @escaping (Bool) -> Void) {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            completion(granted)
        }
    }

    private func showRecordingHUD() {
        recordingHUDTitleLabel.text = L("上滑取消", "Slide Up to Cancel")
        recordingHUDTitleLabel.textColor = .white
        recordingHUDContainer.isHidden = false
    }

    private func hideRecordingHUD() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingStartedAt = nil
        recordingHUDContainer.isHidden = true
        recordingHUDDurationLabel.text = "00:00"
        recordingHUDTitleLabel.textColor = .white
    }

    private func updateRecordingHUDDuration() {
        guard let startedAt = recordingStartedAt else {
            recordingHUDDurationLabel.text = "00:00"
            return
        }
        let seconds = max(Int(Date().timeIntervalSince(startedAt)), 0)
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        recordingHUDDurationLabel.text = String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    private func updateRecordingHUDCancelState(willCancel: Bool) {
        if willCancel {
            recordingHUDTitleLabel.text = L("松开取消", "Release to Cancel")
            recordingHUDTitleLabel.textColor = UIColor.systemRed.withAlphaComponent(0.95)
        } else {
            recordingHUDTitleLabel.text = L("上滑取消", "Slide Up to Cancel")
            recordingHUDTitleLabel.textColor = .white
        }
    }

    private func presentMentionSuggestionsIfNeeded() {
        guard !isMentionPickerPresented else { return }
        guard let query = currentMentionQuery() else {
            lastPresentedMentionQuery = nil
            return
        }
        if query == lastPresentedMentionQuery { return }

        let candidates = mentionCandidates(matching: query)
        guard !candidates.isEmpty else { return }

        lastPresentedMentionQuery = query
        isMentionPickerPresented = true

        let sheet = UIAlertController(
            title: L("选择要@的人", "Choose Mention"),
            message: nil,
            preferredStyle: .actionSheet
        )
        for candidate in candidates.prefix(8) {
            sheet.addAction(UIAlertAction(title: "@\(candidate)", style: .default) { [weak self] _ in
                self?.applyMentionCandidate(candidate)
            })
        }
        sheet.addAction(UIAlertAction(title: L("取消", "Cancel"), style: .cancel) { [weak self] _ in
            self?.isMentionPickerPresented = false
        })

        if let popover = sheet.popoverPresentationController {
            popover.sourceView = inputField
            popover.sourceRect = inputField.bounds
        }
        present(sheet, animated: true)
    }

    private func currentMentionQuery() -> String? {
        let text = inputField.text ?? ""
        guard let atRange = text.range(of: "@", options: .backwards) else { return nil }
        let suffix = String(text[atRange.upperBound...])
        if suffix.contains(" ") || suffix.contains("\n") { return nil }
        let query = suffix.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? nil : query
    }

    private func mentionCandidates(matching query: String) -> [String] {
        let q = query.lowercased()
        var usernames = Set<String>()

        if let peer = conversation.peer?.username, !peer.isEmpty {
            usernames.insert(peer)
        }
        for message in chatController.currentMessagesSnapshot() {
            let username = message.sender.username.trimmingCharacters(in: .whitespacesAndNewlines)
            if !username.isEmpty {
                usernames.insert(username)
            }
        }

        return usernames
            .filter { $0.lowercased().contains(q) }
            .sorted()
    }

    private func applyMentionCandidate(_ candidate: String) {
        defer { isMentionPickerPresented = false }
        var text = inputField.text ?? ""
        guard let atRange = text.range(of: "@", options: .backwards) else { return }
        text.replaceSubrange(atRange.upperBound..<text.endIndex, with: candidate + " ")
        inputField.text = text
        composerActionCoordinator?.handleInputEditingChanged()
    }

    @objc
    private func handleJumpToBottomTapped() {
        viewportCoordinator?.handleJumpToBottomTapped(
            scrollToBottom:
            DemoAlignedWeakBinder.action(
                owner: self,
                DemoAlignedChatViewController.handleJumpToBottomAnimation
            )
        )
    }

    private func handleJumpToBottomAnimation(_ animated: Bool) {
        viewportScrollCoordinator?.scrollToBottom(animated: animated)
    }

    @objc
    private func handleSettingsTapped() {
        chatRouteCoordinator?.presentSettingsIfNeeded()
    }

    @objc
    private func handleSearchTapped() {
        conversationSearchCoordinator?.presentSearchPrompt()
    }

    func presentChatSettings() {
        handleSettingsTapped()
    }

    func presentConversationSearch() {
        handleSearchTapped()
    }

    @objc
    private func handleImageTapped(_ sender: UIButton) {
        presentMediaEntryMenu(anchor: sender)
    }

    @objc
    private func handleVideoTapped(_ sender: UIButton) {
        let sheet = UIAlertController(
            title: L("发送视频", "Send Video"),
            message: nil,
            preferredStyle: .actionSheet
        )
        sheet.addAction(UIAlertAction(title: L("从相册选择视频", "Choose Video"), style: .default) { [weak self] _ in
            self?.composerActionCoordinator?.handleVideoTapped()
        })
        sheet.addAction(UIAlertAction(title: L("取消", "Cancel"), style: .cancel))

        if let popover = sheet.popoverPresentationController {
            popover.sourceView = sender
            popover.sourceRect = sender.bounds
        }
        present(sheet, animated: true)
    }

    private func presentMediaEntryMenu(anchor: UIView) {
        let sheet = UIAlertController(
            title: L("发送媒体", "Send Media"),
            message: nil,
            preferredStyle: .actionSheet
        )
        sheet.addAction(UIAlertAction(title: L("发送图片", "Send Image"), style: .default) { [weak self] _ in
            self?.composerActionCoordinator?.handleImageTapped()
        })
        sheet.addAction(UIAlertAction(title: L("发送视频", "Send Video"), style: .default) { [weak self] _ in
            self?.composerActionCoordinator?.handleVideoTapped()
        })
        sheet.addAction(UIAlertAction(title: L("发送语音（文件）", "Send Voice (File)"), style: .default) { [weak self] _ in
            self?.presentVoicePicker()
        })
        sheet.addAction(UIAlertAction(title: L("取消", "Cancel"), style: .cancel))

        if let popover = sheet.popoverPresentationController {
            popover.sourceView = anchor
            popover.sourceRect = anchor.bounds
        }
        present(sheet, animated: true)
    }

    private func presentVoicePicker() {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.audio, .mpeg4Audio]
        )
        picker.delegate = self
        picker.allowsMultipleSelection = false
        picker.modalPresentationStyle = .formSheet
        present(picker, animated: true)
    }

    private func sendVoiceFile(_ url: URL) {
        guard !isSendingVoice else { return }
        isSendingVoice = true
        Task { [weak self] in
            guard let self else { return }
            defer { self.isSendingVoice = false }
            do {
                _ = try await self.chatController.sendVoiceMessage(fileURL: url)
                await MainActor.run {
                    self.handleSendSucceeded()
                }
            } catch {
                await MainActor.run {
                    self.failureFeedbackActions?.showSendFailureHint()
                }
            }
        }
    }

    @objc
    private func handleVideoTapped() {
        // Fallback for selector compatibility in case an older binding uses no-arg action.
        composerActionCoordinator?.handleVideoTapped()
    }

    private func presentSearchResults(query: String, results: [ChatMessageSearchResult]) {
        IMProbeLogger.log(
            "[DemoAlignedSearch] present-results conversation=\(conversation.id) query=\(query) count=\(results.count)"
        )
        let resultsViewController = DemoAlignedChatSearchResultsViewController(
            query: query,
            results: results
        ) { [weak self] result in
            self?.focusOnSearchResult(result)
        }
        navigationController?.pushViewController(resultsViewController, animated: true)
    }

    private func focusOnSearchResult(_ result: ChatMessageSearchResult) {
        IMProbeLogger.log(
            "[DemoAlignedSearch] focus-request conversation=\(conversation.id) message=\(result.message.id)"
        )
        revealMessage(withID: result.message.id, allowLoadOlder: true, context: .search)
    }

    private func revealMessage(
        withID messageID: String,
        allowLoadOlder: Bool,
        context: MessageRevealContext
    ) {
        if let indexPath = collectionDataSource.indexPath(forMessageID: messageID) {
            IMProbeLogger.log(
                "[DemoAlignedSearch] reveal-hit conversation=\(conversation.id) message=\(messageID)"
            )
            scrollToMessage(at: indexPath)
            return
        }

        guard allowLoadOlder, chatController.canLoadOlderMessages else {
            IMProbeLogger.log(
                "[DemoAlignedSearch] reveal-miss conversation=\(conversation.id) message=\(messageID) allowLoadOlder=\(allowLoadOlder ? 1 : 0)"
            )
            presentLocateFailureAlert(context: context)
            return
        }

        IMProbeLogger.log(
            "[DemoAlignedSearch] reveal-load-older conversation=\(conversation.id) message=\(messageID)"
        )
        Task { [weak self] in
            guard let self else { return }
            await self.messageFlowCoordinator?.loadOlderMessagesIfNeeded()
            self.revealMessage(withID: messageID, allowLoadOlder: false, context: context)
        }
    }

    private func scrollToMessage(at indexPath: IndexPath) {
        collectionView.layoutIfNeeded()
        collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.flashMessageCell(at: indexPath)
        }
    }

    private func flashMessageCell(at indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) else { return }
        let originalBorderWidth = cell.layer.borderWidth
        let originalBorderColor = cell.layer.borderColor

        cell.layer.borderWidth = 2
        cell.layer.borderColor = UIColor.systemYellow.withAlphaComponent(0.95).cgColor
        cell.layer.cornerRadius = 10
        cell.layer.masksToBounds = true

        UIView.animate(
            withDuration: 0.9,
            delay: 0.35,
            options: [.curveEaseOut],
            animations: {
                cell.layer.borderWidth = originalBorderWidth
                cell.layer.borderColor = originalBorderColor
            }
        )
    }

    private func presentLocateFailureAlert(context: MessageRevealContext) {
        let title: String
        let message: String
        switch context {
        case .search:
            title = L("未定位到消息", "Message Not Located")
            message = L(
                "该结果暂不在当前加载窗口，请上滑加载更多历史后再试。",
                "This result is outside the current loaded window. Load more history and try again."
            )
        case .reply:
            title = L("未找到被回复消息", "Original Message Not Found")
            message = L(
                "已尝试加载更多历史，仍未定位到被回复内容，可能已被清理或不可见。",
                "More history was loaded, but the referenced message is still unavailable."
            )
        }
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L("好的", "OK"), style: .default))
        present(alert, animated: true)
    }

    private func consumePendingMessageFocusIfNeeded() {
        pendingFocusTask?.cancel()
        guard let pendingMessageID = IMChatStore.shared.consumePendingMessageFocus(for: conversation) else {
            return
        }
        IMProbeLogger.log(
            "[DemoAlignedSearch] pending-focus-consume conversation=\(conversation.id) message=\(pendingMessageID)"
        )

        pendingFocusTask = Task { [weak self] in
            guard let self else { return }
            while !self.chatController.hasCompletedInitialLoad {
                try? await Task.sleep(nanoseconds: 120_000_000)
                guard !Task.isCancelled else { return }
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                IMProbeLogger.log(
                    "[DemoAlignedSearch] pending-focus-reveal conversation=\(self.conversation.id) message=\(pendingMessageID)"
                )
                self.revealMessage(withID: pendingMessageID, allowLoadOlder: true, context: .search)
            }
        }
    }
}

extension DemoAlignedChatViewController: UICollectionViewDelegate, UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let isNearBottom = viewportScrollCoordinator?.isNearBottom(
            threshold: UIConstants.nearBottomThreshold
        ) ?? true
        viewportCoordinator?.updateJumpToBottomUI(isNearBottom: isNearBottom, animated: true)
        paginationCoordinator?.handleScrollDidScroll(scrollView)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let message = collectionDataSource.message(at: indexPath) else { return }
        DemoAlignedWeakBinder.mainActorAsyncAction(
            owner: self,
            DemoAlignedChatViewController.handleMessageTappedAction
        )(message)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        contextMenuConfigurationForItemAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard let message = collectionDataSource.message(at: indexPath) else { return nil }
        return UIContextMenuConfiguration(identifier: message.id as NSString, previewProvider: nil) { [weak self] _ in
            self?.makeMessageContextMenu(for: message)
        }
    }
}

private extension DemoAlignedChatViewController {
    func handleMessageTappedAction(_ message: ChatMessage) async {
        await messageActionCoordinator?.handleMessageTapped(message)
    }

    func tryRevealReplyTargetIfNeeded(from message: ChatMessage) -> Bool {
        guard let targetMessageID = message.replyToMessageID?.trimmingCharacters(in: .whitespacesAndNewlines),
              !targetMessageID.isEmpty,
              targetMessageID != "inline-reply" else {
            return false
        }
        revealMessage(withID: targetMessageID, allowLoadOlder: true, context: .reply)
        return true
    }

    func makeMessageContextMenu(for message: ChatMessage) -> UIMenu {
        let copyAction = UIAction(
            title: L("复制", "Copy"),
            image: UIImage(systemName: "doc.on.doc")
        ) { _ in
            UIPasteboard.general.string = message.content
        }

        let replyAction = UIAction(
            title: L("引用回复", "Reply"),
            image: UIImage(systemName: "arrowshape.turn.up.left")
        ) { [weak self] _ in
            self?.chatController.toggleReplyDraft(for: message.id)
            self?.inputField.becomeFirstResponder()
        }

        let mentionAction = UIAction(
            title: L("@TA", "@Mention"),
            image: UIImage(systemName: "at")
        ) { [weak self] _ in
            guard let self else { return }
            let mentionName = message.sender.username.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !mentionName.isEmpty else { return }
            let existing = self.inputField.text ?? ""
            self.inputField.text = existing + "@\(mentionName) "
            self.composerActionCoordinator?.handleInputEditingChanged()
            self.inputField.becomeFirstResponder()
        }

        let deleteAction = UIAction(
            title: L("删除", "Delete"),
            image: UIImage(systemName: "trash"),
            attributes: message.isMine && message.deliveryStatus == .failed ? .destructive : .disabled
        ) { [weak self] _ in
            self?.chatController.removeLocalFailedMessage(message.id)
        }

        let resendAction = UIAction(
            title: L("重发", "Resend"),
            image: UIImage(systemName: "arrow.clockwise"),
            attributes: message.isMine && message.deliveryStatus == .failed ? [] : .disabled
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.messageActionCoordinator?.handleMessageTapped(message)
            }
        }

        let orderedActions = [copyAction, replyAction, mentionAction, resendAction, deleteAction]
        return UIMenu(title: "", children: orderedActions)
    }
}

extension DemoAlignedChatViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        composerActionCoordinator?.handleTextFieldDidBeginEditing()
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        composerActionCoordinator?.handleTextFieldDidEndEditing()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        composerActionCoordinator?.handleTextFieldShouldReturn() ?? true
    }
}

extension DemoAlignedChatViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let rawURL = urls.first else { return }
        let accessed = rawURL.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                rawURL.stopAccessingSecurityScopedResource()
            }
        }

        let cacheURL = URL(
            fileURLWithPath: NSTemporaryDirectory(),
            isDirectory: true
        ).appendingPathComponent("voice-\(UUID().uuidString).\(rawURL.pathExtension.isEmpty ? "m4a" : rawURL.pathExtension)")

        do {
            if FileManager.default.fileExists(atPath: cacheURL.path) {
                try FileManager.default.removeItem(at: cacheURL)
            }
            try FileManager.default.copyItem(at: rawURL, to: cacheURL)
            sendVoiceFile(cacheURL)
        } catch {
            failureFeedbackActions?.showSendFailureHint()
        }
    }
}
