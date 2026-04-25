import { Prisma, PrismaClient } from '@prisma/client';
import type {
  NotificationChannel,
  NotificationChannelHandler,
  NotificationDeliveryResult,
  NotificationEvent,
  NotificationPublishInput,
  RegisterDevicePushTokenInput,
} from './notification-center.types';

const prisma = new PrismaClient();
const handlers = new Map<NotificationChannel, NotificationChannelHandler>();

const readBoolEnv = (key: string, fallback: boolean): boolean => {
  const raw = process.env[key];
  if (typeof raw !== 'string') return fallback;
  const normalized = raw.trim().toLowerCase();
  if (normalized === '1' || normalized === 'true' || normalized === 'yes' || normalized === 'on') return true;
  if (normalized === '0' || normalized === 'false' || normalized === 'no' || normalized === 'off') return false;
  return fallback;
};

const NOTIFICATION_OUTBOX_ASYNC_ENABLED = readBoolEnv('NOTIFICATION_OUTBOX_ASYNC_ENABLED', false);

const toInputJsonValue = (value: unknown): Prisma.InputJsonValue => {
  return (value ?? {}) as Prisma.InputJsonValue;
};

const createRuntimeEvent = (eventId: string, input: NotificationPublishInput): NotificationEvent => ({
  id: eventId,
  category: input.category,
  targets: input.targets,
  channels: input.channels,
  payload: input.payload,
  dedupeKey: input.dedupeKey,
  createdAt: new Date(),
});

const deliverWithHandlers = async (event: NotificationEvent): Promise<NotificationDeliveryResult[]> => {
  const results: NotificationDeliveryResult[] = [];
  for (const channel of event.channels) {
    if (channel === 'in_app') {
      results.push({
        channel,
        success: true,
        detail: 'stored-to-inbox',
      });
      continue;
    }

    const handler = handlers.get(channel);
    if (!handler) {
      results.push({
        channel,
        success: false,
        detail: 'handler-not-configured',
      });
      continue;
    }

    try {
      const result = await handler.deliver(event);
      results.push(result);
    } catch (error) {
      results.push({
        channel,
        success: false,
        detail: error instanceof Error ? error.message : 'unknown-delivery-error',
      });
    }
  }
  return results;
};

const normalizePositiveLimit = (limit: number, fallback = 20, max = 100): number => {
  if (!Number.isFinite(limit)) {
    return fallback;
  }
  const value = Math.floor(limit);
  if (value < 1) {
    return fallback;
  }
  return Math.min(value, max);
};

const normalizePositiveWindowHours = (hours: number, fallback = 24, max = 24 * 30): number => {
  if (!Number.isFinite(hours)) {
    return fallback;
  }
  const value = Math.floor(hours);
  if (value < 1) {
    return fallback;
  }
  return Math.min(value, max);
};

const toRate = (numerator: number, denominator: number): number => {
  if (!Number.isFinite(numerator) || !Number.isFinite(denominator) || denominator <= 0) {
    return 0;
  }
  const value = numerator / denominator;
  if (!Number.isFinite(value)) {
    return 0;
  }
  if (value < 0) return 0;
  if (value > 1) return 1;
  return value;
};

const NOTIFICATION_CATEGORIES = [
  'chat_message',
  'community_interaction',
  'event_countdown',
  'event_daily_digest',
  'route_dj_reminder',
  'followed_dj_update',
  'followed_brand_update',
  'major_news',
] as const;

type NotificationCategory = (typeof NOTIFICATION_CATEGORIES)[number];
type NotificationRateLimitPolicy = {
  enabled: boolean;
  windowSeconds: number;
  maxPerUser: number;
  exemptCategories: NotificationCategory[];
};

type NotificationQuietHoursPolicy = {
  enabled: boolean;
  startHour: number;
  endHour: number;
  timezone: string;
  muteChannels: NotificationChannel[];
  exemptCategories: NotificationCategory[];
};

type NotificationAdminGlobalConfig = {
  categorySwitches: Record<NotificationCategory, boolean>;
  channelSwitches: Record<NotificationChannel, boolean>;
  grayRelease: {
    enabled: boolean;
    percentage: number;
    allowUserIDs: string[];
  };
  governance: {
    rateLimit: NotificationRateLimitPolicy;
    quietHours: NotificationQuietHoursPolicy;
  };
};

type NotificationTemplateSeed = {
  category: NotificationCategory;
  locale: string;
  channel: NotificationChannel;
  titleTemplate: string;
  bodyTemplate: string;
  deeplinkTemplate?: string | null;
  variables?: string[];
};

export type EventCountdownPreference = {
  enabled: boolean;
  daysBeforeStart: number;
  reminderHours: number[];
  timezone: string;
  channels: NotificationChannel[];
};

export type EventDailyDigestPreference = {
  enabled: boolean;
  reminderHours: number[];
  timezone: string;
  channels: NotificationChannel[];
  includeNews: boolean;
  includeRatings: boolean;
  includeCheckinReminder: boolean;
};

export type RouteDJReminderWatchSlot = {
  eventId: string;
  slotId: string;
  reminderMinutesBefore?: number;
};

export type RouteDJReminderPreference = {
  enabled: boolean;
  timezone: string;
  channels: NotificationChannel[];
  defaultReminderMinutesBefore: number;
  watchedSlots: RouteDJReminderWatchSlot[];
};

export type FollowedDJUpdatePreference = {
  enabled: boolean;
  reminderHours: number[];
  timezone: string;
  channels: NotificationChannel[];
  includeInfos: boolean;
  includeSets: boolean;
  includeRatings: boolean;
};

export type FollowedBrandUpdatePreference = {
  enabled: boolean;
  reminderHours: number[];
  timezone: string;
  channels: NotificationChannel[];
  watchedBrandIds: string[];
  includeInfos: boolean;
  includeEvents: boolean;
};

const GLOBAL_CONFIG_KEY = 'global_policy';

const DEFAULT_GLOBAL_CONFIG: NotificationAdminGlobalConfig = {
  categorySwitches: {
    chat_message: true,
    community_interaction: true,
    event_countdown: true,
    event_daily_digest: true,
    route_dj_reminder: true,
    followed_dj_update: true,
    followed_brand_update: true,
    major_news: true,
  },
  channelSwitches: {
    in_app: true,
    apns: true,
    openim: true,
  },
  grayRelease: {
    enabled: false,
    percentage: 100,
    allowUserIDs: [],
  },
  governance: {
    rateLimit: {
      enabled: false,
      windowSeconds: 60 * 60,
      maxPerUser: 60,
      exemptCategories: ['chat_message'],
    },
    quietHours: {
      enabled: false,
      startHour: 23,
      endHour: 8,
      timezone: 'UTC',
      muteChannels: ['apns'],
      exemptCategories: ['chat_message', 'route_dj_reminder'],
    },
  },
};

const DEFAULT_EVENT_COUNTDOWN_PREFERENCE: EventCountdownPreference = {
  enabled: true,
  daysBeforeStart: 3,
  reminderHours: [10],
  timezone: 'UTC',
  channels: ['in_app', 'apns'],
};

const DEFAULT_EVENT_DAILY_DIGEST_PREFERENCE: EventDailyDigestPreference = {
  enabled: true,
  reminderHours: [20],
  timezone: 'UTC',
  channels: ['in_app', 'apns'],
  includeNews: true,
  includeRatings: true,
  includeCheckinReminder: true,
};

const DEFAULT_ROUTE_DJ_REMINDER_PREFERENCE: RouteDJReminderPreference = {
  enabled: true,
  timezone: 'UTC',
  channels: ['in_app', 'apns'],
  defaultReminderMinutesBefore: 30,
  watchedSlots: [],
};

const DEFAULT_FOLLOWED_DJ_UPDATE_PREFERENCE: FollowedDJUpdatePreference = {
  enabled: true,
  reminderHours: [21],
  timezone: 'UTC',
  channels: ['in_app', 'apns'],
  includeInfos: true,
  includeSets: true,
  includeRatings: true,
};

const DEFAULT_FOLLOWED_BRAND_UPDATE_PREFERENCE: FollowedBrandUpdatePreference = {
  enabled: true,
  reminderHours: [21],
  timezone: 'UTC',
  channels: ['in_app', 'apns'],
  watchedBrandIds: [],
  includeInfos: true,
  includeEvents: true,
};

const DEFAULT_TEMPLATE_SEEDS: NotificationTemplateSeed[] = [
  {
    category: 'chat_message',
    locale: 'zh-CN',
    channel: 'apns',
    titleTemplate: '你有一条新消息',
    bodyTemplate: '{{senderName}}: {{messagePreview}}',
    deeplinkTemplate: 'raver://messages/conversation/{{conversationId}}',
    variables: ['senderName', 'messagePreview', 'conversationId'],
  },
  {
    category: 'community_interaction',
    locale: 'zh-CN',
    channel: 'apns',
    titleTemplate: '你有新的互动',
    bodyTemplate: '{{actorName}} {{actionText}}',
    deeplinkTemplate: 'raver://community/post/{{postId}}',
    variables: ['actorName', 'actionText', 'postId'],
  },
  {
    category: 'event_countdown',
    locale: 'zh-CN',
    channel: 'in_app',
    titleTemplate: '{{eventName}} 倒计时提醒',
    bodyTemplate: '距离开始还有 {{daysLeft}} 天',
    deeplinkTemplate: 'raver://event/{{eventId}}',
    variables: ['eventName', 'daysLeft', 'eventId'],
  },
  {
    category: 'event_daily_digest',
    locale: 'zh-CN',
    channel: 'in_app',
    titleTemplate: '{{eventName}} 今日动态',
    bodyTemplate: '资讯 {{newsCount}} 条，打分 {{ratingCount}} 条',
    deeplinkTemplate: 'raver://event/{{eventId}}',
    variables: ['eventName', 'newsCount', 'ratingCount', 'eventId'],
  },
  {
    category: 'route_dj_reminder',
    locale: 'zh-CN',
    channel: 'in_app',
    titleTemplate: '{{djName}} 即将上台',
    bodyTemplate: '{{eventName}} · {{stageName}} · {{minutesLeft}} 分钟后开始',
    deeplinkTemplate: 'raver://event/{{eventId}}',
    variables: ['djName', 'eventName', 'stageName', 'minutesLeft', 'eventId'],
  },
  {
    category: 'followed_dj_update',
    locale: 'zh-CN',
    channel: 'in_app',
    titleTemplate: '你关注的 DJ 有新动态',
    bodyTemplate: '资讯 {{infoCount}} 条，Sets {{setCount}} 条，打分 {{ratingCount}} 条',
    deeplinkTemplate: 'raver://dj/{{djId}}',
    variables: ['infoCount', 'setCount', 'ratingCount', 'djId'],
  },
  {
    category: 'followed_brand_update',
    locale: 'zh-CN',
    channel: 'in_app',
    titleTemplate: '你关注的 Brand 有新动态',
    bodyTemplate: '资讯 {{infoCount}} 条，活动 {{eventCount}} 条',
    deeplinkTemplate: 'raver://brand/{{brandId}}',
    variables: ['infoCount', 'eventCount', 'brandId'],
  },
  {
    category: 'major_news',
    locale: 'zh-CN',
    channel: 'apns',
    titleTemplate: '{{headline}}',
    bodyTemplate: '{{summary}}',
    deeplinkTemplate: 'raver://news/{{newsId}}',
    variables: ['headline', 'summary', 'newsId'],
  },
];

