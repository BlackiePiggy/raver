import SwiftUI

struct DiscoverHomeView: View {
    private enum Section: String, CaseIterable, Identifiable {
        case feed
        case discover

        var id: String { rawValue }

        var title: String {
            switch self {
            case .feed: return "动态广场"
            case .discover: return "发现"
            }
        }
    }

    @State private var section: Section = .feed

    var body: some View {
        VStack(spacing: 0) {
            Picker("发现入口", selection: $section) {
                ForEach(Section.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .background(RaverTheme.background)

            Group {
                switch section {
                case .feed:
                    FeedView()
                case .discover:
                    SearchView()
                }
            }
        }
        .background(RaverTheme.background)
    }
}
