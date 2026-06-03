import { authenticatedJsonFetch } from '@/lib/auth/authenticated-fetch';
import { getApiUrl } from '@/lib/config';

export type AdminCatalogPagination = {
  page: number;
  limit: number;
  total: number;
  totalPages: number;
};

type BffEnvelope<T> = {
  data?: T;
  pagination?: AdminCatalogPagination;
};

export type CatalogCacheMeta = {
  scope?: string;
  hit?: boolean;
  stale?: boolean;
  generatedAt?: string;
  ttlMs?: number;
  snapshotVersion?: string;
};

export type EventCatalogItem = {
  id: string;
  name: string;
  slug?: string | null;
  coverImageUrl?: string | null;
  organizerName?: string | null;
  city?: string | null;
  country?: string | null;
  eventType?: string | null;
  status?: string | null;
  isVerified?: boolean;
  startDate: string;
  endDate: string;
  timeZone?: string | null;
  updatedAt: string;
  wikiFestival?: {
    id: string;
    name?: string | null;
  } | null;
  eventDays?: Array<{
    eventDayId?: string;
  }>;
};

export type DJCatalogItem = {
  id: string;
  name: string;
  slug?: string | null;
  avatarUrl?: string | null;
  bannerUrl?: string | null;
  country?: string | null;
  bio?: string | null;
  aliases?: string[] | null;
  genres?: string[] | null;
  followerCount?: number | null;
  soundCloudFollowers?: number | null;
  instagramUrl?: string | null;
  spotifyId?: string | null;
  isVerified?: boolean;
  updatedAt: string;
  createdAt: string;
  lastSyncedAt?: string | null;
};

export type EventCatalogFilters = {
  page?: number;
  limit?: number;
  search?: string;
  status?: string;
  city?: string;
  country?: string;
  eventType?: string;
  wikiFestivalId?: string;
  sortBy?: 'startDateDesc' | 'startDateAsc' | 'updatedAtDesc' | 'updatedAtAsc';
  refresh?: boolean;
};

export type DJCatalogFilters = {
  page?: number;
  limit?: number;
  search?: string;
  country?: string;
  verificationStatus?: 'all' | 'verified' | 'unverified' | 'incomplete';
  sortBy?: 'followerCount' | 'name' | 'createdAt';
  refresh?: boolean;
};

export type DJCatalogSummary = {
  total: number;
  verified: number;
  unverified: number;
  incomplete: number;
};

export type EventCatalogResponse = {
  items: EventCatalogItem[];
  pagination: AdminCatalogPagination;
  cache?: CatalogCacheMeta | null;
};

export type DJCatalogResponse = {
  items: DJCatalogItem[];
  pagination: AdminCatalogPagination;
  cache?: CatalogCacheMeta | null;
  summary?: DJCatalogSummary | null;
};

const buildSearch = (params: Record<string, string | number | boolean | undefined>): string => {
  const search = new URLSearchParams();
  Object.entries(params).forEach(([key, value]) => {
    if (value === undefined || value === '') return;
    search.set(key, String(value));
  });
  return search.toString();
};

const normalizePagination = (pagination: AdminCatalogPagination | undefined, fallbackLimit: number): AdminCatalogPagination => ({
  page: pagination?.page ?? 1,
  limit: pagination?.limit ?? fallbackLimit,
  total: pagination?.total ?? 0,
  totalPages: pagination?.totalPages ?? 1,
});

export const adminCatalogApi = {
  async fetchEvents(filters: EventCatalogFilters): Promise<EventCatalogResponse> {
    const limit = filters.limit ?? 50;
    const query = buildSearch({
      page: filters.page ?? 1,
      limit,
      search: filters.search?.trim() || undefined,
      status: filters.status || undefined,
      city: filters.city?.trim() || undefined,
      country: filters.country?.trim() || undefined,
      eventType: filters.eventType?.trim() || undefined,
      wikiFestivalId: filters.wikiFestivalId?.trim() || undefined,
      sortBy: filters.sortBy || undefined,
      refresh: filters.refresh ? 1 : undefined,
    });
    const response = await authenticatedJsonFetch<BffEnvelope<{ items?: EventCatalogItem[]; meta?: { cache?: CatalogCacheMeta } }>>(
      getApiUrl(`/v1/events/catalog-summary?${query}`)
    );

    return {
      items: Array.isArray(response.data?.items) ? response.data.items : [],
      pagination: normalizePagination(response.pagination, limit),
      cache: response.data?.meta?.cache ?? null,
    };
  },

  async fetchDJs(filters: DJCatalogFilters): Promise<DJCatalogResponse> {
    const limit = filters.limit ?? 50;
    const query = buildSearch({
      page: filters.page ?? 1,
      limit,
      search: filters.search?.trim() || undefined,
      country: filters.country?.trim() || undefined,
      verificationStatus:
        filters.verificationStatus && filters.verificationStatus !== 'all'
          ? filters.verificationStatus
          : undefined,
      sortBy: filters.sortBy || undefined,
      refresh: filters.refresh ? 1 : undefined,
    });
    const response = await authenticatedJsonFetch<BffEnvelope<{
      items?: DJCatalogItem[];
      meta?: {
        cache?: CatalogCacheMeta;
        summary?: DJCatalogSummary;
      };
    }>>(
      getApiUrl(`/v1/djs/catalog-summary?${query}`)
    );

    return {
      items: Array.isArray(response.data?.items) ? response.data.items : [],
      pagination: normalizePagination(response.pagination, limit),
      cache: response.data?.meta?.cache ?? null,
      summary: response.data?.meta?.summary ?? null,
    };
  },
};
