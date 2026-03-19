import SwiftUI

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

                    if showsFollowButton, post.author.id != currentUserId, let onFollowTap {
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

                if let first = post.images.first {
                    RemoteCoverImage(urlString: first)
                        .frame(height: 210)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
    }

    private var authorMeta: some View {
        HStack(alignment: .center, spacing: 10) {
            // 头像
            if let avatarURL = AppConfig.resolvedURLString(post.author.avatarURL), !avatarURL.isEmpty {
                AsyncImage(url: URL(string: avatarURL)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Circle()
                            .fill(RaverTheme.accent.opacity(0.2))
                            .overlay(Text(String(post.author.displayName.prefix(1))).font(.caption).bold())
                    }
                }
                .frame(width: 34, height: 34)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(RaverTheme.accent.opacity(0.2))
                    .frame(width: 34, height: 34)
                    .overlay(Text(String(post.author.displayName.prefix(1))).font(.caption).bold())
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(post.author.displayName)
                    .font(.subheadline.bold())
                Text("@\(post.author.username) · \(post.createdAt.feedTimeText)")
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
            }
        }
    }
}
