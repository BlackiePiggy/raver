import { Router, Request, Response } from 'express';
import { Prisma, PrismaClient } from '@prisma/client';
import { authenticate, AuthRequest } from '../middleware/auth';
import { adminAuditService } from '../modules/admin/admin-audit.service';
import { requireAdmin } from '../modules/admin/admin-auth.policy';
import {
  getNotificationCenterAPNSStatus,
  notificationCenterService,
  NOTIFICATION_ADMIN_DELIVERY_SECTIONS,
  NOTIFICATION_ADMIN_PUBLISH_TASK_TYPES,
  type NotificationAdminDeliverySection,
} from '../modules/notifications';
import type { NotificationChannel } from '../services/notification-center/notification-center.types';
import { deriveNewsBindingIds, includeNewsBindings } from '../services/content-bindings.service';
import {
  USER_ENTITY_RELATION_FAVORITE,
  USER_ENTITY_RELATION_FOLLOW,
  USER_ENTITY_TARGET_DJ,
  USER_ENTITY_TARGET_EVENT,
} from '../services/user-entity-follow.service';

const router: Router = Router();
const prisma = new PrismaClient();

const emptyEntityChangeNotificationMetadata = {
  changeLogId: null,
  publicSummaryZh: null,
  publicSummaryEn: null,
  publicSummaryJa: null,
  publicChanges: [],
};

const fetchLatestEntityChangeNotificationMetadata = async (
  entityType: 'event' | 'dj' | 'brand',
  entityId: string
): Promise<{
  changeLogId: string | null;
  publicSummaryZh: string | null;
  publicSummaryEn: string | null;
  publicSummaryJa: string | null;
  publicChanges: Prisma.JsonValue;
}> => {
  const row = await prisma.entityChangeLog.findFirst({
    where: {
      entityType,
      entityId,
      changed: true,
    },
    orderBy: { createdAt: 'desc' },
    select: {
      id: true,
      publicSummaryZh: true,
      publicSummaryEn: true,
      publicSummaryJa: true,
      publicChanges: true,
    },
  });
  if (!row) return emptyEntityChangeNotificationMetadata;
  return {
    changeLogId: row.id,
    publicSummaryZh: row.publicSummaryZh,
    publicSummaryEn: row.publicSummaryEn,
    publicSummaryJa: row.publicSummaryJa,
    publicChanges: row.publicChanges,
  };
};
const TEMPLATE_CHANNELS = new Set(['in_app', 'apns', 'email', 'sms']);
const DELIVERABLE_CHANNELS = new Set(['in_app', 'apns']);

const isTemplateChannel = (value: string): value is NotificationChannel => TEMPLATE_CHANNELS.has(value);
const isDeliverableChannel = (value: string): value is NotificationChannel => DELIVERABLE_CHANNELS.has(value);

type LegacyNotificationType = 'follow' | 'like' | 'comment' | 'squad_invite';
type CommunityNotificationSource = 'user_follow' | 'post_like' | 'post_comment' | 'post_comment_reply' | 'squad_invite';

const LEGACY_NOTIFICATION_TYPE_SOURCES: Record<LegacyNotificationType, CommunityNotificationSource[]> = {
  follow: ['user_follow'],
  like: ['post_like'],
  comment: ['post_comment', 'post_comment_reply'],
  squad_invite: ['squad_invite'],
};

const parseLimit = (raw: unknown, fallback = 20, max = 100): number => {
  const numeric = Number(raw);
  if (!Number.isFinite(numeric)) {
    return fallback;
  }
  const value = Math.floor(numeric);
  if (value < 1) {
    return fallback;
  }
  return Math.min(value, max);
};

const parseWindowHours = (raw: unknown, fallback = 24, max = 24 * 30): number => {
  const numeric = Number(raw);
  if (!Number.isFinite(numeric)) {
    return fallback;
  }
  const value = Math.floor(numeric);
  if (value < 1) {
    return fallback;
  }
  return Math.min(value, max);
};

const parseBoolean = (raw: unknown): boolean | undefined => {
  if (typeof raw === 'boolean') {
    return raw;
  }
  if (typeof raw !== 'string') {
    return undefined;
  }
  const value = raw.trim().toLowerCase();
  if (value === '1' || value === 'true' || value === 'yes') {
    return true;
  }
  if (value === '0' || value === 'false' || value === 'no') {
    return false;
  }
  return undefined;
};

const parsePage = (raw: unknown, fallback = 1, max = 100000): number => {
  const numeric = Number(raw);
  if (!Number.isFinite(numeric)) {
    return fallback;
  }
  const value = Math.floor(numeric);
  if (value < 1) {
    return fallback;
  }
  return Math.min(value, max);
};

const normalizeStringArray = (value: unknown): string[] =>
  Array.from(
    new Set(
      Array.isArray(value)
        ? value
            .filter((item): item is string => typeof item === 'string')
            .map((item) => item.trim())
            .filter(Boolean)
        : []
    )
  );

const ADMIN_NEWS_AUDIENCE_KEYS = ['event_news', 'followed_dj_news', 'followed_brand_news'] as const;
type AdminNewsAudienceKey = (typeof ADMIN_NEWS_AUDIENCE_KEYS)[number];
const ADMIN_EVENT_AUDIENCE_KEYS = ['followed_dj_event', 'followed_brand_event'] as const;
type AdminEventAudienceKey = (typeof ADMIN_EVENT_AUDIENCE_KEYS)[number];
const ADMIN_DJ_AUDIENCE_KEYS = ['followed_dj_info'] as const;
type AdminDJAudienceKey = (typeof ADMIN_DJ_AUDIENCE_KEYS)[number];
const ADMIN_BRAND_AUDIENCE_KEYS = ['followed_brand_info'] as const;
type AdminBrandAudienceKey = (typeof ADMIN_BRAND_AUDIENCE_KEYS)[number];
type AdminPublishTaskType = (typeof NOTIFICATION_ADMIN_PUBLISH_TASK_TYPES)[number];

const isAdminNewsAudienceKey = (value: string): value is AdminNewsAudienceKey =>
  (ADMIN_NEWS_AUDIENCE_KEYS as readonly string[]).includes(value);
const isAdminEventAudienceKey = (value: string): value is AdminEventAudienceKey =>
  (ADMIN_EVENT_AUDIENCE_KEYS as readonly string[]).includes(value);
const isAdminDJAudienceKey = (value: string): value is AdminDJAudienceKey =>
  (ADMIN_DJ_AUDIENCE_KEYS as readonly string[]).includes(value);
const isAdminBrandAudienceKey = (value: string): value is AdminBrandAudienceKey =>
  (ADMIN_BRAND_AUDIENCE_KEYS as readonly string[]).includes(value);
const isAdminPublishTaskType = (value: string): value is AdminPublishTaskType =>
  (NOTIFICATION_ADMIN_PUBLISH_TASK_TYPES as readonly string[]).includes(value);
const isAdminContentHistoryOperationType = (value: string): value is 'create' | 'edit' =>
  value === 'create' || value === 'edit';
const isAdminContentHistoryResultStatus = (value: string): value is 'success' | 'failed' =>
  value === 'success' || value === 'failed';
const isAdminContentHistoryPushStatus = (
  value: string
): value is 'pending' | 'published' | 'skipped' | 'superseded' | 'not_applicable' =>
  value === 'pending' ||
  value === 'published' ||
  value === 'skipped' ||
  value === 'superseded' ||
  value === 'not_applicable';

