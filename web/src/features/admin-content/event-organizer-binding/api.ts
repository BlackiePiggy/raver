import { authenticatedJsonFetch } from '@/lib/auth/authenticated-fetch';
import { getApiUrl } from '@/lib/config';
import type { EventDerivedStatus, EventVisibility, EventStatusFilter } from '@/lib/api/event';
import {
  eventStudioApi,
  hydrateEventStudioDraftFromEvent,
  mapEventStudioDraftToUpdateInput,
} from '@/features/admin-content/event-studio';
import { EventStudioOrganizer } from '@/features/admin-content/event-studio/types';

export type EventOrganizerBindingCatalogItem = {
  id: string;
  name: string;
  slug?: string | null;
  coverImageUrl?: string | null;
  organizerName?: string | null;
  city?: string | null;
  country?: string | null;
  eventType?: string | null;
  status?: EventDerivedStatus | null;
  isCancelled?: boolean | null;
  visibility?: EventVisibility | null;
  wikiFestivalId?: string | null;
  startDate: string;
  endDate: string;
  updatedAt: string;
  wikiFestival?: {
    id: string;
    name?: string | null;
  } | null;
};

export type EventOrganizerBindingListResponse = {
  items: EventOrganizerBindingCatalogItem[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
  cache?: {
    scope?: string;
    hit?: boolean;
    generatedAt?: string;
  } | null;
};

export const eventOrganizerBindingApi = {
  async fetchEvents(input: {
    page: number;
    limit: number;
    search?: string;
    status?: EventStatusFilter;
  }): Promise<EventOrganizerBindingListResponse> {
    const search = new URLSearchParams();
    search.set('page', String(input.page));
    search.set('limit', String(input.limit));
    search.set('status', input.status || 'all');
    if (input.search?.trim()) {
      search.set('search', input.search.trim());
    }

    const response = await authenticatedJsonFetch<{
      data?: {
        items?: EventOrganizerBindingCatalogItem[];
        meta?: {
          cache?: {
            scope?: string;
            hit?: boolean;
            generatedAt?: string;
          };
        };
      };
      pagination?: EventOrganizerBindingListResponse['pagination'];
    }>(getApiUrl(`/v1/events/catalog-summary?${search.toString()}`));

    return {
      items: Array.isArray(response.data?.items) ? response.data.items : [],
      pagination: response.pagination ?? {
        page: input.page,
        limit: input.limit,
        total: 0,
        totalPages: 1,
      },
      cache: response.data?.meta?.cache ?? null,
    };
  },

  async searchOrganizers(query: string): Promise<EventStudioOrganizer[]> {
    const search = new URLSearchParams({
      search: query.trim(),
      limit: '10',
    });
    const response = await authenticatedJsonFetch<{
      data?: {
        items?: EventStudioOrganizer[];
      };
    }>(getApiUrl(`/v1/learn/festivals?${search.toString()}`));

    return Array.isArray(response.data?.items) ? response.data.items : [];
  },

  async bindOrganizer(input: {
    eventId: string;
    organizerId: string;
    organizerName: string;
  }) {
    const loaded = await eventStudioApi.fetchEvent(input.eventId);
    const draft = hydrateEventStudioDraftFromEvent(loaded);
    draft.organizerFestivalId = input.organizerId;
    draft.organizerName = input.organizerName;
    const updateInput = mapEventStudioDraftToUpdateInput(draft);
    return eventStudioApi.updateEvent(input.eventId, updateInput);
  },

  async clearOrganizer(input: {
    eventId: string;
  }) {
    const loaded = await eventStudioApi.fetchEvent(input.eventId);
    const draft = hydrateEventStudioDraftFromEvent(loaded);
    draft.organizerFestivalId = '';
    draft.organizerName = '';
    const updateInput = mapEventStudioDraftToUpdateInput(draft);
    return eventStudioApi.updateEvent(input.eventId, updateInput);
  },

  async bindOrganizerBatch(input: {
    eventIds: string[];
    organizerId: string;
    organizerName: string;
  }) {
    const results = await Promise.allSettled(
      input.eventIds.map((eventId) =>
        eventOrganizerBindingApi.bindOrganizer({
          eventId,
          organizerId: input.organizerId,
          organizerName: input.organizerName,
        })
      )
    );

    const successCount = results.filter((item) => item.status === 'fulfilled').length;
    return {
      successCount,
      failureCount: results.length - successCount,
    };
  },

  async clearOrganizerBatch(input: {
    eventIds: string[];
  }) {
    const results = await Promise.allSettled(
      input.eventIds.map((eventId) =>
        eventOrganizerBindingApi.clearOrganizer({
          eventId,
        })
      )
    );

    const successCount = results.filter((item) => item.status === 'fulfilled').length;
    return {
      successCount,
      failureCount: results.length - successCount,
    };
  },
};
