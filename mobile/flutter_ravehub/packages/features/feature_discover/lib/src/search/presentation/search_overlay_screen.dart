import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

import '../../_shared/discover_service_locator.dart';
import '../data/recent_search_store.dart';
import 'search_results_screen.dart';

class SearchOverlayScreen extends StatefulWidget {
  const SearchOverlayScreen({super.key, this.onDismiss});

  final VoidCallback? onDismiss;

  @override
  State<SearchOverlayScreen> createState() => _SearchOverlayScreenState();
}

class _SearchOverlayScreenState extends State<SearchOverlayScreen> {
  final TextEditingController _queryController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late final RecentSearchStore _recentStore;

  @override
  void initState() {
    super.initState();
    _recentStore = DiscoverServiceLocator.recentSearchStore;
    _recentStore.addListener(_rebuild);
    _recentStore.initialize();
    _queryController.addListener(_rebuild);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _recentStore.removeListener(_rebuild);
    _queryController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String get _trimmedQuery => _queryController.text.trim();

  void _submit([String? rawQuery]) {
    final keyword = (rawQuery ?? _trimmedQuery).trim();
    if (keyword.isEmpty) return;
    _recentStore.record(keyword);
    _focusNode.unfocus();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SearchResultsScreen(initialQuery: keyword),
      ),
    );
  }

  void _dismiss() {
    _focusNode.unfocus();
    if (widget.onDismiss != null) {
      widget.onDismiss!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom;

    return GestureDetector(
      onTap: _dismiss,
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          key: const ValueKey('global_search_overlay_root'),
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.18),
                ),
              ),
            ),
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              tween: Tween<double>(end: -bottomInset * 0.5),
              builder: (context, offsetY, child) {
                return Transform.translate(
                  offset: Offset(0, offsetY),
                  child: child,
                );
              },
              child: SafeArea(
                child: Center(
                  child: _buildSearchPanel(theme),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchPanel(RaverThemeData theme) {
    return GestureDetector(
      onTap: _focusNode.unfocus,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        margin: const EdgeInsets.symmetric(horizontal: 18),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.card.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: theme.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(theme),
            const SizedBox(height: 16),
            _buildSearchField(theme),
            if (_recentStore.queries.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildRecentSearches(theme),
            ],
            const SizedBox(height: 16),
            _buildScopeHints(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(RaverThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 14,
                    color: theme.accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    lt('全局聚合搜索', 'Global Search', 'グローバル検索'),
                    style: RaverTypography.caption(
                      color: theme.secondaryText,
                      weight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                lt('搜索 RaveHub 里的内容', 'Search across RaveHub',
                    'RaveHub内を検索'),
                style: RaverTypography.title(
                  size: 18,
                  color: theme.primaryText,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: _dismiss,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: theme.cardBorder.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.close,
              size: 16,
              color: theme.secondaryText,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField(RaverThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13),
      height: 54,
      decoration: BoxDecoration(
        color: theme.background.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search,
            size: 22,
            color: theme.secondaryText,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _queryController,
              focusNode: _focusNode,
              style: RaverTypography.body(
                size: 16,
                color: theme.primaryText,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: lt(
                  '搜索活动、DJ、Sets、榜单…',
                  'Search events, DJs, sets, rankings…',
                  'イベント、DJ、Sets、ランキングを検索…',
                ),
                hintStyle: RaverTypography.body(
                  size: 16,
                  color: theme.secondaryText,
                ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _submit(),
            ),
          ),
          if (_trimmedQuery.isNotEmpty)
            GestureDetector(
              onTap: () => _queryController.clear(),
              child: Icon(
                Icons.cancel,
                size: 18,
                color: theme.secondaryText.withValues(alpha: 0.8),
              ),
            ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _trimmedQuery.isEmpty ? null : _submit,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: theme.accent.withValues(
                  alpha: _trimmedQuery.isEmpty ? 0.42 : 1,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSearches(RaverThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              lt('最近搜索', 'Recent Searches', '最近の検索'),
              style: RaverTypography.label(
                size: 14,
                color: theme.primaryText,
                weight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _recentStore.clear,
              child: Text(
                lt('清空', 'Clear', 'クリア'),
                style: RaverTypography.caption(
                  color: theme.secondaryText,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _recentStore.queries.map((query) {
            return GestureDetector(
              onTap: () => _submit(query),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.background.withValues(alpha: 0.64),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: theme.cardBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history, size: 12, color: theme.secondaryText),
                    const SizedBox(width: 4),
                    Text(
                      query,
                      style: RaverTypography.caption(
                        color: theme.primaryText,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildScopeHints(RaverThemeData theme) {
    final hints = _platformStatHints;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lt('在 RaveHub 探索', 'Explore on RaveHub', 'RaveHubで探索'),
          style: RaverTypography.label(
            size: 14,
            color: theme.primaryText,
            weight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            mainAxisExtent: 38,
          ),
          itemCount: hints.length,
          itemBuilder: (context, index) {
            final hint = hints[index];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: hint.color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hint.color.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                children: [
                  Icon(hint.icon, size: 14, color: hint.color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      hint.title,
                      style: RaverTypography.caption(
                        color: theme.primaryText,
                        weight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  static List<_PlatformStatHint> get _platformStatHints => [
        _PlatformStatHint(
          lt('1000+ 场电音活动', '1,000+ events', '1,000件以上のイベント'),
          Icons.calendar_today,
          const Color(0xFFF24D61),
        ),
        _PlatformStatHint(
          lt('10000+ 位 DJ', '10,000+ DJs', '10,000人以上のDJ'),
          Icons.headphones,
          const Color(0xFF6B42DB),
        ),
        _PlatformStatHint(
          lt('100+ 个现场 Set', '100+ live sets', '100件以上のSet'),
          Icons.play_circle_outline,
          const Color(0xFF3DB3C7),
        ),
        _PlatformStatHint(
          lt('热门榜单与排名', 'Charts & rankings', 'ランキング'),
          Icons.format_list_numbered,
          const Color(0xFFFAB538),
        ),
        _PlatformStatHint(
          lt('打分活动与单位', 'Ratings', '評価'),
          Icons.star,
          const Color(0xFFEB6BCC),
        ),
        _PlatformStatHint(
          lt('音乐节、厂牌、风格', 'Brands, labels, genres', 'フェス・レーベル'),
          Icons.auto_awesome,
          const Color(0xFFC278F2),
        ),
        _PlatformStatHint(
          lt('圈子动态', 'Posts', '投稿'),
          Icons.chat_bubble_outline,
          const Color(0xFF85C257),
        ),
        _PlatformStatHint(
          lt('用户与小队', 'People & squads', 'ユーザー'),
          Icons.people_outline,
          const Color(0xFFF57347),
        ),
      ];
}

class _PlatformStatHint {
  const _PlatformStatHint(this.title, this.icon, this.color);

  final String title;
  final IconData icon;
  final Color color;
}
