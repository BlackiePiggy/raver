import { getApiUrl } from '@/lib/config';
import { authenticatedJsonFetch } from '@/lib/auth/authenticated-fetch';

export type ContentSubmissionEntityType = 'event' | 'dj' | 'news' | 'set' | 'brand' | 'label' | 'id' | 'rating';
export type ContentSubmissionStatus =
  | 'pending'
  | 'processing'
  | 'reviewing'
  | 'approved'
  | 'rejected'
  | 'failed'
  | 'cancelled';

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

export interface ContentSubmissionVersion {
  id: string;
  submissionId: string;
  version: number;
  title: string;
  payload: Record<string, unknown>;
  submittedAt: string;
  submittedBy: string | null;
  changeNote: string | null;
}

export interface ContentSubmissionDetail extends ContentSubmission {
  versions: ContentSubmissionVersion[];
}

export interface ContentSubmissionPagination {
  page: number;
  limit: number;
  total: number;
  totalPages: number;
}

export interface ContentSubmissionReviewInput {
  decision: 'approved' | 'rejected';
  reason?: string;
  reviewNotes?: Record<string, unknown>;
}

const buildQuery = (params?: Record<string, string | number | string[] | undefined>): string => {
  const search = new URLSearchParams();
  if (params) {
    for (const [key, value] of Object.entries(params)) {
      if (value === undefined || value === '') continue;
      if (Array.isArray(value)) {
        if (value.length === 0) continue;
        search.set(key, value.join(','));
        continue;
      }
      search.set(key, String(value));
    }
  }
  const query = search.toString();
  return query ? `?${query}` : '';
};

export const contentSubmissionsApi = {
  async listAdmin(
    params?: {
      status?: string;
      statuses?: string[];
      entityType?: string;
      limit?: number;
      page?: number;
      i18nStatus?: 'ready' | 'missing_ja' | 'needs_manual_confirmation' | string;
      missingLocale?: 'ja' | 'en' | 'zh' | string;
      translationStatus?: 'needs_manual_confirmation' | string;
    }
  ): Promise<{ items: ContentSubmission[]; total: number; pagination: ContentSubmissionPagination }> {
    return authenticatedJsonFetch<{ items: ContentSubmission[]; total: number; pagination: ContentSubmissionPagination }>(
      getApiUrl(`/admin/v1/content-submissions${buildQuery(params)}`)
    );
  },

  async getAdminDetail(submissionId: string): Promise<{ submission: ContentSubmissionDetail }> {
    return authenticatedJsonFetch<{ submission: ContentSubmissionDetail }>(
      getApiUrl(`/admin/v1/content-submissions/${submissionId}`)
    );
  },

  async review(
    submissionId: string,
    input: ContentSubmissionReviewInput
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
