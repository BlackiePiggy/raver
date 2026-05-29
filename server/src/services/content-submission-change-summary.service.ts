import { Prisma } from '@prisma/client';

const cleanText = (value: unknown): string | undefined => {
  if (typeof value !== 'string') return undefined;
  const trimmed = value.trim();
  return trimmed || undefined;
};

const hasOwn = (value: Record<string, unknown>, key: string): boolean =>
  Object.prototype.hasOwnProperty.call(value, key);

const hasAnyOwn = (value: Record<string, unknown>, keys: string[]): boolean =>
  keys.some((key) => hasOwn(value, key));

const isTargetedPatch = (payload: Record<string, unknown>, keys: string[]): boolean =>
  keys.some((key) => cleanText(payload[key]));

const buildDJPatchSummary = (
  payload: Record<string, unknown>
): Prisma.InputJsonObject => {
  const partsZh: string[] = [];
  const partsEn: string[] = [];

  const push = (zh: string, en: string): void => {
    partsZh.push(zh);
    partsEn.push(en);
  };

  if (hasAnyOwn(payload, ['name', 'nameI18n'])) {
    push('更新名称', 'Updated name');
  }
  if (hasOwn(payload, 'aliases')) {
    push('更新别名', 'Updated aliases');
  }
  if (hasOwn(payload, 'genres')) {
    push('更新风格标签', 'Updated genres');
  }
  if (hasAnyOwn(payload, ['bio', 'bioI18n'])) {
    push('更新简介', 'Updated bio');
  }
  if (hasAnyOwn(payload, ['country', 'countryI18n'])) {
    push('更新国家/地区', 'Updated country or region');
  }
  if (hasAnyOwn(payload, ['avatarUrl', 'backgroundUrl'])) {
    push('更新图片素材', 'Updated images');
  }
  if (
    hasAnyOwn(payload, [
      'spotifyUrl',
      'appleMusicUrl',
      'soundcloudUrl',
      'instagramUrl',
      'youtubeUrl',
      'facebookUrl',
      'twitterUrl',
      'website',
      'otherPlatformUrl',
      'beatportUrl',
      'bandcampUrl',
      'tiktokUrl',
      'neteaseUrl',
      'qqMusicUrl',
    ])
  ) {
    push('更新外部链接', 'Updated external links');
  }
  if (
    hasAnyOwn(payload, [
      'spotifyFollowers',
      'trackCount',
      'track_count',
      'playlistCount',
      'playlist_count',
      'soundCloudFollowers',
      'soundcloudFollowers',
      'followers_count',
      'soundCloudFavorites',
      'soundcloudFavorites',
      'public_favorites_count',
      'isVerified',
    ])
  ) {
    push('更新平台数据', 'Updated platform stats');
  }

  return {
    mode: 'patch',
    zh: partsZh.length ? partsZh.join('，') : '更新 DJ 基础资料',
    en: partsEn.length ? partsEn.join(', ') : 'Updated DJ profile',
    totalChanges: partsZh.length,
    fields: {
      name: hasAnyOwn(payload, ['name', 'nameI18n']),
      aliases: hasOwn(payload, 'aliases'),
      genres: hasOwn(payload, 'genres'),
      bio: hasAnyOwn(payload, ['bio', 'bioI18n']),
      country: hasAnyOwn(payload, ['country', 'countryI18n']),
      images: hasAnyOwn(payload, ['avatarUrl', 'backgroundUrl']),
      links: hasAnyOwn(payload, [
        'spotifyUrl',
        'appleMusicUrl',
        'soundcloudUrl',
        'instagramUrl',
        'youtubeUrl',
        'facebookUrl',
        'twitterUrl',
        'website',
        'otherPlatformUrl',
        'beatportUrl',
        'bandcampUrl',
        'tiktokUrl',
        'neteaseUrl',
        'qqMusicUrl',
      ]),
      stats: hasAnyOwn(payload, [
        'spotifyFollowers',
        'trackCount',
        'track_count',
        'playlistCount',
        'playlist_count',
        'soundCloudFollowers',
        'soundcloudFollowers',
        'followers_count',
        'soundCloudFavorites',
        'soundcloudFavorites',
        'public_favorites_count',
        'isVerified',
      ]),
    } as Prisma.InputJsonValue,
  };
};

