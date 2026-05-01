import SwiftUI

private struct SkeletonBlock: View {
    var width: CGFloat? = nil
    var height: CGFloat
    var cornerRadius: CGFloat = 14

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(RaverTheme.cardBorder.opacity(0.7))
            .frame(width: width, height: height)
            .redacted(reason: .placeholder)
            .shimmeringPlaceholder()
    }
}

private struct ShimmeringPlaceholderModifier: ViewModifier {
    @State private var phase: CGFloat = -0.9

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { proxy in
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.10),
                            Color.clear,
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .rotationEffect(.degrees(18))
                    .offset(x: proxy.size.width * phase)
                    .blendMode(.screen)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .allowsHitTesting(false)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                    phase = 1.2
                }
            }
    }
}

private extension View {
    func shimmeringPlaceholder() -> some View {
        modifier(ShimmeringPlaceholderModifier())
    }
}

struct FeedSkeletonView: View {
    var count: Int = 4

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(0..<count, id: \.self) { _ in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 12) {
                                SkeletonBlock(width: 44, height: 44, cornerRadius: 22)
                                VStack(alignment: .leading, spacing: 8) {
                                    SkeletonBlock(width: 140, height: 16, cornerRadius: 8)
                                    SkeletonBlock(width: 100, height: 12, cornerRadius: 6)
                                }
                                Spacer()
                            }
                            SkeletonBlock(height: 16, cornerRadius: 8)
                            SkeletonBlock(height: 16, cornerRadius: 8)
                            SkeletonBlock(width: 220, height: 16, cornerRadius: 8)
                            SkeletonBlock(height: 180, cornerRadius: 20)
                            HStack {
                                SkeletonBlock(width: 72, height: 14, cornerRadius: 7)
                                Spacer()
                                SkeletonBlock(width: 130, height: 14, cornerRadius: 7)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .scrollIndicators(.hidden)
    }
}

struct SearchResultsSkeletonView: View {
    var count: Int = 5

    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<count, id: \.self) { _ in
                GlassCard {
                    HStack(spacing: 12) {
                        SkeletonBlock(width: 42, height: 42, cornerRadius: 21)
                        VStack(alignment: .leading, spacing: 8) {
                            SkeletonBlock(width: 150, height: 16, cornerRadius: 8)
                            SkeletonBlock(width: 110, height: 12, cornerRadius: 6)
                        }
                        Spacer()
                        SkeletonBlock(width: 68, height: 32, cornerRadius: 16)
                    }
                }
            }
        }
        .padding(16)
    }
}

struct ProfileSkeletonView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 14) {
                            SkeletonBlock(width: 76, height: 76, cornerRadius: 38)
                            VStack(alignment: .leading, spacing: 8) {
                                SkeletonBlock(width: 180, height: 20, cornerRadius: 10)
                                SkeletonBlock(width: 120, height: 14, cornerRadius: 7)
                                SkeletonBlock(width: 150, height: 14, cornerRadius: 7)
                            }
                        }
                        HStack(spacing: 10) {
                            SkeletonBlock(width: 96, height: 40, cornerRadius: 20)
                            SkeletonBlock(width: 108, height: 40, cornerRadius: 20)
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        SkeletonBlock(width: 120, height: 16, cornerRadius: 8)
                        SkeletonBlock(height: 14, cornerRadius: 7)
                        SkeletonBlock(height: 14, cornerRadius: 7)
                    }
                }

                ForEach(0..<2, id: \.self) { _ in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 12) {
                                SkeletonBlock(width: 40, height: 40, cornerRadius: 20)
                                VStack(alignment: .leading, spacing: 8) {
                                    SkeletonBlock(width: 150, height: 16, cornerRadius: 8)
                                    SkeletonBlock(width: 96, height: 12, cornerRadius: 6)
                                }
                                Spacer()
                            }
                            SkeletonBlock(height: 16, cornerRadius: 8)
                            SkeletonBlock(height: 16, cornerRadius: 8)
                            SkeletonBlock(height: 160, cornerRadius: 18)
                        }
                    }
                }
            }
            .padding(16)
        }
        .scrollIndicators(.hidden)
    }
}

struct EventDetailSkeletonView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SkeletonBlock(height: 320, cornerRadius: 0)

                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 18) {
                        SkeletonBlock(width: 52, height: 18, cornerRadius: 9)
                        SkeletonBlock(width: 60, height: 18, cornerRadius: 9)
                        SkeletonBlock(width: 56, height: 18, cornerRadius: 9)
                        SkeletonBlock(width: 66, height: 18, cornerRadius: 9)
                    }
                    .padding(.top, 12)

                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            SkeletonBlock(width: 110, height: 16, cornerRadius: 8)
                            SkeletonBlock(height: 14, cornerRadius: 7)
                            SkeletonBlock(height: 14, cornerRadius: 7)
                            SkeletonBlock(width: 220, height: 14, cornerRadius: 7)
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            SkeletonBlock(width: 96, height: 16, cornerRadius: 8)
                            SkeletonBlock(height: 14, cornerRadius: 7)
                            SkeletonBlock(height: 14, cornerRadius: 7)
                            SkeletonBlock(height: 160, cornerRadius: 18)
                        }
                    }

                    GlassCard {
                        HStack(spacing: 12) {
                            SkeletonBlock(width: 38, height: 38, cornerRadius: 19)
                            VStack(alignment: .leading, spacing: 8) {
                                SkeletonBlock(width: 72, height: 12, cornerRadius: 6)
                                SkeletonBlock(width: 140, height: 16, cornerRadius: 8)
                            }
                            Spacer()
                            SkeletonBlock(width: 18, height: 18, cornerRadius: 9)
                        }
                    }
                }
                .padding(16)
            }
        }
        .scrollIndicators(.hidden)
    }
}