const parseLegacyNotificationType = (rawType: unknown): LegacyNotificationType | null => {
  if (typeof rawType !== 'string') return null;
  const normalized = rawType.trim().toLowerCase();
  if (!normalized) return null;
  if (normalized === 'follow') return 'follow';
  if (normalized === 'like') return 'like';
  if (normalized === 'comment') return 'comment';
  if (normalized === 'squad_invite' || normalized === 'squadinvite') return 'squad_invite';
  return null;
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

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === 'object' && value !== null && !Array.isArray(value);

const readString = (value: unknown): string | null => {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
};

const readDate = (value: unknown): Date | null => {
  if (value instanceof Date && !Number.isNaN(value.getTime())) {
    return value;
  }
  if (typeof value === 'string' && value.trim().length > 0) {
    const parsed = new Date(value);
    if (!Number.isNaN(parsed.getTime())) {
      return parsed;
    }
  }
  return null;
};

const newsBodyToPlainText = (value: string): string =>
  value
    .replace(/!\[[^\]]*]\([^)]+\)/g, ' ')
    .replace(/\[([^\]]+)]\([^)]+\)/g, '$1')
    .replace(/[`*_>#~-]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

type AdminNewsAudienceSummary = {
  key: AdminNewsAudienceKey;
  label: string;
  entityCount: number;
  targetUserCount: number;
  entities: Array<{
    id: string;
    name: string;
    targetUserCount: number;
  }>;
};

type AdminNewsNotificationContext = {
  article: {
    id: string;
    title: string;
    summary: string;
    coverImageURL: string | null;
    deeplink: string;
    publishedAt: string;
  };
  audiences: AdminNewsAudienceSummary[];
};

type AdminNewsAudienceRuntime = {
  key: AdminNewsAudienceKey;
  label: string;
  rows: Array<{
    id: string;
    name: string;
    targetUserIds: string[];
  }>;
};

type AdminNewsNotificationRuntime = AdminNewsNotificationContext & {
  audienceRuntime: AdminNewsAudienceRuntime[];
};

type AdminPublishAudienceSummary = {
  key: string;
  label: string;
  entityCount: number;
  targetUserCount: number;
  entities: Array<{
    id: string;
    name: string;
    targetUserCount: number;
  }>;
};

type AdminPublishTaskContext = {
  kind: AdminPublishTaskType;
  entity: {
    id: string;
    title: string;
    summary: string;
    coverImageURL: string | null;
    deeplink: string;
    occurredAt: string;
    startDate: string | null;
    timeZone: string | null;
  };
  audiences: AdminPublishAudienceSummary[];
};

type AdminEventNotificationContext = {
  event: {
    id: string;
    title: string;
    summary: string;
    coverImageURL: string | null;
    deeplink: string;
    updatedAt: string;
    startDate: string | null;
    timeZone: string | null;
  };
  audiences: AdminPublishAudienceSummary[];
};

type AdminEventAudienceRuntime = {
  key: AdminEventAudienceKey;
  label: string;
  rows: Array<{
    id: string;
    name: string;
    targetUserIds: string[];
  }>;
};

type AdminEventNotificationRuntime = AdminEventNotificationContext & {
  audienceRuntime: AdminEventAudienceRuntime[];
};

type AdminDJAudienceRuntime = {
  key: AdminDJAudienceKey;
  label: string;
  rows: Array<{
    id: string;
    name: string;
    targetUserIds: string[];
  }>;
};

type AdminDJNotificationContext = {
  dj: {
    id: string;
    title: string;
    summary: string;
    coverImageURL: string | null;
    deeplink: string;
    updatedAt: string;
  };
  audiences: AdminPublishAudienceSummary[];
};

type AdminDJNotificationRuntime = AdminDJNotificationContext & {
  audienceRuntime: AdminDJAudienceRuntime[];
};

type AdminBrandAudienceRuntime = {
  key: AdminBrandAudienceKey;
  label: string;
  rows: Array<{
    id: string;
    name: string;
    entityType: 'festival' | 'label';
    targetUserIds: string[];
  }>;
};

type AdminBrandNotificationContext = {
  brand: {
    id: string;
    entityType: 'festival' | 'label';
    title: string;
    summary: string;
    coverImageURL: string | null;
    deeplink: string;
    updatedAt: string;
  };
  audiences: AdminPublishAudienceSummary[];
};

type AdminBrandNotificationRuntime = AdminBrandNotificationContext & {
  audienceRuntime: AdminBrandAudienceRuntime[];
};

type AdminPublishExecutionAudienceResult = {
  key: string;
  label: string;
  entityCount: number;
  targetUserCount: number;
  dedupeKeys: string[];
  results: Array<{
    entityId: string;
    entityName: string;
    targetUserCount: number;
    publishResult: Array<{
      channel: string;
      success: boolean;
      detail?: string;
    }>;
  }>;
};

type AdminPublishExecutionResult = {
  success: boolean;
  kind: AdminPublishTaskType;
  entity: {
    id: string;
    title: string;
    summary: string;
    coverImageURL: string | null;
    deeplink: string;
    occurredAt: string;
    startDate: string | null;
    timeZone: string | null;
  };
  audiences: AdminPublishExecutionAudienceResult[];
};

const ADMIN_MANUAL_AUDIENCE_TYPES = [
  'direct_users',
  'followed_dj',
  'followed_brand',
  'favorited_event',
] as const;
type AdminManualAudienceType = (typeof ADMIN_MANUAL_AUDIENCE_TYPES)[number];

const ADMIN_MANUAL_RELATED_ENTITY_TYPES = [
  'news',
  'event',
  'dj',
  'festival',
  'label',
] as const;
type AdminManualRelatedEntityType = (typeof ADMIN_MANUAL_RELATED_ENTITY_TYPES)[number];

type AdminManualAudienceEntityInput = {
  id: string;
  name?: string | null;
  entityType?: string | null;
};

type AdminManualAudienceRuntimeRow = {
  id: string;
  name: string;
  entityType?: string | null;
  targetUserIds: string[];
};

type AdminManualAudienceRuntime = {
  type: AdminManualAudienceType;
  label: string;
  rows: AdminManualAudienceRuntimeRow[];
};

type AdminManualRelatedEntityContext = {
  type: AdminManualRelatedEntityType;
  id: string;
  title: string;
  summary: string;
  deeplink: string | null;
  imageUrl: string | null;
};

type AdminManualContentContext = {
  headline: string;
  summary: string;
  deeplink: string | null;
  imageUrl: string | null;
  relatedEntity: AdminManualRelatedEntityContext | null;
};

type AdminManualAudienceSummary = {
  type: AdminManualAudienceType;
  label: string;
  entityCount: number;
  targetUserCount: number;
  uniqueTargetUserCount: number;
  entities: Array<{
    id: string;
    name: string;
    entityType?: string | null;
    targetUserCount: number;
  }>;
};

type AdminManualNotificationPreview = {
  content: AdminManualContentContext;
  audiences: AdminManualAudienceSummary[];
  totals: {
    selectedEntityCount: number;
    totalTargetAssignments: number;
    totalUniqueTargetUsers: number;
  };
};

type AdminManualNotificationExecutionResult = {
  success: boolean;
  content: AdminManualContentContext;
  audiences: Array<AdminManualAudienceSummary & {
    dedupeKeys: string[];
    results: Array<{
      entityId: string;
      entityName: string;
      entityType?: string | null;
      targetUserCount: number;
      publishResult: Array<{
        channel: string;
        success: boolean;
        detail?: string;
      }>;
    }>;
  }>;
  totals: {
    selectedEntityCount: number;
    totalTargetAssignments: number;
    totalUniqueTargetUsers: number;
  };
};

const isAdminManualAudienceType = (value: string): value is AdminManualAudienceType =>
  (ADMIN_MANUAL_AUDIENCE_TYPES as readonly string[]).includes(value);
const isAdminManualRelatedEntityType = (value: string): value is AdminManualRelatedEntityType =>
  (ADMIN_MANUAL_RELATED_ENTITY_TYPES as readonly string[]).includes(value);

const ADMIN_MANUAL_AUDIENCE_LABELS: Record<AdminManualAudienceType, string> = {
  direct_users: 'Direct Users',
  followed_dj: 'Followed DJ Audience',
  followed_brand: 'Followed Brand Audience',
  favorited_event: 'Favorited Event Audience',
};

const resolveAdminNewsNotificationRuntime = async (
  articleId: string
): Promise<AdminNewsNotificationRuntime | null> => {
  const article = await prisma.newsArticle.findUnique({
    where: { id: articleId },
    include: includeNewsBindings,
  });
  if (!article) {
    return null;
  }

  const bindingIds = deriveNewsBindingIds(article);
  const summaryText = article.summary.trim() || newsBodyToPlainText(article.body).slice(0, 140) || article.title;
  const deeplink = `raver://news/${encodeURIComponent(article.id)}`;

  const eventAudienceRows = bindingIds.eventIds.length
    ? await Promise.all(
        (
          await prisma.event.findMany({
            where: { id: { in: bindingIds.eventIds } },
            select: { id: true, name: true },
          })
        ).map(async (eventItem) => {
          const followers = await prisma.userEntityFollow.findMany({
            where: {
              relationType: USER_ENTITY_RELATION_FAVORITE,
              targetType: USER_ENTITY_TARGET_EVENT,
              targetId: eventItem.id,
            },
            select: { userId: true },
          });
          const targetUserIds = Array.from(new Set(followers.map((row) => row.userId.trim()).filter(Boolean)));
          return {
            id: eventItem.id,
            name: eventItem.name.trim() || eventItem.id,
            targetUserIds,
          };
        })
      )
    : [];

  const djAudienceRows = bindingIds.djIds.length
    ? await Promise.all(
        (
          await prisma.dJ.findMany({
            where: { id: { in: bindingIds.djIds } },
            select: { id: true, name: true },
          })
        ).map(async (djItem) => {
          const followers = await prisma.userEntityFollow.findMany({
            where: {
              relationType: USER_ENTITY_RELATION_FOLLOW,
              targetType: USER_ENTITY_TARGET_DJ,
              targetId: djItem.id,
            },
            select: { userId: true },
          });
          const targetUserIds = Array.from(new Set(followers.map((row) => row.userId.trim()).filter(Boolean)));
          return {
            id: djItem.id,
            name: djItem.name.trim() || djItem.id,
            targetUserIds,
          };
        })
      )
    : [];

  const brandAudienceRows = bindingIds.brandIds.length
    ? await (async () => {
        const [festivalBrands, labels, subscriptions] = await Promise.all([
          prisma.wikiFestival.findMany({
            where: { id: { in: bindingIds.brandIds } },
            select: { id: true, name: true },
          }),
          prisma.label.findMany({
            where: { id: { in: bindingIds.brandIds } },
            select: { id: true, name: true },
          }),
          notificationCenterService.fetchFollowedBrandUpdateSubscriptions(),
        ]);

        const brandNameById = new Map<string, string>();
        for (const item of festivalBrands) brandNameById.set(item.id, item.name.trim() || item.id);
        for (const item of labels) {
          if (!brandNameById.has(item.id)) {
            brandNameById.set(item.id, item.name.trim() || item.id);
          }
        }

        return bindingIds.brandIds
          .map((brandId) => {
            const name = brandNameById.get(brandId);
            if (!name) return null;
            const targetUserIds = Array.from(
              new Set(
                subscriptions
                  .filter((row) => row.preference.enabled && row.preference.watchedBrandIds.includes(brandId))
                  .map((row) => row.userId.trim())
                  .filter(Boolean)
              )
            );
            return {
              id: brandId,
              name,
              targetUserIds,
            };
          })
          .filter(
            (item): item is { id: string; name: string; targetUserIds: string[] } => item !== null
          );
      })()
    : [];

  const audienceRuntime: AdminNewsAudienceRuntime[] = [
    {
      key: 'event_news',
      label: 'Favorited Event Followers',
      rows: eventAudienceRows,
    },
    {
      key: 'followed_dj_news',
      label: 'Followed DJ Audience',
      rows: djAudienceRows,
    },
    {
      key: 'followed_brand_news',
      label: 'Followed Brand Audience',
      rows: brandAudienceRows,
    },
  ];

  const audiences: AdminNewsAudienceSummary[] = [
    {
      key: 'event_news',
      label: 'Favorited Event Followers',
      entityCount: eventAudienceRows.length,
      targetUserCount: Array.from(new Set(eventAudienceRows.flatMap((item) => item.targetUserIds))).length,
      entities: eventAudienceRows.map((item) => ({
        id: item.id,
        name: item.name,
        targetUserCount: item.targetUserIds.length,
      })),
    },
    {
      key: 'followed_dj_news',
      label: 'Followed DJ Audience',
      entityCount: djAudienceRows.length,
      targetUserCount: Array.from(new Set(djAudienceRows.flatMap((item) => item.targetUserIds))).length,
      entities: djAudienceRows.map((item) => ({
        id: item.id,
        name: item.name,
        targetUserCount: item.targetUserIds.length,
      })),
    },
    {
      key: 'followed_brand_news',
      label: 'Followed Brand Audience',
      entityCount: brandAudienceRows.length,
      targetUserCount: Array.from(new Set(brandAudienceRows.flatMap((item) => item.targetUserIds))).length,
      entities: brandAudienceRows.map((item) => ({
        id: item.id,
        name: item.name,
        targetUserCount: item.targetUserIds.length,
      })),
    },
  ];

  return {
    article: {
      id: article.id,
      title: article.title,
      summary: summaryText,
      coverImageURL: article.coverImageUrl,
      deeplink,
      publishedAt: article.publishedAt.toISOString(),
    },
    audiences,
    audienceRuntime,
  };
};

const buildAdminNewsNotificationContext = async (articleId: string): Promise<AdminNewsNotificationContext | null> => {
  const runtime = await resolveAdminNewsNotificationRuntime(articleId);
  if (!runtime) return null;
  return {
    article: runtime.article,
    audiences: runtime.audiences,
  };
};

const resolveAdminEventNotificationRuntime = async (
  eventId: string
): Promise<AdminEventNotificationRuntime | null> => {
  const event = await prisma.event.findUnique({
    where: { id: eventId },
    select: {
      id: true,
      name: true,
      description: true,
      coverImageUrl: true,
      lineupImageUrl: true,
      imageAssets: true,
      updatedAt: true,
      startDate: true,
      timeZone: true,
      wikiFestivalId: true,
      canonicalArtists: {
        select: {
          primaryDjId: true,
          members: {
            select: {
              djId: true,
            },
          },
        },
      },
    },
  });
  if (!event) return null;

  const eventSummary =
    readString(event.description) ??
    `New event release: ${event.name.trim() || event.id}`;
  const coverImageURL =
    readString(event.coverImageUrl) ??
    readString(event.lineupImageUrl) ??
    (Array.isArray(event.imageAssets)
      ? event.imageAssets
          .map((asset) => {
            if (!asset || typeof asset !== 'object' || Array.isArray(asset)) return null;
            return readString((asset as Record<string, unknown>).url);
          })
          .find(Boolean) ?? null
      : null);

  const djIds = Array.from(
    new Set(
      (Array.isArray(event.canonicalArtists) ? event.canonicalArtists : []).flatMap((artist) => {
        const primary = readString(artist.primaryDjId);
        const memberIds = Array.isArray(artist.members)
          ? artist.members
              .map((member) => readString(member.djId))
              .filter((value): value is string => Boolean(value))
          : [];
        return primary ? [primary, ...memberIds] : memberIds;
      })
    )
  );

  const djAudienceRows = djIds.length
    ? await Promise.all(
        (
          await prisma.dJ.findMany({
            where: { id: { in: djIds } },
            select: { id: true, name: true },
          })
        ).map(async (djItem) => {
          const followers = await prisma.userEntityFollow.findMany({
            where: {
              relationType: USER_ENTITY_RELATION_FOLLOW,
              targetType: USER_ENTITY_TARGET_DJ,
              targetId: djItem.id,
            },
            select: { userId: true },
          });
          return {
            id: djItem.id,
            name: djItem.name.trim() || djItem.id,
            targetUserIds: Array.from(new Set(followers.map((row) => row.userId.trim()).filter(Boolean))),
          };
        })
      )
    : [];

  const brandAudienceRows = event.wikiFestivalId
    ? await (async () => {
        const brandIdValue = readString(event.wikiFestivalId);
        const brandId = brandIdValue?.trim() || '';
        if (!brandId) return [] as Array<{ id: string; name: string; targetUserIds: string[] }>;
        const [festivalBrand, labelBrand, subscriptions] = await Promise.all([
          prisma.wikiFestival.findUnique({
            where: { id: brandId },
            select: { id: true, name: true },
          }),
          prisma.label.findUnique({
            where: { id: brandId },
            select: { id: true, name: true },
          }),
          notificationCenterService.fetchFollowedBrandUpdateSubscriptions(),
        ]);
        const brandName =
          festivalBrand?.name?.trim() ||
          labelBrand?.name?.trim() ||
          brandId;
        const targetUserIds = Array.from(
          new Set(
            subscriptions
              .filter((row) => row.preference.enabled && row.preference.watchedBrandIds.includes(brandId))
              .map((row) => row.userId.trim())
              .filter(Boolean)
          )
        );
        return [{ id: brandId, name: brandName, targetUserIds }];
      })()
    : [];

  const audienceRuntime: AdminEventAudienceRuntime[] = [
    {
      key: 'followed_dj_event',
      label: 'Followed DJ Audience',
      rows: djAudienceRows,
    },
    {
      key: 'followed_brand_event',
      label: 'Followed Brand Audience',
      rows: brandAudienceRows,
    },
  ];

  const audiences: AdminPublishAudienceSummary[] = audienceRuntime.map((audience) => ({
    key: audience.key,
    label: audience.label,
    entityCount: audience.rows.length,
    targetUserCount: Array.from(new Set(audience.rows.flatMap((item) => item.targetUserIds))).length,
    entities: audience.rows.map((item) => ({
      id: item.id,
      name: item.name,
      targetUserCount: item.targetUserIds.length,
    })),
  }));

  return {
    event: {
      id: event.id,
      title: event.name.trim() || event.id,
      summary: eventSummary,
      coverImageURL,
      deeplink: `raver://event/${encodeURIComponent(event.id)}`,
      updatedAt: event.updatedAt.toISOString(),
      startDate: event.startDate ? event.startDate.toISOString() : null,
      timeZone: readString(event.timeZone),
    },
    audiences,
    audienceRuntime,
  };
};

const buildAdminEventNotificationContext = async (eventId: string): Promise<AdminEventNotificationContext | null> => {
  const runtime = await resolveAdminEventNotificationRuntime(eventId);
  if (!runtime) return null;
  return {
    event: runtime.event,
    audiences: runtime.audiences,
  };
};

const resolveAdminDJNotificationRuntime = async (
  djId: string
): Promise<AdminDJNotificationRuntime | null> => {
  const [row, followers] = await Promise.all([
    prisma.dJ.findUnique({
      where: { id: djId },
      select: {
        id: true,
        name: true,
        bio: true,
        avatarUrl: true,
        updatedAt: true,
      },
    }),
    prisma.userEntityFollow.findMany({
      where: {
        relationType: USER_ENTITY_RELATION_FOLLOW,
        targetType: USER_ENTITY_TARGET_DJ,
        targetId: djId,
      },
      select: { userId: true },
    }),
  ]);

  if (!row) return null;

  const audienceRows = [
    {
      id: row.id,
      name: row.name.trim() || row.id,
      targetUserIds: Array.from(new Set(followers.map((item) => item.userId.trim()).filter(Boolean))),
    },
  ];

  const audienceRuntime: AdminDJAudienceRuntime[] = [
    {
      key: 'followed_dj_info',
      label: 'Followed DJ Audience',
      rows: audienceRows,
    },
  ];

  const audiences: AdminPublishAudienceSummary[] = audienceRuntime.map((audience) => ({
    key: audience.key,
    label: audience.label,
    entityCount: audience.rows.length,
    targetUserCount: Array.from(new Set(audience.rows.flatMap((item) => item.targetUserIds))).length,
    entities: audience.rows.map((item) => ({
      id: item.id,
      name: item.name,
      targetUserCount: item.targetUserIds.length,
    })),
  }));

  return {
    dj: {
      id: row.id,
      title: row.name.trim() || row.id,
      summary: readString(row.bio) ?? row.name.trim() ?? row.id,
      coverImageURL: readString(row.avatarUrl),
      deeplink: `raver://dj/${encodeURIComponent(row.id)}`,
      updatedAt: row.updatedAt.toISOString(),
    },
    audiences,
    audienceRuntime,
  };
};

const buildAdminDJNotificationContext = async (djId: string): Promise<AdminDJNotificationContext | null> => {
  const runtime = await resolveAdminDJNotificationRuntime(djId);
  if (!runtime) return null;
  return {
    dj: runtime.dj,
    audiences: runtime.audiences,
  };
};

const resolveAdminBrandNotificationRuntime = async (
  brandId: string,
  entityType: string
): Promise<AdminBrandNotificationRuntime | null> => {
  const normalizedEntityType = entityType.trim().toLowerCase();
  let row:
    | {
        id: string;
        title: string;
        summary: string;
        coverImageURL: string | null;
        deeplink: string;
        updatedAt: string;
        entityType: 'festival' | 'label';
      }
    | null = null;

  if (normalizedEntityType === 'festival' || normalizedEntityType === 'brand' || normalizedEntityType === 'wiki_festival') {
    const festival = await prisma.wikiFestival.findUnique({
      where: { id: brandId },
      select: {
        id: true,
        name: true,
        introduction: true,
        avatarUrl: true,
        backgroundUrl: true,
        updatedAt: true,
      },
    });
    if (festival) {
      row = {
        id: festival.id,
        title: festival.name.trim() || festival.id,
        summary: readString(festival.introduction) ?? festival.name.trim() ?? festival.id,
        coverImageURL: readString(festival.avatarUrl) ?? readString(festival.backgroundUrl),
        deeplink: `raver://festival/${encodeURIComponent(festival.id)}`,
        updatedAt: festival.updatedAt.toISOString(),
        entityType: 'festival',
      };
    }
  }

  if (!row) {
    const label = await prisma.label.findUnique({
      where: { id: brandId },
      select: {
        id: true,
        name: true,
        introduction: true,
        avatarUrl: true,
        backgroundUrl: true,
        updatedAt: true,
      },
    });
    if (!label) return null;
    row = {
      id: label.id,
      title: label.name.trim() || label.id,
      summary: readString(label.introduction) ?? label.name.trim() ?? label.id,
      coverImageURL: readString(label.avatarUrl) ?? readString(label.backgroundUrl),
      deeplink: `raver://label/${encodeURIComponent(label.id)}`,
      updatedAt: label.updatedAt.toISOString(),
      entityType: 'label',
    };
  }

  const subscriptions = await notificationCenterService.fetchFollowedBrandUpdateSubscriptions();
  const audienceRows = [
    {
      id: row.id,
      name: row.title,
      entityType: row.entityType,
      targetUserIds: Array.from(
        new Set(
          subscriptions
            .filter((item) => item.preference.enabled && item.preference.watchedBrandIds.includes(row!.id))
            .map((item) => item.userId.trim())
            .filter(Boolean)
        )
      ),
    },
  ];

  const audienceRuntime: AdminBrandAudienceRuntime[] = [
    {
      key: 'followed_brand_info',
      label: 'Followed Brand Audience',
      rows: audienceRows,
    },
  ];

  const audiences: AdminPublishAudienceSummary[] = audienceRuntime.map((audience) => ({
    key: audience.key,
    label: audience.label,
    entityCount: audience.rows.length,
    targetUserCount: Array.from(new Set(audience.rows.flatMap((item) => item.targetUserIds))).length,
    entities: audience.rows.map((item) => ({
      id: item.id,
      name: item.name,
      targetUserCount: item.targetUserIds.length,
    })),
  }));

  return {
    brand: row,
    audiences,
    audienceRuntime,
  };
};

const buildAdminBrandNotificationContext = async (
  brandId: string,
  entityType: string
): Promise<AdminBrandNotificationContext | null> => {
  const runtime = await resolveAdminBrandNotificationRuntime(brandId, entityType);
  if (!runtime) return null;
  return {
    brand: runtime.brand,
    audiences: runtime.audiences,
  };
};

const executeAdminNewsPublish = async (input: {
  actorUserId: string;
  articleId: string;
  audienceKeys?: AdminNewsAudienceKey[];
  channels: Array<'in_app' | 'apns'>;
  dedupeSalt?: string | null;
}): Promise<AdminPublishExecutionResult | null> => {
  const runtime = await resolveAdminNewsNotificationRuntime(input.articleId);
  if (!runtime) return null;

  const audienceKeys = input.audienceKeys?.length ? input.audienceKeys : ['event_news'];
  const dedupeSalt = input.dedupeSalt?.trim() || runtime.article.publishedAt.slice(0, 13);
  const publicationResults: AdminPublishExecutionAudienceResult[] = [];

  for (const key of audienceKeys) {
    const runtimeAudience = runtime.audienceRuntime.find((item) => item.key === key);
    if (!runtimeAudience) continue;
    const resultsForAudience: AdminPublishExecutionAudienceResult['results'] = [];
    const dedupeKeys: string[] = [];

    for (const row of runtimeAudience.rows) {
      const targetUserIds = Array.from(new Set(row.targetUserIds.map((item) => item.trim()).filter(Boolean)));
      if (targetUserIds.length === 0) continue;

      let category: 'major_news' | 'followed_dj_update' | 'followed_brand_update' = 'major_news';
      let title = runtime.article.title;
      let metadata: Record<string, unknown> = {
        newsId: runtime.article.id,
        newsTitle: runtime.article.title,
        newsSummary: runtime.article.summary,
        newsCoverImageURL: runtime.article.coverImageURL,
        occurredAt: runtime.article.publishedAt,
        actorUserId: input.actorUserId,
        source: 'admin_news_publish',
      };
      let dedupeKey = '';

      if (key === 'event_news') {
        category = 'major_news';
        title = `${row.name} published an update`;
        metadata = {
          ...metadata,
          route: 'event_update',
          primaryUpdateKind: 'news',
          updateKind: 'news',
          eventId: row.id,
          eventName: row.name,
          sourceAudience: 'marked_event_users',
        };
        dedupeKey = `event-news:${row.id}:post:${runtime.article.id}:${dedupeSalt}`;
      } else if (key === 'followed_dj_news') {
        category = 'followed_dj_update';
        title = `${row.name} published an update`;
        metadata = {
          ...metadata,
          route: 'dj_update',
          primaryUpdateKind: 'news',
          updateKind: 'news',
          djId: row.id,
          djName: row.name,
          sourceAudience: 'followed_dj_users',
        };
        dedupeKey = `dj-news:${row.id}:post:${runtime.article.id}:${dedupeSalt}`;
      } else {
        category = 'followed_brand_update';
        title = `${row.name} published an update`;
        metadata = {
          ...metadata,
          route: 'brand_update',
          primaryUpdateKind: 'news',
          updateKind: 'news',
          brandId: row.id,
          brandName: row.name,
          sourceAudience: 'followed_brand_users',
        };
        dedupeKey = `brand-news:${row.id}:post:${runtime.article.id}:${dedupeSalt}`;
      }

      const publishResult = await notificationCenterService.publish({
        category,
        targets: targetUserIds.map((userId) => ({ userId })),
        channels: input.channels,
        dedupeKey,
        payload: {
          title,
          body: runtime.article.title,
          deeplink: runtime.article.deeplink,
          metadata,
        },
      });

      dedupeKeys.push(dedupeKey);
      resultsForAudience.push({
        entityId: row.id,
        entityName: row.name,
        targetUserCount: targetUserIds.length,
        publishResult: publishResult.map((item) => ({
          channel: item.channel,
          success: item.success,
          detail: item.detail,
        })),
      });
    }

    publicationResults.push({
      key,
      label: runtimeAudience.label,
      entityCount: runtimeAudience.rows.length,
      targetUserCount: Array.from(new Set(runtimeAudience.rows.flatMap((item) => item.targetUserIds))).length,
      dedupeKeys,
      results: resultsForAudience,
    });
  }

  return {
    success: true,
    kind: 'news_release',
    entity: {
      id: runtime.article.id,
      title: runtime.article.title,
      summary: runtime.article.summary,
      coverImageURL: runtime.article.coverImageURL,
      deeplink: runtime.article.deeplink,
      occurredAt: runtime.article.publishedAt,
      startDate: null,
      timeZone: null,
    },
    audiences: publicationResults,
  };
};

const executeAdminEventPublish = async (input: {
  actorUserId: string;
  eventId: string;
  audienceKeys?: AdminEventAudienceKey[];
  channels: Array<'in_app' | 'apns'>;
  dedupeSalt?: string | null;
}): Promise<AdminPublishExecutionResult | null> => {
  const runtime = await resolveAdminEventNotificationRuntime(input.eventId);
  if (!runtime) return null;

  const audienceKeys = input.audienceKeys?.length ? input.audienceKeys : ['followed_dj_event', 'followed_brand_event'];
  const dedupeSalt = input.dedupeSalt?.trim() || runtime.event.updatedAt.slice(0, 13);
  const changeMetadata = await fetchLatestEntityChangeNotificationMetadata('event', runtime.event.id);
  const publicationResults: AdminPublishExecutionAudienceResult[] = [];

  for (const key of audienceKeys) {
    const runtimeAudience = runtime.audienceRuntime.find((item) => item.key === key);
    if (!runtimeAudience) continue;
    const resultsForAudience: AdminPublishExecutionAudienceResult['results'] = [];
    const dedupeKeys: string[] = [];

    for (const row of runtimeAudience.rows) {
      const targetUserIds = Array.from(new Set(row.targetUserIds.map((item) => item.trim()).filter(Boolean)));
      if (targetUserIds.length === 0) continue;

      let category: 'followed_dj_update' | 'followed_brand_update' = 'followed_dj_update';
      let title = `${runtime.event.title} is now live`;
      let metadata: Record<string, unknown> = {
        eventId: runtime.event.id,
        eventName: runtime.event.title,
        eventSummary: runtime.event.summary,
        eventCoverImageURL: runtime.event.coverImageURL,
        occurredAt: runtime.event.updatedAt,
        actorUserId: input.actorUserId,
        source: 'admin_event_publish',
        route: 'event_update',
        primaryUpdateKind: 'event',
        updateKind: 'event',
        ...changeMetadata,
      };
      let dedupeKey = '';

      if (key === 'followed_dj_event') {
        category = 'followed_dj_update';
        title = `${row.name} has a new event`;
        metadata = {
          ...metadata,
          route: 'dj_update',
          djId: row.id,
          djName: row.name,
          sourceAudience: 'followed_dj_users',
        };
        dedupeKey = `dj-event:${row.id}:event:${runtime.event.id}:${dedupeSalt}`;
      } else {
        category = 'followed_brand_update';
        title = `${row.name} has a new event`;
        metadata = {
          ...metadata,
          route: 'brand_update',
          brandId: row.id,
          brandName: row.name,
          sourceAudience: 'followed_brand_users',
        };
        dedupeKey = `brand-event:${row.id}:event:${runtime.event.id}:${dedupeSalt}`;
      }

      const publishResult = await notificationCenterService.publish({
        category,
        targets: targetUserIds.map((userId) => ({ userId })),
        channels: input.channels,
        dedupeKey,
        payload: {
          title,
          body: changeMetadata.publicSummaryZh || runtime.event.title,
          deeplink: runtime.event.deeplink,
          metadata,
        },
      });

      dedupeKeys.push(dedupeKey);
      resultsForAudience.push({
        entityId: row.id,
        entityName: row.name,
        targetUserCount: targetUserIds.length,
        publishResult: publishResult.map((item) => ({
          channel: item.channel,
          success: item.success,
          detail: item.detail,
        })),
      });
    }

    publicationResults.push({
      key,
      label: runtimeAudience.label,
      entityCount: runtimeAudience.rows.length,
      targetUserCount: Array.from(new Set(runtimeAudience.rows.flatMap((item) => item.targetUserIds))).length,
      dedupeKeys,
      results: resultsForAudience,
    });
  }

  return {
    success: true,
    kind: 'event_release',
    entity: {
      id: runtime.event.id,
      title: runtime.event.title,
      summary: runtime.event.summary,
      coverImageURL: runtime.event.coverImageURL,
      deeplink: runtime.event.deeplink,
      occurredAt: runtime.event.updatedAt,
      startDate: runtime.event.startDate,
      timeZone: runtime.event.timeZone,
    },
    audiences: publicationResults,
  };
};

const executeAdminDJPublish = async (input: {
  actorUserId: string;
  djId: string;
  audienceKeys?: AdminDJAudienceKey[];
  channels: Array<'in_app' | 'apns'>;
  dedupeSalt?: string | null;
}): Promise<AdminPublishExecutionResult | null> => {
  const runtime = await resolveAdminDJNotificationRuntime(input.djId);
  if (!runtime) return null;

  const audienceKeys = input.audienceKeys?.length ? input.audienceKeys : ['followed_dj_info'];
  const dedupeSalt = input.dedupeSalt?.trim() || runtime.dj.updatedAt.slice(0, 13);
  const changeMetadata = await fetchLatestEntityChangeNotificationMetadata('dj', runtime.dj.id);
  const publicationResults: AdminPublishExecutionAudienceResult[] = [];

  for (const key of audienceKeys) {
    const runtimeAudience = runtime.audienceRuntime.find((item) => item.key === key);
    if (!runtimeAudience) continue;

    const resultsForAudience: AdminPublishExecutionAudienceResult['results'] = [];
    const dedupeKeys: string[] = [];

    for (const row of runtimeAudience.rows) {
      const targetUserIds = Array.from(new Set(row.targetUserIds.map((item) => item.trim()).filter(Boolean)));
      if (!targetUserIds.length) continue;

      const dedupeKey = `dj-info:${row.id}:dj:${runtime.dj.id}:${dedupeSalt}`;
      const publishResult = await notificationCenterService.publish({
        category: 'followed_dj_update',
        targets: targetUserIds.map((userId) => ({ userId })),
        channels: input.channels,
        dedupeKey,
        payload: {
          title: `${row.name} profile updated`,
          body: changeMetadata.publicSummaryZh || runtime.dj.title,
          deeplink: runtime.dj.deeplink,
          metadata: {
            route: 'dj_update',
            primaryUpdateKind: 'info',
            updateKind: 'info',
            source: 'admin_dj_publish',
            sourceAudience: 'followed_dj_users',
            actorUserId: input.actorUserId,
            djId: runtime.dj.id,
            djName: runtime.dj.title,
            djSummary: runtime.dj.summary,
            djCoverImageURL: runtime.dj.coverImageURL,
            occurredAt: runtime.dj.updatedAt,
            ...changeMetadata,
          },
        },
      });

      dedupeKeys.push(dedupeKey);
      resultsForAudience.push({
        entityId: row.id,
        entityName: row.name,
        targetUserCount: targetUserIds.length,
        publishResult: publishResult.map((item) => ({
          channel: item.channel,
          success: item.success,
          detail: item.detail,
        })),
      });
    }

    publicationResults.push({
      key,
      label: runtimeAudience.label,
      entityCount: runtimeAudience.rows.length,
      targetUserCount: Array.from(new Set(runtimeAudience.rows.flatMap((item) => item.targetUserIds))).length,
      dedupeKeys,
      results: resultsForAudience,
    });
  }

  return {
    success: true,
    kind: 'dj_release',
    entity: {
      id: runtime.dj.id,
      title: runtime.dj.title,
      summary: runtime.dj.summary,
      coverImageURL: runtime.dj.coverImageURL,
      deeplink: runtime.dj.deeplink,
      occurredAt: runtime.dj.updatedAt,
      startDate: null,
      timeZone: null,
    },
    audiences: publicationResults,
  };
};

const executeAdminBrandPublish = async (input: {
  actorUserId: string;
  brandId: string;
  entityType: string;
  audienceKeys?: AdminBrandAudienceKey[];
  channels: Array<'in_app' | 'apns'>;
  dedupeSalt?: string | null;
}): Promise<AdminPublishExecutionResult | null> => {
  const runtime = await resolveAdminBrandNotificationRuntime(input.brandId, input.entityType);
  if (!runtime) return null;

  const audienceKeys = input.audienceKeys?.length ? input.audienceKeys : ['followed_brand_info'];
  const dedupeSalt = input.dedupeSalt?.trim() || runtime.brand.updatedAt.slice(0, 13);
  const changeMetadata = await fetchLatestEntityChangeNotificationMetadata('brand', runtime.brand.id);
  const publicationResults: AdminPublishExecutionAudienceResult[] = [];

  for (const key of audienceKeys) {
    const runtimeAudience = runtime.audienceRuntime.find((item) => item.key === key);
    if (!runtimeAudience) continue;

    const resultsForAudience: AdminPublishExecutionAudienceResult['results'] = [];
    const dedupeKeys: string[] = [];

    for (const row of runtimeAudience.rows) {
      const targetUserIds = Array.from(new Set(row.targetUserIds.map((item) => item.trim()).filter(Boolean)));
      if (!targetUserIds.length) continue;

      const dedupeKey = `brand-info:${row.entityType}:${row.id}:brand:${runtime.brand.id}:${dedupeSalt}`;
      const publishResult = await notificationCenterService.publish({
        category: 'followed_brand_update',
        targets: targetUserIds.map((userId) => ({ userId })),
        channels: input.channels,
        dedupeKey,
        payload: {
          title: `${row.name} profile updated`,
          body: changeMetadata.publicSummaryZh || runtime.brand.title,
          deeplink: runtime.brand.deeplink,
          metadata: {
            route: 'brand_update',
            primaryUpdateKind: 'info',
            updateKind: 'info',
            source: 'admin_brand_publish',
            sourceAudience: 'followed_brand_users',
            actorUserId: input.actorUserId,
            brandId: runtime.brand.id,
            brandEntityType: runtime.brand.entityType,
            brandName: runtime.brand.title,
            brandSummary: runtime.brand.summary,
            brandCoverImageURL: runtime.brand.coverImageURL,
            occurredAt: runtime.brand.updatedAt,
            ...changeMetadata,
          },
        },
      });

      dedupeKeys.push(dedupeKey);
      resultsForAudience.push({
        entityId: row.id,
        entityName: row.name,
        targetUserCount: targetUserIds.length,
        publishResult: publishResult.map((item) => ({
          channel: item.channel,
          success: item.success,
          detail: item.detail,
        })),
      });
    }

    publicationResults.push({
      key,
      label: runtimeAudience.label,
      entityCount: runtimeAudience.rows.length,
      targetUserCount: Array.from(new Set(runtimeAudience.rows.flatMap((item) => item.targetUserIds))).length,
      dedupeKeys,
      results: resultsForAudience,
    });
  }

  return {
    success: true,
    kind: 'brand_release',
    entity: {
      id: runtime.brand.id,
      title: runtime.brand.title,
      summary: runtime.brand.summary,
      coverImageURL: runtime.brand.coverImageURL,
      deeplink: runtime.brand.deeplink,
      occurredAt: runtime.brand.updatedAt,
      startDate: null,
      timeZone: null,
    },
    audiences: publicationResults,
  };
};

const buildAdminPublishTaskContext = async (
  taskType: AdminPublishTaskType,
  entityId: string,
  entityType: string
): Promise<AdminPublishTaskContext | null> => {
  if (taskType === 'news_release') {
    const context = await buildAdminNewsNotificationContext(entityId);
    if (!context) return null;
    return {
      kind: taskType,
      entity: {
        id: context.article.id,
        title: context.article.title,
        summary: context.article.summary,
        coverImageURL: context.article.coverImageURL,
        deeplink: context.article.deeplink,
        occurredAt: context.article.publishedAt,
        startDate: null,
        timeZone: null,
      },
      audiences: context.audiences,
    };
  }

  if (taskType === 'event_release') {
    const context = await buildAdminEventNotificationContext(entityId);
    if (!context) return null;
    return {
      kind: taskType,
      entity: {
        id: context.event.id,
        title: context.event.title,
        summary: context.event.summary,
        coverImageURL: context.event.coverImageURL,
        deeplink: context.event.deeplink,
        occurredAt: context.event.updatedAt,
        startDate: context.event.startDate,
        timeZone: context.event.timeZone,
      },
      audiences: context.audiences,
    };
  }

  if (taskType === 'dj_release') {
    const context = await buildAdminDJNotificationContext(entityId);
    if (!context) return null;
    return {
      kind: taskType,
      entity: {
        id: context.dj.id,
        title: context.dj.title,
        summary: context.dj.summary,
        coverImageURL: context.dj.coverImageURL,
        deeplink: context.dj.deeplink,
        occurredAt: context.dj.updatedAt,
        startDate: null,
        timeZone: null,
      },
      audiences: context.audiences,
    };
  }

  const context = await buildAdminBrandNotificationContext(entityId, entityType);
  if (!context) return null;
  return {
    kind: taskType,
    entity: {
      id: context.brand.id,
      title: context.brand.title,
      summary: context.brand.summary,
      coverImageURL: context.brand.coverImageURL,
      deeplink: context.brand.deeplink,
      occurredAt: context.brand.updatedAt,
      startDate: null,
      timeZone: null,
    },
    audiences: context.audiences,
  };
};

const normalizeAdminManualAudienceEntities = (value: unknown): AdminManualAudienceEntityInput[] => {
  if (!Array.isArray(value)) return [];
  const deduped = new Map<string, AdminManualAudienceEntityInput>();
  for (const item of value) {
    if (!isRecord(item)) continue;
    const id = readString(item.id);
    if (!id) continue;
    const entityType = readString(item.entityType);
    const key = `${entityType ?? 'unknown'}:${id}`;
    deduped.set(key, {
      id,
      name: readString(item.name),
      entityType,
    });
  }
  return Array.from(deduped.values());
};

const buildAdminManualAudienceSummary = (
  type: AdminManualAudienceType,
  rows: AdminManualAudienceRuntimeRow[]
): AdminManualAudienceSummary => ({
  type,
  label: ADMIN_MANUAL_AUDIENCE_LABELS[type],
  entityCount: rows.length,
  targetUserCount: rows.reduce((sum, row) => sum + row.targetUserIds.length, 0),
  uniqueTargetUserCount: Array.from(new Set(rows.flatMap((row) => row.targetUserIds))).length,
  entities: rows.map((row) => ({
    id: row.id,
    name: row.name,
    entityType: row.entityType ?? null,
    targetUserCount: row.targetUserIds.length,
  })),
});

const resolveAdminManualRelatedEntityContext = async (
  value: unknown
): Promise<AdminManualRelatedEntityContext | null> => {
  if (!isRecord(value)) return null;
  const typeRaw = readString(value.type);
  const id = readString(value.id);
  if (!typeRaw || !id || !isAdminManualRelatedEntityType(typeRaw)) {
    return null;
  }

  if (typeRaw === 'news') {
    const row = await prisma.newsArticle.findUnique({
      where: { id },
      select: {
        id: true,
        title: true,
        summary: true,
        body: true,
        coverImageUrl: true,
      },
    });
    if (!row) return null;
    return {
      type: 'news',
      id: row.id,
      title: row.title.trim() || row.id,
      summary: row.summary.trim() || newsBodyToPlainText(row.body).slice(0, 140) || row.title.trim() || row.id,
      deeplink: `raver://news/${encodeURIComponent(row.id)}`,
      imageUrl: readString(row.coverImageUrl),
    };
  }

  if (typeRaw === 'event') {
    const row = await prisma.event.findUnique({
      where: { id },
      select: {
        id: true,
        name: true,
        description: true,
        coverImageUrl: true,
        lineupImageUrl: true,
      },
    });
    if (!row) return null;
    return {
      type: 'event',
      id: row.id,
      title: row.name.trim() || row.id,
      summary: readString(row.description) ?? row.name.trim() ?? row.id,
      deeplink: `raver://event/${encodeURIComponent(row.id)}`,
      imageUrl: readString(row.coverImageUrl) ?? readString(row.lineupImageUrl),
    };
  }

  if (typeRaw === 'dj') {
    const row = await prisma.dJ.findUnique({
      where: { id },
      select: {
        id: true,
        name: true,
        bio: true,
        avatarUrl: true,
      },
    });
    if (!row) return null;
    return {
      type: 'dj',
      id: row.id,
      title: row.name.trim() || row.id,
      summary: readString(row.bio) ?? row.name.trim() ?? row.id,
      deeplink: `raver://dj/${encodeURIComponent(row.id)}`,
      imageUrl: readString(row.avatarUrl),
    };
  }

  if (typeRaw === 'festival') {
    const row = await prisma.wikiFestival.findUnique({
      where: { id },
      select: {
        id: true,
        name: true,
        introduction: true,
        avatarUrl: true,
        backgroundUrl: true,
      },
    });
    if (!row) return null;
    return {
      type: 'festival',
      id: row.id,
      title: row.name.trim() || row.id,
      summary: readString(row.introduction) ?? row.name.trim() ?? row.id,
      deeplink: `raver://festival/${encodeURIComponent(row.id)}`,
      imageUrl: readString(row.avatarUrl) ?? readString(row.backgroundUrl),
    };
  }

  const row = await prisma.label.findUnique({
    where: { id },
    select: {
      id: true,
      name: true,
      introduction: true,
      avatarUrl: true,
      backgroundUrl: true,
    },
  });
  if (!row) return null;
  return {
    type: 'label',
    id: row.id,
    title: row.name.trim() || row.id,
    summary: readString(row.introduction) ?? row.name.trim() ?? row.id,
    deeplink: `raver://label/${encodeURIComponent(row.id)}`,
    imageUrl: readString(row.avatarUrl) ?? readString(row.backgroundUrl),
  };
};

const buildAdminManualContentContext = async (value: unknown): Promise<AdminManualContentContext> => {
  const row = isRecord(value) ? value : {};
  const relatedEntity = await resolveAdminManualRelatedEntityContext(row.relatedEntity);
  const headline = readString(row.headline) ?? relatedEntity?.title ?? '';
  const summary = readString(row.summary) ?? relatedEntity?.summary ?? '';
  const deeplink = readString(row.deeplink) ?? relatedEntity?.deeplink ?? null;
  const imageUrl = readString(row.imageUrl) ?? relatedEntity?.imageUrl ?? null;

  if (!headline || !summary) {
    throw new Error('Manual publish content requires headline and summary, or a valid related entity');
  }

  return {
    headline,
    summary,
    deeplink,
    imageUrl,
    relatedEntity,
  };
};

const buildAdminManualAudienceRuntime = async (
  type: AdminManualAudienceType,
  entities: AdminManualAudienceEntityInput[]
): Promise<AdminManualAudienceRuntime> => {
  if (entities.length === 0) {
    return {
      type,
      label: ADMIN_MANUAL_AUDIENCE_LABELS[type],
      rows: [],
    };
  }

  if (type === 'direct_users') {
    const ids = Array.from(new Set(entities.map((item) => item.id)));
    const rows = await prisma.user.findMany({
      where: {
        id: { in: ids },
        isActive: true,
      },
      select: {
        id: true,
        username: true,
        displayName: true,
      },
    });
    return {
      type,
      label: ADMIN_MANUAL_AUDIENCE_LABELS[type],
      rows: rows.map((row) => ({
        id: row.id,
        name: readString(row.displayName) ?? row.username.trim() ?? row.id,
        entityType: 'user',
        targetUserIds: [row.id],
      })),
    };
  }

  if (type === 'followed_dj') {
    const ids = Array.from(new Set(entities.map((item) => item.id)));
    const [djs, follows] = await Promise.all([
      prisma.dJ.findMany({
        where: { id: { in: ids } },
        select: { id: true, name: true },
      }),
      prisma.userEntityFollow.findMany({
        where: {
          relationType: USER_ENTITY_RELATION_FOLLOW,
          targetType: USER_ENTITY_TARGET_DJ,
          targetId: { in: ids },
        },
        select: { targetId: true, userId: true },
      }),
    ]);

    const userIdsByDjId = new Map<string, string[]>();
    for (const follow of follows) {
      const list = userIdsByDjId.get(follow.targetId) ?? [];
      list.push(follow.userId);
      userIdsByDjId.set(follow.targetId, list);
    }

    return {
      type,
      label: ADMIN_MANUAL_AUDIENCE_LABELS[type],
      rows: djs.map((row) => ({
        id: row.id,
        name: row.name.trim() || row.id,
        entityType: 'dj',
        targetUserIds: Array.from(new Set((userIdsByDjId.get(row.id) ?? []).map((item) => item.trim()).filter(Boolean))),
      })),
    };
  }

  if (type === 'favorited_event') {
    const ids = Array.from(new Set(entities.map((item) => item.id)));
    const [events, favorites] = await Promise.all([
      prisma.event.findMany({
        where: { id: { in: ids } },
        select: { id: true, name: true },
      }),
      prisma.userEntityFollow.findMany({
        where: {
          relationType: USER_ENTITY_RELATION_FAVORITE,
          targetType: USER_ENTITY_TARGET_EVENT,
          targetId: { in: ids },
        },
        select: { targetId: true, userId: true },
      }),
    ]);

    const userIdsByEventId = new Map<string, string[]>();
    for (const favorite of favorites) {
      const list = userIdsByEventId.get(favorite.targetId) ?? [];
      list.push(favorite.userId);
      userIdsByEventId.set(favorite.targetId, list);
    }

    return {
      type,
      label: ADMIN_MANUAL_AUDIENCE_LABELS[type],
      rows: events.map((row) => ({
        id: row.id,
        name: row.name.trim() || row.id,
        entityType: 'event',
        targetUserIds: Array.from(new Set((userIdsByEventId.get(row.id) ?? []).map((item) => item.trim()).filter(Boolean))),
      })),
    };
  }

  const brandIds = Array.from(new Set(entities.map((item) => item.id)));
  const [festivalBrands, labelBrands, subscriptions] = await Promise.all([
    prisma.wikiFestival.findMany({
      where: { id: { in: brandIds } },
      select: { id: true, name: true },
    }),
    prisma.label.findMany({
      where: { id: { in: brandIds } },
      select: { id: true, name: true },
    }),
    notificationCenterService.fetchFollowedBrandUpdateSubscriptions(),
  ]);

  const brandNameById = new Map<string, { name: string; entityType: string }>();
  for (const row of festivalBrands) {
    brandNameById.set(row.id, { name: row.name.trim() || row.id, entityType: 'festival' });
  }
  for (const row of labelBrands) {
    if (!brandNameById.has(row.id)) {
      brandNameById.set(row.id, { name: row.name.trim() || row.id, entityType: 'label' });
    }
  }

  const rows: AdminManualAudienceRuntimeRow[] = [];
  for (const brandId of brandIds) {
    const info = brandNameById.get(brandId);
    if (!info) continue;
    rows.push({
      id: brandId,
      name: info.name,
      entityType: info.entityType,
      targetUserIds: Array.from(
        new Set(
          subscriptions
            .filter((row) => row.preference.enabled && row.preference.watchedBrandIds.includes(brandId))
            .map((row) => row.userId.trim())
            .filter(Boolean)
        )
      ),
    });
  }

  return {
    type,
    label: ADMIN_MANUAL_AUDIENCE_LABELS[type],
    rows,
  };
};

const buildAdminManualNotificationPreview = async (body: unknown): Promise<AdminManualNotificationPreview> => {
  const payload = isRecord(body) ? body : {};
  const content = await buildAdminManualContentContext(payload.content);
  const audiencesInput = Array.isArray(payload.audiences) ? payload.audiences : [];

  const runtimes = await Promise.all(
    audiencesInput
      .filter(isRecord)
      .map(async (item) => {
        const type = readString(item.type);
        if (!type || !isAdminManualAudienceType(type)) return null;
        return buildAdminManualAudienceRuntime(type, normalizeAdminManualAudienceEntities(item.entities));
      })
  );

  const resolvedRuntimes = runtimes.filter((item): item is AdminManualAudienceRuntime => item !== null);
  const audiences = resolvedRuntimes.map((runtime) => buildAdminManualAudienceSummary(runtime.type, runtime.rows));
  const allTargetUserIds = Array.from(new Set(resolvedRuntimes.flatMap((runtime) => runtime.rows.flatMap((row) => row.targetUserIds))));

  return {
    content,
    audiences,
    totals: {
      selectedEntityCount: resolvedRuntimes.reduce((sum, runtime) => sum + runtime.rows.length, 0),
      totalTargetAssignments: resolvedRuntimes.reduce(
        (sum, runtime) => sum + runtime.rows.reduce((inner, row) => inner + row.targetUserIds.length, 0),
        0
      ),
      totalUniqueTargetUsers: allTargetUserIds.length,
    },
  };
};

const executeAdminManualNotificationPublish = async (input: {
  actorUserId: string;
  body: unknown;
  channels: Array<'in_app' | 'apns'>;
  dedupeSalt?: string | null;
}): Promise<AdminManualNotificationExecutionResult> => {
  const payload = isRecord(input.body) ? input.body : {};
  const preview = await buildAdminManualNotificationPreview(payload);
  const runtimesInput = Array.isArray(payload.audiences) ? payload.audiences : [];

  const runtimes = await Promise.all(
    runtimesInput
      .filter(isRecord)
      .map(async (item) => {
        const type = readString(item.type);
        if (!type || !isAdminManualAudienceType(type)) return null;
        return buildAdminManualAudienceRuntime(type, normalizeAdminManualAudienceEntities(item.entities));
      })
  );
  const resolvedRuntimes = runtimes.filter((item): item is AdminManualAudienceRuntime => item !== null);
  const dedupeSalt = input.dedupeSalt?.trim() || new Date().toISOString().slice(0, 13);
  const primaryUpdateKind =
    preview.content.relatedEntity?.type === 'news'
      ? 'news'
      : preview.content.relatedEntity?.type === 'event'
        ? 'event'
        : 'manual';

  const audiences: AdminManualNotificationExecutionResult['audiences'] = [];

  for (const runtime of resolvedRuntimes) {
    const results: AdminManualNotificationExecutionResult['audiences'][number]['results'] = [];
    const dedupeKeys: string[] = [];

    for (const row of runtime.rows) {
      const targetUserIds = Array.from(new Set(row.targetUserIds.map((item) => item.trim()).filter(Boolean)));
      if (targetUserIds.length === 0) continue;

      let category: 'major_news' | 'followed_dj_update' | 'followed_brand_update' = 'major_news';
      let route = 'manual_broadcast';
      const metadata: Record<string, unknown> = {
        source: 'admin_manual_publish',
        actorUserId: input.actorUserId,
        manualAudienceType: runtime.type,
        relatedEntityType: preview.content.relatedEntity?.type ?? null,
        relatedEntityId: preview.content.relatedEntity?.id ?? null,
        primaryUpdateKind,
        updateKind: primaryUpdateKind,
        imageUrl: preview.content.imageUrl,
      };

      if (runtime.type === 'followed_dj') {
        category = 'followed_dj_update';
        route = 'dj_update';
        metadata.djId = row.id;
        metadata.djName = row.name;
      } else if (runtime.type === 'followed_brand') {
        category = 'followed_brand_update';
        route = 'brand_update';
        metadata.brandId = row.id;
        metadata.brandName = row.name;
      } else if (runtime.type === 'favorited_event') {
        category = 'major_news';
        route = 'event_update';
        metadata.eventId = row.id;
        metadata.eventName = row.name;
      } else {
        metadata.audienceEntityId = row.id;
        metadata.audienceEntityName = row.name;
      }

      if (preview.content.relatedEntity?.type === 'news') {
        metadata.newsId = preview.content.relatedEntity.id;
        metadata.newsTitle = preview.content.relatedEntity.title;
        metadata.newsSummary = preview.content.relatedEntity.summary;
      } else if (preview.content.relatedEntity?.type === 'event') {
        metadata.eventId = metadata.eventId ?? preview.content.relatedEntity.id;
        metadata.eventName = metadata.eventName ?? preview.content.relatedEntity.title;
        metadata.eventSummary = preview.content.relatedEntity.summary;
      }

      metadata.route = route;
      const dedupeKey = `manual:${runtime.type}:${row.entityType ?? 'entity'}:${row.id}:${dedupeSalt}`;
      const publishResult = await notificationCenterService.publish({
        category,
        targets: targetUserIds.map((userId) => ({ userId })),
        channels: input.channels,
        dedupeKey,
        payload: {
          title: preview.content.headline,
          body: preview.content.summary,
          deeplink: preview.content.deeplink,
          metadata,
        },
      });

      dedupeKeys.push(dedupeKey);
      results.push({
        entityId: row.id,
        entityName: row.name,
        entityType: row.entityType ?? null,
        targetUserCount: targetUserIds.length,
        publishResult: publishResult.map((item) => ({
          channel: item.channel,
          success: item.success,
          detail: item.detail,
        })),
      });
    }

    audiences.push({
      ...buildAdminManualAudienceSummary(runtime.type, runtime.rows),
      dedupeKeys,
      results,
    });
  }

  return {
    success: true,
    content: preview.content,
    audiences,
    totals: preview.totals,
  };
};

type FollowedEventInboxProjection = {
  id: string;
  type: string;
  eventId: string;
  eventName: string;
  newsId: string;
  newsTitle: string;
  newsSummary: string | null;
  newsCoverImageURL: string | null;
  isRead: boolean;
  occurredAt: Date;
};

type FollowedDJInboxProjection = {
  id: string;
  type: string;
  djId: string;
  djName: string;
  newsId: string;
  newsTitle: string;
  newsSummary: string | null;
  newsCoverImageURL: string | null;
  isRead: boolean;
  occurredAt: Date;
};

type FollowedBrandInboxProjection = {
  id: string;
  type: string;
  brandId: string;
  brandName: string;
  newsId: string;
  newsTitle: string;
  newsSummary: string | null;
  newsCoverImageURL: string | null;
  isRead: boolean;
  occurredAt: Date;
};

type ContentReviewInboxProjection = {
  id: string;
  submissionId: string;
  entityType: string;
  status: string;
  statusLabel: string | null;
  title: string;
  body: string;
  reason: string | null;
  createdEntityId: string | null;
  isRead: boolean;
  occurredAt: Date;
};

const CONTENT_REVIEW_SOURCE = 'content_submission_review';

const mapContentReviewInboxItem = (
  row: {
    id: string;
    type: string;
    title: string;
    body: string;
    deeplink: string | null;
    metadata: Prisma.JsonValue | null;
    isRead: boolean;
    createdAt: Date;
  }
): ContentReviewInboxProjection | null => {
  const metadata = isRecord(row.metadata) ? row.metadata : {};
  if (readString(metadata.source) !== CONTENT_REVIEW_SOURCE) {
    return null;
  }

  const submissionId = readString(metadata.submissionId);
  const entityType = readString(metadata.entityType) ?? 'content';
  const status = readString(metadata.status);
  if (!submissionId || !status || !['processing', 'reviewing', 'approved', 'rejected', 'failed'].includes(status)) {
    return null;
  }

  return {
    id: row.id,
    submissionId,
    entityType,
    status,
    statusLabel: readString(metadata.statusLabel),
    title: row.title,
    body: row.body,
    reason: readString(metadata.reason),
    createdEntityId: readString(metadata.createdEntityId),
    isRead: row.isRead,
    occurredAt: row.createdAt,
  };
};

const mapFollowedEventInboxItem = (
  row: {
    id: string;
    type: string;
    title: string;
    body: string;
    deeplink: string | null;
    metadata: Prisma.JsonValue | null;
    isRead: boolean;
    createdAt: Date;
  }
): FollowedEventInboxProjection | null => {
  const metadata = isRecord(row.metadata) ? row.metadata : {};
  const route =
    readString(metadata.route) ??
    readString(metadata.type) ??
    readString(metadata.category) ??
    null;
  const normalizedRoute = route?.toLowerCase() ?? '';
  if (normalizedRoute && normalizedRoute !== 'event_update') {
    return null;
  }

  const updateKind =
    readString(metadata.primaryUpdateKind) ??
    readString(metadata.updateKind) ??
    null;
  const normalizedUpdateKind = updateKind?.toLowerCase() ?? 'news';
  if (normalizedUpdateKind !== 'news' && normalizedUpdateKind !== 'event') {
    return null;
  }

  const eventId = readString(metadata.eventId);
  const newsId = readString(metadata.newsId) ?? (normalizedUpdateKind === 'event' ? eventId : null);

  if (!eventId || !newsId) {
    return null;
  }

  const occurredAt =
    readDate(metadata.occurredAt) ??
    readDate(metadata.createdAt) ??
    row.createdAt;

  return {
    id: row.id,
    type: normalizedUpdateKind,
    eventId,
    eventName:
      readString(metadata.eventName) ??
      readString(metadata.title) ??
      row.title,
    newsId,
    newsTitle:
      readString(metadata.newsTitle) ??
      readString(metadata.eventName) ??
      readString(metadata.title) ??
      row.title,
    newsSummary:
      readString(metadata.newsSummary) ??
      readString(metadata.eventSummary) ??
      readString(metadata.summary) ??
      readString(metadata.body) ??
      readString(row.body),
    newsCoverImageURL:
      readString(metadata.newsCoverImageURL) ??
      readString(metadata.newsCoverImageUrl) ??
      readString(metadata.coverImageURL) ??
      readString(metadata.coverImageUrl),
    isRead: row.isRead,
    occurredAt,
  };
};

const mapFollowedDJInboxItem = (
  row: {
    id: string;
    type: string;
    title: string;
    body: string;
    deeplink: string | null;
    metadata: Prisma.JsonValue | null;
    isRead: boolean;
    createdAt: Date;
  }
): FollowedDJInboxProjection | null => {
  const metadata = isRecord(row.metadata) ? row.metadata : {};
  const route =
    readString(metadata.route) ??
    readString(metadata.type) ??
    readString(metadata.category) ??
    null;
  const normalizedRoute = route?.toLowerCase() ?? '';
  if (normalizedRoute && normalizedRoute !== 'dj_update') {
    return null;
  }

  const updateKind =
    readString(metadata.primaryUpdateKind) ??
    readString(metadata.updateKind) ??
    null;
  const normalizedUpdateKind = updateKind?.toLowerCase() ?? 'news';
  if (normalizedUpdateKind !== 'news' && normalizedUpdateKind !== 'event') {
    return null;
  }

  const djId = readString(metadata.djId);
  const eventId = readString(metadata.eventId);
  const newsId = readString(metadata.newsId) ?? (normalizedUpdateKind === 'event' ? eventId : null);

  if (!djId || !newsId) {
    return null;
  }

  const occurredAt =
    readDate(metadata.occurredAt) ??
    readDate(metadata.createdAt) ??
    row.createdAt;

  return {
    id: row.id,
    type: normalizedUpdateKind,
    djId,
    djName:
      readString(metadata.djName) ??
      readString(metadata.title) ??
      row.title,
    newsId,
    newsTitle:
      readString(metadata.newsTitle) ??
      readString(metadata.eventName) ??
      readString(metadata.title) ??
      row.title,
    newsSummary:
      readString(metadata.newsSummary) ??
      readString(metadata.eventSummary) ??
      readString(metadata.summary) ??
      readString(metadata.body) ??
      readString(row.body),
    newsCoverImageURL:
      readString(metadata.newsCoverImageURL) ??
      readString(metadata.newsCoverImageUrl) ??
      readString(metadata.coverImageURL) ??
      readString(metadata.coverImageUrl),
    isRead: row.isRead,
    occurredAt,
  };
};

const mapFollowedBrandInboxItem = (
  row: {
    id: string;
    type: string;
    title: string;
    body: string;
    deeplink: string | null;
    metadata: Prisma.JsonValue | null;
    isRead: boolean;
    createdAt: Date;
  }
): FollowedBrandInboxProjection | null => {
  const metadata = isRecord(row.metadata) ? row.metadata : {};
  const route =
    readString(metadata.route) ??
    readString(metadata.type) ??
    readString(metadata.category) ??
    null;
  const normalizedRoute = route?.toLowerCase() ?? '';
  if (normalizedRoute && normalizedRoute !== 'brand_update') {
    return null;
  }

  const updateKind =
    readString(metadata.primaryUpdateKind) ??
    readString(metadata.updateKind) ??
    null;
  const normalizedUpdateKind = updateKind?.toLowerCase() ?? 'news';
  if (normalizedUpdateKind !== 'news' && normalizedUpdateKind !== 'event') {
    return null;
  }

  const brandId = readString(metadata.brandId);
  const eventId = readString(metadata.eventId);
  const newsId = readString(metadata.newsId) ?? (normalizedUpdateKind === 'event' ? eventId : null);

  if (!brandId || !newsId) {
    return null;
  }

  const occurredAt =
    readDate(metadata.occurredAt) ??
    readDate(metadata.createdAt) ??
    row.createdAt;

  return {
    id: row.id,
    type: normalizedUpdateKind,
    brandId,
    brandName:
      readString(metadata.brandName) ??
      readString(metadata.title) ??
      row.title,
    newsId,
    newsTitle:
      readString(metadata.newsTitle) ??
      readString(metadata.eventName) ??
      readString(metadata.title) ??
      row.title,
    newsSummary:
      readString(metadata.newsSummary) ??
      readString(metadata.eventSummary) ??
      readString(metadata.summary) ??
      readString(metadata.body) ??
      readString(row.body),
    newsCoverImageURL:
      readString(metadata.newsCoverImageURL) ??
      readString(metadata.newsCoverImageUrl) ??
      readString(metadata.coverImageURL) ??
      readString(metadata.coverImageUrl),
    isRead: row.isRead,
    occurredAt,
  };
};

const fetchCommunityUnreadBreakdown = async (
  userId: string
): Promise<{ follows: number; likes: number; comments: number; squadInvites: number; total: number }> => {
  const rows = await prisma.$queryRaw<Array<{ source: string | null; count: bigint | number }>>`
    SELECT
      metadata ->> 'source' AS source,
      COUNT(*)::bigint AS count
    FROM notification_inbox
    WHERE user_id = ${userId}
      AND is_read = false
      AND type = 'community_interaction'
    GROUP BY metadata ->> 'source'
  `;

  const bySource = new Map<string, number>();
  for (const row of rows) {
    const source = typeof row.source === 'string' ? row.source.trim() : '';
    if (!source) continue;
    bySource.set(source, toPositiveSafeInteger(row.count));
  }

  const follows = LEGACY_NOTIFICATION_TYPE_SOURCES.follow.reduce((sum, source) => sum + (bySource.get(source) ?? 0), 0);
  const likes = LEGACY_NOTIFICATION_TYPE_SOURCES.like.reduce((sum, source) => sum + (bySource.get(source) ?? 0), 0);
  const comments = LEGACY_NOTIFICATION_TYPE_SOURCES.comment.reduce((sum, source) => sum + (bySource.get(source) ?? 0), 0);
  const squadInvites = LEGACY_NOTIFICATION_TYPE_SOURCES.squad_invite.reduce(
    (sum, source) => sum + (bySource.get(source) ?? 0),
    0
  );

  return {
    follows,
    likes,
    comments,
    squadInvites,
    total: follows + likes + comments + squadInvites,
  };
};

router.post('/push-tokens', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const body = (req.body ?? {}) as {
      deviceId?: unknown;
      platform?: unknown;
      pushToken?: unknown;
      appVersion?: unknown;
      locale?: unknown;
    };

    const deviceId = typeof body.deviceId === 'string' ? body.deviceId.trim() : '';
    const platform = typeof body.platform === 'string' ? body.platform.trim() : '';
    const pushToken = typeof body.pushToken === 'string' ? body.pushToken.trim() : '';
    if (!deviceId || !platform || !pushToken) {
      res.status(400).json({ error: 'deviceId/platform/pushToken are required' });
      return;
    }

    await notificationCenterService.registerDevicePushToken({
      userId,
      deviceId,
      platform,
      pushToken,
      appVersion: typeof body.appVersion === 'string' ? body.appVersion.trim() : undefined,
      locale: typeof body.locale === 'string' ? body.locale.trim() : undefined,
    });

    res.json({ success: true });
  } catch (error) {
    console.error('Register device push token error:', error);
    res.status(500).json({ error: 'Failed to register device token' });
  }
});

