import Foundation
import UIKit

struct DemoAlignedChatLayoutAssemblyDependencies {
    let chatLayout: CollectionViewChatLayout
    let interItemSpacing: CGFloat
    let interSectionSpacing: CGFloat
    let additionalInsets: UIEdgeInsets
}

struct DemoAlignedCollectionViewAssemblyDependencies {
    let hostView: UIView
    let chatLayout: CollectionViewChatLayout
    let delegate: UICollectionViewDelegate
    let dataSource: UICollectionViewDataSource
    let registerCells: (UICollectionView) -> Void
}

struct DemoAlignedComposerAssemblyDependencies {
    let hostView: UIView
    let keyboardTopAnchor: NSLayoutYAxisAnchor
    let collectionView: UICollectionView
    let composerContainer: UIView
    let mediaProgressContainer: UIView
    let mediaProgressView: UIProgressView
    let mediaProgressLabel: UILabel
    let imageButton: UIButton
    let videoButton: UIButton
    let inputField: UITextField
    let inputFieldDelegate: UITextFieldDelegate
    let sendButton: UIButton
    let backgroundColor: UIColor
    let dividerColor: UIColor
    let accentColor: UIColor
    let secondaryTextColor: UIColor
    let mediaProgressText: String
    let inputPlaceholder: String
    let sendButtonTitle: String
    let actionTarget: AnyObject
    let inputChangedAction: Selector
    let imageTappedAction: Selector
    let videoTappedAction: Selector
    let sendTappedAction: Selector
}

struct DemoAlignedNavigationItemsAssemblyDependencies {
    let navigationItem: UINavigationItem
    let actionTarget: AnyObject
    let settingsTappedAction: Selector
    let accessibilityLabel: String
}

struct DemoAlignedJumpToBottomButtonAssemblyDependencies {
    let hostView: UIView
    let composerContainer: UIView
    let jumpToBottomButton: UIButton
    let horizontalInset: CGFloat
    let bottomInset: CGFloat
    let accentColor: UIColor
    let actionTarget: AnyObject
    let tappedAction: Selector
}

struct DemoAlignedOlderLoadingIndicatorAssemblyDependencies {
    let hostView: UIView
    let loadingIndicator: UIActivityIndicatorView
}

