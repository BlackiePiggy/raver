import { NextFunction, Request, RequestHandler, Response, Router } from 'express';
import { authenticate, AuthRequest } from '../../middleware/auth';
import checkinsV2Routes from '../../routes/checkins-v2.routes';
import notificationCenterRoutes from '../../routes/notification-center.routes';
import preRegistrationRoutes from '../../routes/pre-registration.routes';
import virtualAssetRoutes from '../../routes/virtual-asset.routes';
import contentSubmissionRoutes from '../../routes/content-submission.routes';
import accountEnforcementRoutes from '../../routes/account-enforcement.routes';
import { adminAuditService } from './admin-audit.service';
import { requireAdmin, requireAdminOrOperator } from './admin-auth.policy';
import { adminStatusService } from './admin-status.service';
import { accountEnforcementService } from '../../services/account-enforcement.service';
import { accountDeletionService } from '../../services/account-deletion.service';
import { Prisma, PrismaClient } from '@prisma/client';
import { notificationCenterService } from '../../modules/notifications';
import { normalizeTriTextPayload, resolveLocalizedText } from '../../utils/i18n';

const router: Router = Router();
const prisma = new PrismaClient();

const forwardToLegacyRouter = (legacyPrefix: string, legacyRouter: RequestHandler): RequestHandler => {
  return (req: Request, res: Response, next: NextFunction): void => {
    const originalUrl = req.url;
    const suffix = originalUrl === '/' ? '' : originalUrl;
    req.url = `${legacyPrefix}${suffix}`;

    legacyRouter(req, res, (error?: unknown) => {
      req.url = originalUrl;
      if (error) {
        next(error);
        return;
      }
      next();
    });
  };
};

const parseLimit = (value: unknown, fallback = 50, max = 200): number => {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) return fallback;
  return Math.min(Math.floor(parsed), max);
};

const parseDateCursor = (value: unknown): Date | undefined => {
  if (typeof value !== 'string' || !value.trim()) return undefined;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? undefined : date;
};

const firstQueryValue = (value: unknown): string | undefined => {
  if (Array.isArray(value)) return typeof value[0] === 'string' ? value[0] : undefined;
  return typeof value === 'string' ? value : undefined;
};

const REPORT_HIGH_PRIORITY_REASONS = new Set([
  'minor_safety',
  'violence_or_threat',
  'illegal_activity',
  'privacy_violation',
]);

const REPORT_MEDIUM_PRIORITY_REASONS = new Set([
  'harassment',
  'hate_or_discrimination',
  'sexual_content',
  'scam_or_fraud',
  'impersonation',
  'copyright',
]);

const resolveReportPriority = (reason: string): 'high' | 'medium' | 'normal' => {
  if (REPORT_HIGH_PRIORITY_REASONS.has(reason)) return 'high';
  if (REPORT_MEDIUM_PRIORITY_REASONS.has(reason)) return 'medium';
  return 'normal';
};

const reportSlaHours = (priority: 'high' | 'medium' | 'normal'): number => {
  if (priority === 'high') return 12;
  if (priority === 'medium') return 24;
  return 72;
};

const COPYRIGHT_REPEAT_INFRINGER_THRESHOLD = 3;

const MODERATION_TEMPLATE_KEYS = [
  'report_resolved',
  'report_dismissed',
  'content_hidden',
  'content_restored',
  'user_warned',
  'user_restricted',
  'user_suspended',
  'user_banned',
  'report_escalated',
] as const;

const MODERATION_TEMPLATE_LOCALES = ['zh-CN', 'en', 'ja-JP'] as const;

const DEFAULT_MODERATION_TEMPLATES: Record<string, Record<string, { title: string; body: string }>> = {
  report_resolved: {
    'zh-CN': { title: '举报已处理', body: '我们已完成审核并采取必要处理。为保护隐私，具体细节可能无法完全公开。' },
    en: { title: 'Report resolved', body: 'We reviewed your report and took the necessary action. Some details may be limited to protect privacy.' },
    'ja-JP': { title: '通報を処理しました', body: '通報内容を確認し、必要な対応を行いました。プライバシー保護のため、詳細をすべて開示できない場合があります。' },
  },
  report_dismissed: {
    'zh-CN': { title: '举报未发现违规', body: '我们已审核该内容，暂未发现违反社区规范的情况。你仍可补充证据或联系客服。' },
    en: { title: 'No violation found', body: 'We reviewed the content and did not find a policy violation. You may add evidence or contact support.' },
    'ja-JP': { title: '違反は確認されませんでした', body: '対象内容を確認しましたが、現時点ではコミュニティ規約違反は確認されませんでした。追加証拠の提出やサポートへの連絡は可能です。' },
  },
  content_hidden: {
    'zh-CN': { title: '内容已下架', body: '经审核，该内容已被下架。相关用户可能会收到进一步限制或处罚。' },
    en: { title: 'Content hidden', body: 'After review, the reported content has been hidden. The related user may receive further restrictions or enforcement.' },
    'ja-JP': { title: 'コンテンツを非表示にしました', body: '審査の結果、対象コンテンツを非表示にしました。関連ユーザーには追加の制限または措置が行われる場合があります。' },
  },
  content_restored: {
    'zh-CN': { title: '内容已恢复', body: '复核后，该内容已恢复展示。我们会继续关注相关上下文。' },
    en: { title: 'Content restored', body: 'After review, the content has been restored. We will keep monitoring the related context.' },
    'ja-JP': { title: 'コンテンツを復元しました', body: '再確認の結果、対象コンテンツを復元しました。関連する文脈は引き続き確認します。' },
  },
};

const normalizeAdminText = (value: unknown, maxLength: number): string | null => {
  if (typeof value !== 'string') return null;
  const normalized = value.trim().replace(/\s+/g, ' ');
  return normalized ? normalized.slice(0, maxLength) : null;
};

const normalizeStringArray = (value: unknown, maxItems: number): string[] => {
  if (!Array.isArray(value)) return [];
  const seen = new Set<string>();
  for (const item of value) {
    if (typeof item !== 'string') continue;
    const normalized = item.trim();
    if (!normalized || seen.has(normalized)) continue;
    seen.add(normalized);
    if (seen.size >= maxItems) break;
  }
  return Array.from(seen);
};

const asRecord = (value: unknown): Record<string, unknown> => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return {};
  return value as Record<string, unknown>;
};

const isCopyrightReport = (report: { reason: string }): boolean => report.reason === 'copyright';

