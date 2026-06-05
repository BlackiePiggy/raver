import { Prisma, PrismaClient } from '@prisma/client';
import { recordDJContribution } from './contribution.service';
import { normalizeCountryBiTextPayload } from '../utils/country-i18n';
import { normalizeTriTextPayload, triTextToJson } from '../utils/i18n';
import { entityChangeService } from '../modules/entity-change';

const cleanText = (value: unknown): string | undefined => {
  if (typeof value !== 'string') return undefined;
  const trimmed = value.trim();
  return trimmed || undefined;
};

const slugify = (value: string): string =>
  value
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '') || 'dj';

const integerOrNull = (value: unknown): number | null => {
  if (value === null || value === undefined || value === '') return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? Math.trunc(parsed) : null;
};

const stableSerialize = (value: unknown): string => {
  if (value === null || value === undefined) return 'null';
  if (value instanceof Date) return JSON.stringify(value.toISOString());
  if (Array.isArray(value)) {
    return `[${value.map((item) => stableSerialize(item)).join(',')}]`;
  }
  if (typeof value === 'object') {
    const entries = Object.entries(value as Record<string, unknown>)
      .filter(([, entryValue]) => entryValue !== undefined)
      .sort(([left], [right]) => left.localeCompare(right));
    return `{${entries.map(([key, entryValue]) => `${JSON.stringify(key)}:${stableSerialize(entryValue)}`).join(',')}}`;
  }
  return JSON.stringify(value);
};

const isEqualValue = (left: unknown, right: unknown): boolean => stableSerialize(left) === stableSerialize(right);

const stringArray = (value: unknown): string[] => {
  if (Array.isArray(value)) {
    return value
      .map((item) => (typeof item === 'string' ? item.trim() : ''))
      .filter(Boolean);
  }
  if (typeof value === 'string') {
    return value
      .split(/[,\uFF0C\/\u3001|;]+/g)
      .map((item) => item.trim())
      .filter(Boolean);
  }
  return [];
};

const normalizeDJNameKey = (value: string): string => value.trim().toLowerCase();

const mergeAliases = (baseName: string, values: Array<string | null | undefined>): string[] => {
  const baseKey = normalizeDJNameKey(baseName);
  const result: string[] = [];
  const seen = new Set<string>([baseKey]);

  for (const raw of values) {
    if (!raw) continue;
    const trimmed = raw.trim();
    if (!trimmed) continue;
    const key = normalizeDJNameKey(trimmed);
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(trimmed);
  }

  return result;
};

const uniqueDJSlug = async (
  db: Prisma.TransactionClient | PrismaClient,
  name: string,
  requestedSlug?: string,
  existingDJId?: string | null
): Promise<string> => {
  const base = slugify(requestedSlug || name) || `dj-${Date.now()}`;
  let candidate = base;
  let seq = 1;

  while (true) {
    const existing = await db.dJ.findUnique({
      where: { slug: candidate },
      select: { id: true, name: true },
    });
    if (!existing || existing.id === existingDJId || normalizeDJNameKey(existing.name) === normalizeDJNameKey(name)) {
      return candidate;
    }
    seq += 1;
    candidate = `${base}-${seq}`;
  }
};

const resolvePrimaryName = (payload: Prisma.JsonObject, fallback?: string | null): string => {
  const name = cleanText(payload.name) || cleanText(payload.title) || fallback || '';
  return name.trim();
};

const resolveWebsite = (payload: Prisma.JsonObject, fallback?: string | null): string | null =>
  cleanText(payload.website) ||
  cleanText(payload.otherPlatformUrl) ||
  fallback ||
  null;

