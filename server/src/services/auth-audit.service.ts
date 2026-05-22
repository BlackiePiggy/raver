import type { Request } from 'express';
import { Prisma, PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

export type AuthAuditOutcome = 'success' | 'failed' | 'blocked';

export type AuthAuditPayload = {
  action: string;
  outcome: AuthAuditOutcome;
  userId?: string | null;
  identifier?: string | null;
  errorCode?: string | null;
  refreshTokenId?: string | null;
  detail?: Record<string, unknown>;
};

type AuthMetricEvent = {
  at: Date;
  action: string;
  outcome: AuthAuditOutcome;
  errorCode: string | null;
  clientType: string | null;
};

const metricEvents: AuthMetricEvent[] = [];
const maxMetricEvents = 20_000;
const retentionMs = 30 * 24 * 60 * 60 * 1000;

const firstHeaderValue = (value: string | string[] | undefined): string | undefined => {
  if (Array.isArray(value)) return value[0];
  return value;
};

export const getClientIpForAuthAudit = (req: Request): string => {
  const forwarded = req.headers['x-forwarded-for'];
  if (typeof forwarded === 'string' && forwarded.trim()) {
    const first = forwarded.split(',')[0].trim();
    if (first) return first;
  }
  if (Array.isArray(forwarded) && forwarded.length > 0 && forwarded[0].trim()) {
    return forwarded[0].trim();
  }
  return req.socket.remoteAddress || 'unknown';
};

const maskIdentifier = (value: string): string => {
  const trimmed = value.trim();
  if (!trimmed) return 'unknown';
  if (trimmed.length <= 3) return '***';
  return `${trimmed.slice(0, 2)}***${trimmed.slice(-2)}`;
};

const normalizeText = (value: unknown, maxLength: number): string | null => {
  const trimmed = String(value || '').trim();
  if (!trimmed) return null;
  return trimmed.slice(0, maxLength);
};

const safeDetail = (detail: Record<string, unknown> | undefined): Prisma.InputJsonValue | undefined => {
  if (!detail) return undefined;
  const blocked = ['authorization', 'token', 'refreshToken', 'accessToken', 'password', 'idToken'];
  const next: Record<string, Prisma.InputJsonValue> = {};
  for (const [key, value] of Object.entries(detail)) {
    if (blocked.some((blockedKey) => key.toLowerCase().includes(blockedKey.toLowerCase()))) {
      continue;
    }
    if (value === null || ['string', 'number', 'boolean'].includes(typeof value)) {
      next[key.slice(0, 64)] = value as Prisma.InputJsonValue;
    }
  }
  return next;
};

const pruneMetricEvents = (now = Date.now()): void => {
  while (metricEvents.length > 0 && metricEvents[0].at.getTime() < now - retentionMs) {
    metricEvents.shift();
  }
  if (metricEvents.length > maxMetricEvents) {
    metricEvents.splice(0, metricEvents.length - maxMetricEvents);
  }
};

const recordMetric = (event: AuthMetricEvent): void => {
  metricEvents.push(event);
  pruneMetricEvents();
};

const ratio = (part: number, total: number): number => {
  if (total <= 0) return 0;
  return part / total;
};

export const authAuditService = {
  record(req: Request, payload: AuthAuditPayload): void {
    const traceId =
      firstHeaderValue(req.headers['x-request-id']) ||
      firstHeaderValue(req.headers['x-correlation-id']) ||
      null;
    const clientType = normalizeText(firstHeaderValue(req.headers['x-raver-client-type']) ?? payload.detail?.clientType, 64);
    const platform = normalizeText(firstHeaderValue(req.headers['x-raver-platform']) ?? payload.detail?.platform, 64);
    const appVersion = normalizeText(firstHeaderValue(req.headers['x-raver-app-version']) ?? payload.detail?.appVersion, 64);
    const deviceId = normalizeText(firstHeaderValue(req.headers['x-raver-device-id']) ?? payload.detail?.deviceId, 128);
    const deviceName = normalizeText(firstHeaderValue(req.headers['x-raver-device-name']) ?? payload.detail?.deviceName, 128);
    const ip = getClientIpForAuthAudit(req);
    const userAgent = normalizeText(req.headers['user-agent'], 512);
    const maskedIdentifier = payload.identifier ? maskIdentifier(payload.identifier) : null;
    const event = {
      traceId,
      action: payload.action,
      outcome: payload.outcome,
      userId: payload.userId || null,
      identifier: maskedIdentifier,
      errorCode: payload.errorCode || null,
      refreshTokenId: payload.refreshTokenId || null,
      clientType,
      platform,
      appVersion,
      deviceId,
      deviceName,
      ip,
      userAgent,
      ...(payload.detail || {}),
    };

    console.info('[auth-audit]', event);
    recordMetric({
      at: new Date(),
      action: payload.action,
      outcome: payload.outcome,
      errorCode: payload.errorCode || null,
      clientType,
    });

    void prisma.authAuditLog.create({
      data: {
        traceId,
        action: payload.action,
        outcome: payload.outcome,
        userId: payload.userId || null,
        identifierMasked: maskedIdentifier,
        errorCode: payload.errorCode || null,
        refreshTokenId: payload.refreshTokenId || null,
        clientType,
        platform,
        appVersion,
        deviceId,
        deviceName,
        ipAddress: ip,
        userAgent,
        detail: safeDetail(payload.detail),
      },
      select: { id: true },
    }).catch((error) => {
      console.warn('[auth-audit] persist failed', error instanceof Error ? error.message : String(error));
    });
  },

  getMetrics(windowHours = 24) {
    const now = Date.now();
    pruneMetricEvents(now);
    const normalizedWindowHours = Math.max(1, Math.min(Math.floor(windowHours), 24 * 30));
    const windowMs = normalizedWindowHours * 60 * 60 * 1000;
    const events = metricEvents.filter((event) => event.at.getTime() >= now - windowMs);
    const count = (predicate: (event: AuthMetricEvent) => boolean): number => events.filter(predicate).length;
    const refreshTotal = count((event) => event.action === 'auth.refresh');
    const refreshSuccess = count((event) => event.action === 'auth.refresh' && event.outcome === 'success');
    const refreshFailed = count((event) => event.action === 'auth.refresh' && event.outcome !== 'success');
    const refreshHardExpiry = count((event) =>
      event.action === 'auth.refresh'
      && ['AUTH_REFRESH_TOKEN_INVALID_OR_EXPIRED', 'AUTH_SESSION_REVOKED', 'AUTH_SESSION_ABSOLUTE_EXPIRED', 'AUTH_SESSION_IDLE_EXPIRED'].includes(event.errorCode || '')
    );
    const accountInactive = count((event) => event.errorCode === 'AUTH_ACCOUNT_INACTIVE');

    const byErrorCode: Record<string, number> = {};
    const byClientType: Record<string, number> = {};
    for (const event of events) {
      if (event.errorCode) {
        byErrorCode[event.errorCode] = (byErrorCode[event.errorCode] || 0) + 1;
      }
      const clientType = event.clientType || 'unknown';
      byClientType[clientType] = (byClientType[clientType] || 0) + 1;
    }

    return {
      windowHours: normalizedWindowHours,
      processStartedAt: process.uptime() > 0 ? new Date(now - process.uptime() * 1000) : null,
      totals: {
        events: events.length,
        refreshTotal,
        refreshSuccess,
        refreshFailed,
        refreshHardExpiry,
        accountInactive,
      },
      rates: {
        refreshSuccessRate: ratio(refreshSuccess, refreshTotal),
        refreshFailureRate: ratio(refreshFailed, refreshTotal),
        hardExpiryRate: ratio(refreshHardExpiry, refreshTotal),
      },
      byErrorCode,
      byClientType,
    };
  },

  async listLogs(input: {
    limit?: number;
    userId?: string;
    action?: string;
    outcome?: AuthAuditOutcome;
    errorCode?: string;
    clientType?: string;
    before?: Date;
  } = {}) {
    const limit = Math.max(1, Math.min(Math.floor(input.limit || 100), 200));
    const where: Prisma.AuthAuditLogWhereInput = {};
    if (input.userId) where.userId = input.userId;
    if (input.action) where.action = input.action;
    if (input.outcome) where.outcome = input.outcome;
    if (input.errorCode) where.errorCode = input.errorCode;
    if (input.clientType) where.clientType = input.clientType;
    if (input.before && !Number.isNaN(input.before.getTime())) {
      where.createdAt = { lt: input.before };
    }
    const items = await prisma.authAuditLog.findMany({
      where,
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
    });
    const pageItems = items.slice(0, limit);
    return {
      items: pageItems.map((item) => ({
        ...item,
        createdAt: item.createdAt.toISOString(),
      })),
      nextCursor: items.length > limit ? pageItems[pageItems.length - 1]?.createdAt.toISOString() ?? null : null,
    };
  },
};
