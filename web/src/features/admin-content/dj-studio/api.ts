import { authenticatedFetch, authenticatedJsonFetch } from '@/lib/auth/authenticated-fetch';
import { getApiUrl } from '@/lib/config';
import {
  DJStudioCreateInput,
  DJStudioCreateResult,
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

export const djStudioApi = {
  async uploadImage(
    file: File,
    options: {
      usage: DJStudioImageUsage;
      draftId: string;
    }
  ): Promise<DJStudioImageUploadResponse> {
    const formData = new FormData();
    formData.append('image', file);
    formData.append('usage', options.usage);
    formData.append('draftId', options.draftId);

    const response = await authenticatedFetch(getApiUrl('/v1/djs/upload-image'), {
      method: 'POST',
      body: formData,
      headers: {},
    });

    if (!response.ok) {
      const error = await response.json().catch(() => ({}));
      throw new Error(error?.error || 'DJ 图片上传失败');
    }

    return response.json();
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
