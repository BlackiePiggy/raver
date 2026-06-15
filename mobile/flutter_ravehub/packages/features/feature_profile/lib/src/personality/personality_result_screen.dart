import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

import 'widgets/personality_share_card.dart';

/// Personality result screen showing EDMTI type and dimensions.
class PersonalityResultScreen extends StatelessWidget {
  const PersonalityResultScreen({super.key, required this.result});

  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    final typeCode = result['typeCode'] as String? ?? 'XXXX';
    final typeDescription =
        result['description'] as String? ?? '';
    final dimensions =
        (result['dimensions'] as List<dynamic>?) ?? [];
    final matchedDJs =
        (result['matchedDJs'] as List<dynamic>?) ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text('EDMTI'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Type code
            GlassCard(
              child: Column(
                children: [
                  Text(
                    lt('你的 EDMTI 类型', 'Your EDMTI Type',
                        'あなたのEDMTIタイプ'),
                    style: RaverTypography.caption(
                        color: theme.secondaryText),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    typeCode,
                    style: RaverTypography.headline(
                      color: theme.accent,
                    ).copyWith(
                      fontSize: 48,
                      letterSpacing: 8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    typeDescription,
                    style: RaverTypography.body(
                      size: 14,
                      color: theme.primaryText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Dimension bars
            if (dimensions.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  lt('特征维度', 'Dimensions', '特性ディメンション'),
                  style: RaverTypography.title(
                    size: 16,
                    color: theme.primaryText,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...dimensions.map((dim) {
                final map = dim as Map<String, dynamic>;
                final leftLabel = map['leftLabel'] as String? ?? '';
                final rightLabel = map['rightLabel'] as String? ?? '';
                final ratio =
                    (map['ratio'] as num?)?.toDouble() ?? 0.5;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _DimensionBar(
                    leftLabel: leftLabel,
                    rightLabel: rightLabel,
                    ratio: ratio,
                    theme: theme,
                  ),
                );
              }),
              const SizedBox(height: 20),
            ],

            // Matched DJs
            if (matchedDJs.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  lt('匹配名人 DJ', 'Matched DJs', 'マッチしたDJ'),
                  style: RaverTypography.title(
                    size: 16,
                    color: theme.primaryText,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: matchedDJs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final dj = matchedDJs[index] as Map<String, dynamic>;
                    final name = dj['name'] as String? ?? '';
                    final avatarUrl = dj['avatarUrl'] as String? ?? '';

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipOval(
                          child: avatarUrl.isNotEmpty
                              ? RemoteCoverImage(
                                  url: avatarUrl,
                                  width: 72,
                                  height: 72,
                                )
                              : Container(
                                  width: 72,
                                  height: 72,
                                  color: theme.cardBorder,
                                  child: Icon(Icons.person,
                                      color: theme.secondaryText),
                                ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          name,
                          style: RaverTypography.caption(
                            color: theme.primaryText,
                            weight: FontWeight.w500,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Share button
            PrimaryButton(
              label: lt('生成分享卡片', 'Generate Share Card',
                  'シェアカードを生成'),
              icon: Icons.share_outlined,
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (_) => Dialog(
                    backgroundColor: Colors.transparent,
                    child: PersonalityShareCard(
                      typeCode: typeCode,
                      description: typeDescription,
                      theme: theme,
                    ),
                  ),
                );
              },
              isExpanded: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _DimensionBar extends StatelessWidget {
  const _DimensionBar({
    required this.leftLabel,
    required this.rightLabel,
    required this.ratio,
    required this.theme,
  });

  final String leftLabel;
  final String rightLabel;
  final double ratio;
  final RaverThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              leftLabel,
              style: RaverTypography.caption(
                color: theme.primaryText,
                weight: FontWeight.w500,
              ),
            ),
            Text(
              rightLabel,
              style: RaverTypography.caption(
                color: theme.primaryText,
                weight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 12,
          decoration: BoxDecoration(
            color: theme.cardBorder,
            borderRadius: BorderRadius.circular(6),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: ratio.clamp(0.05, 0.95),
            child: Container(
              decoration: BoxDecoration(
                color: theme.accent,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${(ratio * 100).toInt()}%',
              style: RaverTypography.caption(
                color: theme.accent,
                weight: FontWeight.w600,
              ),
            ),
            Text(
              '${((1 - ratio) * 100).toInt()}%',
              style: RaverTypography.caption(
                color: theme.secondaryText,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
