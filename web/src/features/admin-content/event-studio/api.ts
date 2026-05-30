import { authenticatedFetch, authenticatedJsonFetch } from '@/lib/auth/authenticated-fetch';
import { getApiUrl } from '@/lib/config';
import type { components as EventContractComponents } from '../../../../../contracts/generated/web/event-admin';
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

type EventContractSchemas = EventContractComponents['schemas'];

type UploadImageResponse = {
  url: string;
  fileName?: string | null;
};

type EventStudioApiErrorPayload = {
  error?: string;
  message?: string;
  code?: EventStudioApiErrorCode;
  details?: EventStudioApiErrorDetails;
};

type EventEnvelope = EventContractSchemas['EventEnvelope'];
type EventDetailEnvelope = EventContractSchemas['EventDetailEnvelope'];
type EventSubmissionAcceptedEnvelope = EventContractSchemas['EventSubmissionAcceptedEnvelope'];
type EventAlignmentPreviewEnvelope = EventContractSchemas['EventAlignmentPreviewEnvelope'];

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

const unwrapDataEnvelope = <T>(payload: unknown): T => {
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
    throw new Error('接口返回格式不匹配，请检查 Web BFF 契约');
  }

  const row = payload as { data?: T };
  if (row.data === undefined) {
    throw new Error('接口返回格式不匹配，请检查 Web BFF 契约');
  }

  return row.data;
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

  async uploadImage(
    file: File,
    options: {
      usage: 'cover' | 'lineup';
      draftId: string;
    }
  ): Promise<UploadImageResponse> {
    const formData = new FormData();
    formData.append('image', file);
    formData.append('usage', options.usage);
    formData.append('draftId', options.draftId);

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

  async deleteDraftImages(input: { draftId: string; urls: string[] }): Promise<void> {
    await authenticatedJsonFetch<{ success: true }>(getApiUrl('/v1/events/delete-images'), {
      method: 'POST',
      body: JSON.stringify(input),
    });
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
    const data = unwrapDataEnvelope<EventEnvelope['data'] | EventSubmissionAcceptedEnvelope['data']>(payload);

    if (isSubmissionPayload(data)) {
      return { kind: 'submitted', payload: data };
    }

    return { kind: 'created', event: data };
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
    const data = unwrapDataEnvelope<EventEnvelope['data'] | EventSubmissionAcceptedEnvelope['data']>(payload);

    if (isSubmissionPayload(data)) {
      return { kind: 'submitted', payload: data };
    }

    return { kind: 'created', event: data };
  },

  async fetchEvent(id: string): Promise<EventStudioLoadedEvent> {
    const payload = await authenticatedJsonFetch<EventDetailEnvelope>(getApiUrl(`/v1/events/${id}`));
    return payload.data;
  },

  async previewLineupTimetableAlignment(input: EventStudioCreateInput): Promise<EventStudioAlignmentPreview> {
    const payload = await authenticatedJsonFetch<EventAlignmentPreviewEnvelope>(
      getApiUrl('/v1/events/lineup-timetable-alignment/preview'),
      {
        method: 'POST',
        body: JSON.stringify(input),
      }
    );
    return payload.data;
  },
};
