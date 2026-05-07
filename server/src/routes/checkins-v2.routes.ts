import { Router, Request, Response, NextFunction } from 'express';
import { PrismaClient, Prisma } from '@prisma/client';
import { verifyToken, type JWTPayload } from '../utils/auth';
import {
  ReadModelMaybe,
  fetchCheckinGalleryArtistsPageReadModelStrict,
  fetchCheckinGalleryEventsPageReadModelStrict,
  fetchCheckinOverviewReadModelStrict,
  fetchCheckinStatsReadModelStrict,
  fetchCheckinTimelinePageReadModelStrict,
} from '../services/checkin-projection-read-model';
import { rebuildUserCheckinProjection } from '../services/checkin-projection';
import { getCheckinProjectionStatus } from '../services/checkin-projection-status';
import {
  createSnapshotData,
  hydrateStoredSelections,
  normalizeBiText,
  normalizeInt,
  normalizeNullableText,
  normalizeSelections,
} from '../services/checkin-domain';

const router: Router = Router();
const prisma = new PrismaClient();

interface BFFAuthRequest extends Request {
  user?: JWTPayload;
}

type BFFPagination = {
  page: number;
  limit: number;
  total: number;
  totalPages: number;
};

const optionalAuth = (req: Request, _res: Response, next: NextFunction): void => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    next();
    return;
  }

  const token = authHeader.substring(7);
  try {
    const decoded = verifyToken(token);
    (req as BFFAuthRequest).user = decoded;
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
  return userId;
};

const requireAdminOrOperator = (req: BFFAuthRequest, res: Response): boolean => {
  const userId = requireAuth(req, res);
  if (!userId) return false;
  const role = req.user?.role;
  if (role !== 'admin' && role !== 'operator') {
    res.status(403).json({ error: 'Forbidden' });
    return false;
  }
  return true;
};

const ok = <T>(res: Response, data: T, pagination?: BFFPagination): void => {
  if (pagination) {
    res.json({ data, pagination });
    return;
  }
  res.json({ data });
};

const projectionNotReady = (res: Response): void => {
  res.status(503).json({
    error: 'Projection not ready',
    code: 'CHECKIN_PROJECTION_NOT_READY',
  });
};

const handleReadModelUnavailable = (
  res: Response,
  result: { data: null; reason: 'user_not_found' | 'projection_not_ready' }
): void => {
  if (result.reason === 'user_not_found') {
    res.status(404).json({ error: 'User not found' });
    return;
  }
  projectionNotReady(res);
};

const isReadModelUnavailable = <T>(
  result: ReadModelMaybe<T>
): result is { data: null; stale: true; reason: 'user_not_found' | 'projection_not_ready' } =>
  result.data === null;

