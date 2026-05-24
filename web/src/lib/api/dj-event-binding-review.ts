import { getApiUrl } from '@/lib/config';
import { authenticatedJsonFetch } from '@/lib/auth/authenticated-fetch';

export interface DJEventBindingReviewCandidate {
  id: string;
  jobId: string;
  djId: string;
  eventId: string;
  eventArtistId: string | null;
  eventArtistMemberId: string | null;
  eventPerformanceId: string | null;
  sourceType: 'lineup_artist' | 'lineup_member' | 'timetable_slot';
  matchTier: 'exact' | 'fuzzy';
  matchScore: number;
  matchReason: 'normalized_equal' | 'compact_equal' | 'contains' | 'similarity';
  rawName: string;
  normalizedKey: string;
  compactKey: string;
  eventNameSnapshot: string;
  stageNameSnapshot: string | null;
  startAtSnapshot: string | null;
  needsSplit: boolean;
  status: string;
  appliedAt: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface DJEventBindingReviewJobDJ {
  id: string;
  name: string;
  avatarUrl: string | null;
}

export interface DJEventBindingReviewJob {
  id: string;
  djId: string;
  djNameSnapshot: string;
  triggerSource: string;
  status: 'pending' | 'partially_applied' | 'applied' | 'dismissed';
  exactCount: number;
  fuzzyCount: number;
  appliedCount: number;
  createdById: string | null;
  completedAt: string | null;
  createdAt: string;
  updatedAt: string;
  dj: DJEventBindingReviewJobDJ;
  candidates?: DJEventBindingReviewCandidate[];
}

export interface DJEventBindingReviewPagination {
  page: number;
  limit: number;
  total: number;
  totalPages: number;
}

const buildQuery = (params?: Record<string, string | number | undefined>): string => {
  const query = new URLSearchParams();
  for (const [key, value] of Object.entries(params || {})) {
    if (value === undefined || value === '') continue;
    query.set(key, String(value));
  }
  const encoded = query.toString();
  return encoded ? `?${encoded}` : '';
};

export const djEventBindingReviewApi = {
  async list(
    _token: string,
    params?: { status?: string; page?: number; limit?: number }
  ): Promise<{ items: DJEventBindingReviewJob[]; pagination?: DJEventBindingReviewPagination }> {
    const response = await authenticatedJsonFetch<{
      data: { items: DJEventBindingReviewJob[] };
      pagination?: DJEventBindingReviewPagination;
    }>(getApiUrl(`/v1/admin/dj-event-binding-review/jobs${buildQuery(params)}`));
    return {
      items: response.data.items,
      pagination: response.pagination,
    };
  },

  async detail(_token: string, jobId: string): Promise<DJEventBindingReviewJob> {
    const response = await authenticatedJsonFetch<{ data: DJEventBindingReviewJob }>(
      getApiUrl(`/v1/admin/dj-event-binding-review/jobs/${encodeURIComponent(jobId)}`)
    );
    return response.data;
  },

  async applyExact(_token: string, jobId: string): Promise<DJEventBindingReviewJob> {
    const response = await authenticatedJsonFetch<{ data: DJEventBindingReviewJob }>(
      getApiUrl(`/v1/admin/dj-event-binding-review/jobs/${encodeURIComponent(jobId)}/apply-exact`),
      {
        method: 'POST',
      }
    );
    return response.data;
  },

  async applyCandidates(_token: string, jobId: string, candidateIds: string[]): Promise<DJEventBindingReviewJob> {
    const response = await authenticatedJsonFetch<{ data: DJEventBindingReviewJob }>(
      getApiUrl(`/v1/admin/dj-event-binding-review/jobs/${encodeURIComponent(jobId)}/apply`),
      {
        method: 'POST',
        body: JSON.stringify({ candidateIds }),
      }
    );
    return response.data;
  },

  async dismissCandidates(
    _token: string,
    jobId: string,
    input: { candidateIds?: string[]; dismissAll?: boolean }
  ): Promise<DJEventBindingReviewJob> {
    const response = await authenticatedJsonFetch<{ data: DJEventBindingReviewJob }>(
      getApiUrl(`/v1/admin/dj-event-binding-review/jobs/${encodeURIComponent(jobId)}/dismiss`),
      {
        method: 'POST',
        body: JSON.stringify(input),
      }
    );
    return response.data;
  },
};