router.delete('/push-tokens', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const body = (req.body ?? {}) as {
      deviceId?: unknown;
      platform?: unknown;
    };
    const deviceId = typeof body.deviceId === 'string' ? body.deviceId.trim() : '';
    const platform = typeof body.platform === 'string' ? body.platform.trim() : '';
    if (!deviceId || !platform) {
      res.status(400).json({ error: 'deviceId/platform are required' });
      return;
    }

    const count = await notificationCenterService.deactivateDevicePushToken(userId, deviceId, platform);
    res.json({ success: true, updated: count });
  } catch (error) {
    console.error('Deactivate device push token error:', error);
    res.status(500).json({ error: 'Failed to deactivate device token' });
  }
});

router.get('/inbox', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const limit = parseLimit((req.query as Request['query']).limit, 20, 100);
    const items = await notificationCenterService.fetchInbox(userId, limit);
    res.json({ success: true, items });
  } catch (error) {
    console.error('Fetch notification inbox error:', error);
    res.status(500).json({ error: 'Failed to fetch notification inbox' });
  }
});

router.get('/inbox/unread-count', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const [total, legacy] = await Promise.all([
      notificationCenterService.fetchInboxUnreadCount(userId),
      fetchCommunityUnreadBreakdown(userId),
    ]);
    res.json({
      success: true,
      total,
      follows: legacy.follows,
      likes: legacy.likes,
      comments: legacy.comments,
      squadInvites: legacy.squadInvites,
      communityTotal: legacy.total,
    });
  } catch (error) {
    console.error('Fetch notification inbox unread count error:', error);
    res.status(500).json({ error: 'Failed to fetch notification unread count' });
  }
});

