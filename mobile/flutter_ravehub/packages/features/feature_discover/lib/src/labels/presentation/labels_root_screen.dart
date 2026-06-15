import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';

import 'label_view_model.dart';

class LabelsRootScreen extends ConsumerWidget {
  const LabelsRootScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(labelsProvider);

    if (state.isLoading && state.labels.isEmpty) {
      return const _LabelListSkeleton();
    }

    if (state.error != null && state.labels.isEmpty) {
      return ErrorStateView(
        title: lt('加载失败', 'Failed to load', 'ロードに失敗しました'),
        description: state.error,
        onRetry: () => ref.read(labelsProvider.notifier).loadLabels(),
      );
    }

    if (state.labels.isEmpty) {
      return EmptyStateView(
        icon: Icons.album_outlined,
        title: lt('暂无厂牌', 'No labels yet', 'レーベルなし'),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(labelsProvider.notifier).loadLabels(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.labels.length,
        itemBuilder: (context, index) {
          final label = state.labels[index];
          return _LabelTile(
            label: label,
            onTap: () => context.push('/labels/${label.id}'),
          );
        },
      ),
    );
  }
}

class _LabelTile extends StatelessWidget {
  const _LabelTile({required this.label, required this.onTap});
  final LearnLabel label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: label.imageUrl,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                placeholder: (_, __) => const SkeletonShimmer(
                  child: SkeletonBox(width: 56, height: 56, borderRadius: 12),
                ),
                errorWidget: (_, __, ___) => Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: RaverColors.card(Theme.of(context).brightness),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.album, size: 28),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.name,
                    style: RaverTypography.title(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label.introduction,
                    style: RaverTypography.caption(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    );
  }
}

class _LabelListSkeleton extends StatelessWidget {
  const _LabelListSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 6,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              SkeletonBox(width: 56, height: 56, borderRadius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonLine(width: 160),
                    const SizedBox(height: 8),
                    SkeletonLine(width: 220),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
