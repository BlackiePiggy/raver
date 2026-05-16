import { getApiUrl } from '@/lib/config';
import { authenticatedJsonFetch } from '@/lib/auth/authenticated-fetch';

export type ContentSubmissionEntityType = 'event' | 'dj' | 'news' | 'set' | 'brand' | 'label' | 'id' | 'rating';
export type ContentSubmissionStatus = 'pending' | 'approved' | 'rejected';

export interface ContentSubmissionUser {
  id: string;
  username: string;
  displayName: string | null;
  avatarUrl: string | null;
}

export interface ContentSubmission {
  id: string;
  submitterId: string;
  entityType: ContentSubmissionEntityType;
  status: ContentSubmissionStatus;
  title: string;
  payload: Record<string, unknown>;
  reviewReason: string | null;
  reviewNotes?: Record<string, unknown> | null;
  reviewedAt: string | null;
  reviewedBy: string | null;
  createdEntityId: string | null;
  createdAt: string;
  updatedAt: string;
  submitter?: ContentSubmissionUser;
}

const buildQuery = (params?: Record<string, string | number | undefined>): string => {
  const search = new URLSearchParams();
  if (params) {
    for (const [key, value] of Object.entries(params)) {
      if (value === undefined || value === '') continue;
      search.set(key, String(value));
    }
  }
  const query = search.toString();
  return query ? `?${query}` : '';
};

export const contentSubmissionsApi = {
  async listAdmin(
    _token: string,
    params?: {
      status?: string;
      entityType?: string;
      limit?: number;
      i18nStatus?: 'ready' | 'missing_ja' | 'needs_manual_confirmation' | string;
      missingLocale?: 'ja' | 'en' | 'zh' | string;
      translationStatus?: 'needs_manual_confirmation' | string;
    }
  ): Promise<{ items: ContentSubmission[] }> {
    return authenticatedJsonFetch<{ items: ContentSubmission[] }>(
      getApiUrl(`/admin/v1/content-submissions${buildQuery(params)}`)
    );
  },

  async review(
    _token: string,
    submissionId: string,
    input: { decision: 'approved' | 'rejected'; reason?: string }
  ): Promise<{ message: string; submission: ContentSubmission }> {
    return authenticatedJsonFetch<{ message: string; submission: ContentSubmission }>(
      getApiUrl(`/admin/v1/content-submissions/${submissionId}/review`),
      {
        method: 'POST',
        body: JSON.stringify(input),
      }
    );
  },
};
