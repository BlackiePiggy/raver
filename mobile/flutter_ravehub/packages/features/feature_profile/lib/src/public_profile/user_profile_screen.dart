import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';

import '../_shared/profile_service_locator.dart';
import '../profile_me/presentation/widgets/profile_header.dart';
import '../profile_me/presentation/widgets/profile_stats_row.dart';
import 'view_models/user_profile_view_model.dart';

/// Public profile screen for viewing another user's profile.
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late final UserProfileViewModel _viewModel;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _viewModel = UserProfileViewModel(
      userId: widget.userId,
      repository: ProfileServiceLocator.profileRepository,
    );
    _viewModel.addListener(_rebuild);
    _viewModel.load();
    _scrollController.addListener(_onScroll);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _viewModel.loadMorePosts();
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_rebuild);
    _scrollController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LoadPhaseBuilder<UserProfile>(
        phase: _viewModel.phase,
        onLoading: () => const Center(
          child: CircularProgressIndicator.adaptive(),
        ),
        onFailure: (error) => ErrorStateView(
          title: lt('加载失败', 'Failed to Load', '読み込みに失敗しました'),
          error: error,
          onRetry: _viewModel.load,
          retryLabel: lt('重试', 'Retry', '再試行'),
        ),
        onSuccess: (profile) => _buildProfileContent(context, profile),
      ),
    );
  }

  Widget _buildProfileContent(BuildContext context, UserProfile profile) {
    final theme = context.raver;

    return RefreshIndicator(
      color: theme.accent,
      onRefresh: _viewModel.refresh,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // App bar with back button and more menu
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: theme.background,
            leading: IconButton(
              icon: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.more_horiz, color: theme.primaryText),
                onPressed: () => _showMoreMenu(context, theme),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (profile.backgroundUrl != null &&
                      profile.backgroundUrl!.isNotEmpty)
                    RemoteCoverImage(
                      url: profile.backgroundUrl!,
                      fit: BoxFit.cover,
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            theme.accent.withValues(alpha: 0.3),
                            theme.accent.withValues(alpha: 0.05),
                          ],
                        ),
                      ),
                    ),
                  Container(color: Colors.black.withValues(alpha: 0.18)),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, theme.background],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Profile header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Transform.translate(
                    offset: const Offset(0, -44),
                    child: ProfileHeader(profile: profile),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -28),
                    child: Column(
                      children: [
                        ProfileStatsRow(
                          postCount: profile.postCount,
                          followingCount: profile.followingCount,
                          followerCount: profile.followerCount,
                          friendCount: profile.friendCount,
                          onFollowingTap: () => context.push(
                            '/users/${widget.userId}/follow-list/following',
                          ),
                          onFollowersTap: () => context.push(
                            '/users/${widget.userId}/follow-list/followers',
                          ),
                          onFriendsTap: () => context.push(
                            '/users/${widget.userId}/follow-list/friends',
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Follow / Unfollow button
                        SizedBox(
                          width: double.infinity,
                          child: _viewModel.isTogglingFollow
                              ? const Center(
                                  child: CircularProgressIndicator.adaptive(),
                                )
                              : _viewModel.isFollowing
                                  ? OutlinedButton(
                                      onPressed: _viewModel.toggleFollow,
                                      style: OutlinedButton.styleFrom(
                                        side:
                                            BorderSide(color: theme.cardBorder),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10),
                                      ),
                                      child: Text(
                                        lt('已关注', 'Following', 'フォロー中'),
                                        style: RaverTypography.label(
                                          size: 14,
                                          color: theme.primaryText,
                                          weight: FontWeight.w500,
                                        ),
                                      ),
                                    )
                                  : PrimaryButton(
                                      label: lt('关注', 'Follow', 'フォロー'),
                                      onPressed: _viewModel.toggleFollow,
                                      isExpanded: true,
                                      height: 40,
                                    ),
                        ),
                        const SizedBox(height: 16),

                        // Section label
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            lt('动态', 'Posts', '投稿'),
                            style: RaverTypography.title(
                              size: 16,
                              color: theme.primaryText,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Posts list
          if (_viewModel.posts.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: EmptyStateView(
                  icon: Icons.article_outlined,
                  title: lt('暂无动态', 'No Posts', '投稿はありません'),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index >= _viewModel.posts.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child:
                          Center(child: CircularProgressIndicator.adaptive()),
                    );
                  }
                  final post = _viewModel.posts[index];
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: PostCardView(
                      post: PostCardData(
                        id: post.id,
                        authorName: post.user.displayName,
                        authorAvatarUrl: post.user.avatarUrl,
                        content: post.content,
                        createdAt: post.createdAt,
                        images: post.images ?? [],
                        videos: post.videos ?? [],
                        likeCount: post.likeCount,
                        commentCount: post.commentCount,
                        shareCount: post.shareCount,
                        isLiked: post.isLiked ?? false,
                        eventName: post.eventName,
                      ),
                    ),
                  );
                },
                childCount: _viewModel.posts.length +
                    (_viewModel.canLoadMorePosts ? 1 : 0),
              ),
            ),
        ],
      ),
    );
  }

  void _showMoreMenu(BuildContext context, RaverThemeData theme) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.flag_outlined, color: theme.primaryText),
              title: Text(
                lt('举报', 'Report', '通報'),
                style: RaverTypography.body(size: 16, color: theme.primaryText),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _viewModel.reportUser(reason: 'inappropriate');
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.block_outlined, color: Colors.redAccent),
              title: Text(
                lt('拉黑', 'Block', 'ブロック'),
                style: RaverTypography.body(size: 16, color: Colors.redAccent),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showBlockConfirmation(context, theme);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              title: Text(
                lt('取消', 'Cancel', 'キャンセル'),
                style:
                    RaverTypography.body(size: 16, color: theme.secondaryText),
                textAlign: TextAlign.center,
              ),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  void _showBlockConfirmation(BuildContext context, RaverThemeData theme) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.card,
        title: Text(
          lt('确认拉黑', 'Confirm Block', 'ブロックの確認'),
          style: RaverTypography.title(color: theme.primaryText),
        ),
        content: Text(
          lt('拉黑后将不再看到该用户的内容', 'You will no longer see content from this user',
              'ブロックすると、このユーザーのコンテンツが表示されなくなります'),
          style: RaverTypography.body(size: 14, color: theme.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(lt('取消', 'Cancel', 'キャンセル')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _viewModel.blockUser();
              context.pop();
            },
            child: Text(
              lt('确认', 'Confirm', '確認'),
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}
