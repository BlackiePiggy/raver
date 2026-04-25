import { PrismaClient } from '@prisma/client';
import { notificationCenterService, type RouteDJReminderPreference } from './notification-center.service';

const prisma = new PrismaClient();

const readEnv = (key: string): string => String(process.env[key] || '').trim();
const readBooleanEnv = (key: string, fallback = false): boolean => {
  const value = readEnv(key).toLowerCase();
  if (!value) return fallback;
  if (value === '1' || value === 'true' || value === 'yes') return true;
  if (value === '0' || value === 'false' || value === 'no') return false;
  return fallback;
};

const readPositiveIntegerEnv = (key: string, fallback: number): number => {
  const value = Number(readEnv(key));
  if (!Number.isFinite(value)) return fallback;
  const normalized = Math.floor(value);
  if (normalized < 1) return fallback;
  return normalized;
};

const SCHEDULER_CONFIG = {
  enabled: readBooleanEnv('NOTIFICATION_ROUTE_DJ_REMINDER_ENABLED', false),
  intervalMs: readPositiveIntegerEnv('NOTIFICATION_ROUTE_DJ_REMINDER_INTERVAL_MS', 60 * 1000),
  lookAheadMinutes: readPositiveIntegerEnv('NOTIFICATION_ROUTE_DJ_REMINDER_LOOKAHEAD_MINUTES', 180),
  triggerWindowMinutes: readPositiveIntegerEnv('NOTIFICATION_ROUTE_DJ_REMINDER_TRIGGER_WINDOW_MINUTES', 3),
};

export type RouteDJReminderJobReport = {
  executedAt: string;
  enabled: boolean;
  candidateUsers: number;
  candidateSlots: number;
  skippedByPreference: number;
  skippedByMissingSlot: number;
  skippedByTimeWindow: number;
  attemptedPublishes: number;
  sentPublishes: number;
  dedupeSkippedPublishes: number;
  failedPublishes: number;
};

let schedulerTimer: NodeJS.Timeout | null = null;
let running = false;

const resolveSubscriptionMap = async (): Promise<Map<string, RouteDJReminderPreference>> => {
  const rows = await notificationCenterService.fetchRouteDJReminderSubscriptions();
  return new Map(rows.map((item) => [item.userId, item.preference]));
};

const buildReminderMessage = (input: {
  eventName: string;
  djName: string;
  stageName?: string | null;
  minutesUntilStart: number;
}): { title: string; body: string } => {
  const stageText = input.stageName?.trim() ? ` · ${input.stageName.trim()}` : '';
  return {
    title: `${input.djName} 即将上台`,
    body: `${input.eventName}${stageText} · ${input.minutesUntilStart} 分钟后开始`,
  };
};

