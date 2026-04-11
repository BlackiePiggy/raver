import SwiftUI

struct RemoteCoverImage: View {
    let urlString: String

    var body: some View {
        ImageLoaderView(urlString: urlString, resizingMode: .fill)
    }
}
