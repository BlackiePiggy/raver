import 'dotenv/config';
import crypto from 'node:crypto';
import { Prisma, PrismaClient } from '@prisma/client';
import { loadCanonicalEventLineupSnapshot, type CanonicalLineupArtistInput, type CanonicalLineupSlotInput } from '../services/event-lineup-canonical.service';
import { processContentSubmission } from '../services/content-submission-processing.service';

const prisma = new PrismaClient();

type BenchmarkSchedulePayload = {
  schedule: {
    mode: 'single_day' | 'multi_day' | 'multi_week';
    timeZone: string;
    dayRolloverHour: number;
  };
  weeks: Array<{
    weekIndex: number;
    label: string;
    startDate: string;
    endDate: string;
    sortOrder: number;
  }>;
  eventDays: Array<{
    eventDayId: string;
    weekIndex: number;
    dayIndexInWeek: number;
    overallDayIndex: number;
    label: string;
    weekday: string;
    date: string;
    sortOrder: number;
  }>;
};

type BenchmarkMetrics = {
  phaseAWallMs: number;
  phaseBWallMs: number;
  phaseATimings: {
    reviewingTransitionMs: number;
    applyMs: number;
    timetableQueuedMs?: number;
    approvalFinalizeMs: number;
    totalMs: number;
  } | null;
  finalSlotCount: number;
  finalArtistCount: number;
};

type Stats = {
  minMs: number;
  maxMs: number;
  averageMs: number;
  medianMs: number;
  p95Ms: number;
};

const BENCHMARK_TIME_ZONE = 'Asia/Shanghai';

const assert = (condition: boolean, message: string): void => {
  if (!condition) throw new Error(message);
};

const log = (step: string, detail?: Record<string, unknown>): void => {
  console.log('[benchmark-event-submission]', step, detail || {});
};

const parseArgs = (argv: string[]): Record<string, string | boolean> => {
  const parsed: Record<string, string | boolean> = {};
  for (let index = 0; index < argv.length; index += 1) {
    const current = argv[index];
    if (!current.startsWith('--')) continue;
    const key = current.slice(2);
    const next = argv[index + 1];
    if (!next || next.startsWith('--')) {
      parsed[key] = true;
      continue;
    }
    parsed[key] = next;
    index += 1;
  }
  return parsed;
};

const percentile = (values: number[], rawPercentile: number): number => {
  if (values.length === 0) return 0;
  const sorted = [...values].sort((left, right) => left - right);
  const index = Math.min(sorted.length - 1, Math.max(0, Math.ceil(rawPercentile * sorted.length) - 1));
  return sorted[index];
};

const summarize = (durationsMs: number[]): Stats => {
  const sorted = [...durationsMs].sort((left, right) => left - right);
  const total = durationsMs.reduce((sum, value) => sum + value, 0);
  const middle = Math.floor(sorted.length / 2);
  const medianMs = sorted.length % 2 === 0
    ? (sorted[middle - 1] + sorted[middle]) / 2
    : sorted[middle];
  return {
    minMs: sorted[0] || 0,
    maxMs: sorted[sorted.length - 1] || 0,
    averageMs: durationsMs.length > 0 ? total / durationsMs.length : 0,
    medianMs,
    p95Ms: percentile(sorted, 0.95),
  };
};

const formatStats = (stats: Stats): Record<string, string> => ({
  minMs: stats.minMs.toFixed(2),
  avgMs: stats.averageMs.toFixed(2),
  medianMs: stats.medianMs.toFixed(2),
  p95Ms: stats.p95Ms.toFixed(2),
  maxMs: stats.maxMs.toFixed(2),
});

const formatDuration = (value: number): string =>
  value >= 1000 ? `${(value / 1000).toFixed(value >= 10_000 ? 0 : 1)}s` : `${Math.round(value)}ms`;

const shanghaiIsoAt = (date: string, totalMinutes: number): string => {
  const normalizedMinutes = ((totalMinutes % 1_440) + 1_440) % 1_440;
  const hour = Math.floor(normalizedMinutes / 60);
  const minute = normalizedMinutes % 60;
  return `${date}T${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}:00+08:00`;
};

