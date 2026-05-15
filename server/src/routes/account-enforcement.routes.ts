import { Request, Response, Router } from 'express';
import { authenticate, AuthRequest } from '../middleware/auth';
import { adminAuditService } from '../modules/admin/admin-audit.service';
import { requireAdmin, requireAdminOrOperator } from '../modules/admin/admin-auth.policy';
import { notificationCenterService } from '../modules/notifications';
import { accountEnforcementService } from '../services/account-enforcement.service';
import { normalizeTriTextPayload, resolveLocalizedText, type TriTextPayload } from '../utils/i18n';

const router: Router = Router();

const parseLimit = (value: unknown, fallback = 50, max = 200): number => {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) return fallback;
  return Math.min(Math.floor(parsed), max);
};

const parseDate = (value: unknown): Date | null => {
  if (typeof value !== 'string' || !value.trim()) return null;
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
};

const parseScopes = (value: unknown): string[] => {
  if (!Array.isArray(value)) return [];
  return value.map((item) => String(item || '').trim()).filter(Boolean);
};

const parseDurationDays = (value: unknown): number | null => {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) return null;
  return Math.min(Math.floor(parsed), 3650);
};

const routeParam = (value: unknown): string => {
  if (Array.isArray(value)) return String(value[0] || '');
  return String(value || '');
};

const enforcementTypeLabel = (type: string): string => {
  const labels: Record<string, string> = {
    warning: '警告',
    content_action: '内容处置',
    restriction: '功能限制',
    suspension: '临时封禁',
    ban: '永久封禁',
    risk_freeze: '风控冻结',
  };
  return labels[type] || '账号处置';
};

const enforcementTypeLabelI18n = (type: string): TriTextPayload => {
  const labels: Record<string, TriTextPayload> = {
    warning: { zh: '警告', en: 'warning', ja: '警告' },
    content_action: { zh: '内容处置', en: 'content action', ja: 'コンテンツ対応' },
    restriction: { zh: '功能限制', en: 'feature restriction', ja: '機能制限' },
    suspension: { zh: '临时封禁', en: 'temporary suspension', ja: '一時停止' },
    ban: { zh: '永久封禁', en: 'permanent ban', ja: '永久停止' },
    risk_freeze: { zh: '风控冻结', en: 'risk freeze', ja: 'リスク制限' },
  };
  return labels[type] || { zh: enforcementTypeLabel(type), en: 'account action', ja: 'アカウント対応' };
};

const formatEndsAtI18n = (value: Date | string | null | undefined): TriTextPayload => {
  if (!value) {
    return {
      zh: '无固定到期时间',
      en: 'No fixed end time',
      ja: '終了日時は未定です',
    };
  }
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) {
    return {
      zh: '无固定到期时间',
      en: 'No fixed end time',
      ja: '終了日時は未定です',
    };
  }
  return {
    zh: date.toLocaleString('zh-CN', { hour12: false }),
    en: date.toLocaleString('en-US', { hour12: false }),
    ja: date.toLocaleString('ja-JP', { hour12: false }),
  };
};

const enforcementReasonTextI18n = (reasonCode: string): TriTextPayload => {
  const normalized = String(reasonCode || '').trim().toLowerCase();
  const labels: Record<string, TriTextPayload> = {
    spam: { zh: '垃圾信息或刷屏', en: 'Spam or flooding', ja: 'スパムまたは連投' },
    harassment: { zh: '骚扰、辱骂或霸凌', en: 'Harassment or bullying', ja: '嫌がらせ、侮辱、いじめ' },
    hate_or_discrimination: { zh: '仇恨或歧视', en: 'Hate or discrimination', ja: 'ヘイトまたは差別' },
    sexual_content: { zh: '色情或露骨内容', en: 'Sexual content', ja: '性的または露骨な内容' },
    violence_or_threat: { zh: '暴力威胁', en: 'Violence or threats', ja: '暴力や脅迫' },
    illegal_activity: { zh: '违法活动', en: 'Illegal activity', ja: '違法行為' },
    impersonation: { zh: '冒充他人', en: 'Impersonation', ja: 'なりすまし' },
    privacy_violation: { zh: '泄露隐私', en: 'Privacy violation', ja: 'プライバシー侵害' },
    copyright: { zh: '版权侵权', en: 'Copyright infringement', ja: '著作権侵害' },
    scam_or_fraud: { zh: '诈骗或钓鱼', en: 'Scam or fraud', ja: '詐欺またはフィッシング' },
    minor_safety: { zh: '未成年人安全', en: 'Minor safety', ja: '未成年者の安全' },
    platform_abuse: { zh: '平台滥用', en: 'Platform abuse', ja: 'プラットフォーム悪用' },
  };
  return labels[normalized] || {
    zh: '违反社区规范',
    en: 'Community guideline violation',
    ja: 'コミュニティガイドライン違反',
  };
};

