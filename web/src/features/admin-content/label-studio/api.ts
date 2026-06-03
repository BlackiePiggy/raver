import { authenticatedJsonFetch } from '@/lib/auth/authenticated-fetch';
import { getApiUrl } from '@/lib/config';
import {
  LabelStudioCreateInput,
  LabelStudioCreateResult,
  LabelStudioListResponse,
  LabelStudioLoadedLabel,
} from './types';

type LabelListEnvelope = {
  data: {
    items: LabelStudioLoadedLabel[];
  };
  pagination: LabelStudioListResponse['pagination'];
};

export const labelStudioApi = {
  async listLabels(
    page = 1,
    limit = 12,
    search = '',
    sortBy: 'soundcloudFollowers' | 'likes' | 'name' | 'nation' | 'latestRelease' | 'createdAt' = 'soundcloudFollowers',
    order: 'asc' | 'desc' = 'desc'
  ): Promise<LabelStudioListResponse> {
    const params = new URLSearchParams({
      page: String(page),
      limit: String(limit),
      sortBy,
      order,
    });
    if (search.trim()) params.set('search', search.trim());
    const payload = await authenticatedJsonFetch<LabelListEnvelope>(
      getApiUrl(`/v1/learn/labels?${params.toString()}`)
    );
    return {
      items: payload.data.items,
      pagination: payload.pagination,
    };
  },

  async fetchLabel(id: string): Promise<LabelStudioLoadedLabel> {
    const payload = await authenticatedJsonFetch<{ data: LabelStudioLoadedLabel }>(
      getApiUrl(`/v1/learn/labels/${id}`)
    );
    return payload.data;
  },

  async createLabel(input: LabelStudioCreateInput): Promise<LabelStudioCreateResult> {
    const payload = await authenticatedJsonFetch<{ data: LabelStudioLoadedLabel }>(getApiUrl('/v1/learn/labels'), {
      method: 'POST',
      body: JSON.stringify(input),
    });
    return {
      kind: 'created',
      label: {
        id: payload.data.id,
        name: payload.data.name,
        slug: payload.data.slug,
      },
    };
  },

  async updateLabel(id: string, input: LabelStudioCreateInput): Promise<LabelStudioCreateResult> {
    const payload = await authenticatedJsonFetch<{ data: LabelStudioLoadedLabel }>(
      getApiUrl(`/v1/learn/labels/${id}`),
      {
        method: 'PATCH',
        body: JSON.stringify(input),
      }
    );
    return {
      kind: 'created',
      label: {
        id: payload.data.id,
        name: payload.data.name,
        slug: payload.data.slug,
      },
    };
  },
};