const fetchCopyrightStats = async (report: {
  id: string;
  targetType: string;
  targetId: string;
  targetUserId: string | null;
  reason: string;
  status: string;
}) => {
  if (!isCopyrightReport(report)) return null;

  const [resolvedForTargetUser, activeTargetTakedowns] = await Promise.all([
    report.targetUserId
      ? prisma.contentReport.count({
          where: {
            id: { not: report.id },
            targetUserId: report.targetUserId,
            reason: 'copyright',
            status: 'resolved',
          },
        })
      : Promise.resolve(0),
    prisma.contentReport.count({
      where: {
        targetType: report.targetType,
        targetId: report.targetId,
        reason: 'copyright',
        metadata: {
          path: ['copyright', 'takedownStatus'],
          equals: 'active',
        },
      },
    }),
  ]);

  const resolvedCopyrightCount = resolvedForTargetUser + (report.status === 'resolved' ? 1 : 0);
  return {
    resolvedCopyrightCount,
    repeatInfringerThreshold: COPYRIGHT_REPEAT_INFRINGER_THRESHOLD,
    repeatInfringer: resolvedCopyrightCount >= COPYRIGHT_REPEAT_INFRINGER_THRESHOLD,
    activeTargetTakedowns,
  };
};

const fetchTargetModerationState = async (report: { targetType: string; targetId: string }) => {
  if (report.targetType === 'post') {
    const post = await prisma.post.findUnique({ where: { id: report.targetId }, select: { visibility: true } });
    return { field: 'visibility', value: post?.visibility ?? null };
  }
  if (report.targetType === 'event') {
    const event = await prisma.event.findUnique({ where: { id: report.targetId }, select: { status: true } });
    return { field: 'status', value: event?.status ?? null };
  }
  return { field: null, value: null };
};

const applyContentModerationAction = async (input: {
  report: { targetType: string; targetId: string; metadata: Prisma.JsonValue | null };
  action: string;
}) => {
  const previousMetadata = asRecord(input.report.metadata);
  const previousCopyright = asRecord(previousMetadata.copyright);
  const previousState = asRecord(previousCopyright.previousState);
  const previousField = typeof previousState.field === 'string' ? previousState.field : null;
  const previousValue = typeof previousState.value === 'string' ? previousState.value : null;

  if (input.action === 'hide_content') {
    const currentState = await fetchTargetModerationState(input.report);
    if (input.report.targetType === 'post') {
      await prisma.post.updateMany({ where: { id: input.report.targetId }, data: { visibility: 'hidden' } });
      return { applied: true, previousState: currentState, nextState: { field: 'visibility', value: 'hidden' } };
    }
    if (input.report.targetType === 'event') {
      await prisma.event.updateMany({ where: { id: input.report.targetId }, data: { status: 'hidden' } });
      return { applied: true, previousState: currentState, nextState: { field: 'status', value: 'hidden' } };
    }
    return { applied: false, previousState: currentState, nextState: null };
  }

  if (input.action === 'restore_content') {
    if (input.report.targetType === 'post') {
      const restoreVisibility = previousField === 'visibility' && previousValue && previousValue !== 'hidden' ? previousValue : 'public';
      await prisma.post.updateMany({ where: { id: input.report.targetId }, data: { visibility: restoreVisibility } });
      return { applied: true, previousState: { field: 'visibility', value: 'hidden' }, nextState: { field: 'visibility', value: restoreVisibility } };
    }
    if (input.report.targetType === 'event') {
      const restoreStatus = previousField === 'status' && previousValue && previousValue !== 'hidden' ? previousValue : 'upcoming';
      await prisma.event.updateMany({ where: { id: input.report.targetId }, data: { status: restoreStatus } });
      return { applied: true, previousState: { field: 'status', value: 'hidden' }, nextState: { field: 'status', value: restoreStatus } };
    }
    return { applied: false, previousState: null, nextState: null };
  }

  return { applied: false, previousState: null, nextState: null };
};

const normalizeTemplateLocale = (value: unknown): string => {
  const locale = typeof value === 'string' ? value.trim() : '';
  return MODERATION_TEMPLATE_LOCALES.includes(locale as typeof MODERATION_TEMPLATE_LOCALES[number]) ? locale : 'ja-JP';
};

const normalizeTemplateKey = (value: unknown): string => {
  const key = typeof value === 'string' ? value.trim() : '';
  return MODERATION_TEMPLATE_KEYS.includes(key as typeof MODERATION_TEMPLATE_KEYS[number]) ? key : 'report_resolved';
};

const userSummarySelect = {
  id: true,
  username: true,
  displayName: true,
  avatarUrl: true,
} as const;

