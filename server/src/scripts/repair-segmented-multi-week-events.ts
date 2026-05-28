import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import {
  eventDateKey,
  eventDateOnlyToStorageDate,
  normalizeEventTimeZone,
  parseEventDateInput,
} from '../utils/event-timezone';

const prisma = new PrismaClient();

const dryRun = process.env.EVENT_MULTI_WEEK_SEGMENT_REPAIR_APPLY !== '1';
const targetEventId = process.env.EVENT_MULTI_WEEK_SEGMENT_REPAIR_EVENT_ID?.trim() || null;
const transactionTimeoutMs = Number(process.env.EVENT_MULTI_WEEK_SEGMENT_REPAIR_TX_TIMEOUT_MS || 120_000);

type CandidateEventRow = {
  id: string;
  name: string;
  timeZone: string | null;
  startDate: Date;
  endDate: Date;
  scheduleMode: string | null;
  weekCount: bigint | number;
  eventDayCount: bigint | number;
  syntheticWeekCount: bigint | number;
  syntheticDayCount: bigint | number;
  legacyFestivalDayIndexes: number[];
};

type SegmentRepairPlan = {
  eventId: string;
  eventName: string;
  timeZone: string;
  weeks: Array<{
    weekIndex: number;
    label: string;
    startDate: Date;
    endDate: Date;
    sortOrder: number;
    legacyIndexes: number[];
  }>;
  eventDays: Array<{
    eventDayId: string;
    weekIndex: number;
    dayIndexInWeek: number;
    overallDayIndex: number;
    label: string;
    weekday: string;
    date: Date;
    sortOrder: number;
    legacyFestivalDayIndex: number;
  }>;
};

const logStep = (step: string, detail?: Record<string, unknown>): void => {
  console.log('[repair-segmented-multi-week-events]', step, detail || {});
};

const pad2 = (value: number): string => String(value).padStart(2, '0');

const addDaysToDateKey = (dateKey: string, offset: number): string => {
  const [year, month, day] = dateKey.split('-').map(Number);
  const shifted = new Date(Date.UTC(year, month - 1, day + offset));
  return `${shifted.getUTCFullYear()}-${pad2(shifted.getUTCMonth() + 1)}-${pad2(shifted.getUTCDate())}`;
};

const buildLocalDateFromKey = (dateKey: string, timeZone: string): Date => {
  const parsed = parseEventDateInput(dateKey, timeZone, 'start');
  if (!parsed) {
    throw new Error(`无法解析活动本地日期 ${dateKey} (${timeZone})`);
  }
  return parsed;
};

const weekdayTitle = (date: Date, timeZone: string): string =>
  date.toLocaleDateString('en-US', {
    weekday: 'long',
    timeZone,
  });

const weekdayLower = (date: Date, timeZone: string): string =>
  weekdayTitle(date, timeZone).toLowerCase();

async function listCandidateEvents(): Promise<CandidateEventRow[]> {
  return prisma.$queryRaw<CandidateEventRow[]>`
    WITH performance_day_indexes AS (
      SELECT
        ep.event_id,
        ARRAY_AGG(DISTINCT GREATEST(COALESCE(ep.festival_day_index, 1), 1) ORDER BY GREATEST(COALESCE(ep.festival_day_index, 1), 1))
          FILTER (WHERE ep.festival_day_index IS NOT NULL) AS legacy_festival_day_indexes
      FROM event_performances ep
      GROUP BY ep.event_id
    ),
    week_stats AS (
      SELECT event_id, COUNT(*) AS week_count
      FROM event_weeks
      GROUP BY event_id
    ),
    day_stats AS (
      SELECT event_id, COUNT(*) AS event_day_count
      FROM event_days
      GROUP BY event_id
    ),
    synthetic_week_stats AS (
      SELECT event_id, COUNT(*) AS synthetic_week_count
      FROM event_weeks
      WHERE week_index = 1 AND sort_order = 1
      GROUP BY event_id
    ),
    synthetic_day_stats AS (
      SELECT event_id, COUNT(*) AS synthetic_day_count
      FROM event_days
      WHERE event_day_id ~ '^w1d[0-9]+$'
        AND week_index = 1
        AND day_index_in_week = overall_day_index
        AND sort_order = overall_day_index
      GROUP BY event_id
    )
    SELECT
      e.id,
      e.name,
      e.time_zone AS "timeZone",
      e.start_date AS "startDate",
      e.end_date AS "endDate",
      e.schedule_mode AS "scheduleMode",
      COALESCE(ws.week_count, 0) AS "weekCount",
      COALESCE(ds.event_day_count, 0) AS "eventDayCount",
      COALESCE(sws.synthetic_week_count, 0) AS "syntheticWeekCount",
      COALESCE(sds.synthetic_day_count, 0) AS "syntheticDayCount",
      COALESCE(pdi.legacy_festival_day_indexes, ARRAY[]::integer[]) AS "legacyFestivalDayIndexes"
    FROM events e
    LEFT JOIN week_stats ws ON ws.event_id = e.id
    LEFT JOIN day_stats ds ON ds.event_id = e.id
    LEFT JOIN synthetic_week_stats sws ON sws.event_id = e.id
    LEFT JOIN synthetic_day_stats sds ON sds.event_id = e.id
    LEFT JOIN performance_day_indexes pdi ON pdi.event_id = e.id
    WHERE (${targetEventId}::text IS NULL OR e.id = ${targetEventId})
      AND COALESCE(ws.week_count, 0) = 1
      AND COALESCE(sws.synthetic_week_count, 0) = 1
      AND COALESCE(ds.event_day_count, 0) = COALESCE(sds.synthetic_day_count, 0)
      AND COALESCE(array_length(pdi.legacy_festival_day_indexes, 1), 0) >= 2
    ORDER BY e.start_date ASC, e.name ASC
  `;
}

