import 'dotenv/config';
import fs from 'fs';
import path from 'path';
import { PrismaClient } from '@prisma/client';
import {
  eventDateOnlyToStorageDate,
  normalizeEventTimeZone,
} from '../utils/event-timezone';
import {
  normalizeSubmittedEventScheduleContext,
  type SubmittedEventScheduleContext,
} from '../services/content-submission-event.service';

const prisma = new PrismaClient();

const dryRun = process.env.EVENT_MULTI_WEEK_REPAIR_APPLY !== '1';
const specPathInput = process.env.EVENT_MULTI_WEEK_REPAIR_SPEC_PATH?.trim() || '';
const transactionTimeoutMs = Number(process.env.EVENT_MULTI_WEEK_REPAIR_TX_TIMEOUT_MS || 120_000);

type RepairSpec = {
  eventId: string;
  schedule?: {
    mode?: string;
    timeZone?: string;
    dayRolloverHour?: number;
  };
  weeks: unknown;
  eventDays: unknown;
};

type RepairEventDayMapping = {
  eventDayId: string;
  legacyFestivalDayIndex: number | null;
};

const logStep = (step: string, detail?: Record<string, unknown>): void => {
  console.log('[repair-historical-multi-week-event]', step, detail || {});
};

const readSpecFile = (): RepairSpec => {
  if (!specPathInput) {
    throw new Error('请先设置 EVENT_MULTI_WEEK_REPAIR_SPEC_PATH，指向单活动 multi-week 修复 spec JSON 文件');
  }

  const resolvedPath = path.resolve(specPathInput);
  const raw = fs.readFileSync(resolvedPath, 'utf8');
  const parsed = JSON.parse(raw) as RepairSpec;

  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
    throw new Error('修复 spec 必须是 JSON 对象');
  }
  if (typeof parsed.eventId !== 'string' || !parsed.eventId.trim()) {
    throw new Error('修复 spec 缺少有效的 eventId');
  }
  return parsed;
};

const normalizeRepairScheduleContext = (
  spec: RepairSpec,
  fallbackTimeZone: string
): SubmittedEventScheduleContext => {
  return normalizeSubmittedEventScheduleContext({
    schedule: {
      mode: 'multi_week',
      timeZone: spec.schedule?.timeZone ?? fallbackTimeZone,
      dayRolloverHour: spec.schedule?.dayRolloverHour ?? 6,
    },
    weeks: spec.weeks,
    eventDays: spec.eventDays,
  });
};

const normalizeLegacyFestivalDayMappings = (spec: RepairSpec): Map<string, number> => {
  if (!Array.isArray(spec.eventDays)) {
    throw new Error('修复 spec 的 eventDays 必须是数组');
  }

  const mapping = new Map<string, number>();
  const usedLegacyIndexes = new Set<number>();

  for (const item of spec.eventDays as RepairEventDayMapping[]) {
    if (!item || typeof item !== 'object' || Array.isArray(item)) continue;
    if (typeof item.eventDayId !== 'string' || !item.eventDayId.trim()) continue;
    if (item.legacyFestivalDayIndex === null || item.legacyFestivalDayIndex === undefined) continue;
    const normalized = Number(item.legacyFestivalDayIndex);
    if (!Number.isFinite(normalized) || normalized < 1 || Math.floor(normalized) !== normalized) {
      throw new Error(`eventDay ${item.eventDayId} 的 legacyFestivalDayIndex 必须是大于 0 的整数`);
    }
    if (usedLegacyIndexes.has(normalized)) {
      throw new Error(`修复 spec 中存在重复的 legacyFestivalDayIndex=${normalized}`);
    }
    mapping.set(item.eventDayId.trim(), normalized);
    usedLegacyIndexes.add(normalized);
  }

  return mapping;
};

