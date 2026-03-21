import AVFoundation
import AVKit
import SwiftUI
import UIKit

struct PostCardView: View {
    let post: Post
    let currentUserId: String?
    let showsFollowButton: Bool
    let onLikeTap: () -> Void
    let onRepostTap: (() -> Void)?
    let onFollowTap: (() -> Void)?
    let onMessageTap: (() -> Void)?
    let onAuthorTap: (() -> Void)?
    let onSquadTap: (() -> Void)?

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    Group {
                        if let onAuthorTap {
                            Button(action: onAuthorTap) {
                                authorMeta
                            }
                            .buttonStyle(.plain)
                        } else {
                            authorMeta
                        }
                    }

                    Spacer()

                    if showsFollowButton, post.author.id != currentUserId, let onFollowTap {
                        Button(post.author.isFollowing ? "已关注" : "关注", action: onFollowTap)
                            .font(.caption.bold())
                            .foregroundStyle(post.author.isFollowing ? RaverTheme.secondaryText : Color.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(post.author.isFollowing ? RaverTheme.card : RaverTheme.accent)
                            .clipShape(Capsule())
                    }
                }

                Text(post.content)
                    .foregroundStyle(RaverTheme.primaryText)
                    .font(.body)

                if !post.images.isEmpty {
                    PostMediaGridView(mediaURLs: post.images)
                }

                HStack(spacing: 18) {
                    Button(action: onLikeTap) {
                        Label("\(post.likeCount)", systemImage: post.isLiked ? "heart.fill" : "heart")
                    }
                    .foregroundStyle(post.isLiked ? Color.pink : RaverTheme.secondaryText)

                    if let onRepostTap {
                        Button(action: onRepostTap) {
                            Label("\(post.repostCount)", systemImage: post.isReposted ? "arrow.2.squarepath.circle.fill" : "arrow.2.squarepath")
                        }
                        .foregroundStyle(post.isReposted ? RaverTheme.accent : RaverTheme.secondaryText)
                    }

                    Label("\(post.commentCount)", systemImage: "text.bubble")
                        .foregroundStyle(RaverTheme.secondaryText)

                    if post.author.id != currentUserId, let onMessageTap {
                        Button(action: onMessageTap) {
                            Label("私信", systemImage: "paperplane")
                        }
                        .foregroundStyle(RaverTheme.secondaryText)
                    }

                    if post.squad != nil, let onSquadTap {
                        Button(action: onSquadTap) {
                            Label("进小队", systemImage: "person.3")
                        }
                        .foregroundStyle(RaverTheme.secondaryText)
                    }

                    Spacer()
                }
                .font(.subheadline)

                if let squad = post.squad {
                    HStack(spacing: 6) {
                        Image(systemName: "person.3.fill")
                            .font(.caption)
                        Text(squad.name)
                            .font(.caption)
                    }
                    .foregroundStyle(RaverTheme.secondaryText)
                }
            }
        }
    }

    private var authorMeta: some View {
        HStack(alignment: .center, spacing: 10) {
            // 头像
            authorAvatar

            VStack(alignment: .leading, spacing: 2) {
                Text(post.author.displayName)
                    .font(.subheadline.bold())
                Text("@\(post.author.username) · \(post.createdAt.feedTimeText)")
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
            }
        }
    }

    @ViewBuilder
    private var authorAvatar: some View {
        if let resolved = AppConfig.resolvedURLString(post.author.avatarURL),
           let remoteURL = URL(string: resolved),
           resolved.hasPrefix("http://") || resolved.hasPrefix("https://") {
            AsyncImage(url: remoteURL) { phase in
                switch phase {
                case .empty:
                    Circle().fill(RaverTheme.card)
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    authorAvatarFallback
                @unknown default:
                    authorAvatarFallback
                }
            }
            .frame(width: 34, height: 34)
            .clipShape(Circle())
        } else {
            authorAvatarFallback
        }
    }

    private var authorAvatarFallback: some View {
        Image(
            AppConfig.resolvedUserAvatarAssetName(
                userID: post.author.id,
                username: post.author.username,
                avatarURL: post.author.avatarURL
            )
        )
        .resizable()
        .scaledToFill()
        .frame(width: 34, height: 34)
        .background(RaverTheme.card)
        .clipShape(Circle())
    }
}

struct PostMediaGridView: View {
    let mediaURLs: [String]
    var allowsFullscreen: Bool = true

    @State private var selectedMedia: MediaSelection?

    private var items: [PostMediaItem] {
        mediaURLs
            .enumerated()
            .compactMap { offset, raw in
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                return PostMediaItem(rawURL: trimmed, index: offset)
            }
    }

