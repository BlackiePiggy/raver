import { authenticatedFetch, authenticatedJsonFetch } from '@/lib/auth/authenticated-fetch';
import { getApiUrl } from '@/lib/config';
import { uploadMediaWithFetcher } from '@/lib/api/upload-media';
import {
  DJStudioCreateInput,
  DJStudioCreateResult,
  DJStudioSourceCandidate,
  DJStudioImageUsage,
  DJStudioLoadedDJ,
  DJStudioPagination,
  DJStudioRelatedArticlePage,
  DJStudioRelatedEvent,
  DJStudioRelatedPage,
  DJStudioRelatedSet,
  DJStudioRatingUnit,
  DJStudioSubmissionAcceptedPayload,
  DJStudioUpdateInput,
} from './types';

type DJStudioImageUploadResponse = {
  url: string;
  originalUrl?: string | null;
  fileName?: string | null;
};

type BffEnvelope<T> = {
  data?: T;
  pagination?: DJStudioPagination;
  nextCursor?: string | null;
};

const unwrapBffData = <T>(payload: T | BffEnvelope<T>): T => {
  if (payload && typeof payload === 'object' && 'data' in (payload as Record<string, unknown>)) {
    const envelope = payload as BffEnvelope<T>;
    if (envelope.data !== undefined) {
      return envelope.data;
    }
  }
  return payload as T;
};

const isSubmissionPayload = (
  value: unknown
): value is DJStudioSubmissionAcceptedPayload => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return false;
  const row = value as Record<string, unknown>;
  return typeof row.message === 'string' && !!row.submission && typeof row.submission === 'object';
};

const normalizePagination = (
  pagination: DJStudioPagination | undefined,
  fallbackLimit: number
): DJStudioPagination => ({
  page: pagination?.page ?? 1,
  limit: pagination?.limit ?? fallbackLimit,
  total: pagination?.total ?? 0,
  totalPages: pagination?.totalPages ?? 1,
});

const unwrapPagedResponse = <T>(
  response: BffEnvelope<{ items?: T[] }>,
  fallbackLimit: number
): DJStudioRelatedPage<T> => ({
  items: Array.isArray(response.data?.items) ? response.data.items : [],
  pagination: normalizePagination(response.pagination, fallbackLimit),
});

const normalizeString = (value: unknown): string => (typeof value === 'string' ? value.trim() : '');

const normalizeStringList = (value: unknown): string[] => {
  if (Array.isArray(value)) {
    return value.map((item) => normalizeString(item)).filter(Boolean);
  }
  const text = normalizeString(value);
  return text
    ? text
        .split(/[\n,]/)
        .map((item) => item.trim())
        .filter(Boolean)
    : [];
};

const normalizeCountString = (value: unknown): string => {
  if (typeof value === 'number' && Number.isFinite(value)) return String(Math.floor(value));
  const text = normalizeString(value);
  return /^\d+$/.test(text) ? text : '';
};

