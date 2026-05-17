import 'dotenv/config';
import fs from 'fs/promises';
import path from 'path';
import { Prisma, PrismaClient } from '@prisma/client';
import {
  buildMediaObjectKey,
  uploadFileToObjectStorage,
} from '../services/media-storage.service';
import { mediaAssetService } from '../services/media-asset.service';

const prisma = new PrismaClient();

type Candidate = {
  key: string;
  ownerType: string;
  ownerId: string;
  purpose: string;
  url: string;
  update: (nextUrl: string) => Promise<void>;
};

const args = new Set(process.argv.slice(2));
const apply = args.has('--apply');
const reconcile = args.has('--reconcile');
const limitArg = process.argv.find((arg) => arg.startsWith('--limit='));
const limit = limitArg ? Math.max(1, Number(limitArg.split('=')[1]) || 100) : 100;
const legacyPrefix = (process.env.OSS_LEGACY_UPLOADS_PREFIX || 'legacy/uploads').replace(/^\/+|\/+$/g, '');

const isLocalUploadUrl = (value: unknown): value is string =>
  typeof value === 'string' && value.trim().startsWith('/uploads/');

const mimeTypeForPath = (filePath: string): string => {
  const ext = path.extname(filePath).toLowerCase();
  if (ext === '.png') return 'image/png';
  if (ext === '.webp') return 'image/webp';
  if (ext === '.gif') return 'image/gif';
  if (ext === '.mp4') return 'video/mp4';
  if (ext === '.mov') return 'video/quicktime';
  return 'image/jpeg';
};

const localPathForUploadUrl = (url: string): string =>
  path.join(process.cwd(), url.replace(/^\/+/, ''));

const updateJsonArrayUrl = (value: unknown, fromUrl: string, toUrl: string): unknown => {
  if (!Array.isArray(value)) return value;
  return value.map((item) => {
    if (!item || typeof item !== 'object' || Array.isArray(item)) return item;
    const record = item as Record<string, unknown>;
    if (record.url !== fromUrl) return item;
    return { ...record, url: toUrl };
  });
};

