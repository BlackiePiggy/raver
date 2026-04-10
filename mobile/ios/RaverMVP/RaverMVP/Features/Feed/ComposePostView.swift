import AVFoundation
import AVKit
import CoreLocation
import MapKit
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

enum ComposePostMode {
    case create
    case edit(Post)
}

struct ComposePostView: View {
    @Environment(\.dismiss) private var dismiss
    private let service: SocialService
    private let webService: WebFeatureService
    private let maxContentLength = 500
    private let maxMediaCount = 9
    private let mode: ComposePostMode
    private let onPostCreated: ((Post) -> Void)?
    private let onPostUpdated: ((Post) -> Void)?
    private let onPostDeleted: ((String) -> Void)?

    @State private var text: String
    @State private var mediaEntries: [ComposeMediaEntry]
    @State private var selectedMediaItems: [PhotosPickerItem] = []
    @State private var draggingMedia: ComposeMediaEntry?
    @State private var selectedPreview: ComposeMediaPreviewSelection?
    @State private var contentEditorHeight: CGFloat = 96
    @State private var isSending = false
    @State private var isDeleting = false
    @State private var isUploadingMedia = false
    @State private var toast: String?
    @State private var isDeleteConfirmationPresented = false
    @State private var locationTag: String
    @State private var showLocationPicker = false

