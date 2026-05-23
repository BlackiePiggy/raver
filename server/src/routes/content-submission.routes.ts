import { Prisma, PrismaClient } from '@prisma/client';
import { Router, Response } from 'express';
import { authenticate, AuthRequest } from '../middleware/auth';
import { adminAuditService } from '../modules/admin/admin-audit.service';
import { requireAdminOrOperator } from '../modules/admin/admin-auth.policy';
import { notificationCenterService } from '../modules/notifications';
import { analyzeI18nCompleteness, normalizeTriTextPayload, resolveLocalizedText, triTextToJson } from '../utils/i18n';
import { contentCompliance } from '../utils/content-compliance';
import { syncNewsBindings, syncPostBindings } from '../services/content-bindings.service';
import {
  autoAlignEventLineupToTimetablePayload,
  assertEventSubmissionBaseRevision,
  createOrUpdateEventFromSubmission,
  EventSubmissionConflictError,
} from '../services/content-submission-event.service';
import { createOrUpdateDJFromSubmission } from '../services/content-submission-dj.service';
import { djEventBindingReviewService } from '../services/dj-event-binding-review.service';
import { scheduleContentSubmissionProcessingBestEffort } from '../services/content-submission-processing.service';
import {
  attachContentSubmissionChangeSummary,
  changeSummaryTextFromPayload,
} from '../services/content-submission-change-summary.service';
import {
  DEFAULT_EVENT_TIME_ZONE,
  normalizeEventTimeZone,
  parseEventDateInput,
  startOfEventDay,
} from '../utils/event-timezone';

const router: Router = Router();
const prisma = new PrismaClient();

const ENTITY_TYPES = new Set(['event', 'dj', 'news', 'set', 'brand', 'label', 'id', 'rating']);
const STATUSES = new Set(['pending', 'processing', 'reviewing', 'approved', 'rejected', 'failed', 'cancelled']);
const ACTIVE_REVIEWABLE_STATUSES = new Set(['pending', 'processing', 'reviewing']);

const cleanText = (value: unknown): string | undefined => {
  if (typeof value !== 'string') return undefined;
  const trimmed = value.trim();
  return trimmed || undefined;
};
const parseLimit = (value: unknown, fallback = 50, max = 200): number => {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) return fallback;
  return Math.min(Math.floor(parsed), max);
};

const parsePage = (value: unknown, fallback = 1): number => {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) return fallback;
  return Math.floor(parsed);
};

const toJsonObject = (value: unknown): Prisma.InputJsonObject => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return {};
  }
  return value as Prisma.InputJsonObject;
};

const toOptionalJsonObject = (value: unknown): Prisma.InputJsonObject | undefined => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return undefined;
  }
  return value as Prisma.InputJsonObject;
};

const syncRatingUnitDjBindings = async (
  tx: Prisma.TransactionClient,
  unitId: string,
  djIds: string[]
): Promise<void> => {
  await tx.ratingUnitDJBinding.deleteMany({
    where: { unitId },
  });

  const uniqueIds = Array.from(new Set(djIds.map((id) => String(id || '').trim()).filter(Boolean)));
  if (uniqueIds.length === 0) {
    return;
  }

  await tx.ratingUnitDJBinding.createMany({
    data: uniqueIds.map((djId, index) => ({
      unitId,
      djId,
      sortOrder: index,
      bindingType: 'rated',
    })),
  });
};

const titleFromPayload = (entityType: string, payload: Prisma.InputJsonObject): string => {
  const titleI18n = normalizeTriTextPayload(payload.titleI18n ?? payload.nameI18n, '');
  if (titleI18n?.ja || titleI18n?.en || titleI18n?.zh) {
    return titleI18n.ja || titleI18n.en || titleI18n.zh;
  }
  const title = cleanText(payload.title);
  const name = cleanText(payload.name);
  const songName = cleanText(payload.songName);
  if (title) return title;
  if (name) return name;
  if (songName) return songName;
  const fallback: Record<string, string> = {
    event: '未命名活动',
    dj: '未命名 DJ',
    news: '未命名资讯',
    set: '未命名 Set',
    brand: '未命名品牌',
    label: '未命名厂牌',
    id: '未命名 ID',
    rating: '未命名打分',
  };
  return fallback[entityType] || '未命名内容';
};

const CONTENT_I18N_FIELDS_BY_ENTITY: Record<string, string[]> = {
  event: ['nameI18n', 'descriptionI18n'],
  dj: ['nameI18n', 'bioI18n'],
  news: ['titleI18n', 'summaryI18n', 'bodyI18n'],
  set: ['titleI18n', 'descriptionI18n'],
  brand: ['nameI18n', 'descriptionI18n'],
  label: ['nameI18n', 'descriptionI18n'],
  rating: ['titleI18n', 'descriptionI18n'],
  id: ['titleI18n', 'descriptionI18n'],
};

