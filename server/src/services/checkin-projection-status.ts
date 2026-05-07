import { PrismaClient } from '@prisma/client';
import { CHECKIN_PROJECTION_VERSION } from './checkin-projection';

export type CheckinProjectionHealthStatus = 'healthy' | 'degraded' | 'critical';

export type CheckinProjectionStatusThresholds = {
  criticalPendingAgeSeconds: number;
};

export type CheckinProjectionStatusReport = {
  projectionVersion: number;
  status: CheckinProjectionHealthStatus;
  dirtyCheckins: number;
  pendingOutbox: number;
  pendingReadyOutbox: number;
  deadOutbox: number;
  projectedUsers: number;
  oldestPendingAvailableAt: Date | null;
  oldestPendingCreatedAt: Date | null;
  oldestPendingAgeSeconds: number;
  thresholds: CheckinProjectionStatusThresholds;
  alertReasons: string[];
  checkedAt: Date;
};

const DEFAULT_THRESHOLDS: CheckinProjectionStatusThresholds = {
  criticalPendingAgeSeconds: 15 * 60,
};

export const getCheckinProjectionStatus = async (
  prisma: PrismaClient,
  thresholds: Partial<CheckinProjectionStatusThresholds> = {}
): Promise<CheckinProjectionStatusReport> => {
  const now = new Date();
  const normalizedThresholds = {
    ...DEFAULT_THRESHOLDS,
    ...thresholds,
  };

  const [dirtyCheckins, pendingOutbox, pendingReadyOutbox, deadOutbox, oldestPending, projectedUsers] =
    await Promise.all([
      prisma.checkin.count({
        where: {
          status: 'active',
          projectionVersion: { lt: CHECKIN_PROJECTION_VERSION },
        },
      }),
      prisma.checkinOutboxEvent.count({
        where: { status: 'pending' },
      }),
      prisma.checkinOutboxEvent.count({
        where: {
          status: 'pending',
          availableAt: { lte: now },
        },
      }),
      prisma.checkinOutboxEvent.count({
        where: { status: 'dead' },
      }),
      prisma.checkinOutboxEvent.findFirst({
        where: { status: 'pending' },
        orderBy: [{ availableAt: 'asc' }, { createdAt: 'asc' }],
        select: { availableAt: true, createdAt: true },
      }),
      prisma.userCheckinStat.count(),
    ]);

  const oldestPendingAgeSeconds = oldestPending
    ? Math.max(0, Math.floor((now.getTime() - oldestPending.createdAt.getTime()) / 1000))
    : 0;

  const alertReasons: string[] = [];
  if (deadOutbox > 0) {
    alertReasons.push('dead_outbox_exists');
  }
  if (oldestPendingAgeSeconds >= normalizedThresholds.criticalPendingAgeSeconds) {
    alertReasons.push('pending_outbox_too_old');
  }
  if (dirtyCheckins > 0) {
    alertReasons.push('dirty_checkins_exists');
  }
  if (pendingOutbox > 0) {
    alertReasons.push('pending_outbox_exists');
  }

  const status: CheckinProjectionHealthStatus =
    deadOutbox > 0 || oldestPendingAgeSeconds >= normalizedThresholds.criticalPendingAgeSeconds
      ? 'critical'
      : dirtyCheckins > 0 || pendingOutbox > 0
        ? 'degraded'
        : 'healthy';

  return {
    projectionVersion: CHECKIN_PROJECTION_VERSION,
    status,
    dirtyCheckins,
    pendingOutbox,
    pendingReadyOutbox,
    deadOutbox,
    projectedUsers,
    oldestPendingAvailableAt: oldestPending?.availableAt ?? null,
    oldestPendingCreatedAt: oldestPending?.createdAt ?? null,
    oldestPendingAgeSeconds,
    thresholds: normalizedThresholds,
    alertReasons,
    checkedAt: now,
  };
};

export const checkinProjectionStatusExitCode = (status: CheckinProjectionHealthStatus): number => {
  if (status === 'critical') return 2;
  if (status === 'degraded') return 1;
  return 0;
};
