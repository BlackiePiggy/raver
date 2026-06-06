import type {
  NotificationCenterDeliverySection,
  NotificationCenterDeliverySectionSummary,
  NotificationCenterGlobalConfig,
} from '@/lib/api/notification-center-admin';
import { formatDateTimeWithSystemTimeZoneLabel } from '@/lib/timezone';

export const formatTime = (value?: string | null): string => {
  if (!value) return '-';
  return formatDateTimeWithSystemTimeZoneLabel(value);
};

export const formatPercent = (value?: number): string => `${((value ?? 0) * 100).toFixed(1)}%`;

export const trimValue = (value: string): string => value.trim();

export const clampPercentage = (value: number): number => {
  if (!Number.isFinite(value)) return 100;
  const numeric = Math.floor(value);
  if (numeric < 0) return 0;
  if (numeric > 100) return 100;
  return numeric;
};

export const clampInt = (value: number, fallback: number, min: number, max: number): number => {
  if (!Number.isFinite(value)) return fallback;
  const numeric = Math.floor(value);
  if (numeric < min) return min;
  if (numeric > max) return max;
  return numeric;
};

export const CATEGORY_OPTIONS = [
  { value: 'chat_message', label: '聊天消息' },
  { value: 'community_interaction', label: '社区互动' },
  { value: 'event_countdown', label: '活动倒计时' },
  { value: 'event_daily_digest', label: '活动日报' },
  { value: 'route_dj_reminder', label: '路线 DJ 提醒' },
  { value: 'followed_dj_update', label: '关注 DJ 更新' },
  { value: 'followed_brand_update', label: '关注品牌更新' },
  { value: 'account_enforcement', label: '账号处罚 / 申诉' },
  { value: 'content_review', label: '内容审核结果' },
  { value: 'report_decision', label: '举报处理结果' },
  { value: 'major_news', label: '重大资讯' },
] as const;

export const CHANNEL_OPTIONS = [
  { value: 'in_app', label: '站内' },
  { value: 'apns', label: 'APNS' },
  { value: 'email', label: 'Email' },
  { value: 'sms', label: 'SMS' },
] as const;

export const SECTION_OPTIONS: Array<{
  key: NotificationCenterDeliverySection;
  label: string;
  helper: string;
}> = [
  { key: 'event_news', label: '活动资讯通知', helper: '面向关注活动用户的资讯更新通知' },
  { key: 'event_release', label: '活动发布通知', helper: '活动入库或发布后的统一通知记录' },
  { key: 'followed_dj_news', label: 'DJ 资讯通知', helper: '面向关注 DJ 用户的资讯更新通知' },
  { key: 'followed_dj_event', label: 'DJ 关联活动通知', helper: '面向关注 DJ 用户的活动发布提醒' },
  { key: 'followed_brand_news', label: '品牌资讯通知', helper: '面向关注品牌用户的资讯更新通知' },
  { key: 'followed_brand_event', label: '品牌关联活动通知', helper: '面向关注品牌用户的活动发布提醒' },
  { key: 'major_news_broadcast', label: '重大资讯广播', helper: '面向更广泛受众的重大消息广播' },
  { key: 'event_schedule', label: '活动日程提醒', helper: '倒计时、日报、路线 DJ 提醒等时程类通知' },
  { key: 'chat_and_community', label: '聊天与社区', helper: '聊天消息、互动提醒等社区通知' },
  { key: 'moderation_and_system', label: '审核与系统', helper: '内容审核、举报处理、账号处罚等系统通知' },
  { key: 'other', label: '其他通知', helper: '未归入以上分类的投递记录' },
];

export const CATEGORY_VALUES = new Set(CATEGORY_OPTIONS.map((item) => item.value));
export const CHANNEL_VALUES = new Set(CHANNEL_OPTIONS.map((item) => item.value));

export const DEFAULT_GOVERNANCE: NotificationCenterGlobalConfig['governance'] = {
  rateLimit: {
    enabled: false,
    windowSeconds: 3600,
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
};

export const DEFAULT_TEMPLATE_FORM = {
  category: 'chat_message' as (typeof CATEGORY_OPTIONS)[number]['value'],
  locale: 'zh-CN',
  channel: 'apns' as (typeof CHANNEL_OPTIONS)[number]['value'],
  titleTemplate: '',
  bodyTemplate: '',
  deeplinkTemplate: '',
  variablesText: '',
  isActive: true,
};

export const parseCommaValues = (value: string): string[] =>
  Array.from(
    new Set(
      value
        .split(',')
        .map((item) => item.trim())
        .filter(Boolean)
    )
  );

export const normalizeConfigDraft = (config: NotificationCenterGlobalConfig): NotificationCenterGlobalConfig => ({
  ...config,
  governance: {
    rateLimit: {
      ...DEFAULT_GOVERNANCE.rateLimit,
      ...(config.governance?.rateLimit || {}),
    },
    quietHours: {
      ...DEFAULT_GOVERNANCE.quietHours,
      ...(config.governance?.quietHours || {}),
    },
  },
});

export const toVariablesArray = (value: unknown): string[] => {
  if (!Array.isArray(value)) return [];
  return value
    .filter((item): item is string => typeof item === 'string')
    .map((item) => item.trim())
    .filter(Boolean);
};

export const buildVisiblePages = (page: number, totalPages: number): number[] => {
  const safeTotalPages = Math.max(1, totalPages);
  const start = Math.max(1, Math.min(safeTotalPages - 4, page - 2));
  const end = Math.min(safeTotalPages, start + 4);
  return Array.from({ length: end - start + 1 }, (_, index) => start + index);
};

export const sectionSummaryMap = (items: NotificationCenterDeliverySectionSummary[]) =>
  new Map(items.map((item) => [item.section, item]));
