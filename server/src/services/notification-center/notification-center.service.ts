import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import {
  USER_ENTITY_RELATION_FAVORITE,
  USER_ENTITY_TARGET_EVENT,
} from '../user-entity-follow.service';
import type {
  NotificationChannel,
  NotificationChannelHandler,
  NotificationDeliveryResult,
  NotificationEvent,
  NotificationPayload,
  NotificationPublishInput,
  RegisterDevicePushTokenInput,
} from './notification-center.types';

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
const NOTIFICATION_CHANNELS = ['in_app', 'apns', 'email', 'sms'] as const satisfies readonly NotificationChannel[];
const DELIVERABLE_NOTIFICATION_CHANNELS = ['in_app', 'apns'] as const satisfies readonly NotificationChannel[];

const isNotificationChannel = (value: string): value is NotificationChannel =>
  (NOTIFICATION_CHANNELS as readonly string[]).includes(value);

const isDeliverableNotificationChannel = (value: string): value is NotificationChannel =>
  (DELIVERABLE_NOTIFICATION_CHANNELS as readonly string[]).includes(value);

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

const startOfUTCDate = (date: Date): Date =>
  new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));

const endOfUTCDate = (date: Date): Date =>
  new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate(), 23, 59, 59, 999));

const sortDatesAscending = (values: Date[]): Date[] =>
  values.slice().sort((lhs, rhs) => lhs.getTime() - rhs.getTime());

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

const toPositiveSafeInteger = (value: unknown): number => {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return Math.max(0, Math.floor(value));
  }
  if (typeof value === 'bigint') {
    return Number(value > 0n ? value : 0n);
  }
  if (typeof value === 'string') {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? Math.max(0, Math.floor(parsed)) : 0;
  }
  return 0;
};

const NOTIFICATION_CATEGORIES = [
  'chat_message',
  'community_interaction',
  'event_countdown',
  'event_daily_digest',
  'route_dj_reminder',
  'followed_dj_update',
  'followed_brand_update',
  'account_enforcement',
  'content_review',
  'report_decision',
  'major_news',
] as const;

type NotificationCategory = (typeof NOTIFICATION_CATEGORIES)[number];
export const NOTIFICATION_ADMIN_DELIVERY_SECTIONS = [
  'event_news',
  'event_release',
  'followed_dj_news',
  'followed_dj_event',
  'followed_brand_news',
  'followed_brand_event',
  'major_news_broadcast',
  'event_schedule',
  'chat_and_community',
  'moderation_and_system',
  'other',
] as const;

export type NotificationAdminDeliverySection = (typeof NOTIFICATION_ADMIN_DELIVERY_SECTIONS)[number];

export const NOTIFICATION_ADMIN_PUBLISH_TASK_TYPES = [
  'news_release',
  'event_release',
  'dj_release',
  'brand_release',
] as const;

export type NotificationAdminPublishTaskType = (typeof NOTIFICATION_ADMIN_PUBLISH_TASK_TYPES)[number];
export type NotificationAdminPublishTaskStatus = 'pending' | 'published' | 'rejected';

export type NotificationAdminPublishTaskListItem = {
  id: string;
  taskType: NotificationAdminPublishTaskType;
  entityType: string;
  entityId: string;
  status: NotificationAdminPublishTaskStatus;
  title: string;
  summary: string | null;
  createdBy: string | null;
  decidedBy: string | null;
  decidedAt: string | null;
  createdAt: string;
  updatedAt: string;
};

export type NotificationAdminPublishTaskRecord = NotificationAdminPublishTaskListItem & {
  payload: unknown;
  decision: unknown;
};

