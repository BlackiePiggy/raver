import { Prisma, PrismaClient } from '@prisma/client';
import crypto from 'crypto';
import { normalizeCountryBiTextPayload } from '../utils/country-i18n';
import { normalizeTriTextPayload, triTextToJson } from '../utils/i18n';

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

const ensureDJContributor = async (
  db: Prisma.TransactionClient | PrismaClient,
  djId: string,
  userId: string
): Promise<void> => {
  await db.$executeRaw(Prisma.sql`
    INSERT INTO "dj_contributors" ("id", "dj_id", "user_id", "created_at", "updated_at")
    VALUES (${crypto.randomUUID()}, ${djId}, ${userId}, NOW(), NOW())
    ON CONFLICT ("dj_id", "user_id") DO NOTHING
  `);
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

export const createOrUpdateDJFromSubmission = async (
  db: Prisma.TransactionClient | PrismaClient,
  payload: Prisma.JsonObject,
  submitterId: string
) => {
  const targetDJId = cleanText(payload.targetDJId) || cleanText(payload.editTargetDJId) || null;

  if (targetDJId) {
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

    const updated = await db.dJ.update({
      where: { id: existing.id },
      data: {
        name,
        nameI18n: triTextToJson(normalizeTriTextPayload(payload.nameI18n ?? existing.nameI18n, name)),
        aliases,
        genres,
        slug: nextSlug,
        bio: cleanText(payload.bio) ?? existing.bio ?? null,
        bioI18n: triTextToJson(
          normalizeTriTextPayload(payload.bioI18n ?? existing.bioI18n, cleanText(payload.bio) ?? existing.bio ?? '')
        ),
        avatarUrl,
        avatarSourceUrl: avatarUrl,
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
      } as any,
    });

    await ensureDJContributor(db, updated.id, submitterId);
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
  return db.dJ.create({
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
      contributors: { create: { userId: submitterId } },
    } as any,
  });
};
