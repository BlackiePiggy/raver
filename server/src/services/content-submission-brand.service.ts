import { Prisma, PrismaClient } from '@prisma/client';
import crypto from 'crypto';
import { normalizeCountryBiTextPayload } from '../utils/country-i18n';
import { normalizeTriTextPayload, triTextToJson } from '../utils/i18n';

const cleanText = (value: unknown): string | undefined => {
  if (typeof value !== 'string') return undefined;
  const trimmed = value.trim();
  return trimmed || undefined;
};

const hasOwn = (value: Prisma.JsonObject, key: string): boolean =>
  Object.prototype.hasOwnProperty.call(value, key);

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

const integerOrNull = (value: unknown): number | null => {
  if (value === null || value === undefined || value === '') return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? Math.trunc(parsed) : null;
};

const slugify = (value: string): string =>
  value
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '') || 'brand';

type BrandLinkPayload = {
  title: string;
  icon: string;
  url: string;
};

const parseLinks = (value: unknown): BrandLinkPayload[] => {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => {
      if (!item || typeof item !== 'object' || Array.isArray(item)) return null;
      const row = item as Record<string, unknown>;
      const title = cleanText(row.title);
      const icon = cleanText(row.icon);
      const url = cleanText(row.url);
      if (!title || !icon || !url) return null;
      return { title, icon, url } as BrandLinkPayload;
    })
    .filter((item): item is BrandLinkPayload => item !== null);
};

const mergeLinks = (
  baseLinks: BrandLinkPayload[],
  fields: {
    officialWebsite?: string | null;
    facebookUrl?: string | null;
    instagramUrl?: string | null;
    twitterUrl?: string | null;
    youtubeUrl?: string | null;
    tiktokUrl?: string | null;
  }
): BrandLinkPayload[] => {
  const merged: BrandLinkPayload[] = Array.isArray(baseLinks) ? [...baseLinks] : [];
  const seen = new Set(
    merged
      .map((item) => cleanText(item.url)?.toLowerCase() || '')
      .filter(Boolean)
  );

  const push = (title: string, icon: string, url: string | null | undefined): void => {
    const normalizedUrl = cleanText(url);
    if (!normalizedUrl) return;
    const key = normalizedUrl.toLowerCase();
    if (seen.has(key)) return;
    seen.add(key);
    merged.push({ title, icon, url: normalizedUrl });
  };

  push('Official', 'globe', fields.officialWebsite);
  push('Facebook', 'f.square', fields.facebookUrl);
  push('Instagram', 'camera', fields.instagramUrl);
  push('X / Twitter', 'bird', fields.twitterUrl);
  push('YouTube', 'play.rectangle', fields.youtubeUrl);
  push('TikTok', 'music.note', fields.tiktokUrl);
  return merged;
};

const uniqueWikiFestivalId = async (
  db: Prisma.TransactionClient | PrismaClient,
  name: string
): Promise<string> => {
  const base = slugify(name) || `brand-${Date.now()}`;
  let candidate = base;
  let seq = 1;

  while (true) {
    const existing = await db.wikiFestival.findUnique({
      where: { id: candidate },
      select: { id: true },
    });
    if (!existing) {
      return candidate;
    }
    seq += 1;
    candidate = `${base}-${seq}`;
  }
};

const ensureBrandContributor = async (
  db: Prisma.TransactionClient | PrismaClient,
  festivalId: string,
  userId: string
): Promise<void> => {
  await db.$executeRaw(Prisma.sql`
    INSERT INTO "wiki_festival_contributors" ("id", "festival_id", "user_id", "created_at", "updated_at")
    VALUES (${crypto.randomUUID()}, ${festivalId}, ${userId}, NOW(), NOW())
    ON CONFLICT ("festival_id", "user_id") DO NOTHING
  `);
};