export const runRouteDJReminderJob = async (): Promise<RouteDJReminderJobReport> => {
  const executedAt = new Date();
  if (!SCHEDULER_CONFIG.enabled) {
    return {
      executedAt: executedAt.toISOString(),
      enabled: false,
      candidateUsers: 0,
      candidateSlots: 0,
      skippedByPreference: 0,
      skippedByMissingSlot: 0,
      skippedByTimeWindow: 0,
      attemptedPublishes: 0,
      sentPublishes: 0,
      dedupeSkippedPublishes: 0,
      failedPublishes: 0,
    };
  }

  const now = executedAt;
  const lookAhead = new Date(now.getTime() + SCHEDULER_CONFIG.lookAheadMinutes * 60 * 1000);
  const subscriptionMap = await resolveSubscriptionMap();
  const candidateUsers = Array.from(subscriptionMap.keys());
  if (candidateUsers.length === 0) {
    return {
      executedAt: executedAt.toISOString(),
      enabled: true,
      candidateUsers: 0,
      candidateSlots: 0,
      skippedByPreference: 0,
      skippedByMissingSlot: 0,
      skippedByTimeWindow: 0,
      attemptedPublishes: 0,
      sentPublishes: 0,
      dedupeSkippedPublishes: 0,
      failedPublishes: 0,
    };
  }

  const watchedSlots = candidateUsers.flatMap((userId) => {
    const preference = subscriptionMap.get(userId);
    return (preference?.watchedSlots ?? []).map((slot) => ({
      userId,
      eventId: slot.eventId,
      slotId: slot.slotId,
      reminderMinutesBefore: slot.reminderMinutesBefore ?? preference?.defaultReminderMinutesBefore ?? 30,
    }));
  });
  const slotIds = Array.from(new Set(watchedSlots.map((item) => item.slotId)));
  const slotRows = slotIds.length
    ? await prisma.eventLineupSlot.findMany({
        where: {
          id: {
            in: slotIds,
          },
          startTime: {
            gte: now,
            lte: lookAhead,
          },
        },
        select: {
          id: true,
          eventId: true,
          djName: true,
          stageName: true,
          startTime: true,
          event: {
            select: {
              id: true,
              name: true,
            },
          },
          dj: {
            select: {
              id: true,
              name: true,
            },
          },
        },
      })
    : [];
  const slotMap = new Map(slotRows.map((item) => [item.id, item]));

  let skippedByPreference = 0;
  let skippedByMissingSlot = 0;
  let skippedByTimeWindow = 0;
  let attemptedPublishes = 0;
  let sentPublishes = 0;
  let dedupeSkippedPublishes = 0;
  let failedPublishes = 0;

  for (const watch of watchedSlots) {
    const preference = subscriptionMap.get(watch.userId);
    if (!preference || !preference.enabled) {
      skippedByPreference += 1;
      continue;
    }

    const slot = slotMap.get(watch.slotId);
    if (!slot || slot.eventId !== watch.eventId) {
      skippedByMissingSlot += 1;
      continue;
    }

    const minutesUntilStart = Math.floor((slot.startTime.getTime() - now.getTime()) / (60 * 1000));
    const lowerBound = Math.max(0, watch.reminderMinutesBefore - SCHEDULER_CONFIG.triggerWindowMinutes);
    if (minutesUntilStart > watch.reminderMinutesBefore || minutesUntilStart < lowerBound) {
      skippedByTimeWindow += 1;
      continue;
    }

    attemptedPublishes += 1;
    const message = buildReminderMessage({
      eventName: slot.event.name,
      djName: slot.dj?.name || slot.djName,
      stageName: slot.stageName,
      minutesUntilStart,
    });
    const dedupeKey = `route_dj_reminder:${watch.userId}:${slot.id}:${watch.reminderMinutesBefore}`;

    try {
      const result = await notificationCenterService.publish({
        category: 'route_dj_reminder',
        targets: [{ userId: watch.userId }],
        channels: preference.channels,
        dedupeKey,
        payload: {
          title: message.title,
          body: message.body,
          deeplink: `raver://event/${slot.event.id}`,
          metadata: {
            eventId: slot.event.id,
            eventName: slot.event.name,
            slotId: slot.id,
            slotStartTime: slot.startTime.toISOString(),
            stageName: slot.stageName,
            djId: slot.dj?.id || null,
            djName: slot.dj?.name || slot.djName,
            minutesUntilStart,
            reminderMinutesBefore: watch.reminderMinutesBefore,
            source: 'route_dj_reminder_scheduler',
          },
        },
      });

      const dedupeSkipped = result.some((row) => (row.detail || '').startsWith('dedupe-skipped:'));
      if (dedupeSkipped) {
        dedupeSkippedPublishes += 1;
        continue;
      }

      const hasSuccess = result.some((row) => row.success);
      if (hasSuccess) {
        sentPublishes += 1;
      } else {
        failedPublishes += 1;
      }
    } catch (error) {
      failedPublishes += 1;
      const messageText = error instanceof Error ? error.message : String(error);
      console.error(
        `[notification-center][route-dj-reminder] publish failed user=${watch.userId} event=${watch.eventId} slot=${watch.slotId} error=${messageText}`
      );
    }
  }

  return {
    executedAt: executedAt.toISOString(),
    enabled: true,
    candidateUsers: candidateUsers.length,
    candidateSlots: watchedSlots.length,
    skippedByPreference,
    skippedByMissingSlot,
    skippedByTimeWindow,
    attemptedPublishes,
    sentPublishes,
    dedupeSkippedPublishes,
    failedPublishes,
  };
};

const runOnceSafely = async (): Promise<void> => {
  if (running) {
    return;
  }
  running = true;
  try {
    const report = await runRouteDJReminderJob();
    console.log(
      `[notification-center][route-dj-reminder] run completed enabled=${report.enabled} users=${report.candidateUsers} slots=${report.candidateSlots} attempted=${report.attemptedPublishes} sent=${report.sentPublishes} dedupe=${report.dedupeSkippedPublishes} failed=${report.failedPublishes}`
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error(`[notification-center][route-dj-reminder] run failed: ${message}`);
  } finally {
    running = false;
  }
};

export const startNotificationRouteDJReminderScheduler = (): void => {
  if (!SCHEDULER_CONFIG.enabled) {
    console.log('[notification-center][route-dj-reminder] scheduler disabled');
    return;
  }
  if (schedulerTimer) {
    return;
  }
  console.log(`[notification-center][route-dj-reminder] scheduler started intervalMs=${SCHEDULER_CONFIG.intervalMs}`);
  void runOnceSafely();
  schedulerTimer = setInterval(() => {
    void runOnceSafely();
  }, SCHEDULER_CONFIG.intervalMs);
};

export const stopNotificationRouteDJReminderScheduler = (): void => {
  if (!schedulerTimer) {
    return;
  }
  clearInterval(schedulerTimer);
  schedulerTimer = null;
  console.log('[notification-center][route-dj-reminder] scheduler stopped');
};
