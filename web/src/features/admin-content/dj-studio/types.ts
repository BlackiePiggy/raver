import type { EventDerivedStatus } from '@/lib/api/event';

export type DJStudioLocalizedText = {
  zh: string;
  en: string;
  ja: string;
  enFull: string;
};

export type DJStudioImageUsage = 'avatar' | 'banner' | 'proof';

export type DJStudioImageState = {
  remoteUrl: string;
  fileName: string;
  usage: DJStudioImageUsage;
  origin: 'draft-upload' | 'persisted';
};

export type DJStudioSourceKey = 'keep' | 'spotify' | 'discogs' | 'soundcloud';

export type DJStudioSourceCandidate = {
  source: Exclude<DJStudioSourceKey, 'keep'>;
  name: string;
  avatarUrl: string | null;
  aliases: string[];
  genres: string[];
  bio: string;
  country: string;
  countryEnFull: string;
  website: string;
  spotifyUrl: string;
  spotifyId: string;
  spotifyFollowers: string;
  appleMusicId: string;
  instagramUrl: string;
  facebookUrl: string;
  twitterUrl: string;
  youtubeUrl: string;
  soundcloudUrl: string;
  soundcloudId: string;
  neteaseUrl: string;
  qqMusicUrl: string;
  sourceWikipedia: string;
  sourceWebsite: string;
  sourceSameAs: string;
  trackCount: string;
  playlistCount: string;
  soundCloudFollowers: string;
  soundCloudFavorites: string;
  followersCount: number | null;
  city: string;
  existingDJId: string | null;
  existingDJName: string | null;
  existingMatchType: string | null;
  raw: Record<string, unknown>;
};

export type DJStudioSourceFieldKey =
  | 'name'
  | 'aliases'
  | 'genres'
  | 'bio'
  | 'country'
  | 'countryEnFull'
  | 'website'
  | 'spotifyUrl'
  | 'spotifyId'
  | 'spotifyFollowers'
  | 'appleMusicId'
  | 'instagramUrl'
  | 'facebookUrl'
  | 'twitterUrl'
  | 'youtubeUrl'
  | 'soundcloudUrl'
  | 'soundcloudId'
  | 'neteaseUrl'
  | 'qqMusicUrl'
  | 'sourceWikipedia'
  | 'sourceWebsite'
  | 'sourceSameAs'
  | 'trackCount'
  | 'playlistCount'
  | 'soundCloudFollowers'
  | 'soundCloudFavorites';

export type DJStudioGenreBinding = {
  genreId: string;
  label: string;
  displayName?: string | null;
  path?: string | null;
};

export type DJStudioDraft = {
  id: string;
  name: DJStudioLocalizedText;
  aliases: string[];
  genres: string[];
  genreBindings: DJStudioGenreBinding[];
  bio: DJStudioLocalizedText;
  country: DJStudioLocalizedText;
  avatarImage: DJStudioImageState | null;
  bannerImage: DJStudioImageState | null;
  proofImage: DJStudioImageState | null;
  sourceWikipedia: string;
  sourceWebsite: string;
  sourceSameAs: string[];
  spotifyId: string;
  spotifyUrl: string;
  spotifyFollowers: string;
  appleMusicId: string;
  instagramUrl: string;
  facebookUrl: string;
  soundcloudUrl: string;
  soundcloudId: string;
  twitterUrl: string;
  youtubeUrl: string;
  neteaseUrl: string;
  qqMusicUrl: string;
  website: string;
  otherPlatformUrl: string;
  trackCount: string;
  playlistCount: string;
  soundCloudFollowers: string;
  soundCloudFavorites: string;
};

export type DJStudioValidationErrors = Partial<Record<
  'name' | 'avatarImage' | 'links' | 'stats',
  string
>>;

export type DJStudioSubmissionSummary = {
  id: string;
  entityType: string;
  status: string;
  title: string;
  createdEntityId?: string | null;
};

export type DJStudioSubmissionAcceptedPayload = {
  status?: EventDerivedStatus | null;
  message: string;
  submission: DJStudioSubmissionSummary;
};

export type DJStudioCreatedDJ = {
  id: string;
  name: string;
  slug?: string | null;
  avatarUrl?: string | null;
  country?: string | null;
};

export type DJStudioCreateResult =
  | { kind: 'created'; dj: DJStudioCreatedDJ }
  | { kind: 'submitted'; payload: DJStudioSubmissionAcceptedPayload };

export type DJStudioLoadedDJ = {
  id: string;
  name: string;
  nameI18n?: DJStudioLocalizedText | null;
  aliases?: string[] | null;
  genres?: string[] | null;
  genreBindings?: DJStudioGenreBinding[] | null;
  slug?: string | null;
  bio?: string | null;
  bioI18n?: DJStudioLocalizedText | null;
  avatarUrl?: string | null;
  avatarSourceUrl?: string | null;
  bannerUrl?: string | null;
  country?: string | null;
  countryI18n?: DJStudioLocalizedText | null;
  spotifyId?: string | null;
  spotifyUrl?: string | null;
  spotifyFollowers?: number | null;
  appleMusicId?: string | null;
  soundcloudUrl?: string | null;
  soundcloudId?: string | null;
  instagramUrl?: string | null;
  facebookUrl?: string | null;
  twitterUrl?: string | null;
  youtubeUrl?: string | null;
  neteaseUrl?: string | null;
  qqMusicUrl?: string | null;
  website?: string | null;
  otherPlatformUrl?: string | null;
  sourceWikipedia?: string | null;
  sourceWebsite?: string | null;
  sourceSameAs?: string[] | null;
  isVerified?: boolean | null;
  trackCount?: number | null;
  playlistCount?: number | null;
  soundCloudFollowers?: number | null;
  soundCloudFavorites?: number | null;
  canEdit?: boolean | null;
  viewerWatchedCount?: number | null;
  contributors?: Array<{ id: string; username?: string | null; displayName?: string | null; avatarUrl?: string | null }> | null;
  contributorUsernames?: string[] | null;
  honorsJson?: unknown;
};

