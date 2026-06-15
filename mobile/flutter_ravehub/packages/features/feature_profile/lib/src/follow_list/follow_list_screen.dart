import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';

import '../_shared/profile_service_locator.dart';
import 'view_models/follow_list_view_model.dart';

/// Screen showing a follow list (followers or following).
class FollowListScreen extends StatefulWidget {
  const FollowListScreen({
    super.key,
    this.userId,
    required this.listType,
  });

  final String? userId;
  final String listType;

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late FollowListViewModel _currentViewModel;
  late FollowListViewModel _followingViewModel;
  late FollowListViewModel _followersViewModel;
  final ScrollController _scrollController = ScrollController();

  String get _effectiveUserId => widget.userId ?? 'me';

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.listType == 'followers' ? 1 : 0;
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: initialIndex,
    );

    _followingViewModel = FollowListViewModel(
      api: ProfileServiceLocator.followApi,
      userId: _effectiveUserId,
      listType: 'following',
    );
    _followersViewModel = FollowListViewModel(
      api: ProfileServiceLocator.followApi,
      userId: _effectiveUserId,
      listType: 'followers',
    );

    _currentViewModel =
        initialIndex == 0 ? _followingViewModel : _followersViewModel;

    _followingViewModel.addListener(_rebuild);
    _followersViewModel.addListener(_rebuild);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);

    _currentViewModel.load();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _onTabChanged() {
    final isFollowers = _tabController.index == 1;
    _currentViewModel =
        isFollowers ? _followersViewModel : _followingViewModel;

    if (_currentViewModel.users.isEmpty &&
        _currentViewModel.phase is LoadPhaseLoading) {
      _currentViewModel.load();
    }
    setState(() {});
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _currentViewModel.loadMore();
    }
  }

  @override
  void dispose() {
    _followingViewModel.removeListener(_rebuild);
    _followersViewModel.removeListener(_rebuild);
    _tabController.dispose();
    _scrollController.dispose();
    _followingViewModel.dispose();
    _followersViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.listType == 'followers'
              ? lt('粉丝', 'Followers', 'フォロワー')
              : lt('关注', 'Following', 'フォロー中'),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: RaverSegmentedControl(
              segments: [
                lt('关注', 'Following', 'フォロー中'),
                lt('粉丝', 'Followers', 'フォロワー'),
              ],
              selectedIndex: _tabController.index,
              onChanged: (index) => _tabController.animateTo(index),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUserList(_followingViewModel, theme),
          _buildUserList(_followersViewModel, theme),
        ],
      ),
    );
  }

  Widget _buildUserList(
      FollowListViewModel viewModel, RaverThemeData theme) {
    return LoadPhaseBuilder<List<UserSummary>>(
      phase: viewModel.phase,
      onLoading: () =>
          const Center(child: CircularProgressIndicator.adaptive()),
      onEmpty: () => EmptyStateView(
        icon: Icons.people_outline,
        title: viewModel.listType == 'followers'
            ? lt('暂无粉丝', 'No Followers', 'フォロワーなし')
            : lt('暂无关注', 'Not Following Anyone',
                'フォロー中のユーザーなし'),
      ),
      onFailure: (error) => ErrorStateView(
        title: lt('加载失败', 'Failed to Load', '読み込みに失敗しました'),
        error: error,
        onRetry: viewModel.load,
        retryLabel: lt('重试', 'Retry', '再試行'),
      ),
      onSuccess: (_) => RefreshIndicator(
        color: theme.accent,
        onRefresh: viewModel.refresh,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount:
              viewModel.users.length + (viewModel.canLoadMore ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (index >= viewModel.users.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator.adaptive()),
              );
            }

            final user = viewModel.users[index];
            return _UserListItem(
              user: user,
              theme: theme,
              onTap: () => context.push('/users/${user.id}'),
            );
          },
        ),
      ),
    );
  }
}

class _UserListItem extends StatelessWidget {
  const _UserListItem({
    required this.user,
    required this.theme,
    required this.onTap,
  });

  final UserSummary user;
  final RaverThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.cardBorder),
        ),
        child: Row(
          children: [
            ClipOval(
              child: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                  ? RemoteCoverImage(
                      url: user.avatarUrl!,
                      width: 44,
                      height: 44,
                    )
                  : Container(
                      width: 44,
                      height: 44,
                      color: theme.cardBorder,
                      child: Icon(Icons.person,
                          color: theme.secondaryText),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: RaverTypography.label(
                      size: 15,
                      color: theme.primaryText,
                      weight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (user.bio != null && user.bio!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      user.bio!,
                      style: RaverTypography.caption(
                          color: theme.secondaryText),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: theme.secondaryText, size: 20),
          ],
        ),
      ),
    );
  }
}