struct DJDetailSkeletonView: View {
    var body: some View {
        EventDetailSkeletonView()
    }
}

struct SetDetailSkeletonView: View {
    var body: some View {
        EventDetailSkeletonView()
    }
}

struct FollowListSkeletonView: View {
    var count: Int = 8

    var body: some View {
        List {
            ForEach(0..<count, id: \.self) { _ in
                HStack(spacing: 12) {
                    SkeletonBlock(width: 48, height: 48, cornerRadius: 24)
                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonBlock(width: 140, height: 16, cornerRadius: 8)
                        SkeletonBlock(width: 96, height: 12, cornerRadius: 6)
                    }
                    Spacer()
                    SkeletonBlock(width: 78, height: 30, cornerRadius: 15)
                }
                .padding(.vertical, 8)
                .listRowBackground(RaverTheme.background)
            }
        }
        .scrollContentBackground(.hidden)
    }
}

struct SquadProfileSkeletonView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            SkeletonBlock(width: 72, height: 72, cornerRadius: 36)
                            VStack(alignment: .leading, spacing: 8) {
                                SkeletonBlock(width: 180, height: 20, cornerRadius: 10)
                                SkeletonBlock(width: 150, height: 14, cornerRadius: 7)
                            }
                            Spacer()
                        }
                        SkeletonBlock(height: 14, cornerRadius: 7)
                        SkeletonBlock(width: 220, height: 14, cornerRadius: 7)
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        SkeletonBlock(width: 96, height: 16, cornerRadius: 8)
                        HStack(spacing: 12) {
                            ForEach(0..<4, id: \.self) { _ in
                                VStack(spacing: 6) {
                                    SkeletonBlock(width: 46, height: 46, cornerRadius: 23)
                                    SkeletonBlock(width: 56, height: 12, cornerRadius: 6)
                                }
                            }
                        }
                    }
                }

                ForEach(0..<3, id: \.self) { _ in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            SkeletonBlock(width: 120, height: 16, cornerRadius: 8)
                            SkeletonBlock(height: 14, cornerRadius: 7)
                            SkeletonBlock(height: 14, cornerRadius: 7)
                            SkeletonBlock(width: 180, height: 14, cornerRadius: 7)
                        }
                    }
                }

                SkeletonBlock(height: 48, cornerRadius: 24)
            }
            .padding(16)
        }
        .scrollIndicators(.hidden)
    }
}

struct CommentSectionSkeletonView: View {
    var count: Int = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(0..<count, id: \.self) { _ in
                HStack(alignment: .top, spacing: 10) {
                    SkeletonBlock(width: 34, height: 34, cornerRadius: 17)
                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonBlock(width: 120, height: 14, cornerRadius: 7)
                        SkeletonBlock(height: 14, cornerRadius: 7)
                        SkeletonBlock(width: 200, height: 14, cornerRadius: 7)
                    }
                }
            }
        }
    }
}

struct ConversationListSkeletonView: View {
    var count: Int = 8

    var body: some View {
        List {
            ForEach(0..<count, id: \.self) { _ in
                HStack(spacing: 12) {
                    SkeletonBlock(width: 48, height: 48, cornerRadius: 24)
                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonBlock(width: 140, height: 16, cornerRadius: 8)
                        SkeletonBlock(height: 14, cornerRadius: 7)
                        SkeletonBlock(width: 100, height: 12, cornerRadius: 6)
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
                .listRowBackground(RaverTheme.card)
            }
        }
        .scrollContentBackground(.hidden)
    }
}

struct DiscoverGridSkeletonView: View {
    var count: Int = 6
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(0..<count, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonBlock(height: 118, cornerRadius: 0)
                        SkeletonBlock(width: 120, height: 15, cornerRadius: 7)
                        SkeletonBlock(width: 84, height: 12, cornerRadius: 6)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
    }
}

struct NotificationListSkeletonView: View {
    var count: Int = 8

    var body: some View {
        List {
            ForEach(0..<count, id: \.self) { _ in
                HStack(alignment: .top, spacing: 12) {
                    SkeletonBlock(width: 30, height: 30, cornerRadius: 15)
                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonBlock(height: 14, cornerRadius: 7)
                        SkeletonBlock(width: 220, height: 14, cornerRadius: 7)
                        SkeletonBlock(width: 100, height: 12, cornerRadius: 6)
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
                .listRowBackground(RaverTheme.card)
            }
        }
        .scrollContentBackground(.hidden)
    }
}