const buildI18nReviewNotes = (
  entityType: string,
  payload: Prisma.InputJsonObject,
  existing?: Prisma.InputJsonObject
): Prisma.InputJsonObject => {
  const report = analyzeI18nCompleteness(payload, CONTENT_I18N_FIELDS_BY_ENTITY[entityType] || ['titleI18n']);
  return {
    ...(existing || {}),
    i18n: report as unknown as Prisma.InputJsonValue,
    compliance: contentCompliance.reviewNotes(entityType, payload),
  };
};

const ensureSubmissionPayload = (entityType: string, payload: Prisma.InputJsonObject): string | null => {
  const name = cleanText(payload.name);
  const title = cleanText(payload.title);
  if (entityType === 'news') {
    if (!title && !cleanText(payload.content)) return '资讯标题或正文不能为空';
    return null;
  }
  if (entityType === 'set') {
    if (!title) return 'Set 标题不能为空';
    if (!cleanText(payload.djId)) return 'Set 关联 DJ 不能为空';
    if (!cleanText(payload.videoUrl)) return 'Set 视频不能为空';
    return null;
  }
  if (entityType === 'id') {
    if (!cleanText(payload.songName) && !title) return 'ID 名称不能为空';
    return null;
  }
  if (entityType === 'rating') {
    if (!name && !title) return '打分标题不能为空';
    return null;
  }
  if (!name) {
    const label: Record<string, string> = {
      event: '活动名称不能为空',
      dj: 'DJ 名称不能为空',
      brand: '品牌名称不能为空',
      label: '厂牌名称不能为空',
    };
    return label[entityType] || '名称不能为空';
  }
  if (entityType === 'event') {
    if (!cleanText(payload.startDate) || !cleanText(payload.endDate)) {
      return '活动开始和结束日期不能为空';
    }
  }
  const complianceError = contentCompliance.validationError(entityType, payload);
  if (complianceError) return complianceError;
  return null;
};

const normalizeEventSubmissionPayload = (payload: Prisma.InputJsonObject): Prisma.InputJsonObject => {
  if (cleanText(payload.targetEventId) || cleanText(payload.editTargetEventId)) {
    return payload;
  }
  const timeZone = normalizeEventTimeZone(payload.timeZone ?? payload.timezone ?? payload.eventTimeZone ?? DEFAULT_EVENT_TIME_ZONE);
  const startDateRaw = parseEventDateInput(payload.startDate, timeZone, 'start', payload.startTime);
  const startDate = startDateRaw ? startOfEventDay(startDateRaw, timeZone) : null;
  if (!startDate) return payload;
  const dayRolloverHourRaw = Number(payload.dayRolloverHour);
  const dayRolloverHour = Number.isFinite(dayRolloverHourRaw) ? Math.trunc(dayRolloverHourRaw) : 6;
  return autoAlignEventLineupToTimetablePayload(
    payload as unknown as Prisma.JsonObject,
    startDate,
    dayRolloverHour,
    timeZone
  ) as unknown as Prisma.InputJsonObject;
};

const createSubmissionWithVersion = async (input: {
  submitterId: string;
  entityType: string;
  title: string;
  payload: Prisma.InputJsonObject;
}) => {
  return prisma.$transaction(async (tx) => {
    const submission = await tx.contentSubmission.create({
      data: {
        submitterId: input.submitterId,
        entityType: input.entityType,
        title: input.title,
        payload: input.payload,
        reviewNotes: buildI18nReviewNotes(input.entityType, input.payload),
        status: 'processing',
      },
      include: {
        submitter: {
          select: { id: true, username: true, displayName: true, avatarUrl: true },
        },
      },
    });

    await (tx as any).contentSubmissionVersion.create({
      data: {
        submissionId: submission.id,
        version: 1,
        title: input.title,
        payload: input.payload,
        submittedBy: input.submitterId,
        changeNote: 'Initial submission',
      },
    });

    return submission;
  });
};

const slugify = (value: string): string =>
  value
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '') || 'content';

const uniqueLabelSlug = async (name: string, requestedSlug?: string): Promise<string> => {
  const base = slugify(requestedSlug || name) || `label-${Date.now()}`;
  let candidate = base;
  let seq = 1;
  while (await prisma.label.findUnique({ where: { slug: candidate }, select: { id: true } })) {
    seq += 1;
    candidate = `${base}-${seq}`;
  }
  return candidate;
};

const uniqueWikiFestivalIdForName = async (name: string): Promise<string> => {
  const base = slugify(name) || `brand-${Date.now()}`;
  let candidate = base;
  let seq = 1;
  while (await prisma.wikiFestival.findUnique({ where: { id: candidate }, select: { id: true } })) {
    seq += 1;
    candidate = `${base}-${seq}`;
  }
  return candidate;
};

