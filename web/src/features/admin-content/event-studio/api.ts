import { authenticatedFetch, authenticatedJsonFetch } from '@/lib/auth/authenticated-fetch';
import { getApiUrl } from '@/lib/config';
import {
  EventStudioAlignmentPreview,
  EventStudioApiErrorCode,
  EventStudioApiErrorDetails,
  EventStudioCreateInput,
  EventStudioCreateResult,
  EventStudioLoadedEvent,
  EventStudioOrganizer,
  EventStudioSubmissionAcceptedPayload,
  EventStudioTimezoneLookupItem,
  EventStudioUpdateInput,
} from './types';

type UploadImageResponse = {
  url: string;
};

type EventStudioApiErrorPayload = {
  error?: string;
  message?: string;
  code?: EventStudioApiErrorCode;
  details?: EventStudioApiErrorDetails;
};

export class EventStudioApiError extends Error {
  readonly code?: EventStudioApiErrorCode;
  readonly details?: EventStudioApiErrorDetails;
  readonly status: number;

  constructor(message: string, status: number, code?: EventStudioApiErrorCode, details?: EventStudioApiErrorDetails) {
    super(message);
    this.name = 'EventStudioApiError';
    this.status = status;
    this.code = code;
    this.details = details;
  }
}

const isSubmissionPayload = (value: unknown): value is EventStudioSubmissionAcceptedPayload => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return false;
  const row = value as Record<string, unknown>;
  return typeof row.message === 'string' && !!row.submission && typeof row.submission === 'object';
};

export const eventStudioApi = {
  async searchTimezones(query: string): Promise<EventStudioTimezoneLookupItem[]> {
    const search = new URLSearchParams({
      q: query.trim(),
      limit: '8',
    });
    const response = await authenticatedJsonFetch<{ items?: EventStudioTimezoneLookupItem[] }>(
      getApiUrl(`/v1/event-timezones/search?${search.toString()}`)
    );
    return Array.isArray(response.items) ? response.items : [];
  },

  async searchOrganizers(query: string): Promise<EventStudioOrganizer[]> {
    const search = new URLSearchParams({
      search: query.trim(),
      limit: '8',
    });
    const response = await authenticatedJsonFetch<{ items?: EventStudioOrganizer[] }>(
      getApiUrl(`/v1/learn/festivals?${search.toString()}`)
    );
    return Array.isArray(response.items) ? response.items : [];
  },

  async uploadImage(file: File): Promise<UploadImageResponse> {
    const formData = new FormData();
    formData.append('image', file);

    const response = await authenticatedFetch(getApiUrl('/v1/events/upload-image'), {
      method: 'POST',
      body: formData,
      headers: {},
    });

    if (!response.ok) {
      const error = await response.json().catch(() => ({}));
      throw new Error(error?.error || '图片上传失败');
    }

    return response.json();
  },

  async createEvent(input: EventStudioCreateInput): Promise<EventStudioCreateResult> {
    const response = await authenticatedFetch(getApiUrl('/v1/events'), {
      method: 'POST',
      body: JSON.stringify(input),
    });
    if (!response.ok) {
      const error = (await response.json().catch(() => ({}))) as EventStudioApiErrorPayload;
      throw new EventStudioApiError(
        error.error || error.message || '活动提交失败',
        response.status,
        error.code,
        error.details
      );
    }
    const payload = await response.json();

    if (isSubmissionPayload(payload)) {
      return { kind: 'submitted', payload };
    }

    const event = payload as {
      id: string;
      name: string;
      slug: string;
      organizerName?: string | null;
      city?: string | null;
      country?: string | null;
      startDate: string;
      endDate: string;
      status?: string | null;
    };
    return { kind: 'created', event };
  },

  async updateEvent(id: string, input: EventStudioUpdateInput): Promise<EventStudioCreateResult> {
    const response = await authenticatedFetch(getApiUrl(`/v1/events/${id}`), {
      method: 'PATCH',
      body: JSON.stringify(input),
    });
    if (!response.ok) {
      const error = (await response.json().catch(() => ({}))) as EventStudioApiErrorPayload;
      throw new EventStudioApiError(
        error.error || error.message || '活动提交失败',
        response.status,
        error.code,
        error.details
      );
    }
    const payload = await response.json();

    if (isSubmissionPayload(payload)) {
      return { kind: 'submitted', payload };
    }

    const event = payload as {
      id: string;
      name: string;
      slug: string;
      organizerName?: string | null;
      city?: string | null;
      country?: string | null;
      startDate: string;
      endDate: string;
      status?: string | null;
    };
    return { kind: 'created', event };
  },

  async fetchEvent(id: string): Promise<EventStudioLoadedEvent> {
    return authenticatedJsonFetch<EventStudioLoadedEvent>(getApiUrl(`/v1/events/${id}`));
  },

  async previewLineupTimetableAlignment(input: EventStudioCreateInput): Promise<EventStudioAlignmentPreview> {
    return authenticatedJsonFetch<EventStudioAlignmentPreview>(
      getApiUrl('/v1/events/lineup-timetable-alignment/preview'),
      {
        method: 'POST',
        body: JSON.stringify(input),
      }
    );
  },
};
