import { getApiUrl } from '@/lib/config';
import { authenticatedJsonFetch } from '@/lib/auth/authenticated-fetch';

export interface AdminUserCounts {
  posts: number;
  follows: number;
  followers: number;
  authSessions: number;
  enforcements: number;
  deletionRequests: number;
}

export interface AdminUser {
  id: string;
  username: string;
  email: string;
  phoneNumber: string | null;
  displayName: string | null;
  avatarUrl: string | null;
  role: string;
  isActive: boolean;
  isVerified: boolean;
  regionCode: string;
  birthYear: number | null;
  ageBand: string;
  createdAt: string;
  updatedAt: string;
  lastLoginAt: string | null;
  counts?: AdminUserCounts;
}

export interface AdminUserDetail {
  success: true;
  user: AdminUser;
  stats: {
    activeSessions: number;
    activePushTokens: number;
    activeEnforcements: number;
  };
  latestDeletionRequest: null | {
    id: string;
    status: string;
    requestedBy: string;
    requestSource: string;
    createdAt: string;
    completedAt: string | null;
  };
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

export const adminUsersApi = {
  async list(params?: {
    q?: string;
    role?: string;
    status?: string;
    cursor?: string;
    limit?: number;
  }): Promise<{ success: true; items: AdminUser[]; nextCursor: string | null }> {
    return authenticatedJsonFetch<{ success: true; items: AdminUser[]; nextCursor: string | null }>(
      getApiUrl(`/admin/v1/users${buildQuery(params)}`)
    );
  },

  async detail(userId: string): Promise<AdminUserDetail> {
    return authenticatedJsonFetch<AdminUserDetail>(getApiUrl(`/admin/v1/users/${encodeURIComponent(userId)}`));
  },

  async deleteAccount(
    userId: string,
    reauthProof: string
  ): Promise<{ success: true; userId: string; status: string; deletionRequestId: string | null }> {
    return authenticatedJsonFetch<{ success: true; userId: string; status: string; deletionRequestId: string | null }>(
      getApiUrl(`/admin/v1/users/${encodeURIComponent(userId)}/delete-account`),
      {
        method: 'POST',
        headers: { 'x-raver-reauth-proof': reauthProof },
      }
    );
  },
};