    var body: some View {
        Group {
            if items.count == 1, let first = items.first {
                mediaTapWrapper(index: 0) {
                    singleMediaView(first)
                }
            } else if !items.isEmpty {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3),
                    spacing: 6
                ) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        mediaTapWrapper(index: index) {
                            mediaThumbnail(item)
                        }
                    }
                }
            }
        }
        .fullScreenCover(item: $selectedMedia) { selection in
            PostMediaBrowserView(items: items, initialIndex: selection.id)
        }
    }

    @ViewBuilder
    private func mediaTapWrapper<Content: View>(index: Int, @ViewBuilder content: () -> Content) -> some View {
        if allowsFullscreen {
            Button {
                selectedMedia = MediaSelection(id: index)
            } label: {
                content()
            }
            .buttonStyle(.plain)
        } else {
            content()
        }
    }

    private func singleMediaView(_ item: PostMediaItem) -> some View {
        ZStack {
            if item.isVideo {
                if let url = item.url {
                    PostVideoThumbnailView(url: url, contentMode: .fill)
                        .overlay {
                            LinearGradient(
                                colors: [Color.black.opacity(0.18), Color.black.opacity(0.42)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                        .overlay {
                            VStack(spacing: 8) {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 42, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text("视频")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.white.opacity(0.9))
                            }
                        }
                        .frame(height: 230)
                } else {
                    mediaPlaceholder
                        .frame(height: 230)
                }
            } else {
                AsyncImage(url: item.url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 320)
                            .background(RaverTheme.card)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: 320)
                            .background(Color.black.opacity(0.06))
                    case .failure:
                        mediaPlaceholder
                            .frame(height: 200)
                    @unknown default:
                        mediaPlaceholder
                            .frame(height: 200)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func mediaThumbnail(_ item: PostMediaItem) -> some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                ZStack {
                    if item.isVideo {
                        if let url = item.url {
                            PostVideoThumbnailView(url: url, contentMode: .fill)
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
                    } else {
                        AsyncImage(url: item.url) { phase in
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
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var mediaPlaceholder: some View {
        ZStack {
            RaverTheme.card
            Image(systemName: "photo")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(RaverTheme.secondaryText)
        }
    }
}

private struct PostMediaBrowserView: View {
    @Environment(\.dismiss) private var dismiss

    let items: [PostMediaItem]
    @State private var currentIndex: Int

    init(items: [PostMediaItem], initialIndex: Int) {
        self.items = items
        _currentIndex = State(initialValue: min(max(initialIndex, 0), max(0, items.count - 1)))
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    Group {
                        if item.isVideo, let url = item.url {
                            PostMediaVideoPlayer(url: url)
                        } else if let url = item.url {
                            ZoomableAsyncImage(url: url)
                        } else {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.85))
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
                        .background(Color.black.opacity(0.4))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text("\(currentIndex + 1)/\(items.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
        }
    }
}

private struct ZoomableAsyncImage: View {
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
                    let isZoomed = displayScale > minimumScale + 0.01
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .scaleEffect(displayScale)
                        .offset(currentOffset)
                        .contentShape(Rectangle())
                        .gesture(
                            magnificationGesture(in: proxy.size)
                        )
                        .gesture(
                            isZoomed
                            ? dragGesture(in: proxy.size)
                            : nil
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

private struct PostMediaVideoPlayer: View {
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

private struct PostMediaItem: Identifiable, Hashable {
    let id: String
    let rawURL: String
    let resolvedURL: String
    let isVideo: Bool

    init(rawURL: String, index: Int) {
        let resolved = AppConfig.resolvedURLString(rawURL) ?? rawURL
        self.id = "\(index)-\(resolved)"
        self.rawURL = rawURL
        self.resolvedURL = resolved
        self.isVideo = Self.detectIsVideo(from: resolved)
    }

    var url: URL? {
        URL(string: resolvedURL)
    }

    private static func detectIsVideo(from value: String) -> Bool {
        let lower = value.lowercased()
        let extensions = [".mp4", ".mov", ".m4v", ".webm", ".mkv", ".avi", ".m3u8"]
        if extensions.contains(where: { lower.contains($0) }) {
            return true
        }
        return lower.contains("/video/") || lower.contains("video=")
    }
}

private struct MediaSelection: Identifiable {
    let id: Int
}

private enum PostVideoThumbnailGenerator {
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

private final class PostVideoThumbnailCache {
    static let shared = NSCache<NSString, UIImage>()
}

private struct PostVideoThumbnailView: View {
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
        if let cached = PostVideoThumbnailCache.shared.object(forKey: cacheKey) {
            image = cached
            return
        }
        guard let generated = await PostVideoThumbnailGenerator.makeThumbnail(from: url) else {
            didFail = true
            return
        }
        PostVideoThumbnailCache.shared.setObject(generated, forKey: cacheKey)
        image = generated
    }
}
