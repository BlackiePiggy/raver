import { NotificationCenterAPNSStatus, NotificationCenterDeliveryStats, NotificationCenterGlobalConfig } from './notification-center-admin';
import { getApiUrl } from '@/lib/config';
import { authenticatedJsonFetch } from '@/lib/auth/authenticated-fetch';

export type AdminHealthStatus = 'healthy' | 'degraded' | 'critical';

export interface NotificationOutboxWorkerStatus {
  asyncModeEnabled: boolean;
  workerEnabled: boolean;
  intervalMs: number;
  eventLimit: number;
  running: boolean;
  inFlight: boolean;
}

export interface CheckinProjectionStatus {
  projectionVersion: number;
  status: AdminHealthStatus;
  dirtyCheckins: number;
  pendingOutbox: number;
  pendingReadyOutbox: number;
  deadOutbox: number;
  projectedUsers: number;
  oldestPendingAvailableAt: string | null;
  oldestPendingCreatedAt: string | null;
  oldestPendingAgeSeconds: number;
  thresholds: {
    criticalPendingAgeSeconds: number;
  };
  alertReasons: string[];
  checkedAt: string;
}

export interface AdminStatus {
  checkedAt: string;
  overallStatus: AdminHealthStatus;
  alertReasons: string[];
  notification: {
    status: AdminHealthStatus;
    apns: NotificationCenterAPNSStatus;
    delivery: NotificationCenterDeliveryStats;
    config: NotificationCenterGlobalConfig;
    outboxWorker: NotificationOutboxWorkerStatus;
  };
  checkinProjection: CheckinProjectionStatus;
  authSms: {
    status: AdminHealthStatus;
    provider: {
      provider: string;
      productionSafe: boolean;
      aliyunConfigured: boolean;
      missingAliyunConfig: string[];
      debugReturnCodeEnabled: boolean;
    };
    firebasePhoneAuth: {
      configured: boolean;
      projectIdConfigured: boolean;
      serviceAccountJsonConfigured: boolean;
      serviceAccountPathConfigured: boolean;
      googleApplicationCredentialsConfigured: boolean;
      mockEnabled: boolean;
    };
    metrics: {
      windowHours: number;
      processStartedAt: string | null;
      totals: {
        attempted: number;
        sent: number;
        failed: number;
        rateLimited: number;
        verifyFailed: number;
        verifyBlocked: number;
      };
      reasons: {
        cooldown: number;
        phoneHourlyLimit: number;
        ipHourlyLimit: number;
        providerError: number;
        invalidOrExpiredCode: number;
        tooManyVerifyFailures: number;
      };
      rates: {
        sendFailureRate: number;
        rateLimitRate: number;
        verifyFailureRate: number;
      };
    };
  };
}

export interface AdminStatusResponse {
  success: boolean;
  status: AdminStatus;
}

export const adminStatusApi = {
  async getStatus(windowHours = 24): Promise<AdminStatus> {
    const query = new URLSearchParams({ windowHours: String(windowHours) });
    const data = await authenticatedJsonFetch<AdminStatusResponse>(getApiUrl(`/admin/v1/status?${query.toString()}`));
    return data.status;
  },
};
