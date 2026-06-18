import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

import 'organizer_card.dart';
import 'organizer_view_model.dart';

class OrganizersRootScreen extends ConsumerStatefulWidget {
  const OrganizersRootScreen({super.key});

  @override
  ConsumerState<OrganizersRootScreen> createState() =>
      _OrganizersRootScreenState();
}

class _OrganizersRootScreenState extends ConsumerState<OrganizersRootScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(organizersProvider);

    if (state.isLoading && state.festivals.isEmpty) {
      return const OrganizerListSkeleton();
    }

    if (state.error != null && state.festivals.isEmpty) {
      return ErrorStateView(
        title: lt('加载失败', 'Failed to load', 'ロードに失敗しました'),
        description: state.error,
        onRetry: () => ref.read(organizersProvider.notifier).loadFestivals(),
      );
    }

    if (state.festivals.isEmpty) {
      return EmptyStateView(
        icon: Icons.festival_outlined,
        title: lt('暂无活动方', 'No organizers yet', 'オーガナイザーなし'),
      );
    }

    return RaverTabReselectionListener(
      tabIndex: 0,
      onReselected: _scrollToTop,
      child: RefreshIndicator(
        onRefresh: () => ref.read(organizersProvider.notifier).loadFestivals(),
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: state.festivals.length,
          itemBuilder: (context, index) {
            final festival = state.festivals[index];
            return OrganizerCard(
              festival: festival,
              onTap: () => context.push('/festivals/${festival.id}'),
            );
          },
        ),
      ),
    );
  }
}