export type NotificationAdminPublishTaskPage = {
  items: NotificationAdminPublishTaskListItem[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
};

export type NotificationAdminDeliverySectionSummary = {
  section: NotificationAdminDeliverySection;
  total: number;
  apnsCount: number;
  inAppCount: number;
  failedCount: number;
  lastDeliveryAt: string | null;
};

export type NotificationAdminDeliveryListItem = {
  id: string;
  section: NotificationAdminDeliverySection;
  eventId: string;
  userId: string;
  channel: NotificationChannel | string;
  status: string;
  error: string | null;
  attempts: number;
  deliveredAt: string | null;
  createdAt: string;
  updatedAt: string;
  payload: {
    title: string | null;
    body: string | null;
    deeplink: string | null;
  };
  metadata: {
    route: string | null;
    source: string | null;
    newsId: string | null;
    newsTitle: string | null;
    eventId: string | null;
    eventName: string | null;
    djId: string | null;
    djName: string | null;
    brandId: string | null;
    brandName: string | null;
    audience: string | null;
  };
  event: {
    id: string;
    category: string;
    status: string;
    dedupeKey: string | null;
    createdAt: string;
    dispatchedAt: string | null;
  };
  user: {
    id: string;
    username: string;
    displayName: string | null;
  };
};

export type NotificationAdminDeliveryPage = {
  section: NotificationAdminDeliverySection;
  items: NotificationAdminDeliveryListItem[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
};

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

export type NotificationCategoryPreference = {
  category: NotificationCategory;
  enabled: boolean;
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
const NOTIFICATION_DELIVERY_SECTION_CASE_SQL = Prisma.sql`
  CASE
    WHEN e.category = 'major_news'
      AND COALESCE(e.payload #>> '{metadata,route}', '') = 'event_update'
      AND COALESCE(e.payload #>> '{metadata,primaryUpdateKind}', COALESCE(e.payload #>> '{metadata,updateKind}', '')) = 'news'
      THEN 'event_news'
    WHEN e.category = 'major_news'
      AND COALESCE(e.payload #>> '{metadata,route}', '') = 'event_update'
      AND COALESCE(e.payload #>> '{metadata,primaryUpdateKind}', COALESCE(e.payload #>> '{metadata,updateKind}', '')) = 'event'
      THEN 'event_release'
    WHEN e.category = 'followed_dj_update'
      AND COALESCE(e.payload #>> '{metadata,primaryUpdateKind}', COALESCE(e.payload #>> '{metadata,updateKind}', '')) = 'news'
      THEN 'followed_dj_news'
    WHEN e.category = 'followed_dj_update'
      AND COALESCE(e.payload #>> '{metadata,primaryUpdateKind}', COALESCE(e.payload #>> '{metadata,updateKind}', '')) = 'event'
      THEN 'followed_dj_event'
    WHEN e.category = 'followed_brand_update'
      AND COALESCE(e.payload #>> '{metadata,primaryUpdateKind}', COALESCE(e.payload #>> '{metadata,updateKind}', '')) = 'news'
      THEN 'followed_brand_news'
    WHEN e.category = 'followed_brand_update'
      AND COALESCE(e.payload #>> '{metadata,primaryUpdateKind}', COALESCE(e.payload #>> '{metadata,updateKind}', '')) = 'event'
      THEN 'followed_brand_event'
    WHEN e.category = 'major_news'
      THEN 'major_news_broadcast'
    WHEN e.category IN ('event_countdown', 'event_daily_digest', 'route_dj_reminder')
      THEN 'event_schedule'
    WHEN e.category IN ('chat_message', 'community_interaction')
      THEN 'chat_and_community'
    WHEN e.category IN ('content_review', 'report_decision', 'account_enforcement')
      THEN 'moderation_and_system'
    ELSE 'other'
  END
`;

const isNotificationAdminDeliverySection = (value: string): value is NotificationAdminDeliverySection =>
  (NOTIFICATION_ADMIN_DELIVERY_SECTIONS as readonly string[]).includes(value);

const isNotificationAdminPublishTaskType = (value: string): value is NotificationAdminPublishTaskType =>
  (NOTIFICATION_ADMIN_PUBLISH_TASK_TYPES as readonly string[]).includes(value);

const isNotificationAdminPublishTaskStatus = (value: string): value is NotificationAdminPublishTaskStatus =>
  value === 'pending' || value === 'published' || value === 'rejected';

const parseNotificationAdminPublishTaskRow = (row: {
  id: string;
  taskType: string;
  entityType: string;
  entityId: string;
  status: string;
  title: string;
  summary: string | null;
  createdBy: string | null;
  decidedBy: string | null;
  decidedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
  payload?: Prisma.JsonValue | null;
  decision?: Prisma.JsonValue | null;
}): NotificationAdminPublishTaskRecord | null => {
  if (!isNotificationAdminPublishTaskType(row.taskType) || !isNotificationAdminPublishTaskStatus(row.status)) {
    return null;
  }

  return {
    id: row.id,
    taskType: row.taskType,
    entityType: row.entityType,
    entityId: row.entityId,
    status: row.status,
    title: row.title,
    summary: row.summary,
    createdBy: row.createdBy,
    decidedBy: row.decidedBy,
    decidedAt: row.decidedAt ? row.decidedAt.toISOString() : null,
    createdAt: row.createdAt.toISOString(),
    updatedAt: row.updatedAt.toISOString(),
    payload: row.payload ?? null,
    decision: row.decision ?? null,
  };
};

const DEFAULT_GLOBAL_CONFIG: NotificationAdminGlobalConfig = {
  categorySwitches: {
    chat_message: true,
    community_interaction: true,
    event_countdown: true,
    event_daily_digest: true,
    route_dj_reminder: true,
    followed_dj_update: true,
    followed_brand_update: true,
    account_enforcement: true,
    content_review: true,
    report_decision: true,
    major_news: true,
  },
  channelSwitches: {
    in_app: true,
    apns: true,
    email: false,
    sms: false,
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
      timezone: 'Asia/Shanghai',
      muteChannels: ['apns'],
      exemptCategories: ['chat_message', 'route_dj_reminder'],
    },
  },
};

const DEFAULT_EVENT_COUNTDOWN_PREFERENCE: EventCountdownPreference = {
  enabled: true,
  daysBeforeStart: 3,
  reminderHours: [10],
  timezone: 'Asia/Shanghai',
  channels: ['in_app', 'apns'],
};

const DEFAULT_EVENT_DAILY_DIGEST_PREFERENCE: EventDailyDigestPreference = {
  enabled: true,
  reminderHours: [20],
  timezone: 'Asia/Shanghai',
  channels: ['in_app', 'apns'],
  includeNews: true,
  includeRatings: true,
  includeCheckinReminder: true,
};

const DEFAULT_ROUTE_DJ_REMINDER_PREFERENCE: RouteDJReminderPreference = {
  enabled: true,
  timezone: 'Asia/Shanghai',
  channels: ['in_app', 'apns'],
  defaultReminderMinutesBefore: 30,
  watchedSlots: [],
};

const DEFAULT_FOLLOWED_DJ_UPDATE_PREFERENCE: FollowedDJUpdatePreference = {
  enabled: true,
  reminderHours: [21],
  timezone: 'Asia/Shanghai',
  channels: ['in_app', 'apns'],
  includeInfos: true,
  includeSets: true,
  includeRatings: true,
};

const DEFAULT_FOLLOWED_BRAND_UPDATE_PREFERENCE: FollowedBrandUpdatePreference = {
  enabled: true,
  reminderHours: [21],
  timezone: 'Asia/Shanghai',
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
    category: 'chat_message',
    locale: 'en',
    channel: 'apns',
    titleTemplate: 'New message',
    bodyTemplate: '{{senderName}}: {{messagePreview}}',
    deeplinkTemplate: 'raver://messages/conversation/{{conversationId}}',
    variables: ['senderName', 'messagePreview', 'conversationId'],
  },
  {
    category: 'chat_message',
    locale: 'ja-JP',
    channel: 'apns',
    titleTemplate: '新しいメッセージ',
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
    category: 'community_interaction',
    locale: 'en',
    channel: 'apns',
    titleTemplate: 'New activity',
    bodyTemplate: '{{actorName}} {{actionText}}',
    deeplinkTemplate: 'raver://community/post/{{postId}}',
    variables: ['actorName', 'actionText', 'postId'],
  },
  {
    category: 'community_interaction',
    locale: 'ja-JP',
    channel: 'apns',
    titleTemplate: '新しいリアクション',
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
    category: 'event_countdown',
    locale: 'en',
    channel: 'in_app',
    titleTemplate: '{{eventName}} countdown',
    bodyTemplate: '{{daysLeft}} days until it starts',
    deeplinkTemplate: 'raver://event/{{eventId}}',
    variables: ['eventName', 'daysLeft', 'eventId'],
  },
  {
    category: 'event_countdown',
    locale: 'ja-JP',
    channel: 'in_app',
    titleTemplate: '{{eventName}} のカウントダウン',
    bodyTemplate: '開始まであと {{daysLeft}} 日',
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
    category: 'event_daily_digest',
    locale: 'en',
    channel: 'in_app',
    titleTemplate: '{{eventName}} today',
    bodyTemplate: '{{newsCount}} updates, {{ratingCount}} ratings',
    deeplinkTemplate: 'raver://event/{{eventId}}',
    variables: ['eventName', 'newsCount', 'ratingCount', 'eventId'],
  },
  {
    category: 'event_daily_digest',
    locale: 'ja-JP',
    channel: 'in_app',
    titleTemplate: '{{eventName}} の今日の動き',
    bodyTemplate: 'ニュース {{newsCount}} 件、評価 {{ratingCount}} 件',
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
    category: 'route_dj_reminder',
    locale: 'en',
    channel: 'in_app',
    titleTemplate: '{{djName}} is on soon',
    bodyTemplate: '{{eventName}} · {{stageName}} · starts in {{minutesLeft}} min',
    deeplinkTemplate: 'raver://event/{{eventId}}',
    variables: ['djName', 'eventName', 'stageName', 'minutesLeft', 'eventId'],
  },
  {
    category: 'route_dj_reminder',
    locale: 'ja-JP',
    channel: 'in_app',
    titleTemplate: '{{djName}} がまもなく出演',
    bodyTemplate: '{{eventName}} · {{stageName}} · あと {{minutesLeft}} 分で開始',
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
    category: 'followed_dj_update',
    locale: 'en',
    channel: 'in_app',
    titleTemplate: 'New updates from a DJ you follow',
    bodyTemplate: '{{infoCount}} updates, {{setCount}} sets, {{ratingCount}} ratings',
    deeplinkTemplate: 'raver://dj/{{djId}}',
    variables: ['infoCount', 'setCount', 'ratingCount', 'djId'],
  },
  {
    category: 'followed_dj_update',
    locale: 'ja-JP',
    channel: 'in_app',
    titleTemplate: 'フォロー中の DJ に新着情報があります',
    bodyTemplate: 'ニュース {{infoCount}} 件、Sets {{setCount}} 件、評価 {{ratingCount}} 件',
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
    category: 'followed_brand_update',
    locale: 'en',
    channel: 'in_app',
    titleTemplate: 'New updates from a Brand you follow',
    bodyTemplate: '{{infoCount}} updates, {{eventCount}} events',
    deeplinkTemplate: 'raver://brand/{{brandId}}',
    variables: ['infoCount', 'eventCount', 'brandId'],
  },
  {
    category: 'followed_brand_update',
    locale: 'ja-JP',
    channel: 'in_app',
    titleTemplate: 'フォロー中の Brand に新着情報があります',
    bodyTemplate: 'ニュース {{infoCount}} 件、イベント {{eventCount}} 件',
    deeplinkTemplate: 'raver://brand/{{brandId}}',
    variables: ['infoCount', 'eventCount', 'brandId'],
  },
  {
    category: 'account_enforcement',
    locale: 'zh-CN',
    channel: 'in_app',
    titleTemplate: '账号处罚状态已更新',
    bodyTemplate: '{{message}}',
    deeplinkTemplate: 'raver://account/enforcements/{{enforcementId}}',
    variables: ['message', 'enforcementId', 'reasonCode', 'decisionCode'],
  },
  {
    category: 'account_enforcement',
    locale: 'ja-JP',
    channel: 'in_app',
    titleTemplate: 'アカウント制限のステータスが更新されました',
    bodyTemplate: '{{message}}',
    deeplinkTemplate: 'raver://account/enforcements/{{enforcementId}}',
    variables: ['message', 'enforcementId', 'reasonCode', 'decisionCode'],
  },
  {
    category: 'account_enforcement',
    locale: 'en',
    channel: 'in_app',
    titleTemplate: 'Account enforcement status updated',
    bodyTemplate: '{{message}}',
    deeplinkTemplate: 'raver://account/enforcements/{{enforcementId}}',
    variables: ['message', 'enforcementId', 'reasonCode', 'decisionCode'],
  },
  {
    category: 'account_enforcement',
    locale: 'zh-CN',
    channel: 'apns',
    titleTemplate: '账号处罚状态已更新',
    bodyTemplate: '{{message}}',
    deeplinkTemplate: 'raver://account/enforcements/{{enforcementId}}',
    variables: ['message', 'enforcementId', 'reasonCode', 'decisionCode'],
  },
  {
    category: 'account_enforcement',
    locale: 'en',
    channel: 'apns',
    titleTemplate: 'Account enforcement status updated',
    bodyTemplate: '{{message}}',
    deeplinkTemplate: 'raver://account/enforcements/{{enforcementId}}',
    variables: ['message', 'enforcementId', 'reasonCode', 'decisionCode'],
  },
  {
    category: 'account_enforcement',
    locale: 'ja-JP',
    channel: 'apns',
    titleTemplate: 'アカウント制限のステータスが更新されました',
    bodyTemplate: '{{message}}',
    deeplinkTemplate: 'raver://account/enforcements/{{enforcementId}}',
    variables: ['message', 'enforcementId', 'reasonCode', 'decisionCode'],
  },
  {
    category: 'account_enforcement',
    locale: 'zh-CN',
    channel: 'email',
    titleTemplate: '账号处罚状态已更新',
    bodyTemplate: '{{message}}',
    deeplinkTemplate: 'raver://account/enforcements/{{enforcementId}}',
    variables: ['message', 'enforcementId', 'reasonCode', 'decisionCode'],
  },
  {
    category: 'account_enforcement',
    locale: 'en',
    channel: 'email',
    titleTemplate: 'Account enforcement status updated',
    bodyTemplate: '{{message}}',
    deeplinkTemplate: 'raver://account/enforcements/{{enforcementId}}',
    variables: ['message', 'enforcementId', 'reasonCode', 'decisionCode'],
  },
  {
    category: 'account_enforcement',
    locale: 'ja-JP',
    channel: 'email',
    titleTemplate: 'アカウント制限のステータスが更新されました',
    bodyTemplate: '{{message}}',
    deeplinkTemplate: 'raver://account/enforcements/{{enforcementId}}',
    variables: ['message', 'enforcementId', 'reasonCode', 'decisionCode'],
  },
  {
    category: 'account_enforcement',
    locale: 'zh-CN',
    channel: 'sms',
    titleTemplate: 'Raver账号状态',
    bodyTemplate: '{{message}}',
    variables: ['message', 'enforcementId', 'reasonCode', 'decisionCode'],
  },
  {
    category: 'account_enforcement',
    locale: 'en',
    channel: 'sms',
    titleTemplate: 'Raver account status',
    bodyTemplate: '{{message}}',
    variables: ['message', 'enforcementId', 'reasonCode', 'decisionCode'],
  },
  {
    category: 'account_enforcement',
    locale: 'ja-JP',
    channel: 'sms',
    titleTemplate: 'Raverアカウント状態',
    bodyTemplate: '{{message}}',
    variables: ['message', 'enforcementId', 'reasonCode', 'decisionCode'],
  },
  {
    category: 'content_review',
    locale: 'zh-CN',
    channel: 'in_app',
    titleTemplate: '{{typeLabel}}提交{{statusLabel}}',
    bodyTemplate: '{{message}}',
    deeplinkTemplate: 'raver://profile/submissions/{{submissionId}}',
    variables: ['typeLabel', 'statusLabel', 'message', 'submissionId', 'entityType', 'reasonCode'],
  },
  {
    category: 'content_review',
    locale: 'en',
    channel: 'in_app',
    titleTemplate: '{{typeLabel}} submission {{statusLabel}}',
    bodyTemplate: '{{message}}',
    deeplinkTemplate: 'raver://profile/submissions/{{submissionId}}',
    variables: ['typeLabel', 'statusLabel', 'message', 'submissionId', 'entityType', 'reasonCode'],
  },
  {
    category: 'content_review',
    locale: 'ja-JP',
    channel: 'in_app',
    titleTemplate: '{{typeLabel}}の投稿{{statusLabel}}',
    bodyTemplate: '{{message}}',
    deeplinkTemplate: 'raver://profile/submissions/{{submissionId}}',
    variables: ['typeLabel', 'statusLabel', 'message', 'submissionId', 'entityType', 'reasonCode'],
  },
  {
    category: 'content_review',
    locale: 'zh-CN',
    channel: 'apns',
    titleTemplate: '{{typeLabel}}提交{{statusLabel}}',
    bodyTemplate: '{{message}}',
    deeplinkTemplate: 'raver://profile/submissions/{{submissionId}}',
    variables: ['typeLabel', 'statusLabel', 'message', 'submissionId', 'entityType', 'reasonCode'],
  },
  {
    category: 'content_review',
    locale: 'en',
    channel: 'apns',
    titleTemplate: '{{typeLabel}} submission {{statusLabel}}',
    bodyTemplate: '{{message}}',
    deeplinkTemplate: 'raver://profile/submissions/{{submissionId}}',
    variables: ['typeLabel', 'statusLabel', 'message', 'submissionId', 'entityType', 'reasonCode'],
  },
  {
    category: 'content_review',
    locale: 'ja-JP',
    channel: 'apns',
    titleTemplate: '{{typeLabel}}の投稿{{statusLabel}}',
    bodyTemplate: '{{message}}',
    deeplinkTemplate: 'raver://profile/submissions/{{submissionId}}',
    variables: ['typeLabel', 'statusLabel', 'message', 'submissionId', 'entityType', 'reasonCode'],
  },
  {
    category: 'content_review',
    locale: 'zh-CN',
    channel: 'email',
    titleTemplate: '{{typeLabel}}提交{{statusLabel}}',
    bodyTemplate: '{{message}}',
    deeplinkTemplate: 'raver://profile/submissions/{{submissionId}}',
    variables: ['typeLabel', 'statusLabel', 'message', 'submissionId', 'entityType', 'reasonCode'],
  },
  {
    category: 'content_review',
    locale: 'en',
    channel: 'email',
    titleTemplate: '{{typeLabel}} submission {{statusLabel}}',
    bodyTemplate: '{{message}}',
    deeplinkTemplate: 'raver://profile/submissions/{{submissionId}}',
    variables: ['typeLabel', 'statusLabel', 'message', 'submissionId', 'entityType', 'reasonCode'],
  },
  {
    category: 'content_review',
    locale: 'ja-JP',
    channel: 'email',
    titleTemplate: '{{typeLabel}}の投稿{{statusLabel}}',
    bodyTemplate: '{{message}}',
    deeplinkTemplate: 'raver://profile/submissions/{{submissionId}}',
    variables: ['typeLabel', 'statusLabel', 'message', 'submissionId', 'entityType', 'reasonCode'],
  },
  {
    category: 'content_review',
    locale: 'zh-CN',
    channel: 'sms',
    titleTemplate: 'Raver内容审核',
    bodyTemplate: '{{message}}',
    variables: ['typeLabel', 'statusLabel', 'message', 'submissionId', 'entityType', 'reasonCode'],
  },
  {
    category: 'content_review',
    locale: 'en',
    channel: 'sms',
    titleTemplate: 'Raver content review',
    bodyTemplate: '{{message}}',
    variables: ['typeLabel', 'statusLabel', 'message', 'submissionId', 'entityType', 'reasonCode'],
  },
  {
    category: 'content_review',
    locale: 'ja-JP',
    channel: 'sms',
    titleTemplate: 'Raverコンテンツ審査',
    bodyTemplate: '{{message}}',
    variables: ['typeLabel', 'statusLabel', 'message', 'submissionId', 'entityType', 'reasonCode'],
  },
  {
    category: 'report_decision',
    locale: 'zh-CN',
    channel: 'in_app',
    titleTemplate: '举报处理结果',
    bodyTemplate: '{{message}}',
    deeplinkTemplate: 'raver://reports/{{reportId}}',
    variables: ['message', 'reportId', 'decisionCode'],
  },
  {
    category: 'report_decision',
    locale: 'en',
    channel: 'in_app',
    titleTemplate: 'Report decision',
    bodyTemplate: '{{message}}',
    deeplinkTemplate: 'raver://reports/{{reportId}}',
    variables: ['message', 'reportId', 'decisionCode'],
  },
  {
    category: 'report_decision',
    locale: 'ja-JP',
    channel: 'in_app',
    titleTemplate: '通報の対応結果',
    bodyTemplate: '{{message}}',
    deeplinkTemplate: 'raver://reports/{{reportId}}',
    variables: ['message', 'reportId', 'decisionCode'],
  },
  {
    category: 'report_decision',
    locale: 'zh-CN',
    channel: 'apns',
    titleTemplate: '举报处理结果',
    bodyTemplate: '{{message}}',
    deeplinkTemplate: 'raver://reports/{{reportId}}',
    variables: ['message', 'reportId', 'decisionCode'],
  },
  {
    category: 'report_decision',
    locale: 'en',
    channel: 'apns',
    titleTemplate: 'Report decision',
    bodyTemplate: '{{message}}',
    deeplinkTemplate: 'raver://reports/{{reportId}}',
    variables: ['message', 'reportId', 'decisionCode'],
  },
  {
    category: 'report_decision',
    locale: 'ja-JP',
    channel: 'apns',
    titleTemplate: '通報の対応結果',
    bodyTemplate: '{{message}}',
    deeplinkTemplate: 'raver://reports/{{reportId}}',
    variables: ['message', 'reportId', 'decisionCode'],
  },
  {
    category: 'report_decision',
    locale: 'zh-CN',
    channel: 'email',
    titleTemplate: '举报处理结果',
    bodyTemplate: '{{message}}',
    deeplinkTemplate: 'raver://reports/{{reportId}}',
    variables: ['message', 'reportId', 'decisionCode'],
  },
  {
    category: 'report_decision',
    locale: 'en',
    channel: 'email',
    titleTemplate: 'Report decision',
    bodyTemplate: '{{message}}',
    deeplinkTemplate: 'raver://reports/{{reportId}}',
    variables: ['message', 'reportId', 'decisionCode'],
  },
  {
    category: 'report_decision',
    locale: 'ja-JP',
    channel: 'email',
    titleTemplate: '通報の対応結果',
    bodyTemplate: '{{message}}',
    deeplinkTemplate: 'raver://reports/{{reportId}}',
    variables: ['message', 'reportId', 'decisionCode'],
  },
  {
    category: 'report_decision',
    locale: 'zh-CN',
    channel: 'sms',
    titleTemplate: 'Raver举报处理',
    bodyTemplate: '{{message}}',
    variables: ['message', 'reportId', 'decisionCode'],
  },
  {
    category: 'report_decision',
    locale: 'en',
    channel: 'sms',
    titleTemplate: 'Raver report decision',
    bodyTemplate: '{{message}}',
    variables: ['message', 'reportId', 'decisionCode'],
  },
  {
    category: 'report_decision',
    locale: 'ja-JP',
    channel: 'sms',
    titleTemplate: 'Raver通報対応',
    bodyTemplate: '{{message}}',
    variables: ['message', 'reportId', 'decisionCode'],
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
  {
    category: 'major_news',
    locale: 'en',
    channel: 'apns',
    titleTemplate: '{{headline}}',
    bodyTemplate: '{{summary}}',
    deeplinkTemplate: 'raver://news/{{newsId}}',
    variables: ['headline', 'summary', 'newsId'],
  },
  {
    category: 'major_news',
    locale: 'ja-JP',
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

const normalizeNotificationLocale = (value: unknown): string => {
  const normalized = typeof value === 'string' ? value.trim() : '';
  const lower = normalized.toLowerCase();
  if (lower === 'ja' || lower === 'ja-jp' || lower.startsWith('ja-')) return 'ja-JP';
  if (lower === 'zh' || lower === 'zh-cn' || lower === 'zh-hans' || lower.startsWith('zh-')) return 'zh-CN';
  if (lower === 'en' || lower === 'en-us' || lower === 'en-gb' || lower.startsWith('en-')) return 'en';
  return 'zh-CN';
};

const notificationLocaleFallbacks = (locale: string): string[] => {
  const normalized = normalizeNotificationLocale(locale);
  const fallbacks = normalized === 'ja-JP'
    ? ['ja-JP', 'en', 'zh-CN']
    : normalized === 'en'
      ? ['en', 'zh-CN']
      : ['zh-CN', 'en'];
  return fallbacks.filter((item, index) => fallbacks.indexOf(item) === index);
};

const renderNotificationTemplateText = (template: string, variables: Record<string, unknown>): string => {
  return template.replace(/\{\{\s*([a-zA-Z0-9_.-]+)\s*\}\}/g, (_match, key: string) => {
    const value = variables[key];
    if (value === null || value === undefined) return '';
    if (typeof value === 'string') return value;
    if (typeof value === 'number' || typeof value === 'boolean' || typeof value === 'bigint') return String(value);
    return '';
  });
};

const resolveNotificationTemplate = async (
  category: NotificationCategory,
  channel: NotificationChannel,
  locale: string
): Promise<NotificationTemplateSeed | null> => {
  await seedDefaultTemplatesIfNeeded();
  const fallbackLocales = notificationLocaleFallbacks(locale);
  const rows = await prisma.notificationTemplate.findMany({
    where: {
      category,
      channel,
      locale: { in: fallbackLocales },
      isActive: true,
    },
    select: {
      category: true,
      locale: true,
      channel: true,
      titleTemplate: true,
      bodyTemplate: true,
      deeplinkTemplate: true,
      variables: true,
    },
  });

  for (const targetLocale of fallbackLocales) {
    const row = rows.find((item) => item.locale === targetLocale);
    if (row) {
      return {
        category,
        locale: row.locale,
        channel,
        titleTemplate: row.titleTemplate,
        bodyTemplate: row.bodyTemplate,
        deeplinkTemplate: row.deeplinkTemplate,
        variables: Array.isArray(row.variables)
          ? row.variables.filter((item): item is string => typeof item === 'string')
          : [],
      };
    }
  }

  const seed = DEFAULT_TEMPLATE_SEEDS.find((item) => (
    item.category === category
    && item.channel === channel
    && fallbackLocales.includes(item.locale)
  ));
  return seed ?? null;
};

const renderNotificationPayloadForChannel = async (
  category: NotificationCategory,
  channel: NotificationChannel,
  payload: NotificationPayload
): Promise<NotificationPayload> => {
  const metadata = isRecord(payload.metadata) ? payload.metadata : {};
  const locale = normalizeNotificationLocale(payload.locale ?? metadata.locale);
  const template = await resolveNotificationTemplate(category, channel, locale);
  if (!template) {
    return { ...payload, locale };
  }

  const variables = {
    ...metadata,
    title: payload.title,
    body: payload.body,
    deeplink: payload.deeplink ?? '',
  };
  const title = renderNotificationTemplateText(template.titleTemplate, variables).trim() || payload.title;
  const body = renderNotificationTemplateText(template.bodyTemplate, variables).trim() || payload.body;
  const deeplinkTemplate = template.deeplinkTemplate?.trim();
  const deeplink = deeplinkTemplate
    ? (renderNotificationTemplateText(deeplinkTemplate, variables).trim() || payload.deeplink || null)
    : (payload.deeplink || null);

  return {
    ...payload,
    title,
    body,
    deeplink,
    locale,
    metadata,
  };
};

const readRenderedPayloadForChannel = (
  payloadRecord: Record<string, unknown>,
  channel: NotificationChannel
): Partial<NotificationPayload> | null => {
  const renderedByChannel = isRecord(payloadRecord.renderedByChannel)
    ? payloadRecord.renderedByChannel
    : (isRecord(payloadRecord.metadata) && isRecord(payloadRecord.metadata.renderedByChannel)
        ? payloadRecord.metadata.renderedByChannel
        : null);
  if (!renderedByChannel) return null;
  const channelPayload = renderedByChannel[channel];
  if (!isRecord(channelPayload)) return null;
  return {
    title: readStringFromRecord(channelPayload, 'title') || undefined,
    body: readStringFromRecord(channelPayload, 'body') || undefined,
    deeplink: readStringFromRecord(channelPayload, 'deeplink'),
    locale: readStringFromRecord(channelPayload, 'locale') || undefined,
  };
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
        .filter(isNotificationChannel)
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
  for (const channel of NOTIFICATION_CHANNELS) {
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
        .filter(isDeliverableNotificationChannel)
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
        .filter(isDeliverableNotificationChannel)
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
        .filter(isDeliverableNotificationChannel)
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
        .filter(isDeliverableNotificationChannel)
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
        .filter(isDeliverableNotificationChannel)
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

const normalizeNotificationCategoryPreferences = (
  input: Array<{ category?: unknown; enabled?: unknown }>
): NotificationCategoryPreference[] => {
  const preferenceMap = new Map<NotificationCategory, boolean>();
  for (const item of input) {
    const category = typeof item.category === 'string' ? item.category.trim() : '';
    if (!isNotificationCategory(category) || typeof item.enabled !== 'boolean') {
      continue;
    }
    preferenceMap.set(category, item.enabled);
  }
  return Array.from(preferenceMap.entries()).map(([category, enabled]) => ({ category, enabled }));
};

const seedDefaultTemplatesIfNeeded = async (): Promise<void> => {
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

    let configuredChannels = Array.from(new Set(input.channels))
      .filter(isDeliverableNotificationChannel)
      .filter((channel) => globalConfig.channelSwitches[channel]);
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

    const disabledSubscriptions = await prisma.notificationSubscription.findMany({
      where: {
        userId: {
          in: Array.from(new Set(targets.map((target) => target.userId))),
        },
        category: input.category,
        enabled: false,
      },
      select: {
        userId: true,
      },
    });
    if (disabledSubscriptions.length > 0) {
      const disabledUserIds = new Set(disabledSubscriptions.map((item) => item.userId));
      targets = targets.filter((target) => !disabledUserIds.has(target.userId));
      if (targets.length === 0) {
        return configuredChannels.map((channel) => ({
          channel,
          success: false,
          detail: 'user-disabled-category',
        }));
      }
    }

    const renderedPayloadByChannel = new Map<NotificationChannel, NotificationPayload>();
    for (const channel of configuredChannels) {
      renderedPayloadByChannel.set(channel, await renderNotificationPayloadForChannel(input.category, channel, input.payload));
    }
    const primaryPayload =
      renderedPayloadByChannel.get(configuredChannels[0])
      ?? { ...input.payload, locale: normalizeNotificationLocale(input.payload.locale ?? input.payload.metadata?.locale) };

    const eventRow = await prisma.notificationEvent.create({
      data: {
        category: input.category,
        dedupeKey,
        payload: toInputJsonValue({
          title: primaryPayload.title,
          body: primaryPayload.body,
          deeplink: primaryPayload.deeplink || null,
          badgeDelta: primaryPayload.badgeDelta ?? 0,
          locale: primaryPayload.locale,
          metadata: {
            ...(primaryPayload.metadata ?? {}),
            renderedByChannel: Object.fromEntries(
              Array.from(renderedPayloadByChannel.entries()).map(([channel, payload]) => [
                channel,
                {
                  title: payload.title,
                  body: payload.body,
                  deeplink: payload.deeplink || null,
                  locale: payload.locale,
                },
              ])
            ),
          },
        }),
        status: 'queued',
      },
      select: { id: true },
    });

    if (configuredChannels.includes('in_app')) {
      const inboxPayload = renderedPayloadByChannel.get('in_app') ?? primaryPayload;
      await prisma.notificationInboxItem.createMany({
        data: targets.map((target) => ({
          userId: target.userId,
          type: input.category,
          title: inboxPayload.title,
          body: inboxPayload.body,
          deeplink: inboxPayload.deeplink || null,
          metadata: toInputJsonValue({
            ...(inboxPayload.metadata ?? {}),
            locale: inboxPayload.locale,
          }),
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
      payload: renderedPayloadByChannel.get('apns') ?? primaryPayload,
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
        const payloadLocale = readStringFromRecord(payloadRecord, 'locale');
        const payloadMetadataRaw = payloadRecord.metadata;
        const payloadMetadata = isRecord(payloadMetadataRaw) ? payloadMetadataRaw : {};

        const channels = Array.from(
          new Set(
            queuedDeliveries
              .map((item) => item.channel.trim().toLowerCase())
              .filter(isDeliverableNotificationChannel)
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
        const primaryChannel = channels[0];
        const renderedPayload = primaryChannel ? readRenderedPayloadForChannel(payloadRecord, primaryChannel) : null;
        const runtimeEvent = createRuntimeEvent(eventRow.id, {
          category: eventRow.category as NotificationPublishInput['category'],
          targets,
          channels,
          dedupeKey: eventRow.dedupeKey || undefined,
          payload: {
            title: renderedPayload?.title || payloadTitle,
            body: renderedPayload?.body || payloadBody,
            deeplink: renderedPayload?.deeplink ?? payloadDeeplink,
            badgeDelta: payloadBadgeDelta,
            locale: renderedPayload?.locale || payloadLocale || undefined,
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
    if (channel && isNotificationChannel(channel)) {
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

  async fetchAdminDeliverySectionSummaries(input?: {
    channel?: NotificationChannel;
    status?: string;
    userId?: string;
    eventId?: string;
    query?: string;
  }): Promise<NotificationAdminDeliverySectionSummary[]> {
    const channel = input?.channel?.trim();
    const status = input?.status?.trim();
    const userId = input?.userId?.trim();
    const eventId = input?.eventId?.trim();
    const query = input?.query?.trim();

    const whereSql = Prisma.sql`
      WHERE 1 = 1
      ${channel && isNotificationChannel(channel) ? Prisma.sql`AND d.channel = ${channel}` : Prisma.empty}
      ${status ? Prisma.sql`AND d.status = ${status}` : Prisma.empty}
      ${userId ? Prisma.sql`AND d.user_id = ${userId}` : Prisma.empty}
      ${eventId ? Prisma.sql`AND d.event_id = ${eventId}` : Prisma.empty}
      ${
        query
          ? Prisma.sql`
              AND (
                COALESCE(e.payload #>> '{title}', '') ILIKE ${`%${query}%`}
                OR COALESCE(e.payload #>> '{body}', '') ILIKE ${`%${query}%`}
                OR COALESCE(e.payload #>> '{metadata,newsTitle}', '') ILIKE ${`%${query}%`}
                OR COALESCE(e.payload #>> '{metadata,eventName}', '') ILIKE ${`%${query}%`}
                OR COALESCE(e.payload #>> '{metadata,djName}', '') ILIKE ${`%${query}%`}
                OR COALESCE(e.payload #>> '{metadata,brandName}', '') ILIKE ${`%${query}%`}
                OR COALESCE(u.display_name, '') ILIKE ${`%${query}%`}
                OR COALESCE(u.username, '') ILIKE ${`%${query}%`}
              )
            `
          : Prisma.empty
      }
    `;

    const rows = await prisma.$queryRaw<
      Array<{
        section: string;
        total: bigint | number;
        apnsCount: bigint | number;
        inAppCount: bigint | number;
        failedCount: bigint | number;
        lastDeliveryAt: Date | null;
      }>
    >(Prisma.sql`
      SELECT
        ${NOTIFICATION_DELIVERY_SECTION_CASE_SQL} AS section,
        COUNT(*)::bigint AS total,
        COUNT(*) FILTER (WHERE d.channel = 'apns')::bigint AS "apnsCount",
        COUNT(*) FILTER (WHERE d.channel = 'in_app')::bigint AS "inAppCount",
        COUNT(*) FILTER (WHERE d.status = 'failed')::bigint AS "failedCount",
        MAX(COALESCE(d.delivered_at, d.created_at)) AS "lastDeliveryAt"
      FROM notification_deliveries d
      INNER JOIN notification_events e ON e.id = d.event_id
      INNER JOIN users u ON u.id = d.user_id
      ${whereSql}
      GROUP BY 1
      ORDER BY MAX(COALESCE(d.delivered_at, d.created_at)) DESC NULLS LAST, section ASC
    `);

    const summaryMap = new Map<NotificationAdminDeliverySection, NotificationAdminDeliverySectionSummary>();
    for (const section of NOTIFICATION_ADMIN_DELIVERY_SECTIONS) {
      summaryMap.set(section, {
        section,
        total: 0,
        apnsCount: 0,
        inAppCount: 0,
        failedCount: 0,
        lastDeliveryAt: null,
      });
    }

    for (const row of rows) {
      const section = isNotificationAdminDeliverySection(row.section) ? row.section : 'other';
      summaryMap.set(section, {
        section,
        total: toPositiveSafeInteger(row.total),
        apnsCount: toPositiveSafeInteger(row.apnsCount),
        inAppCount: toPositiveSafeInteger(row.inAppCount),
        failedCount: toPositiveSafeInteger(row.failedCount),
        lastDeliveryAt: row.lastDeliveryAt ? row.lastDeliveryAt.toISOString() : null,
      });
    }

    return NOTIFICATION_ADMIN_DELIVERY_SECTIONS.map((section) => summaryMap.get(section)!);
  },

  async fetchAdminDeliveriesBySection(input: {
    section: NotificationAdminDeliverySection;
    page?: number;
    limit?: number;
    channel?: NotificationChannel;
    status?: string;
    userId?: string;
    eventId?: string;
    query?: string;
  }): Promise<NotificationAdminDeliveryPage> {
    const limit = normalizePositiveLimit(Number(input.limit ?? 20), 20, 100);
    const page = normalizePositiveLimit(Number(input.page ?? 1), 1, 100000);
    const channel = input.channel?.trim();
    const status = input.status?.trim();
    const userId = input.userId?.trim();
    const eventId = input.eventId?.trim();
    const query = input.query?.trim();

    const whereSql = Prisma.sql`
      WHERE ${NOTIFICATION_DELIVERY_SECTION_CASE_SQL} = ${input.section}
      ${channel && isNotificationChannel(channel) ? Prisma.sql`AND d.channel = ${channel}` : Prisma.empty}
      ${status ? Prisma.sql`AND d.status = ${status}` : Prisma.empty}
      ${userId ? Prisma.sql`AND d.user_id = ${userId}` : Prisma.empty}
      ${eventId ? Prisma.sql`AND d.event_id = ${eventId}` : Prisma.empty}
      ${
        query
          ? Prisma.sql`
              AND (
                COALESCE(e.payload #>> '{title}', '') ILIKE ${`%${query}%`}
                OR COALESCE(e.payload #>> '{body}', '') ILIKE ${`%${query}%`}
                OR COALESCE(e.payload #>> '{metadata,newsTitle}', '') ILIKE ${`%${query}%`}
                OR COALESCE(e.payload #>> '{metadata,eventName}', '') ILIKE ${`%${query}%`}
                OR COALESCE(e.payload #>> '{metadata,djName}', '') ILIKE ${`%${query}%`}
                OR COALESCE(e.payload #>> '{metadata,brandName}', '') ILIKE ${`%${query}%`}
                OR COALESCE(u.display_name, '') ILIKE ${`%${query}%`}
                OR COALESCE(u.username, '') ILIKE ${`%${query}%`}
              )
            `
          : Prisma.empty
      }
    `;

    const totalRows = await prisma.$queryRaw<Array<{ total: bigint | number }>>(Prisma.sql`
      SELECT COUNT(*)::bigint AS total
      FROM notification_deliveries d
      INNER JOIN notification_events e ON e.id = d.event_id
      INNER JOIN users u ON u.id = d.user_id
      ${whereSql}
    `);
    const total = toPositiveSafeInteger(totalRows[0]?.total ?? 0);
    const totalPages = Math.max(1, Math.ceil(total / limit));
    const safePage = Math.min(page, totalPages);
    const safeOffset = (safePage - 1) * limit;

    const rows = await prisma.$queryRaw<
      Array<{
        id: string;
        section: string;
        eventId: string;
        userId: string;
        channel: string;
        status: string;
        error: string | null;
        attempts: number;
        deliveredAt: Date | null;
        createdAt: Date;
        updatedAt: Date;
        payloadTitle: string | null;
        payloadBody: string | null;
        payloadDeeplink: string | null;
        metadataRoute: string | null;
        metadataSource: string | null;
        metadataNewsId: string | null;
        metadataNewsTitle: string | null;
        metadataEventId: string | null;
        metadataEventName: string | null;
        metadataDjId: string | null;
        metadataDjName: string | null;
        metadataBrandId: string | null;
        metadataBrandName: string | null;
        metadataAudience: string | null;
        notificationEventId: string;
        notificationCategory: string;
        notificationEventStatus: string;
        notificationDedupeKey: string | null;
        notificationCreatedAt: Date;
        notificationDispatchedAt: Date | null;
        username: string;
        displayName: string | null;
      }>
    >(Prisma.sql`
      SELECT
        d.id,
        ${NOTIFICATION_DELIVERY_SECTION_CASE_SQL} AS section,
        d.event_id AS "eventId",
        d.user_id AS "userId",
        d.channel,
        d.status,
        d.error,
        d.attempts,
        d.delivered_at AS "deliveredAt",
        d.created_at AS "createdAt",
        d.updated_at AS "updatedAt",
        e.payload #>> '{title}' AS "payloadTitle",
        e.payload #>> '{body}' AS "payloadBody",
        e.payload #>> '{deeplink}' AS "payloadDeeplink",
        e.payload #>> '{metadata,route}' AS "metadataRoute",
        e.payload #>> '{metadata,source}' AS "metadataSource",
        e.payload #>> '{metadata,newsId}' AS "metadataNewsId",
        e.payload #>> '{metadata,newsTitle}' AS "metadataNewsTitle",
        e.payload #>> '{metadata,eventId}' AS "metadataEventId",
        e.payload #>> '{metadata,eventName}' AS "metadataEventName",
        e.payload #>> '{metadata,djId}' AS "metadataDjId",
        e.payload #>> '{metadata,djName}' AS "metadataDjName",
        e.payload #>> '{metadata,brandId}' AS "metadataBrandId",
        e.payload #>> '{metadata,brandName}' AS "metadataBrandName",
        e.payload #>> '{metadata,sourceAudience}' AS "metadataAudience",
        e.id AS "notificationEventId",
        e.category AS "notificationCategory",
        e.status AS "notificationEventStatus",
        e.dedupe_key AS "notificationDedupeKey",
        e.created_at AS "notificationCreatedAt",
        e.dispatched_at AS "notificationDispatchedAt",
        u.username,
        u.display_name AS "displayName"
      FROM notification_deliveries d
      INNER JOIN notification_events e ON e.id = d.event_id
      INNER JOIN users u ON u.id = d.user_id
      ${whereSql}
      ORDER BY d.created_at DESC, d.id DESC
      LIMIT ${limit}
      OFFSET ${safeOffset}
    `);

    return {
      section: input.section,
      items: rows.map((row) => ({
        id: row.id,
        section: isNotificationAdminDeliverySection(row.section) ? row.section : 'other',
        eventId: row.eventId,
        userId: row.userId,
        channel: row.channel,
        status: row.status,
        error: row.error,
        attempts: row.attempts,
        deliveredAt: row.deliveredAt ? row.deliveredAt.toISOString() : null,
        createdAt: row.createdAt.toISOString(),
        updatedAt: row.updatedAt.toISOString(),
        payload: {
          title: row.payloadTitle,
          body: row.payloadBody,
          deeplink: row.payloadDeeplink,
        },
        metadata: {
          route: row.metadataRoute,
          source: row.metadataSource,
          newsId: row.metadataNewsId,
          newsTitle: row.metadataNewsTitle,
          eventId: row.metadataEventId,
          eventName: row.metadataEventName,
          djId: row.metadataDjId,
          djName: row.metadataDjName,
          brandId: row.metadataBrandId,
          brandName: row.metadataBrandName,
          audience: row.metadataAudience,
        },
        event: {
          id: row.notificationEventId,
          category: row.notificationCategory,
          status: row.notificationEventStatus,
          dedupeKey: row.notificationDedupeKey,
          createdAt: row.notificationCreatedAt.toISOString(),
          dispatchedAt: row.notificationDispatchedAt ? row.notificationDispatchedAt.toISOString() : null,
        },
        user: {
          id: row.userId,
          username: row.username,
          displayName: row.displayName,
        },
      })),
      pagination: {
        page: safePage,
        limit,
        total,
        totalPages,
      },
    };
  },

  async upsertAdminPublishTask(input: {
    taskType: NotificationAdminPublishTaskType;
    entityType: string;
    entityId: string;
    title: string;
    summary?: string | null;
    payload: unknown;
    createdBy?: string | null;
  }): Promise<NotificationAdminPublishTaskRecord> {
    const entityType = input.entityType.trim();
    const entityId = input.entityId.trim();
    const title = input.title.trim();
    if (!entityType || !entityId || !title) {
      throw new Error('task entityType/entityId/title are required');
    }

    const rows = await prisma.$queryRaw<
      Array<{
        id: string;
        taskType: string;
        entityType: string;
        entityId: string;
        status: string;
        title: string;
        summary: string | null;
        createdBy: string | null;
        decidedBy: string | null;
        decidedAt: Date | null;
        createdAt: Date;
        updatedAt: Date;
        payload: Prisma.JsonValue | null;
        decision: Prisma.JsonValue | null;
      }>
    >(Prisma.sql`
      INSERT INTO notification_admin_publish_tasks (
        task_type,
        entity_type,
        entity_id,
        status,
        title,
        summary,
        payload,
        decision,
        created_by
      )
      VALUES (
        ${input.taskType},
        ${entityType},
        ${entityId},
        'pending',
        ${title},
        ${input.summary?.trim() || null},
        ${toInputJsonValue(input.payload)},
        NULL,
        ${input.createdBy?.trim() || null}
      )
      ON CONFLICT (task_type, entity_type, entity_id)
      DO UPDATE SET
        status = 'pending',
        title = EXCLUDED.title,
        summary = EXCLUDED.summary,
        payload = EXCLUDED.payload,
        decision = NULL,
        decided_by = NULL,
        decided_at = NULL,
        updated_at = NOW()
      RETURNING
        id,
        task_type AS "taskType",
        entity_type AS "entityType",
        entity_id AS "entityId",
        status,
        title,
        summary,
        created_by AS "createdBy",
        decided_by AS "decidedBy",
        decided_at AS "decidedAt",
        created_at AS "createdAt",
        updated_at AS "updatedAt",
        payload,
        decision
    `);
    const row = parseNotificationAdminPublishTaskRow(rows[0]);
    if (!row) {
      throw new Error('Failed to persist publish task');
    }
    return row;
  },

  async fetchAdminPublishTaskByEntity(input: {
    taskType: NotificationAdminPublishTaskType;
    entityType: string;
    entityId: string;
  }): Promise<NotificationAdminPublishTaskRecord | null> {
    const entityType = input.entityType.trim();
    const entityId = input.entityId.trim();
    if (!entityType || !entityId) return null;

    const rows = await prisma.$queryRaw<
      Array<{
        id: string;
        taskType: string;
        entityType: string;
        entityId: string;
        status: string;
        title: string;
        summary: string | null;
        createdBy: string | null;
        decidedBy: string | null;
        decidedAt: Date | null;
        createdAt: Date;
        updatedAt: Date;
        payload: Prisma.JsonValue | null;
        decision: Prisma.JsonValue | null;
      }>
    >(Prisma.sql`
      SELECT
        id,
        task_type AS "taskType",
        entity_type AS "entityType",
        entity_id AS "entityId",
        status,
        title,
        summary,
        created_by AS "createdBy",
        decided_by AS "decidedBy",
        decided_at AS "decidedAt",
        created_at AS "createdAt",
        updated_at AS "updatedAt",
        payload,
        decision
      FROM notification_admin_publish_tasks
      WHERE task_type = ${input.taskType}
        AND entity_type = ${entityType}
        AND entity_id = ${entityId}
      LIMIT 1
    `);
    return parseNotificationAdminPublishTaskRow(rows[0]) ?? null;
  },

  async fetchAdminPublishTaskById(id: string): Promise<NotificationAdminPublishTaskRecord | null> {
    const normalizedId = id.trim();
    if (!normalizedId) return null;
    const rows = await prisma.$queryRaw<
      Array<{
        id: string;
        taskType: string;
        entityType: string;
        entityId: string;
        status: string;
        title: string;
        summary: string | null;
        createdBy: string | null;
        decidedBy: string | null;
        decidedAt: Date | null;
        createdAt: Date;
        updatedAt: Date;
        payload: Prisma.JsonValue | null;
        decision: Prisma.JsonValue | null;
      }>
    >(Prisma.sql`
      SELECT
        id,
        task_type AS "taskType",
        entity_type AS "entityType",
        entity_id AS "entityId",
        status,
        title,
        summary,
        created_by AS "createdBy",
        decided_by AS "decidedBy",
        decided_at AS "decidedAt",
        created_at AS "createdAt",
        updated_at AS "updatedAt",
        payload,
        decision
      FROM notification_admin_publish_tasks
      WHERE id = ${normalizedId}
      LIMIT 1
    `);
    return parseNotificationAdminPublishTaskRow(rows[0]) ?? null;
  },

  async fetchAdminPublishTasks(input?: {
    page?: number;
    limit?: number;
    status?: NotificationAdminPublishTaskStatus;
    taskType?: NotificationAdminPublishTaskType;
    query?: string;
  }): Promise<NotificationAdminPublishTaskPage> {
    const limit = normalizePositiveLimit(Number(input?.limit ?? 20), 20, 100);
    const page = normalizePositiveLimit(Number(input?.page ?? 1), 1, 100000);
    const status = input?.status?.trim();
    const taskType = input?.taskType?.trim();
    const query = input?.query?.trim();

    const whereSql = Prisma.sql`
      WHERE 1 = 1
      ${status && isNotificationAdminPublishTaskStatus(status) ? Prisma.sql`AND status = ${status}` : Prisma.empty}
      ${taskType && isNotificationAdminPublishTaskType(taskType) ? Prisma.sql`AND task_type = ${taskType}` : Prisma.empty}
      ${
        query
          ? Prisma.sql`
              AND (
                title ILIKE ${`%${query}%`}
                OR COALESCE(summary, '') ILIKE ${`%${query}%`}
                OR entity_id ILIKE ${`%${query}%`}
              )
            `
          : Prisma.empty
      }
    `;

    const totalRows = await prisma.$queryRaw<Array<{ total: bigint | number }>>(Prisma.sql`
      SELECT COUNT(*)::bigint AS total
      FROM notification_admin_publish_tasks
      ${whereSql}
    `);
    const total = toPositiveSafeInteger(totalRows[0]?.total ?? 0);
    const totalPages = Math.max(1, Math.ceil(total / limit));
    const safePage = Math.min(page, totalPages);
    const safeOffset = (safePage - 1) * limit;

    const rows = await prisma.$queryRaw<
      Array<{
        id: string;
        taskType: string;
        entityType: string;
        entityId: string;
        status: string;
        title: string;
        summary: string | null;
        createdBy: string | null;
        decidedBy: string | null;
        decidedAt: Date | null;
        createdAt: Date;
        updatedAt: Date;
        payload: Prisma.JsonValue | null;
        decision: Prisma.JsonValue | null;
      }>
    >(Prisma.sql`
      SELECT
        id,
        task_type AS "taskType",
        entity_type AS "entityType",
        entity_id AS "entityId",
        status,
        title,
        summary,
        created_by AS "createdBy",
        decided_by AS "decidedBy",
        decided_at AS "decidedAt",
        created_at AS "createdAt",
        updated_at AS "updatedAt",
        payload,
        decision
      FROM notification_admin_publish_tasks
      ${whereSql}
      ORDER BY
        CASE status WHEN 'pending' THEN 0 WHEN 'published' THEN 1 ELSE 2 END,
        updated_at DESC,
        created_at DESC
      LIMIT ${limit}
      OFFSET ${safeOffset}
    `);

    return {
      items: rows
        .map((row) => parseNotificationAdminPublishTaskRow(row))
        .filter((row): row is NotificationAdminPublishTaskRecord => Boolean(row))
        .map((row) => ({
          id: row.id,
          taskType: row.taskType,
          entityType: row.entityType,
          entityId: row.entityId,
          status: row.status,
          title: row.title,
          summary: row.summary,
          createdBy: row.createdBy,
          decidedBy: row.decidedBy,
          decidedAt: row.decidedAt,
          createdAt: row.createdAt,
          updatedAt: row.updatedAt,
        })),
      pagination: {
        page: safePage,
        limit,
        total,
        totalPages,
      },
    };
  },

  async decideAdminPublishTask(input: {
    id: string;
    status: Extract<NotificationAdminPublishTaskStatus, 'published' | 'rejected'>;
    decidedBy: string;
    decision?: unknown;
  }): Promise<NotificationAdminPublishTaskRecord | null> {
    const id = input.id.trim();
    const decidedBy = input.decidedBy.trim();
    if (!id || !decidedBy) {
      throw new Error('task id / decidedBy are required');
    }

    const rows = await prisma.$queryRaw<
      Array<{
        id: string;
        taskType: string;
        entityType: string;
        entityId: string;
        status: string;
        title: string;
        summary: string | null;
        createdBy: string | null;
        decidedBy: string | null;
        decidedAt: Date | null;
        createdAt: Date;
        updatedAt: Date;
        payload: Prisma.JsonValue | null;
        decision: Prisma.JsonValue | null;
      }>
    >(Prisma.sql`
      UPDATE notification_admin_publish_tasks
      SET
        status = ${input.status},
        decided_by = ${decidedBy},
        decided_at = NOW(),
        decision = ${toInputJsonValue(input.decision ?? {})},
        updated_at = NOW()
      WHERE id = ${id}
      RETURNING
        id,
        task_type AS "taskType",
        entity_type AS "entityType",
        entity_id AS "entityId",
        status,
        title,
        summary,
        created_by AS "createdBy",
        decided_by AS "decidedBy",
        decided_at AS "decidedAt",
        created_at AS "createdAt",
        updated_at AS "updatedAt",
        payload,
        decision
    `);
    return parseNotificationAdminPublishTaskRow(rows[0]) ?? null;
  },

  async deleteAdminPublishTasksByEntity(input: {
    entityType: string;
    entityId: string;
    taskTypes?: NotificationAdminPublishTaskType[];
  }): Promise<number> {
    const entityType = input.entityType.trim();
    const entityId = input.entityId.trim();
    if (!entityType || !entityId) {
      return 0;
    }

    const normalizedTaskTypes = Array.from(
      new Set(
        (input.taskTypes ?? []).filter((value): value is NotificationAdminPublishTaskType =>
          isNotificationAdminPublishTaskType(value)
        )
      )
    );

    const taskTypeFilter =
      normalizedTaskTypes.length > 0
        ? Prisma.sql`AND task_type IN (${Prisma.join(normalizedTaskTypes)})`
        : Prisma.empty;

    const rows = await prisma.$queryRaw<Array<{ count: bigint | number }>>(Prisma.sql`
      WITH deleted AS (
        DELETE FROM notification_admin_publish_tasks
        WHERE entity_type = ${entityType}
          AND entity_id = ${entityId}
          ${taskTypeFilter}
        RETURNING 1
      )
      SELECT COUNT(*)::bigint AS count FROM deleted
    `);

    return toPositiveSafeInteger(rows[0]?.count ?? 0);
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
    if (channel && isNotificationChannel(channel)) {
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
    if (!isNotificationChannel(channel)) {
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

  async fetchCategoryPreferences(userId: string): Promise<NotificationCategoryPreference[]> {
    const normalizedUserId = userId.trim();
    if (!normalizedUserId) {
      return NOTIFICATION_CATEGORIES.map((category) => ({ category, enabled: true }));
    }

    const rows = await prisma.notificationSubscription.findMany({
      where: {
        userId: normalizedUserId,
        category: {
          in: [...NOTIFICATION_CATEGORIES],
        },
      },
      select: {
        category: true,
        enabled: true,
      },
    });
    const enabledMap = new Map(
      rows
        .filter((item): item is { category: NotificationCategory; enabled: boolean } =>
          isNotificationCategory(item.category)
        )
        .map((item) => [item.category, item.enabled])
    );

    return NOTIFICATION_CATEGORIES.map((category) => ({
      category,
      enabled: enabledMap.get(category) ?? true,
    }));
  },

  async updateCategoryPreferences(
    userId: string,
    input: Array<{ category?: unknown; enabled?: unknown }>
  ): Promise<NotificationCategoryPreference[]> {
    const normalizedUserId = userId.trim();
    if (!normalizedUserId) {
      throw new Error('userId is required');
    }

    const preferences = normalizeNotificationCategoryPreferences(input);
    for (const preference of preferences) {
      await prisma.notificationSubscription.upsert({
        where: {
          userId_category: {
            userId: normalizedUserId,
            category: preference.category,
          },
        },
        create: {
          userId: normalizedUserId,
          category: preference.category,
          enabled: preference.enabled,
          frequencyConfig: toInputJsonValue({ enabled: preference.enabled }),
        },
        update: {
          enabled: preference.enabled,
        },
        select: {
          id: true,
        },
      });
    }

    return this.fetchCategoryPreferences(normalizedUserId);
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
      eventAnchorDate: Date;
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
    const todayDate = startOfUTCDate(now);
    const untilDate = endOfUTCDate(until);
    const rows = await prisma.$queryRaw<Array<{
      userId: string;
      eventId: string;
      eventName: string;
      eventStartDate: Date;
      createdAt: Date;
    }>>`
      SELECT
        uef.user_id AS "userId",
        uef.target_id AS "eventId",
        e.name AS "eventName",
        e.start_date AS "eventStartDate",
        uef.created_at AS "createdAt"
      FROM user_entity_follows uef
      INNER JOIN events e ON e.id = uef.target_id
      WHERE uef.relation_type = ${USER_ENTITY_RELATION_FAVORITE}
        AND uef.target_type = ${USER_ENTITY_TARGET_EVENT}
        AND uef.user_id IN (${Prisma.join(normalizedUserIds)})
        AND (
          EXISTS (
            SELECT 1
            FROM event_days ed
            WHERE ed.event_id = e.id
              AND ed.date >= ${todayDate}
              AND ed.date <= ${untilDate}
          )
          OR (
            NOT EXISTS (
              SELECT 1
              FROM event_days ed_any
              WHERE ed_any.event_id = e.id
            )
            AND e.start_date >= ${now}
            AND e.start_date <= ${until}
          )
        )
      ORDER BY e.start_date ASC, uef.created_at DESC
    `;

    const eventIds = Array.from(new Set(rows.map((row) => row.eventId?.trim()).filter(Boolean)));
    const eventDayRows = eventIds.length > 0
      ? await prisma.eventDay.findMany({
          where: {
            eventId: {
              in: eventIds,
            },
            date: {
              gte: todayDate,
              lte: untilDate,
            },
          },
          select: {
            eventId: true,
            date: true,
          },
          orderBy: [{ date: 'asc' }, { overallDayIndex: 'asc' }],
        })
      : [];
    const eventDayMap = new Map<string, Date[]>();
    for (const row of eventDayRows) {
      const current = eventDayMap.get(row.eventId) ?? [];
      current.push(row.date);
      eventDayMap.set(row.eventId, current);
    }

    const unique = new Map<string, { userId: string; eventId: string; eventName: string; eventAnchorDate: Date; eventStartDate: Date }>();
    for (const row of rows) {
      const eventId = row.eventId?.trim();
      if (!eventId) {
        continue;
      }
      const eventDayDates = sortDatesAscending(eventDayMap.get(eventId) ?? []);
      const eventAnchorDate = eventDayDates[0] ?? row.eventStartDate;
      const key = `${row.userId}:${eventId}`;
      if (unique.has(key)) {
        continue;
      }
      unique.set(key, {
        userId: row.userId,
        eventId,
        eventName: row.eventName,
        eventAnchorDate,
        eventStartDate: row.eventStartDate,
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
      eventDayDates: Date[];
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
    const sinceDate = startOfUTCDate(since);
    const untilDate = endOfUTCDate(until);
    const rows = await prisma.$queryRaw<Array<{
      userId: string;
      eventId: string;
      eventName: string;
      eventStartDate: Date;
      eventEndDate: Date;
      createdAt: Date;
    }>>`
      SELECT
        uef.user_id AS "userId",
        uef.target_id AS "eventId",
        e.name AS "eventName",
        e.start_date AS "eventStartDate",
        e.end_date AS "eventEndDate",
        uef.created_at AS "createdAt"
      FROM user_entity_follows uef
      INNER JOIN events e ON e.id = uef.target_id
      WHERE uef.relation_type = ${USER_ENTITY_RELATION_FAVORITE}
        AND uef.target_type = ${USER_ENTITY_TARGET_EVENT}
        AND uef.user_id IN (${Prisma.join(normalizedUserIds)})
        AND (
          EXISTS (
            SELECT 1
            FROM event_days ed
            WHERE ed.event_id = e.id
              AND ed.date >= ${sinceDate}
              AND ed.date <= ${untilDate}
          )
          OR (
            NOT EXISTS (
              SELECT 1
              FROM event_days ed_any
              WHERE ed_any.event_id = e.id
            )
            AND e.start_date <= ${until}
            AND e.end_date >= ${since}
          )
        )
      ORDER BY e.start_date ASC, uef.created_at DESC
    `;

    const eventIds = Array.from(new Set(rows.map((row) => row.eventId?.trim()).filter(Boolean)));
    const eventDayRows = eventIds.length > 0
      ? await prisma.eventDay.findMany({
          where: {
            eventId: {
              in: eventIds,
            },
            date: {
              gte: sinceDate,
              lte: untilDate,
            },
          },
          select: {
            eventId: true,
            date: true,
          },
          orderBy: [{ date: 'asc' }, { overallDayIndex: 'asc' }],
        })
      : [];
    const eventDayMap = new Map<string, Date[]>();
    for (const row of eventDayRows) {
      const current = eventDayMap.get(row.eventId) ?? [];
      current.push(row.date);
      eventDayMap.set(row.eventId, current);
    }

    const unique = new Map<
      string,
      { userId: string; eventId: string; eventName: string; eventStartDate: Date; eventEndDate: Date; eventDayDates: Date[] }
    >();
    for (const row of rows) {
      const eventId = row.eventId?.trim();
      if (!eventId) {
        continue;
      }
      const key = `${row.userId}:${eventId}`;
      if (unique.has(key)) {
        continue;
      }
      unique.set(key, {
        userId: row.userId,
        eventId,
        eventName: row.eventName,
        eventStartDate: row.eventStartDate,
        eventEndDate: row.eventEndDate,
        eventDayDates: sortDatesAscending(eventDayMap.get(eventId) ?? []),
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
