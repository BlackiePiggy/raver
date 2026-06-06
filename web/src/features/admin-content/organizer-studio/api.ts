import { authenticatedFetch, authenticatedJsonFetch } from '@/lib/auth/authenticated-fetch';
import { getApiUrl } from '@/lib/config';
import { uploadMediaWithFetcher } from '@/lib/api/upload-media';
import {
  OrganizerStudioCreateInput,
  OrganizerStudioCreateResult,
  OrganizerStudioEventFeed,
  OrganizerStudioImageUsage,
  OrganizerStudioLoadedOrganizer,
  OrganizerStudioPagination,
  OrganizerStudioRelatedArticle,
  OrganizerStudioRelatedEvent,
  OrganizerStudioRelatedPage,
  OrganizerStudioSubmissionAcceptedPayload,
  OrganizerStudioUpdateInput,
} from './types';

type OrganizerImageUploadResponse = {
  url: string;
  originalUrl?: string | null;
  fileName?: string | null;
};

type BffEnvelope<T> = {
  data?: T;
  pagination?: OrganizerStudioPagination;
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

type OrganizerDeleteImagesInput =
  | {
      draftId: string;
      urls: string[];
    }
  | {
      brandId: string;
      urls: string[];
    };

const isSubmissionPayload = (
  value: unknown
): value is OrganizerStudioSubmissionAcceptedPayload => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return false;
  const row = value as Record<string, unknown>;
  return typeof row.message === 'string' && !!row.submission && typeof row.submission === 'object';
};

const normalizePagination = (
  pagination: OrganizerStudioPagination | undefined,
  fallbackLimit: number
): OrganizerStudioPagination => ({
  page: pagination?.page ?? 1,
  limit: pagination?.limit ?? fallbackLimit,
  total: pagination?.total ?? 0,
  totalPages: pagination?.totalPages ?? 1,
});

export const organizerStudioApi = {
  async uploadImage(
    file: File,
    options: {
      usage: OrganizerStudioImageUsage;
      draftId: string;
      sort?: number;
    }
  ): Promise<OrganizerImageUploadResponse> {
    return uploadMediaWithFetcher({
      url: getApiUrl('/v1/wiki/brands/upload-image'),
      file,
      fields: {
        usage: options.usage,
        draftId: options.draftId,
        sort: typeof options.sort === 'number' ? options.sort : undefined,
      },
      fallbackError: '主办方图片上传失败',
      invalidResponseError: '主办方图片上传成功，但未返回有效图片地址',
    });
  },

  async createOrganizer(input: OrganizerStudioCreateInput): Promise<OrganizerStudioCreateResult> {
    const payload = unwrapBffData(await authenticatedJsonFetch<unknown>(getApiUrl('/v1/learn/festivals'), {
      method: 'POST',
      body: JSON.stringify(input),
    }));

    if (isSubmissionPayload(payload)) {
      return { kind: 'submitted', payload };
    }

    const organizer = payload as {
      id: string;
      name: string;
      city?: string | null;
      country?: string | null;
      revision?: number | null;
    };
    return { kind: 'created', organizer };
  },

  async updateOrganizer(
    id: string,
    input: OrganizerStudioUpdateInput
  ): Promise<OrganizerStudioCreateResult> {
    const payload = unwrapBffData(await authenticatedJsonFetch<unknown>(
      getApiUrl(`/v1/learn/festivals/${id}`),
      {
        method: 'PATCH',
        body: JSON.stringify(input),
      }
    ));

    if (isSubmissionPayload(payload)) {
      return { kind: 'submitted', payload };
    }

    const organizer = payload as {
      id: string;
      name: string;
      city?: string | null;
      country?: string | null;
      revision?: number | null;
    };
    return { kind: 'created', organizer };
  },

  async deleteOrganizer(id: string): Promise<void> {
    await authenticatedJsonFetch<{ success: true }>(
      getApiUrl(`/v1/learn/festivals/${id}`),
      {
        method: 'DELETE',
      }
    );
  },

  async fetchOrganizer(id: string): Promise<OrganizerStudioLoadedOrganizer> {
    return unwrapBffData(
      await authenticatedJsonFetch<
        OrganizerStudioLoadedOrganizer | BffEnvelope<OrganizerStudioLoadedOrganizer>
      >(getApiUrl(`/v1/learn/festivals/${id}`))
    );
  },

  async fetchOrganizerEvents(
    id: string,
    input?: {
      upcomingPage?: number;
      upcomingLimit?: number;
      endedPage?: number;
      endedLimit?: number;
    }
  ): Promise<OrganizerStudioEventFeed> {
    const upcomingLimit = input?.upcomingLimit ?? 10;
    const endedLimit = input?.endedLimit ?? 10;
    const query = new URLSearchParams({
      wikiFestivalId: id,
      upcomingPage: String(input?.upcomingPage ?? 1),
      upcomingLimit: String(upcomingLimit),
      endedPage: String(input?.endedPage ?? 1),
      endedLimit: String(endedLimit),
    });
    const response = await authenticatedJsonFetch<BffEnvelope<{
      upcoming?: { items?: OrganizerStudioRelatedEvent[]; pagination?: OrganizerStudioPagination };
      ended?: { items?: OrganizerStudioRelatedEvent[]; pagination?: OrganizerStudioPagination };
    }>>(
      getApiUrl(`/v1/events/festival-feed?${query.toString()}`)
    );
    return {
      upcoming: {
        items: Array.isArray(response.data?.upcoming?.items) ? response.data.upcoming.items : [],
        pagination: normalizePagination(response.data?.upcoming?.pagination, upcomingLimit),
      },
      ended: {
        items: Array.isArray(response.data?.ended?.items) ? response.data.ended.items : [],
        pagination: normalizePagination(response.data?.ended?.pagination, endedLimit),
      },
    };
  },

  async fetchOrganizerPosts(
    id: string,
    cursor?: string | null,
    limit = 10
  ): Promise<{ items: OrganizerStudioRelatedArticle[]; nextCursor: string | null }> {
    const query = new URLSearchParams({ brandId: id, limit: String(limit) });
    if (cursor) query.set('cursor', cursor);
    const response = await authenticatedJsonFetch<{ items?: OrganizerStudioRelatedArticle[]; nextCursor?: string | null }>(
      getApiUrl(`/v1/news/bound?${query.toString()}`)
    );
    return {
      items: Array.isArray(response.items) ? response.items : [],
      nextCursor: response.nextCursor ?? null,
    };
  },

  async deleteImages(input: OrganizerDeleteImagesInput): Promise<void> {
    await authenticatedJsonFetch<{ success: true }>(
      getApiUrl('/v1/wiki/brands/delete-images'),
      {
        method: 'POST',
        body: JSON.stringify(input),
      }
    );
  },
};