const publishEnforcementNotice = async (input: {
  userId: string;
  enforcementId: string;
  titleI18n: TriTextPayload;
  bodyI18n: TriTextPayload;
  source: string;
  dedupeKey: string;
  metadata?: Record<string, unknown>;
}): Promise<void> => {
  const titleI18n = normalizeTriTextPayload(input.titleI18n, '') || input.titleI18n;
  const bodyI18n = normalizeTriTextPayload(input.bodyI18n, '') || input.bodyI18n;
  try {
    await notificationCenterService.publish({
      category: 'account_enforcement',
      targets: [{ userId: input.userId }],
      channels: ['in_app', 'apns'],
      dedupeKey: input.dedupeKey,
      payload: {
        title: resolveLocalizedText(titleI18n, '', ['ja', 'en', 'zh']),
        body: resolveLocalizedText(bodyI18n, '', ['ja', 'en', 'zh']),
        deeplink: `raver://account/enforcements/${input.enforcementId}`,
        metadata: {
          source: input.source,
          enforcementId: input.enforcementId,
          titleI18n,
          bodyI18n,
          message: resolveLocalizedText(bodyI18n, '', ['ja', 'en', 'zh']),
          ...input.metadata,
        },
      },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.warn(`[notification-center] account enforcement notice failed: ${message}`);
  }
};

router.get(
  '/admin/account-enforcements',
  authenticate,
  requireAdminOrOperator,
  async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const items = await accountEnforcementService.listEnforcements({
        userId: typeof req.query.userId === 'string' ? req.query.userId : undefined,
        status: typeof req.query.status === 'string' ? req.query.status : undefined,
        type: typeof req.query.type === 'string' ? req.query.type : undefined,
        limit: parseLimit(req.query.limit),
      });
      res.json({ success: true, items });
    } catch (error) {
      console.error('List account enforcements error:', error);
      res.status(500).json({ error: 'Failed to list account enforcements' });
    }
  }
);

