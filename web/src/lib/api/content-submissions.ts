import { getApiUrl } from '@/lib/config';

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

const parseError = async (response: Response): Promise<string> => {
  try {
    const data = await response.json();
    return data.error || data.message || `Content submission request failed (${response.status})`;
  } catch {
    return `Content submission request failed (${response.status})`;
  }
};

const authHeaders = (token: string): HeadersInit => ({
  'Content-Type': 'application/json',
  Authorization: `Bearer ${token}`,
});

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
    token: string,
    params?: {
      status?: string;
      entityType?: string;
      limit?: number;
      i18nStatus?: 'ready' | 'missing_ja' | 'needs_manual_confirmation' | string;
      missingLocale?: 'ja' | 'en' | 'zh' | string;
      translationStatus?: 'needs_manual_confirmation' | string;
    }
  ): Promise<{ items: ContentSubmission[] }> {
    const response = await fetch(getApiUrl(`/admin/v1/content-submissions${buildQuery(params)}`), {
      headers: authHeaders(token),
    });
    if (!response.ok) {
      throw new Error(await parseError(response));
    }
    return response.json();
  },

  async review(
    token: string,
    submissionId: string,
    input: { decision: 'approved' | 'rejected'; reason?: string }
  ): Promise<{ message: string; submission: ContentSubmission }> {
    const response = await fetch(getApiUrl(`/admin/v1/content-submissions/${submissionId}/review`), {
      method: 'POST',
      headers: authHeaders(token),
      body: JSON.stringify(input),
    });
    if (!response.ok) {
      throw new Error(await parseError(response));
    }
    return response.json();
  },
};