router.post('/inbox/read', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const body = (req.body ?? {}) as {
      inboxIds?: unknown;
      inboxId?: unknown;
      notificationType?: unknown;
    };
    const inboxIds: string[] = [];
    if (typeof body.inboxId === 'string') {
      inboxIds.push(body.inboxId);
    }
    if (Array.isArray(body.inboxIds)) {
      for (const item of body.inboxIds) {
        if (typeof item === 'string') {
          inboxIds.push(item);
        }
      }
    }

    const notificationType = parseLegacyNotificationType(body.notificationType);
    if (inboxIds.length === 0 && !notificationType) {
      res.status(400).json({ error: 'inboxId/inboxIds or notificationType is required' });
      return;
    }

    let updatedByInboxIds = 0;
    if (inboxIds.length > 0) {
      updatedByInboxIds = await notificationCenterService.markInboxRead(userId, inboxIds);
    }

    let updatedByType = 0;
    if (notificationType) {
      const sources = LEGACY_NOTIFICATION_TYPE_SOURCES[notificationType];
      if (sources.length > 0) {
        updatedByType = await prisma.$executeRaw`
          UPDATE notification_inbox
          SET is_read = TRUE,
              read_at = NOW(),
              updated_at = NOW()
          WHERE user_id = ${userId}
            AND is_read = FALSE
            AND type = 'community_interaction'
            AND (metadata ->> 'source') IN (${Prisma.join(sources)})
        `;
      }
    }

    res.json({ success: true, updated: updatedByInboxIds + toPositiveSafeInteger(updatedByType) });
  } catch (error) {
    console.error('Mark notification inbox read error:', error);
    res.status(500).json({ error: 'Failed to mark notification read' });
  }
});

