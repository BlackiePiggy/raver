import { authenticatedFetch, authenticatedJsonFetch } from '@/lib/auth/authenticated-fetch';
import { getApiUrl } from '@/lib/config';
import { uploadMediaWithFetcher } from '@/lib/api/upload-media';

export type RatingUnit = {
  id: string;
  eventId?: string;
  djId?: string | null;
  djIds?: string[];
  name: string;
  description?: string | null;
  imageUrl?: string | null;
  createdAt?: string;
  updatedAt?: string;
  linkedDJs?: Array<{
    id: string;
    name: string;
    avatarUrl?: string | null;
    bannerUrl?: string | null;
    country?: string | null;
  }>;
  averageScore?: number | null;
  commentCount?: number;
};

export type RatingEvent = {
  id: string;
  sourceEventId?: string | null;
  name: string;
  description?: string | null;
  imageUrl?: string | null;
  createdAt?: string;
  updatedAt?: string;
  units: RatingUnit[];
};

export type RatingEventListResponse = {
  items: RatingEvent[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
};

type Envelope<T> = {
  data: T;
  pagination?: RatingEventListResponse['pagination'];
};

export const ratingAdminApi = {
  async listEvents(page = 1, limit = 20): Promise<RatingEventListResponse> {
    const payload = await authenticatedJsonFetch<Envelope<{ items: RatingEvent[] }>>(
      getApiUrl(`/v1/rating-events?page=${encodeURIComponent(String(page))}&limit=${encodeURIComponent(String(limit))}`)
    );
    return {
      items: payload.data.items,
      pagination: payload.pagination ?? { page, limit, total: payload.data.items.length, totalPages: 1 },
    };
  },

  async fetchEvent(id: string): Promise<RatingEvent> {
    const payload = await authenticatedJsonFetch<Envelope<RatingEvent>>(getApiUrl(`/v1/rating-events/${encodeURIComponent(id)}`));
    return payload.data;
  },

  async createEvent(input: {
    name: string;
    description?: string;
    imageUrl?: string | null;
    sourceEventId?: string | null;
  }): Promise<RatingEvent> {
    const payload = await authenticatedJsonFetch<Envelope<RatingEvent>>(getApiUrl('/v1/rating-events'), {
      method: 'POST',
      body: JSON.stringify(input),
    });
    return payload.data;
  },

  async createEventFromEvent(eventId: string): Promise<RatingEvent> {
    const payload = await authenticatedJsonFetch<Envelope<RatingEvent>>(getApiUrl('/v1/rating-events/from-event'), {
      method: 'POST',
      body: JSON.stringify({ eventId }),
    });
    return payload.data;
  },

  async updateEvent(id: string, input: {
    name?: string;
    description?: string | null;
    imageUrl?: string | null;
    sourceEventId?: string | null;
  }): Promise<RatingEvent> {
    const payload = await authenticatedJsonFetch<Envelope<RatingEvent>>(getApiUrl(`/v1/rating-events/${encodeURIComponent(id)}`), {
      method: 'PATCH',
      body: JSON.stringify(input),
    });
    return payload.data;
  },

  async deleteEvent(id: string): Promise<void> {
    await authenticatedJsonFetch<Envelope<{ success: true }>>(getApiUrl(`/v1/rating-events/${encodeURIComponent(id)}`), {
      method: 'DELETE',
    });
  },

  async createUnit(eventId: string, input: {
    name: string;
    description?: string;
    imageUrl?: string | null;
    djId?: string | null;
    djIds?: string[];
  }): Promise<RatingUnit> {
    const payload = await authenticatedJsonFetch<Envelope<RatingUnit>>(getApiUrl(`/v1/rating-events/${encodeURIComponent(eventId)}/units`), {
      method: 'POST',
      body: JSON.stringify(input),
    });
    return payload.data;
  },

  async fetchUnit(id: string): Promise<RatingUnit & { event?: Record<string, unknown> }> {
    const payload = await authenticatedJsonFetch<Envelope<RatingUnit & { event?: Record<string, unknown> }>>(
      getApiUrl(`/v1/rating-units/${encodeURIComponent(id)}`)
    );
    return payload.data;
  },

  async updateUnit(id: string, input: {
    name?: string;
    description?: string | null;
    imageUrl?: string | null;
    djId?: string | null;
    djIds?: string[];
  }): Promise<RatingUnit> {
    const payload = await authenticatedJsonFetch<Envelope<RatingUnit>>(getApiUrl(`/v1/rating-units/${encodeURIComponent(id)}`), {
      method: 'PATCH',
      body: JSON.stringify(input),
    });
    return payload.data;
  },

  async deleteUnit(id: string): Promise<void> {
    await authenticatedJsonFetch<Envelope<{ success: true }>>(getApiUrl(`/v1/rating-units/${encodeURIComponent(id)}`), {
      method: 'DELETE',
    });
  },

  async uploadImage(file: File, options?: { ratingEventId?: string; ratingUnitId?: string; usage?: string }): Promise<{ url: string }> {
    return uploadMediaWithFetcher({
      url: getApiUrl('/v1/rating/upload-image'),
      file,
      fields: {
        ratingEventId: options?.ratingEventId,
        ratingUnitId: options?.ratingUnitId,
        usage: options?.usage,
      },
      fallbackError: '打分图片上传失败',
      invalidResponseError: '打分图片上传成功，但未返回有效图片地址',
    });
  },
};
