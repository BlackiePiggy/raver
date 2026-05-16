import { getApiUrl } from '@/lib/config';
import { authenticatedJsonFetch } from '@/lib/auth/authenticated-fetch';

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
  async summary(_token: string): Promise<{ success: true; summary: ContentReportSummary }> {
    return authenticatedJsonFetch<{ success: true; summary: ContentReportSummary }>(
      getApiUrl('/admin/v1/content-reports/summary')
    );
  },

  async alerts(_token: string): Promise<{ success: true; alert: unknown }> {
    return authenticatedJsonFetch<{ success: true; alert: unknown }>(
      getApiUrl('/admin/v1/content-reports/alerts')
    );
  },

  async dailyReport(_token: string): Promise<{ success: true; report: unknown }> {
    return authenticatedJsonFetch<{ success: true; report: unknown }>(
      getApiUrl('/admin/v1/content-reports/daily-report')
    );
  },

  async list(
    _token: string,
    params?: { status?: string; targetType?: string; reason?: string; priority?: string; limit?: number }
  ): Promise<{ success: true; items: AdminContentReport[]; nextCursor: string | null }> {
    return authenticatedJsonFetch<{ success: true; items: AdminContentReport[]; nextCursor: string | null }>(
      getApiUrl(`/admin/v1/content-reports${buildQuery(params)}`)
    );
  },

  async get(_token: string, reportId: string): Promise<{ success: true; report: AdminContentReport }> {
    return authenticatedJsonFetch<{ success: true; report: AdminContentReport }>(
      getApiUrl(`/admin/v1/content-reports/${encodeURIComponent(reportId)}`)
    );
  },

  async decide(
    _token: string,
    reportId: string,
    input: { action: string; note?: string; durationDays?: number }
  ): Promise<{ success: true; report: AdminContentReport; enforcement?: unknown }> {
    return authenticatedJsonFetch<{ success: true; report: AdminContentReport; enforcement?: unknown }>(
      getApiUrl(`/admin/v1/content-reports/${encodeURIComponent(reportId)}/decision`),
      {
        method: 'POST',
        body: JSON.stringify(input),
      }
    );
  },

  async batchDecide(
    _token: string,
    input: { reportIds: string[]; action: 'resolve' | 'dismiss'; note?: string }
  ): Promise<{ success: true; updatedCount: number; items: AdminContentReport[] }> {
    return authenticatedJsonFetch<{ success: true; updatedCount: number; items: AdminContentReport[] }>(
      getApiUrl('/admin/v1/content-reports/batch-decision'),
      {
        method: 'POST',
        body: JSON.stringify(input),
      }
    );
  },

  async listTemplates(
    _token: string,
    params?: { templateKey?: string; locale?: string }
  ): Promise<{ success: true; items: ModerationDecisionTemplate[] }> {
    return authenticatedJsonFetch<{ success: true; items: ModerationDecisionTemplate[] }>(
      getApiUrl(`/admin/v1/content-reports/templates${buildQuery(params)}`)
    );
  },

  async previewTemplate(
    _token: string,
    input: { title: string; body: string; variables?: Record<string, string | number> }
  ): Promise<{ success: true; preview: { title: string; body: string } }> {
    return authenticatedJsonFetch<{ success: true; preview: { title: string; body: string } }>(
      getApiUrl('/admin/v1/content-reports/templates/preview'),
      {
        method: 'POST',
        body: JSON.stringify(input),
      }
    );
  },

  async createTemplate(
    _token: string,
    input: { templateKey: string; locale: string; title: string; body: string }
  ): Promise<{ success: true; item: ModerationDecisionTemplate }> {
    return authenticatedJsonFetch<{ success: true; item: ModerationDecisionTemplate }>(
      getApiUrl('/admin/v1/content-reports/templates'),
      {
        method: 'POST',
        body: JSON.stringify(input),
      }
    );
  },

  async publishTemplate(_token: string, templateId: string): Promise<{ success: true; item: ModerationDecisionTemplate }> {
    return authenticatedJsonFetch<{ success: true; item: ModerationDecisionTemplate }>(
      getApiUrl(`/admin/v1/content-reports/templates/${encodeURIComponent(templateId)}/publish`),
      {
        method: 'POST',
      }
    );
  },

  async rollbackTemplate(_token: string, templateId: string): Promise<{ success: true; item: ModerationDecisionTemplate }> {
    return authenticatedJsonFetch<{ success: true; item: ModerationDecisionTemplate }>(
      getApiUrl(`/admin/v1/content-reports/templates/${encodeURIComponent(templateId)}/rollback`),
      {
        method: 'POST',
      }
    );
  },
};
