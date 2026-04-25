import Foundation
import UIKit

final class DemoAlignedChatViewController: UIViewController {
    private enum UIConstants {
        static let topPaginationTriggerOffset: CGFloat = 24
        static let nearBottomThreshold: CGFloat = 28
        static let maxBubbleWidthRatio: CGFloat = 0.72
        static let jumpButtonHorizontalInset: CGFloat = 16
        static let jumpButtonBottomInset: CGFloat = 12
        static let keyboardSettleDelayNs: UInt64 = 40_000_000
    }

    private var conversation: Conversation
    private var service: SocialService
    private var onNavigate: ((AppRoute) -> Void)?
    private var onLeaveConversation: (() -> Void)?
    private var pendingFocusTask: Task<Void, Never>?

    private let chatController: RaverChatController
    private let chatLayout = CollectionViewChatLayout()
    private let collectionDataSource: RaverChatCollectionDataSource
    private let scrollCoordinator = RaverChatScrollCoordinator()
    private var collectionView: UICollectionView!
    private let composerContainer = UIView()
    private let mediaProgressContainer = UIView()
    private let mediaProgressView = UIProgressView(progressViewStyle: .default)
    private let mediaProgressLabel = UILabel()
    private let imageButton = UIButton(type: .system)
    private let videoButton = UIButton(type: .system)
    private let inputField = UITextField()
    private let sendButton = UIButton(type: .system)
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
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        pendingFocusTask?.cancel()
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
        let hasMessages = messageFlowCoordinator?.hasMessages ?? false
        let shouldScroll = chatScreenLifecycleCoordinator?.handleViewDidAppear(hasMessages: hasMessages) ?? hasMessages
        if shouldScroll {
            viewportScrollCoordinator?.scrollToBottom(animated: false)
        }
        consumePendingMessageFocusIfNeeded()
    }

    func updateConversation(
        _ conversation: Conversation,
        service: SocialService,
        onNavigate: ((AppRoute) -> Void)? = nil,
        onLeaveConversation: (() -> Void)? = nil
    ) {
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
                imageTappedAction: #selector(handleImageTapped),
                videoTappedAction: #selector(handleVideoTapped),
                sendTappedAction: #selector(handleSendTapped)
            )
        )
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
        viewportScrollCoordinator?.forceScrollOnNextApply()
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
                paginationCoordinator: paginationCoordinator
            )
        )
        controllerBindingCoordinator?.start()
    }

    // MARK: - User Actions

    @objc
    private func handleSendTapped() {
        composerActionCoordinator?.handleSendTapped()
    }

    @objc
    private func handleInputFieldEditingChanged() {
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
    private func handleImageTapped() {
        composerActionCoordinator?.handleImageTapped()
    }

    @objc
    private func handleVideoTapped() {
        composerActionCoordinator?.handleVideoTapped()
    }

    private func presentSearchResults(query: String, results: [ChatMessageSearchResult]) {
        OpenIMProbeLogger.log(
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
        OpenIMProbeLogger.log(
            "[DemoAlignedSearch] focus-request conversation=\(conversation.id) message=\(result.message.id)"
        )
        revealMessage(withID: result.message.id, allowLoadOlder: true)
    }

    private func revealMessage(withID messageID: String, allowLoadOlder: Bool) {
        if let indexPath = collectionDataSource.indexPath(forMessageID: messageID) {
            OpenIMProbeLogger.log(
                "[DemoAlignedSearch] reveal-hit conversation=\(conversation.id) message=\(messageID)"
            )
            scrollToMessage(at: indexPath)
            return
        }

        guard allowLoadOlder, chatController.canLoadOlderMessages else {
            OpenIMProbeLogger.log(
                "[DemoAlignedSearch] reveal-miss conversation=\(conversation.id) message=\(messageID) allowLoadOlder=\(allowLoadOlder ? 1 : 0)"
            )
            presentSearchLocateFailureAlert()
            return
        }

        OpenIMProbeLogger.log(
            "[DemoAlignedSearch] reveal-load-older conversation=\(conversation.id) message=\(messageID)"
        )
        Task { [weak self] in
            guard let self else { return }
            await self.messageFlowCoordinator?.loadOlderMessagesIfNeeded()
            self.revealMessage(withID: messageID, allowLoadOlder: false)
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

    private func presentSearchLocateFailureAlert() {
        let alert = UIAlertController(
            title: L("未定位到消息", "Message Not Located"),
            message: L("该结果暂不在当前加载窗口，请上滑加载更多历史后再试。", "This result is outside the current loaded window. Load more history and try again."),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L("好的", "OK"), style: .default))
        present(alert, animated: true)
    }

    private func consumePendingMessageFocusIfNeeded() {
        pendingFocusTask?.cancel()
        guard let pendingMessageID = OpenIMChatStore.shared.consumePendingMessageFocus(for: conversation) else {
            return
        }
        OpenIMProbeLogger.log(
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
                OpenIMProbeLogger.log(
                    "[DemoAlignedSearch] pending-focus-reveal conversation=\(self.conversation.id) message=\(pendingMessageID)"
                )
                self.revealMessage(withID: pendingMessageID, allowLoadOlder: true)
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
}

private extension DemoAlignedChatViewController {
    func handleMessageTappedAction(_ message: ChatMessage) async {
        await messageActionCoordinator?.handleMessageTapped(message)
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
