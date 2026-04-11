import SwiftUI
import UIKit

struct PostDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appPush) private var appPush
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
                                    self.error = error.userFacingMessage
                                }
                            }
                        },
                        onRepostTap: {
                            Task {
                                do {
                                    post = try await service.toggleRepost(postID: post.id, shouldRepost: !post.isReposted)
                                } catch {
                                    self.error = error.userFacingMessage
                                }
                            }
                        },
                        onFollowTap: {
                            Task {
                                do {
                                    let author = try await service.toggleFollow(userID: post.author.id, shouldFollow: !post.author.isFollowing)
                                    post.author = author
                                } catch {
                                    self.error = error.userFacingMessage
                                }
                            }
                        },
                        onMessageTap: nil,
                        onAuthorTap: {
                            appPush(.userProfile(userID: post.author.id))
                        },
                        onSquadTap: nil,
                        onEditTap: nil
                    )

                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(LL("评论"))
                                .font(.headline)

                            if isLoading {
                                ProgressView()
                            } else if comments.isEmpty {
                                Text(LL("还没有评论，来抢沙发吧。"))
                                    .font(.subheadline)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            } else {
                                ForEach(comments) { comment in
                                    Button {
                                        appPush(.userProfile(userID: comment.author.id))
                                    } label: {
                                        HStack(alignment: .top, spacing: 10) {
                                            commentAvatar(comment.author)

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
            .scrollDismissesKeyboard(.interactively)

            Divider()

            HStack(spacing: 8) {
                TextField(LL("说点什么..."), text: $commentInput)
                    .submitLabel(.send)
                    .onSubmit {
                        submitComment()
                    }
                    .padding(12)
                    .background(RaverTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 1, style: .continuous))

                Button(L("发送", "Send")) {
                    submitComment()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(12)
            .background(RaverTheme.background)
        }
        .background(RaverTheme.background)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(L("收起", "Collapse")) {
                    dismissKeyboard()
                }
            }
        }
        .raverGradientNavigationChrome(title: LL("动态详情")) {
            dismiss()
        }
        .task {
            await loadComments()
        }
        .alert(LL("失败"), isPresented: Binding(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button(L("确定", "OK"), role: .cancel) {}
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
            self.error = error.userFacingMessage
        }
    }

    @ViewBuilder
    private func commentAvatar(_ user: UserSummary) -> some View {
        if let resolved = AppConfig.resolvedURLString(user.avatarURL),
           URL(string: resolved) != nil,
           resolved.hasPrefix("http://") || resolved.hasPrefix("https://") {
            ImageLoaderView(urlString: resolved)
                .background(commentAvatarFallback(user))
                .frame(width: 30, height: 30)
                .clipShape(Circle())
        } else {
            commentAvatarFallback(user)
        }
    }

    private func commentAvatarFallback(_ user: UserSummary) -> some View {
        Image(
            AppConfig.resolvedUserAvatarAssetName(
                userID: user.id,
                username: user.username,
                avatarURL: user.avatarURL
            )
        )
        .resizable()
        .scaledToFill()
        .frame(width: 30, height: 30)
        .background(RaverTheme.card)
        .clipShape(Circle())
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func submitComment() {
        Task {
            let text = commentInput.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            do {
                let comment = try await service.addComment(postID: post.id, content: text)
                comments.append(comment)
                commentInput = ""
                dismissKeyboard()
            } catch {
                self.error = error.userFacingMessage
            }
        }
    }
}