const fetchReportTargetPreview = async (report: {
  targetType: string;
  targetId: string;
}): Promise<Record<string, unknown> | null> => {
  switch (report.targetType) {
    case 'user': {
      const user = await prisma.user.findUnique({
        where: { id: report.targetId },
        select: { ...userSummarySelect, bio: true, isActive: true, createdAt: true },
      });
      return user ? { kind: 'user', user } : null;
    }
    case 'post': {
      const post = await prisma.post.findUnique({
        where: { id: report.targetId },
        select: {
          id: true,
          content: true,
          images: true,
          visibility: true,
          createdAt: true,
          user: { select: userSummarySelect },
        },
      });
      return post ? { kind: 'post', post } : null;
    }
    case 'post_comment': {
      const comment = await prisma.postComment.findUnique({
        where: { id: report.targetId },
        select: {
          id: true,
          postId: true,
          content: true,
          createdAt: true,
          user: { select: userSummarySelect },
          post: { select: { id: true, content: true, userId: true } },
        },
      });
      return comment ? { kind: 'post_comment', comment } : null;
    }
    case 'event_live_comment': {
      const comment = await prisma.eventLiveComment.findUnique({
        where: { id: report.targetId },
        select: {
          id: true,
          eventId: true,
          content: true,
          imageUrls: true,
          createdAt: true,
          user: { select: userSummarySelect },
          event: { select: { id: true, name: true } },
        },
      });
      return comment ? { kind: 'event_live_comment', comment } : null;
    }
    case 'event': {
      const event = await prisma.event.findUnique({
        where: { id: report.targetId },
        select: { id: true, name: true, description: true, status: true, startDate: true },
      });
      return event ? { kind: 'event', event } : null;
    }
    case 'dj': {
      const dj = await prisma.dJ.findUnique({
        where: { id: report.targetId },
        select: { id: true, name: true, bio: true, avatarUrl: true },
      });
      return dj ? { kind: 'dj', dj } : null;
    }
    case 'dj_set': {
      const set = await prisma.dJSet.findUnique({
        where: { id: report.targetId },
        select: { id: true, title: true, description: true, videoUrl: true, uploader: { select: userSummarySelect } },
      });
      return set ? { kind: 'dj_set', set } : null;
    }
    case 'label': {
      const label = await prisma.label.findUnique({
        where: { id: report.targetId },
        select: { id: true, name: true, introductionPreview: true, avatarUrl: true, backgroundUrl: true },
      });
      return label ? { kind: 'label', label } : null;
    }
    case 'festival': {
      const festival = await prisma.wikiFestival.findUnique({
        where: { id: report.targetId },
        select: { id: true, name: true, introduction: true, avatarUrl: true, backgroundUrl: true, isActive: true },
      });
      return festival ? { kind: 'festival', festival } : null;
    }
    case 'rating_event': {
      const ratingEvent = await prisma.ratingEvent.findUnique({
        where: { id: report.targetId },
        select: { id: true, name: true, description: true, imageUrl: true, createdBy: { select: userSummarySelect } },
      });
      return ratingEvent ? { kind: 'rating_event', ratingEvent } : null;
    }
    case 'rating_unit': {
      const ratingUnit = await prisma.ratingUnit.findUnique({
        where: { id: report.targetId },
        select: { id: true, name: true, description: true, imageUrl: true, createdBy: { select: userSummarySelect }, event: { select: { id: true, name: true } } },
      });
      return ratingUnit ? { kind: 'rating_unit', ratingUnit } : null;
    }
    case 'direct_message': {
      const message = await prisma.directMessage.findUnique({
        where: { id: report.targetId },
        select: {
          id: true,
          conversationId: true,
          content: true,
          type: true,
          createdAt: true,
          sender: { select: userSummarySelect },
          conversation: { select: { id: true, userAId: true, userBId: true } },
        },
      });
      return message ? { kind: 'direct_message', message } : null;
    }
    case 'group_message':
    case 'squad_message': {
      const message = await prisma.squadMessage.findUnique({
        where: { id: report.targetId },
        select: {
          id: true,
          squadId: true,
          content: true,
          type: true,
          imageUrl: true,
          createdAt: true,
          user: { select: userSummarySelect },
          squad: { select: { id: true, name: true } },
        },
      });
      return message ? { kind: 'squad_message', message } : null;
    }
    case 'image':
    case 'video':
    case 'audio':
    case 'media_image':
    case 'media_video':
    case 'media_audio':
      return { kind: 'media_attachment', targetType: report.targetType, targetId: report.targetId };
    default:
      return null;
  }
};

const buildContentReportWhere = (input: {
  status?: string;
  targetType?: string;
  reason?: string;
  priority?: string;
  before?: Date;
}): Prisma.ContentReportWhereInput => {
  const where: Prisma.ContentReportWhereInput = {};
  if (input.status) where.status = input.status;
  if (input.targetType) where.targetType = input.targetType;
  if (input.reason) where.reason = input.reason;
  if (input.before && !Number.isNaN(input.before.getTime())) {
    where.createdAt = { lt: input.before };
  }
  if (input.priority === 'high') {
    where.reason = { in: Array.from(REPORT_HIGH_PRIORITY_REASONS) };
  } else if (input.priority === 'medium') {
    where.reason = { in: Array.from(REPORT_MEDIUM_PRIORITY_REASONS) };
  } else if (input.priority === 'normal') {
    where.reason = { notIn: [...REPORT_HIGH_PRIORITY_REASONS, ...REPORT_MEDIUM_PRIORITY_REASONS] };
  }
  return where;
};

const enrichContentReportRows = async (pageRows: Awaited<ReturnType<typeof prisma.contentReport.findMany>>) => {
  const relatedUserIds = Array.from(
    new Set(
      pageRows
        .flatMap((row) => [row.reporterUserId, row.targetUserId])
        .filter((id): id is string => Boolean(id))
    )
  );
  const relatedUsers = relatedUserIds.length > 0
    ? await prisma.user.findMany({
        where: { id: { in: relatedUserIds } },
        select: userSummarySelect,
      })
    : [];
  const userById = new Map(relatedUsers.map((user) => [user.id, user]));
  const reportCounts = await Promise.all(
    pageRows.map((row) =>
      prisma.contentReport.count({
        where: {
          targetType: row.targetType,
          targetId: row.targetId,
        },
      })
    )
  );
  const previews = await Promise.all(pageRows.map((row) => fetchReportTargetPreview(row)));

  const now = Date.now();
  return pageRows.map((row, index) => {
    const priority = resolveReportPriority(row.reason);
    const dueAt = new Date(row.createdAt.getTime() + reportSlaHours(priority) * 60 * 60 * 1000);
    return {
      ...row,
      reporter: userById.get(row.reporterUserId) ?? null,
      targetUser: row.targetUserId ? userById.get(row.targetUserId) ?? null : null,
      priority,
      slaDueAt: dueAt.toISOString(),
      isOverdue: row.status === 'pending' || row.status === 'reviewing' ? dueAt.getTime() < now : false,
      reportCountForTarget: reportCounts[index] ?? 1,
      targetPreview: previews[index],
    };
  });
};

const fetchContentReportsForAdmin = async (input: {
  status?: string;
  targetType?: string;
  reason?: string;
  priority?: string;
  before?: Date;
  limit?: number;
}) => {
  const limit = parseLimit(input.limit, 50, 100);
  const where = buildContentReportWhere(input);

  const rows = await prisma.contentReport.findMany({
    where,
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: limit + 1,
  });

  const pageRows = rows.slice(0, limit);
  const items = await enrichContentReportRows(pageRows);

  return {
    items,
    nextCursor: rows.length > limit ? pageRows[pageRows.length - 1]?.createdAt.toISOString() ?? null : null,
  };
};