const collectCandidates = async (): Promise<Candidate[]> => {
  const candidates: Candidate[] = [];

  const users = await prisma.user.findMany({
    where: { avatarUrl: { startsWith: '/uploads/' } },
    select: { id: true, avatarUrl: true },
    take: limit,
  });
  for (const user of users) {
    if (!isLocalUploadUrl(user.avatarUrl)) continue;
    candidates.push({
      key: `user:${user.id}:avatar`,
      ownerType: 'user',
      ownerId: user.id,
      purpose: 'avatar',
      url: user.avatarUrl,
      update: (nextUrl) => prisma.user.update({ where: { id: user.id }, data: { avatarUrl: nextUrl } }).then(() => undefined),
    });
  }

  const events = await prisma.event.findMany({
    where: {
      OR: [
        { coverImageUrl: { startsWith: '/uploads/' } },
        { lineupImageUrl: { startsWith: '/uploads/' } },
      ],
    },
    select: { id: true, coverImageUrl: true, lineupImageUrl: true, imageAssets: true },
    take: limit,
  });
  for (const event of events) {
    if (isLocalUploadUrl(event.coverImageUrl)) {
      candidates.push({
        key: `event:${event.id}:cover`,
        ownerType: 'event',
        ownerId: event.id,
        purpose: 'cover',
        url: event.coverImageUrl,
        update: (nextUrl) => prisma.event.update({ where: { id: event.id }, data: { coverImageUrl: nextUrl } }).then(() => undefined),
      });
    }
    if (isLocalUploadUrl(event.lineupImageUrl)) {
      candidates.push({
        key: `event:${event.id}:lineup`,
        ownerType: 'event',
        ownerId: event.id,
        purpose: 'lineup',
        url: event.lineupImageUrl,
        update: (nextUrl) => prisma.event.update({ where: { id: event.id }, data: { lineupImageUrl: nextUrl } }).then(() => undefined),
      });
    }
    const imageAssets = Array.isArray(event.imageAssets) ? event.imageAssets : [];
    for (const asset of imageAssets) {
      if (!asset || typeof asset !== 'object' || !isLocalUploadUrl((asset as { url?: unknown }).url)) continue;
      const currentUrl = (asset as { url: string }).url;
      candidates.push({
        key: `event:${event.id}:imageAssets:${currentUrl}`,
        ownerType: 'event',
        ownerId: event.id,
        purpose: 'image_asset',
        url: currentUrl,
        update: async (nextUrl) => {
          const latest = await prisma.event.findUnique({
            where: { id: event.id },
            select: { imageAssets: true },
          });
          await prisma.event.update({
            where: { id: event.id },
            data: { imageAssets: updateJsonArrayUrl(latest?.imageAssets, currentUrl, nextUrl) as any },
          });
        },
      });
    }
  }

  const djs = await prisma.dJ.findMany({
    where: {
      OR: [
        { avatarUrl: { startsWith: '/uploads/' } },
        { avatarSourceUrl: { startsWith: '/uploads/' } },
        { bannerUrl: { startsWith: '/uploads/' } },
      ],
    },
    select: { id: true, avatarUrl: true, avatarSourceUrl: true, bannerUrl: true },
    take: limit,
  });
  for (const dj of djs) {
    for (const [field, purpose] of [
      ['avatarUrl', 'avatar'],
      ['avatarSourceUrl', 'avatar_source'],
      ['bannerUrl', 'banner'],
    ] as const) {
      const url = dj[field];
      if (!isLocalUploadUrl(url)) continue;
      candidates.push({
        key: `dj:${dj.id}:${field}`,
        ownerType: 'dj',
        ownerId: dj.id,
        purpose,
        url,
        update: (nextUrl) => prisma.dJ.update({ where: { id: dj.id }, data: { [field]: nextUrl } }).then(() => undefined),
      });
    }
  }

  const djSets = await prisma.dJSet.findMany({
    where: { thumbnailUrl: { startsWith: '/uploads/' } },
    select: { id: true, uploadedById: true, thumbnailUrl: true },
    take: limit,
  });
  for (const set of djSets) {
    if (!isLocalUploadUrl(set.thumbnailUrl)) continue;
    candidates.push({
      key: `dj_set:${set.id}:thumbnail`,
      ownerType: 'dj_set',
      ownerId: set.id,
      purpose: 'thumbnail',
      url: set.thumbnailUrl,
      update: (nextUrl) => prisma.dJSet.update({ where: { id: set.id }, data: { thumbnailUrl: nextUrl } }).then(() => undefined),
    });
  }

  const posts = await prisma.post.findMany({
    where: { images: { isEmpty: false } },
    select: { id: true, userId: true, images: true },
    take: limit,
  });
  for (const post of posts) {
    for (const url of post.images.filter(isLocalUploadUrl)) {
      candidates.push({
        key: `post:${post.id}:image:${url}`,
        ownerType: 'post',
        ownerId: post.id,
        purpose: 'image',
        url,
        update: async (nextUrl) => {
          const latest = await prisma.post.findUnique({
            where: { id: post.id },
            select: { images: true },
          });
          await prisma.post.update({
            where: { id: post.id },
            data: { images: (latest?.images || []).map((item) => (item === url ? nextUrl : item)) },
          });
        },
      });
    }
  }

  return candidates.slice(0, limit);
};

type ReferencedAsset = {
  key: string;
  ownerType: string;
  ownerId: string;
  purpose: string;
  url: string;
};

const isLegacyOssUrl = (value: unknown): value is string => {
  if (typeof value !== 'string') return false;
  const trimmed = value.trim();
  return trimmed.includes(`/${legacyPrefix}/`) || trimmed.startsWith(`${legacyPrefix}/`);
};

const objectKeyFromLegacyUrl = (url: string): string | null => {
  const marker = `${legacyPrefix}/`;
  const markerIndex = url.indexOf(marker);
  if (markerIndex < 0) return null;
  return decodeURIComponent(url.slice(markerIndex));
};

