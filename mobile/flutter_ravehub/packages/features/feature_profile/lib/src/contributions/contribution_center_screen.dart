import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

import '../_shared/profile_service_locator.dart';
import 'view_models/contribution_view_model.dart';

/// Hub screen for viewing and managing user contributions.
class ContributionCenterScreen extends StatefulWidget {
  const ContributionCenterScreen({super.key});

  @override
  State<ContributionCenterScreen> createState() =>
      _ContributionCenterScreenState();
}

class _ContributionCenterScreenState extends State<ContributionCenterScreen> {
  late final ContributionViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ContributionViewModel(
      repository: ProfileServiceLocator.profileRepository,
    );
    _viewModel.addListener(_rebuild);
    _viewModel.load();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _viewModel.removeListener(_rebuild);
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Scaffold(
      appBar: AppBar(
        title: Text(lt('贡献中心', 'Contribution Center', '貢献センター')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: LoadPhaseBuilder<Map<String, dynamic>>(
        phase: _viewModel.phase,
        onLoading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        onFailure: (error) => ErrorStateView(
          title: lt('加载失败', 'Failed to Load', '読み込みに失敗しました'),
          error: error,
          onRetry: _viewModel.load,
          retryLabel: lt('重试', 'Retry', '再試行'),
        ),
        onSuccess: (_) => _buildContent(theme),
      ),
    );
  }

  Widget _buildContent(RaverThemeData theme) {
    return RefreshIndicator(
      color: theme.accent,
      onRefresh: _viewModel.refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Total points card
          GlassCard(
            child: Column(
              children: [
                Text(
                  lt('总积分', 'Total Points', '合計ポイント'),
                  style: RaverTypography.caption(color: theme.secondaryText),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_viewModel.totalPoints}',
                  style: RaverTypography.headline(
                    color: theme.accent,
                  ).copyWith(fontSize: 40),
                ),
                if (_viewModel.level.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _viewModel.level,
                      style: RaverTypography.label(
                        size: 13,
                        color: theme.accent,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Distribution chart
          if (_viewModel.distribution.isNotEmpty) ...[
            Text(
              lt('贡献分布', 'Contribution Distribution', '貢献分布'),
              style: RaverTypography.title(
                  size: 16, color: theme.primaryText),
            ),
            const SizedBox(height: 12),
            ..._viewModel.distribution.map((item) {
              final map = item as Map<String, dynamic>;
              final type = map['type'] as String? ?? '';
              final count = (map['count'] as int?) ?? 0;
              final maxCount = _viewModel.distribution.fold<int>(
                1,
                (max, e) {
                  final value =
                      ((e as Map<String, dynamic>)['count'] as int?) ?? 0;
                  return value > max ? value : max;
                },
              );
              final ratio =
                  maxCount > 0 ? (count / maxCount).clamp(0.05, 1.0) : 0.05;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        type,
                        style: RaverTypography.caption(
                          color: theme.primaryText,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 20,
                        decoration: BoxDecoration(
                          color: theme.cardBorder,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: ratio,
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.accent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '$count',
                        style: RaverTypography.caption(
                          color: theme.primaryText,
                          weight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 20),
          ],

          // History list
          Text(
            lt('贡献历史', 'History', '貢献履歴'),
            style: RaverTypography.title(
                size: 16, color: theme.primaryText),
          ),
          const SizedBox(height: 12),
          if (_viewModel.history.isEmpty)
            EmptyStateView(
              icon: Icons.history,
              title: lt('暂无记录', 'No History', '履歴なし'),
            )
          else
            ..._viewModel.history.map((item) {
              final map = item as Map<String, dynamic>;
              final description =
                  map['description'] as String? ?? '';
              final points = map['points'] as int? ?? 0;
              final createdAt = map['createdAt'] as String? ?? '';

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.cardBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            description,
                            style: RaverTypography.body(
                              size: 14,
                              color: theme.primaryText,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            createdAt,
                            style: RaverTypography.caption(
                                color: theme.secondaryText),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      points > 0 ? '+$points' : '$points',
                      style: RaverTypography.label(
                        size: 16,
                        color: points > 0 ? Colors.green : Colors.redAccent,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