const fetchContentReportSummary = async () => {
  const pendingWhere: Prisma.ContentReportWhereInput = { status: { in: ['pending', 'reviewing'] } };
  const [pendingRows, byStatus, byReason, byType] = await Promise.all([
    prisma.contentReport.findMany({
      where: pendingWhere,
      select: { id: true, reason: true, createdAt: true },
      take: 1000,
      orderBy: [{ createdAt: 'asc' }],
    }),
    prisma.contentReport.groupBy({ by: ['status'], _count: { _all: true } }),
    prisma.contentReport.groupBy({ by: ['reason'], where: pendingWhere, _count: { _all: true } }),
    prisma.contentReport.groupBy({ by: ['targetType'], where: pendingWhere, _count: { _all: true } }),
  ]);

  const now = Date.now();
  const highPriorityPending = pendingRows.filter((row) => resolveReportPriority(row.reason) === 'high');
  const overdueRows = pendingRows.filter((row) => {
    const priority = resolveReportPriority(row.reason);
    const dueAt = row.createdAt.getTime() + reportSlaHours(priority) * 60 * 60 * 1000;
    return dueAt < now;
  });

  return {
    pendingCount: pendingRows.length,
    overdueCount: overdueRows.length,
    highPriorityPendingCount: highPriorityPending.length,
    oldestPendingAt: pendingRows[0]?.createdAt.toISOString() ?? null,
    byStatus: byStatus.map((item) => ({ status: item.status, count: item._count._all })),
    byReason: byReason.map((item) => ({ reason: item.reason, count: item._count._all })),
    byType: byType.map((item) => ({ targetType: item.targetType, count: item._count._all })),
  };
};

const fetchReportContext = async (report: { targetType: string; targetId: string; targetUserId: string | null }) => {
  if (report.targetType === 'post_comment') {
    const comment = await prisma.postComment.findUnique({
      where: { id: report.targetId },
      select: {
        parentCommentId: true,
        post: { select: { id: true, content: true, user: { select: userSummarySelect } } },
      },
    });
    return comment ? { kind: 'post_comment_context', comment } : null;
  }
  if (report.targetType === 'event_live_comment') {
    const comment = await prisma.eventLiveComment.findUnique({
      where: { id: report.targetId },
      select: {
        parentCommentId: true,
        rootCommentId: true,
        event: { select: { id: true, name: true } },
      },
    });
    return comment ? { kind: 'event_live_comment_context', comment } : null;
  }
  if (report.targetType === 'direct_message') {
    const message = await prisma.directMessage.findUnique({
      where: { id: report.targetId },
      select: { conversationId: true, createdAt: true },
    });
    if (!message) return null;
    const nearby = await prisma.directMessage.findMany({
      where: { conversationId: message.conversationId },
      orderBy: [{ createdAt: 'desc' }],
      take: 12,
      select: { id: true, senderId: true, content: true, type: true, createdAt: true },
    });
    return { kind: 'direct_message_context', nearby };
  }
  if (report.targetType === 'group_message' || report.targetType === 'squad_message') {
    const message = await prisma.squadMessage.findUnique({
      where: { id: report.targetId },
      select: { squadId: true },
    });
    if (!message) return null;
    const nearby = await prisma.squadMessage.findMany({
      where: { squadId: message.squadId },
      orderBy: [{ createdAt: 'desc' }],
      take: 12,
      select: { id: true, userId: true, content: true, type: true, imageUrl: true, createdAt: true },
    });
    return { kind: 'squad_message_context', nearby };
  }
  return null;
};

const fetchModerationTemplateRows = async (templateKey: string, locale: string) => {
  const rows = await prisma.moderationDecisionTemplate.findMany({
    where: { templateKey, locale },
    orderBy: [{ version: 'desc' }],
    take: 20,
  });
  if (rows.length > 0) return rows;
  const fallback = DEFAULT_MODERATION_TEMPLATES[templateKey]?.[locale]
    ?? DEFAULT_MODERATION_TEMPLATES.report_resolved[locale]
    ?? DEFAULT_MODERATION_TEMPLATES.report_resolved.en;
  return [{
    id: `default:${templateKey}:${locale}`,
    templateKey,
    locale,
    title: fallback.title,
    body: fallback.body,
    status: 'default',
    version: 0,
    publishedAt: null,
    publishedBy: null,
    createdBy: null,
    createdAt: new Date(0),
    updatedAt: new Date(0),
  }];
};

const renderTemplate = (template: { title: string; body: string }, variables: Record<string, string | number | null | undefined>) => {
  const replace = (text: string) => text.replace(/\{\{\s*([a-zA-Z0-9_]+)\s*\}\}/g, (_match, key) => String(variables[key] ?? ''));
  return { title: replace(template.title), body: replace(template.body) };
};

const resolvePublishedModerationTemplate = async (templateKey: string, locale = 'ja-JP') => {
  const row = await prisma.moderationDecisionTemplate.findFirst({
    where: { templateKey, locale, status: 'published' },
    orderBy: [{ version: 'desc' }],
  });
  if (row) return row;
  const fallback = DEFAULT_MODERATION_TEMPLATES[templateKey]?.[locale]
    ?? DEFAULT_MODERATION_TEMPLATES.report_resolved[locale]
    ?? DEFAULT_MODERATION_TEMPLATES.report_resolved.en;
  return { title: fallback.title, body: fallback.body };
};

const moderationTemplateKeyForAction = (action: string): string => {
  switch (action) {
    case 'dismiss': return 'report_dismissed';
    case 'hide_content': return 'content_hidden';
    case 'restore_content': return 'content_restored';
    case 'warn_user': return 'user_warned';
    case 'restrict_user': return 'user_restricted';
    case 'suspend_user': return 'user_suspended';
    case 'ban_user': return 'user_banned';
    case 'escalate': return 'report_escalated';
    default: return 'report_resolved';
  }
};