const collectReferencedAssets = async (): Promise<ReferencedAsset[]> => {
  const assets: ReferencedAsset[] = [];

  const users = await prisma.user.findMany({
    where: { avatarUrl: { contains: `/${legacyPrefix}/` } },
    select: { id: true, avatarUrl: true },
    take: limit,
  });
  for (const user of users) {
    if (!isLegacyOssUrl(user.avatarUrl)) continue;
    assets.push({
      key: `user:${user.id}:avatar`,
      ownerType: 'user',
      ownerId: user.id,
      purpose: 'avatar',
      url: user.avatarUrl,
    });
  }

  const events = await prisma.event.findMany({
    where: {
      OR: [
        { coverImageUrl: { contains: `/${legacyPrefix}/` } },
        { lineupImageUrl: { contains: `/${legacyPrefix}/` } },
      ],
    },
    select: { id: true, coverImageUrl: true, lineupImageUrl: true, imageAssets: true },
    take: limit,
  });
  for (const event of events) {
    if (isLegacyOssUrl(event.coverImageUrl)) {
      assets.push({
        key: `event:${event.id}:cover`,
        ownerType: 'event',
        ownerId: event.id,
        purpose: 'cover',
        url: event.coverImageUrl,
      });
    }
    if (isLegacyOssUrl(event.lineupImageUrl)) {
      assets.push({
        key: `event:${event.id}:lineup`,
        ownerType: 'event',
        ownerId: event.id,
        purpose: 'lineup',
        url: event.lineupImageUrl,
      });
    }
    const imageAssets = Array.isArray(event.imageAssets) ? event.imageAssets : [];
    for (const asset of imageAssets) {
      if (!asset || typeof asset !== 'object' || !isLegacyOssUrl((asset as { url?: unknown }).url)) continue;
      const url = (asset as { url: string }).url;
      assets.push({
        key: `event:${event.id}:imageAssets:${url}`,
        ownerType: 'event',
        ownerId: event.id,
        purpose: 'image_asset',
        url,
      });
    }
  }

  const djs = await prisma.dJ.findMany({
    where: {
      OR: [
        { avatarUrl: { contains: `/${legacyPrefix}/` } },
        { avatarSourceUrl: { contains: `/${legacyPrefix}/` } },
        { bannerUrl: { contains: `/${legacyPrefix}/` } },
      ],
    },
    select: { id: true, avatarUrl: true, avatarSourceUrl: true, bannerUrl: true },
    take: limit,
  });
  for (const dj of djs) {
    for (const [field, purpose] of [
      ['avatarUrl', 'avatar'],
      ['avatarSourceUrl', 'avatar_source'],
      ['bannerUrl', 'banner'],
    ] as const) {
      const url = dj[field];
      if (!isLegacyOssUrl(url)) continue;
      assets.push({
        key: `dj:${dj.id}:${field}`,
        ownerType: 'dj',
        ownerId: dj.id,
        purpose,
        url,
      });
    }
  }

  const djSets = await prisma.dJSet.findMany({
    where: { thumbnailUrl: { contains: `/${legacyPrefix}/` } },
    select: { id: true, thumbnailUrl: true },
    take: limit,
  });
  for (const set of djSets) {
    if (!isLegacyOssUrl(set.thumbnailUrl)) continue;
    assets.push({
      key: `dj_set:${set.id}:thumbnail`,
      ownerType: 'dj_set',
      ownerId: set.id,
      purpose: 'thumbnail',
      url: set.thumbnailUrl,
    });
  }

  const posts = await prisma.post.findMany({
    where: { images: { isEmpty: false } },
    select: { id: true, images: true },
    take: limit,
  });
  for (const post of posts) {
    for (const url of post.images.filter(isLegacyOssUrl)) {
      assets.push({
        key: `post:${post.id}:image:${url}`,
        ownerType: 'post',
        ownerId: post.id,
        purpose: 'image',
        url,
      });
    }
  }

  const unique = new Map<string, ReferencedAsset>();
  for (const asset of assets) {
    unique.set(`${asset.ownerType}:${asset.ownerId}:${asset.purpose}:${asset.url}`, asset);
  }

  return Array.from(unique.values()).slice(0, limit);
};

