import SwiftUI
import SDWebImageSwiftUI
import AVKit

/// Unified remote image loader.
/// - Important: The image view itself does not receive taps.
///   Interactions should be handled by the outer container.
struct ImageLoaderView: View {
    var urlString: String?
    var resizingMode: ContentMode = .fill
    var showsIndicator: Bool = true
    var showsFallback: Bool = true
    var contentOffset: CGSize = .zero
    var onImageLoaded: ((CGSize) -> Void)? = nil

    var body: some View {
        Rectangle()
            .opacity(0.001)
            .overlay(imageContent)
            .clipped()
    }

    @ViewBuilder
    private var imageContent: some View {
        if let resolved = AppConfig.resolvedURLString(urlString),
           let remoteURL = URL(string: resolved),
           resolved.hasPrefix("http://") || resolved.hasPrefix("https://") {
            Group {
                if showsIndicator {
                    WebImage(url: remoteURL)
                        .onSuccess { image, _, _ in
                            onImageLoaded?(image.size)
                        }
                        .resizable()
                        .indicator(.activity)
                } else {
                    WebImage(url: remoteURL)
                        .onSuccess { image, _, _ in
                            onImageLoaded?(image.size)
                        }
                        .resizable()
                }
            }
            .aspectRatio(contentMode: resizingMode)
            .offset(contentOffset)
            .allowsHitTesting(false)
        } else {
            Group {
                if showsFallback {
                    fallback
                } else {
                    Color.clear
                }
            }
                .allowsHitTesting(false)
        }
    }

    private var fallback: some View {
        LinearGradient(
            colors: [RaverTheme.card, RaverTheme.background],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "photo")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(RaverTheme.secondaryText)
        )
    }
}

struct AvatarPlaceholderView: View {
    let size: CGFloat
    var isGroup: Bool = false
    var backgroundColor: Color = RaverTheme.cardBorder

    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
            Image(systemName: isGroup ? "person.2.fill" : "person.fill")
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.92))
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

struct DefaultDJAvatarPlaceholderView: View {
    let size: CGFloat
    var backgroundColor: Color = RaverTheme.card
    var imageScale: CGFloat = 0.94

    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
            Image("DefaultDJAvatarPlaceholder")
                .resizable()
                .scaledToFit()
                .padding(size * max(0, (1 - imageScale) / 2))
                .accessibilityHidden(true)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

struct FullscreenMediaItem: Identifiable, Hashable {
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
            return encodedURL
        }
        return nil
    }
}

struct FullscreenMediaSelection: Identifiable {
    let id: Int
}

struct FullscreenMediaViewer: View {
    @Environment(\.dismiss) private var dismiss

    let items: [FullscreenMediaItem]
    @State private var currentIndex: Int