const notifyReportDecision = async (input: {
  report: { id: string; reporterUserId: string; targetUserId: string | null; targetType: string; targetId: string; reason: string };
  action: string;
  note: string | null;
}) => {
  const variables = {
    reportId: input.report.id,
    targetType: input.report.targetType,
    reason: input.report.reason,
  };
  const zhTemplate = await resolvePublishedModerationTemplate(moderationTemplateKeyForAction(input.action), 'zh-CN');
  const enTemplate = await resolvePublishedModerationTemplate(moderationTemplateKeyForAction(input.action), 'en');
  const jaTemplate = await resolvePublishedModerationTemplate(moderationTemplateKeyForAction(input.action), 'ja-JP');
  const renderedI18n = {
    zh: renderTemplate(zhTemplate, variables),
    en: renderTemplate(enTemplate, variables),
    ja: renderTemplate(jaTemplate, variables),
  };
  const reporterTitleI18n = normalizeTriTextPayload({
    zh: renderedI18n.zh.title,
    en: renderedI18n.en.title,
    ja: renderedI18n.ja.title,
  }, renderedI18n.ja.title);
  const reporterBodyI18n = normalizeTriTextPayload({
    zh: renderedI18n.zh.body,
    en: renderedI18n.en.body,
    ja: renderedI18n.ja.body,
  }, renderedI18n.ja.body);

  await notificationCenterService.publish({
    category: 'report_decision',
    targets: [{ userId: input.report.reporterUserId }],
    channels: ['in_app', 'apns'],
    dedupeKey: `content_report:decision:reporter:${input.report.id}:${input.action}`,
    payload: {
      title: resolveLocalizedText(reporterTitleI18n, renderedI18n.ja.title, ['ja', 'en', 'zh']),
      body: resolveLocalizedText(reporterBodyI18n, renderedI18n.ja.body, ['ja', 'en', 'zh']),
      deeplink: `raver://settings/privacy/reports/${input.report.id}`,
      metadata: {
        source: 'content_report_decision',
        reportId: input.report.id,
        action: input.action,
        decisionCode: input.action,
        titleI18n: reporterTitleI18n,
        bodyI18n: reporterBodyI18n,
        message: resolveLocalizedText(reporterBodyI18n, renderedI18n.ja.body, ['ja', 'en', 'zh']),
        privacyNotice: 'Reporter outcome omits private enforcement details.',
      },
    },
  });

  if (input.report.targetUserId && ['warn_user', 'restrict_user', 'suspend_user', 'ban_user', 'hide_content'].includes(input.action)) {
    const targetBodyI18n = normalizeTriTextPayload({
      zh: input.note || renderedI18n.zh.body,
      en: input.note || renderedI18n.en.body,
      ja: input.note || renderedI18n.ja.body,
    }, input.note || renderedI18n.ja.body);
    await notificationCenterService.publish({
      category: 'report_decision',
      targets: [{ userId: input.report.targetUserId }],
      channels: ['in_app', 'apns'],
      dedupeKey: `content_report:decision:target:${input.report.id}:${input.action}`,
      payload: {
        title: resolveLocalizedText(reporterTitleI18n, renderedI18n.ja.title, ['ja', 'en', 'zh']),
        body: resolveLocalizedText(targetBodyI18n, input.note || renderedI18n.ja.body, ['ja', 'en', 'zh']),
        deeplink: 'raver://settings/account-security',
        metadata: {
          source: 'content_report_target_action',
          reportId: input.report.id,
          action: input.action,
          decisionCode: input.action,
          titleI18n: reporterTitleI18n,
          bodyI18n: targetBodyI18n,
          message: resolveLocalizedText(targetBodyI18n, input.note || renderedI18n.ja.body, ['ja', 'en', 'zh']),
          privacyNotice: 'Target user notification does not identify reporter.',
        },
      },
    });
  }
};

router.get('/audit-logs', authenticate, requireAdmin, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const query = req.query as Request['query'];
    const result = await adminAuditService.listLogs({
      limit: parseLimit(query.limit),
      actorId: firstQueryValue(query.actorId),
      action: firstQueryValue(query.action),
      targetType: firstQueryValue(query.targetType),
      targetId: firstQueryValue(query.targetId),
      before: parseDateCursor(query.before || query.cursor),
    });
    res.json({ success: true, ...result });
  } catch (error) {
    console.error('Fetch admin audit logs error:', error);
    res.status(500).json({ error: 'Failed to fetch admin audit logs' });
  }
});

router.get('/account-deletions', authenticate, requireAdminOrOperator, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const query = req.query as Request['query'];
    const items = await accountDeletionService.listRequests({
      userId: firstQueryValue(query.userId),
      status: firstQueryValue(query.status),
      limit: parseLimit(query.limit, 50, 200),
    });
    res.json({ success: true, items });
  } catch (error) {
    console.error('Fetch account deletion requests error:', error);
    res.status(500).json({ error: 'Failed to fetch account deletion requests' });
  }
});

router.post('/account-deletions/process-due', authenticate, requireAdmin, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const results = await accountDeletionService.processDueRequests(parseLimit(req.body?.limit, 20, 100));
    await adminAuditService.createAction({
      actorId: req.user?.userId || 'unknown',
      action: 'account_deletion.process_due',
      targetType: 'account_deletion_request',
      targetId: 'bulk',
      detail: { processed: results.length, failures: results.filter((item) => !item.ok).length },
    });
    res.json({ success: true, results });
  } catch (error) {
    console.error('Process due account deletion requests error:', error);
    res.status(500).json({ error: 'Failed to process account deletion requests' });
  }
});

router.post('/account-deletions/:id/retry', authenticate, requireAdmin, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const requestId = String(req.params.id || '').trim();
    const request = await accountDeletionService.processRequest(requestId, { force: true });
    await adminAuditService.createAction({
      actorId: req.user?.userId || 'unknown',
      action: 'account_deletion.retry',
      targetType: 'account_deletion_request',
      targetId: requestId,
      detail: {
        status: request.status,
        imStatus: request.imStatus,
        mediaStatus: request.mediaStatus,
      },
    });
    res.json({ success: true, request });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    const status = message === 'account_deletion_request_not_found' ? 404 : 500;
    console.error('Retry account deletion request error:', error);
    res.status(status).json({ error: 'Failed to retry account deletion request' });
  }
});

router.get('/status', authenticate, requireAdminOrOperator, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const query = req.query as Request['query'];
    const status = await adminStatusService.getStatus({
      windowHours: query.windowHours,
    });
    res.json({ success: true, status });
  } catch (error) {
    console.error('Fetch admin status error:', error);
    res.status(500).json({ error: 'Failed to fetch admin status' });
  }
});

router.get('/content-reports', authenticate, requireAdminOrOperator, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const query = req.query as Request['query'];
    const result = await fetchContentReportsForAdmin({
      status: firstQueryValue(query.status),
      targetType: firstQueryValue(query.targetType),
      reason: firstQueryValue(query.reason),
      priority: firstQueryValue(query.priority),
      before: parseDateCursor(query.before || query.cursor),
      limit: parseLimit(query.limit, 50, 100),
    });
    res.json({ success: true, ...result });
  } catch (error) {
    console.error('Fetch admin content reports error:', error);
    res.status(500).json({ error: 'Failed to fetch content reports' });
  }
});

router.get('/content-reports/summary', authenticate, requireAdminOrOperator, async (_req: AuthRequest, res: Response): Promise<void> => {
  try {
    const summary = await fetchContentReportSummary();
    res.json({ success: true, summary });
  } catch (error) {
    console.error('Fetch admin content report summary error:', error);
    res.status(500).json({ error: 'Failed to fetch content report summary' });
  }
});

