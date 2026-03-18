import SwiftUI

struct PostDetailView: View {
    @EnvironmentObject private var appState: AppState
    @State private var post: Post
    private let service: SocialService

    @State private var comments: [Comment] = []
    @State private var commentInput = ""
    @State private var isLoading = false
    @State private var error: String?

    init(post: Post, service: SocialService) {
        self._post = State(initialValue: post)
        self.service = service
    }

    var body: some View {
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
                    onAuthorTap: nil,
                    onSquadTap: nil
                )

                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("评论")
                            .font(.headline)

                        HStack {
                            TextField("说点什么...", text: $commentInput)
                                .padding(12)
                                .background(RaverTheme.background)
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

                        if isLoading {
                            ProgressView()
                        } else if comments.isEmpty {
                            Text("还没有评论，来抢沙发吧。")
                                .font(.subheadline)
                                .foregroundStyle(RaverTheme.secondaryText)
                        } else {
                            ForEach(comments) { comment in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(comment.author.displayName)
                                        .font(.subheadline.bold())
                                    Text(comment.content)
                                        .font(.body)
                                    Text(comment.createdAt.feedTimeText)
                                        .font(.caption)
                                        .foregroundStyle(RaverTheme.secondaryText)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(RaverTheme.background)
        .navigationTitle("动态详情")
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
