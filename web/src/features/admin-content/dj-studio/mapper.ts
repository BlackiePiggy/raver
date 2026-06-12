import {
  DJStudioCreateInput,
  DJStudioDraft,
  DJStudioLocalizedText,
  DJStudioUpdateInput,
} from './types';
import { INPUT_LIMITS, normalizeMultiline, normalizeSingleLine, trimArrayItems } from '@/lib/input-rules';

const trimSingleLineOrNull = (value: string | null | undefined, max: number): string | null => {
  const trimmed = normalizeSingleLine(value).slice(0, max);
  return trimmed || null;
};

const trimMultilineOrNull = (value: string | null | undefined, max: number): string | null => {
  const trimmed = normalizeMultiline(value).slice(0, max);
  return trimmed || null;
};

const trimUrlOrNull = (value?: string | null): string | null =>
  trimSingleLineOrNull(value, INPUT_LIMITS.common.url);

const trimIdOrNull = (value?: string | null): string | null =>
  trimSingleLineOrNull(value, INPUT_LIMITS.common.externalId);

const primaryText = (value: DJStudioLocalizedText): string =>
  normalizeSingleLine(value.zh) || normalizeSingleLine(value.en) || normalizeSingleLine(value.ja) || normalizeSingleLine(value.enFull);

const normalizedLocalizedText = (
  value: DJStudioLocalizedText,
  max: number,
  multiline = false
): DJStudioLocalizedText | null => {
  const next: DJStudioLocalizedText = {
    zh: (multiline ? normalizeMultiline(value.zh) : normalizeSingleLine(value.zh)).slice(0, max),
    en: (multiline ? normalizeMultiline(value.en) : normalizeSingleLine(value.en)).slice(0, max),
    ja: (multiline ? normalizeMultiline(value.ja) : normalizeSingleLine(value.ja)).slice(0, max),
    enFull: (multiline ? normalizeMultiline(value.enFull) : normalizeSingleLine(value.enFull)).slice(0, max),
  };
  return next.zh || next.en || next.ja || next.enFull ? next : null;
};

const normalizeStringArray = (value: string[], itemMax: number, maxItems: number): string[] =>
  trimArrayItems(value, itemMax).slice(0, maxItems);

const integerOrNull = (value: string): number | null => {
  const trimmed = normalizeSingleLine(value);
  if (!trimmed) return null;
  const numeric = Number(trimmed);
  return Number.isInteger(numeric) && numeric >= 0 ? numeric : null;
};

export const mapDJStudioDraftToCreateInput = (draft: DJStudioDraft): DJStudioCreateInput => ({
  name: primaryText(normalizedLocalizedText(draft.name, INPUT_LIMITS.dj.name) ?? draft.name).slice(0, INPUT_LIMITS.dj.name),
  nameI18n: normalizedLocalizedText(draft.name, INPUT_LIMITS.dj.name),
  spotifyId: trimIdOrNull(draft.spotifyId),
  aliases: normalizeStringArray(draft.aliases, INPUT_LIMITS.dj.alias, INPUT_LIMITS.dj.aliasesMaxItems),
  genres: normalizeStringArray(draft.genres, INPUT_LIMITS.dj.genre, INPUT_LIMITS.dj.genresMaxItems),
  genreBindings: draft.genreBindings
    .map((binding) => ({
      genreId: trimSingleLineOrNull(binding.genreId, 128) || '',
      label: trimSingleLineOrNull(binding.label, INPUT_LIMITS.dj.genre) || '',
      displayName: trimSingleLineOrNull(binding.displayName, INPUT_LIMITS.dj.genre) || undefined,
      path: trimSingleLineOrNull(binding.path, 255),
    }))
    .filter((binding) => Boolean(binding.genreId)),
  bio: trimMultilineOrNull(primaryText(draft.bio), INPUT_LIMITS.dj.bio),
  bioI18n: normalizedLocalizedText(draft.bio, INPUT_LIMITS.dj.bio, true),
  country: trimSingleLineOrNull(primaryText(draft.country), INPUT_LIMITS.dj.country),
  countryI18n: normalizedLocalizedText(draft.country, INPUT_LIMITS.dj.country),
  avatarUrl: trimUrlOrNull(draft.avatarImage?.remoteUrl),
  bannerUrl: trimUrlOrNull(draft.bannerImage?.remoteUrl),
  proofImageUrl: trimUrlOrNull(draft.proofImage?.remoteUrl),
  spotifyUrl: trimUrlOrNull(draft.spotifyUrl),
  spotifyFollowers: integerOrNull(draft.spotifyFollowers),
  appleMusicId: trimIdOrNull(draft.appleMusicId),
  instagramUrl: trimUrlOrNull(draft.instagramUrl),
  facebookUrl: trimUrlOrNull(draft.facebookUrl),
  soundcloudUrl: trimUrlOrNull(draft.soundcloudUrl),
  soundcloudId: trimIdOrNull(draft.soundcloudId),
  twitterUrl: trimUrlOrNull(draft.twitterUrl),
  youtubeUrl: trimUrlOrNull(draft.youtubeUrl),
  neteaseUrl: trimUrlOrNull(draft.neteaseUrl),
  qqMusicUrl: trimUrlOrNull(draft.qqMusicUrl),
  website: trimUrlOrNull(draft.website),
  otherPlatformUrl: trimUrlOrNull(draft.otherPlatformUrl),
  sourceWikipedia: trimUrlOrNull(draft.sourceWikipedia),
  sourceWebsite: trimUrlOrNull(draft.sourceWebsite),
  sourceSameAs: normalizeStringArray(draft.sourceSameAs, INPUT_LIMITS.common.url, 50),
  trackCount: integerOrNull(draft.trackCount),
  playlistCount: integerOrNull(draft.playlistCount),
  soundCloudFollowers: integerOrNull(draft.soundCloudFollowers),
  soundCloudFavorites: integerOrNull(draft.soundCloudFavorites),
  isVerified: true,
});

