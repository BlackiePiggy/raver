import { PrismaClient } from '@prisma/client';
import { notificationCenterService } from '../modules/notifications';

const prisma = new PrismaClient();

export type ContentSubmissionTaskStatus =
  | 'processing'
  | 'reviewing'
  | 'approved'
  | 'rejected'
  | 'failed';

const typeLabelMap: Record<string, string> = {
  event: '活动',
  dj: 'DJ',
  news: '资讯',
  set: 'Set',
  brand: '品牌',
  label: '厂牌',
  id: 'ID',
  rating: '打分',
};

const statusLabelMap = {
  processing: { zh: '处理中', en: 'processing', ja: '処理中' },
  reviewing: { zh: '审核中', en: 'in review', ja: '審査中' },
  approved: { zh: '已入库', en: 'approved', ja: '入庫済み' },
  rejected: { zh: '未通过', en: 'rejected', ja: '未承認' },
  failed: { zh: '处理失败', en: 'failed', ja: '処理失敗' },
} as const;

export async function publishContentSubmissionTaskNotification(input: {
  userId: string;
  entityType: string;
  status: ContentSubmissionTaskStatus;
  title: string;
  submissionId: string;
  reason?: string | null;
  createdEntityId?: string | null;
}) {
  const typeLabel = typeLabelMap[input.entityType] || '内容';
  const statusLabels = statusLabelMap[input.status];
  const titleI18n = {
    zh: `${typeLabel}提交${statusLabels.zh}`,
    en: `${typeLabel} submission ${statusLabels.en}`,
    ja: `${typeLabel}の投稿${statusLabels.ja}`,
  };
  const bodyI18n = {
    zh:
      input.status === 'processing'
        ? `你提交的「${input.title}」已进入处理队列。`
        : input.status === 'reviewing'
          ? `你提交的「${input.title}」已完成处理，正在审核中。`
          : input.status === 'approved'
            ? `你提交的「${input.title}」已审核通过，内容已入库。`
            : input.status === 'failed'
              ? `你提交的「${input.title}」处理失败：${input.reason || '请稍后重试或联系支持。'}`
              : `你提交的「${input.title}」未通过审核：${input.reason || '请补充更准确的信息后重新提交。'}`,
    en:
      input.status === 'processing'
        ? `Your submission "${input.title}" has entered the processing queue.`
        : input.status === 'reviewing'
          ? `Your submission "${input.title}" finished processing and is now under review.`
          : input.status === 'approved'
            ? `Your submission "${input.title}" was approved and added to Raver.`
            : input.status === 'failed'
              ? `Your submission "${input.title}" failed during processing: ${input.reason || 'Please retry later or contact support.'}`
              : `Your submission "${input.title}" was rejected: ${input.reason || 'Please add more accurate details and submit again.'}`,
    ja:
      input.status === 'processing'
        ? `投稿「${input.title}」は処理キューに入りました。`
        : input.status === 'reviewing'
          ? `投稿「${input.title}」の処理が完了し、現在審査中です。`
          : input.status === 'approved'
            ? `投稿「${input.title}」が承認され、Raver に追加されました。`
            : input.status === 'failed'
              ? `投稿「${input.title}」の処理に失敗しました：${input.reason || '後でもう一度お試しいただくか、サポートへお問い合わせください。'}`
              : `投稿「${input.title}」は承認されませんでした：${input.reason || 'より正確な情報を追加して再送信してください。'}`,
  };

  const localizedBody = bodyI18n.zh;
  await notificationCenterService.publish({
    category: 'content_review',
    targets: [{ userId: input.userId }],
    channels: ['in_app', 'apns'],
    dedupeKey: `content_submission:${input.submissionId}:${input.status}`,
    payload: {
      title: titleI18n.zh,
      body: localizedBody,
      deeplink: input.status === 'approved' && input.createdEntityId
        ? `/${input.entityType}s/${input.createdEntityId}`
        : `/profile/submissions/${input.submissionId}`,
      metadata: {
        source: 'content_submission_review',
        titleI18n,
        bodyI18n,
        message: localizedBody,
        submissionId: input.submissionId,
        entityType: input.entityType,
        status: input.status,
        reason: input.reason || null,
        reasonCode: input.reason || null,
        createdEntityId: input.createdEntityId || null,
        typeLabel,
        statusLabel: statusLabels.zh,
      },
    },
  });
}

async function processContentSubmission(submissionId: string): Promise<void> {
  const submission = await prisma.contentSubmission.findUnique({
    where: { id: submissionId },
    select: {
      id: true,
      status: true,
      entityType: true,
      title: true,
      submitterId: true,
      payload: true,
    },
  });

  if (!submission) return;
  if (submission.status !== 'processing' && submission.status !== 'pending') return;

  try {
    const payload = submission.payload;
    if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
      throw new Error('Invalid submission payload');
    }

    const updated = await prisma.contentSubmission.update({
      where: { id: submission.id },
      data: {
        status: 'reviewing',
        reviewReason: null,
      },
      select: {
        id: true,
        entityType: true,
        title: true,
        submitterId: true,
      },
    });

    await publishContentSubmissionTaskNotification({
      userId: updated.submitterId,
      entityType: updated.entityType,
      status: 'reviewing',
      title: updated.title,
      submissionId: updated.id,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Submission processing failed';
    const failed = await prisma.contentSubmission.update({
      where: { id: submission.id },
      data: {
        status: 'failed',
        reviewReason: message,
      },
      select: {
        id: true,
        entityType: true,
        title: true,
        submitterId: true,
      },
    });

    await publishContentSubmissionTaskNotification({
      userId: failed.submitterId,
      entityType: failed.entityType,
      status: 'failed',
      title: failed.title,
      submissionId: failed.id,
      reason: message,
    });
  }
}

export function scheduleContentSubmissionProcessingBestEffort(submissionId: string): void {
  setImmediate(() => {
    void processContentSubmission(submissionId);
  });
}