const normalizeSourceCandidate = (
  source: DJStudioSourceCandidate['source'],
  payload: unknown
): DJStudioSourceCandidate => {
  const row = payload && typeof payload === 'object' && !Array.isArray(payload)
    ? (payload as Record<string, unknown>)
    : {};

  const rawUrls = Array.isArray(row.urls) ? row.urls.map((item) => normalizeString(item)).filter(Boolean) : [];
  const sourceSameAs = rawUrls.join('\n');
  const city = normalizeString(row.city);
  const country = normalizeString(row.country);

  return {
    source,
    name: normalizeString(row.name),
    avatarUrl:
      normalizeString(row.imageUrl) ||
      normalizeString(row.avatarUrl) ||
      normalizeString(row.primaryImageUrl) ||
      normalizeString(row.thumbnailImageUrl) ||
      normalizeString(row.thumbUrl) ||
      normalizeString(row.coverImageUrl) ||
      null,
    aliases: normalizeStringList(
      source === 'discogs'
        ? [...normalizeStringList(row.aliases), ...normalizeStringList(row.nameVariations), ...normalizeStringList(row.groups)]
        : row.aliases
    ),
    genres: normalizeStringList(row.genres),
    bio:
      normalizeString(row.profile) ||
      normalizeString(row.description) ||
      normalizeString(row.bio),
    country,
    countryEnFull: country,
    website:
      normalizeString(row.website) ||
      normalizeString(row.resourceUrl),
    spotifyUrl: normalizeString(row.spotifyUrl),
    spotifyId: normalizeString(row.spotifyId),
    spotifyFollowers: normalizeCountString(row.spotifyFollowers ?? row.followers),
    appleMusicId: normalizeString(row.appleMusicId),
    instagramUrl: normalizeString(row.instagramUrl),
    facebookUrl: normalizeString(row.facebookUrl),
    twitterUrl: normalizeString(row.twitterUrl),
    youtubeUrl: normalizeString(row.youtubeUrl),
    soundcloudUrl:
      normalizeString(row.soundcloudUrl) ||
      normalizeString(row.permalinkUrl),
    soundcloudId:
      normalizeString(row.soundcloudId) ||
      normalizeString(row.soundCloudId) ||
      normalizeString(row.soundcloudid),
    neteaseUrl: normalizeString(row.neteaseUrl),
    qqMusicUrl: normalizeString(row.qqMusicUrl),
    sourceWikipedia: normalizeString(row.wikipediaUrl),
    sourceWebsite:
      normalizeString(row.resourceUrl) ||
      normalizeString(row.uri),
    sourceSameAs,
    trackCount: normalizeCountString(row.trackCount ?? row.track_count),
    playlistCount: normalizeCountString(row.playlistCount ?? row.playlist_count),
    soundCloudFollowers: normalizeCountString(row.soundCloudFollowers ?? row.followersCount ?? row.followers_count),
    soundCloudFavorites: normalizeCountString(row.soundCloudFavorites ?? row.publicFavoritesCount ?? row.public_favorites_count),
    followersCount:
      typeof row.followersCount === 'number' && Number.isFinite(row.followersCount)
        ? row.followersCount
        : typeof row.followers_count === 'number' && Number.isFinite(row.followers_count)
          ? row.followers_count
          : typeof row.followers === 'number' && Number.isFinite(row.followers)
            ? row.followers
            : null,
    city,
    existingDJId: normalizeString(row.existingDJId) || null,
    existingDJName: normalizeString(row.existingDJName) || null,
    existingMatchType: normalizeString(row.existingMatchType) || null,
    raw: row,
  };
};

