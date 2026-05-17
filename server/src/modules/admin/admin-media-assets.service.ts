import { PrismaClient } from '@prisma/client';
import { mediaAssetService } from '../../services/media-asset.service';

const prisma = new PrismaClient();

const parseLimit = (value: unknown, fallback = 50, max = 200): number => {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) return fallback;
  return Math.min(Math.floor(parsed), max);
};

const normalizeStatuses = (value: unknown): string[] => {
  const items = Array.isArray(value) ? value : typeof value === 'string' ? value.split(',') : [];
  return items
    .map((item) => String(item || '').trim())
    .filter(Boolean)
    .slice(0, 10);
};

export const adminMediaAssetsService = {
  async getSummary() {
    const [statusCounts, providerCounts, purgeFailures, pendingPurge] = await Promise.all([
      prisma.mediaAsset.groupBy({
        by: ['status'],
        _count: { _all: true },
      }),
      prisma.mediaAsset.groupBy({
        by: ['provider'],
        _count: { _all: true },
      }),
      prisma.mediaAsset.count({
        where: {
          purgeLastError: { not: null },
          purgedAt: null,
        },
      }),
      prisma.mediaAsset.count({
        where: {
          status: { in: ['replaced', 'deleted'] },
          purgedAt: null,
        },
      }),
    ]);

    return {
      checkedAt: new Date(),
      byStatus: statusCounts.map((row) => ({ status: row.status, count: row._count._all })),
      byProvider: providerCounts.map((row) => ({ provider: row.provider, count: row._count._all })),
      purgeFailures,
      pendingPurge,
    };
  },

  async listAssets(input: {
    status?: unknown;
    ownerType?: unknown;
    provider?: unknown;
    q?: unknown;
    limit?: unknown;
  }) {
    const statuses = normalizeStatuses(input.status);
    const ownerType = typeof input.ownerType === 'string' ? input.ownerType.trim() : '';
    const provider = typeof input.provider === 'string' ? input.provider.trim() : '';
    const q = typeof input.q === 'string' ? input.q.trim() : '';
    const limit = parseLimit(input.limit, 50, 200);

    return prisma.mediaAsset.findMany({
      where: {
        ...(statuses.length > 0 ? { status: { in: statuses } } : {}),
        ...(ownerType ? { ownerType } : {}),
        ...(provider ? { provider } : {}),
        ...(q
          ? {
              OR: [
                { ownerId: { contains: q, mode: 'insensitive' } },
                { objectKey: { contains: q, mode: 'insensitive' } },
                { url: { contains: q, mode: 'insensitive' } },
                { purpose: { contains: q, mode: 'insensitive' } },
              ],
            }
          : {}),
      },
      orderBy: [{ updatedAt: 'desc' }],
      take: limit,
    });
  },

  async runPurgeNow(input: { limit?: unknown }) {
    const limit = parseLimit(input.limit, 20, 100);
    return mediaAssetService.purgePendingAssets(limit);
  },
};
