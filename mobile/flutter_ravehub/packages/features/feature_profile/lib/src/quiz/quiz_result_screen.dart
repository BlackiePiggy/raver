import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_platform/raver_platform.dart';

/// Quiz result screen showing score, ranking, and wrong answers.
class QuizResultScreen extends StatelessWidget {
  const QuizResultScreen({super.key, required this.result});

  final Map<String, dynamic> result;

  Future<void> _shareResult({
    required BuildContext context,
    required int score,
    required int total,
    required int correctRate,
    required int rank,
  }) async {
    final text = lt(
      '我在 RaveHub 电音测验中答对 $score/$total 题，正确率 $correctRate%，排名 #$rank。来一起测测你的电音知识吧！',
      'I scored $score/$total on the RaveHub EDM quiz with $correctRate% accuracy and rank #$rank. Come test your electronic music knowledge!',
      'RaveHub EDMクイズで $score/$total 問正解、正答率 $correctRate%、ランキング #$rank でした。あなたもEDM知識を試してみて！',
    );
    try {
      await ShareService.shareText(text);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lt(
              '分享失败，请稍后重试',
              'Share failed. Please try again.',
              'シェアに失敗しました。もう一度お試しください。',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    final score = result['score'] as int? ?? 0;
    final total = result['totalQuestions'] as int? ?? 0;
    final correctRate = total > 0 ? (score / total * 100).toInt() : 0;
    final rank = result['rank'] as int? ?? 0;
    final wrongAnswers = (result['wrongAnswers'] as List<dynamic>?) ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(lt('测验结果', 'Quiz Result', 'クイズ結果')),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Score card
            GlassCard(
              child: Column(
                children: [
                  Text(
                    '$score',
                    style: RaverTypography.headline(
                      color: theme.accent,
                    ).copyWith(fontSize: 56),
                  ),
                  Text(
                    '$correctRate%',
                    style: RaverTypography.title(
                      size: 18,
                      color: theme.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ResultStat(
                        label: lt('正确', 'Correct', '正解'),
                        value: '$score',
                        color: Colors.green,
                        theme: theme,
                      ),
                      const SizedBox(width: 24),
                      _ResultStat(
                        label: lt('错误', 'Wrong', '不正解'),
                        value: '${total - score}',
                        color: Colors.redAccent,
                        theme: theme,
                      ),
                      const SizedBox(width: 24),
                      _ResultStat(
                        label: lt('排名', 'Rank', 'ランキング'),
                        value: '#$rank',
                        color: theme.accent,
                        theme: theme,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Wrong answers review
            if (wrongAnswers.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  lt('错题回顾', 'Wrong Answers', '不正解の振り返り'),
                  style: RaverTypography.title(
                    size: 16,
                    color: theme.primaryText,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...wrongAnswers.map((item) {
                final map = item as Map<String, dynamic>;
                final question = map['question'] as String? ?? '';
                final correctAnswer = map['correctAnswer'] as String? ?? '';
                final yourAnswer = map['yourAnswer'] as String? ?? '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        question,
                        style: RaverTypography.body(
                          size: 14,
                          color: theme.primaryText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.check_circle,
                              size: 16, color: Colors.green),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              correctAnswer,
                              style: RaverTypography.caption(
                                color: Colors.green,
                                weight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.cancel, size: 16, color: Colors.redAccent),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              yourAnswer,
                              style: RaverTypography.caption(
                                color: Colors.redAccent,
                                weight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],

            const SizedBox(height: 24),

            // Share button
            PrimaryButton(
              label: lt('分享结果', 'Share Result', '結果をシェア'),
              icon: Icons.share_outlined,
              onPressed: () => _shareResult(
                context: context,
                score: score,
                total: total,
                correctRate: correctRate,
                rank: rank,
              ),
              isExpanded: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultStat extends StatelessWidget {
  const _ResultStat({
    required this.label,
    required this.value,
    required this.color,
    required this.theme,
  });

  final String label;
  final String value;
  final Color color;
  final RaverThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: RaverTypography.title(size: 20, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: RaverTypography.caption(color: theme.secondaryText),
        ),
      ],
    );
  }
}
