import { PrismaClient } from '@prisma/client';
import { notificationCenterService, type EventCountdownPreference } from './notification-center.service';

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
  enabled: readBooleanEnv('NOTIFICATION_EVENT_COUNTDOWN_ENABLED', false),
  intervalMs: readPositiveIntegerEnv('NOTIFICATION_EVENT_COUNTDOWN_INTERVAL_MS', 5 * 60 * 1000),
  maxDaysBeforeStart: readPositiveIntegerEnv('NOTIFICATION_EVENT_COUNTDOWN_MAX_DAYS', 60),
};

type LocalDateParts = {
  year: number;
  month: number;
  day: number;
  hour: number;
};

const toTwoDigits = (value: number): string => value.toString().padStart(2, '0');

const getLocalDateParts = (date: Date, timezone: string): LocalDateParts => {
  const formatter = new Intl.DateTimeFormat('en-US', {
    timeZone: timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    hour12: false,
  });

  const parts = formatter.formatToParts(date);
  const readPart = (type: Intl.DateTimeFormatPartTypes): number => {
    const value = parts.find((item) => item.type === type)?.value || '';
    return Number(value);
  };

  return {
    year: readPart('year'),
    month: readPart('month'),
    day: readPart('day'),
    hour: readPart('hour'),
  };
};

const getDayIndex = (parts: LocalDateParts): number => {
  return Math.floor(Date.UTC(parts.year, parts.month - 1, parts.day) / (24 * 60 * 60 * 1000));
};

const formatLocalDateKey = (parts: LocalDateParts): string => {
  return `${parts.year}-${toTwoDigits(parts.month)}-${toTwoDigits(parts.day)}`;
};

const buildEventCountdownMessage = (input: {
  eventName: string;
  eventStartDate: Date;
  daysLeft: number;
  timezone: string;
}): { title: string; body: string } => {
  const localEventParts = getLocalDateParts(input.eventStartDate, input.timezone);
  const eventDate = `${localEventParts.year}-${toTwoDigits(localEventParts.month)}-${toTwoDigits(localEventParts.day)}`;
  if (input.daysLeft <= 0) {
    return {
      title: `${input.eventName} 今天开始`,
      body: `${eventDate} 开始，别错过了`,
    };
  }
  return {
    title: `${input.eventName} 倒计时 ${input.daysLeft} 天`,
    body: `${eventDate} 开始，提前安排你的行程`,
  };
};

export type EventCountdownJobReport = {
  executedAt: string;
  enabled: boolean;
  candidateUsers: number;
  candidateEvents: number;
  skippedByPreference: number;
  skippedByHourWindow: number;
  skippedByCountdownWindow: number;
  attemptedPublishes: number;
  sentPublishes: number;
  dedupeSkippedPublishes: number;
  failedPublishes: number;
};

let schedulerTimer: NodeJS.Timeout | null = null;
let running = false;

const resolvePreferenceMap = async (userIds: string[]): Promise<Map<string, EventCountdownPreference>> => {
  const rows = await notificationCenterService.fetchEventCountdownSubscriptions(userIds);
  return new Map(rows.map((item) => [item.userId, item.preference]));
};

