import { PrismaClient } from '@prisma/client';
import { notificationCenterService, type EventDailyDigestPreference } from './notification-center.service';

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
  enabled: readBooleanEnv('NOTIFICATION_EVENT_DAILY_DIGEST_ENABLED', false),
  intervalMs: readPositiveIntegerEnv('NOTIFICATION_EVENT_DAILY_DIGEST_INTERVAL_MS', 10 * 60 * 1000),
  maxDaysBeforeStart: readPositiveIntegerEnv('NOTIFICATION_EVENT_DAILY_DIGEST_MAX_DAYS_BEFORE_START', 60),
  maxDaysAfterEnd: readPositiveIntegerEnv('NOTIFICATION_EVENT_DAILY_DIGEST_MAX_DAYS_AFTER_END', 1),
  lookbackHours: readPositiveIntegerEnv('NOTIFICATION_EVENT_DAILY_DIGEST_LOOKBACK_HOURS', 24),
};

type LocalDateParts = {
  year: number;
  month: number;
  day: number;
  hour: number;
};

export type EventDailyDigestJobReport = {
  executedAt: string;
  enabled: boolean;
  candidateUsers: number;
  candidateEvents: number;
  skippedByPreference: number;
  skippedByHourWindow: number;
  skippedByNoSignal: number;
  attemptedPublishes: number;
  sentPublishes: number;
  dedupeSkippedPublishes: number;
  failedPublishes: number;
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

const formatLocalDateKey = (parts: LocalDateParts): string => {
  return `${parts.year}-${toTwoDigits(parts.month)}-${toTwoDigits(parts.day)}`;
};

const getDayIndex = (parts: LocalDateParts): number => {
  return Math.floor(Date.UTC(parts.year, parts.month - 1, parts.day) / (24 * 60 * 60 * 1000));
};

const resolvePreferenceMap = async (userIds: string[]): Promise<Map<string, EventDailyDigestPreference>> => {
  const rows = await notificationCenterService.fetchEventDailyDigestSubscriptions(userIds);
  return new Map(rows.map((item) => [item.userId, item.preference]));
};

const resolveNewsCountMap = async (eventIds: string[], since: Date): Promise<Map<string, number>> => {
  if (eventIds.length === 0) {
    return new Map();
  }
  const grouped = await prisma.post.groupBy({
    by: ['eventId'],
    where: {
      eventId: {
        in: eventIds,
      },
      createdAt: {
        gte: since,
      },
    },
    _count: {
      _all: true,
    },
  });
  const countMap = new Map<string, number>();
  for (const row of grouped) {
    const eventId = row.eventId?.trim();
    if (!eventId) {
      continue;
    }
    countMap.set(eventId, row._count._all);
  }
  return countMap;
};

const resolveRatingCountMap = async (eventIds: string[], since: Date): Promise<Map<string, number>> => {
  if (eventIds.length === 0) {
    return new Map();
  }
  const grouped = await prisma.checkin.groupBy({
    by: ['eventId'],
    where: {
      eventId: {
        in: eventIds,
      },
      type: 'event',
      rating: {
        not: null,
      },
      note: {
        not: 'marked',
      },
      createdAt: {
        gte: since,
      },
    },
    _count: {
      _all: true,
    },
  });
  const countMap = new Map<string, number>();
  for (const row of grouped) {
    const eventId = row.eventId?.trim();
    if (!eventId) {
      continue;
    }
    countMap.set(eventId, row._count._all);
  }
  return countMap;
};

const resolveUserAttendanceMap = async (
  userIds: string[],
  eventIds: string[],
  since: Date
): Promise<Map<string, Date[]>> => {
  if (userIds.length === 0 || eventIds.length === 0) {
    return new Map();
  }
  const rows = await prisma.checkin.findMany({
    where: {
      userId: {
        in: userIds,
      },
      eventId: {
        in: eventIds,
      },
      type: 'event',
      note: {
        not: 'marked',
      },
      attendedAt: {
        gte: since,
      },
    },
    select: {
      userId: true,
      eventId: true,
      attendedAt: true,
    },
    orderBy: {
      attendedAt: 'desc',
    },
  });

  const attendanceMap = new Map<string, Date[]>();
  for (const row of rows) {
    const eventId = row.eventId?.trim();
    if (!eventId) {
      continue;
    }
    const key = `${row.userId}:${eventId}`;
    const current = attendanceMap.get(key) ?? [];
    current.push(row.attendedAt);
    attendanceMap.set(key, current);
  }
  return attendanceMap;
};

const buildDailyDigestMessage = (input: {
  eventName: string;
  newsCount: number;
  ratingCount: number;
  includeNews: boolean;
  includeRatings: boolean;
  needCheckinReminder: boolean;
}): { title: string; body: string } => {
  const summaryParts: string[] = [];
  if (input.includeNews) {
    summaryParts.push(`资讯 ${input.newsCount} 条`);
  }
  if (input.includeRatings) {
    summaryParts.push(`打分 ${input.ratingCount} 条`);
  }
  if (input.needCheckinReminder) {
    summaryParts.push('别忘了今天打卡');
  }
  return {
    title: `${input.eventName} 每日动态`,
    body: summaryParts.join('，'),
  };
};

let schedulerTimer: NodeJS.Timeout | null = null;
let running = false;

export const runEventDailyDigestJob = async (): Promise<EventDailyDigestJobReport> => {
  const executedAt = new Date();
  if (!SCHEDULER_CONFIG.enabled) {
    return {
      executedAt: executedAt.toISOString(),
      enabled: false,
      candidateUsers: 0,
      candidateEvents: 0,
      skippedByPreference: 0,
      skippedByHourWindow: 0,
      skippedByNoSignal: 0,
      attemptedPublishes: 0,
      sentPublishes: 0,
      dedupeSkippedPublishes: 0,
      failedPublishes: 0,
    };
  }

  const now = executedAt;
  const until = new Date(now.getTime() + (SCHEDULER_CONFIG.maxDaysBeforeStart + 1) * 24 * 60 * 60 * 1000);
  const since = new Date(now.getTime() - SCHEDULER_CONFIG.maxDaysAfterEnd * 24 * 60 * 60 * 1000);
  const userRows = await prisma.checkin.findMany({
    where: {
      type: 'event',
      note: 'marked',
      eventId: {
        not: null,
      },
      event: {
        startDate: {
          lte: until,
        },
        endDate: {
          gte: since,
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
      skippedByNoSignal: 0,
      attemptedPublishes: 0,
      sentPublishes: 0,
      dedupeSkippedPublishes: 0,
      failedPublishes: 0,
    };
  }

  const [preferenceMap, candidateEvents] = await Promise.all([
    resolvePreferenceMap(candidateUserIds),
    notificationCenterService.fetchMarkedEventDailyDigestCandidates({
      userIds: candidateUserIds,
      maxDaysBeforeStart: SCHEDULER_CONFIG.maxDaysBeforeStart,
      maxDaysAfterEnd: SCHEDULER_CONFIG.maxDaysAfterEnd,
    }),
  ]);
  const eventsByUser = new Map<string, Array<(typeof candidateEvents)[number]>>();
  const eventIds = Array.from(new Set(candidateEvents.map((item) => item.eventId)));
  for (const item of candidateEvents) {
    const current = eventsByUser.get(item.userId) ?? [];
    current.push(item);
    eventsByUser.set(item.userId, current);
  }

  const lookbackSince = new Date(now.getTime() - SCHEDULER_CONFIG.lookbackHours * 60 * 60 * 1000);
  const [newsCountMap, ratingCountMap, attendanceMap] = await Promise.all([
    resolveNewsCountMap(eventIds, lookbackSince),
    resolveRatingCountMap(eventIds, lookbackSince),
    resolveUserAttendanceMap(candidateUserIds, eventIds, new Date(now.getTime() - 48 * 60 * 60 * 1000)),
  ]);

  let skippedByPreference = 0;
  let skippedByHourWindow = 0;
  let skippedByNoSignal = 0;
  let attemptedPublishes = 0;
  let sentPublishes = 0;
  let dedupeSkippedPublishes = 0;
  let failedPublishes = 0;

  for (const userId of candidateUserIds) {
    const preference = preferenceMap.get(userId) ?? {
      enabled: true,
      reminderHours: [20],
      timezone: 'UTC',
      channels: ['in_app', 'apns'],
      includeNews: true,
      includeRatings: true,
      includeCheckinReminder: true,
    };
    const userEvents = eventsByUser.get(userId) ?? [];
    if (!preference.enabled) {
      skippedByPreference += userEvents.length;
      continue;
    }

    const nowParts = getLocalDateParts(now, preference.timezone);
    if (!preference.reminderHours.includes(nowParts.hour)) {
      skippedByHourWindow += userEvents.length;
      continue;
    }

    const nowDayIndex = getDayIndex(nowParts);
    for (const item of userEvents) {
      const newsCount = preference.includeNews ? newsCountMap.get(item.eventId) ?? 0 : 0;
      const ratingCount = preference.includeRatings ? ratingCountMap.get(item.eventId) ?? 0 : 0;
      const startParts = getLocalDateParts(item.eventStartDate, preference.timezone);
      const endParts = getLocalDateParts(item.eventEndDate, preference.timezone);
      const eventStarted = nowDayIndex >= getDayIndex(startParts);
      const eventNotEnded = nowDayIndex <= getDayIndex(endParts);
      const inEventWindow = eventStarted && eventNotEnded;
      let needCheckinReminder = false;
      if (preference.includeCheckinReminder && inEventWindow) {
        const attendanceKey = `${userId}:${item.eventId}`;
        const attendedRows = attendanceMap.get(attendanceKey) ?? [];
        const todayKey = formatLocalDateKey(nowParts);
        const hasCheckedInToday = attendedRows.some((attendedAt) => {
          const attendedParts = getLocalDateParts(attendedAt, preference.timezone);
          return formatLocalDateKey(attendedParts) === todayKey;
        });
        needCheckinReminder = !hasCheckedInToday;
      }

      if (newsCount === 0 && ratingCount === 0 && !needCheckinReminder) {
        skippedByNoSignal += 1;
        continue;
      }

      attemptedPublishes += 1;
      const dedupeKey = `event_daily_digest:${userId}:${item.eventId}:${formatLocalDateKey(nowParts)}:${toTwoDigits(nowParts.hour)}`;
      const message = buildDailyDigestMessage({
        eventName: item.eventName,
        newsCount,
        ratingCount,
        includeNews: preference.includeNews,
        includeRatings: preference.includeRatings,
        needCheckinReminder,
      });

      try {
        const result = await notificationCenterService.publish({
          category: 'event_daily_digest',
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
              eventEndDate: item.eventEndDate.toISOString(),
              newsCount,
              ratingCount,
              needCheckinReminder,
              timezone: preference.timezone,
              lookbackHours: SCHEDULER_CONFIG.lookbackHours,
              source: 'event_daily_digest_scheduler',
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
        console.error(`[notification-center][event-daily-digest] publish failed user=${userId} event=${item.eventId} error=${messageText}`);
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
    skippedByNoSignal,
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
    const report = await runEventDailyDigestJob();
    console.log(
      `[notification-center][event-daily-digest] run completed enabled=${report.enabled} users=${report.candidateUsers} events=${report.candidateEvents} attempted=${report.attemptedPublishes} sent=${report.sentPublishes} dedupe=${report.dedupeSkippedPublishes} failed=${report.failedPublishes}`
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error(`[notification-center][event-daily-digest] run failed: ${message}`);
  } finally {
    running = false;
  }
};

export const startNotificationEventDailyDigestScheduler = (): void => {
  if (!SCHEDULER_CONFIG.enabled) {
    console.log('[notification-center][event-daily-digest] scheduler disabled');
    return;
  }
  if (schedulerTimer) {
    return;
  }
  console.log(`[notification-center][event-daily-digest] scheduler started intervalMs=${SCHEDULER_CONFIG.intervalMs}`);
  void runOnceSafely();
  schedulerTimer = setInterval(() => {
    void runOnceSafely();
  }, SCHEDULER_CONFIG.intervalMs);
};

export const stopNotificationEventDailyDigestScheduler = (): void => {
  if (!schedulerTimer) {
    return;
  }
  clearInterval(schedulerTimer);
  schedulerTimer = null;
  console.log('[notification-center][event-daily-digest] scheduler stopped');
};