const migrateCandidate = async (candidate: Candidate): Promise<void> => {
  const localPath = localPathForUploadUrl(candidate.url);
  const stat = await fs.stat(localPath);
  const mimeType = mimeTypeForPath(localPath);
  const objectKey = buildMediaObjectKey(
    legacyPrefix,
    candidate.ownerId,
    candidate.purpose,
    path.basename(localPath),
    mimeType
  );

  const uploaded = await uploadFileToObjectStorage({
    filePath: localPath,
    mimeType,
    objectKey,
    unlinkAfterUpload: false,
  });

  await mediaAssetService.register({
    ownerType: candidate.ownerType,
    ownerId: candidate.ownerId,
    purpose: candidate.purpose,
    provider: 'oss',
    objectKey: uploaded.objectKey,
    url: uploaded.url,
    mimeType,
    sizeBytes: stat.size,
    metadata: {
      source: 'migrate-local-uploads-to-oss',
      previousUrl: candidate.url,
      localPath,
    },
  });
  await candidate.update(uploaded.url);
  await mediaAssetService.markDeletedByUrl(candidate.url);
};

const reconcileReferencedAssets = async (): Promise<void> => {
  const referencedAssets = await collectReferencedAssets();
  console.info(`[media-migrate] mode=${apply ? 'reconcile-apply' : 'reconcile-dry-run'} candidates=${referencedAssets.length}`);

  let created = 0;
  let existing = 0;
  let failed = 0;

  for (const asset of referencedAssets) {
    try {
      const existingAsset = await prisma.mediaAsset.findFirst({
        where: { url: asset.url },
        select: { id: true },
      });

      if (existingAsset) {
        existing += 1;
        continue;
      }

      const objectKey = objectKeyFromLegacyUrl(asset.url);
      if (!objectKey) {
        failed += 1;
        console.warn(`[media-migrate] cannot derive object key ${asset.key} ${asset.url}`);
        continue;
      }

      console.info(`[media-migrate] ${apply ? 'registering' : 'would register'} ${asset.key} ${objectKey}`);
      if (apply) {
        await mediaAssetService.register({
          ownerType: asset.ownerType,
          ownerId: asset.ownerId,
          purpose: asset.purpose,
          provider: 'oss',
          objectKey,
          url: asset.url,
          metadata: {
            source: 'migrate-local-uploads-to-oss:reconcile',
          } satisfies Prisma.InputJsonObject,
        });
        created += 1;
      }
    } catch (error) {
      failed += 1;
      const message = error instanceof Error ? error.message : String(error);
      console.error(`[media-migrate] reconcile failed ${asset.key}: ${message}`);
    }
  }

  console.info(`[media-migrate] reconcile done created=${created} existing=${existing} failed=${failed}`);
};

const main = async (): Promise<void> => {
  if (reconcile) {
    await reconcileReferencedAssets();
    return;
  }

  const candidates = await collectCandidates();
  console.info(`[media-migrate] mode=${apply ? 'apply' : 'dry-run'} candidates=${candidates.length}`);

  let migrated = 0;
  let missing = 0;
  let failed = 0;

  for (const candidate of candidates) {
    const localPath = localPathForUploadUrl(candidate.url);
    try {
      await fs.access(localPath);
      console.info(`[media-migrate] ${apply ? 'migrating' : 'would migrate'} ${candidate.key} ${candidate.url} -> ${localPath}`);
      if (apply) {
        await migrateCandidate(candidate);
        migrated += 1;
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      if (message.includes('ENOENT')) {
        missing += 1;
        console.warn(`[media-migrate] missing local file ${candidate.key} ${localPath}`);
      } else {
        failed += 1;
        console.error(`[media-migrate] failed ${candidate.key}: ${message}`);
      }
    }
  }

  console.info(`[media-migrate] done migrated=${migrated} missing=${missing} failed=${failed}`);
};

main()
  .catch((error) => {
    console.error('[media-migrate] fatal:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