export type DJStudioPagination = {
  page: number;
  limit: number;
  total: number;
  totalPages: number;
};

export type DJStudioRelatedPage<T> = {
  items: T[];
  pagination: DJStudioPagination;
};

export type DJStudioRelatedSet = {
  id: string;
  djId?: string | null;
  title: string;
  description?: string | null;
  thumbnailUrl?: string | null;
  videoUrl?: string | null;
  platform?: string | null;
  duration?: number | string | null;
  recordedAt?: string | null;
  venue?: string | null;
  eventId?: string | null;
  eventName?: string | null;
  viewCount?: number | null;
  likeCount?: number | null;
  isVerified?: boolean | null;
  createdAt?: string | null;
  updatedAt?: string | null;
  trackCount?: number | null;
  tracks?: unknown[];
};

export type DJStudioRelatedEvent = {
  id: string;
  name: string;
  slug?: string | null;
  city?: string | null;
  country?: string | null;
  coverImageUrl?: string | null;
  imageUrl?: string | null;
  eventType?: string | null;
  status?: string | null;
  startDate?: string | null;
  endDate?: string | null;
  timeZone?: string | null;
  organizer?: {
    id?: string | null;
    username?: string | null;
    displayName?: string | null;
    avatarUrl?: string | null;
  } | null;
};

export type DJStudioRatingUnit = {
  id: string;
  eventId?: string | null;
  djId?: string | null;
  djIds?: string[];
  name: string;
  description?: string | null;
  imageUrl?: string | null;
  rating?: number | null;
  ratingCount?: number | null;
  createdAt?: string | null;
  updatedAt?: string | null;
  linkedDJs?: Array<{ id: string; name: string; avatarUrl?: string | null; bannerUrl?: string | null; country?: string | null }>;
  event?: {
    id: string;
    name?: string | null;
    description?: string | null;
    imageUrl?: string | null;
  } | null;
  createdBy?: {
    id: string;
    username?: string | null;
    displayName?: string | null;
    avatarUrl?: string | null;
  } | null;
};

export type DJStudioRelatedArticle = {
  id: string;
  category?: string | null;
  source?: string | null;
  title: string;
  summary?: string | null;
  body?: string | null;
  link?: string | null;
  coverImageURL?: string | null;
  coverImageUrl?: string | null;
  publishedAt?: string | null;
  author?: {
    id?: string | null;
    username?: string | null;
    displayName?: string | null;
    avatarUrl?: string | null;
  } | null;
};

export type DJStudioRelatedArticlePage = {
  items: DJStudioRelatedArticle[];
  nextCursor: string | null;
};

export type DJStudioCreateInput = {
  name: string;
  nameI18n?: DJStudioLocalizedText | null;
  spotifyId?: string | null;
  aliases?: string[] | null;
  genres?: string[] | null;
  genreBindings?: DJStudioGenreBinding[] | null;
  bio?: string | null;
  bioI18n?: DJStudioLocalizedText | null;
  country?: string | null;
  countryI18n?: DJStudioLocalizedText | null;
  avatarUrl?: string | null;
  bannerUrl?: string | null;
  proofImageUrl?: string | null;
  spotifyUrl?: string | null;
  spotifyFollowers?: number | null;
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
  otherPlatformUrl?: string | null;
  sourceWikipedia?: string | null;
  sourceWebsite?: string | null;
  sourceSameAs?: string[] | string | null;
  trackCount?: number | null;
  playlistCount?: number | null;
  soundCloudFollowers?: number | null;
  soundCloudFavorites?: number | null;
  isVerified?: boolean | null;
};

export type DJStudioUpdateInput = {
  name?: string | null;
  nameI18n?: DJStudioLocalizedText | null;
  aliases?: string[] | null;
  genres?: string[] | null;
  genreBindings?: DJStudioGenreBinding[] | null;
  bio?: string | null;
  bioI18n?: DJStudioLocalizedText | null;
  avatarUrl?: string | null;
  bannerUrl?: string | null;
  proofImageUrl?: string | null;
  country?: string | null;
  countryI18n?: DJStudioLocalizedText | null;
  spotifyId?: string | null;
  appleMusicId?: string | null;
  spotifyUrl?: string | null;
  spotifyFollowers?: number | null;
  instagramUrl?: string | null;
  facebookUrl?: string | null;
  soundcloudUrl?: string | null;
  soundcloudId?: string | null;
  twitterUrl?: string | null;
  youtubeUrl?: string | null;
  neteaseUrl?: string | null;
  qqMusicUrl?: string | null;
  website?: string | null;
  otherPlatformUrl?: string | null;
  sourceWikipedia?: string | null;
  sourceWebsite?: string | null;
  sourceSameAs?: string[] | string | null;
  trackCount?: number | null;
  playlistCount?: number | null;
  soundCloudFollowers?: number | null;
  soundCloudFavorites?: number | null;
  isVerified?: boolean | null;
};