enum DemoAlignedChatUIAssemblyFactory {
    @MainActor
    static func configureNavigationItems(
        _ dependencies: DemoAlignedNavigationItemsAssemblyDependencies
    ) {
        let settingsButton = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"),
            style: .plain,
            target: dependencies.actionTarget,
            action: dependencies.settingsTappedAction
        )
        settingsButton.accessibilityLabel = dependencies.accessibilityLabel
        dependencies.navigationItem.rightBarButtonItem = settingsButton
    }

    @MainActor
    static func configureLayout(_ dependencies: DemoAlignedChatLayoutAssemblyDependencies) {
        dependencies.chatLayout.settings.interItemSpacing = dependencies.interItemSpacing
        dependencies.chatLayout.settings.interSectionSpacing = dependencies.interSectionSpacing
        dependencies.chatLayout.settings.additionalInsets = dependencies.additionalInsets
        dependencies.chatLayout.keepContentOffsetAtBottomOnBatchUpdates = true
    }

    @MainActor
    static func makeCollectionView(
        _ dependencies: DemoAlignedCollectionViewAssemblyDependencies
    ) -> UICollectionView {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: dependencies.chatLayout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.keyboardDismissMode = .interactive
        collectionView.alwaysBounceVertical = true
        collectionView.showsVerticalScrollIndicator = false
        collectionView.delegate = dependencies.delegate
        collectionView.dataSource = dependencies.dataSource
        dependencies.registerCells(collectionView)
        dependencies.hostView.addSubview(collectionView)
        return collectionView
    }

    @MainActor
    static func configureComposer(
        _ dependencies: DemoAlignedComposerAssemblyDependencies
    ) -> NSLayoutConstraint {
        dependencies.composerContainer.translatesAutoresizingMaskIntoConstraints = false
        dependencies.composerContainer.backgroundColor = dependencies.backgroundColor
        dependencies.hostView.addSubview(dependencies.composerContainer)

        let divider = UIView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.backgroundColor = dependencies.dividerColor
        dependencies.composerContainer.addSubview(divider)

        dependencies.mediaProgressContainer.translatesAutoresizingMaskIntoConstraints = false
        dependencies.mediaProgressContainer.isHidden = true
        dependencies.composerContainer.addSubview(dependencies.mediaProgressContainer)

        dependencies.mediaProgressView.translatesAutoresizingMaskIntoConstraints = false
        dependencies.mediaProgressView.progress = 0
        dependencies.mediaProgressView.trackTintColor = dependencies.dividerColor
        dependencies.mediaProgressView.progressTintColor = dependencies.accentColor
        dependencies.mediaProgressView.isHidden = true

        dependencies.mediaProgressLabel.translatesAutoresizingMaskIntoConstraints = false
        dependencies.mediaProgressLabel.font = .systemFont(ofSize: 11, weight: .medium)
        dependencies.mediaProgressLabel.textColor = dependencies.secondaryTextColor
        dependencies.mediaProgressLabel.text = dependencies.mediaProgressText
        dependencies.mediaProgressLabel.isHidden = true

        let mediaProgressStack = UIStackView(arrangedSubviews: [
            dependencies.mediaProgressView,
            dependencies.mediaProgressLabel
        ])
        mediaProgressStack.translatesAutoresizingMaskIntoConstraints = false
        mediaProgressStack.axis = .vertical
        mediaProgressStack.spacing = 4
        dependencies.mediaProgressContainer.addSubview(mediaProgressStack)

        dependencies.inputField.translatesAutoresizingMaskIntoConstraints = false
        dependencies.inputField.placeholder = dependencies.inputPlaceholder
        dependencies.inputField.borderStyle = .none
        dependencies.inputField.backgroundColor = dependencies.dividerColor.withAlphaComponent(0.28)
        dependencies.inputField.layer.cornerRadius = 18
        dependencies.inputField.layer.borderWidth = 1
        dependencies.inputField.layer.borderColor = dependencies.dividerColor.withAlphaComponent(0.7).cgColor
        dependencies.inputField.font = .systemFont(ofSize: 16)
        dependencies.inputField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 36))
        dependencies.inputField.leftViewMode = .always
        dependencies.inputField.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 36))
        dependencies.inputField.rightViewMode = .always
        dependencies.inputField.returnKeyType = .send
        dependencies.inputField.delegate = dependencies.inputFieldDelegate
        dependencies.inputField.addTarget(
            dependencies.actionTarget,
            action: dependencies.inputChangedAction,
            for: .editingChanged
        )
        dependencies.composerContainer.addSubview(dependencies.inputField)

        dependencies.imageButton.translatesAutoresizingMaskIntoConstraints = false
        var mediaEntryConfig = UIButton.Configuration.plain()
        mediaEntryConfig.image = UIImage(systemName: "plus.circle.fill")
        mediaEntryConfig.baseForegroundColor = dependencies.accentColor
        mediaEntryConfig.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2)
        dependencies.imageButton.configuration = mediaEntryConfig
        dependencies.imageButton.addTarget(
            dependencies.actionTarget,
            action: dependencies.imageTappedAction,
            for: .touchUpInside
        )
        dependencies.composerContainer.addSubview(dependencies.imageButton)

        dependencies.videoButton.translatesAutoresizingMaskIntoConstraints = false
        var quickVideoConfig = UIButton.Configuration.plain()
        quickVideoConfig.image = UIImage(systemName: "video.circle")
        quickVideoConfig.baseForegroundColor = dependencies.secondaryTextColor
        quickVideoConfig.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2)
        dependencies.videoButton.configuration = quickVideoConfig
        dependencies.videoButton.addTarget(
            dependencies.actionTarget,
            action: dependencies.videoTappedAction,
            for: .touchUpInside
        )
        dependencies.composerContainer.addSubview(dependencies.videoButton)

        dependencies.sendButton.translatesAutoresizingMaskIntoConstraints = false
        var sendConfig = UIButton.Configuration.filled()
        sendConfig.title = dependencies.sendButtonTitle
        sendConfig.baseBackgroundColor = dependencies.accentColor
        sendConfig.baseForegroundColor = .white
        sendConfig.cornerStyle = .capsule
        sendConfig.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14)
        dependencies.sendButton.configuration = sendConfig
        dependencies.sendButton.addTarget(
            dependencies.actionTarget,
            action: dependencies.sendTappedAction,
            for: .touchUpInside
        )
        dependencies.composerContainer.addSubview(dependencies.sendButton)

        NSLayoutConstraint.activate([
            dependencies.composerContainer.leadingAnchor.constraint(equalTo: dependencies.hostView.leadingAnchor),
            dependencies.composerContainer.trailingAnchor.constraint(equalTo: dependencies.hostView.trailingAnchor),
            dependencies.composerContainer.bottomAnchor.constraint(equalTo: dependencies.keyboardTopAnchor),

            divider.leadingAnchor.constraint(equalTo: dependencies.composerContainer.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: dependencies.composerContainer.trailingAnchor),
            divider.topAnchor.constraint(equalTo: dependencies.composerContainer.topAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1),

            dependencies.mediaProgressContainer.leadingAnchor.constraint(equalTo: dependencies.composerContainer.leadingAnchor, constant: 12),
            dependencies.mediaProgressContainer.trailingAnchor.constraint(equalTo: dependencies.composerContainer.trailingAnchor, constant: -12),
            dependencies.mediaProgressContainer.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 4),

            mediaProgressStack.leadingAnchor.constraint(equalTo: dependencies.mediaProgressContainer.leadingAnchor),
            mediaProgressStack.trailingAnchor.constraint(equalTo: dependencies.mediaProgressContainer.trailingAnchor),
            mediaProgressStack.topAnchor.constraint(equalTo: dependencies.mediaProgressContainer.topAnchor),
            mediaProgressStack.bottomAnchor.constraint(equalTo: dependencies.mediaProgressContainer.bottomAnchor),

            dependencies.imageButton.leadingAnchor.constraint(equalTo: dependencies.composerContainer.leadingAnchor, constant: 12),
            dependencies.imageButton.centerYAnchor.constraint(equalTo: dependencies.inputField.centerYAnchor),
            dependencies.imageButton.widthAnchor.constraint(equalToConstant: 32),
            dependencies.imageButton.heightAnchor.constraint(equalToConstant: 32),

            dependencies.videoButton.leadingAnchor.constraint(equalTo: dependencies.imageButton.trailingAnchor, constant: 6),
            dependencies.videoButton.centerYAnchor.constraint(equalTo: dependencies.inputField.centerYAnchor),
            dependencies.videoButton.widthAnchor.constraint(equalToConstant: 32),
            dependencies.videoButton.heightAnchor.constraint(equalToConstant: 32),

            dependencies.inputField.leadingAnchor.constraint(equalTo: dependencies.videoButton.trailingAnchor, constant: 8),
            dependencies.inputField.topAnchor.constraint(equalTo: dependencies.mediaProgressContainer.bottomAnchor, constant: 8),
            dependencies.inputField.bottomAnchor.constraint(equalTo: dependencies.composerContainer.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            dependencies.inputField.heightAnchor.constraint(equalToConstant: 36),

            dependencies.sendButton.leadingAnchor.constraint(equalTo: dependencies.inputField.trailingAnchor, constant: 8),
            dependencies.sendButton.trailingAnchor.constraint(equalTo: dependencies.composerContainer.trailingAnchor, constant: -12),
            dependencies.sendButton.centerYAnchor.constraint(equalTo: dependencies.inputField.centerYAnchor),
            dependencies.sendButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 56),
            dependencies.sendButton.heightAnchor.constraint(equalToConstant: 32),

            dependencies.collectionView.leadingAnchor.constraint(equalTo: dependencies.hostView.leadingAnchor),
            dependencies.collectionView.trailingAnchor.constraint(equalTo: dependencies.hostView.trailingAnchor),
            dependencies.collectionView.topAnchor.constraint(equalTo: dependencies.hostView.topAnchor),
            dependencies.collectionView.bottomAnchor.constraint(equalTo: dependencies.composerContainer.topAnchor)
        ])

        let progressHeightConstraint = dependencies.mediaProgressContainer.heightAnchor.constraint(equalToConstant: 0)
        progressHeightConstraint.isActive = true
        return progressHeightConstraint
    }

    @MainActor
    static func configureJumpToBottomButton(
        _ dependencies: DemoAlignedJumpToBottomButtonAssemblyDependencies
    ) {
        dependencies.jumpToBottomButton.translatesAutoresizingMaskIntoConstraints = false

        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: "arrow.down")
        config.imagePlacement = .leading
        config.imagePadding = 6
        config.cornerStyle = .capsule
        config.baseBackgroundColor = dependencies.accentColor
        config.baseForegroundColor = .white
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        dependencies.jumpToBottomButton.configuration = config
        dependencies.jumpToBottomButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        dependencies.jumpToBottomButton.addTarget(
            dependencies.actionTarget,
            action: dependencies.tappedAction,
            for: .touchUpInside
        )
        dependencies.jumpToBottomButton.alpha = 0
        dependencies.jumpToBottomButton.isHidden = true

        dependencies.hostView.addSubview(dependencies.jumpToBottomButton)
        NSLayoutConstraint.activate([
            dependencies.jumpToBottomButton.trailingAnchor.constraint(
                equalTo: dependencies.hostView.safeAreaLayoutGuide.trailingAnchor,
                constant: -dependencies.horizontalInset
            ),
            dependencies.jumpToBottomButton.bottomAnchor.constraint(
                equalTo: dependencies.composerContainer.topAnchor,
                constant: -dependencies.bottomInset
            )
        ])
    }

    @MainActor
    static func configureOlderLoadingIndicator(
        _ dependencies: DemoAlignedOlderLoadingIndicatorAssemblyDependencies
    ) {
        dependencies.loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        dependencies.loadingIndicator.hidesWhenStopped = true
        dependencies.hostView.addSubview(dependencies.loadingIndicator)
        NSLayoutConstraint.activate([
            dependencies.loadingIndicator.centerXAnchor.constraint(equalTo: dependencies.hostView.centerXAnchor),
            dependencies.loadingIndicator.topAnchor.constraint(equalTo: dependencies.hostView.safeAreaLayoutGuide.topAnchor, constant: 8)
        ])
    }
}
