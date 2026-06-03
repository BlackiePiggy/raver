import { authenticatedFetch, authenticatedJsonFetch } from '@/lib/auth/authenticated-fetch';
import { getApiUrl } from '@/lib/config';
import {
  NewsStudioCreateInput,
  NewsStudioCreateResult,
  NewsStudioLoadedArticle,
} from './types';

type NewsListResponse = {
  items: NewsStudioLoadedArticle[];
  nextCursor: string | null;
};

export type NewsStudioListSort = 'newest' | 'oldest';

export type NewsStudioListFilters = {
  cursor?: string | null;
  limit?: number;
  category?: string;
  source?: string;
  sort?: NewsStudioListSort;
};

type NewsStudioImageUploadResponse = {
  url: string;
  mimeType?: string | null;
  fileName?: string | null;
};

const isNewsStudioImageUploadResponse = (
  value: unknown
): value is NewsStudioImageUploadResponse => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return false;
  const row = value as Record<string, unknown>;
  return typeof row.url === 'string' && row.url.trim().length > 0;
};

const parseJsonSafe = async (response: Response): Promise<unknown> => {
  try {
    return await response.json();
  } catch {
    return null;
  }
};

export const newsStudioApi = {
  async listNews(filters?: NewsStudioListFilters): Promise<NewsListResponse> {
    const params = new URLSearchParams({
      limit: String(filters?.limit ?? 12),
      sort: filters?.sort === 'oldest' ? 'oldest' : 'newest',
    });
    if (filters?.cursor) params.set('cursor', filters.cursor);
    if (filters?.category?.trim()) params.set('category', filters.category.trim());
    if (filters?.source?.trim()) params.set('source', filters.source.trim());
    return authenticatedJsonFetch<NewsListResponse>(getApiUrl(`/v1/news?${params.toString()}`));
  },

  async fetchNews(id: string): Promise<NewsStudioLoadedArticle> {
    return authenticatedJsonFetch<NewsStudioLoadedArticle>(getApiUrl(`/v1/news/${id}`));
  },

  async createNews(input: NewsStudioCreateInput): Promise<NewsStudioCreateResult> {
    const article = await authenticatedJsonFetch<NewsStudioLoadedArticle>(getApiUrl('/v1/news'), {
      method: 'POST',
      body: JSON.stringify(input),
    });
    return {
      kind: 'created',
      article: {
        id: article.id,
        title: article.title,
        publishedAt: article.publishedAt,
      },
    };
  },

  async updateNews(id: string, input: NewsStudioCreateInput): Promise<NewsStudioCreateResult> {
    const article = await authenticatedJsonFetch<NewsStudioLoadedArticle>(getApiUrl(`/v1/news/${id}`), {
      method: 'PATCH',
      body: JSON.stringify(input),
    });
    return {
      kind: 'created',
      article: {
        id: article.id,
        title: article.title,
        publishedAt: article.publishedAt,
      },
    };
  },

  async deleteNews(id: string): Promise<void> {
    await authenticatedJsonFetch<{ success: true }>(getApiUrl(`/v1/news/${id}`), {
      method: 'DELETE',
    });
  },

  async uploadImage(
    file: File,
    options: {
      newsId?: string;
      draftKey?: string;
    }
  ): Promise<NewsStudioImageUploadResponse> {
    const formData = new FormData();
    formData.append('image', file);
    if (options.newsId?.trim()) {
      formData.append('postId', options.newsId.trim());
    } else if (options.draftKey?.trim()) {
      formData.append('newsKey', options.draftKey.trim());
    } else {
      throw new Error('newsId or draftKey is required for news image upload');
    }

    const response = await authenticatedFetch('/api/raver/feed/upload-image', {
      method: 'POST',
      body: formData,
      headers: {},
    });

    if (!response.ok) {
      const error = (await parseJsonSafe(response)) as { error?: string; message?: string } | null;
      throw new Error(error?.error || error?.message || '资讯图片上传失败');
    }

    const payload = (await parseJsonSafe(response)) as
      | { data?: unknown }
      | NewsStudioImageUploadResponse
      | null;
    const unwrapped =
      payload && typeof payload === 'object' && 'data' in payload
        ? payload.data
        : payload;

    if (!isNewsStudioImageUploadResponse(unwrapped)) {
      throw new Error('上传成功但未返回图片地址');
    }
    return unwrapped;
  },

  async cleanupDraftMedia(input: { draftKey: string; urls: string[] }): Promise<{ deleted: number }> {
    const response = await authenticatedJsonFetch<{ data?: { deleted?: number }; deleted?: number }>(
      '/api/raver/feed/draft-media/cleanup',
      {
        method: 'POST',
        body: JSON.stringify({
          newsKey: input.draftKey,
          urls: input.urls,
        }),
      }
    );

    return {
      deleted: Number(response.data?.deleted ?? response.deleted ?? 0) || 0,
    };
  },
};