const uniqueDJSetSlug = async (title: string, requestedSlug?: string): Promise<string> => {
  const base = slugify(requestedSlug || title) || `set-${Date.now()}`;
  let candidate = base;
  let seq = 1;
  while (await prisma.dJSet.findUnique({ where: { slug: candidate }, select: { id: true } })) {
    seq += 1;
    candidate = `${base}-${seq}`;
  }
  return candidate;
};

const dateFromPayload = (value: unknown): Date | null => {
  if (typeof value !== 'string' && !(value instanceof Date)) return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
};

const integerOrNull = (value: unknown): number | null => {
  if (value === null || value === undefined || value === '') return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? Math.trunc(parsed) : null;
};

const stringArray = (value: unknown): string[] => {
  if (Array.isArray(value)) {
    return value.map((item) => (typeof item === 'string' ? item.trim() : '')).filter(Boolean);
  }
  if (typeof value === 'string') {
    return value.split(/[,\uFF0C\/\u3001]/g).map((item) => item.trim()).filter(Boolean);
  }
  return [];
};

const dateOrUndefined = (value: unknown): Date | undefined => dateFromPayload(value) ?? undefined;

const createNewsFromSubmission = async (payload: Prisma.JsonObject, submitterId: string) => {
  const title = cleanText(payload.title) || titleFromPayload('news', payload);
  const body = cleanText(payload.body) || cleanText(payload.content) || title;
  const coverImageUrl =
    cleanText(payload.coverImageURL) ||
    cleanText(payload.coverImageUrl) ||
    stringArray(payload.images)[0] ||
    null;
  const boundDjIds = stringArray(payload.boundDjIds);
  const boundBrandIds = stringArray(payload.boundBrandIds);
  const boundEventIds = stringArray(payload.boundEventIds);
  return prisma.$transaction(async (tx) => {
    const article = await tx.newsArticle.create({
      data: {
        authorId: submitterId,
        category: cleanText(payload.category) || 'community',
        source: cleanText(payload.source) || 'Raver',
        title,
        summary: cleanText(payload.summary) || '',
        body,
        link: cleanText(payload.link) || null,
        coverImageUrl,
        visibility: 'public',
        publishedAt: dateFromPayload(payload.publishedAt ?? payload.displayPublishedAt) || new Date(),
      } as any,
    });
    await syncNewsBindings(tx, article.id, {
      djIds: boundDjIds,
      brandIds: boundBrandIds,
      eventIds: boundEventIds,
    });
    return article;
  });
};

const createSetFromSubmission = async (payload: Prisma.JsonObject, submitterId: string) => {
  const title = cleanText(payload.title);
  const djId = cleanText(payload.djId);
  const videoUrl = cleanText(payload.videoUrl);
  if (!title || !djId || !videoUrl) {
    throw new Error('djId、title 和 videoUrl 不能为空');
  }
  const dj = await prisma.dJ.findUnique({ where: { id: djId }, select: { id: true } });
  if (!dj) throw new Error('关联 DJ 不存在');
  const slug = await uniqueDJSetSlug(title, cleanText(payload.slug));
  const normalizedDjIds = Array.from(new Set([djId, ...stringArray(payload.djIds)])).filter(Boolean);
  const customDjNames = stringArray(payload.customDjNames);
  return prisma.$transaction(async (tx) => {
    const set = await tx.dJSet.create({
      data: {
        djId,
        customDjNames,
        uploadedById: submitterId,
        title,
        titleI18n: triTextToJson(normalizeTriTextPayload(payload.titleI18n, title)),
        slug,
        description: cleanText(payload.description) || null,
        descriptionI18n: triTextToJson(normalizeTriTextPayload(payload.descriptionI18n, cleanText(payload.description) || '')),
        thumbnailUrl: cleanText(payload.thumbnailUrl) || null,
        videoUrl,
        platform: cleanText(payload.platform) || 'external',
        videoId: cleanText(payload.videoId) || slug,
        duration: integerOrNull(payload.duration),
        recordedAt: dateOrUndefined(payload.recordedAt),
        venue: cleanText(payload.venue) || null,
        eventId: cleanText(payload.eventId) || null,
        eventName: cleanText(payload.eventName) || null,
        isVerified: true,
      } as any,
    });
    if (normalizedDjIds.length > 0 || customDjNames.length > 0) {
      await tx.dJSetArtist.createMany({
        data: [
          ...normalizedDjIds.map((id, index) => ({
            setId: set.id,
            djId: id,
            artistNameSnapshot: id,
            artistOrder: index,
            role: id === djId ? 'primary' : 'co',
          })),
          ...customDjNames.map((name, index) => ({
            setId: set.id,
            djId: null,
            artistNameSnapshot: name,
            artistOrder: normalizedDjIds.length + index,
            role: 'custom',
          })),
        ],
      });
    }
    return set;
  });
};