const buildBenchmarkSchedule = (weeks = 2, daysPerWeek = 3): BenchmarkSchedulePayload => {
  const baseDates = [
    ['2026-11-06', '2026-11-07', '2026-11-08'],
    ['2026-11-13', '2026-11-14', '2026-11-15'],
    ['2026-11-20', '2026-11-21', '2026-11-22'],
    ['2026-11-27', '2026-11-28', '2026-11-29'],
  ];
  const weekdays = ['friday', 'saturday', 'sunday'];
  const usedWeeks = baseDates.slice(0, weeks);
  const eventDays: BenchmarkSchedulePayload['eventDays'] = [];
  const scheduleWeeks: BenchmarkSchedulePayload['weeks'] = [];
  let overallDayIndex = 1;

  usedWeeks.forEach((weekDates, weekOffset) => {
    const weekIndex = weekOffset + 1;
    const activeDates = weekDates.slice(0, daysPerWeek);
    scheduleWeeks.push({
      weekIndex,
      label: `Weekend ${weekIndex}`,
      startDate: activeDates[0],
      endDate: activeDates[activeDates.length - 1],
      sortOrder: weekIndex,
    });
    activeDates.forEach((date, dayOffset) => {
      eventDays.push({
        eventDayId: `w${weekIndex}d${dayOffset + 1}`,
        weekIndex,
        dayIndexInWeek: dayOffset + 1,
        overallDayIndex,
        label: `Week ${weekIndex} Day ${dayOffset + 1}`,
        weekday: weekdays[dayOffset] || 'saturday',
        date,
        sortOrder: overallDayIndex,
      });
      overallDayIndex += 1;
    });
  });

  return {
    schedule: {
      mode: weeks > 1 ? 'multi_week' : daysPerWeek > 1 ? 'multi_day' : 'single_day',
      timeZone: BENCHMARK_TIME_ZONE,
      dayRolloverHour: 6,
    },
    weeks: scheduleWeeks,
    eventDays,
  };
};

const buildCreatePayload = (
  suffix: string,
  slotCount: number,
  stageCount: number,
  schedule: BenchmarkSchedulePayload
): Prisma.JsonObject => {
  const stageOrder = Array.from({ length: stageCount }, (_, index) => `Benchmark Stage ${index + 1}`);
  const lineupArtists = Array.from({ length: slotCount }, (_, index) => ({
    djName: `Benchmark DJ ${suffix} ${String(index + 1).padStart(3, '0')}`,
    memberNames: [`Benchmark DJ ${suffix} ${String(index + 1).padStart(3, '0')}`],
    memberDjIds: [],
    sortOrder: index + 1,
  }));
  const lineupSlots = Array.from({ length: slotCount }, (_, index) => {
    const day = schedule.eventDays[index % schedule.eventDays.length];
    const stageName = stageOrder[index % stageOrder.length];
    const startMinutes = 12 * 60 + ((index * 30) % (20 * 60));
    return {
      eventDayId: day.eventDayId,
      weekIndex: day.weekIndex,
      dayIndexInWeek: day.dayIndexInWeek,
      overallDayIndex: day.overallDayIndex,
      localDate: day.date,
      djName: lineupArtists[index].djName,
      memberNames: lineupArtists[index].memberNames,
      memberDjIds: [],
      djId: null,
      lineupArtistId: null,
      stageName,
      festivalDayIndex: day.overallDayIndex,
      startTime: shanghaiIsoAt(day.date, startMinutes),
      endTime: shanghaiIsoAt(day.date, startMinutes + 45),
      sortOrder: index + 1,
    };
  });

  return {
    name: `Benchmark Event ${suffix}`,
    ...schedule,
    imageAssets: [
      {
        type: 'poster',
        label: 'POSTER',
        url: 'https://example.com/benchmark-poster.jpg',
      },
    ],
    lineupArtists: lineupArtists as unknown as Prisma.InputJsonValue,
    lineupSlots: lineupSlots as unknown as Prisma.InputJsonValue,
    stageOrder: stageOrder as unknown as Prisma.InputJsonValue,
  } as Prisma.JsonObject;
};

