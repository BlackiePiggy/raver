import { getApiUrl } from '@/lib/config';
import { authenticatedJsonFetch } from '@/lib/auth/authenticated-fetch';

export interface AccountDeletionUser {
  id: string;
  username: string;
  displayName: string | null;
  email: string;
  isActive: boolean;
}

export interface AccountDeletionRequest {
  id: string;
  userId: string;
  status: string;
  requestedBy: string;
  requestSource: string;
  originalEmailHash: string | null;
  originalPhoneHash: string | null;
  previousAvatarUrl: string | null;
  previousProfileQrUrl: string | null;
  imUserId: string | null;
  imStatus: string;
  imAttempts: number;
  imNextRunAt: string;
  imLastError: string | null;
  mediaStatus: string;
  mediaAttempts: number;
  mediaNextRunAt: string;
  mediaLastError: string | null;
  mediaTargets: { objectKeys?: string[]; sourceUrls?: string[] } | null;
  completedAt: string | null;
  createdAt: string;
  updatedAt: string;
  user?: AccountDeletionUser;
}

const parseError = async (response: Response): Promise<string> => {
  try {
    const data = await response.json();
    return data.error || data.message || `Account deletion request failed (${response.status})`;
  } catch {
    return `Account deletion request failed (${response.status})`;
  }
};

const buildQuery = (params?: Record<string, string | number | undefined>): string => {
  const query = new URLSearchParams();
  for (const [key, value] of Object.entries(params || {})) {
    if (value === undefined || value === '') continue;
    query.set(key, String(value));
  }
  const encoded = query.toString();
  return encoded ? `?${encoded}` : '';
};

export const accountDeletionsApi = {
  async list(
    _token: string,
    params?: { userId?: string; status?: string; limit?: number }
  ): Promise<{ success: true; items: AccountDeletionRequest[] }> {
    return authenticatedJsonFetch<{ success: true; items: AccountDeletionRequest[] }>(
      getApiUrl(`/admin/v1/account-deletions${buildQuery(params)}`)
    );
  },

  async retry(_token: string, requestId: string, reauthProof?: string): Promise<{ success: true; request: AccountDeletionRequest }> {
    return authenticatedJsonFetch<{ success: true; request: AccountDeletionRequest }>(
      getApiUrl(`/admin/v1/account-deletions/${encodeURIComponent(requestId)}/retry`),
      {
        method: 'POST',
        headers: reauthProof ? { 'x-raver-reauth-proof': reauthProof } : undefined,
      }
    );
  },

  async processDue(_token: string, limit = 20, reauthProof?: string): Promise<{ success: true; results: Array<{ id: string; ok: boolean }> }> {
    return authenticatedJsonFetch<{ success: true; results: Array<{ id: string; ok: boolean }> }>(
      getApiUrl('/admin/v1/account-deletions/process-due'),
      {
        method: 'POST',
        headers: reauthProof ? { 'x-raver-reauth-proof': reauthProof } : undefined,
        body: JSON.stringify({ limit }),
      }
    );
  },
};