const createBrandFromSubmission = async (payload: Prisma.JsonObject, submitterId: string) => {
  const name = cleanText(payload.name);
  if (!name) throw new Error('品牌名称不能为空');
  const id = await uniqueWikiFestivalIdForName(name);
  return prisma.wikiFestival.create({
    data: {
      id,
      sourceRowId: integerOrNull(payload.sourceRowId),
      name,
      nameI18n: triTextToJson(normalizeTriTextPayload(payload.nameI18n, name)),
      abbreviation: cleanText(payload.abbreviation) || '',
      aliases: stringArray(payload.aliases),
      country: cleanText(payload.country) || '',
      city: cleanText(payload.city) || '',
      foundedYear: cleanText(payload.foundedYear) || '',
      frequency: cleanText(payload.frequency) || '',
      tagline: cleanText(payload.tagline) || '',
      introduction: cleanText(payload.introduction) || cleanText(payload.description) || '',
      descriptionI18n: triTextToJson(normalizeTriTextPayload(payload.descriptionI18n, cleanText(payload.introduction) || cleanText(payload.description) || '')),
      officialWebsite: cleanText(payload.officialWebsite) || null,
      facebookUrl: cleanText(payload.facebookUrl) || null,
      instagramUrl: cleanText(payload.instagramUrl) || null,
      twitterUrl: cleanText(payload.twitterUrl) || null,
      youtubeUrl: cleanText(payload.youtubeUrl) || null,
      tiktokUrl: cleanText(payload.tiktokUrl) || null,
      avatarUrl: cleanText(payload.avatarUrl) || null,
      backgroundUrl: cleanText(payload.backgroundUrl) || null,
      links: (payload.links as Prisma.InputJsonValue | undefined) ?? undefined,
      contributors: { create: { userId: submitterId } },
    } as any,
  });
};

const createLabelFromSubmission = async (payload: Prisma.JsonObject) => {
  const name = cleanText(payload.name);
  if (!name) throw new Error('厂牌名称不能为空');
  const slug = await uniqueLabelSlug(name, cleanText(payload.slug));
  const profileUrl = cleanText(payload.profileUrl) || `community://${slug}`;
  return prisma.label.create({
    data: {
      name,
      nameI18n: triTextToJson(normalizeTriTextPayload(payload.nameI18n, name)),
      slug,
      profileUrl,
      profileSlug: cleanText(payload.profileSlug) || slug,
      logoUrl: cleanText(payload.logoUrl) || null,
      avatarUrl: cleanText(payload.avatarUrl) || null,
      backgroundUrl: cleanText(payload.backgroundUrl) || null,
      nation: cleanText(payload.nation) || cleanText(payload.country) || null,
      genresPreview: cleanText(payload.genresPreview) || null,
      introductionPreview: cleanText(payload.introductionPreview) || null,
      introduction: cleanText(payload.introduction) || cleanText(payload.description) || null,
      descriptionI18n: triTextToJson(normalizeTriTextPayload(payload.descriptionI18n, cleanText(payload.introduction) || cleanText(payload.description) || '')),
      genres: stringArray(payload.genres),
      contacts: (payload.contacts as Prisma.InputJsonValue | undefined) ?? undefined,
      linksInWeb: (payload.linksInWeb as Prisma.InputJsonValue | undefined) ?? undefined,
      generalContactEmail: cleanText(payload.generalContactEmail) || null,
      demoSubmissionUrl: cleanText(payload.demoSubmissionUrl) || null,
      demoSubmissionDisplay: cleanText(payload.demoSubmissionDisplay) || null,
      facebookUrl: cleanText(payload.facebookUrl) || null,
      soundcloudUrl: cleanText(payload.soundcloudUrl) || null,
      musicPurchaseUrl: cleanText(payload.musicPurchaseUrl) || null,
      officialWebsiteUrl: cleanText(payload.officialWebsiteUrl) || cleanText(payload.officialWebsite) || null,
      founderName: cleanText(payload.founderName) || null,
      foundedAt: cleanText(payload.foundedAt) || null,
      founderDjId: cleanText(payload.founderDjId) || null,
    } as any,
  });
};