const isRecord = (value: unknown): value is Record<string, unknown> => {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
};

const readStringFromRecord = (record: Record<string, unknown>, key: string): string | null => {
  const value = record[key];
  if (typeof value !== 'string') return null;
  const normalized = value.trim();
  return normalized.length > 0 ? normalized : null;
};

const readNumberFromRecord = (record: Record<string, unknown>, key: string, fallback: number): number => {
  const value = record[key];
  if (typeof value !== 'number' || !Number.isFinite(value)) return fallback;
  return value;
};

const clampPercentage = (value: number): number => {
  if (!Number.isFinite(value)) {
    return 100;
  }
  const normalized = Math.floor(value);
  if (normalized < 0) return 0;
  if (normalized > 100) return 100;
  return normalized;
};

const clampPositiveInt = (value: number, fallback: number, min: number, max: number): number => {
  if (!Number.isFinite(value)) {
    return fallback;
  }
  const normalized = Math.floor(value);
  if (normalized < min) return min;
  if (normalized > max) return max;
  return normalized;
};

const normalizeNotificationCategoryList = (raw: unknown, fallback: NotificationCategory[]): NotificationCategory[] => {
  if (!Array.isArray(raw)) {
    return [...fallback];
  }
  const normalized = Array.from(
    new Set(
      raw
        .filter((item): item is string => typeof item === 'string')
        .map((item) => item.trim())
        .filter((item): item is NotificationCategory => isNotificationCategory(item))
    )
  );
  return normalized.length > 0 ? normalized : [...fallback];
};

const normalizeNotificationChannelList = (raw: unknown, fallback: NotificationChannel[]): NotificationChannel[] => {
  if (!Array.isArray(raw)) {
    return [...fallback];
  }
  const normalized = Array.from(
    new Set(
      raw
        .filter((item): item is string => typeof item === 'string')
        .map((item) => item.trim().toLowerCase())
        .filter((item): item is NotificationChannel => item === 'in_app' || item === 'apns' || item === 'openim')
    )
  );
  return normalized.length > 0 ? normalized : [...fallback];
};

const getHourInTimezone = (time: Date, timezone: string): number => {
  try {
    const parts = new Intl.DateTimeFormat('en-US', {
      timeZone: timezone,
      hour12: false,
      hour: '2-digit',
    }).formatToParts(time);
    const hourPart = parts.find((item) => item.type === 'hour');
    const parsed = Number(hourPart?.value ?? '');
    if (Number.isFinite(parsed) && parsed >= 0 && parsed <= 23) {
      return Math.floor(parsed);
    }
  } catch {
    // Ignore parse failures and fallback to UTC.
  }
  return time.getUTCHours();
};

const isHourInsideWindow = (hour: number, startHour: number, endHour: number): boolean => {
  if (startHour === endHour) {
    return true;
  }
  if (startHour < endHour) {
    return hour >= startHour && hour < endHour;
  }
  return hour >= startHour || hour < endHour;
};

const normalizeHour = (value: number): number | null => {
  if (!Number.isFinite(value)) return null;
  const numeric = Math.floor(value);
  if (numeric < 0 || numeric > 23) return null;
  return numeric;
};

const normalizeDaysBeforeStart = (value: number, fallback = 3): number => {
  if (!Number.isFinite(value)) return fallback;
  const numeric = Math.floor(value);
  if (numeric < 0) return 0;
  if (numeric > 60) return 60;
  return numeric;
};

const normalizeReminderMinutesBefore = (value: number, fallback = 30): number => {
  if (!Number.isFinite(value)) return fallback;
  const numeric = Math.floor(value);
  if (numeric < 1) return 1;
  if (numeric > 12 * 60) return 12 * 60;
  return numeric;
};

const normalizeTimezone = (value: string | undefined): string => {
  const trimmed = value?.trim();
  if (!trimmed) {
    return DEFAULT_EVENT_COUNTDOWN_PREFERENCE.timezone;
  }
  try {
    new Intl.DateTimeFormat('en-US', { timeZone: trimmed });
    return trimmed;
  } catch {
    return DEFAULT_EVENT_COUNTDOWN_PREFERENCE.timezone;
  }
};

const hashToBucket = (value: string): number => {
  let hash = 0;
  for (let index = 0; index < value.length; index += 1) {
    hash = (hash * 31 + value.charCodeAt(index)) | 0;
  }
  return Math.abs(hash) % 100;
};

const normalizeGlobalConfig = (raw: unknown): NotificationAdminGlobalConfig => {
  const config = isRecord(raw) ? raw : {};
  const categorySwitchesRaw = isRecord(config.categorySwitches) ? config.categorySwitches : {};
  const channelSwitchesRaw = isRecord(config.channelSwitches) ? config.channelSwitches : {};
  const grayReleaseRaw = isRecord(config.grayRelease) ? config.grayRelease : {};
  const governanceRaw = isRecord(config.governance) ? config.governance : {};
  const rateLimitRaw = isRecord(governanceRaw.rateLimit) ? governanceRaw.rateLimit : {};
  const quietHoursRaw = isRecord(governanceRaw.quietHours) ? governanceRaw.quietHours : {};

  const categorySwitches = { ...DEFAULT_GLOBAL_CONFIG.categorySwitches };
  for (const category of NOTIFICATION_CATEGORIES) {
    if (typeof categorySwitchesRaw[category] === 'boolean') {
      categorySwitches[category] = Boolean(categorySwitchesRaw[category]);
    }
  }

  const channelSwitches = { ...DEFAULT_GLOBAL_CONFIG.channelSwitches };
  for (const channel of ['in_app', 'apns', 'openim'] as const) {
    if (typeof channelSwitchesRaw[channel] === 'boolean') {
      channelSwitches[channel] = Boolean(channelSwitchesRaw[channel]);
    }
  }

  const allowUserIDsRaw = Array.isArray(grayReleaseRaw.allowUserIDs) ? grayReleaseRaw.allowUserIDs : [];
  const allowUserIDs = Array.from(
    new Set(
      allowUserIDsRaw
        .filter((item): item is string => typeof item === 'string')
        .map((item) => item.trim())
        .filter(Boolean)
    )
  );

  return {
    categorySwitches,
    channelSwitches,
    grayRelease: {
      enabled:
        typeof grayReleaseRaw.enabled === 'boolean'
          ? grayReleaseRaw.enabled
          : DEFAULT_GLOBAL_CONFIG.grayRelease.enabled,
      percentage: clampPercentage(
        typeof grayReleaseRaw.percentage === 'number'
          ? grayReleaseRaw.percentage
          : DEFAULT_GLOBAL_CONFIG.grayRelease.percentage
      ),
      allowUserIDs,
    },
    governance: {
      rateLimit: {
        enabled:
          typeof rateLimitRaw.enabled === 'boolean'
            ? rateLimitRaw.enabled
            : DEFAULT_GLOBAL_CONFIG.governance.rateLimit.enabled,
        windowSeconds: clampPositiveInt(
          typeof rateLimitRaw.windowSeconds === 'number'
            ? rateLimitRaw.windowSeconds
            : DEFAULT_GLOBAL_CONFIG.governance.rateLimit.windowSeconds,
          DEFAULT_GLOBAL_CONFIG.governance.rateLimit.windowSeconds,
          30,
          24 * 60 * 60
        ),
        maxPerUser: clampPositiveInt(
          typeof rateLimitRaw.maxPerUser === 'number'
            ? rateLimitRaw.maxPerUser
            : DEFAULT_GLOBAL_CONFIG.governance.rateLimit.maxPerUser,
          DEFAULT_GLOBAL_CONFIG.governance.rateLimit.maxPerUser,
          1,
          10_000
        ),
        exemptCategories: normalizeNotificationCategoryList(
          rateLimitRaw.exemptCategories,
          DEFAULT_GLOBAL_CONFIG.governance.rateLimit.exemptCategories
        ),
      },
      quietHours: {
        enabled:
          typeof quietHoursRaw.enabled === 'boolean'
            ? quietHoursRaw.enabled
            : DEFAULT_GLOBAL_CONFIG.governance.quietHours.enabled,
        startHour: clampPositiveInt(
          typeof quietHoursRaw.startHour === 'number'
            ? quietHoursRaw.startHour
            : DEFAULT_GLOBAL_CONFIG.governance.quietHours.startHour,
          DEFAULT_GLOBAL_CONFIG.governance.quietHours.startHour,
          0,
          23
        ),
        endHour: clampPositiveInt(
          typeof quietHoursRaw.endHour === 'number'
            ? quietHoursRaw.endHour
            : DEFAULT_GLOBAL_CONFIG.governance.quietHours.endHour,
          DEFAULT_GLOBAL_CONFIG.governance.quietHours.endHour,
          0,
          23
        ),
        timezone: normalizeTimezone(
          typeof quietHoursRaw.timezone === 'string'
            ? quietHoursRaw.timezone
            : DEFAULT_GLOBAL_CONFIG.governance.quietHours.timezone
        ),
        muteChannels: normalizeNotificationChannelList(
          quietHoursRaw.muteChannels,
          DEFAULT_GLOBAL_CONFIG.governance.quietHours.muteChannels
        ),
        exemptCategories: normalizeNotificationCategoryList(
          quietHoursRaw.exemptCategories,
          DEFAULT_GLOBAL_CONFIG.governance.quietHours.exemptCategories
        ),
      },
    },
  };
};

