import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import {
  normalizeEventTimeZone,
  parseEventDateInput,
} from '../utils/event-timezone';

const prisma = new PrismaClient();

const dryRun = process.env.EVENT_SCHEDULE_FOUNDATION_BACKFILL_APPLY !== '1';
const targetEventId = process.env.EVENT_SCHEDULE_FOUNDATION_EVENT_ID?.trim() || null;
const forceEventId = process.env.EVENT_SCHEDULE_FOUNDATION_FORCE_EVENT_ID?.trim() || null;
const startAfterEventId = process.env.EVENT_SCHEDULE_FOUNDATION_START_AFTER_EVENT_ID?.trim() || null;
const repairSyntheticOnly = process.env.EVENT_SCHEDULE_FOUNDATION_REPAIR_SYNTHETIC_ONLY === '1';
const transactionTimeoutMs = Number(process.env.EVENT_SCHEDULE_FOUNDATION_TX_TIMEOUT_MS || 60_000);

type FoundationCandidateRow = {
  id: string;
  name: string;
  startDate: Date;
  endDate: Date;
  scheduleMode: string | null;
  timeZone: string;
  weekCount: bigint | number;
  eventDayCount: bigint | number;
  performanceCount: bigint | number;
  maxLegacyDayIndex: number | null;
  syntheticWeekCount: bigint | number;
  syntheticDayCount: bigint | number;
};

type EventDaySeed = {
  eventDayId: string;
  weekIndex: number;
  dayIndexInWeek: number;
  overallDayIndex: number;
  date: Date;
  weekday: string;
};

const dayMs = 86_400_000;

const logStep = (step: string, detail?: Record<string, unknown>): void => {
  console.log('[backfill-event-schedule-foundation]', step, detail || {});
};

const normalizeCount = (value: bigint | number | null | undefined): number =>
  typeof value === 'bigint' ? Number(value) : Number(value || 0);

type LocalDateParts = {
  year: number;
  month: number;
  day: number;
};

const pad2 = (value: number): string => String(value).padStart(2, '0');

const localDatePartsToKey = (parts: LocalDateParts): string =>
  `${parts.year}-${pad2(parts.month)}-${pad2(parts.day)}`;

const getLocalDateParts = (value: Date, timeZoneRaw: unknown): LocalDateParts => {
  const timeZone = normalizeEventTimeZone(timeZoneRaw);
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(value);
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return {
    year: Number(values.year),
    month: Number(values.month),
    day: Number(values.day),
  };
};

const localDatePartsToEpoch = (parts: LocalDateParts): number =>
  Date.UTC(parts.year, parts.month - 1, parts.day);

const buildEventDayDate = (parts: LocalDateParts, timeZoneRaw: unknown): Date => {
  const parsed = parseEventDateInput(localDatePartsToKey(parts), timeZoneRaw, 'start');
  if (!parsed) {
    throw new Error(`Unable to resolve event local date ${localDatePartsToKey(parts)}`);
  }
  return parsed;
};

const addLocalDays = (parts: LocalDateParts, days: number, timeZoneRaw: unknown): Date => {
  const shifted = new Date(Date.UTC(parts.year, parts.month - 1, parts.day + days));
  return buildEventDayDate({
    year: shifted.getUTCFullYear(),
    month: shifted.getUTCMonth() + 1,
    day: shifted.getUTCDate(),
  }, timeZoneRaw);
};

const inclusiveSpanDays = (start: LocalDateParts, end: LocalDateParts): number =>
  Math.round((localDatePartsToEpoch(end) - localDatePartsToEpoch(start)) / dayMs) + 1;

const lowerWeekday = (value: Date, timeZoneRaw: unknown): string =>
  value.toLocaleDateString('en-US', {
    weekday: 'long',
    timeZone: normalizeEventTimeZone(timeZoneRaw),
  }).toLowerCase();

const needsFoundationRebuild = (event: FoundationCandidateRow): boolean =>
  repairSyntheticOnly
    ? normalizeCount(event.syntheticWeekCount) > 0 && normalizeCount(event.syntheticDayCount) > 0
    : (
  normalizeCount(event.weekCount) === 0
  || normalizeCount(event.eventDayCount) === 0
  || (
    normalizeCount(event.performanceCount) > 0
    && normalizeCount(event.eventDayCount) < normalizeCount(event.maxLegacyDayIndex)
  ));

const inferScheduleMode = (
  event: FoundationCandidateRow,
  foundationDayCount?: number
): 'single_day' | 'multi_day' | 'multi_week' => {
  const weekCount = normalizeCount(event.weekCount);
  const eventDayCount = normalizeCount(event.eventDayCount);
  if (weekCount > 1) {
    return 'multi_week';
  }
  if ((foundationDayCount ?? eventDayCount) > 1) {
    return 'multi_day';
  }
  return 'single_day';
};

