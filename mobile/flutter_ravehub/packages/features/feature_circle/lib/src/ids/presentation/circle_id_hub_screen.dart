import 'package:flutter/material.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

import '../../data/circle_id_api.dart';
import '../view_models/circle_id_view_model.dart';
import '../widgets/circle_id_composer_sheet.dart';
import '../../_shared/circle_service_locator.dart';

/// Hub for managing the user's Circle ID (raver identity cards).
class CircleIdHubScreen extends StatefulWidget {
  const CircleIdHubScreen({super.key});

  @override
  State<CircleIdHubScreen> createState() => _CircleIdHubScreenState();
}

class _CircleIdHubScreenState extends State<CircleIdHubScreen> {
  late final CircleIdViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = CircleIdViewModel(
      repository: CircleServiceLocator.circleIdRepository,
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

  void _showCreateSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CircleIdComposerSheet(
        onSubmit: (nickname, tagline, gradientIndex) async {
          final card = await _viewModel.createCard(
            nickname: nickname,
            tagline: tagline,
            gradientIndex: gradientIndex,
          );
          if (card != null && mounted) {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }

  void _showEditSheet(CircleIdCard card) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CircleIdComposerSheet(
        initialNickname: card.nickname,
        initialTagline: card.tagline,
        initialGradientIndex: card.gradientIndex,
        onSubmit: (nickname, tagline, gradientIndex) async {
          final updated = await _viewModel.updateCard(
            id: card.id,
            nickname: nickname,
            tagline: tagline,
            gradientIndex: gradientIndex,
          );
          if (updated != null && mounted) {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                lt('我的ID卡', 'My ID Cards', 'マイIDカード'),
                style: RaverTypography.title(
                  size: 18,
                  color: theme.primaryText,
                ),
              ),
              GestureDetector(
                onTap: _showCreateSheet,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: theme.accent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: LoadPhaseBuilder<List<CircleIdCard>>(
            phase: _viewModel.phase,
            onLoading: () =>
                const Center(child: CircularProgressIndicator.adaptive()),
            onEmpty: () => EmptyStateView(
              icon: Icons.badge_outlined,
              title: lt(
                '创建你的第一张ID卡',
                'Create your first ID card',
                '最初のIDカードを作ろう',
              ),
              actionLabel: lt('创建', 'Create', '作成'),
              onAction: _showCreateSheet,
            ),
            onFailure: (error) => ErrorStateView(
              title: lt('加载失败', 'Failed to Load', '読み込みに失敗しました'),
              error: error,
              onRetry: _viewModel.load,
              retryLabel: lt('重试', 'Retry', '再試行'),
            ),
            onSuccess: (cards) => _buildGrid(cards, theme),
          ),
        ),
      ],
    );
  }

  Widget _buildGrid(List<CircleIdCard> cards, RaverThemeData theme) {
    return RefreshIndicator(
      color: theme.accent,
      onRefresh: _viewModel.refresh,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: cards.length,
        itemBuilder: (context, index) {
          final card = cards[index];
          return _CircleIdCardWidget(
            card: card,
            onTap: () => _showEditSheet(card),
          );
        },
      ),
    );
  }
}

class _CircleIdCardWidget extends StatelessWidget {
  const _CircleIdCardWidget({
    required this.card,
    required this.onTap,
  });

  final CircleIdCard card;
  final VoidCallback onTap;

  static const _gradients = [
    [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    [Color(0xFFEC4899), Color(0xFFF43F5E)],
    [Color(0xFF14B8A6), Color(0xFF06B6D4)],
    [Color(0xFFF59E0B), Color(0xFFEF4444)],
    [Color(0xFF8B5CF6), Color(0xFFEC4899)],
    [Color(0xFF06B6D4), Color(0xFF3B82F6)],
  ];

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    final gradientColors =
        _gradients[card.gradientIndex % _gradients.length];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradientColors.first.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                backgroundImage: card.avatarUrl.isNotEmpty
                    ? NetworkImage(card.avatarUrl)
                    : null,
                child: card.avatarUrl.isEmpty
                    ? const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 24,
                      )
                    : null,
              ),
              const SizedBox(height: 12),

              // Nickname
              Text(
                card.nickname,
                style: RaverTypography.label(
                  size: 16,
                  color: Colors.white,
                  weight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              // EDMTI type
              if (card.edmtiType.isNotEmpty) ...[
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    card.edmtiType,
                    style: RaverTypography.caption(
                      size: 10,
                      color: Colors.white,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ],

              const Spacer(),

              // Tagline
              if (card.tagline.isNotEmpty)
                Text(
                  card.tagline,
                  style: RaverTypography.caption(
                    size: 11,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

              const SizedBox(height: 8),

              // Check-in count
              Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${card.checkinCount}',
                    style: RaverTypography.caption(
                      size: 12,
                      color: Colors.white.withValues(alpha: 0.7),
                      weight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