const createRatingFromSubmission = async (payload: Prisma.JsonObject, submitterId: string) => {
  const name = cleanText(payload.name) || cleanText(payload.title);
  if (!name) throw new Error('打分标题不能为空');
  const rawDjId = cleanText(payload.djId);
  const rawDjIds = stringArray(payload.djIds);
  const djIds = Array.from(new Set([...rawDjIds, ...(rawDjId ? [rawDjId] : [])])).filter(Boolean);
  if (djIds.length > 0) {
    const existingDjs = await prisma.dJ.findMany({ where: { id: { in: djIds } }, select: { id: true } });
    const existingDjIds = new Set(existingDjs.map((dj) => dj.id));
    const missingDjId = djIds.find((id) => !existingDjIds.has(id));
    if (missingDjId) throw new Error(`DJ 不存在: ${missingDjId}`);
  }
  if (cleanText(payload.ratingEventId)) {
    const eventId = cleanText(payload.ratingEventId)!;
    const event = await prisma.ratingEvent.findUnique({ where: { id: eventId }, select: { id: true } });
    if (!event) throw new Error('打分事件不存在');
    return prisma.$transaction(async (tx) => {
      const unit = await tx.ratingUnit.create({
        data: {
          eventId,
          createdById: submitterId,
          djId: rawDjId || djIds[0] || null,
          name,
          description: cleanText(payload.description) || null,
          imageUrl: cleanText(payload.imageUrl) || null,
        },
      });
      await syncRatingUnitDjBindings(tx, unit.id, djIds);
      return unit;
    });
  }
  const sourceEventId = cleanText(payload.sourceEventId ?? payload.eventId);
  if (sourceEventId) {
    const sourceEvent = await prisma.event.findUnique({ where: { id: sourceEventId }, select: { id: true } });
    if (!sourceEvent) throw new Error('关联活动不存在');
  }
  return prisma.ratingEvent.create({
    data: {
      createdById: submitterId,
      sourceEventId: sourceEventId || null,
      name,
      description: cleanText(payload.description) || null,
      imageUrl: cleanText(payload.imageUrl) || null,
    },
  });
};

const createIDFromSubmission = async (payload: Prisma.JsonObject, submitterId: string) => {
  const songName = cleanText(payload.songName) || cleanText(payload.title);
  if (!songName) throw new Error('ID 名称不能为空');
  const audioUrl = cleanText(payload.audioUrl);
  const videoUrl = cleanText(payload.videoUrl);
  const eventName = cleanText(payload.eventName);
  const djNames = stringArray(payload.djNames);
  const boundDjIds = stringArray(payload.boundDjIds);
  const boundEventIds = stringArray(payload.boundEventIds);
  return prisma.$transaction(async (tx) => {
    const post = await tx.post.create({
      data: {
        userId: submitterId,
        content: [
          '#RAVER_ID',
          `标题：${songName}`,
          djNames.length > 0 ? `艺人：${djNames.join(', ')}` : (cleanText(payload.artistName) ? `艺人：${cleanText(payload.artistName)}` : null),
          eventName ? `活动：${eventName}` : null,
          audioUrl ? `音频：${audioUrl}` : null,
          videoUrl ? `视频：${videoUrl}` : null,
          cleanText(payload.description) ? `描述：${cleanText(payload.description)}` : null,
        ].filter(Boolean).join('\n'),
        images: stringArray(payload.images),
        type: 'general',
        visibility: 'public',
        displayPublishedAt: new Date(),
      } as any,
    });
    await syncPostBindings(tx, post.id, {
      djIds: boundDjIds,
      eventIds: boundEventIds,
    });
    return post;
  });
};

const createEntityFromSubmission = async (
  entityType: string,
  payload: Prisma.JsonObject,
  submitterId: string,
  options: {
    submissionId?: string;
  } = {}
) => {
  switch (entityType) {
    case 'event':
      return createOrUpdateEventFromSubmission(prisma, payload, submitterId, options);
    case 'dj':
      return createOrUpdateDJFromSubmission(prisma, payload, submitterId);
    case 'news':
      return createNewsFromSubmission(payload, submitterId);
    case 'set':
      return createSetFromSubmission(payload, submitterId);
    case 'brand':
      return createBrandFromSubmission(payload, submitterId);
    case 'label':
      return createLabelFromSubmission(payload);
    case 'rating':
      return createRatingFromSubmission(payload, submitterId);
    case 'id':
      return createIDFromSubmission(payload, submitterId);
    default:
      throw new Error(`暂不支持审核类型：${entityType}`);
  }
};

