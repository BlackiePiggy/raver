import { authenticatedJsonFetch } from '@/lib/auth/authenticated-fetch';
import { getApiUrl } from '@/lib/config';

export type IdentifierOrganizerItem = {
  id: string;
  name: string;
  sourceRowId: number | null;
  country?: string | null;
  city?: string | null;
};

export type IdentifierLabelItem = {
  id: string;
  name: string;
  slug: string;
  profileSlug: string | null;
  profileUrl: string;
  nation?: string | null;
};

export type IdentifierRankingEntryItem = {
  boardId: string;
  boardTitle: string;
  entityType: 'dj' | 'festival';
  year: number;
  rank: number;
  name: string;
  entityId: string | null;
};

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
  async listOrganizers(search = '', page = 1, limit = 20): Promise<{
    items: IdentifierOrganizerItem[];
    pagination: { page: number; limit: number; total: number; totalPages: number };
  }> {
    const query = new URLSearchParams({ search, page: String(page), limit: String(limit) });
    const payload = await authenticatedJsonFetch<Envelope<{ items: IdentifierOrganizerItem[] }>>(
      getApiUrl(`/v1/admin/identifiers/organizers?${query.toString()}`)
    );
    return {
      items: payload.data.items,
      pagination: payload.pagination ?? { page, limit, total: payload.data.items.length, totalPages: 1 },
    };
  },

  async updateOrganizer(id: string, input: { sourceRowId: number | null }): Promise<IdentifierOrganizerItem> {
    const payload = await authenticatedJsonFetch<Envelope<IdentifierOrganizerItem>>(
      getApiUrl(`/v1/admin/identifiers/organizers/${encodeURIComponent(id)}`),
      {
        method: 'PATCH',
        body: JSON.stringify(input),
      }
    );
    return payload.data;
  },

  async listLabels(search = '', page = 1, limit = 20): Promise<{
    items: IdentifierLabelItem[];
    pagination: { page: number; limit: number; total: number; totalPages: number };
  }> {
    const query = new URLSearchParams({ search, page: String(page), limit: String(limit) });
    const payload = await authenticatedJsonFetch<Envelope<{ items: IdentifierLabelItem[] }>>(
      getApiUrl(`/v1/admin/identifiers/labels?${query.toString()}`)
    );
    return {
      items: payload.data.items,
      pagination: payload.pagination ?? { page, limit, total: payload.data.items.length, totalPages: 1 },
    };
  },

  async updateLabel(
    id: string,
    input: { slug?: string; profileSlug?: string | null; profileUrl?: string }
  ): Promise<IdentifierLabelItem> {
    const payload = await authenticatedJsonFetch<Envelope<IdentifierLabelItem>>(
      getApiUrl(`/v1/admin/identifiers/labels/${encodeURIComponent(id)}`),
      {
        method: 'PATCH',
        body: JSON.stringify(input),
      }
    );
    return payload.data;
  },

  async listRankingEntries(search = '', page = 1, limit = 50): Promise<{
    items: IdentifierRankingEntryItem[];
    pagination: { page: number; limit: number; total: number; totalPages: number };
  }> {
    const query = new URLSearchParams({ search, page: String(page), limit: String(limit) });
    const payload = await authenticatedJsonFetch<Envelope<{ items: IdentifierRankingEntryItem[] }>>(
      getApiUrl(`/v1/admin/identifiers/ranking-entries?${query.toString()}`)
    );
    return {
      items: payload.data.items,
      pagination: payload.pagination ?? { page, limit, total: payload.data.items.length, totalPages: 1 },
    };
  },

  async updateRankingEntry(
    boardId: string,
    year: number,
    rank: number,
    input: { entityId: string | null }
  ): Promise<IdentifierRankingEntryItem> {
    const payload = await authenticatedJsonFetch<Envelope<IdentifierRankingEntryItem>>(
      getApiUrl(
        `/v1/admin/identifiers/ranking-entries/${encodeURIComponent(boardId)}/${encodeURIComponent(String(year))}/${encodeURIComponent(String(rank))}`
      ),
      {
        method: 'PATCH',
        body: JSON.stringify(input),
      }
    );
    return payload.data;
  },
};