const buildBrandPatchSummary = (
  payload: Record<string, unknown>
): Prisma.InputJsonObject => {
  const partsZh: string[] = [];
  const partsEn: string[] = [];

  const push = (zh: string, en: string): void => {
    partsZh.push(zh);
    partsEn.push(en);
  };

  if (hasAnyOwn(payload, ['name', 'nameI18n', 'abbreviation', 'aliases'])) {
    push('更新基础名称信息', 'Updated brand naming');
  }
  if (hasAnyOwn(payload, ['country', 'countryI18n', 'city', 'cityI18n', 'foundedYear', 'frequency', 'frequencyI18n'])) {
    push('更新地区与基本资料', 'Updated region and profile basics');
  }
  if (hasAnyOwn(payload, ['tagline', 'introduction', 'descriptionI18n'])) {
    push('更新品牌介绍', 'Updated brand profile');
  }
  if (hasAnyOwn(payload, ['avatarUrl', 'backgroundUrl', 'imageAssets'])) {
    push('更新图片素材', 'Updated images');
  }
  if (hasAnyOwn(payload, ['officialWebsite', 'facebookUrl', 'instagramUrl', 'twitterUrl', 'youtubeUrl', 'tiktokUrl', 'links'])) {
    push('更新官方链接', 'Updated official links');
  }
  if (hasAnyOwn(payload, ['boundEventIDs', 'boundEventTitles'])) {
    push('更新关联活动', 'Updated related events');
  }
  if (hasAnyOwn(payload, ['rightsConfirmed', 'identityConfirmed', 'proofImageUrl'])) {
    push('更新审核与证明信息', 'Updated compliance and proof info');
  }

  return {
    mode: 'patch',
    zh: partsZh.length ? partsZh.join('，') : '更新主办方资料',
    en: partsEn.length ? partsEn.join(', ') : 'Updated brand profile',
    totalChanges: partsZh.length,
    fields: {
      naming: hasAnyOwn(payload, ['name', 'nameI18n', 'abbreviation', 'aliases']),
      profileBasics: hasAnyOwn(payload, ['country', 'countryI18n', 'city', 'cityI18n', 'foundedYear', 'frequency', 'frequencyI18n']),
      profile: hasAnyOwn(payload, ['tagline', 'introduction', 'descriptionI18n']),
      images: hasAnyOwn(payload, ['avatarUrl', 'backgroundUrl', 'imageAssets']),
      links: hasAnyOwn(payload, ['officialWebsite', 'facebookUrl', 'instagramUrl', 'twitterUrl', 'youtubeUrl', 'tiktokUrl', 'links']),
      events: hasAnyOwn(payload, ['boundEventIDs', 'boundEventTitles']),
      compliance: hasAnyOwn(payload, ['rightsConfirmed', 'identityConfirmed', 'proofImageUrl']),
    } as Prisma.InputJsonValue,
  };
};

export const buildContentSubmissionChangeSummary = (
  entityType: string,
  payload: Prisma.InputJsonObject | Prisma.JsonObject
): Prisma.InputJsonObject | null => {
  const row = payload as Record<string, unknown>;
  const isDJPatch =
    entityType === 'dj' &&
    (cleanText(row.editMode) === 'patch' || isTargetedPatch(row, ['targetDJId', 'editTargetDJId']));
  const isBrandPatch =
    entityType === 'brand' &&
    (cleanText(row.editMode) === 'patch' || isTargetedPatch(row, ['targetBrandId', 'editTargetBrandId']));

  if (isDJPatch) {
    return buildDJPatchSummary(row);
  }

  if (isBrandPatch) {
    return buildBrandPatchSummary(row);
  }

  return null;
};

export const attachContentSubmissionChangeSummary = (
  entityType: string,
  payload: Prisma.InputJsonObject
): Prisma.InputJsonObject => {
  const summary = buildContentSubmissionChangeSummary(entityType, payload);
  if (!summary) return payload;
  return {
    ...payload,
    changeSummary: summary as Prisma.InputJsonValue,
  };
};

export const changeSummaryTextFromPayload = (
  payload: unknown
): string | null => {
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) return null;
  const row = payload as Record<string, unknown>;
  const summary = row.changeSummary;
  if (!summary || typeof summary !== 'object' || Array.isArray(summary)) return null;
  return cleanText((summary as Record<string, unknown>).zh) || null;
};