router.post(
  '/admin/users/:id/enforcements',
  authenticate,
  requireAdminOrOperator,
  async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const body = req.body as {
        type?: string;
        scopes?: unknown;
        reasonCode?: string;
        userMessageI18n?: unknown;
        internalNote?: string;
        evidence?: unknown;
        startsAt?: string;
        endsAt?: string;
        durationDays?: unknown;
        createdFromReportId?: string;
        createdFromCaseId?: string;
      };

      const startsAt = parseDate(body.startsAt) || new Date();
      const explicitEndsAt = parseDate(body.endsAt);
      const durationDays = parseDurationDays(body.durationDays);
      const endsAt = explicitEndsAt || (durationDays ? new Date(startsAt.getTime() + durationDays * 24 * 60 * 60 * 1000) : null);

      const enforcement = await accountEnforcementService.createEnforcement({
        userId: routeParam(req.params.id),
        type: String(body.type || ''),
        scopes: parseScopes(body.scopes),
        reasonCode: String(body.reasonCode || ''),
        userMessageI18n: body.userMessageI18n as never,
        internalNote: body.internalNote || null,
        evidence: body.evidence as never,
        startsAt,
        endsAt,
        createdBy: req.user?.userId || null,
        createdFromReportId: body.createdFromReportId || null,
        createdFromCaseId: body.createdFromCaseId || null,
      });

      await adminAuditService.createAction({
        actorId: req.user?.userId || 'unknown',
        action: 'account_enforcement.create',
        targetType: 'user',
        targetId: routeParam(req.params.id),
        detail: {
          enforcementId: enforcement.id,
          type: enforcement.type,
          scopes: enforcement.scopes,
          reasonCode: enforcement.reasonCode,
          startsAt: enforcement.startsAt,
          endsAt: enforcement.endsAt,
          createdFromReportId: enforcement.createdFromReportId,
          createdFromCaseId: enforcement.createdFromCaseId,
        },
      });

      await publishEnforcementNotice({
        userId: enforcement.userId,
        enforcementId: enforcement.id,
        titleI18n: {
          zh: `账号${enforcementTypeLabelI18n(enforcement.type).zh}已生效`,
          en: `Account ${enforcementTypeLabelI18n(enforcement.type).en} is now active`,
          ja: `アカウントの${enforcementTypeLabelI18n(enforcement.type).ja}が有効になりました`,
        },
        bodyI18n: {
          zh: `原因：${enforcementReasonTextI18n(enforcement.reasonCode).zh}。到期时间：${formatEndsAtI18n(enforcement.endsAt).zh}。你可以在账号状态页查看详情并提交申诉。`,
          en: `Reason: ${enforcementReasonTextI18n(enforcement.reasonCode).en}. Ends at: ${formatEndsAtI18n(enforcement.endsAt).en}. You can view details and submit an appeal from Account Status.`,
          ja: `理由：${enforcementReasonTextI18n(enforcement.reasonCode).ja}。終了日時：${formatEndsAtI18n(enforcement.endsAt).ja}。アカウントステータスで詳細確認と異議申し立てができます。`,
        },
        source: 'account_enforcement_create',
        dedupeKey: `account_enforcement:create:${enforcement.id}`,
        metadata: {
          type: enforcement.type,
          status: enforcement.status,
          reasonCode: enforcement.reasonCode,
          reasonTextI18n: enforcementReasonTextI18n(enforcement.reasonCode),
          scopes: enforcement.scopes,
          endsAt: enforcement.endsAt ? enforcement.endsAt.toISOString() : null,
        },
      });

      res.status(201).json({ success: true, enforcement });
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      res.status(400).json({ error: message || 'Failed to create account enforcement' });
    }
  }
);

router.post(
  '/admin/account-enforcements/:id/revoke',
  authenticate,
  requireAdminOrOperator,
  async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const body = req.body as { reason?: string };
      const enforcement = await accountEnforcementService.revokeEnforcement(
        routeParam(req.params.id),
        req.user?.userId || 'unknown',
        body.reason || null
      );

      await adminAuditService.createAction({
        actorId: req.user?.userId || 'unknown',
        action: 'account_enforcement.revoke',
        targetType: 'account_enforcement',
        targetId: routeParam(req.params.id),
        detail: {
          userId: enforcement.userId,
          reason: body.reason || null,
        },
      });

      await publishEnforcementNotice({
        userId: enforcement.userId,
        enforcementId: enforcement.id,
        titleI18n: {
          zh: '账号处罚已撤销',
          en: 'Account enforcement revoked',
          ja: 'アカウント制限が解除されました',
        },
        bodyI18n: {
          zh: `你的账号处罚已撤销。${body.reason ? `原因：${body.reason}` : '你可以继续使用已恢复的功能。'}`,
          en: `Your account enforcement has been revoked. ${body.reason ? `Reason: ${body.reason}` : 'You can continue using the restored features.'}`,
          ja: `アカウント制限が解除されました。${body.reason ? `理由：${body.reason}` : '復元された機能を引き続き利用できます。'}`,
        },
        source: 'account_enforcement_revoke',
        dedupeKey: `account_enforcement:revoke:${enforcement.id}:${enforcement.revokedAt?.toISOString() || Date.now()}`,
        metadata: {
          type: enforcement.type,
          reasonCode: enforcement.reasonCode,
          revocationReason: body.reason || null,
        },
      });

      res.json({ success: true, enforcement });
    } catch (error) {
      console.error('Revoke account enforcement error:', error);
      res.status(400).json({ error: 'Failed to revoke account enforcement' });
    }
  }
);

