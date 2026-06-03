import {
  DJStudioCreateInput,
  DJStudioDraft,
  DJStudioLocalizedText,
  DJStudioUpdateInput,
} from './types';

const trimOrNull = (value?: string | null): string | null => {
  const trimmed = String(value || '').trim();
  return trimmed || null;
};

const primaryText = (value: DJStudioLocalizedText): string =>
  value.zh.trim() || value.en.trim() || value.ja.trim() || value.enFull.trim();

const normalizedLocalizedText = (
  value: DJStudioLocalizedText
): DJStudioLocalizedText | null => {
  const next: DJStudioLocalizedText = {
    zh: value.zh.trim(),
    en: value.en.trim(),
    ja: value.ja.trim(),
    enFull: value.enFull.trim(),
  };
  return next.zh || next.en || next.ja || next.enFull ? next : null;
};

const normalizeStringArray = (value: string[]): string[] => {
  const items = value
    .map((item) => item.trim())
    .filter(Boolean);
  return Array.from(new Set(items));
};

const integerOrNull = (value: string): number | null => {
  const trimmed = value.trim();
  if (!trimmed) return null;
  const numeric = Number(trimmed);
  return Number.isInteger(numeric) && numeric >= 0 ? numeric : null;
};

export const mapDJStudioDraftToCreateInput = (draft: DJStudioDraft): DJStudioCreateInput => ({
  name: primaryText(draft.name),
  nameI18n: normalizedLocalizedText(draft.name),
  spotifyId: trimOrNull(draft.spotifyId),
  aliases: normalizeStringArray(draft.aliases),
  genres: normalizeStringArray(draft.genres),
  bio: trimOrNull(primaryText(draft.bio)),
  bioI18n: normalizedLocalizedText(draft.bio),
  country: trimOrNull(primaryText(draft.country)),
  countryI18n: normalizedLocalizedText(draft.country),
  avatarUrl: trimOrNull(draft.avatarImage?.remoteUrl),
  bannerUrl: trimOrNull(draft.bannerImage?.remoteUrl),
  proofImageUrl: trimOrNull(draft.proofImage?.remoteUrl),
  spotifyUrl: trimOrNull(draft.spotifyUrl),
  spotifyFollowers: integerOrNull(draft.spotifyFollowers),
  appleMusicId: trimOrNull(draft.appleMusicId),
  instagramUrl: trimOrNull(draft.instagramUrl),
  facebookUrl: trimOrNull(draft.facebookUrl),
  soundcloudUrl: trimOrNull(draft.soundcloudUrl),
  soundcloudId: trimOrNull(draft.soundcloudId),
  twitterUrl: trimOrNull(draft.twitterUrl),
  youtubeUrl: trimOrNull(draft.youtubeUrl),
  neteaseUrl: trimOrNull(draft.neteaseUrl),
  qqMusicUrl: trimOrNull(draft.qqMusicUrl),
  website: trimOrNull(draft.website),
  otherPlatformUrl: trimOrNull(draft.otherPlatformUrl),
  trackCount: integerOrNull(draft.trackCount),
  playlistCount: integerOrNull(draft.playlistCount),
  soundCloudFollowers: integerOrNull(draft.soundCloudFollowers),
  soundCloudFavorites: integerOrNull(draft.soundCloudFavorites),
  isVerified: true,
});

export const mapDJStudioDraftToUpdateInput = (draft: DJStudioDraft): DJStudioUpdateInput => ({
  name: trimOrNull(primaryText(draft.name)),
  nameI18n: normalizedLocalizedText(draft.name),
  aliases: normalizeStringArray(draft.aliases),
  genres: normalizeStringArray(draft.genres),
  bio: trimOrNull(primaryText(draft.bio)),
  bioI18n: normalizedLocalizedText(draft.bio),
  avatarUrl: trimOrNull(draft.avatarImage?.remoteUrl),
  bannerUrl: trimOrNull(draft.bannerImage?.remoteUrl),
  country: trimOrNull(primaryText(draft.country)),
  countryI18n: normalizedLocalizedText(draft.country),
  spotifyId: trimOrNull(draft.spotifyId),
  appleMusicId: trimOrNull(draft.appleMusicId),
  spotifyUrl: trimOrNull(draft.spotifyUrl),
  spotifyFollowers: integerOrNull(draft.spotifyFollowers),
  instagramUrl: trimOrNull(draft.instagramUrl),
  facebookUrl: trimOrNull(draft.facebookUrl),
  soundcloudUrl: trimOrNull(draft.soundcloudUrl),
  soundcloudId: trimOrNull(draft.soundcloudId),
  twitterUrl: trimOrNull(draft.twitterUrl),
  youtubeUrl: trimOrNull(draft.youtubeUrl),
  neteaseUrl: trimOrNull(draft.neteaseUrl),
  qqMusicUrl: trimOrNull(draft.qqMusicUrl),
  website: trimOrNull(draft.website),
  otherPlatformUrl: trimOrNull(draft.otherPlatformUrl),
  trackCount: integerOrNull(draft.trackCount),
  playlistCount: integerOrNull(draft.playlistCount),
  soundCloudFollowers: integerOrNull(draft.soundCloudFollowers),
  soundCloudFavorites: integerOrNull(draft.soundCloudFavorites),
  isVerified: true,
});