router.get('/admin/checkins/projection/status', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    if (!requireAdminOrOperator(authReq, res)) return;

    const status = await getCheckinProjectionStatus(prisma);
    ok(res, status);
  } catch (error) {
    console.error('BFF v2 checkins projection status error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

const normalizeText = (value: unknown): string => {
  if (typeof value !== 'string') return '';
  return value.trim();
};

const normalizeVisibility = (value: unknown): 'private' | 'visible' | null => {
  const normalized = normalizeText(value).toLowerCase();
  if (normalized === 'private' || normalized === 'visible') {
    return normalized;
  }
  return null;
};

const normalizeType = (value: unknown): 'event' | 'dj' | null => {
  const normalized = normalizeText(value).toLowerCase();
  if (normalized === 'event' || normalized === 'dj') {
    return normalized;
  }
  return null;
};

const normalizeDate = (value: unknown): Date | null => {
  if (typeof value !== 'string' || !value.trim()) return null;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  return date;
};

const normalizePositiveInt = (value: unknown, fallback: number): number => {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.max(1, Math.floor(parsed));
};

const mapCheckinResponse = (row: {
  id: string;
  userId: string;
  eventId: string | null;
  djId: string | null;
  type: string;
  note: string | null;
  photoUrl: string | null;
  rating: number | null;
  visibility: string;
  status: string;
  source: string;
  schemaVersion: number;
  projectionVersion: number;
  attendedAt: Date;
  createdAt: Date;
  updatedAt: Date;
  event?: {
    id: string;
    name: string;
    nameI18n: Prisma.JsonValue | null;
    cityI18n: Prisma.JsonValue | null;
    countryI18n: Prisma.JsonValue | null;
    manualLocation: Prisma.JsonValue | null;
    locationPoint: Prisma.JsonValue | null;
    coverImageUrl: string | null;
    city: string | null;
    country: string | null;
    startDate: Date;
    endDate: Date;
    venueAddress?: string | null;
  } | null;
  dj?: {
    id: string;
    name: string;
    nameI18n: Prisma.JsonValue | null;
    avatarUrl: string | null;
    country: string | null;
    countryI18n: Prisma.JsonValue | null;
  } | null;
  snapshot?: {
    selectionSummary: Prisma.JsonValue | null;
    snapshotVersion: number;
    visibilityResolved: string;
    generatedAt: Date;
  } | null;
}): Record<string, unknown> => ({
  id: row.id,
  userId: row.userId,
  eventId: row.eventId,
  djId: row.djId,
  type: row.type,
  note: row.note,
  photoUrl: row.photoUrl,
  rating: row.rating,
  visibility: row.visibility,
  status: row.status,
  source: row.source,
  schemaVersion: row.schemaVersion,
  projectionVersion: row.projectionVersion,
  attendedAt: row.attendedAt,
  createdAt: row.createdAt,
  updatedAt: row.updatedAt,
  event: row.event
    ? {
        ...row.event,
        nameI18n: normalizeBiText(row.event.nameI18n, row.event.name),
        cityI18n: normalizeBiText(row.event.cityI18n, row.event.city ?? ''),
        countryI18n: normalizeBiText(row.event.countryI18n, row.event.country ?? ''),
      }
    : null,
  dj: row.dj
    ? {
        ...row.dj,
        nameI18n: normalizeBiText(row.dj.nameI18n, row.dj.name),
        countryI18n: normalizeBiText(row.dj.countryI18n, row.dj.country ?? ''),
      }
    : null,
  snapshot: row.snapshot
    ? {
        selectionSummary: row.snapshot.selectionSummary,
        snapshotVersion: row.snapshot.snapshotVersion,
        visibilityResolved: row.snapshot.visibilityResolved,
        generatedAt: row.snapshot.generatedAt,
      }
    : null,
});

const enqueueOutboxEvent = async (
  tx: Prisma.TransactionClient,
  eventType: string,
  aggregateId: string,
  userId: string,
  payload: Prisma.InputJsonValue
): Promise<void> => {
  await tx.checkinOutboxEvent.create({
    data: {
      eventType,
      aggregateType: 'checkin',
      aggregateId,
      userId,
      payload,
      status: 'pending',
    },
  });
};

const refreshUserProjectionAfterWrite = async (
  userId: string,
  aggregateId: string
): Promise<void> => {
  const report = await rebuildUserCheckinProjection(prisma, userId);
  const [sourceCheckin, projectedTimelineEntry] = await Promise.all([
    prisma.checkin.findUnique({
      where: { id: aggregateId },
      select: {
        id: true,
        userId: true,
        eventId: true,
        djId: true,
        type: true,
        status: true,
        note: true,
        visibility: true,
        attendedAt: true,
        projectionVersion: true,
        _count: {
          select: {
            selections: true,
          },
        },
      },
    }),
    prisma.userCheckinTimelineEntry.findFirst({
      where: {
        userId,
        primaryCheckinId: aggregateId,
      },
      select: {
        id: true,
        primaryCheckinId: true,
        eventId: true,
        anchorAt: true,
        projectionVersion: true,
      },
    }),
  ]);

  console.log('[CheckinProjection] server write-after-refresh', {
    userId,
    aggregateId,
    report,
    sourceCheckin,
    projectedTimelineEntry,
  });

  if (sourceCheckin?.type === 'event' && sourceCheckin.status === 'active' && !projectedTimelineEntry) {
    console.error('[CheckinProjection] server projection missing timeline entry after write', {
      userId,
      aggregateId,
      report,
      sourceCheckin,
    });
  }

  await prisma.checkinOutboxEvent.updateMany({
    where: {
      userId,
      aggregateId,
      status: 'pending',
    },
    data: {
      status: 'processed',
      processedAt: new Date(),
    },
  });
};

router.get('/me/checkins/overview', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const projected = await fetchCheckinOverviewReadModelStrict(prisma, userId, userId);
    if (isReadModelUnavailable(projected)) {
      handleReadModelUnavailable(res, projected);
      return;
    }

    ok(res, projected.data);
  } catch (error) {
    console.error('BFF v2 my checkins overview error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/users/:id/checkins/overview', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const targetUserId = normalizeText(req.params.id);
    if (!targetUserId) {
      res.status(400).json({ error: 'User id is required' });
      return;
    }

    const projected = await fetchCheckinOverviewReadModelStrict(prisma, targetUserId, authReq.user?.userId ?? null);
    if (isReadModelUnavailable(projected)) {
      handleReadModelUnavailable(res, projected);
      return;
    }

    ok(res, projected.data);
  } catch (error) {
    console.error('BFF v2 public checkins overview error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/me/checkins/timeline', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const page = normalizePositiveInt(req.query.page, 1);
    const limit = normalizePositiveInt(req.query.limit, 20);
    const projected = await fetchCheckinTimelinePageReadModelStrict(prisma, userId, userId, page, limit);
    if (isReadModelUnavailable(projected)) {
      handleReadModelUnavailable(res, projected);
      return;
    }

    ok(res, projected.data, projected.pagination);
  } catch (error) {
    console.error('BFF v2 my checkins timeline error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/users/:id/checkins/timeline', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const targetUserId = normalizeText(req.params.id);
    if (!targetUserId) {
      res.status(400).json({ error: 'User id is required' });
      return;
    }

    const page = normalizePositiveInt(req.query.page, 1);
    const limit = normalizePositiveInt(req.query.limit, 20);
    const projected = await fetchCheckinTimelinePageReadModelStrict(
      prisma,
      targetUserId,
      authReq.user?.userId ?? null,
      page,
      limit
    );
    if (isReadModelUnavailable(projected)) {
      handleReadModelUnavailable(res, projected);
      return;
    }

    ok(res, projected.data, projected.pagination);
  } catch (error) {
    console.error('BFF v2 public checkins timeline error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/me/checkins/gallery/events', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const page = normalizePositiveInt(req.query.page, 1);
    const limit = normalizePositiveInt(req.query.limit, 20);
    const projected = await fetchCheckinGalleryEventsPageReadModelStrict(prisma, userId, userId, page, limit);
    if (isReadModelUnavailable(projected)) {
      handleReadModelUnavailable(res, projected);
      return;
    }

    ok(res, projected.data, projected.pagination);
  } catch (error) {
    console.error('BFF v2 my checkins gallery events error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/users/:id/checkins/gallery/events', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const targetUserId = normalizeText(req.params.id);
    if (!targetUserId) {
      res.status(400).json({ error: 'User id is required' });
      return;
    }

    const page = normalizePositiveInt(req.query.page, 1);
    const limit = normalizePositiveInt(req.query.limit, 20);
    const projected = await fetchCheckinGalleryEventsPageReadModelStrict(
      prisma,
      targetUserId,
      authReq.user?.userId ?? null,
      page,
      limit
    );
    if (isReadModelUnavailable(projected)) {
      handleReadModelUnavailable(res, projected);
      return;
    }

    ok(res, projected.data, projected.pagination);
  } catch (error) {
    console.error('BFF v2 public checkins gallery events error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/me/checkins/gallery/djs', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const page = normalizePositiveInt(req.query.page, 1);
    const limit = normalizePositiveInt(req.query.limit, 20);
    const projected = await fetchCheckinGalleryArtistsPageReadModelStrict(prisma, userId, userId, page, limit);
    if (isReadModelUnavailable(projected)) {
      handleReadModelUnavailable(res, projected);
      return;
    }

    ok(res, projected.data, projected.pagination);
  } catch (error) {
    console.error('BFF v2 my checkins gallery djs error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/users/:id/checkins/gallery/djs', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const targetUserId = normalizeText(req.params.id);
    if (!targetUserId) {
      res.status(400).json({ error: 'User id is required' });
      return;
    }

    const page = normalizePositiveInt(req.query.page, 1);
    const limit = normalizePositiveInt(req.query.limit, 20);
    const projected = await fetchCheckinGalleryArtistsPageReadModelStrict(
      prisma,
      targetUserId,
      authReq.user?.userId ?? null,
      page,
      limit
    );
    if (isReadModelUnavailable(projected)) {
      handleReadModelUnavailable(res, projected);
      return;
    }

    ok(res, projected.data, projected.pagination);
  } catch (error) {
    console.error('BFF v2 public checkins gallery djs error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/me/checkins/stats', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const projected = await fetchCheckinStatsReadModelStrict(prisma, userId, userId);
    if (isReadModelUnavailable(projected)) {
      handleReadModelUnavailable(res, projected);
      return;
    }

    ok(res, projected.data);
  } catch (error) {
    console.error('BFF v2 my checkins stats error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/users/:id/checkins/stats', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const targetUserId = normalizeText(req.params.id);
    if (!targetUserId) {
      res.status(400).json({ error: 'User id is required' });
      return;
    }

    const projected = await fetchCheckinStatsReadModelStrict(prisma, targetUserId, authReq.user?.userId ?? null);
    if (isReadModelUnavailable(projected)) {
      handleReadModelUnavailable(res, projected);
      return;
    }

    ok(res, projected.data);
  } catch (error) {
    console.error('BFF v2 public checkins stats error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/checkins', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const body = req.body as Record<string, unknown>;
    const type = normalizeType(body.type);
    if (!type) {
      res.status(400).json({ error: 'type must be event or dj' });
      return;
    }

    const eventId = normalizeNullableText(body.eventId);
    const djId = normalizeNullableText(body.djId);
    const visibility = normalizeVisibility(body.visibility) ?? 'private';
    const attendedAt = body.attendedAt == null ? new Date() : normalizeDate(body.attendedAt);
    const photoUrl = normalizeNullableText(body.photoUrl);
    const rating = body.rating == null ? null : normalizeInt(body.rating, -1);
    const { normalizedSelections, validationError } = normalizeSelections(body.selections);

    if (validationError) {
      res.status(400).json({ error: validationError });
      return;
    }
    if (!attendedAt) {
      res.status(400).json({ error: 'attendedAt must be a valid ISO datetime' });
      return;
    }
    if (rating != null && (rating < 1 || rating > 5)) {
      res.status(400).json({ error: 'rating must be between 1 and 5' });
      return;
    }
    if (type === 'event' && !eventId) {
      res.status(400).json({ error: 'eventId is required for event checkin' });
      return;
    }
    if (type === 'dj' && !djId) {
      res.status(400).json({ error: 'djId is required for dj checkin' });
      return;
    }

    const normalizedDJIDs = Array.from(
      new Set(normalizedSelections.flatMap((selection) => selection.djs.map((item) => item.djId).filter(Boolean)))
    ) as string[];

    const [user, event, dj, matchedDJs] = await Promise.all([
      prisma.user.findUnique({
        where: { id: userId },
        select: { id: true, displayName: true, username: true },
      }),
      eventId
        ? prisma.event.findUnique({
            where: { id: eventId },
            select: {
              id: true,
              name: true,
              nameI18n: true,
              coverImageUrl: true,
              city: true,
              country: true,
              venueAddress: true,
              manualLocation: true,
              startDate: true,
              endDate: true,
              status: true,
            },
          })
        : Promise.resolve(null),
      djId
        ? prisma.dJ.findUnique({
            where: { id: djId },
            select: {
              id: true,
              name: true,
              nameI18n: true,
              avatarUrl: true,
              country: true,
            },
          })
        : Promise.resolve(null),
      normalizedDJIDs.length > 0
        ? prisma.dJ.findMany({
            where: { id: { in: normalizedDJIDs } },
            select: {
              id: true,
              name: true,
              avatarUrl: true,
              country: true,
            },
          })
        : Promise.resolve([]),
    ]);

    if (!user) {
      res.status(404).json({ error: 'User not found' });
      return;
    }
    if (type === 'event' && !event) {
      res.status(404).json({ error: 'Event not found' });
      return;
    }
    if (type === 'dj' && !dj) {
      res.status(404).json({ error: 'DJ not found' });
      return;
    }
    if (normalizedDJIDs.length !== matchedDJs.length) {
      res.status(400).json({ error: 'Selections contain unknown DJs; manual artists are not supported' });
      return;
    }

    if (type === 'event' && eventId) {
      const existingAttendance = await prisma.checkin.findFirst({
        where: {
          userId,
          type: 'event',
          eventId,
          status: 'active',
        },
        select: { id: true },
      });

      if (existingAttendance) {
        res.status(409).json({ error: '该活动已打卡，请直接编辑原有记录' });
        return;
      }
    }

    const displayName = normalizeNullableText(user.displayName) ?? user.username;
    const created = await prisma.$transaction(async (tx) => {
      const checkin = await tx.checkin.create({
        data: {
          userId,
          eventId,
          djId: type === 'dj' ? djId : null,
          type,
          photoUrl,
          rating,
          visibility,
          status: 'active',
          source: 'ios',
          schemaVersion: 1,
          projectionVersion: 0,
          attendedAt,
        },
      });

      if (normalizedSelections.length > 0) {
        for (const selection of normalizedSelections) {
          const createdSelection = await tx.checkinSelection.create({
            data: {
              checkinId: checkin.id,
              dayId: selection.dayId,
              dayIndex: selection.dayIndex,
              sortOrder: selection.dayIndex,
            },
          });

          if (selection.djs.length > 0) {
            await tx.checkinSelectionDJ.createMany({
              data: selection.djs.map((item, index) => {
                const matchedDJ = matchedDJs.find((row) => row.id === item.djId);
                return {
                  selectionId: createdSelection.id,
                  djId: item.djId,
                  actGroupId: item.actGroupId,
                  rawName: item.rawName,
                  displayName: item.displayName,
                  avatarUrl: matchedDJ?.avatarUrl ?? null,
                  country: matchedDJ?.country ?? null,
                  actType: item.actType,
                  performerIndex: item.performerIndex,
                  sortOrder: index,
                };
              }),
            });
          }
        }
      }

      await tx.checkinSnapshot.create({
        data: {
          checkinId: checkin.id,
          ...createSnapshotData(displayName, visibility, normalizedSelections, event, dj),
        },
      });

      await enqueueOutboxEvent(tx, 'checkin.created', checkin.id, userId, {
        type,
        eventId,
        djId: type === 'dj' ? djId : null,
        visibility,
        attendedAt: attendedAt.toISOString(),
      });

      return tx.checkin.findUniqueOrThrow({
        where: { id: checkin.id },
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
              venueAddress: true,
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
          snapshot: {
            select: {
              selectionSummary: true,
              snapshotVersion: true,
              visibilityResolved: true,
              generatedAt: true,
            },
          },
        },
      });
    });

    await refreshUserProjectionAfterWrite(userId, created.id);

    ok(res, mapCheckinResponse(created));
  } catch (error) {
    console.error('BFF v2 create checkin error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.patch('/checkins/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const checkinId = normalizeText(req.params.id);
    const existing = await prisma.checkin.findUnique({
      where: { id: checkinId },
      include: {
        event: {
          select: {
            id: true,
            name: true,
            nameI18n: true,
            coverImageUrl: true,
            city: true,
            country: true,
            venueAddress: true,
            manualLocation: true,
            startDate: true,
            endDate: true,
            status: true,
          },
        },
        dj: {
          select: {
            id: true,
            name: true,
            nameI18n: true,
            avatarUrl: true,
            country: true,
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
                rawName: true,
                actType: true,
                performerIndex: true,
                actGroupId: true,
              },
            },
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
    if (existing.status !== 'active') {
      res.status(409).json({ error: 'Checkin is no longer active' });
      return;
    }

    const body = req.body as Record<string, unknown>;
    const visibility = normalizeVisibility(body.visibility) ?? (existing.visibility as 'private' | 'visible');
    const attendedAt = body.attendedAt == null ? existing.attendedAt : normalizeDate(body.attendedAt);
    const photoUrl =
      body.photoUrl === undefined ? existing.photoUrl : normalizeNullableText(body.photoUrl);
    const rating =
      body.rating === undefined || body.rating === null ? existing.rating : normalizeInt(body.rating, -1);
    const { normalizedSelections, validationError } = normalizeSelections(
      body.selections === undefined ? null : body.selections
    );

    if (validationError) {
      res.status(400).json({ error: validationError });
      return;
    }
    if (!attendedAt) {
      res.status(400).json({ error: 'attendedAt must be a valid ISO datetime' });
      return;
    }
    if (rating != null && (rating < 1 || rating > 5)) {
      res.status(400).json({ error: 'rating must be between 1 and 5' });
      return;
    }

    const normalizedDJIDs = Array.from(
      new Set(normalizedSelections.flatMap((selection) => selection.djs.map((item) => item.djId).filter(Boolean)))
    ) as string[];

    const [user, matchedDJs] = await Promise.all([
      prisma.user.findUnique({
        where: { id: existing.userId },
        select: { id: true, displayName: true, username: true },
      }),
      normalizedDJIDs.length > 0
        ? prisma.dJ.findMany({
            where: { id: { in: normalizedDJIDs } },
            select: {
              id: true,
              name: true,
              avatarUrl: true,
              country: true,
            },
          })
        : Promise.resolve([]),
    ]);

    if (!user) {
      res.status(404).json({ error: 'User not found' });
      return;
    }
    if (normalizedDJIDs.length !== matchedDJs.length) {
      res.status(400).json({ error: 'Selections contain unknown DJs; manual artists are not supported' });
      return;
    }

    const displayName = normalizeNullableText(user.displayName) ?? user.username;
    const snapshotSelections =
      body.selections !== undefined
        ? normalizedSelections
        : hydrateStoredSelections(existing.selections);
    const updated = await prisma.$transaction(async (tx) => {
      const checkin = await tx.checkin.update({
        where: { id: checkinId },
        data: {
          rating,
          photoUrl,
          visibility,
          attendedAt,
          projectionVersion: 0,
        },
      });

      if (body.selections !== undefined) {
        await tx.checkinSelectionDJ.deleteMany({
          where: {
            selection: {
              checkinId: checkin.id,
            },
          },
        });
        await tx.checkinSelection.deleteMany({
          where: { checkinId: checkin.id },
        });

        for (const selection of normalizedSelections) {
          const createdSelection = await tx.checkinSelection.create({
            data: {
              checkinId: checkin.id,
              dayId: selection.dayId,
              dayIndex: selection.dayIndex,
              sortOrder: selection.dayIndex,
            },
          });

          if (selection.djs.length > 0) {
            await tx.checkinSelectionDJ.createMany({
              data: selection.djs.map((item, index) => {
                const matchedDJ = matchedDJs.find((row) => row.id === item.djId);
                return {
                  selectionId: createdSelection.id,
                  djId: item.djId,
                  actGroupId: item.actGroupId,
                  rawName: item.rawName,
                  displayName: item.displayName,
                  avatarUrl: matchedDJ?.avatarUrl ?? null,
                  country: matchedDJ?.country ?? null,
                  actType: item.actType,
                  performerIndex: item.performerIndex,
                  sortOrder: index,
                };
              }),
            });
          }
        }
      }

      await tx.checkinSnapshot.upsert({
        where: { checkinId: checkin.id },
        create: {
          ...createSnapshotData(displayName, visibility, snapshotSelections, existing.event, existing.dj),
          checkinId: checkin.id,
        },
        update: {
          ...createSnapshotData(displayName, visibility, snapshotSelections, existing.event, existing.dj),
          generatedAt: new Date(),
        },
      });

      await enqueueOutboxEvent(tx, 'checkin.updated', checkin.id, existing.userId, {
        visibility,
        attendedAt: attendedAt.toISOString(),
        hasSelectionUpdate: body.selections !== undefined,
      });

      return tx.checkin.findUniqueOrThrow({
        where: { id: checkin.id },
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
              venueAddress: true,
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
          snapshot: {
            select: {
              selectionSummary: true,
              snapshotVersion: true,
              visibilityResolved: true,
              generatedAt: true,
            },
          },
        },
      });
    });

    await refreshUserProjectionAfterWrite(existing.userId, updated.id);

    ok(res, mapCheckinResponse(updated));
  } catch (error) {
    console.error('BFF v2 update checkin error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.delete('/checkins/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const checkinId = normalizeText(req.params.id);
    const existing = await prisma.checkin.findUnique({
      where: { id: checkinId },
      select: {
        id: true,
        userId: true,
        status: true,
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

    await prisma.$transaction(async (tx) => {
      await tx.checkin.update({
        where: { id: checkinId },
        data: {
          status: 'deleted',
          projectionVersion: 0,
        },
      });

      await enqueueOutboxEvent(tx, 'checkin.deleted', checkinId, existing.userId, {
        previousStatus: existing.status,
      });
    });

    await refreshUserProjectionAfterWrite(existing.userId, checkinId);

    ok(res, { success: true });
  } catch (error) {
    console.error('BFF v2 delete checkin error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;
