import 'dotenv/config';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const dryRun = process.env.EVENT_MULTI_WEEK_BACKFILL_APPLY !== '1';
const targetEventId = process.env.EVENT_MULTI_WEEK_BACKFILL_EVENT_ID?.trim() || null;

type LegacyPerformanceRow = {
  eventId: string;
  legacyFestivalDayIndex: number | null;
  performanceCount: bigint | number;
  boundEventDayIdCount: bigint | number;
  localDateCount: bigint | number;
};

type CandidateEventRow = {
  id: string;
  name: string;
  startDate: Date;
  endDate: Date;
  scheduleMode: string;
  existingWeekCount: bigint | number;
  existingEventDayCount: bigint | number;
  performanceDayCount: bigint | number;
  maxFestivalDayIndex: number | null;
};

type CandidateResolution = {
  eventId: string;
  eventName: string;
  inferredWeeks: Array<{
    weekIndex: number;
    label: string;
    startDate: Date;
    endDate: Date;
  }>;
  inferredEventDays: Array<{
    eventDayId: string;
    weekIndex: number;
    dayIndexInWeek: number;
    overallDayIndex: number;
    label: string;
    weekday: string;
    date: Date;
  }>;
  reason: string;
};

const logStep = (step: string, detail?: Record<string, unknown>): void => {
  console.log('[backfill-historical-multi-week-events]', step, detail || {});
};

const normalizeCount = (value: bigint | number | null | undefined): number =>
  typeof value === 'bigint' ? Number(value) : Number(value || 0);

const dayMs = 86_400_000;

const startOfUtcDay = (value: Date): Date =>
  new Date(Date.UTC(value.getUTCFullYear(), value.getUTCMonth(), value.getUTCDate()));

const diffDaysInclusive = (start: Date, end: Date): number =>
  Math.round((startOfUtcDay(end).getTime() - startOfUtcDay(start).getTime()) / dayMs) + 1;

const addUtcDays = (value: Date, days: number): Date =>
  new Date(startOfUtcDay(value).getTime() + days * dayMs);

const weekdayShort = (value: Date): string =>
  value.toLocaleDateString('en-US', { weekday: 'short', timeZone: 'UTC' }).toLowerCase();

const lowerWeekday = (value: Date): string =>
  value.toLocaleDateString('en-US', { weekday: 'long', timeZone: 'UTC' }).toLowerCase();

const titleWeekday = (value: Date): string =>
  value.toLocaleDateString('en-US', { weekday: 'long', timeZone: 'UTC' });

const inferTwoWeekendPattern = (startDate: Date, endDate: Date): CandidateResolution['inferredWeeks'] | null => {
  const normalizedStart = startOfUtcDay(startDate);
  const normalizedEnd = startOfUtcDay(endDate);
  const totalInclusiveDays = diffDaysInclusive(normalizedStart, normalizedEnd);
  if (totalInclusiveDays !== 10 && totalInclusiveDays !== 11) return null;

  let firstWeekStart: Date | null = null;
  for (let offset = 0; offset <= 2; offset += 1) {
    const candidate = addUtcDays(normalizedStart, offset);
    if (weekdayShort(candidate) === 'fri') {
      firstWeekStart = candidate;
      break;
    }
  }
  if (!firstWeekStart) return null;
  const firstWeekEnd = addUtcDays(firstWeekStart, 2);
  if (weekdayShort(firstWeekEnd) !== 'sun' || firstWeekEnd.getTime() > normalizedEnd.getTime()) return null;

  let secondWeekEnd: Date | null = null;
  for (let offset = 0; offset <= 2; offset += 1) {
    const candidate = addUtcDays(normalizedEnd, -offset);
    if (weekdayShort(candidate) === 'sun') {
      secondWeekEnd = candidate;
      break;
    }
  }
  if (!secondWeekEnd) return null;
  const secondWeekStart = addUtcDays(secondWeekEnd, -2);
  if (weekdayShort(secondWeekStart) !== 'fri' || secondWeekStart.getTime() <= firstWeekEnd.getTime()) return null;

  const gapDays = Math.round((secondWeekStart.getTime() - firstWeekEnd.getTime()) / dayMs) - 1;
  if (gapDays !== 4 && gapDays !== 5) return null;

  return [
    {
      weekIndex: 1,
      label: 'Weekend 1',
      startDate: firstWeekStart,
      endDate: firstWeekEnd,
    },
    {
      weekIndex: 2,
      label: 'Weekend 2',
      startDate: secondWeekStart,
      endDate: secondWeekEnd,
    },
  ];
};

