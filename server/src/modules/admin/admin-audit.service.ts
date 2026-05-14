import { Prisma, PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

type AdminAuditActionInput = {
  actorId: string;
  action: string;
  targetType: string;
  targetId: string;
  detail?: Prisma.InputJsonValue | null;
};

type ListAdminAuditLogsInput = {
  limit?: number;
  actorId?: string;
  action?: string;
  targetType?: string;
  targetId?: string;
  before?: Date;
};

const normalizeRequiredText = (value: string, fieldName: string): string => {
  const trimmed = value.trim();
  if (!trimmed) {
    throw new Error(`${fieldName} is required`);
  }
  return trimmed;
};

export const buildAdminAuditLogCreateData = (input: AdminAuditActionInput): Prisma.AdminAuditLogCreateInput => ({
  actorId: normalizeRequiredText(input.actorId, 'actorId'),
  action: normalizeRequiredText(input.action, 'action'),
  targetType: normalizeRequiredText(input.targetType, 'targetType'),
  targetId: normalizeRequiredText(input.targetId, 'targetId'),
  detail: input.detail ?? undefined,
});

const normalizeOptionalText = (value?: string): string | undefined => {
  const trimmed = value?.trim();
  return trimmed || undefined;
};

const normalizeLimit = (value: number | undefined, fallback = 50, max = 200): number => {
  if (!Number.isFinite(value) || !value || value <= 0) {
    return fallback;
  }
  return Math.min(Math.floor(value), max);
};

export const adminAuditService = {
  createAction(input: AdminAuditActionInput) {
    return prisma.adminAuditLog.create({
      data: buildAdminAuditLogCreateData(input),
    });
  },

  async listLogs(input: ListAdminAuditLogsInput = {}) {
    const limit = normalizeLimit(input.limit);
    const actorId = normalizeOptionalText(input.actorId);
    const action = normalizeOptionalText(input.action);
    const targetType = normalizeOptionalText(input.targetType);
    const targetId = normalizeOptionalText(input.targetId);

    const where: Prisma.AdminAuditLogWhereInput = {};
    if (actorId) where.actorId = actorId;
    if (action) where.action = action;
    if (targetType) where.targetType = targetType;
    if (targetId) where.targetId = targetId;
    if (input.before && !Number.isNaN(input.before.getTime())) {
      where.createdAt = { lt: input.before };
    }

    const items = await prisma.adminAuditLog.findMany({
      where,
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
      select: {
        id: true,
        actorId: true,
        action: true,
        targetType: true,
        targetId: true,
        detail: true,
        createdAt: true,
      },
    });

    const pageItems = items.slice(0, limit);
    return {
      items: pageItems,
      nextCursor: items.length > limit ? pageItems[pageItems.length - 1]?.createdAt.toISOString() ?? null : null,
    };
  },
};
