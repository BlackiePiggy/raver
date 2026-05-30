import { DJStudioDraft, DJStudioValidationErrors } from './types';

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

  if (!primaryText(draft.name)) {
    errors.name = '请填写 DJ 名称';
  }

  if (!draft.avatarImage?.remoteUrl?.trim()) {
    errors.avatarImage = '请上传 DJ 头像';
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
