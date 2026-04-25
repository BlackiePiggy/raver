import Foundation
import UIKit
import PhotosUI
import UniformTypeIdentifiers

enum DemoAlignedPickedMedia {
    case image(URL)
    case video(URL)
}

final class DemoAlignedMediaSendCoordinator: NSObject {
    private weak var presenter: UIViewController?
    private let chatContextProvider: DemoAlignedChatContextProvider
    private let failureFeedbackActions: DemoAlignedFailureFeedbackActions
    private let onPicked: (DemoAlignedPickedMedia) -> Void

    init(
        presenter: UIViewController,
        chatContextProvider: DemoAlignedChatContextProvider,
        failureFeedbackActions: DemoAlignedFailureFeedbackActions,
        onPicked: @escaping (DemoAlignedPickedMedia) -> Void
    ) {
        self.presenter = presenter
        self.chatContextProvider = chatContextProvider
        self.failureFeedbackActions = failureFeedbackActions
        self.onPicked = onPicked
        super.init()
    }

    func presentImagePicker() {
        presentPicker(filter: .images)
    }

    func presentVideoPicker() {
        presentPicker(filter: .videos)
    }

    private func presentPicker(filter: PHPickerFilter) {
        guard let presenter else { return }
        var configuration = PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
        configuration.selectionLimit = 1
        configuration.filter = filter

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        presenter.present(picker, animated: true)
    }

    private func loadPickedFile(
        provider: NSItemProvider,
        typeIdentifier: String,
        defaultExtension: String,
        onReady: @escaping (URL) -> Void
    ) {
        provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { [weak self] url, error in
            guard let self else { return }
            if let error {
                self.dispatchError(
                    self.userFacingMessage(from: error),
                    reason: "picker_file_representation_failed"
                )
                return
            }

            guard let url else {
                self.dispatchError(
                    L("读取媒体失败，请重试", "Failed to read media. Please retry."),
                    reason: "picker_file_url_missing"
                )
                return
            }

            do {
                let cacheKind: ChatMediaTempFileStore.MediaKind
                if typeIdentifier == UTType.movie.identifier {
                    cacheKind = .video
                } else if typeIdentifier == UTType.image.identifier {
                    cacheKind = .image
                } else {
                    cacheKind = .other
                }
                let localCopy = try ChatMediaTempFileStore.copyFile(
                    from: url,
                    defaultExtension: defaultExtension,
                    prefix: "chat-upload",
                    kind: cacheKind
                )
                DispatchQueue.main.async {
                    onReady(localCopy)
                }
            } catch {
                self.dispatchError(
                    self.userFacingMessage(from: error),
                    reason: "picker_temp_copy_failed"
                )
            }
        }
    }

    private func dispatchError(_ message: String, reason: String) {
        DemoAlignedChatLogger.mediaPickerError(
            conversationID: chatContextProvider.conversationID,
            reason: reason,
            message: message
        )
        DispatchQueue.main.async { [failureFeedbackActions] in
            failureFeedbackActions.show(message: message, reason: reason)
        }
    }

    private func userFacingMessage(from error: Error) -> String {
        if let message = error.userFacingMessage, !message.isEmpty {
            return message
        }
        return L("发送失败，请重试", "Send failed. Please retry.")
    }
}

extension DemoAlignedMediaSendCoordinator: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let first = results.first else { return }
        let provider = first.itemProvider

        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            loadPickedFile(
                provider: provider,
                typeIdentifier: UTType.image.identifier,
                defaultExtension: "jpg",
                onReady: { [onPicked] url in
                    onPicked(.image(url))
                }
            )
            return
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
            loadPickedFile(
                provider: provider,
                typeIdentifier: UTType.movie.identifier,
                defaultExtension: "mov",
                onReady: { [onPicked] url in
                    onPicked(.video(url))
                }
            )
            return
        }

        dispatchError(
            L("暂不支持该媒体类型", "This media type is not supported yet."),
            reason: "picker_unsupported_media_type"
        )
    }
}
