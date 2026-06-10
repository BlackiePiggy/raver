import { Router, Request, Response, NextFunction } from 'express';
import { PrismaClient, Prisma } from '@prisma/client';
import OSS from 'ali-oss';
import axios, { AxiosRequestConfig } from 'axios';
import multer from 'multer';
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import jpeg from 'jpeg-js';
import { PNG } from 'pngjs';
import { commentService } from '../modules/feed';
import {
  djSetService,
  spotifyArtistService,
  SpotifyUpstreamError,
  discogsArtistService,
  DiscogsUpstreamError,
  soundcloudArtistService,
  SoundCloudUpstreamError,
} from '../modules/music';
import { verifyToken, type JWTPayload } from '../utils/auth';
import { rebuildUserCheckinProjection } from '../services/checkin-projection';
import {
  loadCanonicalEventLineupSnapshot,
  normalizeCanonicalLineupArtists,
  syncCanonicalEventLineupAndTimetable,
} from '../services/event-lineup-canonical.service';
import { adminSummaryCache } from '../infrastructure/admin-summary-cache';
import {
  USER_ENTITY_RELATION_FAVORITE,
  USER_ENTITY_RELATION_FOLLOW,
  USER_ENTITY_TARGET_DJ,
  USER_ENTITY_TARGET_EVENT,
  deleteUserEntityRelation,
  upsertUserEntityRelation,
  userEntityFollowWhere,
} from '../services/user-entity-follow.service';
import {
  normalizeCountryBiTextPayload,
} from '../utils/country-i18n';
import {
  analyzeI18nCompleteness,
  normalizeTriTextPayload,
  resolveTriTextWithFallback,
  type TriTextPayload,
} from '../utils/i18n';
import {
  DEFAULT_EVENT_TIME_ZONE,
  isValidEventTimeZone,
  normalizeEventTimeZone,
  startOfEventDay,
  storageDateToEventDate,
} from '../utils/event-timezone';
import {
  buildEventStatusWhere,
  deriveEventStatus,
  resolveEventTruth,
} from '../utils/event-status';
import {
  resolveEventActivityAddressText,
  resolveEventVenueDisplayAddressText,
} from '../utils/event-address';
import { regionalCompliance, type RegionalComplianceUser } from '../config/regional-compliance';
import { getServerCozeRuntimeConfig } from '../config/runtime-coze-config';
import { contentCompliance } from '../utils/content-compliance';
import {
  INPUT_LIMITS,
  normalizeMultiline,
  normalizeOptionalMultiline,
  normalizeOptionalSingleLine,
  normalizeSingleLine,
  normalizeStringArray,
} from '../utils/input-rules';
import {
  collectLabelFounderDjIds,
  hydrateLabelFounders,
  labelFoundersToJson,
  normalizeLabelFounders,
} from '../utils/label-founders';
import {
  saveBufferToLocalUploads,
  shouldAllowLocalUploadFallback,
} from '../services/media-storage.service';
import { mediaAssetService } from '../services/media-asset.service';
import { notificationCenterService } from '../services/notification-center';
import { adminAuditService } from '../modules/admin/admin-audit.service';
import { djEventBindingReviewService, type DJEventBindingTriggerSource } from '../services/dj-event-binding-review.service';
import {
  CONTENT_SUBMISSION_EVENT_TIMETABLE_JOB_TYPE,
  enqueueContentSubmissionProcessingJob,
  publishContentSubmissionTaskNotification,
  scheduleContentSubmissionProcessingBestEffort,
} from '../services/content-submission-processing.service';
import {
  attachContributionInfo,
  buildContributorSummary,
  emptyContributorInfo,
  fetchContributionCenterSummary,
  fetchContributorEntriesForEntity,
  fetchContributorInfoMap,
  fetchContributionHistoryPage,
  InvalidContributionHistoryCursorError,
  isContributorForEntity,
  recordDJContribution,
  type ContributionHistoryFilter,
  type ContributorInfo,
  type ContributorRegistryEntry,
} from '../services/contribution.service';
import {
  assertBrandSubmissionBaseRevision,
  bindBrandDraftMediaToSubmission,
  BrandSubmissionConflictError,
  buildBrandSubmissionReviewNotes,
  cleanupOrphanedBrandDraftMediaAfterSubmission,
  normalizeBrandSubmissionPayload,
} from '../services/content-submission-brand.service';
import {
  ActiveEventEditSubmissionError,
  assertNoActiveEventEditSubmission,
  autoAlignEventLineupToTimetablePayload,
  bindEventDraftMediaToSubmission,
  buildSubmittedEventScheduleContextFromEvent,
  buildAlignedLineupArtistsFromTimetablePayload,
  createOrUpdateEventFromSubmission,
  EventSubmissionValidationError,
  formatEventLineupTimetableAlignmentError,
  incrementallyFillEventLineupFromTimetablePayload,
  normalizeSubmittedEventScheduleContext,
  normalizeSubmittedTimetableSlots,
  validateEventLineupTimetableAlignment,
} from '../services/content-submission-event.service';

const router: Router = Router();
const prisma = new PrismaClient();
const cityTimezones = require('city-timezones') as {
  lookupViaCity: (city: string) => unknown[];
  findFromCityStateProvince: (query: string) => unknown[];
};

const learnFestivalListSelect = {
  id: true,
  name: true,
  nameI18n: true,
  sourceRowId: true,
  abbreviation: true,
  aliases: true,
  country: true,
  countryI18n: true,
  city: true,
  cityI18n: true,
  foundedYear: true,
  frequency: true,
  frequencyI18n: true,
  tagline: true,
  introduction: true,
  descriptionI18n: true,
  manualLocation: true,
  locationPoint: true,
  officialWebsite: true,
  facebookUrl: true,
  instagramUrl: true,
  twitterUrl: true,
  youtubeUrl: true,
  tiktokUrl: true,
  avatarUrl: true,
  backgroundUrl: true,
  links: true,
  revision: true,
  createdAt: true,
  updatedAt: true,
} satisfies Prisma.WikiFestivalSelect;

const normalizeWikiBrandImageAssetType = (value: unknown): string => {
  const normalized = typeof value === 'string' ? value.trim().toLowerCase() : '';
  switch (normalized) {
    case 'avatar':
    case 'background':
    case 'poster':
    case 'proof':
      return normalized;
    default:
      return 'other';
  }
};

const wikiBrandImageAssetLabel = (type: string): string => {
  switch (type) {
    case 'avatar':
      return 'Avatar';
    case 'background':
      return 'Background';
    case 'poster':
      return 'Poster';
    case 'proof':
      return 'Proof';
    default:
      return 'Other';
  }
};

const wikiBrandImageAssetFileName = (
  asset: {
    url: string;
    objectKey: string | null;
    metadata: Prisma.JsonValue | null;
  }
): string => {
  const metadata = asset.metadata && typeof asset.metadata === 'object' && !Array.isArray(asset.metadata)
    ? (asset.metadata as Record<string, unknown>)
    : null;
  const originalName = typeof metadata?.originalName === 'string' ? metadata.originalName.trim() : '';
  if (originalName) return originalName;
  const objectKey = typeof asset.objectKey === 'string' ? asset.objectKey.trim() : '';
  if (objectKey) return path.basename(objectKey);
  return path.basename(asset.url.split('?')[0] || asset.url);
};

const wikiBrandImageAssetSort = (
  asset: {
    metadata: Prisma.JsonValue | null;
    createdAt?: Date | string | null;
  },
  fallbackSort: number
): number => {
  const metadata = asset.metadata && typeof asset.metadata === 'object' && !Array.isArray(asset.metadata)
    ? (asset.metadata as Record<string, unknown>)
    : null;
  const rawSort = metadata?.sort;
  if (typeof rawSort === 'number' && Number.isFinite(rawSort)) {
    return Math.max(0, Math.trunc(rawSort));
  }
  return fallbackSort;
};

const mapWikiBrandMediaAsset = (
  asset: {
    purpose: string;
    url: string;
    objectKey: string | null;
    metadata: Prisma.JsonValue | null;
    createdAt?: Date | string | null;
  },
  fallbackSort: number
) => {
  const type = normalizeWikiBrandImageAssetType(asset.purpose);
  const sort = wikiBrandImageAssetSort(asset, fallbackSort);
  const metadata = asset.metadata && typeof asset.metadata === 'object' && !Array.isArray(asset.metadata)
    ? (asset.metadata as Record<string, unknown>)
    : null;
  const source = typeof metadata?.source === 'string' && metadata.source.trim().length > 0
    ? metadata.source.trim()
    : 'media_asset';

  return {
    url: asset.url,
    type,
    label: wikiBrandImageAssetLabel(type),
    sort,
    order: sort + 1,
    source,
    fileName: wikiBrandImageAssetFileName(asset),
  };
};

const loadWikiFestivalImageAssets = async (
  brandIds: string[]
): Promise<Map<string, ReturnType<typeof mapWikiBrandMediaAsset>[]>> => {
  const uniqueIds = Array.from(new Set(brandIds.map((item) => item.trim()).filter(Boolean)));
  if (!uniqueIds.length) return new Map();

  const assets = await prisma.mediaAsset.findMany({
    where: {
      ownerType: 'wiki_brand',
      ownerId: { in: uniqueIds },
      status: 'active',
    },
    orderBy: [
      { ownerId: 'asc' },
      { createdAt: 'asc' },
    ],
    select: {
      ownerId: true,
      purpose: true,
      url: true,
      objectKey: true,
      metadata: true,
      createdAt: true,
    },
  });

  const grouped = new Map<string, ReturnType<typeof mapWikiBrandMediaAsset>[]>();
  const sortCounters = new Map<string, number>();

  for (const asset of assets) {
    const ownerId = typeof asset.ownerId === 'string' ? asset.ownerId.trim() : '';
    if (!ownerId) continue;
    const nextFallbackSort = sortCounters.get(ownerId) ?? 0;
    const mapped = mapWikiBrandMediaAsset(asset, nextFallbackSort);
    const bucket = grouped.get(ownerId) ?? [];
    bucket.push(mapped);
    grouped.set(ownerId, bucket);
    sortCounters.set(ownerId, Math.max(nextFallbackSort + 1, mapped.sort + 1));
  }

  for (const [ownerId, rows] of grouped.entries()) {
    grouped.set(ownerId, rows.sort((left, right) => {
      const leftSort = typeof left.sort === 'number' ? left.sort : Number.MAX_SAFE_INTEGER;
      const rightSort = typeof right.sort === 'number' ? right.sort : Number.MAX_SAFE_INTEGER;
      if (leftSort !== rightSort) return leftSort - rightSort;
      return left.url.localeCompare(right.url);
    }));
  }

  return grouped;
};

const attachWikiFestivalImageAssets = <T extends { id: string }>(
  rows: T[],
  imageAssetsByBrandId: Map<string, ReturnType<typeof mapWikiBrandMediaAsset>[]>
): Array<T & { brandImageAssets: ReturnType<typeof mapWikiBrandMediaAsset>[] | null }> =>
  rows.map((row) => ({
    ...row,
    brandImageAssets: imageAssetsByBrandId.get(row.id) ?? null,
  }));

const refreshUserCheckinProjectionBestEffort = async (userId: string): Promise<void> => {
  try {
    await rebuildUserCheckinProjection(prisma, userId);
  } catch (error) {
    console.error('BFF web refresh checkin projection failed:', error);
  }
};

const countUserWatchedDJ = async (userId: string, djId: string): Promise<number> => {
  const [aggregate, directCheckinCount, selectionRows] = await Promise.all([
    prisma.userCheckinGalleryDJAggregate.findFirst({
      where: {
        userId,
        scope: 'all',
        djId,
      },
      select: {
        count: true,
      },
      orderBy: [
        { count: 'desc' },
        { latestAttendedAt: 'desc' },
      ],
    }),
    prisma.checkin.count({
      where: {
        userId,
        status: 'active',
        type: 'dj',
        djId,
        OR: [{ note: null }, { note: { not: 'marked' } }],
      },
    }),
    prisma.checkinSelectionDJ.findMany({
      where: {
        djId,
        selection: {
          checkin: {
            userId,
            status: 'active',
            OR: [{ note: null }, { note: { not: 'marked' } }],
          },
        },
      },
      select: {
        selection: {
          select: {
            checkinId: true,
            dayId: true,
          },
        },
      },
    }),
  ]);

  const selectedSlots = new Set(
    selectionRows.map((row) => `${row.selection.checkinId}:${row.selection.dayId}`)
  ).size;
  const realtimeCount = directCheckinCount + selectedSlots;
  return Math.max(0, Number(aggregate?.count ?? 0) || 0, realtimeCount);
};

interface BFFAuthRequest extends Request {
  user?: JWTPayload;
  authUserId?: string;
  authAccountStatus?: 'active' | 'inactive' | 'missing';
}

const optionalAuth = async (req: Request, _res: Response, next: NextFunction): Promise<void> => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    next();
    return;
  }

  const token = authHeader.substring(7);
  try {
    const decoded = verifyToken(token);
    const authReq = req as BFFAuthRequest;
    const user = await prisma.user.findUnique({
      where: { id: decoded.userId },
      select: { id: true, email: true, role: true, isActive: true },
    });
    authReq.authUserId = decoded.userId;
    authReq.authAccountStatus = !user ? 'missing' : user.isActive ? 'active' : 'inactive';
    if (user?.isActive) {
      authReq.user = {
          ...decoded,
          email: user.email,
          role: user.role,
        };
    }
  } catch (_error) {
    // Ignore invalid token for public endpoints.
  }

  next();
};

const requireAuth = (req: BFFAuthRequest, res: Response): string | null => {
  const userId = req.user?.userId;
  if (!userId) {
    res.status(401).json({ error: 'Unauthorized' });
    return null;
  }
  if (req.authAccountStatus && req.authAccountStatus !== 'active') {
    res.status(401).json({
      error: 'Account is no longer active',
      code: 'ACCOUNT_INACTIVE',
      accountStatus: req.authAccountStatus === 'inactive' ? 'deleted' : 'missing',
    });
    return null;
  }
  return userId;
};

const requireAdminOrOperatorUserId = (req: BFFAuthRequest, res: Response): string | null => {
  const userId = requireAuth(req, res);
  if (!userId) return null;
  const role = req.user?.role ?? null;
  if (role !== 'admin' && role !== 'operator') {
    res.status(403).json({ error: 'Forbidden' });
    return null;
  }
  return userId;
};

const resolveRegionalComplianceUser = async (userId?: string | null): Promise<RegionalComplianceUser | null> => {
  if (!userId) return null;
  return prisma.user.findUnique({
    where: { id: userId },
    select: { regionCode: true, ageBand: true },
  });
};

const canBypassContentReview = (role?: string | null): boolean =>
  role === 'admin' || role === 'operator';

const createDJEventBindingReviewJobBestEffort = async (
  djId: string,
  input: {
    triggerSource: DJEventBindingTriggerSource;
    createdById?: string | null;
  }
): Promise<void> => {
  try {
    await djEventBindingReviewService.createJobForDJ(djId, input);
  } catch (error) {
    console.error('BFF web create DJ event binding review job failed:', {
      djId,
      triggerSource: input.triggerSource,
      createdById: input.createdById ?? null,
      error,
    });
  }
};

type CityTimezoneLookupRow = {
  city: string;
  city_ascii?: string;
  country?: string;
  iso2?: string;
  iso3?: string;
  province?: string;
  exactCity?: string;
  exactProvince?: string;
  state_ansi?: string;
  timezone?: string;
  lat?: number;
  lng?: number;
  pop?: number;
};

type EventTimezoneLookupItem = {
  city: string;
  cityAscii: string;
  province: string;
  exactProvince: string;
  stateAnsi: string;
  country: string;
  iso2: string;
  iso3: string;
  timezone: string;
  lat: number | null;
  lng: number | null;
  population: number | null;
  label: string;
  searchRank: number;
  matchSource: 'exact-city' | 'city-region-search';
};

type SubmittedEventTimezoneSelection = {
  city: string;
  province: string;
  country: string;
  stateAnsi: string;
  lat: number | null;
  lng: number | null;
};

const normalizeCityTimezoneText = (value: unknown): string =>
  String(value ?? '')
    .trim()
    .replace(/\s+/g, ' ');

const toFiniteNumberOrNull = (value: unknown): number | null => {
  const numeric = Number(value);
  return Number.isFinite(numeric) ? numeric : null;
};

const buildEventTimezoneLookupLabel = (item: {
  city: string;
  province?: string;
  exactProvince?: string;
  stateAnsi?: string;
  country?: string;
  timezone: string;
}): string => {
  const parts = [
    normalizeCityTimezoneText(item.city),
    normalizeCityTimezoneText(item.exactProvince || item.stateAnsi || item.province || ''),
    normalizeCityTimezoneText(item.country || ''),
  ].filter(Boolean);
  return `${parts.join(', ')} · ${item.timezone}`;
};

const toEventTimezoneLookupItem = (
  row: unknown,
  query: string,
  matchSource: 'exact-city' | 'city-region-search'
): EventTimezoneLookupItem | null => {
  if (!row || typeof row !== 'object' || Array.isArray(row)) return null;
  const source = row as CityTimezoneLookupRow;
  const timezone = normalizeCityTimezoneText(source.timezone);
  const city = normalizeCityTimezoneText(source.city);
  if (!city || !timezone || !isValidEventTimeZone(timezone)) return null;

  const cityAscii = normalizeCityTimezoneText(source.city_ascii || city);
  const province = normalizeCityTimezoneText(source.province);
  const exactProvince = normalizeCityTimezoneText(source.exactProvince || province);
  const stateAnsi = normalizeCityTimezoneText(source.state_ansi);
  const country = normalizeCityTimezoneText(source.country);
  const iso2 = normalizeCityTimezoneText(source.iso2).toUpperCase();
  const iso3 = normalizeCityTimezoneText(source.iso3).toUpperCase();
  const normalizedQuery = normalizeCityTimezoneText(query).toLowerCase();
  const normalizedCity = city.toLowerCase();
  const normalizedAscii = cityAscii.toLowerCase();
  const exactCity = normalizeCityTimezoneText(source.exactCity || city).toLowerCase();

  let searchRank = matchSource === 'exact-city' ? 0 : 20;
  if (normalizedQuery && (
    normalizedCity === normalizedQuery
    || normalizedAscii === normalizedQuery
    || exactCity === normalizedQuery
  )) {
    searchRank -= 10;
  }
  if (stateAnsi) searchRank -= 1;
  const population = toFiniteNumberOrNull(source.pop);
  if (population) {
    searchRank -= Math.min(5, Math.floor(Math.log10(Math.max(1, population))));
  }

  return {
    city,
    cityAscii,
    province,
    exactProvince,
    stateAnsi,
    country,
    iso2,
    iso3,
    timezone,
    lat: toFiniteNumberOrNull(source.lat),
    lng: toFiniteNumberOrNull(source.lng),
    population,
    label: buildEventTimezoneLookupLabel({
      city,
      province,
      exactProvince,
      stateAnsi,
      country,
      timezone,
    }),
    searchRank,
    matchSource,
  };
};

const searchEventTimezonesByCity = (query: string, limitRaw: unknown): EventTimezoneLookupItem[] => {
  const searchQuery = normalizeCityTimezoneText(query);
  if (!searchQuery) return [];
  const limitParsed = Number(limitRaw);
  const limit = Number.isFinite(limitParsed)
    ? Math.max(1, Math.min(20, Math.floor(limitParsed)))
    : 8;

  const exactMatches = cityTimezones.lookupViaCity(searchQuery) || [];
  const broadMatches = cityTimezones.findFromCityStateProvince(searchQuery) || [];
  const merged = new Map<string, EventTimezoneLookupItem>();
  const push = (rows: unknown[], matchSource: 'exact-city' | 'city-region-search') => {
    for (const row of rows) {
      const item = toEventTimezoneLookupItem(row, searchQuery, matchSource);
      if (!item) continue;
      const key = [
        item.city.toLowerCase(),
        item.exactProvince.toLowerCase(),
        item.country.toLowerCase(),
        item.timezone.toLowerCase(),
      ].join('|');
      const existing = merged.get(key);
      if (!existing || item.searchRank < existing.searchRank) {
        merged.set(key, item);
      }
    }
  };
  push(exactMatches, 'exact-city');
  push(broadMatches, 'city-region-search');

  return Array.from(merged.values())
    .sort((a, b) => {
      if (a.searchRank !== b.searchRank) return a.searchRank - b.searchRank;
      const popA = a.population ?? -1;
      const popB = b.population ?? -1;
      if (popA !== popB) return popB - popA;
      return a.label.localeCompare(b.label, 'en', { sensitivity: 'base' });
    })
    .slice(0, limit);
};

const readSubmittedEventTimezoneSelection = (
  body: Record<string, unknown>
): SubmittedEventTimezoneSelection | null => {
  const city = normalizeCityTimezoneText(body.timeZoneCity);
  const province = normalizeCityTimezoneText(body.timeZoneProvince);
  const country = normalizeCityTimezoneText(body.timeZoneCountry);
  const stateAnsi = normalizeCityTimezoneText(body.timeZoneStateAnsi).toUpperCase();
  const lat = toFiniteNumberOrNull(body.timeZoneLat);
  const lng = toFiniteNumberOrNull(body.timeZoneLng);
  if (!city && !province && !country && !stateAnsi && lat === null && lng === null) return null;
  return {
    city,
    province,
    country,
    stateAnsi,
    lat,
    lng,
  };
};

const validateSubmittedEventTimezoneSelection = (
  body: Record<string, unknown>,
  submittedTimeZone: string
): string | null => {
  const selection = readSubmittedEventTimezoneSelection(body);
  if (!selection) return null;
  if (!selection.city) {
    return 'timeZoneCity is required when submitting city-based timezone metadata';
  }

  const query = [
    selection.city,
    selection.stateAnsi || selection.province,
    selection.country,
  ].filter(Boolean).join(' ').trim() || selection.city;

  const candidates = searchEventTimezonesByCity(query, 20);
  const cityLower = selection.city.toLowerCase();
  const provinceLower = selection.province.toLowerCase();
  const countryLower = selection.country.toLowerCase();
  const targetTimeZone = normalizeEventTimeZone(submittedTimeZone);
  const matched = candidates.find((item) => {
    if (item.timezone !== targetTimeZone) return false;
    const cityMatches = item.city.toLowerCase() === cityLower || item.cityAscii.toLowerCase() === cityLower;
    if (!cityMatches) return false;
    if (selection.stateAnsi && item.stateAnsi.toUpperCase() !== selection.stateAnsi) return false;
    if (provinceLower) {
      const itemProvince = (item.exactProvince || item.province || '').toLowerCase();
      if (itemProvince && itemProvince !== provinceLower) return false;
    }
    if (countryLower && item.country.toLowerCase() !== countryLower) return false;
    if (selection.lat !== null && item.lat !== null && Math.abs(item.lat - selection.lat) > 0.5) return false;
    if (selection.lng !== null && item.lng !== null && Math.abs(item.lng - selection.lng) > 0.5) return false;
    return true;
  });

  return matched ? null : 'Submitted event timezone does not match the selected city timezone result';
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

const buildI18nReviewNotes = (entityType: string, payload: Record<string, unknown>): Prisma.InputJsonObject => ({
  i18n: analyzeI18nCompleteness(payload, CONTENT_I18N_FIELDS_BY_ENTITY[entityType] || ['titleI18n']) as unknown as Prisma.InputJsonValue,
  compliance: contentCompliance.reviewNotes(entityType, payload),
});

const buildSubmissionReviewNotes = async (
  db: PrismaClient | Prisma.TransactionClient,
  entityType: string,
  payload: Record<string, unknown>
): Promise<Prisma.InputJsonObject> => {
  if (entityType !== 'brand') {
    return buildI18nReviewNotes(entityType, payload);
  }
  const brandScreening = await buildBrandSubmissionReviewNotes(
    db,
    payload as Prisma.JsonObject
  );
  return {
    ...buildI18nReviewNotes(entityType, payload),
    ...brandScreening,
  };
};

const cleanSubmittedBrandText = (value: unknown): string | null => {
  if (typeof value !== 'string') return null;
  const trimmed = normalizeSingleLine(value);
  return trimmed.length > 0 ? trimmed : null;
};

const normalizeSubmittedSingleLine = (value: unknown, max: number): string =>
  normalizeSingleLine(value).slice(0, max);

const firstFilledSubmittedText = (...values: unknown[]): string => {
  for (const value of values) {
    const normalized = normalizeSingleLine(value);
    if (normalized) return normalized;
  }
  return '';
};

const firstFilledSubmittedMultiline = (...values: unknown[]): string => {
  for (const value of values) {
    const normalized = normalizeMultiline(value);
    if (normalized) return normalized;
  }
  return '';
};

const normalizeSubmittedUrl = (value: unknown): string | null =>
  normalizeOptionalSingleLine(value, INPUT_LIMITS.common.url);

const normalizeSubmittedMultiline = (value: unknown, max: number): string | null =>
  normalizeOptionalMultiline(value, max);

const normalizeSubmittedId = (value: unknown): string | null =>
  normalizeOptionalSingleLine(value, INPUT_LIMITS.common.externalId);

const normalizeSubmittedStringArray = (
  value: unknown,
  options?: { itemMax?: number; maxItems?: number }
): string[] =>
  normalizeStringArray(value, options);

const isValidHttpUrl = (value: string | null | undefined): boolean => {
  if (!value) return false;
  try {
    const parsed = new URL(value);
    return parsed.protocol === 'http:' || parsed.protocol === 'https:';
  } catch {
    return false;
  }
};

const isValidGeneralUrl = (value: string | null | undefined): boolean => {
  if (!value) return false;
  if (value.startsWith('community://')) return true;
  return isValidHttpUrl(value);
};

const hasSubmittedBrandImageAssetType = (
  payload: Record<string, unknown>,
  acceptedTypes: Set<string>
): boolean =>
  Array.isArray(payload.imageAssets) && payload.imageAssets.some((item) => {
    if (!item || typeof item !== 'object' || Array.isArray(item)) return false;
    const row = item as Record<string, unknown>;
    const type = cleanSubmittedBrandText(row.type)?.toLowerCase() || 'other';
    return acceptedTypes.has(type) && Boolean(cleanSubmittedBrandText(row.url));
  });

const hasSubmittedBrandPrimaryVisual = (payload: Record<string, unknown>): boolean =>
  Boolean(cleanSubmittedBrandText(payload.avatarUrl))
  || Boolean(cleanSubmittedBrandText(payload.backgroundUrl))
  || hasSubmittedBrandImageAssetType(payload, new Set(['avatar', 'background', 'poster']));

const hasSubmittedBrandOfficialLink = (payload: Record<string, unknown>): boolean =>
  [
    payload.officialWebsite,
    payload.facebookUrl,
    payload.instagramUrl,
    payload.twitterUrl,
    payload.youtubeUrl,
    payload.tiktokUrl,
  ].some((item) => Boolean(cleanSubmittedBrandText(item)))
  || (Array.isArray(payload.links) && payload.links.some((item) => {
    if (!item || typeof item !== 'object' || Array.isArray(item)) return false;
    return Boolean(cleanSubmittedBrandText((item as Record<string, unknown>).url));
  }));

const hasSubmittedBrandProofImage = (payload: Record<string, unknown>): boolean =>
  Boolean(cleanSubmittedBrandText(payload.proofImageUrl))
  || hasSubmittedBrandImageAssetType(payload, new Set(['proof']));

const submittedBrandFlag = (value: unknown): boolean =>
  value === true || cleanSubmittedBrandText(value)?.toLowerCase() === 'true';

const validateBrandSubmissionPayload = (payload: Record<string, unknown>): string | null => {
  const name = normalizeSingleLine(payload.name);
  const country = firstFilledSubmittedText(payload.country, payload.countryI18n && (payload.countryI18n as Record<string, unknown>).zh, payload.countryI18n && (payload.countryI18n as Record<string, unknown>).en);
  const city = firstFilledSubmittedText(payload.city, payload.cityI18n && (payload.cityI18n as Record<string, unknown>).zh, payload.cityI18n && (payload.cityI18n as Record<string, unknown>).en);
  const abbreviation = normalizeSingleLine(payload.abbreviation);
  const foundedYear = normalizeSingleLine(payload.foundedYear);
  const frequency = firstFilledSubmittedText(payload.frequency, payload.frequencyI18n && (payload.frequencyI18n as Record<string, unknown>).zh, payload.frequencyI18n && (payload.frequencyI18n as Record<string, unknown>).en);
  const tagline = normalizeSingleLine(payload.tagline);
  const introduction = firstFilledSubmittedMultiline(payload.introduction, payload.description, payload.descriptionI18n && (payload.descriptionI18n as Record<string, unknown>).zh);

  if (!name) {
    return 'name is required';
  }
  if (name.length > INPUT_LIMITS.organizer.name) {
    return `name must be at most ${INPUT_LIMITS.organizer.name} characters`;
  }
  if (abbreviation.length > INPUT_LIMITS.organizer.abbreviation) {
    return `abbreviation must be at most ${INPUT_LIMITS.organizer.abbreviation} characters`;
  }
  if (country.length > INPUT_LIMITS.organizer.country) {
    return `country must be at most ${INPUT_LIMITS.organizer.country} characters`;
  }
  if (city.length > INPUT_LIMITS.organizer.city) {
    return `city must be at most ${INPUT_LIMITS.organizer.city} characters`;
  }
  if (foundedYear.length > INPUT_LIMITS.organizer.foundedYear) {
    return `foundedYear must be at most ${INPUT_LIMITS.organizer.foundedYear} characters`;
  }
  if (frequency.length > INPUT_LIMITS.organizer.frequency) {
    return `frequency must be at most ${INPUT_LIMITS.organizer.frequency} characters`;
  }
  if (tagline.length > INPUT_LIMITS.organizer.tagline) {
    return `tagline must be at most ${INPUT_LIMITS.organizer.tagline} characters`;
  }
  if (introduction.length > INPUT_LIMITS.organizer.introduction) {
    return `introduction must be at most ${INPUT_LIMITS.organizer.introduction} characters`;
  }
  try {
    for (const value of [
      normalizeSubmittedUrl(payload.avatarUrl),
      normalizeSubmittedUrl(payload.backgroundUrl),
      normalizeSubmittedUrl(payload.proofImageUrl),
      normalizeSubmittedUrl(payload.officialWebsite),
      normalizeSubmittedUrl(payload.facebookUrl),
      normalizeSubmittedUrl(payload.instagramUrl),
      normalizeSubmittedUrl(payload.twitterUrl),
      normalizeSubmittedUrl(payload.youtubeUrl),
      normalizeSubmittedUrl(payload.tiktokUrl),
    ]) {
      ensureOptionalHttpUrl(value, 'brand url');
    }
    if (Array.isArray(payload.links)) {
      for (const item of payload.links) {
        if (!item || typeof item !== 'object' || Array.isArray(item)) continue;
        const row = item as Record<string, unknown>;
        ensureOptionalHttpUrl(normalizeSubmittedUrl(row.url), 'links.url');
        const titleLength = normalizeSingleLine(row.title).length;
        if (titleLength > INPUT_LIMITS.organizer.extraLinkTitle) {
          return `links.title must be at most ${INPUT_LIMITS.organizer.extraLinkTitle} characters`;
        }
      }
    }
  } catch (error) {
    return (error as Error).message;
  }
  if (!hasSubmittedBrandPrimaryVisual(payload)) {
    return 'brand primary visual is required';
  }
  if (!hasSubmittedBrandOfficialLink(payload) && !hasSubmittedBrandProofImage(payload)) {
    return 'official link or proof image is required';
  }
  if (!submittedBrandFlag(payload.rightsConfirmed) || !submittedBrandFlag(payload.identityConfirmed)) {
    return 'rightsConfirmed and identityConfirmed are required';
  }
  return null;
};

const ensureOptionalHttpUrl = (
  value: string | null,
  fieldName: string
): string | null => {
  if (!value) return null;
  if (!isValidHttpUrl(value)) {
    throw new Error(`${fieldName} must be a valid http/https URL`);
  }
  return value;
};

const validateLabelPayload = (payload: Record<string, unknown>): string | null => {
  const name = normalizeSubmittedSingleLine(payload.name, INPUT_LIMITS.label.name);
  const slug = normalizeSubmittedSingleLine(payload.slug, INPUT_LIMITS.label.slug);
  const profileSlug = normalizeSubmittedSingleLine(payload.profileSlug, INPUT_LIMITS.label.profileSlug);
  const nation = firstFilledSubmittedText(payload.nation, payload.country);
  const foundedAt = normalizeSubmittedSingleLine(payload.foundedAt, INPUT_LIMITS.label.foundedAt);
  const genresPreview = normalizeSubmittedSingleLine(payload.genresPreview, INPUT_LIMITS.label.genresPreview);
  const latestReleaseListing = normalizeSubmittedSingleLine(payload.latestReleaseListing, INPUT_LIMITS.label.latestReleaseListing);
  const locationPeriod = normalizeSubmittedSingleLine(payload.locationPeriod, INPUT_LIMITS.label.locationPeriod);
  const introductionPreview = normalizeMultiline(payload.introductionPreview).slice(0, INPUT_LIMITS.label.introductionPreview);
  const introduction = firstFilledSubmittedMultiline(payload.introduction, payload.description);
  const demoSubmissionDisplay = normalizeSubmittedSingleLine(payload.demoSubmissionDisplay, INPUT_LIMITS.label.demoSubmissionDisplay);
  const genres = normalizeSubmittedStringArray(payload.genres, {
    itemMax: INPUT_LIMITS.label.genre,
    maxItems: 20,
  });
  const founders = normalizeLabelFounders(payload.founders);

  if (!name) {
    return 'name is required';
  }
  if (normalizeSingleLine(payload.name).length > INPUT_LIMITS.label.name) {
    return `name must be at most ${INPUT_LIMITS.label.name} characters`;
  }
  if (slug && normalizeSingleLine(payload.slug).length > INPUT_LIMITS.label.slug) {
    return `slug must be at most ${INPUT_LIMITS.label.slug} characters`;
  }
  if (profileSlug && normalizeSingleLine(payload.profileSlug).length > INPUT_LIMITS.label.profileSlug) {
    return `profileSlug must be at most ${INPUT_LIMITS.label.profileSlug} characters`;
  }
  if (nation.length > INPUT_LIMITS.label.nation) {
    return `nation must be at most ${INPUT_LIMITS.label.nation} characters`;
  }
  if (founders.length > INPUT_LIMITS.label.foundersMaxItems) {
    return `founders must contain at most ${INPUT_LIMITS.label.foundersMaxItems} items`;
  }
  if (foundedAt.length > INPUT_LIMITS.label.foundedAt) {
    return `foundedAt must be at most ${INPUT_LIMITS.label.foundedAt} characters`;
  }
  if (genresPreview.length > INPUT_LIMITS.label.genresPreview) {
    return `genresPreview must be at most ${INPUT_LIMITS.label.genresPreview} characters`;
  }
  if (latestReleaseListing.length > INPUT_LIMITS.label.latestReleaseListing) {
    return `latestReleaseListing must be at most ${INPUT_LIMITS.label.latestReleaseListing} characters`;
  }
  if (locationPeriod.length > INPUT_LIMITS.label.locationPeriod) {
    return `locationPeriod must be at most ${INPUT_LIMITS.label.locationPeriod} characters`;
  }
  if (introductionPreview.length > INPUT_LIMITS.label.introductionPreview) {
    return `introductionPreview must be at most ${INPUT_LIMITS.label.introductionPreview} characters`;
  }
  if (introduction.length > INPUT_LIMITS.label.introduction) {
    return `introduction must be at most ${INPUT_LIMITS.label.introduction} characters`;
  }
  if (demoSubmissionDisplay.length > INPUT_LIMITS.label.demoSubmissionDisplay) {
    return `demoSubmissionDisplay must be at most ${INPUT_LIMITS.label.demoSubmissionDisplay} characters`;
  }
  if (genres.length > 20) {
    return 'genres must contain at most 20 items';
  }

  try {
    const profileUrl = normalizeOptionalSingleLine(payload.profileUrl, INPUT_LIMITS.common.url);
    if (profileUrl && !isValidGeneralUrl(profileUrl)) {
      return 'profileUrl must be a valid URL';
    }
    for (const [fieldName, value] of [
      ['logoUrl', normalizeSubmittedUrl(payload.logoUrl)],
      ['avatarUrl', normalizeSubmittedUrl(payload.avatarUrl)],
      ['backgroundUrl', normalizeSubmittedUrl(payload.backgroundUrl)],
      ['demoSubmissionUrl', normalizeSubmittedUrl(payload.demoSubmissionUrl)],
      ['facebookUrl', normalizeSubmittedUrl(payload.facebookUrl)],
      ['soundcloudUrl', normalizeSubmittedUrl(payload.soundcloudUrl)],
      ['musicPurchaseUrl', normalizeSubmittedUrl(payload.musicPurchaseUrl)],
      ['officialWebsiteUrl', normalizeSubmittedUrl(payload.officialWebsiteUrl ?? payload.officialWebsite)],
    ] as Array<[string, string | null]>) {
      ensureOptionalHttpUrl(value, fieldName);
    }
  } catch (error) {
    return (error as Error).message;
  }

  return null;
};

const validateManualDjPayload = (payload: Record<string, unknown>): string | null => {
  const name = normalizeSubmittedSingleLine(payload.name, INPUT_LIMITS.dj.name);
  const bio = normalizeMultiline(payload.bio).slice(0, INPUT_LIMITS.dj.bio);
  const country = normalizeSubmittedSingleLine(payload.country, INPUT_LIMITS.dj.country);
  const aliases = normalizeSubmittedStringArray(payload.aliases, {
    itemMax: INPUT_LIMITS.dj.alias,
    maxItems: INPUT_LIMITS.dj.aliasesMaxItems,
  });
  const genres = normalizeSubmittedStringArray(payload.genres, {
    itemMax: INPUT_LIMITS.dj.genre,
    maxItems: INPUT_LIMITS.dj.genresMaxItems,
  });

  if (!name) {
    return 'name is required';
  }
  if (normalizeSingleLine(payload.name).length > INPUT_LIMITS.dj.name) {
    return `name must be at most ${INPUT_LIMITS.dj.name} characters`;
  }
  if (bio.length > INPUT_LIMITS.dj.bio) {
    return `bio must be at most ${INPUT_LIMITS.dj.bio} characters`;
  }
  if (country.length > INPUT_LIMITS.dj.country) {
    return `country must be at most ${INPUT_LIMITS.dj.country} characters`;
  }
  if (aliases.length > INPUT_LIMITS.dj.aliasesMaxItems) {
    return `aliases must contain at most ${INPUT_LIMITS.dj.aliasesMaxItems} items`;
  }
  if (genres.length > INPUT_LIMITS.dj.genresMaxItems) {
    return `genres must contain at most ${INPUT_LIMITS.dj.genresMaxItems} items`;
  }

  try {
    [
      ['avatarUrl', normalizeSubmittedUrl(payload.avatarUrl)],
      ['bannerUrl', normalizeSubmittedUrl(payload.bannerUrl)],
      ['proofImageUrl', normalizeSubmittedUrl(payload.proofImageUrl)],
      ['spotifyUrl', normalizeSubmittedUrl(payload.spotifyUrl)],
      ['instagramUrl', normalizeSubmittedUrl(payload.instagramUrl)],
      ['facebookUrl', normalizeSubmittedUrl(payload.facebookUrl)],
      ['soundcloudUrl', normalizeSubmittedUrl(payload.soundcloudUrl)],
      ['twitterUrl', normalizeSubmittedUrl(payload.twitterUrl)],
      ['youtubeUrl', normalizeSubmittedUrl(payload.youtubeUrl)],
      ['neteaseUrl', normalizeSubmittedUrl(payload.neteaseUrl)],
      ['qqMusicUrl', normalizeSubmittedUrl(payload.qqMusicUrl)],
      ['website', normalizeSubmittedUrl(payload.website ?? payload.websiteUrl ?? payload.officialWebsite)],
      ['otherPlatformUrl', normalizeSubmittedUrl(payload.otherPlatformUrl ?? payload.otherUrl)],
      ['sourceWikipedia', normalizeSubmittedUrl(payload.sourceWikipedia)],
      ['sourceWebsite', normalizeSubmittedUrl(payload.sourceWebsite)],
    ].forEach(([fieldName, value]) => ensureOptionalHttpUrl(value as string | null, fieldName as string));
  } catch (error) {
    return (error as Error).message;
  }

  if (payloadHasAnyKey(payload, ['sourceSameAs'])) {
    const value = payload.sourceSameAs;
    if (value !== null && !Array.isArray(value) && typeof value !== 'string') {
      return 'sourceSameAs must be an array, string, or null';
    }
    const entries = normalizeSubmittedStringArray(value, {
      itemMax: INPUT_LIMITS.common.url,
      maxItems: 50,
    });
    try {
      entries.forEach((entry) => ensureOptionalHttpUrl(entry, 'sourceSameAs'));
    } catch (error) {
      return (error as Error).message;
    }
  }

  return null;
};

const brandPayloadForValidation = (
  body: Record<string, unknown>,
  existing?: {
    name: string;
    avatarUrl?: string | null;
    backgroundUrl?: string | null;
    officialWebsite?: string | null;
    facebookUrl?: string | null;
    instagramUrl?: string | null;
    twitterUrl?: string | null;
    youtubeUrl?: string | null;
    tiktokUrl?: string | null;
    links?: Prisma.JsonValue | null;
  } | null
): Record<string, unknown> => {
  if (!existing) {
    return body;
  }
  return {
    name: existing.name,
    avatarUrl: existing.avatarUrl ?? null,
    backgroundUrl: existing.backgroundUrl ?? null,
    officialWebsite: existing.officialWebsite ?? null,
    facebookUrl: existing.facebookUrl ?? null,
    instagramUrl: existing.instagramUrl ?? null,
    twitterUrl: existing.twitterUrl ?? null,
    youtubeUrl: existing.youtubeUrl ?? null,
    tiktokUrl: existing.tiktokUrl ?? null,
    links: existing.links ?? null,
    ...body,
  };
};

const normalizeSubmittedEventLineupToTimetable = (payload: Record<string, unknown>): Record<string, unknown> => {
  const scheduleContext = normalizeSubmittedEventScheduleContext(payload);
  const lineupSyncMode = typeof payload.lineupSyncMode === 'string'
    ? payload.lineupSyncMode.trim().toLowerCase()
    : 'incremental_fill';
  const normalizedPayload = lineupSyncMode === 'exact_align'
    ? autoAlignEventLineupToTimetablePayload(
      payload as unknown as Prisma.JsonObject,
      scheduleContext
    )
    : incrementallyFillEventLineupFromTimetablePayload(
    payload as unknown as Prisma.JsonObject,
    scheduleContext
    );
  return normalizedPayload as unknown as Record<string, unknown>;
};

const normalizeEventSubmissionPayloadForMutation = async (
  payload: Record<string, unknown>
): Promise<Prisma.InputJsonObject> => {
  let normalizedBasePayload = payload as Prisma.InputJsonObject;
  const hasScheduleObject =
    !!payload.schedule
    && typeof payload.schedule === 'object'
    && !Array.isArray(payload.schedule);
  const hasWeeks = Array.isArray(payload.weeks);
  const hasEventDays = Array.isArray(payload.eventDays);

  if (!hasScheduleObject || !hasWeeks || !hasEventDays) {
    const targetEventId = cleanSubmittedBrandText(payload.targetEventId)
      || cleanSubmittedBrandText(payload.editTargetEventId);
    if (targetEventId) {
      const existing = await prisma.event.findUnique({
        where: { id: targetEventId },
        select: {
          scheduleMode: true,
          timeZone: true,
          dayRolloverHour: true,
          weeks: {
            orderBy: [{ sortOrder: 'asc' }, { weekIndex: 'asc' }],
            select: {
              weekIndex: true,
              label: true,
              startDate: true,
              endDate: true,
              sortOrder: true,
            },
          },
          eventDays: {
            orderBy: [{ sortOrder: 'asc' }, { overallDayIndex: 'asc' }],
            select: {
              eventDayId: true,
              weekIndex: true,
              dayIndexInWeek: true,
              overallDayIndex: true,
              label: true,
              weekday: true,
              date: true,
              sortOrder: true,
            },
          },
        },
      });

      if (existing) {
        const existingScheduleContext = buildSubmittedEventScheduleContextFromEvent(existing);
        normalizedBasePayload = {
          ...payload,
          schedule: hasScheduleObject ? payload.schedule as Prisma.InputJsonValue : {
            mode: existingScheduleContext.scheduleMode,
            timeZone: existingScheduleContext.timeZone,
            dayRolloverHour: existingScheduleContext.dayRolloverHour,
          },
          weeks: hasWeeks ? payload.weeks as Prisma.InputJsonValue : existingScheduleContext.weeks.map((week) => ({
            weekIndex: week.weekIndex,
            label: week.label ?? null,
            startDate: week.startDate,
            endDate: week.endDate,
            sortOrder: week.sortOrder,
          })) as unknown as Prisma.InputJsonValue,
          eventDays: hasEventDays ? payload.eventDays as Prisma.InputJsonValue : existingScheduleContext.eventDays.map((day) => ({
            eventDayId: day.eventDayId,
            weekIndex: day.weekIndex,
            dayIndexInWeek: day.dayIndexInWeek,
            overallDayIndex: day.overallDayIndex,
            label: day.label ?? null,
            weekday: day.weekday ?? null,
            date: day.date,
            sortOrder: day.sortOrder,
          })) as unknown as Prisma.InputJsonValue,
        };
      }
    }
  }

  return normalizeSubmittedEventLineupToTimetable(
    normalizedBasePayload as unknown as Record<string, unknown>
  ) as unknown as Prisma.InputJsonObject;
};

const mapAlignedLineupArtistForPayload = (artist: {
  id?: string;
  djId: string | null;
  memberDjIds?: Array<string | null>;
  memberNames?: string[];
  djName: string;
  sortOrder: number;
}): Prisma.InputJsonObject => ({
  ...(artist.id ? { id: artist.id } : {}),
  djId: artist.djId,
  memberDjIds: (artist.memberDjIds ?? []) as Prisma.InputJsonValue,
  memberNames: (artist.memberNames ?? []) as Prisma.InputJsonValue,
  djName: artist.djName,
  sortOrder: artist.sortOrder,
});

const cleanIdempotencyKey = (value: unknown): string | null => {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed || null;
};

const createPendingContentSubmission = async (input: {
  submitterId: string;
  entityType: 'event' | 'dj' | 'news' | 'set' | 'brand' | 'label' | 'id' | 'rating';
  title: string;
  payload: Record<string, unknown>;
  idempotencyKey?: string | null;
}) => {
  const normalizedPayload =
    input.entityType === 'event'
      ? await normalizeEventSubmissionPayloadForMutation(input.payload)
      : input.entityType === 'brand'
      ? normalizeBrandSubmissionPayload(input.payload as Prisma.InputJsonObject)
      : (input.payload as Prisma.InputJsonObject);
  const payloadWithSummary = normalizedPayload;
  let orphanedBrandDraftObjectKeys: string[] = [];
  const submission = await prisma.$transaction(async (tx) => {
    if (input.idempotencyKey) {
      const existing = await tx.contentSubmission.findFirst({
        where: {
          submitterId: input.submitterId,
          idempotencyKey: input.idempotencyKey,
        },
      });
      if (existing) return existing;
    }
    if (input.entityType === 'event') {
      await assertNoActiveEventEditSubmission(tx, payloadWithSummary as Prisma.InputJsonObject, {
        lockTargetEvent: true,
      });
    }
    if (input.entityType === 'brand') {
      await assertBrandSubmissionBaseRevision(tx, payloadWithSummary as Prisma.JsonObject);
    }
    const reviewNotes = await buildSubmissionReviewNotes(tx, input.entityType, payloadWithSummary);
    const submission = await tx.contentSubmission.create({
      data: {
        submitterId: input.submitterId,
        entityType: input.entityType,
        title: input.title,
        payload: payloadWithSummary,
        idempotencyKey: input.idempotencyKey || null,
        reviewNotes,
        status: 'processing',
      },
    });

    await (tx as any).contentSubmissionVersion.create({
      data: {
        submissionId: submission.id,
        version: 1,
        title: input.title,
        payload: payloadWithSummary,
        submittedBy: input.submitterId,
        changeNote: 'Initial submission',
      },
    });

    if (input.entityType === 'brand') {
      await bindBrandDraftMediaToSubmission(
        tx,
        payloadWithSummary as Prisma.JsonObject,
        input.submitterId,
        submission.id
      );
      orphanedBrandDraftObjectKeys = await cleanupOrphanedBrandDraftMediaAfterSubmission(
        tx,
        payloadWithSummary as Prisma.JsonObject,
        input.submitterId
      );
    } else if (input.entityType === 'event') {
      await bindEventDraftMediaToSubmission(
        tx,
        payloadWithSummary as Prisma.JsonObject,
        input.submitterId,
        submission.id
      );
    }

    return submission;
  });

  if (orphanedBrandDraftObjectKeys.length > 0) {
    await deleteOssObjects(Array.from(new Set(orphanedBrandDraftObjectKeys)));
  }

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
  const processingBody = `你提交的「${input.title}」已进入处理队列。`;
  await scheduleContentSubmissionProcessingBestEffort(submission.id);
  await notificationCenterService.publish({
    category: 'content_review',
    targets: [{ userId: input.submitterId }],
    channels: ['in_app', 'apns'],
    dedupeKey: `content_submission:${submission.id}:processing`,
    payload: {
      title: `${typeLabel}提交处理中`,
      body: processingBody,
      deeplink: `/profile/submissions/${submission.id}`,
      metadata: {
        source: 'content_submission_review',
        submissionId: submission.id,
        entityType: input.entityType,
        status: 'processing',
        reason: null,
        reasonCode: null,
        createdEntityId: null,
        typeLabel,
        statusLabel: '处理中',
        message: processingBody,
      },
    },
  });

  return submission;
};

const acceptedSubmission = (
  res: Response,
  submission: Awaited<ReturnType<typeof createPendingContentSubmission>>,
  message: string
): void => {
  res.status(202).json({
    data: {
      status: 'submitted_for_review',
      message,
      submission,
    },
  });
};

const featureFlagEnabled = (value: string | undefined, fallback: boolean): boolean => {
  if (value === undefined) return fallback;
  const normalized = value.trim().toLowerCase();
  if (!normalized) return fallback;
  return ['1', 'true', 'yes', 'on'].includes(normalized);
};

const resolveEventMutationRoute = (role?: string | null): 'direct_apply' | 'submission' => {
  if (
    canBypassContentReview(role)
    && featureFlagEnabled(process.env.EVENT_EDIT_DIRECT_APPLY_ENABLED, true)
  ) {
    return 'direct_apply';
  }
  return 'submission';
};

const loadEventDetailForWeb = async (
  eventId: string,
  viewerId?: string | null
) => {
  const row = await attachContributionInfo(
    prisma,
    'event',
    await prisma.event.findUnique({
      where: { id: eventId },
      select: selectEventDetailForWeb,
    })
  );
  if (!row) return null;
  const favoriteIdsByEventId = await resolveEventFavoriteIds(viewerId ?? undefined, [row.id]);
  const rowWithFavorite = attachEventFavoriteState([row], favoriteIdsByEventId)[0];
  const complianceUser = await resolveRegionalComplianceUser(viewerId);
  return mapEvent(rowWithFavorite, complianceUser, viewerId ?? null, null);
};

const auditEventDirectApplyBestEffort = async (input: {
  actorId: string;
  action: 'event.direct_create' | 'event.direct_update';
  eventId: string;
  submissionId: string;
  title: string;
}): Promise<void> => {
  try {
    await adminAuditService.createAction({
      actorId: input.actorId,
      action: input.action,
      targetType: 'event',
      targetId: input.eventId,
      detail: {
        submissionId: input.submissionId,
        title: input.title,
        route: 'direct_apply',
      },
    });
  } catch (error) {
    console.warn('BFF web event direct apply audit failed:', {
      eventId: input.eventId,
      submissionId: input.submissionId,
      error: error instanceof Error ? error.message : String(error),
    });
  }
};

const publishEventDirectApplyNotificationBestEffort = async (input: {
  userId: string;
  title: string;
  submissionId: string;
  eventId: string;
  payload: Prisma.JsonObject;
}): Promise<void> => {
  try {
    await publishContentSubmissionTaskNotification({
      userId: input.userId,
      entityType: 'event',
      status: 'approved',
      title: input.title,
      submissionId: input.submissionId,
      createdEntityId: input.eventId,
      statusLabelOverride: '已入库',
      notificationKey: 'event_core_applied',
      bodyOverride: `你提交的「${input.title}」已成功入库，时间表会继续在后台同步。`,
      payload: input.payload,
    });
  } catch (error) {
    console.warn('BFF web event direct apply notification failed:', {
      eventId: input.eventId,
      submissionId: input.submissionId,
      error: error instanceof Error ? error.message : String(error),
    });
  }
};

const createDirectEventApplySubmission = async (input: {
  submitterId: string;
  title: string;
  payload: Record<string, unknown>;
  idempotencyKey?: string | null;
}) => {
  const normalizedPayload = await normalizeEventSubmissionPayloadForMutation(input.payload);
  const payloadWithSummary = normalizedPayload;

  return prisma.$transaction(async (tx) => {
    if (input.idempotencyKey) {
      const existing = await tx.contentSubmission.findFirst({
        where: {
          submitterId: input.submitterId,
          idempotencyKey: input.idempotencyKey,
        },
      });
      if (existing) return { submission: existing, payload: payloadWithSummary, reused: true };
    }

    await assertNoActiveEventEditSubmission(tx, payloadWithSummary, {
      lockTargetEvent: true,
    });
    const reviewNotes = await buildSubmissionReviewNotes(tx, 'event', payloadWithSummary);
    const submission = await tx.contentSubmission.create({
      data: {
        submitterId: input.submitterId,
        entityType: 'event',
        title: input.title,
        payload: payloadWithSummary,
        idempotencyKey: input.idempotencyKey || null,
        reviewNotes: {
          ...reviewNotes,
          route: 'direct_apply',
          directApply: {
            phase: 'core_processing',
            startedAt: new Date().toISOString(),
          },
        },
        status: 'processing',
      },
    });

    await (tx as any).contentSubmissionVersion.create({
      data: {
        submissionId: submission.id,
        version: 1,
        title: input.title,
        payload: payloadWithSummary,
        submittedBy: input.submitterId,
        changeNote: 'Direct apply submission',
      },
    });

    await bindEventDraftMediaToSubmission(
      tx,
      payloadWithSummary as Prisma.JsonObject,
      input.submitterId,
      submission.id
    );

    return { submission, payload: payloadWithSummary, reused: false };
  });
};

const applyEventDirectly = async (input: {
  submitterId: string;
  title: string;
  payload: Record<string, unknown>;
  idempotencyKey?: string | null;
}) => {
  const directSubmission = await createDirectEventApplySubmission(input);
  const existingCreatedEntityId = cleanSubmittedBrandText(directSubmission.submission.createdEntityId);
  if (directSubmission.reused) {
    if (!existingCreatedEntityId) {
      throw new ActiveEventEditSubmissionError({
        targetEventId: cleanSubmittedBrandText(directSubmission.payload.targetEventId) || 'unknown',
        activeSubmissionId: directSubmission.submission.id,
        activeSubmissionStatus: directSubmission.submission.status,
      });
    }
    const existingEvent = await loadEventDetailForWeb(existingCreatedEntityId, input.submitterId);
    if (!existingEvent) throw new Error('Direct applied event not found');
    return {
      event: existingEvent,
      submission: directSubmission.submission,
      reused: true,
    };
  }

  try {
    const event = await createOrUpdateEventFromSubmission(
      prisma,
      directSubmission.payload as Prisma.JsonObject,
      input.submitterId,
      {
        submissionId: directSubmission.submission.id,
        skipCanonicalApply: true,
      }
    );

    const updatedSubmission = await prisma.contentSubmission.update({
      where: { id: directSubmission.submission.id },
      data: {
        status: 'approved',
        reviewReason: null,
        reviewedAt: new Date(),
        reviewedBy: input.submitterId,
        createdEntityId: event.id,
        reviewNotes: {
          ...(directSubmission.submission.reviewNotes && typeof directSubmission.submission.reviewNotes === 'object' && !Array.isArray(directSubmission.submission.reviewNotes)
            ? directSubmission.submission.reviewNotes as Prisma.JsonObject
            : {}),
          route: 'direct_apply',
          directApply: {
            phase: 'core_applied',
            eventId: event.id,
            completedAt: new Date().toISOString(),
          },
        },
      },
    });

    await prisma.contentSubmissionProcessingJob.updateMany({
      where: {
        jobType: CONTENT_SUBMISSION_EVENT_TIMETABLE_JOB_TYPE,
        status: { in: ['queued', 'retrying'] },
        submissionId: { not: updatedSubmission.id },
        submission: {
          entityType: 'event',
          createdEntityId: event.id,
        },
      },
      data: {
        status: 'cancelled',
        lockedBy: null,
        lockedAt: null,
        completedAt: new Date(),
        lastError: 'Superseded by a newer direct event apply',
      },
    });

    await enqueueContentSubmissionProcessingJob(updatedSubmission.id, {
      jobType: CONTENT_SUBMISSION_EVENT_TIMETABLE_JOB_TYPE,
      metadata: {
        source: 'event_direct_apply_phase_b',
        route: 'direct_apply',
        createdEntityId: event.id,
      },
    });

    await auditEventDirectApplyBestEffort({
      actorId: input.submitterId,
      action: cleanSubmittedBrandText(directSubmission.payload.targetEventId) ? 'event.direct_update' : 'event.direct_create',
      eventId: event.id,
      submissionId: updatedSubmission.id,
      title: input.title,
    });
    await publishEventDirectApplyNotificationBestEffort({
      userId: input.submitterId,
      title: input.title,
      submissionId: updatedSubmission.id,
      eventId: event.id,
      payload: directSubmission.payload as Prisma.JsonObject,
    });

    const mappedEvent = await loadEventDetailForWeb(event.id, input.submitterId);
    if (!mappedEvent) throw new Error('Direct applied event not found');
    return {
      event: mappedEvent,
      submission: updatedSubmission,
      reused: false,
    };
  } catch (error) {
    await prisma.contentSubmission.update({
      where: { id: directSubmission.submission.id },
      data: {
        status: 'failed',
        reviewReason: error instanceof Error ? error.message : 'Direct event apply failed',
      },
    }).catch(() => undefined);
    throw error;
  }
};

type BFFPagination = {
  page: number;
  limit: number;
  total: number;
  totalPages: number;
};

const ok = <T>(res: Response, data: T, pagination?: BFFPagination): void => {
  if (pagination) {
    res.json({ data, pagination });
    return;
  }
  res.json({ data });
};

const normalizePage = (value: unknown, fallback = 1): number => {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.max(1, Math.floor(parsed));
};

const normalizeLimit = (value: unknown, fallback = 20, max = 50): number => {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.max(1, Math.min(max, Math.floor(parsed)));
};

const parseSortOrder = (value: unknown, fallback: Prisma.SortOrder): Prisma.SortOrder => {
  if (value === 'asc' || value === 'desc') {
    return value;
  }
  return fallback;
};

const slugify = (value: string): string =>
  value
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '') || 'item';

const toNumber = (value: unknown): number | null => {
  if (value === null || value === undefined || value === '') return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
};

type EventBiTextPayload = TriTextPayload;

type EventSocialLinkPayload = {
  type: string;
  url: string;
  label?: string;
};

type EventImageAssetPayload = {
  type: 'cover' | 'luall' | 'tt' | 'poster' | 'other';
  label: string;
  url: string;
  source?: string;
  originalUrl?: string;
  fileName?: string;
  order?: number;
  sort?: number;
};

const normalizeEventText = (value: unknown): string => {
  if (typeof value !== 'string') return '';
  const text = value.trim();
  if (!text) return '';
  if (/^\[object\s+object\]$/i.test(text)) return '';
  return text;
};

const normalizeEventBiText = (value: unknown, fallback = ''): EventBiTextPayload | null =>
  normalizeTriTextPayload(value, fallback);

const normalizeDJBiText = (value: unknown, fallback = ''): EventBiTextPayload | null =>
  normalizeEventBiText(value, fallback);

const resolveBiTextWithFallback = (value: unknown, fallback = ''): EventBiTextPayload | null =>
  resolveTriTextWithFallback(value, fallback);

const normalizeCountryBiText = (value: unknown, fallback = ''): EventBiTextPayload | null => {
  const normalized = normalizeCountryBiTextPayload(value, fallback);
  if (!normalized) return null;
  return normalized;
};

const resolveCountryBiTextWithFallback = (value: unknown, fallback = ''): EventBiTextPayload | null =>
  normalizeCountryBiText(value, fallback);

const asEventLocationObject = (value: unknown): Record<string, unknown> | null => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  return value as Record<string, unknown>;
};

const EVENT_LOCATION_PROVIDERS = new Set(['amap', 'google', 'mapkit', 'mapbox', 'geoapify']);
const EVENT_LOCATION_PROVIDER_ALIASES = new Map([
  ['apple-mapkit', 'mapkit'],
  ['apple_mapkit', 'mapkit'],
]);
const EVENT_LOCATION_SOURCE_MODES = new Set([
  'manual_search',
  'pin_drag',
  'map_poi_click',
  'my_location',
  'legacy_coords',
]);
const EVENT_LOCATION_SOURCE_MODE_ALIASES = new Map([
  ['composed_search', 'manual_search'],
  ['picker_search', 'manual_search'],
  ['manual_pick', 'pin_drag'],
  ['manual_pin', 'pin_drag'],
  ['ios-event-upload-v2', 'pin_drag'],
  ['web-event-studio-v2', 'pin_drag'],
  ['server_normalized', 'legacy_coords'],
]);

const normalizeEventLocationProvider = (value: unknown, fallback = 'amap'): string => {
  const preferredRaw = normalizeEventText(value).toLowerCase();
  const preferred = EVENT_LOCATION_PROVIDER_ALIASES.get(preferredRaw) || preferredRaw;
  if (EVENT_LOCATION_PROVIDERS.has(preferred)) return preferred;
  const fbRaw = normalizeEventText(fallback).toLowerCase();
  const fb = EVENT_LOCATION_PROVIDER_ALIASES.get(fbRaw) || fbRaw;
  return EVENT_LOCATION_PROVIDERS.has(fb) ? fb : 'amap';
};

const normalizeEventLocationSourceMode = (value: unknown, fallback = 'manual_search'): string => {
  const textRaw = normalizeEventText(value).toLowerCase();
  if (!textRaw) return fallback;
  const text = EVENT_LOCATION_SOURCE_MODE_ALIASES.get(textRaw) || textRaw;
  if (EVENT_LOCATION_SOURCE_MODES.has(text)) return text;
  return EVENT_LOCATION_SOURCE_MODES.has(fallback) ? fallback : 'manual_search';
};

const normalizeEventLocationStringArray = (value: unknown): string[] => {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => normalizeEventText(item))
    .filter((item) => item.length > 0)
    .slice(0, 20);
};

const normalizeEventLocationProviderMeta = (
  value: unknown,
  provider: string,
  providerPlaceId: string,
  legacyPoiId: string,
  legacyAdcode: string
): Record<string, unknown> | null => {
  const src = asEventLocationObject(value) || {};
  const out: Record<string, unknown> = {};

  const amapRaw = asEventLocationObject(src.amap);
  const amapPoiId = normalizeEventText(amapRaw?.poiId) || legacyPoiId || (provider === 'amap' ? providerPlaceId : '');
  const amapAdcode = normalizeEventText(amapRaw?.adcode) || legacyAdcode;
  if (amapPoiId || amapAdcode) {
    out.amap = {
      ...(amapPoiId ? { poiId: amapPoiId } : {}),
      ...(amapAdcode ? { adcode: amapAdcode } : {}),
    };
  }

  const googleRaw = asEventLocationObject(src.google);
  const googlePlaceId = normalizeEventText(googleRaw?.placeId) || (provider === 'google' ? providerPlaceId : '');
  const googleTypes = normalizeEventLocationStringArray(googleRaw?.types);
  if (googlePlaceId || googleTypes.length > 0) {
    out.google = {
      ...(googlePlaceId ? { placeId: googlePlaceId } : {}),
      ...(googleTypes.length > 0 ? { types: googleTypes } : {}),
    };
  }

  const mapkitRaw = asEventLocationObject(src.mapkit);
  const mapkitIdentifier = normalizeEventText(mapkitRaw?.mapItemIdentifier) || (provider === 'mapkit' ? providerPlaceId : '');
  if (mapkitIdentifier) {
    out.mapkit = { mapItemIdentifier: mapkitIdentifier };
  }

  const mapboxRaw = asEventLocationObject(src.mapbox);
  const mapboxPlaceId = normalizeEventText(mapboxRaw?.placeId) || (provider === 'mapbox' ? providerPlaceId : '');
  const mapboxFeatureType = normalizeEventText(mapboxRaw?.featureType);
  if (mapboxPlaceId || mapboxFeatureType) {
    out.mapbox = {
      ...(mapboxPlaceId ? { placeId: mapboxPlaceId } : {}),
      ...(mapboxFeatureType ? { featureType: mapboxFeatureType } : {}),
    };
  }

  const geoapifyRaw = asEventLocationObject(src.geoapify);
  const geoapifyPlaceId = normalizeEventText(geoapifyRaw?.placeId) || (provider === 'geoapify' ? providerPlaceId : '');
  const geoapifyFeatureType = normalizeEventText(geoapifyRaw?.featureType);
  if (geoapifyPlaceId || geoapifyFeatureType) {
    out.geoapify = {
      ...(geoapifyPlaceId ? { placeId: geoapifyPlaceId } : {}),
      ...(geoapifyFeatureType ? { featureType: geoapifyFeatureType } : {}),
    };
  }

  return Object.keys(out).length > 0 ? out : null;
};

const normalizeEventLocationPointPayload = (
  value: unknown,
  fallback: unknown = null
): Record<string, unknown> | null => {
  const src = asEventLocationObject(value) || asEventLocationObject(fallback);
  if (!src) return null;
  const lng = toNumber((src.location as any)?.lng ?? src.lng ?? src.longitude);
  const lat = toNumber((src.location as any)?.lat ?? src.lat ?? src.latitude);
  if (lng === null || lat === null) return null;

  const provider = normalizeEventLocationProvider(src.provider, 'amap');
  const sourceMode = normalizeEventLocationSourceMode(src.sourceMode, 'manual_search');
  const legacyPoiId = normalizeEventText(src.poiId);
  const legacyAdcode = normalizeEventText(src.adcode);

  const providerMetaPreview = asEventLocationObject(src.providerMeta) || {};
  let providerPlaceId =
    normalizeEventText(src.providerPlaceId)
    || legacyPoiId
    || normalizeEventText((asEventLocationObject(providerMetaPreview.amap) || {}).poiId)
    || normalizeEventText((asEventLocationObject(providerMetaPreview.google) || {}).placeId)
    || normalizeEventText((asEventLocationObject(providerMetaPreview.mapkit) || {}).mapItemIdentifier)
    || normalizeEventText((asEventLocationObject(providerMetaPreview.mapbox) || {}).placeId)
    || normalizeEventText((asEventLocationObject(providerMetaPreview.geoapify) || {}).placeId);
  providerPlaceId = providerPlaceId.slice(0, 256);

  const nameI18n = normalizeEventBiText(src.nameI18n ?? src.name, '');
  const addressI18n = normalizeEventBiText(src.addressI18n ?? src.address, '');
  const formattedAddressI18n = normalizeEventBiText(
    src.formattedAddressI18n ?? src.formattedAddress ?? src.addressI18n ?? src.address,
    ''
  );
  const manualSetAddressI18n = normalizeEventBiText(src.manualSetAddressI18n, '');

  const countryCodeRaw = normalizeEventText(src.countryCode).toUpperCase();
  const countryCode = countryCodeRaw.replace(/[^A-Z]/g, '').slice(0, 3);

  const providerMeta = normalizeEventLocationProviderMeta(
    src.providerMeta,
    provider,
    providerPlaceId,
    legacyPoiId,
    legacyAdcode
  );
  const amapMeta = asEventLocationObject(providerMeta?.amap);
  const normalizedPoiId = normalizeEventText(amapMeta?.poiId) || legacyPoiId || (provider === 'amap' ? providerPlaceId : '');
  const normalizedAdcode = normalizeEventText(amapMeta?.adcode) || legacyAdcode;

  const selectedAtRaw = normalizeEventText(src.selectedAt);
  const selectedAtDate = selectedAtRaw ? new Date(selectedAtRaw) : new Date();
  const selectedAt = Number.isNaN(selectedAtDate.getTime()) ? new Date().toISOString() : selectedAtDate.toISOString();

  return {
    provider,
    sourceMode,
    providerPlaceId: providerPlaceId || null,
    // Legacy alias kept for existing clients/modules.
    poiId: normalizedPoiId || null,
    location: {
      lng: Number(lng),
      lat: Number(lat),
    },
    nameI18n: nameI18n ?? { zh: '', en: '' },
    addressI18n: addressI18n ?? { zh: '', en: '' },
    formattedAddressI18n: formattedAddressI18n ?? { zh: '', en: '' },
    manualSetAddressI18n: manualSetAddressI18n ?? null,
    city: normalizeEventText(src.city),
    district: normalizeEventText(src.district),
    province: normalizeEventText(src.province),
    countryCode: countryCode || null,
    i18nPending: !!src.i18nPending,
    selectedAt,
    providerMeta: providerMeta ?? null,
    // Legacy alias kept for existing clients/modules.
    adcode: normalizedAdcode || null,
  };
};

const normalizeEventManualLocationPayload = (
  value: unknown,
  fallback: unknown = null
): Record<string, unknown> | null => {
  const src = asEventLocationObject(value) || asEventLocationObject(fallback);
  if (!src) return null;

  const detailAddressI18n = normalizeEventBiText(
    src.detailAddressI18n
      ?? src.detail_address_i18n
      ?? src.detailAddress
      ?? src.detail_address
      ?? src.addressI18n
      ?? src.address,
    ''
  );
  const formattedAddressI18n = normalizeEventBiText(
    src.formattedAddressI18n
      ?? src.formattedAddress
      ?? detailAddressI18n,
    ''
  );

  const hasDetail =
    !!detailAddressI18n
    && !!(normalizeEventText(detailAddressI18n.zh) || normalizeEventText(detailAddressI18n.en));
  const hasFormatted =
    !!formattedAddressI18n
    && !!(normalizeEventText(formattedAddressI18n.zh) || normalizeEventText(formattedAddressI18n.en));
  if (!hasDetail && !hasFormatted) {
    return null;
  }

  const selectedAtRaw = normalizeEventText(src.selectedAt);
  const selectedAtDate = selectedAtRaw ? new Date(selectedAtRaw) : new Date();
  const selectedAt = Number.isNaN(selectedAtDate.getTime()) ? new Date().toISOString() : selectedAtDate.toISOString();

  return {
    detailAddressI18n: detailAddressI18n ?? { zh: '', en: '' },
    formattedAddressI18n: formattedAddressI18n ?? { zh: '', en: '' },
    selectedAt,
  };
};

const joinEventAddressComponents = (values: Array<unknown>): string => {
  const seen = new Set<string>();
  const parts: string[] = [];
  for (const raw of values) {
    const text = normalizeEventText(raw);
    if (!text) continue;
    const key = text.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    parts.push(text);
  }
  return parts.join(' · ');
};

const mergeManualLocationFormattedWithBaseI18n = (
  manualLocation: Record<string, unknown> | null,
  cityI18n: EventBiTextPayload | null,
  countryI18n: EventBiTextPayload | null
): Record<string, unknown> | null => {
  if (!manualLocation) return null;
  const detailAddressI18n = normalizeEventBiText((manualLocation as any).detailAddressI18n ?? null, '');
  const formattedAddressI18n = normalizeEventBiText((manualLocation as any).formattedAddressI18n ?? null, '');

  const detailZh = normalizeEventText(detailAddressI18n?.zh ?? detailAddressI18n?.en ?? '');
  const detailEn = normalizeEventText(detailAddressI18n?.en ?? detailAddressI18n?.zh ?? '');
  const cityZh = normalizeEventText(cityI18n?.zh ?? cityI18n?.en ?? '');
  const cityEn = normalizeEventText(cityI18n?.en ?? cityI18n?.zh ?? '');
  const countryZh = normalizeEventText(countryI18n?.zh ?? countryI18n?.en ?? '');
  const countryEn = normalizeEventText(countryI18n?.enFull ?? countryI18n?.en ?? countryI18n?.zh ?? '');

  const derivedZh = joinEventAddressComponents([detailZh, cityZh, countryZh]);
  const derivedEn = joinEventAddressComponents([detailEn, cityEn, countryEn]);
  const rawZh = normalizeEventText(formattedAddressI18n?.zh ?? '');
  const rawEn = normalizeEventText(formattedAddressI18n?.en ?? '');

  const shouldRepairZh = !!derivedZh && (!rawZh || (rawEn && rawZh.toLowerCase() === rawEn.toLowerCase()));
  const shouldRepairEn = !!derivedEn && !rawEn;

  const nextZh = shouldRepairZh ? derivedZh : (rawZh || derivedZh || rawEn);
  const nextEn = shouldRepairEn ? derivedEn : (rawEn || derivedEn || rawZh);
  if (!nextZh && !nextEn) return manualLocation;

  return {
    ...manualLocation,
    formattedAddressI18n: {
      zh: nextZh || nextEn,
      en: nextEn || nextZh,
    },
  };
};

const parseEventReferenceLinks = (value: unknown): string[] => {
  const list = Array.isArray(value)
    ? value
    : typeof value === 'string'
      ? value.split(/\r?\n/g)
      : [];

  const result: string[] = [];
  const seen = new Set<string>();
  for (const item of list) {
    const url = normalizeEventText(item);
    if (!url) continue;
    const key = url.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(url);
  }
  return result;
};

const parseEventSocialLinks = (value: unknown): EventSocialLinkPayload[] => {
  if (!Array.isArray(value)) return [];

  const normalized = value
    .map((item) => {
      if (!item || typeof item !== 'object') return null;
      const row = item as Record<string, unknown>;
      const url = normalizeEventText(row.url);
      if (!url) return null;

      const type = normalizeEventText(row.type).toLowerCase() || 'website';
      const label = normalizeEventText(row.label);
      return {
        type,
        url,
        ...(label ? { label } : {}),
      } as EventSocialLinkPayload;
    })
    .filter((item): item is EventSocialLinkPayload => item !== null);

  const deduped: EventSocialLinkPayload[] = [];
  const seen = new Set<string>();
  for (const item of normalized) {
    const key = `${item.type}::${item.url}`.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    deduped.push(item);
  }

  return deduped;
};

const parseEventImageAssets = (value: unknown): EventImageAssetPayload[] => {
  if (!Array.isArray(value)) return [];
  const allowedTypes = new Set(['cover', 'luall', 'tt', 'poster', 'other']);
  return value
    .map((item) => {
      if (!item || typeof item !== 'object') return null;
      const row = item as Record<string, unknown>;
      const typeRaw = normalizeEventText(row.type).toLowerCase();
      if (!allowedTypes.has(typeRaw)) return null;
      const url = normalizeEventText(row.url);
      if (!url) return null;
      const label = normalizeEventText(row.label) || typeRaw.toUpperCase();

      const order = typeof row.order === 'number' && Number.isFinite(row.order) ? row.order : undefined;
      const sort = typeof row.sort === 'number' && Number.isFinite(row.sort) ? row.sort : undefined;
      const source = normalizeEventText(row.source) || undefined;
      const originalUrl = normalizeEventText(row.originalUrl) || undefined;
      const fileName = normalizeEventText(row.fileName) || undefined;

      return {
        type: typeRaw as EventImageAssetPayload['type'],
        label,
        url,
        ...(source ? { source } : {}),
        ...(originalUrl ? { originalUrl } : {}),
        ...(fileName ? { fileName } : {}),
        ...(order !== undefined ? { order } : {}),
        ...(sort !== undefined ? { sort } : {}),
      } as EventImageAssetPayload;
    })
    .filter((item): item is EventImageAssetPayload => item !== null);
};

const hasRequiredEventPrimaryImageAsset = (assets: EventImageAssetPayload[]): boolean =>
  assets.some((asset) => {
    if (asset.type === 'cover' || asset.type === 'luall' || asset.type === 'poster') {
      return true;
    }
    const label = normalizeEventText(asset.label).toUpperCase();
    const fileName = normalizeEventText(asset.fileName).toLowerCase();
    return asset.type === 'other' && (label.includes('POSTER') || fileName.startsWith('poster'));
  });

const resolveEventImageAssetBucket = (asset: EventImageAssetPayload): 'poster' | 'cover' | 'lineup' | 'timetable' | 'other' => {
  const type = normalizeEventText(asset.type).toLowerCase();
  const label = normalizeEventText(asset.label).toLowerCase();
  const fileName = normalizeEventText(asset.fileName).toLowerCase();
  if (type === 'poster' || label.includes('poster') || fileName.startsWith('poster')) return 'poster';
  if (type === 'cover' || label.includes('cover') || fileName.startsWith('cover')) return 'cover';
  if (type === 'luall' || type.includes('lineup') || label.includes('line-up') || label.includes('lineup')) return 'lineup';
  if (type === 'tt' || type.includes('timetable') || label.includes('timetable')) return 'timetable';
  return 'other';
};

const sortEventImageAssetsForDisplay = (assets: EventImageAssetPayload[]): EventImageAssetPayload[] =>
  [...assets].sort((a, b) => {
    const aOrder = typeof a.sort === 'number' ? a.sort : typeof a.order === 'number' ? a.order : Number.MAX_SAFE_INTEGER;
    const bOrder = typeof b.sort === 'number' ? b.sort : typeof b.order === 'number' ? b.order : Number.MAX_SAFE_INTEGER;
    return aOrder - bOrder;
  });

const resolveEventCardImageUrl = (row: { imageAssets?: unknown; coverImageUrl?: unknown; lineupImageUrl?: unknown }): string | null => {
  const assets = sortEventImageAssetsForDisplay(parseEventImageAssets(row.imageAssets ?? []));
  const firstAssetUrl = (bucket: ReturnType<typeof resolveEventImageAssetBucket>) =>
    assets.find((asset) => resolveEventImageAssetBucket(asset) === bucket)?.url ?? null;
  return (
    firstAssetUrl('poster') ||
    normalizeEventText(row.coverImageUrl) ||
    firstAssetUrl('cover') ||
    normalizeEventText(row.lineupImageUrl) ||
    firstAssetUrl('lineup') ||
    null
  );
};

type NormalizedLineupSlot = {
  djId: string | null;
  memberDjIds: Array<string | null>;
  festivalDayIndex: number | null;
  djName: string;
  stageName: string | null;
  sortOrder: number;
  startTime: Date;
  endTime: Date;
};

type NormalizedLineupArtistInput = {
  djId: string | null;
  memberDjIds: Array<string | null>;
  memberNames: string[];
  djName: string;
  sortOrder: number;
};

const EVENT_DEFAULT_START_TIME = '00:00:00';
const EVENT_DEFAULT_END_TIME = '23:59:59';

const normalizeEventClockTime = (value: unknown, fallback: string): string => {
  if (typeof value !== 'string') return fallback;
  const trimmed = value.trim();
  if (!trimmed) return fallback;
  const match = trimmed.match(/^(\d{1,2}):(\d{1,2})(?::(\d{1,2}))?$/);
  if (!match) return fallback;
  const hour = Number(match[1]);
  const minute = Number(match[2]);
  const second = Number(match[3] ?? '0');
  if (!Number.isInteger(hour) || !Number.isInteger(minute) || !Number.isInteger(second)) return fallback;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59 || second < 0 || second > 59) return fallback;
  return `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}:${String(second).padStart(2, '0')}`;
};

const normalizeEventStartDate = (date: Date, timeZone = DEFAULT_EVENT_TIME_ZONE): Date => startOfEventDay(date, timeZone);

const normalizeEventEndDate = (date: Date, timeZone = DEFAULT_EVENT_TIME_ZONE): Date => {
  const start = startOfEventDay(date, timeZone);
  return new Date(start.getTime() + 86_400_000 - 1000);
};

const EVENT_TYPE_FILTER_ALIASES: Record<string, string[]> = {
  festival: ['festival', '电音节'],
  bar_event: ['bar_event', 'bar event', 'bar-event', '酒吧活动'],
  outdoor_event: ['outdoor_event', 'outdoor event', 'outdoor-event', '露天活动'],
  club_party: ['club_party', 'club party', 'club-party', '俱乐部派对'],
  warehouse_party: ['warehouse_party', 'warehouse party', 'warehouse-party', '仓库派对'],
  tour_special: ['tour_special', 'tour special', 'tour-special', '巡演专场'],
  other: ['other', '其他'],
};

const normalizeEventTypeFilterKey = (value: string): string =>
  value
    .trim()
    .toLowerCase()
    .replace(/-/g, '_')
    .replace(/\s+/g, '_');

const resolveEventTypeFilterValues = (rawValue: string): string[] => {
  const trimmed = rawValue.trim();
  if (!trimmed) return [];
  const key = normalizeEventTypeFilterKey(trimmed);
  const aliases = EVENT_TYPE_FILTER_ALIASES[key];
  if (!aliases || aliases.length === 0) {
    return [trimmed];
  }
  return aliases;
};

const LINEUP_DJ_ID_PLACEHOLDER = '__UNBOUND__';
const isLineupDjIdPlaceholder = (value: string): boolean => value === LINEUP_DJ_ID_PLACEHOLDER;

const normalizeEventStageOrder = (value: unknown): string[] => {
  if (!Array.isArray(value)) return [];
  const seen = new Set<string>();
  const result: string[] = [];
  for (const item of value) {
    const text = typeof item === 'string' ? item.trim() : '';
    if (!text) continue;
    const key = text.toLocaleLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(text);
  }
  return result;
};

const buildLineupArtistsFromSlots = (slots: NormalizedLineupSlot[]): NormalizedLineupArtistInput[] => {
  const byKey = new Map<string, NormalizedLineupArtistInput>();
  for (const [index, slot] of slots.entries()) {
    const djName = String(slot.djName || '').trim();
    if (!djName) continue;
    const memberDjIds = Array.isArray(slot.memberDjIds) ? slot.memberDjIds : [];
    const primaryDjId = slot.djId && !isLineupDjIdPlaceholder(slot.djId)
      ? slot.djId
      : (memberDjIds.find((id) => typeof id === 'string' && id.trim() && !isLineupDjIdPlaceholder(id.trim())) || null);
    const key = primaryDjId ? `id:${primaryDjId}` : `name:${djName.toLowerCase()}`;
    const existing = byKey.get(key);
    if (existing) {
      if (!existing.djId && primaryDjId) existing.djId = primaryDjId;
      if (!Array.isArray(existing.memberDjIds) || !existing.memberDjIds.length) existing.memberDjIds = memberDjIds.length ? memberDjIds : (primaryDjId ? [primaryDjId] : []);
      existing.sortOrder = Math.min(existing.sortOrder, slot.sortOrder || index + 1);
      continue;
    }
    byKey.set(key, {
      djId: primaryDjId,
      memberDjIds: memberDjIds.length ? memberDjIds : (primaryDjId ? [primaryDjId] : []),
      memberNames: splitCollaborativeLineupName(djName),
      djName,
      sortOrder: slot.sortOrder || index + 1,
    });
  }
  return Array.from(byKey.values()).sort((a, b) => a.sortOrder - b.sortOrder);
};

const splitCollaborativeLineupName = (value: string): string[] => {
  const name = String(value || '').trim();
  if (!name) return [];
  const parts = name
    .replace(/\s+b3b\s+/ig, '[[B3B]]')
    .replace(/\s+b2b\s+/ig, '[[B2B]]')
    .split(/\[\[(?:B2B|B3B)\]\]/)
    .map((item) => item.trim())
    .filter(Boolean);
  return parts.length > 1 ? parts : [name];
};

const normalizeLineupMemberNamesInput = (row: Record<string, unknown>, djName: string): string[] => {
  const explicit = Array.isArray(row.memberNames)
    ? row.memberNames.map((item) => String(item || '').trim()).filter(Boolean)
    : [];
  return explicit.length ? explicit : splitCollaborativeLineupName(djName);
};

const normalizeLineupMemberDjIdsInput = (row: Record<string, unknown>, djId: string | null): Array<string | null> => {
  if (Array.isArray(row.memberDjIds)) {
    return row.memberDjIds.map((item) => {
      const id = String(item || '').trim();
      return id && !isLineupDjIdPlaceholder(id) ? id : null;
    });
  }
  return djId ? [djId] : [];
};

const normalizeLineupArtistsInput = (
  artists: unknown,
  fallbackSlots: NormalizedLineupSlot[] = []
): NormalizedLineupArtistInput[] => {
  const source = Array.isArray(artists) ? artists : null;
  if (!source) return buildLineupArtistsFromSlots(fallbackSlots);
  return normalizeCanonicalLineupArtists(
    source
      .filter((raw): raw is Record<string, unknown> => !!raw && typeof raw === 'object')
      .map((row, index) => {
        const djName = String(row.djName ?? row.name ?? row.musician ?? row.artistName ?? '').trim();
        const primaryRaw = String(row.djId || '').trim();
        const djId = primaryRaw && !isLineupDjIdPlaceholder(primaryRaw) ? primaryRaw : null;
        return {
          djId,
          memberDjIds: normalizeLineupMemberDjIdsInput(row, djId),
          memberNames: normalizeLineupMemberNamesInput(row, djName),
          djName,
          sortOrder: typeof row.sortOrder === 'number' && Number.isFinite(row.sortOrder) ? row.sortOrder : index + 1,
        };
      }),
    fallbackSlots
  ).map((artist) => ({
    ...artist,
    memberDjIds: Array.isArray(artist.memberDjIds)
      ? artist.memberDjIds
      : (artist.djId ? [artist.djId] : []),
    memberNames: Array.isArray(artist.memberNames) && artist.memberNames.length
      ? artist.memberNames
      : splitCollaborativeLineupName(artist.djName),
  }));
};

const syncEventLineupAndTimetable = async (
  tx: Prisma.TransactionClient,
  eventId: string,
  slots: NormalizedLineupSlot[],
  artists: NormalizedLineupArtistInput[],
  stageOrder: string[] = []
): Promise<void> => {
  await syncCanonicalEventLineupAndTimetable(tx, eventId, slots, artists, stageOrder);
};

const normalizeCanonicalMemberKey = (member: { djId?: string | null; memberNameSnapshot?: string | null }): string => {
  const djId = String(member.djId || '').trim();
  if (djId) return `dj:${djId}`;
  return `name:${String(member.memberNameSnapshot || '').trim().toLowerCase().replace(/\s+/g, ' ')}`;
};

const dedupeCanonicalMembers = <T extends { djId?: string | null; memberNameSnapshot?: string | null }>(members: T[]): T[] => {
  const seen = new Set<string>();
  const result: T[] = [];
  for (const member of members) {
    const key = normalizeCanonicalMemberKey(member);
    if (!key || seen.has(key)) continue;
    seen.add(key);
    result.push(member);
  }
  return result;
};

const includeEventForWeb = {
  ticketTiers: {
    orderBy: { sortOrder: 'asc' as const },
  },
  weeks: {
    orderBy: [{ sortOrder: 'asc' as const }, { weekIndex: 'asc' as const }],
  },
  eventDays: {
    orderBy: [{ sortOrder: 'asc' as const }, { overallDayIndex: 'asc' as const }],
  },
  canonicalArtists: {
    orderBy: { billingOrder: 'asc' as const },
    include: {
      primaryDj: {
        select: { id: true, name: true, avatarUrl: true, bannerUrl: true, country: true, soundCloudFollowers: true },
      },
      members: {
        orderBy: { memberOrder: 'asc' as const },
        include: {
          dj: {
            select: { id: true, name: true, avatarUrl: true, bannerUrl: true, country: true, soundCloudFollowers: true },
          },
        },
      },
    },
  },
  stages: {
    orderBy: { sortOrder: 'asc' as const },
  },
  performances: {
    orderBy: [{ startAt: 'asc' as const }, { sortOrder: 'asc' as const }],
    include: {
      stage: true,
      eventDay: {
        select: {
          id: true,
          eventDayId: true,
          weekIndex: true,
          dayIndexInWeek: true,
          overallDayIndex: true,
          date: true,
        },
      },
      eventArtist: {
        include: {
          primaryDj: {
            select: { id: true, name: true, avatarUrl: true, bannerUrl: true, country: true, soundCloudFollowers: true },
          },
          members: {
            orderBy: { memberOrder: 'asc' as const },
            include: {
              dj: {
                select: { id: true, name: true, avatarUrl: true, bannerUrl: true, country: true, soundCloudFollowers: true },
              },
            },
          },
        },
      },
    },
  },
  organizer: {
    select: { id: true, username: true, displayName: true, avatarUrl: true },
  },
  wikiFestival: {
    select: {
      id: true,
      name: true,
      nameI18n: true,
      abbreviation: true,
      aliases: true,
      country: true,
      countryI18n: true,
      city: true,
      cityI18n: true,
      avatarUrl: true,
      backgroundUrl: true,
    },
  },
};

const selectEventDetailForWeb = {
  id: true,
  name: true,
  nameI18n: true,
  wikiFestivalId: true,
  slug: true,
  archiveFestivalId: true,
  abbreviation: true,
  description: true,
  descriptionI18n: true,
  coverImageUrl: true,
  lineupImageUrl: true,
  imageAssets: true,
  referenceLinks: true,
  socialLinks: true,
  sourceProvider: true,
  sourceEventUrl: true,
  eventType: true,
  organizerName: true,
  city: true,
  cityI18n: true,
  country: true,
  countryI18n: true,
  manualLocation: true,
  locationPoint: true,
  latitude: true,
  longitude: true,
  startDate: true,
  endDate: true,
  scheduleMode: true,
  timeZone: true,
  startTime: true,
  endTime: true,
  dayRolloverHour: true,
  ticketUrl: true,
  ticketPriceMin: true,
  ticketPriceMax: true,
  ticketCurrency: true,
  ticketNotes: true,
  officialWebsite: true,
  isCancelled: true,
  visibility: true,
  isVerified: true,
  revision: true,
  createdAt: true,
  updatedAt: true,
  ticketTiers: {
    orderBy: { sortOrder: 'asc' as const },
  },
  canonicalArtists: {
    orderBy: { billingOrder: 'asc' as const },
    include: {
      primaryDj: {
        select: { id: true, name: true, avatarUrl: true, bannerUrl: true, country: true, soundCloudFollowers: true },
      },
      members: {
        orderBy: { memberOrder: 'asc' as const },
        include: {
          dj: {
            select: { id: true, name: true, avatarUrl: true, bannerUrl: true, country: true, soundCloudFollowers: true },
          },
        },
      },
    },
  },
  weeks: {
    orderBy: [{ sortOrder: 'asc' as const }, { weekIndex: 'asc' as const }],
    select: {
      id: true,
      weekIndex: true,
      label: true,
      startDate: true,
      endDate: true,
      sortOrder: true,
    },
  },
  eventDays: {
    orderBy: [{ sortOrder: 'asc' as const }, { overallDayIndex: 'asc' as const }],
    select: {
      id: true,
      eventDayId: true,
      weekIndex: true,
      dayIndexInWeek: true,
      overallDayIndex: true,
      label: true,
      weekday: true,
      date: true,
      sortOrder: true,
    },
  },
  stages: {
    orderBy: { sortOrder: 'asc' as const },
    select: { name: true },
  },
  performances: {
    orderBy: [{ startAt: 'asc' as const }, { sortOrder: 'asc' as const }],
    include: {
      stage: {
        select: { name: true },
      },
      eventDay: {
        select: {
          id: true,
          eventDayId: true,
          weekIndex: true,
          dayIndexInWeek: true,
          overallDayIndex: true,
          date: true,
        },
      },
      eventArtist: {
        include: {
          primaryDj: {
            select: { id: true, name: true, avatarUrl: true, bannerUrl: true, country: true, soundCloudFollowers: true },
          },
          members: {
            orderBy: { memberOrder: 'asc' as const },
            include: {
              dj: {
                select: { id: true, name: true, avatarUrl: true, bannerUrl: true, country: true, soundCloudFollowers: true },
              },
            },
          },
        },
      },
    },
  },
  organizer: {
    select: { id: true, username: true, displayName: true, avatarUrl: true },
  },
  wikiFestival: {
    select: {
      id: true,
      name: true,
      nameI18n: true,
      abbreviation: true,
      aliases: true,
      country: true,
      countryI18n: true,
      city: true,
      cityI18n: true,
      avatarUrl: true,
      backgroundUrl: true,
    },
  },
} satisfies Prisma.EventSelect;

const selectEventSummaryForIOS = {
  id: true,
  name: true,
  nameI18n: true,
  wikiFestivalId: true,
  slug: true,
  archiveFestivalId: true,
  abbreviation: true,
  description: true,
  descriptionI18n: true,
  coverImageUrl: true,
  lineupImageUrl: true,
  imageAssets: true,
  referenceLinks: true,
  socialLinks: true,
  sourceProvider: true,
  sourceEventUrl: true,
  eventType: true,
  organizerName: true,
  city: true,
  cityI18n: true,
  country: true,
  countryI18n: true,
  manualLocation: true,
  locationPoint: true,
  latitude: true,
  longitude: true,
  startDate: true,
  endDate: true,
  scheduleMode: true,
  timeZone: true,
  startTime: true,
  endTime: true,
  dayRolloverHour: true,
  ticketUrl: true,
  ticketPriceMin: true,
  ticketPriceMax: true,
  ticketCurrency: true,
  ticketNotes: true,
  officialWebsite: true,
  isCancelled: true,
  visibility: true,
  isVerified: true,
  revision: true,
  createdAt: true,
  updatedAt: true,
  ticketTiers: {
    orderBy: { sortOrder: 'asc' as const },
  },
  weeks: {
    orderBy: [{ sortOrder: 'asc' as const }, { weekIndex: 'asc' as const }],
    select: {
      id: true,
      weekIndex: true,
      label: true,
      startDate: true,
      endDate: true,
      sortOrder: true,
    },
  },
  eventDays: {
    orderBy: [{ sortOrder: 'asc' as const }, { overallDayIndex: 'asc' as const }],
    select: {
      id: true,
      eventDayId: true,
      weekIndex: true,
      dayIndexInWeek: true,
      overallDayIndex: true,
      label: true,
      weekday: true,
      date: true,
      sortOrder: true,
    },
  },
  stages: {
    orderBy: { sortOrder: 'asc' as const },
    select: { name: true },
  },
  organizer: {
    select: { id: true, username: true, displayName: true, avatarUrl: true },
  },
  wikiFestival: {
    select: {
      id: true,
      name: true,
      nameI18n: true,
      abbreviation: true,
      aliases: true,
      country: true,
      countryI18n: true,
      city: true,
      cityI18n: true,
      avatarUrl: true,
      backgroundUrl: true,
    },
  },
} satisfies Prisma.EventSelect;

const selectEventLineupForWeb = {
  canonicalArtists: {
    orderBy: { billingOrder: 'asc' as const },
    include: {
      primaryDj: {
        select: { id: true, name: true, avatarUrl: true, bannerUrl: true, country: true, soundCloudFollowers: true },
      },
      members: {
        orderBy: { memberOrder: 'asc' as const },
        include: {
          dj: {
            select: { id: true, name: true, avatarUrl: true, bannerUrl: true, country: true, soundCloudFollowers: true },
          },
        },
      },
    },
  },
} satisfies Prisma.EventSelect;

const selectEventTimetableForWeb = {
  performances: {
    orderBy: [{ startAt: 'asc' as const }, { sortOrder: 'asc' as const }],
    include: {
      stage: {
        select: { name: true },
      },
      eventDay: {
        select: {
          id: true,
          eventDayId: true,
          weekIndex: true,
          dayIndexInWeek: true,
          overallDayIndex: true,
          date: true,
        },
      },
      eventArtist: {
        include: {
          primaryDj: {
            select: { id: true, name: true, avatarUrl: true, bannerUrl: true, country: true, soundCloudFollowers: true },
          },
          members: {
            orderBy: { memberOrder: 'asc' as const },
            include: {
              dj: {
                select: { id: true, name: true, avatarUrl: true, bannerUrl: true, country: true, soundCloudFollowers: true },
              },
            },
          },
        },
      },
    },
  },
} satisfies Prisma.EventSelect;

const selectEventRecommendationCardForWeb = {
  id: true,
  name: true,
  nameI18n: true,
  wikiFestivalId: true,
  slug: true,
  archiveFestivalId: true,
  abbreviation: true,
  countryI18n: true,
  cityI18n: true,
  coverImageUrl: true,
  lineupImageUrl: true,
  imageAssets: true,
  eventType: true,
  organizerName: true,
  city: true,
  country: true,
  manualLocation: true,
  locationPoint: true,
  latitude: true,
  longitude: true,
  startDate: true,
  endDate: true,
  scheduleMode: true,
  timeZone: true,
  startTime: true,
  endTime: true,
  dayRolloverHour: true,
  ticketUrl: true,
  ticketPriceMin: true,
  ticketPriceMax: true,
  ticketCurrency: true,
  ticketNotes: true,
  officialWebsite: true,
  isCancelled: true,
  visibility: true,
  isVerified: true,
  createdAt: true,
  updatedAt: true,
  organizer: {
    select: { id: true, username: true, displayName: true, avatarUrl: true },
  },
  wikiFestival: {
    select: {
      id: true,
      name: true,
      nameI18n: true,
      abbreviation: true,
      aliases: true,
      country: true,
      countryI18n: true,
      city: true,
      cityI18n: true,
      avatarUrl: true,
      backgroundUrl: true,
    },
  },
  weeks: {
    orderBy: [{ sortOrder: 'asc' as const }, { weekIndex: 'asc' as const }],
    select: {
      id: true,
      weekIndex: true,
      label: true,
      startDate: true,
      endDate: true,
      sortOrder: true,
    },
  },
  eventDays: {
    orderBy: [{ sortOrder: 'asc' as const }, { overallDayIndex: 'asc' as const }],
    select: {
      id: true,
      eventDayId: true,
      weekIndex: true,
      dayIndexInWeek: true,
      overallDayIndex: true,
      label: true,
      weekday: true,
      date: true,
      sortOrder: true,
    },
  },
  _count: {
    select: {
      canonicalArtists: true,
      performances: true,
    },
  },
} satisfies Prisma.EventSelect;

const selectEventListCardForWeb = {
  id: true,
  name: true,
  nameI18n: true,
  wikiFestivalId: true,
  slug: true,
  archiveFestivalId: true,
  abbreviation: true,
  description: true,
  descriptionI18n: true,
  countryI18n: true,
  cityI18n: true,
  coverImageUrl: true,
  lineupImageUrl: true,
  imageAssets: true,
  eventType: true,
  organizerName: true,
  city: true,
  country: true,
  manualLocation: true,
  locationPoint: true,
  latitude: true,
  longitude: true,
  startDate: true,
  endDate: true,
  scheduleMode: true,
  timeZone: true,
  startTime: true,
  endTime: true,
  dayRolloverHour: true,
  ticketUrl: true,
  ticketPriceMin: true,
  ticketPriceMax: true,
  ticketCurrency: true,
  ticketNotes: true,
  officialWebsite: true,
  isCancelled: true,
  visibility: true,
  isVerified: true,
  createdAt: true,
  updatedAt: true,
  organizer: {
    select: { id: true, username: true, displayName: true, avatarUrl: true },
  },
  wikiFestival: {
    select: {
      id: true,
      name: true,
      nameI18n: true,
      abbreviation: true,
      aliases: true,
      country: true,
      countryI18n: true,
      city: true,
      cityI18n: true,
      avatarUrl: true,
      backgroundUrl: true,
    },
  },
  weeks: {
    orderBy: [{ sortOrder: 'asc' as const }, { weekIndex: 'asc' as const }],
    select: {
      id: true,
      weekIndex: true,
      label: true,
      startDate: true,
      endDate: true,
      sortOrder: true,
    },
  },
  eventDays: {
    orderBy: [{ sortOrder: 'asc' as const }, { overallDayIndex: 'asc' as const }],
    select: {
      id: true,
      eventDayId: true,
      weekIndex: true,
      dayIndexInWeek: true,
      overallDayIndex: true,
      label: true,
      weekday: true,
      date: true,
      sortOrder: true,
    },
  },
  _count: {
    select: {
      canonicalArtists: true,
      performances: true,
    },
  },
} satisfies Prisma.EventSelect;

const normalizeName = (value: string): string => value.toLowerCase().replace(/[^a-z0-9\u4e00-\u9fa5]/g, '');

const parseRankingText = (text: string): Array<{ rank: number; name: string }> =>
  text
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => {
      const match = line.match(/^(\d+)\.\s+(.+)$/);
      if (!match) return null;
      return { rank: Number(match[1]), name: String(match[2]).trim() };
    })
    .filter((item): item is { rank: number; name: string } => item !== null)
    .sort((a, b) => a.rank - b.rank);

const eventUploadDir = path.join(process.cwd(), 'uploads', 'events');
const djSetUploadDir = path.join(process.cwd(), 'uploads', 'dj-sets');
const feedUploadDir = path.join(process.cwd(), 'uploads', 'feed');
const djUploadDir = path.join(process.cwd(), 'uploads', 'djs');
const ratingUploadDir = path.join(process.cwd(), 'uploads', 'ratings');
const wikiBrandUploadDir = path.join(process.cwd(), 'uploads', 'wiki-brands');
for (const dir of [eventUploadDir, djSetUploadDir, feedUploadDir, djUploadDir, ratingUploadDir, wikiBrandUploadDir]) {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
}

const createImageUpload = (destinationDir: string, maxSize: number) =>
  multer({
    storage: multer.diskStorage({
      destination: (_req, _file, cb) => cb(null, destinationDir),
      filename: (_req, file, cb) => {
        const ext = path.extname(file.originalname || '').toLowerCase();
        const safeExt = ext && ext.length <= 8 ? ext : '.jpg';
        cb(null, `${Date.now()}-${Math.random().toString(36).slice(2, 10)}${safeExt}`);
      },
    }),
    limits: { fileSize: maxSize },
    fileFilter: (_req, file, cb) => {
      if (!file.mimetype.startsWith('image/')) {
        cb(new Error('Only image files are allowed'));
        return;
      }
      cb(null, true);
    },
  });

const createVideoUpload = (destinationDir: string, maxSize: number) =>
  multer({
    storage: multer.diskStorage({
      destination: (_req, _file, cb) => cb(null, destinationDir),
      filename: (_req, file, cb) => {
        const ext = path.extname(file.originalname || '').toLowerCase();
        const safeExt = ext && ext.length <= 8 ? ext : '.mp4';
        cb(null, `${Date.now()}-${Math.random().toString(36).slice(2, 10)}${safeExt}`);
      },
    }),
    limits: { fileSize: maxSize },
    fileFilter: (_req, file, cb) => {
      if (!file.mimetype.startsWith('video/')) {
        cb(new Error('Only video files are allowed'));
        return;
      }
      cb(null, true);
    },
  });

const STANDARD_IMAGE_UPLOAD_MAX_BYTES = 10 * 1024 * 1024;
const eventImageUpload = createImageUpload(eventUploadDir, STANDARD_IMAGE_UPLOAD_MAX_BYTES);
const lineupImportImageUpload = createImageUpload(eventUploadDir, STANDARD_IMAGE_UPLOAD_MAX_BYTES);
const djSetThumbUpload = createImageUpload(djSetUploadDir, STANDARD_IMAGE_UPLOAD_MAX_BYTES);
const djSetVideoUpload = createVideoUpload(djSetUploadDir, 300 * 1024 * 1024);
const feedImageUpload = createImageUpload(feedUploadDir, STANDARD_IMAGE_UPLOAD_MAX_BYTES);
const feedVideoUpload = createVideoUpload(feedUploadDir, 300 * 1024 * 1024);
const djImageUpload = createImageUpload(djUploadDir, STANDARD_IMAGE_UPLOAD_MAX_BYTES);
const ratingImageUpload = createImageUpload(ratingUploadDir, STANDARD_IMAGE_UPLOAD_MAX_BYTES);
const wikiBrandImageUpload = createImageUpload(wikiBrandUploadDir, STANDARD_IMAGE_UPLOAD_MAX_BYTES);

type EventUploadTimingContext = {
  requestId: string;
  startedAtMs: number;
  startedAtHr: bigint;
};

const elapsedMsFrom = (startedAtHr: bigint): number => Number(process.hrtime.bigint() - startedAtHr) / 1_000_000;

const nextEventUploadRequestId = (): string =>
  `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;

const eventUploadTimingStart = (
  req: Request & { eventUploadTiming?: EventUploadTimingContext },
  _res: Response,
  next: NextFunction
): void => {
  req.eventUploadTiming = {
    requestId: nextEventUploadRequestId(),
    startedAtMs: Date.now(),
    startedAtHr: process.hrtime.bigint(),
  };
  next();
};

const cleanEnv = (value: string | undefined): string | null => {
  if (!value) return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
};

const ossRegion = cleanEnv(process.env.OSS_REGION);
const ossAccessKeyId = cleanEnv(process.env.OSS_ACCESS_KEY_ID);
const ossAccessKeySecret = cleanEnv(process.env.OSS_ACCESS_KEY_SECRET);
const ossBucket = cleanEnv(process.env.OSS_BUCKET);
const ossEndpoint = cleanEnv(process.env.OSS_ENDPOINT);
const ossPostsPrefix = (cleanEnv(process.env.OSS_POSTS_PREFIX) || 'posts').replace(/^\/+|\/+$/g, '');
const ossEventsPrefix = (cleanEnv(process.env.OSS_EVENTS_PREFIX) || 'wen-jasonlee/events').replace(/^\/+|\/+$/g, '');
const ossDjsPrefix = (cleanEnv(process.env.OSS_DJS_PREFIX) || 'wen-jasonlee/djs').replace(/^\/+|\/+$/g, '');
const ossDjSetsPrefix = (cleanEnv(process.env.OSS_DJ_SETS_PREFIX) || 'wen-jasonlee/dj-sets').replace(/^\/+|\/+$/g, '');
const ossRatingsPrefix = (cleanEnv(process.env.OSS_RATINGS_PREFIX) || 'wen-jasonlee/ratings').replace(/^\/+|\/+$/g, '');
const ossWikiBrandsPrefix = (cleanEnv(process.env.OSS_WIKI_BRANDS_PREFIX) || 'wiki/brands').replace(/^\/+|\/+$/g, '');
const getRuntimeCozeConfig = () =>
  getServerCozeRuntimeConfig({
    ossBucket,
  });

const tryParseUrlHost = (value: string | null | undefined): string | null => {
  const trimmed = String(value || '').trim();
  if (!trimmed) return null;
  try {
    return new URL(trimmed).host.toLowerCase();
  } catch {
    return null;
  }
};

const publicOssBaseUrlForCurrentBucket = (() => {
  if (!ossBucket || !ossRegion) return null;
  const endpointHost = ossEndpoint
    ? ossEndpoint.replace(/^https?:\/\//, '').replace(/^\/+|\/+$/g, '')
    : `${ossRegion}.aliyuncs.com`;
  const bucketHost = endpointHost.startsWith(`${ossBucket}.`) ? endpointHost : `${ossBucket}.${endpointHost}`;
  return `https://${bucketHost}`;
})();

const currentRequestOrigin = (req: Request): string => {
  const cozePublicBaseUrl = getRuntimeCozeConfig().publicBaseUrl;
  if (cozePublicBaseUrl) {
    return cozePublicBaseUrl.replace(/\/+$/g, '');
  }
  const forwardedProto = String(req.headers['x-forwarded-proto'] || '').split(',')[0].trim();
  const protocol = forwardedProto || req.protocol || 'https';
  const host = String(req.headers['x-forwarded-host'] || req.get('host') || '').split(',')[0].trim();
  return host ? `${protocol}://${host}` : '';
};

const resolvePublicImageUrlForCoze = (req: Request, imageUrl: string): string => {
  const trimmed = imageUrl.trim();
  if (!trimmed) return trimmed;
  if (/^https?:\/\//i.test(trimmed) || trimmed.startsWith('data:')) {
    return trimmed;
  }
  if (trimmed.startsWith('/')) {
    const origin = currentRequestOrigin(req);
    return origin ? `${origin}${trimmed}` : trimmed;
  }
  return trimmed;
};

const rewriteImageUrlToCozeAcceleratedOss = (
  imageUrl: string
): { url: string; rewritten: boolean; reason: 'accelerate' | 'passthrough' } => {
  const cozeOssAccelerateBaseUrl = getRuntimeCozeConfig().ossAccelerateBaseUrl;
  const cozeAcceleratedSourceHosts = new Set(
    [
      publicOssBaseUrlForCurrentBucket,
      cozeOssAccelerateBaseUrl,
      cleanEnv(process.env.MEDIA_PUBLIC_BASE_URL),
      cleanEnv(process.env.OSS_PUBLIC_BASE_URL),
      cleanEnv(process.env.MEDIA_CDN_BASE_URL),
    ]
      .map((value) => tryParseUrlHost(value))
      .filter((value): value is string => Boolean(value))
  );
  const trimmed = imageUrl.trim();
  if (!trimmed || !cozeOssAccelerateBaseUrl || !/^https?:\/\//i.test(trimmed)) {
    return { url: trimmed, rewritten: false, reason: 'passthrough' };
  }

  let parsed: URL;
  try {
    parsed = new URL(trimmed);
  } catch {
    return { url: trimmed, rewritten: false, reason: 'passthrough' };
  }

  if (!cozeAcceleratedSourceHosts.has(parsed.host.toLowerCase())) {
    return { url: trimmed, rewritten: false, reason: 'passthrough' };
  }

  const objectKey = parsed.pathname.replace(/^\/+/, '');
  if (!objectKey) {
    return { url: trimmed, rewritten: false, reason: 'passthrough' };
  }

  const search = parsed.search || '';
  const hash = parsed.hash || '';
  return {
    url: `${cozeOssAccelerateBaseUrl}/${objectKey}${search}${hash}`,
    rewritten: true,
    reason: 'accelerate',
  };
};

const buildCozeImportObjectKey = (
  scope: 'lineup' | 'poster' | 'timetable',
  fileName: string,
  mimeType: string
): string => {
  const rawExt = path.extname(fileName || '').toLowerCase();
  const mimeExt = mimeType.includes('png')
    ? '.png'
    : mimeType.includes('webp')
      ? '.webp'
      : mimeType.includes('gif')
        ? '.gif'
        : '.jpg';
  const ext = rawExt && rawExt.length <= 10 ? rawExt : mimeExt;
  return `${ossEventsPrefix}/${scope}-imports/${Date.now()}-${Math.random().toString(36).slice(2, 10)}${ext}`;
};

const isLegacyCozeUploadUrl = (req: Request, imageUrl: string): boolean => {
  const trimmed = imageUrl.trim();
  if (!trimmed) return false;

  let pathname = '';
  if (/^https?:\/\//i.test(trimmed)) {
    try {
      const parsed = new URL(trimmed);
      const currentOrigin = currentRequestOrigin(req);
      const parsedOrigin = `${parsed.protocol}//${parsed.host}`;
      if (currentOrigin && parsedOrigin !== currentOrigin) return false;
      pathname = parsed.pathname;
    } catch (_error) {
      return false;
    }
  } else if (trimmed.startsWith('/')) {
    pathname = trimmed;
  } else {
    return false;
  }

  return pathname.startsWith('/uploads/');
};

const ensureCozeAccessibleImageUrl = async (
  req: Request,
  imageUrl: string,
  _fileType: string,
  scope: 'lineup' | 'poster' | 'timetable'
): Promise<string> => {
  if (isLegacyCozeUploadUrl(req, imageUrl)) {
    throw new Error(`Legacy /uploads image URLs are no longer supported for Coze ${scope} imports`);
  }
  const publicUrl = resolvePublicImageUrlForCoze(req, imageUrl);
  const accelerated = rewriteImageUrlToCozeAcceleratedOss(publicUrl);
  console.info('[coze-image] resolve', {
    scope,
    originalUrl: imageUrl,
    publicUrl,
    resolvedUrl: accelerated.url,
    rewritten: accelerated.rewritten,
    mode: accelerated.reason,
  });
  return accelerated.url;
};

const postMediaOssClient =
  ossRegion && ossAccessKeyId && ossAccessKeySecret && ossBucket
    ? new OSS({
        region: ossRegion,
        accessKeyId: ossAccessKeyId,
        accessKeySecret: ossAccessKeySecret,
        bucket: ossBucket,
        endpoint: ossEndpoint || undefined,
      })
    : null;

const youtubeProxyUrl = (process.env.YOUTUBE_PROXY_URL || process.env.YOUTUBE_HTTPS_PROXY || 'http://127.0.0.1:7897').trim();

const youtubeAxiosProxyConfig = (): Pick<AxiosRequestConfig, 'proxy'> => {
  if (!youtubeProxyUrl) return {};
  try {
    const parsed = new URL(youtubeProxyUrl);
    return {
      proxy: {
        protocol: parsed.protocol.replace(':', ''),
        host: parsed.hostname,
        port: Number(parsed.port || 80),
      },
    };
  } catch (_error) {
    return {};
  }
};

const looksLikePostMediaName = (name: string, kind: 'image' | 'video'): boolean => {
  const lower = name.trim().toLowerCase();
  if (!lower) return false;
  if (kind === 'image') {
    return lower.startsWith('post-image-');
  }
  return lower.startsWith('post-video-');
};

const normalizeUploadedOssUrl = (rawUrl: string | undefined, objectKey: string): string => {
  if (rawUrl && rawUrl.trim().length > 0) {
    if (rawUrl.startsWith('//')) return `https:${rawUrl}`;
    if (rawUrl.startsWith('http://')) return `https://${rawUrl.slice('http://'.length)}`;
    if (rawUrl.startsWith('https://')) return rawUrl;
  }

  if (!ossBucket || !ossRegion) {
    throw new Error('OSS bucket/region is not configured');
  }
  const endpointHost = ossEndpoint
    ? ossEndpoint.replace(/^https?:\/\//, '').replace(/^\/+|\/+$/g, '')
    : `${ossRegion}.aliyuncs.com`;
  const bucketHost = endpointHost.startsWith(`${ossBucket}.`) ? endpointHost : `${ossBucket}.${endpointHost}`;
  return `https://${bucketHost}/${objectKey}`;
};

const parseOptionalImageSort = (value: unknown): number | null => {
  if (value === null || value === undefined || value === '') return null;
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return null;
  return Math.max(0, Math.trunc(parsed));
};

type WikiBrandImageUsage = 'avatar' | 'background' | 'poster' | 'proof' | 'other';
const WIKI_BRAND_IMAGE_USAGES = new Set<WikiBrandImageUsage>([
  'avatar',
  'background',
  'poster',
  'proof',
  'other',
]);

const parseWikiBrandImageUsage = (value: unknown): WikiBrandImageUsage | null => {
  if (typeof value !== 'string') return null;
  const normalized = value.trim().toLowerCase();
  return WIKI_BRAND_IMAGE_USAGES.has(normalized as WikiBrandImageUsage)
    ? (normalized as WikiBrandImageUsage)
    : null;
};

const computeBufferSha256 = (buffer: Buffer): string =>
  crypto.createHash('sha256').update(buffer).digest('hex');

class WikiBrandImageValidationError extends Error {}

const WIKI_BRAND_PROOF_MIN_SHORT_EDGE_PX = 1200;
const WIKI_BRAND_PUBLIC_IMAGE_JPEG_QUALITY = 90;

const canonicalizeImageMimeType = (mimeType: string | null | undefined): string => {
  const normalized = String(mimeType || '').toLowerCase();
  if (normalized.includes('png')) return 'image/png';
  if (normalized.includes('webp')) return 'image/webp';
  if (normalized.includes('jpeg') || normalized.includes('jpg')) return 'image/jpeg';
  if (normalized.includes('gif')) return 'image/gif';
  return 'image/jpeg';
};

const normalizedImageExtensionFromMimeType = (mimeType: string): string => {
  if (mimeType.includes('png')) return '.png';
  if (mimeType.includes('webp')) return '.webp';
  if (mimeType.includes('gif')) return '.gif';
  return '.jpg';
};

const normalizeWikiBrandUploadImage = (
  buffer: Buffer,
  mimeType: string | null | undefined,
  usage: string | null
): {
  buffer: Buffer;
  mimeType: string;
} => {
  const canonicalMimeType = canonicalizeImageMimeType(mimeType);

  if (usage === 'proof') {
    if (canonicalMimeType === 'image/png' || canonicalMimeType === 'image/jpeg' || canonicalMimeType === 'image/webp') {
      return {
        buffer,
        mimeType: canonicalMimeType,
      };
    }
    throw new WikiBrandImageValidationError('proof image must be png, jpeg, or webp');
  }

  if (canonicalMimeType === 'image/webp') {
    return {
      buffer,
      mimeType: canonicalMimeType,
    };
  }

  if (canonicalMimeType === 'image/png') {
    const decoded = PNG.sync.read(buffer);
    const encoded = jpeg.encode(
      {
        data: decoded.data,
        width: decoded.width,
        height: decoded.height,
      },
      WIKI_BRAND_PUBLIC_IMAGE_JPEG_QUALITY
    );
    return {
      buffer: Buffer.from(encoded.data),
      mimeType: 'image/jpeg',
    };
  }

  if (canonicalMimeType === 'image/jpeg') {
    const decoded = jpeg.decode(buffer, { useTArray: true });
    const encoded = jpeg.encode(
      {
        data: decoded.data,
        width: decoded.width,
        height: decoded.height,
      },
      WIKI_BRAND_PUBLIC_IMAGE_JPEG_QUALITY
    );
    return {
      buffer: Buffer.from(encoded.data),
      mimeType: 'image/jpeg',
    };
  }

  throw new WikiBrandImageValidationError('brand image must be png, jpeg, or webp');
};

const validateWikiBrandImageDimensions = (
  usage: string | null,
  dimensions: { width: number | null; height: number | null }
): void => {
  if (usage !== 'proof') return;
  if (!dimensions.width || !dimensions.height) return;
  const shortEdge = Math.min(dimensions.width, dimensions.height);
  if (shortEdge < WIKI_BRAND_PROOF_MIN_SHORT_EDGE_PX) {
    throw new WikiBrandImageValidationError(
      `proof image is too small; shortest edge must be at least ${WIKI_BRAND_PROOF_MIN_SHORT_EDGE_PX}px`
    );
  }
};

const buildWikiBrandUploadResponseFromAsset = (
  asset: {
    id: string;
    url: string;
    mimeType: string | null;
    sizeBytes: number | null;
    width: number | null;
    height: number | null;
    ownerType: string;
    ownerId: string | null;
    objectKey: string | null;
    metadata: Prisma.JsonValue | null;
  },
  fallbackSort: number | null
) => {
  const metadata = asset.metadata && typeof asset.metadata === 'object' && !Array.isArray(asset.metadata)
    ? (asset.metadata as Record<string, unknown>)
    : {};
  const sortRaw = metadata.sort;
  const originalUrlRaw = metadata.originalUrl;
  const normalizedSort =
    typeof sortRaw === 'number' && Number.isFinite(sortRaw)
      ? Math.max(0, Math.trunc(sortRaw))
      : fallbackSort;
  const originalUrl =
    typeof originalUrlRaw === 'string' && originalUrlRaw.trim().length > 0
      ? originalUrlRaw.trim()
      : asset.url;

  return {
    assetId: asset.id,
    url: asset.url,
    originalUrl,
    fileName: path.basename(asset.objectKey || asset.url.split('?')[0] || 'image.jpg'),
    mimeType: asset.mimeType || 'image/jpeg',
    size: asset.sizeBytes ?? 0,
    width: asset.width,
    height: asset.height,
    sort: normalizedSort,
    ownerType: asset.ownerType,
    ownerId: asset.ownerId,
  };
};

const findReusableWikiBrandMediaAsset = async (
  ownerType: 'wiki_brand' | 'wiki_brand_draft',
  ownerId: string,
  purpose: string,
  contentHash: string
) => prisma.mediaAsset.findFirst({
  where: {
    ownerType,
    ownerId,
    purpose,
    status: 'active',
    metadata: {
      path: ['contentHash'],
      equals: contentHash,
    },
  },
  select: {
    id: true,
    url: true,
    mimeType: true,
    sizeBytes: true,
    width: true,
    height: true,
    ownerType: true,
    ownerId: true,
    objectKey: true,
    metadata: true,
  },
});

const normalizeWikiBrandImageVisibility = (usage: string | null): 'public' | 'review_only' =>
  usage === 'proof' ? 'review_only' : 'public';

const inferImageDimensionsFromBuffer = (
  buffer: Buffer,
  mimeType: string | null | undefined
): { width: number | null; height: number | null } => {
  if (!buffer.length) return { width: null, height: null };

  const normalizedMime = String(mimeType || '').toLowerCase();
  try {
    if (normalizedMime.includes('png')) {
      const png = PNG.sync.read(buffer);
      return {
        width: Number.isFinite(png.width) ? png.width : null,
        height: Number.isFinite(png.height) ? png.height : null,
      };
    }
    if (normalizedMime.includes('jpeg') || normalizedMime.includes('jpg')) {
      const decoded = jpeg.decode(buffer, { useTArray: true });
      return {
        width: Number.isFinite(decoded.width) ? decoded.width : null,
        height: Number.isFinite(decoded.height) ? decoded.height : null,
      };
    }
  } catch (error) {
    console.warn('BFF web infer image dimensions failed:', {
      mimeType: normalizedMime,
      error: error instanceof Error ? error.message : String(error),
    });
  }

  return { width: null, height: null };
};

const sanitizeOssPathSegment = (value: string): string =>
  value
    .trim()
    .replace(/[^a-zA-Z0-9-_]/g, '')
    .slice(0, 128);

const buildEventMediaObjectKey = (
  eventId: string,
  fileName: string,
  mimeType: string,
  usage: string | null
): string => {
  const rawExt = path.extname(fileName || '').toLowerCase();
  const mimeExt = mimeType.includes('png')
    ? '.png'
    : mimeType.includes('webp')
      ? '.webp'
      : mimeType.includes('gif')
        ? '.gif'
        : '.jpg';
  const ext = rawExt && rawExt.length <= 10 ? rawExt : mimeExt;
  const safeEventId = sanitizeOssPathSegment(eventId) || 'unknown-event';
  const safeUsage = sanitizeOssPathSegment(usage || '') || 'image';
  return `${ossEventsPrefix}/${safeEventId}/${safeUsage}-${Date.now()}-${Math.random().toString(36).slice(2, 10)}${ext}`;
};

const buildEventDraftMediaObjectKey = (
  userId: string,
  draftId: string,
  fileName: string,
  mimeType: string,
  usage: string | null
): string => {
  const rawExt = path.extname(fileName || '').toLowerCase();
  const mimeExt = mimeType.includes('png')
    ? '.png'
    : mimeType.includes('webp')
      ? '.webp'
      : mimeType.includes('gif')
        ? '.gif'
        : '.jpg';
  const ext = rawExt && rawExt.length <= 10 ? rawExt : mimeExt;
  const safeUserId = sanitizeOssPathSegment(userId) || 'unknown-user';
  const safeDraftId = sanitizeOssPathSegment(draftId) || 'unknown-draft';
  const safeUsage = sanitizeOssPathSegment(usage || '') || 'image';
  return `${ossEventsPrefix}/drafts/${safeUserId}/${safeDraftId}/${safeUsage}-${Date.now()}-${Math.random().toString(36).slice(2, 10)}${ext}`;
};

const buildRatingMediaObjectKey = (
  owner: {
    userId: string;
    ratingEventId?: string | null;
    ratingUnitId?: string | null;
  },
  fileName: string,
  mimeType: string,
  usage: string | null
): string => {
  const rawExt = path.extname(fileName || '').toLowerCase();
  const mimeExt = mimeType.includes('png')
    ? '.png'
    : mimeType.includes('webp')
      ? '.webp'
      : mimeType.includes('gif')
        ? '.gif'
        : '.jpg';
  const ext = rawExt && rawExt.length <= 10 ? rawExt : mimeExt;
  const safeUsage = sanitizeOssPathSegment(usage || '') || 'image';

  const safeRatingEventId = sanitizeOssPathSegment(owner.ratingEventId || '');
  const safeRatingUnitId = sanitizeOssPathSegment(owner.ratingUnitId || '');
  const safeUserId = sanitizeOssPathSegment(owner.userId) || 'unknown-user';

  if (safeRatingEventId && safeRatingUnitId) {
    return `${ossRatingsPrefix}/events/${safeRatingEventId}/units/${safeRatingUnitId}/${safeUsage}-${Date.now()}-${Math.random().toString(36).slice(2, 10)}${ext}`;
  }
  if (safeRatingEventId) {
    return `${ossRatingsPrefix}/events/${safeRatingEventId}/${safeUsage}-${Date.now()}-${Math.random().toString(36).slice(2, 10)}${ext}`;
  }
  if (safeRatingUnitId) {
    return `${ossRatingsPrefix}/units/${safeRatingUnitId}/${safeUsage}-${Date.now()}-${Math.random().toString(36).slice(2, 10)}${ext}`;
  }
  return `${ossRatingsPrefix}/drafts/${safeUserId}/${safeUsage}-${Date.now()}-${Math.random().toString(36).slice(2, 10)}${ext}`;
};

const parseOssObjectKeyFromUrl = (value: string | null | undefined): string | null => {
  if (!value) return null;
  const trimmed = value.trim();
  if (!trimmed) return null;

  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    try {
      const parsed = new URL(trimmed);
      const key = parsed.pathname.replace(/^\/+/, '');
      return key || null;
    } catch (_error) {
      return null;
    }
  }

  return null;
};

const isEventOssObjectKey = (objectKey: string, eventId: string): boolean => {
  const safeEventId = sanitizeOssPathSegment(eventId);
  if (!safeEventId) return false;
  return objectKey.startsWith(`${ossEventsPrefix}/${safeEventId}/`);
};

const isEventDraftOssObjectKey = (objectKey: string, userId: string, draftId: string): boolean => {
  const safeUserId = sanitizeOssPathSegment(userId);
  const safeDraftId = sanitizeOssPathSegment(draftId);
  if (!safeUserId || !safeDraftId) return false;
  return objectKey.startsWith(`${ossEventsPrefix}/drafts/${safeUserId}/${safeDraftId}/`);
};

const isDjAvatarOssObjectKey = (objectKey: string, djId: string): boolean => {
  const safeDJId = sanitizeOssPathSegment(djId);
  if (!safeDJId) return false;
  return objectKey.startsWith(`${ossDjsPrefix}/${safeDJId}/`);
};

const isDJDraftOssObjectKey = (objectKey: string, userId: string, draftId: string): boolean => {
  const safeUserId = sanitizeOssPathSegment(userId);
  const safeDraftId = sanitizeOssPathSegment(draftId);
  if (!safeUserId || !safeDraftId) return false;
  return objectKey.startsWith(`${ossDjsPrefix}/drafts/${safeUserId}/${safeDraftId}/`);
};

const isWikiBrandOssObjectKey = (objectKey: string, brandId: string): boolean => {
  const safeBrandId = sanitizeOssPathSegment(brandId);
  if (!safeBrandId) return false;
  return objectKey.startsWith(`${ossWikiBrandsPrefix}/${safeBrandId}/`);
};

const isWikiBrandDraftOssObjectKey = (objectKey: string, userId: string, draftId: string): boolean => {
  const safeUserId = sanitizeOssPathSegment(userId);
  const safeDraftId = sanitizeOssPathSegment(draftId);
  if (!safeUserId || !safeDraftId) return false;
  return objectKey.startsWith(`${ossWikiBrandsPrefix}/drafts/${safeUserId}/${safeDraftId}/`);
};

const isRatingOssObjectKey = (objectKey: string): boolean => objectKey.startsWith(`${ossRatingsPrefix}/`);

const normalizeDJNameKey = (value: string): string => value.trim().toLowerCase();

const mergeAliases = (baseName: string, values: Array<string | null | undefined>): string[] => {
  const baseKey = normalizeDJNameKey(baseName);
  const result: string[] = [];
  const seen = new Set<string>([baseKey]);

  for (const raw of values) {
    if (!raw) continue;
    const trimmed = raw.trim();
    if (!trimmed) continue;
    const key = normalizeDJNameKey(trimmed);
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(trimmed);
  }

  return result;
};

const normalizeGenres = (value: unknown): string[] => {
  const list = Array.isArray(value)
    ? value
    : typeof value === 'string'
      ? value.split(/[,\n/\uFF0C\u3001|;]+/g)
      : [];
  const result: string[] = [];
  const seen = new Set<string>();
  for (const item of list) {
    if (typeof item !== 'string') continue;
    const trimmed = item.trim();
    if (!trimmed) continue;
    const key = trimmed.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(trimmed);
  }
  return result;
};

const parseOptionalNonNegativeInt = (value: unknown, fieldName: string): number | null => {
  if (value === null || value === undefined) return null;
  if (typeof value === 'number') {
    if (!Number.isFinite(value)) {
      throw new Error(`${fieldName} must be a finite number or null`);
    }
    return Math.max(0, Math.floor(value));
  }
  if (typeof value === 'string') {
    const trimmed = value.trim();
    if (!trimmed) return null;
    if (!/^\d+$/.test(trimmed)) {
      throw new Error(`${fieldName} must be a non-negative integer or null`);
    }
    return Math.max(0, Math.floor(Number(trimmed)));
  }
  throw new Error(`${fieldName} must be a number, string, or null`);
};

const payloadHasAnyKey = (payload: Record<string, unknown>, keys: string[]): boolean =>
  keys.some((key) => Object.prototype.hasOwnProperty.call(payload, key));

const payloadValueByKeys = (payload: Record<string, unknown>, keys: string[]): unknown => {
  for (const key of keys) {
    if (Object.prototype.hasOwnProperty.call(payload, key)) {
      return payload[key];
    }
  }
  return undefined;
};

const parseOptionalStringFromPayload = (payload: Record<string, unknown>, keys: string[]): string => {
  const value = payloadValueByKeys(payload, keys);
  return typeof value === 'string' ? value.trim() : '';
};

const splitDataSources = (value: string | null | undefined): string[] => {
  if (!value) return [];
  return value
    .split(/[|,;]+/)
    .map((item) => item.trim())
    .filter(Boolean);
};

const mergeDJDataSources = (
  existing: string | null | undefined,
  additions: Array<string | null | undefined>
): string | null => {
  const result: string[] = [];
  const seen = new Set<string>();

  const push = (raw: string | null | undefined) => {
    if (!raw) return;
    const trimmed = raw.trim();
    if (!trimmed) return;
    const key = trimmed.toLowerCase();
    if (seen.has(key)) return;
    seen.add(key);
    result.push(trimmed);
  };

  for (const source of splitDataSources(existing)) {
    push(source);
  }
  for (const source of additions) {
    push(source);
  }

  return result.length > 0 ? result.join('|') : null;
};

const contributorInfoFromRow = (row: any): ContributorInfo =>
  (row?.__contributorInfo as ContributorInfo | undefined) ?? emptyContributorInfo;

type DJStatsInfo = {
  eventCount: number;
  setCount: number;
};

const emptyDJStatsInfo: DJStatsInfo = {
  eventCount: 0,
  setCount: 0,
};

const statsInfoFromRow = (row: any): DJStatsInfo =>
  (row?.__statsInfo as DJStatsInfo | undefined) ?? emptyDJStatsInfo;

const fetchDJContributorInfoMap = async (djIds: string[]) =>
  fetchContributorInfoMap(prisma, 'dj', djIds);

const fetchDJStatsInfoMap = async (djIds: string[]): Promise<Map<string, DJStatsInfo>> => {
  const validIds = Array.from(new Set(djIds.map((id) => id.trim()).filter(Boolean)));
  if (validIds.length === 0) {
    return new Map();
  }

  const [eventRows, setRows] = await Promise.all([
    prisma.$queryRaw<Array<{ djId: string; eventCount: number }>>(Prisma.sql`
      WITH "event_djs" AS (
        SELECT
          "artist"."event_id" AS "eventId",
          "member"."dj_id" AS "djId"
        FROM "event_artist_members" AS "member"
        JOIN "event_artists" AS "artist"
          ON "artist"."id" = "member"."event_artist_id"
        WHERE "member"."dj_id" IN (${Prisma.join(validIds)})
      )
      SELECT
        "event_djs"."djId" AS "djId",
        COUNT(DISTINCT "event_djs"."eventId")::int AS "eventCount"
      FROM "event_djs"
      GROUP BY "event_djs"."djId"
    `),
    prisma.$queryRaw<Array<{ djId: string; setCount: number }>>(Prisma.sql`
      SELECT
        "s"."dj_id" AS "djId",
        COUNT(*)::int AS "setCount"
      FROM "dj_sets" AS "s"
      WHERE "s"."dj_id" IN (${Prisma.join(validIds)})
      GROUP BY "s"."dj_id"
    `),
  ]);

  const map = new Map<string, DJStatsInfo>();
  for (const id of validIds) {
    map.set(id, { ...emptyDJStatsInfo });
  }

  for (const row of eventRows) {
    const current = map.get(row.djId) ?? { ...emptyDJStatsInfo };
    current.eventCount = Number(row.eventCount || 0);
    map.set(row.djId, current);
  }

  for (const row of setRows) {
    const current = map.get(row.djId) ?? { ...emptyDJStatsInfo };
    current.setCount = Number(row.setCount || 0);
    map.set(row.djId, current);
  }

  return map;
};

const attachDJContributorInfo = async (row: any): Promise<any> => {
  if (!row?.id) return row;
  const [contributorMap, statsMap] = await Promise.all([
    fetchDJContributorInfoMap([String(row.id)]),
    fetchDJStatsInfoMap([String(row.id)]),
  ]);
  return {
    ...row,
    __contributorInfo: contributorMap.get(String(row.id)) ?? emptyContributorInfo,
    __statsInfo: statsMap.get(String(row.id)) ?? emptyDJStatsInfo,
  };
};

const attachDJContributorInfoList = async (rows: any[]): Promise<any[]> => {
  if (rows.length === 0) return rows;
  const ids = rows.map((row) => String(row.id));
  const [contributorMap, statsMap] = await Promise.all([
    fetchDJContributorInfoMap(ids),
    fetchDJStatsInfoMap(ids),
  ]);
  return rows.map((row) => ({
    ...row,
    __contributorInfo: contributorMap.get(String(row.id)) ?? emptyContributorInfo,
    __statsInfo: statsMap.get(String(row.id)) ?? emptyDJStatsInfo,
  }));
};

const isDJContributorByRow = (row: any, userId: string | null | undefined): boolean => {
  if (!userId) return false;
  return contributorInfoFromRow(row).userIds.includes(userId);
};

const isDJContributor = async (djId: string, userId: string): Promise<boolean> => {
  return isContributorForEntity(prisma, 'dj', djId, userId);
};

const canUserEditDJ = async (
  djId: string,
  userId: string,
  role: string | null | undefined
): Promise<boolean> => {
  if (role === 'admin') return true;
  return isDJContributor(djId, userId);
};

const recordDirectDJContribution = async (
  dj: {
    id: string;
    name: string;
    avatarUrl?: string | null;
  },
  userId: string,
  actionType: 'create' | 'edit',
  source = 'direct_commit'
): Promise<void> => {
  await recordDJContribution(prisma, {
    entityId: dj.id,
    userId,
    title: dj.name,
    coverImageUrl: dj.avatarUrl ?? null,
    role: actionType === 'create' ? 'creator' : 'editor',
    actionType,
    source,
    approvedAt: new Date(),
  });
};

const parseCommaSeparatedSet = (value: string | undefined, fallback: string[]): Set<string> => {
  const raw = String(value || '').trim();
  const values = (raw ? raw.split(',') : fallback)
    .map((item) => String(item || '').trim().toLowerCase())
    .filter(Boolean);
  return new Set(values);
};

const WEB_SUPER_ADMIN_USERNAMES = parseCommaSeparatedSet(
  process.env.WEB_SUPER_ADMIN_USERNAMES,
  ['uploadtester']
);
const WEB_SUPER_ADMIN_EMAILS = parseCommaSeparatedSet(
  process.env.WEB_SUPER_ADMIN_EMAILS,
  []
);

const canUserManageEvent = async (
  userId: string,
  role: string | null | undefined,
  organizerId: string | null | undefined,
  tokenEmail: string | null | undefined
): Promise<boolean> => {
  if (role === 'admin') return true;
  const normalizedTokenEmail = String(tokenEmail || '').trim().toLowerCase();
  if (normalizedTokenEmail && WEB_SUPER_ADMIN_EMAILS.has(normalizedTokenEmail)) return true;

  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { role: true, username: true, email: true },
  });
  if (!user) return false;

  if (user.role === 'admin') return true;
  const normalizedUsername = String(user.username || '').trim().toLowerCase();
  if (normalizedUsername && WEB_SUPER_ADMIN_USERNAMES.has(normalizedUsername)) return true;

  const normalizedEmail = String(user.email || '').trim().toLowerCase();
  if (normalizedEmail && WEB_SUPER_ADMIN_EMAILS.has(normalizedEmail)) return true;

  return organizerId === userId;
};

const fetchDJWithContributorsById = async (djId: string) =>
  attachDJContributorInfo(
    await prisma.dJ.findUnique({
    where: { id: djId },
    })
  );

const uniqueDJSlugForName = async (name: string): Promise<string> => {
  const base = slugify(name) || `dj-${Date.now()}`;
  let candidate = base;
  let seq = 1;
  while (true) {
    const exists = await prisma.dJ.findUnique({ where: { slug: candidate } });
    if (!exists || normalizeDJNameKey(exists.name) === normalizeDJNameKey(name)) {
      return candidate;
    }
    seq += 1;
    candidate = `${base}-${seq}`;
  }
};

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

const buildDJAvatarObjectKey = (djId: string, mimeType: string, sourceUrl?: string | null): string => {
  const sourceExt = sourceUrl ? path.extname(sourceUrl.split('?')[0] || '').toLowerCase() : '';
  const mimeExt = mimeType.includes('png')
    ? '.png'
    : mimeType.includes('webp')
      ? '.webp'
      : mimeType.includes('gif')
        ? '.gif'
        : '.jpg';
  const ext = sourceExt && sourceExt.length <= 10 ? sourceExt : mimeExt;
  const safeDJId = sanitizeOssPathSegment(djId) || 'unknown-dj';
  return `${ossDjsPrefix}/${safeDJId}/avatar-${Date.now()}-${Math.random().toString(36).slice(2, 10)}${ext}`;
};

const buildDJAvatarVariantObjectKey = (djId: string, size: 'small' | 'medium' | 'original'): string => {
  const safeDJId = sanitizeOssPathSegment(djId) || 'unknown-dj';
  return `${ossDjsPrefix}/${safeDJId}/avatar_${size === 'small' ? '160' : size === 'medium' ? '480' : 'original'}.webp`;
};

const buildDJAvatarVariantURL = (djId: string, size: 'small' | 'medium' | 'original'): string | null => {
  if (!ossBucket || !ossRegion) return null;
  return normalizeUploadedOssUrl(undefined, buildDJAvatarVariantObjectKey(djId, size));
};

const uploadDJAvatarVariantsToOss = async (input: {
  djId: string;
  sourceObjectKey: string;
  uploadedById?: string | null;
}): Promise<{ originalUrl: string; mediumUrl: string; smallUrl: string } | null> => {
  if (!postMediaOssClient) return null;

  const source = `/${input.sourceObjectKey}`;
  const variants = [
    {
      size: 'original' as const,
      process: 'image/resize,m_lfit,w_1600,h_1600/quality,q_92/format,webp',
      mimeType: 'image/webp',
    },
    {
      size: 'medium' as const,
      process: 'image/resize,m_fill,w_480,h_480/quality,q_88/format,webp',
      mimeType: 'image/webp',
    },
    {
      size: 'small' as const,
      process: 'image/resize,m_fill,w_160,h_160/quality,q_82/format,webp',
      mimeType: 'image/webp',
    },
  ];

  const uploaded: Record<'original' | 'medium' | 'small', string> = {
    original: '',
    medium: '',
    small: '',
  };

  try {
    for (const variant of variants) {
      const objectKey = buildDJAvatarVariantObjectKey(input.djId, variant.size);
      const ossWithImageProcess = postMediaOssClient as OSS & {
        processObjectSave: (
          sourceObject: string,
          targetObject: string,
          process: string,
          bucket?: string,
          options?: Record<string, unknown>
        ) => Promise<unknown>;
      };
      await ossWithImageProcess.processObjectSave(
        source,
        objectKey,
        variant.process,
        undefined,
        {
          headers: {
            'Content-Type': variant.mimeType,
            'Cache-Control': 'public, max-age=31536000, immutable',
          },
        }
      );
      const url = normalizeUploadedOssUrl(undefined, objectKey);
      uploaded[variant.size] = url;
      await mediaAssetService.register({
        ownerType: 'dj',
        ownerId: input.djId,
        purpose: `avatar_${variant.size}`,
        provider: 'oss',
        objectKey,
        url,
        mimeType: variant.mimeType,
        uploadedById: input.uploadedById || null,
        metadata: {
          sourceObjectKey: input.sourceObjectKey,
          source: 'dj-avatar-variant',
        },
      });
    }
  } catch (error) {
    console.error('BFF web generate DJ avatar variants error:', {
      djId: input.djId,
      sourceObjectKey: input.sourceObjectKey,
      error,
    });
    return null;
  }

  return {
    originalUrl: uploaded.original,
    mediumUrl: uploaded.medium,
    smallUrl: uploaded.small,
  };
};

const buildDJMediaObjectKey = (
  djId: string,
  fileName: string,
  mimeType: string,
  usage: 'avatar' | 'banner'
): string => {
  const rawExt = path.extname(fileName || '').toLowerCase();
  const mimeExt = mimeType.includes('png')
    ? '.png'
    : mimeType.includes('webp')
      ? '.webp'
      : mimeType.includes('gif')
        ? '.gif'
        : '.jpg';
  const ext = rawExt && rawExt.length <= 10 ? rawExt : mimeExt;
  const safeDJId = sanitizeOssPathSegment(djId) || 'unknown-dj';
  const safeUsage = sanitizeOssPathSegment(usage) || 'image';
  return `${ossDjsPrefix}/${safeDJId}/${safeUsage}-${Date.now()}-${Math.random().toString(36).slice(2, 10)}${ext}`;
};

const buildDJDraftMediaObjectKey = (
  userId: string,
  draftId: string,
  fileName: string,
  mimeType: string,
  usage: 'avatar' | 'banner' | 'proof'
): string => {
  const rawExt = path.extname(fileName || '').toLowerCase();
  const mimeExt = mimeType.includes('png')
    ? '.png'
    : mimeType.includes('webp')
      ? '.webp'
      : mimeType.includes('gif')
        ? '.gif'
        : '.jpg';
  const ext = rawExt && rawExt.length <= 10 ? rawExt : mimeExt;
  const safeUserId = sanitizeOssPathSegment(userId) || 'unknown-user';
  const safeDraftId = sanitizeOssPathSegment(draftId) || 'unknown-draft';
  const safeUsage = sanitizeOssPathSegment(usage) || 'image';
  return `${ossDjsPrefix}/drafts/${safeUserId}/${safeDraftId}/${safeUsage}-${Date.now()}-${Math.random().toString(36).slice(2, 10)}${ext}`;
};

const buildDJSetMediaObjectKey = (
  ownerKey: string,
  fileName: string,
  mimeType: string,
  usage: 'thumbnail'
): string => {
  const rawExt = path.extname(fileName || '').toLowerCase();
  const mimeExt = mimeType.includes('png')
    ? '.png'
    : mimeType.includes('webp')
      ? '.webp'
      : mimeType.includes('gif')
        ? '.gif'
        : '.jpg';
  const ext = rawExt && rawExt.length <= 10 ? rawExt : mimeExt;
  const safeOwnerKey = sanitizeOssPathSegment(ownerKey) || 'unknown-set';
  return `${ossDjSetsPrefix}/${safeOwnerKey}/${usage}-${Date.now()}-${Math.random().toString(36).slice(2, 10)}${ext}`;
};

const buildWikiBrandMediaObjectKey = (
  brandId: string | null,
  fileName: string,
  mimeType: string,
  usage: string | null
): string => {
  const rawExt = path.extname(fileName || '').toLowerCase();
  const mimeExt = normalizedImageExtensionFromMimeType(mimeType);
  const ext = rawExt === mimeExt ? rawExt : mimeExt;
  const safeBrandId = sanitizeOssPathSegment(brandId || '') || 'unknown-brand';
  const safeUsage = sanitizeOssPathSegment(usage || '') || 'image';
  return `${ossWikiBrandsPrefix}/${safeBrandId}/${safeUsage}-${Date.now()}-${Math.random().toString(36).slice(2, 10)}${ext}`;
};

const buildWikiBrandDraftMediaObjectKey = (
  userId: string,
  draftId: string,
  fileName: string,
  mimeType: string,
  usage: string | null
): string => {
  const rawExt = path.extname(fileName || '').toLowerCase();
  const mimeExt = normalizedImageExtensionFromMimeType(mimeType);
  const ext = rawExt === mimeExt ? rawExt : mimeExt;
  const safeUserId = sanitizeOssPathSegment(userId) || 'unknown-user';
  const safeDraftId = sanitizeOssPathSegment(draftId) || 'unknown-draft';
  const safeUsage = sanitizeOssPathSegment(usage || '') || 'image';
  return `${ossWikiBrandsPrefix}/drafts/${safeUserId}/${safeDraftId}/${safeUsage}-${Date.now()}-${Math.random().toString(36).slice(2, 10)}${ext}`;
};

const uploadRemoteDJAvatarToOss = async (
  djId: string,
  sourceUrl: string
): Promise<{ assetId: string; url: string; objectKey: string } | null> => {
  if (!postMediaOssClient) return null;
  const trimmed = sourceUrl.trim();
  if (!trimmed) return null;

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 15_000);

  try {
    const response = await fetch(trimmed, {
      method: 'GET',
      signal: controller.signal,
      headers: {
        Accept: 'image/*',
      },
    });
    if (!response.ok) return null;

    const mimeType = (response.headers.get('content-type') || 'image/jpeg').toLowerCase();
    if (!mimeType.startsWith('image/')) return null;

    const buffer = Buffer.from(await response.arrayBuffer());
    if (buffer.length === 0) return null;

    const objectKey = buildDJAvatarObjectKey(djId, mimeType, trimmed);
    const putResult = await postMediaOssClient.put(objectKey, buffer, {
      headers: {
        'Content-Type': mimeType,
        'Cache-Control': 'public, max-age=31536000, immutable',
      },
    });

    const uploadedOriginalUrl = normalizeUploadedOssUrl(putResult.url, objectKey);
    const variants = await uploadDJAvatarVariantsToOss({
      djId,
      sourceObjectKey: objectKey,
    });
    const url = variants?.originalUrl ?? uploadedOriginalUrl;
    const asset = await mediaAssetService.register({
      ownerType: 'dj',
      ownerId: djId,
      purpose: 'avatar',
      provider: 'oss',
      objectKey,
      url: uploadedOriginalUrl,
      mimeType,
      sizeBytes: buffer.length,
      metadata: {
        sourceUrl: trimmed,
        source: 'remote-dj-avatar-mirror',
        originalVariantUrl: variants?.originalUrl ?? null,
        mediumVariantUrl: variants?.mediumUrl ?? null,
        smallVariantUrl: variants?.smallUrl ?? null,
      },
    });
    return {
      assetId: asset.id,
      url,
      objectKey,
    };
  } catch (_error) {
    return null;
  } finally {
    clearTimeout(timeout);
  }
};

const uploadRemoteImageToDJSetOss = async (
  ownerKey: string,
  sourceUrl: string
): Promise<{ assetId: string; url: string; objectKey: string }> => {
  if (!postMediaOssClient) throw new Error(ossConfigMissingMessage);
  const trimmed = sourceUrl.trim();
  if (!trimmed) throw new Error('Thumbnail URL is empty');

  try {
    const response = await axios.get<ArrayBuffer>(trimmed, {
      responseType: 'arraybuffer',
      timeout: Number(process.env.DJ_SET_THUMBNAIL_FETCH_TIMEOUT_MS || 3500),
      headers: {
        Accept: 'image/*',
      },
      maxContentLength: 10 * 1024 * 1024,
      maxBodyLength: 10 * 1024 * 1024,
      ...youtubeAxiosProxyConfig(),
    });
    if (response.status < 200 || response.status >= 300) {
      throw new Error(`Thumbnail fetch failed with HTTP ${response.status}`);
    }

    const mimeType = String(response.headers['content-type'] || 'image/jpeg').toLowerCase();
    if (!mimeType.startsWith('image/')) throw new Error(`Thumbnail response is not an image (${mimeType})`);

    const buffer = Buffer.from(response.data);
    if (buffer.length === 0) throw new Error('Thumbnail response is empty');

    const objectKey = buildDJSetMediaObjectKey(ownerKey, path.basename(trimmed.split('?')[0] || 'thumbnail.jpg'), mimeType, 'thumbnail');
    const putResult = await postMediaOssClient.put(objectKey, buffer, {
      headers: {
        'Content-Type': mimeType,
        'Cache-Control': 'public, max-age=31536000, immutable',
      },
    });

    const url = normalizeUploadedOssUrl(putResult.url, objectKey);
    const asset = await mediaAssetService.register({
      ownerType: 'dj_set',
      ownerId: ownerKey.startsWith('draft-') ? null : ownerKey,
      purpose: 'thumbnail',
      provider: 'oss',
      objectKey,
      url,
      mimeType,
      sizeBytes: buffer.length,
      uploadedById: ownerKey.startsWith('draft-') ? ownerKey.slice('draft-'.length) : null,
      metadata: {
        sourceUrl: trimmed,
        source: 'remote-dj-set-thumbnail-mirror',
      },
    });
    return {
      assetId: asset.id,
      url,
      objectKey,
    };
  } catch (error) {
    const message = axios.isAxiosError(error)
      ? `${error.code || 'ERR'} ${error.message}`
      : error instanceof Error
        ? error.message
        : String(error);
    throw new Error(`Failed to mirror DJ set thumbnail to OSS: ${message}`);
  }
};

const deleteOssObjects = async (keys: string[]): Promise<void> => {
  if (!postMediaOssClient || keys.length === 0) return;

  const chunkSize = 1000;
  for (let start = 0; start < keys.length; start += chunkSize) {
    const chunk = keys.slice(start, start + chunkSize);
    try {
      await postMediaOssClient.deleteMulti(chunk, { quiet: true });
    } catch (error) {
      console.error('BFF web delete OSS objects error:', error);
    }
  }
};

const listOssObjectKeysByPrefix = async (prefix: string): Promise<string[]> => {
  if (!postMediaOssClient) return [];
  const safePrefix = String(prefix || '').trim();
  if (!safePrefix) return [];

  const keys: string[] = [];
  let marker: string | undefined;

  do {
    let listed:
      | {
          objects?: Array<{ name?: string }>;
          nextMarker?: string;
          isTruncated?: boolean;
        }
      | undefined;

    try {
      listed = await postMediaOssClient.list(
        {
          prefix: safePrefix,
          marker,
          'max-keys': 1000,
        },
        {}
      );
    } catch (error) {
      console.error('BFF web list OSS folder by prefix error:', error);
      return keys;
    }

    const objects = Array.isArray(listed?.objects) ? listed.objects : [];
    for (const item of objects) {
      if (item?.name) {
        keys.push(item.name);
      }
    }

    if (listed?.isTruncated && listed.nextMarker) {
      marker = listed.nextMarker;
    } else {
      marker = undefined;
    }
  } while (marker);

  return keys;
};

const deleteSingleEventOssObjectIfOwned = async (url: string | null | undefined, eventId: string): Promise<void> => {
  if (!postMediaOssClient || !url) return;
  const objectKey = parseOssObjectKeyFromUrl(url);
  if (!objectKey || !isEventOssObjectKey(objectKey, eventId)) return;
  await deleteOssObjects([objectKey]);
};

const deleteSingleDJMediaOssObjectIfOwned = async (url: string | null | undefined, djId: string): Promise<void> => {
  if (!postMediaOssClient || !url) return;
  const objectKey = parseOssObjectKeyFromUrl(url);
  if (!objectKey || !isDjAvatarOssObjectKey(objectKey, djId)) return;
  const dirname = path.posix.dirname(objectKey);
  const basename = path.posix.basename(objectKey);
  const keys = [objectKey];
  if (basename === 'avatar_original.webp') {
    keys.push(`${dirname}/avatar_480.webp`, `${dirname}/avatar_160.webp`);
  }
  await deleteOssObjects(Array.from(new Set(keys)));
};

const deleteSingleWikiBrandOssObjectIfOwned = async (
  url: string | null | undefined,
  brandId: string
): Promise<void> => {
  if (!postMediaOssClient || !url) return;
  const objectKey = parseOssObjectKeyFromUrl(url);
  if (!objectKey || !isWikiBrandOssObjectKey(objectKey, brandId)) return;
  await deleteOssObjects([objectKey]);
};

const deleteSingleRatingOssObjectIfOwned = async (url: string | null | undefined): Promise<void> => {
  if (!postMediaOssClient || !url) return;
  const objectKey = parseOssObjectKeyFromUrl(url);
  if (!objectKey || !isRatingOssObjectKey(objectKey)) return;
  await deleteOssObjects([objectKey]);
};

const isFeedNewsOssObjectKey = (objectKey: string): boolean =>
  objectKey.startsWith(`${ossPostsPrefix}/news/`);

const listFeedDraftOssKeys = async (newsKey: string): Promise<string[]> => {
  const safeNewsKey = sanitizeOssPathSegment(newsKey);
  if (!safeNewsKey) return [];
  const prefix = `${ossPostsPrefix}/news/draft-${safeNewsKey}/`;
  return listOssObjectKeysByPrefix(prefix);
};

const deleteEventOssFolder = async (eventId: string): Promise<void> => {
  if (!postMediaOssClient) return;
  const safeEventId = sanitizeOssPathSegment(eventId);
  if (!safeEventId) return;
  const prefix = `${ossEventsPrefix}/${safeEventId}/`;

  let marker: string | undefined;
  const keys: string[] = [];

  do {
    let listed:
      | {
          objects?: Array<{ name?: string }>;
          nextMarker?: string;
          isTruncated?: boolean;
        }
      | undefined;

    try {
      listed = await postMediaOssClient.list(
        {
          prefix,
          marker,
          'max-keys': 1000,
        },
        {}
      );
    } catch (error) {
      console.error('BFF web list OSS folder error:', error);
      return;
    }

    const objects = Array.isArray(listed?.objects) ? listed.objects : [];
    for (const item of objects) {
      if (item?.name) {
        keys.push(item.name);
      }
    }

    if (listed?.isTruncated && listed.nextMarker) {
      marker = listed.nextMarker;
    } else {
      marker = undefined;
    }
  } while (marker);

  await deleteOssObjects(keys);
};

const deleteDJOssFolder = async (djId: string): Promise<void> => {
  if (!postMediaOssClient) return;
  const safeDJId = sanitizeOssPathSegment(djId);
  if (!safeDJId) return;
  const prefix = `${ossDjsPrefix}/${safeDJId}/`;

  let marker: string | undefined;
  const keys: string[] = [];

  do {
    let listed:
      | {
          objects?: Array<{ name?: string }>;
          nextMarker?: string;
          isTruncated?: boolean;
        }
      | undefined;

    try {
      listed = await postMediaOssClient.list(
        {
          prefix,
          marker,
          'max-keys': 1000,
        },
        {}
      );
    } catch (error) {
      console.error('BFF web list DJ OSS folder error:', error);
      return;
    }

    const objects = Array.isArray(listed?.objects) ? listed.objects : [];
    for (const item of objects) {
      if (item?.name) {
        keys.push(item.name);
      }
    }

    if (listed?.isTruncated && listed.nextMarker) {
      marker = listed.nextMarker;
    } else {
      marker = undefined;
    }
  } while (marker);

  await deleteOssObjects(keys);
};

const deleteWikiBrandOssFolder = async (brandId: string): Promise<void> => {
  if (!postMediaOssClient) return;
  const safeBrandId = sanitizeOssPathSegment(brandId);
  if (!safeBrandId) return;
  const prefix = `${ossWikiBrandsPrefix}/${safeBrandId}/`;

  let marker: string | undefined;
  const keys: string[] = [];

  do {
    let listed:
      | {
          objects?: Array<{ name?: string }>;
          nextMarker?: string;
          isTruncated?: boolean;
        }
      | undefined;

    try {
      listed = await postMediaOssClient.list(
        {
          prefix,
          marker,
          'max-keys': 1000,
        },
        {}
      );
    } catch (error) {
      console.error('BFF web list wiki brand OSS folder error:', error);
      return;
    }

    const objects = Array.isArray(listed?.objects) ? listed.objects : [];
    for (const item of objects) {
      if (item?.name) {
        keys.push(item.name);
      }
    }

    if (listed?.isTruncated && listed.nextMarker) {
      marker = listed.nextMarker;
    } else {
      marker = undefined;
    }
  } while (marker);

  await deleteOssObjects(keys);
};

const uploadPostMediaToOss = async (
  file: Express.Multer.File,
  kind: 'image' | 'video',
  scopeKey?: string | null,
  uploadedById?: string | null
): Promise<{ assetId: string; url: string; fileName: string; mimeType: string; size: number }> => {
  if (!postMediaOssClient) {
    throw new Error('OSS is not configured. Require OSS_REGION/OSS_ACCESS_KEY_ID/OSS_ACCESS_KEY_SECRET/OSS_BUCKET');
  }

  const originalExt = path.extname(file.originalname || '').toLowerCase();
  const fallbackExt = kind === 'image' ? '.jpg' : '.mp4';
  const safeExt = originalExt && originalExt.length <= 10 ? originalExt : fallbackExt;
  const safeScopeKey = scopeKey ? sanitizeOssPathSegment(scopeKey) : '';
  const postMediaDir = safeScopeKey ? `${ossPostsPrefix}/news/${safeScopeKey}` : ossPostsPrefix;
  const objectKey = `${postMediaDir}/${kind}-${Date.now()}-${Math.random().toString(36).slice(2, 10)}${safeExt}`;
  const mimeType = file.mimetype || (kind === 'image' ? 'image/jpeg' : 'video/mp4');

  let putResult: { url?: string };
  try {
    putResult = await postMediaOssClient.put(objectKey, file.path, {
      headers: {
        'Content-Type': mimeType,
        'Cache-Control': 'public, max-age=31536000, immutable',
      },
    });
  } finally {
    await fs.promises.unlink(file.path).catch(() => undefined);
  }

  const url = normalizeUploadedOssUrl(putResult.url, objectKey);
  const asset = await mediaAssetService.register({
    ownerType: 'post',
    ownerId: scopeKey || null,
    purpose: kind,
    provider: 'oss',
    objectKey,
    url,
    mimeType,
    sizeBytes: file.size,
    uploadedById: uploadedById || null,
    metadata: {
      originalName: file.originalname,
      source: kind === 'image' ? 'v1/feed/upload-image' : 'v1/feed/upload-video',
    },
  });

  return {
    assetId: asset.id,
    url,
    fileName: path.basename(objectKey),
    mimeType,
    size: file.size,
  };
};

const uploadEventMediaToOss = async (
  file: Express.Multer.File,
  eventId: string,
  usage: string | null,
  uploadedById?: string | null,
  diagnostics?: {
    requestId?: string;
  }
): Promise<{ assetId: string; url: string; fileName: string; mimeType: string; size: number }> => {
  if (!postMediaOssClient) {
    await fs.promises.unlink(file.path).catch(() => undefined);
    throw new Error(ossConfigMissingMessage);
  }

  const mimeType = file.mimetype || 'image/jpeg';
  const objectKey = buildEventMediaObjectKey(eventId, file.originalname || file.filename || 'image.jpg', mimeType, usage);
  const ossPutStartedAt = process.hrtime.bigint();

  let putResult: { url?: string };
  try {
    putResult = await postMediaOssClient.put(objectKey, file.path, {
      headers: {
        'Content-Type': mimeType,
        'Cache-Control': 'public, max-age=31536000, immutable',
      },
    });
  } finally {
    await fs.promises.unlink(file.path).catch(() => undefined);
  }
  const ossPutDurationMs = elapsedMsFrom(ossPutStartedAt);

  const url = normalizeUploadedOssUrl(putResult.url, objectKey);
  const assetRegisterStartedAt = process.hrtime.bigint();
  const asset = await mediaAssetService.register({
    ownerType: 'event',
    ownerId: eventId,
    purpose: usage || 'image',
    provider: 'oss',
    objectKey,
    url,
    mimeType,
    sizeBytes: file.size,
    uploadedById: uploadedById || null,
    metadata: {
      originalName: file.originalname,
      source: 'v1/events/upload-image',
    },
  });
  const assetRegisterDurationMs = elapsedMsFrom(assetRegisterStartedAt);

  console.info('[event-upload] oss.event.success', {
    requestId: diagnostics?.requestId ?? null,
    eventId,
    usage: usage || 'image',
    sizeBytes: file.size,
    mimeType,
    ossPutDurationMs: Number(ossPutDurationMs.toFixed(1)),
    assetRegisterDurationMs: Number(assetRegisterDurationMs.toFixed(1)),
    objectKey,
  });

  return {
    assetId: asset.id,
    url,
    fileName: path.basename(objectKey),
    mimeType,
    size: file.size,
  };
};

const uploadEventDraftMediaToOss = async (
  file: Express.Multer.File,
  userId: string,
  draftId: string,
  usage: string | null,
  diagnostics?: {
    requestId?: string;
  }
): Promise<{ assetId: string; url: string; fileName: string; mimeType: string; size: number }> => {
  if (!postMediaOssClient) {
    await fs.promises.unlink(file.path).catch(() => undefined);
    throw new Error(ossConfigMissingMessage);
  }

  const mimeType = file.mimetype || 'image/jpeg';
  const objectKey = buildEventDraftMediaObjectKey(
    userId,
    draftId,
    file.originalname || file.filename || 'image.jpg',
    mimeType,
    usage
  );
  const ossPutStartedAt = process.hrtime.bigint();

  let putResult: { url?: string };
  try {
    putResult = await postMediaOssClient.put(objectKey, file.path, {
      headers: {
        'Content-Type': mimeType,
        'Cache-Control': 'public, max-age=31536000, immutable',
      },
    });
  } finally {
    await fs.promises.unlink(file.path).catch(() => undefined);
  }
  const ossPutDurationMs = elapsedMsFrom(ossPutStartedAt);

  const url = normalizeUploadedOssUrl(putResult.url, objectKey);
  const assetRegisterStartedAt = process.hrtime.bigint();
  const asset = await mediaAssetService.register({
    ownerType: 'event-draft',
    ownerId: draftId,
    purpose: usage || 'image',
    provider: 'oss',
    objectKey,
    url,
    mimeType,
    sizeBytes: file.size,
    uploadedById: userId,
    metadata: {
      originalName: file.originalname,
      source: 'v1/events/upload-image:draft',
    },
  });
  const assetRegisterDurationMs = elapsedMsFrom(assetRegisterStartedAt);

  console.info('[event-upload] oss.draft.success', {
    requestId: diagnostics?.requestId ?? null,
    userId,
    draftId,
    usage: usage || 'image',
    sizeBytes: file.size,
    mimeType,
    ossPutDurationMs: Number(ossPutDurationMs.toFixed(1)),
    assetRegisterDurationMs: Number(assetRegisterDurationMs.toFixed(1)),
    objectKey,
  });

  return {
    assetId: asset.id,
    url,
    fileName: path.basename(objectKey),
    mimeType,
    size: file.size,
  };
};

const saveUploadedFileToLocalMediaAsset = async (
  file: Express.Multer.File,
  input: {
    ownerType: string;
    ownerId?: string | null;
    purpose: string;
    uploadedById?: string | null;
    localDir: string;
    publicSubdir: string;
    source: string;
  }
): Promise<{ assetId: string; url: string; fileName: string; mimeType: string; size: number }> => {
  const mimeType = file.mimetype || 'application/octet-stream';

  try {
    const buffer = await fs.promises.readFile(file.path);
    const localUpload = await saveBufferToLocalUploads({
      buffer,
      localDir: input.localDir,
      publicSubdir: input.publicSubdir,
      originalName: file.originalname || file.filename || 'upload.bin',
      mimeType,
    });

    const asset = await mediaAssetService.register({
      ownerType: input.ownerType,
      ownerId: input.ownerId || null,
      purpose: input.purpose,
      provider: 'local',
      objectKey: null,
      url: localUpload.url,
      mimeType,
      sizeBytes: file.size,
      uploadedById: input.uploadedById || null,
      metadata: {
        originalName: file.originalname,
        source: input.source,
      },
    });

    return {
      assetId: asset.id,
      url: localUpload.url,
      fileName: localUpload.fileName,
      mimeType,
      size: file.size,
    };
  } finally {
    await fs.promises.unlink(file.path).catch(() => undefined);
  }
};

const uploadRatingMediaToOss = async (
  file: Express.Multer.File,
  owner: {
    userId: string;
    ratingEventId?: string | null;
    ratingUnitId?: string | null;
  },
  usage: string | null
): Promise<{ assetId: string; url: string; fileName: string; mimeType: string; size: number }> => {
  if (!postMediaOssClient) {
    await fs.promises.unlink(file.path).catch(() => undefined);
    throw new Error('OSS is not configured. Require OSS_REGION/OSS_ACCESS_KEY_ID/OSS_ACCESS_KEY_SECRET/OSS_BUCKET');
  }

  const mimeType = file.mimetype || 'image/jpeg';
  const objectKey = buildRatingMediaObjectKey(owner, file.originalname || file.filename || 'image.jpg', mimeType, usage);

  let putResult: { url?: string };
  try {
    putResult = await postMediaOssClient.put(objectKey, file.path, {
      headers: {
        'Content-Type': mimeType,
        'Cache-Control': 'public, max-age=31536000, immutable',
      },
    });
  } finally {
    await fs.promises.unlink(file.path).catch(() => undefined);
  }

  const url = normalizeUploadedOssUrl(putResult.url, objectKey);
  const asset = await mediaAssetService.register({
    ownerType: owner.ratingUnitId ? 'rating_unit' : owner.ratingEventId ? 'rating_event' : 'rating_draft',
    ownerId: owner.ratingUnitId || owner.ratingEventId || owner.userId,
    purpose: usage || 'image',
    provider: 'oss',
    objectKey,
    url,
    mimeType,
    sizeBytes: file.size,
    uploadedById: owner.userId,
    metadata: {
      originalName: file.originalname,
      source: 'v1/rating/upload-image',
    },
  });

  return {
    assetId: asset.id,
    url,
    fileName: path.basename(objectKey),
    mimeType,
    size: file.size,
  };
};

const uploadRemoteImageToRatingOss = async (
  owner: {
    userId: string;
    ratingEventId?: string | null;
    ratingUnitId?: string | null;
  },
  sourceUrl: string,
  usage: string | null
): Promise<{ assetId: string; url: string; objectKey: string } | null> => {
  if (!postMediaOssClient) return null;
  const trimmed = sourceUrl.trim();
  if (!trimmed) return null;

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 15_000);

  try {
    const response = await fetch(trimmed, {
      method: 'GET',
      signal: controller.signal,
      headers: {
        Accept: 'image/*',
      },
    });
    if (!response.ok) return null;

    const mimeType = (response.headers.get('content-type') || 'image/jpeg').toLowerCase();
    if (!mimeType.startsWith('image/')) return null;

    const buffer = Buffer.from(await response.arrayBuffer());
    if (buffer.length === 0) return null;

    const objectKey = buildRatingMediaObjectKey(owner, path.basename(trimmed.split('?')[0] || 'image.jpg'), mimeType, usage);
    const putResult = await postMediaOssClient.put(objectKey, buffer, {
      headers: {
        'Content-Type': mimeType,
        'Cache-Control': 'public, max-age=31536000, immutable',
      },
    });

    const url = normalizeUploadedOssUrl(putResult.url, objectKey);
    const asset = await mediaAssetService.register({
      ownerType: owner.ratingUnitId ? 'rating_unit' : owner.ratingEventId ? 'rating_event' : 'rating_draft',
      ownerId: owner.ratingUnitId || owner.ratingEventId || owner.userId,
      purpose: usage || 'image',
      provider: 'oss',
      objectKey,
      url,
      mimeType,
      sizeBytes: buffer.length,
      uploadedById: owner.userId,
      metadata: {
        sourceUrl: trimmed,
        source: 'remote-rating-image-mirror',
      },
    });
    return {
      assetId: asset.id,
      url,
      objectKey,
    };
  } catch (_error) {
    return null;
  } finally {
    clearTimeout(timeout);
  }
};

const uploadDJMediaToOss = async (
  file: Express.Multer.File,
  djId: string,
  usage: 'avatar' | 'banner',
  uploadedById?: string | null
): Promise<{
  assetId: string;
  url: string;
  originalUrl: string | null;
  mediumUrl: string | null;
  smallUrl: string | null;
  fileName: string;
  mimeType: string;
  size: number;
}> => {
  if (!postMediaOssClient) {
    await fs.promises.unlink(file.path).catch(() => undefined);
    throw new Error('OSS is not configured. Require OSS_REGION/OSS_ACCESS_KEY_ID/OSS_ACCESS_KEY_SECRET/OSS_BUCKET');
  }

  const mimeType = file.mimetype || 'image/jpeg';
  const objectKey = buildDJMediaObjectKey(djId, file.originalname || file.filename || 'image.jpg', mimeType, usage);

  let putResult: { url?: string };
  try {
    putResult = await postMediaOssClient.put(objectKey, file.path, {
      headers: {
        'Content-Type': mimeType,
        'Cache-Control': 'public, max-age=31536000, immutable',
      },
    });
  } finally {
    await fs.promises.unlink(file.path).catch(() => undefined);
  }

  const uploadedOriginalUrl = normalizeUploadedOssUrl(putResult.url, objectKey);
  const variants = usage === 'avatar'
    ? await uploadDJAvatarVariantsToOss({
        djId,
        sourceObjectKey: objectKey,
        uploadedById,
      })
    : null;
  const url = variants?.originalUrl ?? uploadedOriginalUrl;
  const asset = await mediaAssetService.register({
    ownerType: 'dj',
    ownerId: djId,
    purpose: usage,
    provider: 'oss',
    objectKey,
    url: uploadedOriginalUrl,
    mimeType,
    sizeBytes: file.size,
    uploadedById: uploadedById || null,
    metadata: {
      originalName: file.originalname,
      source: 'v1/djs/upload-image',
      originalVariantUrl: variants?.originalUrl ?? null,
      mediumVariantUrl: variants?.mediumUrl ?? null,
      smallVariantUrl: variants?.smallUrl ?? null,
    },
  });

  return {
    assetId: asset.id,
    url,
    originalUrl: variants?.originalUrl ?? null,
    mediumUrl: variants?.mediumUrl ?? null,
    smallUrl: variants?.smallUrl ?? null,
    fileName: path.basename(objectKey),
    mimeType,
    size: file.size,
  };
};

const uploadDJDraftMediaToOss = async (
  file: Express.Multer.File,
  userId: string,
  draftId: string,
  usage: 'avatar' | 'banner' | 'proof'
): Promise<{
  assetId: string;
  url: string;
  originalUrl: string | null;
  mediumUrl: string | null;
  smallUrl: string | null;
  fileName: string;
  mimeType: string;
  size: number;
}> => {
  if (!postMediaOssClient) {
    await fs.promises.unlink(file.path).catch(() => undefined);
    throw new Error('OSS is not configured. Require OSS_REGION/OSS_ACCESS_KEY_ID/OSS_ACCESS_KEY_SECRET/OSS_BUCKET');
  }

  const mimeType = file.mimetype || 'image/jpeg';
  const objectKey = buildDJDraftMediaObjectKey(userId, draftId, file.originalname || file.filename || 'image.jpg', mimeType, usage);

  let putResult: { url?: string };
  try {
    putResult = await postMediaOssClient.put(objectKey, file.path, {
      headers: {
        'Content-Type': mimeType,
        'Cache-Control': 'public, max-age=31536000, immutable',
      },
    });
  } finally {
    await fs.promises.unlink(file.path).catch(() => undefined);
  }

  const url = normalizeUploadedOssUrl(putResult.url, objectKey);
  const asset = await mediaAssetService.register({
    ownerType: 'dj-draft',
    ownerId: draftId,
    purpose: usage,
    provider: 'oss',
    objectKey,
    url,
    mimeType,
    sizeBytes: file.size,
    uploadedById: userId,
    metadata: {
      originalName: file.originalname,
      source: 'v1/djs/upload-image:draft',
    },
  });

  return {
    assetId: asset.id,
    url,
    originalUrl: null,
    mediumUrl: null,
    smallUrl: null,
    fileName: path.basename(objectKey),
    mimeType,
    size: file.size,
  };
};

const uploadDJSetImageToOss = async (
  file: Express.Multer.File,
  ownerKey: string,
  uploadedById: string | null
): Promise<{ assetId: string; url: string; fileName: string; mimeType: string; size: number }> => {
  if (!postMediaOssClient) {
    await fs.promises.unlink(file.path).catch(() => undefined);
    throw new Error('OSS is not configured. Require OSS_REGION/OSS_ACCESS_KEY_ID/OSS_ACCESS_KEY_SECRET/OSS_BUCKET');
  }

  const mimeType = file.mimetype || 'image/jpeg';
  const objectKey = buildDJSetMediaObjectKey(ownerKey, file.originalname || file.filename || 'thumbnail.jpg', mimeType, 'thumbnail');

  let putResult: { url?: string };
  try {
    putResult = await postMediaOssClient.put(objectKey, file.path, {
      headers: {
        'Content-Type': mimeType,
        'Cache-Control': 'public, max-age=31536000, immutable',
      },
    });
  } finally {
    await fs.promises.unlink(file.path).catch(() => undefined);
  }

  const url = normalizeUploadedOssUrl(putResult.url, objectKey);
  const asset = await mediaAssetService.register({
    ownerType: 'dj_set',
    ownerId: ownerKey.startsWith('draft-') ? null : ownerKey,
    purpose: 'thumbnail',
    provider: 'oss',
    objectKey,
    url,
    mimeType,
    sizeBytes: file.size,
    uploadedById,
    metadata: {
      originalName: file.originalname,
      source: 'v1/dj-sets/upload-thumbnail',
    },
  });

  return {
    assetId: asset.id,
    url,
    fileName: path.basename(objectKey),
    mimeType,
    size: file.size,
  };
};

const uploadWikiBrandMediaToOss = async (
  file: Express.Multer.File,
  brandId: string | null,
  usage: string | null,
  uploadedById?: string | null,
  sort?: number | null
): Promise<{
  assetId: string;
  url: string;
  originalUrl: string;
  fileName: string;
  mimeType: string;
  size: number;
  width: number | null;
  height: number | null;
  sort: number | null;
  ownerType: string;
  ownerId: string | null;
}> => {
  if (!postMediaOssClient) {
    await fs.promises.unlink(file.path).catch(() => undefined);
    throw new Error('OSS is not configured. Require OSS_REGION/OSS_ACCESS_KEY_ID/OSS_ACCESS_KEY_SECRET/OSS_BUCKET');
  }

  try {
    const fileBuffer = await fs.promises.readFile(file.path);
    const normalizedUpload = normalizeWikiBrandUploadImage(fileBuffer, file.mimetype, usage);
    const mimeType = normalizedUpload.mimeType;
    const normalizedBuffer = normalizedUpload.buffer;
    const dimensions = inferImageDimensionsFromBuffer(normalizedBuffer, mimeType);
    validateWikiBrandImageDimensions(usage, dimensions);
    const normalizedSort = typeof sort === 'number' && Number.isFinite(sort) ? sort : null;
    const contentHash = computeBufferSha256(normalizedBuffer);
    const existingAsset = await findReusableWikiBrandMediaAsset(
      'wiki_brand',
      brandId || 'unknown-brand',
      usage || 'image',
      contentHash
    );
    if (existingAsset) {
      return buildWikiBrandUploadResponseFromAsset(existingAsset, normalizedSort);
    }
    const objectKey = buildWikiBrandMediaObjectKey(brandId, file.originalname || file.filename || 'image.jpg', mimeType, usage);

    const putResult = await postMediaOssClient.put(objectKey, normalizedBuffer, {
      headers: {
        'Content-Type': mimeType,
        'Cache-Control': 'public, max-age=31536000, immutable',
      },
    });
    const url = normalizeUploadedOssUrl(putResult.url, objectKey);
    const asset = await mediaAssetService.register({
      ownerType: 'wiki_brand',
      ownerId: brandId,
      purpose: usage || 'image',
      provider: 'oss',
      objectKey,
      url,
      mimeType,
      sizeBytes: file.size,
      width: dimensions.width,
      height: dimensions.height,
      uploadedById: uploadedById || null,
      metadata: {
        originalName: file.originalname,
        originalUrl: url,
        contentHash,
        sort: normalizedSort,
        visibility: normalizeWikiBrandImageVisibility(usage),
        source: 'v1/wiki/brands/upload-image',
      },
    });

    return buildWikiBrandUploadResponseFromAsset(asset, normalizedSort);
  } finally {
    await fs.promises.unlink(file.path).catch(() => undefined);
  }
};

const uploadWikiBrandDraftMediaToOss = async (
  file: Express.Multer.File,
  userId: string,
  draftId: string,
  usage: string | null,
  sort?: number | null
): Promise<{
  assetId: string;
  url: string;
  originalUrl: string;
  fileName: string;
  mimeType: string;
  size: number;
  width: number | null;
  height: number | null;
  sort: number | null;
  ownerType: string;
  ownerId: string | null;
}> => {
  if (!postMediaOssClient) {
    await fs.promises.unlink(file.path).catch(() => undefined);
    throw new Error('OSS is not configured. Require OSS_REGION/OSS_ACCESS_KEY_ID/OSS_ACCESS_KEY_SECRET/OSS_BUCKET');
  }

  try {
    const fileBuffer = await fs.promises.readFile(file.path);
    const normalizedUpload = normalizeWikiBrandUploadImage(fileBuffer, file.mimetype, usage);
    const mimeType = normalizedUpload.mimeType;
    const normalizedBuffer = normalizedUpload.buffer;
    const dimensions = inferImageDimensionsFromBuffer(normalizedBuffer, mimeType);
    validateWikiBrandImageDimensions(usage, dimensions);
    const normalizedSort = typeof sort === 'number' && Number.isFinite(sort) ? sort : null;
    const contentHash = computeBufferSha256(normalizedBuffer);
    const existingAsset = await findReusableWikiBrandMediaAsset(
      'wiki_brand_draft',
      draftId,
      usage || 'image',
      contentHash
    );
    if (existingAsset) {
      return buildWikiBrandUploadResponseFromAsset(existingAsset, normalizedSort);
    }
    const objectKey = buildWikiBrandDraftMediaObjectKey(
      userId,
      draftId,
      file.originalname || file.filename || 'image.jpg',
      mimeType,
      usage
    );

    const putResult = await postMediaOssClient.put(objectKey, normalizedBuffer, {
      headers: {
        'Content-Type': mimeType,
        'Cache-Control': 'public, max-age=31536000, immutable',
      },
    });
    const url = normalizeUploadedOssUrl(putResult.url, objectKey);
    const asset = await mediaAssetService.register({
      ownerType: 'wiki_brand_draft',
      ownerId: draftId,
      purpose: usage || 'image',
      provider: 'oss',
      objectKey,
      url,
      mimeType,
      sizeBytes: file.size,
      width: dimensions.width,
      height: dimensions.height,
      uploadedById: userId,
      metadata: {
        originalName: file.originalname,
        originalUrl: url,
        contentHash,
        sort: normalizedSort,
        visibility: normalizeWikiBrandImageVisibility(usage),
        source: 'v1/wiki/brands/upload-image:draft',
      },
    });

    return buildWikiBrandUploadResponseFromAsset(asset, normalizedSort);
  } finally {
    await fs.promises.unlink(file.path).catch(() => undefined);
  }
};

const uploadLineupImportImageToOss = async (
  file: Express.Multer.File
): Promise<{ url: string; objectKey: string; mimeType: string }> => {
  if (!postMediaOssClient) {
    await fs.promises.unlink(file.path).catch(() => undefined);
    throw new Error('OSS is not configured. Require OSS_REGION/OSS_ACCESS_KEY_ID/OSS_ACCESS_KEY_SECRET/OSS_BUCKET');
  }

  const mimeType = file.mimetype || 'image/jpeg';
  const objectKey = buildCozeImportObjectKey('lineup', file.originalname || file.filename || 'lineup.jpg', mimeType);

  let putResult: { url?: string };
  try {
    putResult = await postMediaOssClient.put(objectKey, file.path, {
      headers: {
        'Content-Type': mimeType,
        'Cache-Control': 'public, max-age=3600',
      },
    });
  } finally {
    await fs.promises.unlink(file.path).catch(() => undefined);
  }

  return {
    url: normalizeUploadedOssUrl(putResult.url, objectKey),
    objectKey,
    mimeType,
  };
};

type ImportedLineupItem = {
  id: string;
  musician: string;
  time: string | null;
  stage: string | null;
  date: string | null;
};

type TimetableRecognitionContext = {
  eventTimeZone?: string;
  schedule?: {
    mode?: string;
    timeZone?: string;
    dayRolloverHour?: number;
  };
  weeks?: Array<{
    weekIndex?: number;
    label?: string;
    startDate?: string;
    endDate?: string;
    sortOrder?: number;
  }>;
  eventDays?: Array<{
    eventDayId?: string;
    weekIndex?: number;
    dayIndexInWeek?: number;
    overallDayIndex?: number;
    label?: string;
    weekday?: string;
    date?: string;
    sortOrder?: number;
  }>;
  dayRolloverHour?: number;
  knownStageNames?: string[];
};

type TimetableImportJobStatus = 'pending' | 'running' | 'succeeded' | 'failed' | 'cancelled';

type BaseImportJob = {
  id: string;
  userId: string;
  status: TimetableImportJobStatus;
  createdAt: string;
  updatedAt: string;
  startedAt: string | null;
  finishedAt: string | null;
  error: string | null;
  abortController?: AbortController | null;
};

type TimetableImportJob = BaseImportJob & {
  result: { rawJson: unknown; rawResponse: unknown } | null;
};

const timetableImportJobs = new Map<string, TimetableImportJob>();
const timetableImportJobRetentionMs = 30 * 60 * 1000;

type LineupRecognitionContext = {
  preferred_language?: string;
  known_dj_names?: string[];
};

type LineupImportJob = BaseImportJob & {
  result: { rawJson: unknown; rawResponse: unknown } | null;
};

const lineupImportJobs = new Map<string, LineupImportJob>();

type PosterImportJob = BaseImportJob & {
  result: { rawJson: unknown; rawResponse: unknown } | null;
};

const posterImportJobs = new Map<string, PosterImportJob>();

const logImportJobLifecycle = (
  kind: 'timetable' | 'lineup' | 'poster',
  phase: 'created' | 'running' | 'succeeded' | 'failed' | 'cancelled' | 'polled' | 'missing',
  payload: Record<string, unknown>
): void => {
  console.info(`[${kind}-import-job] ${phase}`, {
    pid: process.pid,
    ...payload,
  });
};

const cancelImportJob = (
  kind: 'timetable' | 'lineup' | 'poster',
  job: BaseImportJob,
  userId: string
): boolean => {
  if (job.status === 'succeeded' || job.status === 'failed' || job.status === 'cancelled') {
    return false;
  }
  const cancelledAt = new Date().toISOString();
  job.status = 'cancelled';
  job.updatedAt = cancelledAt;
  job.finishedAt = cancelledAt;
  job.error = '任务已取消';
  const controller = job.abortController;
  job.abortController = null;
  controller?.abort();
  logImportJobLifecycle(kind, 'cancelled', {
    jobId: job.id,
    userId,
    status: job.status,
  });
  return true;
};

const pruneTimetableImportJobs = (): void => {
  const now = Date.now();
  for (const [id, job] of timetableImportJobs.entries()) {
    if (now - Date.parse(job.createdAt) > timetableImportJobRetentionMs) {
      timetableImportJobs.delete(id);
    }
  }
  for (const [id, job] of lineupImportJobs.entries()) {
    if (now - Date.parse(job.createdAt) > timetableImportJobRetentionMs) {
      lineupImportJobs.delete(id);
    }
  }
  for (const [id, job] of posterImportJobs.entries()) {
    if (now - Date.parse(job.createdAt) > timetableImportJobRetentionMs) {
      posterImportJobs.delete(id);
    }
  }
};

type SpotifyDJSearchItem = {
  spotifyId: string;
  name: string;
  uri: string;
  url: string | null;
  popularity: number;
  followers: number;
  genres: string[];
  imageUrl: string | null;
  existingDJId: string | null;
  existingDJName: string | null;
  existingMatchType: 'spotify_id' | 'name_case_insensitive' | null;
};

type DiscogsDJSearchItem = {
  artistId: number;
  name: string;
  thumbUrl: string | null;
  coverImageUrl: string | null;
  resourceUrl: string | null;
  uri: string | null;
  existingDJId: string | null;
  existingDJName: string | null;
  existingMatchType: 'name_case_insensitive' | null;
};

type SoundCloudDJSearchItem = {
  soundcloudid: string;
  soundcloudId: string;
  soundCloudId: string;
  name: string;
  username: string;
  avatarUrl: string | null;
  permalink: string | null;
  permalinkUrl: string | null;
  city: string | null;
  country: string | null;
  description: string | null;
  website: string | null;
  spotifyUrl: string | null;
  instagramUrl: string | null;
  facebookUrl: string | null;
  twitterUrl: string | null;
  youtubeUrl: string | null;
  track_count: number;
  playlist_count: number;
  followers_count: number;
  public_favorites_count: number;
  trackCount: number;
  playlistCount: number;
  followersCount: number;
  publicFavoritesCount: number;
  soundCloudFollowers: number;
  soundCloudFavorites: number;
  existingDJId: string | null;
  existingDJName: string | null;
  existingMatchType: 'name_case_insensitive' | null;
};

type DiscogsDJArtistDetailItem = {
  artistId: number;
  name: string;
  realName: string | null;
  profile: string | null;
  urls: string[];
  nameVariations: string[];
  aliases: string[];
  groups: string[];
  primaryImageUrl: string | null;
  thumbnailImageUrl: string | null;
  resourceUrl: string | null;
  uri: string | null;
  existingDJId: string | null;
  existingDJName: string | null;
  existingMatchType: 'name_case_insensitive' | null;
};

const isUnknownText = (value: string): boolean => {
  const normalized = value.trim().toLowerCase();
  if (!normalized) return true;
  return (
    normalized === 'unknown' ||
    normalized === 'unk' ||
    normalized === 'n/a' ||
    normalized === 'na' ||
    normalized === 'none' ||
    normalized === 'null' ||
    normalized === '-' ||
    normalized === '--' ||
    normalized === '未知'
  );
};

const sanitizeOptionalText = (value: unknown): string | null => {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  if (!trimmed || isUnknownText(trimmed)) return null;
  return trimmed;
};

const pickFirstUrlByHosts = (
  urls: string[] | null | undefined,
  hostKeywords: string[]
): string | null => {
  if (!Array.isArray(urls) || urls.length === 0) return null;
  for (const raw of urls) {
    const trimmed = raw?.trim();
    if (!trimmed) continue;
    try {
      const parsed = new URL(trimmed);
      const host = parsed.hostname.toLowerCase();
      if (hostKeywords.some((keyword) => host.includes(keyword.toLowerCase()))) {
        return trimmed;
      }
    } catch (_error) {
      continue;
    }
  }
  return null;
};

const safeParseJson = (text: string): unknown | null => {
  try {
    return JSON.parse(text);
  } catch (_error) {
    return null;
  }
};

const extractFirstJSONObjectText = (input: string): string | null => {
  let depth = 0;
  let start = -1;
  let inString = false;
  let escaped = false;

  for (let i = 0; i < input.length; i += 1) {
    const ch = input[i];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (ch === '\\') {
        escaped = true;
      } else if (ch === '"') {
        inString = false;
      }
      continue;
    }
    if (ch === '"') {
      inString = true;
      continue;
    }
    if (ch === '{') {
      if (depth === 0) start = i;
      depth += 1;
      continue;
    }
    if (ch === '}') {
      if (depth > 0) depth -= 1;
      if (depth === 0 && start >= 0) {
        return input.slice(start, i + 1);
      }
    }
  }
  return null;
};

const tryParseJsonFromText = (rawText: string): unknown | null => {
  const direct = safeParseJson(rawText);
  if (direct !== null) return direct;
  const extracted = extractFirstJSONObjectText(rawText);
  if (!extracted) return null;
  return safeParseJson(extracted);
};

const extractLineupInfo = (value: unknown): Array<Record<string, unknown>> => {
  const seen = new WeakSet<object>();

  const walk = (node: unknown): Array<Record<string, unknown>> | null => {
    if (Array.isArray(node)) {
      for (const item of node) {
        const nested = walk(item);
        if (nested && nested.length > 0) return nested;
      }
      return null;
    }

    if (typeof node === 'string') {
      const parsed = tryParseJsonFromText(node);
      if (parsed !== null) return walk(parsed);
      return null;
    }

    if (!node || typeof node !== 'object') return null;
    if (seen.has(node)) return null;
    seen.add(node);

    const record = node as Record<string, unknown>;
    if (Array.isArray(record.lineup_info)) {
      return record.lineup_info.filter((item): item is Record<string, unknown> => typeof item === 'object' && item !== null);
    }

    for (const value of Object.values(record)) {
      const nested = walk(value);
      if (nested && nested.length > 0) return nested;
    }
    return null;
  };

  return walk(value) ?? [];
};

const extractFormattedOutputText = (value: unknown): string | null => {
  const seen = new WeakSet<object>();

  const walk = (node: unknown): string | null => {
    if (typeof node === 'string') {
      const trimmed = node.trim();
      return trimmed ? trimmed : null;
    }
    if (Array.isArray(node)) {
      for (const item of node) {
        const found = walk(item);
        if (found) return found;
      }
      return null;
    }
    if (!node || typeof node !== 'object') return null;
    if (seen.has(node)) return null;
    seen.add(node);

    const record = node as Record<string, unknown>;
    const direct = record.formatted_output ?? record.formattedOutput ?? record.output ?? null;
    if (typeof direct === 'string' && direct.trim()) {
      return direct.trim();
    }

    for (const child of Object.values(record)) {
      const found = walk(child);
      if (found) return found;
    }
    return null;
  };

  return walk(value);
};

const normalizeTimeText = (value: string): string =>
  value
    .replace(/：/g, ':')
    .replace(/[—–]/g, '-')
    .trim();

const isLikelyTimeRange = (value: string): boolean =>
  /^\s*\d{1,2}:[0-5]\d\s*-\s*\d{1,2}:[0-5]\d\s*$/i.test(normalizeTimeText(value));

const isLikelySingleTime = (value: string): boolean =>
  /^\s*\d{1,2}:[0-5]\d\s*$/i.test(normalizeTimeText(value));

const isLikelyTimeValue = (value: string): boolean => {
  const normalized = normalizeTimeText(value).toLowerCase();
  return isLikelyTimeRange(normalized) || isLikelySingleTime(normalized) || normalized === 'open';
};

const isLikelyDateValue = (value: string): boolean => {
  const trimmed = value.trim();
  if (!trimmed) return false;
  if (/^\s*day\s*\d{1,2}\s*$/i.test(trimmed)) return true;
  if (/^\s*\d{4}[/-]\d{1,2}[/-]\d{1,2}\s*$/i.test(trimmed)) return true;
  if (/^\s*\d{1,2}\s*[A-Za-z]{3,}\.?\s*$/i.test(trimmed)) return true; // 31 DEC.
  if (/^\s*[A-Za-z]{3,}\.?\s*\d{1,2}\s*$/i.test(trimmed)) return true; // Nov.2
  return false;
};

const normalizeFormattedSegment = (value: string): string => {
  let cleaned = value.trim();
  cleaned = cleaned.replace(/^[\[{(]+/, '').replace(/[\]})]+$/, '').trim();
  cleaned = cleaned.replace(
    /^(?:"?(musician|artist|name|date|time|stage)"?)\s*[:：]\s*/i,
    ''
  );
  cleaned = cleaned.replace(/^"(.*)"$/, '$1').replace(/^'(.*)'$/, '$1');
  return cleaned.trim();
};

const parseFormattedOutputToItems = (text: string): ImportedLineupItem[] => {
  const lines = text
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);

  return lines
    .map((line, index) => {
      const segments = line
        .split(/[，,]/)
        .map((item) => normalizeFormattedSegment(item))
        .filter(Boolean);
      if (segments.length === 0) return null;

      const musician = sanitizeOptionalText(segments[0]);
      if (!musician) return null;

      let time: string | null = null;
      let stage: string | null = null;
      let date: string | null = null;
      const rest = segments.slice(1);
      const consumed = new Set<number>();

      for (let i = 0; i < rest.length; i += 1) {
        if (time === null && isLikelyTimeValue(rest[i])) {
          time = sanitizeOptionalText(rest[i]);
          consumed.add(i);
          continue;
        }
        if (date === null && isLikelyDateValue(rest[i])) {
          date = sanitizeOptionalText(rest[i]);
          consumed.add(i);
          continue;
        }
      }

      for (let i = 0; i < rest.length; i += 1) {
        if (consumed.has(i)) continue;
        const candidate = sanitizeOptionalText(rest[i]);
        if (!candidate) continue;
        if (time === null && isLikelyTimeValue(candidate)) {
          time = candidate;
          continue;
        }
        if (date === null && isLikelyDateValue(candidate)) {
          date = candidate;
          continue;
        }
        if (stage === null) {
          stage = candidate;
        }
      }

      return {
        id: `ocr-text-${index}-${Math.random().toString(36).slice(2, 8)}`,
        musician,
        time,
        stage,
        date,
      } satisfies ImportedLineupItem;
    })
    .filter((item): item is ImportedLineupItem => item !== null);
};

const normalizeImportedLineupItems = (items: Array<Record<string, unknown>>): ImportedLineupItem[] =>
  items
    .map((item, index) => {
      const musician = sanitizeOptionalText(item.musician ?? item.name ?? item.artist ?? item.djName);
      if (!musician) return null;
      return {
        id: `ocr-${index}-${Math.random().toString(36).slice(2, 8)}`,
        musician,
        time: sanitizeOptionalText(item.time ?? item.time_range ?? item.timeRange ?? item.slot),
        stage: sanitizeOptionalText(item.stage ?? item.stage_name ?? item.stageName),
        date: sanitizeOptionalText(item.date ?? item.day ?? item.performDate),
      } as ImportedLineupItem;
    })
    .filter((item): item is ImportedLineupItem => item !== null);

const resolveCozeFileType = (value: string): 'image' | 'video' | 'audio' | 'document' | 'default' => {
  const normalized = value.trim().toLowerCase();
  if (!normalized) return 'default';
  if (normalized === 'image' || normalized.startsWith('image/')) return 'image';
  if (normalized === 'video' || normalized.startsWith('video/')) return 'video';
  if (normalized === 'audio' || normalized.startsWith('audio/')) return 'audio';
  if (normalized === 'document' || normalized.startsWith('application/')) return 'document';
  return 'default';
};

const runCozeLineupWorker = async (
  imageUrl: string,
  fileType: string,
  signal?: AbortSignal
): Promise<{ normalizedText: string; lineupInfo: ImportedLineupItem[] }> => {
  const runtimeCozeConfig = getRuntimeCozeConfig();
  const cozeLineupWorkflowRunUrl = runtimeCozeConfig.lineup.runUrl;
  const cozeLineupWorkflowToken = runtimeCozeConfig.lineup.token;
  const cozeLineupWorkflowTimeoutMs = runtimeCozeConfig.lineup.timeoutMs;
  if (!cozeLineupWorkflowRunUrl || !cozeLineupWorkflowToken) {
    throw new Error('COZE_LINEUP_WORKFLOW_RUN_URL or COZE_LINEUP_WORKFLOW_TOKEN is not configured');
  }

  const payload = {
    image_url: imageUrl,
    file_type: fileType || 'image',
    context: {
      preferred_language: 'zh-Hans',
      known_dj_names: [],
    },
  };

  const startedAt = Date.now();
  console.info('[coze-lineup] run.start', {
    runUrl: cozeLineupWorkflowRunUrl,
    imageUrl,
    fileType,
    timeoutMs: cozeLineupWorkflowTimeoutMs,
  });
  const controller = new AbortController();
  if (signal) {
    if (signal.aborted) {
      controller.abort();
    } else {
      signal.addEventListener('abort', () => controller.abort(), { once: true });
    }
  }
  const timeout = setTimeout(() => controller.abort(), cozeLineupWorkflowTimeoutMs);
  let rawText = '';
  try {
    const response = await fetch(cozeLineupWorkflowRunUrl, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${cozeLineupWorkflowToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
      signal: controller.signal,
    });
    rawText = await response.text();
    console.info('[coze-lineup] run.response', {
      status: response.status,
      durationMs: Date.now() - startedAt,
      responseLength: rawText.length,
    });
    if (!response.ok) {
      throw new Error(`Coze workflow request failed (${response.status}): ${rawText.slice(0, 500)}`);
    }
  } catch (error) {
    if (error instanceof Error && error.name === 'AbortError') {
      if (signal?.aborted) {
        throw new Error('COZE_JOB_CANCELLED');
      }
      throw new Error(`COZE_LINEUP_WORKFLOW_TIMEOUT after ${cozeLineupWorkflowTimeoutMs}ms`);
    }
    throw error;
  } finally {
    clearTimeout(timeout);
  }

  const parsed = tryParseJsonFromText(rawText);
  if (parsed === null) {
    throw new Error('Coze workflow returned non-JSON content');
  }

  const lineupRaw = extractLineupInfo(parsed);
  let lineupInfo = normalizeImportedLineupItems(lineupRaw);
  if (lineupInfo.length === 0) {
    const normalized = normalizeLineupAIResult(extractLineupV2RawJson(parsed)) as {
      items?: Array<{ displayName?: string; performerNames?: string[] }>;
    };
    lineupInfo = (normalized.items ?? []).flatMap((item, index) => {
      const musician = sanitizeOptionalText(item.displayName) || (item.performerNames ?? [])[0] || (item.performerNames ?? []).join(' / ');
      return musician
        ? [{ id: `lineup-ai-${index + 1}`, musician, time: null, stage: null, date: null }]
        : [];
    });
  }
  if (lineupInfo.length === 0) {
    const formattedOutput = extractFormattedOutputText(parsed);
    if (formattedOutput) {
      lineupInfo = parseFormattedOutputToItems(formattedOutput);
    }
  }
  console.info('[coze-lineup] run.parsed', {
    durationMs: Date.now() - startedAt,
    lineupCount: lineupInfo.length,
  });

  return {
    normalizedText: JSON.stringify(
      {
        lineup_info: lineupInfo.map((item) => ({
          musician: item.musician,
          time: item.time ?? '未知',
          stage: item.stage ?? '未知',
          date: item.date ?? '未知',
        })),
      },
      null,
      2
    ),
    lineupInfo,
  };
};

const extractLineupV2RawJson = (value: unknown): unknown => {
  const parsed = typeof value === 'string' ? tryParseJsonFromText(value) ?? value : value;
  const seen = new WeakSet<object>();

  const walk = (node: unknown): unknown | null => {
    if (typeof node === 'string') {
      const nested = tryParseJsonFromText(node);
      return nested === null ? null : walk(nested);
    }
    if (Array.isArray(node)) {
      for (const item of node) {
        const found = walk(item);
        if (found !== null) return found;
      }
      return null;
    }
    if (!node || typeof node !== 'object') return null;
    if (seen.has(node)) return null;
    seen.add(node);

    const record = node as Record<string, unknown>;
    if (record.schema_version === 'raver_lineup_ai_v1' || record.schemaVersion === 'raver_lineup_ai_v1' || record.image_type === 'lineup' || record.imageType === 'lineup') {
      return record;
    }
    if (record.raw_json !== undefined) {
      const found = walk(record.raw_json);
      if (found !== null) return found;
    }
    if (record.rawJson !== undefined) {
      const found = walk(record.rawJson);
      if (found !== null) return found;
    }

    for (const child of Object.values(record)) {
      const found = walk(child);
      if (found !== null) return found;
    }
    return null;
  };

  return walk(parsed) ?? parsed;
};

const splitLineupActNamesByKeyword = (value: string, keyword: 'B2B' | 'B3B'): string[] | null => {
  const trimmed = value.trim();
  if (!trimmed) return null;
  const token = `__LINEUP_${keyword}_TOKEN__`;
  const replaced = trimmed.replace(new RegExp(`\\s*${keyword}\\s*`, 'gi'), token);
  const parts = replaced
    .split(token)
    .map((item) => item.trim())
    .filter(Boolean);
  return parts.length > 1 ? parts : null;
};

const parseExplicitLineupActFromText = (
  value: string
): { performerType: 'solo' | 'b2b' | 'b3b'; performerNames: string[] } | null => {
  const b3bNames = splitLineupActNamesByKeyword(value, 'B3B');
  if (b3bNames?.length) return { performerType: 'b3b', performerNames: b3bNames.slice(0, 3) };
  const b2bNames = splitLineupActNamesByKeyword(value, 'B2B');
  if (b2bNames?.length) return { performerType: 'b2b', performerNames: b2bNames.slice(0, 2) };
  return null;
};

const composeLineupDisplayName = (performerType: 'solo' | 'b2b' | 'b3b', performerNames: string[]): string => {
  const names = performerNames.map((item) => item.trim()).filter(Boolean);
  if (!names.length) return '';
  switch (performerType) {
    case 'b3b':
      return names.slice(0, 3).join(' B3B ');
    case 'b2b':
      return names.slice(0, 2).join(' B2B ');
    default:
      return names[0];
  }
};

const normalizeLineupAIResult = (value: unknown): unknown => {
  if (!value || typeof value !== 'object') return { items: [], warnings: [], unparsedTexts: [] };
  const input = value as Record<string, unknown>;
  const itemsInput = Array.isArray(input.items) ? input.items : [];
  const items = itemsInput
    .map((item, index) => {
      if (!item || typeof item !== 'object') return null;
      const record = item as Record<string, unknown>;
      const performerNamesRaw = record.performer_names ?? record.performerNames;
      const performerNames = Array.isArray(performerNamesRaw)
        ? performerNamesRaw.map((name) => (typeof name === 'string' ? name.trim() : '')).filter(Boolean)
        : [];
      const rawDisplayName = sanitizeOptionalText(record.display_name ?? record.displayName);
      const rawText = sanitizeOptionalText(record.raw_text ?? record.rawText) ?? rawDisplayName ?? '';
      const performerTypeRaw = sanitizeOptionalText(record.performer_type ?? record.performerType)?.toLowerCase();
      const explicitAct = parseExplicitLineupActFromText(rawDisplayName ?? rawText);
      let performerType: 'solo' | 'b2b' | 'b3b' = 'solo';
      let normalizedPerformerNames: string[] = [];

      if (performerTypeRaw === 'b3b' || explicitAct?.performerType === 'b3b') {
        performerType = 'b3b';
        normalizedPerformerNames = (performerNames.length >= 3 ? performerNames : explicitAct?.performerNames ?? performerNames).slice(0, 3);
      } else if (performerTypeRaw === 'b2b' || explicitAct?.performerType === 'b2b') {
        performerType = 'b2b';
        normalizedPerformerNames = (performerNames.length >= 2 ? performerNames : explicitAct?.performerNames ?? performerNames).slice(0, 2);
      } else {
        const soloName = rawDisplayName || rawText || performerNames.join(' / ');
        normalizedPerformerNames = soloName ? [soloName] : [];
      }

      const displayName = rawDisplayName || composeLineupDisplayName(performerType, normalizedPerformerNames);
      if (!displayName && normalizedPerformerNames.length === 0) return null;
      const orderRaw = Number(record.order);
      const confidenceRaw = Number(record.confidence);
      return {
        order: Number.isFinite(orderRaw) ? Math.max(1, Math.floor(orderRaw)) : index + 1,
        performerType,
        performerNames: normalizedPerformerNames,
        displayName,
        rawText: rawText || displayName,
        confidence: Number.isFinite(confidenceRaw) ? Math.max(0, Math.min(1, confidenceRaw)) : null,
        notes: Array.isArray(record.notes)
          ? record.notes.map((note) => (typeof note === 'string' ? note.trim() : '')).filter(Boolean)
          : [],
      };
    })
    .filter((item): item is NonNullable<typeof item> => item !== null)
    .sort((a, b) => a.order - b.order);

  const stringArray = (raw: unknown): string[] => Array.isArray(raw)
    ? raw.map((item) => (typeof item === 'string' ? item.trim() : '')).filter(Boolean)
    : [];

  return {
    schemaVersion: sanitizeOptionalText(input.schema_version ?? input.schemaVersion) ?? 'raver_lineup_ai_v1',
    imageType: sanitizeOptionalText(input.image_type ?? input.imageType) ?? 'lineup',
    items,
    unparsedTexts: stringArray(input.unparsed_texts ?? input.unparsedTexts),
    warnings: stringArray(input.warnings),
  };
};

const sanitizeLineupRecognitionContext = (value: unknown): LineupRecognitionContext => {
  if (!value || typeof value !== 'object') return {};
  const input = value as Record<string, unknown>;
  const out: LineupRecognitionContext = {};
  const preferredLanguage = sanitizeOptionalText(input.preferred_language ?? input.preferredLanguage);
  if (preferredLanguage) out.preferred_language = preferredLanguage;
  const knownNames = input.known_dj_names ?? input.knownDJNames;
  if (Array.isArray(knownNames)) {
    out.known_dj_names = knownNames
      .map((item) => (typeof item === 'string' ? item.trim() : ''))
      .filter(Boolean)
      .slice(0, 100);
  }
  return out;
};

const runCozeLineupV2Worker = async (
  req: Request,
  imageUrl: string,
  fileType: string,
  context: LineupRecognitionContext,
  signal?: AbortSignal
): Promise<{ rawJson: unknown; rawResponse: unknown }> => {
  const runtimeCozeConfig = getRuntimeCozeConfig();
  const cozeLineupWorkflowRunUrl = runtimeCozeConfig.lineup.runUrl;
  const cozeLineupWorkflowToken = runtimeCozeConfig.lineup.token;
  const cozeLineupWorkflowTimeoutMs = runtimeCozeConfig.lineup.timeoutMs;
  if (!cozeLineupWorkflowRunUrl || !cozeLineupWorkflowToken) {
    throw new Error('COZE_LINEUP_WORKFLOW_RUN_URL or COZE_LINEUP_WORKFLOW_TOKEN is not configured');
  }

  const resolvedImageUrl = await ensureCozeAccessibleImageUrl(req, imageUrl, fileType, 'lineup');
  const payload = {
    image_url: resolvedImageUrl,
    file_type: fileType || 'image',
    context,
  };

  const startedAt = Date.now();
  console.info('[coze-lineup-v2] run.start', {
    runUrl: cozeLineupWorkflowRunUrl,
    imageUrl: resolvedImageUrl,
    fileType,
    timeoutMs: cozeLineupWorkflowTimeoutMs,
    context,
  });
  const controller = new AbortController();
  if (signal) {
    if (signal.aborted) {
      controller.abort();
    } else {
      signal.addEventListener('abort', () => controller.abort(), { once: true });
    }
  }
  const timeout = setTimeout(() => controller.abort(), cozeLineupWorkflowTimeoutMs);
  let rawText = '';
  try {
    const response = await fetch(cozeLineupWorkflowRunUrl, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${cozeLineupWorkflowToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
      signal: controller.signal,
    });
    rawText = await response.text();
    console.info('[coze-lineup-v2] run.response', {
      status: response.status,
      durationMs: Date.now() - startedAt,
      responseLength: rawText.length,
    });
    if (!response.ok) {
      throw new Error(`Coze workflow request failed (${response.status}): ${rawText.slice(0, 500)}`);
    }
  } catch (error) {
    if (error instanceof Error && error.name === 'AbortError') {
      if (signal?.aborted) {
        throw new Error('COZE_JOB_CANCELLED');
      }
      throw new Error(`COZE_LINEUP_WORKFLOW_TIMEOUT after ${cozeLineupWorkflowTimeoutMs}ms`);
    }
    throw error;
  } finally {
    clearTimeout(timeout);
  }

  const parsed = tryParseJsonFromText(rawText);
  if (parsed === null) {
    throw new Error('Coze workflow returned non-JSON content');
  }

  return {
    rawJson: normalizeLineupAIResult(extractLineupV2RawJson(parsed)),
    rawResponse: parsed,
  };
};

const extractPosterRawJson = (value: unknown): unknown => {
  const parsed = typeof value === 'string' ? tryParseJsonFromText(value) ?? value : value;
  const seen = new WeakSet<object>();

  const walk = (node: unknown): unknown | null => {
    if (typeof node === 'string') {
      const nested = tryParseJsonFromText(node);
      return nested === null ? null : walk(nested);
    }
    if (Array.isArray(node)) {
      for (const item of node) {
        const found = walk(item);
        if (found !== null) return found;
      }
      return null;
    }
    if (!node || typeof node !== 'object') return null;
    if (seen.has(node)) return null;
    seen.add(node);

    const record = node as Record<string, unknown>;
    if (
      record.schema_version === 'raver_event_poster_ai_v1'
      || record.schemaVersion === 'raver_event_poster_ai_v1'
      || record.image_type === 'poster_basic_info'
      || record.imageType === 'poster_basic_info'
    ) {
      return record;
    }
    if (record.raw_json !== undefined) {
      const found = walk(record.raw_json);
      if (found !== null) return found;
    }
    if (record.rawJson !== undefined) {
      const found = walk(record.rawJson);
      if (found !== null) return found;
    }

    for (const child of Object.values(record)) {
      const found = walk(child);
      if (found !== null) return found;
    }
    return null;
  };

  return walk(parsed) ?? parsed;
};

const normalizePosterAIResult = (value: unknown): unknown => {
  const emptyI18n = { zh: '', en: '', ja: '' };
  const emptyCountry = { zh: '', en: '', ja: '', enFull: '' };
  const stringArray = (raw: unknown): string[] => Array.isArray(raw)
    ? raw.map((item) => (typeof item === 'string' ? item.trim() : '')).filter(Boolean)
    : [];
  const normalizeI18n = (raw: unknown, includeEnFull = false) => {
    if (!raw || typeof raw !== 'object') {
      return includeEnFull ? { ...emptyCountry } : { ...emptyI18n };
    }
    const input = raw as Record<string, unknown>;
    const out: Record<string, string> = {
      zh: sanitizeOptionalText(input.zh) ?? '',
      en: sanitizeOptionalText(input.en) ?? '',
      ja: sanitizeOptionalText(input.ja) ?? '',
    };
    if (includeEnFull) {
      out.enFull = sanitizeOptionalText(input.enFull ?? input.en_full) ?? '';
    }
    return out;
  };
  const normalizeWeekRanges = (raw: unknown) => Array.isArray(raw)
    ? raw.map((item, index) => {
        if (!item || typeof item !== 'object') return null;
        const record = item as Record<string, unknown>;
        const weekIndexRaw = Number(record.weekIndex ?? record.week_index);
        const startDate = sanitizeOptionalText(record.startDate ?? record.start_date);
        const endDate = sanitizeOptionalText(record.endDate ?? record.end_date);
        if (!startDate || !endDate) return null;
        return {
          weekIndex: Number.isFinite(weekIndexRaw) ? Math.max(1, Math.floor(weekIndexRaw)) : index + 1,
          startDate,
          endDate,
        };
      }).filter((item): item is NonNullable<typeof item> => item !== null)
    : [];

  if (!value || typeof value !== 'object') {
    return {
      schemaVersion: 'raver_event_poster_ai_v1',
      imageType: 'poster_basic_info',
      nameI18n: { ...emptyI18n },
      cityI18n: { ...emptyI18n },
      detailAddressI18n: { ...emptyI18n },
      countryI18n: { ...emptyCountry },
      timeZone: { ianaName: null, displayName: '', confidence: 0, source: 'unknown' },
      schedule: { scheduleMode: 'unknown', startDate: null, endDate: null, weekRanges: [], rawDateText: '', confidence: 0 },
      ticketInfo: { ticketUrl: '', currency: '', tiers: [] },
      unparsedTexts: [],
      warnings: [],
    };
  }

  const input = value as Record<string, unknown>;
  const timeZoneInput = input.timeZone && typeof input.timeZone === 'object' ? input.timeZone as Record<string, unknown> : {};
  const scheduleInput = input.schedule && typeof input.schedule === 'object' ? input.schedule as Record<string, unknown> : {};
  const ticketInfoInput = input.ticketInfo && typeof input.ticketInfo === 'object' ? input.ticketInfo as Record<string, unknown> : {};
  const tiers = Array.isArray(ticketInfoInput.tiers)
    ? ticketInfoInput.tiers.map((item) => {
        if (!item || typeof item !== 'object') return null;
        const record = item as Record<string, unknown>;
        const priceRaw = Number(record.price);
        return {
          name: sanitizeOptionalText(record.name) ?? '',
          price: Number.isFinite(priceRaw) ? priceRaw : 0,
          priceText: sanitizeOptionalText(record.priceText ?? record.price_text) ?? '',
        };
      }).filter((item): item is NonNullable<typeof item> => item !== null)
    : [];

  return {
    schemaVersion: sanitizeOptionalText(input.schemaVersion ?? input.schema_version) ?? 'raver_event_poster_ai_v1',
    imageType: sanitizeOptionalText(input.imageType ?? input.image_type) ?? 'poster_basic_info',
    nameI18n: normalizeI18n(input.nameI18n ?? input.name_i18n),
    cityI18n: normalizeI18n(input.cityI18n ?? input.city_i18n),
    detailAddressI18n: normalizeI18n(input.detailAddressI18n ?? input.detail_address_i18n),
    countryI18n: normalizeI18n(input.countryI18n ?? input.country_i18n, true),
    timeZone: {
      ianaName: sanitizeOptionalText(timeZoneInput.ianaName ?? timeZoneInput.iana_name),
      displayName: sanitizeOptionalText(timeZoneInput.displayName ?? timeZoneInput.display_name) ?? '',
      confidence: Number.isFinite(Number(timeZoneInput.confidence)) ? Math.max(0, Math.min(1, Number(timeZoneInput.confidence))) : 0,
      source: sanitizeOptionalText(timeZoneInput.source) ?? 'unknown',
    },
    schedule: {
      scheduleMode: sanitizeOptionalText(scheduleInput.scheduleMode ?? scheduleInput.schedule_mode) ?? 'unknown',
      startDate: sanitizeOptionalText(scheduleInput.startDate ?? scheduleInput.start_date),
      endDate: sanitizeOptionalText(scheduleInput.endDate ?? scheduleInput.end_date),
      weekRanges: normalizeWeekRanges(scheduleInput.weekRanges ?? scheduleInput.week_ranges),
      rawDateText: sanitizeOptionalText(scheduleInput.rawDateText ?? scheduleInput.raw_date_text) ?? '',
      confidence: Number.isFinite(Number(scheduleInput.confidence)) ? Math.max(0, Math.min(1, Number(scheduleInput.confidence))) : 0,
    },
    ticketInfo: {
      ticketUrl: sanitizeOptionalText(ticketInfoInput.ticketUrl ?? ticketInfoInput.ticket_url) ?? '',
      currency: sanitizeOptionalText(ticketInfoInput.currency) ?? '',
      tiers,
    },
    unparsedTexts: stringArray(input.unparsedTexts ?? input.unparsed_texts),
    warnings: stringArray(input.warnings),
  };
};

const runCozePosterWorker = async (
  req: Request,
  imageUrl: string,
  fileType: string,
  signal?: AbortSignal
): Promise<{ rawJson: unknown; rawResponse: unknown }> => {
  const runtimeCozeConfig = getRuntimeCozeConfig();
  const cozePosterWorkflowRunUrl = runtimeCozeConfig.poster.runUrl;
  const cozePosterWorkflowToken = runtimeCozeConfig.poster.token;
  const cozePosterWorkflowTimeoutMs = runtimeCozeConfig.poster.timeoutMs;
  if (!cozePosterWorkflowRunUrl || !cozePosterWorkflowToken) {
    throw new Error('COZE_POSTER_WORKFLOW_RUN_URL or COZE_POSTER_WORKFLOW_TOKEN is not configured');
  }

  const resolvedImageUrl = await ensureCozeAccessibleImageUrl(req, imageUrl, fileType, 'poster');
  const payload = {
    image_url: resolvedImageUrl,
    file_type: fileType || 'image/jpeg',
  };

  const startedAt = Date.now();
  console.info('[coze-poster] run.start', {
    runUrl: cozePosterWorkflowRunUrl,
    imageUrl: resolvedImageUrl,
    fileType,
    timeoutMs: cozePosterWorkflowTimeoutMs,
  });
  const controller = new AbortController();
  if (signal) {
    if (signal.aborted) {
      controller.abort();
    } else {
      signal.addEventListener('abort', () => controller.abort(), { once: true });
    }
  }
  const timeout = setTimeout(() => controller.abort(), cozePosterWorkflowTimeoutMs);
  let rawText = '';
  try {
    const response = await fetch(cozePosterWorkflowRunUrl, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${cozePosterWorkflowToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
      signal: controller.signal,
    });
    rawText = await response.text();
    console.info('[coze-poster] run.response', {
      status: response.status,
      durationMs: Date.now() - startedAt,
      responseLength: rawText.length,
    });
    if (!response.ok) {
      throw new Error(`Coze workflow request failed (${response.status}): ${rawText.slice(0, 500)}`);
    }
  } catch (error) {
    if (error instanceof Error && error.name === 'AbortError') {
      if (signal?.aborted) {
        throw new Error('COZE_JOB_CANCELLED');
      }
      throw new Error(`COZE_POSTER_WORKFLOW_TIMEOUT after ${cozePosterWorkflowTimeoutMs}ms`);
    }
    throw error;
  } finally {
    clearTimeout(timeout);
  }

  const parsed = tryParseJsonFromText(rawText);
  if (parsed === null) {
    throw new Error('Coze workflow returned non-JSON content');
  }

  return {
    rawJson: normalizePosterAIResult(extractPosterRawJson(parsed)),
    rawResponse: parsed,
  };
};

const extractTimetableRawJson = (value: unknown): unknown => {
  const parsed = typeof value === 'string' ? tryParseJsonFromText(value) ?? value : value;
  const seen = new WeakSet<object>();

  const walk = (node: unknown): unknown | null => {
    if (typeof node === 'string') {
      const nested = tryParseJsonFromText(node);
      return nested === null ? null : walk(nested);
    }
    if (Array.isArray(node)) {
      for (const item of node) {
        const found = walk(item);
        if (found !== null) return found;
      }
      return null;
    }
    if (!node || typeof node !== 'object') return null;
    if (seen.has(node)) return null;
    seen.add(node);

    const record = node as Record<string, unknown>;
    if (record.schemaVersion === 'raver_timetable_ai_v3' || record.imageType === 'timetable') {
      return record;
    }
    if (record.raw_json !== undefined) {
      const found = walk(record.raw_json);
      if (found !== null) return found;
    }
    if (record.rawJson !== undefined) {
      const found = walk(record.rawJson);
      if (found !== null) return found;
    }

    for (const child of Object.values(record)) {
      const found = walk(child);
      if (found !== null) return found;
    }
    return null;
  };

  return walk(parsed) ?? parsed;
};

const sanitizeTimetableRecognitionContext = (value: unknown): TimetableRecognitionContext => {
  if (!value || typeof value !== 'object') return {};
  const input = value as Record<string, unknown>;
  const out: TimetableRecognitionContext = {};

  const eventTimeZone = sanitizeOptionalText(input.eventTimeZone);
  if (eventTimeZone) {
    out.eventTimeZone = eventTimeZone;
  }

  const rollover = Number(input.dayRolloverHour);
  if (Number.isFinite(rollover)) {
    out.dayRolloverHour = Math.max(0, Math.min(12, Math.floor(rollover)));
  }

  if (input.schedule && typeof input.schedule === 'object') {
    const scheduleInput = input.schedule as Record<string, unknown>;
    out.schedule = {
      mode: sanitizeOptionalText(scheduleInput.mode) ?? undefined,
      timeZone: sanitizeOptionalText(scheduleInput.timeZone) ?? undefined,
      dayRolloverHour: Number.isFinite(Number(scheduleInput.dayRolloverHour))
        ? Math.max(0, Math.min(12, Math.floor(Number(scheduleInput.dayRolloverHour))))
        : undefined,
    };
  }

  if (Array.isArray(input.weeks)) {
    out.weeks = input.weeks
      .map((item, index) => {
        if (!item || typeof item !== 'object') return null;
        const record = item as Record<string, unknown>;
        const weekIndex = Number(record.weekIndex);
        const startDate = typeof record.startDate === 'string' ? record.startDate.trim() : '';
        const endDate = typeof record.endDate === 'string' ? record.endDate.trim() : '';
        return {
          weekIndex: Number.isFinite(weekIndex) ? Math.max(1, Math.floor(weekIndex)) : index + 1,
          label: sanitizeOptionalText(record.label) ?? undefined,
          startDate: startDate || undefined,
          endDate: endDate || undefined,
          sortOrder: Number.isFinite(Number(record.sortOrder))
            ? Math.max(1, Math.floor(Number(record.sortOrder)))
            : index + 1,
        };
      })
      .filter((item): item is NonNullable<typeof item> => item !== null);
  }

  if (Array.isArray(input.eventDays)) {
    out.eventDays = input.eventDays
      .map((item) => {
        if (!item || typeof item !== 'object') return null;
        const record = item as Record<string, unknown>;
        const eventDayId = sanitizeOptionalText(record.eventDayId);
        const weekIndex = Number(record.weekIndex);
        const dayIndexInWeek = Number(record.dayIndexInWeek);
        const overallDayIndex = Number(record.overallDayIndex);
        const date = typeof record.date === 'string' ? record.date.trim() : '';
        if (!eventDayId || !date) return null;
        return {
          eventDayId,
          weekIndex: Number.isFinite(weekIndex) ? Math.max(1, Math.floor(weekIndex)) : undefined,
          dayIndexInWeek: Number.isFinite(dayIndexInWeek) ? Math.max(1, Math.floor(dayIndexInWeek)) : undefined,
          overallDayIndex: Number.isFinite(overallDayIndex) ? Math.max(1, Math.floor(overallDayIndex)) : undefined,
          label: sanitizeOptionalText(record.label) ?? undefined,
          weekday: sanitizeOptionalText(record.weekday)?.toLowerCase() ?? undefined,
          date,
          sortOrder: Number.isFinite(Number(record.sortOrder))
            ? Math.max(1, Math.floor(Number(record.sortOrder)))
            : undefined,
        };
      })
      .filter((item): item is NonNullable<typeof item> => item !== null);
  }

  if (Array.isArray(input.knownStageNames)) {
    out.knownStageNames = input.knownStageNames
      .map((item) => (typeof item === 'string' ? item.trim() : ''))
      .filter(Boolean)
      .slice(0, 50);
  }

  return out;
};

const normalizeTimetableAIResult = (
  value: unknown,
  context: TimetableRecognitionContext
): unknown => {
  const stringArray = (raw: unknown): string[] => Array.isArray(raw)
    ? raw.map((item) => (typeof item === 'string' ? item.trim() : '')).filter(Boolean)
    : [];
  const clampConfidence = (raw: unknown): number => {
    const parsed = Number(raw);
    return Number.isFinite(parsed) ? Math.max(0, Math.min(1, parsed)) : 0;
  };
  const normalizeWeekday = (raw: unknown): string | null => {
    const text = sanitizeOptionalText(raw)?.toLowerCase() ?? '';
    if (!text) return null;
    const mappings: Array<[string, string]> = [
      ['monday', 'monday'],
      ['mon', 'monday'],
      ['tuesday', 'tuesday'],
      ['tue', 'tuesday'],
      ['tues', 'tuesday'],
      ['wednesday', 'wednesday'],
      ['wed', 'wednesday'],
      ['thursday', 'thursday'],
      ['thu', 'thursday'],
      ['thur', 'thursday'],
      ['thurs', 'thursday'],
      ['friday', 'friday'],
      ['fri', 'friday'],
      ['saturday', 'saturday'],
      ['sat', 'saturday'],
      ['sunday', 'sunday'],
      ['sun', 'sunday'],
    ];
    for (const [token, normalized] of mappings) {
      if (text === token || text.includes(token)) return normalized;
    }
    return null;
  };
  const warnings = new Set<string>(stringArray((value as Record<string, unknown> | null)?.warnings));
  const contextEventDays = Array.isArray(context.eventDays) ? context.eventDays : [];
  const contextEventDayById = new Map(
    contextEventDays
      .filter((item): item is NonNullable<typeof item> => Boolean(item?.eventDayId))
      .map((item) => [item.eventDayId as string, item])
  );
  const eventDayCandidates = (
    hints: {
      eventDayId?: string | null;
      weekIndex?: number | null;
      dayIndexInWeek?: number | null;
      weekday?: string | null;
      date?: string | null;
      dayLabel?: string | null;
    }
  ) => {
    const explicitId = sanitizeOptionalText(hints.eventDayId);
    if (explicitId && contextEventDayById.has(explicitId)) {
      return [contextEventDayById.get(explicitId)!];
    }

    let candidates = contextEventDays.slice();
    const dateHint = sanitizeOptionalText(hints.date);
    if (dateHint) {
      candidates = candidates.filter((item) => item.date === dateHint);
    }
    const weekIndexHint = Number.isFinite(Number(hints.weekIndex)) ? Math.max(1, Math.floor(Number(hints.weekIndex))) : null;
    if (weekIndexHint !== null) {
      candidates = candidates.filter((item) => item.weekIndex === weekIndexHint);
    }
    const dayIndexHint = Number.isFinite(Number(hints.dayIndexInWeek)) ? Math.max(1, Math.floor(Number(hints.dayIndexInWeek))) : null;
    if (dayIndexHint !== null) {
      candidates = candidates.filter((item) => item.dayIndexInWeek === dayIndexHint);
    }
    const weekdayHint = normalizeWeekday(hints.weekday) ?? normalizeWeekday(hints.dayLabel);
    if (weekdayHint) {
      candidates = candidates.filter((item) => normalizeWeekday(item.weekday) === weekdayHint);
    }
    return candidates;
  };
  const normalizeResolvedEventDay = (
    raw: unknown,
    fallback: {
      weekIndex?: number | null;
      dayIndexInWeek?: number | null;
      weekday?: string | null;
      date?: string | null;
      dayLabel?: string | null;
    }
  ) => {
    const input = raw && typeof raw === 'object' ? raw as Record<string, unknown> : {};
    const candidates = eventDayCandidates({
      eventDayId: sanitizeOptionalText(input.eventDayId),
      weekIndex: Number(input.weekIndex),
      dayIndexInWeek: Number(input.dayIndexInWeek),
      weekday: sanitizeOptionalText(fallback.weekday),
      date: sanitizeOptionalText(input.date) ?? sanitizeOptionalText(fallback.date),
      dayLabel: sanitizeOptionalText(fallback.dayLabel),
    });
    const matched = candidates.length === 1 ? candidates[0] : null;
    if (!matched && candidates.length > 1) {
      const ambiguityText = sanitizeOptionalText(fallback.dayLabel)
        ?? sanitizeOptionalText(fallback.weekday)
        ?? sanitizeOptionalText(fallback.date)
        ?? `week ${fallback.weekIndex ?? '?'} day ${fallback.dayIndexInWeek ?? '?'}`;
      warnings.add(`Ambiguous event day mapping for "${ambiguityText}" across multiple provided eventDays`);
    }
    if (!matched && contextEventDays.length > 0) {
      warnings.add(
        `Unresolved event day mapping for "${sanitizeOptionalText(fallback.dayLabel) ?? sanitizeOptionalText(fallback.date) ?? `week ${fallback.weekIndex ?? '?'} day ${fallback.dayIndexInWeek ?? '?'}`}". Manual confirmation required.`
      );
    }
    const resolved = matched ?? null;
    return {
      eventDayId: resolved?.eventDayId ?? null,
      weekIndex: resolved?.weekIndex ?? (
        Number.isFinite(Number(input.weekIndex))
          ? Math.max(1, Math.floor(Number(input.weekIndex)))
          : (Number.isFinite(Number(fallback.weekIndex)) ? Math.max(1, Math.floor(Number(fallback.weekIndex))) : 1)
      ),
      dayIndexInWeek: resolved?.dayIndexInWeek ?? (
        Number.isFinite(Number(input.dayIndexInWeek))
          ? Math.max(1, Math.floor(Number(input.dayIndexInWeek)))
          : (Number.isFinite(Number(fallback.dayIndexInWeek)) ? Math.max(1, Math.floor(Number(fallback.dayIndexInWeek))) : 1)
      ),
      overallDayIndex: resolved?.overallDayIndex ?? (
        Number.isFinite(Number(input.overallDayIndex)) ? Math.max(1, Math.floor(Number(input.overallDayIndex))) : null
      ),
      date: resolved?.date ?? sanitizeOptionalText(input.date) ?? sanitizeOptionalText(fallback.date),
      resolutionReason: sanitizeOptionalText(input.resolutionReason)
        ?? (resolved
          ? 'Matched against provided eventDays context'
          : 'No unique eventDay could be resolved from visible text and provided eventDays'),
      confidence: clampConfidence(input.confidence),
    };
  };

  if (!value || typeof value !== 'object') {
    return {
      schemaVersion: 'raver_timetable_ai_v3',
      imageType: 'timetable',
      weeks: [],
      unparsedTexts: [],
      warnings: Array.from(warnings),
    };
  }

  const input = value as Record<string, unknown>;
  const rawWeeks = Array.isArray(input.weeks) ? input.weeks : [];
  const weeks = rawWeeks.map((weekItem, weekOffset) => {
    const weekRecord = weekItem && typeof weekItem === 'object' ? weekItem as Record<string, unknown> : {};
    const normalizedWeekIndex = Number.isFinite(Number(weekRecord.weekIndex))
      ? Math.max(1, Math.floor(Number(weekRecord.weekIndex)))
      : weekOffset + 1;
    const rawDays = Array.isArray(weekRecord.days) ? weekRecord.days : [];
    return {
      weekIndex: normalizedWeekIndex,
      weekLabel: sanitizeOptionalText(weekRecord.weekLabel) ?? null,
      days: rawDays.map((dayItem, dayOffset) => {
        const dayRecord = dayItem && typeof dayItem === 'object' ? dayItem as Record<string, unknown> : {};
        const normalizedDayIndexInWeek = Number.isFinite(Number(dayRecord.dayIndexInWeek))
          ? Math.max(1, Math.floor(Number(dayRecord.dayIndexInWeek)))
          : dayOffset + 1;
        const normalizedWeekday = normalizeWeekday(dayRecord.weekday ?? dayRecord.dayLabel);
        return {
          dayIndexInWeek: normalizedDayIndexInWeek,
          dayLabel: sanitizeOptionalText(dayRecord.dayLabel),
          weekday: normalizedWeekday,
          dateText: sanitizeOptionalText(dayRecord.dateText),
          eventDayRef: normalizeResolvedEventDay(dayRecord.eventDayRef, {
            weekIndex: Number(dayRecord.weekIndex) || normalizedWeekIndex,
            dayIndexInWeek: normalizedDayIndexInWeek,
            weekday: normalizedWeekday,
            date: sanitizeOptionalText(dayRecord.dateText),
            dayLabel: sanitizeOptionalText(dayRecord.dayLabel),
          }),
          stages: Array.isArray(dayRecord.stages)
            ? dayRecord.stages.map((stageItem, stageOffset) => {
                const stageRecord = stageItem && typeof stageItem === 'object' ? stageItem as Record<string, unknown> : {};
                return {
                  stageName: sanitizeOptionalText(stageRecord.stageName) ?? '',
                  order: Number.isFinite(Number(stageRecord.order)) ? Math.max(1, Math.floor(Number(stageRecord.order))) : stageOffset + 1,
                  slots: Array.isArray(stageRecord.slots)
                    ? stageRecord.slots.map((slotItem, slotOffset) => {
                        const slotRecord = slotItem && typeof slotItem === 'object' ? slotItem as Record<string, unknown> : {};
                        return {
                          orderInStage: Number.isFinite(Number(slotRecord.orderInStage))
                            ? Math.max(1, Math.floor(Number(slotRecord.orderInStage)))
                            : slotOffset + 1,
                          performerType: sanitizeOptionalText(slotRecord.performerType) ?? 'solo',
                          performerNames: stringArray(slotRecord.performerNames),
                          displayName: sanitizeOptionalText(slotRecord.displayName) ?? '',
                          rawTimeText: sanitizeOptionalText(slotRecord.rawTimeText),
                          startTimeText: sanitizeOptionalText(slotRecord.startTimeText),
                          endTimeText: sanitizeOptionalText(slotRecord.endTimeText),
                          normalizedStartTime: sanitizeOptionalText(slotRecord.normalizedStartTime),
                          normalizedEndTime: sanitizeOptionalText(slotRecord.normalizedEndTime),
                          confidence: clampConfidence(slotRecord.confidence),
                          notes: stringArray(slotRecord.notes),
                        };
                      })
                    : [],
                };
              })
            : [],
        };
      }),
    };
  });

  return {
    schemaVersion: 'raver_timetable_ai_v3',
    imageType: sanitizeOptionalText(input.imageType) ?? 'timetable',
    weeks,
    unparsedTexts: stringArray(input.unparsedTexts),
    warnings: Array.from(warnings),
  };
};

const runCozeTimetableWorker = async (
  req: Request,
  imageUrl: string,
  fileType: string,
  context: TimetableRecognitionContext,
  signal?: AbortSignal
): Promise<{ rawJson: unknown; rawResponse: unknown }> => {
  const runtimeCozeConfig = getRuntimeCozeConfig();
  const cozeTimetableWorkflowRunUrl = runtimeCozeConfig.timetable.runUrl;
  const cozeTimetableWorkflowToken = runtimeCozeConfig.timetable.token;
  const cozeTimetableWorkflowTimeoutMs = runtimeCozeConfig.timetable.timeoutMs;
  if (!cozeTimetableWorkflowRunUrl || !cozeTimetableWorkflowToken) {
    throw new Error('COZE_TIMETABLE_WORKFLOW_RUN_URL or COZE_TIMETABLE_WORKFLOW_TOKEN is not configured');
  }

  const resolvedImageUrl = await ensureCozeAccessibleImageUrl(req, imageUrl, fileType, 'timetable');
  const payload = {
    image: {
      url: resolvedImageUrl,
      file_type: resolveCozeFileType(fileType),
    },
    context_json: JSON.stringify(context ?? {}),
  };

  const startedAt = Date.now();
  console.info('[coze-timetable] run.start', {
    runUrl: cozeTimetableWorkflowRunUrl,
    imageUrl: resolvedImageUrl,
    fileType,
    timeoutMs: cozeTimetableWorkflowTimeoutMs,
    context,
    contextJsonLength: payload.context_json.length,
  });
  const controller = new AbortController();
  if (signal) {
    if (signal.aborted) {
      controller.abort();
    } else {
      signal.addEventListener('abort', () => controller.abort(), { once: true });
    }
  }
  const timeout = setTimeout(() => controller.abort(), cozeTimetableWorkflowTimeoutMs);
  let rawText = '';
  try {
    const response = await fetch(cozeTimetableWorkflowRunUrl, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${cozeTimetableWorkflowToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
      signal: controller.signal,
    });
    rawText = await response.text();
    console.info('[coze-timetable] run.response', {
      status: response.status,
      durationMs: Date.now() - startedAt,
      responseLength: rawText.length,
    });
    if (!response.ok) {
      throw new Error(`Coze workflow request failed (${response.status}): ${rawText.slice(0, 500)}`);
    }
  } catch (error) {
    if (error instanceof Error && error.name === 'AbortError') {
      if (signal?.aborted) {
        throw new Error('COZE_JOB_CANCELLED');
      }
      throw new Error(`COZE_TIMETABLE_WORKFLOW_TIMEOUT after ${cozeTimetableWorkflowTimeoutMs}ms`);
    }
    throw error;
  } finally {
    clearTimeout(timeout);
  }

  const parsed = tryParseJsonFromText(rawText);
  if (parsed === null) {
    throw new Error('Coze workflow returned non-JSON content');
  }

  return {
    rawJson: normalizeTimetableAIResult(extractTimetableRawJson(parsed), context),
    rawResponse: parsed,
  };
};

const extraOssImageHostSuffixes = (process.env.RAVER_OSS_IMAGE_HOSTS || process.env.OSS_IMAGE_HOSTS || '')
  .split(',')
  .map((item) => item.trim().toLowerCase())
  .filter(Boolean);

const ossConfigMissingMessage = 'OSS is not configured. Require OSS_REGION/OSS_ACCESS_KEY_ID/OSS_ACCESS_KEY_SECRET/OSS_BUCKET';

const isLikelyAliyunOssHost = (host: string): boolean => {
  const normalized = host.trim().toLowerCase();
  if (!normalized) return false;
  if (normalized === 'aliyuncs.com' || normalized.endsWith('.aliyuncs.com')) {
    return true;
  }
  return extraOssImageHostSuffixes.some((suffix) => normalized === suffix || normalized.endsWith(`.${suffix}`));
};

const shouldMirrorRemoteImageToOss = (value: string): boolean => {
  const trimmed = value.trim();
  if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) return false;
  try {
    const parsed = new URL(trimmed);
    return !isLikelyAliyunOssHost(parsed.hostname);
  } catch (_error) {
    return false;
  }
};

const buildOssAvatarVariantUrl = (
  rawUrl: string | null | undefined,
  djIdOrSize: string | 'small' | 'medium' | 'original',
  requestedSize?: 'small' | 'medium' | 'original'
): string | null => {
  const djId = requestedSize ? djIdOrSize : null;
  const size = requestedSize ?? (djIdOrSize as 'small' | 'medium' | 'original');
  const hasMaterializedVariants =
    typeof rawUrl === 'string' && /\/avatar_original\.webp(?:$|\?)/.test(rawUrl.trim());
  const materialized = djId && size !== 'original' && hasMaterializedVariants
    ? buildDJAvatarVariantURL(djId, size)
    : null;
  if (materialized) return materialized;

  return buildDynamicOssAvatarVariantUrl(rawUrl, size);
};

const buildDynamicOssAvatarVariantUrl = (
  rawUrl: string | null | undefined,
  size: 'small' | 'medium' | 'original'
): string | null => {
  const normalized = typeof rawUrl === 'string' ? rawUrl.trim() : '';
  if (!normalized) return null;
  if (size === 'original') return normalized;

  let parsed: URL;
  try {
    parsed = new URL(normalized);
  } catch {
    return normalized;
  }

  const pathLooksLikeDJMedia = parsed.pathname.toLowerCase().includes('/djs/');
  if (!isLikelyAliyunOssHost(parsed.hostname) && !pathLooksLikeDJMedia) {
    return normalized;
  }

  const process = size === 'small'
    ? 'image/resize,m_fill,w_160,h_160/quality,q_82/format,webp'
    : 'image/resize,m_fill,w_480,h_480/quality,q_88/format,webp';
  parsed.searchParams.set('x-oss-process', process);
  return parsed.toString();
};

const mapDJ = (
  row: any,
  isFollowing = false,
  viewerId: string | null | undefined = null,
  viewerRole: string | null | undefined = null
) => {
  const resolvedAvatarUrl =
    typeof row.avatarUrl === 'string' && row.avatarUrl.trim().length > 0
      ? row.avatarUrl.trim()
      : null;
  const nameI18n = resolveBiTextWithFallback(row.nameI18n ?? null, row.name ?? '');
  const bioI18n = row.bio
    ? resolveBiTextWithFallback(row.bioI18n ?? null, row.bio ?? '')
    : (row.bioI18n ? resolveBiTextWithFallback(row.bioI18n, '') : null);
  const countryI18n = row.country
    ? resolveCountryBiTextWithFallback(row.countryI18n ?? null, row.country ?? '')
    : (row.countryI18n ? resolveCountryBiTextWithFallback(row.countryI18n, '') : null);
  const contributorInfo = contributorInfoFromRow(row);
  const statsInfo = statsInfoFromRow(row);
  const contributorUsernames = contributorInfo.usernames;
  const contributors = contributorInfo.users.map((user) => mapUserLite(user));
  const uploadedByUsername = contributorInfo.uploadedByUsername;
  const isContributor = isDJContributorByRow(row, viewerId);
  const canEdit = viewerRole === 'admin' || isContributor;
  const eventCount = Number(statsInfo.eventCount ?? 0);
  const setCount = Math.max(
    Number(row.setCount ?? 0),
    Number(row.setsCount ?? 0),
    Number(row.djSetCount ?? 0),
    Number(statsInfo.setCount ?? 0)
  );

  return {
    id: row.id,
    name: row.name,
    nameI18n: nameI18n ?? null,
    aliases: Array.isArray(row.aliases) ? row.aliases : [],
    genres: Array.isArray(row.genres) ? row.genres : [],
    slug: row.slug,
    bio: row.bio,
    bioI18n: bioI18n ?? null,
    avatarUrl: resolvedAvatarUrl,
    avatarOriginalUrl: resolvedAvatarUrl,
    avatarMediumUrl: buildOssAvatarVariantUrl(resolvedAvatarUrl, row.id, 'medium'),
    avatarSmallUrl: buildOssAvatarVariantUrl(resolvedAvatarUrl, row.id, 'small'),
    avatarSourceUrl: row.avatarSourceUrl ?? null,
    bannerUrl: row.bannerUrl,
    country: row.country,
    countryI18n: countryI18n ?? null,
    spotifyUrl: row.spotifyUrl ?? null,
    spotifyId: row.spotifyId,
    spotifyFollowers: row.spotifyFollowers ?? null,
    appleMusicId: row.appleMusicId,
    soundcloudUrl: row.soundcloudUrl,
    soundcloudId: row.soundcloudId ?? null,
    soundCloudId: row.soundcloudId ?? null,
    neteaseUrl: row.neteaseUrl ?? null,
    qqMusicUrl: row.qqMusicUrl ?? null,
    website: row.website ?? null,
    sourceWikipedia: row.sourceWikipedia ?? null,
    sourceWebsite: row.sourceWebsite ?? null,
    sourceSameAs: Array.isArray(row.sourceSameAs) ? row.sourceSameAs : [],
    trackCount: row.trackCount ?? null,
    playlistCount: row.playlistCount ?? null,
    soundCloudFollowers: row.soundCloudFollowers ?? null,
    soundCloudFavorites: row.soundCloudFavorites ?? null,
    instagramUrl: row.instagramUrl,
    facebookUrl: row.facebookUrl,
    twitterUrl: row.twitterUrl,
    youtubeUrl: row.youtubeUrl ?? null,
    isVerified: row.isVerified,
    followerCount: row.followerCount,
    eventCount,
    eventsCount: eventCount,
    upcomingShows: eventCount,
    setCount,
    setsCount: setCount,
    djSetCount: setCount,
    viewerWatchedCount: Math.max(0, Number(row.viewerWatchedCount ?? 0) || 0),
    honors: Array.isArray(row.honors) ? row.honors : [],
    sourceDataSource: row.sourceDataSource ?? null,
    contributors,
    contributorSummary: contributorInfo.summary,
    contributorUsernames,
    uploadedByUsername,
    isContributor,
    canEdit,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    isFollowing,
  };
};

const mapUserLite = (row: any) => {
  if (!row) return null;
  return {
    id: row.id,
    username: row.username,
    displayName: row.displayName || row.username,
    avatarUrl: row.avatarUrl || null,
  };
};

const buildContributorInfoFromEntries = (entries: ContributorRegistryEntry[]): ContributorInfo => ({
  userIds: entries.map((item) => item.id),
  usernames: entries
    .map((item) => item.username.trim())
    .filter(Boolean)
    .filter((value, index, list) => list.findIndex((item) => item.toLowerCase() === value.toLowerCase()) === index),
  users: entries.map((item) => ({
    id: item.id,
    username: item.username,
    displayName: item.displayName,
    avatarUrl: item.avatarUrl,
  })),
  uploadedByUsername: entries[0]?.username ?? null,
  entries,
  summary: buildContributorSummary(entries),
});

const buildLegacyEventOrganizerContributorInfo = (row: any): ContributorInfo => {
  const organizer = row?.organizer;
  if (!organizer?.id || !organizer?.username) {
    return emptyContributorInfo;
  }

  const createdAt = row?.createdAt instanceof Date ? row.createdAt : new Date(row?.createdAt ?? Date.now());
  const updatedAt = row?.updatedAt instanceof Date ? row.updatedAt : new Date(row?.updatedAt ?? createdAt);
  const entry: ContributorRegistryEntry = {
    id: organizer.id,
    username: organizer.username,
    displayName: organizer.displayName ?? organizer.username,
    avatarUrl: organizer.avatarUrl ?? null,
    entityId: String(row?.id ?? ''),
    role: 'creator',
    firstContributedAt: createdAt,
    lastContributedAt: updatedAt,
    contributionCount: 1,
    firstSubmissionId: null,
    lastSubmissionId: null,
    lastContributionSource: 'legacy_organizer_fallback',
    createdAt,
    updatedAt,
  };

  return buildContributorInfoFromEntries([entry]);
};

const eventContributorInfoFromRow = (row: any): ContributorInfo => {
  const info = contributorInfoFromRow(row);
  if (info.userIds.length > 0) {
    return info;
  }
  return buildLegacyEventOrganizerContributorInfo(row);
};

const normalizeContributionHistoryFilter = (value: unknown): ContributionHistoryFilter => {
  if (value === 'event' || value === 'dj') return value;
  return 'all';
};

const mapContributionHistoryItem = (item: {
  id: string;
  entityType: 'event' | 'dj';
  entityId: string;
  entityTitle: string | null;
  entityCoverImageUrl: string | null;
  role: 'creator' | 'editor';
  actionType: 'create' | 'edit';
  source: string;
  submissionId: string | null;
  occurredAt: Date;
  approvedAt: Date | null;
  versionAfter: number | null;
  changeSummary: string | null;
  metadata: Prisma.JsonValue | null;
  createdAt: Date;
}) => ({
  id: item.id,
  entity: {
    id: item.entityId,
    type: item.entityType,
    title: item.entityTitle,
    coverImageUrl: item.entityCoverImageUrl,
  },
  role: item.role,
  actionType: item.actionType,
  source: item.source,
  submissionId: item.submissionId,
  occurredAt: item.occurredAt,
  approvedAt: item.approvedAt,
  versionAfter: item.versionAfter,
  changeSummary: item.changeSummary,
  metadata: item.metadata,
  createdAt: item.createdAt,
});

type WikiFestivalLinkPayload = {
  title: string;
  icon: string;
  url: string;
};

const normalizeWikiFestivalText = (value: unknown): string => {
  if (typeof value !== 'string') return '';
  return value.trim();
};

const normalizeWikiFestivalInteger = (value: unknown): number | null => {
  if (value === null || value === undefined || value === '') return null;
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return null;
  return Math.trunc(parsed);
};

const normalizeWikiFestivalBiText = (value: unknown, fallback = ''): EventBiTextPayload | null =>
  normalizeEventBiText(value, fallback);

const pickWikiFestivalPrimaryText = (value: EventBiTextPayload | null, fallback = ''): string => {
  const zh = normalizeWikiFestivalText(value?.zh);
  const en = normalizeWikiFestivalText(value?.en);
  const fallbackText = normalizeWikiFestivalText(fallback);
  return zh || en || fallbackText;
};

const parseWikiFestivalLinks = (value: unknown): WikiFestivalLinkPayload[] => {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => {
      if (typeof item !== 'object' || item === null) return null;
      const title = normalizeWikiFestivalText((item as Record<string, unknown>).title);
      const icon = normalizeWikiFestivalText((item as Record<string, unknown>).icon);
      const url = normalizeWikiFestivalText((item as Record<string, unknown>).url);
      if (!title || !url) return null;
      return {
        title,
        icon: icon || 'link',
        url,
      } as WikiFestivalLinkPayload;
    })
    .filter((item): item is WikiFestivalLinkPayload => item !== null);
};

const mergeWikiFestivalLinks = (
  baseLinks: WikiFestivalLinkPayload[],
  fields: {
    officialWebsite?: string | null;
    facebookUrl?: string | null;
    instagramUrl?: string | null;
    twitterUrl?: string | null;
    youtubeUrl?: string | null;
    tiktokUrl?: string | null;
  }
): WikiFestivalLinkPayload[] => {
  const merged: WikiFestivalLinkPayload[] = Array.isArray(baseLinks) ? [...baseLinks] : [];
  const seen = new Set(
    merged
      .map((item) => normalizeWikiFestivalText(item.url).toLowerCase())
      .filter((item) => item.length > 0)
  );

  const push = (title: string, icon: string, url: string | null | undefined): void => {
    const normalizedUrl = normalizeWikiFestivalText(url);
    if (!normalizedUrl) return;
    const key = normalizedUrl.toLowerCase();
    if (seen.has(key)) return;
    seen.add(key);
    merged.push({ title, icon, url: normalizedUrl });
  };

  push('Official', 'globe', fields.officialWebsite);
  push('Facebook', 'f.square', fields.facebookUrl);
  push('Instagram', 'camera', fields.instagramUrl);
  push('X / Twitter', 'bird', fields.twitterUrl);
  push('YouTube', 'play.rectangle', fields.youtubeUrl);
  push('TikTok', 'music.note', fields.tiktokUrl);
  return merged;
};

const normalizeWikiFestivalManualLocationPayload = (
  value: unknown,
  cityI18n: EventBiTextPayload | null,
  countryI18n: EventBiTextPayload | null
): Record<string, unknown> | null => {
  const manualLocationRaw = normalizeEventManualLocationPayload(value ?? null);
  return mergeManualLocationFormattedWithBaseI18n(manualLocationRaw, cityI18n, countryI18n);
};

const parseWikiFestivalAliases = (value: unknown): string[] => {
  if (Array.isArray(value)) {
    return value
      .map((item) => normalizeWikiFestivalText(item))
      .filter((item) => item.length > 0);
  }
  if (typeof value === 'string') {
    return value
      .split(/[,\uFF0C\/\u3001]/g)
      .map((item) => item.trim())
      .filter((item) => item.length > 0);
  }
  return [];
};

const mapWikiFestival = (
  row: any,
  viewerId: string | null | undefined = null,
  viewerRole: string | null | undefined = null
) => {
  const contributors = Array.isArray(row?.contributors)
    ? row.contributors
        .map((item: any) => mapUserLite(item?.user ?? item))
        .filter((item: ReturnType<typeof mapUserLite>): item is NonNullable<ReturnType<typeof mapUserLite>> => Boolean(item))
    : [];
  const nameI18n = resolveBiTextWithFallback(row?.nameI18n ?? null, row?.name ?? '');
  const descriptionI18n = resolveBiTextWithFallback(row?.descriptionI18n ?? null, row?.introduction ?? '');
  const cityI18n = resolveBiTextWithFallback(row?.cityI18n ?? null, row?.city ?? '');
  const countryI18n = resolveCountryBiTextWithFallback(row?.countryI18n ?? null, row?.country ?? '');
  const frequencyI18n = resolveBiTextWithFallback(row?.frequencyI18n ?? null, row?.frequency ?? '');
  const manualLocation = normalizeWikiFestivalManualLocationPayload(
    row?.manualLocation ?? null,
    cityI18n,
    countryI18n
  );
  const locationFallback = manualLocation
    ? {
        lng: null,
        lat: null,
        addressI18n: (manualLocation as any).formattedAddressI18n ?? (manualLocation as any).detailAddressI18n ?? null,
        formattedAddressI18n: (manualLocation as any).formattedAddressI18n ?? (manualLocation as any).detailAddressI18n ?? null,
      }
    : null;
  const locationPoint = normalizeEventLocationPointPayload(row?.locationPoint ?? null, locationFallback);
  const links = mergeWikiFestivalLinks(parseWikiFestivalLinks(row?.links), {
    officialWebsite: row?.officialWebsite ?? null,
    facebookUrl: row?.facebookUrl ?? null,
    instagramUrl: row?.instagramUrl ?? null,
    twitterUrl: row?.twitterUrl ?? null,
    youtubeUrl: row?.youtubeUrl ?? null,
    tiktokUrl: row?.tiktokUrl ?? null,
  });
  const isContributor = !!viewerId && contributors.some((user: any) => user.id === viewerId);
  const canEdit = viewerRole === 'admin' || isContributor;
  const isFollowing = !!viewerId && Array.isArray(row?.followedByUserIds) && row.followedByUserIds.includes(viewerId);

  return {
    id: row.id,
    name: row.name,
    nameI18n: nameI18n ?? null,
    sourceRowId: row.sourceRowId ?? null,
    abbreviation: row.abbreviation ?? null,
    aliases: Array.isArray(row.aliases) ? row.aliases : [],
    country: row.country,
    countryI18n: countryI18n ?? null,
    city: row.city,
    cityI18n: cityI18n ?? null,
    foundedYear: row.foundedYear,
    frequency: row.frequency,
    frequencyI18n: frequencyI18n ?? null,
    tagline: row.tagline,
    introduction: row.introduction,
    descriptionI18n: descriptionI18n ?? null,
    manualLocation: manualLocation ?? null,
    locationPoint: locationPoint ?? null,
    officialWebsite: row.officialWebsite ?? null,
    facebookUrl: row.facebookUrl ?? null,
    instagramUrl: row.instagramUrl ?? null,
    twitterUrl: row.twitterUrl ?? null,
    youtubeUrl: row.youtubeUrl ?? null,
    tiktokUrl: row.tiktokUrl ?? null,
    avatarUrl: row.avatarUrl ?? null,
    backgroundUrl: row.backgroundUrl ?? null,
    imageAssets: Array.isArray(row.brandImageAssets)
      ? row.brandImageAssets
      : Array.isArray(row.imageAssets)
        ? row.imageAssets
        : null,
    links,
    revision: typeof row.revision === 'number' ? row.revision : 1,
    contributors,
    isFollowing,
    canEdit,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  };
};

const mapDJLiteForEvent = (dj: any) => dj
  ? {
      id: dj.id,
      name: dj.name,
      avatarUrl: dj.avatarUrl,
      avatarOriginalUrl: buildOssAvatarVariantUrl(dj.avatarUrl, dj.id, 'original'),
      avatarMediumUrl: buildOssAvatarVariantUrl(dj.avatarUrl, dj.id, 'medium'),
      avatarSmallUrl: buildOssAvatarVariantUrl(dj.avatarUrl, dj.id, 'small'),
      bannerUrl: dj.bannerUrl,
      country: dj.country,
      soundCloudFollowers: dj.soundCloudFollowers ?? null,
    }
  : null;

const mapEventLineupArtists = (canonicalArtistsRaw: any): any[] => {
  const canonicalArtists = Array.isArray(canonicalArtistsRaw) ? canonicalArtistsRaw : [];
  return canonicalArtists.map((artist: any) => {
    const uniqueMembers = Array.isArray(artist.members) ? dedupeCanonicalMembers(artist.members) : [];
    const memberDjs = uniqueMembers.map((member: any) => member.dj).filter(Boolean);
    const primaryDj = artist.primaryDj || memberDjs[0] || null;
    return {
      id: artist.id,
      eventId: artist.eventId,
      djId: artist.primaryDjId ?? primaryDj?.id ?? null,
      memberNames: uniqueMembers.map((member: any) => member.memberNameSnapshot).filter(Boolean),
      memberDjIds: uniqueMembers.map((member: any) => member.djId || null),
      djName: artist.displayName,
      displayName: artist.displayName,
      normalizedName: artist.normalizedName ?? null,
      actType: artist.actType ?? 'unknown',
      sortOrder: artist.billingOrder,
      billingOrder: artist.billingOrder,
      posterTier: artist.posterTier ?? null,
      sourceType: artist.sourceType ?? null,
      isTimetableOnly: Boolean(artist.isTimetableOnly),
      createdAt: artist.createdAt,
      updatedAt: artist.updatedAt,
      dj: mapDJLiteForEvent(primaryDj),
      djs: memberDjs.map(mapDJLiteForEvent).filter(Boolean),
      members: uniqueMembers.map((member: any) => ({
        id: member.id,
        eventArtistId: member.eventArtistId,
        djId: member.djId,
        memberNameSnapshot: member.memberNameSnapshot,
        memberOrder: member.memberOrder,
        role: member.role,
        createdAt: member.createdAt,
        dj: mapDJLiteForEvent(member.dj),
      })),
    };
  });
};

const mapEventTimetableSlots = (performancesRaw: any): any[] => {
  const canonicalPerformances = Array.isArray(performancesRaw) ? performancesRaw : [];
  return canonicalPerformances.map((performance: any) => {
    const artist = performance.eventArtist || {};
    const uniqueMembers = Array.isArray(artist.members) ? dedupeCanonicalMembers(artist.members) : [];
    const memberDjs = uniqueMembers.map((member: any) => member.dj).filter(Boolean);
    const primaryDj = artist.primaryDj || memberDjs[0] || null;
    const dj = mapDJLiteForEvent(primaryDj);
    const djs = memberDjs.map(mapDJLiteForEvent).filter(Boolean);
    return {
      id: performance.id,
      eventId: performance.eventId,
      lineupArtistId: performance.eventArtistId,
      eventArtistId: performance.eventArtistId,
      eventDayId: performance.eventDay?.eventDayId ?? null,
      weekIndex: typeof performance.weekIndex === 'number' ? performance.weekIndex : null,
      dayIndexInWeek: typeof performance.dayIndexInWeek === 'number' ? performance.dayIndexInWeek : null,
      overallDayIndex: typeof performance.overallDayIndex === 'number' ? performance.overallDayIndex : null,
      localDate: performance.localDate ?? performance.eventDay?.date ?? null,
      djId: artist.primaryDjId ?? primaryDj?.id ?? null,
      memberDjIds: uniqueMembers.map((member: any) => member.djId || null),
      djName: performance.displayNameSnapshot,
      djNameSnapshot: performance.displayNameSnapshot,
      festivalDayIndex: typeof performance.festivalDayIndex === 'number' ? performance.festivalDayIndex : null,
      stageName: performance.stage?.name ?? null,
      stageId: performance.stageId ?? null,
      sortOrder: performance.sortOrder,
      startTime: performance.startAt,
      endTime: performance.endAt,
      startAt: performance.startAt,
      endAt: performance.endAt,
      status: performance.status,
      sourceType: performance.sourceType,
      createdAt: performance.createdAt,
      updatedAt: performance.updatedAt,
      dj,
      djs,
    };
  });
};

const buildEventAddressPayload = (row: any) => {
  const latitude = toNumber(row.latitude);
  const longitude = toNumber(row.longitude);
  const locationFallback =
    latitude !== null && longitude !== null
      ? {
          provider: 'amap',
          sourceMode: 'legacy_coords',
          location: { lng: longitude, lat: latitude },
          nameI18n: row.city ?? row.name ?? '',
          addressI18n: '',
          formattedAddressI18n: '',
          city: row.city ?? '',
          countryCode: row.country ?? '',
        }
      : null;
  const cityI18n = normalizeEventBiText(row.cityI18n ?? null, row.city ?? '');
  const countryI18n = normalizeCountryBiText(row.countryI18n ?? null, row.country ?? '');
  const manualLocationRaw = normalizeEventManualLocationPayload(row.manualLocation ?? null);
  const manualLocation = mergeManualLocationFormattedWithBaseI18n(manualLocationRaw, cityI18n, countryI18n);
  const locationPoint = normalizeEventLocationPointPayload(row.locationPoint ?? null, locationFallback);

  return {
    latitude,
    longitude,
    cityI18n,
    countryI18n,
    manualLocation: manualLocation ?? null,
    locationPoint: locationPoint ?? null,
    activityAddress: resolveEventActivityAddressText({
      manualLocation: row.manualLocation ?? null,
    }),
    venueDisplayAddress: resolveEventVenueDisplayAddressText({
      manualLocation: row.manualLocation ?? null,
      locationPoint: row.locationPoint ?? null,
    }),
  };
};

const mapEventReference = (
  row: any,
  options?: {
    includeCoverImageUrl?: boolean;
    includeCreatedAt?: boolean;
  }
) => {
  const addressPayload = buildEventAddressPayload(row);

  return {
    id: row.id,
    name: row.name,
    nameI18n: row.nameI18n ?? null,
    cityI18n: addressPayload.cityI18n ?? null,
    countryI18n: addressPayload.countryI18n ?? null,
    manualLocation: addressPayload.manualLocation,
    locationPoint: addressPayload.locationPoint,
    activityAddress: addressPayload.activityAddress,
    venueDisplayAddress: addressPayload.venueDisplayAddress,
    city: row.city ?? null,
    country: row.country ?? null,
    ...(options?.includeCoverImageUrl ? { coverImageUrl: row.coverImageUrl ?? null } : {}),
    ...(row.startDate ? { startDate: row.startDate } : {}),
    ...(row.endDate ? { endDate: row.endDate } : {}),
    ...(options?.includeCreatedAt ? { createdAt: row.createdAt } : {}),
  };
};

const mapEvent = (
  row: any,
  complianceUser?: RegionalComplianceUser | null,
  viewerId: string | null | undefined = null,
  viewerRole: string | null | undefined = null
) => {
  const eventTimeZone = normalizeEventTimeZone(row.timeZone ?? row.timezone ?? DEFAULT_EVENT_TIME_ZONE);
  const {
    latitude,
    longitude,
    cityI18n,
    countryI18n,
    manualLocation,
    locationPoint,
    activityAddress,
    venueDisplayAddress,
  } = buildEventAddressPayload(row);
  const mappedCanonicalArtists = mapEventLineupArtists(row.canonicalArtists);
  const mappedCanonicalSlots = mapEventTimetableSlots(row.performances);
  const contributorInfo = eventContributorInfoFromRow(row);
  const contributors = contributorInfo.users.map((user) => mapUserLite(user)).filter(Boolean);
  const isContributor = !!viewerId && contributorInfo.userIds.includes(viewerId);
  const isOrganizer = !!viewerId && row?.organizer?.id === viewerId;
  const canEdit = viewerRole === 'admin' || isOrganizer;
  const resolvedEventTruth = resolveEventTruth({
    isCancelled: 'isCancelled' in row ? (row as { isCancelled?: boolean | null }).isCancelled : undefined,
    visibility: 'visibility' in row ? (row as { visibility?: string | null }).visibility : undefined,
  });

  return {
    id: row.id,
    favoriteId: row.favoriteId ?? null,
    isFavorited: Boolean(row.favoriteId),
    name: row.name,
    nameI18n: row.nameI18n ?? null,
    wikiFestivalId: row.wikiFestivalId ?? null,
    slug: row.slug,
    archiveFestivalId: row.archiveFestivalId ?? null,
    abbreviation: row.abbreviation ?? null,
    description: row.description,
    descriptionI18n: row.descriptionI18n ?? null,
    countryI18n: countryI18n ?? null,
    cityI18n: cityI18n ?? null,
    cardImageUrl: resolveEventCardImageUrl(row),
    coverImageUrl: row.coverImageUrl,
    lineupImageUrl: row.lineupImageUrl,
    imageAssets: row.imageAssets ?? null,
    referenceLinks: Array.isArray(row.referenceLinks) ? row.referenceLinks : [],
    socialLinks: row.socialLinks ?? null,
    sourceProvider: row.sourceProvider ?? null,
    sourceEventUrl: row.sourceEventUrl ?? null,
    eventType: row.eventType,
    organizerName: row.organizerName,
    city: row.city,
    country: row.country,
    manualLocation: manualLocation ?? null,
    locationPoint: locationPoint ?? null,
    activityAddress,
    venueDisplayAddress,
    latitude,
    longitude,
    startDate: row.startDate,
    endDate: row.endDate,
    schedule: {
      mode: row.scheduleMode ?? 'single_day',
      timeZone: eventTimeZone,
      dayRolloverHour: row.dayRolloverHour ?? 6,
    },
    weeks: Array.isArray(row.weeks)
      ? row.weeks.map((week: any) => ({
          id: week.id,
          weekIndex: week.weekIndex,
          label: week.label ?? null,
          startDate: storageDateToEventDate(week.startDate, eventTimeZone),
          endDate: storageDateToEventDate(week.endDate, eventTimeZone),
          sortOrder: week.sortOrder ?? week.weekIndex,
        }))
      : [],
    eventDays: Array.isArray(row.eventDays)
      ? row.eventDays.map((day: any) => ({
          id: day.id,
          eventDayId: day.eventDayId,
          weekIndex: day.weekIndex,
          dayIndexInWeek: day.dayIndexInWeek,
          overallDayIndex: day.overallDayIndex,
          label: day.label ?? null,
          weekday: day.weekday ?? null,
          date: storageDateToEventDate(day.date, eventTimeZone),
          sortOrder: day.sortOrder ?? day.overallDayIndex,
        }))
      : [],
    timeZone: eventTimeZone,
    startTime: normalizeEventClockTime(row.startTime, EVENT_DEFAULT_START_TIME),
    endTime: normalizeEventClockTime(row.endTime, EVENT_DEFAULT_END_TIME),
    dayRolloverHour: row.dayRolloverHour ?? 6,
    stageOrder: Array.isArray(row.stages) ? row.stages.map((stage: any) => stage.name).filter(Boolean) : [],
    ticketUrl: regionalCompliance.shouldHideLateNightTicketLink(complianceUser, row.startDate) ? null : row.ticketUrl,
    ticketPriceMin: toNumber(row.ticketPriceMin),
    ticketPriceMax: toNumber(row.ticketPriceMax),
    ticketCurrency: row.ticketCurrency,
    ticketNotes: row.ticketNotes,
    officialWebsite: row.officialWebsite,
    status: deriveEventStatus(new Date(row.startDate), new Date(row.endDate), {
      isCancelled: resolvedEventTruth.isCancelled,
      visibility: resolvedEventTruth.visibility,
    }),
    isVerified: row.isVerified,
    revision: typeof row.revision === 'number' ? row.revision : 1,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    organizer: mapUserLite(row.organizer),
    contributors,
    contributorSummary: contributorInfo.summary,
    isContributor,
    canEdit,
    wikiFestival: row.wikiFestival
      ? {
          id: row.wikiFestival.id,
          name: row.wikiFestival.name,
          nameI18n: row.wikiFestival.nameI18n ?? null,
          abbreviation: row.wikiFestival.abbreviation ?? null,
          aliases: row.wikiFestival.aliases ?? [],
          country: row.wikiFestival.country,
          countryI18n: row.wikiFestival.countryI18n ?? null,
          city: row.wikiFestival.city,
          cityI18n: row.wikiFestival.cityI18n ?? null,
          avatarUrl: row.wikiFestival.avatarUrl ?? null,
          backgroundUrl: row.wikiFestival.backgroundUrl ?? null,
        }
      : null,
    ticketTiers: Array.isArray(row.ticketTiers)
      ? row.ticketTiers.map((tier: any) => ({
          id: tier.id,
          name: tier.name,
          price: toNumber(tier.price),
          currency: tier.currency,
          sortOrder: tier.sortOrder,
        }))
      : [],
    lineupArtists: mappedCanonicalArtists,
    timetableSlots: mappedCanonicalSlots.map((slot: any) => ({
      id: slot.id,
      eventId: slot.eventId,
      lineupArtistId: slot.lineupArtistId ?? null,
      eventDayId: slot.eventDayId ?? null,
      weekIndex: slot.weekIndex ?? null,
      dayIndexInWeek: slot.dayIndexInWeek ?? null,
      overallDayIndex: slot.overallDayIndex ?? null,
      localDate: slot.localDate ? storageDateToEventDate(slot.localDate, eventTimeZone) : null,
      djId: slot.djId,
      memberDjIds: Array.isArray(slot.memberDjIds) ? slot.memberDjIds : (slot.djId ? [slot.djId] : []),
      djName: slot.djName,
      djNameSnapshot: slot.djNameSnapshot ?? slot.djName,
      festivalDayIndex: typeof slot.festivalDayIndex === 'number' ? slot.festivalDayIndex : null,
      stageName: slot.stageName,
      sortOrder: slot.sortOrder,
      startTime: slot.startTime,
      endTime: slot.endTime,
      dj: mapDJLiteForEvent(slot.dj),
      djs: Array.isArray(slot.djs) ? slot.djs.map(mapDJLiteForEvent).filter(Boolean) : [],
    })),
    lineupSlots: mappedCanonicalSlots
      .map((slot: any) => ({
          id: slot.id,
          eventId: slot.eventId,
          lineupArtistId: slot.lineupArtistId ?? null,
          eventDayId: slot.eventDayId ?? null,
          weekIndex: slot.weekIndex ?? null,
          dayIndexInWeek: slot.dayIndexInWeek ?? null,
          overallDayIndex: slot.overallDayIndex ?? null,
          localDate: slot.localDate ? storageDateToEventDate(slot.localDate, eventTimeZone) : null,
          djId: slot.djId,
          memberDjIds: Array.isArray(slot.memberDjIds) ? slot.memberDjIds : (slot.djId ? [slot.djId] : []),
          djs: Array.isArray(slot.djs)
            ? slot.djs.map((dj: any) => ({
                id: dj.id,
                name: dj.name,
                avatarUrl: dj.avatarUrl,
                avatarOriginalUrl: buildOssAvatarVariantUrl(dj.avatarUrl, dj.id, 'original'),
                avatarMediumUrl: buildOssAvatarVariantUrl(dj.avatarUrl, dj.id, 'medium'),
                avatarSmallUrl: buildOssAvatarVariantUrl(dj.avatarUrl, dj.id, 'small'),
                bannerUrl: dj.bannerUrl,
                country: dj.country,
                soundCloudFollowers: dj.soundCloudFollowers ?? null,
              }))
            : [],
          djName: slot.djName,
          festivalDayIndex: typeof slot.festivalDayIndex === 'number' ? slot.festivalDayIndex : null,
          stageName: slot.stageName,
          sortOrder: slot.sortOrder,
          startTime: slot.startTime,
          endTime: slot.endTime,
          dj: mapDJLiteForEvent(slot.dj),
        }))
  };
};

const mapEventRecommendationCard = (row: any, complianceUser?: RegionalComplianceUser | null) => {
  const event = mapEvent(
    {
      ...row,
      description: null,
      descriptionI18n: null,
      referenceLinks: [],
      socialLinks: null,
      ticketTiers: [],
      lineupArtists: [],
      timetableSlots: [],
      lineupSlots: [],
    },
    complianceUser
  );
  return {
    ...event,
    imageAssets: null,
    ticketTiers: [],
    lineupArtists: [],
    timetableSlots: [],
    lineupSlots: [],
  };
};

const mapEventListCard = (row: any, complianceUser?: RegionalComplianceUser | null) =>
  {
    const event = mapEvent(
      {
      ...row,
      referenceLinks: [],
      socialLinks: null,
      ticketTiers: [],
      stages: [],
      performances: [],
      canonicalArtists: [],
      lineupArtists: [],
      timetableSlots: [],
      lineupSlots: [],
      },
      complianceUser
    );
    return {
      ...event,
      imageAssets: null,
      lineupArtistCount: Number(row?._count?.canonicalArtists || 0),
      timetableSlotCount: Number(row?._count?.performances || 0),
    };
  };

const resolveEventFavoriteIds = async (userId: string | undefined, eventIds: string[]): Promise<Map<string, string>> => {
  if (!userId || eventIds.length === 0) {
    return new Map();
  }

  const rows = await prisma.userEntityFollow.findMany({
    where: {
      userId,
      relationType: USER_ENTITY_RELATION_FAVORITE,
      targetType: USER_ENTITY_TARGET_EVENT,
      targetId: { in: Array.from(new Set(eventIds)) },
    },
    select: {
      id: true,
      targetId: true,
    },
  });

  return new Map(rows.map((row) => [row.targetId, row.id]));
};

const attachEventFavoriteState = <T extends { id: string }>(rows: T[], favoriteIdsByEventId: Map<string, string>): Array<T & { favoriteId: string | null }> =>
  rows.map((row) => ({
    ...row,
    favoriteId: favoriteIdsByEventId.get(row.id) ?? null,
  }));

const mapTrack = (track: any) => ({
  id: track.id,
  position: track.position,
  startTime: track.startTime,
  endTime: track.endTime,
  title: track.title,
  artist: track.artist,
  status: track.status,
  spotifyUrl: track.spotifyUrl,
  spotifyId: track.spotifyId,
  spotifyUri: track.spotifyUri,
  neteaseUrl: track.neteaseUrl,
  neteaseId: track.neteaseId,
  createdAt: track.createdAt,
  updatedAt: track.updatedAt,
});

const mapTracklistSummary = (row: any) => ({
  id: row.id,
  setId: row.setId,
  title: row.title,
  isDefault: row.isDefault,
  createdAt: row.createdAt,
  updatedAt: row.updatedAt,
  contributor: row.contributor || null,
  trackCount: row.trackCount || 0,
});

const mapTracklistDetail = (row: any) => ({
  id: row.id,
  setId: row.setId,
  title: row.title,
  isDefault: row.isDefault,
  createdAt: row.createdAt,
  updatedAt: row.updatedAt,
  contributor: row.contributor || null,
  tracks: Array.isArray(row.tracks) ? row.tracks.map(mapTrack) : [],
});

const mapDJSet = (row: any) => ({
  id: row.id,
  djId: row.djId,
  title: row.title,
  slug: row.slug,
  description: row.description,
  thumbnailUrl: row.thumbnailUrl,
  videoUrl: row.videoUrl,
  videoAuthorName: row.videoAuthorName,
  platform: row.platform,
  videoId: row.videoId,
  duration: row.duration,
  recordedAt: row.recordedAt,
  venue: row.venue,
  eventId: row.eventId,
  eventName: row.eventName,
  viewCount: row.viewCount,
  likeCount: row.likeCount,
  isVerified: row.isVerified,
  createdAt: row.createdAt,
  updatedAt: row.updatedAt,
  uploadedById: row.uploadedById,
  coDjIds: Array.isArray(row.coDjIds) ? row.coDjIds : [],
  customDjNames: row.customDjNames || [],
  dj: row.dj
    ? {
        id: row.dj.id,
        name: row.dj.name,
        slug: row.dj.slug,
        avatarUrl: row.dj.avatarUrl,
        avatarOriginalUrl: buildOssAvatarVariantUrl(row.dj.avatarUrl, row.dj.id, 'original'),
        avatarMediumUrl: buildOssAvatarVariantUrl(row.dj.avatarUrl, row.dj.id, 'medium'),
        avatarSmallUrl: buildOssAvatarVariantUrl(row.dj.avatarUrl, row.dj.id, 'small'),
        bannerUrl: row.dj.bannerUrl,
        country: row.dj.country,
      }
    : null,
  lineupDjs: Array.isArray(row.lineupDjs)
    ? row.lineupDjs.map((dj: any) => ({
        id: dj.id,
        name: dj.name,
        avatarUrl: dj.avatarUrl,
        avatarOriginalUrl: buildOssAvatarVariantUrl(dj.avatarUrl, dj.id, 'original'),
        avatarMediumUrl: buildOssAvatarVariantUrl(dj.avatarUrl, dj.id, 'medium'),
        avatarSmallUrl: buildOssAvatarVariantUrl(dj.avatarUrl, dj.id, 'small'),
      }))
    : [],
  tracks: Array.isArray(row.tracks) ? row.tracks.map(mapTrack) : [],
  trackCount: Array.isArray(row.tracks) ? row.tracks.length : 0,
  uploader: mapUserLite(row.uploader),
  videoContributor: row.videoContributor || null,
  tracklistContributor: row.tracklistContributor || null,
});

const mapRatingComment = (row: any) => ({
  id: row.id,
  unitId: row.unitId,
  userId: row.userId,
  score: row.score,
  content: row.content,
  createdAt: row.createdAt,
  updatedAt: row.updatedAt,
  user: mapUserLite(row.user),
});

const resolveRatingSummary = (comments: Array<{ score: number }>): { rating: number; ratingCount: number } => {
  const scores = comments.map((item) => item.score).filter((value) => typeof value === 'number' && Number.isFinite(value));
  if (!scores.length) {
    return { rating: 0, ratingCount: 0 };
  }
  const total = scores.reduce((sum, value) => sum + value, 0);
  return {
    rating: total / scores.length,
    ratingCount: scores.length,
  };
};

const mapRatingUnit = (row: any, includeComments = false) => {
  const scoreRows: Array<{ score: number }> = Array.isArray(row.comments)
    ? row.comments
        .filter((item: any) => typeof item === 'object' && item !== null && typeof item.score === 'number')
        .map((item: any) => ({ score: item.score }))
    : [];
  const summary = resolveRatingSummary(scoreRows);
  const derivedDjIds = Array.isArray(row.djBindings)
    ? row.djBindings
        .map((binding: any) => String(binding?.djId || '').trim())
        .filter(Boolean)
    : Array.isArray(row.linkedDJs)
      ? row.linkedDJs
          .map((dj: any) => String(dj?.id || '').trim())
          .filter(Boolean)
      : [];

  return {
    id: row.id,
    eventId: row.eventId,
    djId: row.djId ?? null,
    djIds: Array.from(new Set(derivedDjIds)),
    name: row.name,
    description: row.description,
    imageUrl: row.imageUrl,
    linkedDJs: Array.isArray(row.linkedDJs)
      ? row.linkedDJs.map((dj: any) => ({
          id: dj.id,
          name: dj.name,
          avatarUrl: dj.avatarUrl || null,
          bannerUrl: dj.bannerUrl || null,
          country: dj.country || null,
        }))
      : [],
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    rating: summary.rating,
    ratingCount: summary.ratingCount,
    comments: includeComments && Array.isArray(row.comments) ? row.comments.map(mapRatingComment) : [],
    event: row.event
      ? {
          id: row.event.id,
          name: row.event.name,
          description: row.event.description ?? null,
          imageUrl: row.event.imageUrl ?? null,
          ...(row.event.manualLocation || row.event.locationPoint || row.event.city || row.event.country
            ? mapEventReference(row.event, { includeCoverImageUrl: false })
            : {}),
        }
      : undefined,
    createdBy: mapUserLite(row.createdBy),
  };
};

const mapRatingEvent = (row: any) => ({
  id: row.id,
  name: row.name,
  description: row.description,
  imageUrl: row.imageUrl,
  sourceEventId: row.sourceEventId ?? null,
  createdAt: row.createdAt,
  updatedAt: row.updatedAt,
  createdBy: mapUserLite(row.createdBy),
  units: Array.isArray(row.units) ? row.units.map((unit: any) => mapRatingUnit(unit)) : [],
});

const parseActPerformerNames = (rawName: string): string[] => {
  const trimmed = rawName.trim();
  if (!trimmed) return [];
  const separated = trimmed
    .replace(/\s*[bB]\s*[23]\s*[bB]\s*/g, '|')
    .split('|')
    .map((item) => item.trim())
    .filter(Boolean);
  return separated.length > 0 ? separated : [trimmed];
};

const formatHourMinute = (value: Date): string => {
  const hours = String(value.getHours()).padStart(2, '0');
  const minutes = String(value.getMinutes()).padStart(2, '0');
  return `${hours}:${minutes}`;
};

const buildRatingUnitDescriptionFromLineupSlot = (slot: {
  stageName?: string | null;
  startTime: Date;
  endTime: Date;
}): string => {
  const stageName = typeof slot.stageName === 'string' ? slot.stageName.trim() : '';
  const timeRange = `${formatHourMinute(slot.startTime)}-${formatHourMinute(slot.endTime)}`;
  return stageName ? `${stageName} · ${timeRange}` : timeRange;
};

const attachLinkedDJsToRatingUnits = async (units: any[]): Promise<any[]> => {
  if (!Array.isArray(units) || units.length === 0) return [];

  const idsByUnitId = new Map<string, string[]>();
  const allDjIds = new Set<string>();
  const missingBindingUnitIds: string[] = [];
  for (const unit of units) {
    const ids: string[] = Array.isArray(unit?.djBindings)
      ? unit.djBindings
          .map((binding: any) => String(binding?.djId || '').trim())
          .filter(Boolean)
      : [];
    if (ids.length === 0) {
      missingBindingUnitIds.push(unit.id);
    }
    const uniqueIds: string[] = Array.from(new Set(ids));
    idsByUnitId.set(unit.id, uniqueIds);
    for (const id of uniqueIds) {
      allDjIds.add(id);
    }
  }

  if (missingBindingUnitIds.length > 0) {
    const bindingRows = await prisma.ratingUnitDJBinding.findMany({
      where: {
        unitId: { in: missingBindingUnitIds },
      },
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
      select: {
        unitId: true,
        djId: true,
      },
    });
    for (const unitId of missingBindingUnitIds) {
      const ids = bindingRows
        .filter((row) => row.unitId === unitId)
        .map((row) => row.djId)
        .filter(Boolean);
      if (ids.length === 0) continue;
      idsByUnitId.set(unitId, Array.from(new Set(ids)));
      for (const id of ids) {
        allDjIds.add(id);
      }
    }
  }

  const djIds = Array.from(allDjIds);
  if (djIds.length === 0) {
    return units.map((unit) => ({ ...unit, linkedDJs: [] }));
  }

  const matchedDJs = await prisma.dJ.findMany({
    where: {
      id: { in: djIds },
    },
    select: {
      id: true,
      name: true,
      avatarUrl: true,
      bannerUrl: true,
      country: true,
    },
  });

  const djById = new Map<string, any>();
  for (const dj of matchedDJs) {
    djById.set(dj.id, dj);
  }

  return units.map((unit) => {
    const ids = idsByUnitId.get(unit.id) || [];
    const linkedDJs = ids
      .map((id) => djById.get(id))
      .filter(Boolean);
    return {
      ...unit,
      linkedDJs,
    };
  });
};

const normalizeRatingUnitDjIdsFromBody = async (body: Record<string, unknown>): Promise<{ djId: string | null; djIds: string[] }> => {
  const rawPrimary = typeof body.djId === 'string' ? body.djId.trim() : '';
  const rawIds = Array.isArray(body.djIds)
    ? body.djIds
        .map((id) => (typeof id === 'string' ? id.trim() : ''))
        .filter(Boolean)
    : [];
  const djIds = Array.from(new Set([...rawIds, ...(rawPrimary ? [rawPrimary] : [])])).filter(Boolean);
  if (djIds.length === 0) {
    return { djId: null, djIds: [] };
  }

  const existing = await prisma.dJ.findMany({
    where: { id: { in: djIds } },
    select: { id: true },
  });
  const existingIds = new Set(existing.map((dj) => dj.id));
  const missingId = djIds.find((id) => !existingIds.has(id));
  if (missingId) {
    throw new Error(`DJ not found: ${missingId}`);
  }

  return { djId: rawPrimary || djIds[0] || null, djIds };
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

type RankingEntityType = 'dj' | 'festival';

type RankingBoardRecord = {
  id: string;
  title: string;
  subtitle: string;
  description: string;
  coverImageUrl: string | null;
  entityType: RankingEntityType;
  years: number[];
  createdAt: string;
  updatedAt: string;
};

type RankingEntryRecord = {
  rank: number;
  name: string;
  entityId?: string | null;
};

type RankingYearRecord = {
  boardId: string;
  year: number;
  source?: string;
  updatedAt: string;
  entries: RankingEntryRecord[];
};

type RankingMatchCandidate = {
  id: string;
  name: string;
  subtitle?: string | null;
  imageUrl?: string | null;
};

type RankingAutoMatchStatus = 'already_bound' | 'matched' | 'ambiguous' | 'unmatched';

type RankingAutoMatchPreviewItem = {
  rank: number;
  name: string;
  currentEntityId: string | null;
  status: RankingAutoMatchStatus;
  current?: RankingMatchCandidate | null;
  suggested?: RankingMatchCandidate | null;
  candidates: RankingMatchCandidate[];
};

type RankingAutoMatchPreview = {
  boardId: string;
  year: number;
  entityType: RankingEntityType;
  total: number;
  alreadyBoundCount: number;
  matchedCount: number;
  ambiguousCount: number;
  unmatchedCount: number;
  items: RankingAutoMatchPreviewItem[];
};

const sanitizeRankingBoardId = (value: string): string => {
  const normalized = String(value || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9_-]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .replace(/^_+|_+$/g, '');
  return normalized || `ranking-${Date.now()}`;
};

const normalizeRankingYears = (value: unknown): number[] => {
  if (!Array.isArray(value)) return [];
  return Array.from(
    new Set(
      value
        .map((item) => Number(item))
        .filter((item) => Number.isFinite(item))
        .map((item) => Math.max(1900, Math.min(2200, Math.floor(item))))
    )
  ).sort((a, b) => a - b);
};

const parseRankingEntries = (value: unknown): RankingEntryRecord[] => {
  if (!Array.isArray(value)) return [];
  const rows = value
    .map((item) => {
      if (!item || typeof item !== 'object' || Array.isArray(item)) return null;
      const row = item as Record<string, unknown>;
      const rank = Number(row.rank);
      const name = String(row.name || '').trim();
      if (!Number.isFinite(rank) || rank <= 0 || !name) return null;
      const entityIdRaw = String(row.entityId || '').trim();
      const entityId = entityIdRaw.length > 0 ? entityIdRaw : null;
      return {
        rank: Math.floor(rank),
        name,
        ...(entityId ? { entityId } : {}),
      } as RankingEntryRecord;
    })
    .filter((item): item is RankingEntryRecord => item !== null);

  const deduped = new Map<number, RankingEntryRecord>();
  for (const item of rows) {
    deduped.set(item.rank, item);
  }
  return Array.from(deduped.values()).sort((a, b) => a.rank - b.rank);
};

const normalizeRankingBoardRow = (row: {
  id: string;
  title: string;
  subtitle: string;
  description: string;
  coverImageUrl: string | null;
  entityType: string;
  createdAt: Date;
  updatedAt: Date;
  years?: Array<{ year: number }> | null;
}): RankingBoardRecord => ({
  id: row.id,
  title: row.title,
  subtitle: row.subtitle || '',
  description: row.description || '',
  coverImageUrl: row.coverImageUrl || null,
  entityType: row.entityType === 'festival' ? 'festival' : 'dj',
  years: Array.isArray(row.years) ? row.years.map((item) => item.year).sort((a, b) => a - b) : [],
  createdAt: row.createdAt.toISOString(),
  updatedAt: row.updatedAt.toISOString(),
});

const loadRankingBoardsFromDB = async (): Promise<RankingBoardRecord[]> => {
  const boards = await prisma.rankingBoard.findMany({
    include: {
      years: {
        select: { year: true },
      },
    },
    orderBy: {
      title: 'asc',
    },
  });
  return boards.map(normalizeRankingBoardRow);
};

const loadRankingBoardById = async (boardId: string): Promise<RankingBoardRecord | null> => {
  const row = await prisma.rankingBoard.findUnique({
    where: { id: sanitizeRankingBoardId(boardId) },
    include: {
      years: {
        select: { year: true },
      },
    },
  });
  return row ? normalizeRankingBoardRow(row) : null;
};

const loadRankingYearData = async (boardId: string, year: number): Promise<RankingYearRecord | null> => {
  const row = await prisma.rankingYear.findUnique({
    where: {
      boardId_year: {
        boardId: sanitizeRankingBoardId(boardId),
        year: Math.floor(year),
      },
    },
    include: {
      entries: {
        orderBy: { rank: 'asc' },
      },
    },
  });
  if (!row) return null;
  return {
    boardId: sanitizeRankingBoardId(boardId),
    year: row.year,
    source: row.source || undefined,
    updatedAt: row.updatedAt.toISOString(),
    entries: row.entries.map((entry) => ({
      rank: entry.rank,
      name: entry.name,
      entityId: entry.entityId || null,
    })),
  };
};

const collectAffectedDJIdsFromEntries = async (entries: RankingEntryRecord[]): Promise<string[]> => {
  const directIds = entries
    .map((entry) => String(entry.entityId || '').trim())
    .filter(Boolean);
  const unmatchedNames = entries
    .filter((entry) => !entry.entityId)
    .map((entry) => entry.name)
    .filter(Boolean);
  if (unmatchedNames.length === 0) {
    return Array.from(new Set(directIds));
  }

  const djs = await prisma.dJ.findMany({
    where: {
      OR: [
        { name: { in: unmatchedNames } },
        { aliases: { hasSome: unmatchedNames } },
      ],
    },
    select: {
      id: true,
      name: true,
      aliases: true,
    },
  });
  const matchedIds = new Set<string>(directIds);
  const normalizedLookup = new Map<string, string>();
  for (const dj of djs) {
    normalizedLookup.set(normalizeName(dj.name), dj.id);
    for (const alias of Array.isArray(dj.aliases) ? dj.aliases : []) {
      normalizedLookup.set(normalizeName(alias), dj.id);
    }
  }
  for (const name of unmatchedNames) {
    const matchedId = normalizedLookup.get(normalizeName(name));
    if (matchedId) matchedIds.add(matchedId);
  }
  return Array.from(matchedIds);
};

const buildDJHonorsForDJ = async (djId: string): Promise<Record<string, unknown>[]> => {
  const rows = await prisma.rankingEntry.findMany({
    where: {
      entityId: djId,
      rankingYear: {
        board: {
          entityType: 'dj',
        },
      },
    },
    include: {
      rankingYear: {
        include: {
          board: true,
        },
      },
    },
    orderBy: [
      { rankingYear: { year: 'desc' } },
      { rank: 'asc' },
    ],
  });

  return rows.map((row) => {
    const board = row.rankingYear.board;
    const subtitle = board.subtitle?.trim()
      ? `${row.rankingYear.year} · ${board.subtitle.trim()}`
      : `${row.rankingYear.year} Ranking`;
    return {
      id: `ranking-${board.id}-${row.rankingYear.year}-${row.rank}`,
      category: 'ranking',
      title: board.title,
      subtitle,
      source: board.id,
      year: row.rankingYear.year,
      rank: row.rank,
      url: null,
    };
  });
};

const syncDJHonorsForDJIds = async (djIds: string[]): Promise<void> => {
  const ids = Array.from(new Set(djIds.map((item) => String(item || '').trim()).filter(Boolean)));
  if (ids.length === 0) return;
  const updates = await Promise.all(ids.map(async (djId) => ({
    djId,
    honors: await buildDJHonorsForDJ(djId),
  })));
  await prisma.$transaction(
    updates.map((item) => prisma.dJ.update({
      where: { id: item.djId },
      data: { honors: item.honors as Prisma.InputJsonValue },
    }))
  );
};

const saveRankingBoard = async (board: RankingBoardRecord): Promise<RankingBoardRecord> => {
  const saved = await prisma.rankingBoard.upsert({
    where: { id: sanitizeRankingBoardId(board.id) },
    update: {
      title: board.title,
      subtitle: board.subtitle,
      description: board.description,
      coverImageUrl: board.coverImageUrl,
      entityType: board.entityType === 'festival' ? 'festival' : 'dj',
      updatedAt: new Date(),
    },
    create: {
      id: sanitizeRankingBoardId(board.id),
      title: board.title,
      subtitle: board.subtitle,
      description: board.description,
      coverImageUrl: board.coverImageUrl,
      entityType: board.entityType === 'festival' ? 'festival' : 'dj',
      createdAt: new Date(board.createdAt || new Date().toISOString()),
      updatedAt: new Date(board.updatedAt || new Date().toISOString()),
    },
    include: {
      years: {
        select: { year: true },
      },
    },
  });
  return normalizeRankingBoardRow(saved);
};

const saveRankingYearData = async (
  boardId: string,
  year: number,
  entries: RankingEntryRecord[],
  source = 'manual'
): Promise<RankingYearRecord> => {
  const normalizedEntries = parseRankingEntries(entries);
  const normalizedBoardId = sanitizeRankingBoardId(boardId);
  const savedYear = await prisma.$transaction(async (tx) => {
    const row = await tx.rankingYear.upsert({
      where: {
        boardId_year: {
          boardId: normalizedBoardId,
          year: Math.floor(year),
        },
      },
      update: {
        source,
        updatedAt: new Date(),
      },
      create: {
        boardId: normalizedBoardId,
        year: Math.floor(year),
        source,
        updatedAt: new Date(),
      },
    });
    await tx.rankingEntry.deleteMany({
      where: { rankingYearId: row.id },
    });
    if (normalizedEntries.length > 0) {
      await tx.rankingEntry.createMany({
        data: normalizedEntries.map((entry) => ({
          rankingYearId: row.id,
          rank: entry.rank,
          name: entry.name,
          entityId: entry.entityId || null,
        })),
      });
    }
    return tx.rankingYear.findUniqueOrThrow({
      where: { id: row.id },
      include: {
        entries: {
          orderBy: { rank: 'asc' },
        },
      },
    });
  });

  return {
    boardId: normalizedBoardId,
    year: savedYear.year,
    source: savedYear.source || undefined,
    updatedAt: savedYear.updatedAt.toISOString(),
    entries: savedYear.entries.map((entry) => ({
      rank: entry.rank,
      name: entry.name,
      entityId: entry.entityId || null,
    })),
  };
};

const buildRankingAutoMatchPreview = async (
  board: RankingBoardRecord,
  yearData: RankingYearRecord
): Promise<RankingAutoMatchPreview> => {
  if (board.entityType === 'festival') {
    const festivals = await prisma.wikiFestival.findMany({
      where: { isActive: true },
      select: {
        id: true,
        name: true,
        nameI18n: true,
        aliases: true,
        avatarUrl: true,
        backgroundUrl: true,
        country: true,
        city: true,
        tagline: true,
      },
    });

    const byId = new Map<string, RankingMatchCandidate>();
    const lookup = new Map<string, RankingMatchCandidate[]>();
    const addLookup = (key: string, candidate: RankingMatchCandidate) => {
      if (!key) return;
      const current = lookup.get(key) ?? [];
      if (!current.some((item) => item.id === candidate.id)) current.push(candidate);
      lookup.set(key, current);
    };

    for (const festival of festivals) {
      const candidate: RankingMatchCandidate = {
        id: festival.id,
        name: festival.name,
        subtitle: [festival.city, festival.country].filter(Boolean).join(', ') || festival.tagline || null,
        imageUrl: festival.avatarUrl || festival.backgroundUrl || null,
      };
      byId.set(candidate.id, candidate);
      addLookup(normalizeName(festival.name), candidate);
      const nameI18n = resolveBiTextWithFallback(festival.nameI18n ?? null, festival.name ?? '');
      if (nameI18n?.zh) addLookup(normalizeName(nameI18n.zh), candidate);
      if (nameI18n?.en) addLookup(normalizeName(nameI18n.en), candidate);
      for (const alias of Array.isArray(festival.aliases) ? festival.aliases : []) {
        addLookup(normalizeName(alias), candidate);
      }
    }

    const items = yearData.entries.map<RankingAutoMatchPreviewItem>((entry) => {
      const current = entry.entityId ? byId.get(entry.entityId) ?? null : null;
      if (current) {
        return {
          rank: entry.rank,
          name: entry.name,
          currentEntityId: entry.entityId || null,
          status: 'already_bound',
          current,
          suggested: current,
          candidates: [current],
        };
      }
      const candidates = lookup.get(normalizeName(entry.name)) ?? [];
      if (candidates.length === 1) {
        return {
          rank: entry.rank,
          name: entry.name,
          currentEntityId: entry.entityId || null,
          status: 'matched',
          current: null,
          suggested: candidates[0],
          candidates,
        };
      }
      if (candidates.length > 1) {
        return {
          rank: entry.rank,
          name: entry.name,
          currentEntityId: entry.entityId || null,
          status: 'ambiguous',
          current: null,
          suggested: null,
          candidates,
        };
      }
      return {
        rank: entry.rank,
        name: entry.name,
        currentEntityId: entry.entityId || null,
        status: 'unmatched',
        current: null,
        suggested: null,
        candidates: [],
      };
    });

    return {
      boardId: board.id,
      year: yearData.year,
      entityType: board.entityType,
      total: items.length,
      alreadyBoundCount: items.filter((item) => item.status === 'already_bound').length,
      matchedCount: items.filter((item) => item.status === 'matched').length,
      ambiguousCount: items.filter((item) => item.status === 'ambiguous').length,
      unmatchedCount: items.filter((item) => item.status === 'unmatched').length,
      items,
    };
  }

  const djs = await prisma.dJ.findMany({
    select: {
      id: true,
      name: true,
      slug: true,
      avatarUrl: true,
      bannerUrl: true,
      country: true,
      aliases: true,
    },
  });
  const byId = new Map<string, RankingMatchCandidate>();
  const lookup = new Map<string, RankingMatchCandidate[]>();
  const addLookup = (key: string, candidate: RankingMatchCandidate) => {
    if (!key) return;
    const current = lookup.get(key) ?? [];
    if (!current.some((item) => item.id === candidate.id)) current.push(candidate);
    lookup.set(key, current);
  };

  for (const dj of djs) {
    const candidate: RankingMatchCandidate = {
      id: dj.id,
      name: dj.name,
      subtitle: dj.country || dj.slug || null,
      imageUrl: dj.avatarUrl || dj.bannerUrl || null,
    };
    byId.set(candidate.id, candidate);
    addLookup(normalizeName(dj.name), candidate);
    for (const alias of Array.isArray(dj.aliases) ? dj.aliases : []) {
      addLookup(normalizeName(alias), candidate);
    }
  }

  const items = yearData.entries.map<RankingAutoMatchPreviewItem>((entry) => {
    const current = entry.entityId ? byId.get(entry.entityId) ?? null : null;
    if (current) {
      return {
        rank: entry.rank,
        name: entry.name,
        currentEntityId: entry.entityId || null,
        status: 'already_bound',
        current,
        suggested: current,
        candidates: [current],
      };
    }
    const candidates = lookup.get(normalizeName(entry.name)) ?? [];
    if (candidates.length === 1) {
      return {
        rank: entry.rank,
        name: entry.name,
        currentEntityId: entry.entityId || null,
        status: 'matched',
        current: null,
        suggested: candidates[0],
        candidates,
      };
    }
    if (candidates.length > 1) {
      return {
        rank: entry.rank,
        name: entry.name,
        currentEntityId: entry.entityId || null,
        status: 'ambiguous',
        current: null,
        suggested: null,
        candidates,
      };
    }
    return {
      rank: entry.rank,
      name: entry.name,
      currentEntityId: entry.entityId || null,
      status: 'unmatched',
      current: null,
      suggested: null,
      candidates: [],
    };
  });

  return {
    boardId: board.id,
    year: yearData.year,
    entityType: board.entityType,
    total: items.length,
    alreadyBoundCount: items.filter((item) => item.status === 'already_bound').length,
    matchedCount: items.filter((item) => item.status === 'matched').length,
    ambiguousCount: items.filter((item) => item.status === 'ambiguous').length,
    unmatchedCount: items.filter((item) => item.status === 'unmatched').length,
    items,
  };
};

const normalizeEventWikiFestivalId = (value: unknown): string | null => {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
};

type EventRecommendationStatus = 'ongoing' | 'upcoming' | 'ended' | 'cancelled';

const DAILY_EVENT_RECOMMENDATION_ALGORITHM_VERSION = 'daily-event-recommendations-v1';
const DAILY_EVENT_RECOMMENDATION_SIZE = 10;
const DAILY_EVENT_RECOMMENDATION_TIME_ZONE = 'Asia/Shanghai';
const DAILY_EVENT_RECOMMENDATION_MEMORY_TTL_MS = 5 * 60 * 1000;
const DAILY_EVENT_RECOMMENDATION_CANDIDATE_LIMIT_PER_STATUS = 120;
const DAILY_DJ_RECOMMENDATION_ALGORITHM_VERSION = 'daily-dj-recommendations-soundcloud-top100-v1';
const DAILY_DJ_RECOMMENDATION_SIZE = 10;
const DAILY_DJ_RECOMMENDATION_CANDIDATE_LIMIT = 100;
const DAILY_DJ_RECOMMENDATION_CANDIDATE_SOURCE = 'soundcloud_followers_top_100';
const ADMIN_EVENT_CATALOG_SNAPSHOT_VERSION = 'admin-event-catalog-summary-v1';
const ADMIN_DJ_CATALOG_SNAPSHOT_VERSION = 'admin-dj-catalog-summary-v1';
const ADMIN_EVENT_ARCHIVE_YEAR_SUMMARY_VERSION = 'admin-event-archive-year-summary-v1';
const ADMIN_CATALOG_MEMORY_TTL_MS = 5 * 60 * 1000;

const invalidateEventAdminSummaryCachesBestEffort = async (): Promise<void> => {
  await Promise.allSettled([
    adminSummaryCache.invalidateNamespace('event-catalog-summary'),
    adminSummaryCache.invalidateNamespace('event-archive-year-summary'),
  ]);
};

const invalidateDJAdminSummaryCachesBestEffort = async (): Promise<void> => {
  await Promise.allSettled([
    adminSummaryCache.invalidateNamespace('dj-catalog-summary'),
  ]);
};

type DailyEventRecommendationSnapshot = {
  userId: string;
  dateKey: string;
  recommendationDate: Date;
  activityIds: string[];
  statuses: EventRecommendationStatus[];
  algorithmVersion: string;
  generatedAt: Date;
};

type DailyDJRecommendationSnapshot = {
  userId: string;
  dateKey: string;
  recommendationDate: Date;
  djIds: string[];
  algorithmVersion: string;
  candidateSource: string;
  candidateLimit: number;
  generatedAt: Date;
};

const dailyEventRecommendationMemoryCache = new Map<
  string,
  { expiresAt: number; snapshot: DailyEventRecommendationSnapshot }
>();
const dailyDJRecommendationMemoryCache = new Map<
  string,
  { expiresAt: number; snapshot: DailyDJRecommendationSnapshot }
>();

const isTruthyQueryFlag = (value: unknown): boolean =>
  value === '1' || value === 'true' || value === 1 || value === true;

const eventRecommendationStatusOrder: EventRecommendationStatus[] = [
  'ongoing',
  'upcoming',
  'ended',
  'cancelled',
];

const parseEventRecommendationStatuses = (value: unknown): EventRecommendationStatus[] => {
  if (typeof value !== 'string' || !value.trim()) {
    return ['ongoing', 'upcoming', 'ended'];
  }

  const tokens = value
    .split(',')
    .map((item) => item.trim().toLowerCase())
    .filter(Boolean);

  const seen = new Set<EventRecommendationStatus>();
  const parsed: EventRecommendationStatus[] = [];
  for (const token of tokens) {
    if (
      (token === 'ongoing' || token === 'upcoming' || token === 'ended' || token === 'cancelled') &&
      !seen.has(token)
    ) {
      seen.add(token);
      parsed.push(token);
    }
  }

  if (parsed.length === 0) {
    return ['ongoing', 'upcoming', 'ended'];
  }

  return eventRecommendationStatusOrder.filter((status) => parsed.includes(status));
};

const buildRecommendationEventStatusWhere = (status: EventRecommendationStatus, now: Date): Prisma.EventWhereInput => {
  return buildEventStatusWhere(status, now) ?? {};
};

const popRandomItem = <T>(items: T[]): T | null => {
  if (items.length === 0) return null;
  const randomIndex = Math.floor(Math.random() * items.length);
  return items.splice(randomIndex, 1)[0] ?? null;
};

const getDailyEventRecommendationDateKey = (now: Date): string => {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: DAILY_EVENT_RECOMMENDATION_TIME_ZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(now);

  const year = parts.find((part) => part.type === 'year')?.value;
  const month = parts.find((part) => part.type === 'month')?.value;
  const day = parts.find((part) => part.type === 'day')?.value;
  return `${year}-${month}-${day}`;
};

const parseDailyEventRecommendationStatuses = (values: string[]): EventRecommendationStatus[] => {
  const statuses = values.filter((value): value is EventRecommendationStatus =>
    value === 'ongoing' || value === 'upcoming' || value === 'ended' || value === 'cancelled'
  );
  return statuses.length > 0 ? statuses : ['ongoing', 'upcoming', 'ended'];
};

const selectEventRecommendationIds = async (
  statuses: EventRecommendationStatus[],
  limit: number,
  now: Date
): Promise<string[]> => {
  const poolEntries = await Promise.all(
    statuses.map(async (status) => {
      const rows = await prisma.event.findMany({
        where: buildRecommendationEventStatusWhere(status, now),
        orderBy:
          status === 'upcoming'
            ? [{ startDate: 'asc' }, { id: 'asc' }]
            : status === 'ongoing'
              ? [{ endDate: 'asc' }, { startDate: 'asc' }, { id: 'asc' }]
              : status === 'ended'
                ? [{ endDate: 'desc' }, { id: 'asc' }]
                : [{ updatedAt: 'desc' }, { id: 'asc' }],
        take: DAILY_EVENT_RECOMMENDATION_CANDIDATE_LIMIT_PER_STATUS,
        select: { id: true },
      });
      return [status, shuffleArray(rows.map((row) => row.id))] as const;
    })
  );

  const idPoolByStatus: Record<EventRecommendationStatus, string[]> = {
    ongoing: [],
    upcoming: [],
    ended: [],
    cancelled: [],
  };
  for (const [status, ids] of poolEntries) {
    idPoolByStatus[status] = ids;
  }

  const selectedIds: string[] = [];
  const selectedSet = new Set<string>();

  for (const status of statuses) {
    if (selectedIds.length >= limit) break;
    const picked = popRandomItem(idPoolByStatus[status]);
    if (!picked || selectedSet.has(picked)) continue;
    selectedSet.add(picked);
    selectedIds.push(picked);
  }

  const remainingPool = statuses.flatMap((status) => idPoolByStatus[status]);
  while (selectedIds.length < limit) {
    const picked = popRandomItem(remainingPool);
    if (!picked) break;
    if (selectedSet.has(picked)) continue;
    selectedSet.add(picked);
    selectedIds.push(picked);
  }

  return selectedIds;
};

const mapDailyEventRecommendationSnapshot = (row: {
  userId: string;
  recommendationDate: Date;
  activityIds: string[];
  statuses: string[];
  algorithmVersion: string;
  generatedAt: Date;
}): DailyEventRecommendationSnapshot => {
  const dateKey = row.recommendationDate.toISOString().slice(0, 10);
  return {
    userId: row.userId,
    dateKey,
    recommendationDate: row.recommendationDate,
    activityIds: row.activityIds,
    statuses: parseDailyEventRecommendationStatuses(row.statuses),
    algorithmVersion: row.algorithmVersion,
    generatedAt: row.generatedAt,
  };
};

const readDailyEventRecommendationSnapshot = async (
  userId: string,
  dateKey: string
): Promise<DailyEventRecommendationSnapshot | null> => {
  const cacheKey = `${userId}:${dateKey}`;
  const cached = dailyEventRecommendationMemoryCache.get(cacheKey);
  if (cached && cached.expiresAt > Date.now()) {
    return cached.snapshot;
  }
  dailyEventRecommendationMemoryCache.delete(cacheKey);

  const recommendationDate = new Date(`${dateKey}T00:00:00.000Z`);
  const row = await prisma.userDailyEventRecommendation.findUnique({
    where: {
      userId_recommendationDate: {
        userId,
        recommendationDate,
      },
    },
  });
  if (!row) return null;

  const snapshot = mapDailyEventRecommendationSnapshot(row);
  dailyEventRecommendationMemoryCache.set(cacheKey, {
    expiresAt: Date.now() + DAILY_EVENT_RECOMMENDATION_MEMORY_TTL_MS,
    snapshot,
  });
  return snapshot;
};

const getOrCreateDailyEventRecommendationSnapshot = async (
  userId: string,
  statuses: EventRecommendationStatus[],
  now: Date
): Promise<DailyEventRecommendationSnapshot> => {
  const dateKey = getDailyEventRecommendationDateKey(now);
  const existing = await readDailyEventRecommendationSnapshot(userId, dateKey);
  if (existing) return existing;

  const recommendationDate = new Date(`${dateKey}T00:00:00.000Z`);
  const selectedIds = await selectEventRecommendationIds(
    statuses,
    DAILY_EVENT_RECOMMENDATION_SIZE,
    now
  );

  try {
    const row = await prisma.userDailyEventRecommendation.create({
      data: {
        userId,
        recommendationDate,
        activityIds: selectedIds,
        algorithmVersion: DAILY_EVENT_RECOMMENDATION_ALGORITHM_VERSION,
        statuses,
      },
    });
    const snapshot = mapDailyEventRecommendationSnapshot(row);
    dailyEventRecommendationMemoryCache.set(`${userId}:${dateKey}`, {
      expiresAt: Date.now() + DAILY_EVENT_RECOMMENDATION_MEMORY_TTL_MS,
      snapshot,
    });
    return snapshot;
  } catch (error) {
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
      const raced = await readDailyEventRecommendationSnapshot(userId, dateKey);
      if (raced) return raced;
    }
    throw error;
  }
};

const mapDailyDJRecommendationSnapshot = (row: {
  userId: string;
  recommendationDate: Date;
  djIds: string[];
  algorithmVersion: string;
  candidateSource: string;
  candidateLimit: number;
  generatedAt: Date;
}): DailyDJRecommendationSnapshot => {
  const dateKey = row.recommendationDate.toISOString().slice(0, 10);
  return {
    userId: row.userId,
    dateKey,
    recommendationDate: row.recommendationDate,
    djIds: row.djIds,
    algorithmVersion: row.algorithmVersion,
    candidateSource: row.candidateSource,
    candidateLimit: row.candidateLimit,
    generatedAt: row.generatedAt,
  };
};

const readDailyDJRecommendationSnapshot = async (
  userId: string,
  dateKey: string
): Promise<DailyDJRecommendationSnapshot | null> => {
  const cacheKey = `${userId}:${dateKey}`;
  const cached = dailyDJRecommendationMemoryCache.get(cacheKey);
  if (cached && cached.expiresAt > Date.now()) {
    return cached.snapshot;
  }
  dailyDJRecommendationMemoryCache.delete(cacheKey);

  const recommendationDate = new Date(`${dateKey}T00:00:00.000Z`);
  const row = await prisma.userDailyDJRecommendation.findUnique({
    where: {
      userId_recommendationDate: {
        userId,
        recommendationDate,
      },
    },
  });
  if (!row) return null;

  const snapshot = mapDailyDJRecommendationSnapshot(row);
  dailyDJRecommendationMemoryCache.set(cacheKey, {
    expiresAt: Date.now() + DAILY_EVENT_RECOMMENDATION_MEMORY_TTL_MS,
    snapshot,
  });
  return snapshot;
};

const selectDailyDJRecommendationIds = async (): Promise<string[]> => {
  const candidates = await prisma.dJ.findMany({
    where: {
      soundCloudFollowers: { not: null },
    },
    select: { id: true },
    orderBy: [
      { soundCloudFollowers: 'desc' },
      { name: 'asc' },
    ],
    take: DAILY_DJ_RECOMMENDATION_CANDIDATE_LIMIT,
  });
  const pool = candidates.map((row) => row.id);
  const selectedIds: string[] = [];
  const selectedSet = new Set<string>();

  while (selectedIds.length < DAILY_DJ_RECOMMENDATION_SIZE) {
    const picked = popRandomItem(pool);
    if (!picked) break;
    if (selectedSet.has(picked)) continue;
    selectedSet.add(picked);
    selectedIds.push(picked);
  }

  return selectedIds;
};

const getOrCreateDailyDJRecommendationSnapshot = async (
  userId: string,
  now: Date
): Promise<DailyDJRecommendationSnapshot> => {
  const dateKey = getDailyEventRecommendationDateKey(now);
  const existing = await readDailyDJRecommendationSnapshot(userId, dateKey);
  if (existing) return existing;

  const recommendationDate = new Date(`${dateKey}T00:00:00.000Z`);
  const selectedIds = await selectDailyDJRecommendationIds();

  try {
    const row = await prisma.userDailyDJRecommendation.create({
      data: {
        userId,
        recommendationDate,
        djIds: selectedIds,
        algorithmVersion: DAILY_DJ_RECOMMENDATION_ALGORITHM_VERSION,
        candidateSource: DAILY_DJ_RECOMMENDATION_CANDIDATE_SOURCE,
        candidateLimit: DAILY_DJ_RECOMMENDATION_CANDIDATE_LIMIT,
      },
    });
    const snapshot = mapDailyDJRecommendationSnapshot(row);
    dailyDJRecommendationMemoryCache.set(`${userId}:${dateKey}`, {
      expiresAt: Date.now() + DAILY_EVENT_RECOMMENDATION_MEMORY_TTL_MS,
      snapshot,
    });
    return snapshot;
  } catch (error) {
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
      const raced = await readDailyDJRecommendationSnapshot(userId, dateKey);
      if (raced) return raced;
    }
    throw error;
  }
};

router.get('/events/recommendations', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = (req as BFFAuthRequest).user?.userId;
    const limit = normalizeLimit(req.query.limit, 10, 20);
    const requestedStatuses = parseEventRecommendationStatuses(req.query.statuses);
    const now = new Date();
    const snapshot = userId
      ? await getOrCreateDailyEventRecommendationSnapshot(userId, requestedStatuses, now)
      : null;
    const selectedIds = snapshot
      ? snapshot.activityIds.slice(0, limit)
      : await selectEventRecommendationIds(requestedStatuses, limit, now);

    if (selectedIds.length === 0) {
      ok(res, {
        items: [],
        meta: {
          limit,
          selected: 0,
          statuses: snapshot?.statuses ?? requestedStatuses,
          cache: snapshot
            ? {
                scope: 'daily-user',
                hit: true,
                date: snapshot.dateKey,
                algorithmVersion: snapshot.algorithmVersion,
                generatedAt: snapshot.generatedAt.toISOString(),
                timeZone: DAILY_EVENT_RECOMMENDATION_TIME_ZONE,
              }
            : { scope: 'request', hit: false },
        },
      });
      return;
    }

    // Fetch only selected events to keep payload generation cheap.
    const rows = await prisma.event.findMany({
      where: {
        id: { in: selectedIds },
      },
      select: selectEventRecommendationCardForWeb,
    });
    const rowById = new Map(rows.map((row) => [row.id, row]));
    const orderedRows = selectedIds
      .map((id) => rowById.get(id))
      .filter((row): row is NonNullable<typeof row> => Boolean(row));

    const favoriteIdsByEventId = await resolveEventFavoriteIds(userId, orderedRows.map((row) => row.id));
    const rowsWithFavorites = attachEventFavoriteState(orderedRows, favoriteIdsByEventId);
    const complianceUser = await resolveRegionalComplianceUser(userId);

    ok(res, {
      items: rowsWithFavorites.map((row) => mapEventRecommendationCard(row, complianceUser)),
      meta: {
        limit,
        selected: orderedRows.length,
        statuses: snapshot?.statuses ?? requestedStatuses,
        cache: snapshot
          ? {
              scope: 'daily-user',
              hit: true,
              date: snapshot.dateKey,
              algorithmVersion: snapshot.algorithmVersion,
              generatedAt: snapshot.generatedAt.toISOString(),
              timeZone: DAILY_EVENT_RECOMMENDATION_TIME_ZONE,
            }
          : { scope: 'request', hit: false },
      },
    });
  } catch (error) {
    console.error('BFF web event recommendations error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/events/bootstrap', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = (req as BFFAuthRequest).user?.userId;
    const limit = normalizeLimit(req.query.limit, 5, 20);
    const search = typeof req.query.search === 'string' ? req.query.search.trim() : '';
    const eventType = typeof req.query.eventType === 'string' ? req.query.eventType.trim() : '';
    const now = new Date();

    const baseWhere: Prisma.EventWhereInput = {};
    if (search) {
      const aliasMatchedBrands = await prisma.$queryRaw<Array<{ id: string }>>(Prisma.sql`
        SELECT "id"
        FROM "wiki_festivals"
        WHERE "is_active" = true
          AND cardinality("aliases") > 0
          AND EXISTS (
            SELECT 1
            FROM unnest("aliases") AS alias
            WHERE alias ILIKE ${`%${search}%`}
          )
        LIMIT 100
      `);
      const aliasMatchedBrandIDs = aliasMatchedBrands.map((brand) => brand.id);
      baseWhere.OR = [
        { name: { contains: search, mode: 'insensitive' } },
        { abbreviation: { contains: search, mode: 'insensitive' } },
        { description: { contains: search, mode: 'insensitive' } },
        { slug: { contains: search, mode: 'insensitive' } },
        { city: { contains: search, mode: 'insensitive' } },
        { country: { contains: search, mode: 'insensitive' } },
        { organizerName: { contains: search, mode: 'insensitive' } },
        { wikiFestivalId: { contains: search, mode: 'insensitive' } },
        {
          wikiFestival: {
            is: {
              OR: [
                { name: { contains: search, mode: 'insensitive' } },
                { abbreviation: { contains: search, mode: 'insensitive' } },
                { aliases: { has: search } },
              ],
            },
          },
        },
        ...(aliasMatchedBrandIDs.length > 0 ? [{ wikiFestivalId: { in: aliasMatchedBrandIDs } }] : []),
        { nameI18n: { path: ['zh'], string_contains: search } },
        { nameI18n: { path: ['en'], string_contains: search } },
        { descriptionI18n: { path: ['zh'], string_contains: search } },
        { descriptionI18n: { path: ['en'], string_contains: search } },
        { manualLocation: { path: ['detailAddressI18n', 'zh'], string_contains: search } },
        { manualLocation: { path: ['detailAddressI18n', 'en'], string_contains: search } },
        { manualLocation: { path: ['formattedAddressI18n', 'zh'], string_contains: search } },
        { manualLocation: { path: ['formattedAddressI18n', 'en'], string_contains: search } },
        { cityI18n: { path: ['zh'], string_contains: search } },
        { cityI18n: { path: ['en'], string_contains: search } },
        { countryI18n: { path: ['zh'], string_contains: search } },
        { countryI18n: { path: ['en'], string_contains: search } },
        { countryI18n: { path: ['enFull'], string_contains: search } },
      ];
    }
    if (eventType) {
      const eventTypeValues = resolveEventTypeFilterValues(eventType);
      if (eventTypeValues.length <= 1) {
        baseWhere.eventType = eventTypeValues[0] ?? eventType;
      } else {
        baseWhere.eventType = { in: eventTypeValues };
      }
    }

    const ongoingWhere: Prisma.EventWhereInput = {
      ...baseWhere,
      ...(buildEventStatusWhere('ongoing', now) ?? {}),
    };
    const upcomingWhere: Prisma.EventWhereInput = {
      ...baseWhere,
      ...(buildEventStatusWhere('upcoming', now) ?? {}),
    };

    const [ongoingRows, ongoingTotal, upcomingRows, upcomingTotal] = await Promise.all([
      prisma.event.findMany({
        where: ongoingWhere,
        take: limit,
        orderBy: [{ startDate: 'asc' }, { id: 'asc' }],
        select: selectEventListCardForWeb,
      }),
      prisma.event.count({ where: ongoingWhere }),
      prisma.event.findMany({
        where: upcomingWhere,
        take: limit,
        orderBy: [{ startDate: 'asc' }, { id: 'asc' }],
        select: selectEventListCardForWeb,
      }),
      prisma.event.count({ where: upcomingWhere }),
    ]);

    const favoriteIdsByEventId = await resolveEventFavoriteIds(userId, [
      ...ongoingRows.map((row) => row.id),
      ...upcomingRows.map((row) => row.id),
    ]);
    const complianceUser = await resolveRegionalComplianceUser(userId);
    const mapRows = (rows: typeof ongoingRows) =>
      attachEventFavoriteState(rows, favoriteIdsByEventId).map((row) => mapEventListCard(row, complianceUser));

    ok(res, {
      ongoing: {
        items: mapRows(ongoingRows),
        pagination: {
          page: 1,
          limit,
          total: ongoingTotal,
          totalPages: Math.ceil(ongoingTotal / limit) || 1,
        },
      },
      upcoming: {
        items: mapRows(upcomingRows),
        pagination: {
          page: 1,
          limit,
          total: upcomingTotal,
          totalPages: Math.ceil(upcomingTotal / limit) || 1,
        },
      },
    });
  } catch (error) {
    console.error('BFF web events bootstrap error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/events', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = (req as BFFAuthRequest).user?.userId;
    const page = normalizePage(req.query.page, 1);
    const limit = normalizeLimit(req.query.limit, 20, 100);
    const skip = (page - 1) * limit;

    const search = typeof req.query.search === 'string' ? req.query.search.trim() : '';
    const city = typeof req.query.city === 'string' ? req.query.city.trim() : '';
    const country = typeof req.query.country === 'string' ? req.query.country.trim() : '';
    const eventType = typeof req.query.eventType === 'string' ? req.query.eventType.trim() : '';
    const wikiFestivalId = typeof req.query.wikiFestivalId === 'string' ? req.query.wikiFestivalId.trim() : '';
    const statusRaw = typeof req.query.status === 'string' ? req.query.status.trim() : 'upcoming';
    const status = statusRaw.toLowerCase();

    const where: any = {};
    const now = new Date();
    const statusWhere = buildEventStatusWhere(status, now);
    if (statusWhere) {
      Object.assign(where, statusWhere);
    }
    if (search) {
      const aliasMatchedBrands = await prisma.$queryRaw<Array<{ id: string }>>(Prisma.sql`
        SELECT "id"
        FROM "wiki_festivals"
        WHERE "is_active" = true
          AND cardinality("aliases") > 0
          AND EXISTS (
            SELECT 1
            FROM unnest("aliases") AS alias
            WHERE alias ILIKE ${`%${search}%`}
          )
        LIMIT 100
      `);
      const aliasMatchedBrandIDs = aliasMatchedBrands.map((brand) => brand.id);
      where.OR = [
        { name: { contains: search, mode: 'insensitive' } },
        { abbreviation: { contains: search, mode: 'insensitive' } },
        { description: { contains: search, mode: 'insensitive' } },
        { slug: { contains: search, mode: 'insensitive' } },
        { city: { contains: search, mode: 'insensitive' } },
        { country: { contains: search, mode: 'insensitive' } },
        { organizerName: { contains: search, mode: 'insensitive' } },
        { wikiFestivalId: { contains: search, mode: 'insensitive' } },
        {
          wikiFestival: {
            is: {
              OR: [
                { name: { contains: search, mode: 'insensitive' } },
                { abbreviation: { contains: search, mode: 'insensitive' } },
                { aliases: { has: search } },
              ],
            },
          },
        },
        ...(aliasMatchedBrandIDs.length > 0 ? [{ wikiFestivalId: { in: aliasMatchedBrandIDs } }] : []),
        { nameI18n: { path: ['zh'], string_contains: search } },
        { nameI18n: { path: ['en'], string_contains: search } },
        { descriptionI18n: { path: ['zh'], string_contains: search } },
        { descriptionI18n: { path: ['en'], string_contains: search } },
        { manualLocation: { path: ['detailAddressI18n', 'zh'], string_contains: search } },
        { manualLocation: { path: ['detailAddressI18n', 'en'], string_contains: search } },
        { manualLocation: { path: ['formattedAddressI18n', 'zh'], string_contains: search } },
        { manualLocation: { path: ['formattedAddressI18n', 'en'], string_contains: search } },
        { cityI18n: { path: ['zh'], string_contains: search } },
        { cityI18n: { path: ['en'], string_contains: search } },
        { countryI18n: { path: ['zh'], string_contains: search } },
        { countryI18n: { path: ['en'], string_contains: search } },
        { countryI18n: { path: ['enFull'], string_contains: search } },
      ];
    }
    if (city) where.city = city;
    if (country) where.country = country;
    if (wikiFestivalId) where.wikiFestivalId = wikiFestivalId;
    if (eventType) {
      const eventTypeValues = resolveEventTypeFilterValues(eventType);
      if (eventTypeValues.length <= 1) {
        where.eventType = eventTypeValues[0] ?? eventType;
      } else {
        where.eventType = { in: eventTypeValues };
      }
    }

    const eventOrderBy: Prisma.EventOrderByWithRelationInput[] =
      status === 'ended'
        ? [{ startDate: 'desc' }, { id: 'desc' }]
        : [{ startDate: 'asc' }, { id: 'asc' }];

    const [rows, total] = await Promise.all([
      prisma.event.findMany({
        where,
        skip,
        take: limit,
        orderBy: eventOrderBy,
        select: selectEventListCardForWeb,
      }),
      prisma.event.count({ where }),
    ]);

    const favoriteIdsByEventId = await resolveEventFavoriteIds(userId, rows.map((row) => row.id));
    const rowsWithFavorites = attachEventFavoriteState(rows, favoriteIdsByEventId);
    const complianceUser = await resolveRegionalComplianceUser(userId);

    ok(
      res,
      { items: rowsWithFavorites.map((row) => mapEventListCard(row, complianceUser)) },
      {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit) || 1,
      }
    );
  } catch (error) {
    console.error('BFF web events error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/events/catalog-summary', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const page = normalizePage(req.query.page, 1);
    const limit = normalizeLimit(req.query.limit, 50, 100);
    const skip = (page - 1) * limit;

    const search = typeof req.query.search === 'string' ? req.query.search.trim() : '';
    const city = typeof req.query.city === 'string' ? req.query.city.trim() : '';
    const country = typeof req.query.country === 'string' ? req.query.country.trim() : '';
    const eventType = typeof req.query.eventType === 'string' ? req.query.eventType.trim() : '';
    const wikiFestivalId = typeof req.query.wikiFestivalId === 'string' ? req.query.wikiFestivalId.trim() : '';
    const sortByRaw = typeof req.query.sortBy === 'string' ? req.query.sortBy.trim() : 'startDateDesc';
    const sortBy =
      sortByRaw === 'startDateAsc'
      || sortByRaw === 'updatedAtDesc'
      || sortByRaw === 'updatedAtAsc'
        ? sortByRaw
        : 'startDateDesc';
    const statusRaw = typeof req.query.status === 'string' ? req.query.status.trim() : 'all';
    const status = statusRaw.toLowerCase();
    const forceRefresh = isTruthyQueryFlag(req.query.refresh);

    const cacheKey = JSON.stringify({
      page,
      limit,
      search,
      city,
      country,
      eventType,
      wikiFestivalId,
      sortBy,
      status,
    });
    const cached = !forceRefresh
      ? await adminSummaryCache.get<{
          items: unknown[];
          pagination: BFFPagination;
          generatedAt: string;
        }>({
          namespace: 'event-catalog-summary',
          key: cacheKey,
          snapshotVersion: ADMIN_EVENT_CATALOG_SNAPSHOT_VERSION,
        })
      : null;
    if (cached) {
      res.json({
        data: {
          items: cached.payload.items,
          meta: {
            cache: {
              scope: cached.scope,
              hit: true,
              stale: false,
              generatedAt: cached.payload.generatedAt,
              ttlMs: ADMIN_CATALOG_MEMORY_TTL_MS,
              snapshotVersion: ADMIN_EVENT_CATALOG_SNAPSHOT_VERSION,
            },
          },
        },
        pagination: cached.payload.pagination,
      });
      return;
    }

    const where: any = {};
    const now = new Date();
    const statusWhere = buildEventStatusWhere(status, now);
    if (statusWhere) {
      Object.assign(where, statusWhere);
    }
    if (search) {
      const aliasMatchedBrands = await prisma.$queryRaw<Array<{ id: string }>>(Prisma.sql`
        SELECT "id"
        FROM "wiki_festivals"
        WHERE "is_active" = true
          AND cardinality("aliases") > 0
          AND EXISTS (
            SELECT 1
            FROM unnest("aliases") AS alias
            WHERE alias ILIKE ${`%${search}%`}
          )
        LIMIT 100
      `);
      const aliasMatchedBrandIDs = aliasMatchedBrands.map((brand) => brand.id);
      where.OR = [
        { name: { contains: search, mode: 'insensitive' } },
        { abbreviation: { contains: search, mode: 'insensitive' } },
        { description: { contains: search, mode: 'insensitive' } },
        { slug: { contains: search, mode: 'insensitive' } },
        { city: { contains: search, mode: 'insensitive' } },
        { country: { contains: search, mode: 'insensitive' } },
        { organizerName: { contains: search, mode: 'insensitive' } },
        { wikiFestivalId: { contains: search, mode: 'insensitive' } },
        {
          wikiFestival: {
            is: {
              OR: [
                { name: { contains: search, mode: 'insensitive' } },
                { abbreviation: { contains: search, mode: 'insensitive' } },
                { aliases: { has: search } },
              ],
            },
          },
        },
        ...(aliasMatchedBrandIDs.length > 0 ? [{ wikiFestivalId: { in: aliasMatchedBrandIDs } }] : []),
        { nameI18n: { path: ['zh'], string_contains: search } },
        { nameI18n: { path: ['en'], string_contains: search } },
        { descriptionI18n: { path: ['zh'], string_contains: search } },
        { descriptionI18n: { path: ['en'], string_contains: search } },
        { manualLocation: { path: ['detailAddressI18n', 'zh'], string_contains: search } },
        { manualLocation: { path: ['detailAddressI18n', 'en'], string_contains: search } },
        { manualLocation: { path: ['formattedAddressI18n', 'zh'], string_contains: search } },
        { manualLocation: { path: ['formattedAddressI18n', 'en'], string_contains: search } },
        { cityI18n: { path: ['zh'], string_contains: search } },
        { cityI18n: { path: ['en'], string_contains: search } },
        { countryI18n: { path: ['zh'], string_contains: search } },
        { countryI18n: { path: ['en'], string_contains: search } },
        { countryI18n: { path: ['enFull'], string_contains: search } },
      ];
    }
    if (city) where.city = city;
    if (country) where.country = country;
    if (wikiFestivalId) where.wikiFestivalId = wikiFestivalId;
    if (eventType) {
      const eventTypeValues = resolveEventTypeFilterValues(eventType);
      if (eventTypeValues.length <= 1) {
        where.eventType = eventTypeValues[0] ?? eventType;
      } else {
        where.eventType = { in: eventTypeValues };
      }
    }

    const eventOrderBy: Prisma.EventOrderByWithRelationInput[] =
      sortBy === 'startDateAsc'
        ? [{ startDate: 'asc' }, { id: 'asc' }]
        : sortBy === 'updatedAtDesc'
          ? [{ updatedAt: 'desc' }, { id: 'desc' }]
          : sortBy === 'updatedAtAsc'
            ? [{ updatedAt: 'asc' }, { id: 'asc' }]
            : [{ startDate: 'desc' }, { id: 'desc' }];

    const [rows, total] = await Promise.all([
      prisma.event.findMany({
        where,
        skip,
        take: limit,
        orderBy: eventOrderBy,
        select: {
          id: true,
          name: true,
          slug: true,
          coverImageUrl: true,
          organizerName: true,
          city: true,
          country: true,
          cityI18n: true,
          countryI18n: true,
          manualLocation: true,
          locationPoint: true,
          latitude: true,
          longitude: true,
          eventType: true,
          isCancelled: true,
          visibility: true,
          isVerified: true,
          startDate: true,
          endDate: true,
          timeZone: true,
          updatedAt: true,
          wikiFestival: {
            select: {
              id: true,
              name: true,
            },
          },
          eventDays: {
            orderBy: [{ sortOrder: 'asc' as const }, { overallDayIndex: 'asc' as const }],
            select: {
              eventDayId: true,
            },
          },
        },
      }),
      prisma.event.count({ where }),
    ]);

    const pagination = {
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit) || 1,
    };
    const items = rows.map((row) => {
      const resolvedEventTruth = resolveEventTruth({
        isCancelled: row.isCancelled,
        visibility: row.visibility,
      });
      return {
        ...mapEventReference(row, { includeCoverImageUrl: true }),
        slug: row.slug,
        organizerName: row.organizerName,
        eventType: row.eventType,
        isVerified: row.isVerified,
        updatedAt: row.updatedAt,
        wikiFestival: row.wikiFestival,
        eventDays: row.eventDays,
        status: deriveEventStatus(new Date(row.startDate), new Date(row.endDate), {
          isCancelled: resolvedEventTruth.isCancelled,
          visibility: resolvedEventTruth.visibility,
        }),
      };
    });
    const generatedAt = new Date().toISOString();
    await adminSummaryCache.set({
      namespace: 'event-catalog-summary',
      key: cacheKey,
      ttlMs: ADMIN_CATALOG_MEMORY_TTL_MS,
      snapshotVersion: ADMIN_EVENT_CATALOG_SNAPSHOT_VERSION,
      payload: {
        items,
        pagination,
        generatedAt,
      },
    });

    res.json({
      data: {
        items,
        meta: {
          cache: {
            scope: 'memory',
            hit: false,
            stale: false,
            generatedAt,
            ttlMs: ADMIN_CATALOG_MEMORY_TTL_MS,
            snapshotVersion: ADMIN_EVENT_CATALOG_SNAPSHOT_VERSION,
          },
        },
      },
      pagination,
    });
  } catch (error) {
    console.error('BFF web event catalog summary error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/events/archive-year-summary', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const cacheKey = 'archive-year-summary';
    const forceRefresh = isTruthyQueryFlag(req.query.refresh);
    const cached = !forceRefresh
      ? await adminSummaryCache.get<{
          items: unknown[];
          generatedAt: string;
        }>({
          namespace: 'event-archive-year-summary',
          key: cacheKey,
          snapshotVersion: ADMIN_EVENT_ARCHIVE_YEAR_SUMMARY_VERSION,
        })
      : null;
    if (cached) {
      res.json({
        data: {
          items: cached.payload.items,
          meta: {
            cache: {
              scope: cached.scope,
              hit: true,
              stale: false,
              generatedAt: cached.payload.generatedAt,
              ttlMs: ADMIN_CATALOG_MEMORY_TTL_MS,
              snapshotVersion: ADMIN_EVENT_ARCHIVE_YEAR_SUMMARY_VERSION,
            },
          },
        },
      });
      return;
    }

    const rows = await prisma.$queryRaw<Array<{ year: number; count: number }>>(Prisma.sql`
      SELECT
        EXTRACT(YEAR FROM "start_date")::int AS "year",
        COUNT(*)::int AS "count"
      FROM "events"
      GROUP BY EXTRACT(YEAR FROM "start_date")
      ORDER BY "year" DESC
    `);

    const items = rows.map((row) => ({
      year: Number(row.year),
      count: Number(row.count),
    }));
    const generatedAt = new Date().toISOString();
    await adminSummaryCache.set({
      namespace: 'event-archive-year-summary',
      key: cacheKey,
      ttlMs: ADMIN_CATALOG_MEMORY_TTL_MS,
      snapshotVersion: ADMIN_EVENT_ARCHIVE_YEAR_SUMMARY_VERSION,
      payload: {
        items,
        generatedAt,
      },
    });

    res.json({
      data: {
        items,
        meta: {
          cache: {
            scope: 'memory',
            hit: false,
            stale: false,
            generatedAt,
            ttlMs: ADMIN_CATALOG_MEMORY_TTL_MS,
            snapshotVersion: ADMIN_EVENT_ARCHIVE_YEAR_SUMMARY_VERSION,
          },
        },
      },
    });
  } catch (error) {
    console.error('BFF web event archive year summary error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/event-timezones/search', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const query = String(req.query.q || req.query.query || '').trim();
    if (!query) {
      res.json({
        data: {
          query: '',
          items: [],
        },
      });
      return;
    }

    const items = searchEventTimezonesByCity(query, req.query.limit);
    res.json({
      data: {
        query,
        items,
      },
    });
  } catch (error) {
    console.error('BFF event timezone search failed:', error);
    res.status(500).json({ error: 'Failed to search event timezones' });
  }
});

router.get('/events/festival-feed', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = (req as BFFAuthRequest).user?.userId;
    const wikiFestivalId = typeof req.query.wikiFestivalId === 'string' ? req.query.wikiFestivalId.trim() : '';
    if (!wikiFestivalId) {
      res.status(400).json({ error: 'wikiFestivalId is required' });
      return;
    }

    const upcomingPage = normalizePage(req.query.upcomingPage, 1);
    const upcomingLimit = normalizeLimit(req.query.upcomingLimit, 10, 100);
    const endedPage = normalizePage(req.query.endedPage, 1);
    const endedLimit = normalizeLimit(req.query.endedLimit, 10, 100);
    const now = new Date();

    const upcomingWhere: Prisma.EventWhereInput = {
      wikiFestivalId,
      ...(buildEventStatusWhere('upcoming', now) ?? {}),
    };
    const endedWhere: Prisma.EventWhereInput = {
      wikiFestivalId,
      ...(buildEventStatusWhere('ended', now) ?? {}),
    };

    const [
      upcomingRows,
      upcomingTotal,
      endedRows,
      endedTotal,
    ] = await Promise.all([
      prisma.event.findMany({
        where: upcomingWhere,
        skip: (upcomingPage - 1) * upcomingLimit,
        take: upcomingLimit,
        orderBy: [{ startDate: 'asc' }, { id: 'asc' }],
        select: selectEventListCardForWeb,
      }),
      prisma.event.count({ where: upcomingWhere }),
      prisma.event.findMany({
        where: endedWhere,
        skip: (endedPage - 1) * endedLimit,
        take: endedLimit,
        orderBy: [{ startDate: 'desc' }, { id: 'desc' }],
        select: selectEventListCardForWeb,
      }),
      prisma.event.count({ where: endedWhere }),
    ]);

    const favoriteIdsByEventId = await resolveEventFavoriteIds(userId, [
      ...upcomingRows.map((row) => row.id),
      ...endedRows.map((row) => row.id),
    ]);
    const complianceUser = await resolveRegionalComplianceUser(userId);
    const mapRows = (rows: typeof upcomingRows) =>
      attachEventFavoriteState(rows, favoriteIdsByEventId).map((row) => mapEventListCard(row, complianceUser));

    ok(res, {
      upcoming: {
        items: mapRows(upcomingRows),
        pagination: {
          page: upcomingPage,
          limit: upcomingLimit,
          total: upcomingTotal,
          totalPages: Math.ceil(upcomingTotal / upcomingLimit) || 1,
        },
      },
      ended: {
        items: mapRows(endedRows),
        pagination: {
          page: endedPage,
          limit: endedLimit,
          total: endedTotal,
          totalPages: Math.ceil(endedTotal / endedLimit) || 1,
        },
      },
    });
  } catch (error) {
    console.error('BFF web festival event feed error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/events/my', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;
    const page = normalizePage(req.query.page, 1);
    const limit = normalizeLimit(req.query.limit, 20, 100);
    const skip = (page - 1) * limit;

    const [rows, total] = await Promise.all([
      prisma.event.findMany({
        where: { organizerId: userId },
        orderBy: { createdAt: 'desc' },
        include: includeEventForWeb,
        skip,
        take: limit,
      }),
      prisma.event.count({
        where: { organizerId: userId },
      }),
    ]);

    const favoriteIdsByEventId = await resolveEventFavoriteIds(userId, rows.map((row) => row.id));
    const rowsWithFavorites = attachEventFavoriteState(rows, favoriteIdsByEventId);
    const complianceUser = await resolveRegionalComplianceUser(userId);

    ok(
      res,
      { items: rowsWithFavorites.map((row) => mapEvent(row, complianceUser)) },
      {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit) || 1,
      }
    );
  } catch (error) {
    console.error('BFF web my events error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/events/favorites', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const page = normalizePage(req.query.page, 1);
    const limit = normalizeLimit(req.query.limit, 20, 100);
    const skip = (page - 1) * limit;

    const [favoriteRows, total] = await Promise.all([
      prisma.userEntityFollow.findMany({
        where: {
          userId,
          relationType: USER_ENTITY_RELATION_FAVORITE,
          targetType: USER_ENTITY_TARGET_EVENT,
        },
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        select: { id: true, targetId: true },
      }),
      prisma.userEntityFollow.count({
        where: {
          userId,
          relationType: USER_ENTITY_RELATION_FAVORITE,
          targetType: USER_ENTITY_TARGET_EVENT,
        },
      }),
    ]);

    const eventRows = await prisma.event.findMany({
      where: { id: { in: favoriteRows.map((row) => row.targetId) } },
      include: includeEventForWeb,
    });
    const eventById = new Map(eventRows.map((event) => [event.id, event]));
    const events = favoriteRows
      .map((row) => {
        const event = eventById.get(row.targetId);
        return event ? { ...event, favoriteId: row.id } : null;
      })
      .filter((event): event is NonNullable<typeof event> => Boolean(event));
    const complianceUser = await resolveRegionalComplianceUser(userId);

    ok(
      res,
      { items: events.map((row) => mapEvent(row, complianceUser)) },
      {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit) || 1,
      }
    );
  } catch (error) {
    console.error('BFF web event favorites error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/events/:id/favorite', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const eventId = req.params.id as string;
    const row = await prisma.userEntityFollow.findUnique({
      where: userEntityFollowWhere(userId, USER_ENTITY_RELATION_FAVORITE, USER_ENTITY_TARGET_EVENT, eventId),
    });

    ok(res, {
      id: row?.id ?? null,
      eventId,
      isFavorited: Boolean(row),
      createdAt: row?.createdAt ?? null,
    });
  } catch (error) {
    console.error('BFF web event favorite status error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/events/:id/favorite', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const eventId = req.params.id as string;
    const event = await prisma.event.findUnique({
      where: { id: eventId },
      select: { id: true },
    });
    if (!event) {
      res.status(404).json({ error: 'Event not found' });
      return;
    }

    const row = await prisma.$transaction(async (tx) => {
      const relation = await upsertUserEntityRelation(tx, {
        userId,
        relationType: USER_ENTITY_RELATION_FAVORITE,
        targetType: USER_ENTITY_TARGET_EVENT,
        targetId: eventId,
      });
      return relation;
    });

    ok(res, {
      id: row.id,
      eventId: row.targetId,
      isFavorited: true,
      createdAt: row.createdAt,
    });
  } catch (error) {
    console.error('BFF web event favorite create error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.delete('/events/:id/favorite', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const eventId = req.params.id as string;
    await prisma.$transaction(async (tx) => {
      await deleteUserEntityRelation(tx, {
        userId,
        relationType: USER_ENTITY_RELATION_FAVORITE,
        targetType: USER_ENTITY_TARGET_EVENT,
        targetId: eventId,
      });
    });

    ok(res, { success: true });
  } catch (error) {
    console.error('BFF web event favorite delete error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/events/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = authReq.user?.userId;
    const viewerRole = authReq.user?.role ?? null;
    const eventId = req.params.id as string;
    const row = await attachContributionInfo(
      prisma,
      'event',
      await prisma.event.findUnique({
        where: { id: eventId },
        select: selectEventDetailForWeb,
      })
    );

    if (!row) {
      res.status(404).json({ error: 'Event not found' });
      return;
    }

    const favoriteIdsByEventId = await resolveEventFavoriteIds(userId, [row.id]);
    const rowWithFavorite = attachEventFavoriteState([row], favoriteIdsByEventId)[0];
    const complianceUser = await resolveRegionalComplianceUser(userId);

    ok(res, mapEvent(rowWithFavorite, complianceUser, userId ?? null, viewerRole));
  } catch (error) {
    console.error('BFF web event detail error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/events/:id/summary', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = authReq.user?.userId;
    const viewerRole = authReq.user?.role ?? null;
    const eventId = req.params.id as string;
    const row = await attachContributionInfo(
      prisma,
      'event',
      await prisma.event.findUnique({
        where: { id: eventId },
        select: selectEventSummaryForIOS,
      })
    );

    if (!row) {
      res.status(404).json({ error: 'Event not found' });
      return;
    }

    const favoriteIdsByEventId = await resolveEventFavoriteIds(userId, [row.id]);
    const rowWithFavorite = attachEventFavoriteState([row], favoriteIdsByEventId)[0];
    const complianceUser = await resolveRegionalComplianceUser(userId);

    ok(res, mapEvent(rowWithFavorite, complianceUser, userId ?? null, viewerRole));
  } catch (error) {
    console.error('BFF iOS event summary error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/events/:id/contributors', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const eventId = req.params.id as string;
    const event = await prisma.event.findUnique({
      where: { id: eventId },
      select: {
        id: true,
        createdAt: true,
        updatedAt: true,
        organizer: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
      },
    });
    if (!event) {
      res.status(404).json({ error: 'Event not found' });
      return;
    }

    const contributors = await fetchContributorEntriesForEntity(prisma, 'event', eventId);
    const resolvedContributors = contributors.length > 0
      ? contributors
      : eventContributorInfoFromRow(event).entries;
    ok(res, {
      items: resolvedContributors.map((item) => ({
        user: mapUserLite(item),
        role: item.role,
        firstContributedAt: item.firstContributedAt,
        lastContributedAt: item.lastContributedAt,
        contributionCount: item.contributionCount,
        firstSubmissionId: item.firstSubmissionId,
        lastSubmissionId: item.lastSubmissionId,
        lastContributionSource: item.lastContributionSource,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
      })),
      summary: buildContributorSummary(resolvedContributors),
    });
  } catch (error) {
    console.error('BFF event contributors error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/events/:id/lineup', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const eventId = req.params.id as string;
    const event = await prisma.event.findUnique({
      where: { id: eventId },
      select: selectEventLineupForWeb,
    });
    if (!event) {
      res.status(404).json({ error: 'Event not found' });
      return;
    }
    ok(res, { items: mapEventLineupArtists(event.canonicalArtists) });
  } catch (error) {
    console.error('BFF web event lineup error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/events/:id/lineup', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    const eventId = req.params.id as string;
    const event = await prisma.event.findUnique({
      where: { id: eventId },
      select: { id: true, organizerId: true },
    });
    if (!event) {
      res.status(404).json({ error: 'Event not found' });
      return;
    }
    const canManage = await canUserManageEvent(userId, authReq.user?.role ?? null, event.organizerId, authReq.user?.email ?? null);
    if (!canManage) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const [artist] = normalizeLineupArtistsInput([req.body || {}], []);
    if (!artist) {
      res.status(400).json({ error: 'djName is required' });
      return;
    }
    const createdArtistId = crypto.randomUUID();
    const created = await prisma.$transaction(async (tx) => {
      const snapshot = await loadCanonicalEventLineupSnapshot(tx, eventId);
      await syncCanonicalEventLineupAndTimetable(tx, eventId, snapshot.slots, [
        ...snapshot.artists,
        {
          id: createdArtistId,
          djId: artist.djId,
          memberDjIds: artist.memberDjIds,
          memberNames: artist.memberNames,
          djName: artist.djName,
          sortOrder: artist.sortOrder,
        },
      ]);
      return tx.event.findUnique({
        where: { id: eventId },
        include: includeEventForWeb,
      });
    });
    ok(res, { item: mapEvent(created).lineupArtists.find((item: any) => item.id === createdArtistId) || null });
  } catch (error) {
    console.error('BFF web add lineup artist error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.patch('/events/:id/lineup/:artistId', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    const eventId = req.params.id as string;
    const artistId = req.params.artistId as string;
    const event = await prisma.event.findUnique({
      where: { id: eventId },
      select: { id: true, organizerId: true },
    });
    if (!event) {
      res.status(404).json({ error: 'Event not found' });
      return;
    }
    const canManage = await canUserManageEvent(userId, authReq.user?.role ?? null, event.organizerId, authReq.user?.email ?? null);
    if (!canManage) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }
    const existingEvent = await prisma.event.findUnique({
      where: { id: eventId },
      include: includeEventForWeb,
    });
    const existing = existingEvent ? mapEvent(existingEvent).lineupArtists.find((item: any) => item.id === artistId) : null;
    if (!existing) {
      res.status(404).json({ error: 'Lineup artist not found' });
      return;
    }
    const body = req.body as Record<string, unknown>;
    const [artist] = normalizeLineupArtistsInput([{ ...existing, ...body }], []);
    if (!artist) {
      res.status(400).json({ error: 'djName is required' });
      return;
    }
    const updated = await prisma.$transaction(async (tx) => {
      const snapshot = await loadCanonicalEventLineupSnapshot(tx, eventId);
      const nextArtists = snapshot.artists.map((item) => (
            item.id === artistId
          ? {
              ...item,
              djId: Object.prototype.hasOwnProperty.call(body, 'djId') || Object.prototype.hasOwnProperty.call(body, 'memberDjIds') ? artist.djId : item.djId,
              memberDjIds: Object.prototype.hasOwnProperty.call(body, 'djId') || Object.prototype.hasOwnProperty.call(body, 'memberDjIds') ? artist.memberDjIds : item.memberDjIds,
              memberNames: Object.prototype.hasOwnProperty.call(body, 'memberNames') ? artist.memberNames : item.memberNames,
              djName: Object.prototype.hasOwnProperty.call(body, 'djName') || Object.prototype.hasOwnProperty.call(body, 'name') || Object.prototype.hasOwnProperty.call(body, 'musician') ? artist.djName : item.djName,
              sortOrder: Object.prototype.hasOwnProperty.call(body, 'sortOrder') ? artist.sortOrder : item.sortOrder,
            }
          : item
      ));
      await syncCanonicalEventLineupAndTimetable(tx, eventId, snapshot.slots, nextArtists);
      return tx.event.findUnique({
        where: { id: eventId },
        include: includeEventForWeb,
      });
    });
    ok(res, { item: mapEvent(updated).lineupArtists.find((item: any) => item.id === artistId) || null });
  } catch (error) {
    console.error('BFF web update lineup artist error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.delete('/events/:id/lineup/:artistId', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    const eventId = req.params.id as string;
    const artistId = req.params.artistId as string;
    const event = await prisma.event.findUnique({
      where: { id: eventId },
      select: { id: true, organizerId: true },
    });
    if (!event) {
      res.status(404).json({ error: 'Event not found' });
      return;
    }
    const canManage = await canUserManageEvent(userId, authReq.user?.role ?? null, event.organizerId, authReq.user?.email ?? null);
    if (!canManage) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }
    const snapshot = await loadCanonicalEventLineupSnapshot(prisma, eventId);
    const existing = snapshot.artists.find((item) => item.id === artistId);
    if (!existing) {
      res.status(404).json({ error: 'Lineup artist not found' });
      return;
    }
    const slotCount = snapshot.slots.filter((slot) => slot.lineupArtistId === artistId).length;
    if (slotCount > 0) {
      res.status(409).json({ error: `该 DJ 下还有 ${slotCount} 条时间表演出，请先删除时间表条目后再删除阵容。` });
      return;
    }
    await prisma.$transaction(async (tx) => {
      await syncCanonicalEventLineupAndTimetable(
        tx,
        eventId,
        snapshot.slots,
        snapshot.artists.filter((item) => item.id !== artistId)
      );
    });
    ok(res, { deleted: true });
  } catch (error) {
    console.error('BFF web delete lineup artist error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/events/:id/timetable', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const eventId = req.params.id as string;
    const event = await prisma.event.findUnique({
      where: { id: eventId },
      select: selectEventTimetableForWeb,
    });
    if (!event) {
      res.status(404).json({ error: 'Event not found' });
      return;
    }
    ok(res, {
      items: mapEventTimetableSlots(event.performances).map((slot: any) => ({
        id: slot.id,
        eventId: slot.eventId,
        lineupArtistId: slot.lineupArtistId ?? null,
        eventDayId: slot.eventDayId ?? null,
        weekIndex: typeof slot.weekIndex === 'number' ? slot.weekIndex : null,
        dayIndexInWeek: typeof slot.dayIndexInWeek === 'number' ? slot.dayIndexInWeek : null,
        overallDayIndex: typeof slot.overallDayIndex === 'number' ? slot.overallDayIndex : null,
        localDate: slot.localDate ?? null,
        djId: slot.djId,
        memberDjIds: Array.isArray(slot.memberDjIds) ? slot.memberDjIds : (slot.djId ? [slot.djId] : []),
        djName: slot.djName,
        djNameSnapshot: slot.djNameSnapshot ?? slot.djName,
        festivalDayIndex: typeof slot.festivalDayIndex === 'number' ? slot.festivalDayIndex : null,
        stageName: slot.stageName,
        sortOrder: slot.sortOrder,
        startTime: slot.startTime,
        endTime: slot.endTime,
        dj: mapDJLiteForEvent(slot.dj),
        djs: Array.isArray(slot.djs) ? slot.djs.map(mapDJLiteForEvent).filter(Boolean) : [],
      })),
    });
  } catch (error) {
    console.error('BFF web event timetable error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/events/:id/timetable', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    const eventId = req.params.id as string;
    const event = await prisma.event.findUnique({
      where: { id: eventId },
      select: {
        id: true,
        organizerId: true,
        scheduleMode: true,
        dayRolloverHour: true,
        timeZone: true,
        weeks: {
          orderBy: [{ sortOrder: 'asc' as const }, { weekIndex: 'asc' as const }],
          select: {
            weekIndex: true,
            label: true,
            startDate: true,
            endDate: true,
            sortOrder: true,
          },
        },
        eventDays: {
          orderBy: [{ sortOrder: 'asc' as const }, { overallDayIndex: 'asc' as const }],
          select: {
            eventDayId: true,
            weekIndex: true,
            dayIndexInWeek: true,
            overallDayIndex: true,
            label: true,
            weekday: true,
            date: true,
            sortOrder: true,
          },
        },
      },
    });
    if (!event) {
      res.status(404).json({ error: 'Event not found' });
      return;
    }
    const canManage = await canUserManageEvent(userId, authReq.user?.role ?? null, event.organizerId, authReq.user?.email ?? null);
    if (!canManage) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }
    const scheduleContext = buildSubmittedEventScheduleContextFromEvent(event);
    const [slot] = normalizeSubmittedTimetableSlots([req.body || {}], scheduleContext);
    if (!slot) {
      res.status(400).json({ error: 'Valid timetable slot is required' });
      return;
    }
    const createdSlotId = crypto.randomUUID();
    const created = await prisma.$transaction(async (tx) => {
      const snapshot = await loadCanonicalEventLineupSnapshot(tx, eventId);
      let lineupArtistId = snapshot.artists.find((artist) => (
        (slot.djId && artist.djId === slot.djId) || artist.djName === slot.djName
      ))?.id ?? null;
      const nextArtists = [...snapshot.artists];
      if (!lineupArtistId) {
        lineupArtistId = crypto.randomUUID();
        nextArtists.push({
          id: lineupArtistId,
          djId: slot.djId,
          memberDjIds: slot.memberDjIds,
          memberNames: splitCollaborativeLineupName(slot.djName),
          djName: slot.djName,
          sortOrder: nextArtists.length + 1,
        });
      }
      await syncCanonicalEventLineupAndTimetable(tx, eventId, [
        ...snapshot.slots,
        {
          id: createdSlotId,
          lineupArtistId,
          eventDayId: slot.eventDayId ?? null,
          weekIndex: slot.weekIndex ?? null,
          dayIndexInWeek: slot.dayIndexInWeek ?? null,
          overallDayIndex: slot.overallDayIndex ?? null,
          localDate: slot.localDate ?? null,
          djId: slot.djId,
          memberDjIds: slot.memberDjIds,
          djName: slot.djName,
          stageName: slot.stageName,
          festivalDayIndex: slot.festivalDayIndex,
          startTime: slot.startTime,
          endTime: slot.endTime,
          sortOrder: slot.sortOrder || snapshot.slots.length + 1,
        },
      ], nextArtists);
      return tx.event.findUnique({
        where: { id: eventId },
        include: includeEventForWeb,
      });
    });
    ok(res, { item: mapEvent(created).timetableSlots.find((item: any) => item.id === createdSlotId) || null });
  } catch (error) {
    if (error instanceof EventSubmissionValidationError) {
      res.status(400).json({ error: error.message, code: error.code });
      return;
    }
    console.error('BFF web add timetable slot error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.patch('/events/:id/timetable/:slotId', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    const eventId = req.params.id as string;
    const slotId = req.params.slotId as string;
    const event = await prisma.event.findUnique({
      where: { id: eventId },
      select: {
        id: true,
        organizerId: true,
        scheduleMode: true,
        dayRolloverHour: true,
        timeZone: true,
        weeks: {
          orderBy: [{ sortOrder: 'asc' as const }, { weekIndex: 'asc' as const }],
          select: {
            weekIndex: true,
            label: true,
            startDate: true,
            endDate: true,
            sortOrder: true,
          },
        },
        eventDays: {
          orderBy: [{ sortOrder: 'asc' as const }, { overallDayIndex: 'asc' as const }],
          select: {
            eventDayId: true,
            weekIndex: true,
            dayIndexInWeek: true,
            overallDayIndex: true,
            label: true,
            weekday: true,
            date: true,
            sortOrder: true,
          },
        },
      },
    });
    if (!event) {
      res.status(404).json({ error: 'Event not found' });
      return;
    }
    const canManage = await canUserManageEvent(userId, authReq.user?.role ?? null, event.organizerId, authReq.user?.email ?? null);
    if (!canManage) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }
    const eventSnapshot = await loadCanonicalEventLineupSnapshot(prisma, eventId);
    const existing = eventSnapshot.slots.find((slot) => slot.id === slotId);
    if (!existing) {
      res.status(404).json({ error: 'Timetable slot not found' });
      return;
    }
    const merged = {
      djId: existing.djId,
      memberDjIds: existing.memberDjIds,
      djName: existing.djName,
      eventDayId: existing.eventDayId,
      weekIndex: existing.weekIndex,
      dayIndexInWeek: existing.dayIndexInWeek,
      overallDayIndex: existing.overallDayIndex,
      localDate: existing.localDate,
      stageName: existing.stageName,
      festivalDayIndex: existing.festivalDayIndex,
      startTime: existing.startTime,
      endTime: existing.endTime,
      sortOrder: existing.sortOrder,
      ...(req.body || {}),
    };
    const scheduleContext = buildSubmittedEventScheduleContextFromEvent(event);
    const [slot] = normalizeSubmittedTimetableSlots([merged], scheduleContext);
    if (!slot) {
      res.status(400).json({ error: 'Valid timetable slot is required' });
      return;
    }
    const updated = await prisma.$transaction(async (tx) => {
      const snapshot = await loadCanonicalEventLineupSnapshot(tx, eventId);
      let lineupArtistId = snapshot.artists.find((artist) => (
        (slot.djId && artist.djId === slot.djId) || artist.djName === slot.djName
      ))?.id ?? existing.lineupArtistId ?? null;
      const nextArtists = [...snapshot.artists];
      if (!lineupArtistId) {
        lineupArtistId = crypto.randomUUID();
        nextArtists.push({
          id: lineupArtistId,
          djId: slot.djId,
          memberDjIds: slot.memberDjIds,
          memberNames: splitCollaborativeLineupName(slot.djName),
          djName: slot.djName,
          sortOrder: nextArtists.length + 1,
        });
      }
      await syncCanonicalEventLineupAndTimetable(
        tx,
        eventId,
        snapshot.slots.map((item) => (
          item.id === slotId
            ? {
                ...item,
                lineupArtistId,
                eventDayId: slot.eventDayId ?? null,
                weekIndex: slot.weekIndex ?? null,
                dayIndexInWeek: slot.dayIndexInWeek ?? null,
                overallDayIndex: slot.overallDayIndex ?? null,
                localDate: slot.localDate ?? null,
                djId: slot.djId,
                memberDjIds: slot.memberDjIds,
                djName: slot.djName,
                stageName: slot.stageName,
                festivalDayIndex: slot.festivalDayIndex,
                startTime: slot.startTime,
                endTime: slot.endTime,
                sortOrder: slot.sortOrder,
              }
            : item
        )),
        nextArtists
      );
      return tx.event.findUnique({
        where: { id: eventId },
        include: includeEventForWeb,
      });
    });
    ok(res, { item: mapEvent(updated).timetableSlots.find((item: any) => item.id === slotId) || null });
  } catch (error) {
    if (error instanceof EventSubmissionValidationError) {
      res.status(400).json({ error: error.message, code: error.code });
      return;
    }
    console.error('BFF web update timetable slot error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.delete('/events/:id/timetable/:slotId', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    const eventId = req.params.id as string;
    const slotId = req.params.slotId as string;
    const event = await prisma.event.findUnique({
      where: { id: eventId },
      select: { id: true, organizerId: true },
    });
    if (!event) {
      res.status(404).json({ error: 'Event not found' });
      return;
    }
    const canManage = await canUserManageEvent(userId, authReq.user?.role ?? null, event.organizerId, authReq.user?.email ?? null);
    if (!canManage) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }
    const snapshot = await loadCanonicalEventLineupSnapshot(prisma, eventId);
    const existing = snapshot.slots.find((slot) => slot.id === slotId);
    if (!existing) {
      res.status(404).json({ error: 'Timetable slot not found' });
      return;
    }
    await prisma.$transaction(async (tx) => {
      await syncCanonicalEventLineupAndTimetable(
        tx,
        eventId,
        snapshot.slots.filter((slot) => slot.id !== slotId),
        snapshot.artists
      );
    });
    ok(res, { deleted: true });
  } catch (error) {
    console.error('BFF web delete timetable slot error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/events/:id/rating-events', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const eventId = req.params.id as string;
    const page = normalizePage(req.query.page, 1);
    const limit = normalizeLimit(req.query.limit, 20, 100);
    const skip = (page - 1) * limit;
    const sourceEvent = await prisma.event.findUnique({
      where: { id: eventId },
      select: { id: true },
    });

    if (!sourceEvent) {
      res.status(404).json({ error: 'Event not found' });
      return;
    }

    const [rows, total] = await Promise.all([
      prisma.ratingEvent.findMany({
        where: { sourceEventId: eventId },
        orderBy: [{ createdAt: 'desc' }],
        include: {
          createdBy: {
            select: { id: true, username: true, displayName: true, avatarUrl: true },
          },
          units: {
            orderBy: [{ createdAt: 'asc' }],
            include: {
              comments: {
                select: { score: true },
              },
              createdBy: {
                select: { id: true, username: true, displayName: true, avatarUrl: true },
              },
            },
          },
        },
        skip,
        take: limit,
      }),
      prisma.ratingEvent.count({
        where: { sourceEventId: eventId },
      }),
    ]);

    const rowsWithLinkedUnits = await Promise.all(
      rows.map(async (row) => ({
        ...row,
        units: await attachLinkedDJsToRatingUnits(row.units as any[]),
      }))
    );

    ok(res, { items: rowsWithLinkedUnits.map(mapRatingEvent) }, {
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit) || 1,
    });
  } catch (error) {
    console.error('BFF web event rating events error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

void [
  validateSubmittedEventTimezoneSelection,
  parseEventReferenceLinks,
  parseEventSocialLinks,
  normalizeEventStartDate,
  normalizeEventEndDate,
  normalizeEventStageOrder,
  syncEventLineupAndTimetable,
  deleteSingleEventOssObjectIfOwned,
  normalizeEventWikiFestivalId,
];

router.post('/events/lineup-timetable-alignment/preview', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const body = req.body as Record<string, unknown>;
    const scheduleContext = normalizeSubmittedEventScheduleContext(body);

    const issue = validateEventLineupTimetableAlignment(
      body as unknown as Prisma.JsonObject,
      scheduleContext
    );
    const alignedLineupArtists = buildAlignedLineupArtistsFromTimetablePayload(
      body as unknown as Prisma.JsonObject,
      scheduleContext
    );

    ok(res, {
      aligned: issue === null,
      issue,
      message: issue ? formatEventLineupTimetableAlignmentError(issue) : null,
      lineupArtists: alignedLineupArtists.map(mapAlignedLineupArtistForPayload),
    });
  } catch (error) {
    if (error instanceof EventSubmissionValidationError) {
      res.status(400).json({ error: error.message, code: error.code });
      return;
    }
    console.error('BFF web lineup timetable alignment preview error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/events', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    const body = req.body as Record<string, unknown>;
    const name = String(body.name || '').trim();
    if (!name) {
      res.status(400).json({ error: 'name is required' });
      return;
    }
    normalizeSubmittedEventScheduleContext(body);

    const submittedImageAssets = parseEventImageAssets(body.imageAssets);
    if (!hasRequiredEventPrimaryImageAsset(submittedImageAssets)) {
      res.status(400).json({ error: 'At least one poster, lineup, or cover image is required' });
      return;
    }

    const normalizedBody = normalizeSubmittedEventLineupToTimetable(body);
    const idempotencyKey = cleanIdempotencyKey(body.idempotencyKey) || cleanIdempotencyKey(req.get('Idempotency-Key'));

    if (resolveEventMutationRoute(authReq.user?.role ?? null) === 'direct_apply') {
      const applied = await applyEventDirectly({
        submitterId: userId,
        title: name,
        payload: normalizedBody,
        idempotencyKey,
      });
      await invalidateEventAdminSummaryCachesBestEffort();
      await upsertEventReleasePublishTaskBestEffort({
        actorUserId: userId,
        operationType: 'create',
        sourceRoute: '/v1/events',
        event: applied.event,
      });
      ok(res, applied.event);
      return;
    }

    const submission = await createPendingContentSubmission({
      submitterId: userId,
      entityType: 'event',
      title: name,
      payload: normalizedBody,
      idempotencyKey,
    });
    acceptedSubmission(res, submission, '活动任务已提交，当前正在处理中，后续状态会通过通知更新');
    return;
  } catch (error) {
    if (error instanceof EventSubmissionValidationError) {
      console.warn('BFF web create event validation error:', {
        message: error.message,
        code: error.code,
      });
      res.status(400).json({
        error: error.message,
        code: error.code,
      });
      return;
    }
    if (error instanceof ActiveEventEditSubmissionError) {
      res.status(409).json({
        error: error.message,
        code: error.code,
        details: error.details,
      });
      return;
    }
    console.error('BFF web create event error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.patch('/events/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const eventId = req.params.id as string;
    const existing = await prisma.event.findUnique({
      where: { id: eventId },
      select: {
        id: true,
        organizerId: true,
        wikiFestivalId: true,
        startDate: true,
        endDate: true,
        timeZone: true,
        startTime: true,
        endTime: true,
        dayRolloverHour: true,
        coverImageUrl: true,
        lineupImageUrl: true,
        imageAssets: true,
      },
    });

    if (!existing) {
      res.status(404).json({ error: 'Event not found' });
      return;
    }

    const canManage = await canUserManageEvent(
      userId,
      authReq.user?.role ?? null,
      existing.organizerId,
      authReq.user?.email ?? null
    );
    if (!canManage) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const body = req.body as Record<string, unknown>;
    const submittedName = typeof body.name === 'string' ? body.name.trim() : '';
    if (!submittedName) {
      res.status(400).json({ error: 'Event name is required' });
      return;
    }
    normalizeSubmittedEventScheduleContext(body);

    const submittedImageAssets = parseEventImageAssets(body.imageAssets);
    if (!hasRequiredEventPrimaryImageAsset(submittedImageAssets)) {
      res.status(400).json({ error: 'At least one poster, lineup, or cover image is required' });
      return;
    }

    const normalizedBody = {
      ...normalizeSubmittedEventLineupToTimetable({
        ...body,
        targetEventId: eventId,
      }),
      targetEventId: eventId,
    };
    const idempotencyKey = cleanIdempotencyKey(body.idempotencyKey) || cleanIdempotencyKey(req.get('Idempotency-Key'));

    if (resolveEventMutationRoute(authReq.user?.role ?? null) === 'direct_apply') {
      const applied = await applyEventDirectly({
        submitterId: userId,
        title: submittedName,
        payload: normalizedBody,
        idempotencyKey,
      });
      await invalidateEventAdminSummaryCachesBestEffort();
      await upsertEventReleasePublishTaskBestEffort({
        actorUserId: userId,
        operationType: 'edit',
        sourceRoute: `/v1/events/${eventId}`,
        event: applied.event,
      });
      ok(res, applied.event);
      return;
    }

    const submission = await createPendingContentSubmission({
      submitterId: userId,
      entityType: 'event',
      title: submittedName,
      payload: normalizedBody,
      idempotencyKey,
    });
    acceptedSubmission(res, submission, '活动编辑任务已提交，当前正在处理中，后续状态会通过通知更新');
  } catch (error) {
    if (error instanceof EventSubmissionValidationError) {
      console.warn('BFF web update event validation error:', {
        eventId: req.params.id as string,
        message: error.message,
        code: error.code,
      });
      res.status(400).json({
        error: error.message,
        code: error.code,
      });
      return;
    }
    if (error instanceof ActiveEventEditSubmissionError) {
      res.status(409).json({
        error: error.message,
        code: error.code,
        details: error.details,
      });
      return;
    }
    console.error('BFF web update event error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.delete('/events/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const eventId = req.params.id as string;
    const existing = await prisma.event.findUnique({
      where: { id: eventId },
      select: { id: true, organizerId: true },
    });

    if (!existing) {
      res.status(404).json({ error: 'Event not found' });
      return;
    }

    const canManage = await canUserManageEvent(
      userId,
      authReq.user?.role ?? null,
      existing.organizerId,
      authReq.user?.email ?? null
    );
    if (!canManage) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const eventAssets = await prisma.event.findUnique({
      where: { id: eventId },
      select: { coverImageUrl: true, lineupImageUrl: true, imageAssets: true },
    });
    await prisma.event.delete({ where: { id: eventId } });
    await notificationCenterService.deleteAdminPublishTasksByEntity({
      entityType: 'event',
      entityId: eventId,
      taskTypes: ['event_release'],
    });
    await notificationCenterService.deleteAdminContentHistoryByEntity({
      entityType: 'event',
      entityId: eventId,
    });
    await invalidateEventAdminSummaryCachesBestEffort();
    await mediaAssetService.markDeletedByUrl(eventAssets?.coverImageUrl);
    await mediaAssetService.markDeletedByUrl(eventAssets?.lineupImageUrl);
    const imageAssets = Array.isArray(eventAssets?.imageAssets) ? eventAssets?.imageAssets : [];
    for (const asset of imageAssets) {
      if (asset && typeof asset === 'object' && 'url' in asset) {
        await mediaAssetService.markDeletedByUrl((asset as { url?: unknown }).url as string | null | undefined);
      }
    }
    await deleteEventOssFolder(eventId);
    ok(res, { success: true });
  } catch (error) {
    console.error('BFF web delete event error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/events/upload-image', optionalAuth, eventUploadTimingStart, eventImageUpload.single('image'), async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest & { eventUploadTiming?: EventUploadTimingContext };
    const timing = authReq.eventUploadTiming ?? {
      requestId: nextEventUploadRequestId(),
      startedAtMs: Date.now(),
      startedAtHr: process.hrtime.bigint(),
    };
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    const file = (req as Request & { file?: Express.Multer.File }).file;
    if (!file) {
      res.status(400).json({ error: 'No file uploaded' });
      return;
    }
    const formBody = req.body as Record<string, unknown>;
    const eventId = typeof formBody.eventId === 'string' ? formBody.eventId.trim() : '';
    const draftId = typeof formBody.draftId === 'string' ? formBody.draftId.trim() : '';
    const usage = typeof formBody.usage === 'string' ? formBody.usage.trim() : '';

    console.info('[event-upload] route.start', {
      requestId: timing.requestId,
      elapsedMs: Number(elapsedMsFrom(timing.startedAtHr).toFixed(1)),
      userId,
      eventId: eventId || null,
      draftId: draftId || null,
      usage: usage || null,
      mimeType: file.mimetype || null,
      sizeBytes: file.size,
      originalName: file.originalname || null,
    });

    if (!postMediaOssClient) {
      await fs.promises.unlink(file.path).catch(() => undefined);
      res.status(503).json({ error: 'OSS is not configured for rating image upload' });
      return;
    }

    if (eventId) {
      const eventLookupStartedAt = process.hrtime.bigint();
      const event = await prisma.event.findUnique({
        where: { id: eventId },
        select: { id: true, organizerId: true },
      });
      const eventLookupDurationMs = elapsedMsFrom(eventLookupStartedAt);

      if (!event) {
        await fs.promises.unlink(file.path).catch(() => undefined);
        res.status(404).json({ error: 'Event not found' });
        return;
      }

      const permissionCheckStartedAt = process.hrtime.bigint();
      const canManage = await canUserManageEvent(
        userId,
        authReq.user?.role ?? null,
        event.organizerId,
        authReq.user?.email ?? null
      );
      const permissionCheckDurationMs = elapsedMsFrom(permissionCheckStartedAt);
      if (!canManage) {
        await fs.promises.unlink(file.path).catch(() => undefined);
        res.status(403).json({ error: 'Forbidden' });
        return;
      }

      const uploaded = await uploadEventMediaToOss(file, eventId, usage || null, userId, {
        requestId: timing.requestId,
      });
      const totalDurationMs = elapsedMsFrom(timing.startedAtHr);
      const approximateIngressDurationMs = Math.max(
        0,
        totalDurationMs - eventLookupDurationMs - permissionCheckDurationMs
      );
      console.info('[event-upload] route.success', {
        requestId: timing.requestId,
        mode: 'event',
        eventId,
        usage: usage || null,
        sizeBytes: file.size,
        eventLookupDurationMs: Number(eventLookupDurationMs.toFixed(1)),
        permissionCheckDurationMs: Number(permissionCheckDurationMs.toFixed(1)),
        approximateIngressDurationMs: Number(approximateIngressDurationMs.toFixed(1)),
        totalDurationMs: Number(totalDurationMs.toFixed(1)),
        uploadedUrl: uploaded.url,
      });
      ok(res, uploaded);
      return;
    }

    if (draftId) {
      const uploaded = await uploadEventDraftMediaToOss(file, userId, draftId, usage || null, {
        requestId: timing.requestId,
      });
      const totalDurationMs = elapsedMsFrom(timing.startedAtHr);
      console.info('[event-upload] route.success', {
        requestId: timing.requestId,
        mode: 'draft',
        draftId,
        usage: usage || null,
        sizeBytes: file.size,
        approximateIngressDurationMs: Number(totalDurationMs.toFixed(1)),
        totalDurationMs: Number(totalDurationMs.toFixed(1)),
        uploadedUrl: uploaded.url,
      });
      ok(res, uploaded);
      return;
    }

    if (looksLikePostMediaName(file.originalname || '', 'image')) {
      const uploaded = await uploadPostMediaToOss(file, 'image', null, userId);
      ok(res, uploaded);
      return;
    }

    await fs.promises.unlink(file.path).catch(() => undefined);
    res.status(503).json({ error: 'OSS is required for event image upload' });
    return;
  } catch (error) {
    const authReq = req as BFFAuthRequest & { eventUploadTiming?: EventUploadTimingContext };
    const timing = authReq.eventUploadTiming;
    console.error('BFF web upload event image error:', {
      requestId: timing?.requestId ?? null,
      totalDurationMs: timing ? Number(elapsedMsFrom(timing.startedAtHr).toFixed(1)) : null,
      error,
    });
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/events/delete-images', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const body = (req.body ?? {}) as Record<string, unknown>;
    const eventId = typeof body.eventId === 'string' ? body.eventId.trim() : '';
    const draftId = typeof body.draftId === 'string' ? body.draftId.trim() : '';
    const urls = Array.isArray(body.urls)
      ? body.urls
          .map((value) => (typeof value === 'string' ? value.trim() : ''))
          .filter(Boolean)
      : [];

    if (!eventId && !draftId) {
      res.status(400).json({ error: 'eventId or draftId is required' });
      return;
    }
    if (eventId && draftId) {
      res.status(400).json({ error: 'eventId and draftId cannot be provided together' });
      return;
    }
    if (!urls.length) {
      ok(res, { success: true });
      return;
    }

    if (draftId) {
      const assets = await prisma.mediaAsset.findMany({
        where: {
          ownerType: 'event-draft',
          ownerId: draftId,
          uploadedById: userId,
          url: { in: urls },
          status: { in: ['active', 'replaced'] },
        },
        select: {
          id: true,
          url: true,
          objectKey: true,
        },
      });

      const keys = assets
        .filter((asset) => typeof asset.objectKey === 'string' && isEventDraftOssObjectKey(asset.objectKey, userId, draftId))
        .map((asset) => asset.objectKey as string);

      for (const asset of assets) {
        await mediaAssetService.markDeletedByUrl(asset.url);
      }
      await deleteOssObjects(keys);
      ok(res, { success: true });
      return;
    }

    const event = await prisma.event.findUnique({
      where: { id: eventId },
      select: { id: true, organizerId: true, coverImageUrl: true, lineupImageUrl: true, imageAssets: true },
    });
    if (!event) {
      res.status(404).json({ error: 'Event not found' });
      return;
    }

    const canManage = await canUserManageEvent(
      userId,
      authReq.user?.role ?? null,
      event.organizerId,
      authReq.user?.email ?? null
    );
    if (!canManage) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const protectedURLs = new Set<string>();
    if (typeof event.coverImageUrl === 'string' && event.coverImageUrl.trim()) {
      protectedURLs.add(event.coverImageUrl.trim().toLowerCase());
    }
    if (typeof event.lineupImageUrl === 'string' && event.lineupImageUrl.trim()) {
      protectedURLs.add(event.lineupImageUrl.trim().toLowerCase());
    }
    const persistedAssets = parseEventImageAssets(event.imageAssets ?? []);
    for (const asset of persistedAssets) {
      const value = String(asset.url || '').trim().toLowerCase();
      if (value) protectedURLs.add(value);
    }

    const deletableURLs = urls.filter((url) => !protectedURLs.has(url.toLowerCase()));
    if (!deletableURLs.length) {
      ok(res, { success: true });
      return;
    }

    const assets = await prisma.mediaAsset.findMany({
      where: {
        ownerType: 'event',
        ownerId: eventId,
        url: { in: deletableURLs },
        status: { in: ['active', 'replaced'] },
      },
      select: {
        id: true,
        url: true,
        objectKey: true,
      },
    });

    const keys = assets
      .filter((asset) => typeof asset.objectKey === 'string' && isEventOssObjectKey(asset.objectKey, eventId))
      .map((asset) => asset.objectKey as string);

    for (const asset of assets) {
      await mediaAssetService.markDeletedByUrl(asset.url);
    }
    await deleteOssObjects(keys);
    ok(res, { success: true });
  } catch (error) {
    console.error('BFF web delete event images error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/wiki/brands/upload-image', optionalAuth, wikiBrandImageUpload.single('image'), async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    const viewerRole = authReq.user?.role ?? null;

    const file = (req as Request & { file?: Express.Multer.File }).file;
    if (!file) {
      res.status(400).json({ error: 'No file uploaded' });
      return;
    }

    if (!postMediaOssClient) {
      await fs.promises.unlink(file.path).catch(() => undefined);
      res.status(503).json({ error: 'OSS is not configured for wiki brand image upload' });
      return;
    }

    const formBody = req.body as Record<string, unknown>;
    const brandIdRaw = typeof formBody.brandId === 'string' ? formBody.brandId.trim() : '';
    const draftIdRaw = typeof formBody.draftId === 'string' ? formBody.draftId.trim() : '';
    const usage = parseWikiBrandImageUsage(formBody.usage);
    const sort = parseOptionalImageSort(formBody.sort);
    const brandId = brandIdRaw.length > 0 ? brandIdRaw : null;
    const draftId = draftIdRaw.length > 0 ? draftIdRaw : null;

    if (brandId && draftId) {
      await fs.promises.unlink(file.path).catch(() => undefined);
      res.status(400).json({ error: 'brandId and draftId cannot be provided together' });
      return;
    }
    if (!brandId && !draftId) {
      await fs.promises.unlink(file.path).catch(() => undefined);
      res.status(400).json({ error: 'brandId or draftId is required' });
      return;
    }
    if (!usage) {
      await fs.promises.unlink(file.path).catch(() => undefined);
      res.status(400).json({ error: 'usage must be avatar, background, poster, proof, or other' });
      return;
    }

    if (draftId) {
      const uploaded = await uploadWikiBrandDraftMediaToOss(file, userId, draftId, usage, sort);
      ok(res, uploaded);
      return;
    }

    const existing = await prisma.wikiFestival.findUnique({
      where: { id: brandId! },
      include: {
        contributors: {
          select: { userId: true },
        },
      },
    });
    if (!existing) {
      await fs.promises.unlink(file.path).catch(() => undefined);
      res.status(404).json({ error: 'Festival not found' });
      return;
    }

    const isContributor = existing.contributors.some((item) => item.userId === userId);
    const canEdit = viewerRole === 'admin' || isContributor;
    if (!canEdit) {
      await fs.promises.unlink(file.path).catch(() => undefined);
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const uploaded = await uploadWikiBrandMediaToOss(file, brandId, usage, userId, sort);
    ok(res, uploaded);
  } catch (error) {
    if (error instanceof WikiBrandImageValidationError) {
      res.status(400).json({ error: error.message });
      return;
    }
    console.error('BFF web upload wiki brand image error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/wiki/brands/delete-images', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    const viewerRole = authReq.user?.role ?? null;

    const body = (req.body ?? {}) as Record<string, unknown>;
    const brandId = typeof body.brandId === 'string' ? body.brandId.trim() : '';
    const draftId = typeof body.draftId === 'string' ? body.draftId.trim() : '';
    const urls = Array.isArray(body.urls)
      ? body.urls
          .map((value) => (typeof value === 'string' ? value.trim() : ''))
          .filter(Boolean)
      : [];

    if (!brandId && !draftId) {
      res.status(400).json({ error: 'brandId or draftId is required' });
      return;
    }
    if (brandId && draftId) {
      res.status(400).json({ error: 'brandId and draftId cannot be provided together' });
      return;
    }
    if (!urls.length) {
      ok(res, { success: true });
      return;
    }

    if (draftId) {
      const assets = await prisma.mediaAsset.findMany({
        where: {
          ownerType: 'wiki_brand_draft',
          ownerId: draftId,
          uploadedById: userId,
          url: { in: urls },
          status: { in: ['active', 'replaced'] },
        },
        select: {
          id: true,
          url: true,
          objectKey: true,
        },
      });

      const keys = assets
        .filter((asset) => typeof asset.objectKey === 'string' && isWikiBrandDraftOssObjectKey(asset.objectKey, userId, draftId))
        .map((asset) => asset.objectKey as string);

      for (const asset of assets) {
        await mediaAssetService.markDeletedByUrl(asset.url);
      }
      await deleteOssObjects(keys);
      ok(res, { success: true });
      return;
    }

    const brand = await prisma.wikiFestival.findUnique({
      where: { id: brandId },
      include: {
        contributors: {
          select: { userId: true },
        },
      },
    });
    if (!brand) {
      res.status(404).json({ error: 'Festival not found' });
      return;
    }

    const isContributor = brand.contributors.some((item) => item.userId === userId);
    const canEdit = viewerRole === 'admin' || isContributor;
    if (!canEdit) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const protectedURLs = new Set<string>();
    if (typeof brand.avatarUrl === 'string' && brand.avatarUrl.trim()) {
      protectedURLs.add(brand.avatarUrl.trim().toLowerCase());
    }
    if (typeof brand.backgroundUrl === 'string' && brand.backgroundUrl.trim()) {
      protectedURLs.add(brand.backgroundUrl.trim().toLowerCase());
    }

    const deletableURLs = urls.filter((url) => !protectedURLs.has(url.toLowerCase()));
    if (!deletableURLs.length) {
      ok(res, { success: true });
      return;
    }

    const assets = await prisma.mediaAsset.findMany({
      where: {
        ownerType: 'wiki_brand',
        ownerId: brandId,
        url: { in: deletableURLs },
        status: { in: ['active', 'replaced'] },
      },
      select: {
        id: true,
        url: true,
        objectKey: true,
      },
    });

    const keys = assets
      .filter((asset) => typeof asset.objectKey === 'string' && isWikiBrandOssObjectKey(asset.objectKey, brandId))
      .map((asset) => asset.objectKey as string);

    for (const asset of assets) {
      await mediaAssetService.markDeletedByUrl(asset.url);
    }
    await deleteOssObjects(keys);
    ok(res, { success: true });
  } catch (error) {
    console.error('BFF web delete wiki brand images error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/events/lineup/import-image', optionalAuth, lineupImportImageUpload.single('image'), async (req: Request, res: Response): Promise<void> => {
  const requestStartedAt = Date.now();
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const file = (req as Request & { file?: Express.Multer.File }).file;
    if (!file) {
      res.status(400).json({ error: 'No file uploaded' });
      return;
    }

    if (!postMediaOssClient) {
      await fs.promises.unlink(file.path).catch(() => undefined);
      res.status(503).json({ error: 'OSS is not configured for lineup image import' });
      return;
    }
    const runtimeCozeConfig = getRuntimeCozeConfig();
    const cozeLineupWorkflowRunUrl = runtimeCozeConfig.lineup.runUrl;
    const cozeLineupWorkflowToken = runtimeCozeConfig.lineup.token;
    if (!cozeLineupWorkflowRunUrl || !cozeLineupWorkflowToken) {
      await fs.promises.unlink(file.path).catch(() => undefined);
      res.status(503).json({ error: 'COZE_LINEUP_WORKFLOW_RUN_URL or COZE_LINEUP_WORKFLOW_TOKEN is not configured' });
      return;
    }

    const uploaded = await uploadLineupImportImageToOss(file);
    try {
      const cozeImageUrl = await ensureCozeAccessibleImageUrl(req, uploaded.url, uploaded.mimeType, 'lineup');
      const imported = await runCozeLineupWorker(cozeImageUrl, uploaded.mimeType);
      console.info('[lineup-import] request.success', {
        userId,
        durationMs: Date.now() - requestStartedAt,
        lineupCount: imported.lineupInfo.length,
      });
      ok(res, imported);
    } finally {
      await deleteOssObjects([uploaded.objectKey]);
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : '';
    console.error('BFF web lineup import image error:', {
      durationMs: Date.now() - requestStartedAt,
      message,
      error,
    });
    if (message.includes('WORKFLOW_TIMEOUT')) {
      res.status(504).json({ error: '阵容识别超时，请稍后重试或换一张更清晰的图' });
      return;
    }
    if (message.startsWith('Coze workflow request failed')) {
      res.status(502).json({ error: '阵容识别服务暂时不可用，请稍后重试' });
      return;
    }
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/feed/upload-image', optionalAuth, feedImageUpload.single('image'), async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;
    const file = (req as Request & { file?: Express.Multer.File }).file;
    if (!file) {
      res.status(400).json({ error: 'No file uploaded' });
      return;
    }

    const formBody = req.body as Record<string, unknown>;
    const postIdRaw = typeof formBody.postId === 'string' ? formBody.postId.trim() : '';
    const newsKeyRaw = typeof formBody.newsKey === 'string' ? formBody.newsKey.trim() : '';
    const scopeKey = postIdRaw
      ? `post-${postIdRaw}`
      : (newsKeyRaw ? `draft-${newsKeyRaw}` : null);

    const uploaded = await uploadPostMediaToOss(file, 'image', scopeKey, userId);
    ok(res, uploaded);
  } catch (error) {
    console.error('BFF web upload feed image error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/feed/upload-video', optionalAuth, feedVideoUpload.single('video'), async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;
    const file = (req as Request & { file?: Express.Multer.File }).file;
    if (!file) {
      res.status(400).json({ error: 'No file uploaded' });
      return;
    }

    const formBody = req.body as Record<string, unknown>;
    const postIdRaw = typeof formBody.postId === 'string' ? formBody.postId.trim() : '';
    const newsKeyRaw = typeof formBody.newsKey === 'string' ? formBody.newsKey.trim() : '';
    const scopeKey = postIdRaw
      ? `post-${postIdRaw}`
      : (newsKeyRaw ? `draft-${newsKeyRaw}` : null);

    const uploaded = await uploadPostMediaToOss(file, 'video', scopeKey, userId);
    ok(res, uploaded);
  } catch (error) {
    console.error('BFF web upload feed video error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/feed/draft-media/cleanup', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const payload = (req.body && typeof req.body === 'object' && !Array.isArray(req.body))
      ? (req.body as Record<string, unknown>)
      : {};

    const newsKeyRaw = typeof payload.newsKey === 'string' ? payload.newsKey.trim() : '';
    const rawUrls = Array.isArray(payload.urls) ? payload.urls : [];
    const urls = rawUrls
      .map((value) => (typeof value === 'string' ? value.trim() : ''))
      .filter(Boolean);

    const keys = new Set<string>();

    if (newsKeyRaw) {
      const folderKeys = await listFeedDraftOssKeys(newsKeyRaw);
      for (const key of folderKeys) {
        if (isFeedNewsOssObjectKey(key)) {
          keys.add(key);
        }
      }
    }

    for (const url of urls) {
      const objectKey = parseOssObjectKeyFromUrl(url);
      if (!objectKey) continue;
      if (!isFeedNewsOssObjectKey(objectKey)) continue;
      keys.add(objectKey);
    }

    const toDelete = Array.from(keys);
    if (toDelete.length > 0) {
      await deleteOssObjects(toDelete);
    }

    ok(res, {
      deleted: toDelete.length,
      byNewsKey: Boolean(newsKeyRaw),
      byUrlCount: urls.length,
    });
  } catch (error) {
    console.error('BFF web cleanup feed draft media error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/djs', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const viewerId = authReq.user?.userId;
    const viewerRole = authReq.user?.role ?? null;
    const page = normalizePage(req.query.page, 1);
    const isOnboardingCandidates = req.query.onboarding === '1' || req.query.onboarding === 'true';
    const limit = normalizeLimit(req.query.limit, 20, isOnboardingCandidates ? 300 : 100);
    const skip = (page - 1) * limit;

    const search = typeof req.query.search === 'string' ? req.query.search.trim() : '';
    const country = typeof req.query.country === 'string' ? req.query.country.trim() : '';
    const letterRaw = typeof req.query.letter === 'string' ? req.query.letter.trim().toUpperCase() : '';
    const letter = /^[A-Z]$/.test(letterRaw) ? letterRaw : '';
    const sortBy = typeof req.query.sortBy === 'string' ? req.query.sortBy : 'followerCount';

    const where: Prisma.DJWhereInput = {};
    if (isOnboardingCandidates) {
      where.soundCloudFollowers = { not: null };
    }
    if (search) {
      const normalizedSearchVariants = Array.from(
        new Set([search, search.toLowerCase(), search.toUpperCase()])
      );
      where.OR = [
        { name: { contains: search, mode: 'insensitive' } },
        { aliases: { hasSome: normalizedSearchVariants } },
        { bio: { contains: search, mode: 'insensitive' } },
      ];
    }
    if (country) where.country = country;
    if (letter) where.name = { startsWith: letter, mode: 'insensitive' };

    let rows: any[] = [];
    let total = 0;

    // When keyword search is present, prioritize textual relevance:
    // name match relevance > aliases match relevance > bio match relevance.
    // `sortBy=random` remains an explicit override.
    if (search && sortBy !== 'random') {
      const searchPattern = `%${search}%`;
      const whereSqlParts: Prisma.Sql[] = [
        Prisma.sql`(
          "d"."name" ILIKE ${searchPattern}
          OR COALESCE("d"."bio", '') ILIKE ${searchPattern}
          OR EXISTS (
            SELECT 1
            FROM unnest("d"."aliases") AS "alias"
            WHERE "alias" ILIKE ${searchPattern}
          )
          OR "d"."name" % ${search}
          OR COALESCE("d"."bio", '') % ${search}
          OR EXISTS (
            SELECT 1
            FROM unnest("d"."aliases") AS "alias"
            WHERE "alias" % ${search}
          )
        )`,
      ];

      if (country) {
        whereSqlParts.push(Prisma.sql`"d"."country" = ${country}`);
      }
      if (letter) {
        whereSqlParts.push(Prisma.sql`"d"."name" ILIKE ${`${letter}%`}`);
      }

      const whereSql = Prisma.sql`WHERE ${Prisma.join(whereSqlParts, ' AND ')}`;

      const [idRows, totalCountRows] = await Promise.all([
        prisma.$queryRaw<Array<{ id: string }>>(Prisma.sql`
          WITH scored AS (
            SELECT
              "d"."id",
              "d"."name",
              "d"."follower_count",
              CASE
                WHEN "d"."name" ILIKE ${searchPattern} OR "d"."name" % ${search} THEN 0
                WHEN EXISTS (
                  SELECT 1
                  FROM unnest("d"."aliases") AS "alias"
                  WHERE "alias" ILIKE ${searchPattern} OR "alias" % ${search}
                ) THEN 1
                WHEN COALESCE("d"."bio", '') ILIKE ${searchPattern} OR COALESCE("d"."bio", '') % ${search} THEN 2
                ELSE 3
              END AS "match_bucket",
              GREATEST(
                similarity(COALESCE("d"."name", ''), ${search}),
                word_similarity(COALESCE("d"."name", ''), ${search})
              ) AS "name_score",
              COALESCE((
                SELECT MAX(
                  GREATEST(
                    similarity("alias", ${search}),
                    word_similarity("alias", ${search})
                  )
                )
                FROM unnest("d"."aliases") AS "alias"
              ), 0) AS "alias_score",
              GREATEST(
                similarity(COALESCE("d"."bio", ''), ${search}),
                word_similarity(COALESCE("d"."bio", ''), ${search})
              ) AS "bio_score"
            FROM "djs" AS "d"
            ${whereSql}
          )
          SELECT "id"
          FROM scored
          ORDER BY
            "match_bucket" ASC,
            CASE
              WHEN "match_bucket" = 0 THEN "name_score"
              WHEN "match_bucket" = 1 THEN "alias_score"
              WHEN "match_bucket" = 2 THEN "bio_score"
              ELSE 0
            END DESC,
            GREATEST("name_score", "alias_score", "bio_score") DESC,
            "follower_count" DESC,
            "name" ASC
          LIMIT ${limit}
          OFFSET ${skip}
        `),
        prisma.$queryRaw<Array<{ total: number }>>(Prisma.sql`
          SELECT COUNT(*)::int AS "total"
          FROM "djs" AS "d"
          ${whereSql}
        `),
      ]);

      total = Number(totalCountRows[0]?.total ?? 0);
      const orderedIds = idRows.map((row) => row.id);
      if (orderedIds.length > 0) {
        const idOrder = new Map(orderedIds.map((id, index) => [id, index]));
        rows = await prisma.dJ.findMany({
          where: {
            id: { in: orderedIds },
          },
        });
        rows.sort((a, b) => (idOrder.get(a.id) ?? 0) - (idOrder.get(b.id) ?? 0));
      }
    } else if (sortBy === 'random') {
      const whereSqlParts: Prisma.Sql[] = [];

      if (search) {
        const searchPattern = `%${search}%`;
        whereSqlParts.push(Prisma.sql`(
          "djs"."name" ILIKE ${searchPattern}
          OR COALESCE("djs"."bio", '') ILIKE ${searchPattern}
          OR EXISTS (
            SELECT 1
            FROM unnest("djs"."aliases") AS "alias"
            WHERE "alias" ILIKE ${searchPattern}
          )
        )`);
      }

      if (country) {
        whereSqlParts.push(Prisma.sql`"djs"."country" = ${country}`);
      }
      if (letter) {
        whereSqlParts.push(Prisma.sql`"djs"."name" ILIKE ${`${letter}%`}`);
      }

      const whereSql =
        whereSqlParts.length > 0
          ? Prisma.sql`WHERE ${Prisma.join(whereSqlParts, ' AND ')}`
          : Prisma.empty;

      const [idRows, totalCount] = await Promise.all([
        prisma.$queryRaw<Array<{ id: string }>>(Prisma.sql`
          SELECT "djs"."id"
          FROM "djs"
          ${whereSql}
          ORDER BY RANDOM()
          LIMIT ${limit}
          OFFSET ${skip}
        `),
        prisma.dJ.count({ where }),
      ]);

      total = totalCount;
      const orderedIds = idRows.map((row) => row.id);
      if (orderedIds.length > 0) {
        const idOrder = new Map(orderedIds.map((id, index) => [id, index]));
        rows = await prisma.dJ.findMany({
          where: {
            id: { in: orderedIds },
          },
        });
        rows.sort((a, b) => (idOrder.get(a.id) ?? 0) - (idOrder.get(b.id) ?? 0));
      }
    } else {
      const orderBy: Prisma.DJOrderByWithRelationInput =
        sortBy === 'name'
          ? { name: 'asc' }
          : sortBy === 'createdAt'
            ? { createdAt: 'desc' }
            : sortBy === 'soundcloudFollowers'
              ? { soundCloudFollowers: 'desc' }
              : { followerCount: 'desc' };

      const [sortedRows, totalCount] = await Promise.all([
        prisma.dJ.findMany({
          where,
          skip,
          take: limit,
          orderBy,
        }),
        prisma.dJ.count({ where }),
      ]);

      rows = sortedRows;
      total = totalCount;
    }

    rows = await attachDJContributorInfoList(rows);

    const ids = rows.map((row) => row.id);
    const followRows = viewerId
      ? await prisma.userEntityFollow.findMany({
          where: {
            userId: viewerId,
            relationType: USER_ENTITY_RELATION_FOLLOW,
            targetType: USER_ENTITY_TARGET_DJ,
            targetId: { in: ids },
          },
          select: { targetId: true },
        })
      : [];
    const followSet = new Set(followRows.map((row) => row.targetId).filter((id): id is string => Boolean(id)));

    ok(
      res,
      { items: rows.map((row) => mapDJ(row, followSet.has(row.id), viewerId, viewerRole)) },
      {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit) || 1,
      }
    );
  } catch (error) {
    console.error('BFF web djs error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/djs/catalog-summary', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const page = normalizePage(req.query.page, 1);
    const limit = normalizeLimit(req.query.limit, 50, 100);
    const skip = (page - 1) * limit;
    const search = typeof req.query.search === 'string' ? req.query.search.trim() : '';
    const country = typeof req.query.country === 'string' ? req.query.country.trim() : '';
    const verificationStatus =
      typeof req.query.verificationStatus === 'string' ? req.query.verificationStatus.trim() : '';
    const sortBy = typeof req.query.sortBy === 'string' ? req.query.sortBy : 'followerCount';
    const forceRefresh = isTruthyQueryFlag(req.query.refresh);

    const incompleteClause: Prisma.DJWhereInput = {
      OR: [
        { avatarUrl: null },
        { bio: null },
        { country: null },
        { genres: { isEmpty: true } },
      ],
    };
    const completeClause: Prisma.DJWhereInput = {
      NOT: incompleteClause,
    };

    const cacheKey = JSON.stringify({
      page,
      limit,
      search,
      country,
      verificationStatus,
      sortBy,
    });
    const cached = !forceRefresh
      ? await adminSummaryCache.get<{
          items: unknown[];
          pagination: BFFPagination;
          generatedAt: string;
          summary: {
            total: number;
            verified: number;
            unverified: number;
            incomplete: number;
          };
        }>({
          namespace: 'dj-catalog-summary',
          key: cacheKey,
          snapshotVersion: ADMIN_DJ_CATALOG_SNAPSHOT_VERSION,
        })
      : null;
    if (cached) {
      res.json({
        data: {
          items: cached.payload.items,
          meta: {
            cache: {
              scope: cached.scope,
              hit: true,
              stale: false,
              generatedAt: cached.payload.generatedAt,
              ttlMs: ADMIN_CATALOG_MEMORY_TTL_MS,
              snapshotVersion: ADMIN_DJ_CATALOG_SNAPSHOT_VERSION,
            },
            summary: cached.payload.summary,
          },
        },
        pagination: cached.payload.pagination,
      });
      return;
    }

    const baseWhere: Prisma.DJWhereInput = {};
    if (search) {
      const normalizedSearchVariants = Array.from(new Set([search, search.toLowerCase(), search.toUpperCase()]));
      baseWhere.OR = [
        { name: { contains: search, mode: 'insensitive' } },
        { aliases: { hasSome: normalizedSearchVariants } },
        { bio: { contains: search, mode: 'insensitive' } },
        { genres: { hasSome: normalizedSearchVariants } },
      ];
    }
    if (country) baseWhere.country = country;

    let where: Prisma.DJWhereInput = baseWhere;
    if (verificationStatus === 'verified') {
      where = {
        AND: [baseWhere, { isVerified: true }, completeClause],
      };
    } else if (verificationStatus === 'unverified') {
      where = {
        AND: [baseWhere, { isVerified: false }, completeClause],
      };
    } else if (verificationStatus === 'incomplete') {
      where = {
        AND: [baseWhere, incompleteClause],
      };
    }

    const verifiedWhere: Prisma.DJWhereInput = {
      AND: [baseWhere, { isVerified: true }, completeClause],
    };
    const unverifiedWhere: Prisma.DJWhereInput = {
      AND: [baseWhere, { isVerified: false }, completeClause],
    };
    const incompleteWhere: Prisma.DJWhereInput = {
      AND: [baseWhere, incompleteClause],
    };

    const orderBy: Prisma.DJOrderByWithRelationInput =
      sortBy === 'name'
        ? { name: 'asc' }
        : sortBy === 'createdAt'
          ? { createdAt: 'desc' }
          : sortBy === 'soundcloudFollowers'
            ? { soundCloudFollowers: 'desc' }
            : { followerCount: 'desc' };

    const [rows, total, verifiedCount, unverifiedCount, incompleteCount] = await Promise.all([
      prisma.dJ.findMany({
        where,
        skip,
        take: limit,
        orderBy,
        select: {
          id: true,
          name: true,
          slug: true,
          avatarUrl: true,
          bannerUrl: true,
          country: true,
          bio: true,
          aliases: true,
          genres: true,
          followerCount: true,
          soundCloudFollowers: true,
          instagramUrl: true,
          spotifyId: true,
          isVerified: true,
          updatedAt: true,
          createdAt: true,
          lastSyncedAt: true,
        },
      }),
      prisma.dJ.count({ where }),
      prisma.dJ.count({ where: verifiedWhere }),
      prisma.dJ.count({ where: unverifiedWhere }),
      prisma.dJ.count({ where: incompleteWhere }),
    ]);

    const pagination = {
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit) || 1,
    };
    const generatedAt = new Date().toISOString();
    await adminSummaryCache.set({
      namespace: 'dj-catalog-summary',
      key: cacheKey,
      ttlMs: ADMIN_CATALOG_MEMORY_TTL_MS,
      snapshotVersion: ADMIN_DJ_CATALOG_SNAPSHOT_VERSION,
      payload: {
        items: rows,
        pagination,
        generatedAt,
        summary: {
          total: verifiedCount + unverifiedCount + incompleteCount,
          verified: verifiedCount,
          unverified: unverifiedCount,
          incomplete: incompleteCount,
        },
      },
    });

    res.json({
      data: {
        items: rows,
          meta: {
            cache: {
              scope: 'memory',
              hit: false,
              stale: false,
              generatedAt,
              ttlMs: ADMIN_CATALOG_MEMORY_TTL_MS,
              snapshotVersion: ADMIN_DJ_CATALOG_SNAPSHOT_VERSION,
            },
            summary: {
              total: verifiedCount + unverifiedCount + incompleteCount,
              verified: verifiedCount,
              unverified: unverifiedCount,
              incomplete: incompleteCount,
            },
          },
        },
        pagination,
    });
  } catch (error) {
    console.error('BFF web DJ catalog summary error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/djs/match-exact', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;
    const body = req.body as Record<string, unknown>;
    const rawNames = Array.isArray(body.names) ? body.names : [];
    const names = rawNames
      .map((item) => (typeof item === 'string' ? item.trim() : ''))
      .filter(Boolean)
      .slice(0, 200);

    const uniqueNames: string[] = [];
    const seen = new Set<string>();
    for (const name of names) {
      const key = name.toLocaleLowerCase();
      if (seen.has(key)) continue;
      seen.add(key);
      uniqueNames.push(name);
    }

    if (uniqueNames.length === 0) {
      ok(res, { matches: [] });
      return;
    }

    const values = Prisma.join(
      uniqueNames.map((name, index) => Prisma.sql`(${name}, ${name.toLocaleLowerCase()}, ${index})`)
    );

    const rows = await prisma.$queryRaw<Array<{
      query: string;
      query_order: number;
      id: string;
      name: string;
      aliases: string[];
      avatar_url: string | null;
    }>>(Prisma.sql`
      WITH input("query", "norm", "query_order") AS (
        VALUES ${values}
      ),
      matched AS (
        SELECT DISTINCT ON (input."norm")
          input."query",
          input."query_order",
          "d"."id",
          "d"."name",
          "d"."aliases",
          "d"."avatar_url",
          CASE
            WHEN lower("d"."name") = input."norm" THEN 0
            ELSE 1
          END AS "match_rank"
        FROM input
        JOIN "djs" AS "d"
          ON lower("d"."name") = input."norm"
          OR EXISTS (
            SELECT 1
            FROM unnest("d"."aliases") AS "alias"
            WHERE lower("alias") = input."norm"
          )
        ORDER BY input."norm", "match_rank" ASC, "d"."follower_count" DESC, "d"."name" ASC
      )
      SELECT "query", "query_order", "id", "name", "aliases", "avatar_url"
      FROM matched
      ORDER BY "query_order" ASC
    `);

    ok(res, {
      matches: rows.map((row) => ({
        query: row.query,
        djId: row.id,
        name: row.name,
        aliases: Array.isArray(row.aliases) ? row.aliases : [],
        avatarUrl: row.avatar_url,
        avatarOriginalUrl: row.avatar_url,
        avatarMediumUrl: buildOssAvatarVariantUrl(row.avatar_url, row.id, 'medium'),
        avatarSmallUrl: buildOssAvatarVariantUrl(row.avatar_url, row.id, 'small'),
      })),
    });
  } catch (error) {
    console.error('BFF web match exact DJs error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/djs/recommendations', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const viewerId = authReq.user?.userId;
    const viewerRole = authReq.user?.role ?? null;
    const limit = normalizeLimit(req.query.limit, DAILY_DJ_RECOMMENDATION_SIZE, 20);
    const now = new Date();

    let orderedIds: string[] = [];
    let snapshot: DailyDJRecommendationSnapshot | null = null;

    if (viewerId) {
      snapshot = await getOrCreateDailyDJRecommendationSnapshot(viewerId, now);
      orderedIds = snapshot.djIds.slice(0, limit);
    } else {
      orderedIds = (await selectDailyDJRecommendationIds()).slice(0, limit);
    }

    if (orderedIds.length === 0) {
      ok(res, {
        items: [],
        meta: {
          limit,
          selected: 0,
          cache: snapshot
            ? {
                scope: 'daily-user',
                hit: true,
                date: snapshot.dateKey,
                algorithmVersion: snapshot.algorithmVersion,
                candidateSource: snapshot.candidateSource,
                candidateLimit: snapshot.candidateLimit,
                generatedAt: snapshot.generatedAt.toISOString(),
                timeZone: DAILY_EVENT_RECOMMENDATION_TIME_ZONE,
              }
            : {
                scope: 'request',
                hit: false,
                candidateSource: DAILY_DJ_RECOMMENDATION_CANDIDATE_SOURCE,
                candidateLimit: DAILY_DJ_RECOMMENDATION_CANDIDATE_LIMIT,
              },
        },
      });
      return;
    }

    let rows = await prisma.dJ.findMany({
      where: { id: { in: orderedIds } },
    });
    const idOrder = new Map(orderedIds.map((id, index) => [id, index]));
    rows.sort((a, b) => (idOrder.get(a.id) ?? 0) - (idOrder.get(b.id) ?? 0));
    rows = await attachDJContributorInfoList(rows);

    const followRows = viewerId
      ? await prisma.userEntityFollow.findMany({
          where: {
            userId: viewerId,
            relationType: USER_ENTITY_RELATION_FOLLOW,
            targetType: USER_ENTITY_TARGET_DJ,
            targetId: { in: orderedIds },
          },
          select: { targetId: true },
        })
      : [];
    const followSet = new Set(followRows.map((row) => row.targetId).filter((id): id is string => Boolean(id)));

    ok(res, {
      items: rows.map((row) => mapDJ(row, followSet.has(row.id), viewerId, viewerRole)),
      meta: {
        limit,
        selected: rows.length,
        cache: snapshot
          ? {
              scope: 'daily-user',
              hit: true,
              date: snapshot.dateKey,
              algorithmVersion: snapshot.algorithmVersion,
              candidateSource: snapshot.candidateSource,
              candidateLimit: snapshot.candidateLimit,
              generatedAt: snapshot.generatedAt.toISOString(),
              timeZone: DAILY_EVENT_RECOMMENDATION_TIME_ZONE,
            }
          : {
              scope: 'request',
              hit: false,
              candidateSource: DAILY_DJ_RECOMMENDATION_CANDIDATE_SOURCE,
              candidateLimit: DAILY_DJ_RECOMMENDATION_CANDIDATE_LIMIT,
            },
      },
    });
  } catch (error) {
    console.error('BFF web DJ recommendations error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/djs/spotify/search', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    if (!spotifyArtistService.isConfigured()) {
      res.status(503).json({ error: 'Spotify credentials are not configured' });
      return;
    }

    const query = typeof req.query.q === 'string' ? req.query.q.trim() : '';
    if (!query) {
      res.status(400).json({ error: 'q is required' });
      return;
    }

    const limit = normalizeLimit(req.query.limit, 10, 10);
    console.info('[spotify-debug] bff.search.start', {
      userId,
      query,
      limit,
    });
    const candidates = await spotifyArtistService.searchArtistsByName(query, limit);
    if (candidates.length === 0) {
      console.info('[spotify-debug] bff.search.empty', {
        userId,
        query,
      });
      ok(res, { items: [] as SpotifyDJSearchItem[] });
      return;
    }

    const spotifyIds = candidates.map((item) => item.id).filter(Boolean);
    const nameConditions = candidates.map((item) => ({
      name: { equals: item.name, mode: 'insensitive' as const },
    }));
    const existingRows = await prisma.dJ.findMany({
      where: {
        OR: [
          ...(spotifyIds.length > 0 ? [{ spotifyId: { in: spotifyIds } }] : []),
          ...nameConditions,
        ],
      },
      select: {
        id: true,
        name: true,
        spotifyId: true,
      },
      orderBy: {
        createdAt: 'asc',
      },
    });

    const bySpotifyId = new Map<string, (typeof existingRows)[number]>();
    const byName = new Map<string, (typeof existingRows)[number]>();
    for (const row of existingRows) {
      if (row.spotifyId && !bySpotifyId.has(row.spotifyId)) {
        bySpotifyId.set(row.spotifyId, row);
      }
      const key = normalizeDJNameKey(row.name);
      if (!byName.has(key)) {
        byName.set(key, row);
      }
    }

    const items: SpotifyDJSearchItem[] = candidates.map((item) => {
      const spotifyMatched = bySpotifyId.get(item.id) ?? null;
      const nameMatched = byName.get(normalizeDJNameKey(item.name)) ?? null;
      const matched = spotifyMatched ?? nameMatched;
      const matchType: SpotifyDJSearchItem['existingMatchType'] = spotifyMatched
        ? 'spotify_id'
        : nameMatched
          ? 'name_case_insensitive'
          : null;

      return {
        spotifyId: item.id,
        name: item.name,
        uri: item.uri,
        url: item.url,
        popularity: item.popularity,
        followers: item.followers,
        genres: item.genres,
        imageUrl: item.imageUrl,
        existingDJId: matched?.id ?? null,
        existingDJName: matched?.name ?? null,
        existingMatchType: matchType,
      };
    });

    console.info('[spotify-debug] bff.search.success', {
      userId,
      query,
      spotifyCandidateCount: candidates.length,
      responseItemCount: items.length,
      matchedExistingCount: items.filter((item) => Boolean(item.existingDJId)).length,
    });
    ok(res, { items });
  } catch (error) {
    if (error instanceof SpotifyUpstreamError) {
      console.error('BFF web spotify dj search upstream error:', {
        code: error.code,
        status: error.status,
        message: error.message,
      });
      res.status(503).json({
        error: 'Spotify 服务暂时不可用，请稍后重试',
        errorCode: error.code,
      });
      return;
    }
    console.error('BFF web spotify dj search error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/djs/discogs/search', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    if (!discogsArtistService.isConfigured()) {
      res.status(503).json({ error: 'Discogs token is not configured' });
      return;
    }

    const query = typeof req.query.q === 'string' ? req.query.q.trim() : '';
    if (!query) {
      res.status(400).json({ error: 'q is required' });
      return;
    }

    const limit = normalizeLimit(req.query.limit, 10, 20);
    const candidates = await discogsArtistService.searchArtistsByName(query, limit);
    if (candidates.length === 0) {
      ok(res, { items: [] as DiscogsDJSearchItem[] });
      return;
    }

    const nameConditions = candidates.map((item) => ({
      name: { equals: item.name, mode: 'insensitive' as const },
    }));
    const existingRows = await prisma.dJ.findMany({
      where: {
        OR: nameConditions,
      },
      select: {
        id: true,
        name: true,
      },
      orderBy: {
        createdAt: 'asc',
      },
    });

    const byName = new Map<string, (typeof existingRows)[number]>();
    for (const row of existingRows) {
      const key = normalizeDJNameKey(row.name);
      if (!byName.has(key)) {
        byName.set(key, row);
      }
    }

    const items: DiscogsDJSearchItem[] = candidates.map((item) => {
      const matched = byName.get(normalizeDJNameKey(item.name)) ?? null;
      return {
        artistId: item.artistId,
        name: item.name,
        thumbUrl: item.thumbUrl,
        coverImageUrl: item.coverImageUrl,
        resourceUrl: item.resourceUrl,
        uri: item.uri,
        existingDJId: matched?.id ?? null,
        existingDJName: matched?.name ?? null,
        existingMatchType: matched ? 'name_case_insensitive' : null,
      };
    });

    ok(res, { items });
  } catch (error) {
    if (error instanceof DiscogsUpstreamError) {
      console.error('BFF web discogs dj search upstream error:', {
        code: error.code,
        status: error.status,
        message: error.message,
      });
      res.status(503).json({
        error: 'Discogs 服务暂时不可用，请稍后重试',
        errorCode: error.code,
      });
      return;
    }
    console.error('BFF web discogs dj search error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/djs/discogs/artists/:artistId', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    if (!discogsArtistService.isConfigured()) {
      res.status(503).json({ error: 'Discogs token is not configured' });
      return;
    }

    const parsedArtistId = Number(req.params.artistId);
    if (!Number.isFinite(parsedArtistId) || parsedArtistId <= 0) {
      res.status(400).json({ error: 'artistId must be a positive number' });
      return;
    }

    const detail = await discogsArtistService.getArtistById(Math.floor(parsedArtistId));
    if (!detail) {
      res.status(404).json({ error: 'Discogs artist not found' });
      return;
    }

    const existing = await prisma.dJ.findFirst({
      where: { name: { equals: detail.name, mode: 'insensitive' } },
      select: { id: true, name: true },
      orderBy: { createdAt: 'asc' },
    });

    const payload: DiscogsDJArtistDetailItem = {
      artistId: detail.artistId,
      name: detail.name,
      realName: detail.realName,
      profile: detail.profile,
      urls: detail.urls,
      nameVariations: detail.nameVariations,
      aliases: detail.aliases,
      groups: detail.groups,
      primaryImageUrl: detail.primaryImageUrl,
      thumbnailImageUrl: detail.thumbnailImageUrl,
      resourceUrl: detail.resourceUrl,
      uri: detail.uri,
      existingDJId: existing?.id ?? null,
      existingDJName: existing?.name ?? null,
      existingMatchType: existing ? 'name_case_insensitive' : null,
    };

    ok(res, payload);
  } catch (error) {
    if (error instanceof DiscogsUpstreamError) {
      console.error('BFF web discogs artist detail upstream error:', {
        code: error.code,
        status: error.status,
        message: error.message,
      });
      res.status(503).json({
        error: 'Discogs 服务暂时不可用，请稍后重试',
        errorCode: error.code,
      });
      return;
    }
    console.error('BFF web discogs artist detail error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/djs/soundcloud/search', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    if (!soundcloudArtistService.isConfigured()) {
      res.status(503).json({ error: 'SoundCloud credentials are not configured' });
      return;
    }

    const query = typeof req.query.q === 'string' ? req.query.q.trim() : '';
    if (!query) {
      res.status(400).json({ error: 'q is required' });
      return;
    }

    const limit = normalizeLimit(req.query.limit, 10, 30);
    const candidates = await soundcloudArtistService.searchUsersByName(query, limit);
    if (candidates.length === 0) {
      ok(res, { items: [] as SoundCloudDJSearchItem[] });
      return;
    }

    const nameConditions = candidates.map((item) => ({
      name: { equals: item.name, mode: 'insensitive' as const },
    }));
    const existingRows = await prisma.dJ.findMany({
      where: {
        OR: nameConditions,
      },
      select: {
        id: true,
        name: true,
      },
      orderBy: {
        createdAt: 'asc',
      },
    });

    const byName = new Map<string, (typeof existingRows)[number]>();
    for (const row of existingRows) {
      const key = normalizeDJNameKey(row.name);
      if (!byName.has(key)) {
        byName.set(key, row);
      }
    }

    const items: SoundCloudDJSearchItem[] = candidates.map((item) => {
      const matched = byName.get(normalizeDJNameKey(item.name)) ?? null;
      return {
        soundcloudid: item.soundcloudId,
        soundcloudId: item.soundcloudId,
        soundCloudId: item.soundcloudId,
        name: item.name,
        username: item.username,
        avatarUrl: item.avatarUrl,
        permalink: item.permalink,
        permalinkUrl: item.permalinkUrl,
        city: item.city,
        country: item.country,
        description: item.description,
        website: item.website,
        spotifyUrl: item.spotifyUrl,
        instagramUrl: item.instagramUrl,
        facebookUrl: item.facebookUrl,
        twitterUrl: item.twitterUrl,
        youtubeUrl: item.youtubeUrl,
        track_count: item.trackCount,
        playlist_count: item.playlistCount,
        followers_count: item.followersCount,
        public_favorites_count: item.publicFavoritesCount,
        trackCount: item.trackCount,
        playlistCount: item.playlistCount,
        followersCount: item.followersCount,
        publicFavoritesCount: item.publicFavoritesCount,
        soundCloudFollowers: item.followersCount,
        soundCloudFavorites: item.publicFavoritesCount,
        existingDJId: matched?.id ?? null,
        existingDJName: matched?.name ?? null,
        existingMatchType: matched ? 'name_case_insensitive' : null,
      };
    });

    ok(res, { items });
  } catch (error) {
    if (error instanceof SoundCloudUpstreamError) {
      console.error('BFF web soundcloud dj search upstream error:', {
        code: error.code,
        status: error.status,
        message: error.message,
      });
      res.status(503).json({
        error: 'SoundCloud 服务暂时不可用，请稍后重试',
        errorCode: error.code,
      });
      return;
    }
    console.error('BFF web soundcloud dj search error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/djs/spotify/import', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    const viewerRole = authReq.user?.role ?? null;

    if (!spotifyArtistService.isConfigured()) {
      res.status(503).json({ error: 'Spotify credentials are not configured' });
      return;
    }

    const payload = (req.body ?? {}) as Record<string, unknown>;
    const spotifyId = typeof payload.spotifyId === 'string' ? payload.spotifyId.trim() : '';
    if (!spotifyId) {
      res.status(400).json({ error: 'spotifyId is required' });
      return;
    }

    const spotifyArtist = await spotifyArtistService.getArtistById(spotifyId);
    if (!spotifyArtist) {
      res.status(404).json({ error: 'Spotify artist not found' });
      return;
    }

    const requestedName = typeof payload.name === 'string' ? payload.name.trim() : '';
    const finalName = requestedName || spotifyArtist.name.trim();
    if (!finalName) {
      res.status(400).json({ error: 'DJ name is empty' });
      return;
    }

    if (!canBypassContentReview(viewerRole)) {
      const submission = await createPendingContentSubmission({
        submitterId: userId,
        entityType: 'dj',
        title: finalName,
        payload: {
          ...payload,
          name: finalName,
          spotifyId: spotifyArtist.id,
          avatarUrl: spotifyArtist.imageUrl,
          importSource: 'spotify',
          spotifyPreview: {
            name: spotifyArtist.name,
            followers: spotifyArtist.followers,
            genres: spotifyArtist.genres,
            imageUrl: spotifyArtist.imageUrl,
          },
        },
      });
      acceptedSubmission(res, submission, 'DJ 信息已提交审核，管理员审核通过后才会入库');
      return;
    }

    const hasAliasesInput = Object.prototype.hasOwnProperty.call(payload, 'aliases');
    let requestedAliases: string[] = [];
    if (hasAliasesInput) {
      const aliasValue = payload.aliases;
      if (aliasValue !== null && !Array.isArray(aliasValue)) {
        res.status(400).json({ error: 'aliases must be an array or null' });
        return;
      }
      requestedAliases = Array.isArray(aliasValue)
        ? aliasValue.map((item) => (typeof item === 'string' ? item.trim() : '')).filter(Boolean)
        : [];
    }
    const requestedBio = typeof payload.bio === 'string' ? payload.bio.trim() : '';
    const requestedCountry = typeof payload.country === 'string' ? payload.country.trim() : '';
    const hasGenresInput = Object.prototype.hasOwnProperty.call(payload, 'genres');
    if (hasGenresInput && payload.genres !== null && !Array.isArray(payload.genres) && typeof payload.genres !== 'string') {
      res.status(400).json({ error: 'genres must be an array, string, or null' });
      return;
    }
    const requestedGenres = hasGenresInput ? normalizeGenres(payload.genres) : [];
    const requestedInstagram = typeof payload.instagramUrl === 'string' ? payload.instagramUrl.trim() : '';
    const requestedFacebook = typeof payload.facebookUrl === 'string' ? payload.facebookUrl.trim() : '';
    const requestedSoundcloud = typeof payload.soundcloudUrl === 'string' ? payload.soundcloudUrl.trim() : '';
    const requestedTwitter = typeof payload.twitterUrl === 'string' ? payload.twitterUrl.trim() : '';
    const requestedYoutube = typeof payload.youtubeUrl === 'string' ? payload.youtubeUrl.trim() : '';
    const requestedSpotifyUrl = typeof payload.spotifyUrl === 'string' ? payload.spotifyUrl.trim() : '';
    const requestedNeteaseUrl = typeof payload.neteaseUrl === 'string' ? payload.neteaseUrl.trim() : '';
    const requestedQqMusicUrl = typeof payload.qqMusicUrl === 'string' ? payload.qqMusicUrl.trim() : '';
    const requestedSoundcloudId = parseOptionalStringFromPayload(payload, ['soundcloudId', 'soundcloudid']);
    const requestedWebsite = parseOptionalStringFromPayload(payload, ['website', 'websiteUrl', 'officialWebsite']);
    const hasTrackCountInput = payloadHasAnyKey(payload, ['trackCount', 'track_count']);
    const hasPlaylistCountInput = payloadHasAnyKey(payload, ['playlistCount', 'playlist_count']);
    const hasSoundCloudFollowersInput = payloadHasAnyKey(payload, [
      'soundCloudFollowers',
      'soundcloudFollowers',
      'followers_count',
    ]);
    const hasSoundCloudFavoritesInput = payloadHasAnyKey(payload, [
      'soundCloudFavorites',
      'soundcloudFavorites',
      'public_favorites_count',
    ]);
    let requestedTrackCount: number | null = null;
    let requestedPlaylistCount: number | null = null;
    let requestedSoundCloudFollowers: number | null = null;
    let requestedSoundCloudFavorites: number | null = null;
    try {
      if (hasTrackCountInput) {
        requestedTrackCount = parseOptionalNonNegativeInt(
          payloadValueByKeys(payload, ['trackCount', 'track_count']),
          'trackCount'
        );
      }
      if (hasPlaylistCountInput) {
        requestedPlaylistCount = parseOptionalNonNegativeInt(
          payloadValueByKeys(payload, ['playlistCount', 'playlist_count']),
          'playlistCount'
        );
      }
      if (hasSoundCloudFollowersInput) {
        requestedSoundCloudFollowers = parseOptionalNonNegativeInt(
          payloadValueByKeys(payload, ['soundCloudFollowers', 'soundcloudFollowers', 'followers_count']),
          'soundCloudFollowers'
        );
      }
      if (hasSoundCloudFavoritesInput) {
        requestedSoundCloudFavorites = parseOptionalNonNegativeInt(
          payloadValueByKeys(payload, ['soundCloudFavorites', 'soundcloudFavorites', 'public_favorites_count']),
          'soundCloudFavorites'
        );
      }
    } catch (error) {
      res.status(400).json({ error: (error as Error).message });
      return;
    }
    const hasSpotifyFollowersInput = Object.prototype.hasOwnProperty.call(payload, 'spotifyFollowers');
    let requestedSpotifyFollowers: number | null = null;
    if (hasSpotifyFollowersInput) {
      try {
        requestedSpotifyFollowers = parseOptionalNonNegativeInt(payload.spotifyFollowers, 'spotifyFollowers');
      } catch (error) {
        res.status(400).json({ error: (error as Error).message });
        return;
      }
    }
    const requestedVerified =
      typeof payload.isVerified === 'boolean' ? payload.isVerified : true;

    const spotifyName = spotifyArtist.name.trim();
    const derivedBio = spotifyArtist.genres.length
      ? `Spotify genres: ${spotifyArtist.genres.slice(0, 4).join(', ')}`
      : '';
    const derivedGenres = normalizeGenres(spotifyArtist.genres);
    const derivedSpotifyFollowers = Number.isFinite(spotifyArtist.followers)
      ? Math.max(0, Math.floor(spotifyArtist.followers))
      : 0;

    const existingBySpotifyId = await prisma.dJ.findFirst({
      where: { spotifyId: spotifyArtist.id },
    });
    const existingByName = existingBySpotifyId
      ? null
      : await prisma.dJ.findFirst({
          where: { name: { equals: finalName, mode: 'insensitive' } },
          orderBy: { createdAt: 'asc' },
        });

    const target = existingBySpotifyId ?? existingByName;
    if (target) {
      const allowed = await canUserEditDJ(target.id, userId, viewerRole);
      if (!allowed) {
        res.status(403).json({ error: '仅该 DJ 的贡献者或管理员可修改信息' });
        return;
      }
    }
    const mergedAliases = mergeAliases(finalName, [
      ...(target?.aliases ?? []),
      ...requestedAliases,
      spotifyName,
    ]);

    let action: 'created' | 'updated' = 'created';
    let previousAvatarUrl: string | null = null;
    let persisted: any;

    if (target) {
      action = 'updated';
      previousAvatarUrl = target.avatarUrl ?? null;
      persisted = await prisma.dJ.update({
        where: { id: target.id },
        data: {
          name: target.name || finalName,
          nameI18n: (normalizeDJBiText(target.nameI18n ?? null, target.name || finalName) as unknown as Prisma.InputJsonValue | null) ?? undefined,
          aliases: mergedAliases,
          genres: hasGenresInput ? requestedGenres : normalizeGenres([...(target.genres ?? []), ...derivedGenres]),
          bio: requestedBio || target.bio || derivedBio || null,
          bioI18n: (normalizeDJBiText(target.bioI18n ?? null, requestedBio || target.bio || derivedBio || '') as unknown as Prisma.InputJsonValue | null) ?? undefined,
          country: requestedCountry || target.country || null,
          countryI18n: (normalizeCountryBiText(target.countryI18n ?? null, requestedCountry || target.country || '') as unknown as Prisma.InputJsonValue | null) ?? undefined,
          spotifyUrl: requestedSpotifyUrl || target.spotifyUrl || null,
          spotifyId: spotifyArtist.id,
          spotifyFollowers: hasSpotifyFollowersInput ? requestedSpotifyFollowers : derivedSpotifyFollowers,
          followerCount: spotifyArtist.followers || target.followerCount || 0,
          instagramUrl: requestedInstagram || target.instagramUrl || null,
          facebookUrl: requestedFacebook || target.facebookUrl || null,
          soundcloudUrl: requestedSoundcloud || target.soundcloudUrl || null,
          soundcloudId: requestedSoundcloudId || target.soundcloudId || null,
          neteaseUrl: requestedNeteaseUrl || target.neteaseUrl || null,
          qqMusicUrl: requestedQqMusicUrl || target.qqMusicUrl || null,
          website: requestedWebsite || target.website || null,
          trackCount: hasTrackCountInput ? requestedTrackCount : (target.trackCount ?? null),
          playlistCount: hasPlaylistCountInput ? requestedPlaylistCount : (target.playlistCount ?? null),
          soundCloudFollowers: hasSoundCloudFollowersInput
            ? requestedSoundCloudFollowers
            : (target.soundCloudFollowers ?? null),
          soundCloudFavorites: hasSoundCloudFavoritesInput
            ? requestedSoundCloudFavorites
            : (target.soundCloudFavorites ?? null),
          twitterUrl: requestedTwitter || target.twitterUrl || null,
          youtubeUrl: requestedYoutube || target.youtubeUrl || null,
          isVerified: target.isVerified || requestedVerified,
          avatarSourceUrl: spotifyArtist.imageUrl || target.avatarSourceUrl || null,
          sourceDataSource: mergeDJDataSources(target.sourceDataSource, ['spotify']),
        },
      });
    } else {
      const slug = await uniqueDJSlugForName(finalName);
      persisted = await prisma.dJ.create({
        data: {
          name: finalName,
          nameI18n: (normalizeDJBiText(payload.nameI18n ?? null, finalName) as unknown as Prisma.InputJsonValue | null) ?? undefined,
          aliases: mergedAliases,
          genres: hasGenresInput ? requestedGenres : derivedGenres,
          slug,
          bio: requestedBio || derivedBio || null,
          bioI18n: (normalizeDJBiText(payload.bioI18n ?? null, requestedBio || derivedBio || '') as unknown as Prisma.InputJsonValue | null) ?? undefined,
          country: requestedCountry || null,
          countryI18n: (normalizeCountryBiText(payload.countryI18n ?? null, requestedCountry || '') as unknown as Prisma.InputJsonValue | null) ?? undefined,
          spotifyUrl: requestedSpotifyUrl || `https://open.spotify.com/artist/${spotifyArtist.id}`,
          spotifyId: spotifyArtist.id,
          spotifyFollowers: hasSpotifyFollowersInput ? requestedSpotifyFollowers : derivedSpotifyFollowers,
          followerCount: spotifyArtist.followers || 0,
          instagramUrl: requestedInstagram || null,
          facebookUrl: requestedFacebook || null,
          soundcloudUrl: requestedSoundcloud || null,
          soundcloudId: requestedSoundcloudId || null,
          neteaseUrl: requestedNeteaseUrl || null,
          qqMusicUrl: requestedQqMusicUrl || null,
          website: requestedWebsite || null,
          trackCount: hasTrackCountInput ? requestedTrackCount : null,
          playlistCount: hasPlaylistCountInput ? requestedPlaylistCount : null,
          soundCloudFollowers: hasSoundCloudFollowersInput ? requestedSoundCloudFollowers : null,
          soundCloudFavorites: hasSoundCloudFavoritesInput ? requestedSoundCloudFavorites : null,
          twitterUrl: requestedTwitter || null,
          youtubeUrl: requestedYoutube || null,
          isVerified: requestedVerified,
          avatarSourceUrl: spotifyArtist.imageUrl || null,
          avatarUrl: null,
          sourceDataSource: mergeDJDataSources(null, ['spotify']),
        },
      });
    }

    let avatarUploadedToOss = false;
    let replacedExistingAvatar = false;
    if (spotifyArtist.imageUrl) {
      const uploadedAvatar = await uploadRemoteDJAvatarToOss(persisted.id, spotifyArtist.imageUrl);
      if (uploadedAvatar) {
        avatarUploadedToOss = true;
        replacedExistingAvatar = Boolean(previousAvatarUrl && previousAvatarUrl !== uploadedAvatar.url);
        const updated = await prisma.dJ.update({
          where: { id: persisted.id },
          data: {
            avatarUrl: uploadedAvatar.url,
            avatarSourceUrl: spotifyArtist.imageUrl,
          },
        });
        if (previousAvatarUrl && previousAvatarUrl !== uploadedAvatar.url) {
          await deleteSingleDJMediaOssObjectIfOwned(previousAvatarUrl, persisted.id);
        }
        persisted = updated;
      } else if (!persisted.avatarUrl) {
        persisted = await prisma.dJ.update({
          where: { id: persisted.id },
          data: {
            avatarUrl: spotifyArtist.imageUrl,
            avatarSourceUrl: spotifyArtist.imageUrl,
          },
        });
      }
    }

    await recordDirectDJContribution(
      {
        id: persisted.id,
        name: persisted.name,
        avatarUrl: persisted.avatarUrl ?? null,
      },
      userId,
      action === 'created' ? 'create' : 'edit',
      'manual_import'
    );
    if (action === 'created') {
      await createDJEventBindingReviewJobBestEffort(persisted.id, {
        triggerSource: 'manual_import',
        createdById: userId,
      });
    }
    const hydrated = await fetchDJWithContributorsById(persisted.id);
    const mapped = mapDJ(hydrated ?? persisted, false, userId, viewerRole);

    ok(res, {
      action,
      avatarUploadedToOss,
      replacedExistingAvatar,
      dj: mapped,
    });
  } catch (error) {
    if (error instanceof SpotifyUpstreamError) {
      console.error('BFF web spotify dj import upstream error:', {
        code: error.code,
        status: error.status,
        message: error.message,
      });
      res.status(503).json({
        error: 'Spotify 服务暂时不可用，请稍后重试',
        errorCode: error.code,
      });
      return;
    }
    console.error('BFF web spotify dj import error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/djs/discogs/import', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    const viewerRole = authReq.user?.role ?? null;

    if (!discogsArtistService.isConfigured()) {
      res.status(503).json({ error: 'Discogs token is not configured' });
      return;
    }

    const payload = (req.body ?? {}) as Record<string, unknown>;
    const rawArtistId = payload.discogsArtistId ?? payload.artistId;
    const discogsArtistId = Number(rawArtistId);
    if (!Number.isFinite(discogsArtistId) || discogsArtistId <= 0) {
      res.status(400).json({ error: 'discogsArtistId is required and must be a positive number' });
      return;
    }

    const discogsArtist = await discogsArtistService.getArtistById(Math.floor(discogsArtistId));
    if (!discogsArtist) {
      res.status(404).json({ error: 'Discogs artist not found' });
      return;
    }

    const requestedName = typeof payload.name === 'string' ? payload.name.trim() : '';
    const finalName = requestedName || discogsArtist.name.trim();
    if (!finalName) {
      res.status(400).json({ error: 'DJ name is empty' });
      return;
    }

    if (!canBypassContentReview(viewerRole)) {
      const submission = await createPendingContentSubmission({
        submitterId: userId,
        entityType: 'dj',
        title: finalName,
        payload: {
          ...payload,
          name: finalName,
          avatarUrl: discogsArtist.primaryImageUrl,
          importSource: 'discogs',
          discogsArtistId: Math.floor(discogsArtistId),
          discogsPreview: {
            name: discogsArtist.name,
            realName: discogsArtist.realName,
            profile: discogsArtist.profile,
            primaryImageUrl: discogsArtist.primaryImageUrl,
            urls: discogsArtist.urls,
          },
        },
      });
      acceptedSubmission(res, submission, 'DJ 信息已提交审核，管理员审核通过后才会入库');
      return;
    }

    const hasAliasesInput = Object.prototype.hasOwnProperty.call(payload, 'aliases');
    let requestedAliases: string[] = [];
    if (hasAliasesInput) {
      const aliasValue = payload.aliases;
      if (aliasValue !== null && !Array.isArray(aliasValue)) {
        res.status(400).json({ error: 'aliases must be an array or null' });
        return;
      }
      requestedAliases = Array.isArray(aliasValue)
        ? aliasValue.map((item) => (typeof item === 'string' ? item.trim() : '')).filter(Boolean)
        : [];
    }
    const requestedBio = typeof payload.bio === 'string' ? payload.bio.trim() : '';
    const requestedCountry = typeof payload.country === 'string' ? payload.country.trim() : '';
    const hasGenresInput = Object.prototype.hasOwnProperty.call(payload, 'genres');
    if (hasGenresInput && payload.genres !== null && !Array.isArray(payload.genres) && typeof payload.genres !== 'string') {
      res.status(400).json({ error: 'genres must be an array, string, or null' });
      return;
    }
    const requestedGenres = hasGenresInput ? normalizeGenres(payload.genres) : [];
    const requestedInstagram = typeof payload.instagramUrl === 'string' ? payload.instagramUrl.trim() : '';
    const requestedFacebook = typeof payload.facebookUrl === 'string' ? payload.facebookUrl.trim() : '';
    const requestedSoundcloud = typeof payload.soundcloudUrl === 'string' ? payload.soundcloudUrl.trim() : '';
    const requestedTwitter = typeof payload.twitterUrl === 'string' ? payload.twitterUrl.trim() : '';
    const requestedYoutube = typeof payload.youtubeUrl === 'string' ? payload.youtubeUrl.trim() : '';
    const requestedSpotifyId = typeof payload.spotifyId === 'string' ? payload.spotifyId.trim() : '';
    const requestedSoundcloudId = parseOptionalStringFromPayload(payload, ['soundcloudId', 'soundcloudid']);
    const requestedWebsite = parseOptionalStringFromPayload(payload, ['website', 'websiteUrl', 'officialWebsite']);
    const hasTrackCountInput = payloadHasAnyKey(payload, ['trackCount', 'track_count']);
    const hasPlaylistCountInput = payloadHasAnyKey(payload, ['playlistCount', 'playlist_count']);
    const hasSoundCloudFollowersInput = payloadHasAnyKey(payload, [
      'soundCloudFollowers',
      'soundcloudFollowers',
      'followers_count',
    ]);
    const hasSoundCloudFavoritesInput = payloadHasAnyKey(payload, [
      'soundCloudFavorites',
      'soundcloudFavorites',
      'public_favorites_count',
    ]);
    let requestedTrackCount: number | null = null;
    let requestedPlaylistCount: number | null = null;
    let requestedSoundCloudFollowers: number | null = null;
    let requestedSoundCloudFavorites: number | null = null;
    try {
      if (hasTrackCountInput) {
        requestedTrackCount = parseOptionalNonNegativeInt(
          payloadValueByKeys(payload, ['trackCount', 'track_count']),
          'trackCount'
        );
      }
      if (hasPlaylistCountInput) {
        requestedPlaylistCount = parseOptionalNonNegativeInt(
          payloadValueByKeys(payload, ['playlistCount', 'playlist_count']),
          'playlistCount'
        );
      }
      if (hasSoundCloudFollowersInput) {
        requestedSoundCloudFollowers = parseOptionalNonNegativeInt(
          payloadValueByKeys(payload, ['soundCloudFollowers', 'soundcloudFollowers', 'followers_count']),
          'soundCloudFollowers'
        );
      }
      if (hasSoundCloudFavoritesInput) {
        requestedSoundCloudFavorites = parseOptionalNonNegativeInt(
          payloadValueByKeys(payload, ['soundCloudFavorites', 'soundcloudFavorites', 'public_favorites_count']),
          'soundCloudFavorites'
        );
      }
    } catch (error) {
      res.status(400).json({ error: (error as Error).message });
      return;
    }
    const hasSpotifyFollowersInput = Object.prototype.hasOwnProperty.call(payload, 'spotifyFollowers');
    let requestedSpotifyFollowers: number | null = null;
    if (hasSpotifyFollowersInput) {
      try {
        requestedSpotifyFollowers = parseOptionalNonNegativeInt(payload.spotifyFollowers, 'spotifyFollowers');
      } catch (error) {
        res.status(400).json({ error: (error as Error).message });
        return;
      }
    }
    const requestedVerified =
      typeof payload.isVerified === 'boolean' ? payload.isVerified : true;

    const existingBySpotifyId = requestedSpotifyId
      ? await prisma.dJ.findFirst({
          where: { spotifyId: requestedSpotifyId },
        })
      : null;
    const existingByName = existingBySpotifyId
      ? null
      : await prisma.dJ.findFirst({
          where: { name: { equals: finalName, mode: 'insensitive' } },
          orderBy: { createdAt: 'asc' },
        });
    const target = existingBySpotifyId ?? existingByName;
    if (target) {
      const allowed = await canUserEditDJ(target.id, userId, viewerRole);
      if (!allowed) {
        res.status(403).json({ error: '仅该 DJ 的贡献者或管理员可修改信息' });
        return;
      }
    }

    const derivedBio = discogsArtist.profile?.trim() || '';
    const derivedInstagram = pickFirstUrlByHosts(discogsArtist.urls, ['instagram.com']);
    const derivedFacebook = pickFirstUrlByHosts(discogsArtist.urls, ['facebook.com', 'fb.com']);
    const derivedSoundcloud = pickFirstUrlByHosts(discogsArtist.urls, ['soundcloud.com']);
    const derivedTwitter = pickFirstUrlByHosts(discogsArtist.urls, ['twitter.com', 'x.com']);
    const derivedYoutube = pickFirstUrlByHosts(discogsArtist.urls, ['youtube.com', 'youtu.be']);
    const mergedAliases = hasAliasesInput
      ? mergeAliases(finalName, requestedAliases)
      : mergeAliases(finalName, [
          ...(target?.aliases ?? []),
          discogsArtist.name,
          discogsArtist.realName,
          ...discogsArtist.nameVariations,
          ...discogsArtist.aliases,
          ...discogsArtist.groups,
        ]);

    let action: 'created' | 'updated' = 'created';
    let previousAvatarUrl: string | null = null;
    let persisted: any;

    if (target) {
      action = 'updated';
      previousAvatarUrl = target.avatarUrl ?? null;
      persisted = await prisma.dJ.update({
        where: { id: target.id },
        data: {
          name: target.name || finalName,
          nameI18n: (normalizeDJBiText(target.nameI18n ?? null, target.name || finalName) as unknown as Prisma.InputJsonValue | null) ?? undefined,
          aliases: mergedAliases,
          genres: hasGenresInput ? requestedGenres : (target.genres ?? []),
          bio: requestedBio || target.bio || derivedBio || null,
          bioI18n: (normalizeDJBiText(target.bioI18n ?? null, requestedBio || target.bio || derivedBio || '') as unknown as Prisma.InputJsonValue | null) ?? undefined,
          country: requestedCountry || target.country || null,
          countryI18n: (normalizeCountryBiText(target.countryI18n ?? null, requestedCountry || target.country || '') as unknown as Prisma.InputJsonValue | null) ?? undefined,
          spotifyId: requestedSpotifyId || target.spotifyId || null,
          spotifyFollowers: hasSpotifyFollowersInput ? requestedSpotifyFollowers : (target.spotifyFollowers ?? null),
          instagramUrl: requestedInstagram || target.instagramUrl || derivedInstagram || null,
          facebookUrl: requestedFacebook || target.facebookUrl || derivedFacebook || null,
          soundcloudUrl: requestedSoundcloud || target.soundcloudUrl || derivedSoundcloud || null,
          soundcloudId: requestedSoundcloudId || target.soundcloudId || null,
          website: requestedWebsite || target.website || null,
          trackCount: hasTrackCountInput ? requestedTrackCount : (target.trackCount ?? null),
          playlistCount: hasPlaylistCountInput ? requestedPlaylistCount : (target.playlistCount ?? null),
          soundCloudFollowers: hasSoundCloudFollowersInput
            ? requestedSoundCloudFollowers
            : (target.soundCloudFollowers ?? null),
          soundCloudFavorites: hasSoundCloudFavoritesInput
            ? requestedSoundCloudFavorites
            : (target.soundCloudFavorites ?? null),
          twitterUrl: requestedTwitter || target.twitterUrl || derivedTwitter || null,
          youtubeUrl: requestedYoutube || target.youtubeUrl || derivedYoutube || null,
          isVerified: target.isVerified || requestedVerified,
          avatarSourceUrl: discogsArtist.primaryImageUrl || target.avatarSourceUrl || null,
          sourceDataSource: mergeDJDataSources(target.sourceDataSource, [
            'discogs',
            requestedSpotifyId ? 'spotify' : null,
          ]),
        },
      });
    } else {
      const slug = await uniqueDJSlugForName(finalName);
      persisted = await prisma.dJ.create({
        data: {
          name: finalName,
          nameI18n: (normalizeDJBiText(payload.nameI18n ?? null, finalName) as unknown as Prisma.InputJsonValue | null) ?? undefined,
          aliases: mergedAliases,
          genres: hasGenresInput ? requestedGenres : [],
          slug,
          bio: requestedBio || derivedBio || null,
          bioI18n: (normalizeDJBiText(payload.bioI18n ?? null, requestedBio || derivedBio || '') as unknown as Prisma.InputJsonValue | null) ?? undefined,
          country: requestedCountry || null,
          countryI18n: (normalizeCountryBiText(payload.countryI18n ?? null, requestedCountry || '') as unknown as Prisma.InputJsonValue | null) ?? undefined,
          spotifyId: requestedSpotifyId || null,
          spotifyFollowers: hasSpotifyFollowersInput ? requestedSpotifyFollowers : null,
          instagramUrl: requestedInstagram || derivedInstagram || null,
          facebookUrl: requestedFacebook || derivedFacebook || null,
          soundcloudUrl: requestedSoundcloud || derivedSoundcloud || null,
          soundcloudId: requestedSoundcloudId || null,
          website: requestedWebsite || null,
          trackCount: hasTrackCountInput ? requestedTrackCount : null,
          playlistCount: hasPlaylistCountInput ? requestedPlaylistCount : null,
          soundCloudFollowers: hasSoundCloudFollowersInput ? requestedSoundCloudFollowers : null,
          soundCloudFavorites: hasSoundCloudFavoritesInput ? requestedSoundCloudFavorites : null,
          twitterUrl: requestedTwitter || derivedTwitter || null,
          youtubeUrl: requestedYoutube || derivedYoutube || null,
          isVerified: requestedVerified,
          avatarSourceUrl: discogsArtist.primaryImageUrl || null,
          avatarUrl: null,
          sourceDataSource: mergeDJDataSources(null, [
            'discogs',
            requestedSpotifyId ? 'spotify' : null,
          ]),
        },
      });
    }

    let avatarUploadedToOss = false;
    let replacedExistingAvatar = false;
    if (discogsArtist.primaryImageUrl) {
      const uploadedAvatar = await uploadRemoteDJAvatarToOss(persisted.id, discogsArtist.primaryImageUrl);
      if (uploadedAvatar) {
        avatarUploadedToOss = true;
        replacedExistingAvatar = Boolean(previousAvatarUrl && previousAvatarUrl !== uploadedAvatar.url);
        const updated = await prisma.dJ.update({
          where: { id: persisted.id },
          data: {
            avatarUrl: uploadedAvatar.url,
            avatarSourceUrl: discogsArtist.primaryImageUrl,
          },
        });
        if (previousAvatarUrl && previousAvatarUrl !== uploadedAvatar.url) {
          await deleteSingleDJMediaOssObjectIfOwned(previousAvatarUrl, persisted.id);
        }
        persisted = updated;
      } else if (!persisted.avatarUrl) {
        persisted = await prisma.dJ.update({
          where: { id: persisted.id },
          data: {
            avatarUrl: discogsArtist.primaryImageUrl,
            avatarSourceUrl: discogsArtist.primaryImageUrl,
          },
        });
      }
    }

    await recordDirectDJContribution(
      {
        id: persisted.id,
        name: persisted.name,
        avatarUrl: persisted.avatarUrl ?? null,
      },
      userId,
      action === 'created' ? 'create' : 'edit',
      'direct_commit'
    );
    if (action === 'created') {
      await createDJEventBindingReviewJobBestEffort(persisted.id, {
        triggerSource: 'admin_create',
        createdById: userId,
      });
    }
    const hydrated = await fetchDJWithContributorsById(persisted.id);
    const mapped = mapDJ(hydrated ?? persisted, false, userId, viewerRole);

    ok(res, {
      action,
      avatarUploadedToOss,
      replacedExistingAvatar,
      dj: mapped,
    });
  } catch (error) {
    if (error instanceof DiscogsUpstreamError) {
      console.error('BFF web discogs dj import upstream error:', {
        code: error.code,
        status: error.status,
        message: error.message,
      });
      res.status(503).json({
        error: 'Discogs 服务暂时不可用，请稍后重试',
        errorCode: error.code,
      });
      return;
    }
    console.error('BFF web discogs dj import error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/djs/manual/import', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    const viewerRole = authReq.user?.role ?? null;

    const payload = (req.body ?? {}) as Record<string, unknown>;
    const manualDjValidationError = validateManualDjPayload(payload);
    if (manualDjValidationError) {
      res.status(400).json({ error: manualDjValidationError });
      return;
    }

    const name = normalizeSubmittedSingleLine(payload.name, INPUT_LIMITS.dj.name);
    if (!name) {
      res.status(400).json({ error: 'name is required' });
      return;
    }

    const avatarUrl = ensureOptionalHttpUrl(normalizeSubmittedUrl(payload.avatarUrl), 'avatarUrl') || '';
    const bannerUrl = ensureOptionalHttpUrl(normalizeSubmittedUrl(payload.bannerUrl), 'bannerUrl') || '';
    const proofImageUrl = ensureOptionalHttpUrl(normalizeSubmittedUrl(payload.proofImageUrl), 'proofImageUrl') || '';
    const spotifyIdForProof = normalizeSubmittedId(payload.spotifyId) || '';
    const spotifyUrl = ensureOptionalHttpUrl(normalizeSubmittedUrl(payload.spotifyUrl), 'spotifyUrl') || '';
    const appleMusicId = normalizeSubmittedId(payload.appleMusicId) || '';
    const instagramUrl = ensureOptionalHttpUrl(normalizeSubmittedUrl(payload.instagramUrl), 'instagramUrl') || '';
    const facebookUrl = ensureOptionalHttpUrl(normalizeSubmittedUrl(payload.facebookUrl), 'facebookUrl') || '';
    const soundcloudUrl = ensureOptionalHttpUrl(normalizeSubmittedUrl(payload.soundcloudUrl), 'soundcloudUrl') || '';
    const twitterUrl = ensureOptionalHttpUrl(normalizeSubmittedUrl(payload.twitterUrl), 'twitterUrl') || '';
    const youtubeUrl = ensureOptionalHttpUrl(normalizeSubmittedUrl(payload.youtubeUrl), 'youtubeUrl') || '';
    const neteaseUrl = ensureOptionalHttpUrl(normalizeSubmittedUrl(payload.neteaseUrl), 'neteaseUrl') || '';
    const qqMusicUrl = ensureOptionalHttpUrl(normalizeSubmittedUrl(payload.qqMusicUrl), 'qqMusicUrl') || '';
    const soundcloudIdForProof = normalizeSubmittedId(payloadValueByKeys(payload, ['soundcloudId', 'soundcloudid'])) || '';
    const website = ensureOptionalHttpUrl(normalizeSubmittedUrl(payloadValueByKeys(payload, ['website', 'websiteUrl', 'officialWebsite'])), 'website') || '';
    const otherPlatformUrl = ensureOptionalHttpUrl(normalizeSubmittedUrl(payloadValueByKeys(payload, ['otherPlatformUrl', 'otherUrl'])), 'otherPlatformUrl') || '';
    const sourceWikipedia = ensureOptionalHttpUrl(normalizeSubmittedUrl(payload.sourceWikipedia), 'sourceWikipedia') || '';
    const sourceWebsite = ensureOptionalHttpUrl(normalizeSubmittedUrl(payload.sourceWebsite), 'sourceWebsite') || '';
    const sourceSameAs = normalizeSubmittedStringArray(payload.sourceSameAs, {
      itemMax: INPUT_LIMITS.common.url,
      maxItems: 50,
    });
    const hasProofLink = [
      spotifyIdForProof,
      spotifyUrl,
      appleMusicId,
      instagramUrl,
      facebookUrl,
      soundcloudUrl,
      soundcloudIdForProof,
      twitterUrl,
      youtubeUrl,
      neteaseUrl,
      qqMusicUrl,
      website,
      otherPlatformUrl,
    ].some((value) => !!value);

    if (!avatarUrl) {
      res.status(400).json({ error: 'avatarUrl is required' });
      return;
    }
    if (!hasProofLink && !proofImageUrl) {
      res.status(400).json({ error: 'At least one platform link or proofImageUrl is required' });
      return;
    }

    if (!canBypassContentReview(viewerRole)) {
      const submission = await createPendingContentSubmission({
        submitterId: userId,
        entityType: 'dj',
        title: name,
        payload: {
          ...payload,
          name,
          avatarUrl,
          bannerUrl: bannerUrl || null,
          proofImageUrl: proofImageUrl || null,
          spotifyId: spotifyIdForProof || null,
          spotifyUrl: spotifyUrl || null,
          appleMusicId: appleMusicId || null,
          instagramUrl: instagramUrl || null,
          facebookUrl: facebookUrl || null,
          soundcloudUrl: soundcloudUrl || null,
          soundcloudId: soundcloudIdForProof || null,
          twitterUrl: twitterUrl || null,
          youtubeUrl: youtubeUrl || null,
          neteaseUrl: neteaseUrl || null,
          qqMusicUrl: qqMusicUrl || null,
          website: website || null,
          otherPlatformUrl: otherPlatformUrl || null,
          sourceWikipedia: sourceWikipedia || null,
          sourceWebsite: sourceWebsite || null,
          sourceSameAs,
          bio: normalizeSubmittedMultiline(payload.bio, INPUT_LIMITS.dj.bio),
          country: normalizeOptionalSingleLine(payload.country, INPUT_LIMITS.dj.country),
          aliases: normalizeSubmittedStringArray(payload.aliases, {
            itemMax: INPUT_LIMITS.dj.alias,
            maxItems: INPUT_LIMITS.dj.aliasesMaxItems,
          }),
          genres: normalizeSubmittedStringArray(payload.genres, {
            itemMax: INPUT_LIMITS.dj.genre,
            maxItems: INPUT_LIMITS.dj.genresMaxItems,
          }),
          importSource: 'manual',
        },
      });
      const submissionMediaUrls = [avatarUrl, bannerUrl, proofImageUrl].filter(Boolean);
      if (submissionMediaUrls.length) {
        await prisma.mediaAsset.updateMany({
          where: {
            ownerType: 'dj-draft',
            uploadedById: userId,
            url: { in: submissionMediaUrls },
            status: 'active',
          },
          data: {
            ownerType: 'content-submission',
            ownerId: submission.id,
          },
        });
      }
      acceptedSubmission(res, submission, 'DJ 信息已提交审核，管理员审核通过后才会入库');
      return;
    }

    const spotifyId = normalizeSubmittedId(payload.spotifyId) || '';
    const aliases = normalizeSubmittedStringArray(payload.aliases, {
      itemMax: INPUT_LIMITS.dj.alias,
      maxItems: INPUT_LIMITS.dj.aliasesMaxItems,
    });
    const bio = normalizeSubmittedMultiline(payload.bio, INPUT_LIMITS.dj.bio) || '';
    const country = normalizeOptionalSingleLine(payload.country, INPUT_LIMITS.dj.country) || '';
    const hasGenresInput = Object.prototype.hasOwnProperty.call(payload, 'genres');
    if (hasGenresInput && payload.genres !== null && !Array.isArray(payload.genres) && typeof payload.genres !== 'string') {
      res.status(400).json({ error: 'genres must be an array, string, or null' });
      return;
    }
    const genres = hasGenresInput
      ? normalizeSubmittedStringArray(payload.genres, {
        itemMax: INPUT_LIMITS.dj.genre,
        maxItems: INPUT_LIMITS.dj.genresMaxItems,
      })
      : [];
    const hasSpotifyFollowersInput = Object.prototype.hasOwnProperty.call(payload, 'spotifyFollowers');
    let spotifyFollowers: number | null = null;
    if (hasSpotifyFollowersInput) {
      try {
        spotifyFollowers = parseOptionalNonNegativeInt(payload.spotifyFollowers, 'spotifyFollowers');
      } catch (error) {
        res.status(400).json({ error: (error as Error).message });
        return;
      }
    }
    const soundcloudId = normalizeSubmittedId(payloadValueByKeys(payload, ['soundcloudId', 'soundcloudid'])) || '';
    const hasTrackCountInput = payloadHasAnyKey(payload, ['trackCount', 'track_count']);
    const hasPlaylistCountInput = payloadHasAnyKey(payload, ['playlistCount', 'playlist_count']);
    const hasSoundCloudFollowersInput = payloadHasAnyKey(payload, [
      'soundCloudFollowers',
      'soundcloudFollowers',
      'followers_count',
    ]);
    const hasSoundCloudFavoritesInput = payloadHasAnyKey(payload, [
      'soundCloudFavorites',
      'soundcloudFavorites',
      'public_favorites_count',
    ]);
    let trackCount: number | null = null;
    let playlistCount: number | null = null;
    let soundCloudFollowers: number | null = null;
    let soundCloudFavorites: number | null = null;
    try {
      if (hasTrackCountInput) {
        trackCount = parseOptionalNonNegativeInt(
          payloadValueByKeys(payload, ['trackCount', 'track_count']),
          'trackCount'
        );
      }
      if (hasPlaylistCountInput) {
        playlistCount = parseOptionalNonNegativeInt(
          payloadValueByKeys(payload, ['playlistCount', 'playlist_count']),
          'playlistCount'
        );
      }
      if (hasSoundCloudFollowersInput) {
        soundCloudFollowers = parseOptionalNonNegativeInt(
          payloadValueByKeys(payload, ['soundCloudFollowers', 'soundcloudFollowers', 'followers_count']),
          'soundCloudFollowers'
        );
      }
      if (hasSoundCloudFavoritesInput) {
        soundCloudFavorites = parseOptionalNonNegativeInt(
          payloadValueByKeys(payload, ['soundCloudFavorites', 'soundcloudFavorites', 'public_favorites_count']),
          'soundCloudFavorites'
        );
      }
    } catch (error) {
      res.status(400).json({ error: (error as Error).message });
      return;
    }
    const isVerified = typeof payload.isVerified === 'boolean' ? payload.isVerified : true;

    const existingBySpotifyId = spotifyId
      ? await prisma.dJ.findFirst({
          where: { spotifyId },
        })
      : null;
    const existingByName = existingBySpotifyId
      ? null
      : await prisma.dJ.findFirst({
          where: { name: { equals: name, mode: 'insensitive' } },
          orderBy: { createdAt: 'asc' },
        });
    const target = existingBySpotifyId ?? existingByName;
    if (target) {
      const allowed = await canUserEditDJ(target.id, userId, viewerRole);
      if (!allowed) {
        res.status(403).json({ error: '仅该 DJ 的贡献者或管理员可修改信息' });
        return;
      }
    }

    const mergedAliases = mergeAliases(name, [...(target?.aliases ?? []), ...aliases]);

    let action: 'created' | 'updated' = 'created';
    let persisted: any;
    if (target) {
      action = 'updated';
      persisted = await prisma.dJ.update({
        where: { id: target.id },
        data: {
          name: target.name || name,
          nameI18n: (normalizeDJBiText(target.nameI18n ?? null, target.name || name) as unknown as Prisma.InputJsonValue | null) ?? undefined,
          aliases: mergedAliases,
          genres: hasGenresInput ? genres : (target.genres ?? []),
          bio: bio || target.bio || null,
          bioI18n: (normalizeDJBiText(target.bioI18n ?? null, bio || target.bio || '') as unknown as Prisma.InputJsonValue | null) ?? undefined,
          avatarUrl: avatarUrl || target.avatarUrl || null,
          avatarSourceUrl: avatarUrl || target.avatarSourceUrl || null,
          bannerUrl: bannerUrl || target.bannerUrl || null,
          country: country || target.country || null,
          countryI18n: (normalizeCountryBiText(target.countryI18n ?? null, country || target.country || '') as unknown as Prisma.InputJsonValue | null) ?? undefined,
          spotifyUrl: spotifyUrl || target.spotifyUrl || null,
          spotifyId: spotifyId || target.spotifyId || null,
          spotifyFollowers: hasSpotifyFollowersInput ? spotifyFollowers : (target.spotifyFollowers ?? null),
          appleMusicId: appleMusicId || target.appleMusicId || null,
          instagramUrl: instagramUrl || target.instagramUrl || null,
          facebookUrl: facebookUrl || target.facebookUrl || null,
          soundcloudUrl: soundcloudUrl || target.soundcloudUrl || null,
          soundcloudId: soundcloudId || target.soundcloudId || null,
          neteaseUrl: neteaseUrl || target.neteaseUrl || null,
          qqMusicUrl: qqMusicUrl || target.qqMusicUrl || null,
          website: website || target.website || null,
          sourceWikipedia: sourceWikipedia || target.sourceWikipedia || null,
          sourceWebsite: sourceWebsite || target.sourceWebsite || null,
          sourceSameAs: sourceSameAs.length ? sourceSameAs : (target.sourceSameAs ?? []),
          trackCount: hasTrackCountInput ? trackCount : (target.trackCount ?? null),
          playlistCount: hasPlaylistCountInput ? playlistCount : (target.playlistCount ?? null),
          soundCloudFollowers: hasSoundCloudFollowersInput
            ? soundCloudFollowers
            : (target.soundCloudFollowers ?? null),
          soundCloudFavorites: hasSoundCloudFavoritesInput
            ? soundCloudFavorites
            : (target.soundCloudFavorites ?? null),
          twitterUrl: twitterUrl || target.twitterUrl || null,
          youtubeUrl: youtubeUrl || target.youtubeUrl || null,
          isVerified: target.isVerified || isVerified,
          sourceDataSource: mergeDJDataSources(target.sourceDataSource, ['manual']),
        },
      });
    } else {
      const slug = await uniqueDJSlugForName(name);
      persisted = await prisma.dJ.create({
        data: {
          name,
          nameI18n: (normalizeDJBiText(payload.nameI18n ?? null, name) as unknown as Prisma.InputJsonValue | null) ?? undefined,
          aliases: mergedAliases,
          genres,
          slug,
          bio: bio || null,
          bioI18n: (normalizeDJBiText(payload.bioI18n ?? null, bio || '') as unknown as Prisma.InputJsonValue | null) ?? undefined,
          avatarUrl,
          avatarSourceUrl: avatarUrl,
          bannerUrl: bannerUrl || null,
          country: country || null,
          countryI18n: (normalizeCountryBiText(payload.countryI18n ?? null, country || '') as unknown as Prisma.InputJsonValue | null) ?? undefined,
          spotifyUrl: spotifyUrl || null,
          spotifyId: spotifyId || null,
          spotifyFollowers,
          appleMusicId: appleMusicId || null,
          instagramUrl: instagramUrl || null,
          facebookUrl: facebookUrl || null,
          soundcloudUrl: soundcloudUrl || null,
          soundcloudId: soundcloudId || null,
          neteaseUrl: neteaseUrl || null,
          qqMusicUrl: qqMusicUrl || null,
          website: website || null,
          sourceWikipedia: sourceWikipedia || null,
          sourceWebsite: sourceWebsite || null,
          sourceSameAs,
          trackCount: hasTrackCountInput ? trackCount : null,
          playlistCount: hasPlaylistCountInput ? playlistCount : null,
          soundCloudFollowers: hasSoundCloudFollowersInput ? soundCloudFollowers : null,
          soundCloudFavorites: hasSoundCloudFavoritesInput ? soundCloudFavorites : null,
          twitterUrl: twitterUrl || null,
          youtubeUrl: youtubeUrl || null,
          isVerified,
          sourceDataSource: mergeDJDataSources(null, ['manual']),
        },
      });
    }

    await recordDirectDJContribution(
      {
        id: persisted.id,
        name: persisted.name,
        avatarUrl: persisted.avatarUrl ?? null,
      },
      userId,
      action === 'created' ? 'create' : 'edit',
      'direct_commit'
    );
    if (action === 'created') {
      await createDJEventBindingReviewJobBestEffort(persisted.id, {
        triggerSource: 'admin_create',
        createdById: userId,
      });
    }
    const hydrated = await fetchDJWithContributorsById(persisted.id);
    const mapped = mapDJ(hydrated ?? persisted, false, userId, viewerRole);

    await upsertDJReleasePublishTaskBestEffort({
      actorUserId: userId,
      operationType: action === 'created' ? 'create' : 'edit',
      sourceRoute: '/v1/djs/manual/import',
      dj: {
        id: mapped.id,
        name: mapped.name,
        bio: mapped.bio ?? null,
        avatarUrl: mapped.avatarUrl ?? null,
      },
    });
    await invalidateDJAdminSummaryCachesBestEffort();

    ok(res, {
      action,
      dj: mapped,
    });
  } catch (error) {
    console.error('BFF web manual dj import error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/admin/dj-event-binding-review/jobs', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const actorId = requireAdminOrOperatorUserId(authReq, res);
    if (!actorId) return;

    const status = typeof req.query.status === 'string' ? req.query.status.trim() : '';
    const page = normalizePage(req.query.page, 1);
    const limit = normalizeLimit(req.query.limit, 20, 100);
    const result = await djEventBindingReviewService.listJobs({
      status: status || undefined,
      page,
      limit,
    });

    ok(res, { items: result.items }, result.pagination);
  } catch (error) {
    console.error('BFF web list DJ event binding review jobs error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/admin/dj-event-binding-review/jobs/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const actorId = requireAdminOrOperatorUserId(authReq, res);
    if (!actorId) return;

    const jobId = typeof req.params.id === 'string' ? req.params.id.trim() : '';
    if (!jobId) {
      res.status(400).json({ error: 'jobId is required' });
      return;
    }

    const job = await djEventBindingReviewService.getJobDetail(jobId);
    ok(res, job);
  } catch (error) {
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2025') {
      res.status(404).json({ error: 'Job not found' });
      return;
    }
    console.error('BFF web get DJ event binding review job detail error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/admin/dj-event-binding-review/jobs/:id/apply', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const actorId = requireAdminOrOperatorUserId(authReq, res);
    if (!actorId) return;

    const jobId = typeof req.params.id === 'string' ? req.params.id.trim() : '';
    const candidateIds = Array.isArray((req.body as Record<string, unknown>)?.candidateIds)
      ? ((req.body as Record<string, unknown>).candidateIds as unknown[])
        .map((item) => (typeof item === 'string' ? item.trim() : ''))
        .filter(Boolean)
      : [];
    if (!jobId) {
      res.status(400).json({ error: 'jobId is required' });
      return;
    }
    if (!candidateIds.length) {
      res.status(400).json({ error: 'candidateIds is required' });
      return;
    }

    const job = await djEventBindingReviewService.applyCandidates(jobId, candidateIds, actorId);
    await adminAuditService.createAction({
      actorId,
      action: 'dj_event_binding_review.apply',
      targetType: 'dj_event_binding_review_job',
      targetId: jobId,
      detail: {
        candidateIds,
      },
    });
    ok(res, job);
  } catch (error) {
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2025') {
      res.status(404).json({ error: 'Job not found' });
      return;
    }
    if (error instanceof Error && /candidateIds is required|No review candidates found/.test(error.message)) {
      res.status(400).json({ error: error.message });
      return;
    }
    console.error('BFF web apply DJ event binding review candidates error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/admin/dj-event-binding-review/jobs/:id/apply-exact', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const actorId = requireAdminOrOperatorUserId(authReq, res);
    if (!actorId) return;

    const jobId = typeof req.params.id === 'string' ? req.params.id.trim() : '';
    if (!jobId) {
      res.status(400).json({ error: 'jobId is required' });
      return;
    }

    const job = await djEventBindingReviewService.applyExactCandidates(jobId, actorId);
    await adminAuditService.createAction({
      actorId,
      action: 'dj_event_binding_review.apply_exact',
      targetType: 'dj_event_binding_review_job',
      targetId: jobId,
      detail: {},
    });
    ok(res, job);
  } catch (error) {
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2025') {
      res.status(404).json({ error: 'Job not found' });
      return;
    }
    console.error('BFF web apply exact DJ event binding review candidates error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/admin/dj-event-binding-review/jobs/:id/dismiss', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const actorId = requireAdminOrOperatorUserId(authReq, res);
    if (!actorId) return;

    const jobId = typeof req.params.id === 'string' ? req.params.id.trim() : '';
    const body = (req.body ?? {}) as Record<string, unknown>;
    const dismissAll = body.dismissAll === true;
    const candidateIds = Array.isArray(body.candidateIds)
      ? (body.candidateIds as unknown[])
        .map((item) => (typeof item === 'string' ? item.trim() : ''))
        .filter(Boolean)
      : [];
    if (!jobId) {
      res.status(400).json({ error: 'jobId is required' });
      return;
    }
    if (!dismissAll && !candidateIds.length) {
      res.status(400).json({ error: 'candidateIds is required' });
      return;
    }

    const job = await djEventBindingReviewService.dismissCandidates(jobId, {
      candidateIds,
      dismissAll,
    });
    await adminAuditService.createAction({
      actorId,
      action: dismissAll ? 'dj_event_binding_review.dismiss_all' : 'dj_event_binding_review.dismiss',
      targetType: 'dj_event_binding_review_job',
      targetId: jobId,
      detail: {
        dismissAll,
        candidateIds,
      },
    });
    ok(res, job);
  } catch (error) {
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2025') {
      res.status(404).json({ error: 'Job not found' });
      return;
    }
    if (error instanceof Error && /candidateIds is required/.test(error.message)) {
      res.status(400).json({ error: error.message });
      return;
    }
    console.error('BFF web dismiss DJ event binding review candidates error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/djs/upload-image', optionalAuth, djImageUpload.single('image'), async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    const viewerRole = authReq.user?.role ?? null;

    const file = (req as Request & { file?: Express.Multer.File }).file;
    if (!file) {
      res.status(400).json({ error: 'No file uploaded' });
      return;
    }

    const formBody = req.body as Record<string, unknown>;
    const djId = typeof formBody.djId === 'string' ? formBody.djId.trim() : '';
    const draftId = typeof formBody.draftId === 'string' ? formBody.draftId.trim() : '';
    const usageRaw = typeof formBody.usage === 'string' ? formBody.usage.trim().toLowerCase() : '';
    const usage: 'avatar' | 'banner' | null =
      usageRaw === 'avatar' || usageRaw === 'banner' ? usageRaw : null;
    const draftUsage: 'avatar' | 'banner' | 'proof' | null =
      usageRaw === 'avatar' || usageRaw === 'banner' || usageRaw === 'proof' ? usageRaw : null;

    if (djId && draftId) {
      await fs.promises.unlink(file.path).catch(() => undefined);
      res.status(400).json({ error: 'djId and draftId cannot be provided together' });
      return;
    }
    if (!djId && !draftId) {
      await fs.promises.unlink(file.path).catch(() => undefined);
      res.status(400).json({ error: 'djId or draftId is required' });
      return;
    }
    if (draftId) {
      if (!draftUsage) {
        await fs.promises.unlink(file.path).catch(() => undefined);
        res.status(400).json({ error: 'usage must be avatar, banner, or proof' });
        return;
      }
      const uploaded = await uploadDJDraftMediaToOss(file, userId, draftId, draftUsage);
      ok(res, uploaded);
      return;
    }
    if (!usage) {
      await fs.promises.unlink(file.path).catch(() => undefined);
      res.status(400).json({ error: 'usage must be avatar or banner' });
      return;
    }

    const existing = await prisma.dJ.findUnique({
      where: { id: djId },
      select: { id: true, name: true, avatarUrl: true, bannerUrl: true },
    });
    if (!existing) {
      await fs.promises.unlink(file.path).catch(() => undefined);
      res.status(404).json({ error: 'DJ not found' });
      return;
    }

    const allowed = await canUserEditDJ(existing.id, userId, viewerRole);
    if (!allowed) {
      await fs.promises.unlink(file.path).catch(() => undefined);
      res.status(403).json({ error: '仅该 DJ 的贡献者或管理员可修改信息' });
      return;
    }

    const uploaded = await uploadDJMediaToOss(file, djId, usage, userId);
    const previousUrl = usage === 'avatar' ? existing.avatarUrl : existing.bannerUrl;

    const nextMediaUrl = usage === 'avatar'
      ? (uploaded.originalUrl || uploaded.url)
      : uploaded.url;

    await prisma.dJ.update({
      where: { id: djId },
      data:
        usage === 'avatar'
          ? {
              avatarUrl: nextMediaUrl,
              avatarSourceUrl: nextMediaUrl,
            }
          : {
              bannerUrl: nextMediaUrl,
            },
    });
    if (previousUrl && previousUrl !== nextMediaUrl) {
      await mediaAssetService.markReplacedByUrl(previousUrl);
    }

    if (previousUrl && previousUrl !== nextMediaUrl) {
      await deleteSingleDJMediaOssObjectIfOwned(previousUrl, djId);
    }

    await recordDirectDJContribution(
      {
        id: djId,
        name: existing.name,
        avatarUrl: usage === 'avatar' ? nextMediaUrl : existing.avatarUrl ?? null,
      },
      userId,
      'edit',
      'direct_media_upload'
    );
    await invalidateDJAdminSummaryCachesBestEffort();

    ok(res, uploaded);
  } catch (error) {
    console.error('BFF web upload dj image error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/djs/delete-images', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const body = (req.body ?? {}) as Record<string, unknown>;
    const draftId = typeof body.draftId === 'string' ? body.draftId.trim() : '';
    const urls = Array.isArray(body.urls)
      ? body.urls
          .map((value) => (typeof value === 'string' ? value.trim() : ''))
          .filter(Boolean)
      : [];

    if (!draftId) {
      res.status(400).json({ error: 'draftId is required' });
      return;
    }
    if (!urls.length) {
      ok(res, { success: true });
      return;
    }

    const assets = await prisma.mediaAsset.findMany({
      where: {
        ownerType: 'dj-draft',
        ownerId: draftId,
        uploadedById: userId,
        url: { in: urls },
        status: { in: ['active', 'replaced'] },
      },
      select: {
        id: true,
        url: true,
        objectKey: true,
      },
    });

    const keys = assets
      .filter((asset) => typeof asset.objectKey === 'string' && isDJDraftOssObjectKey(asset.objectKey, userId, draftId))
      .map((asset) => asset.objectKey as string);

    for (const asset of assets) {
      await mediaAssetService.markDeletedByUrl(asset.url);
    }
    await deleteOssObjects(keys);
    ok(res, { success: true });
  } catch (error) {
    console.error('BFF web delete dj images error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.patch('/djs/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    const viewerRole = authReq.user?.role ?? null;

    const djId = typeof req.params.id === 'string' ? req.params.id.trim() : '';
    if (!djId) {
      res.status(400).json({ error: 'DJ id is required' });
      return;
    }

    const existing = await fetchDJWithContributorsById(djId);
    if (!existing) {
      res.status(404).json({ error: 'DJ not found' });
      return;
    }

    const allowed = await canUserEditDJ(existing.id, userId, viewerRole);
    if (!allowed) {
      res.status(403).json({ error: '仅该 DJ 的贡献者或管理员可修改信息' });
      return;
    }

    const payload = (req.body ?? {}) as Record<string, unknown>;
    const updateData: Prisma.DJUpdateInput = {};
    const hasNameI18nField = Object.prototype.hasOwnProperty.call(payload, 'nameI18n');
    const hasBioI18nField = Object.prototype.hasOwnProperty.call(payload, 'bioI18n');
    const hasCountryI18nField = Object.prototype.hasOwnProperty.call(payload, 'countryI18n');

    let nextName = existing.name;
    let hasNameInput = false;
    if (Object.prototype.hasOwnProperty.call(payload, 'name')) {
      if (typeof payload.name !== 'string') {
        res.status(400).json({ error: 'name must be a string' });
        return;
      }
      const trimmed = payload.name.trim();
      if (!trimmed) {
        res.status(400).json({ error: 'name cannot be empty' });
        return;
      }
      hasNameInput = true;
      nextName = trimmed;
      updateData.name = trimmed;
    }

    const hasAliasesInput = Object.prototype.hasOwnProperty.call(payload, 'aliases');
    if (hasAliasesInput || hasNameInput) {
      let aliasCandidates: string[] = [];

      if (hasAliasesInput) {
        const aliasValue = payload.aliases;
        if (aliasValue !== null && !Array.isArray(aliasValue)) {
          res.status(400).json({ error: 'aliases must be an array or null' });
          return;
        }
        aliasCandidates = Array.isArray(aliasValue)
          ? aliasValue
              .map((item) => (typeof item === 'string' ? item.trim() : ''))
              .filter(Boolean)
          : [];
      } else {
        aliasCandidates = [...(existing.aliases ?? [])];
      }

      if (hasNameInput && normalizeDJNameKey(existing.name) !== normalizeDJNameKey(nextName)) {
        aliasCandidates.push(existing.name);
      }
      updateData.aliases = mergeAliases(nextName, aliasCandidates);
    }

    if (Object.prototype.hasOwnProperty.call(payload, 'genres')) {
      const genreValue = payload.genres;
      if (genreValue === null) {
        updateData.genres = [];
      } else if (Array.isArray(genreValue) || typeof genreValue === 'string') {
        updateData.genres = normalizeGenres(genreValue);
      } else {
        res.status(400).json({ error: 'genres must be an array, string, or null' });
        return;
      }
    }

    if (Object.prototype.hasOwnProperty.call(payload, 'spotifyFollowers')) {
      try {
        updateData.spotifyFollowers = parseOptionalNonNegativeInt(payload.spotifyFollowers, 'spotifyFollowers');
      } catch (error) {
        res.status(400).json({ error: (error as Error).message });
        return;
      }
    }

    if (payloadHasAnyKey(payload, ['trackCount', 'track_count'])) {
      try {
        updateData.trackCount = parseOptionalNonNegativeInt(
          payloadValueByKeys(payload, ['trackCount', 'track_count']),
          'trackCount'
        );
      } catch (error) {
        res.status(400).json({ error: (error as Error).message });
        return;
      }
    }

    if (payloadHasAnyKey(payload, ['playlistCount', 'playlist_count'])) {
      try {
        updateData.playlistCount = parseOptionalNonNegativeInt(
          payloadValueByKeys(payload, ['playlistCount', 'playlist_count']),
          'playlistCount'
        );
      } catch (error) {
        res.status(400).json({ error: (error as Error).message });
        return;
      }
    }

    if (payloadHasAnyKey(payload, ['soundCloudFollowers', 'soundcloudFollowers', 'followers_count'])) {
      try {
        updateData.soundCloudFollowers = parseOptionalNonNegativeInt(
          payloadValueByKeys(payload, ['soundCloudFollowers', 'soundcloudFollowers', 'followers_count']),
          'soundCloudFollowers'
        );
      } catch (error) {
        res.status(400).json({ error: (error as Error).message });
        return;
      }
    }

    if (payloadHasAnyKey(payload, ['soundCloudFavorites', 'soundcloudFavorites', 'public_favorites_count'])) {
      try {
        updateData.soundCloudFavorites = parseOptionalNonNegativeInt(
          payloadValueByKeys(payload, ['soundCloudFavorites', 'soundcloudFavorites', 'public_favorites_count']),
          'soundCloudFavorites'
        );
      } catch (error) {
        res.status(400).json({ error: (error as Error).message });
        return;
      }
    }

    if (payloadHasAnyKey(payload, ['soundcloudId', 'soundcloudid'])) {
      const value = payloadValueByKeys(payload, ['soundcloudId', 'soundcloudid']);
      if (value === null) {
        updateData.soundcloudId = null;
      } else if (typeof value === 'string') {
        updateData.soundcloudId = value.trim() || null;
      } else {
        res.status(400).json({ error: 'soundcloudId must be a string or null' });
        return;
      }
    }

    if (payloadHasAnyKey(payload, ['website', 'websiteUrl', 'officialWebsite'])) {
      const value = payloadValueByKeys(payload, ['website', 'websiteUrl', 'officialWebsite']);
      if (value === null) {
        updateData.website = null;
      } else if (typeof value === 'string') {
        updateData.website = value.trim() || null;
      } else {
        res.status(400).json({ error: 'website must be a string or null' });
        return;
      }
    }

    if (Object.prototype.hasOwnProperty.call(payload, 'spotifyUrl')) {
      const value = payload.spotifyUrl;
      if (value === null) {
        updateData.spotifyUrl = null;
      } else if (typeof value === 'string') {
        updateData.spotifyUrl = value.trim() || null;
      } else {
        res.status(400).json({ error: 'spotifyUrl must be a string or null' });
        return;
      }
    }

    if (Object.prototype.hasOwnProperty.call(payload, 'neteaseUrl')) {
      const value = payload.neteaseUrl;
      if (value === null) {
        updateData.neteaseUrl = null;
      } else if (typeof value === 'string') {
        updateData.neteaseUrl = value.trim() || null;
      } else {
        res.status(400).json({ error: 'neteaseUrl must be a string or null' });
        return;
      }
    }

    if (Object.prototype.hasOwnProperty.call(payload, 'qqMusicUrl')) {
      const value = payload.qqMusicUrl;
      if (value === null) {
        updateData.qqMusicUrl = null;
      } else if (typeof value === 'string') {
        updateData.qqMusicUrl = value.trim() || null;
      } else {
        res.status(400).json({ error: 'qqMusicUrl must be a string or null' });
        return;
      }
    }

    if (Object.prototype.hasOwnProperty.call(payload, 'sourceWikipedia')) {
      const value = payload.sourceWikipedia;
      if (value === null) {
        updateData.sourceWikipedia = null;
      } else if (typeof value === 'string') {
        updateData.sourceWikipedia = value.trim() || null;
      } else {
        res.status(400).json({ error: 'sourceWikipedia must be a string or null' });
        return;
      }
    }

    if (Object.prototype.hasOwnProperty.call(payload, 'sourceWebsite')) {
      const value = payload.sourceWebsite;
      if (value === null) {
        updateData.sourceWebsite = null;
      } else if (typeof value === 'string') {
        updateData.sourceWebsite = value.trim() || null;
      } else {
        res.status(400).json({ error: 'sourceWebsite must be a string or null' });
        return;
      }
    }

    if (Object.prototype.hasOwnProperty.call(payload, 'sourceSameAs')) {
      const value = payload.sourceSameAs;
      if (value === null) {
        updateData.sourceSameAs = [];
      } else if (Array.isArray(value) || typeof value === 'string') {
        updateData.sourceSameAs = normalizeGenres(value);
      } else {
        res.status(400).json({ error: 'sourceSameAs must be an array, string, or null' });
        return;
      }
    }

    const assignOptionalString = (
      payloadKey: string,
      targetKey:
        | 'bio'
        | 'country'
        | 'avatarUrl'
        | 'avatarSourceUrl'
        | 'bannerUrl'
        | 'spotifyUrl'
        | 'spotifyId'
        | 'appleMusicId'
        | 'instagramUrl'
        | 'facebookUrl'
        | 'soundcloudUrl'
        | 'soundcloudId'
        | 'neteaseUrl'
        | 'qqMusicUrl'
        | 'website'
        | 'twitterUrl'
        | 'youtubeUrl'
    ) => {
      if (!Object.prototype.hasOwnProperty.call(payload, payloadKey)) return;
      const value = payload[payloadKey];
      if (value === null) {
        updateData[targetKey] = null;
        return;
      }
      if (typeof value !== 'string') {
        throw new Error(`${payloadKey} must be a string or null`);
      }
      const trimmed = value.trim();
      updateData[targetKey] = trimmed || null;
    };

    try {
      assignOptionalString('bio', 'bio');
      assignOptionalString('country', 'country');
      if (Object.prototype.hasOwnProperty.call(payload, 'avatarUrl')) {
        assignOptionalString('avatarUrl', 'avatarUrl');
        if (typeof payload.avatarUrl === 'string' && payload.avatarUrl.trim()) {
          updateData.avatarSourceUrl = payload.avatarUrl.trim();
        }
      }
      assignOptionalString('bannerUrl', 'bannerUrl');
      assignOptionalString('spotifyUrl', 'spotifyUrl');
      assignOptionalString('spotifyId', 'spotifyId');
      assignOptionalString('appleMusicId', 'appleMusicId');
      assignOptionalString('instagramUrl', 'instagramUrl');
      assignOptionalString('facebookUrl', 'facebookUrl');
      assignOptionalString('soundcloudUrl', 'soundcloudUrl');
      assignOptionalString('soundcloudId', 'soundcloudId');
      assignOptionalString('neteaseUrl', 'neteaseUrl');
      assignOptionalString('qqMusicUrl', 'qqMusicUrl');
      assignOptionalString('website', 'website');
      assignOptionalString('twitterUrl', 'twitterUrl');
      assignOptionalString('youtubeUrl', 'youtubeUrl');
    } catch (error) {
      res.status(400).json({ error: (error as Error).message });
      return;
    }

    if (hasNameI18nField) {
      const normalized = normalizeDJBiText(payload.nameI18n, nextName);
      if (normalized) {
        updateData.nameI18n = normalized as unknown as Prisma.InputJsonValue;
      }
    } else if (hasNameInput) {
      const normalized = normalizeDJBiText(existing.nameI18n ?? null, nextName);
      if (normalized) {
        updateData.nameI18n = normalized as unknown as Prisma.InputJsonValue;
      }
    }

    const hasBioField = Object.prototype.hasOwnProperty.call(payload, 'bio');
    if (hasBioI18nField) {
      const bioSeed = hasBioField
        ? (typeof payload.bio === 'string' ? payload.bio.trim() : '')
        : (existing.bio ?? '');
      const normalized = normalizeDJBiText(payload.bioI18n, bioSeed);
      if (normalized) {
        updateData.bioI18n = normalized as unknown as Prisma.InputJsonValue;
      }
    } else if (hasBioField) {
      const bioSeed = typeof payload.bio === 'string' ? payload.bio.trim() : '';
      const normalized = normalizeDJBiText(existing.bioI18n ?? null, bioSeed);
      if (normalized) {
        updateData.bioI18n = normalized as unknown as Prisma.InputJsonValue;
      }
    }

    const hasCountryField = Object.prototype.hasOwnProperty.call(payload, 'country');
    if (hasCountryI18nField) {
      const countrySeed = hasCountryField
        ? (typeof payload.country === 'string' ? payload.country.trim() : '')
        : (existing.country ?? '');
      const normalized = normalizeCountryBiText(payload.countryI18n, countrySeed);
      if (normalized) {
        updateData.countryI18n = normalized as unknown as Prisma.InputJsonValue;
      }
    } else if (hasCountryField) {
      const countrySeed = typeof payload.country === 'string' ? payload.country.trim() : '';
      const normalized = normalizeCountryBiText(existing.countryI18n ?? null, countrySeed);
      if (normalized) {
        updateData.countryI18n = normalized as unknown as Prisma.InputJsonValue;
      }
    }

    if (Object.prototype.hasOwnProperty.call(payload, 'isVerified')) {
      if (typeof payload.isVerified !== 'boolean') {
        res.status(400).json({ error: 'isVerified must be a boolean' });
        return;
      }
      updateData.isVerified = payload.isVerified;
    }

    if (Object.keys(updateData).length === 0) {
      ok(res, mapDJ(existing, false, userId, viewerRole));
      return;
    }

    const submission = await createPendingContentSubmission({
      submitterId: userId,
      entityType: 'dj',
      title: nextName,
      payload: {
        ...payload,
        name: nextName,
        targetDJId: djId,
      },
    });
    acceptedSubmission(res, submission, 'DJ 编辑任务已提交，当前正在处理中，后续状态会通过通知更新');
  } catch (error) {
    console.error('BFF web update dj error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.delete('/djs/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    const viewerRole = authReq.user?.role ?? null;

    const djId = typeof req.params.id === 'string' ? req.params.id.trim() : '';
    if (!djId) {
      res.status(400).json({ error: 'DJ id is required' });
      return;
    }

    const existing = await prisma.dJ.findUnique({
      where: { id: djId },
      select: {
        id: true,
        avatarUrl: true,
        avatarSourceUrl: true,
        bannerUrl: true,
      },
    });
    if (!existing) {
      res.status(404).json({ error: 'DJ not found' });
      return;
    }

    const allowed = await canUserEditDJ(existing.id, userId, viewerRole);
    if (!allowed) {
      res.status(403).json({ error: '仅该 DJ 的贡献者或管理员可删除' });
      return;
    }

    const urlsToDelete = [
      existing.avatarUrl,
      existing.avatarSourceUrl,
      existing.bannerUrl,
    ].filter((value): value is string => typeof value === 'string' && value.trim().length > 0);

    await prisma.dJ.delete({ where: { id: djId } });
    await notificationCenterService.deleteAdminPublishTasksByEntity({
      entityType: 'dj',
      entityId: djId,
      taskTypes: ['dj_release'],
    });
    await notificationCenterService.deleteAdminContentHistoryByEntity({
      entityType: 'dj',
      entityId: djId,
    });
    await invalidateDJAdminSummaryCachesBestEffort();
    for (const url of urlsToDelete) {
      await mediaAssetService.markDeletedByUrl(url);
      await deleteSingleDJMediaOssObjectIfOwned(url, djId);
    }
    await deleteDJOssFolder(djId);

    ok(res, { success: true });
  } catch (error) {
    console.error('BFF web delete dj error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/djs/:id/sets', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const djId = req.params.id as string;
    const page = normalizePage(req.query.page, 1);
    const limit = normalizeLimit(req.query.limit, 20, 100);
    const start = (page - 1) * limit;
    const sets = await djSetService.getDJSetsByDJ(djId);
    const pageItems = sets.slice(start, start + limit);
    ok(res, { items: pageItems.map(mapDJSet) }, {
      page,
      limit,
      total: sets.length,
      totalPages: Math.ceil(sets.length / limit) || 1,
    });
  } catch (error) {
    console.error('BFF web dj sets error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/djs/:id/events', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = (req as BFFAuthRequest).user?.userId;
    const djId = req.params.id as string;
    const page = normalizePage(req.query.page, 1);
    const limit = normalizeLimit(req.query.limit, 20, 50);
    const skip = (page - 1) * limit;
    const statuses = String(req.query.statuses ?? req.query.status ?? '')
      .split(',')
      .map((value) => value.trim().toLowerCase())
      .filter((value) => value.length > 0);
    const normalizedStatuses = statuses
      .filter((value) => ['upcoming', 'ongoing', 'ended', 'cancelled'].includes(value));
    const statusFilters = normalizedStatuses
      .map((status) => buildEventStatusWhere(status, new Date()))
      .filter((item): item is Prisma.EventWhereInput => Boolean(item));
    const where = {
      canonicalArtists: {
        some: {
          members: {
            some: {
              djId,
            },
          },
        },
      },
      ...(statusFilters.length > 0 ? { OR: statusFilters } : {}),
    } satisfies Prisma.EventWhereInput;
    const [rows, total] = await Promise.all([
      prisma.event.findMany({
        where,
        skip,
        take: limit,
        orderBy: [{ startDate: 'desc' }, { name: 'asc' }],
        select: {
          id: true,
          name: true,
          nameI18n: true,
          slug: true,
          city: true,
          cityI18n: true,
          country: true,
          countryI18n: true,
          manualLocation: true,
          locationPoint: true,
          coverImageUrl: true,
          eventType: true,
          startDate: true,
          endDate: true,
          timeZone: true,
          startTime: true,
          endTime: true,
          dayRolloverHour: true,
          isCancelled: true,
          visibility: true,
          isVerified: true,
          createdAt: true,
          updatedAt: true,
          organizer: {
            select: { id: true, username: true, displayName: true, avatarUrl: true },
          },
        },
      }),
      prisma.event.count({ where }),
    ]);

    const complianceUser = await resolveRegionalComplianceUser(userId);
    ok(
      res,
      { items: rows.map((row) => mapEvent(row, complianceUser)) },
      {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit) || 1,
      }
    );
  } catch (error) {
    console.error('BFF web dj events error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/djs/:id/rating-units', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const djId = req.params.id as string;
    const page = normalizePage(req.query.page, 1);
    const limit = normalizeLimit(req.query.limit, 20, 100);
    const skip = (page - 1) * limit;
    const sourceDJ = await prisma.dJ.findUnique({
      where: { id: djId },
      select: { id: true },
    });
    if (!sourceDJ) {
      res.status(404).json({ error: 'DJ not found' });
      return;
    }

    const where = {
      djBindings: {
        some: {
          djId,
        },
      },
    } satisfies Prisma.RatingUnitWhereInput;

    const [rows, total] = await Promise.all([
      prisma.ratingUnit.findMany({
        where,
        orderBy: [{ createdAt: 'desc' }],
        include: {
          event: {
            select: { id: true, name: true, description: true, imageUrl: true },
          },
          comments: {
            select: { score: true },
          },
          createdBy: {
            select: { id: true, username: true, displayName: true, avatarUrl: true },
          },
        },
        skip,
        take: limit,
      }),
      prisma.ratingUnit.count({ where }),
    ]);

    const linkedRows = await attachLinkedDJsToRatingUnits(rows as any[]);
    ok(res, { items: linkedRows.map((row) => mapRatingUnit(row)) }, {
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit) || 1,
    });
  } catch (error) {
    console.error('BFF web dj rating units error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/djs/followed', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const viewerId = requireAuth(authReq, res);
    if (!viewerId) return;

    const viewerRole = authReq.user?.role ?? null;
    const page = normalizePage(req.query.page, 1);
    const limit = normalizeLimit(req.query.limit, 20, 100);
    const skip = (page - 1) * limit;

    const [followRows, total] = await Promise.all([
      prisma.userEntityFollow.findMany({
        where: {
          userId: viewerId,
          relationType: USER_ENTITY_RELATION_FOLLOW,
          targetType: USER_ENTITY_TARGET_DJ,
        },
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        select: {
          targetId: true,
        },
      }),
      prisma.userEntityFollow.count({
        where: {
          userId: viewerId,
          relationType: USER_ENTITY_RELATION_FOLLOW,
          targetType: USER_ENTITY_TARGET_DJ,
        },
      }),
    ]);

    const orderedDjIds = followRows.map((row) => row.targetId).filter((id): id is string => Boolean(id));
    const djRows = orderedDjIds.length
      ? await prisma.dJ.findMany({
          where: {
            id: {
              in: orderedDjIds,
            },
          },
        })
      : [];
    const djById = new Map(djRows.map((row) => [row.id, row]));

    const rows = await attachDJContributorInfoList(
      orderedDjIds
        .map((djId) => djById.get(djId) ?? null)
        .filter((dj): dj is NonNullable<typeof dj> => Boolean(dj))
    );

    ok(
      res,
      { items: rows.map((row) => mapDJ(row, true, viewerId, viewerRole)) },
      {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit) || 1,
      }
    );
  } catch (error) {
    console.error('BFF web followed djs error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/djs/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const viewerId = authReq.user?.userId;
    const viewerRole = authReq.user?.role ?? null;
    const djId = req.params.id as string;
    const row = await attachDJContributorInfo(
      await prisma.dJ.findUnique({
        where: { id: djId },
      })
    );
    if (!row) {
      res.status(404).json({ error: 'DJ not found' });
      return;
    }

    let isFollowing = false;
    let viewerWatchedCount = 0;
    if (viewerId) {
      const [follow, watchedCount] = await Promise.all([
        prisma.userEntityFollow.findUnique({
          where: userEntityFollowWhere(viewerId, USER_ENTITY_RELATION_FOLLOW, USER_ENTITY_TARGET_DJ, djId),
        }),
        countUserWatchedDJ(viewerId, djId),
      ]);
      isFollowing = Boolean(follow);
      viewerWatchedCount = watchedCount;
    }

    ok(res, mapDJ({ ...row, viewerWatchedCount }, isFollowing, viewerId, viewerRole));
  } catch (error) {
    console.error('BFF web dj detail error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/djs/:id/contributors', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const djId = req.params.id as string;
    const dj = await prisma.dJ.findUnique({
      where: { id: djId },
      select: { id: true },
    });
    if (!dj) {
      res.status(404).json({ error: 'DJ not found' });
      return;
    }

    const contributors = await fetchContributorEntriesForEntity(prisma, 'dj', djId);
    ok(res, {
      items: contributors.map((item) => ({
        user: mapUserLite(item),
        role: item.role,
        firstContributedAt: item.firstContributedAt,
        lastContributedAt: item.lastContributedAt,
        contributionCount: item.contributionCount,
        firstSubmissionId: item.firstSubmissionId,
        lastSubmissionId: item.lastSubmissionId,
        lastContributionSource: item.lastContributionSource,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
      })),
      summary: buildContributorSummary(contributors),
    });
  } catch (error) {
    console.error('BFF dj contributors error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/djs/:id/watched-count', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const djId = req.params.id as string;
    const count = await countUserWatchedDJ(userId, djId);
    ok(res, { count });
  } catch (error) {
    console.error('BFF web dj watched count error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/djs/:id/follow-status', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const djId = req.params.id as string;
    const follow = await prisma.userEntityFollow.findUnique({
      where: userEntityFollowWhere(userId, USER_ENTITY_RELATION_FOLLOW, USER_ENTITY_TARGET_DJ, djId),
    });

    ok(res, { isFollowing: Boolean(follow) });
  } catch (error) {
    console.error('BFF web dj follow status error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/djs/:id/follow', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    const viewerRole = authReq.user?.role ?? null;

    const djId = req.params.id as string;
    const dj = await prisma.dJ.findUnique({ where: { id: djId } });
    if (!dj) {
      res.status(404).json({ error: 'DJ not found' });
      return;
    }

    const existing = await prisma.userEntityFollow.findUnique({
      where: userEntityFollowWhere(userId, USER_ENTITY_RELATION_FOLLOW, USER_ENTITY_TARGET_DJ, djId),
    });

    if (!existing) {
      await prisma.$transaction(async (tx) => {
        await upsertUserEntityRelation(tx, {
          userId,
          relationType: USER_ENTITY_RELATION_FOLLOW,
          targetType: USER_ENTITY_TARGET_DJ,
          targetId: djId,
        });
        await tx.dJ.update({
          where: { id: djId },
          data: {
            followerCount: {
              increment: 1,
            },
          },
        });
      });
    }

    const updated = await attachDJContributorInfo(
      await prisma.dJ.findUnique({
        where: { id: djId },
      })
    );
    ok(res, mapDJ(updated || dj, true, userId, viewerRole));
  } catch (error) {
    console.error('BFF web follow dj error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.delete('/djs/:id/follow', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    const viewerRole = authReq.user?.role ?? null;

    const djId = req.params.id as string;
    const dj = await prisma.dJ.findUnique({ where: { id: djId } });
    if (!dj) {
      res.status(404).json({ error: 'DJ not found' });
      return;
    }

    const existing = await prisma.userEntityFollow.findUnique({
      where: userEntityFollowWhere(userId, USER_ENTITY_RELATION_FOLLOW, USER_ENTITY_TARGET_DJ, djId),
    });

    if (existing) {
      await prisma.$transaction(async (tx) => {
        await deleteUserEntityRelation(tx, {
          userId,
          relationType: USER_ENTITY_RELATION_FOLLOW,
          targetType: USER_ENTITY_TARGET_DJ,
          targetId: djId,
        });
        await tx.dJ.update({
          where: { id: djId },
          data: {
            followerCount: {
              decrement: 1,
            },
          },
        });
      });
    }

    const updated = await attachDJContributorInfo(
      await prisma.dJ.findUnique({
        where: { id: djId },
      })
    );
    ok(res, mapDJ(updated || dj, false, userId, viewerRole));
  } catch (error) {
    console.error('BFF web unfollow dj error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/dj-sets', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const page = normalizePage(req.query.page, 1);
    const limit = normalizeLimit(req.query.limit, 20, 100);
    const sortBy = typeof req.query.sortBy === 'string' ? req.query.sortBy : 'latest';
    const djIdFilter = typeof req.query.djId === 'string' ? req.query.djId.trim() : '';
    const eventIdFilter = typeof req.query.eventId === 'string' ? req.query.eventId.trim() : '';
    const eventNameFilter = typeof req.query.eventName === 'string' ? req.query.eventName.trim() : '';
    const { items, total } = await djSetService.listDJSets({
      page,
      limit,
      sortBy: sortBy === 'popular' || sortBy === 'tracks' ? sortBy : 'latest',
      djId: djIdFilter || undefined,
      eventId: eventIdFilter || undefined,
      eventName: eventNameFilter || undefined,
    });

    ok(
      res,
      { items: items.map(mapDJSet) },
      {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit) || 1,
      }
    );
  } catch (error) {
    console.error('BFF web dj sets list error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/dj-sets/mine', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;
    const page = normalizePage(req.query.page, 1);
    const limit = normalizeLimit(req.query.limit, 20, 100);
    const start = (page - 1) * limit;
    const sets = await djSetService.getDJSetsByUploader(userId);
    const pageItems = sets.slice(start, start + limit);
    ok(res, { items: pageItems.map(mapDJSet) }, {
      page,
      limit,
      total: sets.length,
      totalPages: Math.ceil(sets.length / limit) || 1,
    });
  } catch (error) {
    console.error('BFF web my dj sets error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/dj-sets/preview', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const videoUrl = typeof req.query.videoUrl === 'string' ? req.query.videoUrl.trim() : '';
    if (!videoUrl) {
      res.status(400).json({ error: 'videoUrl is required' });
      return;
    }
    const data = await djSetService.getVideoPreview(videoUrl);
    ok(res, data);
  } catch (error) {
    res.status(500).json({ error: (error as Error).message || 'Internal server error' });
  }
});

router.get('/dj-sets/youtube-embed/:videoId', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  const rawVideoId = String(req.params.videoId || '').trim();
  if (!/^[A-Za-z0-9_-]{11}$/.test(rawVideoId)) {
    res.status(400).type('text/plain; charset=utf-8').send('Invalid YouTube video ID');
    return;
  }

  const embedUrl = `https://www.youtube.com/embed/${rawVideoId}?playsinline=1&rel=0&modestbranding=1`;
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store');
  res.send(`<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1" />
    <meta name="referrer" content="strict-origin-when-cross-origin" />
    <style>
      html, body {
        margin: 0;
        padding: 0;
        width: 100%;
        height: 100%;
        overflow: hidden;
        background: #000;
      }
      iframe {
        display: block;
        width: 100%;
        height: 100%;
        border: 0;
        background: #000;
      }
    </style>
  </head>
  <body>
    <iframe
      id="player"
      src="${embedUrl}"
      title="YouTube video player"
      referrerpolicy="strict-origin-when-cross-origin"
      allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
      allowfullscreen
    ></iframe>
    <script>
      (function () {
        function log(message) {
          console.log('[RaverEmbedPage] ' + message);
        }
        var frame = document.getElementById('player');
        log('page loaded videoId=${rawVideoId} iframeSrc=' + frame.src + ' viewport=' + window.innerWidth + 'x' + window.innerHeight);
        frame.addEventListener('load', function () {
          log('iframe load iframeSrc=' + frame.src + ' size=' + frame.offsetWidth + 'x' + frame.offsetHeight);
        });
        frame.addEventListener('error', function () {
          log('iframe error iframeSrc=' + frame.src);
        });
        window.addEventListener('message', function (event) {
          log('message origin=' + event.origin + ' data=' + (typeof event.data === 'string' ? event.data.slice(0, 200) : '[object]'));
        });
      })();
    </script>
  </body>
</html>`);
});

router.get('/dj-sets/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const setId = req.params.id as string;
    const set = await djSetService.getDJSet(setId);
    if (!set) {
      res.status(404).json({ error: 'DJ set not found' });
      return;
    }
    ok(res, mapDJSet(set));
  } catch (error) {
    console.error('BFF web dj set detail error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/dj-sets/:id/tracklists', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const setId = req.params.id as string;
    const page = normalizePage(req.query.page, 1);
    const limit = normalizeLimit(req.query.limit, 20, 100);
    const start = (page - 1) * limit;
    const set = await djSetService.getDJSet(setId);
    if (!set) {
      res.status(404).json({ error: 'DJ set not found' });
      return;
    }

    const tracklists = await djSetService.getTracklists(setId);
    const pageItems = tracklists.slice(start, start + limit);
    ok(res, { items: pageItems.map(mapTracklistSummary) }, {
      page,
      limit,
      total: tracklists.length,
      totalPages: Math.ceil(tracklists.length / limit) || 1,
    });
  } catch (error) {
    console.error('BFF web dj set tracklists error:', error);
    res.status(500).json({ error: (error as Error).message || 'Internal server error' });
  }
});

router.get('/dj-sets/:setId/tracklists/:tracklistId', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const setId = req.params.setId as string;
    const tracklistId = req.params.tracklistId as string;
    const tracklist = await djSetService.getTracklistById(tracklistId);

    if (!tracklist || tracklist.setId !== setId) {
      res.status(404).json({ error: 'Tracklist not found' });
      return;
    }

    ok(res, mapTracklistDetail(tracklist));
  } catch (error) {
    console.error('BFF web dj set tracklist detail error:', error);
    res.status(500).json({ error: (error as Error).message || 'Internal server error' });
  }
});

router.post('/dj-sets/:id/tracklists', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const setId = req.params.id as string;
    const body = req.body as Record<string, unknown>;
    const title = typeof body.title === 'string' ? body.title.trim() : '';
    const tracksInput = Array.isArray(body.tracks) ? body.tracks : [];

    const tracks = tracksInput
      .filter((item): item is Record<string, unknown> => typeof item === 'object' && item !== null)
      .map((track, index) => ({
        position: typeof track.position === 'number' ? track.position : index + 1,
        startTime: Number(track.startTime || 0),
        endTime: track.endTime === null || track.endTime === undefined || track.endTime === '' ? undefined : Number(track.endTime),
        title: String(track.title || '').trim(),
        artist: String(track.artist || '').trim(),
        status:
          typeof track.status === 'string' && ['released', 'id', 'remix', 'edit'].includes(track.status)
            ? (track.status as 'released' | 'id' | 'remix' | 'edit')
            : 'released',
        spotifyUrl: typeof track.spotifyUrl === 'string' ? track.spotifyUrl : undefined,
        spotifyId: typeof track.spotifyId === 'string' ? track.spotifyId : undefined,
        spotifyUri: typeof track.spotifyUri === 'string' ? track.spotifyUri : undefined,
        neteaseUrl: typeof track.neteaseUrl === 'string' ? track.neteaseUrl : undefined,
        neteaseId: typeof track.neteaseId === 'string' ? track.neteaseId : undefined,
      }))
      .filter((track) => track.title && track.artist);

    if (tracks.length === 0) {
      res.status(400).json({ error: 'tracks is required and must contain valid title/artist rows' });
      return;
    }

    const created = await djSetService.createTracklist(setId, userId, title || undefined, tracks);
    if (!created) {
      res.status(500).json({ error: 'Failed to create tracklist' });
      return;
    }

    res.status(201);
    ok(res, mapTracklistDetail(created));
  } catch (error) {
    const message = (error as Error).message || 'Internal server error';
    if (message === 'DJ set not found') {
      res.status(404).json({ error: message });
      return;
    }
    console.error('BFF web create tracklist error:', error);
    res.status(500).json({ error: message });
  }
});

router.post('/dj-sets', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const body = req.body as Record<string, unknown>;
    const djId = String(body.djId || '').trim();
    const title = String(body.title || '').trim();
    const videoUrl = String(body.videoUrl || '').trim();

    if (!title || !videoUrl) {
      res.status(400).json({ error: 'title and videoUrl are required' });
      return;
    }

    const complianceError = contentCompliance.validationError('set', body);
    if (complianceError) {
      res.status(400).json({ error: complianceError });
      return;
    }

    const inputThumbnailUrl = typeof body.thumbnailUrl === 'string' ? body.thumbnailUrl.trim() : '';
    const uploadedThumbnail = inputThumbnailUrl && shouldMirrorRemoteImageToOss(inputThumbnailUrl)
      ? await uploadRemoteImageToDJSetOss(`draft-${userId}`, inputThumbnailUrl)
      : null;
    const thumbnailUrl = uploadedThumbnail?.url || inputThumbnailUrl || undefined;

    const created = await djSetService.createDJSet({
      djId,
      djIds: Array.isArray(body.djIds)
        ? body.djIds.filter((item): item is string => typeof item === 'string')
        : undefined,
      customDjNames: Array.isArray(body.customDjNames)
        ? body.customDjNames.filter((item): item is string => typeof item === 'string')
        : undefined,
      uploadedById: userId,
      title,
      videoUrl,
      videoAuthorName: typeof body.videoAuthorName === 'string' ? body.videoAuthorName : undefined,
      thumbnailUrl,
      description: typeof body.description === 'string' ? body.description : undefined,
      recordedAt: typeof body.recordedAt === 'string' ? new Date(body.recordedAt) : undefined,
      venue: typeof body.venue === 'string' ? body.venue : undefined,
      eventId: typeof body.eventId === 'string' ? body.eventId : null,
      eventName: typeof body.eventName === 'string' ? body.eventName : undefined,
    });

    ok(res, mapDJSet(created));
  } catch (error) {
    console.error('BFF web create dj set error:', error);
    res.status(500).json({ error: (error as Error).message || 'Internal server error' });
  }
});

router.patch('/dj-sets/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const setId = req.params.id as string;
    const body = req.body as Record<string, unknown>;

    const updated = await djSetService.updateDJSetByUploader(setId, userId, {
      djId: typeof body.djId === 'string' ? body.djId : undefined,
      djIds: Array.isArray(body.djIds)
        ? body.djIds.filter((item): item is string => typeof item === 'string')
        : undefined,
      customDjNames: Array.isArray(body.customDjNames)
        ? body.customDjNames.filter((item): item is string => typeof item === 'string')
        : undefined,
      title: typeof body.title === 'string' ? body.title : undefined,
      description: typeof body.description === 'string' ? body.description : undefined,
      videoUrl: typeof body.videoUrl === 'string' ? body.videoUrl : undefined,
      videoAuthorName: typeof body.videoAuthorName === 'string' ? body.videoAuthorName : undefined,
      thumbnailUrl: typeof body.thumbnailUrl === 'string' ? body.thumbnailUrl : undefined,
      venue: typeof body.venue === 'string' ? body.venue : undefined,
      eventId:
        typeof body.eventId === 'string'
          ? body.eventId
          : body.eventId === null
            ? null
            : undefined,
      eventName: typeof body.eventName === 'string' ? body.eventName : undefined,
      recordedAt: typeof body.recordedAt === 'string' ? new Date(body.recordedAt) : undefined,
    });

    ok(res, mapDJSet(updated));
  } catch (error) {
    const message = (error as Error).message || 'Internal server error';
    if (message === 'Forbidden') {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }
    if (message === 'DJ set not found') {
      res.status(404).json({ error: message });
      return;
    }
    res.status(500).json({ error: message });
  }
});

router.delete('/dj-sets/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const setId = req.params.id as string;
    const deleted = await djSetService.deleteDJSetByUploader(setId, userId, authReq.user?.role);
    await mediaAssetService.markDeletedByUrl(deleted.thumbnailUrl);
    ok(res, { success: true });
  } catch (error) {
    const message = (error as Error).message || 'Internal server error';
    if (message === 'Forbidden') {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }
    if (message === 'DJ set not found') {
      res.status(404).json({ error: message });
      return;
    }
    res.status(500).json({ error: message });
  }
});

router.put('/dj-sets/:id/tracks', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const setId = req.params.id as string;
    const body = req.body as { tracks?: unknown };
    const tracksInput = Array.isArray(body.tracks) ? body.tracks : [];

    const tracks = tracksInput
      .filter((item): item is Record<string, unknown> => typeof item === 'object' && item !== null)
      .map((track, index) => ({
        position: typeof track.position === 'number' ? track.position : index + 1,
        startTime: Number(track.startTime || 0),
        endTime: track.endTime === null || track.endTime === undefined || track.endTime === '' ? undefined : Number(track.endTime),
        title: String(track.title || '').trim(),
        artist: String(track.artist || '').trim(),
        status:
          typeof track.status === 'string' && ['released', 'id', 'remix', 'edit'].includes(track.status)
            ? (track.status as 'released' | 'id' | 'remix' | 'edit')
            : 'released',
        spotifyUrl: typeof track.spotifyUrl === 'string' ? track.spotifyUrl : undefined,
        spotifyId: typeof track.spotifyId === 'string' ? track.spotifyId : undefined,
        spotifyUri: typeof track.spotifyUri === 'string' ? track.spotifyUri : undefined,
        neteaseUrl: typeof track.neteaseUrl === 'string' ? track.neteaseUrl : undefined,
        neteaseId: typeof track.neteaseId === 'string' ? track.neteaseId : undefined,
      }))
      .filter((track) => track.title && track.artist);

    const updated = await djSetService.replaceTracksByUploader(setId, userId, tracks);
    ok(res, mapDJSet(updated));
  } catch (error) {
    const message = (error as Error).message || 'Internal server error';
    if (message === 'Forbidden') {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }
    if (message === 'DJ set not found') {
      res.status(404).json({ error: message });
      return;
    }
    res.status(500).json({ error: message });
  }
});

router.post('/dj-sets/:id/auto-link', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const setId = req.params.id as string;
    const set = await prisma.dJSet.findUnique({ where: { id: setId }, select: { uploadedById: true } });
    if (!set) {
      res.status(404).json({ error: 'DJ set not found' });
      return;
    }
    if (authReq.user?.role !== 'admin' && set.uploadedById !== userId) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    await djSetService.autoLinkTracks(setId);
    ok(res, { success: true });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message || 'Internal server error' });
  }
});

router.post('/dj-sets/upload-thumbnail', optionalAuth, djSetThumbUpload.single('image'), async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const file = (req as Request & { file?: Express.Multer.File }).file;
    if (!file) {
      res.status(400).json({ error: 'No file uploaded' });
      return;
    }

    const uploaded = await uploadDJSetImageToOss(file, `draft-${userId}`, userId);
    ok(res, uploaded);
  } catch (error) {
    console.error('BFF web upload dj set thumbnail error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/dj-sets/upload-video', optionalAuth, djSetVideoUpload.single('video'), async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const file = (req as Request & { file?: Express.Multer.File }).file;
    if (!file) {
      res.status(400).json({ error: 'No file uploaded' });
      return;
    }

    if (looksLikePostMediaName(file.originalname || '', 'video')) {
      const uploaded = await uploadPostMediaToOss(file, 'video', null, userId);
      ok(res, uploaded);
      return;
    }

    if (!shouldAllowLocalUploadFallback()) {
      await fs.promises.unlink(file.path).catch(() => undefined);
      res.status(503).json({ error: 'Object storage is required for DJ set video upload' });
      return;
    }

    const uploaded = await saveUploadedFileToLocalMediaAsset(file, {
      ownerType: 'dj_set',
      ownerId: null,
      purpose: 'video',
      uploadedById: userId,
      localDir: djSetUploadDir,
      publicSubdir: 'dj-sets',
      source: 'v1/dj-sets/upload-video:local-fallback',
    });
    ok(res, uploaded);
  } catch (error) {
    console.error('BFF web upload dj set video error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/dj-sets/:id/comments', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const setId = req.params.id as string;
    const page = normalizePage(req.query.page, 1);
    const limit = normalizeLimit(req.query.limit, 20, 100);
    const start = (page - 1) * limit;
    const comments = await commentService.getComments(setId);
    const pageItems = comments.slice(start, start + limit);
    ok(res, { items: pageItems }, {
      page,
      limit,
      total: comments.length,
      totalPages: Math.ceil(comments.length / limit) || 1,
    });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message || 'Internal server error' });
  }
});

router.post('/dj-sets/:id/comments', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const setId = req.params.id as string;
    const body = req.body as { content?: unknown; parentId?: unknown };
    const content = typeof body.content === 'string' ? body.content : '';
    if (!content.trim()) {
      res.status(400).json({ error: 'content is required' });
      return;
    }

    const comment = await commentService.createComment({
      setId,
      userId,
      content,
      parentId: typeof body.parentId === 'string' ? body.parentId : undefined,
    });

    ok(res, comment);
  } catch (error) {
    const message = (error as Error).message || 'Internal server error';
    if (message === 'DJ Set not found') {
      res.status(404).json({ error: message });
      return;
    }
    if (message.includes('Parent comment')) {
      res.status(400).json({ error: message });
      return;
    }
    res.status(500).json({ error: message });
  }
});

router.patch('/comments/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const commentId = req.params.id as string;
    const body = req.body as { content?: unknown };
    const content = typeof body.content === 'string' ? body.content : '';
    if (!content.trim()) {
      res.status(400).json({ error: 'content is required' });
      return;
    }

    const comment = await commentService.updateComment(commentId, userId, { content });
    ok(res, comment);
  } catch (error) {
    const message = (error as Error).message || 'Internal server error';
    if (message === 'Comment not found') {
      res.status(404).json({ error: message });
      return;
    }
    if (message === 'Forbidden') {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }
    if (message.includes('5分钟')) {
      res.status(400).json({ error: message });
      return;
    }
    res.status(500).json({ error: message });
  }
});

router.delete('/comments/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const commentId = req.params.id as string;
    await commentService.deleteComment(commentId, userId, authReq.user?.role);
    ok(res, { success: true });
  } catch (error) {
    const message = (error as Error).message || 'Internal server error';
    if (message === 'Comment not found') {
      res.status(404).json({ error: message });
      return;
    }
    if (message === 'Forbidden') {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }
    res.status(500).json({ error: message });
  }
});

router.get('/checkins', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const page = normalizePage(req.query.page, 1);
    const limit = normalizeLimit(req.query.limit, 20, 100);
    const skip = (page - 1) * limit;
    const type = typeof req.query.type === 'string' ? req.query.type : undefined;
    const requestedUserId = typeof req.query.userId === 'string' ? req.query.userId.trim() : '';
    const targetUserId = requestedUserId || userId;
    const djId = typeof req.query.djId === 'string' ? req.query.djId.trim() : '';
    const eventId = typeof req.query.eventId === 'string' ? req.query.eventId.trim() : '';

    const where: any = { userId: targetUserId };
    if (type === 'event' || type === 'dj') {
      where.type = type;
    }
    if (djId) where.djId = djId;
    if (eventId) where.eventId = eventId;

    const [rows, total] = await Promise.all([
      prisma.checkin.findMany({
        where,
        skip,
        take: limit,
        orderBy: [{ attendedAt: 'desc' }, { createdAt: 'desc' }],
        include: {
          event: {
            select: {
              id: true,
              name: true,
              nameI18n: true,
              cityI18n: true,
              countryI18n: true,
              manualLocation: true,
              locationPoint: true,
              coverImageUrl: true,
              city: true,
              country: true,
              startDate: true,
              endDate: true,
            },
          },
          dj: {
            select: {
              id: true,
              name: true,
              nameI18n: true,
              avatarUrl: true,
              country: true,
              countryI18n: true,
            },
          },
          selections: {
            orderBy: [{ dayIndex: 'asc' }, { sortOrder: 'asc' }],
            select: {
              dayId: true,
              dayIndex: true,
              djs: {
                orderBy: [{ sortOrder: 'asc' }, { performerIndex: 'asc' }],
                select: {
                  djId: true,
                  displayName: true,
                  actGroupId: true,
                  actType: true,
                  performerIndex: true,
                },
              },
            },
          },
        },
      }),
      prisma.checkin.count({ where }),
    ]);

    ok(
      res,
      {
        items: rows.map((row) => ({
          id: row.id,
          userId: row.userId,
          eventId: row.eventId,
          djId: row.djId,
          type: row.type,
          note: row.note,
          photoUrl: row.photoUrl,
          rating: row.rating,
          attendedAt: row.attendedAt,
          createdAt: row.createdAt,
          event: row.event ? mapEventReference(row.event, { includeCoverImageUrl: true }) : null,
          dj: row.dj,
          selections: row.selections.map((selection) => ({
            dayId: selection.dayId,
            dayIndex: selection.dayIndex,
            djs: selection.djs.map((dj) => ({
              djId: dj.djId,
              displayName: dj.displayName,
              actGroupId: dj.actGroupId ?? `${selection.dayId}:act:${dj.displayName}`,
              actType: dj.actType ?? 'solo',
              performerIndex: dj.performerIndex,
            })),
          })),
        })),
      },
      {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit) || 1,
      }
    );
  } catch (error) {
    console.error('BFF web checkins error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/checkins', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const body = req.body as Record<string, unknown>;
    const type = typeof body.type === 'string' ? body.type.trim() : '';
    if (type !== 'event' && type !== 'dj') {
      res.status(400).json({ error: 'type must be event or dj' });
      return;
    }

    const eventId = typeof body.eventId === 'string' ? body.eventId : null;
    const djId = typeof body.djId === 'string' ? body.djId : null;
    const attendedAt =
      typeof body.attendedAt === 'string' && body.attendedAt.trim().length > 0
        ? new Date(body.attendedAt)
        : null;

    if (type === 'event' && !eventId) {
      res.status(400).json({ error: 'eventId is required for event checkin' });
      return;
    }
    if (type === 'dj' && !djId) {
      res.status(400).json({ error: 'djId is required for dj checkin' });
      return;
    }
    if (attendedAt && Number.isNaN(attendedAt.getTime())) {
      res.status(400).json({ error: 'attendedAt must be a valid ISO datetime' });
      return;
    }

    if (type === 'event' && eventId) {
      const targetEvent = await prisma.event.findUnique({
        where: { id: eventId },
        select: {
          id: true,
          startDate: true,
          endDate: true,
          isCancelled: true,
          visibility: true,
        },
      });

      if (!targetEvent) {
        res.status(404).json({ error: 'Event not found' });
        return;
      }

      const resolvedStatus = deriveEventStatus(
        targetEvent.startDate,
        targetEvent.endDate,
        {
          isCancelled: targetEvent.isCancelled,
          visibility: targetEvent.visibility,
        }
      );
      if (resolvedStatus !== 'ongoing' && resolvedStatus !== 'ended') {
        res.status(400).json({ error: '活动尚未开始或已取消，暂时不能打卡' });
        return;
      }

      const existingAttendance = await prisma.checkin.findFirst({
        where: {
          userId,
          type: 'event',
          eventId,
          NOT: [
            { note: 'marked' },
          ],
        },
        orderBy: [{ attendedAt: 'desc' }, { createdAt: 'desc' }],
      });

      if (existingAttendance) {
        res.status(409).json({ error: '该活动已打卡，请直接编辑原有记录' });
        return;
      }
    }

    const created = await prisma.checkin.create({
      data: {
        userId,
        type,
        // Allow DJ checkins to optionally bind to an event for timeline grouping.
        eventId,
        djId: type === 'dj' ? djId : null,
        note: typeof body.note === 'string' ? body.note : null,
        photoUrl: typeof body.photoUrl === 'string' ? body.photoUrl : null,
        rating: typeof body.rating === 'number' ? body.rating : null,
        attendedAt: attendedAt ?? new Date(),
      },
      include: {
        event: {
          select: {
            id: true,
            name: true,
            nameI18n: true,
            cityI18n: true,
            countryI18n: true,
            manualLocation: true,
            locationPoint: true,
            coverImageUrl: true,
            city: true,
            country: true,
            startDate: true,
            endDate: true,
          },
        },
        dj: {
          select: {
            id: true,
            name: true,
            nameI18n: true,
            avatarUrl: true,
            country: true,
            countryI18n: true,
          },
        },
      },
    });

    ok(res, {
      ...created,
      event: created.event ? mapEventReference(created.event, { includeCoverImageUrl: true }) : null,
    });
  } catch (error) {
    console.error('BFF web create checkin error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.patch('/checkins/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const checkinId = req.params.id as string;
    const existing = await prisma.checkin.findUnique({
      where: { id: checkinId },
      include: {
        event: {
          select: {
            id: true,
            name: true,
            nameI18n: true,
            cityI18n: true,
            countryI18n: true,
            manualLocation: true,
            locationPoint: true,
            coverImageUrl: true,
            city: true,
            country: true,
            startDate: true,
            endDate: true,
          },
        },
        dj: {
          select: {
            id: true,
            name: true,
            nameI18n: true,
            avatarUrl: true,
            country: true,
            countryI18n: true,
          },
        },
      },
    });

    if (!existing) {
      res.status(404).json({ error: 'Checkin not found' });
      return;
    }

    if (authReq.user?.role !== 'admin' && existing.userId !== userId) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const body = req.body as Record<string, unknown>;
    const nextEventId = typeof body.eventId === 'string' ? body.eventId : existing.eventId;
    const nextDjId = typeof body.djId === 'string' ? body.djId : existing.djId;
    const nextNote = typeof body.note === 'string' ? body.note : existing.note;
    const nextRating = typeof body.rating === 'number' ? body.rating : existing.rating;
    const attendedAt =
      typeof body.attendedAt === 'string' && body.attendedAt.trim().length > 0
        ? new Date(body.attendedAt)
        : existing.attendedAt;

    if (Number.isNaN(attendedAt.getTime())) {
      res.status(400).json({ error: 'attendedAt must be a valid ISO datetime' });
      return;
    }

    if (existing.type === 'event' && !nextEventId) {
      res.status(400).json({ error: 'eventId is required for event checkin' });
      return;
    }

    if (existing.type === 'dj' && !nextDjId) {
      res.status(400).json({ error: 'djId is required for dj checkin' });
      return;
    }

    if (existing.type === 'event' && nextEventId) {
      const conflicting = await prisma.checkin.findFirst({
        where: {
          id: { not: checkinId },
          userId,
          type: 'event',
          eventId: nextEventId,
          NOT: [
            { note: 'marked' },
          ],
        },
        orderBy: [{ attendedAt: 'desc' }, { createdAt: 'desc' }],
      });

      if (conflicting) {
        res.status(409).json({ error: '该活动已存在另一条打卡记录' });
        return;
      }
    }

    const updated = await prisma.checkin.update({
      where: { id: checkinId },
      data: {
        eventId: nextEventId ?? null,
        djId: existing.type === 'dj' ? nextDjId : null,
        note: nextNote ?? null,
        rating: nextRating ?? null,
        attendedAt,
      },
      include: {
        event: {
          select: {
            id: true,
            name: true,
            nameI18n: true,
            cityI18n: true,
            countryI18n: true,
            manualLocation: true,
            locationPoint: true,
            coverImageUrl: true,
            city: true,
            country: true,
            startDate: true,
            endDate: true,
          },
        },
        dj: {
          select: {
            id: true,
            name: true,
            nameI18n: true,
            avatarUrl: true,
            country: true,
            countryI18n: true,
          },
        },
      },
    });

    ok(res, {
      ...updated,
      event: updated.event ? mapEventReference(updated.event, { includeCoverImageUrl: true }) : null,
    });
  } catch (error) {
    console.error('BFF web update checkin error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.delete('/checkins/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const checkinId = req.params.id as string;
    const existing = await prisma.checkin.findUnique({
      where: { id: checkinId },
      select: { id: true, userId: true },
    });

    if (!existing) {
      res.status(404).json({ error: 'Checkin not found' });
      return;
    }

    if (authReq.user?.role !== 'admin' && existing.userId !== userId) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    await prisma.checkin.update({
      where: { id: checkinId },
      data: {
        status: 'deleted',
        projectionVersion: 0,
      },
    });
    await refreshUserCheckinProjectionBestEffort(existing.userId);
    ok(res, { success: true });
  } catch (error) {
    console.error('BFF web delete checkin error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/rating/upload-image', optionalAuth, ratingImageUpload.single('image'), async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const file = (req as Request & { file?: Express.Multer.File }).file;
    if (!file) {
      res.status(400).json({ error: 'No file uploaded' });
      return;
    }

    const formBody = req.body as Record<string, unknown>;
    const ratingEventId = typeof formBody.ratingEventId === 'string' ? formBody.ratingEventId.trim() : '';
    const ratingUnitId = typeof formBody.ratingUnitId === 'string' ? formBody.ratingUnitId.trim() : '';
    const usage = typeof formBody.usage === 'string' ? formBody.usage.trim() : '';

    if (ratingEventId) {
      const event = await prisma.ratingEvent.findUnique({
        where: { id: ratingEventId },
        select: { id: true, createdById: true },
      });
      if (!event) {
        await fs.promises.unlink(file.path).catch(() => undefined);
        res.status(404).json({ error: 'Rating event not found' });
        return;
      }
      if (authReq.user?.role !== 'admin' && event.createdById !== userId) {
        await fs.promises.unlink(file.path).catch(() => undefined);
        res.status(403).json({ error: 'Forbidden' });
        return;
      }
    }

    if (ratingUnitId) {
      const unit = await prisma.ratingUnit.findUnique({
        where: { id: ratingUnitId },
        select: { id: true, createdById: true, eventId: true },
      });
      if (!unit) {
        await fs.promises.unlink(file.path).catch(() => undefined);
        res.status(404).json({ error: 'Rating unit not found' });
        return;
      }
      if (authReq.user?.role !== 'admin' && unit.createdById !== userId) {
        await fs.promises.unlink(file.path).catch(() => undefined);
        res.status(403).json({ error: 'Forbidden' });
        return;
      }
    }

    const uploaded = await uploadRatingMediaToOss(
      file,
      {
        userId,
        ratingEventId: ratingEventId || null,
        ratingUnitId: ratingUnitId || null,
      },
      usage || null
    );
    ok(res, uploaded);
  } catch (error) {
    console.error('BFF web upload rating image error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/rating-events', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const page = normalizePage(req.query.page, 1);
    const limit = normalizeLimit(req.query.limit, 20, 100);
    const skip = (page - 1) * limit;
    const [rows, total] = await Promise.all([
      prisma.ratingEvent.findMany({
        orderBy: [{ createdAt: 'desc' }],
        include: {
          createdBy: {
            select: { id: true, username: true, displayName: true, avatarUrl: true },
          },
          units: {
            orderBy: [{ createdAt: 'asc' }],
            include: {
              comments: {
                select: { score: true },
              },
              createdBy: {
                select: { id: true, username: true, displayName: true, avatarUrl: true },
              },
            },
          },
        },
        skip,
        take: limit,
      }),
      prisma.ratingEvent.count(),
    ]);

    const rowsWithLinkedDJs = await Promise.all(
      rows.map(async (row) => ({
        ...row,
        units: await attachLinkedDJsToRatingUnits(row.units as any[]),
      }))
    );

    ok(res, { items: rowsWithLinkedDJs.map(mapRatingEvent) }, {
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit) || 1,
    });
  } catch (error) {
    console.error('BFF web rating events error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/rating-events/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const eventId = req.params.id as string;
    const row = await prisma.ratingEvent.findUnique({
      where: { id: eventId },
      include: {
        createdBy: {
          select: { id: true, username: true, displayName: true, avatarUrl: true },
        },
        units: {
          orderBy: [{ createdAt: 'asc' }],
          include: {
            comments: {
              select: { score: true },
            },
            createdBy: {
              select: { id: true, username: true, displayName: true, avatarUrl: true },
            },
          },
        },
      },
    });

    if (!row) {
      res.status(404).json({ error: 'Rating event not found' });
      return;
    }

    const linkedUnits = await attachLinkedDJsToRatingUnits(row.units as any[]);
    ok(res, mapRatingEvent({ ...row, units: linkedUnits }));
  } catch (error) {
    console.error('BFF web rating event detail error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/rating-events', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    const viewerRole = authReq.user?.role ?? null;

    const body = req.body as Record<string, unknown>;
    const name = typeof body.name === 'string' ? body.name.trim() : '';
    if (!name) {
      res.status(400).json({ error: 'name is required' });
      return;
    }
    const sourceEventId =
      typeof body.sourceEventId === 'string'
        ? body.sourceEventId.trim()
        : typeof body.eventId === 'string'
          ? body.eventId.trim()
          : '';
    if (sourceEventId) {
      const sourceEvent = await prisma.event.findUnique({
        where: { id: sourceEventId },
        select: { id: true },
      });
      if (!sourceEvent) {
        res.status(404).json({ error: 'Source event not found' });
        return;
      }
    }

    if (!canBypassContentReview(viewerRole)) {
      const submission = await createPendingContentSubmission({
        submitterId: userId,
        entityType: 'rating',
        title: name,
        payload: body,
      });
      acceptedSubmission(res, submission, '打分信息已提交审核，管理员审核通过后才会入库');
      return;
    }

    const created = await prisma.ratingEvent.create({
      data: {
        createdById: userId,
        sourceEventId: sourceEventId || null,
        name,
        description: typeof body.description === 'string' ? body.description.trim() || null : null,
        imageUrl: typeof body.imageUrl === 'string' ? body.imageUrl.trim() || null : null,
      },
      include: {
        createdBy: {
          select: { id: true, username: true, displayName: true, avatarUrl: true },
        },
        units: {
          orderBy: [{ createdAt: 'asc' }],
          include: {
            comments: {
              select: { score: true },
            },
            createdBy: {
              select: { id: true, username: true, displayName: true, avatarUrl: true },
            },
          },
        },
      },
    });

    ok(res, mapRatingEvent(created));
  } catch (error) {
    console.error('BFF web create rating event error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/rating-events/from-event', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const body = req.body as Record<string, unknown>;
    const sourceEventId = typeof body.eventId === 'string' ? body.eventId.trim() : '';
    if (!sourceEventId) {
      res.status(400).json({ error: 'eventId is required' });
      return;
    }

    const sourceEvent = await prisma.event.findUnique({
      where: { id: sourceEventId },
      select: {
        id: true,
        name: true,
        description: true,
        coverImageUrl: true,
      },
    });
    if (!sourceEvent) {
      res.status(404).json({ error: 'Event not found' });
      return;
    }

    const sourceSnapshot = await loadCanonicalEventLineupSnapshot(prisma, sourceEventId);
    const snapshotDjIds = Array.from(
      new Set(
        sourceSnapshot.slots.flatMap((slot) => [
          ...(Array.isArray(slot.memberDjIds) ? slot.memberDjIds : []),
          ...(slot.djId ? [slot.djId] : []),
        ])
      )
    ).filter((id): id is string => typeof id === 'string' && !!id.trim());
    const snapshotDjs = snapshotDjIds.length
      ? await prisma.dJ.findMany({
          where: { id: { in: snapshotDjIds } },
          select: { id: true, name: true, avatarUrl: true },
        })
      : [];
    const snapshotDjById = new Map(snapshotDjs.map((dj) => [dj.id, dj]));

    const createdEvent = await prisma.ratingEvent.create({
      data: {
        createdById: userId,
        sourceEventId: sourceEvent.id,
        name: sourceEvent.name,
        description: sourceEvent.description ?? null,
        imageUrl: null,
      },
      select: { id: true },
    });

    let nextEventImageUrl: string | null = null;
    if (sourceEvent.coverImageUrl) {
      const uploadedCover = await uploadRemoteImageToRatingOss(
        {
          userId,
          ratingEventId: createdEvent.id,
        },
        sourceEvent.coverImageUrl,
        'event-cover'
      );
      if (uploadedCover?.url) {
        nextEventImageUrl = uploadedCover.url;
      }
    }

    const performerNamesToResolve = new Set<string>();
    const lineupActNamesBySlot = new Map<string, string[]>();
    for (const slot of sourceSnapshot.slots) {
      const names = parseActPerformerNames(slot.djName);
      lineupActNamesBySlot.set(slot.id || slot.djName, names);
      const firstName = names[0];
      if (firstName) {
        performerNamesToResolve.add(firstName.toLowerCase());
      }
    }

    const nameCandidates = Array.from(performerNamesToResolve);
    const allDJs = nameCandidates.length
      ? await prisma.dJ.findMany({
          where: {
            OR: nameCandidates.map((name) => ({
              name: {
                equals: name,
                mode: 'insensitive',
              },
            })),
          },
          select: { id: true, name: true, avatarUrl: true },
        })
      : [];
    const djByNormalizedName = new Map<string, { id: string; name: string; avatarUrl: string | null }>();
    for (const dj of allDJs) {
      djByNormalizedName.set(dj.name.trim().toLowerCase(), dj);
    }

    for (const slot of sourceSnapshot.slots) {
      const slotKey = slot.id || slot.djName;
      const performerNames = lineupActNamesBySlot.get(slotKey) || [];
      const firstPerformerName = performerNames[0]?.trim() || slot.djName;
      const fallbackLineupDJ = (slot.djId ? snapshotDjById.get(slot.djId) : null) || null;
      const matchedFirstDJ =
        (firstPerformerName
          ? djByNormalizedName.get(firstPerformerName.toLowerCase()) || null
          : null) || fallbackLineupDJ;
      const boundDjIds = Array.from(new Set([
        ...(Array.isArray(slot.memberDjIds) ? slot.memberDjIds : []),
        ...(slot.djId ? [slot.djId] : []),
        ...(matchedFirstDJ?.id ? [matchedFirstDJ.id] : []),
      ]
        .map((id) => String(id || '').trim())
        .filter(Boolean)));
      const primaryDjId = boundDjIds[0] || null;

      let unitImageUrl: string | null = null;
      const sourceAvatarUrl = matchedFirstDJ?.avatarUrl || null;

      const createdUnit = await prisma.$transaction(async (tx) => {
        const unit = await tx.ratingUnit.create({
          data: {
            eventId: createdEvent.id,
            createdById: userId,
            djId: primaryDjId,
            name: slot.djName,
            description: buildRatingUnitDescriptionFromLineupSlot({
              ...slot,
              startTime: slot.startTime,
              endTime: slot.endTime,
            }),
            imageUrl: null,
          },
          select: { id: true },
        });
        await syncRatingUnitDjBindings(tx, unit.id, boundDjIds);
        return unit;
      });

      if (sourceAvatarUrl) {
        const uploadedAvatar = await uploadRemoteImageToRatingOss(
          {
            userId,
            ratingEventId: createdEvent.id,
            ratingUnitId: createdUnit.id,
          },
          sourceAvatarUrl,
          'unit-cover'
        );
        if (uploadedAvatar?.url) {
          unitImageUrl = uploadedAvatar.url;
        }
      }

      if (unitImageUrl) {
        await prisma.ratingUnit.update({
          where: { id: createdUnit.id },
          data: { imageUrl: unitImageUrl },
        });
      }
    }

    await prisma.ratingEvent.update({
      where: { id: createdEvent.id },
      data: {
        imageUrl: nextEventImageUrl,
      },
    });

    const created = await prisma.ratingEvent.findUnique({
      where: { id: createdEvent.id },
      include: {
        createdBy: {
          select: { id: true, username: true, displayName: true, avatarUrl: true },
        },
        units: {
          orderBy: [{ createdAt: 'asc' }],
          include: {
            comments: {
              select: { score: true },
            },
            createdBy: {
              select: { id: true, username: true, displayName: true, avatarUrl: true },
            },
          },
        },
      },
    });

    if (!created) {
      res.status(500).json({ error: 'Failed to create rating event' });
      return;
    }

    const linkedUnits = await attachLinkedDJsToRatingUnits(created.units as any[]);
    ok(res, mapRatingEvent({ ...created, units: linkedUnits }));
  } catch (error) {
    console.error('BFF web create rating event from event error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/rating-events/:id/units', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    const viewerRole = authReq.user?.role ?? null;

    const eventId = req.params.id as string;
    const event = await prisma.ratingEvent.findUnique({
      where: { id: eventId },
      select: { id: true },
    });
    if (!event) {
      res.status(404).json({ error: 'Rating event not found' });
      return;
    }

    const body = req.body as Record<string, unknown>;
    const name = typeof body.name === 'string' ? body.name.trim() : '';
    if (!name) {
      res.status(400).json({ error: 'name is required' });
      return;
    }
    let djBinding: { djId: string | null; djIds: string[] };
    try {
      djBinding = await normalizeRatingUnitDjIdsFromBody(body);
    } catch (error) {
      res.status(404).json({ error: error instanceof Error ? error.message : 'DJ not found' });
      return;
    }

    if (!canBypassContentReview(viewerRole)) {
      const submission = await createPendingContentSubmission({
        submitterId: userId,
        entityType: 'rating',
        title: name,
        payload: {
          ...body,
          name,
          ratingEventId: eventId,
          djId: djBinding.djId,
          djIds: djBinding.djIds,
        },
      });
      acceptedSubmission(res, submission, '打分项目已提交审核，管理员审核通过后才会入库');
      return;
    }

    const created = await prisma.$transaction(async (tx) => {
      const unit = await tx.ratingUnit.create({
        data: {
          eventId,
          createdById: userId,
          djId: djBinding.djId,
          name,
          description: typeof body.description === 'string' ? body.description.trim() || null : null,
          imageUrl: typeof body.imageUrl === 'string' ? body.imageUrl.trim() || null : null,
        },
        include: {
          comments: {
            select: { score: true },
          },
          createdBy: {
            select: { id: true, username: true, displayName: true, avatarUrl: true },
          },
        },
      });
      await syncRatingUnitDjBindings(tx, unit.id, djBinding.djIds);
      return unit;
    });

    const linkedRows = await attachLinkedDJsToRatingUnits([created as any]);
    ok(res, mapRatingUnit(linkedRows[0]));
  } catch (error) {
    console.error('BFF web create rating unit error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.patch('/rating-events/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const eventId = req.params.id as string;
    const existing = await prisma.ratingEvent.findUnique({
      where: { id: eventId },
      select: { id: true, createdById: true, imageUrl: true, sourceEventId: true },
    });
    if (!existing) {
      res.status(404).json({ error: 'Rating event not found' });
      return;
    }
    if (authReq.user?.role !== 'admin' && existing.createdById !== userId) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const body = req.body as Record<string, unknown>;
    const nextImageUrl = typeof body.imageUrl === 'string' ? body.imageUrl.trim() || null : undefined;
    const nextSourceEventId =
      typeof body.sourceEventId === 'string'
        ? body.sourceEventId.trim() || null
        : typeof body.eventId === 'string'
          ? body.eventId.trim() || null
          : body.sourceEventId === null || body.eventId === null
            ? null
            : undefined;
    if (nextSourceEventId) {
      const sourceEvent = await prisma.event.findUnique({
        where: { id: nextSourceEventId },
        select: { id: true },
      });
      if (!sourceEvent) {
        res.status(404).json({ error: 'Source event not found' });
        return;
      }
    }
    const updated = await prisma.ratingEvent.update({
      where: { id: eventId },
      data: {
        name: typeof body.name === 'string' ? body.name.trim() : undefined,
        description: typeof body.description === 'string' ? body.description.trim() || null : undefined,
        imageUrl: nextImageUrl,
        sourceEventId: nextSourceEventId,
      },
      include: {
        createdBy: {
          select: { id: true, username: true, displayName: true, avatarUrl: true },
        },
        units: {
          orderBy: [{ createdAt: 'asc' }],
          include: {
            comments: {
              select: { score: true },
            },
            createdBy: {
              select: { id: true, username: true, displayName: true, avatarUrl: true },
            },
          },
        },
      },
    });

    if (nextImageUrl !== undefined && nextImageUrl !== existing.imageUrl) {
      await mediaAssetService.markDeletedByUrl(existing.imageUrl);
      await deleteSingleRatingOssObjectIfOwned(existing.imageUrl);
    }

    const linkedUnits = await attachLinkedDJsToRatingUnits(updated.units as any[]);
    ok(res, mapRatingEvent({ ...updated, units: linkedUnits }));
  } catch (error) {
    console.error('BFF web update rating event error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.delete('/rating-events/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const eventId = req.params.id as string;
    const existing = await prisma.ratingEvent.findUnique({
      where: { id: eventId },
      select: {
        id: true,
        createdById: true,
        imageUrl: true,
        units: {
          select: { id: true, imageUrl: true },
        },
      },
    });
    if (!existing) {
      res.status(404).json({ error: 'Rating event not found' });
      return;
    }
    if (authReq.user?.role !== 'admin' && existing.createdById !== userId) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    await prisma.ratingEvent.delete({ where: { id: eventId } });
    await mediaAssetService.markDeletedByUrl(existing.imageUrl);
    await deleteSingleRatingOssObjectIfOwned(existing.imageUrl);
    for (const unit of existing.units) {
      await mediaAssetService.markDeletedByUrl(unit.imageUrl);
      await deleteSingleRatingOssObjectIfOwned(unit.imageUrl);
    }
    ok(res, { success: true });
  } catch (error) {
    console.error('BFF web delete rating event error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/rating-units/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const unitId = req.params.id as string;
    const row = await prisma.ratingUnit.findUnique({
      where: { id: unitId },
      include: {
        event: {
          select: { id: true, name: true, description: true, imageUrl: true },
        },
        djBindings: {
          orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
          select: { djId: true },
        },
        comments: {
          orderBy: [{ createdAt: 'desc' }],
          include: {
            user: {
              select: { id: true, username: true, displayName: true, avatarUrl: true },
            },
          },
        },
        createdBy: {
          select: { id: true, username: true, displayName: true, avatarUrl: true },
        },
      },
    });

    if (!row) {
      res.status(404).json({ error: 'Rating unit not found' });
      return;
    }

    const linkedRows = await attachLinkedDJsToRatingUnits([row as any]);
    ok(res, {
      ...mapRatingUnit(linkedRows[0], true),
      event: row.event,
    });
  } catch (error) {
    console.error('BFF web rating unit detail error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.patch('/rating-units/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const unitId = req.params.id as string;
    const existing = await prisma.ratingUnit.findUnique({
      where: { id: unitId },
      select: { id: true, createdById: true, imageUrl: true },
    });
    if (!existing) {
      res.status(404).json({ error: 'Rating unit not found' });
      return;
    }
    if (authReq.user?.role !== 'admin' && existing.createdById !== userId) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const body = req.body as Record<string, unknown>;
    const nextImageUrl = typeof body.imageUrl === 'string' ? body.imageUrl.trim() || null : undefined;
    const shouldUpdateDjBinding = Object.prototype.hasOwnProperty.call(body, 'djId') || Object.prototype.hasOwnProperty.call(body, 'djIds');
    let djBinding: { djId: string | null; djIds: string[] } | undefined;
    if (shouldUpdateDjBinding) {
      try {
        djBinding = await normalizeRatingUnitDjIdsFromBody(body);
      } catch (error) {
        res.status(404).json({ error: error instanceof Error ? error.message : 'DJ not found' });
        return;
      }
    }
    const updated = await prisma.$transaction(async (tx) => {
      const unit = await tx.ratingUnit.update({
        where: { id: unitId },
        data: {
          name: typeof body.name === 'string' ? body.name.trim() : undefined,
          description: typeof body.description === 'string' ? body.description.trim() || null : undefined,
          imageUrl: nextImageUrl,
          djId: shouldUpdateDjBinding ? djBinding?.djId ?? null : undefined,
        },
        include: {
          comments: {
            select: { score: true },
          },
          createdBy: {
            select: { id: true, username: true, displayName: true, avatarUrl: true },
          },
        },
      });
      if (shouldUpdateDjBinding) {
        await syncRatingUnitDjBindings(tx, unitId, djBinding?.djIds ?? []);
      }
      return unit;
    });

    if (nextImageUrl !== undefined && nextImageUrl !== existing.imageUrl) {
      await deleteSingleRatingOssObjectIfOwned(existing.imageUrl);
    }

    const linkedRows = await attachLinkedDJsToRatingUnits([updated as any]);
    ok(res, mapRatingUnit(linkedRows[0]));
  } catch (error) {
    console.error('BFF web update rating unit error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.delete('/rating-units/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const unitId = req.params.id as string;
    const existing = await prisma.ratingUnit.findUnique({
      where: { id: unitId },
      select: { id: true, createdById: true, imageUrl: true },
    });
    if (!existing) {
      res.status(404).json({ error: 'Rating unit not found' });
      return;
    }
    if (authReq.user?.role !== 'admin' && existing.createdById !== userId) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    await prisma.ratingUnit.delete({ where: { id: unitId } });
    await deleteSingleRatingOssObjectIfOwned(existing.imageUrl);
    ok(res, { success: true });
  } catch (error) {
    console.error('BFF web delete rating unit error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/rating-units/:id/comments', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const unitId = req.params.id as string;
    const body = req.body as Record<string, unknown>;
    const content = typeof body.content === 'string' ? body.content.trim() : '';
    const score = typeof body.score === 'number' ? Math.round(body.score) : NaN;

    if (!Number.isFinite(score) || score < 1 || score > 10) {
      res.status(400).json({ error: '请先评分' });
      return;
    }
    if (!content) {
      res.status(400).json({ error: 'content is required' });
      return;
    }

    const unit = await prisma.ratingUnit.findUnique({
      where: { id: unitId },
      select: { id: true },
    });
    if (!unit) {
      res.status(404).json({ error: 'Rating unit not found' });
      return;
    }

    const comment = await prisma.ratingComment.create({
      data: {
        unitId,
        userId,
        score,
        content,
      },
      include: {
        user: {
          select: { id: true, username: true, displayName: true, avatarUrl: true },
        },
      },
    });

    ok(res, mapRatingComment(comment));
  } catch (error) {
    console.error('BFF web create rating comment error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

type LearnGenreTreeNode = {
  id: string;
  name: string;
  nameI18n: TriTextPayload | null;
  path: string;
  themeColor: string;
  description: string;
  descriptionI18n: TriTextPayload | null;
  example: string;
  exampleI18n: TriTextPayload | null;
  soundCueTracks: LearnGenreSoundCueTrack[];
  origin: string;
  era: string;
  bpm: string;
  backgroundImageURL: string;
  spotifyTrackURL: string;
  wikipediaURL: string;
  keyArtists: string[];
  keyArtistBindings: LearnGenreKeyArtistBinding[];
  children: LearnGenreTreeNode[];
};

type LearnGenreTreeSummaryNode = {
  id: string;
  name: string;
  path: string;
  themeColor: string;
  children: LearnGenreTreeSummaryNode[];
};

type LearnGenreDetailNode = {
  id: string;
  name: string;
  nameI18n: TriTextPayload | null;
  path: string;
  themeColor: string;
  description: string;
  descriptionI18n: TriTextPayload | null;
  example: string;
  exampleI18n: TriTextPayload | null;
  soundCueTracks: LearnGenreSoundCueTrack[];
  origin: string;
  era: string;
  bpm: string;
  backgroundImageURL: string;
  spotifyTrackURL: string;
  wikipediaURL: string;
  keyArtists: string[];
  keyArtistBindings: LearnGenreKeyArtistBinding[];
};

type LearnGenreKeyArtistBinding = {
  name: string;
  djId: string | null;
  dj: {
    id: string;
    name: string;
    avatarUrl: string | null;
    avatarMediumUrl: string | null;
  } | null;
};

type LearnGenreSoundCueTrack = {
  title: string;
  artist: string;
  spotifyUrl: string | null;
  appleMusicUrl: string | null;
  neteaseUrl: string | null;
  soundcloudUrl: string | null;
  beatportUrl: string | null;
};

type GenreThemeRow = {
  id: string;
  parentId: string | null;
  color: string | null;
};

const normalizeGenreKeyArtistBindings = (
  keyArtists: string[],
  rawBindings: unknown,
  djById: Map<string, any> = new Map()
): LearnGenreKeyArtistBinding[] => {
  const bindingByName = new Map<string, string | null>();
  if (Array.isArray(rawBindings)) {
    for (const item of rawBindings) {
      if (!item || typeof item !== 'object') continue;
      const record = item as Record<string, unknown>;
      const name = typeof record.name === 'string' ? record.name.trim() : '';
      if (!name) continue;
      const djId = typeof record.djId === 'string' && record.djId.trim() ? record.djId.trim() : null;
      bindingByName.set(name.toLowerCase(), djId);
    }
  }

  return keyArtists.map((name) => {
    const djId = bindingByName.get(name.toLowerCase()) ?? null;
    const dj = djId ? djById.get(djId) : null;
    const avatarUrl = dj && typeof dj.avatarUrl === 'string' && dj.avatarUrl.trim() ? dj.avatarUrl.trim() : null;
    return {
      name,
      djId,
      dj: dj
        ? {
            id: dj.id,
            name: dj.name,
            avatarUrl,
            avatarMediumUrl: buildOssAvatarVariantUrl(avatarUrl, dj.id, 'medium'),
          }
        : null,
    };
  });
};

const normalizeGenreEditableText = (value: unknown): string | null => {
  if (typeof value !== 'string') return null;
  const text = value.trim();
  return text ? text : null;
};

const ELECTRONIC_MUSIC_GENRE_ID = 'electronic-music';

const normalizeGenreThemeColor = (value: unknown): string | null => {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim().replace(/^#/, '');
  if (!trimmed) return null;
  const expanded = trimmed.length === 3
    ? trimmed.split('').map((char) => `${char}${char}`).join('')
    : trimmed;
  if (!/^[0-9a-fA-F]{6}$/.test(expanded)) {
    return null;
  }
  return `#${expanded.toUpperCase()}`;
};

const buildGenreBranchThemeColorLookup = <TRow extends GenreThemeRow>(rows: TRow[]): Map<string, string | null> => {
  const byId = new Map(rows.map((row) => [row.id, row]));
  const memo = new Map<string, string | null>();

  const resolve = (row: TRow): string | null => {
    const cached = memo.get(row.id);
    if (cached !== undefined) {
      return cached;
    }

    let current: TRow | undefined = row;
    while (current?.parentId) {
      const parent = byId.get(current.parentId);
      if (!parent) break;
      if (parent.id === ELECTRONIC_MUSIC_GENRE_ID) {
        const color = normalizeGenreThemeColor(current.color);
        memo.set(row.id, color);
        return color;
      }
      current = parent;
    }

    const fallback = row.parentId == null && row.id !== ELECTRONIC_MUSIC_GENRE_ID
      ? normalizeGenreThemeColor(row.color)
      : null;
    memo.set(row.id, fallback);
    return fallback;
  };

  for (const row of rows) {
    resolve(row);
  }

  return memo;
};

const normalizeGenreSoundCueTracks = (value: unknown): LearnGenreSoundCueTrack[] => {
  if (!Array.isArray(value)) return [];
  const out: LearnGenreSoundCueTrack[] = [];
  for (const item of value) {
    if (!item || typeof item !== 'object') continue;
    const row = item as Record<string, unknown>;
    const title = typeof row.title === 'string' ? row.title.trim() : '';
    const artist = typeof row.artist === 'string' ? row.artist.trim() : '';
    if (!title) continue;
    out.push({
      title,
      artist,
      spotifyUrl: normalizeGenreEditableText(row.spotifyUrl),
      appleMusicUrl: normalizeGenreEditableText(row.appleMusicUrl),
      neteaseUrl: normalizeGenreEditableText(row.neteaseUrl),
      soundcloudUrl: normalizeGenreEditableText(row.soundcloudUrl),
      beatportUrl: normalizeGenreEditableText(row.beatportUrl),
    });
  }
  return out;
};

const normalizeGenreKeyArtistsInput = (value: unknown): string[] => {
  if (!Array.isArray(value)) return [];
  const seen = new Set<string>();
  const out: string[] = [];
  for (const item of value) {
    const name = typeof item === 'string' ? item.trim() : '';
    const key = name.toLowerCase();
    if (!name || seen.has(key)) continue;
    seen.add(key);
    out.push(name);
  }
  return out;
};

const parseGenreSortOrder = (value: unknown): number | null => {
  if (value === null || value === undefined || value === '') return null;
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return null;
  return Math.floor(parsed);
};

const uniqueGenreSlug = async (name: string, requestedSlug?: string, excludeId?: string | null): Promise<string> => {
  const base = slugify(requestedSlug || name) || `genre-${Date.now()}`;
  let candidate = base;
  let seq = 1;
  while (true) {
    const existing = await prisma.genre.findUnique({
      where: { slug: candidate },
      select: { id: true },
    });
    if (!existing || (excludeId && existing.id === excludeId)) {
      return candidate;
    }
    seq += 1;
    candidate = `${base}-${seq}`;
  }
};

const fetchLatestEntityChangePayloadForHistory = async (
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
  return {
    changeLogId: row?.id ?? null,
    publicSummaryZh: row?.publicSummaryZh ?? null,
    publicSummaryEn: row?.publicSummaryEn ?? null,
    publicSummaryJa: row?.publicSummaryJa ?? null,
    publicChanges: row?.publicChanges ?? [],
  };
};

const upsertEventReleasePublishTaskBestEffort = async (input: {
  actorUserId: string;
  operationType: 'create' | 'edit';
  sourceRoute?: string | null;
  event: {
    id: string;
    name: string;
    description?: string | null;
    coverImageUrl?: string | null;
    timeZone?: string | null;
    startDate?: Date | string | null;
    wikiFestivalId?: string | null;
    lineupArtists?: Array<{
      djId?: string | null;
      memberDjIds?: Array<string | null>;
    }> | null;
  };
}): Promise<void> => {
  try {
    const changePayload = await fetchLatestEntityChangePayloadForHistory('event', input.event.id);
    const djIds = Array.from(
      new Set(
        (Array.isArray(input.event.lineupArtists) ? input.event.lineupArtists : []).flatMap((artist) => {
          const primary = typeof artist?.djId === 'string' ? artist.djId.trim() : '';
          const members = Array.isArray(artist?.memberDjIds)
            ? artist.memberDjIds
                .map((value) => (typeof value === 'string' ? value.trim() : ''))
                .filter(Boolean)
            : [];
          return primary ? [primary, ...members] : members;
        })
      )
    );

    const task = await notificationCenterService.upsertAdminPublishTask({
      taskType: 'event_release',
      entityType: 'event',
      entityId: input.event.id,
      title: input.event.name,
      summary: (typeof input.event.description === 'string' && input.event.description.trim()) || input.event.name,
      createdBy: input.actorUserId,
      payload: {
        eventId: input.event.id,
        title: input.event.name,
        summary:
          (typeof input.event.description === 'string' && input.event.description.trim()) || input.event.name,
        coverImageURL: input.event.coverImageUrl ?? null,
        timeZone: input.event.timeZone ?? null,
        startDate:
          input.event.startDate instanceof Date
            ? input.event.startDate.toISOString()
            : typeof input.event.startDate === 'string'
              ? input.event.startDate
              : null,
        wikiFestivalId: input.event.wikiFestivalId ?? null,
        djIds,
        ...changePayload,
      },
    });
    await notificationCenterService.createAdminContentHistory({
      entityType: 'event',
      entityId: input.event.id,
      taskType: 'event_release',
      operationType: input.operationType,
      resultStatus: 'success',
      pushStatus: 'pending',
      title: input.event.name,
      summary: (typeof input.event.description === 'string' && input.event.description.trim()) || input.event.name,
      payload: {
        eventId: input.event.id,
        title: input.event.name,
        summary:
          (typeof input.event.description === 'string' && input.event.description.trim()) || input.event.name,
        coverImageURL: input.event.coverImageUrl ?? null,
        timeZone: input.event.timeZone ?? null,
        startDate:
          input.event.startDate instanceof Date
            ? input.event.startDate.toISOString()
            : typeof input.event.startDate === 'string'
              ? input.event.startDate
              : null,
        wikiFestivalId: input.event.wikiFestivalId ?? null,
        djIds,
        ...changePayload,
      },
      sourceRoute: input.sourceRoute,
      createdBy: input.actorUserId,
      linkedTaskId: task.id,
    });
  } catch (error) {
    console.warn('BFF web event publish task upsert failed:', {
      eventId: input.event.id,
      error: error instanceof Error ? error.message : String(error),
    });
  }
};

const upsertDJReleasePublishTaskBestEffort = async (input: {
  actorUserId: string;
  operationType: 'create' | 'edit';
  sourceRoute?: string | null;
  dj: {
    id: string;
    name: string;
    bio?: string | null;
    avatarUrl?: string | null;
  };
}): Promise<void> => {
  try {
    const changePayload = await fetchLatestEntityChangePayloadForHistory('dj', input.dj.id);
    const task = await notificationCenterService.upsertAdminPublishTask({
      taskType: 'dj_release',
      entityType: 'dj',
      entityId: input.dj.id,
      title: input.dj.name,
      summary: (typeof input.dj.bio === 'string' && input.dj.bio.trim()) || input.dj.name,
      createdBy: input.actorUserId,
      payload: {
        djId: input.dj.id,
        title: input.dj.name,
        summary: (typeof input.dj.bio === 'string' && input.dj.bio.trim()) || input.dj.name,
        coverImageURL: input.dj.avatarUrl ?? null,
        ...changePayload,
      },
    });
    await notificationCenterService.createAdminContentHistory({
      entityType: 'dj',
      entityId: input.dj.id,
      taskType: 'dj_release',
      operationType: input.operationType,
      resultStatus: 'success',
      pushStatus: 'pending',
      title: input.dj.name,
      summary: (typeof input.dj.bio === 'string' && input.dj.bio.trim()) || input.dj.name,
      payload: {
        djId: input.dj.id,
        title: input.dj.name,
        summary: (typeof input.dj.bio === 'string' && input.dj.bio.trim()) || input.dj.name,
        coverImageURL: input.dj.avatarUrl ?? null,
        ...changePayload,
      },
      sourceRoute: input.sourceRoute,
      createdBy: input.actorUserId,
      linkedTaskId: task.id,
    });
  } catch (error) {
    console.warn('BFF web DJ publish task upsert failed:', {
      djId: input.dj.id,
      error: error instanceof Error ? error.message : String(error),
    });
  }
};

const upsertBrandReleasePublishTaskBestEffort = async (input: {
  actorUserId: string;
  operationType: 'create' | 'edit';
  sourceRoute?: string | null;
  brand: {
    id: string;
    name: string;
    summary?: string | null;
    coverImageURL?: string | null;
  };
  entityType: 'festival' | 'label';
}): Promise<void> => {
  try {
    const changePayload = input.entityType === 'festival'
      ? await fetchLatestEntityChangePayloadForHistory('brand', input.brand.id)
      : {
          changeLogId: null,
          publicSummaryZh: null,
          publicSummaryEn: null,
          publicSummaryJa: null,
          publicChanges: [],
        };
    const task = await notificationCenterService.upsertAdminPublishTask({
      taskType: 'brand_release',
      entityType: input.entityType,
      entityId: input.brand.id,
      title: input.brand.name,
      summary: (typeof input.brand.summary === 'string' && input.brand.summary.trim()) || input.brand.name,
      createdBy: input.actorUserId,
      payload: {
        brandId: input.brand.id,
        brandEntityType: input.entityType,
        title: input.brand.name,
        summary: (typeof input.brand.summary === 'string' && input.brand.summary.trim()) || input.brand.name,
        coverImageURL: input.brand.coverImageURL ?? null,
        ...changePayload,
      },
    });
    await notificationCenterService.createAdminContentHistory({
      entityType: input.entityType,
      entityId: input.brand.id,
      taskType: 'brand_release',
      operationType: input.operationType,
      resultStatus: 'success',
      pushStatus: 'pending',
      title: input.brand.name,
      summary: (typeof input.brand.summary === 'string' && input.brand.summary.trim()) || input.brand.name,
      payload: {
        brandId: input.brand.id,
        brandEntityType: input.entityType,
        title: input.brand.name,
        summary: (typeof input.brand.summary === 'string' && input.brand.summary.trim()) || input.brand.name,
        coverImageURL: input.brand.coverImageURL ?? null,
        ...changePayload,
      },
      sourceRoute: input.sourceRoute,
      createdBy: input.actorUserId,
      linkedTaskId: task.id,
    });
  } catch (error) {
    console.warn('BFF web brand publish task upsert failed:', {
      brandId: input.brand.id,
      entityType: input.entityType,
      error: error instanceof Error ? error.message : String(error),
    });
  }
};

const buildGenrePath = (parentPath: string | null, slug: string): string =>
  parentPath ? `${parentPath}/${slug}` : slug;

const updateGenreSubtreePaths = async (
  tx: Prisma.TransactionClient,
  genreId: string,
  nextPath: string
): Promise<void> => {
  const children = await tx.genre.findMany({
    where: { parentId: genreId },
    select: { id: true, slug: true },
  });

  for (const child of children) {
    const childPath = buildGenrePath(nextPath, child.slug);
    await tx.genre.update({
      where: { id: child.id },
      data: { path: childPath },
    });
    await updateGenreSubtreePaths(tx, child.id, childPath);
  }
};

const ensureGenreDeleteSafe = async (genreId: string): Promise<void> => {
  const [childCount, bindingCount] = await Promise.all([
    prisma.genre.count({ where: { parentId: genreId } }),
    prisma.dJGenreBinding.count({ where: { genreId } }),
  ]);
  if (childCount > 0) {
    throw new Error('请先删除或移动子流派节点');
  }
  if (bindingCount > 0) {
    throw new Error('该流派仍然绑定了 DJ，不能直接删除');
  }
};

const selectGenreDJLite = {
  id: true,
  name: true,
  aliases: true,
  avatarUrl: true,
} satisfies Prisma.DJSelect;

const ONBOARDING_GENRE_OPTION_LIMIT = 24;
const ONBOARDING_BRAND_OPTION_LIMIT = 10;
const ONBOARDING_DJ_OPTION_LIMIT = 18;
const ONBOARDING_DJ_CANDIDATE_LIMIT = 100;

type OnboardingGenreOption = {
  id: string;
  name: string;
  level: number;
};

const shuffleArray = <T>(items: T[]): T[] => {
  const next = [...items];
  for (let i = next.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1));
    [next[i], next[j]] = [next[j], next[i]];
  }
  return next;
};

const uniqueOnboardingGenreOptions = (items: OnboardingGenreOption[]): OnboardingGenreOption[] => {
  const seen = new Set<string>();
  const out: OnboardingGenreOption[] = [];
  for (const item of items) {
    if (seen.has(item.id)) continue;
    seen.add(item.id);
    out.push(item);
  }
  return out;
};

const sampleOnboardingGenreOptions = (
  rows: Array<{ id: string; name: string; parentId: string | null; sortOrder: number }>
): OnboardingGenreOption[] => {
  const byParentId = new Map<string | null, typeof rows>();
  for (const row of rows) {
    const siblings = byParentId.get(row.parentId) ?? [];
    siblings.push(row);
    byParentId.set(row.parentId, siblings);
  }

  const roots = byParentId.get(null) ?? [];
  const electronicRoot = roots.find((row) => row.id === 'electronic-music');
  const flatten = (items: typeof rows, level: number): OnboardingGenreOption[] =>
    items.flatMap((row) => [
      { id: row.id, name: row.name, level },
      ...flatten(byParentId.get(row.id) ?? [], level + 1),
    ]);

  const flattened = flatten(electronicRoot ? (byParentId.get(electronicRoot.id) ?? []) : roots, 0);
  const byLevel = new Map<number, OnboardingGenreOption[]>();
  for (const item of flattened) {
    const bucket = byLevel.get(item.level) ?? [];
    bucket.push(item);
    byLevel.set(item.level, bucket);
  }

  const sampled: OnboardingGenreOption[] = [];
  for (const level of Array.from(byLevel.keys()).sort((a, b) => a - b)) {
    sampled.push(...shuffleArray(byLevel.get(level) ?? []).slice(0, 8));
  }
  return uniqueOnboardingGenreOptions([...shuffleArray(sampled), ...shuffleArray(flattened)])
    .slice(0, ONBOARDING_GENRE_OPTION_LIMIT);
};

router.get('/onboarding/preferences/options', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const viewerId = authReq.user?.userId ?? null;

    const [genreRows, brandRows, djRows] = await Promise.all([
      prisma.genre.findMany({
        orderBy: [{ parentId: 'asc' }, { sortOrder: 'asc' }, { name: 'asc' }],
        select: {
          id: true,
          name: true,
          parentId: true,
          sortOrder: true,
        },
      }),
      prisma.wikiFestival.findMany({
        where: { isActive: true },
        orderBy: [{ name: 'asc' }],
        take: 120,
        select: {
          id: true,
          name: true,
          nameI18n: true,
          sourceRowId: true,
          abbreviation: true,
          aliases: true,
          country: true,
          countryI18n: true,
          city: true,
          cityI18n: true,
          foundedYear: true,
          frequency: true,
          frequencyI18n: true,
          tagline: true,
          introduction: true,
          descriptionI18n: true,
          avatarUrl: true,
          backgroundUrl: true,
          links: true,
          createdAt: true,
          updatedAt: true,
        },
      }),
      prisma.dJ.findMany({
        where: {
          soundCloudFollowers: { not: null },
        },
        orderBy: [
          { soundCloudFollowers: 'desc' },
          { name: 'asc' },
        ],
        take: ONBOARDING_DJ_CANDIDATE_LIMIT,
        select: {
          id: true,
          name: true,
          nameI18n: true,
          aliases: true,
          avatarUrl: true,
          country: true,
          countryI18n: true,
          soundCloudFollowers: true,
        },
      }),
    ]);

    const onboardingBrandRows = shuffleArray(brandRows).slice(0, ONBOARDING_BRAND_OPTION_LIMIT);
    const onboardingBrandImageAssets = await loadWikiFestivalImageAssets(onboardingBrandRows.map((row) => row.id));
    const brandOptions = attachWikiFestivalImageAssets(onboardingBrandRows, onboardingBrandImageAssets)
      .map((row) => mapWikiFestival({ ...row, contributors: [] }, viewerId, null));
    const djOptions = shuffleArray(djRows)
      .slice(0, ONBOARDING_DJ_OPTION_LIMIT)
      .map((row) => mapDJ(row, false, viewerId, null));

    ok(res, {
      genres: sampleOnboardingGenreOptions(genreRows),
      brands: brandOptions,
      djs: djOptions,
    });
  } catch (error) {
    console.error('BFF web onboarding preference options error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/learn/genres', async (_req: Request, res: Response): Promise<void> => {
  try {
    const rows = await prisma.genre.findMany({
      orderBy: [{ parentId: 'asc' }, { sortOrder: 'asc' }, { name: 'asc' }],
      select: {
        id: true,
        name: true,
        nameI18n: true,
        path: true,
        color: true,
        description: true,
        descriptionI18n: true,
        example: true,
        exampleI18n: true,
        soundCueTracks: true,
        origin: true,
        era: true,
        bpm: true,
        backgroundImageUrl: true,
        spotifyTrackUrl: true,
        wikipediaUrl: true,
        keyArtists: true,
        keyArtistBindings: true,
        parentId: true,
        sortOrder: true,
      },
    });

    const boundDjIds = Array.from(new Set(rows.flatMap((row) => {
      if (!Array.isArray(row.keyArtistBindings)) return [];
      return row.keyArtistBindings
        .map((item) => (item && typeof item === 'object' && typeof (item as any).djId === 'string' ? (item as any).djId.trim() : ''))
        .filter(Boolean);
    })));
    const boundDJs = boundDjIds.length
      ? await prisma.dJ.findMany({
          where: { id: { in: boundDjIds } },
          select: selectGenreDJLite,
        })
      : [];
    const djById = new Map(boundDJs.map((dj) => [dj.id, dj]));

    const byParentId = new Map<string | null, typeof rows>();
    for (const row of rows) {
      const siblings = byParentId.get(row.parentId) ?? [];
      siblings.push(row);
      byParentId.set(row.parentId, siblings);
    }
    const themeColorById = buildGenreBranchThemeColorLookup(rows);

    const buildNode = (row: (typeof rows)[number]): LearnGenreTreeNode => ({
      id: row.id,
      name: row.name,
      nameI18n: resolveTriTextWithFallback(row.nameI18n ?? null, row.name ?? ''),
      path: row.path,
      themeColor: themeColorById.get(row.id) ?? '',
      description: row.description ?? '',
      descriptionI18n: resolveTriTextWithFallback(row.descriptionI18n ?? null, row.description ?? ''),
      example: row.example ?? '',
      exampleI18n: resolveTriTextWithFallback(row.exampleI18n ?? null, row.example ?? ''),
      soundCueTracks: normalizeGenreSoundCueTracks(row.soundCueTracks),
      origin: row.origin ?? '',
      era: row.era ?? '',
      bpm: row.bpm ?? '',
      backgroundImageURL: row.backgroundImageUrl ?? '',
      spotifyTrackURL: row.spotifyTrackUrl ?? '',
      wikipediaURL: row.wikipediaUrl ?? '',
      keyArtists: row.keyArtists,
      keyArtistBindings: normalizeGenreKeyArtistBindings(row.keyArtists, row.keyArtistBindings, djById),
      children: (byParentId.get(row.id) ?? []).map(buildNode),
    });

    const roots = (byParentId.get(null) ?? []).map(buildNode);
    const electronicRoot = roots.find((node) => node.id === 'electronic-music');
    ok(res, electronicRoot?.children ?? roots);
  } catch (error) {
    console.error('BFF web learn genres error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/learn/genres/tree-summary', async (_req: Request, res: Response): Promise<void> => {
  try {
    const rows = await prisma.genre.findMany({
      orderBy: [{ parentId: 'asc' }, { sortOrder: 'asc' }, { name: 'asc' }],
      select: {
        id: true,
        name: true,
        nameI18n: true,
        path: true,
        parentId: true,
        color: true,
      },
    });

    const byParentId = new Map<string | null, typeof rows>();
    for (const row of rows) {
      const siblings = byParentId.get(row.parentId) ?? [];
      siblings.push(row);
      byParentId.set(row.parentId, siblings);
    }
    const themeColorById = buildGenreBranchThemeColorLookup(rows);

    const buildNode = (row: (typeof rows)[number]): LearnGenreTreeSummaryNode => ({
      id: row.id,
      name: row.name,
      path: row.path,
      themeColor: themeColorById.get(row.id) ?? '',
      children: (byParentId.get(row.id) ?? []).map(buildNode),
    });

    const roots = (byParentId.get(null) ?? []).map(buildNode);
    const electronicRoot = roots.find((node) => node.id === 'electronic-music');
    ok(res, electronicRoot?.children ?? roots);
  } catch (error) {
    console.error('BFF web learn genres tree summary error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/learn/genres/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const id = typeof req.params.id === 'string' ? req.params.id.trim() : '';
    if (!id) {
      res.status(400).json({ error: 'Genre id is required' });
      return;
    }

    const row = await prisma.genre.findUnique({
      where: { id },
      select: {
        id: true,
        name: true,
        nameI18n: true,
        path: true,
        color: true,
        parentId: true,
        description: true,
        descriptionI18n: true,
        example: true,
        exampleI18n: true,
        soundCueTracks: true,
        origin: true,
        era: true,
        bpm: true,
        backgroundImageUrl: true,
        spotifyTrackUrl: true,
        wikipediaUrl: true,
        keyArtists: true,
        keyArtistBindings: true,
      },
    });

    if (!row) {
      res.status(404).json({ error: 'Genre not found' });
      return;
    }

    const boundDjIds = Array.from(new Set(
      (Array.isArray(row.keyArtistBindings) ? row.keyArtistBindings : [])
        .map((item) => (item && typeof item === 'object' && typeof (item as any).djId === 'string' ? (item as any).djId.trim() : ''))
        .filter(Boolean)
    ));
    const boundDJs = boundDjIds.length
      ? await prisma.dJ.findMany({
          where: { id: { in: boundDjIds } },
          select: selectGenreDJLite,
        })
      : [];
    const djById = new Map(boundDJs.map((dj) => [dj.id, dj]));
    const themeRows = await prisma.genre.findMany({
      select: {
        id: true,
        parentId: true,
        color: true,
      },
    });
    const themeColorById = buildGenreBranchThemeColorLookup(themeRows);

    const detail: LearnGenreDetailNode = {
      id: row.id,
      name: row.name,
      nameI18n: resolveTriTextWithFallback(row.nameI18n ?? null, row.name ?? ''),
      path: row.path,
      themeColor: themeColorById.get(row.id) ?? '',
      description: row.description ?? '',
      descriptionI18n: resolveTriTextWithFallback(row.descriptionI18n ?? null, row.description ?? ''),
      example: row.example ?? '',
      exampleI18n: resolveTriTextWithFallback(row.exampleI18n ?? null, row.example ?? ''),
      soundCueTracks: normalizeGenreSoundCueTracks(row.soundCueTracks),
      origin: row.origin ?? '',
      era: row.era ?? '',
      bpm: row.bpm ?? '',
      backgroundImageURL: row.backgroundImageUrl ?? '',
      spotifyTrackURL: row.spotifyTrackUrl ?? '',
      wikipediaURL: row.wikipediaUrl ?? '',
      keyArtists: row.keyArtists,
      keyArtistBindings: normalizeGenreKeyArtistBindings(row.keyArtists, row.keyArtistBindings, djById),
    };

    ok(res, detail);
  } catch (error) {
    console.error('BFF web learn genre detail error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/learn/genres/admin/tree', optionalAuth, async (_req: Request, res: Response): Promise<void> => {
  try {
    const rows = await prisma.genre.findMany({
      orderBy: [{ parentId: 'asc' }, { sortOrder: 'asc' }, { name: 'asc' }],
      select: {
        id: true,
        name: true,
        nameI18n: true,
        path: true,
        color: true,
        description: true,
        descriptionI18n: true,
        example: true,
        exampleI18n: true,
        soundCueTracks: true,
        origin: true,
        era: true,
        bpm: true,
        backgroundImageUrl: true,
        spotifyTrackUrl: true,
        wikipediaUrl: true,
        keyArtists: true,
        keyArtistBindings: true,
        parentId: true,
        sortOrder: true,
      },
    });
    const boundDjIds = Array.from(new Set(rows.flatMap((row) => {
      if (!Array.isArray(row.keyArtistBindings)) return [];
      return row.keyArtistBindings
        .map((item) => (item && typeof item === 'object' && typeof (item as any).djId === 'string' ? (item as any).djId.trim() : ''))
        .filter(Boolean);
    })));
    const boundDJs = boundDjIds.length
      ? await prisma.dJ.findMany({ where: { id: { in: boundDjIds } }, select: selectGenreDJLite })
      : [];
    const djById = new Map(boundDJs.map((dj) => [dj.id, dj]));
    const themeColorById = buildGenreBranchThemeColorLookup(rows);
    ok(res, {
      items: rows.map((row) => ({
        id: row.id,
        name: row.name,
        nameI18n: resolveTriTextWithFallback(row.nameI18n ?? null, row.name ?? ''),
        path: row.path,
        color: normalizeGenreThemeColor(row.color) ?? '',
        effectiveThemeColor: themeColorById.get(row.id) ?? '',
        description: row.description ?? '',
        descriptionI18n: resolveTriTextWithFallback(row.descriptionI18n ?? null, row.description ?? ''),
        example: row.example ?? '',
        exampleI18n: resolveTriTextWithFallback(row.exampleI18n ?? null, row.example ?? ''),
        soundCueTracks: normalizeGenreSoundCueTracks(row.soundCueTracks),
        origin: row.origin ?? '',
        era: row.era ?? '',
        bpm: row.bpm ?? '',
        backgroundImageURL: row.backgroundImageUrl ?? '',
        spotifyTrackURL: row.spotifyTrackUrl ?? '',
        wikipediaURL: row.wikipediaUrl ?? '',
        keyArtists: row.keyArtists,
        keyArtistBindings: normalizeGenreKeyArtistBindings(row.keyArtists, row.keyArtistBindings, djById),
        parentId: row.parentId,
        sortOrder: row.sortOrder,
      })),
    });
  } catch (error) {
    console.error('BFF web learn genres admin tree error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/learn/genres/:id/key-artist-bindings', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const genreId = req.params.id as string;
    const body = req.body as Record<string, unknown>;
    const bindingsInput = Array.isArray(body.bindings) ? body.bindings : [];
    const keyArtistsInput = normalizeGenreKeyArtistsInput(body.keyArtists);
    const genre = await prisma.genre.findUnique({
      where: { id: genreId },
      select: { id: true, keyArtists: true },
    });
    if (!genre) {
      res.status(404).json({ error: 'Genre not found' });
      return;
    }

    const bindingNames = normalizeGenreKeyArtistsInput(bindingsInput.map((item) => {
      if (!item || typeof item !== 'object') return '';
      const record = item as Record<string, unknown>;
      return typeof record.name === 'string' ? record.name : '';
    }));
    const keyArtists = keyArtistsInput.length
      ? keyArtistsInput
      : normalizeGenreKeyArtistsInput([...genre.keyArtists, ...bindingNames]);
    const requestedDjIds = Array.from(new Set(bindingsInput.map((item) => {
      if (!item || typeof item !== 'object') return '';
      const record = item as Record<string, unknown>;
      return typeof record.djId === 'string' ? record.djId.trim() : '';
    }).filter(Boolean)));
    const knownDJs = requestedDjIds.length
      ? await prisma.dJ.findMany({ where: { id: { in: requestedDjIds } }, select: selectGenreDJLite })
      : [];
    const knownDjIds = new Set(knownDJs.map((dj) => dj.id));

    const bindings = bindingsInput.flatMap((item) => {
      if (!item || typeof item !== 'object') return [];
      const record = item as Record<string, unknown>;
      const name = typeof record.name === 'string' ? record.name.trim() : '';
      if (!name) return [];
      const djId = typeof record.djId === 'string' && knownDjIds.has(record.djId.trim())
        ? record.djId.trim()
        : null;
      return [{ name, djId }];
    });

    const bindingByName = new Map(bindings.map((item) => [item.name.toLowerCase(), item]));
    const normalized = keyArtists.map((name) => bindingByName.get(name.toLowerCase()) ?? { name, djId: null });
    const updated = await prisma.genre.update({
      where: { id: genreId },
      data: { keyArtists, keyArtistBindings: normalized },
      select: { id: true, keyArtists: true, keyArtistBindings: true },
    });
    const djById = new Map(knownDJs.map((dj) => [dj.id, dj]));
    ok(res, {
      id: updated.id,
      keyArtists: updated.keyArtists,
      keyArtistBindings: normalizeGenreKeyArtistBindings(updated.keyArtists, updated.keyArtistBindings, djById),
    });
  } catch (error) {
    console.error('BFF web update genre key artist bindings error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/learn/genres/:id/content', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const genreId = req.params.id as string;
    const body = req.body as Record<string, unknown>;
    const genre = await prisma.genre.findUnique({
      where: { id: genreId },
      select: {
        id: true,
        name: true,
        nameI18n: true,
        description: true,
        example: true,
        soundCueTracks: true,
        origin: true,
        era: true,
        bpm: true,
        color: true,
        backgroundImageUrl: true,
        spotifyTrackUrl: true,
        wikipediaUrl: true,
      },
    });
    if (!genre) {
      res.status(404).json({ error: 'Genre not found' });
      return;
    }

    const hasDescriptionField = Object.prototype.hasOwnProperty.call(body, 'description');
    const hasDescriptionI18nField = Object.prototype.hasOwnProperty.call(body, 'descriptionI18n');
    const hasNameI18nField = Object.prototype.hasOwnProperty.call(body, 'nameI18n');
    const hasExampleField = Object.prototype.hasOwnProperty.call(body, 'example');
    const hasExampleI18nField = Object.prototype.hasOwnProperty.call(body, 'exampleI18n');
    const hasSoundCueTracksField = Object.prototype.hasOwnProperty.call(body, 'soundCueTracks');
    const hasOriginField = Object.prototype.hasOwnProperty.call(body, 'origin');
    const hasEraField = Object.prototype.hasOwnProperty.call(body, 'era');
    const hasBpmField = Object.prototype.hasOwnProperty.call(body, 'bpm');
    const hasColorField = Object.prototype.hasOwnProperty.call(body, 'color');
    const hasBackgroundImageField = Object.prototype.hasOwnProperty.call(body, 'backgroundImageURL');
    const hasSpotifyTrackField = Object.prototype.hasOwnProperty.call(body, 'spotifyTrackURL');
    const hasWikipediaField = Object.prototype.hasOwnProperty.call(body, 'wikipediaURL');

    const nextDescription = hasDescriptionField
      ? normalizeGenreEditableText(body.description)
      : (genre.description ?? null);
    const nextExample = hasExampleField
      ? normalizeGenreEditableText(body.example)
      : (genre.example ?? null);
    const nextSoundCueTracks = hasSoundCueTracksField
      ? normalizeGenreSoundCueTracks(body.soundCueTracks)
      : normalizeGenreSoundCueTracks(genre.soundCueTracks);
    const nextSpotifyTrackUrl = hasSpotifyTrackField
      ? normalizeGenreEditableText(body.spotifyTrackURL)
      : (genre.spotifyTrackUrl ?? null);
    const nextWikipediaUrl = hasWikipediaField
      ? normalizeGenreEditableText(body.wikipediaURL)
      : (genre.wikipediaUrl ?? null);
    const nextOrigin = hasOriginField
      ? normalizeGenreEditableText(body.origin)
      : (genre.origin ?? null);
    const nextEra = hasEraField
      ? normalizeGenreEditableText(body.era)
      : (genre.era ?? null);
    const nextBpm = hasBpmField
      ? normalizeGenreEditableText(body.bpm)
      : (genre.bpm ?? null);
    const nextColor = hasColorField
      ? normalizeGenreThemeColor(body.color)
      : (normalizeGenreThemeColor(genre.color) ?? null);
    const nextBackgroundImageUrl = hasBackgroundImageField
      ? normalizeGenreEditableText(body.backgroundImageURL)
      : (genre.backgroundImageUrl ?? null);

    const descriptionI18n = hasDescriptionField || hasDescriptionI18nField
      ? normalizeTriTextPayload(body.descriptionI18n, nextDescription ?? '')
      : undefined;
    const exampleI18n = hasExampleField || hasExampleI18nField
      ? normalizeTriTextPayload(body.exampleI18n, nextExample ?? '')
      : undefined;

    const updateData: Prisma.GenreUpdateInput = {};
    if (hasNameI18nField) {
      const nameI18n = normalizeTriTextPayload(body.nameI18n, genre.name ?? '');
      updateData.nameI18n = nameI18n
        ? (nameI18n as unknown as Prisma.InputJsonValue)
        : Prisma.DbNull;
    }
    if (hasDescriptionField || hasDescriptionI18nField) {
      updateData.description = nextDescription;
      updateData.descriptionI18n = descriptionI18n
        ? (descriptionI18n as unknown as Prisma.InputJsonValue)
        : Prisma.DbNull;
    }
    if (hasExampleField || hasExampleI18nField) {
      updateData.example = nextExample;
      updateData.exampleI18n = exampleI18n
        ? (exampleI18n as unknown as Prisma.InputJsonValue)
        : Prisma.DbNull;
    }
    if (hasSoundCueTracksField) {
      updateData.soundCueTracks = nextSoundCueTracks.length
        ? (nextSoundCueTracks as unknown as Prisma.InputJsonValue)
        : Prisma.DbNull;
    }
    if (hasSpotifyTrackField) {
      updateData.spotifyTrackUrl = nextSpotifyTrackUrl;
    }
    if (hasWikipediaField) {
      updateData.wikipediaUrl = nextWikipediaUrl;
    }
    if (hasOriginField) {
      updateData.origin = nextOrigin;
    }
    if (hasEraField) {
      updateData.era = nextEra;
    }
    if (hasBpmField) {
      updateData.bpm = nextBpm;
    }
    if (hasColorField) {
      updateData.color = nextColor;
    }
    if (hasBackgroundImageField) {
      updateData.backgroundImageUrl = nextBackgroundImageUrl;
    }

    const updated = await prisma.genre.update({
      where: { id: genreId },
      data: updateData,
      select: {
        id: true,
        name: true,
        nameI18n: true,
        description: true,
        descriptionI18n: true,
        example: true,
        exampleI18n: true,
        soundCueTracks: true,
        origin: true,
        era: true,
        bpm: true,
        color: true,
        backgroundImageUrl: true,
        spotifyTrackUrl: true,
        wikipediaUrl: true,
      },
    });

    ok(res, {
      id: updated.id,
      name: updated.name,
      nameI18n: resolveTriTextWithFallback(updated.nameI18n ?? null, updated.name ?? ''),
      description: updated.description ?? '',
      descriptionI18n: resolveTriTextWithFallback(updated.descriptionI18n ?? null, updated.description ?? ''),
      example: updated.example ?? '',
      exampleI18n: resolveTriTextWithFallback(updated.exampleI18n ?? null, updated.example ?? ''),
      soundCueTracks: normalizeGenreSoundCueTracks(updated.soundCueTracks),
      origin: updated.origin ?? '',
      era: updated.era ?? '',
      bpm: updated.bpm ?? '',
      color: normalizeGenreThemeColor(updated.color) ?? '',
      backgroundImageURL: updated.backgroundImageUrl ?? '',
      spotifyTrackURL: updated.spotifyTrackUrl ?? '',
      wikipediaURL: updated.wikipediaUrl ?? '',
    });
  } catch (error) {
    console.error('BFF web update genre content error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/learn/genres/key-artists/auto-match', optionalAuth, async (_req: Request, res: Response): Promise<void> => {
  try {
    const [genres, djs] = await Promise.all([
      prisma.genre.findMany({ select: { id: true, keyArtists: true, keyArtistBindings: true } }),
      prisma.dJ.findMany({ select: selectGenreDJLite }),
    ]);
    const byName = new Map<string, (typeof djs)[number]>();
    const addKey = (value: string | null | undefined, dj: (typeof djs)[number]) => {
      const key = typeof value === 'string' ? value.trim().toLowerCase() : '';
      if (key && !byName.has(key)) byName.set(key, dj);
    };
    for (const dj of djs) {
      addKey(dj.name, dj);
      for (const alias of Array.isArray(dj.aliases) ? dj.aliases : []) addKey(alias, dj);
    }

    let matched = 0;
    let totalArtists = 0;
    let updatedGenres = 0;

    await prisma.$transaction(async (tx) => {
      for (const genre of genres) {
        const keyArtists = genre.keyArtists.map((item) => item.trim()).filter(Boolean);
        if (!keyArtists.length) continue;
        totalArtists += keyArtists.length;
        const existing = normalizeGenreKeyArtistBindings(keyArtists, genre.keyArtistBindings);
        const existingByName = new Map(existing.map((item) => [item.name.toLowerCase(), item.djId]));
        const next = keyArtists.map((name) => {
          const current = existingByName.get(name.toLowerCase()) ?? null;
          if (current) return { name, djId: current };
          const dj = byName.get(name.toLowerCase()) ?? null;
          if (dj) matched += 1;
          return { name, djId: dj?.id ?? null };
        });
        const changed = JSON.stringify(next) !== JSON.stringify(existing.map((item) => ({ name: item.name, djId: item.djId })));
        if (changed) {
          updatedGenres += 1;
          await tx.genre.update({
            where: { id: genre.id },
            data: { keyArtistBindings: next },
          });
        }
      }
    });

    ok(res, { matched, totalArtists, updatedGenres });
  } catch (error) {
    console.error('BFF web auto match genre key artists error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/learn/genres/admin/nodes', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    if (!canBypassContentReview(authReq.user?.role ?? null)) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const body = (req.body ?? {}) as Record<string, unknown>;
    const name = typeof body.name === 'string' ? body.name.trim() : '';
    if (!name) {
      res.status(400).json({ error: 'name is required' });
      return;
    }
    const parentId = typeof body.parentId === 'string' && body.parentId.trim() ? body.parentId.trim() : null;
    const parent = parentId
      ? await prisma.genre.findUnique({
          where: { id: parentId },
          select: { id: true, path: true },
        })
      : null;
    if (parentId && !parent) {
      res.status(404).json({ error: 'Parent genre not found' });
      return;
    }

    const slug = await uniqueGenreSlug(name, typeof body.slug === 'string' ? body.slug.trim() : undefined);
    const path = buildGenrePath(parent?.path ?? null, slug);
    const siblingCount = await prisma.genre.count({ where: { parentId } });
    const sortOrder = parseGenreSortOrder(body.sortOrder) ?? siblingCount;

    const created = await prisma.genre.create({
      data: {
        name,
        slug,
        path,
        parentId,
        sortOrder,
      },
      select: {
        id: true,
        name: true,
        nameI18n: true,
        slug: true,
        path: true,
        description: true,
        descriptionI18n: true,
        example: true,
        exampleI18n: true,
        soundCueTracks: true,
        origin: true,
        era: true,
        bpm: true,
        color: true,
        backgroundImageUrl: true,
        spotifyTrackUrl: true,
        wikipediaUrl: true,
        keyArtists: true,
        keyArtistBindings: true,
        parentId: true,
        sortOrder: true,
      },
    });

    ok(res, {
      id: created.id,
      name: created.name,
      nameI18n: resolveTriTextWithFallback(created.nameI18n ?? null, created.name ?? ''),
      slug: created.slug,
      path: created.path,
      description: created.description ?? '',
      descriptionI18n: resolveTriTextWithFallback(created.descriptionI18n ?? null, created.description ?? ''),
      example: created.example ?? '',
      exampleI18n: resolveTriTextWithFallback(created.exampleI18n ?? null, created.example ?? ''),
      soundCueTracks: normalizeGenreSoundCueTracks(created.soundCueTracks),
      origin: created.origin ?? '',
      era: created.era ?? '',
      bpm: created.bpm ?? '',
      color: normalizeGenreThemeColor(created.color) ?? '',
      effectiveThemeColor: normalizeGenreThemeColor(created.color) ?? '',
      backgroundImageURL: created.backgroundImageUrl ?? '',
      spotifyTrackURL: created.spotifyTrackUrl ?? '',
      wikipediaURL: created.wikipediaUrl ?? '',
      keyArtists: created.keyArtists,
      keyArtistBindings: normalizeGenreKeyArtistBindings(created.keyArtists, created.keyArtistBindings),
      parentId: created.parentId,
      sortOrder: created.sortOrder,
    });
  } catch (error) {
    console.error('BFF web create genre node error:', error);
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

router.patch('/learn/genres/admin/nodes/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    if (!canBypassContentReview(authReq.user?.role ?? null)) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const genreId = req.params.id as string;
    const existing = await prisma.genre.findUnique({
      where: { id: genreId },
      select: {
        id: true,
        name: true,
        nameI18n: true,
        slug: true,
        path: true,
        parentId: true,
        sortOrder: true,
        description: true,
        descriptionI18n: true,
        example: true,
        exampleI18n: true,
        soundCueTracks: true,
        origin: true,
        era: true,
        bpm: true,
        color: true,
        backgroundImageUrl: true,
        spotifyTrackUrl: true,
        wikipediaUrl: true,
        keyArtists: true,
        keyArtistBindings: true,
      },
    });
    if (!existing) {
      res.status(404).json({ error: 'Genre not found' });
      return;
    }

    const body = (req.body ?? {}) as Record<string, unknown>;
    const nextName = typeof body.name === 'string' && body.name.trim() ? body.name.trim() : existing.name;
    const hasParentField = Object.prototype.hasOwnProperty.call(body, 'parentId');
    const nextParentId = hasParentField
      ? (typeof body.parentId === 'string' && body.parentId.trim() ? body.parentId.trim() : null)
      : existing.parentId;
    if (nextParentId === existing.id) {
      res.status(400).json({ error: 'parentId cannot point to self' });
      return;
    }

    const parent = nextParentId
      ? await prisma.genre.findUnique({
          where: { id: nextParentId },
          select: { id: true, path: true },
        })
      : null;
    if (nextParentId && !parent) {
      res.status(404).json({ error: 'Parent genre not found' });
      return;
    }
    if (parent && (parent.path === existing.path || parent.path.startsWith(`${existing.path}/`))) {
      res.status(400).json({ error: '不能把父节点移动到自己的子树下' });
      return;
    }

    const nextSlug = Object.prototype.hasOwnProperty.call(body, 'slug') || nextName !== existing.name
      ? await uniqueGenreSlug(nextName, typeof body.slug === 'string' ? body.slug.trim() : undefined, existing.id)
      : existing.slug;
    const nextSortOrder = Object.prototype.hasOwnProperty.call(body, 'sortOrder')
      ? (parseGenreSortOrder(body.sortOrder) ?? existing.sortOrder)
      : existing.sortOrder;
    const nextPath = buildGenrePath(parent?.path ?? null, nextSlug);

    const updated = await prisma.$transaction(async (tx) => {
      const row = await tx.genre.update({
        where: { id: existing.id },
        data: {
          name: nextName,
          slug: nextSlug,
          parentId: nextParentId,
          sortOrder: nextSortOrder,
          path: nextPath,
        },
        select: {
          id: true,
          name: true,
          nameI18n: true,
          slug: true,
          path: true,
          description: true,
          descriptionI18n: true,
          example: true,
          exampleI18n: true,
        soundCueTracks: true,
        origin: true,
        era: true,
        bpm: true,
        color: true,
        backgroundImageUrl: true,
        spotifyTrackUrl: true,
        wikipediaUrl: true,
          keyArtists: true,
          keyArtistBindings: true,
          parentId: true,
          sortOrder: true,
        },
      });
      if (row.path !== existing.path) {
        await updateGenreSubtreePaths(tx, row.id, row.path);
      }
      return row;
    });

    ok(res, {
      id: updated.id,
      name: updated.name,
      nameI18n: resolveTriTextWithFallback(updated.nameI18n ?? null, updated.name ?? ''),
      slug: updated.slug,
      path: updated.path,
      description: updated.description ?? '',
      descriptionI18n: resolveTriTextWithFallback(updated.descriptionI18n ?? null, updated.description ?? ''),
      example: updated.example ?? '',
      exampleI18n: resolveTriTextWithFallback(updated.exampleI18n ?? null, updated.example ?? ''),
      soundCueTracks: normalizeGenreSoundCueTracks(updated.soundCueTracks),
      origin: updated.origin ?? '',
      era: updated.era ?? '',
      bpm: updated.bpm ?? '',
      color: normalizeGenreThemeColor(updated.color) ?? '',
      effectiveThemeColor: normalizeGenreThemeColor(updated.color) ?? '',
      backgroundImageURL: updated.backgroundImageUrl ?? '',
      spotifyTrackURL: updated.spotifyTrackUrl ?? '',
      wikipediaURL: updated.wikipediaUrl ?? '',
      keyArtists: updated.keyArtists,
      keyArtistBindings: normalizeGenreKeyArtistBindings(updated.keyArtists, updated.keyArtistBindings),
      parentId: updated.parentId,
      sortOrder: updated.sortOrder,
    });
  } catch (error) {
    console.error('BFF web update genre node error:', error);
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

router.delete('/learn/genres/admin/nodes/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    if (!canBypassContentReview(authReq.user?.role ?? null)) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const genreId = req.params.id as string;
    const existing = await prisma.genre.findUnique({
      where: { id: genreId },
      select: { id: true },
    });
    if (!existing) {
      res.status(404).json({ error: 'Genre not found' });
      return;
    }

    await ensureGenreDeleteSafe(genreId);
    await prisma.genre.delete({ where: { id: genreId } });
    ok(res, { success: true });
  } catch (error) {
    console.error('BFF web delete genre node error:', error);
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

router.get('/learn/festivals', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const viewerId = authReq.user?.userId ?? null;
    const viewerRole = authReq.user?.role ?? null;
    const page = normalizePage(req.query.page, 1);
    const limit = normalizeLimit(req.query.limit, 20, 100);
    const skip = (page - 1) * limit;
    const search = typeof req.query.search === 'string' ? req.query.search.trim().toLowerCase() : '';
    const country = typeof req.query.country === 'string' ? req.query.country.trim() : '';
    const sortByRaw = typeof req.query.sortBy === 'string' ? req.query.sortBy.trim() : 'updatedAtDesc';
    const sortBy =
      sortByRaw === 'nameAsc'
      || sortByRaw === 'nameDesc'
      || sortByRaw === 'createdAtAsc'
      || sortByRaw === 'createdAtDesc'
      || sortByRaw === 'updatedAtAsc'
      || sortByRaw === 'updatedAtDesc'
        ? sortByRaw
        : 'updatedAtDesc';
    const where: Prisma.WikiFestivalWhereInput = {
      isActive: true,
      ...(country
        ? {
            country: {
              equals: country,
              mode: 'insensitive',
            },
          }
        : {}),
      ...(search
        ? {
            OR: [
              { name: { contains: search, mode: 'insensitive' } },
              { abbreviation: { contains: search, mode: 'insensitive' } },
              { aliases: { has: search } },
              { country: { contains: search, mode: 'insensitive' } },
              { city: { contains: search, mode: 'insensitive' } },
              { frequency: { contains: search, mode: 'insensitive' } },
              { tagline: { contains: search, mode: 'insensitive' } },
              { introduction: { contains: search, mode: 'insensitive' } },
              { officialWebsite: { contains: search, mode: 'insensitive' } },
              { facebookUrl: { contains: search, mode: 'insensitive' } },
              { instagramUrl: { contains: search, mode: 'insensitive' } },
              { twitterUrl: { contains: search, mode: 'insensitive' } },
              { youtubeUrl: { contains: search, mode: 'insensitive' } },
              { tiktokUrl: { contains: search, mode: 'insensitive' } },
            ],
          }
        : {}),
    };

    const orderBy: Prisma.WikiFestivalOrderByWithRelationInput[] =
      sortBy === 'nameAsc'
        ? [{ name: 'asc' }, { id: 'asc' }]
        : sortBy === 'nameDesc'
          ? [{ name: 'desc' }, { id: 'desc' }]
          : sortBy === 'createdAtAsc'
            ? [{ createdAt: 'asc' }, { id: 'asc' }]
            : sortBy === 'createdAtDesc'
              ? [{ createdAt: 'desc' }, { id: 'desc' }]
              : sortBy === 'updatedAtAsc'
                ? [{ updatedAt: 'asc' }, { id: 'asc' }]
                : [{ updatedAt: 'desc' }, { id: 'desc' }];

    const [rows, total, followedBrandPreference] = await Promise.all([
      prisma.wikiFestival.findMany({
        where,
        skip,
        take: limit,
        orderBy,
        select: learnFestivalListSelect,
      }),
      prisma.wikiFestival.count({ where }),
      viewerId
        ? notificationCenterService.fetchFollowedBrandUpdatePreference(viewerId)
        : Promise.resolve(null),
    ]);
    const followedBrandIDs = new Set(followedBrandPreference?.watchedBrandIds ?? []);
    const festivalImageAssets = await loadWikiFestivalImageAssets(rows.map((row) => row.id));
    const rowsWithImageAssets = attachWikiFestivalImageAssets(rows, festivalImageAssets);

    ok(
      res,
      {
        items: rowsWithImageAssets.map((row: Prisma.WikiFestivalGetPayload<{ select: typeof learnFestivalListSelect }> & { brandImageAssets: ReturnType<typeof mapWikiBrandMediaAsset>[] | null }) =>
          mapWikiFestival(
            {
              ...row,
              contributors: [],
              followedByUserIds: followedBrandIDs.has(row.id) && viewerId ? [viewerId] : [],
            },
            viewerId,
            viewerRole
          )
        ),
      },
      {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit) || 1,
      }
    );
  } catch (error) {
    console.error('BFF web learn festivals error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/learn/festivals', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const body = (req.body ?? {}) as Record<string, unknown>;
    const sourceRowIdRaw = normalizeWikiFestivalInteger(body.sourceRowId);
    if (Object.prototype.hasOwnProperty.call(body, 'sourceRowId') && body.sourceRowId !== null && body.sourceRowId !== '' && sourceRowIdRaw === null) {
      res.status(400).json({ error: 'sourceRowId must be an integer' });
      return;
    }

    const rawName = normalizeWikiFestivalText(body.name);
    const nameI18n = normalizeWikiFestivalBiText(body.nameI18n, rawName);
    const name = rawName || pickWikiFestivalPrimaryText(nameI18n);
    if (!name) {
      res.status(400).json({ error: 'name is required' });
      return;
    }
    const brandValidationError = validateBrandSubmissionPayload(
      normalizeBrandSubmissionPayload(body as Prisma.InputJsonObject)
    );
    if (brandValidationError) {
      res.status(400).json({ error: brandValidationError });
      return;
    }

    const submission = await createPendingContentSubmission({
      submitterId: userId,
      entityType: 'brand',
      title: name,
      payload: body,
    });
    acceptedSubmission(res, submission, '品牌任务已提交，当前正在处理中，后续状态会通过通知更新');
  } catch (error) {
    console.error('BFF web create learn festival error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/learn/festivals/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const viewerId = authReq.user?.userId ?? null;
    const viewerRole = authReq.user?.role ?? null;
    const festivalId = req.params.id as string;

    const [row, followedBrandPreference] = await Promise.all([
      prisma.wikiFestival.findUnique({
        where: { id: festivalId },
        include: {
          contributors: {
            include: {
              user: {
                select: { id: true, username: true, displayName: true, avatarUrl: true },
              },
            },
          },
        },
      }),
      viewerId
        ? notificationCenterService.fetchFollowedBrandUpdatePreference(viewerId)
        : Promise.resolve(null),
    ]);

    if (!row || !row.isActive) {
      res.status(404).json({ error: 'Festival not found' });
      return;
    }

    const isFollowing = Boolean(viewerId && followedBrandPreference?.watchedBrandIds.includes(row.id));
    const detailImageAssets = await loadWikiFestivalImageAssets([row.id]);
    ok(
      res,
      mapWikiFestival(
        {
          ...row,
          brandImageAssets: detailImageAssets.get(row.id) ?? null,
          followedByUserIds: isFollowing && viewerId ? [viewerId] : [],
        },
        viewerId,
        viewerRole
      )
    );
  } catch (error) {
    console.error('BFF web learn festival detail error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.patch('/learn/festivals/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    const viewerRole = authReq.user?.role ?? null;

    const festivalId = req.params.id as string;
    const existing = await prisma.wikiFestival.findUnique({
      where: { id: festivalId },
      include: {
        contributors: {
          select: { userId: true },
        },
      },
    });

    if (!existing) {
      res.status(404).json({ error: 'Festival not found' });
      return;
    }

    const isContributor = existing.contributors.some((item) => item.userId === userId);
    const canEdit = viewerRole === 'admin' || isContributor;
    if (!canEdit) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const body = (req.body ?? {}) as Record<string, unknown>;
    const brandValidationError = validateBrandSubmissionPayload(
      normalizeBrandSubmissionPayload(
        brandPayloadForValidation(body, existing) as Prisma.InputJsonObject
      )
    );
    if (brandValidationError) {
      res.status(400).json({ error: brandValidationError });
      return;
    }
    const updateData: Prisma.WikiFestivalUpdateInput = {};
    const hasNameField = Object.prototype.hasOwnProperty.call(body, 'name');
    const hasNameI18nField = Object.prototype.hasOwnProperty.call(body, 'nameI18n');
    const hasSourceRowIdField = Object.prototype.hasOwnProperty.call(body, 'sourceRowId');
    const hasAbbreviationField = Object.prototype.hasOwnProperty.call(body, 'abbreviation');
    const hasCountryField = Object.prototype.hasOwnProperty.call(body, 'country');
    const hasCountryI18nField = Object.prototype.hasOwnProperty.call(body, 'countryI18n');
    const hasCityField = Object.prototype.hasOwnProperty.call(body, 'city');
    const hasCityI18nField = Object.prototype.hasOwnProperty.call(body, 'cityI18n');
    const hasFrequencyField = Object.prototype.hasOwnProperty.call(body, 'frequency');
    const hasFrequencyI18nField = Object.prototype.hasOwnProperty.call(body, 'frequencyI18n');
    const hasIntroductionField = Object.prototype.hasOwnProperty.call(body, 'introduction');
    const hasDescriptionI18nField = Object.prototype.hasOwnProperty.call(body, 'descriptionI18n');
    const hasOfficialWebsiteField = Object.prototype.hasOwnProperty.call(body, 'officialWebsite');
    const hasFacebookUrlField = Object.prototype.hasOwnProperty.call(body, 'facebookUrl');
    const hasInstagramUrlField = Object.prototype.hasOwnProperty.call(body, 'instagramUrl');
    const hasTwitterUrlField = Object.prototype.hasOwnProperty.call(body, 'twitterUrl');
    const hasYoutubeUrlField = Object.prototype.hasOwnProperty.call(body, 'youtubeUrl');
    const hasTiktokUrlField = Object.prototype.hasOwnProperty.call(body, 'tiktokUrl');
    const hasLinksField = Object.prototype.hasOwnProperty.call(body, 'links');

    if (hasSourceRowIdField) {
      if (body.sourceRowId === null || body.sourceRowId === '') {
        updateData.sourceRowId = null;
      } else {
        const sourceRowId = normalizeWikiFestivalInteger(body.sourceRowId);
        if (sourceRowId === null) {
          res.status(400).json({ error: 'sourceRowId must be an integer' });
          return;
        }
        updateData.sourceRowId = sourceRowId;
      }
    }

    let nextName = hasNameField ? normalizeWikiFestivalText(body.name) : existing.name;
    if (hasNameI18nField) {
      const normalized = normalizeWikiFestivalBiText(body.nameI18n, nextName);
      updateData.nameI18n = normalized ? (normalized as unknown as Prisma.InputJsonValue) : Prisma.DbNull;
      if (!hasNameField && normalized) {
        nextName = pickWikiFestivalPrimaryText(normalized, existing.name);
      }
    }
    if (hasNameField || hasNameI18nField) {
      const finalName = nextName || existing.name;
      if (!finalName) {
        res.status(400).json({ error: 'name is required' });
        return;
      }
      updateData.name = finalName;
    }

    if (hasAbbreviationField) {
      updateData.abbreviation = normalizeWikiFestivalText(body.abbreviation);
    }

    if (Object.prototype.hasOwnProperty.call(body, 'aliases')) {
      updateData.aliases = parseWikiFestivalAliases(body.aliases);
    }

    if (hasCountryField || hasCountryI18nField) {
      let nextCountry = hasCountryField ? normalizeWikiFestivalText(body.country) : existing.country;
      if (hasCountryI18nField) {
        const normalized = normalizeCountryBiText(body.countryI18n, nextCountry);
        updateData.countryI18n = normalized ? (normalized as unknown as Prisma.InputJsonValue) : Prisma.DbNull;
        if (!hasCountryField && normalized) {
          nextCountry = pickWikiFestivalPrimaryText(normalized, existing.country);
        }
      }
      updateData.country = nextCountry || '';
    }

    if (hasCityField || hasCityI18nField) {
      let nextCity = hasCityField ? normalizeWikiFestivalText(body.city) : existing.city;
      if (hasCityI18nField) {
        const normalized = normalizeWikiFestivalBiText(body.cityI18n, nextCity);
        updateData.cityI18n = normalized ? (normalized as unknown as Prisma.InputJsonValue) : Prisma.DbNull;
        if (!hasCityField && normalized) {
          nextCity = pickWikiFestivalPrimaryText(normalized, existing.city);
        }
      }
      updateData.city = nextCity || '';
    }

    if (Object.prototype.hasOwnProperty.call(body, 'foundedYear')) {
      updateData.foundedYear = normalizeWikiFestivalText(body.foundedYear);
    }

    if (hasFrequencyField || hasFrequencyI18nField) {
      let nextFrequency = hasFrequencyField ? normalizeWikiFestivalText(body.frequency) : existing.frequency;
      if (hasFrequencyI18nField) {
        const normalized = normalizeWikiFestivalBiText(body.frequencyI18n, nextFrequency);
        updateData.frequencyI18n = normalized ? (normalized as unknown as Prisma.InputJsonValue) : Prisma.DbNull;
        if (!hasFrequencyField && normalized) {
          nextFrequency = pickWikiFestivalPrimaryText(normalized, existing.frequency);
        }
      }
      updateData.frequency = nextFrequency || '';
    }

    if (Object.prototype.hasOwnProperty.call(body, 'tagline')) {
      updateData.tagline = normalizeWikiFestivalText(body.tagline);
    }

    if (hasIntroductionField || hasDescriptionI18nField) {
      let nextIntroduction = hasIntroductionField ? normalizeWikiFestivalText(body.introduction) : existing.introduction;
      if (hasDescriptionI18nField) {
        const normalized = normalizeWikiFestivalBiText(body.descriptionI18n, nextIntroduction);
        updateData.descriptionI18n = normalized ? (normalized as unknown as Prisma.InputJsonValue) : Prisma.DbNull;
        if (!hasIntroductionField && normalized) {
          nextIntroduction = pickWikiFestivalPrimaryText(normalized, existing.introduction);
        }
      }
      updateData.introduction = nextIntroduction || '';
    }

    if (Object.prototype.hasOwnProperty.call(body, 'avatarUrl')) {
      if (body.avatarUrl === null) {
        updateData.avatarUrl = null;
      } else {
        const avatarUrl = normalizeWikiFestivalText(body.avatarUrl);
        updateData.avatarUrl = avatarUrl.length > 0 ? avatarUrl : null;
      }
    }

    if (Object.prototype.hasOwnProperty.call(body, 'backgroundUrl')) {
      if (body.backgroundUrl === null) {
        updateData.backgroundUrl = null;
      } else {
        const backgroundUrl = normalizeWikiFestivalText(body.backgroundUrl);
        updateData.backgroundUrl = backgroundUrl.length > 0 ? backgroundUrl : null;
      }
    }

    const nextOfficialWebsite = hasOfficialWebsiteField
      ? normalizeWikiFestivalText(body.officialWebsite)
      : (existing.officialWebsite ?? '');
    const nextFacebookUrl = hasFacebookUrlField
      ? normalizeWikiFestivalText(body.facebookUrl)
      : (existing.facebookUrl ?? '');
    const nextInstagramUrl = hasInstagramUrlField
      ? normalizeWikiFestivalText(body.instagramUrl)
      : (existing.instagramUrl ?? '');
    const nextTwitterUrl = hasTwitterUrlField
      ? normalizeWikiFestivalText(body.twitterUrl)
      : (existing.twitterUrl ?? '');
    const nextYoutubeUrl = hasYoutubeUrlField
      ? normalizeWikiFestivalText(body.youtubeUrl)
      : (existing.youtubeUrl ?? '');
    const nextTiktokUrl = hasTiktokUrlField
      ? normalizeWikiFestivalText(body.tiktokUrl)
      : (existing.tiktokUrl ?? '');

    if (hasOfficialWebsiteField) {
      updateData.officialWebsite = nextOfficialWebsite.length > 0 ? nextOfficialWebsite : null;
    }
    if (hasFacebookUrlField) {
      updateData.facebookUrl = nextFacebookUrl.length > 0 ? nextFacebookUrl : null;
    }
    if (hasInstagramUrlField) {
      updateData.instagramUrl = nextInstagramUrl.length > 0 ? nextInstagramUrl : null;
    }
    if (hasTwitterUrlField) {
      updateData.twitterUrl = nextTwitterUrl.length > 0 ? nextTwitterUrl : null;
    }
    if (hasYoutubeUrlField) {
      updateData.youtubeUrl = nextYoutubeUrl.length > 0 ? nextYoutubeUrl : null;
    }
    if (hasTiktokUrlField) {
      updateData.tiktokUrl = nextTiktokUrl.length > 0 ? nextTiktokUrl : null;
    }

    if (
      hasLinksField ||
      hasOfficialWebsiteField ||
      hasFacebookUrlField ||
      hasInstagramUrlField ||
      hasTwitterUrlField ||
      hasYoutubeUrlField ||
      hasTiktokUrlField
    ) {
      const baseLinks = hasLinksField ? parseWikiFestivalLinks(body.links) : parseWikiFestivalLinks(existing.links);
      const mergedLinks = mergeWikiFestivalLinks(baseLinks, {
        officialWebsite: nextOfficialWebsite,
        facebookUrl: nextFacebookUrl,
        instagramUrl: nextInstagramUrl,
        twitterUrl: nextTwitterUrl,
        youtubeUrl: nextYoutubeUrl,
        tiktokUrl: nextTiktokUrl,
      });
      updateData.links = mergedLinks as unknown as Prisma.InputJsonValue;
    }

    const hasUpdateFields = Object.keys(updateData).length > 0;

    if (!hasUpdateFields) {
      const existingImageAssets = await loadWikiFestivalImageAssets([existing.id]);
      ok(res, mapWikiFestival({
        ...existing,
        brandImageAssets: existingImageAssets.get(existing.id) ?? null,
      }, userId, viewerRole));
      return;
    }

    const submission = await createPendingContentSubmission({
      submitterId: userId,
      entityType: 'brand',
      title: nextName || existing.name,
      payload: {
        ...body,
        name: nextName || existing.name,
        baseBrandRevision: body.baseBrandRevision,
        targetBrandId: festivalId,
        editMode: 'patch',
      },
    });
    acceptedSubmission(res, submission, '主办方编辑任务已提交，当前正在处理中，后续状态会通过通知更新');
  } catch (error) {
    if (error instanceof BrandSubmissionConflictError) {
      res.status(409).json({
        error: error.message,
        code: error.code,
        details: error.details,
      });
      return;
    }
    console.error('BFF web update learn festival error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.delete('/learn/festivals/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    const viewerRole = authReq.user?.role ?? null;

    const festivalId = req.params.id as string;
    const existing = await prisma.wikiFestival.findUnique({
      where: { id: festivalId },
      include: {
        contributors: {
          select: { userId: true },
        },
      },
    });

    if (!existing) {
      res.status(404).json({ error: 'Festival not found' });
      return;
    }

    const isContributor = existing.contributors.some((item) => item.userId === userId);
    const canDelete = viewerRole === 'admin' || isContributor;
    if (!canDelete) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const urlsToDelete = [
      existing.avatarUrl,
      existing.backgroundUrl,
    ].filter((value): value is string => typeof value === 'string' && value.trim().length > 0);

    await prisma.wikiFestival.delete({ where: { id: festivalId } });
    await notificationCenterService.deleteAdminPublishTasksByEntity({
      entityType: 'festival',
      entityId: festivalId,
      taskTypes: ['brand_release'],
    });
    await notificationCenterService.deleteAdminContentHistoryByEntity({
      entityType: 'festival',
      entityId: festivalId,
    });
    for (const url of urlsToDelete) {
      await mediaAssetService.markDeletedByUrl(url);
      await deleteSingleWikiBrandOssObjectIfOwned(url, festivalId);
    }
    await deleteWikiBrandOssFolder(festivalId);

    ok(res, { success: true });
  } catch (error) {
    console.error('BFF web delete learn festival error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

type LearnLabelSortBy = 'soundcloudFollowers' | 'likes' | 'name' | 'nation' | 'latestRelease' | 'createdAt';

const learnLabelListSelect = {
  id: true,
  name: true,
  slug: true,
  profileUrl: true,
  profileSlug: true,
  logoUrl: true,
  avatarUrl: true,
  backgroundUrl: true,
  nation: true,
  soundcloudFollowers: true,
  likes: true,
  genres: true,
  genresPreview: true,
  latestReleaseListing: true,
  locationPeriod: true,
  introductionPreview: true,
  introduction: true,
  generalContactEmail: true,
  demoSubmissionUrl: true,
  demoSubmissionDisplay: true,
  facebookUrl: true,
  soundcloudUrl: true,
  musicPurchaseUrl: true,
  officialWebsiteUrl: true,
  foundedAt: true,
  founders: true,
  createdAt: true,
} satisfies Prisma.LabelSelect;

const parseLearnLabelSortBy = (value: unknown): LearnLabelSortBy => {
  if (value === 'likes') return 'likes';
  if (value === 'name') return 'name';
  if (value === 'nation') return 'nation';
  if (value === 'latestRelease') return 'latestRelease';
  if (value === 'createdAt') return 'createdAt';
  return 'soundcloudFollowers';
};

const parseMultiFilterValues = (value: unknown): string[] => {
  const normalized = Array.isArray(value) ? value : [value];
  return normalized
    .flatMap((item) => (typeof item === 'string' ? item.split(',') : []))
    .map((item) => item.trim())
    .filter((item) => item.length > 0);
};

router.get('/learn/labels', async (req: Request, res: Response): Promise<void> => {
  try {
    const page = normalizePage(req.query.page);
    const limit = normalizeLimit(req.query.limit, 20, 500);
    const sortBy = parseLearnLabelSortBy(req.query.sortBy);

    const defaultOrder: Prisma.SortOrder = sortBy === 'name' || sortBy === 'nation' ? 'asc' : 'desc';
    const order = parseSortOrder(req.query.order, defaultOrder);

    const search = typeof req.query.search === 'string' ? req.query.search.trim() : '';
    const nationFilters = Array.from(
      new Set([
        ...parseMultiFilterValues(req.query.nation),
        ...parseMultiFilterValues(req.query.nations),
      ])
    );
    const genreFilters = Array.from(
      new Set([
        ...parseMultiFilterValues(req.query.genre),
        ...parseMultiFilterValues(req.query.genres),
      ])
    );

    const andConditions: Prisma.LabelWhereInput[] = [];

    if (search) {
      andConditions.push({
        OR: [
          { name: { contains: search, mode: 'insensitive' } },
          { introduction: { contains: search, mode: 'insensitive' } },
          { genresPreview: { contains: search, mode: 'insensitive' } },
        ],
      });
    }

    if (nationFilters.length > 0) {
      andConditions.push({
        OR: nationFilters.map((nation) => ({
          nation: { equals: nation, mode: 'insensitive' },
        })),
      });
    }

    if (genreFilters.length > 0) {
      for (const genre of genreFilters) {
        andConditions.push({ genres: { has: genre } });
      }
    }

    const where: Prisma.LabelWhereInput =
      andConditions.length > 0
        ? { AND: andConditions }
        : {};

    const orderBy: Prisma.LabelOrderByWithRelationInput =
      sortBy === 'soundcloudFollowers'
        ? { soundcloudFollowers: order }
        : sortBy === 'likes'
          ? { likes: order }
          : sortBy === 'nation'
            ? { nation: order }
            : sortBy === 'latestRelease'
              ? { latestReleaseListing: order }
              : sortBy === 'createdAt'
                ? { createdAt: order }
                : { name: order };

    const [labels, total] = await Promise.all([
      prisma.label.findMany({
        where,
        orderBy,
        skip: (page - 1) * limit,
        take: limit,
        select: learnLabelListSelect,
      }),
      prisma.label.count({ where }),
    ]);

    const founderDjIds = Array.from(
      new Set(
        labels.flatMap((item) => {
          const nextIds = collectLabelFounderDjIds(normalizeLabelFounders(item.founders));
          return nextIds.filter((id): id is string => Boolean(id));
        })
      )
    );
    const founderDjs = founderDjIds.length > 0
      ? await prisma.dJ.findMany({
          where: { id: { in: founderDjIds } },
        })
      : [];
    const founderDjById = new Map(founderDjs.map((item: { id: string }) => [item.id, item]));
    const hydratedLabels = labels.map((item) => ({
      ...item,
      founders: hydrateLabelFounders(normalizeLabelFounders(item.founders), founderDjById),
    }));

    ok(
      res,
      {
        items: hydratedLabels,
      },
      {
        page,
        limit,
        total,
        totalPages: Math.max(1, Math.ceil(total / limit)),
      }
    );
  } catch (error) {
    console.error('BFF web learn labels error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/learn/labels/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const labelId = String(req.params.id || '').trim();
    if (!labelId) {
      res.status(400).json({ error: 'Label ID is required' });
      return;
    }

    const label = await prisma.label.findUnique({
      where: { id: labelId },
    });

    if (!label) {
      res.status(404).json({ error: 'Label not found' });
      return;
    }

    const normalizedFounders = normalizeLabelFounders(label.founders);
    const founderDjIds = collectLabelFounderDjIds(normalizedFounders);
    const founderDjs = founderDjIds.length
      ? await prisma.dJ.findMany({ where: { id: { in: founderDjIds } } })
      : [];
    const founderDjById = new Map(founderDjs.map((item: { id: string }) => [item.id, item]));

    ok(res, {
      ...label,
      founders: hydrateLabelFounders(normalizedFounders, founderDjById),
    });
  } catch (error) {
    console.error('BFF web learn label detail error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/learn/labels', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    const viewerRole = authReq.user?.role ?? null;

    const body = req.body as Record<string, unknown>;
    const labelValidationError = validateLabelPayload(body);
    if (labelValidationError) {
      res.status(400).json({ error: labelValidationError });
      return;
    }

    const name = normalizeSubmittedSingleLine(body.name, INPUT_LIMITS.label.name);
    if (!name) {
      res.status(400).json({ error: 'Name is required' });
      return;
    }

    const founders = normalizeLabelFounders(body.founders);

    if (!canBypassContentReview(viewerRole)) {
      const normalizedSubmissionPayload = {
        ...body,
        name,
        slug: normalizeOptionalSingleLine(body.slug, INPUT_LIMITS.label.slug),
        profileUrl: normalizeOptionalSingleLine(body.profileUrl, INPUT_LIMITS.common.url),
        profileSlug: normalizeOptionalSingleLine(body.profileSlug, INPUT_LIMITS.label.profileSlug),
        logoUrl: normalizeSubmittedUrl(body.logoUrl),
        avatarUrl: normalizeSubmittedUrl(body.avatarUrl),
        backgroundUrl: normalizeSubmittedUrl(body.backgroundUrl),
        nation: normalizeOptionalSingleLine(body.nation ?? body.country, INPUT_LIMITS.label.nation),
        genresPreview: normalizeOptionalSingleLine(body.genresPreview, INPUT_LIMITS.label.genresPreview),
        latestReleaseListing: normalizeOptionalSingleLine(body.latestReleaseListing, INPUT_LIMITS.label.latestReleaseListing),
        locationPeriod: normalizeOptionalSingleLine(body.locationPeriod, INPUT_LIMITS.label.locationPeriod),
        introductionPreview: normalizeSubmittedMultiline(body.introductionPreview, INPUT_LIMITS.label.introductionPreview),
        introduction: normalizeSubmittedMultiline(body.introduction ?? body.description, INPUT_LIMITS.label.introduction),
        genres: normalizeSubmittedStringArray(body.genres, {
          itemMax: INPUT_LIMITS.label.genre,
          maxItems: 20,
        }),
        foundedAt: normalizeOptionalSingleLine(body.foundedAt, INPUT_LIMITS.label.foundedAt),
        founders,
        demoSubmissionUrl: normalizeSubmittedUrl(body.demoSubmissionUrl),
        demoSubmissionDisplay: normalizeOptionalSingleLine(body.demoSubmissionDisplay, INPUT_LIMITS.label.demoSubmissionDisplay),
        facebookUrl: normalizeSubmittedUrl(body.facebookUrl),
        soundcloudUrl: normalizeSubmittedUrl(body.soundcloudUrl),
        musicPurchaseUrl: normalizeSubmittedUrl(body.musicPurchaseUrl),
        officialWebsiteUrl: normalizeSubmittedUrl(body.officialWebsiteUrl ?? body.officialWebsite),
      };
      const submission = await createPendingContentSubmission({
        submitterId: userId,
        entityType: 'label',
        title: name,
        payload: normalizedSubmissionPayload,
      });
      acceptedSubmission(res, submission, '厂牌信息已提交审核，管理员审核通过后才会入库');
      return;
    }

    const requestedSlug = normalizeOptionalSingleLine(body.slug, INPUT_LIMITS.label.slug) || undefined;
    const slug = await uniqueLabelSlug(name, requestedSlug);
    const created = await prisma.label.create({
      data: {
        name,
        slug,
        profileUrl: normalizeOptionalSingleLine(body.profileUrl, INPUT_LIMITS.common.url) || `community://${slug}`,
        profileSlug: normalizeOptionalSingleLine(body.profileSlug, INPUT_LIMITS.label.profileSlug) || slug,
        logoUrl: normalizeSubmittedUrl(body.logoUrl),
        avatarUrl: normalizeSubmittedUrl(body.avatarUrl),
        backgroundUrl: normalizeSubmittedUrl(body.backgroundUrl),
        nation: normalizeOptionalSingleLine(body.nation ?? body.country, INPUT_LIMITS.label.nation),
        genresPreview: normalizeOptionalSingleLine(body.genresPreview, INPUT_LIMITS.label.genresPreview),
        latestReleaseListing: normalizeOptionalSingleLine(body.latestReleaseListing, INPUT_LIMITS.label.latestReleaseListing),
        locationPeriod: normalizeOptionalSingleLine(body.locationPeriod, INPUT_LIMITS.label.locationPeriod),
        introductionPreview: normalizeSubmittedMultiline(body.introductionPreview, INPUT_LIMITS.label.introductionPreview),
        introduction: normalizeSubmittedMultiline(body.introduction ?? body.description, INPUT_LIMITS.label.introduction),
        genres: normalizeSubmittedStringArray(body.genres, {
          itemMax: INPUT_LIMITS.label.genre,
          maxItems: 20,
        }),
        generalContactEmail: normalizeOptionalSingleLine(body.generalContactEmail, 254),
        demoSubmissionUrl: normalizeSubmittedUrl(body.demoSubmissionUrl),
        demoSubmissionDisplay: normalizeOptionalSingleLine(body.demoSubmissionDisplay, INPUT_LIMITS.label.demoSubmissionDisplay),
        facebookUrl: normalizeSubmittedUrl(body.facebookUrl),
        soundcloudUrl: normalizeSubmittedUrl(body.soundcloudUrl),
        musicPurchaseUrl: normalizeSubmittedUrl(body.musicPurchaseUrl),
        officialWebsiteUrl: normalizeSubmittedUrl(body.officialWebsiteUrl ?? body.officialWebsite),
        foundedAt: normalizeOptionalSingleLine(body.foundedAt, INPUT_LIMITS.label.foundedAt),
        founders: labelFoundersToJson(founders),
        soundcloudFollowers: Object.prototype.hasOwnProperty.call(body, 'soundcloudFollowers')
          ? parseOptionalNonNegativeInt(body.soundcloudFollowers, 'soundcloudFollowers')
          : null,
        likes: Object.prototype.hasOwnProperty.call(body, 'likes')
          ? parseOptionalNonNegativeInt(body.likes, 'likes')
          : null,
      },
    });

    await upsertBrandReleasePublishTaskBestEffort({
      actorUserId: userId,
      operationType: 'create',
      sourceRoute: '/v1/learn/labels',
      entityType: 'label',
      brand: {
        id: created.id,
        name: created.name,
        summary: created.introduction ?? created.introductionPreview ?? created.genresPreview ?? created.name,
        coverImageURL: created.avatarUrl ?? created.backgroundUrl ?? created.logoUrl ?? null,
      },
    });

    const founderDjById = new Map(
      (
        founders.length
          ? await prisma.dJ.findMany({ where: { id: { in: collectLabelFounderDjIds(founders) } } })
          : []
      ).map((item: { id: string }) => [item.id, item])
    );

    ok(res, {
      ...created,
      founders: hydrateLabelFounders(founders, founderDjById),
    });
  } catch (error) {
    console.error('BFF web create learn label error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.patch('/learn/labels/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    const viewerRole = authReq.user?.role ?? null;

    if (!canBypassContentReview(viewerRole)) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const labelId = String(req.params.id || '').trim();
    if (!labelId) {
      res.status(400).json({ error: 'Label ID is required' });
      return;
    }

    const existing = await prisma.label.findUnique({
      where: { id: labelId },
    });
    if (!existing) {
      res.status(404).json({ error: 'Label not found' });
      return;
    }

    const body = (req.body ?? {}) as Record<string, unknown>;
    const hasField = (key: string): boolean => Object.prototype.hasOwnProperty.call(body, key);
    const mergedPayloadForValidation: Record<string, unknown> = {
      name: hasField('name') ? body.name : existing.name,
      slug: hasField('slug') ? body.slug : existing.slug,
      profileUrl: hasField('profileUrl') ? body.profileUrl : existing.profileUrl,
      profileSlug: hasField('profileSlug') ? body.profileSlug : existing.profileSlug,
      nation: hasField('nation') ? body.nation : (hasField('country') ? body.country : existing.nation),
      genresPreview: hasField('genresPreview') ? body.genresPreview : existing.genresPreview,
      latestReleaseListing: hasField('latestReleaseListing') ? body.latestReleaseListing : existing.latestReleaseListing,
      locationPeriod: hasField('locationPeriod') ? body.locationPeriod : existing.locationPeriod,
      introductionPreview: hasField('introductionPreview') ? body.introductionPreview : existing.introductionPreview,
      introduction: hasField('introduction') ? body.introduction : (hasField('description') ? body.description : existing.introduction),
      genres: hasField('genres') ? body.genres : existing.genres,
      foundedAt: hasField('foundedAt') ? body.foundedAt : existing.foundedAt,
      founders: hasField('founders') ? body.founders : existing.founders,
      demoSubmissionDisplay: hasField('demoSubmissionDisplay') ? body.demoSubmissionDisplay : existing.demoSubmissionDisplay,
      demoSubmissionUrl: hasField('demoSubmissionUrl') ? body.demoSubmissionUrl : existing.demoSubmissionUrl,
      facebookUrl: hasField('facebookUrl') ? body.facebookUrl : existing.facebookUrl,
      soundcloudUrl: hasField('soundcloudUrl') ? body.soundcloudUrl : existing.soundcloudUrl,
      musicPurchaseUrl: hasField('musicPurchaseUrl') ? body.musicPurchaseUrl : existing.musicPurchaseUrl,
      officialWebsiteUrl: hasField('officialWebsiteUrl') ? body.officialWebsiteUrl : (hasField('officialWebsite') ? body.officialWebsite : existing.officialWebsiteUrl),
      logoUrl: hasField('logoUrl') ? body.logoUrl : existing.logoUrl,
      avatarUrl: hasField('avatarUrl') ? body.avatarUrl : existing.avatarUrl,
      backgroundUrl: hasField('backgroundUrl') ? body.backgroundUrl : existing.backgroundUrl,
    };
    const labelValidationError = validateLabelPayload(mergedPayloadForValidation);
    if (labelValidationError) {
      res.status(400).json({ error: labelValidationError });
      return;
    }

    const nextName = hasField('name')
      ? normalizeSubmittedSingleLine(body.name, INPUT_LIMITS.label.name)
      : existing.name;
    if (!nextName) {
      res.status(400).json({ error: 'Name is required' });
      return;
    }

    const requestedSlug = hasField('slug') ? normalizeOptionalSingleLine(body.slug, INPUT_LIMITS.label.slug) : null;
    let nextSlug = existing.slug;
    const shouldRegenerateSlug = hasField('slug')
      ? Boolean(requestedSlug && requestedSlug !== existing.slug)
      : nextName !== existing.name;
    if (shouldRegenerateSlug) {
      nextSlug = await uniqueLabelSlug(nextName, requestedSlug || undefined);
    }

    const updateData: Prisma.LabelUpdateInput = {
      name: nextName,
    };

    if (nextSlug !== existing.slug) {
      updateData.slug = nextSlug;
      if (!hasField('profileSlug') && (!existing.profileSlug || existing.profileSlug === existing.slug)) {
        updateData.profileSlug = nextSlug;
      }
      if (!hasField('profileUrl') && existing.profileUrl === `community://${existing.slug}`) {
        updateData.profileUrl = `community://${nextSlug}`;
      }
    }

    if (hasField('profileUrl')) {
      updateData.profileUrl = normalizeOptionalSingleLine(body.profileUrl, INPUT_LIMITS.common.url) || `community://${nextSlug}`;
    }
    if (hasField('profileSlug')) {
      updateData.profileSlug = normalizeOptionalSingleLine(body.profileSlug, INPUT_LIMITS.label.profileSlug);
    }
    if (hasField('logoUrl')) updateData.logoUrl = normalizeSubmittedUrl(body.logoUrl);
    if (hasField('avatarUrl')) updateData.avatarUrl = normalizeSubmittedUrl(body.avatarUrl);
    if (hasField('backgroundUrl')) updateData.backgroundUrl = normalizeSubmittedUrl(body.backgroundUrl);
    if (hasField('nation')) updateData.nation = normalizeOptionalSingleLine(body.nation, INPUT_LIMITS.label.nation);
    if (hasField('country') && !hasField('nation')) updateData.nation = normalizeOptionalSingleLine(body.country, INPUT_LIMITS.label.nation);
    if (hasField('genresPreview')) updateData.genresPreview = normalizeOptionalSingleLine(body.genresPreview, INPUT_LIMITS.label.genresPreview);
    if (hasField('latestReleaseListing')) updateData.latestReleaseListing = normalizeOptionalSingleLine(body.latestReleaseListing, INPUT_LIMITS.label.latestReleaseListing);
    if (hasField('locationPeriod')) updateData.locationPeriod = normalizeOptionalSingleLine(body.locationPeriod, INPUT_LIMITS.label.locationPeriod);
    if (hasField('introductionPreview')) updateData.introductionPreview = normalizeSubmittedMultiline(body.introductionPreview, INPUT_LIMITS.label.introductionPreview);
    if (hasField('introduction')) updateData.introduction = normalizeSubmittedMultiline(body.introduction, INPUT_LIMITS.label.introduction);
    if (hasField('description') && !hasField('introduction')) updateData.introduction = normalizeSubmittedMultiline(body.description, INPUT_LIMITS.label.introduction);
    if (hasField('generalContactEmail')) updateData.generalContactEmail = normalizeOptionalSingleLine(body.generalContactEmail, 254);
    if (hasField('demoSubmissionUrl')) updateData.demoSubmissionUrl = normalizeSubmittedUrl(body.demoSubmissionUrl);
    if (hasField('demoSubmissionDisplay')) updateData.demoSubmissionDisplay = normalizeOptionalSingleLine(body.demoSubmissionDisplay, INPUT_LIMITS.label.demoSubmissionDisplay);
    if (hasField('facebookUrl')) updateData.facebookUrl = normalizeSubmittedUrl(body.facebookUrl);
    if (hasField('soundcloudUrl')) updateData.soundcloudUrl = normalizeSubmittedUrl(body.soundcloudUrl);
    if (hasField('musicPurchaseUrl')) updateData.musicPurchaseUrl = normalizeSubmittedUrl(body.musicPurchaseUrl);
    if (hasField('officialWebsiteUrl')) updateData.officialWebsiteUrl = normalizeSubmittedUrl(body.officialWebsiteUrl);
    if (hasField('officialWebsite') && !hasField('officialWebsiteUrl')) updateData.officialWebsiteUrl = normalizeSubmittedUrl(body.officialWebsite);
    if (hasField('foundedAt')) updateData.foundedAt = normalizeOptionalSingleLine(body.foundedAt, INPUT_LIMITS.label.foundedAt);
    if (hasField('founders')) {
      updateData.founders = labelFoundersToJson(normalizeLabelFounders(body.founders));
    }
    if (hasField('soundcloudFollowers')) {
      const value = body.soundcloudFollowers;
      updateData.soundcloudFollowers = value === null || value === '' ? null : Number(value);
    }
    if (hasField('likes')) {
      const value = body.likes;
      updateData.likes = value === null || value === '' ? null : Number(value);
    }
    if (hasField('genres')) {
      updateData.genres = normalizeSubmittedStringArray(body.genres, {
        itemMax: INPUT_LIMITS.label.genre,
        maxItems: 20,
      });
    }

    const updated = await prisma.label.update({
      where: { id: labelId },
      data: updateData,
    });

    const normalizedFounders = normalizeLabelFounders(updated.founders);
    const founderDjIds = collectLabelFounderDjIds(normalizedFounders);
    const founderDjs = founderDjIds.length
      ? await prisma.dJ.findMany({ where: { id: { in: founderDjIds } } })
      : [];
    const founderDjById = new Map(founderDjs.map((item: { id: string }) => [item.id, item]));

    await upsertBrandReleasePublishTaskBestEffort({
      actorUserId: userId,
      operationType: 'edit',
      sourceRoute: `/v1/learn/labels/${labelId}`,
      entityType: 'label',
      brand: {
        id: updated.id,
        name: updated.name,
        summary: updated.introduction ?? updated.introductionPreview ?? updated.genresPreview ?? updated.name,
        coverImageURL: updated.avatarUrl ?? updated.backgroundUrl ?? updated.logoUrl ?? null,
      },
    });

    ok(res, {
      ...updated,
      founders: hydrateLabelFounders(normalizedFounders, founderDjById),
    });
  } catch (error) {
    console.error('BFF web update learn label error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.delete('/learn/labels/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    const viewerRole = authReq.user?.role ?? null;

    if (!canBypassContentReview(viewerRole)) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const labelId = String(req.params.id || '').trim();
    if (!labelId) {
      res.status(400).json({ error: 'Label ID is required' });
      return;
    }

    const target = await prisma.label.findUnique({
      where: { id: labelId },
      select: {
        id: true,
        logoUrl: true,
        avatarUrl: true,
        backgroundUrl: true,
      },
    });
    if (!target) {
      res.status(404).json({ error: 'Label not found' });
      return;
    }

    const urlsToDelete = [
      target.logoUrl,
      target.avatarUrl,
      target.backgroundUrl,
    ].filter((value): value is string => typeof value === 'string' && value.trim().length > 0);

    await prisma.label.delete({ where: { id: labelId } });
    await notificationCenterService.deleteAdminPublishTasksByEntity({
      entityType: 'label',
      entityId: labelId,
      taskTypes: ['brand_release'],
    });
    await notificationCenterService.deleteAdminContentHistoryByEntity({
      entityType: 'label',
      entityId: labelId,
    });
    for (const url of urlsToDelete) {
      await mediaAssetService.markDeletedByUrl(url);
      await deleteSingleWikiBrandOssObjectIfOwned(url, labelId);
    }
    await deleteWikiBrandOssFolder(labelId);

    ok(res, { success: true });
  } catch (error) {
    console.error('BFF web delete learn label error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/learn/rankings', async (_req: Request, res: Response): Promise<void> => {
  try {
    const boards = await loadRankingBoardsFromDB();
    ok(
      res,
      boards.map((board) => ({
        id: board.id,
        title: board.title,
        subtitle: board.subtitle,
        description: board.description,
        coverImageUrl: board.coverImageUrl || null,
        years: board.years,
        entityType: board.entityType,
        createdAt: board.createdAt,
        updatedAt: board.updatedAt,
      }))
    );
  } catch (error) {
    console.error('BFF web rankings list error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/learn/rankings/:boardId', async (req: Request, res: Response): Promise<void> => {
  try {
    const boardId = sanitizeRankingBoardId(req.params.boardId as string);
    const board = await loadRankingBoardById(boardId);
    if (!board) {
      res.status(404).json({ error: 'Board not found' });
      return;
    }

    if (board.years.length === 0) {
      ok(res, {
        boardId: board.id,
        title: board.title,
        subtitle: board.subtitle,
        description: board.description,
        coverImageUrl: board.coverImageUrl || null,
        entityType: board.entityType,
        years: [],
        year: null,
        entries: [],
      });
      return;
    }

    const requestedYear = Number(req.query.year);
    const year = Number.isFinite(requestedYear) ? requestedYear : board.years[board.years.length - 1];
    if (!board.years.includes(year)) {
      res.status(400).json({ error: 'year is invalid' });
      return;
    }

    const currentYearData = await loadRankingYearData(boardId, year);
    const current = currentYearData?.entries ?? [];
    const strictEntityBinding = Boolean(currentYearData && currentYearData.source !== 'legacy_txt');

    const prevYear = board.years[board.years.indexOf(year) - 1];
    const prev = prevYear
      ? (await loadRankingYearData(boardId, prevYear))?.entries ?? []
      : [];

    const previousRankMap: Record<string, number> = {};
    for (const item of prev) {
      previousRankMap[normalizeName(item.name)] = item.rank;
    }

    let entries: Array<Record<string, unknown>> = [];

    if (board.entityType === 'festival') {
      const festivals = await prisma.wikiFestival.findMany({
        where: { isActive: true },
        select: {
          id: true,
          name: true,
          nameI18n: true,
          aliases: true,
          avatarUrl: true,
          backgroundUrl: true,
          country: true,
          city: true,
          tagline: true,
        },
      });

      const festivalMap: Record<string, any> = {};
      const festivalMapById: Record<string, any> = {};
      for (const fest of festivals) {
        festivalMapById[fest.id] = fest;
        festivalMap[normalizeName(fest.name)] = fest;
        const nameI18n = resolveBiTextWithFallback(fest.nameI18n ?? null, fest.name ?? '');
        if (nameI18n?.zh) {
          festivalMap[normalizeName(nameI18n.zh)] = fest;
        }
        if (nameI18n?.en) {
          festivalMap[normalizeName(nameI18n.en)] = fest;
        }
        for (const alias of Array.isArray(fest.aliases) ? fest.aliases : []) {
          festivalMap[normalizeName(alias)] = fest;
        }
      }

      entries = current.map((item) => {
        const key = normalizeName(item.name);
        const prevRank = previousRankMap[key];
        const fest = (item.entityId ? festivalMapById[item.entityId] : null)
          || (strictEntityBinding ? null : festivalMap[key]);
        return {
          rank: item.rank,
          name: item.name,
          entityId: fest?.id || item.entityId || null,
          delta: prevYear && prevRank !== undefined ? prevRank - item.rank : null,
          festival: fest
            ? {
                id: fest.id,
                name: fest.name,
                avatarUrl: fest.avatarUrl,
                backgroundUrl: fest.backgroundUrl,
                country: fest.country,
                city: fest.city,
                tagline: fest.tagline,
              }
            : null,
          dj: null,
        };
      });
    } else {
      const djs = await prisma.dJ.findMany({
        select: {
          id: true,
          name: true,
          slug: true,
          avatarUrl: true,
          bannerUrl: true,
          followerCount: true,
          country: true,
          aliases: true,
        },
      });
      const djMap: Record<string, any> = {};
      const djMapById: Record<string, any> = {};
      for (const dj of djs) {
        djMapById[dj.id] = dj;
        djMap[normalizeName(dj.name)] = dj;
        for (const alias of Array.isArray(dj.aliases) ? dj.aliases : []) {
          djMap[normalizeName(alias)] = dj;
        }
      }

      entries = current.map((item) => {
        const key = normalizeName(item.name);
        const prevRank = previousRankMap[key];
        const matchedDJ = (item.entityId ? djMapById[item.entityId] : null)
          || (strictEntityBinding ? null : djMap[key]);
        return {
          rank: item.rank,
          name: item.name,
          entityId: matchedDJ?.id || item.entityId || null,
          delta: prevYear && prevRank !== undefined ? prevRank - item.rank : null,
          dj: matchedDJ
            ? {
                id: matchedDJ.id,
                name: matchedDJ.name,
                slug: matchedDJ.slug,
                avatarUrl: matchedDJ.avatarUrl,
                bannerUrl: matchedDJ.bannerUrl,
                followerCount: matchedDJ.followerCount,
                country: matchedDJ.country,
              }
            : null,
          festival: null,
        };
      });
    }

    ok(res, {
      boardId: board.id,
      title: board.title,
      subtitle: board.subtitle,
      description: board.description,
      coverImageUrl: board.coverImageUrl || null,
      entityType: board.entityType,
      years: board.years,
      year,
      strictEntityBinding,
      entries,
    });
  } catch (error) {
    console.error('BFF web rankings detail error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/learn/rankings/upload-image', optionalAuth, wikiBrandImageUpload.single('image'), async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    if (!req.file) {
      res.status(400).json({ error: 'No file uploaded' });
      return;
    }

    if (!postMediaOssClient) {
      res.status(503).json({ error: 'OSS is not configured for ranking image upload' });
      return;
    }

    const body = req.body as Record<string, unknown>;
    const boardId = sanitizeRankingBoardId(String(body?.boardId || 'ranking-temp'));
    const usage = 'cover';
    const uploaded = await uploadWikiBrandMediaToOss(req.file, boardId, usage, userId);
    ok(res, uploaded);
  } catch (error) {
    console.error('BFF web upload ranking image error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/learn/rankings', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const body = (req.body ?? {}) as Record<string, unknown>;
    const title = String(body.title || '').trim();
    if (!title) {
      res.status(400).json({ error: 'title is required' });
      return;
    }

    const entityType: RankingEntityType = String(body.entityType || '').trim() === 'festival' ? 'festival' : 'dj';
    const requestedId = String(body.id || '').trim();
    const boardId = sanitizeRankingBoardId(requestedId || title);
    const existing = await prisma.rankingBoard.findUnique({ where: { id: boardId }, select: { id: true } });
    if (existing) {
      res.status(409).json({ error: 'board id already exists' });
      return;
    }

    const nowIso = new Date().toISOString();
    const board: RankingBoardRecord = {
      id: boardId,
      title,
      subtitle: String(body.subtitle || '').trim(),
      description: String(body.description || '').trim(),
      coverImageUrl: String(body.coverImageUrl || '').trim() || null,
      entityType,
      years: normalizeRankingYears(body.years),
      createdAt: nowIso,
      updatedAt: nowIso,
    };

    const year = Number(body.year);
    const importText = String(body.importText || '').trim();
    const explicitEntries = parseRankingEntries(body.entries);
    const importedEntries = importText
      ? parseRankingText(importText).map((item) => ({ rank: item.rank, name: item.name }))
      : [];
    const finalEntries = explicitEntries.length > 0 ? explicitEntries : importedEntries;

    const created = await saveRankingBoard(board);
    if (Number.isFinite(year) && year > 1900 && year < 2201 && finalEntries.length > 0) {
      await saveRankingYearData(boardId, Math.floor(year), finalEntries, importText ? 'import_text' : 'manual_create');
      if (entityType === 'dj') {
        await syncDJHonorsForDJIds(await collectAffectedDJIdsFromEntries(finalEntries));
      }
    }

    ok(res, {
      ...created,
      years: Array.from(new Set([...created.years, ...board.years, ...(Number.isFinite(year) ? [Math.floor(year)] : [])]))
        .filter((item) => item >= 1900 && item <= 2200)
        .sort((a, b) => a - b),
    });
  } catch (error) {
    console.error('BFF web create ranking board error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.patch('/learn/rankings/:boardId', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const boardId = sanitizeRankingBoardId(String(req.params.boardId ?? ''));
    const body = (req.body ?? {}) as Record<string, unknown>;
    const current = await loadRankingBoardById(boardId);
    if (!current) {
      res.status(404).json({ error: 'Board not found' });
      return;
    }

    const next: RankingBoardRecord = {
      ...current,
      title: Object.prototype.hasOwnProperty.call(body, 'title')
        ? String(body.title || '').trim() || current.title
        : current.title,
      subtitle: Object.prototype.hasOwnProperty.call(body, 'subtitle')
        ? String(body.subtitle || '').trim()
        : current.subtitle,
      description: Object.prototype.hasOwnProperty.call(body, 'description')
        ? String(body.description || '').trim()
        : current.description,
      coverImageUrl: Object.prototype.hasOwnProperty.call(body, 'coverImageUrl')
        ? (String(body.coverImageUrl || '').trim() || null)
        : current.coverImageUrl,
      entityType: Object.prototype.hasOwnProperty.call(body, 'entityType')
        ? (String(body.entityType || '').trim() === 'festival' ? 'festival' : 'dj')
        : current.entityType,
      years: Object.prototype.hasOwnProperty.call(body, 'years')
        ? normalizeRankingYears(body.years)
        : current.years,
      updatedAt: new Date().toISOString(),
    };

    const saved = await saveRankingBoard(next);
    if (current.entityType === 'dj' || saved.entityType === 'dj') {
      const yearRows = await prisma.rankingEntry.findMany({
        where: {
          rankingYear: { boardId },
          entityId: { not: null },
        },
        select: { entityId: true },
      });
      await syncDJHonorsForDJIds(yearRows.map((row) => row.entityId).filter((item): item is string => Boolean(item)));
    }
    ok(res, saved);
  } catch (error) {
    console.error('BFF web update ranking board error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.delete('/learn/rankings/:boardId', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const boardId = sanitizeRankingBoardId(String(req.params.boardId ?? ''));
    const target = await loadRankingBoardById(boardId);
    if (!target) {
      res.status(404).json({ error: 'Board not found' });
      return;
    }
    const affectedDJIds = target.entityType === 'dj'
      ? (await prisma.rankingEntry.findMany({
          where: {
            rankingYear: { boardId },
            entityId: { not: null },
          },
          select: { entityId: true },
        })).map((row) => row.entityId).filter((item): item is string => Boolean(item))
      : [];

    if (target.coverImageUrl) {
      await mediaAssetService.markDeletedByUrl(target.coverImageUrl);
      await deleteSingleWikiBrandOssObjectIfOwned(target.coverImageUrl, boardId);
    }
    await deleteWikiBrandOssFolder(boardId);
    await prisma.rankingBoard.delete({ where: { id: boardId } });
    await syncDJHonorsForDJIds(affectedDJIds);
    ok(res, { success: true });
  } catch (error) {
    console.error('BFF web delete ranking board error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/learn/rankings/:boardId/years/:year/upsert', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const boardId = sanitizeRankingBoardId(String(req.params.boardId ?? ''));
    const year = Number(String(req.params.year ?? ''));
    if (!Number.isFinite(year) || year < 1900 || year > 2200) {
      res.status(400).json({ error: 'year is invalid' });
      return;
    }

    const board = await loadRankingBoardById(boardId);
    if (!board) {
      res.status(404).json({ error: 'Board not found' });
      return;
    }
    const previousEntries = (await loadRankingYearData(boardId, Math.floor(year)))?.entries ?? [];

    const body = (req.body ?? {}) as Record<string, unknown>;
    const explicitEntries = parseRankingEntries(body.entries);
    const importText = String(body.importText || '').trim();
    const importedEntries = importText
      ? parseRankingText(importText).map((item) => ({ rank: item.rank, name: item.name }))
      : [];
    const entries = explicitEntries.length > 0 ? explicitEntries : importedEntries;

    await saveRankingYearData(boardId, Math.floor(year), entries, importText ? 'import_text' : 'manual_update');
    const nextYears = Array.from(new Set([...board.years, Math.floor(year)])).sort((a, b) => a - b);
    if (board.entityType === 'dj') {
      const affectedIds = await collectAffectedDJIdsFromEntries([...previousEntries, ...entries]);
      await syncDJHonorsForDJIds(affectedIds);
    }

    ok(res, {
      boardId,
      year: Math.floor(year),
      count: entries.length,
      years: nextYears,
    });
  } catch (error) {
    console.error('BFF web upsert ranking year error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/learn/rankings/:boardId/years/:year/auto-match-preview', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const boardId = sanitizeRankingBoardId(String(req.params.boardId ?? ''));
    const year = Number(req.params.year);
    if (!Number.isFinite(year) || year < 1900 || year > 2200) {
      res.status(400).json({ error: 'year is invalid' });
      return;
    }

    const board = await loadRankingBoardById(boardId);
    if (!board) {
      res.status(404).json({ error: 'Board not found' });
      return;
    }

    const yearData = await loadRankingYearData(boardId, Math.floor(year));
    if (!yearData) {
      res.status(404).json({ error: 'Ranking year not found' });
      return;
    }

    ok(res, await buildRankingAutoMatchPreview(board, yearData));
  } catch (error) {
    console.error('BFF web ranking auto match preview error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/learn/rankings/:boardId/years/:year/auto-match-apply', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const boardId = sanitizeRankingBoardId(String(req.params.boardId ?? ''));
    const year = Number(req.params.year);
    if (!Number.isFinite(year) || year < 1900 || year > 2200) {
      res.status(400).json({ error: 'year is invalid' });
      return;
    }

    const board = await loadRankingBoardById(boardId);
    if (!board) {
      res.status(404).json({ error: 'Board not found' });
      return;
    }

    const yearData = await loadRankingYearData(boardId, Math.floor(year));
    if (!yearData) {
      res.status(404).json({ error: 'Ranking year not found' });
      return;
    }

    const preview = await buildRankingAutoMatchPreview(board, yearData);
    const nextEntries = yearData.entries.map((entry) => {
      const matched = preview.items.find((item) => item.rank === entry.rank);
      if (matched?.status === 'matched' && matched.suggested?.id) {
        return {
          ...entry,
          entityId: matched.suggested.id,
        };
      }
      return entry;
    });

    await saveRankingYearData(boardId, Math.floor(year), nextEntries, 'auto_match_apply');
    if (board.entityType === 'dj') {
      const affectedIds = await collectAffectedDJIdsFromEntries([...yearData.entries, ...nextEntries]);
      await syncDJHonorsForDJIds(affectedIds);
    }

    const savedYear = await loadRankingYearData(boardId, Math.floor(year));
    if (!savedYear) {
      res.status(500).json({ error: 'Ranking year could not be reloaded' });
      return;
    }

    ok(res, await buildRankingAutoMatchPreview(board, savedYear));
  } catch (error) {
    console.error('BFF web ranking auto match apply error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.patch('/learn/rankings/:boardId/years/:year/entries/:rank/binding', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    if (!canBypassContentReview(authReq.user?.role ?? null)) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const boardId = sanitizeRankingBoardId(String(req.params.boardId ?? ''));
    const year = Number(req.params.year);
    const rank = Number(req.params.rank);
    if (!Number.isFinite(year) || !Number.isFinite(rank)) {
      res.status(400).json({ error: 'year or rank is invalid' });
      return;
    }

    const rankingYear = await prisma.rankingYear.findUnique({
      where: {
        boardId_year: {
          boardId,
          year: Math.floor(year),
        },
      },
      include: {
        board: true,
      },
    });
    if (!rankingYear) {
      res.status(404).json({ error: 'Ranking year not found' });
      return;
    }

    const body = (req.body ?? {}) as Record<string, unknown>;
    const entityId = typeof body.entityId === 'string' && body.entityId.trim() ? body.entityId.trim() : null;

    const updated = await prisma.rankingEntry.update({
      where: {
        rankingYearId_rank: {
          rankingYearId: rankingYear.id,
          rank: Math.floor(rank),
        },
      },
      data: { entityId },
    });

    let dj: Record<string, unknown> | null = null;
    let festival: Record<string, unknown> | null = null;

    if (rankingYear.board.entityType === 'dj' && entityId) {
      const matchedDJ = await prisma.dJ.findUnique({
        where: { id: entityId },
        select: {
          id: true,
          name: true,
          slug: true,
          avatarUrl: true,
          bannerUrl: true,
          followerCount: true,
          country: true,
        },
      });
      if (matchedDJ) {
        dj = matchedDJ;
      }
      await syncDJHonorsForDJIds([entityId]);
    }

    if (rankingYear.board.entityType === 'festival' && entityId) {
      const matchedFestival = await prisma.wikiFestival.findUnique({
        where: { id: entityId },
        select: {
          id: true,
          name: true,
          avatarUrl: true,
          backgroundUrl: true,
          country: true,
          city: true,
          tagline: true,
        },
      });
      if (matchedFestival) {
        festival = matchedFestival;
      }
    }

    ok(res, {
      rank: updated.rank,
      name: updated.name,
      entityId: updated.entityId || null,
      delta: null,
      dj,
      festival,
    });
  } catch (error) {
    console.error('BFF web ranking binding update error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/admin/identifiers/organizers', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    if (!canBypassContentReview(authReq.user?.role ?? null)) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const page = normalizePage(req.query.page, 1);
    const limit = normalizeLimit(req.query.limit, 20, 100);
    const search = typeof req.query.search === 'string' ? req.query.search.trim() : '';
    const where: Prisma.WikiFestivalWhereInput = {
      isActive: true,
      ...(search
        ? {
            OR: [
              { name: { contains: search, mode: 'insensitive' } },
              { country: { contains: search, mode: 'insensitive' } },
              { city: { contains: search, mode: 'insensitive' } },
            ],
          }
        : {}),
    };

    const [items, total] = await Promise.all([
      prisma.wikiFestival.findMany({
        where,
        orderBy: [{ updatedAt: 'desc' }],
        skip: (page - 1) * limit,
        take: limit,
        select: {
          id: true,
          name: true,
          sourceRowId: true,
          country: true,
          city: true,
        },
      }),
      prisma.wikiFestival.count({ where }),
    ]);

    ok(res, { items }, {
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit) || 1,
    });
  } catch (error) {
    console.error('BFF web identifier organizers list error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.patch('/admin/identifiers/organizers/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    if (!canBypassContentReview(authReq.user?.role ?? null)) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const id = req.params.id as string;
    const body = (req.body ?? {}) as Record<string, unknown>;
    const sourceRowId = body.sourceRowId === null || body.sourceRowId === ''
      ? null
      : normalizeWikiFestivalInteger(body.sourceRowId);
    if (body.sourceRowId !== null && body.sourceRowId !== '' && sourceRowId === null) {
      res.status(400).json({ error: 'sourceRowId must be an integer' });
      return;
    }

    const updated = await prisma.wikiFestival.update({
      where: { id },
      data: { sourceRowId },
      select: {
        id: true,
        name: true,
        sourceRowId: true,
        country: true,
        city: true,
      },
    });

    ok(res, updated);
  } catch (error) {
    console.error('BFF web identifier organizer update error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/admin/identifiers/labels', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    if (!canBypassContentReview(authReq.user?.role ?? null)) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const page = normalizePage(req.query.page, 1);
    const limit = normalizeLimit(req.query.limit, 20, 100);
    const search = typeof req.query.search === 'string' ? req.query.search.trim() : '';
    const where: Prisma.LabelWhereInput = search
      ? {
          OR: [
            { name: { contains: search, mode: 'insensitive' } },
            { slug: { contains: search, mode: 'insensitive' } },
            { profileSlug: { contains: search, mode: 'insensitive' } },
            { profileUrl: { contains: search, mode: 'insensitive' } },
          ],
        }
      : {};

    const [items, total] = await Promise.all([
      prisma.label.findMany({
        where,
        orderBy: [{ updatedAt: 'desc' }],
        skip: (page - 1) * limit,
        take: limit,
        select: {
          id: true,
          name: true,
          slug: true,
          profileSlug: true,
          profileUrl: true,
          nation: true,
        },
      }),
      prisma.label.count({ where }),
    ]);

    ok(res, { items }, {
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit) || 1,
    });
  } catch (error) {
    console.error('BFF web identifier labels list error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.patch('/admin/identifiers/labels/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    if (!canBypassContentReview(authReq.user?.role ?? null)) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const id = req.params.id as string;
    const existing = await prisma.label.findUnique({
      where: { id },
      select: {
        id: true,
        name: true,
        slug: true,
        profileSlug: true,
        profileUrl: true,
        nation: true,
      },
    });
    if (!existing) {
      res.status(404).json({ error: 'Label not found' });
      return;
    }

    const body = (req.body ?? {}) as Record<string, unknown>;
    const hasSlug = Object.prototype.hasOwnProperty.call(body, 'slug');
    const hasProfileSlug = Object.prototype.hasOwnProperty.call(body, 'profileSlug');
    const hasProfileUrl = Object.prototype.hasOwnProperty.call(body, 'profileUrl');
    const requestedSlug = hasSlug && typeof body.slug === 'string' ? body.slug.trim() : existing.slug;
    const nextSlug = hasSlug ? await uniqueLabelSlug(existing.name, requestedSlug) : existing.slug;
    const nextProfileSlug = hasProfileSlug
      ? (typeof body.profileSlug === 'string' && body.profileSlug.trim() ? body.profileSlug.trim() : null)
      : existing.profileSlug;
    const nextProfileUrl = hasProfileUrl
      ? (typeof body.profileUrl === 'string' && body.profileUrl.trim() ? body.profileUrl.trim() : `community://${nextSlug}`)
      : existing.profileUrl;

    const updated = await prisma.label.update({
      where: { id },
      data: {
        slug: nextSlug,
        profileSlug: nextProfileSlug,
        profileUrl: nextProfileUrl,
      },
      select: {
        id: true,
        name: true,
        slug: true,
        profileSlug: true,
        profileUrl: true,
        nation: true,
      },
    });

    ok(res, updated);
  } catch (error) {
    console.error('BFF web identifier label update error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/admin/identifiers/ranking-entries', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    if (!canBypassContentReview(authReq.user?.role ?? null)) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const page = normalizePage(req.query.page, 1);
    const limit = normalizeLimit(req.query.limit, 50, 100);
    const search = typeof req.query.search === 'string' ? req.query.search.trim() : '';
    const where: Prisma.RankingEntryWhereInput = search
      ? {
          OR: [
            { name: { contains: search, mode: 'insensitive' } },
            { entityId: { contains: search, mode: 'insensitive' } },
            { rankingYear: { board: { title: { contains: search, mode: 'insensitive' } } } },
          ],
        }
      : {};

    const [rows, total] = await Promise.all([
      prisma.rankingEntry.findMany({
        where,
        include: {
          rankingYear: {
            include: {
              board: true,
            },
          },
        },
        orderBy: [
          { rankingYear: { updatedAt: 'desc' } },
          { rank: 'asc' },
        ],
        skip: (page - 1) * limit,
        take: limit,
      }),
      prisma.rankingEntry.count({ where }),
    ]);

    ok(res, {
      items: rows.map((row) => ({
        boardId: row.rankingYear.boardId,
        boardTitle: row.rankingYear.board.title,
        entityType: row.rankingYear.board.entityType === 'festival' ? 'festival' : 'dj',
        year: row.rankingYear.year,
        rank: row.rank,
        name: row.name,
        entityId: row.entityId || null,
      })),
    }, {
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit) || 1,
    });
  } catch (error) {
    console.error('BFF web identifier ranking entries list error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.patch('/admin/identifiers/ranking-entries/:boardId/:year/:rank', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    if (!canBypassContentReview(authReq.user?.role ?? null)) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const boardId = sanitizeRankingBoardId(String(req.params.boardId ?? ''));
    const year = Number(req.params.year);
    const rank = Number(req.params.rank);
    if (!Number.isFinite(year) || !Number.isFinite(rank)) {
      res.status(400).json({ error: 'year or rank is invalid' });
      return;
    }

    const yearRow = await prisma.rankingYear.findUnique({
      where: {
        boardId_year: {
          boardId,
          year: Math.floor(year),
        },
      },
      include: {
        board: true,
      },
    });
    if (!yearRow) {
      res.status(404).json({ error: 'Ranking year not found' });
      return;
    }

    const body = (req.body ?? {}) as Record<string, unknown>;
    const entityId = typeof body.entityId === 'string' && body.entityId.trim() ? body.entityId.trim() : null;

    const updated = await prisma.rankingEntry.update({
      where: {
        rankingYearId_rank: {
          rankingYearId: yearRow.id,
          rank: Math.floor(rank),
        },
      },
      data: {
        entityId,
      },
    });

    if (yearRow.board.entityType === 'dj') {
      await syncDJHonorsForDJIds(
        [updated.entityId].filter((item): item is string => Boolean(item))
      );
    }

    ok(res, {
      boardId,
      boardTitle: yearRow.board.title,
      entityType: yearRow.board.entityType === 'festival' ? 'festival' : 'dj',
      year: yearRow.year,
      rank: updated.rank,
      name: updated.name,
      entityId: updated.entityId || null,
    });
  } catch (error) {
    console.error('BFF web identifier ranking entry update error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/admin/identifiers/unreleased-tracks', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    if (!canBypassContentReview(authReq.user?.role ?? null)) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const page = normalizePage(req.query.page, 1);
    const limit = normalizeLimit(req.query.limit, 20, 100);
    const search = typeof req.query.search === 'string' ? req.query.search.trim() : '';
    const sourceType = typeof req.query.sourceType === 'string' ? req.query.sourceType.trim() : 'all';

    const trackWhere: Prisma.TrackWhereInput = {
      status: 'id',
      ...(search
        ? {
            OR: [
              { title: { contains: search, mode: 'insensitive' } },
              { artist: { contains: search, mode: 'insensitive' } },
              { set: { title: { contains: search, mode: 'insensitive' } } },
              { set: { eventName: { contains: search, mode: 'insensitive' } } },
            ],
          }
        : {}),
    };

    const tracklistTrackWhere: Prisma.TracklistTrackWhereInput = {
      status: 'id',
      ...(search
        ? {
            OR: [
              { title: { contains: search, mode: 'insensitive' } },
              { artist: { contains: search, mode: 'insensitive' } },
              { tracklist: { title: { contains: search, mode: 'insensitive' } } },
              { tracklist: { set: { title: { contains: search, mode: 'insensitive' } } } },
              { tracklist: { uploader: { displayName: { contains: search, mode: 'insensitive' } } } },
              { tracklist: { uploader: { username: { contains: search, mode: 'insensitive' } } } },
            ],
          }
        : {}),
    };

    const [defaultTracks, tracklistTracks] = await Promise.all([
      sourceType === 'tracklist_track'
        ? Promise.resolve([])
        : prisma.track.findMany({
            where: trackWhere,
            include: {
              set: {
                include: {
                  dj: {
                    select: { id: true, name: true },
                  },
                  artists: {
                    orderBy: [{ artistOrder: 'asc' }, { createdAt: 'asc' }],
                    include: {
                      dj: {
                        select: { id: true, name: true },
                      },
                    },
                  },
                },
              },
            },
            orderBy: [{ updatedAt: 'desc' }, { createdAt: 'desc' }],
          }),
      sourceType === 'default_track'
        ? Promise.resolve([])
        : prisma.tracklistTrack.findMany({
            where: tracklistTrackWhere,
            include: {
              tracklist: {
                include: {
                  uploader: {
                    select: {
                      id: true,
                      username: true,
                      displayName: true,
                    },
                  },
                  set: {
                    include: {
                      dj: {
                        select: { id: true, name: true },
                      },
                      artists: {
                        orderBy: [{ artistOrder: 'asc' }, { createdAt: 'asc' }],
                        include: {
                          dj: {
                            select: { id: true, name: true },
                          },
                        },
                      },
                    },
                  },
                },
              },
            },
            orderBy: [{ updatedAt: 'desc' }, { createdAt: 'desc' }],
          }),
    ]);

    const defaultItems = defaultTracks.map((item) => {
      const setArtists = Array.isArray(item.set?.artists) ? item.set.artists : [];
      const djDisplayName =
        setArtists
          .map((artist) => artist.dj?.name || artist.artistNameSnapshot)
          .filter(Boolean)
          .join(' b2b ')
        || item.set?.dj?.name
        || item.set?.title
        || 'Unknown DJ';

      return {
        rowId: `track:${item.id}`,
        sourceType: 'default_track',
        setId: item.setId,
        setTitle: item.set?.title || '',
        setSlug: item.set?.slug || '',
        setRecordedAt: item.set?.recordedAt?.toISOString?.() || null,
        djDisplayName,
        tracklistId: null,
        tracklistTitle: null,
        contributorName: null,
        position: item.position,
        startTime: item.startTime,
        endTime: item.endTime ?? null,
        title: item.title,
        artist: item.artist,
        status: item.status,
        label: item.label ?? null,
        releaseYear: item.releaseYear ?? null,
        spotifyUrl: item.spotifyUrl ?? null,
        spotifyId: item.spotifyId ?? null,
        spotifyUri: item.spotifyUri ?? null,
        appleMusicUrl: item.appleMusicUrl ?? null,
        youtubeMusicUrl: item.youtubeMusicUrl ?? null,
        soundcloudUrl: item.soundcloudUrl ?? null,
        beatportUrl: item.beatportUrl ?? null,
        neteaseUrl: item.neteaseUrl ?? null,
        neteaseId: item.neteaseId ?? null,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
      };
    });

    const tracklistItems = tracklistTracks.map((item) => {
      const setArtists = Array.isArray(item.tracklist?.set?.artists) ? item.tracklist.set.artists : [];
      const contributorName =
        item.tracklist?.uploader?.displayName
        || item.tracklist?.uploader?.username
        || null;
      const djDisplayName =
        setArtists
          .map((artist) => artist.dj?.name || artist.artistNameSnapshot)
          .filter(Boolean)
          .join(' b2b ')
        || item.tracklist?.set?.dj?.name
        || item.tracklist?.set?.title
        || 'Unknown DJ';

      return {
        rowId: `tracklist:${item.id}`,
        sourceType: 'tracklist_track',
        setId: item.tracklist?.setId || '',
        setTitle: item.tracklist?.set?.title || '',
        setSlug: item.tracklist?.set?.slug || '',
        setRecordedAt: item.tracklist?.set?.recordedAt?.toISOString?.() || null,
        djDisplayName,
        tracklistId: item.tracklistId,
        tracklistTitle: item.tracklist?.title || null,
        contributorName,
        position: item.position,
        startTime: item.startTime,
        endTime: item.endTime ?? null,
        title: item.title,
        artist: item.artist,
        status: item.status,
        label: item.label ?? null,
        releaseYear: item.releaseYear ?? null,
        spotifyUrl: item.spotifyUrl ?? null,
        spotifyId: item.spotifyId ?? null,
        spotifyUri: item.spotifyUri ?? null,
        appleMusicUrl: item.appleMusicUrl ?? null,
        youtubeMusicUrl: item.youtubeMusicUrl ?? null,
        soundcloudUrl: item.soundcloudUrl ?? null,
        beatportUrl: item.beatportUrl ?? null,
        neteaseUrl: item.neteaseUrl ?? null,
        neteaseId: item.neteaseId ?? null,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
      };
    });

    const merged = [...defaultItems, ...tracklistItems]
      .sort((a, b) => {
        const aTime = new Date(a.updatedAt).getTime();
        const bTime = new Date(b.updatedAt).getTime();
        return bTime - aTime;
      });

    const start = (page - 1) * limit;
    const paged = merged.slice(start, start + limit);

    ok(res, { items: paged }, {
      page,
      limit,
      total: merged.length,
      totalPages: Math.ceil(merged.length / limit) || 1,
    });
  } catch (error) {
    console.error('BFF web unreleased tracks list error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.patch('/admin/identifiers/unreleased-tracks/:rowId', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;
    if (!canBypassContentReview(authReq.user?.role ?? null)) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const rowId = String(req.params.rowId || '');
    const [sourceType, sourceId] = rowId.split(':');
    if (!sourceType || !sourceId) {
      res.status(400).json({ error: 'rowId is invalid' });
      return;
    }

    const body = (req.body ?? {}) as Record<string, unknown>;
    const nextStatus = typeof body.status === 'string' ? body.status.trim() : undefined;
    if (nextStatus && !['released', 'id', 'remix', 'edit'].includes(nextStatus)) {
      res.status(400).json({ error: 'status is invalid' });
      return;
    }
    const releaseYear = body.releaseYear === null || body.releaseYear === ''
      ? null
      : Number(body.releaseYear);
    if (body.releaseYear !== undefined && body.releaseYear !== null && body.releaseYear !== '' && !Number.isFinite(releaseYear)) {
      res.status(400).json({ error: 'releaseYear is invalid' });
      return;
    }

    const baseData = {
      ...(Object.prototype.hasOwnProperty.call(body, 'title') ? { title: String(body.title || '').trim() } : {}),
      ...(Object.prototype.hasOwnProperty.call(body, 'artist') ? { artist: String(body.artist || '').trim() } : {}),
      ...(Object.prototype.hasOwnProperty.call(body, 'status') ? { status: nextStatus || 'id' } : {}),
      ...(Object.prototype.hasOwnProperty.call(body, 'label')
        ? { label: typeof body.label === 'string' && body.label.trim() ? body.label.trim() : null }
        : {}),
      ...(Object.prototype.hasOwnProperty.call(body, 'releaseYear') ? { releaseYear: releaseYear === null ? null : Math.floor(releaseYear) } : {}),
      ...(Object.prototype.hasOwnProperty.call(body, 'spotifyUrl')
        ? { spotifyUrl: typeof body.spotifyUrl === 'string' && body.spotifyUrl.trim() ? body.spotifyUrl.trim() : null }
        : {}),
      ...(Object.prototype.hasOwnProperty.call(body, 'spotifyId')
        ? { spotifyId: typeof body.spotifyId === 'string' && body.spotifyId.trim() ? body.spotifyId.trim() : null }
        : {}),
      ...(Object.prototype.hasOwnProperty.call(body, 'spotifyUri')
        ? { spotifyUri: typeof body.spotifyUri === 'string' && body.spotifyUri.trim() ? body.spotifyUri.trim() : null }
        : {}),
      ...(Object.prototype.hasOwnProperty.call(body, 'appleMusicUrl')
        ? { appleMusicUrl: typeof body.appleMusicUrl === 'string' && body.appleMusicUrl.trim() ? body.appleMusicUrl.trim() : null }
        : {}),
      ...(Object.prototype.hasOwnProperty.call(body, 'youtubeMusicUrl')
        ? { youtubeMusicUrl: typeof body.youtubeMusicUrl === 'string' && body.youtubeMusicUrl.trim() ? body.youtubeMusicUrl.trim() : null }
        : {}),
      ...(Object.prototype.hasOwnProperty.call(body, 'soundcloudUrl')
        ? { soundcloudUrl: typeof body.soundcloudUrl === 'string' && body.soundcloudUrl.trim() ? body.soundcloudUrl.trim() : null }
        : {}),
      ...(Object.prototype.hasOwnProperty.call(body, 'beatportUrl')
        ? { beatportUrl: typeof body.beatportUrl === 'string' && body.beatportUrl.trim() ? body.beatportUrl.trim() : null }
        : {}),
      ...(Object.prototype.hasOwnProperty.call(body, 'neteaseUrl')
        ? { neteaseUrl: typeof body.neteaseUrl === 'string' && body.neteaseUrl.trim() ? body.neteaseUrl.trim() : null }
        : {}),
      ...(Object.prototype.hasOwnProperty.call(body, 'neteaseId')
        ? { neteaseId: typeof body.neteaseId === 'string' && body.neteaseId.trim() ? body.neteaseId.trim() : null }
        : {}),
    };

    if (sourceType === 'track') {
      const updated = await prisma.track.update({
        where: { id: sourceId },
        data: baseData,
      });
      ok(res, {
        rowId,
        sourceType: 'default_track',
        setId: updated.setId,
        setTitle: '',
        setSlug: '',
        setRecordedAt: null,
        djDisplayName: '',
        tracklistId: null,
        tracklistTitle: null,
        contributorName: null,
        position: updated.position,
        startTime: updated.startTime,
        endTime: updated.endTime ?? null,
        title: updated.title,
        artist: updated.artist,
        status: updated.status,
        label: updated.label ?? null,
        releaseYear: updated.releaseYear ?? null,
        spotifyUrl: updated.spotifyUrl ?? null,
        spotifyId: updated.spotifyId ?? null,
        spotifyUri: updated.spotifyUri ?? null,
        appleMusicUrl: updated.appleMusicUrl ?? null,
        youtubeMusicUrl: updated.youtubeMusicUrl ?? null,
        soundcloudUrl: updated.soundcloudUrl ?? null,
        beatportUrl: updated.beatportUrl ?? null,
        neteaseUrl: updated.neteaseUrl ?? null,
        neteaseId: updated.neteaseId ?? null,
        createdAt: updated.createdAt,
        updatedAt: updated.updatedAt,
      });
      return;
    }

    if (sourceType === 'tracklist') {
      const updated = await prisma.tracklistTrack.update({
        where: { id: sourceId },
        data: baseData,
      });
      ok(res, {
        rowId,
        sourceType: 'tracklist_track',
        setId: '',
        setTitle: '',
        setSlug: '',
        setRecordedAt: null,
        djDisplayName: '',
        tracklistId: updated.tracklistId,
        tracklistTitle: null,
        contributorName: null,
        position: updated.position,
        startTime: updated.startTime,
        endTime: updated.endTime ?? null,
        title: updated.title,
        artist: updated.artist,
        status: updated.status,
        label: updated.label ?? null,
        releaseYear: updated.releaseYear ?? null,
        spotifyUrl: updated.spotifyUrl ?? null,
        spotifyId: updated.spotifyId ?? null,
        spotifyUri: updated.spotifyUri ?? null,
        appleMusicUrl: updated.appleMusicUrl ?? null,
        youtubeMusicUrl: updated.youtubeMusicUrl ?? null,
        soundcloudUrl: updated.soundcloudUrl ?? null,
        beatportUrl: updated.beatportUrl ?? null,
        neteaseUrl: updated.neteaseUrl ?? null,
        neteaseId: updated.neteaseId ?? null,
        createdAt: updated.createdAt,
        updatedAt: updated.updatedAt,
      });
      return;
    }

    res.status(400).json({ error: 'rowId source type is invalid' });
  } catch (error) {
    console.error('BFF web unreleased track update error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/events/timetable/import-image', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  const requestStartedAt = Date.now();
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const runtimeCozeConfig = getRuntimeCozeConfig();
    const cozeTimetableWorkflowRunUrl = runtimeCozeConfig.timetable.runUrl;
    const cozeTimetableWorkflowToken = runtimeCozeConfig.timetable.token;
    if (!cozeTimetableWorkflowRunUrl || !cozeTimetableWorkflowToken) {
      res.status(503).json({ error: 'COZE_TIMETABLE_WORKFLOW_RUN_URL or COZE_TIMETABLE_WORKFLOW_TOKEN is not configured' });
      return;
    }

    const body = req.body as Record<string, unknown>;
    const imageUrl = typeof body.imageUrl === 'string' ? body.imageUrl.trim() : '';
    const fileType = typeof body.fileType === 'string' ? body.fileType.trim() : 'image';
    const context = sanitizeTimetableRecognitionContext(body.context);

    if (!imageUrl) {
      res.status(400).json({ error: 'imageUrl is required' });
      return;
    }

    const imported = await runCozeTimetableWorker(req, imageUrl, fileType, context);
    console.info('[timetable-import] request.success', {
      userId,
      durationMs: Date.now() - requestStartedAt,
    });
    ok(res, imported);
  } catch (error) {
    const message = error instanceof Error ? error.message : '';
    console.error('BFF web timetable import image error:', {
      durationMs: Date.now() - requestStartedAt,
      message,
      error,
    });
    if (message.includes('WORKFLOW_TIMEOUT')) {
      res.status(504).json({ error: '时间表识别超时，请稍后重试或换一张更清晰的图' });
      return;
    }
    if (message.startsWith('Coze workflow request failed')) {
      res.status(502).json({ error: '时间表识别服务暂时不可用，请稍后重试' });
      return;
    }
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/events/timetable/import-image/jobs', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  const requestStartedAt = Date.now();
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const runtimeCozeConfig = getRuntimeCozeConfig();
    const cozeTimetableWorkflowRunUrl = runtimeCozeConfig.timetable.runUrl;
    const cozeTimetableWorkflowToken = runtimeCozeConfig.timetable.token;
    if (!cozeTimetableWorkflowRunUrl || !cozeTimetableWorkflowToken) {
      res.status(503).json({ error: 'COZE_TIMETABLE_WORKFLOW_RUN_URL or COZE_TIMETABLE_WORKFLOW_TOKEN is not configured' });
      return;
    }

    const body = req.body as Record<string, unknown>;
    const imageUrl = typeof body.imageUrl === 'string' ? body.imageUrl.trim() : '';
    const fileType = typeof body.fileType === 'string' ? body.fileType.trim() : 'image';
    const context = sanitizeTimetableRecognitionContext(body.context);

    if (!imageUrl) {
      res.status(400).json({ error: 'imageUrl is required' });
      return;
    }

    pruneTimetableImportJobs();
    const now = new Date().toISOString();
    const job: TimetableImportJob = {
      id: crypto.randomUUID(),
      userId,
      status: 'pending',
      createdAt: now,
      updatedAt: now,
      startedAt: null,
      finishedAt: null,
      result: null,
      error: null,
      abortController: null,
    };
    timetableImportJobs.set(job.id, job);
    logImportJobLifecycle('timetable', 'created', {
      jobId: job.id,
      userId,
      status: job.status,
      hasContext: Boolean(context),
      fileType,
    });

    void (async () => {
      const startedAt = new Date().toISOString();
      const controller = new AbortController();
      job.status = 'running';
      job.startedAt = startedAt;
      job.updatedAt = startedAt;
      job.abortController = controller;
      logImportJobLifecycle('timetable', 'running', {
        jobId: job.id,
        userId,
        status: job.status,
      });
      try {
        const imported = await runCozeTimetableWorker(req, imageUrl, fileType, context, controller.signal);
        if (controller.signal.aborted) {
          job.abortController = null;
          return;
        }
        const finishedAt = new Date().toISOString();
        job.status = 'succeeded';
        job.finishedAt = finishedAt;
        job.updatedAt = finishedAt;
        job.result = imported;
        job.abortController = null;
        logImportJobLifecycle('timetable', 'succeeded', {
          jobId: job.id,
          userId,
          status: job.status,
          hasResult: Boolean(job.result),
          durationMs: Date.now() - Date.parse(startedAt),
        });
      } catch (error) {
        if (controller.signal.aborted || (error instanceof Error && error.message === 'COZE_JOB_CANCELLED')) {
          job.abortController = null;
          return;
        }
        const finishedAt = new Date().toISOString();
        const message = error instanceof Error ? error.message : 'Unknown error';
        job.status = 'failed';
        job.finishedAt = finishedAt;
        job.updatedAt = finishedAt;
        job.abortController = null;
        job.error = message.includes('WORKFLOW_TIMEOUT')
          ? '时间表识别超时，请稍后重试或换一张更清晰的图'
          : message.startsWith('Coze workflow request failed')
            ? '时间表识别服务暂时不可用，请稍后重试'
            : '时间表识别失败，请稍后重试';
        logImportJobLifecycle('timetable', 'failed', {
          jobId: job.id,
          userId,
          status: job.status,
          errorMessage: message,
        });
        console.error('BFF web timetable import job error:', {
          jobId: job.id,
          userId,
          message,
          error,
        });
      }
    })();

    logImportJobLifecycle('timetable', 'created', {
      jobId: job.id,
      userId,
      requestDurationMs: Date.now() - requestStartedAt,
    });
    ok(res, {
      jobId: job.id,
      status: job.status,
      createdAt: job.createdAt,
      updatedAt: job.updatedAt,
    });
  } catch (error) {
    console.error('BFF web create timetable import job error:', {
      durationMs: Date.now() - requestStartedAt,
      error,
    });
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/events/timetable/import-image/jobs/:jobId', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    pruneTimetableImportJobs();
    const jobId = Array.isArray(req.params.jobId) ? req.params.jobId[0] : req.params.jobId;
    const job = timetableImportJobs.get(jobId);
    if (!job || job.userId !== userId) {
      logImportJobLifecycle('timetable', 'missing', {
        jobId,
        userId,
      });
      res.status(404).json({ error: 'Timetable import job not found' });
      return;
    }
    logImportJobLifecycle('timetable', 'polled', {
      jobId: job.id,
      userId,
      status: job.status,
      hasResult: Boolean(job.result),
      hasError: Boolean(job.error),
    });

    ok(res, {
      jobId: job.id,
      status: job.status,
      createdAt: job.createdAt,
      updatedAt: job.updatedAt,
      startedAt: job.startedAt,
      finishedAt: job.finishedAt,
      result: job.result,
      error: job.error,
    });
  } catch (error) {
    console.error('BFF web get timetable import job error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.delete('/events/timetable/import-image/jobs/:jobId', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    pruneTimetableImportJobs();
    const jobId = Array.isArray(req.params.jobId) ? req.params.jobId[0] : req.params.jobId;
    const job = timetableImportJobs.get(jobId);
    if (!job || job.userId !== userId) {
      res.status(404).json({ error: 'Timetable import job not found' });
      return;
    }

    cancelImportJob('timetable', job, userId);
    ok(res, {
      jobId: job.id,
      status: job.status,
      updatedAt: job.updatedAt,
      finishedAt: job.finishedAt,
      error: job.error,
    });
  } catch (error) {
    console.error('BFF web cancel timetable import job error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/events/lineup/import-image/jobs', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  const requestStartedAt = Date.now();
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const runtimeCozeConfig = getRuntimeCozeConfig();
    const cozeLineupWorkflowRunUrl = runtimeCozeConfig.lineup.runUrl;
    const cozeLineupWorkflowToken = runtimeCozeConfig.lineup.token;
    if (!cozeLineupWorkflowRunUrl || !cozeLineupWorkflowToken) {
      res.status(503).json({ error: 'COZE_LINEUP_WORKFLOW_RUN_URL or COZE_LINEUP_WORKFLOW_TOKEN is not configured' });
      return;
    }

    const body = req.body as Record<string, unknown>;
    const imageUrl = typeof body.imageUrl === 'string' ? body.imageUrl.trim() : '';
    const fileType = typeof body.fileType === 'string' ? body.fileType.trim() : 'image/jpeg';
    const context = sanitizeLineupRecognitionContext(body.context);

    if (!imageUrl) {
      res.status(400).json({ error: 'imageUrl is required' });
      return;
    }

    pruneTimetableImportJobs();
    const now = new Date().toISOString();
    const job: LineupImportJob = {
      id: crypto.randomUUID(),
      userId,
      status: 'pending',
      createdAt: now,
      updatedAt: now,
      startedAt: null,
      finishedAt: null,
      result: null,
      error: null,
      abortController: null,
    };
    lineupImportJobs.set(job.id, job);
    logImportJobLifecycle('lineup', 'created', {
      jobId: job.id,
      userId,
      status: job.status,
      knownDJNamesCount: context.known_dj_names?.length ?? 0,
      fileType,
    });

    void (async () => {
      const startedAt = new Date().toISOString();
      const controller = new AbortController();
      job.status = 'running';
      job.startedAt = startedAt;
      job.updatedAt = startedAt;
      job.abortController = controller;
      logImportJobLifecycle('lineup', 'running', {
        jobId: job.id,
        userId,
        status: job.status,
      });
      try {
        const imported = await runCozeLineupV2Worker(req, imageUrl, fileType, context, controller.signal);
        if (controller.signal.aborted) {
          job.abortController = null;
          return;
        }
        const finishedAt = new Date().toISOString();
        job.status = 'succeeded';
        job.finishedAt = finishedAt;
        job.updatedAt = finishedAt;
        job.result = imported;
        job.abortController = null;
        logImportJobLifecycle('lineup', 'succeeded', {
          jobId: job.id,
          userId,
          status: job.status,
          hasResult: Boolean(job.result),
          durationMs: Date.now() - Date.parse(startedAt),
        });
      } catch (error) {
        if (controller.signal.aborted || (error instanceof Error && error.message === 'COZE_JOB_CANCELLED')) {
          job.abortController = null;
          return;
        }
        const finishedAt = new Date().toISOString();
        const message = error instanceof Error ? error.message : 'Unknown error';
        job.status = 'failed';
        job.finishedAt = finishedAt;
        job.updatedAt = finishedAt;
        job.abortController = null;
        job.error = message.includes('WORKFLOW_TIMEOUT')
          ? '阵容识别超时，请稍后重试或换一张更清晰的图'
          : message.startsWith('Coze workflow request failed')
            ? '阵容识别服务暂时不可用，请稍后重试'
            : '阵容识别失败，请稍后重试';
        logImportJobLifecycle('lineup', 'failed', {
          jobId: job.id,
          userId,
          status: job.status,
          errorMessage: message,
        });
        console.error('BFF web lineup import job error:', {
          jobId: job.id,
          userId,
          message,
          error,
        });
      }
    })();

    logImportJobLifecycle('lineup', 'created', {
      jobId: job.id,
      userId,
      requestDurationMs: Date.now() - requestStartedAt,
    });
    ok(res, {
      jobId: job.id,
      status: job.status,
      createdAt: job.createdAt,
      updatedAt: job.updatedAt,
    });
  } catch (error) {
    console.error('BFF web create lineup import job error:', {
      durationMs: Date.now() - requestStartedAt,
      error,
    });
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/events/lineup/import-image/jobs/:jobId', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    pruneTimetableImportJobs();
    const jobId = Array.isArray(req.params.jobId) ? req.params.jobId[0] : req.params.jobId;
    const job = lineupImportJobs.get(jobId);
    if (!job || job.userId !== userId) {
      logImportJobLifecycle('lineup', 'missing', {
        jobId,
        userId,
      });
      res.status(404).json({ error: 'Lineup import job not found' });
      return;
    }
    logImportJobLifecycle('lineup', 'polled', {
      jobId: job.id,
      userId,
      status: job.status,
      hasResult: Boolean(job.result),
      hasError: Boolean(job.error),
    });

    ok(res, {
      jobId: job.id,
      status: job.status,
      createdAt: job.createdAt,
      updatedAt: job.updatedAt,
      startedAt: job.startedAt,
      finishedAt: job.finishedAt,
      result: job.result,
      error: job.error,
    });
  } catch (error) {
    console.error('BFF web get lineup import job error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.delete('/events/lineup/import-image/jobs/:jobId', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    pruneTimetableImportJobs();
    const jobId = Array.isArray(req.params.jobId) ? req.params.jobId[0] : req.params.jobId;
    const job = lineupImportJobs.get(jobId);
    if (!job || job.userId !== userId) {
      res.status(404).json({ error: 'Lineup import job not found' });
      return;
    }

    cancelImportJob('lineup', job, userId);
    ok(res, {
      jobId: job.id,
      status: job.status,
      updatedAt: job.updatedAt,
      finishedAt: job.finishedAt,
      error: job.error,
    });
  } catch (error) {
    console.error('BFF web cancel lineup import job error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/events/poster/import-image/jobs', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  const requestStartedAt = Date.now();
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const runtimeCozeConfig = getRuntimeCozeConfig();
    const cozePosterWorkflowRunUrl = runtimeCozeConfig.poster.runUrl;
    const cozePosterWorkflowToken = runtimeCozeConfig.poster.token;
    if (!cozePosterWorkflowRunUrl || !cozePosterWorkflowToken) {
      res.status(503).json({ error: 'COZE_POSTER_WORKFLOW_RUN_URL or COZE_POSTER_WORKFLOW_TOKEN is not configured' });
      return;
    }

    const body = req.body as Record<string, unknown>;
    const imageUrl = typeof body.imageUrl === 'string' ? body.imageUrl.trim() : '';
    const fileType = typeof body.fileType === 'string' ? body.fileType.trim() : 'image/jpeg';

    if (!imageUrl) {
      res.status(400).json({ error: 'imageUrl is required' });
      return;
    }

    pruneTimetableImportJobs();
    const now = new Date().toISOString();
    const job: PosterImportJob = {
      id: crypto.randomUUID(),
      userId,
      status: 'pending',
      createdAt: now,
      updatedAt: now,
      startedAt: null,
      finishedAt: null,
      result: null,
      error: null,
      abortController: null,
    };
    posterImportJobs.set(job.id, job);
    logImportJobLifecycle('poster', 'created', {
      jobId: job.id,
      userId,
      status: job.status,
      fileType,
    });

    void (async () => {
      const startedAt = new Date().toISOString();
      const controller = new AbortController();
      job.status = 'running';
      job.startedAt = startedAt;
      job.updatedAt = startedAt;
      job.abortController = controller;
      logImportJobLifecycle('poster', 'running', {
        jobId: job.id,
        userId,
        status: job.status,
      });
      try {
        const imported = await runCozePosterWorker(req, imageUrl, fileType, controller.signal);
        if (controller.signal.aborted) {
          job.abortController = null;
          return;
        }
        const finishedAt = new Date().toISOString();
        job.status = 'succeeded';
        job.finishedAt = finishedAt;
        job.updatedAt = finishedAt;
        job.result = imported;
        job.abortController = null;
        logImportJobLifecycle('poster', 'succeeded', {
          jobId: job.id,
          userId,
          status: job.status,
          hasResult: Boolean(job.result),
          durationMs: Date.now() - Date.parse(startedAt),
        });
      } catch (error) {
        if (controller.signal.aborted || (error instanceof Error && error.message === 'COZE_JOB_CANCELLED')) {
          job.abortController = null;
          return;
        }
        const finishedAt = new Date().toISOString();
        const message = error instanceof Error ? error.message : 'Unknown error';
        job.status = 'failed';
        job.finishedAt = finishedAt;
        job.updatedAt = finishedAt;
        job.abortController = null;
        job.error = message.includes('COZE_POSTER_WORKFLOW_TIMEOUT')
          ? '活动信息识别超时，请稍后重试或换一张更清晰的图'
          : message.startsWith('Coze workflow request failed')
            ? '活动信息识别服务暂时不可用，请稍后重试'
            : '活动信息识别失败，请稍后重试';
        logImportJobLifecycle('poster', 'failed', {
          jobId: job.id,
          userId,
          status: job.status,
          errorMessage: message,
        });
        console.error('BFF web poster import job error:', {
          jobId: job.id,
          userId,
          message,
          error,
        });
      }
    })();

    logImportJobLifecycle('poster', 'created', {
      jobId: job.id,
      userId,
      requestDurationMs: Date.now() - requestStartedAt,
    });
    ok(res, {
      jobId: job.id,
      status: job.status,
      createdAt: job.createdAt,
      updatedAt: job.updatedAt,
    });
  } catch (error) {
    console.error('BFF web create poster import job error:', {
      durationMs: Date.now() - requestStartedAt,
      error,
    });
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/events/poster/import-image/jobs/:jobId', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    pruneTimetableImportJobs();
    const jobId = Array.isArray(req.params.jobId) ? req.params.jobId[0] : req.params.jobId;
    const job = posterImportJobs.get(jobId);
    if (!job || job.userId !== userId) {
      logImportJobLifecycle('poster', 'missing', {
        jobId,
        userId,
      });
      res.status(404).json({ error: 'Poster import job not found' });
      return;
    }
    logImportJobLifecycle('poster', 'polled', {
      jobId: job.id,
      userId,
      status: job.status,
      hasResult: Boolean(job.result),
      hasError: Boolean(job.error),
    });

    ok(res, {
      jobId: job.id,
      status: job.status,
      createdAt: job.createdAt,
      updatedAt: job.updatedAt,
      startedAt: job.startedAt,
      finishedAt: job.finishedAt,
      result: job.result,
      error: job.error,
    });
  } catch (error) {
    console.error('BFF web get poster import job error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.delete('/events/poster/import-image/jobs/:jobId', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    pruneTimetableImportJobs();
    const jobId = Array.isArray(req.params.jobId) ? req.params.jobId[0] : req.params.jobId;
    const job = posterImportJobs.get(jobId);
    if (!job || job.userId !== userId) {
      res.status(404).json({ error: 'Poster import job not found' });
      return;
    }

    cancelImportJob('poster', job, userId);
    ok(res, {
      jobId: job.id,
      status: job.status,
      updatedAt: job.updatedAt,
      finishedAt: job.finishedAt,
      error: job.error,
    });
  } catch (error) {
    console.error('BFF web cancel poster import job error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/me/contribution-center/summary', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const summary = await fetchContributionCenterSummary(prisma, userId);
    ok(res, {
      totalContributionCount: summary.totalContributionCount,
      contributedEventCount: summary.contributedEventCount,
      contributedDJCount: summary.contributedDJCount,
      lastContributionAt: summary.lastContributionAt,
      recentItems: summary.recentItems.map(mapContributionHistoryItem),
    });
  } catch (error) {
    console.error('BFF contribution center summary error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/me/contributions', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const entityType = normalizeContributionHistoryFilter(req.query.entityType);
    const limit = normalizeLimit(req.query.limit, 20, 50);
    const cursor = typeof req.query.cursor === 'string' ? req.query.cursor.trim() || null : null;
    const page = await fetchContributionHistoryPage(prisma, userId, {
      entityType,
      limit,
      cursor,
    });

    ok(res, {
      items: page.items.map(mapContributionHistoryItem),
      filter: {
        entityType: page.entityType,
      },
      pageInfo: {
        limit: page.limit,
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
      },
    });
  } catch (error) {
    if (error instanceof InvalidContributionHistoryCursorError) {
      res.status(400).json({ error: error.message });
      return;
    }
    console.error('BFF contributions history error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/publishes/me', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const [djSets, events, ratingEvents, ratingUnits] = await Promise.all([
      prisma.dJSet.findMany({
        where: { uploadedById: userId },
        include: {
          dj: {
            select: {
              id: true,
              name: true,
              slug: true,
              avatarUrl: true,
              bannerUrl: true,
              country: true,
            },
          },
          tracks: {
            select: { id: true },
          },
        },
        orderBy: { createdAt: 'desc' },
      }),
      prisma.event.findMany({
        where: { organizerId: userId },
        select: {
          id: true,
          name: true,
          nameI18n: true,
          cityI18n: true,
          countryI18n: true,
          manualLocation: true,
          locationPoint: true,
          coverImageUrl: true,
          city: true,
          country: true,
          startDate: true,
          createdAt: true,
        },
        orderBy: { createdAt: 'desc' },
      }),
      prisma.ratingEvent.findMany({
        where: { createdById: userId },
        include: {
          units: {
            select: { id: true },
          },
        },
        orderBy: { createdAt: 'desc' },
      }),
      prisma.ratingUnit.findMany({
        where: { createdById: userId },
        include: {
          event: {
            select: { id: true, name: true },
          },
        },
        orderBy: { createdAt: 'desc' },
      }),
    ]);

    const eventLineupCounts = new Map<string, number>();
    const eventSnapshots = await Promise.all(events.map((event) => loadCanonicalEventLineupSnapshot(prisma, event.id)));
    eventSnapshots.forEach((snapshot, index) => {
      eventLineupCounts.set(events[index]!.id, snapshot.slots.length);
    });

    ok(res, {
      djSets: djSets.map((set) => ({
        id: set.id,
        title: set.title,
        thumbnailUrl: set.thumbnailUrl,
        createdAt: set.createdAt,
        trackCount: set.tracks.length,
        dj: set.dj,
      })),
      events: events.map((event) => ({
        ...mapEventReference(event, { includeCoverImageUrl: true, includeCreatedAt: true }),
        lineupSlotCount: eventLineupCounts.get(event.id) ?? 0,
      })),
      ratingEvents: ratingEvents.map((event) => ({
        id: event.id,
        name: event.name,
        imageUrl: event.imageUrl,
        description: event.description,
        unitCount: event.units.length,
        createdAt: event.createdAt,
      })),
      ratingUnits: ratingUnits.map((unit) => ({
        id: unit.id,
        eventId: unit.eventId,
        eventName: unit.event?.name || '未知事件',
        name: unit.name,
        imageUrl: unit.imageUrl,
        description: unit.description,
        createdAt: unit.createdAt,
      })),
    });
  } catch (error) {
    console.error('BFF web my publishes error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;
