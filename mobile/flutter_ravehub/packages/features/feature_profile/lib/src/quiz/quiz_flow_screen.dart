import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

import '../_shared/profile_service_locator.dart';
import 'view_models/quiz_view_model.dart';
import 'quiz_result_screen.dart';

/// Multi-step quiz flow screen for genre/preference discovery.
class QuizFlowScreen extends StatefulWidget {
  const QuizFlowScreen({super.key});

  @override
  State<QuizFlowScreen> createState() => _QuizFlowScreenState();
}

class _QuizFlowScreenState extends State<QuizFlowScreen> {
  late final QuizViewModel _viewModel;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _viewModel = QuizViewModel(api: ProfileServiceLocator.quizApi);
    _pageController = PageController();
    _viewModel.addListener(_onChanged);
    _viewModel.load();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});

    if (_viewModel.hasResult && _viewModel.result != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => QuizResultScreen(result: _viewModel.result!),
        ),
      );
      return;
    }

    // Sync PageView with current index
    if (_pageController.hasClients &&
        _pageController.page?.round() != _viewModel.currentIndex) {
      _pageController.animateToPage(
        _viewModel.currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onChanged);
    _pageController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Scaffold(
      appBar: AppBar(
        title: Text(lt('知识测验', 'Quiz', 'クイズ')),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: LoadPhaseBuilder<List<Map<String, dynamic>>>(
        phase: _viewModel.phase,
        onLoading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        onEmpty: () => EmptyStateView(
          icon: Icons.quiz_outlined,
          title: lt('暂无题目', 'No Questions', '問題がありません'),
        ),
        onFailure: (error) => ErrorStateView(
          title: lt('加载失败', 'Failed to Load', '読み込みに失敗しました'),
          error: error,
          onRetry: _viewModel.load,
          retryLabel: lt('重试', 'Retry', '再試行'),
        ),
        onSuccess: (_) => _buildQuizContent(theme),
      ),
    );
  }

  Widget _buildQuizContent(RaverThemeData theme) {
    if (_viewModel.isSubmitting) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator.adaptive(),
            const SizedBox(height: 16),
            Text(
              lt('正在提交...', 'Submitting...', '送信中...'),
              style: RaverTypography.body(size: 16, color: theme.secondaryText),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Progress bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _viewModel.progressText,
                    style: RaverTypography.label(
                      size: 14,
                      color: theme.primaryText,
                      weight: FontWeight.w600,
                    ),
                  ),
                  // Timer
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _viewModel.remainingSeconds <= 10
                          ? Colors.redAccent.withValues(alpha: 0.12)
                          : theme.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_viewModel.remainingSeconds}s',
                      style: RaverTypography.label(
                        size: 13,
                        color: _viewModel.remainingSeconds <= 10
                            ? Colors.redAccent
                            : theme.accent,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _viewModel.progress,
                  backgroundColor: theme.cardBorder,
                  valueColor: AlwaysStoppedAnimation<Color>(theme.accent),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),

        // Questions PageView
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _viewModel.totalQuestions,
            itemBuilder: (context, index) {
              final question = _viewModel.questions[index];
              return _buildQuestion(theme, question, index);
            },
          ),
        ),

        // Navigation buttons
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (_viewModel.currentIndex > 0) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _viewModel.previousQuestion,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: theme.cardBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      lt('上一题', 'Previous', '前の問題'),
                      style: RaverTypography.label(
                        size: 14,
                        color: theme.primaryText,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: PrimaryButton(
                  label:
                      _viewModel.currentIndex == _viewModel.totalQuestions - 1
                          ? lt('提交', 'Submit', '送信')
                          : lt('下一题', 'Next', '次の問題'),
                  onPressed: _viewModel.currentAnswer != null
                      ? _viewModel.nextQuestion
                      : null,
                  isExpanded: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuestion(
    RaverThemeData theme,
    Map<String, dynamic> question,
    int questionIndex,
  ) {
    final text = question['text'] as String? ?? '';
    final stemImageUrl = question['stemImageUrl'] as String?;
    final options = (question['options'] as List<dynamic>?) ?? [];
    final optionImages = (question['optionImages'] as List<dynamic>?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: RaverTypography.title(
              size: 18,
              color: theme.primaryText,
            ),
          ),
          if (_isRenderableImageUrl(stemImageUrl)) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  stemImageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          ...options.asMap().entries.map((entry) {
            final optionIndex = entry.key;
            final option = entry.value as String? ?? '';
            final optionImageUrl = optionIndex < optionImages.length
                ? optionImages[optionIndex] as String?
                : null;
            final isSelected = _viewModel.currentAnswer == optionIndex;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => _viewModel.selectAnswer(optionIndex),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.accent.withValues(alpha: 0.12)
                        : theme.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? theme.accent : theme.cardBorder,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isSelected ? theme.accent : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? theme.accent : theme.cardBorder,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                                size: 16, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (option.isNotEmpty)
                              Text(
                                option,
                                style: RaverTypography.body(
                                  size: 15,
                                  color: theme.primaryText,
                                ),
                              ),
                            if (_isRenderableImageUrl(optionImageUrl)) ...[
                              if (option.isNotEmpty) const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: Image.network(
                                    optionImageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  bool _isRenderableImageUrl(String? value) {
    if (value == null || value.trim().isEmpty) return false;
    final uri = Uri.tryParse(value.trim());
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }
}
