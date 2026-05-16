import { getApiUrl } from '@/lib/config';
import { authenticatedJsonFetch } from '@/lib/auth/authenticated-fetch';

export interface AdminAuditLogItem {
  id: string;
  actorId: string;
  action: string;
  targetType: string;
  targetId: string;
  detail: unknown;
  createdAt: string;
}

export interface AdminAuditLogListResponse {
  success: boolean;
  items: AdminAuditLogItem[];
  nextCursor: string | null;
}

export interface AdminAuditLogListParams {
  limit?: number;
  actorId?: string;
  action?: string;
  targetType?: string;
  targetId?: string;
  before?: string;
  cursor?: string;
}

const buildQuery = (params?: AdminAuditLogListParams): string => {
  const query = new URLSearchParams();
  if (!params) return '';
  for (const [key, value] of Object.entries(params)) {
    if (value === undefined || value === null || value === '') continue;
    query.set(key, String(value));
  }
  return query.toString() ? `?${query.toString()}` : '';
};

export const adminAuditApi = {
  async listLogs(params?: AdminAuditLogListParams): Promise<AdminAuditLogListResponse> {
    return authenticatedJsonFetch<AdminAuditLogListResponse>(getApiUrl(`/admin/v1/audit-logs${buildQuery(params)}`));
  },
};
