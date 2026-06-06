import { authenticatedFetch, authenticatedJsonFetch } from '@/lib/auth/authenticated-fetch';
import { getApiUrl } from '@/lib/config';
import { uploadMediaWithFetcher } from '@/lib/api/upload-media';
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

type LabelStudioImageUploadResponse = {
  url: string;
  originalUrl?: string | null;
  fileName?: string | null;
};

export const labelStudioApi = {
  async uploadImage(
    file: File,
    options: {
      usage: 'avatar' | 'background' | 'poster';
      draftId: string;
    }
  ): Promise<LabelStudioImageUploadResponse> {
    return uploadMediaWithFetcher({
      url: getApiUrl('/v1/wiki/brands/upload-image'),
      file,
      fields: {
        usage: options.usage,
        draftId: options.draftId,
      },
      fallbackError: '厂牌图片上传失败',
      invalidResponseError: '厂牌图片上传成功，但未返回有效图片地址',
    });
  },

  async deleteImages(input: {
    draftId: string;
    urls: string[];
  }): Promise<void> {
    await authenticatedJsonFetch<{ success: true }>(
      getApiUrl('/v1/wiki/brands/delete-images'),
      {
        method: 'POST',
        body: JSON.stringify(input),
      }
    );
  },

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

  async deleteLabel(id: string): Promise<void> {
    await authenticatedJsonFetch<{ success: true }>(getApiUrl(`/v1/learn/labels/${id}`), {
      method: 'DELETE',
    });
  },
};