router.get('/content-reports/alerts', authenticate, requireAdminOrOperator, async (_req: AuthRequest, res: Response): Promise<void> => {
  try {
    const pendingRows = await prisma.contentReport.findMany({
      where: { status: { in: ['pending', 'reviewing'] } },
      orderBy: [{ createdAt: 'asc' }],
      take: 500,
    });
    const now = Date.now();
    const overdue = pendingRows
      .map((row) => {
        const priority = resolveReportPriority(row.reason);
        const dueAt = new Date(row.createdAt.getTime() + reportSlaHours(priority) * 60 * 60 * 1000);
        return { ...row, priority, slaDueAt: dueAt };
      })
      .filter((row) => row.slaDueAt.getTime() < now);

    res.json({
      success: true,
      alert: {
        shouldNotify: overdue.length > 0,
        overdueCount: overdue.length,
        highPriorityOverdueCount: overdue.filter((row) => row.priority === 'high').length,
        oldestOverdueAt: overdue[0]?.createdAt.toISOString() ?? null,
        items: overdue.slice(0, 25).map((row) => ({
          id: row.id,
          targetType: row.targetType,
          targetId: row.targetId,
          reason: row.reason,
          priority: row.priority,
          slaDueAt: row.slaDueAt.toISOString(),
          createdAt: row.createdAt.toISOString(),
        })),
      },
    });
  } catch (error) {
    console.error('Fetch admin content report alerts error:', error);
    res.status(500).json({ error: 'Failed to fetch content report alerts' });
  }
});

router.get('/content-reports/daily-report', authenticate, requireAdminOrOperator, async (_req: AuthRequest, res: Response): Promise<void> => {
  try {
    const since = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const [summary, recentDecisions, enforcementCount, appealCounts] = await Promise.all([
      fetchContentReportSummary(),
      prisma.contentReport.groupBy({
        by: ['status'],
        where: { updatedAt: { gte: since } },
        _count: { _all: true },
      }),
      prisma.accountEnforcement.count({ where: { createdAt: { gte: since } } }),
      prisma.enforcementAppeal.groupBy({
        by: ['status'],
        where: { updatedAt: { gte: since } },
        _count: { _all: true },
      }),
    ]);
    const approvedAppeals = appealCounts
      .filter((item) => ['approved', 'accepted'].includes(item.status))
      .reduce((sum, item) => sum + item._count._all, 0);
    const totalAppeals = appealCounts.reduce((sum, item) => sum + item._count._all, 0);

    res.json({
      success: true,
      report: {
        windowHours: 24,
        generatedAt: new Date().toISOString(),
        pendingCount: summary.pendingCount,
        overdueCount: summary.overdueCount,
        enforcementCount,
        appealApprovalRate: totalAppeals > 0 ? approvedAppeals / totalAppeals : null,
        decisionsByStatus: recentDecisions.map((item) => ({ status: item.status, count: item._count._all })),
        appealsByStatus: appealCounts.map((item) => ({ status: item.status, count: item._count._all })),
        byReason: summary.byReason,
        byType: summary.byType,
      },
    });
  } catch (error) {
    console.error('Fetch admin content report daily report error:', error);
    res.status(500).json({ error: 'Failed to fetch content report daily report' });
  }
});

router.get('/content-reports/templates', authenticate, requireAdminOrOperator, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const templateKey = normalizeTemplateKey(req.query.templateKey);
    const locale = normalizeTemplateLocale(req.query.locale);
    const rows = await fetchModerationTemplateRows(templateKey, locale);
    res.json({ success: true, items: rows });
  } catch (error) {
    console.error('Fetch moderation templates error:', error);
    res.status(500).json({ error: 'Failed to fetch moderation templates' });
  }
});

router.post('/content-reports/templates/preview', authenticate, requireAdminOrOperator, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const body = (req.body ?? {}) as Record<string, unknown>;
    const title = normalizeAdminText(body.title, 200) || '';
    const templateBody = normalizeAdminText(body.body, 4000) || '';
    const variables = body.variables && typeof body.variables === 'object' ? body.variables as Record<string, string | number> : {};
    res.json({ success: true, preview: renderTemplate({ title, body: templateBody }, variables) });
  } catch (error) {
    console.error('Preview moderation template error:', error);
    res.status(500).json({ error: 'Failed to preview moderation template' });
  }
});

router.post('/content-reports/templates', authenticate, requireAdminOrOperator, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const body = (req.body ?? {}) as Record<string, unknown>;
    const templateKey = normalizeTemplateKey(body.templateKey);
    const locale = normalizeTemplateLocale(body.locale);
    const title = normalizeAdminText(body.title, 200);
    const templateBody = normalizeAdminText(body.body, 4000);
    if (!title || !templateBody) {
      res.status(400).json({ error: 'title and body are required' });
      return;
    }
    const latest = await prisma.moderationDecisionTemplate.findFirst({
      where: { templateKey, locale },
      orderBy: [{ version: 'desc' }],
      select: { version: true },
    });
    const item = await prisma.moderationDecisionTemplate.create({
      data: {
        templateKey,
        locale,
        title,
        body: templateBody,
        status: 'draft',
        version: (latest?.version ?? 0) + 1,
        createdBy: req.user?.userId ?? null,
      },
    });
    await adminAuditService.createAction({
      actorId: req.user?.userId || 'unknown',
      action: 'content_report.template.draft',
      targetType: 'moderation_decision_template',
      targetId: item.id,
      detail: { templateKey, locale, version: item.version },
    });
    res.status(201).json({ success: true, item });
  } catch (error) {
    console.error('Create moderation template error:', error);
    res.status(500).json({ error: 'Failed to create moderation template' });
  }
});

router.post('/content-reports/templates/:id/publish', authenticate, requireAdminOrOperator, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const id = String(req.params.id || '');
    const existing = await prisma.moderationDecisionTemplate.findUnique({ where: { id } });
    if (!existing) {
      res.status(404).json({ error: 'Template not found' });
      return;
    }
    await prisma.moderationDecisionTemplate.updateMany({
      where: { templateKey: existing.templateKey, locale: existing.locale, status: 'published' },
      data: { status: 'archived' },
    });
    const item = await prisma.moderationDecisionTemplate.update({
      where: { id },
      data: { status: 'published', publishedAt: new Date(), publishedBy: req.user?.userId ?? null },
    });
    await adminAuditService.createAction({
      actorId: req.user?.userId || 'unknown',
      action: 'content_report.template.publish',
      targetType: 'moderation_decision_template',
      targetId: item.id,
      detail: { templateKey: item.templateKey, locale: item.locale, version: item.version },
    });
    res.json({ success: true, item });
  } catch (error) {
    console.error('Publish moderation template error:', error);
    res.status(500).json({ error: 'Failed to publish moderation template' });
  }
});