router.get('/followed-events/summary', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const rows = await prisma.notificationInboxItem.findMany({
      where: {
        userId,
      },
      select: {
        id: true,
        type: true,
        title: true,
        body: true,
        deeplink: true,
        metadata: true,
        isRead: true,
        createdAt: true,
      },
      orderBy: {
        createdAt: 'desc',
      },
      take: 100,
    });

    const items = rows
      .map(mapFollowedEventInboxItem)
      .filter((item): item is FollowedEventInboxProjection => Boolean(item));

    const latest = items[0] ?? null;
    const unreadCount = items.reduce((sum, item) => sum + (item.isRead ? 0 : 1), 0);

    res.json({
      unreadCount,
      latestItemPreview: latest?.newsSummary ?? latest?.newsTitle ?? null,
      latestOccurredAt: latest?.occurredAt ?? null,
    });
  } catch (error) {
    console.error('Fetch followed events summary error:', error);
    res.status(500).json({ error: 'Failed to fetch followed events summary' });
  }
});

router.get('/followed-events/items', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const limit = parseLimit((req.query as Request['query']).limit, 20, 100);
    const rows = await prisma.notificationInboxItem.findMany({
      where: {
        userId,
      },
      select: {
        id: true,
        type: true,
        title: true,
        body: true,
        deeplink: true,
        metadata: true,
        isRead: true,
        createdAt: true,
      },
      orderBy: {
        createdAt: 'desc',
      },
      take: Math.max(limit * 3, 100),
    });

    const items = rows
      .map(mapFollowedEventInboxItem)
      .filter((item): item is FollowedEventInboxProjection => Boolean(item))
      .slice(0, limit);

    res.json({ items });
  } catch (error) {
    console.error('Fetch followed events inbox items error:', error);
    res.status(500).json({ error: 'Failed to fetch followed event notifications' });
  }
});