const buildEventDays = (weeks: CandidateResolution['inferredWeeks']): CandidateResolution['inferredEventDays'] => {
  const days: CandidateResolution['inferredEventDays'] = [];
  let overallDayIndex = 1;
  for (const week of weeks) {
    const span = diffDaysInclusive(week.startDate, week.endDate);
    for (let offset = 0; offset < span; offset += 1) {
      const date = addUtcDays(week.startDate, offset);
      const weekdayTitle = titleWeekday(date);
      days.push({
        eventDayId: `w${week.weekIndex}d${offset + 1}`,
        weekIndex: week.weekIndex,
        dayIndexInWeek: offset + 1,
        overallDayIndex,
        label: `${week.label} ${weekdayTitle}`,
        weekday: lowerWeekday(date),
        date,
      });
      overallDayIndex += 1;
    }
  }
  return days;
};

async function listCandidateEvents(): Promise<CandidateEventRow[]> {
  return prisma.$queryRaw<CandidateEventRow[]>`
    WITH performance_stats AS (
      SELECT
        ep."event_id",
        COUNT(DISTINCT GREATEST(COALESCE(ep."festival_day_index", 1), 1)) AS performance_day_count,
        MAX(GREATEST(COALESCE(ep."festival_day_index", 1), 1)) AS max_festival_day_index
      FROM "event_performances" ep
      GROUP BY ep."event_id"
    ),
    week_stats AS (
      SELECT
        ew."event_id",
        COUNT(*) AS existing_week_count
      FROM "event_weeks" ew
      GROUP BY ew."event_id"
    ),
    day_stats AS (
      SELECT
        ed."event_id",
        COUNT(*) AS existing_event_day_count
      FROM "event_days" ed
      GROUP BY ed."event_id"
    )
    SELECT
      e."id",
      e."name",
      e."start_date" AS "startDate",
      e."end_date" AS "endDate",
      e."schedule_mode" AS "scheduleMode",
      COALESCE(ws."existing_week_count", 0) AS "existingWeekCount",
      COALESCE(ds."existing_event_day_count", 0) AS "existingEventDayCount",
      COALESCE(ps."performance_day_count", 0) AS "performanceDayCount",
      ps."max_festival_day_index" AS "maxFestivalDayIndex"
    FROM "events" e
    LEFT JOIN performance_stats ps
      ON ps."event_id" = e."id"
    LEFT JOIN week_stats ws
      ON ws."event_id" = e."id"
    LEFT JOIN day_stats ds
      ON ds."event_id" = e."id"
    WHERE (${targetEventId}::text IS NULL OR e."id" = ${targetEventId})
      AND (
        e."schedule_mode" <> 'multi_week'
        OR COALESCE(ws."existing_week_count", 0) <= 1
      )
      AND (e."end_date"::date - e."start_date"::date) >= 5
    ORDER BY e."start_date" ASC, e."name" ASC
  `;
}

function resolveCandidate(event: CandidateEventRow): CandidateResolution | null {
  const inferredWeeks = inferTwoWeekendPattern(event.startDate, event.endDate);
  if (!inferredWeeks) return null;

  const inferredEventDays = buildEventDays(inferredWeeks);
  const inferredEventDayCount = inferredEventDays.length;
  const maxFestivalDayIndex = event.maxFestivalDayIndex ?? 0;
  const performanceDayCount = normalizeCount(event.performanceDayCount);

  if (maxFestivalDayIndex > inferredEventDayCount) return null;
  if (performanceDayCount > inferredEventDayCount) return null;

  return {
    eventId: event.id,
    eventName: event.name,
    inferredWeeks,
    inferredEventDays,
    reason: `Continuous ${diffDaysInclusive(event.startDate, event.endDate)}-day legacy range matches two 3-day weekends with a gap`,
  };
}

async function summarizePerformances(eventId: string): Promise<LegacyPerformanceRow[]> {
  return prisma.$queryRaw<LegacyPerformanceRow[]>`
    SELECT
      ep."event_id" AS "eventId",
      ep."festival_day_index" AS "legacyFestivalDayIndex",
      COUNT(*) AS "performanceCount",
      COUNT(*) FILTER (WHERE ep."event_day_id" IS NOT NULL) AS "boundEventDayIdCount",
      COUNT(*) FILTER (WHERE ep."local_date" IS NOT NULL) AS "localDateCount"
    FROM "event_performances" ep
    WHERE ep."event_id" = ${eventId}
    GROUP BY ep."event_id", ep."festival_day_index"
    ORDER BY ep."festival_day_index" ASC NULLS FIRST
  `;
}