router.post('/content-reports/templates/:id/rollback', authenticate, requireAdminOrOperator, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const id = String(req.params.id || '');
    const target = await prisma.moderationDecisionTemplate.findUnique({ where: { id } });
    if (!target) {
      res.status(404).json({ error: 'Template not found' });
      return;
    }
    await prisma.moderationDecisionTemplate.updateMany({
      where: { templateKey: target.templateKey, locale: target.locale, status: 'published' },
      data: { status: 'archived' },
    });
    const item = await prisma.moderationDecisionTemplate.update({
      where: { id },
      data: { status: 'published', publishedAt: new Date(), publishedBy: req.user?.userId ?? null },
    });
    await adminAuditService.createAction({
      actorId: req.user?.userId || 'unknown',
      action: 'content_report.template.rollback',
      targetType: 'moderation_decision_template',
      targetId: item.id,
      detail: { templateKey: item.templateKey, locale: item.locale, version: item.version },
    });
    res.json({ success: true, item });
  } catch (error) {
    console.error('Rollback moderation template error:', error);
    res.status(500).json({ error: 'Failed to rollback moderation template' });
  }
});

router.post('/content-reports/batch-decision', authenticate, requireAdminOrOperator, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const body = (req.body ?? {}) as Record<string, unknown>;
    const reportIds = normalizeStringArray(body.reportIds, 50);
    const action = normalizeAdminText(body.action, 64) || 'resolve';
    const note = normalizeAdminText(body.note, 2000);

    if (reportIds.length === 0) {
      res.status(400).json({ error: 'reportIds is required' });
      return;
    }
    if (!['resolve', 'dismiss'].includes(action)) {
      res.status(400).json({ error: 'Batch decision only supports resolve or dismiss' });
      return;
    }

    const reports = await prisma.contentReport.findMany({
      where: { id: { in: reportIds } },
      orderBy: [{ createdAt: 'asc' }],
    });
    if (reports.length !== reportIds.length) {
      res.status(404).json({ error: 'One or more reports were not found' });
      return;
    }

    const targetTypes = new Set(reports.map((report) => report.targetType));
    const reasons = new Set(reports.map((report) => report.reason));
    const statuses = new Set(reports.map((report) => report.status));
    const unsafeReports = reports.filter((report) => resolveReportPriority(report.reason) !== 'normal');
    const unresolvedStatuses = new Set(['pending', 'reviewing']);
    const hasClosedReports = Array.from(statuses).some((status) => !unresolvedStatuses.has(status));
    if (targetTypes.size !== 1 || reasons.size !== 1 || unsafeReports.length > 0 || hasClosedReports) {
      res.status(400).json({ error: 'Batch decision requires same target type, same reason, unresolved normal priority reports only' });
      return;
    }

    const previousStatuses = Object.fromEntries(reports.map((report) => [report.id, report.status]));
    const nextStatus = action === 'dismiss' ? 'rejected' : 'resolved';
    const updated = await prisma.contentReport.updateMany({
      where: { id: { in: reportIds } },
      data: {
        status: nextStatus,
        resolutionNote: note || `batch:${action}`,
        resolvedAt: new Date(),
        resolvedBy: req.user?.userId ?? null,
      },
    });

    await adminAuditService.createAction({
      actorId: req.user?.userId || 'unknown',
      action: `content_report.batch.${action}`,
      targetType: 'content_report_batch',
      targetId: reportIds[0],
      detail: {
        reportIds,
        count: reportIds.length,
        targetType: reports[0]?.targetType ?? null,
        reason: reports[0]?.reason ?? null,
        previousStatuses,
        nextStatus,
        note,
      },
    });

    const refreshedRows = await prisma.contentReport.findMany({
      where: { id: { in: reportIds } },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    });
    const items = await enrichContentReportRows(refreshedRows);

    res.json({ success: true, updatedCount: updated.count, items });
  } catch (error) {
    console.error('Admin content report batch decision error:', error);
    res.status(500).json({ error: error instanceof Error ? error.message : 'Failed to process content report batch' });
  }
});

router.get('/content-reports/:id', authenticate, requireAdminOrOperator, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const report = await prisma.contentReport.findUnique({
      where: { id: String(req.params.id || '') },
    });
    if (!report) {
      res.status(404).json({ error: 'Report not found' });
      return;
    }

    const [reporter, targetUser, targetPreview, context, similarReports, targetHistory, enforcementHistory, appealHistory, copyrightStats] = await Promise.all([
      prisma.user.findUnique({ where: { id: report.reporterUserId }, select: userSummarySelect }),
      report.targetUserId
        ? prisma.user.findUnique({ where: { id: report.targetUserId }, select: userSummarySelect })
        : Promise.resolve(null),
      fetchReportTargetPreview(report),
      fetchReportContext(report),
      prisma.contentReport.findMany({
        where: {
          targetType: report.targetType,
          targetId: report.targetId,
          id: { not: report.id },
        },
        orderBy: [{ createdAt: 'desc' }],
        take: 20,
      }),
      report.targetUserId
        ? prisma.contentReport.findMany({
            where: { targetUserId: report.targetUserId },
            orderBy: [{ createdAt: 'desc' }],
            take: 20,
          })
        : Promise.resolve([]),
      report.targetUserId
        ? prisma.accountEnforcement.findMany({
            where: { userId: report.targetUserId },
            orderBy: [{ createdAt: 'desc' }],
            take: 20,
          })
        : Promise.resolve([]),
      report.targetUserId
        ? prisma.enforcementAppeal.findMany({
            where: { userId: report.targetUserId },
            orderBy: [{ createdAt: 'desc' }],
            take: 20,
          })
        : Promise.resolve([]),
      fetchCopyrightStats(report),
    ]);

    const priority = resolveReportPriority(report.reason);
    const slaDueAt = new Date(report.createdAt.getTime() + reportSlaHours(priority) * 60 * 60 * 1000);

    res.json({
      success: true,
      report: {
        ...report,
        reporter,
        targetUser,
        priority,
        slaDueAt: slaDueAt.toISOString(),
        isOverdue: (report.status === 'pending' || report.status === 'reviewing') && slaDueAt.getTime() < Date.now(),
        targetPreview,
        context,
        similarReports,
        targetHistory,
        enforcementHistory,
        appealHistory,
        copyrightStats,
      },
    });
  } catch (error) {
    console.error('Fetch admin content report detail error:', error);
    res.status(500).json({ error: 'Failed to fetch content report detail' });
  }
});