const shouldAllowUserByGrayRelease = (grayRelease: NotificationAdminGlobalConfig['grayRelease'], userId: string): boolean => {
  const normalizedUserId = userId.trim();
  if (!normalizedUserId) {
    return false;
  }
  if (!grayRelease.enabled) {
    return true;
  }
  if (grayRelease.allowUserIDs.includes(normalizedUserId)) {
    return true;
  }
  const percentage = clampPercentage(grayRelease.percentage);
  if (percentage >= 100) return true;
  if (percentage <= 0) return false;
  return hashToBucket(normalizedUserId) < percentage;
};

const shouldApplyQuietHours = (
  quietHours: NotificationQuietHoursPolicy,
  category: NotificationCategory,
  now: Date
): boolean => {
  if (!quietHours.enabled) {
    return false;
  }
  if (quietHours.exemptCategories.includes(category)) {
    return false;
  }
  const hour = getHourInTimezone(now, quietHours.timezone);
  return isHourInsideWindow(hour, quietHours.startHour, quietHours.endHour);
};

const normalizeEventCountdownPreference = (raw: unknown): EventCountdownPreference => {
  const payload = isRecord(raw) ? raw : {};

  const reminderHoursRaw = Array.isArray(payload.reminderHours)
    ? payload.reminderHours
    : Array.isArray(payload.dailyReminderHours)
      ? payload.dailyReminderHours
      : [];
  const reminderHours = Array.from(
    new Set(
      reminderHoursRaw
        .map((item) => (typeof item === 'number' ? normalizeHour(item) : null))
        .filter((item): item is number => item !== null)
    )
  ).sort((left, right) => left - right);

  const channelsRaw = Array.isArray(payload.channels) ? payload.channels : [];
  const channels = Array.from(
    new Set(
      channelsRaw
        .filter((item): item is string => typeof item === 'string')
        .map((item) => item.trim().toLowerCase())
        .filter((item): item is NotificationChannel => item === 'in_app' || item === 'apns' || item === 'openim')
    )
  );

  const daysBeforeStartRaw =
    typeof payload.daysBeforeStart === 'number'
      ? payload.daysBeforeStart
      : typeof payload.countdownDays === 'number'
        ? payload.countdownDays
        : DEFAULT_EVENT_COUNTDOWN_PREFERENCE.daysBeforeStart;
  const timezoneRaw = typeof payload.timezone === 'string' ? payload.timezone : undefined;

  return {
    enabled:
      typeof payload.enabled === 'boolean'
        ? payload.enabled
        : DEFAULT_EVENT_COUNTDOWN_PREFERENCE.enabled,
    daysBeforeStart: normalizeDaysBeforeStart(daysBeforeStartRaw, DEFAULT_EVENT_COUNTDOWN_PREFERENCE.daysBeforeStart),
    reminderHours:
      reminderHours.length > 0 ? reminderHours : [...DEFAULT_EVENT_COUNTDOWN_PREFERENCE.reminderHours],
    timezone: normalizeTimezone(timezoneRaw),
    channels:
      channels.length > 0 ? channels : [...DEFAULT_EVENT_COUNTDOWN_PREFERENCE.channels],
  };
};

const normalizeEventDailyDigestPreference = (raw: unknown): EventDailyDigestPreference => {
  const payload = isRecord(raw) ? raw : {};

  const reminderHoursRaw = Array.isArray(payload.reminderHours)
    ? payload.reminderHours
    : Array.isArray(payload.dailyReminderHours)
      ? payload.dailyReminderHours
      : [];
  const reminderHours = Array.from(
    new Set(
      reminderHoursRaw
        .map((item) => (typeof item === 'number' ? normalizeHour(item) : null))
        .filter((item): item is number => item !== null)
    )
  ).sort((left, right) => left - right);

  const channelsRaw = Array.isArray(payload.channels) ? payload.channels : [];
  const channels = Array.from(
    new Set(
      channelsRaw
        .filter((item): item is string => typeof item === 'string')
        .map((item) => item.trim().toLowerCase())
        .filter((item): item is NotificationChannel => item === 'in_app' || item === 'apns' || item === 'openim')
    )
  );

  const timezoneRaw = typeof payload.timezone === 'string' ? payload.timezone : undefined;
  const includeNews =
    typeof payload.includeNews === 'boolean'
      ? payload.includeNews
      : typeof payload.includeInfos === 'boolean'
        ? payload.includeInfos
        : DEFAULT_EVENT_DAILY_DIGEST_PREFERENCE.includeNews;
  const includeRatings =
    typeof payload.includeRatings === 'boolean'
      ? payload.includeRatings
      : typeof payload.includeScoring === 'boolean'
        ? payload.includeScoring
        : DEFAULT_EVENT_DAILY_DIGEST_PREFERENCE.includeRatings;
  const includeCheckinReminder =
    typeof payload.includeCheckinReminder === 'boolean'
      ? payload.includeCheckinReminder
      : typeof payload.includeCheckin === 'boolean'
        ? payload.includeCheckin
        : DEFAULT_EVENT_DAILY_DIGEST_PREFERENCE.includeCheckinReminder;

  return {
    enabled:
      typeof payload.enabled === 'boolean'
        ? payload.enabled
        : DEFAULT_EVENT_DAILY_DIGEST_PREFERENCE.enabled,
    reminderHours:
      reminderHours.length > 0 ? reminderHours : [...DEFAULT_EVENT_DAILY_DIGEST_PREFERENCE.reminderHours],
    timezone: normalizeTimezone(timezoneRaw),
    channels:
      channels.length > 0 ? channels : [...DEFAULT_EVENT_DAILY_DIGEST_PREFERENCE.channels],
    includeNews,
    includeRatings,
    includeCheckinReminder,
  };
};

const normalizeRouteDJReminderPreference = (raw: unknown): RouteDJReminderPreference => {
  const payload = isRecord(raw) ? raw : {};

  const channelsRaw = Array.isArray(payload.channels) ? payload.channels : [];
  const channels = Array.from(
    new Set(
      channelsRaw
        .filter((item): item is string => typeof item === 'string')
        .map((item) => item.trim().toLowerCase())
        .filter((item): item is NotificationChannel => item === 'in_app' || item === 'apns' || item === 'openim')
    )
  );
  const timezoneRaw = typeof payload.timezone === 'string' ? payload.timezone : undefined;
  const defaultReminderMinutesBefore = normalizeReminderMinutesBefore(
    typeof payload.defaultReminderMinutesBefore === 'number'
      ? payload.defaultReminderMinutesBefore
      : DEFAULT_ROUTE_DJ_REMINDER_PREFERENCE.defaultReminderMinutesBefore,
    DEFAULT_ROUTE_DJ_REMINDER_PREFERENCE.defaultReminderMinutesBefore
  );

  const watchedSlotsRaw = Array.isArray(payload.watchedSlots)
    ? payload.watchedSlots
    : Array.isArray(payload.routeSlots)
      ? payload.routeSlots
      : [];
  const watchedSlotsMap = new Map<string, RouteDJReminderWatchSlot>();
  for (const item of watchedSlotsRaw) {
    if (!isRecord(item)) {
      continue;
    }
    const eventId = typeof item.eventId === 'string' ? item.eventId.trim() : '';
    const slotId = typeof item.slotId === 'string' ? item.slotId.trim() : '';
    if (!eventId || !slotId) {
      continue;
    }
    const reminderMinutesBefore =
      typeof item.reminderMinutesBefore === 'number'
        ? normalizeReminderMinutesBefore(item.reminderMinutesBefore, defaultReminderMinutesBefore)
        : undefined;
    watchedSlotsMap.set(`${eventId}:${slotId}`, {
      eventId,
      slotId,
      ...(typeof reminderMinutesBefore === 'number' ? { reminderMinutesBefore } : {}),
    });
  }

  return {
    enabled:
      typeof payload.enabled === 'boolean'
        ? payload.enabled
        : DEFAULT_ROUTE_DJ_REMINDER_PREFERENCE.enabled,
    timezone: normalizeTimezone(timezoneRaw),
    channels: channels.length > 0 ? channels : [...DEFAULT_ROUTE_DJ_REMINDER_PREFERENCE.channels],
    defaultReminderMinutesBefore,
    watchedSlots: Array.from(watchedSlotsMap.values()),
  };
};

const normalizeFollowedDJUpdatePreference = (raw: unknown): FollowedDJUpdatePreference => {
  const payload = isRecord(raw) ? raw : {};

  const reminderHoursRaw = Array.isArray(payload.reminderHours)
    ? payload.reminderHours
    : Array.isArray(payload.dailyReminderHours)
      ? payload.dailyReminderHours
      : [];
  const reminderHours = Array.from(
    new Set(
      reminderHoursRaw
        .map((item) => (typeof item === 'number' ? normalizeHour(item) : null))
        .filter((item): item is number => item !== null)
    )
  ).sort((left, right) => left - right);

  const channelsRaw = Array.isArray(payload.channels) ? payload.channels : [];
  const channels = Array.from(
    new Set(
      channelsRaw
        .filter((item): item is string => typeof item === 'string')
        .map((item) => item.trim().toLowerCase())
        .filter((item): item is NotificationChannel => item === 'in_app' || item === 'apns' || item === 'openim')
    )
  );
  const timezoneRaw = typeof payload.timezone === 'string' ? payload.timezone : undefined;

  const includeInfos =
    typeof payload.includeInfos === 'boolean'
      ? payload.includeInfos
      : typeof payload.includeNews === 'boolean'
        ? payload.includeNews
        : DEFAULT_FOLLOWED_DJ_UPDATE_PREFERENCE.includeInfos;
  const includeSets =
    typeof payload.includeSets === 'boolean'
      ? payload.includeSets
      : DEFAULT_FOLLOWED_DJ_UPDATE_PREFERENCE.includeSets;
  const includeRatings =
    typeof payload.includeRatings === 'boolean'
      ? payload.includeRatings
      : DEFAULT_FOLLOWED_DJ_UPDATE_PREFERENCE.includeRatings;

  return {
    enabled:
      typeof payload.enabled === 'boolean'
        ? payload.enabled
        : DEFAULT_FOLLOWED_DJ_UPDATE_PREFERENCE.enabled,
    reminderHours:
      reminderHours.length > 0 ? reminderHours : [...DEFAULT_FOLLOWED_DJ_UPDATE_PREFERENCE.reminderHours],
    timezone: normalizeTimezone(timezoneRaw),
    channels:
      channels.length > 0 ? channels : [...DEFAULT_FOLLOWED_DJ_UPDATE_PREFERENCE.channels],
    includeInfos,
    includeSets,
    includeRatings,
  };
};