const resolvePrimaryName = (payload: Prisma.JsonObject, fallback?: string | null): string => {
  const name =
    cleanText(payload.name) ||
    cleanText(payload.title) ||
    pickPrimaryText(payload.nameI18n) ||
    fallback ||
    '';
  return name.trim();
};

const pickPrimaryText = (value: unknown, fallback = ''): string => {
  const normalized = normalizeTriTextPayload(value, fallback);
  return cleanText(normalized?.zh) || cleanText(normalized?.en) || cleanText(normalized?.ja) || cleanText(fallback) || '';
};

const resolveOptionalString = (
  payload: Prisma.JsonObject,
  key: string,
  fallback?: string | null
): string | null => {
  if (!hasOwn(payload, key)) {
    return fallback ?? null;
  }
  const value = payload[key];
  if (value === null) return null;
  return cleanText(value) ?? null;
};

const resolveRequiredText = (
  payload: Prisma.JsonObject,
  key: string,
  fallback?: string | null
): string => {
  if (!hasOwn(payload, key)) {
    return cleanText(fallback) || '';
  }
  return cleanText(payload[key]) || '';
};

const collectImageAssetUrls = (value: unknown): string[] => {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => {
      if (!item || typeof item !== 'object' || Array.isArray(item)) return null;
      return cleanText((item as Record<string, unknown>).url) || null;
    })
    .filter((item): item is string => Boolean(item));
};

export const collectBrandSubmissionMediaUrls = (payload: Prisma.JsonObject): string[] => {
  const urls = [
    cleanText(payload.avatarUrl) || null,
    cleanText(payload.backgroundUrl) || null,
    cleanText(payload.proofImageUrl) || null,
    ...collectImageAssetUrls(payload.imageAssets),
  ].filter((item): item is string => Boolean(item));

  return Array.from(new Set(urls.map((item) => item.trim()).filter(Boolean)));
};

export const bindBrandDraftMediaToSubmission = async (
  db: Prisma.TransactionClient | PrismaClient,
  payload: Prisma.JsonObject,
  submitterId: string,
  submissionId: string
): Promise<void> => {
  const urls = collectBrandSubmissionMediaUrls(payload);
  if (!urls.length) return;

  await db.mediaAsset.updateMany({
    where: {
      ownerType: 'wiki_brand_draft',
      uploadedById: submitterId,
      url: { in: urls },
      status: 'active',
    },
    data: {
      ownerType: 'content-submission',
      ownerId: submissionId,
    },
  });
};

export const rebindBrandSubmissionMediaToBrand = async (
  db: Prisma.TransactionClient | PrismaClient,
  payload: Prisma.JsonObject,
  submissionId: string,
  brandId: string
): Promise<void> => {
  const urls = collectBrandSubmissionMediaUrls(payload);
  if (!urls.length) return;

  await db.mediaAsset.updateMany({
    where: {
      ownerType: 'content-submission',
      ownerId: submissionId,
      url: { in: urls },
      status: 'active',
    },
    data: {
      ownerType: 'wiki_brand',
      ownerId: brandId,
    },
  });
};

