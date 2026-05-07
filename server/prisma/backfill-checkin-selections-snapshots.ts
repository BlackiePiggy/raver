import { PrismaClient, Prisma } from '@prisma/client';
import {
  createSnapshotData,
  type NormalizedSelection,
  type SnapshotDJLite,
  type SnapshotEventLite,
} from '../src/services/checkin-domain';

const prisma = new PrismaClient();

const EVENT_ATTENDANCE_NOTE_PREFIX = 'event_checkin_v1:';

type LegacySelectionDJ = {
  id: string;
  name: string;
  avatarUrl?: string | null;
  country?: string | null;
};

type LegacySelectionDay = {
  dayID: string;
  dayIndex: number;
  djSelections: LegacySelectionDJ[];
};

type ResolvedActType = 'solo' | 'b2b' | 'b3b';

type ResolvedAct = {
  actType: ResolvedActType;
  displayName: string;
  performerNames: string[];
  performerDjIds: Array<string | null>;
};

type BackfillMode = 'dry-run' | 'apply';

type BackfillDecision = 'restored_from_lineup' | 'degraded_without_lineup' | 'no_payload';

type BackfillCheckinRow = {
  id: string;
  userId: string;
  eventId: string | null;
  djId: string | null;
  type: string;
  note: string | null;
  visibility: string;
  status: string;
  attendedAt: Date;
  createdAt: Date;
  event: SnapshotEventLite;
  dj: SnapshotDJLite;
  user: {
    displayName: string | null;
    username: string;
  };
  selections: Array<{
    id: string;
  }>;
  snapshot: {
    checkinId: string;
  } | null;
};

type EventLineupSlotLite = {
  id: string;
  djId: string | null;
  djIds: string[];
  festivalDayIndex: number | null;
  djName: string;
  startTime: Date;
  dj: {
    id: string;
    name: string;
    avatarUrl: string | null;
  } | null;
};

type EventLineupContext = {
  dayRolloverHour: number;
  startDate: Date;
  lineupSlots: EventLineupSlotLite[];
};

type BatchSummary = {
  scanned: number;
  candidates: number;
  rebuilt: number;
  restoredFromLineup: number;
  degradedWithoutLineup: number;
  skippedNoPayload: number;
  failed: number;
};

const mode: BackfillMode = process.argv.includes('--apply') ? 'apply' : 'dry-run';
const userIdFilter = readArgValue('--user-id');
const checkinIdFilter = readArgValue('--checkin-id');
const limit = Math.max(0, parseInt(readArgValue('--limit') || '0', 10) || 0);
const batchSize = Math.max(20, parseInt(readArgValue('--batch-size') || '100', 10) || 100);
const includeExisting = process.argv.includes('--include-existing');

function readArgValue(flag: string): string | null {
  const index = process.argv.indexOf(flag);
  if (index < 0) return null;
  const value = process.argv[index + 1];
  return value ? String(value).trim() : null;
}

function normalizeText(value: unknown): string {
  if (typeof value !== 'string') return '';
  return value.trim();
}

function normalizeDayRolloverHour(raw: number | null | undefined): number {
  if (typeof raw === 'number' && Number.isInteger(raw) && raw >= 0 && raw <= 23) {
    return raw;
  }
  return 6;
}

function normalizeDjId(raw: unknown): string | null {
  const value = normalizeText(raw);
  return value || null;
}

function normalizeNameKey(raw: string): string {
  return raw
    .trim()
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .normalize('NFKC');
}

function splitActName(raw: string, keyword: 'B2B' | 'B3B'): string[] | null {
  if (!raw.trim()) return null;
  const token = '__CHECKIN_BACKFILL_SPLIT__';
  const pattern = new RegExp(`\\s*${keyword}\\s*`, 'ig');
  const replaced = raw.replace(pattern, token);
  const parts = replaced
    .split(token)
    .map((item) => item.trim())
    .filter(Boolean);
  return parts.length > 1 ? parts : null;
}

function parseResolvedAct(slot: EventLineupSlotLite): ResolvedAct {
  const preferredName = normalizeText(slot.djName);
  const fallbackName = normalizeText(slot.dj?.name);
  const rawName = preferredName || fallbackName;

  const b3bParts = splitActName(rawName, 'B3B');
  if (b3bParts && b3bParts.length >= 3) {
    return {
      actType: 'b3b',
      displayName: rawName,
      performerNames: b3bParts.slice(0, 3),
      performerDjIds: buildPerformerDjIds(slot, 3),
    };
  }

  const b2bParts = splitActName(rawName, 'B2B');
  if (b2bParts && b2bParts.length >= 2) {
    return {
      actType: 'b2b',
      displayName: rawName,
      performerNames: b2bParts.slice(0, 2),
      performerDjIds: buildPerformerDjIds(slot, 2),
    };
  }

  return {
    actType: 'solo',
    displayName: rawName,
    performerNames: [rawName],
    performerDjIds: [normalizeDjId(slot.dj?.id ?? slot.djId)],
  };
}

