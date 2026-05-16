import { PrismaClient } from '@prisma/client';
import { getCheckinProjectionStatus } from '../../modules/checkins';
import {
  getNotificationCenterAPNSStatus,
  getNotificationOutboxWorkerStatus,
  notificationCenterService,
} from '../../modules/notifications';
import { getSmsMetrics } from '../../services/sms/sms-metrics';
import { getSmsProviderStatus } from '../../services/sms/sms-provider';
import { getFirebasePhoneAuthStatus } from '../../services/firebase-phone-auth.service';

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
    const smsProvider = getSmsProviderStatus();
    const smsMetrics = getSmsMetrics(windowHours);
    const firebasePhoneAuth = getFirebasePhoneAuthStatus();
    const notificationStatus: AdminHealthStatus =
      delivery.alerts.triggeredCount > 0 || (apns.enabled && !apns.configured) ? 'degraded' : 'healthy';
    const smsStatus: AdminHealthStatus =
      !smsProvider.productionSafe || (smsProvider.provider === 'aliyun' && !smsProvider.aliyunConfigured)
        ? 'critical'
        : smsMetrics.rates.sendFailureRate >= 0.2 || smsMetrics.rates.rateLimitRate >= 0.5
          ? 'degraded'
          : 'healthy';

    const overallStatus = mergeStatus([notificationStatus, checkinProjection.status, smsStatus]);
    const alertReasons = [
      ...delivery.alerts.items.filter((item) => item.triggered).map((item) => `notification.${item.code}`),
      ...(apns.enabled && !apns.configured ? ['notification.apns_not_configured'] : []),
      ...checkinProjection.alertReasons.map((reason) => `checkin_projection.${reason}`),
      ...(smsStatus !== 'healthy' ? ['auth_sms.status_attention'] : []),
      ...smsProvider.missingAliyunConfig.map((key) => `auth_sms.missing_${key.toLowerCase()}`),
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
      authSms: {
        status: smsStatus,
        provider: smsProvider,
        firebasePhoneAuth,
        metrics: smsMetrics,
      },
    };
  },
};
