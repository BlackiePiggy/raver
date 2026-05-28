import 'dotenv/config';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const dryRun = process.env.EVENT_SCHEDULE_FOUNDATION_BACKFILL_APPLY !== '1';
const targetEventId = process.env.EVENT_SCHEDULE_FOUNDATION_EVENT_ID?.trim() || null;
const startAfterEventId = process.env.EVENT_SCHEDULE_FOUNDATION_START_AFTER_EVENT_ID?.trim() || null;
const transactionTimeoutMs = Number(process.env.EVENT_SCHEDULE_FOUNDATION_TX_TIMEOUT_MS || 60_000);

type FoundationCandidateRow = {
  id: string;
  name: string;
  startDate: Date;
  endDate: Date;
  scheduleMode: string;
  weekCount: bigint | number;
  eventDayCount: bigint | number;
  performanceCount: bigint | number;
  maxLegacyDayIndex: number | null;
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

const startOfUtcDay = (value: Date): Date =>
  new Date(Date.UTC(value.getUTCFullYear(), value.getUTCMonth(), value.getUTCDate()));

const addUtcDays = (value: Date, days: number): Date =>
  new Date(startOfUtcDay(value).getTime() + dayMs * days);

const inclusiveSpanDays = (start: Date, end: Date): number =>
  Math.round((startOfUtcDay(end).getTime() - startOfUtcDay(start).getTime()) / dayMs) + 1;

const lowerWeekday = (value: Date): string =>
  value.toLocaleDateString('en-US', { weekday: 'long', timeZone: 'UTC' }).toLowerCase();

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
    )
    SELECT
      e."id",
      e."name",
      e."start_date" AS "startDate",
      e."end_date" AS "endDate",
      e."schedule_mode" AS "scheduleMode",
      COALESCE(ws.week_count, 0) AS "weekCount",
      COALESCE(ds.event_day_count, 0) AS "eventDayCount",
      COALESCE(ps.performance_count, 0) AS "performanceCount",
      ps.max_legacy_day_index AS "maxLegacyDayIndex"
    FROM "events" e
    LEFT JOIN week_stats ws
      ON ws."event_id" = e."id"
    LEFT JOIN day_stats ds
      ON ds."event_id" = e."id"
    LEFT JOIN performance_stats ps
      ON ps."event_id" = e."id"
    WHERE (${targetEventId}::text IS NULL OR e."id" = ${targetEventId})
      AND (${startAfterEventId}::text IS NULL OR e."id" > ${startAfterEventId})
      AND (
        COALESCE(ws.week_count, 0) = 0
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
  const startDate = startOfUtcDay(event.startDate);
  const endDate = startOfUtcDay(event.endDate);
  const minimumSpan = Math.max(inclusiveSpanDays(startDate, endDate), normalizeCount(event.maxLegacyDayIndex), 1);

  return Array.from({ length: minimumSpan }, (_, index) => {
    const date = addUtcDays(startDate, index);
    return {
      eventDayId: `w1d${index + 1}`,
      weekIndex: 1,
      dayIndexInWeek: index + 1,
      overallDayIndex: index + 1,
      date,
      weekday: lowerWeekday(date),
    };
  });
}

async function applyFoundation(event: FoundationCandidateRow): Promise<void> {
  const foundationDays = buildFoundationDays(event);

  await prisma.$transaction(async (tx) => {
    await tx.eventDay.deleteMany({ where: { eventId: event.id } });
    await tx.eventWeek.deleteMany({ where: { eventId: event.id } });

    const createdWeek = await tx.eventWeek.create({
      data: {
        eventId: event.id,
        weekIndex: 1,
        label: null,
        startDate: startOfUtcDay(event.startDate),
        endDate: addUtcDays(startOfUtcDay(event.startDate), foundationDays.length - 1),
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
  }, {
    timeout: transactionTimeoutMs,
  });
}

async function main(): Promise<void> {
  logStep('scan start', { dryRun, targetEventId, startAfterEventId, transactionTimeoutMs });
  const candidates = await listCandidates();

  logStep('scan done', {
    candidateCount: candidates.length,
    candidates: candidates.slice(0, 50).map((event) => {
      const foundationDays = buildFoundationDays(event);
      return {
        eventId: event.id,
        name: event.name,
        scheduleMode: event.scheduleMode,
        weekCount: normalizeCount(event.weekCount),
        eventDayCount: normalizeCount(event.eventDayCount),
        performanceCount: normalizeCount(event.performanceCount),
        maxLegacyDayIndex: event.maxLegacyDayIndex,
        inferredFoundationDayCount: foundationDays.length,
        inferredDateRange: [
          foundationDays[0]?.date.toISOString().slice(0, 10) ?? null,
          foundationDays[foundationDays.length - 1]?.date.toISOString().slice(0, 10) ?? null,
        ],
      };
    }),
  });

  if (!dryRun) {
    for (const event of candidates) {
      logStep('apply candidate', { eventId: event.id, name: event.name });
      await applyFoundation(event);
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