export const mapDJStudioDraftToUpdateInput = (draft: DJStudioDraft): DJStudioUpdateInput => ({
  name: trimSingleLineOrNull(primaryText(draft.name), INPUT_LIMITS.dj.name),
  nameI18n: normalizedLocalizedText(draft.name, INPUT_LIMITS.dj.name),
  aliases: normalizeStringArray(draft.aliases, INPUT_LIMITS.dj.alias, INPUT_LIMITS.dj.aliasesMaxItems),
  genres: normalizeStringArray(draft.genres, INPUT_LIMITS.dj.genre, INPUT_LIMITS.dj.genresMaxItems),
  genreBindings: draft.genreBindings
    .map((binding) => ({
      genreId: trimSingleLineOrNull(binding.genreId, 128) || '',
      label: trimSingleLineOrNull(binding.label, INPUT_LIMITS.dj.genre) || '',
      displayName: trimSingleLineOrNull(binding.displayName, INPUT_LIMITS.dj.genre) || undefined,
      path: trimSingleLineOrNull(binding.path, 255),
    }))
    .filter((binding) => Boolean(binding.genreId)),
  bio: trimMultilineOrNull(primaryText(draft.bio), INPUT_LIMITS.dj.bio),
  bioI18n: normalizedLocalizedText(draft.bio, INPUT_LIMITS.dj.bio, true),
  avatarUrl: trimUrlOrNull(draft.avatarImage?.remoteUrl),
  bannerUrl: trimUrlOrNull(draft.bannerImage?.remoteUrl),
  proofImageUrl: trimUrlOrNull(draft.proofImage?.remoteUrl),
  country: trimSingleLineOrNull(primaryText(draft.country), INPUT_LIMITS.dj.country),
  countryI18n: normalizedLocalizedText(draft.country, INPUT_LIMITS.dj.country),
  spotifyId: trimIdOrNull(draft.spotifyId),
  appleMusicId: trimIdOrNull(draft.appleMusicId),
  spotifyUrl: trimUrlOrNull(draft.spotifyUrl),
  spotifyFollowers: integerOrNull(draft.spotifyFollowers),
  instagramUrl: trimUrlOrNull(draft.instagramUrl),
  facebookUrl: trimUrlOrNull(draft.facebookUrl),
  soundcloudUrl: trimUrlOrNull(draft.soundcloudUrl),
  soundcloudId: trimIdOrNull(draft.soundcloudId),
  twitterUrl: trimUrlOrNull(draft.twitterUrl),
  youtubeUrl: trimUrlOrNull(draft.youtubeUrl),
  neteaseUrl: trimUrlOrNull(draft.neteaseUrl),
  qqMusicUrl: trimUrlOrNull(draft.qqMusicUrl),
  website: trimUrlOrNull(draft.website),
  otherPlatformUrl: trimUrlOrNull(draft.otherPlatformUrl),
  sourceWikipedia: trimUrlOrNull(draft.sourceWikipedia),
  sourceWebsite: trimUrlOrNull(draft.sourceWebsite),
  sourceSameAs: normalizeStringArray(draft.sourceSameAs, INPUT_LIMITS.common.url, 50),
  trackCount: integerOrNull(draft.trackCount),
  playlistCount: integerOrNull(draft.playlistCount),
  soundCloudFollowers: integerOrNull(draft.soundCloudFollowers),
  soundCloudFavorites: integerOrNull(draft.soundCloudFavorites),
  isVerified: true,
});
