import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

import '../../data/circle_id_api.dart';
import '../view_models/circle_id_view_model.dart';
import '../../_shared/circle_service_locator.dart';

/// Full-screen detail view for a Circle ID card.
class CircleIdDetailScreen extends StatefulWidget {
  const CircleIdDetailScreen({super.key, required this.cardId});

  final String cardId;

  @override
  State<CircleIdDetailScreen> createState() => _CircleIdDetailScreenState();
}

class _CircleIdDetailScreenState extends State<CircleIdDetailScreen> {
  CircleIdCard? _card;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCard();
  }

  Future<void> _loadCard() async {
    try {
      _card = await CircleServiceLocator.circleIdRepository
          .fetchCircleId(id: widget.cardId);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

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

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.background,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.primaryText),
          onPressed: () => context.pop(),
        ),
        title: Text(
          lt('ID卡详情', 'ID Card Detail', 'IDカード詳細'),
          style: RaverTypography.title(size: 17, color: theme.primaryText),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share_outlined, color: theme.primaryText),
            onPressed: () {
              // TODO: Implement share
            },
          ),
        ],
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : _card == null
              ? ErrorStateView(
                  title: lt('加载失败', 'Failed to Load', '読み込みに失敗しました'),
                  onRetry: () {
                    setState(() => _isLoading = true);
                    _loadCard();
                  },
                  retryLabel: lt('重试', 'Retry', '再試行'),
                )
              : _buildDetail(theme),
    );
  }

  Widget _buildDetail(RaverThemeData theme) {
    final card = _card!;
    final gradientColors = _gradients[card.gradientIndex % _gradients.length];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Large card
          Container(
            width: double.infinity,
            height: 280,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: gradientColors.first.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        backgroundImage: card.avatarUrl.isNotEmpty
                            ? NetworkImage(card.avatarUrl)
                            : null,
                        child: card.avatarUrl.isEmpty
                            ? const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 32,
                              )
                            : null,
                      ),
                      const Spacer(),
                      if (card.edmtiType.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            card.edmtiType,
                            style: RaverTypography.label(
                              size: 14,
                              color: Colors.white,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    card.nickname,
                    style: RaverTypography.headline(color: Colors.white)
                        .copyWith(fontSize: 26),
                  ),
                  if (card.tagline.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      card.tagline,
                      style: RaverTypography.body(
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    'CIRCLE ID',
                    style: RaverTypography.caption(
                      size: 10,
                      color: Colors.white.withValues(alpha: 0.5),
                      weight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatTile(
                value: '${card.checkinCount}',
                label: lt('签到', 'Check-ins', 'チェックイン'),
                theme: theme,
              ),
              _StatTile(
                value: '${card.followerCount}',
                label: lt('关注者', 'Followers', 'フォロワー'),
                theme: theme,
              ),
              _StatTile(
                value: '${card.contributionScore}',
                label: lt('贡献分', 'Contribution', '貢献'),
                theme: theme,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.theme,
  });

  final String value;
  final String label;
  final RaverThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: RaverTypography.label(
              size: 20,
              color: theme.primaryText,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: RaverTypography.caption(color: theme.secondaryText),
          ),
        ],
      ),
    );
  }
}
