import { authenticatedJsonFetch } from '@/lib/auth/authenticated-fetch';

export interface AuthSessionItem {
  id: string;
  userId?: string;
  clientType: string;
  deviceId: string | null;
  deviceName: string | null;
  platform: string | null;
  appVersion: string | null;
  userAgent: string | null;
  ipAddressMasked: string | null;
  createdAt: string;
  lastUsedAt: string | null;
  expiresAt: string;
  idleExpiresAt: string | null;
  absoluteExpiresAt: string | null;
  revokedAt: string | null;
  isCurrent: boolean;
  user?: {
    id: string;
    username: string;
    displayName: string | null;
    email: string;
    role: string;
  };
}

export interface AuthSessionListResponse {
  items: AuthSessionItem[];
}

export interface AuthSessionRevokeResponse {
  success: true;
  revokedCurrent: boolean;
}

export const authSessionsApi = {
  async list(): Promise<AuthSessionListResponse> {
    return authenticatedJsonFetch<AuthSessionListResponse>('/v1/auth/sessions');
  },

  async revoke(sessionId: string): Promise<AuthSessionRevokeResponse> {
    return authenticatedJsonFetch<AuthSessionRevokeResponse>(`/v1/auth/sessions/${encodeURIComponent(sessionId)}`, {
      method: 'DELETE',
    });
  },
};

export interface AdminAuthSessionListParams {
  userId?: string;
  q?: string;
  includeRevoked?: boolean;
  limit?: number;
}

export interface AdminAuthSessionListResponse {
  success: true;
  items: AuthSessionItem[];
}

export interface AdminAuthSessionRevokeResponse {
  success: true;
  sessionId: string;
  targetUserId: string;
}

const buildAdminQuery = (params?: AdminAuthSessionListParams): string => {
  const query = new URLSearchParams();
  if (params?.userId) query.set('userId', params.userId);
  if (params?.q) query.set('q', params.q);
  if (params?.includeRevoked !== undefined) query.set('includeRevoked', String(params.includeRevoked));
  if (params?.limit) query.set('limit', String(params.limit));
  const value = query.toString();
  return value ? `?${value}` : '';
};

export const adminAuthSessionsApi = {
  async list(params?: AdminAuthSessionListParams): Promise<AdminAuthSessionListResponse> {
    return authenticatedJsonFetch<AdminAuthSessionListResponse>(`/api/admin/v1/auth-sessions${buildAdminQuery(params)}`);
  },

  async revoke(sessionId: string): Promise<AdminAuthSessionRevokeResponse> {
    return authenticatedJsonFetch<AdminAuthSessionRevokeResponse>(
      `/api/admin/v1/auth-sessions/${encodeURIComponent(sessionId)}/revoke`,
      {
        method: 'POST',
      }
    );
  },
};
