import { getApiUrl } from '@/lib/config';
import { authenticatedJsonFetch } from '@/lib/auth/authenticated-fetch';

export interface WebsiteVisitRecord {
  id?: string;
  createdAt?: string;
  visitorIdHash?: string;
  path?: string;
  referrer?: string | null;
  language?: string | null;
  timezone?: string | null;
  screen?: {
    width?: number;
    height?: number;
    viewportWidth?: number;
    viewportHeight?: number;
    devicePixelRatio?: number;
  } | null;
  ipHash?: string;
  userAgent?: string | null;
}

export interface WebsiteVisitsSummary {
  totalVisits: number;
  uniqueVisitors: number;
  topPaths: Array<{ value: string; count: number }>;
  topReferrers: Array<{ value: string; count: number }>;
}

export interface WebsiteVisitsResponse {
  success: boolean;
  summary: WebsiteVisitsSummary;
  visits: WebsiteVisitRecord[];
}

export const adminAnalyticsApi = {
  async getWebsiteVisits(limit = 100): Promise<WebsiteVisitsResponse> {
    const query = new URLSearchParams({ limit: String(limit) });
    return authenticatedJsonFetch<WebsiteVisitsResponse>(
      getApiUrl(`/admin/v1/analytics/visits?${query.toString()}`)
    );
  },
};