router.post('/followed-events/read', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const body = (req.body ?? {}) as {
      itemId?: unknown;
    };
    const itemId = readString(body.itemId);
    if (!itemId) {
      res.status(400).json({ error: 'itemId is required' });
      return;
    }

    const updated = await prisma.notificationInboxItem.updateMany({
      where: {
        id: itemId,
        userId,
        isRead: false,
      },
      data: {
        isRead: true,
        readAt: new Date(),
      },
    });

    res.json({ success: true, updated: updated.count });
  } catch (error) {
    console.error('Mark followed event notification read error:', error);
    res.status(500).json({ error: 'Failed to mark followed event notification read' });
  }
});

router.get('/content-reviews/summary', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const rows = await prisma.notificationInboxItem.findMany({
      where: {
        userId,
        type: 'content_review',
      },
      select: {
        id: true,
        type: true,
        title: true,
        body: true,
        deeplink: true,
        metadata: true,
        isRead: true,
        createdAt: true,
      },
      orderBy: {
        createdAt: 'desc',
      },
      take: 100,
    });

    const items = rows
      .map(mapContentReviewInboxItem)
      .filter((item): item is ContentReviewInboxProjection => Boolean(item));
    const latest = items[0] ?? null;

    res.json({
      unreadCount: items.reduce((sum, item) => sum + (item.isRead ? 0 : 1), 0),
      latestItemPreview: latest?.body ?? latest?.title ?? null,
      latestOccurredAt: latest?.occurredAt ?? null,
    });
  } catch (error) {
    console.error('Fetch content review summary error:', error);
    res.status(500).json({ error: 'Failed to fetch content review summary' });
  }
});

router.get('/content-reviews/items', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const limit = parseLimit((req.query as Request['query']).limit, 20, 100);
    const rows = await prisma.notificationInboxItem.findMany({
      where: {
        userId,
        type: 'content_review',
      },
      select: {
        id: true,
        type: true,
        title: true,
        body: true,
        deeplink: true,
        metadata: true,
        isRead: true,
        createdAt: true,
      },
      orderBy: {
        createdAt: 'desc',
      },
      take: Math.max(limit * 3, 100),
    });

    const items = rows
      .map(mapContentReviewInboxItem)
      .filter((item): item is ContentReviewInboxProjection => Boolean(item))
      .slice(0, limit);

    res.json({ items });
  } catch (error) {
    console.error('Fetch content review inbox items error:', error);
    res.status(500).json({ error: 'Failed to fetch content review notifications' });
  }
});

router.post('/content-reviews/read', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const body = (req.body ?? {}) as {
      itemId?: unknown;
    };
    const itemId = readString(body.itemId);
    if (!itemId) {
      res.status(400).json({ error: 'itemId is required' });
      return;
    }

    const updated = await prisma.notificationInboxItem.updateMany({
      where: {
        id: itemId,
        userId,
        isRead: false,
      },
      data: {
        isRead: true,
        readAt: new Date(),
      },
    });

    res.json({ success: true, updated: updated.count });
  } catch (error) {
    console.error('Mark content review notification read error:', error);
    res.status(500).json({ error: 'Failed to mark content review notification read' });
  }
});

router.get('/followed-djs/summary', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const rows = await prisma.notificationInboxItem.findMany({
      where: {
        userId,
      },
      select: {
        id: true,
        type: true,
        title: true,
        body: true,
        deeplink: true,
        metadata: true,
        isRead: true,
        createdAt: true,
      },
      orderBy: {
        createdAt: 'desc',
      },
      take: 100,
    });

    const items = rows
      .map(mapFollowedDJInboxItem)
      .filter((item): item is FollowedDJInboxProjection => Boolean(item));

    const latest = items[0] ?? null;
    const unreadCount = items.reduce((sum, item) => sum + (item.isRead ? 0 : 1), 0);

    res.json({
      unreadCount,
      latestItemPreview: latest?.newsSummary ?? latest?.newsTitle ?? null,
      latestOccurredAt: latest?.occurredAt ?? null,
    });
  } catch (error) {
    console.error('Fetch followed DJs summary error:', error);
    res.status(500).json({ error: 'Failed to fetch followed DJs summary' });
  }
});

router.get('/followed-djs/items', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const limit = parseLimit((req.query as Request['query']).limit, 20, 100);
    const rows = await prisma.notificationInboxItem.findMany({
      where: {
        userId,
      },
      select: {
        id: true,
        type: true,
        title: true,
        body: true,
        deeplink: true,
        metadata: true,
        isRead: true,
        createdAt: true,
      },
      orderBy: {
        createdAt: 'desc',
      },
      take: Math.max(limit * 3, 100),
    });

    const items = rows
      .map(mapFollowedDJInboxItem)
      .filter((item): item is FollowedDJInboxProjection => Boolean(item))
      .slice(0, limit);

    res.json({ items });
  } catch (error) {
    console.error('Fetch followed DJs inbox items error:', error);
    res.status(500).json({ error: 'Failed to fetch followed DJ notifications' });
  }
});

router.post('/followed-djs/read', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const body = (req.body ?? {}) as {
      itemId?: unknown;
    };
    const itemId = readString(body.itemId);
    if (!itemId) {
      res.status(400).json({ error: 'itemId is required' });
      return;
    }

    const updated = await prisma.notificationInboxItem.updateMany({
      where: {
        id: itemId,
        userId,
        isRead: false,
      },
      data: {
        isRead: true,
        readAt: new Date(),
      },
    });

    res.json({ success: true, updated: updated.count });
  } catch (error) {
    console.error('Mark followed DJ notification read error:', error);
    res.status(500).json({ error: 'Failed to mark followed DJ notification read' });
  }
});

router.get('/followed-brands/summary', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const rows = await prisma.notificationInboxItem.findMany({
      where: {
        userId,
      },
      select: {
        id: true,
        type: true,
        title: true,
        body: true,
        deeplink: true,
        metadata: true,
        isRead: true,
        createdAt: true,
      },
      orderBy: {
        createdAt: 'desc',
      },
      take: 100,
    });

    const items = rows
      .map(mapFollowedBrandInboxItem)
      .filter((item): item is FollowedBrandInboxProjection => Boolean(item));

    const latest = items[0] ?? null;
    const unreadCount = items.reduce((sum, item) => sum + (item.isRead ? 0 : 1), 0);

    res.json({
      unreadCount,
      latestItemPreview: latest?.newsSummary ?? latest?.newsTitle ?? null,
      latestOccurredAt: latest?.occurredAt ?? null,
    });
  } catch (error) {
    console.error('Fetch followed brands summary error:', error);
    res.status(500).json({ error: 'Failed to fetch followed brands summary' });
  }
});

router.get('/followed-brands/items', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const limit = parseLimit((req.query as Request['query']).limit, 20, 100);
    const rows = await prisma.notificationInboxItem.findMany({
      where: {
        userId,
      },
      select: {
        id: true,
        type: true,
        title: true,
        body: true,
        deeplink: true,
        metadata: true,
        isRead: true,
        createdAt: true,
      },
      orderBy: {
        createdAt: 'desc',
      },
      take: Math.max(limit * 3, 100),
    });

    const items = rows
      .map(mapFollowedBrandInboxItem)
      .filter((item): item is FollowedBrandInboxProjection => Boolean(item))
      .slice(0, limit);

    res.json({ items });
  } catch (error) {
    console.error('Fetch followed brands inbox items error:', error);
    res.status(500).json({ error: 'Failed to fetch followed brand notifications' });
  }
});

router.post('/followed-brands/read', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const body = (req.body ?? {}) as {
      itemId?: unknown;
    };
    const itemId = readString(body.itemId);
    if (!itemId) {
      res.status(400).json({ error: 'itemId is required' });
      return;
    }

    const updated = await prisma.notificationInboxItem.updateMany({
      where: {
        id: itemId,
        userId,
        isRead: false,
      },
      data: {
        isRead: true,
        readAt: new Date(),
      },
    });

    res.json({ success: true, updated: updated.count });
  } catch (error) {
    console.error('Mark followed brand notification read error:', error);
    res.status(500).json({ error: 'Failed to mark followed brand notification read' });
  }
});

router.get('/preferences/categories', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const preferences = await notificationCenterService.fetchCategoryPreferences(userId);
    res.json({ success: true, preferences });
  } catch (error) {
    console.error('Fetch notification category preferences error:', error);
    res.status(500).json({ error: 'Failed to fetch notification category preferences' });
  }
});

router.put('/preferences/categories', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const body = (req.body ?? {}) as {
      preferences?: unknown;
    };
    if (!Array.isArray(body.preferences)) {
      res.status(400).json({ error: 'preferences is required' });
      return;
    }

    const preferences = await notificationCenterService.updateCategoryPreferences(userId, body.preferences);
    res.json({ success: true, preferences });
  } catch (error) {
    console.error('Update notification category preferences error:', error);
    res.status(500).json({
      error: error instanceof Error ? error.message : 'Failed to update notification category preferences',
    });
  }
});

router.get('/preferences/event-countdown', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const preference = await notificationCenterService.fetchEventCountdownPreference(userId);
    res.json({ success: true, preference });
  } catch (error) {
    console.error('Fetch event countdown preference error:', error);
    res.status(500).json({ error: 'Failed to fetch event countdown preference' });
  }
});

router.put('/preferences/event-countdown', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const body = (req.body ?? {}) as {
      enabled?: unknown;
      daysBeforeStart?: unknown;
      reminderHours?: unknown;
      timezone?: unknown;
      channels?: unknown;
    };

    const preference = await notificationCenterService.updateEventCountdownPreference(userId, {
      enabled: typeof body.enabled === 'boolean' ? body.enabled : undefined,
      daysBeforeStart: typeof body.daysBeforeStart === 'number' ? body.daysBeforeStart : undefined,
      reminderHours: Array.isArray(body.reminderHours) ? body.reminderHours : undefined,
      timezone: typeof body.timezone === 'string' ? body.timezone.trim() : undefined,
      channels: Array.isArray(body.channels) ? body.channels : undefined,
    });
    res.json({ success: true, preference });
  } catch (error) {
    console.error('Update event countdown preference error:', error);
    res.status(500).json({ error: error instanceof Error ? error.message : 'Failed to update event countdown preference' });
  }
});

router.get('/preferences/event-daily-digest', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const preference = await notificationCenterService.fetchEventDailyDigestPreference(userId);
    res.json({ success: true, preference });
  } catch (error) {
    console.error('Fetch event daily digest preference error:', error);
    res.status(500).json({ error: 'Failed to fetch event daily digest preference' });
  }
});

router.put('/preferences/event-daily-digest', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const body = (req.body ?? {}) as {
      enabled?: unknown;
      reminderHours?: unknown;
      timezone?: unknown;
      channels?: unknown;
      includeNews?: unknown;
      includeRatings?: unknown;
      includeCheckinReminder?: unknown;
    };

    const preference = await notificationCenterService.updateEventDailyDigestPreference(userId, {
      enabled: typeof body.enabled === 'boolean' ? body.enabled : undefined,
      reminderHours: Array.isArray(body.reminderHours) ? body.reminderHours : undefined,
      timezone: typeof body.timezone === 'string' ? body.timezone.trim() : undefined,
      channels: Array.isArray(body.channels) ? body.channels : undefined,
      includeNews: typeof body.includeNews === 'boolean' ? body.includeNews : undefined,
      includeRatings: typeof body.includeRatings === 'boolean' ? body.includeRatings : undefined,
      includeCheckinReminder:
        typeof body.includeCheckinReminder === 'boolean' ? body.includeCheckinReminder : undefined,
    });
    res.json({ success: true, preference });
  } catch (error) {
    console.error('Update event daily digest preference error:', error);
    res.status(500).json({ error: error instanceof Error ? error.message : 'Failed to update event daily digest preference' });
  }
});

router.get('/preferences/route-dj-reminder', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const preference = await notificationCenterService.fetchRouteDJReminderPreference(userId);
    res.json({ success: true, preference });
  } catch (error) {
    console.error('Fetch route dj reminder preference error:', error);
    res.status(500).json({ error: 'Failed to fetch route dj reminder preference' });
  }
});

router.put('/preferences/route-dj-reminder', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const body = (req.body ?? {}) as {
      enabled?: unknown;
      timezone?: unknown;
      channels?: unknown;
      defaultReminderMinutesBefore?: unknown;
      watchedSlots?: unknown;
    };

    const preference = await notificationCenterService.updateRouteDJReminderPreference(userId, {
      enabled: typeof body.enabled === 'boolean' ? body.enabled : undefined,
      timezone: typeof body.timezone === 'string' ? body.timezone.trim() : undefined,
      channels: Array.isArray(body.channels) ? body.channels : undefined,
      defaultReminderMinutesBefore:
        typeof body.defaultReminderMinutesBefore === 'number' ? body.defaultReminderMinutesBefore : undefined,
      watchedSlots: Array.isArray(body.watchedSlots) ? body.watchedSlots : undefined,
    });
    res.json({ success: true, preference });
  } catch (error) {
    console.error('Update route dj reminder preference error:', error);
    res.status(500).json({ error: error instanceof Error ? error.message : 'Failed to update route dj reminder preference' });
  }
});

router.get('/preferences/followed-dj-update', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const preference = await notificationCenterService.fetchFollowedDJUpdatePreference(userId);
    res.json({ success: true, preference });
  } catch (error) {
    console.error('Fetch followed dj update preference error:', error);
    res.status(500).json({ error: 'Failed to fetch followed dj update preference' });
  }
});

router.put('/preferences/followed-dj-update', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const body = (req.body ?? {}) as {
      enabled?: unknown;
      reminderHours?: unknown;
      timezone?: unknown;
      channels?: unknown;
      includeInfos?: unknown;
      includeSets?: unknown;
      includeRatings?: unknown;
    };

    const preference = await notificationCenterService.updateFollowedDJUpdatePreference(userId, {
      enabled: typeof body.enabled === 'boolean' ? body.enabled : undefined,
      reminderHours: Array.isArray(body.reminderHours) ? body.reminderHours : undefined,
      timezone: typeof body.timezone === 'string' ? body.timezone.trim() : undefined,
      channels: Array.isArray(body.channels) ? body.channels : undefined,
      includeInfos: typeof body.includeInfos === 'boolean' ? body.includeInfos : undefined,
      includeSets: typeof body.includeSets === 'boolean' ? body.includeSets : undefined,
      includeRatings: typeof body.includeRatings === 'boolean' ? body.includeRatings : undefined,
    });
    res.json({ success: true, preference });
  } catch (error) {
    console.error('Update followed dj update preference error:', error);
    res.status(500).json({ error: error instanceof Error ? error.message : 'Failed to update followed dj update preference' });
  }
});

router.get('/preferences/followed-brand-update', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const preference = await notificationCenterService.fetchFollowedBrandUpdatePreference(userId);
    res.json({ success: true, preference });
  } catch (error) {
    console.error('Fetch followed brand update preference error:', error);
    res.status(500).json({ error: 'Failed to fetch followed brand update preference' });
  }
});

router.put('/preferences/followed-brand-update', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const body = (req.body ?? {}) as {
      enabled?: unknown;
      reminderHours?: unknown;
      timezone?: unknown;
      channels?: unknown;
      watchedBrandIds?: unknown;
      includeInfos?: unknown;
      includeEvents?: unknown;
    };

    const preference = await notificationCenterService.updateFollowedBrandUpdatePreference(userId, {
      enabled: typeof body.enabled === 'boolean' ? body.enabled : undefined,
      reminderHours: Array.isArray(body.reminderHours) ? body.reminderHours : undefined,
      timezone: typeof body.timezone === 'string' ? body.timezone.trim() : undefined,
      channels: Array.isArray(body.channels) ? body.channels : undefined,
      watchedBrandIds: Array.isArray(body.watchedBrandIds) ? body.watchedBrandIds : undefined,
      includeInfos: typeof body.includeInfos === 'boolean' ? body.includeInfos : undefined,
      includeEvents: typeof body.includeEvents === 'boolean' ? body.includeEvents : undefined,
    });
    res.json({ success: true, preference });
  } catch (error) {
    console.error('Update followed brand update preference error:', error);
    res.status(500).json({ error: error instanceof Error ? error.message : 'Failed to update followed brand update preference' });
  }
});