const publishSubmissionStatusNotification = async (input: {
  userId: string;
  entityType: string;
  status: 'processing' | 'reviewing' | 'approved' | 'rejected' | 'failed';
  title: string;
  submissionId: string;
  reason?: string | null;
  createdEntityId?: string | null;
  payload?: Prisma.InputJsonObject | Prisma.JsonObject;
}) => {
  const typeLabelMap: Record<string, string> = {
    event: '活动',
    dj: 'DJ',
    news: '资讯',
    set: 'Set',
    brand: '品牌',
    label: '厂牌',
    id: 'ID',
    rating: '打分',
  };
  const typeLabel = typeLabelMap[input.entityType] || '内容';
  const statusLabelMap = {
    processing: { zh: '处理中', en: 'processing', ja: '処理中' },
    reviewing: { zh: '审核中', en: 'in review', ja: '審査中' },
    approved: { zh: '已入库', en: 'approved', ja: '入庫済み' },
    rejected: { zh: '未通过', en: 'rejected', ja: '未承認' },
    failed: { zh: '处理失败', en: 'failed', ja: '処理失敗' },
  } as const;
  const statusLabels = statusLabelMap[input.status];
  const changeSummary = changeSummaryTextFromPayload(input.payload);
  const titleI18n = {
    zh: `${typeLabel}提交${statusLabels.zh}`,
    en: `${typeLabel} submission ${statusLabels.en}`,
    ja: `${typeLabel}の投稿${statusLabels.ja}`,
  };
  const bodyI18n = {
    zh:
      input.status === 'processing'
        ? `你提交的「${input.title}」已进入处理队列。`
        : input.status === 'reviewing'
          ? `你提交的「${input.title}」已完成处理，正在审核中。`
          : input.status === 'approved'
            ? `你提交的「${input.title}」已审核通过，内容已入库。`
            : input.status === 'failed'
              ? `你提交的「${input.title}」处理失败：${input.reason || '请稍后重试或联系支持。'}`
              : `你提交的「${input.title}」未通过审核：${input.reason || '请补充更准确的信息后重新提交。'}`,
    en:
      input.status === 'processing'
        ? `Your submission "${input.title}" has entered the processing queue.`
        : input.status === 'reviewing'
          ? `Your submission "${input.title}" finished processing and is now under review.`
          : input.status === 'approved'
            ? `Your submission "${input.title}" was approved and added to Raver.`
            : input.status === 'failed'
              ? `Your submission "${input.title}" failed during processing: ${input.reason || 'Please retry later or contact support.'}`
              : `Your submission "${input.title}" was rejected: ${input.reason || 'Please add more accurate details and submit again.'}`,
    ja:
      input.status === 'processing'
        ? `投稿「${input.title}」は処理キューに入りました。`
        : input.status === 'reviewing'
          ? `投稿「${input.title}」の処理が完了し、現在審査中です。`
          : input.status === 'approved'
            ? `投稿「${input.title}」が承認され、Raver に追加されました。`
            : input.status === 'failed'
              ? `投稿「${input.title}」の処理に失敗しました：${input.reason || '後でもう一度お試しいただくか、サポートへお問い合わせください。'}`
              : `投稿「${input.title}」は承認されませんでした：${input.reason || 'より正確な情報を追加して再送信してください。'}`,
  };
  if (changeSummary) {
    bodyI18n.zh = `${bodyI18n.zh}\n变更摘要：${changeSummary}`;
    bodyI18n.en = `${bodyI18n.en}\nChange summary: ${changeSummary}`;
    bodyI18n.ja = `${bodyI18n.ja}\n変更概要：${changeSummary}`;
  }
  await notificationCenterService.publish({
    category: 'content_review',
    targets: [{ userId: input.userId }],
    channels: ['in_app', 'apns'],
    dedupeKey: `content_submission:${input.submissionId}:${input.status}`,
    payload: {
      title: resolveLocalizedText(titleI18n, titleI18n.zh, ['ja', 'en', 'zh']),
      body: resolveLocalizedText(bodyI18n, bodyI18n.zh, ['ja', 'en', 'zh']),
      deeplink: input.status === 'approved' && input.createdEntityId
        ? `/${input.entityType}s/${input.createdEntityId}`
        : `/profile/submissions/${input.submissionId}`,
      metadata: {
        source: 'content_submission_review',
        titleI18n,
        bodyI18n,
        message: resolveLocalizedText(bodyI18n, bodyI18n.zh, ['ja', 'en', 'zh']),
        submissionId: input.submissionId,
        entityType: input.entityType,
        status: input.status,
        reason: input.reason || null,
        reasonCode: input.reason || null,
        createdEntityId: input.createdEntityId || null,
        typeLabel,
        statusLabel: statusLabels.zh,
      },
    },
  });
};

router.post('/', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }
    const entityType = cleanText(req.body.entityType)?.toLowerCase();
    if (!entityType || !ENTITY_TYPES.has(entityType)) {
      res.status(400).json({ error: 'entityType 不支持' });
      return;
    }
    const rawPayload = toJsonObject(req.body.payload);
    const normalizedPayload = entityType === 'event' ? normalizeEventSubmissionPayload(rawPayload) : rawPayload;
    if (entityType === 'event') {
      await assertEventSubmissionBaseRevision(
        prisma,
        normalizedPayload as unknown as Prisma.JsonObject
      );
    }
    const payloadWithSummary = attachContentSubmissionChangeSummary(entityType, normalizedPayload);
    const validationError = ensureSubmissionPayload(entityType, payloadWithSummary);
    if (validationError) {
      res.status(400).json({ error: validationError });
      return;
    }

    const submission = await createSubmissionWithVersion({
      submitterId: userId,
      entityType,
      title: titleFromPayload(entityType, payloadWithSummary),
      payload: payloadWithSummary,
    });

    await scheduleContentSubmissionProcessingBestEffort(submission.id);
    await publishSubmissionStatusNotification({
      userId,
      entityType,
      status: 'processing',
      title: submission.title,
      submissionId: submission.id,
      payload: payloadWithSummary,
    });

    res.status(201).json({
      message: '任务已提交，当前正在处理中',
      submission,
    });
  } catch (error) {
    console.error('Create content submission error:', error);
    if (error instanceof EventSubmissionConflictError) {
      res.status(409).json({ error: error.message, code: error.code });
      return;
    }
    res.status(500).json({ error: '提交审核失败' });
  }
});

