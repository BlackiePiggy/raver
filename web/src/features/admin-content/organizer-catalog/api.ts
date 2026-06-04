import { authenticatedJsonFetch } from '@/lib/auth/authenticated-fetch';
import { getApiUrl } from '@/lib/config';

export type OrganizerCatalogPagination = {
  page: number;
  limit: number;
  total: number;
  totalPages: number;
};

export type OrganizerCatalogItem = {
  id: string;
  name: string;
  nameI18n?: {
    zh?: string;
    en?: string;
    ja?: string;
    enFull?: string;
  } | null;
  revision?: number | null;
  abbreviation?: string | null;
  aliases?: string[] | null;
  country?: string | null;
  city?: string | null;
  tagline?: string | null;
  officialWebsite?: string | null;
  avatarUrl?: string | null;
  backgroundUrl?: string | null;
  links?: Array<{
    title: string;
    icon: string;
    url: string;
  }> | null;
  updatedAt?: string | null;
  createdAt?: string | null;
};

export type OrganizerCatalogResponse = {
  items: OrganizerCatalogItem[];
  pagination: OrganizerCatalogPagination;
};

export type OrganizerCatalogSortBy =
  | 'updatedAtDesc'
  | 'updatedAtAsc'
  | 'createdAtDesc'
  | 'createdAtAsc'
  | 'nameAsc'
  | 'nameDesc';

const buildQuery = (params: Record<string, string | number | undefined>): string => {
  const search = new URLSearchParams();
  Object.entries(params).forEach(([key, value]) => {
    if (value === undefined || value === '') return;
    search.set(key, String(value));
  });
  return search.toString();
};

export const organizerCatalogApi = {
  async fetchOrganizers(input: {
    page: number;
    limit: number;
    search?: string;
    country?: string;
    sortBy?: OrganizerCatalogSortBy;
  }): Promise<OrganizerCatalogResponse> {
    const query = buildQuery({
      page: input.page,
      limit: input.limit,
      search: input.search?.trim() || undefined,
      country: input.country?.trim() || undefined,
      sortBy: input.sortBy || undefined,
    });

    const response = await authenticatedJsonFetch<{
      data?: {
        items?: OrganizerCatalogItem[];
      };
      pagination?: OrganizerCatalogPagination;
    }>(getApiUrl(`/v1/learn/festivals?${query}`));

    return {
      items: Array.isArray(response.data?.items) ? response.data.items : [],
      pagination: response.pagination ?? {
        page: input.page,
        limit: input.limit,
        total: 0,
        totalPages: 1,
      },
    };
  },
};