const hasAnyProof = (
  payload: Prisma.JsonObject,
  fallback?: {
    spotifyId?: string | null;
    spotifyUrl?: string | null;
    appleMusicId?: string | null;
    instagramUrl?: string | null;
    facebookUrl?: string | null;
    soundcloudUrl?: string | null;
    soundcloudId?: string | null;
    twitterUrl?: string | null;
    youtubeUrl?: string | null;
    neteaseUrl?: string | null;
    qqMusicUrl?: string | null;
    website?: string | null;
    proofImageUrl?: string | null;
  }
): boolean => {
  const values = [
    cleanText(payload.spotifyId) ?? fallback?.spotifyId ?? null,
    cleanText(payload.spotifyUrl) ?? fallback?.spotifyUrl ?? null,
    cleanText(payload.appleMusicId) ?? fallback?.appleMusicId ?? null,
    cleanText(payload.instagramUrl) ?? fallback?.instagramUrl ?? null,
    cleanText(payload.facebookUrl) ?? fallback?.facebookUrl ?? null,
    cleanText(payload.soundcloudUrl) ?? fallback?.soundcloudUrl ?? null,
    cleanText(payload.soundcloudId) ?? cleanText(payload.soundcloudid) ?? fallback?.soundcloudId ?? null,
    cleanText(payload.twitterUrl) ?? fallback?.twitterUrl ?? null,
    cleanText(payload.youtubeUrl) ?? fallback?.youtubeUrl ?? null,
    cleanText(payload.neteaseUrl) ?? fallback?.neteaseUrl ?? null,
    cleanText(payload.qqMusicUrl) ?? fallback?.qqMusicUrl ?? null,
    resolveWebsite(payload, fallback?.website) ?? null,
    cleanText(payload.proofImageUrl) ?? fallback?.proofImageUrl ?? null,
  ];
  return values.some((value) => typeof value === 'string' && value.trim().length > 0);
};

const buildResolvedDJUpdateData = (
  payload: Prisma.JsonObject,
  existing: Awaited<ReturnType<Prisma.TransactionClient['dJ']['findUnique']>> extends infer T
    ? NonNullable<T>
    : never,
  resolved: {
    name: string;
    avatarUrl: string;
    aliases: string[];
    genres: string[];
    slug: string;
  }
) => ({
  name: resolved.name,
  nameI18n: triTextToJson(normalizeTriTextPayload(payload.nameI18n ?? existing.nameI18n, resolved.name)),
  aliases: resolved.aliases,
  genres: resolved.genres,
  slug: resolved.slug,
  bio: cleanText(payload.bio) ?? existing.bio ?? null,
  bioI18n: triTextToJson(
    normalizeTriTextPayload(payload.bioI18n ?? existing.bioI18n, cleanText(payload.bio) ?? existing.bio ?? '')
  ),
  avatarUrl: resolved.avatarUrl,
  avatarSourceUrl: resolved.avatarUrl,
  bannerUrl: cleanText(payload.bannerUrl) ?? existing.bannerUrl ?? null,
  country: cleanText(payload.country) ?? existing.country ?? null,
  countryI18n: triTextToJson(
    normalizeCountryBiTextPayload(
      payload.countryI18n ?? existing.countryI18n,
      cleanText(payload.country) ?? existing.country ?? ''
    )
  ),
  spotifyUrl: cleanText(payload.spotifyUrl) ?? existing.spotifyUrl ?? null,
  spotifyId: cleanText(payload.spotifyId) ?? existing.spotifyId ?? null,
  spotifyFollowers: integerOrNull(payload.spotifyFollowers) ?? existing.spotifyFollowers ?? null,
  appleMusicId: cleanText(payload.appleMusicId) ?? existing.appleMusicId ?? null,
  soundcloudUrl: cleanText(payload.soundcloudUrl) ?? existing.soundcloudUrl ?? null,
  soundcloudId:
    cleanText(payload.soundcloudId) ??
    cleanText(payload.soundcloudid) ??
    existing.soundcloudId ??
    null,
  instagramUrl: cleanText(payload.instagramUrl) ?? existing.instagramUrl ?? null,
  facebookUrl: cleanText(payload.facebookUrl) ?? existing.facebookUrl ?? null,
  twitterUrl: cleanText(payload.twitterUrl) ?? existing.twitterUrl ?? null,
  youtubeUrl: cleanText(payload.youtubeUrl) ?? existing.youtubeUrl ?? null,
  neteaseUrl: cleanText(payload.neteaseUrl) ?? existing.neteaseUrl ?? null,
  qqMusicUrl: cleanText(payload.qqMusicUrl) ?? existing.qqMusicUrl ?? null,
  website: resolveWebsite(payload, existing.website) ?? null,
  trackCount: integerOrNull(payload.trackCount) ?? existing.trackCount ?? null,
  playlistCount: integerOrNull(payload.playlistCount) ?? existing.playlistCount ?? null,
  soundCloudFollowers:
    integerOrNull(payload.soundCloudFollowers) ??
    integerOrNull(payload.soundcloudFollowers) ??
    integerOrNull(payload.followers_count) ??
    existing.soundCloudFollowers ??
    null,
  soundCloudFavorites:
    integerOrNull(payload.soundCloudFavorites) ??
    integerOrNull(payload.soundcloudFavorites) ??
    integerOrNull(payload.public_favorites_count) ??
    existing.soundCloudFavorites ??
    null,
  isVerified: typeof payload.isVerified === 'boolean' ? payload.isVerified : existing.isVerified,
});