async function applyRepair(
  eventId: string,
  scheduleContext: SubmittedEventScheduleContext,
  legacyFestivalDayMappings: Map<string, number>
): Promise<void> {
  await prisma.$transaction(async (tx) => {
    await tx.eventPerformance.updateMany({
      where: { eventId },
      data: {
        eventDayId: null,
        weekIndex: null,
        dayIndexInWeek: null,
        overallDayIndex: null,
        localDate: null,
      },
    });

    await tx.eventDay.deleteMany({ where: { eventId } });
    await tx.eventWeek.deleteMany({ where: { eventId } });

    const createdWeeks = new Map<number, string>();

    for (const week of scheduleContext.weeks) {
      const created = await tx.eventWeek.create({
        data: {
          eventId,
          weekIndex: week.weekIndex,
          label: week.label,
          startDate: eventDateOnlyToStorageDate(week.startDate, scheduleContext.timeZone),
          endDate: eventDateOnlyToStorageDate(week.endDate, scheduleContext.timeZone),
          sortOrder: week.sortOrder,
        },
      });
      createdWeeks.set(week.weekIndex, created.id);
    }

    await tx.eventDay.createMany({
      data: scheduleContext.eventDays.map((day) => ({
        eventId,
        eventWeekId: createdWeeks.get(day.weekIndex) ?? null,
        eventDayId: day.eventDayId,
        weekIndex: day.weekIndex,
        dayIndexInWeek: day.dayIndexInWeek,
        overallDayIndex: day.overallDayIndex,
        label: day.label,
        weekday: day.weekday,
        date: eventDateOnlyToStorageDate(day.date, scheduleContext.timeZone),
        sortOrder: day.sortOrder,
      })),
    });

    for (const day of scheduleContext.eventDays) {
      const legacyFestivalDayIndex = legacyFestivalDayMappings.get(day.eventDayId) ?? day.overallDayIndex;
      await tx.eventPerformance.updateMany({
        where: {
          eventId,
          OR: [
            { festivalDayIndex: legacyFestivalDayIndex },
            {
              festivalDayIndex: null,
              OR: [
                { overallDayIndex: legacyFestivalDayIndex },
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
          localDate: eventDateOnlyToStorageDate(day.date, scheduleContext.timeZone),
        },
      });
    }

    await tx.event.update({
      where: { id: eventId },
      data: {
        scheduleMode: 'multi_week',
      },
    });
  }, {
    timeout: transactionTimeoutMs,
  });
}

async function main(): Promise<void> {
  const spec = readSpecFile();
  const event = await prisma.event.findUnique({
    where: { id: spec.eventId },
    select: {
      id: true,
      name: true,
      timeZone: true,
      startDate: true,
      endDate: true,
      scheduleMode: true,
      weeks: {
        orderBy: [{ sortOrder: 'asc' }, { weekIndex: 'asc' }],
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
        orderBy: [{ sortOrder: 'asc' }, { overallDayIndex: 'asc' }],
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
    },
  });

  if (!event) {
    throw new Error(`活动不存在: ${spec.eventId}`);
  }

  const timeZone = normalizeEventTimeZone(spec.schedule?.timeZone ?? event.timeZone);
  const scheduleContext = normalizeRepairScheduleContext(spec, timeZone);
  const legacyFestivalDayMappings = normalizeLegacyFestivalDayMappings(spec);

  logStep('spec loaded', {
    dryRun,
    eventId: event.id,
    eventName: event.name,
    timeZone,
    currentScheduleMode: event.scheduleMode,
    currentWeekCount: event.weeks.length,
    currentEventDayCount: event.eventDays.length,
    targetWeekCount: scheduleContext.weeks.length,
    targetEventDayCount: scheduleContext.eventDays.length,
    targetWeeks: scheduleContext.weeks.map((week) => ({
      weekIndex: week.weekIndex,
      label: week.label,
      startDate: week.startDate.toISOString().slice(0, 10),
      endDate: week.endDate.toISOString().slice(0, 10),
      sortOrder: week.sortOrder,
    })),
    targetEventDays: scheduleContext.eventDays.map((day) => ({
      eventDayId: day.eventDayId,
      weekIndex: day.weekIndex,
      dayIndexInWeek: day.dayIndexInWeek,
      overallDayIndex: day.overallDayIndex,
      label: day.label,
      weekday: day.weekday,
      date: day.date.toISOString().slice(0, 10),
      sortOrder: day.sortOrder,
      legacyFestivalDayIndex: legacyFestivalDayMappings.get(day.eventDayId) ?? day.overallDayIndex,
    })),
  });

  if (dryRun) {
    logStep('dry run complete', {
      eventId: event.id,
      specPath: path.resolve(specPathInput),
    });
    return;
  }

  await applyRepair(event.id, scheduleContext, legacyFestivalDayMappings);

  logStep('apply complete', {
    eventId: event.id,
    eventName: event.name,
    specPath: path.resolve(specPathInput),
  });
}

void main()
  .catch((error: unknown) => {
    console.error('[repair-historical-multi-week-event] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
