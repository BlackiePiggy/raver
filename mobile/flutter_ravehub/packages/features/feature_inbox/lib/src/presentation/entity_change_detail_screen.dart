import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

/// Detail screen showing what changed for a followed entity (event/DJ/brand).
///
/// Displays the entity information, a list of changed fields, and
/// a before/after comparison for each field.
class EntityChangeDetailScreen extends StatelessWidget {
  const EntityChangeDetailScreen({
    super.key,
    required this.entityType,
    required this.entityId,
    required this.entityName,
    required this.changeType,
    required this.summary,
    this.updateTitle,
    this.targetType,
    this.targetId,
    this.imageUrl,
  });

  final String entityType;
  final String entityId;
  final String entityName;
  final String changeType;
  final String summary;
  final String? updateTitle;
  final String? targetType;
  final String? targetId;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        title: Text(
          lt('变更详情', 'Change Detail', '変更詳細'),
          style: RaverTypography.title(color: theme.primaryText),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Entity header
            _buildEntityHeader(theme),
            const SizedBox(height: 20),
            // Change type and summary
            _buildChangeInfo(theme),
            const SizedBox(height: 24),
            _buildActions(context, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildEntityHeader(RaverThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Row(
        children: [
          if (imageUrl != null && imageUrl!.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: RemoteCoverImage(url: imageUrl!, width: 56, height: 56),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _entityTypeLabel(entityType),
                    style: RaverTypography.caption(
                      color: theme.accent,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  entityName,
                  style: RaverTypography.title(
                    size: 18,
                    color: theme.primaryText,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChangeInfo(RaverThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lt('变更类型', 'Change Type', '変更タイプ'),
          style: RaverTypography.label(
            size: 14,
            color: theme.secondaryText,
            weight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _changeTypeColor(changeType).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            _changeTypeLabel(changeType),
            style: RaverTypography.label(
              size: 13,
              color: _changeTypeColor(changeType),
              weight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (updateTitle != null && updateTitle!.isNotEmpty) ...[
          Text(
            lt('更新标题', 'Update Title', '更新タイトル'),
            style: RaverTypography.label(
              size: 14,
              color: theme.secondaryText,
              weight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            updateTitle!,
            style: RaverTypography.title(size: 16, color: theme.primaryText),
          ),
          const SizedBox(height: 14),
        ],
        Text(
          lt('变更摘要', 'Summary', '変更概要'),
          style: RaverTypography.label(
            size: 14,
            color: theme.secondaryText,
            weight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          summary.isEmpty ? lt('暂无摘要', 'No summary', '概要なし') : summary,
          style: RaverTypography.body(size: 14, color: theme.primaryText),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context, RaverThemeData theme) {
    final targetRoute = _targetRoute(targetType, targetId);
    final entityRoute = _entityRoute(entityType, entityId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lt('下一步', 'Next', '次の操作'),
          style: RaverTypography.title(size: 16, color: theme.primaryText),
        ),
        const SizedBox(height: 12),
        if (targetRoute != null)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.push(targetRoute),
              icon: const Icon(Icons.open_in_new),
              label: Text(_targetActionLabel(targetType)),
            ),
          ),
        if (entityRoute != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push(entityRoute),
              icon: const Icon(Icons.account_tree_outlined),
              label: Text(_entityActionLabel(entityType)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: theme.cardBorder),
              ),
            ),
          ),
        ],
        if (targetRoute == null && entityRoute == null)
          Text(
            lt(
              '当前更新没有可跳转的目标页面',
              'This update has no navigable target yet',
              'この更新には遷移できる対象がありません',
            ),
            style: RaverTypography.body(size: 14, color: theme.secondaryText),
          ),
      ],
    );
  }

  static String _entityTypeLabel(String type) => switch (type) {
    'event' => lt('活动', 'Event', 'イベント'),
    'dj' => 'DJ',
    'brand' => lt('厂牌', 'Brand', 'ブランド'),
    _ => type,
  };

  static String _changeTypeLabel(String type) => switch (type.toLowerCase()) {
    'event' => lt('活动', 'Event', 'イベント'),
    'news' => lt('资讯', 'News', 'ニュース'),
    'cancelled' => lt('已取消', 'Cancelled', 'キャンセル'),
    'lineup_update' => lt('阵容更新', 'Lineup', 'ラインナップ'),
    'schedule_update' => lt('时间更新', 'Schedule', 'スケジュール'),
    'venue_update' => lt('场地更新', 'Venue', '会場'),
    _ => type.isEmpty ? lt('更新', 'Update', '更新') : type,
  };

  static Color _changeTypeColor(String type) => switch (type) {
    'cancelled' => const Color(0xFFD93636),
    'lineup_update' => const Color(0xFF6B42DB),
    'schedule_update' => const Color(0xFFF88A35),
    'event' => const Color(0xFF4DABF7),
    'news' => const Color(0xFF70C754),
    'venue_update' => const Color(0xFF4DABF7),
    _ => const Color(0xFF70C754),
  };

  static String? _targetRoute(String? type, String? id) {
    if (id == null || id.isEmpty) return null;
    switch (type?.toLowerCase()) {
      case 'event':
        return '/events/$id';
      case 'news':
        return '/news/$id';
    }
    return null;
  }

  static String? _entityRoute(String type, String id) {
    if (id.isEmpty) return null;
    switch (type.toLowerCase()) {
      case 'event':
        return '/events/$id';
      case 'dj':
        return '/djs/$id';
    }
    return null;
  }

  static String _targetActionLabel(String? type) {
    switch (type?.toLowerCase()) {
      case 'event':
        return lt('查看活动', 'Open Event', 'イベントを見る');
      case 'news':
        return lt('查看资讯', 'Open News', 'ニュースを見る');
      default:
        return lt('查看更新', 'Open Update', '更新を見る');
    }
  }

  static String _entityActionLabel(String type) {
    switch (type.toLowerCase()) {
      case 'event':
        return lt('查看关注活动', 'Open Followed Event', 'フォローイベントを見る');
      case 'dj':
        return lt('查看关注 DJ', 'Open Followed DJ', 'フォロー DJ を見る');
      default:
        return lt('查看来源', 'Open Source', 'ソースを見る');
    }
  }
}
