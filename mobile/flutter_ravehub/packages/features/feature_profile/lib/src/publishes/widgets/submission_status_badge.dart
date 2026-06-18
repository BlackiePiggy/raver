import 'package:flutter/material.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

class SubmissionStatusBadge extends StatelessWidget {
  const SubmissionStatusBadge({
    super.key,
    required this.status,
    this.statusLabel,
  });

  final String status;
  final String? statusLabel;

  @override
  Widget build(BuildContext context) {
    final meta = submissionStatusMeta(status, statusLabel: statusLabel);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: meta.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        meta.label,
        style: RaverTypography.caption(
          color: meta.color,
          weight: FontWeight.w600,
        ),
      ),
    );
  }
}

class SubmissionStatusMeta {
  const SubmissionStatusMeta({required this.label, required this.color});

  final String label;
  final Color color;
}

SubmissionStatusMeta submissionStatusMeta(
  String status, {
  String? statusLabel,
}) {
  final normalized = status.trim().toLowerCase().replaceAll('_', '-');
  final liveLabel = statusLabel?.trim();
  if (liveLabel != null &&
      liveLabel.isNotEmpty &&
      !_isKnownStatus(normalized)) {
    return SubmissionStatusMeta(
      label: liveLabel,
      color: Colors.blueGrey,
    );
  }

  switch (normalized) {
    case 'processing':
      return SubmissionStatusMeta(
        label: lt('处理中', 'Processing', '処理中'),
        color: Colors.blueAccent,
      );
    case 'reviewing':
    case 'in-review':
    case 'pending':
      return SubmissionStatusMeta(
        label: lt('审核中', 'In Review', '審査中'),
        color: Colors.orange,
      );
    case 'approved':
      return SubmissionStatusMeta(
        label: lt('已入库', 'Approved', '入庫済み'),
        color: Colors.green,
      );
    case 'rejected':
      return SubmissionStatusMeta(
        label: lt('未通过', 'Rejected', '未承認'),
        color: Colors.redAccent,
      );
    case 'failed':
      return SubmissionStatusMeta(
        label: lt('处理失败', 'Failed', '処理失敗'),
        color: Colors.deepOrange,
      );
    case 'cancelled':
    case 'canceled':
      return SubmissionStatusMeta(
        label: lt('已取消', 'Cancelled', 'キャンセル済み'),
        color: Colors.blueGrey,
      );
    default:
      return SubmissionStatusMeta(
        label: status.isEmpty ? lt('未知', 'Unknown', '不明') : status,
        color: Colors.blueGrey,
      );
  }
}

bool _isKnownStatus(String status) {
  return const {
    'processing',
    'reviewing',
    'in-review',
    'pending',
    'approved',
    'rejected',
    'failed',
    'cancelled',
    'canceled',
  }.contains(status);
}
