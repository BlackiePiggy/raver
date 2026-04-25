import { PrismaClient } from '@prisma/client';
import { notificationCenterService, type FollowedDJUpdatePreference } from './notification-center.service';

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
  enabled: readBooleanEnv('NOTIFICATION_FOLLOWED_DJ_UPDATE_ENABLED', false),
  intervalMs: readPositiveIntegerEnv('NOTIFICATION_FOLLOWED_DJ_UPDATE_INTERVAL_MS', 10 * 60 * 1000),
  lookbackHours: readPositiveIntegerEnv('NOTIFICATION_FOLLOWED_DJ_UPDATE_LOOKBACK_HOURS', 24),
};

type LocalDateParts = {
  year: number;
  month: number;
  day: number;
  hour: number;
};

export type FollowedDJUpdateJobReport = {
  executedAt: string;
  enabled: boolean;
  candidateUsers: number;
  candidateFollowedDJs: number;
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

const resolvePreferenceMap = async (userIds: string[]): Promise<Map<string, FollowedDJUpdatePreference>> => {
  const rows = await notificationCenterService.fetchFollowedDJUpdateSubscriptions(userIds);
  return new Map(rows.map((item) => [item.userId, item.preference]));
};

const resolveInfoCountMap = async (djIds: string[], since: Date): Promise<Map<string, number>> => {
  if (djIds.length === 0) {
    return new Map();
  }
  const posts = await prisma.post.findMany({
    where: {
      createdAt: {
        gte: since,
      },
      boundDjIds: {
        hasSome: djIds,
      },
    },
    select: {
      boundDjIds: true,
    },
  });

  const countMap = new Map<string, number>();
  const djIdSet = new Set(djIds);
  for (const row of posts) {
    const uniqueDjIds = Array.from(new Set(row.boundDjIds.map((item) => item.trim()).filter(Boolean)));
    for (const djId of uniqueDjIds) {
      if (!djIdSet.has(djId)) continue;
      countMap.set(djId, (countMap.get(djId) ?? 0) + 1);
    }
  }
  return countMap;
};

const resolveSetCountMap = async (djIds: string[], since: Date): Promise<Map<string, number>> => {
  if (djIds.length === 0) {
    return new Map();
  }
  const sets = await prisma.dJSet.findMany({
    where: {
      createdAt: {
        gte: since,
      },
      OR: [
        {
          djId: {
            in: djIds,
          },
        },
        {
          coDjIds: {
            hasSome: djIds,
          },
        },
      ],
    },
    select: {
      djId: true,
      coDjIds: true,
    },
  });

  const countMap = new Map<string, number>();
  const djIdSet = new Set(djIds);
  for (const row of sets) {
    const uniqueDjIds = new Set<string>([row.djId, ...row.coDjIds].map((item) => item.trim()).filter(Boolean));
    for (const djId of uniqueDjIds) {
      if (!djIdSet.has(djId)) continue;
      countMap.set(djId, (countMap.get(djId) ?? 0) + 1);
    }
  }
  return countMap;
};

const resolveRatingCountMap = async (djIds: string[], since: Date): Promise<Map<string, number>> => {
  if (djIds.length === 0) {
    return new Map();
  }
  const grouped = await prisma.checkin.groupBy({
    by: ['djId'],
    where: {
      djId: {
        in: djIds,
      },
      type: 'dj',
      rating: {
        not: null,
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
    const djId = row.djId?.trim();
    if (!djId) continue;
    countMap.set(djId, row._count._all);
  }
  return countMap;
};

const pickTopDJs = (input: {
  djIds: string[];
  includeInfos: boolean;
  includeSets: boolean;
  includeRatings: boolean;
  infoCountMap: Map<string, number>;
  setCountMap: Map<string, number>;
  ratingCountMap: Map<string, number>;
}): string[] => {
  const scoreRows = input.djIds
    .map((djId) => {
      const info = input.includeInfos ? input.infoCountMap.get(djId) ?? 0 : 0;
      const set = input.includeSets ? input.setCountMap.get(djId) ?? 0 : 0;
      const rating = input.includeRatings ? input.ratingCountMap.get(djId) ?? 0 : 0;
      const score = info + set * 2 + rating;
      return { djId, score };
    })
    .filter((row) => row.score > 0)
    .sort((left, right) => right.score - left.score);
  return scoreRows.slice(0, 2).map((item) => item.djId);
};

const buildSummaryMessage = (input: {
  topDJNames: string[];
  includeInfos: boolean;
  includeSets: boolean;
  includeRatings: boolean;
  infoCount: number;
  setCount: number;
  ratingCount: number;
}): { title: string; body: string } => {
  const prefix = input.topDJNames.length > 0 ? `${input.topDJNames.join(' / ')} 有新动态` : '你关注的 DJ 有新动态';
  const summary: string[] = [];
  if (input.includeInfos) summary.push(`资讯 ${input.infoCount} 条`);
  if (input.includeSets) summary.push(`Sets ${input.setCount} 条`);
  if (input.includeRatings) summary.push(`打分 ${input.ratingCount} 条`);
  return {
    title: '你关注的 DJ 有新动态',
    body: `${prefix}，${summary.join('，')}`,
  };
};

let schedulerTimer: NodeJS.Timeout | null = null;
let running = false;

export const runFollowedDJUpdateJob = async (): Promise<FollowedDJUpdateJobReport> => {
  const executedAt = new Date();
  if (!SCHEDULER_CONFIG.enabled) {
    return {
      executedAt: executedAt.toISOString(),
      enabled: false,
      candidateUsers: 0,
      candidateFollowedDJs: 0,
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
  const followRows = await prisma.follow.findMany({
    where: {
      type: 'dj',
      djId: {
        not: null,
      },
    },
    select: {
      followerId: true,
      djId: true,
    },
  });
  if (followRows.length === 0) {
    return {
      executedAt: executedAt.toISOString(),
      enabled: true,
      candidateUsers: 0,
      candidateFollowedDJs: 0,
      skippedByPreference: 0,
      skippedByHourWindow: 0,
      skippedByNoSignal: 0,
      attemptedPublishes: 0,
      sentPublishes: 0,
      dedupeSkippedPublishes: 0,
      failedPublishes: 0,
    };
  }

  const followsByUser = new Map<string, Set<string>>();
  for (const row of followRows) {
    const djId = row.djId?.trim();
    if (!djId) continue;
    const current = followsByUser.get(row.followerId) ?? new Set<string>();
    current.add(djId);
    followsByUser.set(row.followerId, current);
  }
  const candidateUserIds = Array.from(followsByUser.keys());
  const preferenceMap = await resolvePreferenceMap(candidateUserIds);

  const activeUserIds: string[] = [];
  let skippedByPreference = 0;
  let skippedByHourWindow = 0;
  for (const userId of candidateUserIds) {
    const preference = preferenceMap.get(userId) ?? {
      enabled: true,
      reminderHours: [21],
      timezone: 'UTC',
      channels: ['in_app', 'apns'],
      includeInfos: true,
      includeSets: true,
      includeRatings: true,
    };
    if (!preference.enabled) {
      skippedByPreference += 1;
      continue;
    }
    const nowParts = getLocalDateParts(now, preference.timezone);
    if (!preference.reminderHours.includes(nowParts.hour)) {
      skippedByHourWindow += 1;
      continue;
    }
    activeUserIds.push(userId);
  }

  if (activeUserIds.length === 0) {
    return {
      executedAt: executedAt.toISOString(),
      enabled: true,
      candidateUsers: candidateUserIds.length,
      candidateFollowedDJs: followRows.length,
      skippedByPreference,
      skippedByHourWindow,
      skippedByNoSignal: 0,
      attemptedPublishes: 0,
      sentPublishes: 0,
      dedupeSkippedPublishes: 0,
      failedPublishes: 0,
    };
  }

  const activeDjIds = Array.from(
    new Set(activeUserIds.flatMap((userId) => Array.from(followsByUser.get(userId) ?? new Set<string>())))
  );
  const since = new Date(now.getTime() - SCHEDULER_CONFIG.lookbackHours * 60 * 60 * 1000);
  const [infoCountMap, setCountMap, ratingCountMap] = await Promise.all([
    resolveInfoCountMap(activeDjIds, since),
    resolveSetCountMap(activeDjIds, since),
    resolveRatingCountMap(activeDjIds, since),
  ]);

  const topDjIdCandidates = Array.from(
    new Set(
      activeUserIds.flatMap((userId) =>
        pickTopDJs({
          djIds: Array.from(followsByUser.get(userId) ?? new Set<string>()),
          includeInfos: preferenceMap.get(userId)?.includeInfos ?? true,
          includeSets: preferenceMap.get(userId)?.includeSets ?? true,
          includeRatings: preferenceMap.get(userId)?.includeRatings ?? true,
          infoCountMap,
          setCountMap,
          ratingCountMap,
        })
      )
    )
  );
  const djRows = topDjIdCandidates.length
    ? await prisma.dJ.findMany({
        where: {
          id: {
            in: topDjIdCandidates,
          },
        },
        select: {
          id: true,
          name: true,
        },
      })
    : [];
  const djNameMap = new Map(djRows.map((item) => [item.id, item.name]));

  let skippedByNoSignal = 0;
  let attemptedPublishes = 0;
  let sentPublishes = 0;
  let dedupeSkippedPublishes = 0;
  let failedPublishes = 0;

  for (const userId of activeUserIds) {
    const preference = preferenceMap.get(userId) ?? {
      enabled: true,
      reminderHours: [21],
      timezone: 'UTC',
      channels: ['in_app', 'apns'],
      includeInfos: true,
      includeSets: true,
      includeRatings: true,
    };
    const followedDjIds = Array.from(followsByUser.get(userId) ?? new Set<string>());
    const infoCount = preference.includeInfos
      ? followedDjIds.reduce((acc, djId) => acc + (infoCountMap.get(djId) ?? 0), 0)
      : 0;
    const setCount = preference.includeSets
      ? followedDjIds.reduce((acc, djId) => acc + (setCountMap.get(djId) ?? 0), 0)
      : 0;
    const ratingCount = preference.includeRatings
      ? followedDjIds.reduce((acc, djId) => acc + (ratingCountMap.get(djId) ?? 0), 0)
      : 0;
    if (infoCount === 0 && setCount === 0 && ratingCount === 0) {
      skippedByNoSignal += 1;
      continue;
    }

    const topDjIds = pickTopDJs({
      djIds: followedDjIds,
      includeInfos: preference.includeInfos,
      includeSets: preference.includeSets,
      includeRatings: preference.includeRatings,
      infoCountMap,
      setCountMap,
      ratingCountMap,
    });
    const topDJNames = topDjIds.map((djId) => djNameMap.get(djId) ?? djId);
    const nowParts = getLocalDateParts(now, preference.timezone);
    const dedupeKey = `followed_dj_update:${userId}:${formatLocalDateKey(nowParts)}:${toTwoDigits(nowParts.hour)}`;
    const message = buildSummaryMessage({
      topDJNames,
      includeInfos: preference.includeInfos,
      includeSets: preference.includeSets,
      includeRatings: preference.includeRatings,
      infoCount,
      setCount,
      ratingCount,
    });
    attemptedPublishes += 1;

    try {
      const result = await notificationCenterService.publish({
        category: 'followed_dj_update',
        targets: [{ userId }],
        channels: preference.channels,
        dedupeKey,
        payload: {
          title: message.title,
          body: message.body,
          deeplink: topDjIds[0] ? `raver://dj/${topDjIds[0]}` : null,
          metadata: {
            topDjIds,
            topDJNames,
            infoCount,
            setCount,
            ratingCount,
            lookbackHours: SCHEDULER_CONFIG.lookbackHours,
            source: 'followed_dj_update_scheduler',
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
      console.error(`[notification-center][followed-dj-update] publish failed user=${userId} error=${messageText}`);
    }
  }

  return {
    executedAt: executedAt.toISOString(),
    enabled: true,
    candidateUsers: candidateUserIds.length,
    candidateFollowedDJs: followRows.length,
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
    const report = await runFollowedDJUpdateJob();
    console.log(
      `[notification-center][followed-dj-update] run completed enabled=${report.enabled} users=${report.candidateUsers} followedDJs=${report.candidateFollowedDJs} attempted=${report.attemptedPublishes} sent=${report.sentPublishes} dedupe=${report.dedupeSkippedPublishes} failed=${report.failedPublishes}`
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error(`[notification-center][followed-dj-update] run failed: ${message}`);
  } finally {
    running = false;
  }
};

export const startNotificationFollowedDJUpdateScheduler = (): void => {
  if (!SCHEDULER_CONFIG.enabled) {
    console.log('[notification-center][followed-dj-update] scheduler disabled');
    return;
  }
  if (schedulerTimer) {
    return;
  }
  console.log(`[notification-center][followed-dj-update] scheduler started intervalMs=${SCHEDULER_CONFIG.intervalMs}`);
  void runOnceSafely();
  schedulerTimer = setInterval(() => {
    void runOnceSafely();
  }, SCHEDULER_CONFIG.intervalMs);
};

export const stopNotificationFollowedDJUpdateScheduler = (): void => {
  if (!schedulerTimer) {
    return;
  }
  clearInterval(schedulerTimer);
  schedulerTimer = null;
  console.log('[notification-center][followed-dj-update] scheduler stopped');
};
