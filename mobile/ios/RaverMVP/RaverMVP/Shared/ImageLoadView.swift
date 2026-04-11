import SwiftUI

/// Backward-compatible wrapper. Prefer `ImageLoaderView`.
struct ImageLoadView: View {
    var urlString: String?
    var resizingMode: ContentMode = .fill

    var body: some View {
        ImageLoaderView(urlString: urlString, resizingMode: resizingMode)
    }
}

#Preview {
    ImageLoadView(urlString: "https://images.unsplash.com/photo-1506157786151-b8491531f063")
        .frame(width: 280, height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding()
}
