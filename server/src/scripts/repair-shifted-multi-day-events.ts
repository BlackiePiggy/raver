import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import {
  eventDateKey,
  eventDateOnlyToStorageDate,
  normalizeEventTimeZone,
  parseEventDateInput,
} from '../utils/event-timezone';

const prisma = new PrismaClient();

const dryRun = process.env.EVENT_MULTI_DAY_SHIFT_REPAIR_APPLY !== '1';
const targetEventId = process.env.EVENT_MULTI_DAY_SHIFT_REPAIR_EVENT_ID?.trim() || null;
const transactionTimeoutMs = Number(process.env.EVENT_MULTI_DAY_SHIFT_REPAIR_TX_TIMEOUT_MS || 120_000);

type CandidateEventRow = {
  id: string;
  name: string;
  timeZone: string | null;
  scheduleMode: string | null;
  startDate: Date;
  endDate: Date;
  eventDayCount: bigint | number;
  performanceDayCount: bigint | number;
  maxLegacyDayIndex: bigint | number;
  legacyFestivalDayIndexes: number[];
};

type RepairPlan = {
  eventId: string;
  eventName: string;
  timeZone: string;
  week: {
    weekIndex: number;
    label: string | null;
    startDate: Date;
    endDate: Date;
    sortOrder: number;
  };
  eventDays: Array<{
    eventDayId: string;
    weekIndex: number;
    dayIndexInWeek: number;
    overallDayIndex: number;
    label: string | null;
    weekday: string;
    date: Date;
    sortOrder: number;
    legacyFestivalDayIndex: number;
  }>;
};

const logStep = (step: string, detail?: Record<string, unknown>): void => {
  console.log('[repair-shifted-multi-day-events]', step, detail || {});
};

const sleep = (ms: number): Promise<void> =>
  new Promise((resolve) => {
    setTimeout(resolve, ms);
  });

const normalizeCount = (value: bigint | number | null | undefined): number =>
  typeof value === 'bigint' ? Number(value) : Number(value || 0);

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

const weekdayLower = (date: Date, timeZone: string): string =>
  date.toLocaleDateString('en-US', {
    weekday: 'long',
    timeZone,
  }).toLowerCase();

async function listCandidates(): Promise<CandidateEventRow[]> {
  return prisma.$queryRaw<CandidateEventRow[]>`
    WITH performance_stats AS (
      SELECT
        ep.event_id,
        COUNT(DISTINCT GREATEST(COALESCE(ep.festival_day_index, 1), 1)) AS performance_day_count,
        MAX(GREATEST(COALESCE(ep.festival_day_index, 1), 1)) AS max_legacy_day_index,
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
      e.schedule_mode AS "scheduleMode",
      e.start_date AS "startDate",
      e.end_date AS "endDate",
      COALESCE(ds.event_day_count, 0) AS "eventDayCount",
      COALESCE(ps.performance_day_count, 0) AS "performanceDayCount",
      COALESCE(ps.max_legacy_day_index, 0) AS "maxLegacyDayIndex",
      COALESCE(ps.legacy_festival_day_indexes, ARRAY[]::integer[]) AS "legacyFestivalDayIndexes"
    FROM events e
    JOIN performance_stats ps ON ps.event_id = e.id
    LEFT JOIN week_stats ws ON ws.event_id = e.id
    LEFT JOIN day_stats ds ON ds.event_id = e.id
    LEFT JOIN synthetic_week_stats sws ON sws.event_id = e.id
    LEFT JOIN synthetic_day_stats sds ON sds.event_id = e.id
    WHERE (${targetEventId}::text IS NULL OR e.id = ${targetEventId})
      AND COALESCE(ps.performance_day_count, 0) > 0
      AND COALESCE(ps.performance_day_count, 0) < COALESCE(ps.max_legacy_day_index, 0)
      AND COALESCE(ws.week_count, 0) = 1
      AND COALESCE(sws.synthetic_week_count, 0) = 1
      AND COALESCE(ds.event_day_count, 0) = COALESCE(sds.synthetic_day_count, 0)
    ORDER BY e.start_date ASC, e.name ASC
  `;
}

async function listCandidatesWithRetry(): Promise<CandidateEventRow[]> {
  let lastError: unknown = null;
  for (let attempt = 1; attempt <= 4; attempt += 1) {
    try {
      return await listCandidates();
    } catch (error) {
      lastError = error;
      if (attempt === 4) break;
      logStep('scan retry', { attempt, message: error instanceof Error ? error.message : String(error) });
      await sleep(1500 * attempt);
    }
  }
  throw lastError;
}

function canRepair(row: CandidateEventRow): boolean {
  const indexes = row.legacyFestivalDayIndexes;
  if (!indexes.length || indexes[0] !== 2) return false;
  for (let index = 1; index < indexes.length; index += 1) {
    if (indexes[index] !== indexes[index - 1] + 1) return false;
  }
  return (
    indexes[indexes.length - 1] === normalizeCount(row.maxLegacyDayIndex)
    && indexes.length === normalizeCount(row.performanceDayCount)
    && normalizeCount(row.eventDayCount) === normalizeCount(row.maxLegacyDayIndex)
  );
}

