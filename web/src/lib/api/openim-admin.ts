const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3901/api';
const V1_BASE_URL = API_URL.endsWith('/api') ? `${API_URL.slice(0, -4)}/v1` : `${API_URL}/v1`;

export interface OpenIMAdminOverview {
  pendingReports: number;
  reports24h: number;
  webhooks24h: number;
  invalidWebhooks24h: number;
  pendingSyncJobs: number;
  pendingImageModerationJobs: number;
  rejectedImageModeration24h: number;
  timestamp: string;
}

export interface OpenIMMessageReport {
  id: string;
  messageID: string;
  conversationID: string | null;
  reportedByUserID: string;
  reason: string;
  detail: string | null;
  source: string;
  status: string;
  metadata: unknown;
  resolvedAt: string | null;
  resolvedBy: string | null;
  resolutionNote: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface OpenIMImageModerationJob {
  id: string;
  webhookEventID: string | null;
  messageID: string | null;
  conversationID: string | null;
  imageURL: string;
  status: string;
  reason: string | null;
  source: string;
  provider: string;
  decisionDetail: unknown;
  reviewedAt: string | null;
  reviewedBy: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface OpenIMWebhookEvent {
  id: string;
  deliveryID: string | null;
  callbackCommand: string | null;
  operationID: string | null;
  eventID: string | null;
  sourceIP: string | null;
  signatureValid: boolean;
  verifyReason: string | null;
  receivedAt: string;
  createdAt: string;
}

export interface OpenIMSyncJob {
  id: string;
  dedupeKey: string;
  jobType: string;
  entityType: string;
  entityId: string;
  status: string;
  attempts: number;
  maxAttempts: number;
  nextRunAt: string;
  lockedAt: string | null;
  lockedBy: string | null;
  lastError: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface OpenIMAuditLog {
  id: string;
  actorID: string;
  action: string;
  targetType: string;
  targetID: string;
  detail: unknown;
  createdAt: string;
}

interface ListResult<T> {
  items: T[];
  nextCursor: string | null;
}

const getToken = (): string => {
  const token = localStorage.getItem('token');
  if (!token) {
    throw new Error('请先登录');
  }
  return token;
};

const request = async <T>(path: string, init?: RequestInit): Promise<T> => {
  const token = getToken();
  const response = await fetch(`${V1_BASE_URL}${path}`, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
      ...(init?.headers || {}),
    },
  });

  if (!response.ok) {
    const error = await response.json().catch(() => ({}));
    throw new Error(error.error || `OpenIM admin request failed (${response.status})`);
  }
  return response.json();
};

export const openIMAdminApi = {
  getOverview(): Promise<OpenIMAdminOverview> {
    return request<OpenIMAdminOverview>('/openim/admin/overview');
  },

  getReports(status = 'pending', limit = 20): Promise<ListResult<OpenIMMessageReport>> {
    const query = new URLSearchParams({ status, limit: String(limit) });
    return request<ListResult<OpenIMMessageReport>>(`/openim/admin/reports?${query.toString()}`);
  },

  resolveReport(reportId: string, status: 'resolved' | 'rejected', resolutionNote?: string): Promise<{
    id: string;
    status: string;
    resolvedAt: string | null;
    resolvedBy: string | null;
    resolutionNote: string | null;
    updatedAt: string;
  }> {
    return request(`/openim/admin/reports/${reportId}/resolve`, {
      method: 'PATCH',
      body: JSON.stringify({ status, resolutionNote }),
    });
  },

  getImageModerationJobs(status = 'pending', limit = 20): Promise<ListResult<OpenIMImageModerationJob>> {
    const query = new URLSearchParams({ status, limit: String(limit) });
    return request<ListResult<OpenIMImageModerationJob>>(
      `/openim/admin/image-moderation/jobs?${query.toString()}`
    );
  },

  reviewImageModerationJob(
    jobId: string,
    status: 'approved' | 'rejected',
    reason?: string,
    detail?: string
  ): Promise<{
    id: string;
    status: string;
    reason: string | null;
    reviewedAt: string | null;
    reviewedBy: string | null;
    updatedAt: string;
  }> {
    return request(`/openim/admin/image-moderation/jobs/${jobId}/review`, {
      method: 'PATCH',
      body: JSON.stringify({ status, reason, detail }),
    });
  },

  getWebhooks(limit = 20): Promise<ListResult<OpenIMWebhookEvent>> {
    const query = new URLSearchParams({ limit: String(limit) });
    return request<ListResult<OpenIMWebhookEvent>>(`/openim/admin/webhooks?${query.toString()}`);
  },

  getSyncJobs(limit = 20): Promise<ListResult<OpenIMSyncJob>> {
    const query = new URLSearchParams({ limit: String(limit) });
    return request<ListResult<OpenIMSyncJob>>(`/openim/admin/sync-jobs?${query.toString()}`);
  },

  getAuditLogs(limit = 20): Promise<ListResult<OpenIMAuditLog>> {
    const query = new URLSearchParams({ limit: String(limit) });
    return request<ListResult<OpenIMAuditLog>>(`/openim/admin/audit-logs?${query.toString()}`);
  },
};
