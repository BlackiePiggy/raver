import { authenticatedJsonFetch } from '@/lib/auth/authenticated-fetch';
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

export const newsStudioApi = {
  async listNews(cursor?: string | null, limit = 12): Promise<NewsListResponse> {
    const params = new URLSearchParams({ limit: String(limit) });
    if (cursor) params.set('cursor', cursor);
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
};