router.get('/mine', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }
    const page = parsePage(req.query.page, 1);
    const limit = parseLimit(req.query.limit);
    const where = { submitterId: userId };
    const [items, total] = await Promise.all([
      prisma.contentSubmission.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
      prisma.contentSubmission.count({ where }),
    ]);
    res.json({
      items,
      data: { items },
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit) || 1,
      },
    });
  } catch (error) {
    console.error('List my content submissions error:', error);
    res.status(500).json({ error: '获取我的提交失败' });
  }
});

router.get('/mine/:id', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }
    const submissionId = cleanText(req.params.id);
    if (!submissionId) {
      res.status(400).json({ error: '提交 ID 不能为空' });
      return;
    }

    const submission = await prisma.contentSubmission.findFirst({
      where: { id: submissionId, submitterId: userId },
      include: {
        versions: {
          orderBy: { version: 'desc' },
        },
      },
    });
    if (!submission) {
      res.status(404).json({ error: '提交记录不存在' });
      return;
    }
    res.json({ submission });
  } catch (error) {
    console.error('Get my content submission error:', error);
    res.status(500).json({ error: '获取提交详情失败' });
  }
});

router.patch('/mine/:id', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }
    const submissionId = cleanText(req.params.id);
    if (!submissionId) {
      res.status(400).json({ error: '提交 ID 不能为空' });
      return;
    }

    const changeNote = cleanText(req.body.changeNote);
    const current = await prisma.contentSubmission.findFirst({
      where: { id: submissionId, submitterId: userId },
    });
    if (!current) {
      res.status(404).json({ error: '提交记录不存在' });
      return;
    }
    if (current.status === 'approved') {
      res.status(409).json({ error: '已审核通过的内容不能重新提交' });
      return;
    }
    const rawPayload = toJsonObject(req.body.payload);
    const normalizedPayload = current.entityType === 'event' ? normalizeEventSubmissionPayload(rawPayload) : rawPayload;
    const payload = attachContentSubmissionChangeSummary(current.entityType, normalizedPayload);

    const validationError = ensureSubmissionPayload(current.entityType, payload);
    if (validationError) {
      res.status(400).json({ error: validationError });
      return;
    }

    const title = titleFromPayload(current.entityType, payload);
    const updated = await prisma.$transaction(async (tx) => {
      const latest = await (tx as any).contentSubmissionVersion.findFirst({
        where: { submissionId: current.id },
        orderBy: { version: 'desc' },
        select: { version: true },
      });
      const nextVersion = Number(latest?.version || 0) + 1;

      await (tx as any).contentSubmissionVersion.create({
        data: {
          submissionId: current.id,
          version: nextVersion,
          title,
          payload,
          submittedBy: userId,
          changeNote: changeNote || 'Resubmitted by user',
        },
      });

      return tx.contentSubmission.update({
        where: { id: current.id },
      data: {
          title,
          payload,
          status: 'processing',
          reviewReason: null,
          reviewNotes: buildI18nReviewNotes(current.entityType, payload),
          reviewedAt: null,
          reviewedBy: null,
          createdEntityId: null,
        },
        include: {
          versions: {
            orderBy: { version: 'desc' },
          },
        },
      });
    });

    await scheduleContentSubmissionProcessingBestEffort(updated.id);
    await publishSubmissionStatusNotification({
      userId,
      entityType: current.entityType,
      status: 'processing',
      title: updated.title,
      submissionId: updated.id,
      payload,
    });

    res.json({
      message: '任务已重新提交，当前正在处理中',
      submission: updated,
    });
  } catch (error) {
    console.error('Resubmit my content submission error:', error);
    res.status(500).json({ error: '重新提交失败' });
  }
});

router.get('/admin', authenticate, requireAdminOrOperator, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const status = cleanText(req.query.status)?.toLowerCase();
    const entityType = cleanText(req.query.entityType)?.toLowerCase();
    const i18nStatus = cleanText(req.query.i18nStatus)?.toLowerCase();
    const missingLocale = cleanText(req.query.missingLocale)?.toLowerCase();
    const translationStatus = cleanText(req.query.translationStatus)?.toLowerCase();
    const where: Prisma.ContentSubmissionWhereInput = {};
    const andFilters: Prisma.ContentSubmissionWhereInput[] = [];
    if (status && STATUSES.has(status)) where.status = status;
    if (entityType && ENTITY_TYPES.has(entityType)) where.entityType = entityType;
    if (i18nStatus) {
      andFilters.push({ reviewNotes: {
        path: ['i18n', 'status'],
        equals: i18nStatus,
      } as any });
    }
    if (missingLocale === 'ja' || missingLocale === 'en' || missingLocale === 'zh') {
      andFilters.push({ reviewNotes: {
        path: ['i18n', 'missingLocales'],
        array_contains: [missingLocale],
      } as any });
    }
    if (translationStatus === 'needs_manual_confirmation') {
      andFilters.push({ reviewNotes: {
        path: ['i18n', 'status'],
        equals: 'needs_manual_confirmation',
      } as any });
    }
    if (andFilters.length > 0) where.AND = andFilters;

    const [items, total] = await prisma.$transaction([
      prisma.contentSubmission.findMany({
        where,
        include: {
          submitter: {
            select: { id: true, username: true, displayName: true, avatarUrl: true },
          },
        },
        orderBy: { createdAt: 'desc' },
        take: parseLimit(req.query.limit),
      }),
      prisma.contentSubmission.count({ where }),
    ]);
    res.json({ items, total });
  } catch (error) {
    console.error('List admin content submissions error:', error);
    res.status(500).json({ error: '获取审核列表失败' });
  }
});