router.post(
  '/admin/account-enforcements/expire-due',
  authenticate,
  requireAdmin,
  async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const [activated, expired] = await Promise.all([
        accountEnforcementService.activateScheduledEnforcements(),
        accountEnforcementService.expireDueEnforcements(),
      ]);

      await adminAuditService.createAction({
        actorId: req.user?.userId || 'unknown',
        action: 'account_enforcement.expire_due',
        targetType: 'account_enforcement',
        targetId: 'bulk',
        detail: { activatedCount: activated.count, expiredCount: expired.count },
      });

      res.json({ success: true, activatedCount: activated.count, expiredCount: expired.count });
    } catch (error) {
      console.error('Expire due account enforcements error:', error);
      res.status(500).json({ error: 'Failed to expire due account enforcements' });
    }
  }
);

router.get(
  '/admin/enforcement-appeals',
  authenticate,
  requireAdminOrOperator,
  async (req: Request, res: Response): Promise<void> => {
    try {
      const items = await accountEnforcementService.listAppeals({
        userId: typeof req.query.userId === 'string' ? req.query.userId : undefined,
        status: typeof req.query.status === 'string' ? req.query.status : undefined,
        limit: parseLimit(req.query.limit),
      });
      res.json({ success: true, items });
    } catch (error) {
      console.error('List enforcement appeals error:', error);
      res.status(500).json({ error: 'Failed to list enforcement appeals' });
    }
  }
);

router.post(
  '/admin/enforcement-appeals/:id/decision',
  authenticate,
  requireAdminOrOperator,
  async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const body = req.body as {
        status?: string;
        decision?: string;
        decisionNote?: string;
      };
      const appeal = await accountEnforcementService.decideAppeal({
        appealId: routeParam(req.params.id),
        reviewerId: req.user?.userId || 'unknown',
        status: String(body.status || ''),
        decision: String(body.decision || ''),
        decisionNote: body.decisionNote || null,
      });

      await adminAuditService.createAction({
        actorId: req.user?.userId || 'unknown',
        action: 'enforcement_appeal.decision',
        targetType: 'enforcement_appeal',
        targetId: routeParam(req.params.id),
        detail: {
          enforcementId: appeal.enforcementId,
          userId: appeal.userId,
          status: appeal.status,
          decision: appeal.decision,
        },
      });

      await publishEnforcementNotice({
        userId: appeal.userId,
        enforcementId: appeal.enforcementId,
        titleI18n: {
          zh: appeal.status === 'accepted' ? '账号处罚申诉已通过' : appeal.status === 'rejected' ? '账号处罚申诉未通过' : '账号处罚申诉已更新',
          en: appeal.status === 'accepted' ? 'Account appeal accepted' : appeal.status === 'rejected' ? 'Account appeal rejected' : 'Account appeal updated',
          ja: appeal.status === 'accepted' ? 'アカウント制限への異議申し立てが承認されました' : appeal.status === 'rejected' ? 'アカウント制限への異議申し立ては承認されませんでした' : 'アカウント制限への異議申し立てが更新されました',
        },
        bodyI18n: {
          zh: appeal.decisionNote || `申诉处理结果：${appeal.decision || appeal.status}`,
          en: appeal.decisionNote || `Appeal decision: ${appeal.decision || appeal.status}`,
          ja: appeal.decisionNote || `異議申し立ての結果：${appeal.decision || appeal.status}`,
        },
        source: 'enforcement_appeal_decision',
        dedupeKey: `enforcement_appeal:decision:${appeal.id}:${appeal.status}`,
        metadata: {
          appealId: appeal.id,
          status: appeal.status,
          decision: appeal.decision,
        },
      });

      res.json({ success: true, appeal });
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      res.status(400).json({ error: message || 'Failed to decide enforcement appeal' });
    }
  }
);

export default router;