router.post('/admin/major-news/publish', authenticate, requireAdmin, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const actorUserId = req.user?.userId;
    if (!actorUserId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const body = (req.body ?? {}) as {
      headline?: unknown;
      summary?: unknown;
      deeplink?: unknown;
      channels?: unknown;
      targetUserIds?: unknown;
      userLimit?: unknown;
      dedupeKey?: unknown;
    };

    const headline = typeof body.headline === 'string' ? body.headline.trim() : '';
    const summary = typeof body.summary === 'string' ? body.summary.trim() : '';
    if (!headline || !summary) {
      res.status(400).json({ error: 'headline/summary are required' });
      return;
    }

    const channelsRaw = Array.isArray(body.channels)
      ? body.channels.filter((item): item is string => typeof item === 'string').map((item) => item.trim().toLowerCase())
      : [];
    const channels = (channelsRaw.length > 0 ? channelsRaw : ['in_app', 'apns']).filter(
      isDeliverableChannel
    );
    if (channels.length === 0) {
      res.status(400).json({ error: 'channels are invalid' });
      return;
    }

    const targetUserIds = Array.isArray(body.targetUserIds)
      ? Array.from(
          new Set(
            body.targetUserIds
              .filter((item): item is string => typeof item === 'string')
              .map((item) => item.trim())
              .filter(Boolean)
          )
        )
      : [];
    const userLimit = parseLimit(body.userLimit, 2000, 10000);
    const audienceUserIds =
      targetUserIds.length > 0
        ? targetUserIds
        : (
            await prisma.user.findMany({
              where: {
                isActive: true,
              },
              select: {
                id: true,
              },
              take: userLimit,
              orderBy: {
                createdAt: 'desc',
              },
            })
          ).map((item) => item.id);

    if (audienceUserIds.length === 0) {
      res.status(400).json({ error: 'No audience users found' });
      return;
    }

    const dedupeKeyRaw = typeof body.dedupeKey === 'string' ? body.dedupeKey.trim() : '';
    const dedupeKey = dedupeKeyRaw || `major_news:${headline}:${new Date().toISOString().slice(0, 13)}`;
    const results = await notificationCenterService.publish({
      category: 'major_news',
      targets: audienceUserIds.map((userId) => ({ userId })),
      channels,
      dedupeKey,
      payload: {
        title: headline,
        body: summary,
        deeplink: typeof body.deeplink === 'string' ? body.deeplink.trim() : null,
        metadata: {
          source: 'major_news_admin_publish',
          actorUserId,
          audienceCount: audienceUserIds.length,
        },
      },
    });

    res.json({
      success: true,
      audienceCount: audienceUserIds.length,
      dedupeKey,
      results,
    });
  } catch (error) {
    console.error('Publish major news error:', error);
    res.status(500).json({ error: error instanceof Error ? error.message : 'Failed to publish major news' });
  }
});

router.post('/admin/publish-test', authenticate, requireAdmin, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const actorUserId = req.user?.userId;
    if (!actorUserId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const body = (req.body ?? {}) as {
      category?: unknown;
      title?: unknown;
      message?: unknown;
      deeplink?: unknown;
      targetUserIds?: unknown;
      channels?: unknown;
    };

    const category = typeof body.category === 'string' ? body.category.trim() : 'major_news';
    const title = typeof body.title === 'string' ? body.title.trim() : '';
    const message = typeof body.message === 'string' ? body.message.trim() : '';
    if (!title || !message) {
      res.status(400).json({ error: 'title/message are required' });
      return;
    }

    const targetUserIds = Array.isArray(body.targetUserIds)
      ? body.targetUserIds.filter((item): item is string => typeof item === 'string').map((item) => item.trim()).filter(Boolean)
      : [];
    const channelsRaw = Array.isArray(body.channels)
      ? body.channels.filter((item): item is string => typeof item === 'string').map((item) => item.trim().toLowerCase())
      : [];
    const channels = channelsRaw.length > 0 ? channelsRaw : ['in_app'];

    const results = await notificationCenterService.publish({
      category: category as
        | 'chat_message'
        | 'community_interaction'
        | 'event_countdown'
        | 'event_daily_digest'
        | 'route_dj_reminder'
        | 'followed_dj_update'
        | 'followed_brand_update'
        | 'major_news',
      targets: (targetUserIds.length > 0 ? targetUserIds : [actorUserId]).map((userId) => ({ userId })),
      channels: channels as Array<'in_app' | 'apns'>,
      payload: {
        title,
        body: message,
        deeplink: typeof body.deeplink === 'string' ? body.deeplink.trim() : null,
      },
    });

    res.json({ success: true, results });
  } catch (error) {
    console.error('Notification publish test error:', error);
    res.status(500).json({ error: 'Failed to publish notification' });
  }
});

router.post('/admin/manual-publish/preview', authenticate, requireAdmin, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const actorUserId = req.user?.userId;
    if (!actorUserId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const preview = await buildAdminManualNotificationPreview(req.body ?? {});
    res.json({ success: true, preview });
  } catch (error) {
    console.error('Preview admin manual publish error:', error);
    res.status(500).json({ error: error instanceof Error ? error.message : 'Failed to preview manual publish' });
  }
});

router.post('/admin/manual-publish', authenticate, requireAdmin, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const actorUserId = req.user?.userId;
    if (!actorUserId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const body = (req.body ?? {}) as {
      content?: unknown;
      audiences?: unknown;
      channels?: unknown;
      dedupeSalt?: unknown;
    };
    const requestedChannels = normalizeStringArray(body.channels).filter(isDeliverableChannel);
    const channels = (requestedChannels.length > 0 ? requestedChannels : ['in_app', 'apns']) as Array<'in_app' | 'apns'>;
    const result = await executeAdminManualNotificationPublish({
      actorUserId,
      body,
      channels,
      dedupeSalt: readString(body.dedupeSalt),
    });

    await adminAuditService.createAction({
      actorId: actorUserId,
      action: 'notification.manual_publish.send',
      targetType: 'notification_manual_publish',
      targetId: result.content.relatedEntity?.id ?? `manual:${new Date().toISOString()}`,
      detail: {
        channels,
        content: result.content,
        totals: result.totals,
        audiences: result.audiences.map((audience) => ({
          type: audience.type,
          entityCount: audience.entityCount,
          targetUserCount: audience.targetUserCount,
          uniqueTargetUserCount: audience.uniqueTargetUserCount,
          dedupeKeys: audience.dedupeKeys,
        })),
      },
    });

    res.json({ success: true, result });
  } catch (error) {
    console.error('Publish admin manual notification error:', error);
    res.status(500).json({ error: error instanceof Error ? error.message : 'Failed to publish manual notification' });
  }
});

router.get('/admin/status', authenticate, requireAdmin, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const windowHours = parseWindowHours((req.query as Request['query']).windowHours, 24, 24 * 30);
    const stats = await notificationCenterService.fetchDeliveryStats(windowHours);
    const config = await notificationCenterService.fetchAdminGlobalConfig();
    res.json({
      success: true,
      status: {
        apns: getNotificationCenterAPNSStatus(),
        delivery: stats,
        config,
      },
    });
  } catch (error) {
    console.error('Fetch notification center status error:', error);
    res.status(500).json({ error: 'Failed to fetch notification center status' });
  }
});

router.get('/admin/deliveries/sections', authenticate, requireAdmin, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const query = req.query as Request['query'];
    const channelRaw = typeof query.channel === 'string' ? query.channel.trim().toLowerCase() : '';
    const channel = isTemplateChannel(channelRaw) ? channelRaw : undefined;
    const status = typeof query.status === 'string' ? query.status.trim() : undefined;
    const userId = typeof query.userId === 'string' ? query.userId.trim() : undefined;
    const eventId = typeof query.eventId === 'string' ? query.eventId.trim() : undefined;
    const search = typeof query.query === 'string' ? query.query.trim() : undefined;
    const items = await notificationCenterService.fetchAdminDeliverySectionSummaries({
      channel,
      status,
      userId,
      eventId,
      query: search,
    });
    res.json({ success: true, items });
  } catch (error) {
    console.error('Fetch notification delivery sections error:', error);
    res.status(500).json({ error: 'Failed to fetch notification delivery sections' });
  }
});

router.get('/admin/deliveries/by-section', authenticate, requireAdmin, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const query = req.query as Request['query'];
    const rawSection = typeof query.section === 'string' ? query.section.trim() : '';
    if (!rawSection || !(NOTIFICATION_ADMIN_DELIVERY_SECTIONS as readonly string[]).includes(rawSection)) {
      res.status(400).json({ error: 'Valid section is required' });
      return;
    }

    const channelRaw = typeof query.channel === 'string' ? query.channel.trim().toLowerCase() : '';
    const channel = isTemplateChannel(channelRaw) ? channelRaw : undefined;
    const status = typeof query.status === 'string' ? query.status.trim() : undefined;
    const userId = typeof query.userId === 'string' ? query.userId.trim() : undefined;
    const eventId = typeof query.eventId === 'string' ? query.eventId.trim() : undefined;
    const search = typeof query.query === 'string' ? query.query.trim() : undefined;
    const page = parsePage(query.page, 1, 100000);
    const limit = parseLimit(query.limit, 20, 100);

    const result = await notificationCenterService.fetchAdminDeliveriesBySection({
      section: rawSection as NotificationAdminDeliverySection,
      page,
      limit,
      channel,
      status,
      userId,
      eventId,
      query: search,
    });

    res.json({ success: true, ...result });
  } catch (error) {
    console.error('Fetch notification deliveries by section error:', error);
    res.status(500).json({ error: 'Failed to fetch notification deliveries by section' });
  }
});

router.get('/admin/deliveries', authenticate, requireAdmin, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const query = req.query as Request['query'];
    const channelRaw = typeof query.channel === 'string' ? query.channel.trim().toLowerCase() : '';
    const channel = isTemplateChannel(channelRaw) ? channelRaw : undefined;
    const status = typeof query.status === 'string' ? query.status.trim() : undefined;
    const userId = typeof query.userId === 'string' ? query.userId.trim() : undefined;
    const eventId = typeof query.eventId === 'string' ? query.eventId.trim() : undefined;
    const limit = parseLimit(query.limit, 50, 200);

    const items = await notificationCenterService.fetchRecentDeliveries({
      limit,
      channel,
      status,
      userId,
      eventId,
    });

    res.json({ success: true, items });
  } catch (error) {
    console.error('Fetch notification center deliveries error:', error);
    res.status(500).json({ error: 'Failed to fetch notification deliveries' });
  }
});

router.get('/admin/publish-tasks', authenticate, requireAdmin, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const query = req.query as Request['query'];
    const page = parsePage(query.page, 1, 100000);
    const limit = parseLimit(query.limit, 20, 100);
    const statusRaw = typeof query.status === 'string' ? query.status.trim().toLowerCase() : '';
    const status =
      statusRaw === 'pending' || statusRaw === 'published' || statusRaw === 'rejected'
        ? statusRaw
        : undefined;
    const taskTypeRaw = typeof query.taskType === 'string' ? query.taskType.trim() : '';
    const taskType = isAdminPublishTaskType(taskTypeRaw) ? taskTypeRaw : undefined;
    const search = typeof query.query === 'string' ? query.query.trim() : undefined;
    const result = await notificationCenterService.fetchAdminPublishTasks({
      page,
      limit,
      status,
      taskType,
      query: search,
    });
    res.json({ success: true, ...result });
  } catch (error) {
    console.error('Fetch admin publish tasks error:', error);
    res.status(500).json({ error: 'Failed to fetch admin publish tasks' });
  }
});

router.get('/admin/publish-tasks/by-entity', authenticate, requireAdmin, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const query = req.query as Request['query'];
    const taskTypeRaw = typeof query.taskType === 'string' ? query.taskType.trim() : '';
    const entityId = typeof query.entityId === 'string' ? query.entityId.trim() : '';
    const entityType = typeof query.entityType === 'string' ? query.entityType.trim() : '';
    if (!isAdminPublishTaskType(taskTypeRaw) || !entityId || !entityType) {
      res.status(400).json({ error: 'taskType, entityType and entityId are required' });
      return;
    }

    const task = await notificationCenterService.fetchAdminPublishTaskByEntity({
      taskType: taskTypeRaw,
      entityType,
      entityId,
    });
    const context = await buildAdminPublishTaskContext(taskTypeRaw, entityId, entityType);
    res.json({ success: true, task, context });
  } catch (error) {
    console.error('Fetch admin publish task by entity error:', error);
    res.status(500).json({ error: 'Failed to fetch admin publish task by entity' });
  }
});

router.get('/admin/publish-tasks/:id', authenticate, requireAdmin, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const id = String(req.params.id || '').trim();
    if (!id) {
      res.status(400).json({ error: 'task id is required' });
      return;
    }
    const task = await notificationCenterService.fetchAdminPublishTaskById(id);
    if (!task) {
      res.status(404).json({ error: 'Publish task not found' });
      return;
    }
    const context = await buildAdminPublishTaskContext(task.taskType, task.entityId, task.entityType);
    res.json({ success: true, task, context });
  } catch (error) {
    console.error('Fetch admin publish task error:', error);
    res.status(500).json({ error: 'Failed to fetch admin publish task' });
  }
});

router.get('/admin/content-history', authenticate, requireAdmin, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const query = req.query as Request['query'];
    const page = parsePage(query.page, 1, 100000);
    const limit = parseLimit(query.limit, 20, 100);
    const entityType = typeof query.entityType === 'string' ? query.entityType.trim() : undefined;
    const taskTypeRaw = typeof query.taskType === 'string' ? query.taskType.trim() : '';
    const taskType = isAdminPublishTaskType(taskTypeRaw) ? taskTypeRaw : undefined;
    const resultStatusRaw = typeof query.resultStatus === 'string' ? query.resultStatus.trim().toLowerCase() : '';
    const resultStatus = isAdminContentHistoryResultStatus(resultStatusRaw) ? resultStatusRaw : undefined;
    const pushStatusRaw = typeof query.pushStatus === 'string' ? query.pushStatus.trim().toLowerCase() : '';
    const pushStatus = isAdminContentHistoryPushStatus(pushStatusRaw) ? pushStatusRaw : undefined;
    const search = typeof query.query === 'string' ? query.query.trim() : undefined;

    const result = await notificationCenterService.fetchAdminContentHistory({
      page,
      limit,
      entityType,
      taskType,
      resultStatus,
      pushStatus,
      query: search,
    });
    res.json({ success: true, ...result });
  } catch (error) {
    console.error('Fetch admin content history error:', error);
    res.status(500).json({ error: 'Failed to fetch admin content history' });
  }
});

router.get('/admin/content-history/:id', authenticate, requireAdmin, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const id = String(req.params.id || '').trim();
    if (!id) {
      res.status(400).json({ error: 'history id is required' });
      return;
    }
    const item = await notificationCenterService.fetchAdminContentHistoryById(id);
    if (!item) {
      res.status(404).json({ error: 'Content history record not found' });
      return;
    }

    let task = item.linkedTaskId
      ? await notificationCenterService.fetchAdminPublishTaskById(item.linkedTaskId)
      : null;
    if (!task && item.taskType && item.entityId) {
      task = await notificationCenterService.fetchAdminPublishTaskByEntity({
        taskType: item.taskType,
        entityType: item.entityType,
        entityId: item.entityId,
      });
    }

    const context =
      item.taskType && item.entityId
        ? await buildAdminPublishTaskContext(item.taskType, item.entityId, item.entityType)
        : null;
    res.json({ success: true, item, task, context });
  } catch (error) {
    console.error('Fetch admin content history detail error:', error);
    res.status(500).json({ error: 'Failed to fetch admin content history detail' });
  }
});

