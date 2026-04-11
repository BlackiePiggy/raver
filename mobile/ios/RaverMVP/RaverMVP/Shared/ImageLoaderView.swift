import SwiftUI
import SDWebImageSwiftUI

/// Unified remote image loader.
/// - Important: The image view itself does not receive taps.
///   Interactions should be handled by the outer container.
struct ImageLoaderView: View {
    var urlString: String?
    var resizingMode: ContentMode = .fill

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

#Preview {
    ImageLoaderView(urlString: "https://images.unsplash.com/photo-1506157786151-b8491531f063")
        .frame(width: 280, height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding()
}