router.post('/content-reports/:id/decision', authenticate, requireAdminOrOperator, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const report = await prisma.contentReport.findUnique({ where: { id: String(req.params.id || '') } });
    if (!report) {
      res.status(404).json({ error: 'Report not found' });
      return;
    }

    const body = (req.body ?? {}) as Record<string, unknown>;
    const action = normalizeAdminText(body.action, 64) || 'resolve';
    const note = normalizeAdminText(body.note, 2000);
    const nextStatus =
      action === 'dismiss'
        ? 'rejected'
        : action === 'escalate'
          ? 'reviewing'
          : 'resolved';
    const copyrightStatsBeforeDecision = await fetchCopyrightStats(report);

    let enforcement: Awaited<ReturnType<typeof accountEnforcementService.createEnforcement>> | null = null;
    if (['warn_user', 'restrict_user', 'suspend_user', 'ban_user'].includes(action)) {
      if (!report.targetUserId) {
        res.status(400).json({ error: 'Report target user is required for account enforcement action' });
        return;
      }
      const now = new Date();
      const durationDays =
        typeof body.durationDays === 'number' && Number.isFinite(body.durationDays)
          ? Math.max(1, Math.min(Math.floor(body.durationDays), 90))
          : action === 'suspend_user'
            ? 7
            : action === 'restrict_user'
              ? 14
              : undefined;
      enforcement = await accountEnforcementService.createEnforcement({
        userId: report.targetUserId,
        type:
          action === 'warn_user'
            ? 'warning'
            : action === 'restrict_user'
              ? 'restriction'
              : action === 'suspend_user'
                ? 'suspension'
                : 'ban',
        scopes: action === 'restrict_user' ? ['post_create', 'comment_create', 'message_send', 'media_upload'] : undefined,
        reasonCode: report.reason,
        internalNote: note || `Created from content report ${report.id}`,
        evidence: {
          reportId: report.id,
          targetType: report.targetType,
          targetId: report.targetId,
          detail: report.detail,
          copyrightStats: copyrightStatsBeforeDecision,
        },
        startsAt: now,
        endsAt: durationDays ? new Date(now.getTime() + durationDays * 24 * 60 * 60 * 1000) : null,
        createdBy: req.user?.userId ?? null,
        createdFromReportId: report.id,
      });
    }

    const targetModeration = ['hide_content', 'restore_content'].includes(action)
      ? await applyContentModerationAction({ report, action })
      : null;

    const metadata = asRecord(report.metadata);
    if (isCopyrightReport(report)) {
      const nowIso = new Date().toISOString();
      const resolvedCopyrightCount = (copyrightStatsBeforeDecision?.resolvedCopyrightCount ?? 0)
        + (nextStatus === 'resolved' && report.status !== 'resolved' ? 1 : 0);
      metadata.copyright = {
        ...asRecord(metadata.copyright),
        complaintWorkflow: true,
        lastDecisionAction: action,
        lastDecisionAt: nowIso,
        lastDecisionBy: req.user?.userId ?? null,
        lastDecisionNote: note,
        takedownStatus:
          action === 'hide_content'
            ? 'active'
            : action === 'restore_content'
              ? 'restored'
              : asRecord(metadata.copyright).takedownStatus ?? null,
        temporaryTakedownAt:
          action === 'hide_content'
            ? nowIso
            : asRecord(metadata.copyright).temporaryTakedownAt ?? null,
        restoredAt:
          action === 'restore_content'
            ? nowIso
            : asRecord(metadata.copyright).restoredAt ?? null,
        previousState: targetModeration?.previousState ?? asRecord(metadata.copyright).previousState ?? null,
        nextState: targetModeration?.nextState ?? asRecord(metadata.copyright).nextState ?? null,
        takedownApplied: targetModeration?.applied ?? false,
        repeatCopyrightCount: resolvedCopyrightCount,
        repeatInfringerThreshold: COPYRIGHT_REPEAT_INFRINGER_THRESHOLD,
        repeatInfringer: resolvedCopyrightCount >= COPYRIGHT_REPEAT_INFRINGER_THRESHOLD,
        repeatInfringerAction:
          ['warn_user', 'restrict_user', 'suspend_user', 'ban_user'].includes(action)
            ? action
            : null,
        enforcementId: enforcement?.id ?? null,
      };
    }

    const updated = await prisma.contentReport.update({
      where: { id: report.id },
      data: {
        status: nextStatus,
        resolutionNote: note || action,
        resolvedAt: nextStatus === 'reviewing' ? null : new Date(),
        resolvedBy: req.user?.userId ?? null,
        metadata: isCopyrightReport(report) ? metadata as Prisma.InputJsonObject : undefined,
      },
    });

    if (nextStatus !== 'reviewing') {
      await notifyReportDecision({ report, action, note });
    }

    await adminAuditService.createAction({
      actorId: req.user?.userId || 'unknown',
      action: `content_report.${action}`,
      targetType: 'content_report',
      targetId: report.id,
      detail: {
        reportId: report.id,
        reportTargetType: report.targetType,
        reportTargetId: report.targetId,
        targetUserId: report.targetUserId,
        previousStatus: report.status,
        nextStatus,
        note,
        enforcementId: enforcement?.id ?? null,
        copyrightStats: copyrightStatsBeforeDecision,
        targetModeration,
      },
    });

    res.json({ success: true, report: updated, enforcement });
  } catch (error) {
    console.error('Admin content report decision error:', error);
    res.status(500).json({ error: error instanceof Error ? error.message : 'Failed to process content report' });
  }
});

router.use('/notifications', forwardToLegacyRouter('/admin', notificationCenterRoutes));
router.use('/pre-registrations', forwardToLegacyRouter('/admin/pre-registrations', preRegistrationRoutes));
router.use('/pre-registration-batches', forwardToLegacyRouter('/admin/pre-registration-batches', preRegistrationRoutes));
router.use('/pre-registration-notifications', forwardToLegacyRouter('/admin/pre-registration-notifications', preRegistrationRoutes));
router.use('/content-submissions', forwardToLegacyRouter('/admin', contentSubmissionRoutes));
router.use('/checkins', forwardToLegacyRouter('/admin/checkins', checkinsV2Routes));
router.use('/virtual-assets', forwardToLegacyRouter('/admin/virtual-assets', virtualAssetRoutes));
router.use('/', forwardToLegacyRouter('/admin', accountEnforcementRoutes));

export default router;
