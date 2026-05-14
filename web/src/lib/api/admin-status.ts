import { NotificationCenterAPNSStatus, NotificationCenterDeliveryStats, NotificationCenterGlobalConfig } from './notification-center-admin';
import { getApiUrl } from '@/lib/config';

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
}

export interface AdminStatusResponse {
  success: boolean;
  status: AdminStatus;
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
    return data.error || data.message || `Admin status request failed (${response.status})`;
  } catch {
    return `Admin status request failed (${response.status})`;
  }
};

export const adminStatusApi = {
  async getStatus(windowHours = 24): Promise<AdminStatus> {
    const query = new URLSearchParams({ windowHours: String(windowHours) });
    const response = await fetch(getApiUrl(`/admin/v1/status?${query.toString()}`), {
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${getToken()}`,
      },
    });

    if (!response.ok) {
      throw new Error(await parseError(response));
    }

    const data = (await response.json()) as AdminStatusResponse;
    return data.status;
  },
};
