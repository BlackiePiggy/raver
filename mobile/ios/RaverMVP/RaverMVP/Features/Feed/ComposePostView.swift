import AVFoundation
import AVKit
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
    @EnvironmentObject private var appState: AppState
    private let webService: WebFeatureService = AppEnvironment.makeWebService()
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

    init(
        mode: ComposePostMode = .create,
        onPostCreated: ((Post) -> Void)? = nil,
        onPostUpdated: ((Post) -> Void)? = nil,
        onPostDeleted: ((String) -> Void)? = nil
    ) {
        self.mode = mode
        self.onPostCreated = onPostCreated
        self.onPostUpdated = onPostUpdated
        self.onPostDeleted = onPostDeleted

        switch mode {
        case .create:
            _text = State(initialValue: "")
            _mediaEntries = State(initialValue: [])
        case .edit(let post):
            _text = State(initialValue: post.content)
            _mediaEntries = State(
                initialValue: post.images
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .map { ComposeMediaEntry(url: $0) }
            )
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
        isEditMode ? "重新发布" : "发布动态"
    }

    private var pageTitle: String {
        isEditMode ? "编辑动态" : "发布动态"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                HStack {
                    Text("正文")
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
                        Text("分享这一刻...")
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
                    Text("媒体")
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
                                        Text("添加")
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
                            Text("删除动态")
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
                    Button("返回") {
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
            .alert("提示", isPresented: Binding(
                get: { toast != nil },
                set: { if !$0 { toast = nil } }
            )) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(toast ?? "")
            }
            .confirmationDialog(
                "确认删除这条动态吗？",
                isPresented: $isDeleteConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button("删除动态", role: .destructive) {
                    Task { await deletePost() }
                }
                Button("取消", role: .cancel) {}
            }
            .fullScreenCover(item: $selectedPreview) { preview in
                ComposeMediaBrowserView(
                    entries: mediaEntries,
                    initialIndex: preview.index
                )
            }
        }
    }

    @MainActor
    private func submitPost() async {
        isSending = true
        defer { isSending = false }

        guard !trimmedText.isEmpty || !normalizedMediaURLs.isEmpty else {
            toast = "请填写正文或添加媒体"
            return
        }

        do {
            if let editingPost {
                let updated = try await appState.service.updatePost(
                    postID: editingPost.id,
                    input: UpdatePostInput(content: trimmedText, images: normalizedMediaURLs)
                )
                onPostUpdated?(updated)
            } else {
                let created = try await appState.service.createPost(
                    input: CreatePostInput(content: trimmedText, images: normalizedMediaURLs)
                )
                onPostCreated?(created)
            }
            dismiss()
        } catch {
            toast = error.localizedDescription
        }
    }

    @MainActor
    private func deletePost() async {
        guard let editingPost else { return }
        guard !isDeleting else { return }

        isDeleting = true
        defer { isDeleting = false }

        do {
            try await appState.service.deletePost(postID: editingPost.id)
            onPostDeleted?(editingPost.id)
            dismiss()
        } catch {
            toast = error.localizedDescription
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
                toast = "最多添加 \(maxMediaCount) 个媒体"
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
                toast = "媒体上传失败：\(error.localizedDescription)"
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
            if player == nil {
                player = AVPlayer(url: url)
            }
        }
        .onDisappear {
            player?.pause()
            player?.replaceCurrentItem(with: nil)
            player = nil
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