const hasDJMaterialChanges = (
  existing: Awaited<ReturnType<Prisma.TransactionClient['dJ']['findUnique']>> extends infer T
    ? NonNullable<T>
    : never,
  next: ReturnType<typeof buildResolvedDJUpdateData>
): boolean => (
  !isEqualValue(existing.name, next.name)
  || !isEqualValue(existing.nameI18n, next.nameI18n)
  || !isEqualValue(existing.aliases ?? [], next.aliases)
  || !isEqualValue(existing.genres ?? [], next.genres)
  || !isEqualValue(existing.slug, next.slug)
  || !isEqualValue(existing.bio ?? null, next.bio)
  || !isEqualValue(existing.bioI18n, next.bioI18n)
  || !isEqualValue(existing.avatarUrl ?? null, next.avatarUrl)
  || !isEqualValue(existing.avatarSourceUrl ?? null, next.avatarSourceUrl)
  || !isEqualValue(existing.bannerUrl ?? null, next.bannerUrl)
  || !isEqualValue(existing.country ?? null, next.country)
  || !isEqualValue(existing.countryI18n, next.countryI18n)
  || !isEqualValue(existing.spotifyUrl ?? null, next.spotifyUrl)
  || !isEqualValue(existing.spotifyId ?? null, next.spotifyId)
  || !isEqualValue(existing.spotifyFollowers ?? null, next.spotifyFollowers)
  || !isEqualValue(existing.appleMusicId ?? null, next.appleMusicId)
  || !isEqualValue(existing.soundcloudUrl ?? null, next.soundcloudUrl)
  || !isEqualValue(existing.soundcloudId ?? null, next.soundcloudId)
  || !isEqualValue(existing.instagramUrl ?? null, next.instagramUrl)
  || !isEqualValue(existing.facebookUrl ?? null, next.facebookUrl)
  || !isEqualValue(existing.twitterUrl ?? null, next.twitterUrl)
  || !isEqualValue(existing.youtubeUrl ?? null, next.youtubeUrl)
  || !isEqualValue(existing.neteaseUrl ?? null, next.neteaseUrl)
  || !isEqualValue(existing.qqMusicUrl ?? null, next.qqMusicUrl)
  || !isEqualValue(existing.website ?? null, next.website)
  || !isEqualValue(existing.trackCount ?? null, next.trackCount)
  || !isEqualValue(existing.playlistCount ?? null, next.playlistCount)
  || !isEqualValue(existing.soundCloudFollowers ?? null, next.soundCloudFollowers)
  || !isEqualValue(existing.soundCloudFavorites ?? null, next.soundCloudFavorites)
  || !isEqualValue(existing.isVerified, next.isVerified)
);

