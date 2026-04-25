import AVFoundation
import AVKit
import LinkPresentation
import MapKit
import SwiftUI
import UIKit

struct PostCardView: View {
    @Environment(\.colorScheme) private var colorScheme

    let post: Post
    let currentUserId: String?
    let showsFollowButton: Bool
    let onLikeTap: () -> Void
    let onRepostTap: (() -> Void)?
    let onSaveTap: (() -> Void)?
    let onShareTap: (() -> Void)?
    let onHideTap: (() -> Void)?
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
        onSaveTap: (() -> Void)? = nil,
        onShareTap: (() -> Void)? = nil,
        onHideTap: (() -> Void)? = nil,
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
        self.onSaveTap = onSaveTap
        self.onShareTap = onShareTap
        self.onHideTap = onHideTap
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
                        .accessibilityLabel(L("编辑动态", "Edit Post"))
                    } else if showsFollowButton, let onFollowTap {
                        Button(post.author.isFollowing ? L("已关注", "Following") : L("关注", "Follow"), action: onFollowTap)
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

                if let reason = normalizedRecommendationReason {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.caption.weight(.semibold))
                        Text(reason)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(RaverTheme.secondaryText)
                }

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
                        .foregroundStyle(locationLabelTextColor)
                        .frame(maxWidth: locationLabelMaxWidth, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(locationLabelBackgroundColor)
                        .overlay(
                            Capsule()
                                .stroke(locationLabelStrokeColor, lineWidth: 0.8)
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

                    if let onSaveTap {
                        Button(action: onSaveTap) {
                            Label("\(post.saveCount)", systemImage: post.isSaved ? "bookmark.fill" : "bookmark")
                        }
                        .foregroundStyle(post.isSaved ? RaverTheme.accent : RaverTheme.secondaryText)
                    }

                    if post.author.id != currentUserId, let onMessageTap {
                        Button(action: onMessageTap) {
                            Label(LL("私信"), systemImage: "paperplane")
                        }
                        .foregroundStyle(RaverTheme.secondaryText)
                    }

                    if post.squad != nil, let onSquadTap {
                        Button(action: onSquadTap) {
                            Label(LL("进小队"), systemImage: "person.3")
                        }
                        .foregroundStyle(RaverTheme.secondaryText)
                    }

                    if onShareTap != nil || onHideTap != nil {
                        Menu {
                            if let onShareTap {
                                Button(action: onShareTap) {
                                    Label(LL("分享"), systemImage: "square.and.arrow.up")
                                }
                            }
                            if let onHideTap {
                                Button(role: .destructive, action: onHideTap) {
                                    Label(LL("不感兴趣"), systemImage: "eye.slash")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .frame(width: 28, height: 28)
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

    private var normalizedRecommendationReason: String? {
        let trimmed = post.recommendationReason?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private var locationLabelMaxWidth: CGFloat {
        max(150, min(UIScreen.main.bounds.width * 0.48, 210))
    }

    private var locationLabelBackgroundColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.36)
            : Color(red: 0.90, green: 0.94, blue: 0.98)
    }

    private var locationLabelTextColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.94)
            : Color.black.opacity(0.78)
    }

    private var locationLabelStrokeColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.14)
            : Color.black.opacity(0.08)
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
           resolved.hasPrefix("http://") || resolved.hasPrefix("https://"),
           URL(string: resolved) != nil {
            ImageLoaderView(urlString: resolved)
                .background(authorAvatarFallback)
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
    @State private var availableMapApps: [ExternalMapApp] = []
    @State private var showMapAppPicker = false

    private enum ExternalMapApp: String, CaseIterable, Identifiable {
        case apple
        case amap
        case baidu
        case tencent

        var id: String { rawValue }

        var title: String {
            switch self {
            case .apple: return L("Apple 地图", "Apple Maps")
            case .amap: return L("高德地图", "Amap")
            case .baidu: return L("百度地图", "Baidu Maps")
            case .tencent: return L("腾讯地图", "Tencent Maps")
            }
        }
    }

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
                    Text(LL("定位信息"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RaverTheme.secondaryText)
                    Text(locationText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                        .lineLimit(2)

                    if isResolving {
                        ProgressView(LL("正在解析位置…"))
                            .font(.caption)
                            .tint(RaverTheme.secondaryText)
                    } else if resolveFailed {
                        Text(LL("未能精确定位，仍可在地图中拖动查看区域。"))
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }

                    Button {
                        refreshAvailableMapApps()
                        if !availableMapApps.isEmpty {
                            showMapAppPicker = true
                        }
                    } label: {
                        Label(LL("打开地图App"), systemImage: "arrow.up.right.square")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(RaverTheme.accent)
                    .disabled(availableMapApps.isEmpty)
                    .opacity(availableMapApps.isEmpty ? 0.65 : 1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .raverSystemNavigation(title: LL("位置地图"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
            }
            .confirmationDialog(L("选择地图应用", "Choose Map App"), isPresented: $showMapAppPicker, titleVisibility: .visible) {
                ForEach(availableMapApps) { app in
                    Button(app.title) {
                        openExternalMap(app)
                    }
                }
                Button(L("取消", "Cancel"), role: .cancel) {}
            }
            .task {
                refreshAvailableMapApps()
                await resolveLocation()
            }
        }
        .raverEnableCustomSwipeBack(edgeRatio: 0.2)
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
                refreshAvailableMapApps()
                return
            }
            resolveFailed = true
            refreshAvailableMapApps()
        } catch {
            resolveFailed = true
            refreshAvailableMapApps()
        }
    }

    private func refreshAvailableMapApps() {
        let app = UIApplication.shared
        var result: [ExternalMapApp] = [.apple]
        if app.canOpenURL(URL(string: "iosamap://")!) {
            result.append(.amap)
        }
        if app.canOpenURL(URL(string: "baidumap://")!) {
            result.append(.baidu)
        }
        if app.canOpenURL(URL(string: "qqmap://")!) {
            result.append(.tencent)
        }
        availableMapApps = result
    }

    private func openExternalMap(_ app: ExternalMapApp) {
        guard let url = externalMapURL(for: app) else { return }
        UIApplication.shared.open(url)
    }

    private func externalMapURL(for app: ExternalMapApp) -> URL? {
        let query = locationText.trimmingCharacters(in: .whitespacesAndNewlines)
        switch app {
        case .apple:
            if let resolvedCoordinate {
                let placemark = MKPlacemark(coordinate: resolvedCoordinate)
                let item = MKMapItem(placemark: placemark)
                item.name = locationText
                return item.url
            }
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            return URL(string: "http://maps.apple.com/?q=\(encoded)")
        case .amap:
            if let resolvedCoordinate {
                var components = URLComponents()
                components.scheme = "iosamap"
                components.host = "viewMap"
                components.queryItems = [
                    URLQueryItem(name: "sourceApplication", value: "RaveHub"),
                    URLQueryItem(name: "poiname", value: locationText),
                    URLQueryItem(name: "lat", value: "\(resolvedCoordinate.latitude)"),
                    URLQueryItem(name: "lon", value: "\(resolvedCoordinate.longitude)"),
                    URLQueryItem(name: "dev", value: "0"),
                    URLQueryItem(name: "zoom", value: "17")
                ]
                return components.url
            }
            guard !query.isEmpty else { return nil }
            var components = URLComponents()
            components.scheme = "iosamap"
            components.host = "poi"
            components.queryItems = [
                URLQueryItem(name: "sourceApplication", value: "RaveHub"),
                URLQueryItem(name: "keywords", value: query)
            ]
            return components.url
        case .baidu:
            if let resolvedCoordinate {
                var components = URLComponents()
                components.scheme = "baidumap"
                components.host = "map"
                components.path = "/marker"
                components.queryItems = [
                    URLQueryItem(name: "location", value: "\(resolvedCoordinate.latitude),\(resolvedCoordinate.longitude)"),
                    URLQueryItem(name: "title", value: locationText),
                    URLQueryItem(name: "content", value: query.isEmpty ? locationText : query),
                    URLQueryItem(name: "src", value: "RaveHub")
                ]
                return components.url
            }
            guard !query.isEmpty else { return nil }
            var components = URLComponents()
            components.scheme = "baidumap"
            components.host = "map"
            components.path = "/search"
            components.queryItems = [
                URLQueryItem(name: "query", value: query),
                URLQueryItem(name: "src", value: "RaveHub")
            ]
            return components.url
        case .tencent:
            var components = URLComponents()
            components.scheme = "qqmap"
            components.host = "map"
            components.path = "/search"
            var items: [URLQueryItem] = [
                URLQueryItem(name: "referer", value: "RaveHub"),
                URLQueryItem(name: "keyword", value: query.isEmpty ? locationText : query)
            ]
            if let resolvedCoordinate {
                items.append(URLQueryItem(name: "center", value: "\(resolvedCoordinate.latitude),\(resolvedCoordinate.longitude)"))
            }
            components.queryItems = items
            return components.url
        }
    }
}

struct PostMediaGridView: View {
    let mediaURLs: [String]
    var allowsFullscreen: Bool = true

    @State private var selectedMedia: FullscreenMediaSelection?
    @State private var singleImageAspectRatioByID: [String: CGFloat] = [:]
    @State private var singleImageContainerWidth: CGFloat = max(UIScreen.main.bounds.width - 64, 1)

    private var items: [FullscreenMediaItem] {
        mediaURLs
            .enumerated()
            .compactMap { offset, raw in
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                return FullscreenMediaItem(rawURL: trimmed, index: offset)
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
            FullscreenMediaViewer(items: items, initialIndex: selection.id)
        }
    }

    @ViewBuilder
    private func mediaTapWrapper<Content: View>(index: Int, @ViewBuilder content: () -> Content) -> some View {
        if allowsFullscreen {
            Button {
                selectedMedia = FullscreenMediaSelection(id: index)
            } label: {
                content()
            }
            .buttonStyle(.plain)
        } else {
            content()
        }
    }

    private func singleMediaView(_ item: FullscreenMediaItem) -> some View {
        let width = max(singleImageContainerWidth, 1)
        let maxHeight = width * 1.5
        let naturalHeight = singleImageAspectRatio(for: item).map { width / max($0, 0.0001) }
        let isOverflowing = (naturalHeight ?? maxHeight) > maxHeight
        let targetHeight = min(naturalHeight ?? width, maxHeight)

        return ZStack {
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
                ImageLoaderView(
                    urlString: item.url?.absoluteString,
                    resizingMode: isOverflowing ? .fill : .fit,
                    onImageLoaded: { imageSize in
                        guard imageSize.width > 0, imageSize.height > 0 else { return }
                        let ratio = imageSize.width / imageSize.height
                        let old = singleImageAspectRatioByID[item.id]
                        if old == nil || abs((old ?? ratio) - ratio) > 0.001 {
                            singleImageAspectRatioByID[item.id] = ratio
                        }
                    }
                )
                    .background(mediaPlaceholder.frame(height: 200))
                    .frame(maxWidth: .infinity)
                    .frame(height: max(targetHeight, 1))
                    .background(Color.black.opacity(0.06))
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .onAppear {
                                    updateSingleImageContainerWidth(geo.size.width)
                                }
                                .onChange(of: geo.size.width) { _, newValue in
                                    updateSingleImageContainerWidth(newValue)
                                }
                        }
                    )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func singleImageAspectRatio(for item: FullscreenMediaItem) -> CGFloat? {
        singleImageAspectRatioByID[item.id]
    }

    private func updateSingleImageContainerWidth(_ width: CGFloat) {
        guard width.isFinite, width > 0 else { return }
        if abs(singleImageContainerWidth - width) > 0.5 {
            singleImageContainerWidth = width
        }
    }

    private func mediaThumbnail(_ item: FullscreenMediaItem) -> some View {
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
                        ImageLoaderView(urlString: item.url?.absoluteString)
                            .background(mediaPlaceholder)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                PostVideoDebugLogger.log("duration load failed. url=\(url.absoluteString), error=\(error.userFacingMessage ?? "")")
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

struct PostSharePayload: Identifiable {
    let id: String
    let post: Post

    init(post: Post) {
        self.id = post.id
        self.post = post
    }

    var shareSummary: String {
        let trimmed = post.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return L("来自 Raver 的动态", "A post from Raver")
        }
        return String(trimmed.prefix(90))
    }

    var shareTitle: String {
        "\(post.author.displayName) · \(L("Raver 动态", "Raver Post"))"
    }

    var shareURLString: String {
        "https://raver.app/posts/\(post.id)"
    }

    var shareURL: URL {
        URL(string: shareURLString) ?? URL(string: "https://raver.app")!
    }

    var firstMedia: FullscreenMediaItem? {
        guard let first = post.images.first?.trimmingCharacters(in: .whitespacesAndNewlines), !first.isEmpty else {
            return nil
        }
        return FullscreenMediaItem(rawURL: first, index: 0)
    }
}

struct PostInAppShareSheet: View {
    @Environment(\.dismiss) private var dismiss

    let payload: PostSharePayload
    let onRecordShare: (_ channel: String) -> Void

    @State private var isShowingSystemShare = false
    @State private var feedbackText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Capsule()
                .fill(RaverTheme.secondaryText.opacity(0.35))
                .frame(width: 44, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 6)

            HStack(spacing: 10) {
                Text(L("分享动态", "Share Post"))
                    .font(.headline)
                    .foregroundStyle(RaverTheme.primaryText)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(RaverTheme.secondaryText)
                        .frame(width: 30, height: 30)
                        .background(RaverTheme.card)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            PostSharePreviewCard(payload: payload)

            HStack(spacing: 18) {
                PostShareActionButton(
                    title: L("系统分享", "System Share"),
                    icon: "square.and.arrow.up"
                ) {
                    isShowingSystemShare = true
                }

                PostShareActionButton(
                    title: L("复制链接", "Copy Link"),
                    icon: "link"
                ) {
                    UIPasteboard.general.string = payload.shareURLString
                    feedbackText = L("链接已复制", "Link copied")
                    onRecordShare("copy_link")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        dismiss()
                    }
                }

                Spacer()
            }

            if let feedbackText {
                Text(feedbackText)
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .background(RaverTheme.background)
        .presentationDetents([.height(350), .medium])
        .presentationDragIndicator(.hidden)
        .sheet(isPresented: $isShowingSystemShare) {
            PostSystemActivityShareSheet(payload: payload) { activityType, completed, _, _ in
                guard completed else { return }
                let channel = activityType?.rawValue ?? "system"
                onRecordShare(channel)
                dismiss()
            }
        }
    }
}

private struct PostShareActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .frame(width: 48, height: 48)
                    .background(RaverTheme.card)
                    .clipShape(Circle())
                Text(title)
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct PostSharePreviewCard: View {
    let payload: PostSharePayload

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            mediaPreview
                .frame(width: 74, height: 74)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(payload.post.author.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
                    .lineLimit(1)

                Text(payload.shareSummary)
                    .font(.footnote)
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(3)

                HStack(spacing: 10) {
                    Label("\(payload.post.likeCount)", systemImage: "heart")
                    Label("\(payload.post.commentCount)", systemImage: "text.bubble")
                    Label("\(payload.post.shareCount)", systemImage: "square.and.arrow.up")
                }
                .font(.caption2)
                .foregroundStyle(RaverTheme.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(RaverTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private var mediaPreview: some View {
        if let item = payload.firstMedia {
            if item.isVideo, let url = item.url {
                ZStack {
                    PostVideoThumbnailView(url: url, contentMode: .fill)
                    Image(systemName: "play.fill")
                        .font(.footnote.bold())
                        .foregroundStyle(.white)
                        .shadow(color: Color.black.opacity(0.45), radius: 2, x: 0, y: 1)
                }
            } else {
                ImageLoaderView(urlString: item.url?.absoluteString)
                    .background(RaverTheme.card)
            }
        } else {
            ZStack {
                RaverTheme.card
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
            }
        }
    }
}

private struct PostSystemActivityShareSheet: UIViewControllerRepresentable {
    let payload: PostSharePayload
    var completion: UIActivityViewController.CompletionWithItemsHandler?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let itemSource = PostShareActivityItemSource(payload: payload)
        let controller = UIActivityViewController(activityItems: [itemSource], applicationActivities: nil)
        controller.completionWithItemsHandler = completion
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private final class PostShareActivityItemSource: NSObject, UIActivityItemSource {
    private let payload: PostSharePayload

    init(payload: PostSharePayload) {
        self.payload = payload
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        payload.shareURL
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        payload.shareURL
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        payload.shareTitle
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = payload.shareSummary
        metadata.originalURL = payload.shareURL
        metadata.url = payload.shareURL

        if let previewImage = PostShareMetadataCardRenderer.makeImage(payload: payload) {
            let provider = NSItemProvider(object: previewImage)
            metadata.imageProvider = provider
            metadata.iconProvider = provider
        }
        return metadata
    }
}

private enum PostShareMetadataCardRenderer {
    static func makeImage(payload: PostSharePayload) -> UIImage? {
        let size = CGSize(width: 960, height: 520)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let cg = context.cgContext
            let bounds = CGRect(origin: .zero, size: size)
            UIColor(red: 0.08, green: 0.09, blue: 0.12, alpha: 1).setFill()
            cg.fill(bounds)

            let cardRect = bounds.insetBy(dx: 44, dy: 44)
            let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: 28)
            UIColor(red: 0.14, green: 0.16, blue: 0.20, alpha: 1).setFill()
            cardPath.fill()

            let titleRect = CGRect(x: cardRect.minX + 34, y: cardRect.minY + 34, width: cardRect.width - 68, height: 170)
            let bodyStyle = NSMutableParagraphStyle()
            bodyStyle.lineBreakMode = .byTruncatingTail
            bodyStyle.maximumLineHeight = 58
            bodyStyle.minimumLineHeight = 58
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 50, weight: .bold),
                .foregroundColor: UIColor.white,
                .paragraphStyle: bodyStyle
            ]
            NSString(string: payload.shareSummary).draw(with: titleRect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: titleAttrs, context: nil)

            let authorRect = CGRect(x: cardRect.minX + 34, y: cardRect.maxY - 120, width: cardRect.width - 68, height: 80)
            let authorAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 32, weight: .semibold),
                .foregroundColor: UIColor(white: 0.88, alpha: 1)
            ]
            NSString(string: payload.shareTitle).draw(in: authorRect, withAttributes: authorAttrs)
        }
    }
}