export const createOrUpdateBrandFromSubmission = async (
  db: Prisma.TransactionClient | PrismaClient,
  payload: Prisma.JsonObject,
  submitterId: string,
  options: {
    submissionId?: string;
  } = {}
) => {
  const targetBrandId = cleanText(payload.targetBrandId) || cleanText(payload.editTargetBrandId) || null;

  if (targetBrandId) {
    const existing = await db.wikiFestival.findUnique({
      where: { id: targetBrandId },
    });
    if (!existing) {
      throw new Error('目标主办方不存在');
    }

    const name = resolvePrimaryName(payload, existing.name);
    if (!name) {
      throw new Error('主办方名称不能为空');
    }

    const hasNameField = hasOwn(payload, 'name');
    const hasNameI18nField = hasOwn(payload, 'nameI18n');
    const hasCountryField = hasOwn(payload, 'country');
    const hasCountryI18nField = hasOwn(payload, 'countryI18n');
    const hasCityField = hasOwn(payload, 'city');
    const hasCityI18nField = hasOwn(payload, 'cityI18n');
    const hasFrequencyField = hasOwn(payload, 'frequency');
    const hasFrequencyI18nField = hasOwn(payload, 'frequencyI18n');
    const hasIntroductionField = hasOwn(payload, 'introduction');
    const hasDescriptionField = hasOwn(payload, 'description');
    const hasDescriptionI18nField = hasOwn(payload, 'descriptionI18n');
    const hasLinksField = hasOwn(payload, 'links');
    const hasOfficialWebsiteField = hasOwn(payload, 'officialWebsite');
    const hasFacebookUrlField = hasOwn(payload, 'facebookUrl');
    const hasInstagramUrlField = hasOwn(payload, 'instagramUrl');
    const hasTwitterUrlField = hasOwn(payload, 'twitterUrl');
    const hasYoutubeUrlField = hasOwn(payload, 'youtubeUrl');
    const hasTiktokUrlField = hasOwn(payload, 'tiktokUrl');

    let nextName = hasNameField ? (cleanText(payload.name) || '') : existing.name;
    let nextNameI18n: Prisma.InputJsonValue | typeof Prisma.DbNull | undefined = undefined;
    if (hasNameI18nField) {
      const normalized = normalizeTriTextPayload(payload.nameI18n, nextName);
      nextNameI18n = normalized ? triTextToJson(normalized) : Prisma.DbNull;
      if (!hasNameField && normalized) {
        nextName = pickPrimaryText(normalized, existing.name);
      }
    }

    let nextCountry = hasCountryField ? (cleanText(payload.country) || '') : existing.country;
    let nextCountryI18n: Prisma.InputJsonValue | typeof Prisma.DbNull | undefined = undefined;
    if (hasCountryI18nField) {
      const normalized = normalizeCountryBiTextPayload(payload.countryI18n, nextCountry);
      nextCountryI18n = normalized ? (normalized as unknown as Prisma.InputJsonValue) : Prisma.DbNull;
      if (!hasCountryField && normalized) {
        nextCountry = pickPrimaryText(normalized, existing.country);
      }
    }

    let nextCity = hasCityField ? (cleanText(payload.city) || '') : existing.city;
    let nextCityI18n: Prisma.InputJsonValue | typeof Prisma.DbNull | undefined = undefined;
    if (hasCityI18nField) {
      const normalized = normalizeTriTextPayload(payload.cityI18n, nextCity);
      nextCityI18n = normalized ? triTextToJson(normalized) : Prisma.DbNull;
      if (!hasCityField && normalized) {
        nextCity = pickPrimaryText(normalized, existing.city);
      }
    }

    let nextFrequency = hasFrequencyField ? (cleanText(payload.frequency) || '') : existing.frequency;
    let nextFrequencyI18n: Prisma.InputJsonValue | typeof Prisma.DbNull | undefined = undefined;
    if (hasFrequencyI18nField) {
      const normalized = normalizeTriTextPayload(payload.frequencyI18n, nextFrequency);
      nextFrequencyI18n = normalized ? triTextToJson(normalized) : Prisma.DbNull;
      if (!hasFrequencyField && normalized) {
        nextFrequency = pickPrimaryText(normalized, existing.frequency);
      }
    }

    let nextIntroduction =
      hasIntroductionField || hasDescriptionField
        ? (cleanText(payload.introduction) || cleanText(payload.description) || '')
        : (existing.introduction || '');
    let nextDescriptionI18n: Prisma.InputJsonValue | typeof Prisma.DbNull | undefined = undefined;
    if (hasDescriptionI18nField) {
      const normalized = normalizeTriTextPayload(payload.descriptionI18n, nextIntroduction);
      nextDescriptionI18n = normalized ? triTextToJson(normalized) : Prisma.DbNull;
      if (!hasIntroductionField && !hasDescriptionField && normalized) {
        nextIntroduction = pickPrimaryText(normalized, existing.introduction || '');
      }
    }

    const nextOfficialWebsite = resolveOptionalString(payload, 'officialWebsite', existing.officialWebsite);
    const nextFacebookUrl = resolveOptionalString(payload, 'facebookUrl', existing.facebookUrl);
    const nextInstagramUrl = resolveOptionalString(payload, 'instagramUrl', existing.instagramUrl);
    const nextTwitterUrl = resolveOptionalString(payload, 'twitterUrl', existing.twitterUrl);
    const nextYoutubeUrl = resolveOptionalString(payload, 'youtubeUrl', existing.youtubeUrl);
    const nextTiktokUrl = resolveOptionalString(payload, 'tiktokUrl', existing.tiktokUrl);

    const nextLinks =
      hasLinksField ||
      hasOfficialWebsiteField ||
      hasFacebookUrlField ||
      hasInstagramUrlField ||
      hasTwitterUrlField ||
      hasYoutubeUrlField ||
      hasTiktokUrlField
        ? mergeLinks(
            hasLinksField ? parseLinks(payload.links) : parseLinks(existing.links),
            {
              officialWebsite: nextOfficialWebsite,
              facebookUrl: nextFacebookUrl,
              instagramUrl: nextInstagramUrl,
              twitterUrl: nextTwitterUrl,
              youtubeUrl: nextYoutubeUrl,
              tiktokUrl: nextTiktokUrl,
            }
          )
        : null;

    const updated = await db.wikiFestival.update({
      where: { id: existing.id },
      data: {
        sourceRowId: hasOwn(payload, 'sourceRowId')
          ? integerOrNull(payload.sourceRowId)
          : existing.sourceRowId,
        name: (hasNameField || hasNameI18nField) ? (nextName || existing.name) : name,
        nameI18n: nextNameI18n === undefined
          ? existing.nameI18n
          : nextNameI18n,
        abbreviation: hasOwn(payload, 'abbreviation')
          ? (cleanText(payload.abbreviation) || '')
          : (existing.abbreviation ?? ''),
        aliases: hasOwn(payload, 'aliases')
          ? stringArray(payload.aliases)
          : existing.aliases,
        country: (hasCountryField || hasCountryI18nField) ? nextCountry : resolveRequiredText(payload, 'country', existing.country),
        countryI18n: nextCountryI18n === undefined
          ? existing.countryI18n
          : nextCountryI18n,
        city: (hasCityField || hasCityI18nField) ? nextCity : resolveRequiredText(payload, 'city', existing.city),
        cityI18n: nextCityI18n === undefined
          ? existing.cityI18n
          : nextCityI18n,
        foundedYear: hasOwn(payload, 'foundedYear')
          ? resolveRequiredText(payload, 'foundedYear', existing.foundedYear)
          : existing.foundedYear,
        frequency: (hasFrequencyField || hasFrequencyI18nField)
          ? nextFrequency
          : existing.frequency,
        frequencyI18n: nextFrequencyI18n === undefined
          ? existing.frequencyI18n
          : nextFrequencyI18n,
        tagline: hasOwn(payload, 'tagline')
          ? resolveRequiredText(payload, 'tagline', existing.tagline)
          : existing.tagline,
        introduction: (hasIntroductionField || hasDescriptionField || hasDescriptionI18nField)
          ? nextIntroduction
          : existing.introduction,
        descriptionI18n: nextDescriptionI18n === undefined
          ? existing.descriptionI18n
          : nextDescriptionI18n,
        officialWebsite: nextOfficialWebsite,
        facebookUrl: nextFacebookUrl,
        instagramUrl: nextInstagramUrl,
        twitterUrl: nextTwitterUrl,
        youtubeUrl: nextYoutubeUrl,
        tiktokUrl: nextTiktokUrl,
        avatarUrl: resolveOptionalString(payload, 'avatarUrl', existing.avatarUrl),
        backgroundUrl: resolveOptionalString(payload, 'backgroundUrl', existing.backgroundUrl),
        links: nextLinks === null
          ? (existing.links ?? undefined)
          : (nextLinks as unknown as Prisma.InputJsonValue),
      } as any,
    });

    await ensureBrandContributor(db, updated.id, submitterId);
    if (options.submissionId) {
      await rebindBrandSubmissionMediaToBrand(db, payload, options.submissionId, updated.id);
    }
    return updated;
  }

  const name = resolvePrimaryName(payload);
  if (!name) {
    throw new Error('主办方名称不能为空');
  }

  const id = await uniqueWikiFestivalId(db, name);
  const created = await db.wikiFestival.create({
    data: {
      id,
      sourceRowId: integerOrNull(payload.sourceRowId),
      name,
      nameI18n: triTextToJson(normalizeTriTextPayload(payload.nameI18n, name)),
      abbreviation: cleanText(payload.abbreviation) || '',
      aliases: stringArray(payload.aliases),
      country: cleanText(payload.country) || pickPrimaryText(payload.countryI18n) || '',
      countryI18n: triTextToJson(
        normalizeCountryBiTextPayload(
          payload.countryI18n,
          cleanText(payload.country) || pickPrimaryText(payload.countryI18n) || ''
        )
      ),
      city: cleanText(payload.city) || pickPrimaryText(payload.cityI18n) || '',
      cityI18n: triTextToJson(
        normalizeTriTextPayload(
          payload.cityI18n,
          cleanText(payload.city) || pickPrimaryText(payload.cityI18n) || ''
        )
      ),
      foundedYear: cleanText(payload.foundedYear) || '',
      frequency: cleanText(payload.frequency) || pickPrimaryText(payload.frequencyI18n) || '',
      frequencyI18n: triTextToJson(
        normalizeTriTextPayload(
          payload.frequencyI18n,
          cleanText(payload.frequency) || pickPrimaryText(payload.frequencyI18n) || ''
        )
      ),
      tagline: cleanText(payload.tagline) || '',
      introduction:
        cleanText(payload.introduction) ||
        cleanText(payload.description) ||
        pickPrimaryText(payload.descriptionI18n) ||
        '',
      descriptionI18n: triTextToJson(
        normalizeTriTextPayload(
          payload.descriptionI18n,
          cleanText(payload.introduction) ||
            cleanText(payload.description) ||
            pickPrimaryText(payload.descriptionI18n) ||
            ''
        )
      ),
      officialWebsite: cleanText(payload.officialWebsite) || null,
      facebookUrl: cleanText(payload.facebookUrl) || null,
      instagramUrl: cleanText(payload.instagramUrl) || null,
      twitterUrl: cleanText(payload.twitterUrl) || null,
      youtubeUrl: cleanText(payload.youtubeUrl) || null,
      tiktokUrl: cleanText(payload.tiktokUrl) || null,
      avatarUrl: cleanText(payload.avatarUrl) || null,
      backgroundUrl: cleanText(payload.backgroundUrl) || null,
      links: mergeLinks(parseLinks(payload.links), {
        officialWebsite: cleanText(payload.officialWebsite) || null,
        facebookUrl: cleanText(payload.facebookUrl) || null,
        instagramUrl: cleanText(payload.instagramUrl) || null,
        twitterUrl: cleanText(payload.twitterUrl) || null,
        youtubeUrl: cleanText(payload.youtubeUrl) || null,
        tiktokUrl: cleanText(payload.tiktokUrl) || null,
      }) as unknown as Prisma.InputJsonValue,
      contributors: { create: { userId: submitterId } },
    } as any,
  });
  if (options.submissionId) {
    await rebindBrandSubmissionMediaToBrand(db, payload, options.submissionId, created.id);
  }
  return created;
};