function buildPerformerDjIds(slot: EventLineupSlotLite, performerCount: number): Array<string | null> {
  const ids = slot.djIds.map((id) => normalizeDjId(id)).filter((id): id is string => Boolean(id));
  const primary = normalizeDjId(slot.dj?.id ?? slot.djId);
  const merged = primary ? [primary, ...ids.filter((id) => id !== primary)] : ids;
  const out: Array<string | null> = [];
  for (let index = 0; index < performerCount; index += 1) {
    out.push(merged[index] ?? null);
  }
  return out;
}

function parseLegacySelections(note: string | null): LegacySelectionDay[] {
  const trimmed = normalizeText(note);
  if (!trimmed.startsWith(EVENT_ATTENDANCE_NOTE_PREFIX)) {
    return [];
  }

  const rawPayload = trimmed.slice(EVENT_ATTENDANCE_NOTE_PREFIX.length);
  if (!rawPayload) return [];

  try {
    const parsed = JSON.parse(rawPayload) as unknown;
    if (Array.isArray(parsed)) {
      return parsed.flatMap(normalizeLegacyDay).filter((item): item is LegacySelectionDay => item !== null);
    }
    const single = normalizeLegacyDay(parsed);
    return single ? [single] : [];
  } catch {
    return [];
  }
}

function normalizeLegacyDay(value: unknown): LegacySelectionDay | null {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  const row = value as Record<string, unknown>;
  const dayID = normalizeText(row.dayID ?? row.dayId);
  const dayIndex = Number(row.dayIndex);
  const sourceSelections = Array.isArray(row.djSelections) ? row.djSelections : [];
  if (!dayID || !Number.isFinite(dayIndex)) return null;

  const djSelections = sourceSelections
    .map(normalizeLegacySelectionDJ)
    .filter((item): item is LegacySelectionDJ => item !== null);

  return {
    dayID,
    dayIndex: Math.max(1, Math.floor(dayIndex)),
    djSelections,
  };
}

function normalizeLegacySelectionDJ(value: unknown): LegacySelectionDJ | null {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  const row = value as Record<string, unknown>;
  const id = normalizeText(row.id);
  const name = normalizeText(row.name);
  if (!id || !name) return null;
  return {
    id,
    name,
    avatarUrl: normalizeText(row.avatarUrl) || null,
    country: normalizeText(row.country) || null,
  };
}

function resolveFestivalDayIndex(slot: EventLineupSlotLite, context: EventLineupContext): number {
  if (typeof slot.festivalDayIndex === 'number' && slot.festivalDayIndex > 0) {
    return slot.festivalDayIndex;
  }

  const rolloverHour = normalizeDayRolloverHour(context.dayRolloverHour);
  const startDay = new Date(context.startDate);
  startDay.setHours(0, 0, 0, 0);

  const slotDay = new Date(slot.startTime);
  const adjustedSlotDay = new Date(slot.startTime);
  if (adjustedSlotDay.getHours() < rolloverHour) {
    adjustedSlotDay.setDate(adjustedSlotDay.getDate() - 1);
  }
  slotDay.setHours(0, 0, 0, 0);
  adjustedSlotDay.setHours(0, 0, 0, 0);

  const diffMs = adjustedSlotDay.getTime() - startDay.getTime();
  const diffDays = Math.floor(diffMs / 86_400_000);
  return Math.max(1, diffDays + 1);
}

function buildLineupLookup(context: EventLineupContext): Map<string, ResolvedAct> {
  const lookup = new Map<string, ResolvedAct>();

  for (const slot of [...context.lineupSlots].sort((a, b) => a.startTime.getTime() - b.startTime.getTime())) {
    const act = parseResolvedAct(slot);
    const dayIndex = resolveFestivalDayIndex(slot, context);
    const actKey = normalizeNameKey(act.displayName);
    const names = new Set<string>([actKey]);
    for (const performerName of act.performerNames) {
      const key = normalizeNameKey(performerName);
      if (key) names.add(key);
    }

    for (const key of names) {
      const scopedKey = `${dayIndex}:${key}`;
      if (!lookup.has(scopedKey)) {
        lookup.set(scopedKey, act);
      }
    }
  }

  return lookup;
}

