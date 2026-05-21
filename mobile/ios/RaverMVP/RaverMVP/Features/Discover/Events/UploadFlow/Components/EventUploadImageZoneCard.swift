import PhotosUI
import SwiftUI
import UIKit

struct EventUploadImageZoneCard: View {
    let zone: EventUploadImageZone
    let images: [EventUploadImageDraft]
    let isRequired: Bool
    let onPicked: ([EventUploadPickedImageData]) async -> Void
    let onReplace: (UUID, EventUploadPickedImageData) async -> Void
    let onDelete: (UUID) -> Void
    let onMove: (UUID, Int) -> Void

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var replaceSelections: [UUID: PhotosPickerItem] = [:]
    @State private var showCamera = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(zone.title)
                    .font(.headline)
                    .foregroundStyle(RaverTheme.primaryText)
                if isRequired {
                    Text("*")
                        .foregroundStyle(.red)
                }
                Spacer()
                Text(LT("\(images.count) 张", "\(images.count) images", "\(images.count)枚"))
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
            }

            HStack(spacing: 10) {
                PhotosPicker(selection: $selectedItems, maxSelectionCount: 12, matching: .images) {
                    imageActionLabel(
                        title: images.isEmpty ? LT("选择图片", "Choose Images", "画像を選択") : LT("继续添加", "Add More", "さらに追加"),
                        systemImage: "photo.on.rectangle"
                    )
                }
                .buttonStyle(.plain)

                Button {
                    showCamera = true
                } label: {
                    imageActionLabel(title: LT("拍照", "Camera", "撮影"), systemImage: "camera")
                }
                .buttonStyle(.plain)
                .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
            }
            .onChange(of: selectedItems) { _, items in
                guard !items.isEmpty else { return }
                Task {
                    await onPicked(await pickedImageData(from: items))
                    selectedItems = []
                }
            }

            if !images.isEmpty {
                VStack(spacing: 8) {
                    ForEach(Array(images.enumerated()), id: \.element.id) { index, image in
                        HStack(spacing: 8) {
                            thumbnail(for: image)
                            Text(image.fileName)
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            PhotosPicker(selection: replaceBinding(for: image.id), matching: .images) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                            .buttonStyle(.plain)

                            Button {
                                onMove(image.id, -1)
                            } label: {
                                Image(systemName: "chevron.up")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                            .buttonStyle(.plain)
                            .disabled(index == 0)

                            Button {
                                onMove(image.id, 1)
                            } label: {
                                Image(systemName: "chevron.down")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                            .buttonStyle(.plain)
                            .disabled(index == images.count - 1)

                            Button {
                                onDelete(image.id)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(RaverTheme.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
        .padding(16)
        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isRequired && images.isEmpty ? RaverTheme.accent : RaverTheme.cardBorder, lineWidth: 1)
        )
        .sheet(isPresented: $showCamera) {
            EventUploadCameraPicker { imageData in
                Task {
                    await onPicked([imageData])
                }
            }
        }
        .onChange(of: replaceSelections) { _, selections in
            for (imageID, item) in selections {
                Task {
                    if let data = await pickedImageData(from: [item]).first {
                        await onReplace(imageID, data)
                    }
                    replaceSelections[imageID] = nil
                }
            }
        }
    }

    private func imageActionLabel(title: String, systemImage: String) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(RaverTheme.background)
            .frame(height: images.isEmpty ? 92 : 56)
            .overlay {
                Label(title, systemImage: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
            }
    }

    private func replaceBinding(for imageID: UUID) -> Binding<PhotosPickerItem?> {
        Binding {
            replaceSelections[imageID]
        } set: { item in
            replaceSelections[imageID] = item
        }
    }

    private func pickedImageData(from items: [PhotosPickerItem]) async -> [EventUploadPickedImageData] {
        var results: [EventUploadPickedImageData] = []
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            let contentType = item.supportedContentTypes.first
            results.append(
                EventUploadPickedImageData(
                    data: data,
                    fileExtension: contentType?.preferredFilenameExtension ?? "jpg",
                    mimeType: contentType?.preferredMIMEType ?? "image/jpeg"
                )
            )
        }
        return results
    }

    @ViewBuilder
    private func thumbnail(for image: EventUploadImageDraft) -> some View {
        if let localFileURL = image.localFileURL,
           let uiImage = UIImage(contentsOfFile: localFileURL.path) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 42, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else if let remoteURL = image.remoteURL,
                  let url = URL(string: AppConfig.resolvedURLString(remoteURL) ?? remoteURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let loadedImage):
                    loadedImage
                        .resizable()
                        .scaledToFill()
                default:
                    Image(systemName: "photo")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RaverTheme.accent)
                }
            }
            .frame(width: 42, height: 42)
            .background(RaverTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            Image(systemName: "photo")
                .font(.caption.weight(.semibold))
                .foregroundStyle(RaverTheme.accent)
                .frame(width: 42, height: 42)
                .background(RaverTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

private struct EventUploadCameraPicker: UIViewControllerRepresentable {
    let onPicked: (EventUploadPickedImageData) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = ["public.image"]
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onPicked: (EventUploadPickedImageData) -> Void

        init(onPicked: @escaping (EventUploadPickedImageData) -> Void) {
            self.onPicked = onPicked
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            defer { picker.dismiss(animated: true) }
            guard let image = info[.originalImage] as? UIImage,
                  let data = image.jpegData(compressionQuality: 0.92) else { return }
            onPicked(EventUploadPickedImageData(data: data, fileExtension: "jpg", mimeType: "image/jpeg"))
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
