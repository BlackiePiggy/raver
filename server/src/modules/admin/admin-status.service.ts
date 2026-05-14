import { PrismaClient } from '@prisma/client';
import { getCheckinProjectionStatus } from '../../modules/checkins';
import {
  getNotificationCenterAPNSStatus,
  getNotificationOutboxWorkerStatus,
  notificationCenterService,
} from '../../modules/notifications';

const prisma = new PrismaClient();

export type AdminHealthStatus = 'healthy' | 'degraded' | 'critical';

const normalizeWindowHours = (value: unknown, fallback = 24, max = 24 * 30): number => {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) return fallback;
  return Math.min(Math.floor(parsed), max);
};

const mergeStatus = (statuses: AdminHealthStatus[]): AdminHealthStatus => {
  if (statuses.includes('critical')) return 'critical';
  if (statuses.includes('degraded')) return 'degraded';
  return 'healthy';
};

export const adminStatusService = {
  async getStatus(input: { windowHours?: unknown } = {}) {
    const windowHours = normalizeWindowHours(input.windowHours);
    const [delivery, notificationConfig, checkinProjection] = await Promise.all([
      notificationCenterService.fetchDeliveryStats(windowHours),
      notificationCenterService.fetchAdminGlobalConfig(),
      getCheckinProjectionStatus(prisma),
    ]);

    const apns = getNotificationCenterAPNSStatus();
    const outboxWorker = getNotificationOutboxWorkerStatus();
    const notificationStatus: AdminHealthStatus =
      delivery.alerts.triggeredCount > 0 || (apns.enabled && !apns.configured) ? 'degraded' : 'healthy';

    const overallStatus = mergeStatus([notificationStatus, checkinProjection.status]);
    const alertReasons = [
      ...delivery.alerts.items.filter((item) => item.triggered).map((item) => `notification.${item.code}`),
      ...(apns.enabled && !apns.configured ? ['notification.apns_not_configured'] : []),
      ...checkinProjection.alertReasons.map((reason) => `checkin_projection.${reason}`),
    ];

    return {
      checkedAt: new Date(),
      overallStatus,
      alertReasons,
      notification: {
        status: notificationStatus,
        apns,
        delivery,
        config: notificationConfig,
        outboxWorker,
      },
      checkinProjection,
    };
  },
};