router.get('/admin/:id', authenticate, requireAdminOrOperator, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const submissionId = cleanText(req.params.id);
    if (!submissionId) {
      res.status(400).json({ error: '提交 ID 不能为空' });
      return;
    }

    const submission = await prisma.contentSubmission.findUnique({
      where: { id: submissionId },
      include: {
        submitter: {
          select: { id: true, username: true, displayName: true, avatarUrl: true },
        },
        versions: {
          orderBy: { version: 'desc' },
        },
      },
    });
    if (!submission) {
      res.status(404).json({ error: '提交记录不存在' });
      return;
    }

    res.json({ submission });
  } catch (error) {
    console.error('Get admin content submission error:', error);
    res.status(500).json({ error: '获取审核详情失败' });
  }
});

router.post('/admin/:id/review', authenticate, requireAdminOrOperator, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const actorId = req.user?.userId;
    if (!actorId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }
    const decision = cleanText(req.body.decision)?.toLowerCase();
    const reason = cleanText(req.body.reason);
    const reviewNotes = toOptionalJsonObject(req.body.reviewNotes);
    if (decision !== 'approved' && decision !== 'rejected') {
      res.status(400).json({ error: 'decision 必须是 approved 或 rejected' });
      return;
    }

    const submissionId = cleanText(req.params.id);
    if (!submissionId) {
      res.status(400).json({ error: '提交 ID 不能为空' });
      return;
    }

    const current = await prisma.contentSubmission.findUnique({
      where: { id: submissionId },
      include: { submitter: { select: { id: true } } },
    });
    if (!current) {
      res.status(404).json({ error: '提交记录不存在' });
      return;
    }
    if (!ACTIVE_REVIEWABLE_STATUSES.has(current.status)) {
      res.status(409).json({ error: '该提交已审核，不能重复处理' });
      return;
    }

    let createdEntityId: string | null = null;
    if (decision === 'approved') {
      const payload = current.payload as Prisma.JsonObject;
      const created = await createEntityFromSubmission(current.entityType, payload, current.submitterId, {
        submissionId: current.id,
      });
      createdEntityId = created.id;
      if (current.entityType === 'dj' && createdEntityId) {
        try {
          await djEventBindingReviewService.createJobForDJ(createdEntityId, {
            triggerSource: 'content_submission_approved',
            createdById: actorId,
          });
        } catch (jobError) {
          console.error('Create DJ event binding review job after submission approval failed:', {
            submissionId: current.id,
            djId: createdEntityId,
            actorId,
            error: jobError,
          });
        }
      }
    }

    const updated = await prisma.contentSubmission.update({
      where: { id: current.id },
      data: {
        status: decision,
        reviewReason: reason || null,
        ...(reviewNotes ? { reviewNotes } : {}),
        reviewedAt: new Date(),
        reviewedBy: actorId,
        createdEntityId,
      } as any,
      include: {
        submitter: {
          select: { id: true, username: true, displayName: true, avatarUrl: true },
        },
      },
    });

    await adminAuditService.createAction({
      actorId,
      action: `content_submission.${decision}`,
      targetType: 'content_submission',
      targetId: current.id,
      detail: {
        entityType: current.entityType,
        title: current.title,
        reason: reason || null,
        reviewNotes: reviewNotes || null,
        createdEntityId,
      },
    });

    await publishSubmissionStatusNotification({
      userId: current.submitterId,
      entityType: current.entityType,
      status: decision,
      title: current.title,
      submissionId: current.id,
      reason: reason || null,
      createdEntityId,
    });

    res.json({ message: decision === 'approved' ? '审核通过，内容已入库' : '审核未通过，结果已反馈给用户', submission: updated });
  } catch (error) {
    console.error('Review content submission error:', error);
    if (error instanceof EventSubmissionConflictError) {
      res.status(409).json({ error: error.message, code: error.code });
      return;
    }
    res.status(500).json({ error: error instanceof Error ? error.message : '审核处理失败' });
  }
});

export default router;