const splitIntoSegments = (indexes: number[]): number[][] => {
  const segments: number[][] = [];
  let current: number[] = [];
  for (const index of indexes) {
    if (current.length === 0 || index === current[current.length - 1] + 1) {
      current.push(index);
      continue;
    }
    segments.push(current);
    current = [index];
  }
  if (current.length > 0) {
    segments.push(current);
  }
  return segments;
};

function buildRepairPlan(event: CandidateEventRow, legacyIndexes: number[]): SegmentRepairPlan | null {
  const segments = splitIntoSegments(legacyIndexes).filter((segment) => segment.length >= 2);
  if (segments.length < 2) return null;

  const timeZone = normalizeEventTimeZone(event.timeZone);
  const eventStartDateKey = eventDateKey(event.startDate, timeZone);
  if (!eventStartDateKey) {
    throw new Error(`活动 ${event.id} 缺少有效 startDate`);
  }

  const weeks: SegmentRepairPlan['weeks'] = [];
  const eventDays: SegmentRepairPlan['eventDays'] = [];
  let overallDayIndex = 1;

  for (const [segmentIndex, segment] of segments.entries()) {
    const weekIndex = segmentIndex + 1;
    const segmentDates = segment.map((legacyIndex) => {
      const dateKey = addDaysToDateKey(eventStartDateKey, legacyIndex - 1);
      return buildLocalDateFromKey(dateKey, timeZone);
    });
    const firstDate = segmentDates[0];
    const lastDate = segmentDates[segmentDates.length - 1];
    if (!firstDate || !lastDate) {
      throw new Error(`活动 ${event.id} 无法为第 ${weekIndex} 段生成日期`);
    }
    weeks.push({
      weekIndex,
      label: `Week ${weekIndex}`,
      startDate: firstDate,
      endDate: lastDate,
      sortOrder: weekIndex,
      legacyIndexes: segment,
    });

    segment.forEach((legacyFestivalDayIndex, dayOffset) => {
      const date = segmentDates[dayOffset];
      const weekday = weekdayLower(date, timeZone);
      eventDays.push({
        eventDayId: `w${weekIndex}d${dayOffset + 1}`,
        weekIndex,
        dayIndexInWeek: dayOffset + 1,
        overallDayIndex,
        label: `Week ${weekIndex} ${weekdayTitle(date, timeZone)}`,
        weekday,
        date,
        sortOrder: overallDayIndex,
        legacyFestivalDayIndex,
      });
      overallDayIndex += 1;
    });
  }

  return {
    eventId: event.id,
    eventName: event.name,
    timeZone,
    weeks,
    eventDays,
  };
}

