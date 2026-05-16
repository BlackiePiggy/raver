import { getApiUrl } from '@/lib/config';
import { authenticatedJsonFetch } from '@/lib/auth/authenticated-fetch';

export interface AccountEnforcementUser {
  id: string;
  username: string;
  displayName: string | null;
  email: string;
}

export interface AccountEnforcement {
  id: string;
  userId: string;
  status: string;
  type: string;
  scopes: string[];
  reasonCode: string;
  userMessageI18n?: Record<string, string> | null;
  internalNote: string | null;
  evidence?: unknown;
  startsAt: string;
  endsAt: string | null;
  createdBy: string | null;
  createdFromReportId: string | null;
  createdFromCaseId: string | null;
  revokedAt: string | null;
  revokedBy: string | null;
  revocationReason: string | null;
  createdAt: string;
  updatedAt: string;
  user?: AccountEnforcementUser;
}

export interface EnforcementAppeal {
  id: string;
  enforcementId: string;
  userId: string;
  status: string;
  appealReason: string;
  attachments?: unknown;
  contactEmail: string | null;
  reviewerId: string | null;
  decision: string | null;
  decisionNote: string | null;
  reviewedAt: string | null;
  createdAt: string;
  updatedAt: string;
  enforcement?: AccountEnforcement;
}

const parseError = async (response: Response): Promise<string> => {
  try {
    const data = await response.json();
    return data.error || data.message || `Account enforcement request failed (${response.status})`;
  } catch {
    return `Account enforcement request failed (${response.status})`;
  }
};

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

export const accountEnforcementsApi = {
  async list(
    _token: string,
    params?: { userId?: string; status?: string; type?: string; limit?: number }
  ): Promise<{ success: true; items: AccountEnforcement[] }> {
    return authenticatedJsonFetch<{ success: true; items: AccountEnforcement[] }>(
      getApiUrl(`/admin/v1/account-enforcements${buildQuery(params)}`)
    );
  },

  async create(
    _token: string,
    userId: string,
    input: {
      type: string;
      scopes?: string[];
      reasonCode: string;
      durationDays?: number;
      endsAt?: string;
      internalNote?: string;
      userMessageI18n?: Record<string, string>;
      evidence?: unknown;
      createdFromReportId?: string;
      createdFromCaseId?: string;
    },
    reauthProof?: string
  ): Promise<{ success: true; enforcement: AccountEnforcement }> {
    return authenticatedJsonFetch<{ success: true; enforcement: AccountEnforcement }>(
      getApiUrl(`/admin/v1/users/${encodeURIComponent(userId)}/enforcements`),
      {
        method: 'POST',
        headers: reauthProof ? { 'x-raver-reauth-proof': reauthProof } : undefined,
        body: JSON.stringify(input),
      }
    );
  },

  async revoke(
    _token: string,
    enforcementId: string,
    reason: string,
    reauthProof?: string
  ): Promise<{ success: true; enforcement: AccountEnforcement }> {
    return authenticatedJsonFetch<{ success: true; enforcement: AccountEnforcement }>(
      getApiUrl(`/admin/v1/account-enforcements/${encodeURIComponent(enforcementId)}/revoke`),
      {
        method: 'POST',
        headers: reauthProof ? { 'x-raver-reauth-proof': reauthProof } : undefined,
        body: JSON.stringify({ reason }),
      }
    );
  },

  async expireDue(_token: string, reauthProof?: string): Promise<{ success: true; activatedCount: number; expiredCount: number }> {
    return authenticatedJsonFetch<{ success: true; activatedCount: number; expiredCount: number }>(
      getApiUrl('/admin/v1/account-enforcements/expire-due'),
      {
        method: 'POST',
        headers: reauthProof ? { 'x-raver-reauth-proof': reauthProof } : undefined,
      }
    );
  },

  async listAppeals(
    _token: string,
    params?: { userId?: string; status?: string; limit?: number }
  ): Promise<{ success: true; items: EnforcementAppeal[] }> {
    return authenticatedJsonFetch<{ success: true; items: EnforcementAppeal[] }>(
      getApiUrl(`/admin/v1/enforcement-appeals${buildQuery(params)}`)
    );
  },

  async decideAppeal(
    _token: string,
    appealId: string,
    input: { status: string; decision: string; decisionNote?: string }
  ): Promise<{ success: true; appeal: EnforcementAppeal }> {
    return authenticatedJsonFetch<{ success: true; appeal: EnforcementAppeal }>(
      getApiUrl(`/admin/v1/enforcement-appeals/${encodeURIComponent(appealId)}/decision`),
      {
        method: 'POST',
        body: JSON.stringify(input),
      }
    );
  },
};
