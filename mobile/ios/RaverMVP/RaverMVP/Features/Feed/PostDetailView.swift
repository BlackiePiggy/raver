import SwiftUI

struct PostDetailView: View {
    @EnvironmentObject private var appState: AppState
    @State private var post: Post
    private let service: SocialService

    @State private var comments: [Comment] = []
    @State private var commentInput = ""
    @State private var isLoading = false
    @State private var error: String?
    @State private var selectedUserForProfile: UserSummary?

    init(post: Post, service: SocialService) {
        self._post = State(initialValue: post)
        self.service = service
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    PostCardView(
                        post: post,
                        currentUserId: appState.session?.user.id,
                        showsFollowButton: true,
                        onLikeTap: {
                            Task {
                                do {
                                    post = try await service.toggleLike(postID: post.id, shouldLike: !post.isLiked)
                                } catch {
                                    self.error = error.localizedDescription
                                }
                            }
                        },
                        onRepostTap: {
                            Task {
                                do {
                                    post = try await service.toggleRepost(postID: post.id, shouldRepost: !post.isReposted)
                                } catch {
                                    self.error = error.localizedDescription
                                }
                            }
                        },
                        onFollowTap: {
                            Task {
                                do {
                                    let author = try await service.toggleFollow(userID: post.author.id, shouldFollow: !post.author.isFollowing)
                                    post.author = author
                                } catch {
                                    self.error = error.localizedDescription
                                }
                            }
                        },
                        onMessageTap: nil,
                        onAuthorTap: {
                            selectedUserForProfile = post.author
                        },
                        onSquadTap: nil
                    )

                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("评论")
                                .font(.headline)

                            if isLoading {
                                ProgressView()
                            } else if comments.isEmpty {
                                Text("还没有评论，来抢沙发吧。")
                                    .font(.subheadline)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            } else {
                                ForEach(comments) { comment in
                                    Button {
                                        selectedUserForProfile = comment.author
                                    } label: {
                                        HStack(alignment: .top, spacing: 10) {
                                            if let avatar = AppConfig.resolvedURLString(comment.author.avatarURL), !avatar.isEmpty {
                                                AsyncImage(url: URL(string: avatar)) { phase in
                                                    switch phase {
                                                    case .empty:
                                                        Circle().fill(RaverTheme.card)
                                                    case .success(let image):
                                                        image.resizable().scaledToFill()
                                                    case .failure:
                                                        Circle().fill(RaverTheme.card)
                                                    @unknown default:
                                                        Circle().fill(RaverTheme.card)
                                                    }
                                                }
                                                .frame(width: 30, height: 30)
                                                .clipShape(Circle())
                                            } else {
                                                Circle()
                                                    .fill(RaverTheme.card)
                                                    .frame(width: 30, height: 30)
                                                    .overlay(
                                                        Image(systemName: "person.fill")
                                                            .font(.system(size: 12))
                                                            .foregroundStyle(RaverTheme.secondaryText)
                                                    )
                                            }

                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(comment.author.displayName)
                                                    .font(.subheadline.bold())
                                                    .foregroundStyle(RaverTheme.primaryText)
                                                Text(comment.content)
                                                    .font(.body)
                                                    .foregroundStyle(RaverTheme.primaryText)
                                                Text(comment.createdAt.feedTimeText)
                                                    .font(.caption)
                                                    .foregroundStyle(RaverTheme.secondaryText)
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .padding(.vertical, 4)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }

            Divider()

            HStack(spacing: 8) {
                TextField("说点什么...", text: $commentInput)
                    .padding(12)
                    .background(RaverTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Button("发送") {
                    Task {
                        let text = commentInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !text.isEmpty else { return }
                        do {
                            let comment = try await service.addComment(postID: post.id, content: text)
                            comments.append(comment)
                            commentInput = ""
                        } catch {
                            self.error = error.localizedDescription
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(12)
            .background(RaverTheme.background)
        }
        .background(RaverTheme.background)
        .navigationTitle("动态详情")
        .navigationDestination(item: $selectedUserForProfile) { user in
            UserProfileView(userID: user.id)
        }
        .task {
            await loadComments()
        }
        .alert("失败", isPresented: Binding(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(error ?? "")
        }
    }

    @MainActor
    private func loadComments() async {
        isLoading = true
        defer { isLoading = false }

        do {
            comments = try await service.fetchComments(postID: post.id)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
