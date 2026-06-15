import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';

import '../_shared/profile_service_locator.dart';
import 'presentation/view_models/profile_me_view_model.dart';
import 'presentation/widgets/profile_header.dart';
import 'presentation/widgets/profile_stats_row.dart';

/// The current user's own profile screen.
class ProfileMeScreen extends StatefulWidget {
  const ProfileMeScreen({super.key});

  @override
  State<ProfileMeScreen> createState() => _ProfileMeScreenState();
}

class _ProfileMeScreenState extends State<ProfileMeScreen> {
  late final ProfileMeViewModel _viewModel;
  final ScrollController _postsScrollController = ScrollController();
  final ScrollController _savesScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _viewModel = ProfileMeViewModel(
      repository: ProfileServiceLocator.profileRepository,
    );
    _viewModel.addListener(_rebuild);
    _viewModel.load();
    _postsScrollController.addListener(_onPostsScroll);
    _savesScrollController.addListener(_onSavesScroll);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _onPostsScroll() {
    if (_postsScrollController.position.pixels >=
        _postsScrollController.position.maxScrollExtent - 200) {
      _viewModel.loadMorePosts();
    }
  }

  void _onSavesScroll() {
    if (_savesScrollController.position.pixels >=
        _savesScrollController.position.maxScrollExtent - 200) {
      _viewModel.loadMoreSaves();
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_rebuild);
    _postsScrollController.dispose();
    _savesScrollController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LoadPhaseBuilder<UserProfile>(
        phase: _viewModel.phase,
        onLoading: () => const _ProfileSkeleton(),
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
        slivers: [
          // Gradient hero background — iOS: expandedHeight 250
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: theme.background,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: Icon(Icons.settings_outlined, color: theme.primaryText),
                onPressed: () => context.push('/profile/settings'),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // iOS fallback: accent@0.55 → near-black → card gradient
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.accent.withValues(alpha: 0.55),
                          const Color(0xFF0D0D14),
                          theme.card,
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                  // Radial white highlight overlay (iOS has this)
                  Positioned(
                    top: -40,
                    left: -40,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.07),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Bottom fade to background
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            theme.background,
                          ],
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
                  // Pull avatar up to overlap the app bar
                  Transform.translate(
                    offset: const Offset(0, -44),
                    child: ProfileHeader(profile: profile),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -28),
                    child: Column(
                      children: [
                        // Stats row — iOS: Posts | Followers | Following | Friends
                        ProfileStatsRow(
                          postCount: profile.postCount,
                          followingCount: profile.followingCount,
                          followerCount: profile.followerCount,
                          friendCount: profile.friendCount,
                          onFollowingTap: () => context.push(
                            '/profile/follow-list/following',
                          ),
                          onFollowersTap: () => context.push(
                            '/profile/follow-list/followers',
                          ),
                          onFriendsTap: () => context.push(
                            '/profile/follow-list/friends',
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Edit profile button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => context.push('/profile/edit'),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: theme.cardBorder),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: Text(
                              lt('编辑资料', 'Edit Profile', 'プロフィール編集'),
                              style: RaverTypography.label(
                                size: 14,
                                color: theme.primaryText,
                                weight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Quick actions
                        _buildQuickActions(context, theme),
                        const SizedBox(height: 16),

                        // iOS tabs: Published / Saves / Likes
                        RaverSegmentedControl(
                          segments: [
                            lt('发布', 'Published', '投稿'),
                            lt('收藏', 'Saves', 'お気に入り'),
                            lt('喜欢', 'Likes', 'いいね'),
                          ],
                          selectedIndex: _viewModel.selectedTab,
                          onChanged: _viewModel.setSelectedTab,
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Tab content
          _buildTabContent(context, theme),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, RaverThemeData theme) {
    return Row(
      children: [
        _QuickActionItem(
          icon: Icons.book_outlined,
          label: lt('发布', 'Publishes', '投稿管理'),
          theme: theme,
          onTap: () => context.push('/profile/publishes'),
        ),
        const SizedBox(width: 12),
        _QuickActionItem(
          icon: Icons.emoji_events_outlined,
          label: lt('贡献', 'Contributions', '貢献'),
          theme: theme,
          onTap: () => context.push('/profile/contributions'),
        ),
        const SizedBox(width: 12),
        _QuickActionItem(
          icon: Icons.psychology_outlined,
          label: lt('测验', 'Quiz', 'クイズ'),
          theme: theme,
          onTap: () => context.push('/profile/quiz'),
        ),
        const SizedBox(width: 12),
        _QuickActionItem(
          icon: Icons.fingerprint,
          label: 'EDMTI',
          theme: theme,
          onTap: () => context.push('/profile/personality'),
        ),
      ],
    );
  }

  Widget _buildTabContent(BuildContext context, RaverThemeData theme) {
    switch (_viewModel.selectedTab) {
      case 0:
        return _buildPostsTab(context, theme);
      case 1:
        return _buildSavesTab(context, theme);
      case 2:
        return _buildLikesTab(context, theme);
      default:
        return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
  }

  Widget _buildPostsTab(BuildContext context, RaverThemeData theme) {
    if (_viewModel.posts.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: EmptyStateView(
            icon: Icons.article_outlined,
            title: lt('暂无动态', 'No Posts', '投稿はありません'),
            subtitle: lt('发布你的第一条动态吧', 'Share your first post',
                '最初の投稿をシェアしましょう'),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= _viewModel.posts.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator.adaptive()),
            );
          }
          final post = _viewModel.posts[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: PostCardView(
              post: PostCardData(
                id: post.id,
                authorName: post.user.displayName,
                authorAvatarUrl: post.user.avatarUrl,
                content: post.content,
                createdAt: post.createdAt,
                images: post.images ?? [],
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
    );
  }

  Widget _buildSavesTab(BuildContext context, RaverThemeData theme) {
    if (_viewModel.saves.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: EmptyStateView(
            icon: Icons.bookmark_outline,
            title: lt('暂无收藏', 'No Saves', 'お気に入りはありません'),
            subtitle: lt(
              '收藏你喜欢的内容',
              'Save content you like',
              '気に入ったコンテンツを保存しましょう',
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= _viewModel.saves.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator.adaptive()),
            );
          }
          final post = _viewModel.saves[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: PostCardView(
              post: PostCardData(
                id: post.id,
                authorName: post.user.displayName,
                authorAvatarUrl: post.user.avatarUrl,
                content: post.content,
                createdAt: post.createdAt,
                images: post.images ?? [],
                likeCount: post.likeCount,
                commentCount: post.commentCount,
                shareCount: post.shareCount,
                isLiked: post.isLiked ?? false,
                eventName: post.eventName,
              ),
            ),
          );
        },
        childCount: _viewModel.saves.length +
            (_viewModel.canLoadMoreSaves ? 1 : 0),
      ),
    );
  }

  Widget _buildLikesTab(BuildContext context, RaverThemeData theme) {
    // iOS: "Likes" tab — posts the user has liked
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GlassCard(
              child: Column(
                children: [
                  Icon(Icons.favorite_outline, size: 48, color: theme.accent),
                  const SizedBox(height: 12),
                  Text(
                    lt('喜欢的内容', 'Liked Content', 'いいねしたコンテンツ'),
                    style: RaverTypography.title(size: 16, color: theme.primaryText),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lt('查看你喜欢过的所有内容', 'View all content you have liked',
                        'いいねしたすべてのコンテンツを見る'),
                    style: RaverTypography.body(size: 14, color: theme.secondaryText),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.theme,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final RaverThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: theme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.cardBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: theme.accent),
              const SizedBox(height: 4),
              Text(
                label,
                style: RaverTypography.caption(
                  color: theme.primaryText,
                  weight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 60),
            const SkeletonCircle(size: 84),
            const SizedBox(height: 12),
            const SkeletonLine(width: 120, height: 20),
            const SizedBox(height: 8),
            const SkeletonLine(width: 80, height: 14),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                4,
                (_) => const Column(
                  children: [
                    SkeletonLine(width: 40, height: 18),
                    SizedBox(height: 4),
                    SkeletonLine(width: 50, height: 12),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const SkeletonBox(height: 40),
            const SizedBox(height: 16),
            const SkeletonBox(height: 36),
            const SizedBox(height: 16),
            const Expanded(child: SkeletonBox()),
          ],
        ),
      ),
    );
  }
}