const normalizeFollowedBrandUpdatePreference = (raw: unknown): FollowedBrandUpdatePreference => {
  const payload = isRecord(raw) ? raw : {};

  const reminderHoursRaw = Array.isArray(payload.reminderHours)
    ? payload.reminderHours
    : Array.isArray(payload.dailyReminderHours)
      ? payload.dailyReminderHours
      : [];
  const reminderHours = Array.from(
    new Set(
      reminderHoursRaw
        .map((item) => (typeof item === 'number' ? normalizeHour(item) : null))
        .filter((item): item is number => item !== null)
    )
  ).sort((left, right) => left - right);

  const channelsRaw = Array.isArray(payload.channels) ? payload.channels : [];
  const channels = Array.from(
    new Set(
      channelsRaw
        .filter((item): item is string => typeof item === 'string')
        .map((item) => item.trim().toLowerCase())
        .filter((item): item is NotificationChannel => item === 'in_app' || item === 'apns' || item === 'openim')
    )
  );
  const timezoneRaw = typeof payload.timezone === 'string' ? payload.timezone : undefined;
  const watchedBrandIdsRaw = Array.isArray(payload.watchedBrandIds)
    ? payload.watchedBrandIds
    : Array.isArray(payload.brandIds)
      ? payload.brandIds
      : [];
  const watchedBrandIds = Array.from(
    new Set(
      watchedBrandIdsRaw
        .filter((item): item is string => typeof item === 'string')
        .map((item) => item.trim())
        .filter(Boolean)
    )
  );
  const includeInfos =
    typeof payload.includeInfos === 'boolean'
      ? payload.includeInfos
      : typeof payload.includeNews === 'boolean'
        ? payload.includeNews
        : DEFAULT_FOLLOWED_BRAND_UPDATE_PREFERENCE.includeInfos;
  const includeEvents =
    typeof payload.includeEvents === 'boolean'
      ? payload.includeEvents
      : typeof payload.includeActivities === 'boolean'
        ? payload.includeActivities
        : DEFAULT_FOLLOWED_BRAND_UPDATE_PREFERENCE.includeEvents;

  return {
    enabled:
      typeof payload.enabled === 'boolean'
        ? payload.enabled
        : DEFAULT_FOLLOWED_BRAND_UPDATE_PREFERENCE.enabled,
    reminderHours:
      reminderHours.length > 0 ? reminderHours : [...DEFAULT_FOLLOWED_BRAND_UPDATE_PREFERENCE.reminderHours],
    timezone: normalizeTimezone(timezoneRaw),
    channels:
      channels.length > 0 ? channels : [...DEFAULT_FOLLOWED_BRAND_UPDATE_PREFERENCE.channels],
    watchedBrandIds,
    includeInfos,
    includeEvents,
  };
};

const isNotificationCategory = (value: string): value is NotificationCategory => {
  return NOTIFICATION_CATEGORIES.includes(value as NotificationCategory);
};

const seedDefaultTemplatesIfNeeded = async (): Promise<void> => {
  const existingCount = await prisma.notificationTemplate.count();
  if (existingCount > 0) {
    return;
  }

  await prisma.notificationTemplate.createMany({
    data: DEFAULT_TEMPLATE_SEEDS.map((item) => ({
      category: item.category,
      locale: item.locale,
      channel: item.channel,
      titleTemplate: item.titleTemplate,
      bodyTemplate: item.bodyTemplate,
      deeplinkTemplate: item.deeplinkTemplate || null,
      variables: toInputJsonValue(item.variables ?? []),
      isActive: true,
    })),
    skipDuplicates: true,
  });
};

const IOS_PLATFORM_ALIASES = ['ios', 'apns', 'ios_apns'] as const;
const ANDROID_PLATFORM_ALIASES = ['android', 'fcm', 'android_fcm'] as const;

const normalizeDevicePlatform = (raw: string): string => {
  const normalized = raw.trim().toLowerCase();
  if (!normalized) return normalized;
  if ((IOS_PLATFORM_ALIASES as readonly string[]).includes(normalized)) return 'ios';
  if ((ANDROID_PLATFORM_ALIASES as readonly string[]).includes(normalized)) return 'android';
  return normalized;
};

const platformAliasesFor = (platform: string): string[] => {
  if (platform === 'ios') {
    return [...IOS_PLATFORM_ALIASES];
  }
  if (platform === 'android') {
    return [...ANDROID_PLATFORM_ALIASES];
  }
  return [platform];
};