router.post('/admin/content-history/:id/skip', authenticate, requireAdmin, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const actorUserId = req.user?.userId;
    if (!actorUserId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }
    const id = String(req.params.id || '').trim();
    if (!id) {
      res.status(400).json({ error: 'history id is required' });
      return;
    }
    const item = await notificationCenterService.fetchAdminContentHistoryById(id);
    if (!item) {
      res.status(404).json({ error: 'Content history record not found' });
      return;
    }

    const body = (req.body ?? {}) as { reason?: unknown };
    const reason = readString(body.reason);
    const updatedHistory = await notificationCenterService.updateAdminContentHistoryDecision({
      id,
      pushStatus: item.resultStatus === 'success' ? 'skipped' : 'not_applicable',
      decidedBy: actorUserId,
      decision: { reason, action: 'skip_push' },
    });

    let updatedTask = null;
    if (item.linkedTaskId) {
      const task = await notificationCenterService.fetchAdminPublishTaskById(item.linkedTaskId);
      if (task && task.status === 'pending') {
        updatedTask = await notificationCenterService.decideAdminPublishTask({
          id: task.id,
          status: 'rejected',
          decidedBy: actorUserId,
          decision: { reason, source: 'content_history_skip' },
        });
      }
    }

    await adminAuditService.createAction({
      actorId: actorUserId,
      action: 'notification.content_history.skip',
      targetType: 'notification_content_history',
      targetId: id,
      detail: {
        entityType: item.entityType,
        entityId: item.entityId,
        taskType: item.taskType,
        reason,
      },
    });

    res.json({ success: true, item: updatedHistory, task: updatedTask });
  } catch (error) {
    console.error('Skip admin content history push error:', error);
    res.status(500).json({ error: error instanceof Error ? error.message : 'Failed to skip admin content history push' });
  }
});

router.post('/admin/content-history/log-failure', authenticate, requireAdmin, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const actorUserId = req.user?.userId;
    if (!actorUserId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const body = (req.body ?? {}) as {
      entityType?: unknown;
      entityId?: unknown;
      taskType?: unknown;
      operationType?: unknown;
      title?: unknown;
      summary?: unknown;
      sourceRoute?: unknown;
      errorMessage?: unknown;
      payload?: unknown;
    };

    const entityType = readString(body.entityType);
    const operationTypeRaw = readString(body.operationType) || '';
    const title = readString(body.title);
    if (!entityType || !isAdminContentHistoryOperationType(operationTypeRaw) || !title) {
      res.status(400).json({ error: 'entityType, operationType and title are required' });
      return;
    }

    const taskTypeRaw = readString(body.taskType) || '';
    const taskType = isAdminPublishTaskType(taskTypeRaw) ? taskTypeRaw : null;
    const item = await notificationCenterService.createAdminContentHistory({
      entityType,
      entityId: readString(body.entityId),
      taskType,
      operationType: operationTypeRaw,
      resultStatus: 'failed',
      pushStatus: 'not_applicable',
      title,
      summary: readString(body.summary),
      payload: isRecord(body.payload) ? body.payload : {},
      errorMessage: readString(body.errorMessage) || 'Unknown error',
      sourceRoute: readString(body.sourceRoute),
      createdBy: actorUserId,
    });

    res.json({ success: true, item });
  } catch (error) {
    console.error('Log admin content history failure error:', error);
    res.status(500).json({ error: error instanceof Error ? error.message : 'Failed to log admin content history failure' });
  }
});

router.get('/admin/news/:id/publish-context', authenticate, requireAdmin, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const articleId = String(req.params.id || '').trim();
    if (!articleId) {
      res.status(400).json({ error: 'news id is required' });
      return;
    }

    const context = await buildAdminNewsNotificationContext(articleId);
    if (!context) {
      res.status(404).json({ error: 'News article not found' });
      return;
    }

    res.json({ success: true, context });
  } catch (error) {
    console.error('Fetch admin news publish context error:', error);
    res.status(500).json({ error: 'Failed to fetch news publish context' });
  }
});

router.post('/admin/news/:id/publish', authenticate, requireAdmin, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const actorUserId = req.user?.userId;
    if (!actorUserId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const articleId = String(req.params.id || '').trim();
    if (!articleId) {
      res.status(400).json({ error: 'news id is required' });
      return;
    }

    const body = (req.body ?? {}) as {
      audienceKeys?: unknown;
      channels?: unknown;
      dedupeSalt?: unknown;
    };

    const execution = await executeAdminNewsPublish({
      actorUserId,
      articleId,
      audienceKeys: normalizeStringArray(body.audienceKeys).filter(isAdminNewsAudienceKey),
      channels: (normalizeStringArray(body.channels).filter(isDeliverableChannel).length > 0
        ? normalizeStringArray(body.channels).filter(isDeliverableChannel)
        : ['in_app', 'apns']) as Array<'in_app' | 'apns'>,
      dedupeSalt: readString(body.dedupeSalt),
    });
    if (!execution) {
      res.status(404).json({ error: 'News article not found' });
      return;
    }

    await adminAuditService.createAction({
      actorId: actorUserId,
      action: 'notification.news.publish',
      targetType: 'news_article',
      targetId: execution.entity.id,
      detail: {
        articleTitle: execution.entity.title,
        audienceKeys: normalizeStringArray(body.audienceKeys).filter(isAdminNewsAudienceKey),
        channels: (normalizeStringArray(body.channels).filter(isDeliverableChannel).length > 0
          ? normalizeStringArray(body.channels).filter(isDeliverableChannel)
          : ['in_app', 'apns']),
        dedupeSalt: readString(body.dedupeSalt),
        publicationResults: execution.audiences.map((item) => ({
          key: item.key,
          entityCount: item.entityCount,
          targetUserCount: item.targetUserCount,
          dedupeKeys: item.dedupeKeys,
        })),
      },
    });

    const publishTask = await notificationCenterService.fetchAdminPublishTaskByEntity({
      taskType: 'news_release',
      entityType: 'news_article',
      entityId: execution.entity.id,
    });
    if (publishTask && publishTask.status === 'pending') {
      await notificationCenterService.decideAdminPublishTask({
        id: publishTask.id,
        status: 'published',
        decidedBy: actorUserId,
        decision: {
          channels: normalizeStringArray(body.channels).filter(isDeliverableChannel),
          audienceKeys: normalizeStringArray(body.audienceKeys).filter(isAdminNewsAudienceKey),
          dedupeSalt: readString(body.dedupeSalt),
          result: execution,
        },
      });
      await notificationCenterService.syncAdminContentHistoryForTaskDecision({
        taskId: publishTask.id,
        status: 'published',
        decidedBy: actorUserId,
        decision: {
          channels: normalizeStringArray(body.channels).filter(isDeliverableChannel),
          audienceKeys: normalizeStringArray(body.audienceKeys).filter(isAdminNewsAudienceKey),
          dedupeSalt: readString(body.dedupeSalt),
          result: execution,
        },
      });
    }

    res.json(execution);
  } catch (error) {
    console.error('Publish admin news notification error:', error);
    res.status(500).json({ error: error instanceof Error ? error.message : 'Failed to publish news notification' });
  }
});

router.post('/admin/publish-tasks/:id/publish', authenticate, requireAdmin, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const actorUserId = req.user?.userId;
    if (!actorUserId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const taskId = String(req.params.id || '').trim();
    if (!taskId) {
      res.status(400).json({ error: 'task id is required' });
      return;
    }

    const task = await notificationCenterService.fetchAdminPublishTaskById(taskId);
    if (!task) {
      res.status(404).json({ error: 'Publish task not found' });
      return;
    }

    const body = (req.body ?? {}) as {
      audienceKeys?: unknown;
      channels?: unknown;
      dedupeSalt?: unknown;
    };
    const requestedChannels = normalizeStringArray(body.channels).filter(isDeliverableChannel);
    const channels = (requestedChannels.length > 0 ? requestedChannels : ['in_app', 'apns']) as Array<'in_app' | 'apns'>;

    let result: AdminPublishExecutionResult | null = null;
    if (task.taskType === 'news_release') {
      result = await executeAdminNewsPublish({
        actorUserId,
        articleId: task.entityId,
        audienceKeys: normalizeStringArray(body.audienceKeys).filter(isAdminNewsAudienceKey),
        channels,
        dedupeSalt: readString(body.dedupeSalt),
      });
    } else if (task.taskType === 'event_release') {
      result = await executeAdminEventPublish({
        actorUserId,
        eventId: task.entityId,
        audienceKeys: normalizeStringArray(body.audienceKeys).filter(isAdminEventAudienceKey),
        channels,
        dedupeSalt: readString(body.dedupeSalt),
      });
    } else if (task.taskType === 'dj_release') {
      result = await executeAdminDJPublish({
        actorUserId,
        djId: task.entityId,
        audienceKeys: normalizeStringArray(body.audienceKeys).filter(isAdminDJAudienceKey),
        channels,
        dedupeSalt: readString(body.dedupeSalt),
      });
    } else if (task.taskType === 'brand_release') {
      result = await executeAdminBrandPublish({
        actorUserId,
        brandId: task.entityId,
        entityType: task.entityType,
        audienceKeys: normalizeStringArray(body.audienceKeys).filter(isAdminBrandAudienceKey),
        channels,
        dedupeSalt: readString(body.dedupeSalt),
      });
    }

    if (!result) {
      res.status(404).json({ error: 'Notification source entity not found' });
      return;
    }

    const updatedTask = await notificationCenterService.decideAdminPublishTask({
      id: task.id,
      status: 'published',
      decidedBy: actorUserId,
      decision: {
        channels,
        audienceKeys: normalizeStringArray(body.audienceKeys),
        dedupeSalt: readString(body.dedupeSalt),
        result,
      },
    });
    await notificationCenterService.syncAdminContentHistoryForTaskDecision({
      taskId: task.id,
      status: 'published',
      decidedBy: actorUserId,
      decision: {
        channels,
        audienceKeys: normalizeStringArray(body.audienceKeys),
        dedupeSalt: readString(body.dedupeSalt),
        result,
      },
    });

    await adminAuditService.createAction({
      actorId: actorUserId,
      action: 'notification.publish_task.publish',
      targetType: 'notification_publish_task',
      targetId: task.id,
      detail: {
        taskType: task.taskType,
        entityType: task.entityType,
        entityId: task.entityId,
        channels,
      },
    });

    res.json({ success: true, task: updatedTask, result });
  } catch (error) {
    console.error('Publish admin task error:', error);
    res.status(500).json({ error: error instanceof Error ? error.message : 'Failed to publish admin task' });
  }
});

router.post('/admin/publish-tasks/:id/reject', authenticate, requireAdmin, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const actorUserId = req.user?.userId;
    if (!actorUserId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const taskId = String(req.params.id || '').trim();
    if (!taskId) {
      res.status(400).json({ error: 'task id is required' });
      return;
    }

    const task = await notificationCenterService.fetchAdminPublishTaskById(taskId);
    if (!task) {
      res.status(404).json({ error: 'Publish task not found' });
      return;
    }

    const body = (req.body ?? {}) as { reason?: unknown };
    const updatedTask = await notificationCenterService.decideAdminPublishTask({
      id: task.id,
      status: 'rejected',
      decidedBy: actorUserId,
      decision: {
        reason: readString(body.reason),
      },
    });
    await notificationCenterService.syncAdminContentHistoryForTaskDecision({
      taskId: task.id,
      status: 'rejected',
      decidedBy: actorUserId,
      decision: {
        reason: readString(body.reason),
      },
    });

    await adminAuditService.createAction({
      actorId: actorUserId,
      action: 'notification.publish_task.reject',
      targetType: 'notification_publish_task',
      targetId: task.id,
      detail: {
        taskType: task.taskType,
        entityType: task.entityType,
        entityId: task.entityId,
        reason: readString(body.reason),
      },
    });

    res.json({ success: true, task: updatedTask });
  } catch (error) {
    console.error('Reject admin task error:', error);
    res.status(500).json({ error: error instanceof Error ? error.message : 'Failed to reject admin task' });
  }
});

router.get('/admin/config', authenticate, requireAdmin, async (_req: AuthRequest, res: Response): Promise<void> => {
  try {
    const config = await notificationCenterService.fetchAdminGlobalConfig();
    res.json({ success: true, config });
  } catch (error) {
    console.error('Fetch notification center config error:', error);
    res.status(500).json({ error: 'Failed to fetch notification center config' });
  }
});

router.put('/admin/config', authenticate, requireAdmin, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }
    const body = (req.body ?? {}) as { config?: unknown };
    const config = await notificationCenterService.updateAdminGlobalConfig(body.config ?? {}, userId);
    await adminAuditService.createAction({
      actorId: userId,
      action: 'notification.config.update',
      targetType: 'notification_admin_config',
      targetId: 'global',
      detail: {
        categorySwitches: config.categorySwitches,
        channelSwitches: config.channelSwitches,
        grayRelease: config.grayRelease,
        governance: config.governance,
      },
    });
    res.json({ success: true, config });
  } catch (error) {
    console.error('Update notification center config error:', error);
    res.status(500).json({ error: error instanceof Error ? error.message : 'Failed to update notification center config' });
  }
});

router.get('/admin/templates', authenticate, requireAdmin, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const query = req.query as Request['query'];
    const channelRaw = typeof query.channel === 'string' ? query.channel.trim().toLowerCase() : '';
    const channel = isTemplateChannel(channelRaw) ? channelRaw : undefined;
    const items = await notificationCenterService.fetchAdminTemplates({
      limit: parseLimit(query.limit, 50, 200),
      category: typeof query.category === 'string' ? query.category.trim() : undefined,
      locale: typeof query.locale === 'string' ? query.locale.trim() : undefined,
      channel,
      isActive: parseBoolean(query.isActive),
    });
    res.json({ success: true, items });
  } catch (error) {
    console.error('Fetch notification templates error:', error);
    res.status(500).json({ error: 'Failed to fetch notification templates' });
  }
});

router.put('/admin/templates', authenticate, requireAdmin, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const actorUserId = req.user?.userId;
    if (!actorUserId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const body = (req.body ?? {}) as {
      category?: unknown;
      locale?: unknown;
      channel?: unknown;
      titleTemplate?: unknown;
      bodyTemplate?: unknown;
      deeplinkTemplate?: unknown;
      variables?: unknown;
      isActive?: unknown;
    };

    const category = typeof body.category === 'string' ? body.category.trim() : '';
    const locale = typeof body.locale === 'string' ? body.locale.trim() : 'zh-CN';
    const channelRaw = typeof body.channel === 'string' ? body.channel.trim().toLowerCase() : '';
    const titleTemplate = typeof body.titleTemplate === 'string' ? body.titleTemplate.trim() : '';
    const bodyTemplate = typeof body.bodyTemplate === 'string' ? body.bodyTemplate.trim() : '';
    if (!category || !titleTemplate || !bodyTemplate) {
      res.status(400).json({ error: 'category/titleTemplate/bodyTemplate are required' });
      return;
    }
    if (!isTemplateChannel(channelRaw)) {
      res.status(400).json({ error: 'channel must be one of in_app/apns/email/sms' });
      return;
    }

    const item = await notificationCenterService.upsertAdminTemplate({
      category,
      locale,
      channel: channelRaw,
      titleTemplate,
      bodyTemplate,
      deeplinkTemplate: typeof body.deeplinkTemplate === 'string' ? body.deeplinkTemplate.trim() : null,
      variables: Array.isArray(body.variables) ? body.variables : [],
      isActive: parseBoolean(body.isActive),
    });
    await adminAuditService.createAction({
      actorId: actorUserId,
      action: 'notification.template.upsert',
      targetType: 'notification_template',
      targetId: item.id,
      detail: {
        category: item.category,
        locale: item.locale,
        channel: item.channel,
        isActive: item.isActive,
      },
    });
    res.json({ success: true, item });
  } catch (error) {
    console.error('Upsert notification template error:', error);
    res.status(500).json({ error: error instanceof Error ? error.message : 'Failed to upsert notification template' });
  }
});

export default router;
