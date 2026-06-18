import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';
import 'package:raver_platform/raver_platform.dart';

import '../_shared/profile_service_locator.dart';
import 'view_models/publishes_view_model.dart';
import 'widgets/submission_status_badge.dart';

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

  void _editAndResubmit(ContentSubmissionDetail detail) {
    final editRoute = _editRouteFor(detail);
    if (editRoute != null) {
      context.push(editRoute);
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = context.raver;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lt('暂时无法直接编辑', 'Direct Edit Unavailable', '直接編集できません'),
                style: RaverTypography.title(
                  size: 18,
                  color: theme.primaryText,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                lt(
                  '当前提交详情缺少可编辑实体 ID，暂时不能跳转到对应编辑器。你可以复制提交 ID，用于后台核对后重新提交。',
                  'This submission detail is missing an editable entity ID, so it cannot open the matching editor yet. Copy the submission ID for support review and resubmission.',
                  'この投稿詳細には編集可能なエンティティ ID がないため、対応する編集画面を開けません。サポート確認と再提出用に投稿 ID をコピーできます。',
                ),
                style: RaverTypography.body(
                  size: 14,
                  color: theme.secondaryText,
                ),
              ),
              const SizedBox(height: 18),
              PrimaryButton(
                label: lt('复制提交 ID', 'Copy Submission ID', '投稿 ID をコピー'),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(this.context);
                  await ClipboardService.copyText(detail.id);
                  if (!mounted || !context.mounted) return;
                  Navigator.of(context).pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        lt(
                          '已复制提交 ID',
                          'Submission ID copied',
                          '投稿 ID をコピーしました',
                        ),
                      ),
                    ),
                  );
                },
                isExpanded: true,
              ),
            ],
          ),
        );
      },
    );
  }

  String? _editRouteFor(ContentSubmissionDetail detail) {
    final entityId = detail.entityId;
    if (entityId == null || entityId.isEmpty) return null;

    final type = detail.entityType.toLowerCase().replaceAll('_', '-');
    switch (type) {
      case 'event':
      case 'events':
        return '/events/$entityId/edit';
      case 'dj':
      case 'djs':
        return '/djs/$entityId/edit';
      case 'set':
      case 'sets':
      case 'dj-set':
      case 'djset':
        return '/sets/$entityId/edit';
      case 'news':
      case 'article':
      case 'articles':
        return '/news/$entityId/edit';
    }
    return null;
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
                  error: lt('无法加载详情', 'Unable to load details', '詳細を読み込めません'),
                  onRetry: () => _viewModel.loadDetail(widget.submissionId),
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
                          SubmissionStatusBadge(
                            status: _viewModel.detail!.status,
                            statusLabel: _viewModel.detail!.statusLabel,
                          ),
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
                        final isLast =
                            entry.key == _viewModel.detail!.versions.length - 1;
                        return _TimelineStep(
                          status: version.status,
                          statusLabel: version.statusLabel,
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
                          label: lt('修改并重新提交', 'Edit & Resubmit', '修正して再提出'),
                          onPressed: () => _editAndResubmit(_viewModel.detail!),
                          isExpanded: true,
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.status,
    this.statusLabel,
    required this.date,
    required this.isLast,
    required this.theme,
  });

  final String status;
  final String? statusLabel;
  final String date;
  final bool isLast;
  final RaverThemeData theme;

  @override
  Widget build(BuildContext context) {
    final statusMeta = submissionStatusMeta(status, statusLabel: statusLabel);
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
                    color: statusMeta.color,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 2, color: theme.cardBorder)),
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
                    statusMeta.label,
                    style: RaverTypography.label(
                      size: 14,
                      color: statusMeta.color,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    date,
                    style: RaverTypography.caption(color: theme.secondaryText),
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
