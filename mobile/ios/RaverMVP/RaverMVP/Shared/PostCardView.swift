import AVFoundation
import AVKit
import MapKit
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
    let onEditTap: (() -> Void)?
    @State private var isShowingLocationMap = false

    init(
        post: Post,
        currentUserId: String?,
        showsFollowButton: Bool,
        onLikeTap: @escaping () -> Void,
        onRepostTap: (() -> Void)?,
        onFollowTap: (() -> Void)?,
        onMessageTap: (() -> Void)?,
        onAuthorTap: (() -> Void)?,
        onSquadTap: (() -> Void)?,
        onEditTap: (() -> Void)? = nil
    ) {
        self.post = post
        self.currentUserId = currentUserId
        self.showsFollowButton = showsFollowButton
        self.onLikeTap = onLikeTap
        self.onRepostTap = onRepostTap
        self.onFollowTap = onFollowTap
        self.onMessageTap = onMessageTap
        self.onAuthorTap = onAuthorTap
        self.onSquadTap = onSquadTap
        self.onEditTap = onEditTap
    }

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

                    if post.author.id == currentUserId, let onEditTap {
                        Button(action: onEditTap) {
                            Image(systemName: "square.and.pencil")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(RaverTheme.secondaryText)
                                .frame(width: 30, height: 30)
                                .background(
                                    Circle()
                                        .fill(RaverTheme.card.opacity(0.9))
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("编辑动态")
                    } else if showsFollowButton, let onFollowTap {
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

                if let locationText = normalizedLocationText {
                    Button {
                        isShowingLocationMap = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.caption.weight(.semibold))
                            Text(locationText)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .foregroundStyle(Color.white.opacity(0.94))
                        .frame(maxWidth: locationLabelMaxWidth, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.36))
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.14), lineWidth: 0.8)
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
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
        .fullScreenCover(isPresented: $isShowingLocationMap) {
            if let locationText = normalizedLocationText {
                PostLocationMapView(locationText: locationText)
            }
        }
    }

    private var normalizedLocationText: String? {
        let trimmed = post.location?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private var locationLabelMaxWidth: CGFloat {
        max(150, min(UIScreen.main.bounds.width * 0.48, 210))
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

private struct PostLocationMapView: View {
    @Environment(\.dismiss) private var dismiss

    let locationText: String

    @State private var mapPosition: MapCameraPosition
    @State private var resolvedCoordinate: CLLocationCoordinate2D?
    @State private var isResolving = false
    @State private var resolveFailed = false

    init(locationText: String) {
        self.locationText = locationText
        let fallback = CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737)
        _mapPosition = State(
            initialValue: .region(
                MKCoordinateRegion(
                    center: fallback,
                    span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
                )
            )
        )
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $mapPosition, interactionModes: .all) {
                    if let resolvedCoordinate {
                        Marker(locationText, coordinate: resolvedCoordinate)
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .ignoresSafeArea(edges: .bottom)

                VStack(alignment: .leading, spacing: 8) {
                    Text("定位信息")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RaverTheme.secondaryText)
                    Text(locationText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                        .lineLimit(2)

                    if isResolving {
                        ProgressView("正在解析位置…")
                            .font(.caption)
                            .tint(RaverTheme.secondaryText)
                    } else if resolveFailed {
                        Text("未能精确定位，仍可在地图中拖动查看区域。")
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }

                    Button {
                        openInSystemMaps()
                    } label: {
                        Label("系统地图打开", systemImage: "arrow.up.right.square")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(RaverTheme.accent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("返回") { dismiss() }
                        .font(.subheadline.weight(.semibold))
                }
            }
            .navigationTitle("位置地图")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await resolveLocation()
            }
        }
    }

    @MainActor
    private func resolveLocation() async {
        guard !isResolving else { return }
        isResolving = true
        defer { isResolving = false }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = locationText
        request.resultTypes = [.address, .pointOfInterest]
        do {
            let response = try await MKLocalSearch(request: request).start()
            if let coordinate = response.mapItems.first?.placemark.coordinate {
                resolvedCoordinate = coordinate
                resolveFailed = false
                mapPosition = .region(
                    MKCoordinateRegion(
                        center: coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
                    )
                )
                return
            }
            resolveFailed = true
        } catch {
            resolveFailed = true
        }
    }

    private func openInSystemMaps() {
        if let resolvedCoordinate {
            let placemark = MKPlacemark(coordinate: resolvedCoordinate)
            let item = MKMapItem(placemark: placemark)
            item.name = locationText
            item.openInMaps()
            return
        }

        let encoded = locationText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? locationText
        if let url = URL(string: "http://maps.apple.com/?q=\(encoded)") {
            UIApplication.shared.open(url)
        }
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
                                PostVideoDurationLabel(url: url, font: .subheadline)
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
        //.contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                                    VStack(spacing: 6) {
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 26, weight: .bold))
                                            .foregroundStyle(.white)
                                        PostVideoDurationLabel(url: url, font: .caption2)
                                    }
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
                            ZoomableAsyncImage(
                                url: url,
                                isActive: currentIndex == index,
                                canGoPrevious: index > 0,
                                canGoNext: index < (items.count - 1),
                                onRequestPrevious: {
                                    guard currentIndex > 0 else { return }
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        currentIndex -= 1
                                    }
                                },
                                onRequestNext: {
                                    guard currentIndex < (items.count - 1) else { return }
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        currentIndex += 1
                                    }
                                }
                            )
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
    let isActive: Bool
    let canGoPrevious: Bool
    let canGoNext: Bool
    let onRequestPrevious: () -> Void
    let onRequestNext: () -> Void
    private let minimumScale: CGFloat = 1
    private let maximumScale: CGFloat = 4
    private let quickZoomScale: CGFloat = 2.2
    private let pageTurnThreshold: CGFloat = 24
    private let panEdgeEpsilon: CGFloat = 1.0

    @State private var baseScale: CGFloat = 1
    @State private var gestureScale: CGFloat = 1
    @State private var currentOffset: CGSize = .zero
    @State private var accumulatedOffset: CGSize = .zero
    @State private var didTriggerPageTurnInCurrentDrag = false

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
                        .simultaneousGesture(
                            magnificationGesture(in: proxy.size)
                        )
                        .highPriorityGesture(
                            dragGesture(in: proxy.size),
                            including: isZoomed ? .all : .subviews
                        )
                        .simultaneousGesture(
                            TapGesture(count: 2).onEnded {
                                withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.86)) {
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
            .onAppear {
                if isActive {
                    resetZoom()
                }
            }
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    resetZoom()
                }
            }
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

                if tryHandlePageTurnIfNeeded(value: value, containerSize: containerSize) {
                    return
                }

                let proposed = CGSize(
                    width: accumulatedOffset.width + value.translation.width,
                    height: accumulatedOffset.height + value.translation.height
                )
                currentOffset = clampedOffset(proposed, scale: displayScale, in: containerSize)
            }
            .onEnded { _ in
                accumulatedOffset = currentOffset
                didTriggerPageTurnInCurrentDrag = false
            }
    }

    private func tryHandlePageTurnIfNeeded(value: DragGesture.Value, containerSize: CGSize) -> Bool {
        guard !didTriggerPageTurnInCurrentDrag else { return true }

        let horizontalLimit = horizontalPanLimit(scale: displayScale, in: containerSize)
        guard horizontalLimit > 0 else { return false }

        let atLeftEdge = currentOffset.width <= (-horizontalLimit + panEdgeEpsilon)
        let atRightEdge = currentOffset.width >= (horizontalLimit - panEdgeEpsilon)
        let translationX = value.translation.width

        if atLeftEdge && translationX <= -pageTurnThreshold && canGoNext {
            didTriggerPageTurnInCurrentDrag = true
            resetZoom()
            onRequestNext()
            return true
        }

        if atRightEdge && translationX >= pageTurnThreshold && canGoPrevious {
            didTriggerPageTurnInCurrentDrag = true
            resetZoom()
            onRequestPrevious()
            return true
        }

        return false
    }

    private func clampedScale(_ value: CGFloat) -> CGFloat {
        min(max(value, minimumScale), maximumScale)
    }

    private func horizontalPanLimit(scale: CGFloat, in size: CGSize) -> CGFloat {
        max(0, (size.width * (scale - 1)) / 2)
    }

    private func clampedOffset(_ value: CGSize, scale: CGFloat, in size: CGSize) -> CGSize {
        let horizontalLimit = horizontalPanLimit(scale: scale, in: size)
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
    let url: URL?

    init(rawURL: String, index: Int) {
        let resolved = AppConfig.resolvedURLString(rawURL) ?? rawURL
        self.id = "\(index)-\(resolved)"
        self.rawURL = rawURL
        self.resolvedURL = resolved
        self.isVideo = Self.detectIsVideo(from: resolved)
        self.url = Self.makeURL(from: resolved)

        if self.isVideo {
            if let parsedURL = self.url {
                PostVideoDebugLogger.log("media item resolved video url: \(parsedURL.absoluteString)")
            } else {
                PostVideoDebugLogger.log("media item failed to parse video url. raw=\(rawURL), resolved=\(resolved)")
            }
        }
    }

    private static func detectIsVideo(from value: String) -> Bool {
        let lower = value.lowercased()
        let extensions = [".mp4", ".mov", ".m4v", ".webm", ".mkv", ".avi", ".m3u8"]
        if extensions.contains(where: { lower.contains($0) }) {
            return true
        }
        return lower.contains("/video/") || lower.contains("video=")
    }

    private static func makeURL(from raw: String) -> URL? {
        if let direct = URL(string: raw) {
            return direct
        }
        if let encoded = raw.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed),
           let encodedURL = URL(string: encoded) {
            PostVideoDebugLogger.log("url encoded fallback success. raw=\(raw), encoded=\(encodedURL.absoluteString)")
            return encodedURL
        }
        return nil
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

private final class PostVideoDurationCache {
    static let shared = NSCache<NSString, NSString>()
}

private enum PostVideoDebugLogger {
    static func log(_ message: String) {
        #if DEBUG
        print("[PostVideoDuration] \(message)")
        #endif
    }
}

private enum PostVideoDurationLoader {
    static func loadText(from url: URL) async -> String? {
        await Task.detached(priority: .utility) {
            let asset = AVURLAsset(url: url)
            PostVideoDebugLogger.log("start loading duration: \(url.absoluteString)")

            do {
                let duration = try await asset.load(.duration)
                let isPlayable = (try? await asset.load(.isPlayable)) ?? false

                guard duration.isValid else {
                    PostVideoDebugLogger.log("duration invalid. url=\(url.absoluteString), isPlayable=\(isPlayable)")
                    return nil
                }
                guard !duration.isIndefinite else {
                    PostVideoDebugLogger.log("duration indefinite. url=\(url.absoluteString), isPlayable=\(isPlayable)")
                    return nil
                }

                let seconds = duration.seconds
                guard seconds.isFinite, !seconds.isNaN, seconds > 0 else {
                    PostVideoDebugLogger.log(
                        "duration seconds not usable. url=\(url.absoluteString), seconds=\(seconds), isPlayable=\(isPlayable)"
                    )
                    return nil
                }

                let formatted = formatDuration(totalSeconds: Int(seconds.rounded()))
                PostVideoDebugLogger.log(
                    "duration loaded success. url=\(url.absoluteString), seconds=\(seconds), text=\(formatted), isPlayable=\(isPlayable)"
                )
                return formatted
            } catch {
                PostVideoDebugLogger.log("duration load failed. url=\(url.absoluteString), error=\(error.localizedDescription)")
                return nil
            }
        }.value
    }

    private static func formatDuration(totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private struct PostVideoDurationLabel: View {
    let url: URL
    let font: Font

    @State private var durationText: String?

    var body: some View {
        ZStack {
            if let durationText {
                Text(durationText)
                    .font(font.weight(.semibold))
                    .foregroundStyle(.white)
                    .shadow(color: Color.black.opacity(0.45), radius: 2, x: 0, y: 1)
            }
        }
        .task(id: url.absoluteString) {
            await loadDurationIfNeeded()
        }
    }

    @MainActor
    private func loadDurationIfNeeded() async {
        if durationText != nil { return }

        let key = url.absoluteString as NSString
        if let cached = PostVideoDurationCache.shared.object(forKey: key) {
            durationText = cached as String
            PostVideoDebugLogger.log("duration cache hit. url=\(url.absoluteString), text=\(durationText ?? "")")
            return
        }

        guard let loaded = await PostVideoDurationLoader.loadText(from: url) else {
            PostVideoDebugLogger.log("duration label not shown because load returned nil. url=\(url.absoluteString)")
            return
        }
        PostVideoDurationCache.shared.setObject(loaded as NSString, forKey: key)
        durationText = loaded
        PostVideoDebugLogger.log("duration label updated. url=\(url.absoluteString), text=\(loaded)")
    }
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