function buildRepairPlan(row: CandidateEventRow): RepairPlan {
  const timeZone = normalizeEventTimeZone(row.timeZone);
  const firstLegacyIndex = row.legacyFestivalDayIndexes[0];
  const lastLegacyIndex = row.legacyFestivalDayIndexes[row.legacyFestivalDayIndexes.length - 1];
  if (!firstLegacyIndex || !lastLegacyIndex) {
    throw new Error(`活动 ${row.id} 缺少 legacy day 索引`);
  }

  const startKey = eventDateKey(row.startDate, timeZone);
  if (!startKey) {
    throw new Error(`活动 ${row.id} 缺少有效 startDate`);
  }

  const eventDays = row.legacyFestivalDayIndexes.map((legacyFestivalDayIndex, arrayIndex) => {
    const dateKey = addDaysToDateKey(startKey, legacyFestivalDayIndex - 1);
    const date = buildLocalDateFromKey(dateKey, timeZone);
    return {
      eventDayId: `w1d${arrayIndex + 1}`,
      weekIndex: 1,
      dayIndexInWeek: arrayIndex + 1,
      overallDayIndex: arrayIndex + 1,
      label: null,
      weekday: weekdayLower(date, timeZone),
      date,
      sortOrder: arrayIndex + 1,
      legacyFestivalDayIndex,
    };
  });

  return {
    eventId: row.id,
    eventName: row.name,
    timeZone,
    week: {
      weekIndex: 1,
      label: null,
      startDate: eventDays[0]!.date,
      endDate: eventDays[eventDays.length - 1]!.date,
      sortOrder: 1,
    },
    eventDays,
  };
}

async function applyRepairPlan(plan: RepairPlan): Promise<void> {
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

    const createdWeek = await tx.eventWeek.create({
      data: {
        eventId: plan.eventId,
        weekIndex: plan.week.weekIndex,
        label: plan.week.label,
        startDate: eventDateOnlyToStorageDate(plan.week.startDate, plan.timeZone),
        endDate: eventDateOnlyToStorageDate(plan.week.endDate, plan.timeZone),
        sortOrder: plan.week.sortOrder,
      },
    });

    await tx.eventDay.createMany({
      data: plan.eventDays.map((day) => ({
        eventId: plan.eventId,
        eventWeekId: createdWeek.id,
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
      data: {
        scheduleMode: plan.eventDays.length === 1 ? 'single_day' : 'multi_day',
      },
    });
  }, {
    timeout: transactionTimeoutMs,
  });
}

async function applyRepairPlanWithRetry(plan: RepairPlan): Promise<void> {
  let lastError: unknown = null;
  for (let attempt = 1; attempt <= 4; attempt += 1) {
    try {
      await applyRepairPlan(plan);
      return;
    } catch (error) {
      lastError = error;
      if (attempt === 4) break;
      logStep('apply retry', {
        eventId: plan.eventId,
        attempt,
        message: error instanceof Error ? error.message : String(error),
      });
      await sleep(1500 * attempt);
    }
  }
  throw lastError;
}

async function main(): Promise<void> {
  logStep('scan start', { dryRun, targetEventId, transactionTimeoutMs });
  const candidates = await listCandidatesWithRetry();
  const applicable = candidates.filter(canRepair);
  const plans = applicable.map(buildRepairPlan);

  logStep('scan done', {
    candidateCount: candidates.length,
    applicableCount: plans.length,
    reviewOnlyCount: candidates.length - plans.length,
    applicable: plans.map((plan) => ({
      eventId: plan.eventId,
      eventName: plan.eventName,
      eventDayCount: plan.eventDays.length,
      startDate: eventDateKey(plan.week.startDate, plan.timeZone),
      endDate: eventDateKey(plan.week.endDate, plan.timeZone),
      legacyFestivalDayIndexes: plan.eventDays.map((day) => day.legacyFestivalDayIndex),
    })),
  });

  for (const plan of plans) {
    logStep(dryRun ? 'dry run candidate' : 'apply candidate', {
      eventId: plan.eventId,
      eventName: plan.eventName,
      startDate: eventDateKey(plan.week.startDate, plan.timeZone),
      endDate: eventDateKey(plan.week.endDate, plan.timeZone),
      eventDays: plan.eventDays.map((day) => ({
        eventDayId: day.eventDayId,
        overallDayIndex: day.overallDayIndex,
        date: eventDateKey(day.date, plan.timeZone),
        legacyFestivalDayIndex: day.legacyFestivalDayIndex,
      })),
    });
    if (!dryRun) {
      await applyRepairPlanWithRetry(plan);
    }
  }

  logStep(dryRun ? 'dry run complete' : 'apply complete', {
    appliedCount: dryRun ? 0 : plans.length,
  });
}

void main()
  .catch((error: unknown) => {
    console.error('[repair-shifted-multi-day-events] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
