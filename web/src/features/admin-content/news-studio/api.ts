import { authenticatedFetch, authenticatedJsonFetch } from '@/lib/auth/authenticated-fetch';
import { getApiUrl } from '@/lib/config';
import { uploadMediaWithFetcher } from '@/lib/api/upload-media';
import {
  NewsStudioCreateInput,
  NewsStudioCreateResult,
  NewsStudioLoadedArticle,
} from './types';

type NewsListResponse = {
  items: NewsStudioLoadedArticle[];
  nextCursor: string | null;
  pagination?: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
};

export type NewsStudioListSort = 'newest' | 'oldest';
export type NewsStudioSearchItem = Pick<
  NewsStudioLoadedArticle,
  'id' | 'title' | 'summary' | 'source' | 'category' | 'coverImageURL' | 'publishedAt'
>;

export type NewsStudioListFilters = {
  page?: number;
  cursor?: string | null;
  limit?: number;
  category?: string;
  source?: string;
  sort?: NewsStudioListSort;
  query?: string;
};

type NewsStudioImageUploadResponse = {
  url: string;
  mimeType?: string | null;
  fileName?: string | null;
};

export const newsStudioApi = {
  async listNews(filters?: NewsStudioListFilters): Promise<NewsListResponse> {
    const params = new URLSearchParams({
      limit: String(filters?.limit ?? 12),
      sort: filters?.sort === 'oldest' ? 'oldest' : 'newest',
    });
    if (typeof filters?.page === 'number' && Number.isFinite(filters.page)) {
      params.set('page', String(filters.page));
    }
    if (filters?.cursor) params.set('cursor', filters.cursor);
    if (filters?.category?.trim()) params.set('category', filters.category.trim());
    if (filters?.source?.trim()) params.set('source', filters.source.trim());
    if (filters?.query?.trim()) params.set('query', filters.query.trim());
    return authenticatedJsonFetch<NewsListResponse>(getApiUrl(`/v1/news?${params.toString()}`));
  },

  async fetchNews(id: string): Promise<NewsStudioLoadedArticle> {
    return authenticatedJsonFetch<NewsStudioLoadedArticle>(getApiUrl(`/v1/news/${id}`));
  },

  async searchNews(query: string, limit = 8): Promise<NewsStudioSearchItem[]> {
    const params = new URLSearchParams({
      q: query.trim(),
      limit: String(limit),
    });
    const response = await authenticatedJsonFetch<{ items?: NewsStudioSearchItem[] }>(
      getApiUrl(`/v1/news/search?${params.toString()}`)
    );
    return Array.isArray(response.items) ? response.items : [];
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
    if (options.newsId?.trim()) {
    } else if (options.draftKey?.trim()) {
    } else {
      throw new Error('newsId or draftKey is required for news image upload');
    }
    return uploadMediaWithFetcher({
      url: '/api/raver/feed/upload-image',
      file,
      fields: {
        postId: options.newsId?.trim() || undefined,
        newsKey: options.draftKey?.trim() || undefined,
      },
      fallbackError: '资讯图片上传失败',
      invalidResponseError: '上传成功但未返回图片地址',
    });
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
