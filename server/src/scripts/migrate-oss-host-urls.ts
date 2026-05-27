import 'dotenv/config';
import { Prisma, PrismaClient } from '@prisma/client';

const prisma = new PrismaClient({
  datasources: process.env.WORKER_DATABASE_URL
    ? {
        db: {
          url: process.env.WORKER_DATABASE_URL,
        },
      }
    : undefined,
});

const args = new Set(process.argv.slice(2));
const apply = args.has('--apply');

const getArgValue = (name: string): string | null => {
  const prefix = `${name}=`;
  const raw = process.argv.find((arg) => arg.startsWith(prefix));
  if (!raw) return null;
  const value = raw.slice(prefix.length).trim();
  return value.length > 0 ? value : null;
};

const cleanHost = (value: string | null | undefined): string | null => {
  if (!value) return null;
  const trimmed = value.trim();
  if (!trimmed) return null;
  try {
    const parsed = new URL(trimmed.includes('://') ? trimmed : `https://${trimmed}`);
    return parsed.host.toLowerCase();
  } catch {
    return trimmed.replace(/^https?:\/\//, '').replace(/\/+$/g, '').toLowerCase();
  }
};

const cleanInt = (value: string | null | undefined, fallback: number): number => {
  if (!value) return fallback;
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? Math.floor(parsed) : fallback;
};

const fromHost = cleanHost(
  getArgValue('--from-host') ||
    process.env.OSS_MIGRATE_FROM_HOST ||
    process.env.OSS_LEGACY_HOST
);
const derivedToHost =
  process.env.OSS_BUCKET && process.env.OSS_ENDPOINT
    ? `${process.env.OSS_BUCKET}.${process.env.OSS_ENDPOINT}`
    : null;
const toHost = cleanHost(
  getArgValue('--to-host') ||
    process.env.OSS_MIGRATE_TO_HOST ||
    process.env.OSS_PUBLIC_HOST ||
    derivedToHost
);
const batchSize = cleanInt(getArgValue('--batch-size') || process.env.OSS_MIGRATE_BATCH_SIZE, 200);
const limit = cleanInt(getArgValue('--limit') || process.env.OSS_MIGRATE_LIMIT, Number.MAX_SAFE_INTEGER);
const explicitOldBucket = getArgValue('--old-bucket') || process.env.OSS_MIGRATE_OLD_BUCKET || null;
const explicitNewBucket = getArgValue('--new-bucket') || process.env.OSS_MIGRATE_NEW_BUCKET || process.env.OSS_BUCKET || null;

if (!fromHost || !toHost) {
  throw new Error(
    'Require --from-host and --to-host (or OSS_MIGRATE_FROM_HOST / OSS_MIGRATE_TO_HOST / OSS_BUCKET+OSS_ENDPOINT)'
  );
}

const oldBucket = explicitOldBucket || fromHost.split('.')[0] || null;
const newBucket = explicitNewBucket?.trim() || null;

type Summary = {
  scanned: number;
  matched: number;
  updated: number;
};

const summary = new Map<string, Summary>();

const track = (label: string, key: keyof Summary, count = 1): void => {
  const current = summary.get(label) || { scanned: 0, matched: 0, updated: 0 };
  current[key] += count;
  summary.set(label, current);
};

const replaceUrlHost = (value: string | null | undefined): { nextValue: string | null | undefined; changed: boolean } => {
  if (typeof value !== 'string') return { nextValue: value, changed: false };
  const trimmed = value.trim();
  if (!trimmed) return { nextValue: value, changed: false };

  let parsed: URL;
  try {
    parsed = new URL(trimmed);
  } catch {
    return { nextValue: value, changed: false };
  }

  if (parsed.host.toLowerCase() !== fromHost) {
    return { nextValue: value, changed: false };
  }

  parsed.host = toHost;
  return { nextValue: parsed.toString(), changed: true };
};

const rewriteUnknown = (value: unknown): { nextValue: unknown; changed: boolean } => {
  if (typeof value === 'string') {
    const result = replaceUrlHost(value);
    return { nextValue: result.nextValue, changed: result.changed };
  }

  if (Array.isArray(value)) {
    let changed = false;
    const nextValue = value.map((item) => {
      const rewritten = rewriteUnknown(item);
      changed = changed || rewritten.changed;
      return rewritten.nextValue;
    });
    return { nextValue, changed };
  }

  if (value && typeof value === 'object') {
    let changed = false;
    const nextObject: Record<string, unknown> = {};
    for (const [key, nestedValue] of Object.entries(value as Record<string, unknown>)) {
      const rewritten = rewriteUnknown(nestedValue);
      changed = changed || rewritten.changed;
      nextObject[key] = rewritten.nextValue;
    }
    return { nextValue: nextObject, changed };
  }

  return { nextValue: value, changed: false };
};

const rewriteStringArray = (values: string[]): { nextValue: string[]; changed: boolean } => {
  let changed = false;
  const nextValue = values.map((value) => {
    const rewritten = replaceUrlHost(value);
    changed = changed || rewritten.changed;
    return typeof rewritten.nextValue === 'string' ? rewritten.nextValue : value;
  });
  return { nextValue, changed };
};

const canContinue = (): boolean => {
  let totalUpdated = 0;
  for (const value of summary.values()) totalUpdated += value.updated;
  return totalUpdated < limit;
};

const logPreview = (label: string, id: string, fields: string[]): void => {
  console.info(`[oss-host-migrate] ${apply ? 'updating' : 'would update'} ${label} id=${id} fields=${fields.join(',')}`);
};

async function processRows(input: {
  label: string;
  fetch: (cursor: string | null) => Promise<Array<Record<string, any>>>;
  getCursor: (row: Record<string, any>) => string;
  update: (row: Record<string, any>) => Promise<boolean>;
}): Promise<void> {
  let cursor: string | null = null;

  while (canContinue()) {
    const rows = await input.fetch(cursor);
    if (rows.length === 0) break;

    for (const row of rows) {
      track(input.label, 'scanned');
      const changed = await input.update(row);
      if (changed) {
        track(input.label, 'matched');
        if (apply) track(input.label, 'updated');
      }
      if (!canContinue()) break;
    }

    cursor = input.getCursor(rows[rows.length - 1]) || null;
    if (rows.length < batchSize) break;
  }
}

async function main(): Promise<void> {
  console.info(
    `[oss-host-migrate] mode=${apply ? 'apply' : 'dry-run'} fromHost=${fromHost} toHost=${toHost} oldBucket=${
      oldBucket || 'n/a'
    } newBucket=${newBucket || 'n/a'} batchSize=${batchSize} limit=${limit === Number.MAX_SAFE_INTEGER ? 'all' : limit}`
  );

  await processRows({
    label: 'media_assets',
    getCursor: (row) => row.id,
    fetch: (cursor) =>
      prisma.mediaAsset.findMany({
        ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
        orderBy: { id: 'asc' },
        take: batchSize,
        select: { id: true, url: true, bucket: true, provider: true },
      }),
    update: async (row) => {
      const urlRewrite = replaceUrlHost(row.url);
      const bucketChanged = row.provider === 'oss' && !!newBucket && row.bucket === oldBucket;
      if (!urlRewrite.changed && !bucketChanged) return false;

      const fields: string[] = [];
      const data: { url?: string; bucket?: string | null } = {};
      if (urlRewrite.changed && typeof urlRewrite.nextValue === 'string') {
        data.url = urlRewrite.nextValue;
        fields.push('url');
      }
      if (bucketChanged) {
        data.bucket = newBucket;
        fields.push('bucket');
      }
      logPreview('media_assets', row.id, fields);
      if (apply) {
        await prisma.mediaAsset.update({ where: { id: row.id }, data });
      }
      return true;
    },
  });

  await processRows({
    label: 'users',
    getCursor: (row) => row.id,
    fetch: (cursor) =>
      prisma.user.findMany({
        ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
        orderBy: { id: 'asc' },
        take: batchSize,
        select: { id: true, avatarUrl: true, backgroundUrl: true },
      }),
    update: async (row) => {
      const avatar = replaceUrlHost(row.avatarUrl);
      const background = replaceUrlHost(row.backgroundUrl);
      if (!avatar.changed && !background.changed) return false;

      const data: { avatarUrl?: string | null; backgroundUrl?: string | null } = {};
      const fields: string[] = [];
      if (avatar.changed) {
        data.avatarUrl = (avatar.nextValue as string) || null;
        fields.push('avatarUrl');
      }
      if (background.changed) {
        data.backgroundUrl = (background.nextValue as string) || null;
        fields.push('backgroundUrl');
      }
      logPreview('users', row.id, fields);
      if (apply) {
        await prisma.user.update({ where: { id: row.id }, data });
      }
      return true;
    },
  });

  await processRows({
    label: 'events',
    getCursor: (row) => row.id,
    fetch: (cursor) =>
      prisma.event.findMany({
        ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
        orderBy: { id: 'asc' },
        take: batchSize,
        select: { id: true, coverImageUrl: true, lineupImageUrl: true, imageAssets: true },
      }),
    update: async (row) => {
      const cover = replaceUrlHost(row.coverImageUrl);
      const lineup = replaceUrlHost(row.lineupImageUrl);
      const imageAssets = rewriteUnknown(row.imageAssets);
      if (!cover.changed && !lineup.changed && !imageAssets.changed) return false;

      const data: Prisma.EventUpdateInput = {};
      const fields: string[] = [];
      if (cover.changed) {
        data.coverImageUrl = (cover.nextValue as string) || null;
        fields.push('coverImageUrl');
      }
      if (lineup.changed) {
        data.lineupImageUrl = (lineup.nextValue as string) || null;
        fields.push('lineupImageUrl');
      }
      if (imageAssets.changed) {
        data.imageAssets = imageAssets.nextValue as Prisma.InputJsonValue;
        fields.push('imageAssets');
      }
      logPreview('events', row.id, fields);
      if (apply) {
        await prisma.event.update({ where: { id: row.id }, data });
      }
      return true;
    },
  });

  await processRows({
    label: 'djs',
    getCursor: (row) => row.id,
    fetch: (cursor) =>
      prisma.dJ.findMany({
        ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
        orderBy: { id: 'asc' },
        take: batchSize,
        select: { id: true, avatarUrl: true, avatarSourceUrl: true, bannerUrl: true },
      }),
    update: async (row) => {
      const avatar = replaceUrlHost(row.avatarUrl);
      const avatarSource = replaceUrlHost(row.avatarSourceUrl);
      const banner = replaceUrlHost(row.bannerUrl);
      if (!avatar.changed && !avatarSource.changed && !banner.changed) return false;

      const data: { avatarUrl?: string | null; avatarSourceUrl?: string | null; bannerUrl?: string | null } = {};
      const fields: string[] = [];
      if (avatar.changed) {
        data.avatarUrl = (avatar.nextValue as string) || null;
        fields.push('avatarUrl');
      }
      if (avatarSource.changed) {
        data.avatarSourceUrl = (avatarSource.nextValue as string) || null;
        fields.push('avatarSourceUrl');
      }
      if (banner.changed) {
        data.bannerUrl = (banner.nextValue as string) || null;
        fields.push('bannerUrl');
      }
      logPreview('djs', row.id, fields);
      if (apply) {
        await prisma.dJ.update({ where: { id: row.id }, data });
      }
      return true;
    },
  });

  await processRows({
    label: 'dj_sets',
    getCursor: (row) => row.id,
    fetch: (cursor) =>
      prisma.dJSet.findMany({
        ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
        orderBy: { id: 'asc' },
        take: batchSize,
        select: { id: true, thumbnailUrl: true },
      }),
    update: async (row) => {
      const thumbnail = replaceUrlHost(row.thumbnailUrl);
      if (!thumbnail.changed) return false;
      logPreview('dj_sets', row.id, ['thumbnailUrl']);
      if (apply) {
        await prisma.dJSet.update({
          where: { id: row.id },
          data: { thumbnailUrl: (thumbnail.nextValue as string) || null },
        });
      }
      return true;
    },
  });

  await processRows({
    label: 'posts',
    getCursor: (row) => row.id,
    fetch: (cursor) =>
      prisma.post.findMany({
        ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
        orderBy: { id: 'asc' },
        take: batchSize,
        select: { id: true, images: true },
      }),
    update: async (row) => {
      const rewritten = rewriteStringArray(row.images || []);
      if (!rewritten.changed) return false;
      logPreview('posts', row.id, ['images']);
      if (apply) {
        await prisma.post.update({ where: { id: row.id }, data: { images: rewritten.nextValue } });
      }
      return true;
    },
  });

  await processRows({
    label: 'event_live_comments',
    getCursor: (row) => row.id,
    fetch: (cursor) =>
      prisma.eventLiveComment.findMany({
        ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
        orderBy: { id: 'asc' },
        take: batchSize,
        select: { id: true, imageUrls: true },
      }),
    update: async (row) => {
      const rewritten = rewriteStringArray(row.imageUrls || []);
      if (!rewritten.changed) return false;
      logPreview('event_live_comments', row.id, ['imageUrls']);
      if (apply) {
        await prisma.eventLiveComment.update({ where: { id: row.id }, data: { imageUrls: rewritten.nextValue } });
      }
      return true;
    },
  });

  await processRows({
    label: 'labels',
    getCursor: (row) => row.id,
    fetch: (cursor) =>
      prisma.label.findMany({
        ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
        orderBy: { id: 'asc' },
        take: batchSize,
        select: {
          id: true,
          logoUrl: true,
          avatarSourceUrl: true,
          backgroundSourceUrl: true,
          avatarUrl: true,
          backgroundUrl: true,
        },
      }),
    update: async (row) => {
      const values = {
        logoUrl: replaceUrlHost(row.logoUrl),
        avatarSourceUrl: replaceUrlHost(row.avatarSourceUrl),
        backgroundSourceUrl: replaceUrlHost(row.backgroundSourceUrl),
        avatarUrl: replaceUrlHost(row.avatarUrl),
        backgroundUrl: replaceUrlHost(row.backgroundUrl),
      };
      const fields = Object.entries(values)
        .filter(([, result]) => result.changed)
        .map(([key]) => key);
      if (fields.length === 0) return false;
      logPreview('labels', row.id, fields);
      if (apply) {
        await prisma.label.update({
          where: { id: row.id },
          data: {
            logoUrl: (values.logoUrl.nextValue as string) || null,
            avatarSourceUrl: (values.avatarSourceUrl.nextValue as string) || null,
            backgroundSourceUrl: (values.backgroundSourceUrl.nextValue as string) || null,
            avatarUrl: (values.avatarUrl.nextValue as string) || null,
            backgroundUrl: (values.backgroundUrl.nextValue as string) || null,
          },
        });
      }
      return true;
    },
  });

  await processRows({
    label: 'wiki_festivals',
    getCursor: (row) => row.id,
    fetch: (cursor) =>
      prisma.wikiFestival.findMany({
        ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
        orderBy: { id: 'asc' },
        take: batchSize,
        select: { id: true, avatarUrl: true, backgroundUrl: true },
      }),
    update: async (row) => {
      const avatar = replaceUrlHost(row.avatarUrl);
      const background = replaceUrlHost(row.backgroundUrl);
      if (!avatar.changed && !background.changed) return false;
      const fields: string[] = [];
      if (avatar.changed) fields.push('avatarUrl');
      if (background.changed) fields.push('backgroundUrl');
      logPreview('wiki_festivals', row.id, fields);
      if (apply) {
        await prisma.wikiFestival.update({
          where: { id: row.id },
          data: {
            avatarUrl: (avatar.nextValue as string) || null,
            backgroundUrl: (background.nextValue as string) || null,
          },
        });
      }
      return true;
    },
  });

  await processRows({
    label: 'ranking_boards',
    getCursor: (row) => row.id,
    fetch: (cursor) =>
      prisma.rankingBoard.findMany({
        ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
        orderBy: { id: 'asc' },
        take: batchSize,
        select: { id: true, coverImageUrl: true },
      }),
    update: async (row) => {
      const rewritten = replaceUrlHost(row.coverImageUrl);
      if (!rewritten.changed) return false;
      logPreview('ranking_boards', row.id, ['coverImageUrl']);
      if (apply) {
        await prisma.rankingBoard.update({
          where: { id: row.id },
          data: { coverImageUrl: (rewritten.nextValue as string) || null },
        });
      }
      return true;
    },
  });

  await processRows({
    label: 'news_articles',
    getCursor: (row) => row.id,
    fetch: (cursor) =>
      prisma.newsArticle.findMany({
        ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
        orderBy: { id: 'asc' },
        take: batchSize,
        select: { id: true, coverImageUrl: true },
      }),
    update: async (row) => {
      const rewritten = replaceUrlHost(row.coverImageUrl);
      if (!rewritten.changed) return false;
      logPreview('news_articles', row.id, ['coverImageUrl']);
      if (apply) {
        await prisma.newsArticle.update({
          where: { id: row.id },
          data: { coverImageUrl: (rewritten.nextValue as string) || null },
        });
      }
      return true;
    },
  });

  await processRows({
    label: 'rating_events',
    getCursor: (row) => row.id,
    fetch: (cursor) =>
      prisma.ratingEvent.findMany({
        ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
        orderBy: { id: 'asc' },
        take: batchSize,
        select: { id: true, imageUrl: true },
      }),
    update: async (row) => {
      const rewritten = replaceUrlHost(row.imageUrl);
      if (!rewritten.changed) return false;
      logPreview('rating_events', row.id, ['imageUrl']);
      if (apply) {
        await prisma.ratingEvent.update({
          where: { id: row.id },
          data: { imageUrl: (rewritten.nextValue as string) || null },
        });
      }
      return true;
    },
  });

  await processRows({
    label: 'rating_units',
    getCursor: (row) => row.id,
    fetch: (cursor) =>
      prisma.ratingUnit.findMany({
        ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
        orderBy: { id: 'asc' },
        take: batchSize,
        select: { id: true, imageUrl: true },
      }),
    update: async (row) => {
      const rewritten = replaceUrlHost(row.imageUrl);
      if (!rewritten.changed) return false;
      logPreview('rating_units', row.id, ['imageUrl']);
      if (apply) {
        await prisma.ratingUnit.update({
          where: { id: row.id },
          data: { imageUrl: (rewritten.nextValue as string) || null },
        });
      }
      return true;
    },
  });

  await processRows({
    label: 'share_links',
    getCursor: (row) => row.id,
    fetch: (cursor) =>
      prisma.shareLink.findMany({
        ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
        orderBy: { id: 'asc' },
        take: batchSize,
        select: { id: true, imageUrl: true, posterUrl: true },
      }),
    update: async (row) => {
      const image = replaceUrlHost(row.imageUrl);
      const poster = replaceUrlHost(row.posterUrl);
      if (!image.changed && !poster.changed) return false;
      const fields: string[] = [];
      if (image.changed) fields.push('imageUrl');
      if (poster.changed) fields.push('posterUrl');
      logPreview('share_links', row.id, fields);
      if (apply) {
        await prisma.shareLink.update({
          where: { id: row.id },
          data: {
            imageUrl: (image.nextValue as string) || null,
            posterUrl: (poster.nextValue as string) || null,
          },
        });
      }
      return true;
    },
  });

  await processRows({
    label: 'squads',
    getCursor: (row) => row.id,
    fetch: (cursor) =>
      prisma.squad.findMany({
        ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
        orderBy: { id: 'asc' },
        take: batchSize,
        select: { id: true, avatarUrl: true, bannerUrl: true, qrCodeUrl: true },
      }),
    update: async (row) => {
      const avatar = replaceUrlHost(row.avatarUrl);
      const banner = replaceUrlHost(row.bannerUrl);
      const qrCode = replaceUrlHost(row.qrCodeUrl);
      if (!avatar.changed && !banner.changed && !qrCode.changed) return false;
      const fields: string[] = [];
      if (avatar.changed) fields.push('avatarUrl');
      if (banner.changed) fields.push('bannerUrl');
      if (qrCode.changed) fields.push('qrCodeUrl');
      logPreview('squads', row.id, fields);
      if (apply) {
        await prisma.squad.update({
          where: { id: row.id },
          data: {
            avatarUrl: (avatar.nextValue as string) || null,
            bannerUrl: (banner.nextValue as string) || null,
            qrCodeUrl: (qrCode.nextValue as string) || null,
          },
        });
      }
      return true;
    },
  });

  await processRows({
    label: 'squad_messages',
    getCursor: (row) => row.id,
    fetch: (cursor) =>
      prisma.squadMessage.findMany({
        ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
        orderBy: { id: 'asc' },
        take: batchSize,
        select: { id: true, imageUrl: true },
      }),
    update: async (row) => {
      const rewritten = replaceUrlHost(row.imageUrl);
      if (!rewritten.changed) return false;
      logPreview('squad_messages', row.id, ['imageUrl']);
      if (apply) {
        await prisma.squadMessage.update({
          where: { id: row.id },
          data: { imageUrl: (rewritten.nextValue as string) || null },
        });
      }
      return true;
    },
  });

  await processRows({
    label: 'checkin_snapshots',
    getCursor: (row) => row.checkinId,
    fetch: (cursor) =>
      prisma.checkinSnapshot.findMany({
        ...(cursor ? { cursor: { checkinId: cursor }, skip: 1 } : {}),
        orderBy: { checkinId: 'asc' },
        take: batchSize,
        select: { checkinId: true, primaryDjAvatarUrl: true },
      }),
    update: async (row) => {
      const rewritten = replaceUrlHost(row.primaryDjAvatarUrl);
      if (!rewritten.changed) return false;
      logPreview('checkin_snapshots', row.checkinId, ['primaryDjAvatarUrl']);
      if (apply) {
        await prisma.checkinSnapshot.update({
          where: { checkinId: row.checkinId },
          data: { primaryDjAvatarUrl: (rewritten.nextValue as string) || null },
        });
      }
      return true;
    },
  });

  await processRows({
    label: 'checkin_selection_djs',
    getCursor: (row) => row.id,
    fetch: (cursor) =>
      prisma.checkinSelectionDJ.findMany({
        ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
        orderBy: { id: 'asc' },
        take: batchSize,
        select: { id: true, avatarUrl: true },
      }),
    update: async (row) => {
      const rewritten = replaceUrlHost(row.avatarUrl);
      if (!rewritten.changed) return false;
      logPreview('checkin_selection_djs', row.id, ['avatarUrl']);
      if (apply) {
        await prisma.checkinSelectionDJ.update({
          where: { id: row.id },
          data: { avatarUrl: (rewritten.nextValue as string) || null },
        });
      }
      return true;
    },
  });

  await processRows({
    label: 'user_checkin_timeline_entries',
    getCursor: (row) => row.id,
    fetch: (cursor) =>
      prisma.userCheckinTimelineEntry.findMany({
        ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
        orderBy: { id: 'asc' },
        take: batchSize,
        select: { id: true, eventCoverUrl: true },
      }),
    update: async (row) => {
      const rewritten = replaceUrlHost(row.eventCoverUrl);
      if (!rewritten.changed) return false;
      logPreview('user_checkin_timeline_entries', row.id, ['eventCoverUrl']);
      if (apply) {
        await prisma.userCheckinTimelineEntry.update({
          where: { id: row.id },
          data: { eventCoverUrl: (rewritten.nextValue as string) || null },
        });
      }
      return true;
    },
  });

  await processRows({
    label: 'user_checkin_gallery_dj_aggregates',
    getCursor: (row) => row.id,
    fetch: (cursor) =>
      prisma.userCheckinGalleryDJAggregate.findMany({
        ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
        orderBy: { id: 'asc' },
        take: batchSize,
        select: { id: true, avatarUrl: true },
      }),
    update: async (row) => {
      const rewritten = replaceUrlHost(row.avatarUrl);
      if (!rewritten.changed) return false;
      logPreview('user_checkin_gallery_dj_aggregates', row.id, ['avatarUrl']);
      if (apply) {
        await prisma.userCheckinGalleryDJAggregate.update({
          where: { id: row.id },
          data: { avatarUrl: (rewritten.nextValue as string) || null },
        });
      }
      return true;
    },
  });

  await processRows({
    label: 'user_checkin_gallery_event_aggregates',
    getCursor: (row) => row.id,
    fetch: (cursor) =>
      prisma.userCheckinGalleryEventAggregate.findMany({
        ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
        orderBy: { id: 'asc' },
        take: batchSize,
        select: { id: true, eventCoverUrl: true },
      }),
    update: async (row) => {
      const rewritten = replaceUrlHost(row.eventCoverUrl);
      if (!rewritten.changed) return false;
      logPreview('user_checkin_gallery_event_aggregates', row.id, ['eventCoverUrl']);
      if (apply) {
        await prisma.userCheckinGalleryEventAggregate.update({
          where: { id: row.id },
          data: { eventCoverUrl: (rewritten.nextValue as string) || null },
        });
      }
      return true;
    },
  });

  let totalScanned = 0;
  let totalMatched = 0;
  let totalUpdated = 0;
  for (const [label, value] of summary.entries()) {
    totalScanned += value.scanned;
    totalMatched += value.matched;
    totalUpdated += value.updated;
    console.info(
      `[oss-host-migrate] summary table=${label} scanned=${value.scanned} matched=${value.matched} updated=${value.updated}`
    );
  }
  console.info(
    `[oss-host-migrate] done mode=${apply ? 'apply' : 'dry-run'} scanned=${totalScanned} matched=${totalMatched} updated=${totalUpdated}`
  );
}

main()
  .catch((error) => {
    console.error('[oss-host-migrate] fatal:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
