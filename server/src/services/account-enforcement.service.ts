import { Prisma, PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

export const ENFORCEMENT_TYPES = ['warning', 'content_action', 'restriction', 'suspension', 'ban', 'risk_freeze'] as const;
export const ENFORCEMENT_STATUSES = ['active', 'scheduled', 'expired', 'revoked'] as const;
export const ENFORCEMENT_APPEAL_STATUSES = [
  'submitted',
  'under_review',
  'need_more_info',
  'accepted',
  'rejected',
  'closed',
] as const;

export const ENFORCEMENT_SCOPES = [
  'login',
  'post_create',
  'comment_create',
  'message_send',
  'media_upload',
  'event_create',
  'location_share',
  'profile_update',
  'squad_create',
] as const;

export type EnforcementType = (typeof ENFORCEMENT_TYPES)[number];
export type EnforcementScope = (typeof ENFORCEMENT_SCOPES)[number];

export type ActiveEnforcementSummary = {
  id: string;
  type: string;
  scopes: string[];
  reasonCode: string;
  userMessageI18n: Prisma.JsonValue | null;
  startsAt: Date;
  endsAt: Date | null;
};

export type AccountEnforcementStatus = {
  userId: string;
  accountStatus: string;
  enforcementStatus: string;
  scopes: string[];
  nextReviewAt: string | null;
  appealable: boolean;
  activeEnforcements: ReturnType<typeof serializeEnforcement>[];
} | null;

type CreateEnforcementInput = {
  userId: string;
  type: string;
  scopes?: string[];
  reasonCode: string;
  userMessageI18n?: Prisma.InputJsonValue | null;
  internalNote?: string | null;
  evidence?: Prisma.InputJsonValue | null;
  startsAt?: Date;
  endsAt?: Date | null;
  createdBy?: string | null;
  createdFromReportId?: string | null;
  createdFromCaseId?: string | null;
};

type ListEnforcementsInput = {
  userId?: string;
  status?: string;
  type?: string;
  limit?: number;
};

type CreateAppealInput = {
  enforcementId: string;
  userId: string;
  appealReason: string;
  attachments?: Prisma.InputJsonValue | null;
  contactEmail?: string | null;
};

const normalizeText = (value: unknown, maxLength: number): string | null => {
  if (typeof value !== 'string') return null;
  const normalized = value.trim().replace(/\s+/g, ' ');
  return normalized ? normalized.slice(0, maxLength) : null;
};

const normalizeTextRequired = (value: unknown, fieldName: string, maxLength: number): string => {
  const normalized = normalizeText(value, maxLength);
  if (!normalized) {
    throw new Error(`${fieldName} is required`);
  }
  return normalized;
};

const normalizeLimit = (value: number | undefined, fallback = 50, max = 200): number => {
  if (!Number.isFinite(value) || !value || value <= 0) return fallback;
  return Math.min(Math.floor(value), max);
};

const isAllowedType = (value: string): value is EnforcementType =>
  ENFORCEMENT_TYPES.includes(value as EnforcementType);

const normalizeScopes = (type: string, scopes: string[] | undefined): string[] => {
  if (type === 'warning' || type === 'content_action') return [];
  if (type === 'suspension' || type === 'ban') return ['login'];
  const normalized = Array.from(
    new Set(
      (scopes || [])
        .map((item) => normalizeText(item, 64))
        .filter((item): item is string => Boolean(item))
    )
  );
  const invalid = normalized.filter((item) => !ENFORCEMENT_SCOPES.includes(item as EnforcementScope));
  if (invalid.length > 0) {
    throw new Error(`Unsupported enforcement scope: ${invalid[0]}`);
  }
  if ((type === 'restriction' || type === 'risk_freeze') && normalized.length === 0) {
    throw new Error('scopes are required for restriction/risk_freeze');
  }
  return normalized;
};

const serializeEnforcement = (item: ActiveEnforcementSummary) => ({
  id: item.id,
  type: item.type,
  scopes: item.scopes,
  reasonCode: item.reasonCode,
  userMessageI18n: item.userMessageI18n,
  startsAt: item.startsAt.toISOString(),
  endsAt: item.endsAt ? item.endsAt.toISOString() : null,
});

const activeWhereForUser = (userId: string, now: Date): Prisma.AccountEnforcementWhereInput => ({
  userId,
  status: 'active',
  startsAt: { lte: now },
  OR: [{ endsAt: null }, { endsAt: { gt: now } }],
  revokedAt: null,
});

export const accountEnforcementService = {
  async createEnforcement(input: CreateEnforcementInput) {
    const type = normalizeTextRequired(input.type, 'type', 64);
    if (!isAllowedType(type)) {
      throw new Error(`Unsupported enforcement type: ${type}`);
    }

    const startsAt = input.startsAt || new Date();
    const endsAt = input.endsAt ?? null;
    if (endsAt && endsAt.getTime() <= startsAt.getTime()) {
      throw new Error('endsAt must be after startsAt');
    }

    const data = {
      userId: normalizeTextRequired(input.userId, 'userId', 128),
      status: startsAt.getTime() > Date.now() ? 'scheduled' : 'active',
      type,
      scopes: normalizeScopes(type, input.scopes),
      reasonCode: normalizeTextRequired(input.reasonCode, 'reasonCode', 128),
      userMessageI18n: input.userMessageI18n ?? undefined,
      internalNote: normalizeText(input.internalNote, 5000),
      evidence: input.evidence ?? undefined,
      startsAt,
      endsAt,
      createdBy: normalizeText(input.createdBy, 128),
      createdFromReportId: normalizeText(input.createdFromReportId, 128),
      createdFromCaseId: normalizeText(input.createdFromCaseId, 128),
    };

    return prisma.accountEnforcement.create({
      data,
      include: {
        user: {
          select: {
            id: true,
            username: true,
            displayName: true,
            email: true,
          },
        },
      },
    });
  },

  async revokeEnforcement(id: string, revokedBy: string, reason?: string | null) {
    const now = new Date();
    return prisma.accountEnforcement.update({
      where: { id },
      data: {
        status: 'revoked',
        revokedAt: now,
        revokedBy,
        revocationReason: normalizeText(reason, 5000),
      },
    });
  },

  async expireDueEnforcements(now = new Date()) {
    return prisma.accountEnforcement.updateMany({
      where: {
        status: 'active',
        endsAt: { lte: now },
        revokedAt: null,
      },
      data: { status: 'expired' },
    });
  },

  async activateScheduledEnforcements(now = new Date()) {
    return prisma.accountEnforcement.updateMany({
      where: {
        status: 'scheduled',
        startsAt: { lte: now },
        revokedAt: null,
        OR: [{ endsAt: null }, { endsAt: { gt: now } }],
      },
      data: { status: 'active' },
    });
  },

  async listEnforcements(input: ListEnforcementsInput = {}) {
    const where: Prisma.AccountEnforcementWhereInput = {};
    const userId = normalizeText(input.userId, 128);
    const status = normalizeText(input.status, 64);
    const type = normalizeText(input.type, 64);
    if (userId) where.userId = userId;
    if (status) where.status = status;
    if (type) where.type = type;

    return prisma.accountEnforcement.findMany({
      where,
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: normalizeLimit(input.limit),
      include: {
        user: {
          select: {
            id: true,
            username: true,
            displayName: true,
            email: true,
          },
        },
        appeals: {
          orderBy: { createdAt: 'desc' },
          take: 3,
        },
      },
    });
  },

  async getActiveEnforcements(userId: string, now = new Date()): Promise<ActiveEnforcementSummary[]> {
    await this.expireDueEnforcements(now);
    await this.activateScheduledEnforcements(now);
    return prisma.accountEnforcement.findMany({
      where: activeWhereForUser(userId, now),
      orderBy: [{ startsAt: 'desc' }, { id: 'desc' }],
      select: {
        id: true,
        type: true,
        scopes: true,
        reasonCode: true,
        userMessageI18n: true,
        startsAt: true,
        endsAt: true,
      },
    });
  },

  async getAccountStatus(userId: string) {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, isActive: true },
    });
    if (!user) return null;

    const activeEnforcements = await this.getActiveEnforcements(userId);
    const scopes = Array.from(new Set(activeEnforcements.flatMap((item) => item.scopes)));
    const hasBan = activeEnforcements.some((item) => item.type === 'ban');
    const hasSuspension = activeEnforcements.some((item) => item.type === 'suspension');
    const hasRestriction = activeEnforcements.some((item) => item.type === 'restriction' || item.type === 'risk_freeze');
    const finiteEndsAt = activeEnforcements
      .map((item) => item.endsAt)
      .filter((item): item is Date => Boolean(item))
      .sort((a, b) => a.getTime() - b.getTime());

    return {
      userId,
      accountStatus: user.isActive ? 'active' : 'disabled',
      enforcementStatus: hasBan ? 'banned' : hasSuspension ? 'suspended' : hasRestriction ? 'restricted' : 'none',
      scopes,
      nextReviewAt: finiteEndsAt[0] ? finiteEndsAt[0].toISOString() : null,
      appealable: activeEnforcements.length > 0,
      activeEnforcements: activeEnforcements.map(serializeEnforcement),
    };
  },

  async assertAllowed(userId: string, scope: EnforcementScope): Promise<{
    allowed: boolean;
    status: AccountEnforcementStatus;
    blockingEnforcements: ActiveEnforcementSummary[];
  }> {
    const status = await this.getAccountStatus(userId);
    if (!status) {
      return { allowed: false, status, blockingEnforcements: [] };
    }
    const activeEnforcements = await this.getActiveEnforcements(userId);
    const blockingEnforcements = activeEnforcements.filter((item) => item.scopes.includes(scope) || item.scopes.includes('login'));
    return {
      allowed: status.accountStatus === 'active' && blockingEnforcements.length === 0,
      status,
      blockingEnforcements,
    };
  },

  async createAppeal(input: CreateAppealInput) {
    const enforcement = await prisma.accountEnforcement.findFirst({
      where: {
        id: input.enforcementId,
        userId: input.userId,
      },
      select: { id: true, userId: true, status: true },
    });
    if (!enforcement) {
      throw new Error('enforcement_not_found');
    }

    return prisma.enforcementAppeal.create({
      data: {
        enforcementId: enforcement.id,
        userId: input.userId,
        appealReason: normalizeTextRequired(input.appealReason, 'appealReason', 5000),
        attachments: input.attachments ?? undefined,
        contactEmail: normalizeText(input.contactEmail, 320),
      },
    });
  },

  async listAppeals(input: { userId?: string; status?: string; limit?: number } = {}) {
    const where: Prisma.EnforcementAppealWhereInput = {};
    const userId = normalizeText(input.userId, 128);
    const status = normalizeText(input.status, 64);
    if (userId) where.userId = userId;
    if (status) where.status = status;

    return prisma.enforcementAppeal.findMany({
      where,
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: normalizeLimit(input.limit),
      include: {
        enforcement: true,
      },
    });
  },

  async decideAppeal(input: {
    appealId: string;
    reviewerId: string;
    status: string;
    decision: string;
    decisionNote?: string | null;
  }) {
    const status = normalizeTextRequired(input.status, 'status', 64);
    if (!ENFORCEMENT_APPEAL_STATUSES.includes(status as (typeof ENFORCEMENT_APPEAL_STATUSES)[number])) {
      throw new Error(`Unsupported appeal status: ${status}`);
    }
    return prisma.enforcementAppeal.update({
      where: { id: input.appealId },
      data: {
        status,
        reviewerId: input.reviewerId,
        decision: normalizeTextRequired(input.decision, 'decision', 128),
        decisionNote: normalizeText(input.decisionNote, 5000),
        reviewedAt: new Date(),
      },
      include: {
        enforcement: true,
      },
    });
  },
};
