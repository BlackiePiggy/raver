import SwiftUI

struct RemoteCoverImage: View {
    let urlString: String

    var body: some View {
        let resolved = AppConfig.resolvedURLString(urlString) ?? urlString
        AsyncImage(url: URL(string: resolved)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            default:
                LinearGradient(colors: [RaverTheme.card, .black], startPoint: .top, endPoint: .bottom)
                    .overlay(Image(systemName: "photo").foregroundStyle(RaverTheme.secondaryText))
            }
        }
    }
}