async function listCandidates(): Promise<FoundationCandidateRow[]> {
  return prisma.$queryRaw<FoundationCandidateRow[]>`
    WITH week_stats AS (
      SELECT
        ew."event_id",
        COUNT(*) AS week_count
      FROM "event_weeks" ew
      GROUP BY ew."event_id"
    ),
    day_stats AS (
      SELECT
        ed."event_id",
        COUNT(*) AS event_day_count
      FROM "event_days" ed
      GROUP BY ed."event_id"
    ),
    performance_stats AS (
      SELECT
        ep."event_id",
        COUNT(*) AS performance_count,
        MAX(GREATEST(COALESCE(ep."festival_day_index", 1), 1)) AS max_legacy_day_index
      FROM "event_performances" ep
      GROUP BY ep."event_id"
    ),
    synthetic_week_stats AS (
      SELECT
        ew."event_id",
        COUNT(*) AS synthetic_week_count
      FROM "event_weeks" ew
      WHERE ew."week_index" = 1
        AND ew."sort_order" = 1
      GROUP BY ew."event_id"
    ),
    synthetic_day_stats AS (
      SELECT
        ed."event_id",
        COUNT(*) AS synthetic_day_count
      FROM "event_days" ed
      WHERE ed."event_day_id" ~ '^w1d[0-9]+$'
        AND ed."week_index" = 1
        AND ed."day_index_in_week" = ed."overall_day_index"
        AND ed."sort_order" = ed."overall_day_index"
      GROUP BY ed."event_id"
    )
    SELECT
      e."id",
      e."name",
      e."start_date" AS "startDate",
      e."end_date" AS "endDate",
      e."schedule_mode" AS "scheduleMode",
      e."time_zone" AS "timeZone",
      COALESCE(ws.week_count, 0) AS "weekCount",
      COALESCE(ds.event_day_count, 0) AS "eventDayCount",
      COALESCE(ps.performance_count, 0) AS "performanceCount",
      ps.max_legacy_day_index AS "maxLegacyDayIndex",
      COALESCE(sws.synthetic_week_count, 0) AS "syntheticWeekCount",
      COALESCE(sds.synthetic_day_count, 0) AS "syntheticDayCount"
    FROM "events" e
    LEFT JOIN week_stats ws
      ON ws."event_id" = e."id"
    LEFT JOIN day_stats ds
      ON ds."event_id" = e."id"
    LEFT JOIN performance_stats ps
      ON ps."event_id" = e."id"
    LEFT JOIN synthetic_week_stats sws
      ON sws."event_id" = e."id"
    LEFT JOIN synthetic_day_stats sds
      ON sds."event_id" = e."id"
    WHERE (${targetEventId}::text IS NULL OR e."id" = ${targetEventId})
      AND (${startAfterEventId}::text IS NULL OR e."id" > ${startAfterEventId})
      AND (
        (${forceEventId}::text IS NOT NULL AND e."id" = ${forceEventId})
        OR (${repairSyntheticOnly}::boolean = true
          AND COALESCE(sws.synthetic_week_count, 0) > 0
          AND COALESCE(sds.synthetic_day_count, 0) > 0
          AND COALESCE(ws.week_count, 0) = COALESCE(sws.synthetic_week_count, 0)
          AND COALESCE(ds.event_day_count, 0) = COALESCE(sds.synthetic_day_count, 0)
        )
        OR e."schedule_mode" IS NULL
        OR COALESCE(ws.week_count, 0) = 0
        OR COALESCE(ds.event_day_count, 0) = 0
        OR (
          COALESCE(ps.performance_count, 0) > 0
          AND COALESCE(ds.event_day_count, 0) < COALESCE(ps.max_legacy_day_index, 0)
        )
      )
    ORDER BY e."start_date" ASC, e."name" ASC
  `;
}

function buildFoundationDays(event: FoundationCandidateRow): EventDaySeed[] {
  const timeZone = normalizeEventTimeZone(event.timeZone);
  const startDate = getLocalDateParts(event.startDate, timeZone);
  const endDate = getLocalDateParts(event.endDate, timeZone);
  const minimumSpan = Math.max(inclusiveSpanDays(startDate, endDate), normalizeCount(event.maxLegacyDayIndex), 1);

  return Array.from({ length: minimumSpan }, (_, index) => {
    const date = addLocalDays(startDate, index, timeZone);
    return {
      eventDayId: `w1d${index + 1}`,
      weekIndex: 1,
      dayIndexInWeek: index + 1,
      overallDayIndex: index + 1,
      date,
      weekday: lowerWeekday(date, timeZone),
    };
  });
}

