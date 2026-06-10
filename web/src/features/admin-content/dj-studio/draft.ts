import {
  DJStudioDraft,
  DJStudioLoadedDJ,
  DJStudioLocalizedText,
} from './types';

const emptyLocalizedText = (initialValue = ''): DJStudioLocalizedText => ({
  zh: initialValue,
  en: '',
  ja: '',
  enFull: '',
});

const fromNullableLocalizedText = (
  value?: DJStudioLocalizedText | null,
  fallback = ''
): DJStudioLocalizedText => ({
  zh: value?.zh ?? fallback,
  en: value?.en ?? '',
  ja: value?.ja ?? '',
  enFull: value?.enFull ?? '',
});

export const createDJStudioDraft = (initialName = ''): DJStudioDraft => ({
  id: crypto.randomUUID(),
  name: emptyLocalizedText(initialName),
  aliases: [''],
  genres: [''],
  genreBindings: [],
  bio: emptyLocalizedText(),
  country: emptyLocalizedText(),
  avatarImage: null,
  bannerImage: null,
  proofImage: null,
  sourceWikipedia: '',
  sourceWebsite: '',
  sourceSameAs: [''],
  spotifyId: '',
  spotifyUrl: '',
  spotifyFollowers: '',
  appleMusicId: '',
  instagramUrl: '',
  facebookUrl: '',
  soundcloudUrl: '',
  soundcloudId: '',
  twitterUrl: '',
  youtubeUrl: '',
  neteaseUrl: '',
  qqMusicUrl: '',
  website: '',
  otherPlatformUrl: '',
  trackCount: '',
  playlistCount: '',
  soundCloudFollowers: '',
  soundCloudFavorites: '',
});

export const hydrateDJStudioDraftFromDJ = (dj: DJStudioLoadedDJ): DJStudioDraft => ({
  id: crypto.randomUUID(),
  name: fromNullableLocalizedText(dj.nameI18n, dj.name),
  aliases: (dj.aliases ?? []).length ? [...(dj.aliases ?? [])] : [''],
  genres: (dj.genres ?? []).length ? [...(dj.genres ?? [])] : [''],
  genreBindings: Array.isArray(dj.genreBindings) ? [...dj.genreBindings] : [],
  bio: fromNullableLocalizedText(dj.bioI18n, dj.bio ?? ''),
  country: fromNullableLocalizedText(dj.countryI18n, dj.country ?? ''),
  avatarImage: dj.avatarUrl
    ? {
        remoteUrl: dj.avatarUrl,
        fileName: dj.avatarUrl.split('/').pop() || 'avatar',
        usage: 'avatar',
        origin: 'persisted',
      }
    : null,
  bannerImage: dj.bannerUrl
    ? {
        remoteUrl: dj.bannerUrl,
        fileName: dj.bannerUrl.split('/').pop() || 'banner',
        usage: 'banner',
        origin: 'persisted',
      }
    : null,
  proofImage: null,
  sourceWikipedia: dj.sourceWikipedia ?? '',
  sourceWebsite: dj.sourceWebsite ?? '',
  sourceSameAs: (dj.sourceSameAs ?? []).length ? [...(dj.sourceSameAs ?? [])] : [''],
  spotifyId: dj.spotifyId ?? '',
  spotifyUrl: dj.spotifyUrl ?? '',
  spotifyFollowers: dj.spotifyFollowers != null ? String(dj.spotifyFollowers) : '',
  appleMusicId: dj.appleMusicId ?? '',
  instagramUrl: dj.instagramUrl ?? '',
  facebookUrl: dj.facebookUrl ?? '',
  soundcloudUrl: dj.soundcloudUrl ?? '',
  soundcloudId: dj.soundcloudId ?? '',
  twitterUrl: dj.twitterUrl ?? '',
  youtubeUrl: dj.youtubeUrl ?? '',
  neteaseUrl: dj.neteaseUrl ?? '',
  qqMusicUrl: dj.qqMusicUrl ?? '',
  website: dj.website ?? '',
  otherPlatformUrl: dj.otherPlatformUrl ?? '',
  trackCount: dj.trackCount != null ? String(dj.trackCount) : '',
  playlistCount: dj.playlistCount != null ? String(dj.playlistCount) : '',
  soundCloudFollowers: dj.soundCloudFollowers != null ? String(dj.soundCloudFollowers) : '',
  soundCloudFavorites: dj.soundCloudFavorites != null ? String(dj.soundCloudFavorites) : '',
});
