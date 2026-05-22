import PhotosUI
import SwiftUI

struct EventUploadImageZoneCard: View {
    private let thumbnailSize = CGSize(width: 64, height: 64)

    let zone: EventUploadImageZone
    let images: [EventUploadImageDraft]
    let isRequired: Bool
    let onPicked: ([EventUploadPickedImageData]) async -> Void
    let onDelete: (UUID) -> Void
    let onMove: (UUID, Int) -> Void

    @State private var selectedItems: [PhotosPickerItem] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(zone.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(RaverTheme.primaryText)
                        if isRequired {
                            Text("*")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.red)
                        }
                    }
                }
                Spacer()
                Text(LT("\(images.count) 张", "\(images.count) images", "\(images.count)枚"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(RaverTheme.background, in: Capsule())
            }

            PhotosPicker(selection: $selectedItems, maxSelectionCount: 12, matching: .images) {
                imageActionLabel(
                    title: images.isEmpty ? LT("选择图片", "Choose Images", "画像を選択") : LT("继续添加", "Add More", "さらに追加"),
                    systemImage: "photo.on.rectangle"
                )
            }
            .buttonStyle(.plain)
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
                        HStack(spacing: 10) {
                            thumbnail(for: image)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(imageRowTitle(index: index))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(RaverTheme.primaryText)
                                Text(image.fileName)
                                    .font(.caption2)
                                    .foregroundStyle(RaverTheme.secondaryText)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()

                            Button {
                                onMove(image.id, -1)
                            } label: {
                                Image(systemName: "chevron.up")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(RaverTheme.secondaryText)
                                    .frame(width: 24, height: 24)
                                    .background(RaverTheme.card.opacity(index == 0 ? 0.6 : 1), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .disabled(index == 0)

                            Button {
                                onMove(image.id, 1)
                            } label: {
                                Image(systemName: "chevron.down")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(RaverTheme.secondaryText)
                                    .frame(width: 24, height: 24)
                                    .background(RaverTheme.card.opacity(index == images.count - 1 ? 0.6 : 1), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .disabled(index == images.count - 1)

                            Button {
                                onDelete(image.id)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.red)
                                    .frame(width: 24, height: 24)
                                    .background(RaverTheme.card, in: Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 9)
                        .background(RaverTheme.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: images.isEmpty ? 176 : 168, alignment: .topLeading)
        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isRequired && images.isEmpty ? RaverTheme.accent : RaverTheme.cardBorder, lineWidth: 1)
        )
    }

    private func imageActionLabel(title: String, systemImage: String) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(RaverTheme.background)
            .frame(height: images.isEmpty ? 96 : 52)
            .overlay {
                if images.isEmpty {
                    VStack(spacing: 7) {
                        Image(systemName: systemImage)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(RaverTheme.accent)
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(RaverTheme.primaryText)
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: systemImage)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(RaverTheme.accent)
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(RaverTheme.primaryText)
                    }
                }
            }
    }

    private func imageRowTitle(index: Int) -> String {
        if index == 0 {
            return LT("主图", "Primary", "メイン")
        }
        return LT("附图 \(index)", "Extra \(index)", "追加 \(index)")
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
                .frame(width: thumbnailSize.width, height: thumbnailSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
            .frame(width: thumbnailSize.width, height: thumbnailSize.height)
            .background(RaverTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            Image(systemName: "photo")
                .font(.caption.weight(.semibold))
                .foregroundStyle(RaverTheme.accent)
                .frame(width: thumbnailSize.width, height: thumbnailSize.height)
                .background(RaverTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}
