import { getApiUrl } from '@/lib/config';

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

const getToken = (): string => {
  const token = localStorage.getItem('token');
  if (!token) {
    throw new Error('请先登录');
  }
  return token;
};

const parseError = async (response: Response): Promise<string> => {
  try {
    const data = await response.json();
    return data.error || data.message || `Admin audit request failed (${response.status})`;
  } catch {
    return `Admin audit request failed (${response.status})`;
  }
};

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
    const response = await fetch(getApiUrl(`/admin/v1/audit-logs${buildQuery(params)}`), {
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${getToken()}`,
      },
    });

    if (!response.ok) {
      throw new Error(await parseError(response));
    }

    return response.json();
  },
};