    init(items: [FullscreenMediaItem], initialIndex: Int) {
        self.items = items
        _currentIndex = State(initialValue: min(max(initialIndex, 0), max(0, items.count - 1)))
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            if items.isEmpty {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.85))
            } else {
                TabView(selection: $currentIndex) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        Group {
                            if item.isVideo, let url = item.url {
                                FullscreenMediaVideoPlayer(url: url)
                            } else if let url = item.url {
                                FullscreenZoomableRemoteImage(
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
            }

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

                if !items.isEmpty {
                    Text("\(currentIndex + 1)/\(items.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
        }
    }
}

private struct FullscreenZoomableRemoteImage: View {
    let url: URL
    let isActive: Bool
    let canGoPrevious: Bool
    let canGoNext: Bool
    let onRequestPrevious: () -> Void
    let onRequestNext: () -> Void

    private let minimumScale: CGFloat = 1
    private let maximumScale: CGFloat = 4
    private let quickZoomScale: CGFloat = 2.2
    @State private var resetToken = UUID()
    @State private var isLoading = true

    var body: some View {
        ZStack {
            FullscreenZoomableImageScrollView(
                url: url,
                minimumZoomScale: minimumScale,
                maximumZoomScale: maximumScale,
                quickZoomScale: quickZoomScale,
                resetToken: resetToken,
                onLoadingChanged: { isLoading = $0 }
            )
            .background(
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            )

            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.white)
                    Text(LT("图片加载中...", "Loading image...", "画像を読み込み中..."))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.82))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(Color.black.opacity(0.54), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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

    private func resetZoom() {
        resetToken = UUID()
    }
}

private struct FullscreenZoomableImageScrollView: UIViewRepresentable {
    let url: URL
    let minimumZoomScale: CGFloat
    let maximumZoomScale: CGFloat
    let quickZoomScale: CGFloat
    let resetToken: UUID
    let onLoadingChanged: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.backgroundColor = .black
        scrollView.minimumZoomScale = minimumZoomScale
        scrollView.maximumZoomScale = maximumZoomScale
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.decelerationRate = .fast
        scrollView.contentInsetAdjustmentBehavior = .never

        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        imageView.backgroundColor = .black
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        context.coordinator.scrollView = scrollView
        context.coordinator.imageView = imageView
        context.coordinator.quickZoomScale = quickZoomScale
        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.quickZoomScale = quickZoomScale
        context.coordinator.onLoadingChanged = onLoadingChanged
        context.coordinator.loadImageIfNeeded(from: url)

        if context.coordinator.resetToken != resetToken {
            context.coordinator.resetToken = resetToken
            scrollView.setZoomScale(minimumZoomScale, animated: false)
            scrollView.contentOffset = .zero
            context.coordinator.centerImage()
        }
    }

    static func dismantleUIView(_ uiView: UIScrollView, coordinator: Coordinator) {
        coordinator.cancelImageLoad()
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var scrollView: UIScrollView?
        weak var imageView: UIImageView?
        var quickZoomScale: CGFloat = 2.2
        var resetToken: UUID?
        var onLoadingChanged: ((Bool) -> Void)?
        private var loadedURL: URL?
        private var loadTask: URLSessionDataTask?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerImage()
        }

        @objc func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
            guard let scrollView, let imageView else { return }

            if scrollView.zoomScale > scrollView.minimumZoomScale + 0.01 {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
                return
            }

            let tapPoint = recognizer.location(in: imageView)
            let targetScale = min(max(quickZoomScale, scrollView.minimumZoomScale), scrollView.maximumZoomScale)
            let width = scrollView.bounds.width / targetScale
            let height = scrollView.bounds.height / targetScale
            let zoomRect = CGRect(
                x: tapPoint.x - (width / 2),
                y: tapPoint.y - (height / 2),
                width: width,
                height: height
            )
            scrollView.zoom(to: zoomRect, animated: true)
        }

        func loadImageIfNeeded(from url: URL) {
            guard loadedURL != url else { return }
            loadedURL = url
            loadTask?.cancel()
            imageView?.image = nil
            setLoading(true)
            scrollView?.setZoomScale(scrollView?.minimumZoomScale ?? 1, animated: false)
            scrollView?.contentOffset = .zero

            if url.isFileURL {
                imageView?.image = UIImage(contentsOfFile: url.path)
                centerImage()
                setLoading(false)
                return
            }

            loadTask = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let self else { return }
                DispatchQueue.main.async {
                    guard self.loadedURL == url else { return }
                    if let data, let image = UIImage(data: data) {
                        self.imageView?.image = image
                    }
                    self.centerImage()
                    self.setLoading(false)
                }
            }
            loadTask?.resume()
        }

        func cancelImageLoad() {
            loadTask?.cancel()
            loadTask = nil
        }

        private func setLoading(_ isLoading: Bool) {
            DispatchQueue.main.async { [weak self] in
                self?.onLoadingChanged?(isLoading)
            }
        }

        func centerImage() {
            guard let scrollView, let imageView else { return }
            let horizontalInset = max(0, (scrollView.bounds.width - imageView.frame.width) / 2)
            let verticalInset = max(0, (scrollView.bounds.height - imageView.frame.height) / 2)
            scrollView.contentInset = UIEdgeInsets(
                top: verticalInset,
                left: horizontalInset,
                bottom: verticalInset,
                right: horizontalInset
            )
        }
    }
}

private struct FullscreenMediaVideoPlayer: View {
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

#Preview {
    ImageLoaderView(urlString: "https://images.unsplash.com/photo-1506157786151-b8491531f063")
        .frame(width: 280, height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding()
}