    init(
        service: SocialService,
        webService: WebFeatureService,
        mode: ComposePostMode = .create,
        onPostCreated: ((Post) -> Void)? = nil,
        onPostUpdated: ((Post) -> Void)? = nil,
        onPostDeleted: ((String) -> Void)? = nil
    ) {
        self.service = service
        self.webService = webService
        self.mode = mode
        self.onPostCreated = onPostCreated
        self.onPostUpdated = onPostUpdated
        self.onPostDeleted = onPostDeleted

        switch mode {
        case .create:
            _text = State(initialValue: "")
            _mediaEntries = State(initialValue: [])
            _locationTag = State(initialValue: "")
        case .edit(let post):
            _text = State(initialValue: post.content)
            _mediaEntries = State(
                initialValue: post.images
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .map { ComposeMediaEntry(url: $0) }
            )
            _locationTag = State(initialValue: post.location ?? "")
        }
    }

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedMediaURLs: [String] {
        mediaEntries
            .map(\.url)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private var normalizedLocationTag: String? {
        let trimmed = locationTag.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var canSend: Bool {
        (!trimmedText.isEmpty || !normalizedMediaURLs.isEmpty)
            && !isSending
            && !isDeleting
            && !isUploadingMedia
    }

    private var isEditMode: Bool {
        if case .edit = mode {
            return true
        }
        return false
    }

    private var editingPost: Post? {
        if case .edit(let post) = mode {
            return post
        }
        return nil
    }

    private var submitButtonTitle: String {
        isEditMode ? L("重新发布", "Republish") : L("发布动态", "Publish Post")
    }

    private var pageTitle: String {
        isEditMode ? L("编辑动态", "Edit Post") : L("发布动态", "Publish Post")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                HStack {
                    Text(LL("正文"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                    Spacer()
                    Text("\(text.count)/\(maxContentLength)")
                        .font(.caption)
                        .foregroundStyle(text.count >= maxContentLength ? Color.orange : RaverTheme.secondaryText)
                }

                ZStack(alignment: .topLeading) {
                    AutoGrowingTextView(
                        text: $text,
                        calculatedHeight: $contentEditorHeight,
                        minHeight: 96,
                        maxHeight: 220
                    )
                    .frame(height: contentEditorHeight)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)

                    if text.isEmpty {
                        Text(LL("分享这一刻..."))
                            .font(.body)
                            .foregroundStyle(RaverTheme.secondaryText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 14)
                            .allowsHitTesting(false)
                    }
                }
                .background(RaverTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .onChange(of: text) { _, newValue in
                    guard newValue.count > maxContentLength else { return }
                    text = String(newValue.prefix(maxContentLength))
                }

                HStack(spacing: 10) {
                    Text(LL("媒体"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                    Spacer()
                    Text("\(mediaEntries.count)/\(maxMediaCount)")
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                }

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3),
                    spacing: 6
                ) {
                    ForEach(mediaEntries) { entry in
                        composeMediaTile(entry)
                            .onTapGesture {
                                guard let index = mediaEntries.firstIndex(of: entry) else { return }
                                selectedPreview = ComposeMediaPreviewSelection(index: index)
                            }
                            .contentShape(Rectangle())
                            .zIndex(draggingMedia?.id == entry.id ? 1 : 0)
                            .scaleEffect(draggingMedia?.id == entry.id ? 0.96 : 1)
                            .opacity(draggingMedia?.id == entry.id ? 0.82 : 1)
                            .onDrag {
                                draggingMedia = entry
                                return NSItemProvider(object: entry.id.uuidString as NSString)
                            }
                            .onDrop(
                                of: [UTType.plainText],
                                delegate: ComposeMediaDropDelegate(
                                    destinationItem: entry,
                                    items: $mediaEntries,
                                    draggingItem: $draggingMedia
                                )
                            )
                    }

                    if mediaEntries.count < maxMediaCount {
                        PhotosPicker(
                            selection: $selectedMediaItems,
                            maxSelectionCount: max(0, maxMediaCount - mediaEntries.count),
                            matching: .any(of: [.images, .videos])
                        ) {
                            ZStack {
                                RaverTheme.card

                                if isUploadingMedia {
                                    ProgressView()
                                        .tint(RaverTheme.primaryText)
                                } else {
                                    VStack(spacing: 6) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundStyle(RaverTheme.secondaryText)
                                        Text(LL("添加"))
                                            .font(.caption)
                                            .foregroundStyle(RaverTheme.secondaryText)
                                    }
                                }
                            }
                            .aspectRatio(1, contentMode: .fit)
                        }
                        .buttonStyle(.plain)
                        .disabled(isUploadingMedia)
                    }
                }
                .animation(.spring(response: 0.26, dampingFraction: 0.84), value: mediaEntries)
                .onDrop(
                    of: [UTType.plainText],
                    delegate: ComposeMediaDropOutsideDelegate(draggingItem: $draggingMedia)
                )

                locationSection

                Button {
                    Task { await submitPost() }
                } label: {
                    if isSending {
                        ProgressView().tint(.white)
                    } else {
                        Text(submitButtonTitle)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canSend)

                if isEditMode {
                    Button(role: .destructive) {
                        isDeleteConfirmationPresented = true
                    } label: {
                        if isDeleting {
                            ProgressView()
                                .tint(.red)
                        } else {
                            Text(LL("删除动态"))
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isDeleting || isSending || isUploadingMedia)
                }

                Spacer()
            }
            .padding(16)
            .foregroundStyle(RaverTheme.primaryText)
            .background(RaverTheme.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(pageTitle)
                        .font(.headline)
                        .foregroundStyle(RaverTheme.primaryText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("返回", "Back")) {
                        dismiss()
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }
            .onChange(of: selectedMediaItems) { _, newValue in
                guard !newValue.isEmpty else { return }
                Task {
                    await uploadSelectedMedia(from: newValue)
                }
            }
            .alert(L("提示", "Notice"), isPresented: Binding(
                get: { toast != nil },
                set: { if !$0 { toast = nil } }
            )) {
                Button(L("确定", "OK"), role: .cancel) {}
            } message: {
                Text(toast ?? "")
            }
            .confirmationDialog(
                L("确认删除这条动态吗？", "Are you sure you want to delete this post?"),
                isPresented: $isDeleteConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button(LL("删除动态"), role: .destructive) {
                    Task { await deletePost() }
                }
                Button(L("取消", "Cancel"), role: .cancel) {}
            }
            .fullScreenCover(item: $selectedPreview) { preview in
                ComposeMediaBrowserView(
                    entries: mediaEntries,
                    initialIndex: preview.index
                )
            }
            .fullScreenCover(isPresented: $showLocationPicker) {
                PostLocationPickerSheet(
                    initialQuery: normalizedLocationTag ?? "",
                    onSelect: { selected in
                        locationTag = selected
                    }
                )
            }
        }
    }

    @MainActor
    private func submitPost() async {
        isSending = true
        defer { isSending = false }

        guard !trimmedText.isEmpty || !normalizedMediaURLs.isEmpty else {
            toast = L("请填写正文或添加媒体", "Please enter text or add media.")
            return
        }

        do {
            if let editingPost {
                let updated = try await service.updatePost(
                    postID: editingPost.id,
                    input: UpdatePostInput(
                        content: trimmedText,
                        images: normalizedMediaURLs,
                        location: normalizedLocationTag
                    )
                )
                onPostUpdated?(updated)
            } else {
                let created = try await service.createPost(
                    input: CreatePostInput(
                        content: trimmedText,
                        images: normalizedMediaURLs,
                        location: normalizedLocationTag
                    )
                )
                onPostCreated?(created)
            }
            dismiss()
        } catch {
            toast = error.userFacingMessage
        }
    }

    @MainActor
    private func deletePost() async {
        guard let editingPost else { return }
        guard !isDeleting else { return }

        isDeleting = true
        defer { isDeleting = false }

        do {
            try await service.deletePost(postID: editingPost.id)
            onPostDeleted?(editingPost.id)
            dismiss()
        } catch {
            toast = error.userFacingMessage
        }
    }

    @MainActor
    private func uploadSelectedMedia(from items: [PhotosPickerItem]) async {
        guard !isUploadingMedia else { return }
        isUploadingMedia = true
        defer {
            isUploadingMedia = false
            selectedMediaItems = []
        }

        for item in items {
            if mediaEntries.count >= maxMediaCount {
                toast = L("最多添加 \(maxMediaCount) 个媒体", "You can add up to \(maxMediaCount) media items.")
                break
            }

            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { continue }
                let contentType = item.supportedContentTypes.first
                if let contentType, contentType.conforms(to: .movie) {
                    let ext = contentType.preferredFilenameExtension ?? "mp4"
                    let mime = contentType.preferredMIMEType ?? "video/mp4"
                    let upload = try await webService.uploadPostVideo(
                        videoData: data,
                        fileName: "post-video-\(UUID().uuidString).\(ext)",
                        mimeType: mime
                    )
                    mediaEntries.append(ComposeMediaEntry(url: upload.url))
                } else {
                    let upload = try await webService.uploadPostImage(
                        imageData: normalizedImageData(from: data),
                        fileName: "post-image-\(UUID().uuidString).jpg",
                        mimeType: "image/jpeg"
                    )
                    mediaEntries.append(ComposeMediaEntry(url: upload.url))
                }
            } catch {
                toast = L("媒体上传失败：\(error.userFacingMessage ?? "")", "Media upload failed: \(error.userFacingMessage ?? "")")
            }
        }
    }

    private func normalizedImageData(from rawData: Data) -> Data {
        if let image = UIImage(data: rawData),
           let jpeg = image.jpegData(compressionQuality: 0.9) {
            return jpeg
        }
        return rawData
    }

    @ViewBuilder
    private func composeMediaTile(_ entry: ComposeMediaEntry) -> some View {
        ZStack(alignment: .topTrailing) {
            let resolved = AppConfig.resolvedURLString(entry.url) ?? entry.url
            let isVideo = ComposeMediaEntry.detectIsVideo(from: resolved)
            let remoteURL = URL(string: resolved)

            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    ZStack {
                        if isVideo {
                            if let remoteURL {
                                ComposeVideoThumbnailView(url: remoteURL, contentMode: .fill)
                                    .overlay {
                                        LinearGradient(
                                            colors: [Color.black.opacity(0.2), Color.black.opacity(0.44)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    }
                                    .overlay {
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 26, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                            } else {
                                mediaPlaceholder
                            }
                        } else if let remoteURL {
                            AsyncImage(url: remoteURL) { phase in
                                switch phase {
                                case .empty:
                                    mediaPlaceholder
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                case .failure:
                                    mediaPlaceholder
                                @unknown default:
                                    mediaPlaceholder
                                }
                            }
                        } else {
                            mediaPlaceholder
                        }
                    }
                }
                .clipped()

            Button {
                mediaEntries.removeAll { $0.id == entry.id }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
                    .padding(5)
            }
            .buttonStyle(.plain)
        }
    }

    private var mediaPlaceholder: some View {
        ZStack {
            RaverTheme.card
            Image(systemName: "photo")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(RaverTheme.secondaryText)
        }
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(LL("定位标签"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                Spacer()
                if normalizedLocationTag != nil {
                    Button(L("清除", "Clear")) {
                        locationTag = ""
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
                }
            }

            Button {
                showLocationPicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(RaverTheme.secondaryText)
                    Text(normalizedLocationTag ?? L("添加定位标签", "Add Location Tag"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(normalizedLocationTag == nil ? RaverTheme.secondaryText : RaverTheme.primaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RaverTheme.secondaryText.opacity(0.8))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(RaverTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}

private struct ComposeMediaEntry: Identifiable, Equatable {
    let id: UUID
    let url: String

    init(id: UUID = UUID(), url: String) {
        self.id = id
        self.url = url
    }

    static func detectIsVideo(from value: String) -> Bool {
        let lower = value.lowercased()
        let extensions = [".mp4", ".mov", ".m4v", ".webm", ".mkv", ".avi", ".m3u8"]
        if extensions.contains(where: { lower.contains($0) }) {
            return true
        }
        return lower.contains("/video/") || lower.contains("video=")
    }
}

private struct ComposeMediaPreviewSelection: Identifiable {
    let id = UUID()
    let index: Int
}

private struct ComposeMediaDropDelegate: DropDelegate {
    let destinationItem: ComposeMediaEntry
    @Binding var items: [ComposeMediaEntry]
    @Binding var draggingItem: ComposeMediaEntry?

    func dropEntered(info: DropInfo) {
        guard let draggingItem, draggingItem != destinationItem else { return }
        guard let fromIndex = items.firstIndex(of: draggingItem),
              let toIndex = items.firstIndex(of: destinationItem) else { return }

        if items[toIndex] != draggingItem {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                items.move(
                    fromOffsets: IndexSet(integer: fromIndex),
                    toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
                )
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingItem = nil
        return true
    }
}

private struct ComposeMediaBrowserView: View {
    @Environment(\.dismiss) private var dismiss

    let entries: [ComposeMediaEntry]
    @State private var currentIndex: Int

    init(entries: [ComposeMediaEntry], initialIndex: Int) {
        self.entries = entries
        _currentIndex = State(initialValue: min(max(initialIndex, 0), max(0, entries.count - 1)))
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    let resolved = AppConfig.resolvedURLString(entry.url) ?? entry.url
                    let isVideo = ComposeMediaEntry.detectIsVideo(from: resolved)
                    let mediaURL = URL(string: resolved)

                    Group {
                        if isVideo, let mediaURL {
                            ComposeFullscreenVideoPlayer(url: mediaURL)
                        } else if let mediaURL {
                            ComposeZoomableAsyncImage(url: mediaURL)
                        } else {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.9))
                        }
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.black.opacity(0.45))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text("\(currentIndex + 1)/\(entries.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
        }
    }
}

private struct ComposeFullscreenVideoPlayer: View {
    let url: URL
    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let player {
                VideoPlayer(player: player)
                    .onAppear {
                        player.play()
                    }
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .onAppear {
            AppOrientationLock.shared.allowLandscape()
            if player == nil {
                player = AVPlayer(url: url)
            }
        }
        .onDisappear {
            player?.pause()
            player?.replaceCurrentItem(with: nil)
            player = nil
            AppOrientationLock.shared.lockPortrait(force: true)
        }
    }
}

private struct ComposeZoomableAsyncImage: View {
    let url: URL
    private let minimumScale: CGFloat = 1
    private let maximumScale: CGFloat = 4
    private let quickZoomScale: CGFloat = 2.5

    @State private var baseScale: CGFloat = 1
    @State private var gestureScale: CGFloat = 1
    @State private var currentOffset: CGSize = .zero
    @State private var accumulatedOffset: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView().tint(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .scaleEffect(displayScale)
                        .offset(currentOffset)
                        .contentShape(Rectangle())
                        .gesture(
                            SimultaneousGesture(
                                magnificationGesture(in: proxy.size),
                                dragGesture(in: proxy.size)
                            )
                        )
                        .simultaneousGesture(
                            TapGesture(count: 2).onEnded {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if displayScale > minimumScale + 0.01 {
                                        resetZoom()
                                    } else {
                                        baseScale = quickZoomScale
                                        gestureScale = 1
                                        currentOffset = .zero
                                        accumulatedOffset = .zero
                                    }
                                }
                            }
                        )
                case .failure:
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                @unknown default:
                    EmptyView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
        }
    }

    private var displayScale: CGFloat {
        clampedScale(baseScale * gestureScale)
    }

    private func magnificationGesture(in containerSize: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                gestureScale = value
            }
            .onEnded { value in
                baseScale = clampedScale(baseScale * value)
                gestureScale = 1
                if baseScale <= minimumScale + 0.01 {
                    resetZoom()
                } else {
                    currentOffset = clampedOffset(currentOffset, scale: baseScale, in: containerSize)
                    accumulatedOffset = currentOffset
                }
            }
    }

    private func dragGesture(in containerSize: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard displayScale > minimumScale + 0.01 else { return }
                let proposed = CGSize(
                    width: accumulatedOffset.width + value.translation.width,
                    height: accumulatedOffset.height + value.translation.height
                )
                currentOffset = clampedOffset(proposed, scale: displayScale, in: containerSize)
            }
            .onEnded { _ in
                accumulatedOffset = currentOffset
            }
    }

    private func clampedScale(_ value: CGFloat) -> CGFloat {
        min(max(value, minimumScale), maximumScale)
    }

    private func clampedOffset(_ value: CGSize, scale: CGFloat, in size: CGSize) -> CGSize {
        let horizontalLimit = max(0, (size.width * (scale - 1)) / 2)
        let verticalLimit = max(0, (size.height * (scale - 1)) / 2)
        return CGSize(
            width: min(max(value.width, -horizontalLimit), horizontalLimit),
            height: min(max(value.height, -verticalLimit), verticalLimit)
        )
    }

    private func resetZoom() {
        baseScale = minimumScale
        gestureScale = 1
        currentOffset = .zero
        accumulatedOffset = .zero
    }
}

private struct ComposeMediaDropOutsideDelegate: DropDelegate {
    @Binding var draggingItem: ComposeMediaEntry?

    func performDrop(info: DropInfo) -> Bool {
        draggingItem = nil
        return true
    }
}

private enum ComposeVideoThumbnailGenerator {
    static func makeThumbnail(from url: URL, maxLength: CGFloat = 1200) async -> UIImage? {
        await Task.detached(priority: .utility) {
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: maxLength, height: maxLength)

            let candidateTimes = [
                CMTime(seconds: 0.15, preferredTimescale: 600),
                CMTime(seconds: 0.5, preferredTimescale: 600),
                CMTime(seconds: 1.0, preferredTimescale: 600),
                CMTime(seconds: 2.0, preferredTimescale: 600)
            ]

            for time in candidateTimes {
                if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                    return UIImage(cgImage: cgImage)
                }
            }
            return nil
        }.value
    }
}

private final class ComposeVideoThumbnailCache {
    static let shared = NSCache<NSString, UIImage>()
}

private struct ComposeVideoThumbnailView: View {
    let url: URL
    let contentMode: ContentMode

    @State private var image: UIImage?
    @State private var didFail = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                ZStack {
                    LinearGradient(
                        colors: [Color.black.opacity(0.92), Color.black.opacity(0.58)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: didFail ? "video.slash.fill" : "video.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.85))
                }
            }
        }
        .task(id: url.absoluteString) {
            await loadThumbnailIfNeeded()
        }
    }

    @MainActor
    private func loadThumbnailIfNeeded() async {
        if image != nil || didFail { return }
        let cacheKey = url.absoluteString as NSString
        if let cached = ComposeVideoThumbnailCache.shared.object(forKey: cacheKey) {
            image = cached
            return
        }
        guard let generated = await ComposeVideoThumbnailGenerator.makeThumbnail(from: url) else {
            didFail = true
            return
        }
        ComposeVideoThumbnailCache.shared.setObject(generated, forKey: cacheKey)
        image = generated
    }
}

private struct AutoGrowingTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var calculatedHeight: CGFloat
    let minHeight: CGFloat
    let maxHeight: CGFloat

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.textColor = UIColor.label
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.isScrollEnabled = false
        textView.textContainerInset = UIEdgeInsets(top: 6, left: 2, bottom: 6, right: 2)
        textView.textContainer.lineFragmentPadding = 0
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        DispatchQueue.main.async {
            recalculateHeight(for: uiView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    private func recalculateHeight(for textView: UITextView) {
        let fittingSize = CGSize(width: textView.bounds.width, height: .greatestFiniteMagnitude)
        let estimated = textView.sizeThatFits(fittingSize).height
        let clamped = min(max(estimated, minHeight), maxHeight)
        if abs(calculatedHeight - clamped) > 0.5 {
            calculatedHeight = clamped
        }
        textView.isScrollEnabled = estimated > maxHeight
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: AutoGrowingTextView

        init(parent: AutoGrowingTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            parent.recalculateHeight(for: textView)
        }
    }
}

private struct PostLocationCandidate: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D?

    var displayLabel: String {
        subtitle.isEmpty ? title : "\(title) · \(subtitle)"
    }

    static func == (lhs: PostLocationCandidate, rhs: PostLocationCandidate) -> Bool {
        lhs.id == rhs.id
    }
}

private final class PostPickerCurrentLocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var coordinate: CLLocationCoordinate2D?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus

    private let manager = CLLocationManager()

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestCurrentLocation() {
        authorizationStatus = manager.authorizationStatus
        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        coordinate = locations.last?.coordinate
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Post picker location error: \(error.userFacingMessage ?? "")")
    }
}

private final class PostLocationSearchModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published private(set) var queryCandidates: [PostLocationCandidate] = []
    @Published private(set) var nearbyCandidates: [PostLocationCandidate] = []
    @Published private(set) var isLoadingNearby = false
    private let completer = MKLocalSearchCompleter()
    private var query: String = ""

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func updateQuery(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        query = trimmed
        if trimmed.isEmpty {
            queryCandidates = []
            completer.queryFragment = ""
            return
        }
        completer.queryFragment = trimmed
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        guard !query.isEmpty else {
            queryCandidates = []
            return
        }
        queryCandidates = completer.results.map { item in
            PostLocationCandidate(
                id: "\(item.title)|\(item.subtitle)",
                title: item.title,
                subtitle: item.subtitle,
                coordinate: nil
            )
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Post location completer error: \(error.userFacingMessage ?? "")")
        queryCandidates = []
    }

    @MainActor
    func searchNearby(around coordinate: CLLocationCoordinate2D) async {
        isLoadingNearby = true
        defer { isLoadingNearby = false }

        let request = MKLocalSearch.Request()
        request.resultTypes = [.pointOfInterest, .address]
        request.region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )

        do {
            let response = try await MKLocalSearch(request: request).start()
            var dedup = Set<String>()
            var result: [PostLocationCandidate] = []
            for item in response.mapItems {
                let coordinate = item.placemark.coordinate
                let title = item.name?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    ?? ""
                let fallbackTitle = item.placemark.thoroughfare?.trimmingCharacters(in: .whitespacesAndNewlines)
                    ?? item.placemark.locality?.trimmingCharacters(in: .whitespacesAndNewlines)
                    ?? ""
                let resolvedTitle = title.isEmpty ? fallbackTitle : title
                let subtitleParts = [
                    item.placemark.locality,
                    item.placemark.subLocality,
                    item.placemark.thoroughfare
                ]
                    .compactMap { value in
                        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        return trimmed.isEmpty ? nil : trimmed
                    }
                let subtitle = subtitleParts.joined(separator: " ")
                let key = "\(resolvedTitle)|\(subtitle)|\(String(format: "%.5f", coordinate.latitude)),\(String(format: "%.5f", coordinate.longitude))"
                guard !resolvedTitle.isEmpty || !subtitle.isEmpty, !dedup.contains(key) else { continue }
                dedup.insert(key)
                result.append(
                    PostLocationCandidate(
                        id: key,
                        title: resolvedTitle.isEmpty ? L("附近地点", "Nearby Place") : resolvedTitle,
                        subtitle: subtitle,
                        coordinate: coordinate
                    )
                )
                if result.count >= 20 { break }
            }
            nearbyCandidates = result
        } catch {
            nearbyCandidates = []
        }
    }
}

private struct PostLocationPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var searchModel = PostLocationSearchModel()
    @StateObject private var locationProvider = PostPickerCurrentLocationProvider()

    private enum CandidateListMode {
        case nearby
        case query
    }

    let initialQuery: String
    let onSelect: (String) -> Void

    @State private var query: String
    @State private var mapPosition: MapCameraPosition
    @State private var selectedCandidate: PostLocationCandidate?
    @State private var pinCoordinate: CLLocationCoordinate2D
    @State private var isResolving = false
    @State private var errorMessage: String?
    @State private var listMode: CandidateListMode = .nearby
    @State private var nearbySearchTask: Task<Void, Never>?
    @FocusState private var isSearchFieldFocused: Bool
    @State private var hasAppliedInitialDeviceLocation = false

    init(initialQuery: String, onSelect: @escaping (String) -> Void) {
        self.initialQuery = initialQuery
        self.onSelect = onSelect
        _query = State(initialValue: initialQuery)
        let fallbackCenter = CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737)
        _pinCoordinate = State(initialValue: fallbackCenter)
        _mapPosition = State(
            initialValue: .region(
                MKCoordinateRegion(
                    center: fallbackCenter,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
            )
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                mapArea
                Divider().overlay(Color.white.opacity(0.08))
                locationListArea
            }
            .background(RaverTheme.background)
            .navigationTitle(LL("选择定位"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("取消", "Cancel")) { dismiss() }
                        .font(.subheadline.weight(.semibold))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("确认", "Confirm")) {
                        Task { await confirmSelection() }
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }
            .safeAreaInset(edge: .top) {
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(RaverTheme.secondaryText)
                        TextField(LL("搜索地点"), text: $query)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .focused($isSearchFieldFocused)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(RaverTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                    .padding(.bottom, 6)
                }
                .background(.ultraThinMaterial)
            }
            .onAppear {
                searchModel.updateQuery(query)
                scheduleNearbySearch(for: pinCoordinate)
                locationProvider.requestCurrentLocation()
            }
            .onReceive(locationProvider.$coordinate) { coordinate in
                guard let coordinate else { return }
                guard !hasAppliedInitialDeviceLocation else { return }
                hasAppliedInitialDeviceLocation = true
                pinCoordinate = coordinate
                mapPosition = .region(
                    MKCoordinateRegion(
                        center: coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
                    )
                )
                listMode = .nearby
                scheduleNearbySearch(for: coordinate)
            }
            .onChange(of: query) { _, newValue in
                searchModel.updateQuery(newValue)
                if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    listMode = .query
                } else if !isSearchFieldFocused {
                    listMode = .nearby
                }
            }
            .onChange(of: isSearchFieldFocused) { _, isFocused in
                if isFocused {
                    listMode = .query
                } else if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    listMode = .nearby
                }
            }
            .onDisappear {
                nearbySearchTask?.cancel()
            }
            .alert(L("提示", "Notice"), isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button(L("确定", "OK"), role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var mapArea: some View {
        ZStack {
            Map(position: $mapPosition, interactionModes: .all) {}
            .mapStyle(.standard(elevation: .realistic))
            .frame(maxWidth: .infinity, minHeight: 280, maxHeight: 360)
            .onMapCameraChange(frequency: .onEnd) { context in
                pinCoordinate = context.region.center
                listMode = .nearby
                scheduleNearbySearch(for: context.region.center)
            }

            VStack(spacing: 0) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(RaverTheme.accent)
                    .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 4)
                    .offset(y: -17)
                Circle()
                    .fill(RaverTheme.accent.opacity(0.9))
                    .frame(width: 6, height: 6)
                    .offset(y: -17)
            }
            .allowsHitTesting(false)

            if isResolving {
                ProgressView()
                    .padding(10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        centerOnCurrentLocation(forceRequest: true)
                    } label: {
                        Image(systemName: "location.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 10)
                    .padding(.trailing, 12)
                }
                Spacer()
            }
        }
    }

    private var locationListArea: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: listMode == .query ? "magnifyingglass" : "scope")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RaverTheme.secondaryText)
                    Text(listMode == .query ? L("搜索候选地点", "Search Candidates") : L("附近推荐地点", "Nearby Recommendations"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RaverTheme.secondaryText)
                    Spacer(minLength: 0)
                    if listMode == .nearby, searchModel.isLoadingNearby {
                        ProgressView()
                            .controlSize(.mini)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 8)

                if displayedCandidates.isEmpty {
                    Text(emptyHintText)
                        .font(.subheadline)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                        .padding(.bottom, 22)
                } else {
                    ForEach(displayedCandidates) { candidate in
                        Button {
                            Task { await chooseCandidate(candidate) }
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(RaverTheme.accent)
                                    .padding(.top, 1)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(candidate.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(RaverTheme.primaryText)
                                        .lineLimit(1)
                                    if !candidate.subtitle.isEmpty {
                                        Text(candidate.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(RaverTheme.secondaryText)
                                            .lineLimit(2)
                                    }
                                }
                                Spacer()
                                if selectedCandidate?.id == candidate.id {
                                    Image(systemName: "scope")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(RaverTheme.accent)
                                        .padding(.top, 2)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider().overlay(Color.white.opacity(0.06))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @MainActor
    private func chooseCandidate(_ candidate: PostLocationCandidate) async {
        guard !isResolving else { return }
        selectedCandidate = candidate

        if let coordinate = candidate.coordinate {
            pinCoordinate = coordinate
            mapPosition = .region(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
                )
            )
            return
        }

        isResolving = true
        defer { isResolving = false }

        do {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = candidate.displayLabel
            request.resultTypes = [.address, .pointOfInterest]
            let response = try await MKLocalSearch(request: request).start()
            if let coordinate = response.mapItems.first?.placemark.coordinate {
                pinCoordinate = coordinate
                mapPosition = .region(
                    MKCoordinateRegion(
                        center: coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
                    )
                )
            }
        } catch {
            errorMessage = L("地点解析失败，请重试", "Failed to resolve place. Please try again.")
        }
    }

    @MainActor
    private func confirmSelection() async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        if let reverseLabel = await reverseGeocodeLabel(for: pinCoordinate),
           !reverseLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            onSelect(reverseLabel)
            dismiss()
            return
        }

        if let selectedCandidate {
            onSelect(selectedCandidate.displayLabel)
            dismiss()
            return
        }

        if !trimmedQuery.isEmpty {
            onSelect(trimmedQuery)
            dismiss()
            return
        }

        errorMessage = L("请先搜索地点，或拖动地图后确认", "Please search for a place, or drag the map pin and confirm.")
    }

    private var displayedCandidates: [PostLocationCandidate] {
        switch listMode {
        case .query:
            return searchModel.queryCandidates
        case .nearby:
            return searchModel.nearbyCandidates
        }
    }

    private var emptyHintText: String {
        switch listMode {
        case .query:
            return query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? L("输入关键词搜索地点", "Enter keywords to search places")
                : L("未找到匹配地点", "No matching places found")
        case .nearby:
            return L("拖动地图后，将在这里展示 pin 附近地点", "After dragging the map, nearby places around the pin will appear here.")
        }
    }

    private func scheduleNearbySearch(for coordinate: CLLocationCoordinate2D) {
        nearbySearchTask?.cancel()
        nearbySearchTask = Task {
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }
            await searchModel.searchNearby(around: coordinate)
        }
    }

    private func centerOnCurrentLocation(forceRequest: Bool) {
        if let coordinate = locationProvider.coordinate {
            pinCoordinate = coordinate
            mapPosition = .region(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
                )
            )
            listMode = .nearby
            scheduleNearbySearch(for: coordinate)
            return
        }

        if forceRequest {
            locationProvider.requestCurrentLocation()
        }

        switch locationProvider.authorizationStatus {
        case .denied, .restricted:
            errorMessage = L("定位权限未开启，请在系统设置中允许定位后重试", "Location permission is disabled. Please enable it in Settings and try again.")
        default:
            errorMessage = L("正在获取当前位置，请稍后再试", "Getting current location. Please try again shortly.")
        }
    }

    private func reverseGeocodeLabel(for coordinate: CLLocationCoordinate2D) async -> String? {
        do {
            let placemark = try await reverseGeocode(coordinate: coordinate)
            if let name = placemark?.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
                return name
            }
            let components = [
                placemark?.country,
                placemark?.administrativeArea,
                placemark?.locality,
                placemark?.subLocality,
                placemark?.thoroughfare,
                placemark?.subThoroughfare
            ]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            let merged = components.joined(separator: " ")
            return merged.isEmpty ? nil : merged
        } catch {
            return nil
        }
    }

    private func reverseGeocode(coordinate: CLLocationCoordinate2D) async throws -> CLPlacemark? {
        try await withCheckedThrowingContinuation { continuation in
            CLGeocoder().reverseGeocodeLocation(
                CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
                preferredLocale: Locale(identifier: "zh_CN")
            ) { placemarks, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: placemarks?.first)
            }
        }
    }
}
