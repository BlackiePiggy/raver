import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

import '../_shared/profile_service_locator.dart';
import 'view_models/publishes_view_model.dart';

/// Content submission detail screen with review timeline.
class ContentSubmissionDetailScreen extends StatefulWidget {
  const ContentSubmissionDetailScreen({super.key, required this.submissionId});

  final String submissionId;

  @override
  State<ContentSubmissionDetailScreen> createState() =>
      _ContentSubmissionDetailScreenState();
}

class _ContentSubmissionDetailScreenState
    extends State<ContentSubmissionDetailScreen> {
  late final PublishesViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = PublishesViewModel(api: ProfileServiceLocator.publishesApi);
    _viewModel.addListener(_rebuild);
    _viewModel.loadDetail(widget.submissionId);
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

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Scaffold(
      appBar: AppBar(
        title: Text(lt('提交详情', 'Submission Detail', '投稿詳細')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _viewModel.isLoadingDetail
          ? const Center(child: CircularProgressIndicator.adaptive())
          : _viewModel.detail == null
              ? ErrorStateView(
                  title: lt('加载失败', 'Failed to Load', '読み込みに失敗しました'),
                  error: lt('无法加载详情', 'Unable to load details',
                      '詳細を読み込めません'),
                  onRetry: () =>
                      _viewModel.loadDetail(widget.submissionId),
                  retryLabel: lt('重试', 'Retry', '再試行'),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Content info
                      Text(
                        _viewModel.detail!.entityName,
                        style: RaverTypography.headline(
                          color: theme.primaryText,
                        ).copyWith(fontSize: 20),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildStatusBadge(
                              _viewModel.detail!.status, theme),
                          const SizedBox(width: 8),
                          Text(
                            _viewModel.detail!.entityType.toUpperCase(),
                            style: RaverTypography.caption(
                              color: theme.secondaryText,
                              weight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Review timeline
                      Text(
                        lt('审核时间线', 'Review Timeline', '審査タイムライン'),
                        style: RaverTypography.title(
                          size: 16,
                          color: theme.primaryText,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._viewModel.detail!.versions
                          .asMap()
                          .entries
                          .map((entry) {
                        final version = entry.value;
                        final isLast = entry.key ==
                            _viewModel.detail!.versions.length - 1;
                        return _TimelineStep(
                          status: version.status,
                          date: version.createdAt,
                          isLast: isLast,
                          theme: theme,
                        );
                      }),

                      // Review note
                      if (_viewModel.detail!.reviewNote.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          lt('审核意见', 'Review Note', '審査コメント'),
                          style: RaverTypography.title(
                            size: 16,
                            color: theme.primaryText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            _viewModel.detail!.reviewNote,
                            style: RaverTypography.body(
                              size: 14,
                              color: theme.primaryText,
                            ),
                          ),
                        ),
                      ],

                      // Resubmit button for rejected items
                      if (_viewModel.detail!.status.toLowerCase() ==
                          'rejected') ...[
                        const SizedBox(height: 24),
                        PrimaryButton(
                          label: lt('修改并重新提交', 'Edit & Resubmit',
                              '修正して再提出'),
                          onPressed: () {
                            // TODO: Navigate to edit submission
                          },
                          isExpanded: true,
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatusBadge(String status, RaverThemeData theme) {
    Color color;
    String label;

    switch (status.toLowerCase()) {
      case 'pending':
        color = Colors.orange;
        label = lt('待审核', 'Pending', '審査中');
        break;
      case 'approved':
        color = Colors.green;
        label = lt('已通过', 'Approved', '承認済み');
        break;
      case 'rejected':
        color = Colors.redAccent;
        label = lt('已拒绝', 'Rejected', '却下');
        break;
      default:
        color = theme.secondaryText;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: RaverTypography.caption(
          color: color,
          weight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.status,
    required this.date,
    required this.isLast,
    required this.theme,
  });

  final String status;
  final String date;
  final bool isLast;
  final RaverThemeData theme;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: theme.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: theme.cardBorder,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status,
                    style: RaverTypography.label(
                      size: 14,
                      color: theme.primaryText,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    date,
                    style: RaverTypography.caption(
                        color: theme.secondaryText),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