function buildNormalizedSelections(
  legacySelections: LegacySelectionDay[],
  eventContext: EventLineupContext | null
): { selections: NormalizedSelection[]; decision: BackfillDecision } {
  if (legacySelections.length === 0) {
    return { selections: [], decision: 'no_payload' };
  }

  const lineupLookup = eventContext ? buildLineupLookup(eventContext) : null;
  const decision: BackfillDecision = lineupLookup ? 'restored_from_lineup' : 'degraded_without_lineup';

  const selections: NormalizedSelection[] = legacySelections.map((day) => {
    const normalizedDJs: NormalizedSelection['djs'] = [];
    const usedKeys = new Set<string>();

    for (let djIndex = 0; djIndex < day.djSelections.length; djIndex += 1) {
      const legacyDJ = day.djSelections[djIndex];
      const lookupKey = `${day.dayIndex}:${normalizeNameKey(legacyDJ.name)}`;
      const resolvedAct = lineupLookup?.get(lookupKey) ?? null;

      if (resolvedAct) {
        const actGroupId = `${day.dayID}:act:${normalizeNameKey(resolvedAct.displayName)}`;
        if (usedKeys.has(actGroupId)) {
          continue;
        }
        usedKeys.add(actGroupId);

        for (let performerIndex = 0; performerIndex < resolvedAct.performerNames.length; performerIndex += 1) {
          normalizedDJs.push({
            djId: resolvedAct.performerDjIds[performerIndex] ?? (performerIndex === 0 ? legacyDJ.id : null),
            displayName: resolvedAct.performerNames[performerIndex] ?? legacyDJ.name,
            rawName: resolvedAct.performerNames[performerIndex] ?? legacyDJ.name,
            actType: resolvedAct.actType,
            performerIndex,
            actGroupId,
          });
        }
        continue;
      }

      normalizedDJs.push({
        djId: legacyDJ.id,
        displayName: legacyDJ.name,
        rawName: legacyDJ.name,
        actType: 'solo',
        performerIndex: 0,
        actGroupId: `${day.dayID}:solo:${normalizeNameKey(legacyDJ.name)}:${djIndex + 1}`,
      });
    }

    return {
      dayId: day.dayID,
      dayIndex: day.dayIndex,
      djs: normalizedDJs,
    };
  });

  return { selections, decision };
}

async function buildEventContextMap(eventIds: string[]): Promise<Map<string, EventLineupContext>> {
  if (eventIds.length === 0) return new Map();

  const events = await prisma.event.findMany({
    where: { id: { in: eventIds } },
    select: {
      id: true,
      startDate: true,
      dayRolloverHour: true,
      lineupSlots: {
        select: {
          id: true,
          djId: true,
          djIds: true,
          festivalDayIndex: true,
          djName: true,
          startTime: true,
          dj: {
            select: {
              id: true,
              name: true,
              avatarUrl: true,
            },
          },
        },
      },
    },
  });

  return new Map(
    events.map((event) => [
      event.id,
      {
        dayRolloverHour: event.dayRolloverHour,
        startDate: event.startDate,
        lineupSlots: event.lineupSlots,
      },
    ])
  );
}

async function fetchBatch(cursorId?: string): Promise<BackfillCheckinRow[]> {
  const where: Prisma.CheckinWhereInput = {
    type: 'event',
    status: 'active',
    eventId: { not: null },
    note: { startsWith: EVENT_ATTENDANCE_NOTE_PREFIX },
    ...(userIdFilter ? { userId: userIdFilter } : {}),
    ...(checkinIdFilter ? { id: checkinIdFilter } : {}),
    ...(includeExisting ? {} : { selections: { none: {} } }),
  };

  return prisma.checkin.findMany({
    where,
    orderBy: { id: 'asc' },
    take: batchSize,
    ...(cursorId ? { skip: 1, cursor: { id: cursorId } } : {}),
    select: {
      id: true,
      userId: true,
      eventId: true,
      djId: true,
      type: true,
      note: true,
      visibility: true,
      status: true,
      attendedAt: true,
      createdAt: true,
      event: {
        select: {
          name: true,
          nameI18n: true,
          coverImageUrl: true,
          city: true,
          country: true,
          venueAddress: true,
          manualLocation: true,
          startDate: true,
          endDate: true,
        },
      },
      dj: {
        select: {
          name: true,
          nameI18n: true,
          avatarUrl: true,
          country: true,
        },
      },
      user: {
        select: {
          displayName: true,
          username: true,
        },
      },
      selections: {
        select: { id: true },
      },
      snapshot: {
        select: { checkinId: true },
      },
    },
  });
}

