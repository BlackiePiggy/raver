import { getApiUrl } from '@/lib/config';

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

const authHeaders = (token: string): HeadersInit => ({
  'Content-Type': 'application/json',
  Authorization: `Bearer ${token}`,
});

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
    token: string,
    params?: { userId?: string; status?: string; limit?: number }
  ): Promise<{ success: true; items: AccountDeletionRequest[] }> {
    const response = await fetch(getApiUrl(`/admin/v1/account-deletions${buildQuery(params)}`), {
      headers: authHeaders(token),
    });
    if (!response.ok) throw new Error(await parseError(response));
    return response.json();
  },

  async retry(token: string, requestId: string): Promise<{ success: true; request: AccountDeletionRequest }> {
    const response = await fetch(getApiUrl(`/admin/v1/account-deletions/${encodeURIComponent(requestId)}/retry`), {
      method: 'POST',
      headers: authHeaders(token),
    });
    if (!response.ok) throw new Error(await parseError(response));
    return response.json();
  },

  async processDue(token: string, limit = 20): Promise<{ success: true; results: Array<{ id: string; ok: boolean }> }> {
    const response = await fetch(getApiUrl('/admin/v1/account-deletions/process-due'), {
      method: 'POST',
      headers: authHeaders(token),
      body: JSON.stringify({ limit }),
    });
    if (!response.ok) throw new Error(await parseError(response));
    return response.json();
  },
};
