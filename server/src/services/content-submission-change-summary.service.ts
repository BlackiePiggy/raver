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

const countOps = (value: unknown): Record<string, number> => {
  const counts: Record<string, number> = {};
  if (!Array.isArray(value)) return counts;
  for (const item of value) {
    if (!item || typeof item !== 'object' || Array.isArray(item)) continue;
    const op = cleanText((item as Record<string, unknown>).op) || 'unknown';
    counts[op] = (counts[op] || 0) + 1;
  }
  return counts;
};

const pushCount = (
  parts: string[],
  count: number,
  label: string
): void => {
  if (count > 0) parts.push(`${label} ${count} 个`);
};

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

export const buildContentSubmissionChangeSummary = (
  entityType: string,
  payload: Prisma.InputJsonObject | Prisma.JsonObject
): Prisma.InputJsonObject | null => {
  const row = payload as Record<string, unknown>;
  const isEventPatch =
    entityType === 'event' &&
    (cleanText(row.editMode) === 'patch' || isTargetedPatch(row, ['targetEventId', 'editTargetEventId']));
  const isDJPatch =
    entityType === 'dj' &&
    (cleanText(row.editMode) === 'patch' || isTargetedPatch(row, ['targetDJId', 'editTargetDJId']));

  if (isEventPatch) {
    const lineup = countOps(payload.lineupChanges);
    const timetable = countOps(payload.timetableChanges);
    const stage = countOps(payload.stageChanges);
    const parts: string[] = [];

    pushCount(parts, lineup.add || 0, '新增艺人');
    pushCount(parts, lineup.update || 0, '修改艺人');
    pushCount(parts, lineup.delete || 0, '删除艺人');
    pushCount(parts, lineup.reorder || 0, '调整艺人排序');
    pushCount(parts, timetable.add || 0, '新增 time slot');
    pushCount(parts, timetable.update || 0, '修改 time slot');
    pushCount(parts, timetable.delete || 0, '删除 time slot');
    pushCount(parts, timetable.reorder || 0, '调整 time slot 排序');
    pushCount(parts, stage.rename || 0, '重命名舞台');
    pushCount(parts, stage.delete || 0, '删除舞台');

    const total = Object.values({ ...lineup, ...timetable, ...stage }).reduce((sum, count) => sum + count, 0);
    return {
      mode: 'patch',
      zh: parts.length ? parts.join('，') : '未检测到阵容或时间表变更',
      en: parts.length ? parts.join(', ') : 'No lineup or timetable changes detected',
      totalChanges: total,
      lineup,
      timetable,
      stage,
    };
  }

  if (isDJPatch) {
    return buildDJPatchSummary(row);
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
