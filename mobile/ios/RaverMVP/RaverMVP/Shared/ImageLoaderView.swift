import SwiftUI
import SDWebImageSwiftUI
import AVKit

/// Unified remote image loader.
/// - Important: The image view itself does not receive taps.
///   Interactions should be handled by the outer container.
struct ImageLoaderView: View {
    var urlString: String?
    var resizingMode: ContentMode = .fill
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
            WebImage(url: remoteURL)
                .onSuccess { image, _, _ in
                    onImageLoaded?(image.size)
                }
                .resizable()
                .indicator(.activity)
                .aspectRatio(contentMode: resizingMode)
                .allowsHitTesting(false)
        } else {
            fallback
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
    private let pageTurnThreshold: CGFloat = 24
    private let panEdgeEpsilon: CGFloat = 1.0

    @State private var baseScale: CGFloat = 1
    @State private var gestureScale: CGFloat = 1
    @State private var currentOffset: CGSize = .zero
    @State private var accumulatedOffset: CGSize = .zero
    @State private var didTriggerPageTurnInCurrentDrag = false

    var body: some View {
        GeometryReader { proxy in
            let isZoomed = displayScale > minimumScale + 0.01
            ImageLoaderView(urlString: url.absoluteString, resizingMode: .fit)
                .background(
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                )
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
