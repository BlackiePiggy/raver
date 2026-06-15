import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';

import '../data/set_providers.dart';

class SetsListScreen extends ConsumerStatefulWidget {
  const SetsListScreen({super.key});

  @override
  ConsumerState<SetsListScreen> createState() => _SetsListScreenState();
}

class _SetsListScreenState extends ConsumerState<SetsListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(setsListProvider.notifier).loadIfNeeded());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(setsListProvider);
    final theme = context.raver;

    if (!state.hasLoaded && state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null && state.sets.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.secondaryText),
            const SizedBox(height: 12),
            Text(
              lt('Sets 加载失败', 'Failed to load sets',
                  'セットの読み込みに失敗しました'),
              style: TextStyle(color: theme.primaryText, fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => ref.read(setsListProvider.notifier).reload(),
              child: Text(lt('重试', 'Retry', '再試行')),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _SortBar(
          selected: state.sortBy,
          onSelected: (s) =>
              ref.read(setsListProvider.notifier).setSortBy(s),
          theme: theme,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(setsListProvider.notifier).reload(),
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              itemCount: state.sets.length + (state.canLoadMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= state.sets.length) {
                  Future.microtask(
                      () => ref.read(setsListProvider.notifier).loadMore());
                  return const Center(child: CircularProgressIndicator());
                }
                final djSet = state.sets[index];
                return _SetGridCard(djSet: djSet);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _SortBar extends StatelessWidget {
  const _SortBar({
    required this.selected,
    required this.onSelected,
    required this.theme,
  });

  final SetSortBy selected;
  final ValueChanged<SetSortBy> onSelected;
  final RaverThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      color: theme.background,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          PopupMenuButton<SetSortBy>(
            initialValue: selected,
            onSelected: onSelected,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sort, size: 18, color: theme.primaryText),
                const SizedBox(width: 4),
                Text(
                  selected.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.primaryText,
                  ),
                ),
                Icon(Icons.arrow_drop_down,
                    size: 20, color: theme.primaryText),
              ],
            ),
            itemBuilder: (_) => SetSortBy.values
                .map((s) =>
                    PopupMenuItem(value: s, child: Text(s.title)))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _SetGridCard extends StatelessWidget {
  const _SetGridCard({required this.djSet});

  final WebDJSet djSet;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    return GestureDetector(
      onTap: () => context.push('/sets/${djSet.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  djSet.thumbnailUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: djSet.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              _thumbnailFallback(theme),
                        )
                      : _thumbnailFallback(theme),
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatDuration(djSet.duration),
                        style: const TextStyle(
                            fontSize: 10, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 38),
            child: Text(
              djSet.title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.primaryText,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: djSet.djAvatarUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: djSet.djAvatarUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color: theme.cardBorder,
                            child: Icon(Icons.person,
                                size: 10, color: theme.secondaryText),
                          ),
                        )
                      : Container(
                          color: theme.cardBorder,
                          child: Icon(Icons.person,
                              size: 10, color: theme.secondaryText),
                        ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  djSet.djName.isNotEmpty
                      ? djSet.djName
                      : lt('未关联 DJ', 'No DJ Linked', 'DJ未リンク'),
                  style: TextStyle(
                      fontSize: 11, color: theme.secondaryText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _thumbnailFallback(RaverThemeData theme) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(Icons.play_circle_outline,
            size: 32, color: theme.secondaryText),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