export const createOrUpdateDJFromSubmission = async (
  db: Prisma.TransactionClient | PrismaClient,
  payload: Prisma.JsonObject,
  submitterId: string,
  options: {
    submissionId?: string;
    approvedAt?: Date | null;
  } = {}
) => {
  const targetDJId = cleanText(payload.targetDJId) || cleanText(payload.editTargetDJId) || null;

  if (targetDJId) {
    const beforeChangeSnapshot = await entityChangeService.captureSnapshot({
      entityType: 'dj',
      entityId: targetDJId,
      db,
    });
    const existing = await db.dJ.findUnique({
      where: { id: targetDJId },
    });
    if (!existing) {
      throw new Error('目标 DJ 不存在');
    }

    const name = resolvePrimaryName(payload, existing.name);
    if (!name) {
      throw new Error('DJ 名称不能为空');
    }

    const avatarUrl = cleanText(payload.avatarUrl) || existing.avatarUrl || null;
    if (!avatarUrl) {
      throw new Error('DJ 头像不能为空');
    }
    if (!hasAnyProof(payload, {
      spotifyId: existing.spotifyId,
      spotifyUrl: existing.spotifyUrl,
      appleMusicId: existing.appleMusicId,
      instagramUrl: existing.instagramUrl,
      facebookUrl: existing.facebookUrl,
      soundcloudUrl: existing.soundcloudUrl,
      soundcloudId: existing.soundcloudId,
      twitterUrl: existing.twitterUrl,
      youtubeUrl: existing.youtubeUrl,
      neteaseUrl: existing.neteaseUrl,
      qqMusicUrl: existing.qqMusicUrl,
      website: existing.website,
      proofImageUrl: null,
    })) {
      throw new Error('至少需要一个平台链接或一张证明图片');
    }

    const submittedAliases = Object.prototype.hasOwnProperty.call(payload, 'aliases')
      ? stringArray(payload.aliases)
      : (existing.aliases ?? []);
    const aliases = mergeAliases(
      name,
      normalizeDJNameKey(existing.name) === normalizeDJNameKey(name)
        ? submittedAliases
        : [existing.name, ...submittedAliases]
    );
    const genres = Object.prototype.hasOwnProperty.call(payload, 'genres')
      ? stringArray(payload.genres)
      : (existing.genres ?? []);
    const nextSlug = await uniqueDJSlug(db, name, cleanText(payload.slug) || existing.slug, existing.id);
    const nextData = buildResolvedDJUpdateData(payload, existing, {
      name,
      avatarUrl,
      aliases,
      genres,
      slug: nextSlug,
    });

    if (!hasDJMaterialChanges(existing, nextData)) {
      return existing;
    }

    const updated = await db.dJ.update({
      where: { id: existing.id },
      data: nextData as any,
    });

    await recordDJContribution(db, {
      entityId: updated.id,
      userId: submitterId,
      title: updated.name,
      coverImageUrl: updated.avatarUrl ?? null,
      role: 'editor',
      actionType: 'edit',
      source: 'submission_edit',
      submissionId: options.submissionId ?? null,
      approvedAt: options.approvedAt ?? null,
      versionAfter: null,
    });
    const afterChangeSnapshot = await entityChangeService.captureSnapshot({
      entityType: 'dj',
      entityId: updated.id,
      db,
    });
    const change = await entityChangeService.diffSnapshots({
      entityType: 'dj',
      entityId: updated.id,
      operationType: 'update',
      before: beforeChangeSnapshot,
      after: afterChangeSnapshot,
    });
    await entityChangeService.persistChange({
      result: change,
      snapshots: {
        before: beforeChangeSnapshot,
        after: afterChangeSnapshot,
      },
      actorId: submitterId,
      source: 'content_submission_dj_apply',
      sourceRoute: 'content-submission:dj:update',
      metadata: {
        submissionId: options.submissionId ?? null,
      },
    });
    return updated;
  }

  const name = resolvePrimaryName(payload);
  if (!name) {
    throw new Error('DJ 名称不能为空');
  }

  const avatarUrl = cleanText(payload.avatarUrl);
  if (!avatarUrl) {
    throw new Error('DJ 头像不能为空');
  }
  if (!hasAnyProof(payload)) {
    throw new Error('至少需要一个平台链接或一张证明图片');
  }

  const existing = await db.dJ.findFirst({
    where: { name: { equals: name, mode: 'insensitive' } },
    select: { id: true },
  });
  if (existing) {
    throw new Error('同名 DJ 已存在');
  }

  const slug = await uniqueDJSlug(db, name, cleanText(payload.slug));
  const created = await db.dJ.create({
    data: {
      name,
      nameI18n: triTextToJson(normalizeTriTextPayload(payload.nameI18n, name)),
      aliases: stringArray(payload.aliases),
      genres: stringArray(payload.genres),
      slug,
      bio: cleanText(payload.bio) || null,
      bioI18n: triTextToJson(normalizeTriTextPayload(payload.bioI18n, cleanText(payload.bio) || '')),
      avatarUrl,
      avatarSourceUrl: avatarUrl,
      bannerUrl: cleanText(payload.bannerUrl) || null,
      country: cleanText(payload.country) || null,
      countryI18n: triTextToJson(
        normalizeCountryBiTextPayload(payload.countryI18n, cleanText(payload.country) || '')
      ),
      spotifyUrl: cleanText(payload.spotifyUrl) || null,
      spotifyId: cleanText(payload.spotifyId) || null,
      spotifyFollowers: integerOrNull(payload.spotifyFollowers),
      appleMusicId: cleanText(payload.appleMusicId) || null,
      soundcloudUrl: cleanText(payload.soundcloudUrl) || null,
      soundcloudId: cleanText(payload.soundcloudId) || cleanText(payload.soundcloudid) || null,
      instagramUrl: cleanText(payload.instagramUrl) || null,
      facebookUrl: cleanText(payload.facebookUrl) || null,
      twitterUrl: cleanText(payload.twitterUrl) || null,
      youtubeUrl: cleanText(payload.youtubeUrl) || null,
      neteaseUrl: cleanText(payload.neteaseUrl) || null,
      qqMusicUrl: cleanText(payload.qqMusicUrl) || null,
      website: resolveWebsite(payload) || null,
      trackCount: integerOrNull(payload.trackCount),
      playlistCount: integerOrNull(payload.playlistCount),
      soundCloudFollowers:
        integerOrNull(payload.soundCloudFollowers) ??
        integerOrNull(payload.soundcloudFollowers) ??
        integerOrNull(payload.followers_count),
      soundCloudFavorites:
        integerOrNull(payload.soundCloudFavorites) ??
        integerOrNull(payload.soundcloudFavorites) ??
        integerOrNull(payload.public_favorites_count),
      isVerified: typeof payload.isVerified === 'boolean' ? payload.isVerified : true,
    } as any,
  });
  await recordDJContribution(db, {
    entityId: created.id,
    userId: submitterId,
    title: created.name,
    coverImageUrl: created.avatarUrl ?? null,
    role: 'creator',
    actionType: 'create',
    source: 'submission_create',
    submissionId: options.submissionId ?? null,
    approvedAt: options.approvedAt ?? null,
    versionAfter: null,
  });
  const afterChangeSnapshot = await entityChangeService.captureSnapshot({
    entityType: 'dj',
    entityId: created.id,
    db,
  });
  const change = await entityChangeService.diffSnapshots({
    entityType: 'dj',
    entityId: created.id,
    operationType: 'create',
    before: null,
    after: afterChangeSnapshot,
  });
  await entityChangeService.persistChange({
    result: change,
    snapshots: {
      before: null,
      after: afterChangeSnapshot,
    },
    actorId: submitterId,
    source: 'content_submission_dj_apply',
    sourceRoute: 'content-submission:dj:create',
    metadata: {
      submissionId: options.submissionId ?? null,
    },
  });
  return created;
};