export const djStudioApi = {
  async uploadImage(
    file: File,
    options: {
      usage: DJStudioImageUsage;
      draftId: string;
    }
  ): Promise<DJStudioImageUploadResponse> {
    return uploadMediaWithFetcher({
      url: getApiUrl('/v1/djs/upload-image'),
      file,
      fields: {
        usage: options.usage,
        draftId: options.draftId,
      },
      fallbackError: 'DJ 图片上传失败',
      invalidResponseError: 'DJ 图片上传成功，但未返回有效图片地址',
    });
  },

  async deleteDraftImages(input: {
    draftId: string;
    urls: string[];
  }): Promise<void> {
    await authenticatedJsonFetch<{ success: true }>(
      getApiUrl('/v1/djs/delete-images'),
      {
        method: 'POST',
        body: JSON.stringify(input),
      }
    );
  },

  async createDJ(input: DJStudioCreateInput): Promise<DJStudioCreateResult> {
    const payload = unwrapBffData(await authenticatedJsonFetch<unknown>(getApiUrl('/v1/djs/manual/import'), {
      method: 'POST',
      body: JSON.stringify(input),
    }));

    if (isSubmissionPayload(payload)) {
      return { kind: 'submitted', payload };
    }

    const row = payload as {
      action: string;
      dj: {
        id: string;
        name: string;
        slug?: string | null;
        avatarUrl?: string | null;
        country?: string | null;
      };
    };
    return {
      kind: 'created',
      dj: row.dj,
    };
  },

  async updateDJ(id: string, input: DJStudioUpdateInput): Promise<DJStudioCreateResult> {
    const payload = unwrapBffData(await authenticatedJsonFetch<unknown>(getApiUrl(`/v1/djs/${id}`), {
      method: 'PATCH',
      body: JSON.stringify(input),
    }));

    if (isSubmissionPayload(payload)) {
      return { kind: 'submitted', payload };
    }

    const row = payload as {
      id: string;
      name: string;
      slug?: string | null;
      avatarUrl?: string | null;
      country?: string | null;
    };
    return {
      kind: 'created',
      dj: row,
    };
  },

  async deleteDJ(id: string): Promise<void> {
    await authenticatedJsonFetch<{ success: true }>(getApiUrl(`/v1/djs/${id}`), {
      method: 'DELETE',
    });
  },

  async fetchDJ(id: string): Promise<DJStudioLoadedDJ> {
    return unwrapBffData(
      await authenticatedJsonFetch<DJStudioLoadedDJ | BffEnvelope<DJStudioLoadedDJ>>(getApiUrl(`/v1/djs/${id}`))
    );
  },

  async searchSpotifyCandidates(query: string): Promise<DJStudioSourceCandidate[]> {
    const response = await authenticatedJsonFetch<BffEnvelope<{ items?: unknown[] }>>(
      `/api/raver/djs/spotify/search?q=${encodeURIComponent(query)}&limit=8`
    );
    return Array.isArray(response.data?.items)
      ? response.data.items.map((item) => normalizeSourceCandidate('spotify', item))
      : [];
  },

  async searchDiscogsCandidates(query: string): Promise<DJStudioSourceCandidate[]> {
    const response = await authenticatedJsonFetch<BffEnvelope<{ items?: unknown[] }>>(
      `/api/raver/djs/discogs/search?q=${encodeURIComponent(query)}&limit=8`
    );
    const items = Array.isArray(response.data?.items) ? response.data.items : [];
    const enriched = await Promise.all(
      items.map(async (item) => {
        const row = item && typeof item === 'object' && !Array.isArray(item)
          ? (item as Record<string, unknown>)
          : {};
        const artistId = Number(row.artistId);
        if (!Number.isFinite(artistId) || artistId <= 0) return row;
        try {
          const detail = await authenticatedJsonFetch<BffEnvelope<unknown>>(
            `/api/raver/djs/discogs/artists/${encodeURIComponent(String(Math.floor(artistId)))}`
          );
          return {
            ...row,
            ...(detail.data && typeof detail.data === 'object' && !Array.isArray(detail.data) ? detail.data as Record<string, unknown> : {}),
          };
        } catch {
          return row;
        }
      })
    );
    return enriched.map((item) => normalizeSourceCandidate('discogs', item));
  },

  async searchSoundCloudCandidates(query: string): Promise<DJStudioSourceCandidate[]> {
    const response = await authenticatedJsonFetch<BffEnvelope<{ items?: unknown[] }>>(
      `/api/raver/djs/soundcloud/search?q=${encodeURIComponent(query)}&limit=20`
    );
    const items = Array.isArray(response.data?.items)
      ? response.data.items.map((item) => normalizeSourceCandidate('soundcloud', item))
      : [];
    return items.sort((left, right) => {
      const rightFollowers = right.followersCount ?? 0;
      const leftFollowers = left.followersCount ?? 0;
      if (rightFollowers !== leftFollowers) return rightFollowers - leftFollowers;
      return left.name.localeCompare(right.name, 'en', { sensitivity: 'base' });
    }).slice(0, 8);
  },

  async fetchDJSets(
    id: string,
    page = 1,
    limit = 10
  ): Promise<DJStudioRelatedPage<DJStudioRelatedSet>> {
    const response = await authenticatedJsonFetch<BffEnvelope<{ items?: DJStudioRelatedSet[] }>>(
      getApiUrl(`/v1/djs/${id}/sets?page=${page}&limit=${limit}`)
    );
    return unwrapPagedResponse<DJStudioRelatedSet>(response, limit);
  },

  async fetchDJEvents(
    id: string,
    page = 1,
    limit = 8,
    statuses?: string[]
  ): Promise<DJStudioRelatedPage<DJStudioRelatedEvent>> {
    const query = new URLSearchParams({
      page: String(page),
      limit: String(limit),
    });
    if (statuses?.length) {
      query.set('statuses', statuses.join(','));
    }
    const response = await authenticatedJsonFetch<BffEnvelope<{ items?: DJStudioRelatedEvent[] }>>(
      getApiUrl(`/v1/djs/${id}/events?${query.toString()}`)
    );
    return unwrapPagedResponse<DJStudioRelatedEvent>(response, limit);
  },

  async fetchDJRatingUnits(
    id: string,
    page = 1,
    limit = 10
  ): Promise<DJStudioRelatedPage<DJStudioRatingUnit>> {
    const response = await authenticatedJsonFetch<BffEnvelope<{ items?: DJStudioRatingUnit[] }>>(
      getApiUrl(`/v1/djs/${id}/rating-units?page=${page}&limit=${limit}`)
    );
    return unwrapPagedResponse<DJStudioRatingUnit>(response, limit);
  },

  async fetchDJRelatedArticles(
    id: string,
    cursor?: string | null,
    limit = 10
  ): Promise<DJStudioRelatedArticlePage> {
    const query = new URLSearchParams({ djId: id, limit: String(limit) });
    if (cursor) query.set('cursor', cursor);
    return authenticatedJsonFetch<DJStudioRelatedArticlePage>(getApiUrl(`/v1/news/bound?${query.toString()}`));
  },
};
