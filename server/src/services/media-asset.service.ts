import { Prisma, PrismaClient } from '@prisma/client';
import { deleteObjectStorageObject } from './media-storage.service';

const prisma = new PrismaClient();

type RegisterMediaAssetInput = {
  ownerType: string;
  ownerId?: string | null;
  purpose: string;
  provider: 'oss' | 'local';
  bucket?: string | null;
  objectKey?: string | null;
  url: string;
  mimeType?: string | null;
  sizeBytes?: number | null;
  uploadedById?: string | null;
  metadata?: Prisma.InputJsonValue | null;
};

const cleanEnv = (value: string | undefined): string | null => {
  if (!value) return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
};

const ossBucket = cleanEnv(process.env.OSS_BUCKET);

export const mediaAssetService = {
  async register(input: RegisterMediaAssetInput) {
    return prisma.mediaAsset.create({
      data: {
        ownerType: input.ownerType,
        ownerId: input.ownerId || null,
        purpose: input.purpose,
        provider: input.provider,
        bucket: input.bucket ?? (input.provider === 'oss' ? ossBucket : null),
        objectKey: input.objectKey || null,
        url: input.url,
        mimeType: input.mimeType || null,
        sizeBytes: input.sizeBytes ?? null,
        uploadedById: input.uploadedById || null,
        metadata: input.metadata || undefined,
      },
    });
  },

  async markReplacedByUrl(url: string | null | undefined) {
    const normalized = String(url || '').trim();
    if (!normalized) return { count: 0 };

    return prisma.mediaAsset.updateMany({
      where: {
        url: normalized,
        status: 'active',
      },
      data: {
        status: 'replaced',
        purgeNextRunAt: new Date(),
      },
    });
  },

  async markDeletedByUrl(url: string | null | undefined) {
    const normalized = String(url || '').trim();
    if (!normalized) return { count: 0 };

    return prisma.mediaAsset.updateMany({
      where: {
        url: normalized,
        status: {
          in: ['active', 'replaced'],
        },
      },
      data: {
        status: 'deleted',
        deletedAt: new Date(),
        purgeNextRunAt: new Date(),
      },
    });
  },

  async purgePendingAssets(limit = 20) {
    const candidates = await prisma.mediaAsset.findMany({
      where: {
        provider: 'oss',
        objectKey: {
          not: null,
        },
        status: {
          in: ['replaced', 'deleted'],
        },
        purgedAt: null,
        purgeNextRunAt: {
          lte: new Date(),
        },
      },
      orderBy: [
        { purgeNextRunAt: 'asc' },
        { updatedAt: 'asc' },
      ],
      take: limit,
    });

    let purgedCount = 0;
    let failedCount = 0;

    for (const asset of candidates) {
      const objectKey = asset.objectKey?.trim();
      if (!objectKey) continue;

      try {
        await deleteObjectStorageObject(objectKey);
        await prisma.mediaAsset.update({
          where: { id: asset.id },
          data: {
            status: 'purged',
            purgedAt: new Date(),
            purgeLastError: null,
          },
        });
        purgedCount += 1;
      } catch (error) {
        failedCount += 1;
        const nextAttempts = asset.purgeAttempts + 1;
        const delayMinutes = Math.min(60 * 24, Math.max(5, nextAttempts * 10));
        const nextRunAt = new Date(Date.now() + delayMinutes * 60 * 1000);
        const message = error instanceof Error ? error.message : String(error);

        await prisma.mediaAsset.update({
          where: { id: asset.id },
          data: {
            purgeAttempts: nextAttempts,
            purgeNextRunAt: nextRunAt,
            purgeLastError: message.slice(0, 4000),
          },
        });
      }
    }

    return {
      scannedCount: candidates.length,
      purgedCount,
      failedCount,
    };
  },
};