async function persistBackfill(
  row: BackfillCheckinRow,
  selections: NormalizedSelection[]
): Promise<void> {
  const displayName = normalizeText(row.user.displayName) || row.user.username;
  const visibility = row.visibility === 'visible' ? 'visible' : 'private';
  const snapshotData = createSnapshotData(displayName, visibility, selections, row.event, row.dj);

  await prisma.$transaction(async (tx) => {
    await tx.checkinSelectionDJ.deleteMany({
      where: {
        selection: {
          checkinId: row.id,
        },
      },
    });
    await tx.checkinSelection.deleteMany({
      where: { checkinId: row.id },
    });

    for (const selection of selections) {
      const createdSelection = await tx.checkinSelection.create({
        data: {
          checkinId: row.id,
          dayId: selection.dayId,
          dayIndex: selection.dayIndex,
          sortOrder: selection.dayIndex,
        },
      });

      if (selection.djs.length > 0) {
        await tx.checkinSelectionDJ.createMany({
          data: selection.djs.map((dj, index) => ({
            selectionId: createdSelection.id,
            djId: dj.djId,
            actGroupId: dj.actGroupId,
            rawName: dj.rawName,
            displayName: dj.displayName,
            avatarUrl: null,
            country: null,
            actType: dj.actType,
            performerIndex: dj.performerIndex,
            sortOrder: index,
          })),
        });
      }
    }

    await tx.checkinSnapshot.upsert({
      where: { checkinId: row.id },
      create: {
        ...snapshotData,
        checkinId: row.id,
      },
      update: {
        ...snapshotData,
        generatedAt: new Date(),
      },
    });

    await tx.checkin.update({
      where: { id: row.id },
      data: {
        schemaVersion: 1,
        projectionVersion: 0,
      },
    });

    await tx.checkinOutboxEvent.create({
      data: {
        eventType: 'checkin.snapshot.regenerated',
        aggregateType: 'checkin',
        aggregateId: row.id,
        userId: row.userId,
        payload: {
          reason: 'legacy_note_backfill',
          selectionCount: selections.length,
        } as Prisma.InputJsonValue,
        status: 'pending',
      },
    });
  });
}

async function main() {
  console.log(
    `[checkin-backfill] mode=${mode} batchSize=${batchSize} limit=${limit || 'ALL'} userId=${userIdFilter || 'ALL'} checkinId=${checkinIdFilter || 'ALL'} includeExisting=${includeExisting}`
  );

  const summary: BatchSummary = {
    scanned: 0,
    candidates: 0,
    rebuilt: 0,
    restoredFromLineup: 0,
    degradedWithoutLineup: 0,
    skippedNoPayload: 0,
    failed: 0,
  };

  let cursorId: string | undefined;

  while (true) {
    const batch = await fetchBatch(cursorId);
    if (batch.length === 0) break;
    cursorId = batch[batch.length - 1]?.id;

    const eventIds = Array.from(new Set(batch.map((row) => row.eventId).filter((id): id is string => Boolean(id))));
    const eventContextMap = await buildEventContextMap(eventIds);

    for (const row of batch) {
      if (limit > 0 && summary.scanned >= limit) break;

      summary.scanned += 1;
      const legacySelections = parseLegacySelections(row.note);
      if (legacySelections.length === 0) {
        summary.skippedNoPayload += 1;
        continue;
      }

      summary.candidates += 1;
      const eventContext = row.eventId ? eventContextMap.get(row.eventId) ?? null : null;
      const result = buildNormalizedSelections(legacySelections, eventContext);

      if (result.decision === 'restored_from_lineup') {
        summary.restoredFromLineup += 1;
      } else if (result.decision === 'degraded_without_lineup') {
        summary.degradedWithoutLineup += 1;
      } else {
        summary.skippedNoPayload += 1;
        continue;
      }

      if (mode === 'dry-run') {
        if (summary.rebuilt < 8) {
          console.log(
            `[DRY-RUN] checkin=${row.id} event=${row.eventId} selections=${result.selections.length} decision=${result.decision}`
          );
        }
        summary.rebuilt += 1;
        continue;
      }

      try {
        await persistBackfill(row, result.selections);
        summary.rebuilt += 1;
      } catch (error) {
        summary.failed += 1;
        console.error(`[checkin-backfill] failed checkin=${row.id}`, error);
      }
    }

    if (limit > 0 && summary.scanned >= limit) break;
  }

  console.log('[checkin-backfill] summary', summary);
  if (mode === 'dry-run') {
    console.log('Dry-run only. Re-run with --apply to persist changes.');
  }
}

main()
  .catch((error) => {
    if (
      error instanceof Prisma.PrismaClientKnownRequestError &&
      error.code === 'P2022' &&
      String(error.meta?.column || '').includes('checkins.visibility')
    ) {
      console.error(
        '[checkin-backfill] database schema is behind code. Apply MyCheckins v2 migration before running this script.'
      );
    }
    console.error('[checkin-backfill] fatal', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