const buildEditPayload = (
  eventId: string,
  schedule: BenchmarkSchedulePayload,
  snapshot: {
    artists: CanonicalLineupArtistInput[];
    slots: CanonicalLineupSlotInput[];
    stageOrder: string[];
  }
): Prisma.JsonObject => {
  const rotatedStageOrder = snapshot.stageOrder.length > 1
    ? [...snapshot.stageOrder.slice(1), snapshot.stageOrder[0]]
    : snapshot.stageOrder.slice();
  const renamedStageMap = new Map(rotatedStageOrder.map((stageName, index) => [
    snapshot.stageOrder[index] || stageName,
    `${stageName} Rev`,
  ]));

  const lineupArtists = snapshot.artists.map((artist, index) => {
    const nextName = index % 8 === 0 ? `${artist.djName} Rev` : artist.djName;
    return {
      id: artist.id,
      djId: artist.djId,
      memberDjIds: artist.memberDjIds ?? [],
      memberNames: [nextName],
      djName: nextName,
      sortOrder: artist.sortOrder,
    };
  });

  const slotNameByArtistId = new Map(lineupArtists
    .filter((artist) => artist.id)
    .map((artist) => [artist.id as string, artist.djName]));

  const lineupSlots = snapshot.slots.map((slot, index) => {
    const startTime = new Date(slot.startTime.getTime() + 5 * 60_000);
    const endTime = new Date(slot.endTime.getTime() + 5 * 60_000);
    return {
      id: slot.id,
      lineupArtistId: slot.lineupArtistId ?? null,
      eventDayId: slot.eventDayId ?? null,
      weekIndex: slot.weekIndex ?? null,
      dayIndexInWeek: slot.dayIndexInWeek ?? null,
      overallDayIndex: slot.overallDayIndex ?? null,
      localDate: slot.localDate ? slot.localDate.toISOString().slice(0, 10) : null,
      djId: slot.djId,
      memberDjIds: slot.memberDjIds ?? [],
      memberNames: undefined,
      djName: slot.lineupArtistId ? slotNameByArtistId.get(slot.lineupArtistId) || slot.djName : slot.djName,
      stageName: renamedStageMap.get(slot.stageName || '') || (slot.stageName ? `${slot.stageName} Rev` : null),
      festivalDayIndex: slot.festivalDayIndex,
      startTime: startTime.toISOString(),
      endTime: endTime.toISOString(),
      sortOrder: slot.sortOrder || index + 1,
    };
  });

  return {
    targetEventId: eventId,
    name: `Benchmark Event Edit ${Date.now()}`,
    ...schedule,
    imageAssets: [
      {
        type: 'poster',
        label: 'POSTER',
        url: 'https://example.com/benchmark-poster-updated.jpg',
      },
    ],
    lineupArtists: lineupArtists as unknown as Prisma.InputJsonValue,
    lineupSlots: lineupSlots as unknown as Prisma.InputJsonValue,
    stageOrder: rotatedStageOrder.map((stageName) => `${stageName} Rev`) as unknown as Prisma.InputJsonValue,
  } as Prisma.JsonObject;
};

const createBenchmarkUser = async (suffix: string): Promise<string> => {
  const user = await prisma.user.create({
    data: {
      username: `event_benchmark_${suffix}`,
      email: `event_benchmark_${suffix}@example.com`,
      passwordHash: 'benchmark-only',
      displayName: `Event Benchmark ${suffix}`,
      displayNameNormalized: `event benchmark ${suffix}`,
      role: 'admin',
      isVerified: true,
      regionCode: 'US',
      birthYear: 1990,
      ageBand: 'adult',
      ageDeclaredAt: new Date(),
    },
    select: { id: true },
  });
  return user.id;
};

const createSubmission = async (
  userId: string,
  payload: Prisma.JsonObject,
  title: string
): Promise<string> => {
  const submission = await prisma.contentSubmission.create({
    data: {
      submitterId: userId,
      entityType: 'event',
      status: 'reviewing',
      title,
      payload,
      reviewReason: null,
    },
    select: { id: true },
  });
  return submission.id;
};

const processSubmissionWithTimetable = async (submissionId: string): Promise<{
  result: BenchmarkMetrics;
  eventId: string;
}> => {
  const phaseAStartedAt = process.hrtime.bigint();
  const phaseAResult = await processContentSubmission(submissionId, {
    db: prisma,
    markFailedOnError: false,
  });
  const phaseAWallMs = Number(process.hrtime.bigint() - phaseAStartedAt) / 1_000_000;
  assert(phaseAResult.status === 'succeeded', `phase A failed for submission ${submissionId}`);
  assert(Boolean(phaseAResult.createdEntityId), `phase A did not create/update event for submission ${submissionId}`);
  const eventId = phaseAResult.createdEntityId as string;

  const phaseBStartedAt = process.hrtime.bigint();
  const phaseBResult = await processContentSubmission(submissionId, {
    db: prisma,
    markFailedOnError: false,
    jobType: 'apply_event_timetable',
  } as never);
  const phaseBWallMs = Number(process.hrtime.bigint() - phaseBStartedAt) / 1_000_000;
  assert(phaseBResult.status === 'succeeded', `phase B failed for submission ${submissionId}`);

  const snapshot = await loadCanonicalEventLineupSnapshot(prisma, eventId);
  return {
    eventId,
    result: {
      phaseAWallMs,
      phaseBWallMs,
      phaseATimings: phaseAResult.timings ?? null,
      finalSlotCount: snapshot.slots.length,
      finalArtistCount: snapshot.artists.length,
    },
  };
};

