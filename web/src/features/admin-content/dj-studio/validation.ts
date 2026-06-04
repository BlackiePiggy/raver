import { DJStudioDraft, DJStudioValidationErrors } from './types';
import {
  INPUT_LIMITS,
  countText,
  normalizeSingleLine,
} from '@/lib/input-rules';

const primaryText = (value: DJStudioDraft['name'] | DJStudioDraft['bio'] | DJStudioDraft['country']): string =>
  value.zh.trim() || value.en.trim() || value.ja.trim() || value.enFull.trim();

const isValidUrl = (value: string): boolean => {
  try {
    const url = new URL(value);
    return url.protocol === 'http:' || url.protocol === 'https:';
  } catch {
    return false;
  }
};

export const validateDJStudioDraft = (draft: DJStudioDraft): DJStudioValidationErrors => {
  const errors: DJStudioValidationErrors = {};
  const name = primaryText(draft.name);
  const bio = primaryText(draft.bio);
  const country = primaryText(draft.country);

  if (!name) {
    errors.name = '请填写 DJ 名称';
  } else if (countText(name) > INPUT_LIMITS.dj.name) {
    errors.name = `DJ 名称不能超过 ${INPUT_LIMITS.dj.name} 个字符`;
  }

  if (!draft.avatarImage?.remoteUrl?.trim()) {
    errors.avatarImage = '请上传 DJ 头像';
  }

  if (bio && countText(bio, true) > INPUT_LIMITS.dj.bio) {
    errors.name = errors.name || `DJ 简介不能超过 ${INPUT_LIMITS.dj.bio} 个字符`;
  }

  if (country && countText(country) > INPUT_LIMITS.dj.country) {
    errors.name = errors.name || `国家/地区不能超过 ${INPUT_LIMITS.dj.country} 个字符`;
  }

  if (draft.aliases.some((item) => countText(item) > INPUT_LIMITS.dj.alias)) {
    errors.name = errors.name || `别名单项不能超过 ${INPUT_LIMITS.dj.alias} 个字符`;
  }

  if (draft.genres.some((item) => countText(item) > INPUT_LIMITS.dj.genre)) {
    errors.name = errors.name || `Genre 单项不能超过 ${INPUT_LIMITS.dj.genre} 个字符`;
  }

  const platformLinks = [
    draft.spotifyUrl,
    draft.instagramUrl,
    draft.facebookUrl,
    draft.soundcloudUrl,
    draft.twitterUrl,
    draft.youtubeUrl,
    draft.neteaseUrl,
    draft.qqMusicUrl,
    draft.website,
    draft.otherPlatformUrl,
  ].map((item) => item.trim()).filter(Boolean);

  if (!platformLinks.length && !draft.proofImage?.remoteUrl?.trim()) {
    errors.links = '请至少填写一个平台链接，或上传一张证明图片';
  }

  if (platformLinks.some((item) => !isValidUrl(item))) {
    errors.links = '平台链接格式不正确，请使用 http 或 https 链接';
  } else if (platformLinks.some((item) => normalizeSingleLine(item).length > 2000)) {
    errors.links = '平台链接长度过长，请控制在 2000 个字符以内';
  }

  const stats = [
    draft.spotifyFollowers,
    draft.trackCount,
    draft.playlistCount,
    draft.soundCloudFollowers,
    draft.soundCloudFavorites,
  ];
  if (
    stats.some((item) => {
      const trimmed = item.trim();
      if (!trimmed) return false;
      const numeric = Number(trimmed);
      return !Number.isInteger(numeric) || numeric < 0;
    })
  ) {
    errors.stats = '平台数据只能填写非负整数';
  }

  return errors;
};