async function applyRepairPlan(plan: SegmentRepairPlan): Promise<void> {
  await prisma.$transaction(async (tx) => {
    await tx.eventPerformance.updateMany({
      where: { eventId: plan.eventId },
      data: {
        eventDayId: null,
        weekIndex: null,
        dayIndexInWeek: null,
        overallDayIndex: null,
        localDate: null,
      },
    });

    await tx.eventDay.deleteMany({ where: { eventId: plan.eventId } });
    await tx.eventWeek.deleteMany({ where: { eventId: plan.eventId } });

    const createdWeeks = new Map<number, string>();

    for (const week of plan.weeks) {
      const created = await tx.eventWeek.create({
        data: {
          eventId: plan.eventId,
          weekIndex: week.weekIndex,
          label: week.label,
          startDate: eventDateOnlyToStorageDate(week.startDate, plan.timeZone),
          endDate: eventDateOnlyToStorageDate(week.endDate, plan.timeZone),
          sortOrder: week.sortOrder,
        },
      });
      createdWeeks.set(week.weekIndex, created.id);
    }

    await tx.eventDay.createMany({
      data: plan.eventDays.map((day) => ({
        eventId: plan.eventId,
        eventWeekId: createdWeeks.get(day.weekIndex) ?? null,
        eventDayId: day.eventDayId,
        weekIndex: day.weekIndex,
        dayIndexInWeek: day.dayIndexInWeek,
        overallDayIndex: day.overallDayIndex,
        label: day.label,
        weekday: day.weekday,
        date: eventDateOnlyToStorageDate(day.date, plan.timeZone),
        sortOrder: day.sortOrder,
      })),
    });

    for (const day of plan.eventDays) {
      await tx.eventPerformance.updateMany({
        where: {
          eventId: plan.eventId,
          OR: [
            { festivalDayIndex: day.legacyFestivalDayIndex },
            {
              festivalDayIndex: null,
              OR: [
                { overallDayIndex: day.legacyFestivalDayIndex },
                { overallDayIndex: day.overallDayIndex },
              ],
            },
          ],
        },
        data: {
          eventDayId: day.eventDayId,
          weekIndex: day.weekIndex,
          dayIndexInWeek: day.dayIndexInWeek,
          overallDayIndex: day.overallDayIndex,
          localDate: eventDateOnlyToStorageDate(day.date, plan.timeZone),
        },
      });
    }

    await tx.event.update({
      where: { id: plan.eventId },
      data: { scheduleMode: 'multi_week' },
    });
  }, {
    timeout: transactionTimeoutMs,
  });
}

async function main(): Promise<void> {
  logStep('scan start', { dryRun, targetEventId, transactionTimeoutMs });
  const candidates = await listCandidateEvents();
  const plans: SegmentRepairPlan[] = [];

  for (const event of candidates) {
    const plan = buildRepairPlan(event, event.legacyFestivalDayIndexes);
    if (plan) {
      plans.push(plan);
    }
  }

  logStep('scan done', {
    candidateCount: candidates.length,
    applicableCount: plans.length,
    applicable: plans.map((plan) => ({
      eventId: plan.eventId,
      eventName: plan.eventName,
      timeZone: plan.timeZone,
      weekCount: plan.weeks.length,
      eventDayCount: plan.eventDays.length,
      weeks: plan.weeks.map((week) => ({
        weekIndex: week.weekIndex,
        label: week.label,
        startDate: eventDateKey(week.startDate, plan.timeZone),
        endDate: eventDateKey(week.endDate, plan.timeZone),
        legacyIndexes: week.legacyIndexes,
      })),
    })),
  });

  for (const plan of plans) {
    logStep(dryRun ? 'dry run candidate' : 'apply candidate', {
      eventId: plan.eventId,
      eventName: plan.eventName,
      weeks: plan.weeks.map((week) => ({
        weekIndex: week.weekIndex,
        label: week.label,
        startDate: eventDateKey(week.startDate, plan.timeZone),
        endDate: eventDateKey(week.endDate, plan.timeZone),
        legacyIndexes: week.legacyIndexes,
      })),
      eventDays: plan.eventDays.map((day) => ({
        eventDayId: day.eventDayId,
        weekIndex: day.weekIndex,
        dayIndexInWeek: day.dayIndexInWeek,
        overallDayIndex: day.overallDayIndex,
        date: eventDateKey(day.date, plan.timeZone),
        legacyFestivalDayIndex: day.legacyFestivalDayIndex,
      })),
    });
    if (!dryRun) {
      await applyRepairPlan(plan);
    }
  }

  logStep(dryRun ? 'dry run complete' : 'apply complete', {
    appliedCount: dryRun ? 0 : plans.length,
  });
}

void main()
  .catch((error: unknown) => {
    console.error('[repair-segmented-multi-week-events] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