const cleanupBenchmarkArtifacts = async (
  userId: string,
  eventIds: string[],
  keepArtifacts: boolean
): Promise<void> => {
  if (keepArtifacts) {
    log('keeping benchmark artifacts', { userId, eventIds });
    return;
  }
  if (eventIds.length > 0) {
    await prisma.event.deleteMany({
      where: { id: { in: Array.from(new Set(eventIds)) } },
    });
  }
  await prisma.contentSubmission.deleteMany({
    where: { submitterId: userId },
  });
  await prisma.user.deleteMany({
    where: { id: userId },
  });
};

const printSummary = (
  label: string,
  metrics: BenchmarkMetrics[]
): void => {
  const phaseAStats = summarize(metrics.map((item) => item.phaseAWallMs));
  const phaseBStats = summarize(metrics.map((item) => item.phaseBWallMs));
  const phaseAApplyStats = summarize(metrics.map((item) => item.phaseATimings?.applyMs ?? 0));
  const phaseATotalStats = summarize(metrics.map((item) => item.phaseATimings?.totalMs ?? 0));
  console.log(`[benchmark-event-submission] summary ${label}`);
  console.log(`  phaseA.wall ${JSON.stringify(formatStats(phaseAStats))}`);
  console.log(`  phaseA.apply ${JSON.stringify(formatStats(phaseAApplyStats))}`);
  console.log(`  phaseA.total ${JSON.stringify(formatStats(phaseATotalStats))}`);
  console.log(`  phaseB.wall ${JSON.stringify(formatStats(phaseBStats))}`);
};

async function main(): Promise<void> {
  const args = parseArgs(process.argv.slice(2));
  const slotCount = Number(args.slots || process.env.EVENT_SUBMISSION_BENCHMARK_SLOTS || 240);
  const rounds = Number(args.rounds || process.env.EVENT_SUBMISSION_BENCHMARK_ROUNDS || 3);
  const stageCount = Number(args.stages || process.env.EVENT_SUBMISSION_BENCHMARK_STAGES || 4);
  const keepArtifacts = args.keep === true;
  const schedule = buildBenchmarkSchedule(2, 3);

  assert(Number.isFinite(slotCount) && slotCount >= 50, 'slots must be at least 50');
  assert(Number.isFinite(rounds) && rounds > 0, 'rounds must be a positive number');
  assert(Number.isFinite(stageCount) && stageCount > 0, 'stages must be a positive number');

  const createMetrics: BenchmarkMetrics[] = [];
  const editMetrics: BenchmarkMetrics[] = [];

  for (let round = 0; round < rounds; round += 1) {
    const suffix = `${Date.now()}_${round}_${crypto.randomInt(1000, 9999)}`;
    const userId = await createBenchmarkUser(suffix);
    const eventIds: string[] = [];

    try {
      log('round start', { round: round + 1, rounds, slotCount, stageCount, keepArtifacts });
      const createPayload = buildCreatePayload(suffix, slotCount, stageCount, schedule);
      const createSubmissionId = await createSubmission(userId, createPayload, `Benchmark Create ${suffix}`);
      const createResult = await processSubmissionWithTimetable(createSubmissionId);
      eventIds.push(createResult.eventId);
      createMetrics.push(createResult.result);
      assert(createResult.result.finalSlotCount === slotCount, `create slot count mismatch: expected ${slotCount}, got ${createResult.result.finalSlotCount}`);

      log('round create done', {
        round: round + 1,
        eventId: createResult.eventId,
        phaseA: formatDuration(createResult.result.phaseAWallMs),
        phaseB: formatDuration(createResult.result.phaseBWallMs),
        slots: createResult.result.finalSlotCount,
      });

      const snapshot = await loadCanonicalEventLineupSnapshot(prisma, createResult.eventId);
      const editPayload = buildEditPayload(createResult.eventId, schedule, snapshot);
      const editSubmissionId = await createSubmission(userId, editPayload, `Benchmark Edit ${suffix}`);
      const editResult = await processSubmissionWithTimetable(editSubmissionId);
      editMetrics.push(editResult.result);
      assert(editResult.result.finalSlotCount === slotCount, `edit slot count mismatch: expected ${slotCount}, got ${editResult.result.finalSlotCount}`);

      log('round edit done', {
        round: round + 1,
        eventId: editResult.eventId,
        phaseA: formatDuration(editResult.result.phaseAWallMs),
        phaseB: formatDuration(editResult.result.phaseBWallMs),
        slots: editResult.result.finalSlotCount,
      });
    } finally {
      await cleanupBenchmarkArtifacts(userId, eventIds, keepArtifacts);
    }
  }

  printSummary(`create slots=${slotCount} rounds=${rounds}`, createMetrics);
  printSummary(`edit slots=${slotCount} rounds=${rounds}`, editMetrics);
}

main()
  .catch((error) => {
    console.error('[benchmark-event-submission] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