export const runEventCountdownJob = async (): Promise<EventCountdownJobReport> => {
  const executedAt = new Date();
  if (!SCHEDULER_CONFIG.enabled) {
    return {
      executedAt: executedAt.toISOString(),
      enabled: false,
      candidateUsers: 0,
      candidateEvents: 0,
      skippedByPreference: 0,
      skippedByHourWindow: 0,
      skippedByCountdownWindow: 0,
      attemptedPublishes: 0,
      sentPublishes: 0,
      dedupeSkippedPublishes: 0,
      failedPublishes: 0,
    };
  }

  const now = executedAt;
  const until = new Date(now.getTime() + (SCHEDULER_CONFIG.maxDaysBeforeStart + 1) * 24 * 60 * 60 * 1000);
  const userRows = await prisma.checkin.findMany({
    where: {
      type: 'event',
      note: 'marked',
      eventId: {
        not: null,
      },
      event: {
        startDate: {
          gte: now,
          lte: until,
        },
      },
    },
    select: {
      userId: true,
    },
    distinct: ['userId'],
  });
  const candidateUserIds = userRows.map((item) => item.userId.trim()).filter(Boolean);
  if (candidateUserIds.length === 0) {
    return {
      executedAt: executedAt.toISOString(),
      enabled: true,
      candidateUsers: 0,
      candidateEvents: 0,
      skippedByPreference: 0,
      skippedByHourWindow: 0,
      skippedByCountdownWindow: 0,
      attemptedPublishes: 0,
      sentPublishes: 0,
      dedupeSkippedPublishes: 0,
      failedPublishes: 0,
    };
  }

  const [preferenceMap, candidateEvents] = await Promise.all([
    resolvePreferenceMap(candidateUserIds),
    notificationCenterService.fetchMarkedEventCountdownCandidates({
      userIds: candidateUserIds,
      maxDaysBeforeStart: SCHEDULER_CONFIG.maxDaysBeforeStart,
    }),
  ]);

  const eventsByUser = new Map<string, Array<(typeof candidateEvents)[number]>>();
  for (const item of candidateEvents) {
    const current = eventsByUser.get(item.userId) ?? [];
    current.push(item);
    eventsByUser.set(item.userId, current);
  }

  let skippedByPreference = 0;
  let skippedByHourWindow = 0;
  let skippedByCountdownWindow = 0;
  let attemptedPublishes = 0;
  let sentPublishes = 0;
  let dedupeSkippedPublishes = 0;
  let failedPublishes = 0;

  for (const userId of candidateUserIds) {
    const preference = preferenceMap.get(userId) ?? {
      enabled: true,
      daysBeforeStart: 3,
      reminderHours: [10],
      timezone: 'UTC',
      channels: ['in_app', 'apns'],
    };
    if (!preference.enabled) {
      skippedByPreference += (eventsByUser.get(userId) ?? []).length;
      continue;
    }

    const nowParts = getLocalDateParts(now, preference.timezone);
    if (!preference.reminderHours.includes(nowParts.hour)) {
      skippedByHourWindow += (eventsByUser.get(userId) ?? []).length;
      continue;
    }

    const userEvents = eventsByUser.get(userId) ?? [];
    for (const item of userEvents) {
      const eventParts = getLocalDateParts(item.eventStartDate, preference.timezone);
      const daysLeft = getDayIndex(eventParts) - getDayIndex(nowParts);
      if (daysLeft < 0 || daysLeft > preference.daysBeforeStart) {
        skippedByCountdownWindow += 1;
        continue;
      }

      attemptedPublishes += 1;
      const dedupeKey = `event_countdown:${userId}:${item.eventId}:${formatLocalDateKey(nowParts)}:${toTwoDigits(nowParts.hour)}`;
      const message = buildEventCountdownMessage({
        eventName: item.eventName,
        eventStartDate: item.eventStartDate,
        daysLeft,
        timezone: preference.timezone,
      });

      try {
        const result = await notificationCenterService.publish({
          category: 'event_countdown',
          targets: [{ userId }],
          channels: preference.channels,
          dedupeKey,
          payload: {
            title: message.title,
            body: message.body,
            deeplink: `raver://event/${item.eventId}`,
            metadata: {
              eventId: item.eventId,
              eventName: item.eventName,
              eventStartDate: item.eventStartDate.toISOString(),
              daysLeft,
              timezone: preference.timezone,
              source: 'event_countdown_scheduler',
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
        const message = error instanceof Error ? error.message : String(error);
        console.error(`[notification-center][event-countdown] publish failed user=${userId} event=${item.eventId} error=${message}`);
      }
    }
  }

  return {
    executedAt: executedAt.toISOString(),
    enabled: true,
    candidateUsers: candidateUserIds.length,
    candidateEvents: candidateEvents.length,
    skippedByPreference,
    skippedByHourWindow,
    skippedByCountdownWindow,
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
    const report = await runEventCountdownJob();
    console.log(
      `[notification-center][event-countdown] run completed enabled=${report.enabled} users=${report.candidateUsers} events=${report.candidateEvents} attempted=${report.attemptedPublishes} sent=${report.sentPublishes} dedupe=${report.dedupeSkippedPublishes} failed=${report.failedPublishes}`
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error(`[notification-center][event-countdown] run failed: ${message}`);
  } finally {
    running = false;
  }
};

export const startNotificationEventCountdownScheduler = (): void => {
  if (!SCHEDULER_CONFIG.enabled) {
    console.log('[notification-center][event-countdown] scheduler disabled');
    return;
  }

  if (schedulerTimer) {
    return;
  }

  console.log(`[notification-center][event-countdown] scheduler started intervalMs=${SCHEDULER_CONFIG.intervalMs}`);
  void runOnceSafely();
  schedulerTimer = setInterval(() => {
    void runOnceSafely();
  }, SCHEDULER_CONFIG.intervalMs);
};

export const stopNotificationEventCountdownScheduler = (): void => {
  if (!schedulerTimer) {
    return;
  }
  clearInterval(schedulerTimer);
  schedulerTimer = null;
  console.log('[notification-center][event-countdown] scheduler stopped');
};
