import { PrismaClient } from '@prisma/client';
import { notificationCenterService, type FollowedBrandUpdatePreference } from './notification-center.service';

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
  enabled: readBooleanEnv('NOTIFICATION_FOLLOWED_BRAND_UPDATE_ENABLED', false),
  intervalMs: readPositiveIntegerEnv('NOTIFICATION_FOLLOWED_BRAND_UPDATE_INTERVAL_MS', 10 * 60 * 1000),
  lookbackHours: readPositiveIntegerEnv('NOTIFICATION_FOLLOWED_BRAND_UPDATE_LOOKBACK_HOURS', 24),
};

type LocalDateParts = {
  year: number;
  month: number;
  day: number;
  hour: number;
};

export type FollowedBrandUpdateJobReport = {
  executedAt: string;
  enabled: boolean;
  candidateUsers: number;
  candidateWatchedBrands: number;
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

const resolvePreferenceMap = async (userIds: string[]): Promise<Map<string, FollowedBrandUpdatePreference>> => {
  const rows = await notificationCenterService.fetchFollowedBrandUpdateSubscriptions(userIds);
  return new Map(rows.map((item) => [item.userId, item.preference]));
};

const resolveInfoCountMap = async (brandIds: string[], since: Date): Promise<Map<string, number>> => {
  if (brandIds.length === 0) {
    return new Map();
  }
  const posts = await prisma.post.findMany({
    where: {
      createdAt: {
        gte: since,
      },
      boundBrandIds: {
        hasSome: brandIds,
      },
    },
    select: {
      boundBrandIds: true,
    },
  });
  const brandIdSet = new Set(brandIds);
  const countMap = new Map<string, number>();
  for (const post of posts) {
    const uniqueBrandIds = Array.from(new Set(post.boundBrandIds.map((item) => item.trim()).filter(Boolean)));
    for (const brandId of uniqueBrandIds) {
      if (!brandIdSet.has(brandId)) continue;
      countMap.set(brandId, (countMap.get(brandId) ?? 0) + 1);
    }
  }
  return countMap;
};

const resolveEventCountMap = async (brandIds: string[], since: Date): Promise<Map<string, number>> => {
  if (brandIds.length === 0) {
    return new Map();
  }
  const grouped = await prisma.event.groupBy({
    by: ['wikiFestivalId'],
    where: {
      wikiFestivalId: {
        in: brandIds,
      },
      updatedAt: {
        gte: since,
      },
    },
    _count: {
      _all: true,
    },
  });

  const countMap = new Map<string, number>();
  for (const row of grouped) {
    const brandId = row.wikiFestivalId?.trim();
    if (!brandId) continue;
    countMap.set(brandId, row._count._all);
  }
  return countMap;
};

const resolveBrandNameMap = async (brandIds: string[]): Promise<Map<string, string>> => {
  if (brandIds.length === 0) {
    return new Map();
  }
  const [wikiBrands, labels] = await Promise.all([
    prisma.wikiFestival.findMany({
      where: {
        id: {
          in: brandIds,
        },
      },
      select: {
        id: true,
        name: true,
      },
    }),
    prisma.label.findMany({
      where: {
        id: {
          in: brandIds,
        },
      },
      select: {
        id: true,
        name: true,
      },
    }),
  ]);
  const nameMap = new Map<string, string>();
  for (const brand of wikiBrands) {
    nameMap.set(brand.id, brand.name);
  }
  for (const brand of labels) {
    if (!nameMap.has(brand.id)) {
      nameMap.set(brand.id, brand.name);
    }
  }
  return nameMap;
};

const pickTopBrands = (input: {
  brandIds: string[];
  includeInfos: boolean;
  includeEvents: boolean;
  infoCountMap: Map<string, number>;
  eventCountMap: Map<string, number>;
}): string[] => {
  const scoreRows = input.brandIds
    .map((brandId) => {
      const info = input.includeInfos ? input.infoCountMap.get(brandId) ?? 0 : 0;
      const event = input.includeEvents ? input.eventCountMap.get(brandId) ?? 0 : 0;
      const score = info + event * 2;
      return { brandId, score };
    })
    .filter((row) => row.score > 0)
    .sort((left, right) => right.score - left.score);
  return scoreRows.slice(0, 2).map((item) => item.brandId);
};

const buildSummaryMessage = (input: {
  topBrandNames: string[];
  includeInfos: boolean;
  includeEvents: boolean;
  infoCount: number;
  eventCount: number;
}): { title: string; body: string } => {
  const prefix =
    input.topBrandNames.length > 0 ? `${input.topBrandNames.join(' / ')} 有新动态` : '你关注的 Brand 有新动态';
  const summary: string[] = [];
  if (input.includeInfos) summary.push(`资讯 ${input.infoCount} 条`);
  if (input.includeEvents) summary.push(`活动 ${input.eventCount} 条`);
  return {
    title: '你关注的 Brand 有新动态',
    body: `${prefix}，${summary.join('，')}`,
  };
};

let schedulerTimer: NodeJS.Timeout | null = null;
let running = false;

export const runFollowedBrandUpdateJob = async (): Promise<FollowedBrandUpdateJobReport> => {
  const executedAt = new Date();
  if (!SCHEDULER_CONFIG.enabled) {
    return {
      executedAt: executedAt.toISOString(),
      enabled: false,
      candidateUsers: 0,
      candidateWatchedBrands: 0,
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
  const subscriptions = await notificationCenterService.fetchFollowedBrandUpdateSubscriptions();
  if (subscriptions.length === 0) {
    return {
      executedAt: executedAt.toISOString(),
      enabled: true,
      candidateUsers: 0,
      candidateWatchedBrands: 0,
      skippedByPreference: 0,
      skippedByHourWindow: 0,
      skippedByNoSignal: 0,
      attemptedPublishes: 0,
      sentPublishes: 0,
      dedupeSkippedPublishes: 0,
      failedPublishes: 0,
    };
  }

  const candidateUserIds = subscriptions.map((row) => row.userId);
  const preferenceMap = await resolvePreferenceMap(candidateUserIds);

  const activeUserIds: string[] = [];
  let skippedByPreference = 0;
  let skippedByHourWindow = 0;
  for (const userId of candidateUserIds) {
    const preference = preferenceMap.get(userId);
    if (!preference || !preference.enabled || preference.watchedBrandIds.length === 0) {
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
      candidateWatchedBrands: subscriptions.reduce((acc, item) => acc + item.preference.watchedBrandIds.length, 0),
      skippedByPreference,
      skippedByHourWindow,
      skippedByNoSignal: 0,
      attemptedPublishes: 0,
      sentPublishes: 0,
      dedupeSkippedPublishes: 0,
      failedPublishes: 0,
    };
  }

  const activeBrandIds = Array.from(
    new Set(activeUserIds.flatMap((userId) => preferenceMap.get(userId)?.watchedBrandIds ?? []))
  );
  const since = new Date(now.getTime() - SCHEDULER_CONFIG.lookbackHours * 60 * 60 * 1000);
  const [infoCountMap, eventCountMap, brandNameMap] = await Promise.all([
    resolveInfoCountMap(activeBrandIds, since),
    resolveEventCountMap(activeBrandIds, since),
    resolveBrandNameMap(activeBrandIds),
  ]);

  let skippedByNoSignal = 0;
  let attemptedPublishes = 0;
  let sentPublishes = 0;
  let dedupeSkippedPublishes = 0;
  let failedPublishes = 0;

  for (const userId of activeUserIds) {
    const preference = preferenceMap.get(userId);
    if (!preference) {
      skippedByPreference += 1;
      continue;
    }

    const infoCount = preference.includeInfos
      ? preference.watchedBrandIds.reduce((acc, brandId) => acc + (infoCountMap.get(brandId) ?? 0), 0)
      : 0;
    const eventCount = preference.includeEvents
      ? preference.watchedBrandIds.reduce((acc, brandId) => acc + (eventCountMap.get(brandId) ?? 0), 0)
      : 0;
    if (infoCount === 0 && eventCount === 0) {
      skippedByNoSignal += 1;
      continue;
    }

    const topBrandIds = pickTopBrands({
      brandIds: preference.watchedBrandIds,
      includeInfos: preference.includeInfos,
      includeEvents: preference.includeEvents,
      infoCountMap,
      eventCountMap,
    });
    const topBrandNames = topBrandIds.map((brandId) => brandNameMap.get(brandId) ?? brandId);
    const nowParts = getLocalDateParts(now, preference.timezone);
    const dedupeKey = `followed_brand_update:${userId}:${formatLocalDateKey(nowParts)}:${toTwoDigits(nowParts.hour)}`;
    const message = buildSummaryMessage({
      topBrandNames,
      includeInfos: preference.includeInfos,
      includeEvents: preference.includeEvents,
      infoCount,
      eventCount,
    });
    attemptedPublishes += 1;

    try {
      const result = await notificationCenterService.publish({
        category: 'followed_brand_update',
        targets: [{ userId }],
        channels: preference.channels,
        dedupeKey,
        payload: {
          title: message.title,
          body: message.body,
          deeplink: topBrandIds[0] ? `raver://brand/${topBrandIds[0]}` : null,
          metadata: {
            topBrandIds,
            topBrandNames,
            infoCount,
            eventCount,
            lookbackHours: SCHEDULER_CONFIG.lookbackHours,
            source: 'followed_brand_update_scheduler',
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
      console.error(`[notification-center][followed-brand-update] publish failed user=${userId} error=${messageText}`);
    }
  }

  return {
    executedAt: executedAt.toISOString(),
    enabled: true,
    candidateUsers: candidateUserIds.length,
    candidateWatchedBrands: activeBrandIds.length,
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
    const report = await runFollowedBrandUpdateJob();
    console.log(
      `[notification-center][followed-brand-update] run completed enabled=${report.enabled} users=${report.candidateUsers} watchedBrands=${report.candidateWatchedBrands} attempted=${report.attemptedPublishes} sent=${report.sentPublishes} dedupe=${report.dedupeSkippedPublishes} failed=${report.failedPublishes}`
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error(`[notification-center][followed-brand-update] run failed: ${message}`);
  } finally {
    running = false;
  }
};

export const startNotificationFollowedBrandUpdateScheduler = (): void => {
  if (!SCHEDULER_CONFIG.enabled) {
    console.log('[notification-center][followed-brand-update] scheduler disabled');
    return;
  }
  if (schedulerTimer) {
    return;
  }
  console.log(`[notification-center][followed-brand-update] scheduler started intervalMs=${SCHEDULER_CONFIG.intervalMs}`);
  void runOnceSafely();
  schedulerTimer = setInterval(() => {
    void runOnceSafely();
  }, SCHEDULER_CONFIG.intervalMs);
};

export const stopNotificationFollowedBrandUpdateScheduler = (): void => {
  if (!schedulerTimer) {
    return;
  }
  clearInterval(schedulerTimer);
  schedulerTimer = null;
  console.log('[notification-center][followed-brand-update] scheduler stopped');
};