export const notificationCenterService = {
  registerHandler(channel: NotificationChannel, handler: NotificationChannelHandler): void {
    handlers.set(channel, handler);
  },

  async registerDevicePushToken(input: RegisterDevicePushTokenInput): Promise<void> {
    const userId = input.userId.trim();
    const deviceId = input.deviceId.trim();
    const platform = normalizeDevicePlatform(input.platform);
    const pushToken = input.pushToken.trim();
    const appVersion = input.appVersion?.trim() || null;
    const locale = input.locale?.trim() || null;

    if (!userId || !deviceId || !platform || !pushToken) {
      throw new Error('userId/deviceId/platform/pushToken are required');
    }

    await prisma.devicePushToken.upsert({
      where: {
        userId_deviceId_platform: {
          userId,
          deviceId,
          platform,
        },
      },
      update: {
        pushToken,
        isActive: true,
        appVersion,
        locale,
        lastSeenAt: new Date(),
      },
      create: {
        userId,
        deviceId,
        platform,
        pushToken,
        isActive: true,
        appVersion,
        locale,
      },
      select: { id: true },
    });
  },

  async deactivateDevicePushToken(userId: string, deviceId: string, platform: string): Promise<number> {
    const normalizedUserId = userId.trim();
    const normalizedDeviceId = deviceId.trim();
    const normalizedPlatform = normalizeDevicePlatform(platform);
    if (!normalizedUserId || !normalizedDeviceId || !normalizedPlatform) {
      return 0;
    }
    const platformAliases = platformAliasesFor(normalizedPlatform);

    const result = await prisma.devicePushToken.updateMany({
      where: {
        userId: normalizedUserId,
        deviceId: normalizedDeviceId,
        platform: {
          in: platformAliases,
        },
      },
      data: {
        isActive: false,
      },
    });

    return result.count;
  },

  async publish(input: NotificationPublishInput): Promise<NotificationDeliveryResult[]> {
    const dedupeKey = input.dedupeKey?.trim() || null;
    if (dedupeKey) {
      const existing = await prisma.notificationEvent.findFirst({
        where: {
          dedupeKey,
        },
        select: {
          id: true,
        },
      });
      if (existing) {
        return input.channels.map((channel) => ({
          channel,
          success: true,
          detail: `dedupe-skipped:${existing.id}`,
        }));
      }
    }

    const now = new Date();
    const globalConfig = await this.fetchAdminGlobalConfig();
    if (!globalConfig.categorySwitches[input.category]) {
      return input.channels.map((channel) => ({
        channel,
        success: false,
        detail: 'category-disabled-by-admin-config',
      }));
    }

    let configuredChannels = Array.from(new Set(input.channels)).filter((channel) => globalConfig.channelSwitches[channel]);
    if (configuredChannels.length === 0) {
      return input.channels.map((channel) => ({
        channel,
        success: false,
        detail: 'channel-disabled-by-admin-config',
      }));
    }

    if (shouldApplyQuietHours(globalConfig.governance.quietHours, input.category, now)) {
      const mutedChannels = new Set(globalConfig.governance.quietHours.muteChannels);
      configuredChannels = configuredChannels.filter((channel) => !mutedChannels.has(channel));
      if (configuredChannels.length === 0) {
        return input.channels.map((channel) => ({
          channel,
          success: false,
          detail: 'quiet-hours-muted-by-governance',
        }));
      }
    }

    let targets = input.targets
      .filter((target) => target.userId.trim().length > 0)
      .filter((target) => shouldAllowUserByGrayRelease(globalConfig.grayRelease, target.userId));
    if (targets.length === 0) {
      return configuredChannels.map((channel) => ({
        channel,
        success: false,
        detail: 'gray-release-filtered',
      }));
    }

    const rateLimitPolicy = globalConfig.governance.rateLimit;
    if (rateLimitPolicy.enabled && !rateLimitPolicy.exemptCategories.includes(input.category)) {
      const uniqueUserIds = Array.from(new Set(targets.map((target) => target.userId)));
      const since = new Date(now.getTime() - rateLimitPolicy.windowSeconds * 1000);
      const grouped = await prisma.notificationInboxItem.groupBy({
        by: ['userId'],
        where: {
          userId: {
            in: uniqueUserIds,
          },
          createdAt: {
            gte: since,
          },
        },
        _count: {
          _all: true,
        },
      });
      const sentCountMap = new Map(grouped.map((item) => [item.userId, item._count._all]));
      targets = targets.filter((target) => {
        const sent = sentCountMap.get(target.userId) ?? 0;
        return sent < rateLimitPolicy.maxPerUser;
      });
      if (targets.length === 0) {
        return configuredChannels.map((channel) => ({
          channel,
          success: false,
          detail: `rate-limited-by-governance:windowSeconds=${rateLimitPolicy.windowSeconds};maxPerUser=${rateLimitPolicy.maxPerUser}`,
        }));
      }
    }

    const eventRow = await prisma.notificationEvent.create({
      data: {
        category: input.category,
        dedupeKey,
        payload: toInputJsonValue({
          title: input.payload.title,
          body: input.payload.body,
          deeplink: input.payload.deeplink || null,
          badgeDelta: input.payload.badgeDelta ?? 0,
          metadata: input.payload.metadata ?? {},
        }),
        status: 'queued',
      },
      select: { id: true },
    });

    if (configuredChannels.includes('in_app')) {
      await prisma.notificationInboxItem.createMany({
        data: targets.map((target) => ({
          userId: target.userId,
          type: input.category,
          title: input.payload.title,
          body: input.payload.body,
          deeplink: input.payload.deeplink || null,
          metadata: toInputJsonValue(input.payload.metadata ?? {}),
          sourceEventId: eventRow.id,
        })),
      });
    }

    if (NOTIFICATION_OUTBOX_ASYNC_ENABLED) {
      if (configuredChannels.length > 0) {
        await prisma.notificationDelivery.createMany({
          data: targets.flatMap((target) =>
            configuredChannels.map((channel) => {
              const isInApp = channel === 'in_app';
              return {
                eventId: eventRow.id,
                userId: target.userId,
                channel,
                status: isInApp ? 'sent' : 'queued',
                error: null,
                attempts: isInApp ? 1 : 0,
                deliveredAt: isInApp ? now : null,
              };
            })
          ),
        });
      }

      const hasQueuedChannel = configuredChannels.some((channel) => channel !== 'in_app');
      await prisma.notificationEvent.update({
        where: { id: eventRow.id },
        data: {
          status: hasQueuedChannel ? 'queued' : 'sent',
          dispatchedAt: hasQueuedChannel ? null : now,
        },
        select: { id: true },
      });

      return configuredChannels.map((channel) => ({
        channel,
        success: true,
        detail: channel === 'in_app' ? 'stored-to-inbox' : 'queued-for-worker',
        targetResults: targets.map((target) => ({
          userId: target.userId,
          success: true,
          detail: channel === 'in_app' ? 'stored-to-inbox' : 'queued-for-worker',
          attempts: channel === 'in_app' ? 1 : 0,
        })),
      }));
    }

    const runtimeEvent = createRuntimeEvent(eventRow.id, {
      ...input,
      channels: configuredChannels,
      targets,
    });
    const results = await deliverWithHandlers(runtimeEvent);
    const resultMap = new Map(results.map((item) => [item.channel, item]));

    if (configuredChannels.length > 0) {
      await prisma.notificationDelivery.createMany({
        data: targets.flatMap((target) =>
          configuredChannels.map((channel) => {
            const matched = resultMap.get(channel);
            const targetResult = matched?.targetResults?.find((item) => item.userId === target.userId);
            const success = targetResult ? Boolean(targetResult.success) : Boolean(matched?.success);
            return {
              eventId: eventRow.id,
              userId: target.userId,
              channel,
              status: success ? 'sent' : 'failed',
              error: success ? null : targetResult?.detail || matched?.detail || 'delivery-failed',
              attempts: targetResult?.attempts ?? 1,
              deliveredAt: success ? targetResult?.deliveredAt ?? now : null,
            };
          })
        ),
      });
    }

    await prisma.notificationEvent.update({
      where: { id: eventRow.id },
      data: {
        status: results.every((item) => item.success) ? 'sent' : 'partial_failed',
        dispatchedAt: new Date(),
      },
      select: { id: true },
    });

    return results;
  },

  async dispatchQueuedEvents(input?: { eventLimit?: number }) {
    const eventLimit = normalizePositiveLimit(Number(input?.eventLimit ?? 20), 20, 200);
    const report = {
      enabled: NOTIFICATION_OUTBOX_ASYNC_ENABLED,
      scannedEvents: 0,
      processedEvents: 0,
      sentDeliveries: 0,
      failedDeliveries: 0,
      skippedEvents: 0,
      errors: [] as string[],
    };

    if (!NOTIFICATION_OUTBOX_ASYNC_ENABLED) {
      return report;
    }

    const queuedEvents = await prisma.notificationEvent.findMany({
      where: {
        status: {
          in: ['queued', 'dispatching'],
        },
      },
      orderBy: { createdAt: 'asc' },
      take: eventLimit,
      select: {
        id: true,
        category: true,
        dedupeKey: true,
        payload: true,
      },
    });
    report.scannedEvents = queuedEvents.length;

    for (const eventRow of queuedEvents) {
      try {
        const queuedDeliveries = await prisma.notificationDelivery.findMany({
          where: {
            eventId: eventRow.id,
            status: 'queued',
          },
          orderBy: { createdAt: 'asc' },
          select: {
            id: true,
            userId: true,
            channel: true,
            attempts: true,
          },
        });

        if (queuedDeliveries.length === 0) {
          report.skippedEvents += 1;
          continue;
        }

        await prisma.notificationEvent.update({
          where: { id: eventRow.id },
          data: {
            status: 'dispatching',
          },
          select: { id: true },
        });

        const payloadRecord = isRecord(eventRow.payload) ? eventRow.payload : {};
        const payloadTitle = readStringFromRecord(payloadRecord, 'title') || '';
        const payloadBody = readStringFromRecord(payloadRecord, 'body') || '';
        const payloadDeeplink = readStringFromRecord(payloadRecord, 'deeplink');
        const payloadBadgeDelta = readNumberFromRecord(payloadRecord, 'badgeDelta', 0);
        const payloadMetadataRaw = payloadRecord.metadata;
        const payloadMetadata = isRecord(payloadMetadataRaw) ? payloadMetadataRaw : {};

        const channels = Array.from(
          new Set(
            queuedDeliveries
              .map((item) => item.channel.trim().toLowerCase())
              .filter((item): item is NotificationChannel => item === 'in_app' || item === 'apns' || item === 'openim')
          )
        );
        if (channels.length === 0) {
          await prisma.notificationEvent.update({
            where: { id: eventRow.id },
            data: {
              status: 'failed',
              dispatchedAt: new Date(),
            },
            select: { id: true },
          });
          for (const delivery of queuedDeliveries) {
            await prisma.notificationDelivery.update({
              where: { id: delivery.id },
              data: {
                status: 'failed',
                error: 'invalid-queued-channel',
                attempts: delivery.attempts + 1,
              },
              select: { id: true },
            });
            report.failedDeliveries += 1;
          }
          report.processedEvents += 1;
          continue;
        }

        const targets = Array.from(new Set(queuedDeliveries.map((item) => item.userId))).map((userId) => ({ userId }));
        const runtimeEvent = createRuntimeEvent(eventRow.id, {
          category: eventRow.category as NotificationPublishInput['category'],
          targets,
          channels,
          dedupeKey: eventRow.dedupeKey || undefined,
          payload: {
            title: payloadTitle,
            body: payloadBody,
            deeplink: payloadDeeplink,
            badgeDelta: payloadBadgeDelta,
            metadata: payloadMetadata,
          },
        });

        const results = await deliverWithHandlers(runtimeEvent);
        const resultMap = new Map(results.map((item) => [item.channel, item]));
        const now = new Date();

        for (const delivery of queuedDeliveries) {
          const matched = resultMap.get(delivery.channel as NotificationChannel);
          const targetResult = matched?.targetResults?.find((item) => item.userId === delivery.userId);
          const success = targetResult ? Boolean(targetResult.success) : Boolean(matched?.success);
          await prisma.notificationDelivery.update({
            where: { id: delivery.id },
            data: {
              status: success ? 'sent' : 'failed',
              error: success ? null : targetResult?.detail || matched?.detail || 'delivery-failed',
              attempts: delivery.attempts + (targetResult?.attempts ?? 1),
              deliveredAt: success ? targetResult?.deliveredAt ?? now : null,
            },
            select: { id: true },
          });
          if (success) {
            report.sentDeliveries += 1;
          } else {
            report.failedDeliveries += 1;
          }
        }

        const grouped = await prisma.notificationDelivery.groupBy({
          by: ['status'],
          where: {
            eventId: eventRow.id,
          },
          _count: {
            _all: true,
          },
        });
        const statusCount = new Map(grouped.map((item) => [item.status, item._count._all]));
        const queuedCount = statusCount.get('queued') ?? 0;
        const sentCount = statusCount.get('sent') ?? 0;
        const failedCount = statusCount.get('failed') ?? 0;

        const eventStatus =
          queuedCount > 0
            ? 'dispatching'
            : failedCount === 0
              ? 'sent'
              : sentCount === 0
                ? 'failed'
                : 'partial_failed';

        await prisma.notificationEvent.update({
          where: { id: eventRow.id },
          data: {
            status: eventStatus,
            dispatchedAt: queuedCount > 0 ? null : new Date(),
          },
          select: { id: true },
        });

        report.processedEvents += 1;
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        report.errors.push(`event=${eventRow.id} error=${message}`);
      }
    }

    return report;
  },

  async fetchInbox(userId: string, limit = 20) {
    const normalizedUserId = userId.trim();
    if (!normalizedUserId) {
      return [];
    }
    return prisma.notificationInboxItem.findMany({
      where: {
        userId: normalizedUserId,
      },
      orderBy: { createdAt: 'desc' },
      take: normalizePositiveLimit(limit),
      select: {
        id: true,
        type: true,
        title: true,
        body: true,
        deeplink: true,
        metadata: true,
        isRead: true,
        readAt: true,
        createdAt: true,
      },
    });
  },

  async fetchInboxUnreadCount(userId: string): Promise<number> {
    const normalizedUserId = userId.trim();
    if (!normalizedUserId) {
      return 0;
    }
    return prisma.notificationInboxItem.count({
      where: {
        userId: normalizedUserId,
        isRead: false,
      },
    });
  },

  async markInboxRead(userId: string, inboxIds: string[]): Promise<number> {
    const normalizedUserId = userId.trim();
    const normalizedIds = Array.from(
      new Set(
        inboxIds
          .map((item) => item.trim())
          .filter((item) => item.length > 0)
      )
    );
    if (!normalizedUserId || normalizedIds.length === 0) {
      return 0;
    }

    const result = await prisma.notificationInboxItem.updateMany({
      where: {
        userId: normalizedUserId,
        id: {
          in: normalizedIds,
        },
      },
      data: {
        isRead: true,
        readAt: new Date(),
      },
    });
    return result.count;
  },

  async fetchRecentDeliveries(input?: {
    limit?: number;
    channel?: NotificationChannel;
    status?: string;
    userId?: string;
    eventId?: string;
  }) {
    const limit = normalizePositiveLimit(Number(input?.limit ?? 50), 50, 200);
    const where: Prisma.NotificationDeliveryWhereInput = {};
    const channel = input?.channel?.trim();
    if (channel === 'in_app' || channel === 'apns' || channel === 'openim') {
      where.channel = channel;
    }
    const status = input?.status?.trim();
    if (status) {
      where.status = status;
    }
    const userId = input?.userId?.trim();
    if (userId) {
      where.userId = userId;
    }
    const eventId = input?.eventId?.trim();
    if (eventId) {
      where.eventId = eventId;
    }

    return prisma.notificationDelivery.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: limit,
      select: {
        id: true,
        eventId: true,
        userId: true,
        channel: true,
        status: true,
        error: true,
        attempts: true,
        deliveredAt: true,
        createdAt: true,
        updatedAt: true,
        event: {
          select: {
            id: true,
            category: true,
            status: true,
            dedupeKey: true,
            createdAt: true,
            dispatchedAt: true,
          },
        },
        user: {
          select: {
            id: true,
            username: true,
            displayName: true,
          },
        },
      },
    });
  },

  async fetchDeliveryStats(windowHours = 24) {
    const normalizedWindowHours = normalizePositiveWindowHours(windowHours, 24, 24 * 30);
    const since = new Date(Date.now() - normalizedWindowHours * 60 * 60 * 1000);
    const grouped = await prisma.notificationDelivery.groupBy({
      by: ['channel', 'status'],
      where: {
        createdAt: {
          gte: since,
        },
      },
      _count: {
        _all: true,
      },
    });

    const byChannel: Record<string, { sent: number; failed: number; queued: number; total: number }> = {};
    for (const item of grouped) {
      const channel = item.channel.trim().toLowerCase();
      const status = item.status.trim().toLowerCase();
      const count = item._count._all;
      const current = byChannel[channel] || { sent: 0, failed: 0, queued: 0, total: 0 };
      if (status === 'sent') {
        current.sent += count;
      } else if (status === 'failed') {
        current.failed += count;
      } else if (status === 'queued') {
        current.queued += count;
      }
      current.total += count;
      byChannel[channel] = current;
    }

    const totals = Object.values(byChannel).reduce(
      (acc, item) => {
        acc.sent += item.sent;
        acc.failed += item.failed;
        acc.queued += item.queued;
        acc.total += item.total;
        return acc;
      },
      { sent: 0, failed: 0, queued: 0, total: 0 }
    );

    const queueStuckThresholdMinutes = 10;
    const retryHighThreshold = 3;
    const failedRateAlertThreshold = 0.1;
    const staleBefore = new Date(Date.now() - queueStuckThresholdMinutes * 60 * 1000);

    const [
      inboxCreated,
      inboxRead,
      subscriptionTotal,
      subscriptionDisabled,
      subscriptionDisabledUpdatedInWindow,
      retryHighCount,
      staleQueuedEventCount,
      staleQueuedDeliveryCount,
    ] =
      await Promise.all([
        prisma.notificationInboxItem.count({
          where: {
            createdAt: {
              gte: since,
            },
          },
        }),
        prisma.notificationInboxItem.count({
          where: {
            createdAt: {
              gte: since,
            },
            isRead: true,
          },
        }),
        prisma.notificationSubscription.count(),
        prisma.notificationSubscription.count({
          where: {
            enabled: false,
          },
        }),
        prisma.notificationSubscription.count({
          where: {
            enabled: false,
            updatedAt: {
              gte: since,
            },
          },
        }),
        prisma.notificationDelivery.count({
          where: {
            createdAt: {
              gte: since,
            },
            attempts: {
              gte: retryHighThreshold,
            },
          },
        }),
        prisma.notificationEvent.count({
          where: {
            status: 'queued',
            createdAt: {
              lte: staleBefore,
            },
          },
        }),
        prisma.notificationDelivery.count({
          where: {
            status: 'queued',
            createdAt: {
              lte: staleBefore,
            },
          },
        }),
      ]);

    const deliverySuccessRate = toRate(totals.sent, totals.total);
    const deliveryFailureRate = toRate(totals.failed, totals.total);
    const openRate = toRate(inboxRead, inboxCreated);
    const unsubscribeRate = toRate(subscriptionDisabled, subscriptionTotal);

    const alerts = [
      {
        code: 'delivery_failed_rate',
        severity: deliveryFailureRate >= failedRateAlertThreshold ? 'high' : 'info',
        triggered: deliveryFailureRate >= failedRateAlertThreshold,
        value: deliveryFailureRate,
        threshold: failedRateAlertThreshold,
        message: `Delivery failure rate ${Math.round(deliveryFailureRate * 1000) / 10}%`,
      },
      {
        code: 'delivery_retry_high',
        severity: retryHighCount > 0 ? 'medium' : 'info',
        triggered: retryHighCount > 0,
        value: retryHighCount,
        threshold: retryHighThreshold,
        message: `Deliveries with attempts >= ${retryHighThreshold}: ${retryHighCount}`,
      },
      {
        code: 'event_queue_stuck',
        severity: staleQueuedEventCount > 0 ? 'high' : 'info',
        triggered: staleQueuedEventCount > 0,
        value: staleQueuedEventCount,
        threshold: queueStuckThresholdMinutes,
        message: `Queued notification events older than ${queueStuckThresholdMinutes}m: ${staleQueuedEventCount}`,
      },
      {
        code: 'delivery_queue_stuck',
        severity: staleQueuedDeliveryCount > 0 ? 'high' : 'info',
        triggered: staleQueuedDeliveryCount > 0,
        value: staleQueuedDeliveryCount,
        threshold: queueStuckThresholdMinutes,
        message: `Queued deliveries older than ${queueStuckThresholdMinutes}m: ${staleQueuedDeliveryCount}`,
      },
    ] as const;

    return {
      since,
      windowHours: normalizedWindowHours,
      byChannel,
      totals,
      rates: {
        deliverySuccessRate,
        deliveryFailureRate,
      },
      engagement: {
        inboxCreated,
        inboxRead,
        inboxUnread: Math.max(0, inboxCreated - inboxRead),
        openRate,
      },
      subscriptions: {
        total: subscriptionTotal,
        disabled: subscriptionDisabled,
        disabledUpdatedInWindow: subscriptionDisabledUpdatedInWindow,
        unsubscribeRate,
      },
      alerts: {
        triggeredCount: alerts.filter((item) => item.triggered).length,
        queueStuckThresholdMinutes,
        retryHighThreshold,
        failedRateAlertThreshold,
        items: alerts,
      },
    };
  },

  async fetchAdminGlobalConfig(): Promise<NotificationAdminGlobalConfig> {
    const row = await prisma.notificationAdminConfig.findUnique({
      where: {
        configKey: GLOBAL_CONFIG_KEY,
      },
      select: {
        config: true,
      },
    });
    if (!row) {
      return { ...DEFAULT_GLOBAL_CONFIG };
    }
    return normalizeGlobalConfig(row.config);
  },

  async updateAdminGlobalConfig(input: unknown, updatedBy?: string | null): Promise<NotificationAdminGlobalConfig> {
    const normalizedConfig = normalizeGlobalConfig(input);
    await prisma.notificationAdminConfig.upsert({
      where: {
        configKey: GLOBAL_CONFIG_KEY,
      },
      update: {
        config: toInputJsonValue(normalizedConfig),
        updatedBy: updatedBy?.trim() || null,
      },
      create: {
        configKey: GLOBAL_CONFIG_KEY,
        config: toInputJsonValue(normalizedConfig),
        updatedBy: updatedBy?.trim() || null,
      },
      select: {
        id: true,
      },
    });
    return normalizedConfig;
  },

  async fetchAdminTemplates(input?: {
    limit?: number;
    category?: string;
    locale?: string;
    channel?: NotificationChannel;
    isActive?: boolean;
  }) {
    await seedDefaultTemplatesIfNeeded();

    const limit = normalizePositiveLimit(Number(input?.limit ?? 50), 50, 200);
    const where: Prisma.NotificationTemplateWhereInput = {};
    const category = input?.category?.trim();
    if (category) {
      where.category = category;
    }
    const locale = input?.locale?.trim();
    if (locale) {
      where.locale = locale;
    }
    const channel = input?.channel?.trim();
    if (channel === 'in_app' || channel === 'apns' || channel === 'openim') {
      where.channel = channel;
    }
    if (typeof input?.isActive === 'boolean') {
      where.isActive = input.isActive;
    }

    return prisma.notificationTemplate.findMany({
      where,
      orderBy: [{ updatedAt: 'desc' }, { category: 'asc' }],
      take: limit,
      select: {
        id: true,
        category: true,
        locale: true,
        channel: true,
        titleTemplate: true,
        bodyTemplate: true,
        deeplinkTemplate: true,
        variables: true,
        isActive: true,
        createdAt: true,
        updatedAt: true,
      },
    });
  },

  async upsertAdminTemplate(input: {
    category: string;
    locale: string;
    channel: NotificationChannel;
    titleTemplate: string;
    bodyTemplate: string;
    deeplinkTemplate?: string | null;
    variables?: unknown;
    isActive?: boolean;
  }) {
    const category = input.category.trim();
    const locale = input.locale.trim() || 'zh-CN';
    const channel = input.channel.trim().toLowerCase();
    const titleTemplate = input.titleTemplate.trim();
    const bodyTemplate = input.bodyTemplate.trim();
    const deeplinkTemplate = input.deeplinkTemplate?.trim() || null;
    const isActive = typeof input.isActive === 'boolean' ? input.isActive : true;
    if (!category || !titleTemplate || !bodyTemplate) {
      throw new Error('category/titleTemplate/bodyTemplate are required');
    }
    if (!isNotificationCategory(category)) {
      throw new Error(`unsupported notification category: ${category}`);
    }
    if (channel !== 'in_app' && channel !== 'apns' && channel !== 'openim') {
      throw new Error(`unsupported notification channel: ${channel}`);
    }

    const normalizedVariables = Array.isArray(input.variables)
      ? Array.from(
          new Set(
            input.variables
              .filter((item): item is string => typeof item === 'string')
              .map((item) => item.trim())
              .filter(Boolean)
          )
        )
      : [];

    return prisma.notificationTemplate.upsert({
      where: {
        category_locale_channel: {
          category,
          locale,
          channel,
        },
      },
      update: {
        titleTemplate,
        bodyTemplate,
        deeplinkTemplate,
        variables: toInputJsonValue(normalizedVariables),
        isActive,
      },
      create: {
        category,
        locale,
        channel,
        titleTemplate,
        bodyTemplate,
        deeplinkTemplate,
        variables: toInputJsonValue(normalizedVariables),
        isActive,
      },
      select: {
        id: true,
        category: true,
        locale: true,
        channel: true,
        titleTemplate: true,
        bodyTemplate: true,
        deeplinkTemplate: true,
        variables: true,
        isActive: true,
        createdAt: true,
        updatedAt: true,
      },
    });
  },

  async fetchEventCountdownPreference(userId: string): Promise<EventCountdownPreference> {
    const normalizedUserId = userId.trim();
    if (!normalizedUserId) {
      return { ...DEFAULT_EVENT_COUNTDOWN_PREFERENCE };
    }

    const row = await prisma.notificationSubscription.findUnique({
      where: {
        userId_category: {
          userId: normalizedUserId,
          category: 'event_countdown',
        },
      },
      select: {
        enabled: true,
        frequencyConfig: true,
      },
    });

    if (!row) {
      return { ...DEFAULT_EVENT_COUNTDOWN_PREFERENCE };
    }
    const preference = normalizeEventCountdownPreference(row.frequencyConfig);
    return {
      ...preference,
      enabled: row.enabled,
    };
  },

  async updateEventCountdownPreference(userId: string, input: unknown): Promise<EventCountdownPreference> {
    const normalizedUserId = userId.trim();
    if (!normalizedUserId) {
      throw new Error('userId is required');
    }

    const existing = await this.fetchEventCountdownPreference(normalizedUserId);
    const payload = isRecord(input) ? input : {};
    const mergedInput: Record<string, unknown> = {
      enabled: existing.enabled,
      daysBeforeStart: existing.daysBeforeStart,
      reminderHours: existing.reminderHours,
      timezone: existing.timezone,
      channels: existing.channels,
    };
    if (typeof payload.enabled === 'boolean') {
      mergedInput.enabled = payload.enabled;
    }
    if (typeof payload.daysBeforeStart === 'number') {
      mergedInput.daysBeforeStart = payload.daysBeforeStart;
    }
    if (Array.isArray(payload.reminderHours)) {
      mergedInput.reminderHours = payload.reminderHours;
    }
    if (typeof payload.timezone === 'string') {
      mergedInput.timezone = payload.timezone;
    }
    if (Array.isArray(payload.channels)) {
      mergedInput.channels = payload.channels;
    }

    const preference = normalizeEventCountdownPreference(mergedInput);

    await prisma.notificationSubscription.upsert({
      where: {
        userId_category: {
          userId: normalizedUserId,
          category: 'event_countdown',
        },
      },
      update: {
        enabled: preference.enabled,
        frequencyConfig: toInputJsonValue(preference),
      },
      create: {
        userId: normalizedUserId,
        category: 'event_countdown',
        enabled: preference.enabled,
        frequencyConfig: toInputJsonValue(preference),
      },
      select: {
        id: true,
      },
    });

    return preference;
  },

  async fetchEventCountdownSubscriptions(userIds?: string[]): Promise<
    Array<{
      userId: string;
      preference: EventCountdownPreference;
    }>
  > {
    const normalizedUserIds = Array.from(
      new Set(
        (userIds ?? [])
          .map((item) => item.trim())
          .filter(Boolean)
      )
    );

    const rows = await prisma.notificationSubscription.findMany({
      where: {
        category: 'event_countdown',
        ...(normalizedUserIds.length > 0
          ? {
              userId: {
                in: normalizedUserIds,
              },
            }
          : {}),
      },
      select: {
        userId: true,
        enabled: true,
        frequencyConfig: true,
      },
    });

    return rows.map((row) => {
      const preference = normalizeEventCountdownPreference(row.frequencyConfig);
      return {
        userId: row.userId,
        preference: {
          ...preference,
          enabled: row.enabled,
        },
      };
    });
  },

  async fetchMarkedEventCountdownCandidates(input: {
    userIds: string[];
    maxDaysBeforeStart: number;
  }): Promise<
    Array<{
      userId: string;
      eventId: string;
      eventName: string;
      eventStartDate: Date;
    }>
  > {
    const normalizedUserIds = Array.from(
      new Set(
        input.userIds
          .map((item) => item.trim())
          .filter(Boolean)
      )
    );
    if (normalizedUserIds.length === 0) {
      return [];
    }

    const maxDaysBeforeStart = normalizeDaysBeforeStart(input.maxDaysBeforeStart, 3);
    const now = new Date();
    const until = new Date(now.getTime() + (maxDaysBeforeStart + 1) * 24 * 60 * 60 * 1000);
    const rows = await prisma.checkin.findMany({
      where: {
        userId: {
          in: normalizedUserIds,
        },
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
        eventId: true,
        event: {
          select: {
            id: true,
            name: true,
            startDate: true,
          },
        },
      },
      orderBy: [{ event: { startDate: 'asc' } }, { createdAt: 'desc' }],
    });

    const unique = new Map<string, { userId: string; eventId: string; eventName: string; eventStartDate: Date }>();
    for (const row of rows) {
      const event = row.event;
      const eventId = row.eventId?.trim();
      if (!event || !eventId) {
        continue;
      }
      const key = `${row.userId}:${eventId}`;
      if (unique.has(key)) {
        continue;
      }
      unique.set(key, {
        userId: row.userId,
        eventId,
        eventName: event.name,
        eventStartDate: event.startDate,
      });
    }

    return Array.from(unique.values());
  },

  async fetchEventDailyDigestPreference(userId: string): Promise<EventDailyDigestPreference> {
    const normalizedUserId = userId.trim();
    if (!normalizedUserId) {
      return { ...DEFAULT_EVENT_DAILY_DIGEST_PREFERENCE };
    }

    const row = await prisma.notificationSubscription.findUnique({
      where: {
        userId_category: {
          userId: normalizedUserId,
          category: 'event_daily_digest',
        },
      },
      select: {
        enabled: true,
        frequencyConfig: true,
      },
    });

    if (!row) {
      return { ...DEFAULT_EVENT_DAILY_DIGEST_PREFERENCE };
    }
    const preference = normalizeEventDailyDigestPreference(row.frequencyConfig);
    return {
      ...preference,
      enabled: row.enabled,
    };
  },

  async updateEventDailyDigestPreference(userId: string, input: unknown): Promise<EventDailyDigestPreference> {
    const normalizedUserId = userId.trim();
    if (!normalizedUserId) {
      throw new Error('userId is required');
    }

    const existing = await this.fetchEventDailyDigestPreference(normalizedUserId);
    const payload = isRecord(input) ? input : {};
    const mergedInput: Record<string, unknown> = {
      enabled: existing.enabled,
      reminderHours: existing.reminderHours,
      timezone: existing.timezone,
      channels: existing.channels,
      includeNews: existing.includeNews,
      includeRatings: existing.includeRatings,
      includeCheckinReminder: existing.includeCheckinReminder,
    };
    if (typeof payload.enabled === 'boolean') {
      mergedInput.enabled = payload.enabled;
    }
    if (Array.isArray(payload.reminderHours)) {
      mergedInput.reminderHours = payload.reminderHours;
    }
    if (typeof payload.timezone === 'string') {
      mergedInput.timezone = payload.timezone;
    }
    if (Array.isArray(payload.channels)) {
      mergedInput.channels = payload.channels;
    }
    if (typeof payload.includeNews === 'boolean') {
      mergedInput.includeNews = payload.includeNews;
    }
    if (typeof payload.includeRatings === 'boolean') {
      mergedInput.includeRatings = payload.includeRatings;
    }
    if (typeof payload.includeCheckinReminder === 'boolean') {
      mergedInput.includeCheckinReminder = payload.includeCheckinReminder;
    }

    const preference = normalizeEventDailyDigestPreference(mergedInput);

    await prisma.notificationSubscription.upsert({
      where: {
        userId_category: {
          userId: normalizedUserId,
          category: 'event_daily_digest',
        },
      },
      update: {
        enabled: preference.enabled,
        frequencyConfig: toInputJsonValue(preference),
      },
      create: {
        userId: normalizedUserId,
        category: 'event_daily_digest',
        enabled: preference.enabled,
        frequencyConfig: toInputJsonValue(preference),
      },
      select: {
        id: true,
      },
    });

    return preference;
  },

  async fetchEventDailyDigestSubscriptions(userIds?: string[]): Promise<
    Array<{
      userId: string;
      preference: EventDailyDigestPreference;
    }>
  > {
    const normalizedUserIds = Array.from(
      new Set(
        (userIds ?? [])
          .map((item) => item.trim())
          .filter(Boolean)
      )
    );

    const rows = await prisma.notificationSubscription.findMany({
      where: {
        category: 'event_daily_digest',
        ...(normalizedUserIds.length > 0
          ? {
              userId: {
                in: normalizedUserIds,
              },
            }
          : {}),
      },
      select: {
        userId: true,
        enabled: true,
        frequencyConfig: true,
      },
    });

    return rows.map((row) => {
      const preference = normalizeEventDailyDigestPreference(row.frequencyConfig);
      return {
        userId: row.userId,
        preference: {
          ...preference,
          enabled: row.enabled,
        },
      };
    });
  },

  async fetchMarkedEventDailyDigestCandidates(input: {
    userIds: string[];
    maxDaysBeforeStart: number;
    maxDaysAfterEnd: number;
  }): Promise<
    Array<{
      userId: string;
      eventId: string;
      eventName: string;
      eventStartDate: Date;
      eventEndDate: Date;
    }>
  > {
    const normalizedUserIds = Array.from(
      new Set(
        input.userIds
          .map((item) => item.trim())
          .filter(Boolean)
      )
    );
    if (normalizedUserIds.length === 0) {
      return [];
    }

    const maxDaysBeforeStart = normalizeDaysBeforeStart(input.maxDaysBeforeStart, 14);
    const maxDaysAfterEnd = normalizeDaysBeforeStart(input.maxDaysAfterEnd, 1);
    const now = new Date();
    const until = new Date(now.getTime() + (maxDaysBeforeStart + 1) * 24 * 60 * 60 * 1000);
    const since = new Date(now.getTime() - maxDaysAfterEnd * 24 * 60 * 60 * 1000);
    const rows = await prisma.checkin.findMany({
      where: {
        userId: {
          in: normalizedUserIds,
        },
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
        eventId: true,
        event: {
          select: {
            id: true,
            name: true,
            startDate: true,
            endDate: true,
          },
        },
      },
      orderBy: [{ event: { startDate: 'asc' } }, { createdAt: 'desc' }],
    });

    const unique = new Map<
      string,
      { userId: string; eventId: string; eventName: string; eventStartDate: Date; eventEndDate: Date }
    >();
    for (const row of rows) {
      const event = row.event;
      const eventId = row.eventId?.trim();
      if (!event || !eventId) {
        continue;
      }
      const key = `${row.userId}:${eventId}`;
      if (unique.has(key)) {
        continue;
      }
      unique.set(key, {
        userId: row.userId,
        eventId,
        eventName: event.name,
        eventStartDate: event.startDate,
        eventEndDate: event.endDate,
      });
    }

    return Array.from(unique.values());
  },

  async fetchRouteDJReminderPreference(userId: string): Promise<RouteDJReminderPreference> {
    const normalizedUserId = userId.trim();
    if (!normalizedUserId) {
      return { ...DEFAULT_ROUTE_DJ_REMINDER_PREFERENCE };
    }

    const row = await prisma.notificationSubscription.findUnique({
      where: {
        userId_category: {
          userId: normalizedUserId,
          category: 'route_dj_reminder',
        },
      },
      select: {
        enabled: true,
        frequencyConfig: true,
      },
    });

    if (!row) {
      return { ...DEFAULT_ROUTE_DJ_REMINDER_PREFERENCE };
    }
    const preference = normalizeRouteDJReminderPreference(row.frequencyConfig);
    return {
      ...preference,
      enabled: row.enabled,
    };
  },

  async updateRouteDJReminderPreference(userId: string, input: unknown): Promise<RouteDJReminderPreference> {
    const normalizedUserId = userId.trim();
    if (!normalizedUserId) {
      throw new Error('userId is required');
    }

    const existing = await this.fetchRouteDJReminderPreference(normalizedUserId);
    const payload = isRecord(input) ? input : {};
    const mergedInput: Record<string, unknown> = {
      enabled: existing.enabled,
      timezone: existing.timezone,
      channels: existing.channels,
      defaultReminderMinutesBefore: existing.defaultReminderMinutesBefore,
      watchedSlots: existing.watchedSlots,
    };
    if (typeof payload.enabled === 'boolean') {
      mergedInput.enabled = payload.enabled;
    }
    if (typeof payload.timezone === 'string') {
      mergedInput.timezone = payload.timezone;
    }
    if (Array.isArray(payload.channels)) {
      mergedInput.channels = payload.channels;
    }
    if (typeof payload.defaultReminderMinutesBefore === 'number') {
      mergedInput.defaultReminderMinutesBefore = payload.defaultReminderMinutesBefore;
    }
    if (Array.isArray(payload.watchedSlots)) {
      mergedInput.watchedSlots = payload.watchedSlots;
    }

    const preference = normalizeRouteDJReminderPreference(mergedInput);

    await prisma.notificationSubscription.upsert({
      where: {
        userId_category: {
          userId: normalizedUserId,
          category: 'route_dj_reminder',
        },
      },
      update: {
        enabled: preference.enabled,
        frequencyConfig: toInputJsonValue(preference),
      },
      create: {
        userId: normalizedUserId,
        category: 'route_dj_reminder',
        enabled: preference.enabled,
        frequencyConfig: toInputJsonValue(preference),
      },
      select: {
        id: true,
      },
    });

    return preference;
  },

  async fetchRouteDJReminderSubscriptions(userIds?: string[]): Promise<
    Array<{
      userId: string;
      preference: RouteDJReminderPreference;
    }>
  > {
    const normalizedUserIds = Array.from(
      new Set(
        (userIds ?? [])
          .map((item) => item.trim())
          .filter(Boolean)
      )
    );

    const rows = await prisma.notificationSubscription.findMany({
      where: {
        category: 'route_dj_reminder',
        ...(normalizedUserIds.length > 0
          ? {
              userId: {
                in: normalizedUserIds,
              },
            }
          : {}),
      },
      select: {
        userId: true,
        enabled: true,
        frequencyConfig: true,
      },
    });

    return rows.map((row) => {
      const preference = normalizeRouteDJReminderPreference(row.frequencyConfig);
      return {
        userId: row.userId,
        preference: {
          ...preference,
          enabled: row.enabled,
        },
      };
    });
  },

  async fetchFollowedDJUpdatePreference(userId: string): Promise<FollowedDJUpdatePreference> {
    const normalizedUserId = userId.trim();
    if (!normalizedUserId) {
      return { ...DEFAULT_FOLLOWED_DJ_UPDATE_PREFERENCE };
    }

    const row = await prisma.notificationSubscription.findUnique({
      where: {
        userId_category: {
          userId: normalizedUserId,
          category: 'followed_dj_update',
        },
      },
      select: {
        enabled: true,
        frequencyConfig: true,
      },
    });

    if (!row) {
      return { ...DEFAULT_FOLLOWED_DJ_UPDATE_PREFERENCE };
    }
    const preference = normalizeFollowedDJUpdatePreference(row.frequencyConfig);
    return {
      ...preference,
      enabled: row.enabled,
    };
  },

  async updateFollowedDJUpdatePreference(userId: string, input: unknown): Promise<FollowedDJUpdatePreference> {
    const normalizedUserId = userId.trim();
    if (!normalizedUserId) {
      throw new Error('userId is required');
    }

    const existing = await this.fetchFollowedDJUpdatePreference(normalizedUserId);
    const payload = isRecord(input) ? input : {};
    const mergedInput: Record<string, unknown> = {
      enabled: existing.enabled,
      reminderHours: existing.reminderHours,
      timezone: existing.timezone,
      channels: existing.channels,
      includeInfos: existing.includeInfos,
      includeSets: existing.includeSets,
      includeRatings: existing.includeRatings,
    };
    if (typeof payload.enabled === 'boolean') {
      mergedInput.enabled = payload.enabled;
    }
    if (Array.isArray(payload.reminderHours)) {
      mergedInput.reminderHours = payload.reminderHours;
    }
    if (typeof payload.timezone === 'string') {
      mergedInput.timezone = payload.timezone;
    }
    if (Array.isArray(payload.channels)) {
      mergedInput.channels = payload.channels;
    }
    if (typeof payload.includeInfos === 'boolean') {
      mergedInput.includeInfos = payload.includeInfos;
    }
    if (typeof payload.includeSets === 'boolean') {
      mergedInput.includeSets = payload.includeSets;
    }
    if (typeof payload.includeRatings === 'boolean') {
      mergedInput.includeRatings = payload.includeRatings;
    }

    const preference = normalizeFollowedDJUpdatePreference(mergedInput);

    await prisma.notificationSubscription.upsert({
      where: {
        userId_category: {
          userId: normalizedUserId,
          category: 'followed_dj_update',
        },
      },
      update: {
        enabled: preference.enabled,
        frequencyConfig: toInputJsonValue(preference),
      },
      create: {
        userId: normalizedUserId,
        category: 'followed_dj_update',
        enabled: preference.enabled,
        frequencyConfig: toInputJsonValue(preference),
      },
      select: {
        id: true,
      },
    });

    return preference;
  },

  async fetchFollowedDJUpdateSubscriptions(userIds?: string[]): Promise<
    Array<{
      userId: string;
      preference: FollowedDJUpdatePreference;
    }>
  > {
    const normalizedUserIds = Array.from(
      new Set(
        (userIds ?? [])
          .map((item) => item.trim())
          .filter(Boolean)
      )
    );

    const rows = await prisma.notificationSubscription.findMany({
      where: {
        category: 'followed_dj_update',
        ...(normalizedUserIds.length > 0
          ? {
              userId: {
                in: normalizedUserIds,
              },
            }
          : {}),
      },
      select: {
        userId: true,
        enabled: true,
        frequencyConfig: true,
      },
    });

    return rows.map((row) => {
      const preference = normalizeFollowedDJUpdatePreference(row.frequencyConfig);
      return {
        userId: row.userId,
        preference: {
          ...preference,
          enabled: row.enabled,
        },
      };
    });
  },

  async fetchFollowedBrandUpdatePreference(userId: string): Promise<FollowedBrandUpdatePreference> {
    const normalizedUserId = userId.trim();
    if (!normalizedUserId) {
      return { ...DEFAULT_FOLLOWED_BRAND_UPDATE_PREFERENCE };
    }

    const row = await prisma.notificationSubscription.findUnique({
      where: {
        userId_category: {
          userId: normalizedUserId,
          category: 'followed_brand_update',
        },
      },
      select: {
        enabled: true,
        frequencyConfig: true,
      },
    });

    if (!row) {
      return { ...DEFAULT_FOLLOWED_BRAND_UPDATE_PREFERENCE };
    }
    const preference = normalizeFollowedBrandUpdatePreference(row.frequencyConfig);
    return {
      ...preference,
      enabled: row.enabled,
    };
  },

  async updateFollowedBrandUpdatePreference(userId: string, input: unknown): Promise<FollowedBrandUpdatePreference> {
    const normalizedUserId = userId.trim();
    if (!normalizedUserId) {
      throw new Error('userId is required');
    }

    const existing = await this.fetchFollowedBrandUpdatePreference(normalizedUserId);
    const payload = isRecord(input) ? input : {};
    const mergedInput: Record<string, unknown> = {
      enabled: existing.enabled,
      reminderHours: existing.reminderHours,
      timezone: existing.timezone,
      channels: existing.channels,
      watchedBrandIds: existing.watchedBrandIds,
      includeInfos: existing.includeInfos,
      includeEvents: existing.includeEvents,
    };
    if (typeof payload.enabled === 'boolean') {
      mergedInput.enabled = payload.enabled;
    }
    if (Array.isArray(payload.reminderHours)) {
      mergedInput.reminderHours = payload.reminderHours;
    }
    if (typeof payload.timezone === 'string') {
      mergedInput.timezone = payload.timezone;
    }
    if (Array.isArray(payload.channels)) {
      mergedInput.channels = payload.channels;
    }
    if (Array.isArray(payload.watchedBrandIds)) {
      mergedInput.watchedBrandIds = payload.watchedBrandIds;
    }
    if (typeof payload.includeInfos === 'boolean') {
      mergedInput.includeInfos = payload.includeInfos;
    }
    if (typeof payload.includeEvents === 'boolean') {
      mergedInput.includeEvents = payload.includeEvents;
    }

    const preference = normalizeFollowedBrandUpdatePreference(mergedInput);

    await prisma.notificationSubscription.upsert({
      where: {
        userId_category: {
          userId: normalizedUserId,
          category: 'followed_brand_update',
        },
      },
      update: {
        enabled: preference.enabled,
        frequencyConfig: toInputJsonValue(preference),
      },
      create: {
        userId: normalizedUserId,
        category: 'followed_brand_update',
        enabled: preference.enabled,
        frequencyConfig: toInputJsonValue(preference),
      },
      select: {
        id: true,
      },
    });

    return preference;
  },

  async fetchFollowedBrandUpdateSubscriptions(userIds?: string[]): Promise<
    Array<{
      userId: string;
      preference: FollowedBrandUpdatePreference;
    }>
  > {
    const normalizedUserIds = Array.from(
      new Set(
        (userIds ?? [])
          .map((item) => item.trim())
          .filter(Boolean)
      )
    );

    const rows = await prisma.notificationSubscription.findMany({
      where: {
        category: 'followed_brand_update',
        ...(normalizedUserIds.length > 0
          ? {
              userId: {
                in: normalizedUserIds,
              },
            }
          : {}),
      },
      select: {
        userId: true,
        enabled: true,
        frequencyConfig: true,
      },
    });

    return rows.map((row) => {
      const preference = normalizeFollowedBrandUpdatePreference(row.frequencyConfig);
      return {
        userId: row.userId,
        preference: {
          ...preference,
          enabled: row.enabled,
        },
      };
    });
  },
};