async function applyFoundation(event: FoundationCandidateRow): Promise<void> {
  const foundationDays = buildFoundationDays(event);
  const normalizedScheduleMode = inferScheduleMode(event, foundationDays.length);
  const firstDay = foundationDays[0];
  const lastDay = foundationDays[foundationDays.length - 1];

  if (!firstDay || !lastDay) {
    throw new Error(`No foundation days generated for event ${event.id}`);
  }

  await prisma.$transaction(async (tx) => {
    await tx.eventDay.deleteMany({ where: { eventId: event.id } });
    await tx.eventWeek.deleteMany({ where: { eventId: event.id } });

    const createdWeek = await tx.eventWeek.create({
      data: {
        eventId: event.id,
        weekIndex: 1,
        label: null,
        startDate: firstDay.date,
        endDate: lastDay.date,
        sortOrder: 1,
      },
    });

    await tx.eventDay.createMany({
      data: foundationDays.map((day) => ({
        eventId: event.id,
        eventWeekId: createdWeek.id,
        eventDayId: day.eventDayId,
        weekIndex: day.weekIndex,
        dayIndexInWeek: day.dayIndexInWeek,
        overallDayIndex: day.overallDayIndex,
        label: null,
        weekday: day.weekday,
        date: day.date,
        sortOrder: day.overallDayIndex,
      })),
    });

    await tx.eventPerformance.updateMany({
      where: { eventId: event.id },
      data: {
        eventDayId: null,
        weekIndex: null,
        dayIndexInWeek: null,
        overallDayIndex: null,
        localDate: null,
      },
    });

    for (const day of foundationDays) {
      await tx.eventPerformance.updateMany({
        where: {
          eventId: event.id,
          OR: [
            { festivalDayIndex: day.overallDayIndex },
            {
              festivalDayIndex: null,
              overallDayIndex: day.overallDayIndex,
            },
          ],
        },
        data: {
          eventDayId: day.eventDayId,
          weekIndex: day.weekIndex,
          dayIndexInWeek: day.dayIndexInWeek,
          overallDayIndex: day.overallDayIndex,
          localDate: day.date,
        },
      });
    }

    await tx.event.update({
      where: { id: event.id },
      data: {
        scheduleMode: normalizedScheduleMode,
      },
    });
  }, {
    timeout: transactionTimeoutMs,
  });
}

async function applyScheduleModeOnly(event: FoundationCandidateRow): Promise<void> {
  await prisma.event.update({
    where: { id: event.id },
    data: {
      scheduleMode: inferScheduleMode(event),
    },
  });
}

async function main(): Promise<void> {
  logStep('scan start', {
    dryRun,
    targetEventId,
    forceEventId,
    startAfterEventId,
    repairSyntheticOnly,
    transactionTimeoutMs,
  });
  const candidates = await listCandidates();

  logStep('scan done', {
    candidateCount: candidates.length,
    candidates: candidates.slice(0, 50).map((event) => {
      const foundationDays = buildFoundationDays(event);
      const timeZone = normalizeEventTimeZone(event.timeZone);
      return {
        eventId: event.id,
        name: event.name,
        scheduleMode: event.scheduleMode,
        timeZone,
        weekCount: normalizeCount(event.weekCount),
        eventDayCount: normalizeCount(event.eventDayCount),
        performanceCount: normalizeCount(event.performanceCount),
        maxLegacyDayIndex: event.maxLegacyDayIndex,
        syntheticWeekCount: normalizeCount(event.syntheticWeekCount),
        syntheticDayCount: normalizeCount(event.syntheticDayCount),
        needsFoundationRebuild: needsFoundationRebuild(event),
        inferredScheduleMode: inferScheduleMode(event, foundationDays.length),
        inferredFoundationDayCount: foundationDays.length,
        inferredDateRange: [
          foundationDays[0] ? localDatePartsToKey(getLocalDateParts(foundationDays[0].date, timeZone)) : null,
          foundationDays[foundationDays.length - 1]
            ? localDatePartsToKey(getLocalDateParts(foundationDays[foundationDays.length - 1].date, timeZone))
            : null,
        ],
      };
    }),
  });

  if (!dryRun) {
    for (const event of candidates) {
      const rebuild = needsFoundationRebuild(event) || event.id === forceEventId;
      logStep('apply candidate', {
        eventId: event.id,
        name: event.name,
        action: rebuild ? 'foundation_rebuild' : 'schedule_mode_only',
      });
      if (rebuild) {
        await applyFoundation(event);
      } else {
        await applyScheduleModeOnly(event);
      }
    }
  }

  logStep(dryRun ? 'dry run complete' : 'apply complete', {
    candidateCount: candidates.length,
  });
}

void main()
  .catch((error: unknown) => {
    console.error('[backfill-event-schedule-foundation] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