async function applyResolution(resolution: CandidateResolution): Promise<void> {
  await prisma.$transaction(async (tx) => {
    await tx.eventDay.deleteMany({ where: { eventId: resolution.eventId } });
    await tx.eventWeek.deleteMany({ where: { eventId: resolution.eventId } });

    const createdWeeks = new Map<number, string>();

    for (const week of resolution.inferredWeeks) {
      const created = await tx.eventWeek.create({
        data: {
          eventId: resolution.eventId,
          weekIndex: week.weekIndex,
          label: week.label,
          startDate: week.startDate,
          endDate: week.endDate,
          sortOrder: week.weekIndex,
        },
      });
      createdWeeks.set(week.weekIndex, created.id);
    }

    for (const day of resolution.inferredEventDays) {
      await tx.eventDay.create({
        data: {
          eventId: resolution.eventId,
          eventWeekId: createdWeeks.get(day.weekIndex) || null,
          eventDayId: day.eventDayId,
          weekIndex: day.weekIndex,
          dayIndexInWeek: day.dayIndexInWeek,
          overallDayIndex: day.overallDayIndex,
          label: day.label,
          weekday: day.weekday,
          date: day.date,
          sortOrder: day.overallDayIndex,
        },
      });
    }

    await tx.event.update({
      where: { id: resolution.eventId },
      data: {
        scheduleMode: 'multi_week',
      },
    });

    for (const day of resolution.inferredEventDays) {
      await tx.eventPerformance.updateMany({
        where: {
          eventId: resolution.eventId,
          OR: [
            { festivalDayIndex: day.overallDayIndex },
            { festivalDayIndex: null, overallDayIndex: day.overallDayIndex },
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
  });
}

async function main(): Promise<void> {
  if (!dryRun && !targetEventId) {
    throw new Error(
      'historical multi-week apply 已被限制为单活动模式；请先设置 EVENT_MULTI_WEEK_BACKFILL_EVENT_ID，再执行 apply'
    );
  }
  logStep('scan start', { dryRun, targetEventId });
  const candidates = await listCandidateEvents();
  const resolved = candidates
    .map((event) => ({
      event,
      resolution: resolveCandidate(event),
    }));

  const applicable = resolved.filter((item) => item.resolution !== null) as Array<{
    event: CandidateEventRow;
    resolution: CandidateResolution;
  }>;
  const reviewOnly = resolved.filter((item) => item.resolution === null).map((item) => item.event);

  logStep('scan done', {
    candidateCount: candidates.length,
    applicableCount: applicable.length,
    reviewOnlyCount: reviewOnly.length,
    applicable: applicable.map(({ event, resolution }) => ({
      eventId: event.id,
      name: event.name,
      currentScheduleMode: event.scheduleMode,
      currentWeekCount: normalizeCount(event.existingWeekCount),
      currentEventDayCount: normalizeCount(event.existingEventDayCount),
      performanceDayCount: normalizeCount(event.performanceDayCount),
      inferredWeeks: resolution.inferredWeeks.map((week) => ({
        weekIndex: week.weekIndex,
        label: week.label,
        startDate: week.startDate.toISOString().slice(0, 10),
        endDate: week.endDate.toISOString().slice(0, 10),
      })),
      reason: resolution.reason,
    })),
    reviewOnly: reviewOnly.slice(0, 20).map((event) => ({
      eventId: event.id,
      name: event.name,
      startDate: event.startDate.toISOString().slice(0, 10),
      endDate: event.endDate.toISOString().slice(0, 10),
      scheduleMode: event.scheduleMode,
      performanceDayCount: normalizeCount(event.performanceDayCount),
      maxFestivalDayIndex: event.maxFestivalDayIndex,
    })),
  });

  for (const { resolution } of applicable) {
    const performanceSummary = await summarizePerformances(resolution.eventId);
    logStep(dryRun ? 'dry run candidate' : 'apply candidate', {
      eventId: resolution.eventId,
      eventName: resolution.eventName,
      inferredEventDays: resolution.inferredEventDays.map((day) => ({
        eventDayId: day.eventDayId,
        weekIndex: day.weekIndex,
        dayIndexInWeek: day.dayIndexInWeek,
        overallDayIndex: day.overallDayIndex,
        date: day.date.toISOString().slice(0, 10),
      })),
      performanceSummary: performanceSummary.map((row) => ({
        legacyFestivalDayIndex: row.legacyFestivalDayIndex,
        performanceCount: normalizeCount(row.performanceCount),
        boundEventDayIdCount: normalizeCount(row.boundEventDayIdCount),
        localDateCount: normalizeCount(row.localDateCount),
      })),
    });

    if (!dryRun) {
      await applyResolution(resolution);
    }
  }

  logStep(dryRun ? 'dry run complete' : 'apply complete', {
    appliedCount: dryRun ? 0 : applicable.length,
    reviewOnlyCount: reviewOnly.length,
  });
}

void main()
  .catch((error: unknown) => {
    console.error('[backfill-historical-multi-week-events] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
