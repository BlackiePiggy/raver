import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';

import 'genre_sunburst_painter.dart';
import 'genre_sunburst_view_model.dart';

class GenresRootScreen extends ConsumerStatefulWidget {
  const GenresRootScreen({super.key});

  @override
  ConsumerState<GenresRootScreen> createState() => _GenresRootScreenState();
}

class _GenresRootScreenState extends ConsumerState<GenresRootScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _expandController;
  late final Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(genreSunburstProvider);

    ref.listen(genreSunburstProvider, (prev, next) {
      if ((prev?.isLoading ?? true) && !next.isLoading && next.roots.isNotEmpty) {
        _expandController.forward(from: 0);
      }
    });

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (state.error != null) {
      return ErrorStateView(
        title: lt('加载失败', 'Failed to load', 'ロードに失敗しました'),
        description: state.error,
        onRetry: () => ref.read(genreSunburstProvider.notifier).loadTree(),
      );
    }

    if (state.roots.isEmpty) {
      return EmptyStateView(
        icon: Icons.donut_large_outlined,
        title: lt('暂无流派数据', 'No genres yet', 'ジャンルデータなし'),
      );
    }

    return Column(
      children: [
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: AnimatedBuilder(
              animation: _expandAnimation,
              builder: (context, _) {
                return GestureDetector(
                  onTapUp: (details) => _onTapSunburst(details, context),
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: GenreSunburstPainter(
                        roots: state.roots,
                        expandProgress: _expandAnimation.value,
                        selectedId: state.selectedGenreId,
                        isDark: Theme.of(context).brightness == Brightness.dark,
                      ),
                      size: Size.infinite,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (state.selectedGenreId != null)
          Expanded(
            flex: 1,
            child: _SelectedGenreBar(genreId: state.selectedGenreId!),
          ),
      ],
    );
  }

  void _onTapSunburst(TapUpDetails details, BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final padding = const EdgeInsets.all(16);
    final canvasSize = Size(
      size.width - padding.horizontal,
      (size.height) * 0.75 - padding.vertical,
    );
    final localPos = details.localPosition - Offset(padding.left, padding.top);

    final state = ref.read(genreSunburstProvider);
    final painter = GenreSunburstPainter(
      roots: state.roots,
      expandProgress: 1.0,
      selectedId: state.selectedGenreId,
      isDark: Theme.of(context).brightness == Brightness.dark,
    );

    final sector = painter.hitTest(localPos, canvasSize);
    if (sector != null) {
      ref.read(genreSunburstProvider.notifier).selectGenre(sector.node.id);
    }
  }
}

class _SelectedGenreBar extends ConsumerWidget {
  const _SelectedGenreBar({required this.genreId});
  final String genreId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(genreSunburstProvider);
    final node = _findNode(state.roots, genreId);

    if (node == null) return const SizedBox.shrink();

    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  node.name,
                  style: RaverTypography.title(),
                ),
                const SizedBox(height: 4),
                Text(
                  lt('点击查看详情', 'Tap to view details', '詳細を表示'),
                  style: RaverTypography.caption(),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
            onPressed: () => context.push('/genres/$genreId'),
          ),
        ],
      ),
    );
  }

  GenreSunburstNode? _findNode(List<GenreSunburstNode> nodes, String id) {
    for (final node in nodes) {
      if (node.id == id) return node;
      final children = node.children;
      if (children != null) {
        final found = _findNode(children, id);
        if (found != null) return found;
      }
    }
    return null;
  }
}
