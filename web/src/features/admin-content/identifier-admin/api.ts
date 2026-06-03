import { authenticatedJsonFetch } from '@/lib/auth/authenticated-fetch';
import { getApiUrl } from '@/lib/config';

export type UnreleasedTrackSourceType = 'default_track' | 'tracklist_track';

export type UnreleasedTrackItem = {
  rowId: string;
  sourceType: UnreleasedTrackSourceType;
  setId: string;
  setTitle: string;
  setSlug: string;
  setRecordedAt: string | null;
  djDisplayName: string;
  tracklistId: string | null;
  tracklistTitle: string | null;
  contributorName: string | null;
  position: number;
  startTime: number;
  endTime: number | null;
  title: string;
  artist: string;
  status: 'released' | 'id' | 'remix' | 'edit';
  label: string | null;
  releaseYear: number | null;
  spotifyUrl: string | null;
  spotifyId: string | null;
  spotifyUri: string | null;
  appleMusicUrl: string | null;
  youtubeMusicUrl: string | null;
  soundcloudUrl: string | null;
  beatportUrl: string | null;
  neteaseUrl: string | null;
  neteaseId: string | null;
  createdAt: string;
  updatedAt: string;
};

export type UnreleasedTrackListResponse = {
  items: UnreleasedTrackItem[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
};

export type UnreleasedTrackUpdateInput = Partial<
  Pick<
    UnreleasedTrackItem,
    | 'title'
    | 'artist'
    | 'status'
    | 'label'
    | 'releaseYear'
    | 'spotifyUrl'
    | 'spotifyId'
    | 'spotifyUri'
    | 'appleMusicUrl'
    | 'youtubeMusicUrl'
    | 'soundcloudUrl'
    | 'beatportUrl'
    | 'neteaseUrl'
    | 'neteaseId'
  >
>;

type Envelope<T> = {
  data: T;
  pagination?: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
};

export const identifierAdminApi = {
  async listUnreleasedTracks(input: {
    search?: string;
    sourceType?: 'all' | UnreleasedTrackSourceType;
    page?: number;
    limit?: number;
  }): Promise<UnreleasedTrackListResponse> {
    const query = new URLSearchParams({
      search: input.search?.trim() || '',
      sourceType: input.sourceType || 'all',
      page: String(input.page || 1),
      limit: String(input.limit || 20),
    });

    const payload = await authenticatedJsonFetch<Envelope<{ items: UnreleasedTrackItem[] }>>(
      getApiUrl(`/v1/admin/identifiers/unreleased-tracks?${query.toString()}`)
    );

    return {
      items: payload.data.items,
      pagination: payload.pagination ?? {
        page: input.page || 1,
        limit: input.limit || 20,
        total: payload.data.items.length,
        totalPages: 1,
      },
    };
  },

  async updateUnreleasedTrack(rowId: string, input: UnreleasedTrackUpdateInput): Promise<UnreleasedTrackItem> {
    const payload = await authenticatedJsonFetch<Envelope<UnreleasedTrackItem>>(
      getApiUrl(`/v1/admin/identifiers/unreleased-tracks/${encodeURIComponent(rowId)}`),
      {
        method: 'PATCH',
        body: JSON.stringify(input),
      }
    );
    return payload.data;
  },
};
