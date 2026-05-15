import { getApiUrl } from '@/lib/config';

export interface ContentReportUser {
  id: string;
  username: string;
  displayName: string | null;
  avatarUrl: string | null;
}

export interface AdminContentReport {
  id: string;
  reporterUserId: string;
  targetType: string;
  targetId: string;
  targetUserId: string | null;
  reason: string;
  detail: string | null;
  attachments?: Array<{ type?: string | null; url?: string | null; label?: string | null }> | null;
  source: string;
  status: string;
  metadata?: unknown;
  resolvedAt: string | null;
  resolvedBy: string | null;
  resolutionNote: string | null;
  createdAt: string;
  updatedAt: string;
  reporter?: ContentReportUser | null;
  targetUser?: ContentReportUser | null;
  priority?: 'high' | 'medium' | 'normal';
  slaDueAt?: string;
  isOverdue?: boolean;
  reportCountForTarget?: number;
  targetPreview?: unknown;
  context?: unknown;
  similarReports?: AdminContentReport[];
  targetHistory?: AdminContentReport[];
  enforcementHistory?: unknown[];
  appealHistory?: unknown[];
  copyrightStats?: {
    resolvedCopyrightCount: number;
    repeatInfringerThreshold: number;
    repeatInfringer: boolean;
    activeTargetTakedowns: number;
  } | null;
}

export interface ContentReportSummary {
  pendingCount: number;
  overdueCount: number;
  highPriorityPendingCount: number;
  oldestPendingAt: string | null;
  byStatus: Array<{ status: string; count: number }>;
  byReason: Array<{ reason: string; count: number }>;
  byType: Array<{ targetType: string; count: number }>;
}

export interface ModerationDecisionTemplate {
  id: string;
  templateKey: string;
  locale: string;
  title: string;
  body: string;
  status: string;
  version: number;
  publishedAt: string | null;
  publishedBy: string | null;
  createdAt: string;
  updatedAt: string;
}

const parseError = async (response: Response): Promise<string> => {
  try {
    const data = await response.json();
    return data.error || data.message || `Content report request failed (${response.status})`;
  } catch {
    return `Content report request failed (${response.status})`;
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

export const contentReportsApi = {
  async summary(token: string): Promise<{ success: true; summary: ContentReportSummary }> {
    const response = await fetch(getApiUrl('/admin/v1/content-reports/summary'), {
      headers: authHeaders(token),
    });
    if (!response.ok) throw new Error(await parseError(response));
    return response.json();
  },

  async alerts(token: string): Promise<{ success: true; alert: unknown }> {
    const response = await fetch(getApiUrl('/admin/v1/content-reports/alerts'), {
      headers: authHeaders(token),
    });
    if (!response.ok) throw new Error(await parseError(response));
    return response.json();
  },

  async dailyReport(token: string): Promise<{ success: true; report: unknown }> {
    const response = await fetch(getApiUrl('/admin/v1/content-reports/daily-report'), {
      headers: authHeaders(token),
    });
    if (!response.ok) throw new Error(await parseError(response));
    return response.json();
  },

  async list(
    token: string,
    params?: { status?: string; targetType?: string; reason?: string; priority?: string; limit?: number }
  ): Promise<{ success: true; items: AdminContentReport[]; nextCursor: string | null }> {
    const response = await fetch(getApiUrl(`/admin/v1/content-reports${buildQuery(params)}`), {
      headers: authHeaders(token),
    });
    if (!response.ok) throw new Error(await parseError(response));
    return response.json();
  },

  async get(token: string, reportId: string): Promise<{ success: true; report: AdminContentReport }> {
    const response = await fetch(getApiUrl(`/admin/v1/content-reports/${encodeURIComponent(reportId)}`), {
      headers: authHeaders(token),
    });
    if (!response.ok) throw new Error(await parseError(response));
    return response.json();
  },

  async decide(
    token: string,
    reportId: string,
    input: { action: string; note?: string; durationDays?: number }
  ): Promise<{ success: true; report: AdminContentReport; enforcement?: unknown }> {
    const response = await fetch(getApiUrl(`/admin/v1/content-reports/${encodeURIComponent(reportId)}/decision`), {
      method: 'POST',
      headers: authHeaders(token),
      body: JSON.stringify(input),
    });
    if (!response.ok) throw new Error(await parseError(response));
    return response.json();
  },

  async batchDecide(
    token: string,
    input: { reportIds: string[]; action: 'resolve' | 'dismiss'; note?: string }
  ): Promise<{ success: true; updatedCount: number; items: AdminContentReport[] }> {
    const response = await fetch(getApiUrl('/admin/v1/content-reports/batch-decision'), {
      method: 'POST',
      headers: authHeaders(token),
      body: JSON.stringify(input),
    });
    if (!response.ok) throw new Error(await parseError(response));
    return response.json();
  },

  async listTemplates(
    token: string,
    params?: { templateKey?: string; locale?: string }
  ): Promise<{ success: true; items: ModerationDecisionTemplate[] }> {
    const response = await fetch(getApiUrl(`/admin/v1/content-reports/templates${buildQuery(params)}`), {
      headers: authHeaders(token),
    });
    if (!response.ok) throw new Error(await parseError(response));
    return response.json();
  },

  async previewTemplate(
    token: string,
    input: { title: string; body: string; variables?: Record<string, string | number> }
  ): Promise<{ success: true; preview: { title: string; body: string } }> {
    const response = await fetch(getApiUrl('/admin/v1/content-reports/templates/preview'), {
      method: 'POST',
      headers: authHeaders(token),
      body: JSON.stringify(input),
    });
    if (!response.ok) throw new Error(await parseError(response));
    return response.json();
  },

  async createTemplate(
    token: string,
    input: { templateKey: string; locale: string; title: string; body: string }
  ): Promise<{ success: true; item: ModerationDecisionTemplate }> {
    const response = await fetch(getApiUrl('/admin/v1/content-reports/templates'), {
      method: 'POST',
      headers: authHeaders(token),
      body: JSON.stringify(input),
    });
    if (!response.ok) throw new Error(await parseError(response));
    return response.json();
  },

  async publishTemplate(token: string, templateId: string): Promise<{ success: true; item: ModerationDecisionTemplate }> {
    const response = await fetch(getApiUrl(`/admin/v1/content-reports/templates/${encodeURIComponent(templateId)}/publish`), {
      method: 'POST',
      headers: authHeaders(token),
    });
    if (!response.ok) throw new Error(await parseError(response));
    return response.json();
  },

  async rollbackTemplate(token: string, templateId: string): Promise<{ success: true; item: ModerationDecisionTemplate }> {
    const response = await fetch(getApiUrl(`/admin/v1/content-reports/templates/${encodeURIComponent(templateId)}/rollback`), {
      method: 'POST',
      headers: authHeaders(token),
    });
    if (!response.ok) throw new Error(await parseError(response));
    return response.json();
  },
};
