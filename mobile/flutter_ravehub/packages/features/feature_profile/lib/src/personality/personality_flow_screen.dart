import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

import '../_shared/profile_service_locator.dart';
import 'view_models/personality_view_model.dart';
import 'personality_result_screen.dart';

/// Multi-step personality flow screen for raver personality type.
class PersonalityFlowScreen extends StatefulWidget {
  const PersonalityFlowScreen({super.key});

  @override
  State<PersonalityFlowScreen> createState() => _PersonalityFlowScreenState();
}

class _PersonalityFlowScreenState extends State<PersonalityFlowScreen> {
  late final PersonalityViewModel _viewModel;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _viewModel =
        PersonalityViewModel(api: ProfileServiceLocator.personalityApi);
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
          builder: (_) =>
              PersonalityResultScreen(result: _viewModel.result!),
        ),
      );
      return;
    }

    // Sync PageView
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
        title: Text('EDMTI'),
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
          icon: Icons.psychology_outlined,
          title: lt('暂无题目', 'No Questions', '問題がありません'),
        ),
        onFailure: (error) => ErrorStateView(
          title: lt('加载失败', 'Failed to Load', '読み込みに失敗しました'),
          error: error,
          onRetry: _viewModel.load,
          retryLabel: lt('重试', 'Retry', '再試行'),
        ),
        onSuccess: (_) => _buildFlowContent(theme),
      ),
    );
  }

  Widget _buildFlowContent(RaverThemeData theme) {
    if (_viewModel.isSubmitting) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator.adaptive(),
            const SizedBox(height: 16),
            Text(
              lt('正在分析你的性格...', 'Analyzing your personality...',
                  'あなたの性格を分析中...'),
              style: RaverTypography.body(
                  size: 16, color: theme.secondaryText),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Progress bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _viewModel.progress,
              backgroundColor: theme.cardBorder,
              valueColor: AlwaysStoppedAnimation<Color>(theme.accent),
              minHeight: 6,
            ),
          ),
        ),

        // Questions
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
      ],
    );
  }

  Widget _buildQuestion(
    RaverThemeData theme,
    Map<String, dynamic> question,
    int questionIndex,
  ) {
    final text = question['text'] as String? ?? '';
    final options = (question['options'] as List<dynamic>?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${questionIndex + 1}/${_viewModel.totalQuestions}',
            style: RaverTypography.caption(
              color: theme.secondaryText,
              weight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: RaverTypography.title(
              size: 18,
              color: theme.primaryText,
            ),
          ),
          const SizedBox(height: 24),
          ...options.asMap().entries.map((entry) {
            final optionIndex = entry.key;
            final option = entry.value as String? ?? '';
            final isSelected = _viewModel.currentAnswer == optionIndex;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => _viewModel.selectAnswer(optionIndex),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.accent.withValues(alpha: 0.12)
                        : theme.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? theme.accent : theme.cardBorder,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    option,
                    style: RaverTypography.body(
                      size: 15,
                      color: isSelected ? theme.accent : theme.primaryText,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
