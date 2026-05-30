import { authenticatedJsonFetch } from '@/lib/auth/authenticated-fetch';
import { getApiUrl } from '@/lib/config';
import { CatalogCacheMeta, EventCatalogItem } from '@/features/admin-content/catalog/api';

export type ArchiveYearSummaryItem = {
  year: number;
  count: number;
};

export const archiveAdminApi = {
  async fetchYearSummary(): Promise<{
    items: ArchiveYearSummaryItem[];
    cache?: CatalogCacheMeta | null;
  }> {
    const response = await authenticatedJsonFetch<{
      data?: {
        items?: ArchiveYearSummaryItem[];
        meta?: {
          cache?: CatalogCacheMeta;
        };
      };
    }>(getApiUrl('/v1/events/archive-year-summary'));

    return {
      items: Array.isArray(response.data?.items) ? response.data.items : [],
      cache: response.data?.meta?.cache ?? null,
    };
  },

  async fetchEventsByYear(input: {
    year: number;
    page: number;
    limit: number;
    refresh?: boolean;
  }): Promise<{
    items: EventCatalogItem[];
    pagination: {
      page: number;
      limit: number;
      total: number;
      totalPages: number;
    };
    cache?: CatalogCacheMeta | null;
  }> {
    const search = new URLSearchParams({
      page: String(input.page),
      limit: String(input.limit),
      status: 'all',
      search: String(input.year),
      refresh: input.refresh ? '1' : '0',
    });
    const response = await authenticatedJsonFetch<{
      data?: {
        items?: EventCatalogItem[];
        meta?: {
          cache?: CatalogCacheMeta;
        };
      };
      pagination?: {
        page: number;
        limit: number;
        total: number;
        totalPages: number;
      };
    }>(getApiUrl(`/v1/events/catalog-summary?${search.toString()}`));

    const yearItems = (Array.isArray(response.data?.items) ? response.data.items : []).filter((item) => {
      const startYear = new Date(item.startDate).getFullYear();
      return startYear === input.year;
    });

    return {
      items: yearItems,
      pagination: response.pagination ?? {
        page: input.page,
        limit: input.limit,
        total: yearItems.length,
        totalPages: 1,
      },
      cache: response.data?.meta?.cache ?? null,
    };
  },

  async refreshYearSummary(): Promise<{
    items: ArchiveYearSummaryItem[];
    cache?: CatalogCacheMeta | null;
  }> {
    const response = await authenticatedJsonFetch<{
      data?: {
        items?: ArchiveYearSummaryItem[];
        meta?: {
          cache?: CatalogCacheMeta;
        };
      };
    }>(getApiUrl('/v1/events/archive-year-summary?refresh=1'));

    return {
      items: Array.isArray(response.data?.items) ? response.data.items : [],
      cache: response.data?.meta?.cache ?? null,
    };
  },
};
