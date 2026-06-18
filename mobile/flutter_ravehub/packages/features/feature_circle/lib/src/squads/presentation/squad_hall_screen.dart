import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';

import 'view_models/squad_view_model.dart';
import 'widgets/squad_create_sheet.dart';
import '../../_shared/circle_service_locator.dart';

/// Hall / directory of squads the user can browse and join.
class SquadHallScreen extends StatefulWidget {
  const SquadHallScreen({super.key});

  @override
  State<SquadHallScreen> createState() => _SquadHallScreenState();
}

class _SquadHallScreenState extends State<SquadHallScreen> {
  late final SquadViewModel _viewModel;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _viewModel = SquadViewModel(
      repository: CircleServiceLocator.squadRepository,
    );
    _viewModel.addListener(_rebuild);
    if (_isAuthenticated) {
      _viewModel.load();
    }
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _viewModel.removeListener(_rebuild);
    _scrollController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: RaverMotion.normal,
      curve: RaverMotion.curve,
    );
  }

  void _showCreateSheet() {
    if (!_isAuthenticated) {
      _goToLogin();
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SquadCreateSheet(
        onSubmit: (name, description, avatarLocalPath) async {
          final squad = await _viewModel.createSquad(
            name: name,
            description: description,
            avatarLocalPath: avatarLocalPath,
          );
          if (squad != null && mounted) {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    if (!_isAuthenticated) {
      return RaverTabReselectionListener(
        tabIndex: 1,
        onReselected: _scrollToTop,
        child: _buildLoginRequired(theme),
      );
    }

    return RaverTabReselectionListener(
      tabIndex: 1,
      onReselected: _scrollToTop,
      child: RefreshIndicator(
        color: theme.accent,
        onRefresh: _viewModel.refresh,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Header with create button
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      lt('我的小队', 'My Squads', 'マイスクワッド'),
                      style: RaverTypography.title(
                        size: 18,
                        color: theme.primaryText,
                      ),
                    ),
                    GestureDetector(
                      onTap: _showCreateSheet,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: theme.accent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // My squads - horizontal list
            SliverToBoxAdapter(
              child: _buildMySquadsSection(theme),
            ),

            // Recommended section header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Text(
                  lt('推荐小队', 'Recommended', 'おすすめ'),
                  style: RaverTypography.title(
                    size: 18,
                    color: theme.primaryText,
                  ),
                ),
              ),
            ),

            // Recommended squads - vertical list
            _buildRecommendedSection(theme),
          ],
        ),
      ),
    );
  }

  bool get _isAuthenticated => CircleServiceLocator.currentUserId != null;

  void _goToLogin() {
    context.go('/login?returnTo=${Uri.encodeComponent('/circle')}');
  }

  Widget _buildLoginRequired(RaverThemeData theme) {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 120),
            child: Center(
              child: GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: theme.accent.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.groups_2_outlined,
                          color: theme.accent,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        lt('登录后查看小队', 'Sign in to view squads',
                            'ログインしてSquadを表示'),
                        textAlign: TextAlign.center,
                        style: RaverTypography.title(
                          size: 20,
                          color: theme.primaryText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        lt(
                          '小队推荐、加入和管理需要你的 RaveHub 账号。',
                          'Squad recommendations, joining, and management need your RaveHub account.',
                          'Squadのおすすめ、参加、管理にはRaveHubアカウントが必要です。',
                        ),
                        textAlign: TextAlign.center,
                        style: RaverTypography.body(
                          size: 14,
                          color: theme.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 20),
                      PrimaryButton(
                        label: lt('去登录', 'Sign In', 'ログイン'),
                        onPressed: _goToLogin,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMySquadsSection(RaverThemeData theme) {
    return LoadPhaseBuilder<List<SquadProfile>>(
      phase: _viewModel.mySquadsPhase,
      onLoading: () => const SizedBox(
        height: 140,
        child: Center(child: CircularProgressIndicator.adaptive()),
      ),
      onEmpty: () => Padding(
        padding: const EdgeInsets.all(16),
        child: GestureDetector(
          onTap: _showCreateSheet,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: theme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.cardBorder,
                style: BorderStyle.solid,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.group_add, size: 32, color: theme.accent),
                  const SizedBox(height: 8),
                  Text(
                    lt('创建你的第一个小队', 'Create your first squad', '最初のスクワッドを作ろう'),
                    style: RaverTypography.label(
                      size: 14,
                      color: theme.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      onFailure: (error) => Padding(
        padding: const EdgeInsets.all(16),
        child: ErrorStateView(
          title: lt('加载失败', 'Failed to Load', '読み込みに失敗しました'),
          error: error,
          onRetry: _viewModel.load,
          retryLabel: lt('重试', 'Retry', '再試行'),
        ),
      ),
      onSuccess: (squads) => SizedBox(
        height: 140,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: squads.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final squad = squads[index];
            return _MySquadCard(
              squad: squad,
              theme: theme,
              onTap: () => context.push('/circle/squads/${squad.id}'),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRecommendedSection(RaverThemeData theme) {
    return switch (_viewModel.recommendedPhase) {
      LoadPhaseLoading<List<SquadProfile>>() => const SliverToBoxAdapter(
          child: SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator.adaptive()),
          ),
        ),
      LoadPhaseEmpty<List<SquadProfile>>() => SliverToBoxAdapter(
          child: EmptyStateView(
            icon: Icons.explore_outlined,
            title: lt('暂无推荐', 'No recommendations', 'おすすめはありません'),
          ),
        ),
      LoadPhaseFailure<List<SquadProfile>>(:final error) => SliverToBoxAdapter(
          child: ErrorStateView(
            title: lt('加载失败', 'Failed to Load', '読み込みに失敗しました'),
            error: error,
            onRetry: _viewModel.load,
            retryLabel: lt('重试', 'Retry', '再試行'),
          ),
        ),
      LoadPhaseOffline<List<SquadProfile>>(:final error) => SliverToBoxAdapter(
          child: ErrorStateView(
            title: lt('网络不可用', 'No Connection', 'ネットワーク未接続'),
            error: error,
            onRetry: _viewModel.load,
            retryLabel: lt('重试', 'Retry', '再試行'),
          ),
        ),
      LoadPhaseSuccess<List<SquadProfile>>() => SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final squad = _viewModel.recommendedSquads[index];
              return _RecommendedSquadTile(
                squad: squad,
                theme: theme,
                onTap: () => context.push('/circle/squads/${squad.id}'),
                onJoin: () => _viewModel.joinSquad(squad.id),
              );
            },
            childCount: _viewModel.recommendedSquads.length,
          ),
        ),
    };
  }
}

class _MySquadCard extends StatelessWidget {
  const _MySquadCard({
    required this.squad,
    required this.theme,
    required this.onTap,
  });

  final SquadProfile squad;
  final RaverThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.cardBorder),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: theme.cardBorder,
              backgroundImage: squad.avatarUrl.isNotEmpty
                  ? NetworkImage(squad.avatarUrl)
                  : null,
              child: squad.avatarUrl.isEmpty
                  ? Icon(Icons.group, color: theme.secondaryText)
                  : null,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                squad.name,
                style: RaverTypography.label(
                  size: 13,
                  color: theme.primaryText,
                  weight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${squad.memberCount} ${lt("成员", "members", "メンバー")}',
              style: RaverTypography.caption(color: theme.secondaryText),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendedSquadTile extends StatelessWidget {
  const _RecommendedSquadTile({
    required this.squad,
    required this.theme,
    required this.onTap,
    required this.onJoin,
  });

  final SquadProfile squad;
  final RaverThemeData theme;
  final VoidCallback onTap;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.cardBorder),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: theme.cardBorder,
              backgroundImage: squad.avatarUrl.isNotEmpty
                  ? NetworkImage(squad.avatarUrl)
                  : null,
              child: squad.avatarUrl.isEmpty
                  ? Icon(Icons.group, color: theme.secondaryText)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    squad.name,
                    style: RaverTypography.label(
                      size: 15,
                      color: theme.primaryText,
                      weight: FontWeight.w600,
                    ),
                  ),
                  if (squad.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      squad.description,
                      style: RaverTypography.caption(
                        color: theme.secondaryText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    '${squad.memberCount} ${lt("成员", "members", "メンバー")}',
                    style: RaverTypography.caption(
                      size: 11,
                      color: theme.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onJoin,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.accent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  lt('加入', 'Join', '参加'),
                  style: RaverTypography.label(
                    size: 13,
                    color: Colors.white,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
