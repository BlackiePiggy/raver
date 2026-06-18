import 'package:flutter/material.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';

class SearchResultCard extends StatelessWidget {
  const SearchResultCard({
    required this.item,
    required this.onTap,
    super.key,
  });

  final GlobalSearchItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Semantics(
      key: const ValueKey('search_result_card_semantics'),
      button: true,
      excludeSemantics: true,
      label: _semanticLabel,
      child: Material(
        color: theme.card,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.cardBorder),
        ),
        child: InkWell(
          onTap: onTap,
          splashColor: theme.accent.withValues(alpha: 0.08),
          highlightColor: theme.accent.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _buildThumbnail(theme),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDomainBadge(theme),
                      const SizedBox(height: 6),
                      Text(
                        item.title,
                        style: RaverTypography.label(
                          size: 14,
                          color: theme.primaryText,
                          weight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.subtitle != null &&
                          item.subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.subtitle!,
                          style: RaverTypography.caption(
                            color: theme.secondaryText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: theme.secondaryText.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _semanticLabel {
    final subtitle = item.subtitle;
    return [
      _typeLabel,
      item.title,
      if (subtitle != null && subtitle.isNotEmpty) subtitle,
    ].join(', ');
  }

  Widget _buildThumbnail(RaverThemeData theme) {
    final imageUrl = item.imageUrl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 58,
        height: 58,
        child: imageUrl != null && imageUrl.isNotEmpty
            ? RemoteCoverImage(
                url: imageUrl,
                width: 58,
                height: 58,
                fit: BoxFit.cover,
              )
            : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _colorForType.withValues(alpha: 0.34),
                      theme.background,
                    ],
                  ),
                ),
                child: Icon(
                  _iconForType,
                  size: 22,
                  color: _colorForType,
                ),
              ),
      ),
    );
  }

  Widget _buildDomainBadge(RaverThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: _colorForType.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: _colorForType.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconForType, size: 10, color: _colorForType),
          const SizedBox(width: 3),
          Text(
            _typeLabel,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _colorForType,
            ),
          ),
        ],
      ),
    );
  }

  IconData get _iconForType => switch (item.type) {
        GlobalSearchItemType.event => Icons.calendar_today,
        GlobalSearchItemType.news => Icons.article,
        GlobalSearchItemType.dj => Icons.headphones,
        GlobalSearchItemType.set => Icons.play_circle_outline,
        GlobalSearchItemType.rankingBoard ||
        GlobalSearchItemType.rankingEntry =>
          Icons.format_list_numbered,
        GlobalSearchItemType.ratingEvent ||
        GlobalSearchItemType.ratingUnit =>
          Icons.star,
        GlobalSearchItemType.post => Icons.chat_bubble_outline,
        GlobalSearchItemType.label => Icons.label,
        GlobalSearchItemType.festival => Icons.auto_awesome,
        GlobalSearchItemType.genre => Icons.park,
        GlobalSearchItemType.user => Icons.person,
        GlobalSearchItemType.squad => Icons.people,
      };

  Color get _colorForType => switch (item.type) {
        GlobalSearchItemType.event => const Color(0xFFF88A35),
        GlobalSearchItemType.news => const Color(0xFFFB9E38),
        GlobalSearchItemType.dj => const Color(0xFF70C754),
        GlobalSearchItemType.set => const Color(0xFF4DABF7),
        GlobalSearchItemType.rankingBoard ||
        GlobalSearchItemType.rankingEntry =>
          const Color(0xFFFAB538),
        GlobalSearchItemType.ratingEvent ||
        GlobalSearchItemType.ratingUnit =>
          const Color(0xFFEB6BCC),
        GlobalSearchItemType.post => const Color(0xFFF24D61),
        GlobalSearchItemType.label => const Color(0xFF9E80EB),
        GlobalSearchItemType.festival => const Color(0xFFC278F2),
        GlobalSearchItemType.genre => const Color(0xFF3DB3C7),
        GlobalSearchItemType.user => const Color(0xFFF57347),
        GlobalSearchItemType.squad => const Color(0xFFF57347),
      };

  String get _typeLabel => switch (item.type) {
        GlobalSearchItemType.event => lt('活动', 'Event', 'イベント'),
        GlobalSearchItemType.news => lt('资讯', 'News', 'ニュース'),
        GlobalSearchItemType.dj => 'DJ',
        GlobalSearchItemType.set => 'Set',
        GlobalSearchItemType.rankingBoard => lt('榜单', 'Ranking', 'ランキング'),
        GlobalSearchItemType.rankingEntry => lt('榜单', 'Ranking', 'ランキング'),
        GlobalSearchItemType.ratingEvent => lt('打分', 'Rating', '評価'),
        GlobalSearchItemType.ratingUnit => lt('打分', 'Rating', '評価'),
        GlobalSearchItemType.post => lt('圈子', 'Post', '投稿'),
        GlobalSearchItemType.label => lt('厂牌', 'Label', 'レーベル'),
        GlobalSearchItemType.festival => lt('品牌', 'Brand', 'ブランド'),
        GlobalSearchItemType.genre => lt('风格树', 'Genre', 'ジャンル'),
        GlobalSearchItemType.user => lt('用户', 'User', 'ユーザー'),
        GlobalSearchItemType.squad => lt('小队', 'Squad', 'スクワッド'),
      };
}
