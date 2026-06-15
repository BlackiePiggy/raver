import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';

import '../view_models/squad_view_model.dart';
import '../widgets/squad_member_list.dart';
import '../../_shared/circle_service_locator.dart';

/// Profile page for a specific squad.
class SquadProfileScreen extends StatefulWidget {
  const SquadProfileScreen({super.key, required this.squadId});

  final String squadId;

  @override
  State<SquadProfileScreen> createState() => _SquadProfileScreenState();
}

class _SquadProfileScreenState extends State<SquadProfileScreen> {
  late final SquadProfileViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = SquadProfileViewModel(
      squadId: widget.squadId,
      repository: CircleServiceLocator.squadRepository,
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
        backgroundColor: theme.background,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.primaryText),
          onPressed: () => context.pop(),
        ),
        title: Text(
          lt('小队', 'Squad', 'スクワッド'),
          style: RaverTypography.title(size: 17, color: theme.primaryText),
        ),
        actions: [
          if (_viewModel.isOwner)
            IconButton(
              icon: Icon(Icons.settings, color: theme.primaryText),
              onPressed: () => context.push(
                '/circle/squads/${widget.squadId}/manage',
              ),
            ),
        ],
        elevation: 0,
      ),
      body: LoadPhaseBuilder<SquadProfile>(
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
        onSuccess: (squad) => _buildContent(squad, theme),
      ),
    );
  }

  Widget _buildContent(SquadProfile squad, RaverThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section
          _buildHeader(squad, theme),

          const SizedBox(height: 20),

          // Members section
          _buildSectionHeader(
            theme,
            lt('成员', 'Members', 'メンバー'),
            '${_viewModel.members.length}',
          ),
          const SizedBox(height: 8),
          if (_viewModel.members.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SquadMemberList(
                members: _viewModel.members,
                maxVisible: 8,
                theme: theme,
              ),
            ),

          const SizedBox(height: 20),

          // Offline activities section
          _buildSectionHeader(
            theme,
            lt('线下活动', 'Activities', 'オフライン活動'),
            '${_viewModel.activities.length}',
            onViewAll: _viewModel.activities.length > 3
                ? () => context.push(
                      '/circle/squads/${widget.squadId}/activities',
                    )
                : null,
          ),
          const SizedBox(height: 8),
          if (_viewModel.activities.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                lt('暂无线下活动', 'No activities yet', 'まだ活動がありません'),
                style: RaverTypography.body(
                  size: 14,
                  color: theme.secondaryText,
                ),
              ),
            )
          else
            ..._viewModel.activities.take(3).map(
                  (activity) => _ActivityTile(
                    activity: activity,
                    theme: theme,
                  ),
                ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeader(SquadProfile squad, RaverThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: theme.cardBorder,
            backgroundImage: squad.avatarUrl.isNotEmpty
                ? NetworkImage(squad.avatarUrl)
                : null,
            child: squad.avatarUrl.isEmpty
                ? Icon(Icons.group, size: 40, color: theme.secondaryText)
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            squad.name,
            style: RaverTypography.headline(color: theme.primaryText)
                .copyWith(fontSize: 22),
            textAlign: TextAlign.center,
          ),
          if (squad.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              squad.description,
              style: RaverTypography.body(
                size: 14,
                color: theme.secondaryText,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StatChip(
                label: lt('成员', 'Members', 'メンバー'),
                value: '${squad.memberCount}',
                theme: theme,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    RaverThemeData theme,
    String title,
    String count, {
    VoidCallback? onViewAll,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            title,
            style: RaverTypography.title(size: 16, color: theme.primaryText),
          ),
          const SizedBox(width: 6),
          Text(
            count,
            style: RaverTypography.caption(color: theme.secondaryText),
          ),
          const Spacer(),
          if (onViewAll != null)
            GestureDetector(
              onTap: onViewAll,
              child: Text(
                lt('查看全部', 'View All', 'すべて見る'),
                style: RaverTypography.label(
                  size: 13,
                  color: theme.accent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.theme,
  });

  final String label;
  final String value;
  final RaverThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: RaverTypography.label(
              size: 18,
              color: theme.primaryText,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: RaverTypography.caption(color: theme.secondaryText),
          ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.activity,
    required this.theme,
  });

  final SquadOfflineActivity activity;
  final RaverThemeData theme;

  @override
  Widget build(BuildContext context) {
    final isOngoing = activity.status == 'ongoing';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isOngoing ? Colors.green : theme.secondaryText,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.eventName,
                  style: RaverTypography.label(
                    size: 14,
                    color: theme.primaryText,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDateRange(activity.startedAt, activity.endedAt),
                  style: RaverTypography.caption(
                    color: theme.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isOngoing
                  ? Colors.green.withValues(alpha: 0.12)
                  : theme.cardBorder,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isOngoing
                  ? lt('进行中', 'Ongoing', '進行中')
                  : lt('已结束', 'Ended', '終了'),
              style: RaverTypography.caption(
                size: 11,
                color: isOngoing ? Colors.green : theme.secondaryText,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDateRange(String start, String end) {
    try {
      final s = DateTime.parse(start);
      final e = DateTime.parse(end);
      return '${s.month}/${s.day} - ${e.month}/${e.day}';
    } catch (_) {
      return '$start - $end';
    }
  }
}
