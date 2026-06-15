import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

import '../view_models/events_list_view_model.dart';
import '../widgets/event_card.dart';
import '../widgets/event_filter_sheet.dart';
import '../../_shared/discover_service_locator.dart';

class EventsListScreen extends StatefulWidget {
  const EventsListScreen({super.key});

  @override
  State<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends State<EventsListScreen> {
  late final EventsListViewModel _viewModel;
  final ScrollController _scrollController = ScrollController();
  EventFilterResult? _activeFilter;

  @override
  void initState() {
    super.initState();
    _viewModel = EventsListViewModel(
      repository: DiscoverServiceLocator.eventsRepository,
    );
    _viewModel.addListener(_rebuild);
    _viewModel.load();
    _scrollController.addListener(_onScroll);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _viewModel.loadMore();
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_rebuild);
    _scrollController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Column(
      children: [
        _buildFilterBar(theme),
        const SizedBox(height: 8),
        Expanded(
          child: LoadPhaseBuilder<List<dynamic>>(
            phase: _viewModel.phase,
            onLoading: () => const EventListSkeleton(),
            onEmpty: () => EmptyStateView(
              icon: Icons.event_busy,
              title: lt('暂无活动', 'No Events', 'イベントなし'),
              subtitle: lt(
                '换个条件试试',
                'Try different filters',
                '別の条件を試してください',
              ),
            ),
            onFailure: (error) => ErrorStateView(
              title: lt('加载失败', 'Failed to Load', '読み込みに失敗しました'),
              error: error,
              onRetry: _viewModel.load,
              retryLabel: lt('重试', 'Retry', '再試行'),
            ),
            onSuccess: (_) => _buildEventsList(theme),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar(RaverThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: EventTypeFilter.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = EventTypeFilter.values[index];
                final isSelected = _viewModel.eventTypeFilter == filter;

                return GestureDetector(
                  onTap: () => _viewModel.setEventTypeFilter(filter),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? theme.accent : theme.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? theme.accent : theme.cardBorder,
                      ),
                    ),
                    child: Text(
                      filter.label,
                      style: RaverTypography.label(
                        size: 13,
                        color: isSelected ? Colors.white : theme.primaryText,
                        weight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: GestureDetector(
            onTap: _showFilterSheet,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _activeFilter != null
                    ? theme.accent.withValues(alpha: 0.12)
                    : theme.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _activeFilter != null
                      ? theme.accent
                      : theme.cardBorder,
                ),
              ),
              child: Icon(
                Icons.tune,
                size: 18,
                color: _activeFilter != null
                    ? theme.accent
                    : theme.secondaryText,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showFilterSheet() async {
    final result = await EventFilterSheet.show(
      context,
      initialResult: _activeFilter,
    );
    if (result != null) {
      setState(() => _activeFilter = result);
      // Re-load with the filter applied
      _viewModel.load();
    }
  }

  Widget _buildEventsList(RaverThemeData theme) {
    return RefreshIndicator(
      color: theme.accent,
      onRefresh: _viewModel.refresh,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _viewModel.events.length + (_viewModel.canLoadMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        addRepaintBoundaries: true,
        cacheExtent: 500,
        itemBuilder: (context, index) {
          if (index >= _viewModel.events.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator.adaptive()),
            );
          }

          final event = _viewModel.events[index];
          return EventCard(
            event: event,
            onTap: () => context.push('/events/${event.id}'),
          );
        },
      ),
    );
  }
}
