import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';

import '../data/dj_providers.dart';

class DjsListScreen extends ConsumerStatefulWidget {
  const DjsListScreen({super.key});

  @override
  ConsumerState<DjsListScreen> createState() => _DjsListScreenState();
}

class _DjsListScreenState extends ConsumerState<DjsListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(djsListProvider.notifier).loadIfNeeded());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(djsListProvider);
    final theme = context.raver;

    if (!state.hasLoaded && state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null && state.djs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.secondaryText),
            const SizedBox(height: 12),
            Text(
              lt('DJ 列表加载失败', 'Failed to load DJs',
                  'DJ一覧を読み込めませんでした'),
              style: TextStyle(color: theme.primaryText, fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => ref.read(djsListProvider.notifier).reload(),
              child: Text(lt('重试', 'Retry', '再試行')),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(djsListProvider.notifier).reload(),
      child: CustomScrollView(
        cacheExtent: 500,
        slivers: [
          if (state.carouselDJs.isNotEmpty)
            SliverToBoxAdapter(
              child: _SpotlightCarousel(
                djs: state.carouselDJs,
                theme: theme,
              ),
            ),
          if (state.djs.isNotEmpty) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  lt('随机热门 DJ', 'Hot DJs', 'ホット DJ'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.primaryText,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final dj = state.djs[index];
                    return _DjListTile(dj: dj);
                  },
                  childCount: state.djs.length,
                  addRepaintBoundaries: true,
                ),
              ),
            ),
          ],
          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      ),
    );
  }
}

class _SpotlightCarousel extends StatelessWidget {
  const _SpotlightCarousel({required this.djs, required this.theme});

  final List<WebDJ> djs;
  final RaverThemeData theme;

  @override
  Widget build(BuildContext context) {
    final displayDJs = djs.take(10).toList();
    return SizedBox(
      height: 280,
      child: PageView.builder(
        controller: PageController(viewportFraction: 0.8),
        itemCount: displayDJs.length,
        itemBuilder: (context, index) {
          final dj = displayDJs[index];
          return GestureDetector(
            onTap: () => context.push('/djs/${dj.id}'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    dj.avatarUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: dj.avatarUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                _fallbackGradient(),
                          )
                        : _fallbackGradient(),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            dj.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          if (dj.genres != null && dj.genres!.isNotEmpty)
                            Text(
                              dj.genres!.take(3).join(' · '),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.people,
                                  size: 14, color: Colors.white70),
                              const SizedBox(width: 4),
                              Text(
                                '${dj.followerCount}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _fallbackGradient() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(Icons.person, size: 48, color: theme.secondaryText),
      ),
    );
  }
}

class _DjListTile extends StatelessWidget {
  const _DjListTile({required this.dj});

  final WebDJ dj;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    return InkWell(
      onTap: () => context.push('/djs/${dj.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 56,
                height: 56,
                child: dj.avatarUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: dj.avatarUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            _avatarFallback(theme),
                      )
                    : _avatarFallback(theme),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dj.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.primaryText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (dj.country.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      dj.country,
                      style: TextStyle(
                          fontSize: 12, color: theme.secondaryText),
                    ),
                  ],
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people, size: 14, color: theme.secondaryText),
                const SizedBox(width: 4),
                Text(
                  '${dj.followerCount}',
                  style:
                      TextStyle(fontSize: 12, color: theme.secondaryText),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarFallback(RaverThemeData theme) {
    return Container(
      color: theme.card,
      child: Icon(Icons.person, size: 28, color: theme.secondaryText),
    );
  }
}
