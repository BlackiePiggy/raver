import 'dotenv/config';
import { PrismaClient } from '@prisma/client';

// Read-only diagnostic utility for historical event submission payloads.
// Use this to inspect stored state during replay/debugging, not as a production
// writer or as a source of truth for the current event mutation contract.

const prisma = new PrismaClient({
  datasources: process.env.WORKER_DATABASE_URL
    ? {
        db: {
          url: process.env.WORKER_DATABASE_URL,
        },
      }
    : undefined,
});

type JsonObject = Record<string, unknown>;

type EventDayPayload = {
  eventDayId: string;
  weekIndex: number | null;
  dayIndexInWeek: number | null;
  overallDayIndex: number | null;
  date: string | null;
};

type SlotMismatch = {
  slotIndex: number;
  slotId: string | null;
  djName: string | null;
  stageName: string | null;
  startTime: string | null;
  endTime: string | null;
  eventDayId: string | null;
  problems: string[];
  raw: {
    eventDayId: string | null;
    weekIndex: number | null;
    dayIndexInWeek: number | null;
    overallDayIndex: number | null;
    festivalDayIndex: number | null;
    localDate: string | null;
  };
  expected: {
    weekIndex: number | null;
    dayIndexInWeek: number | null;
    overallDayIndex: number | null;
    festivalDayIndex: number | null;
    localDate: string | null;
  } | null;
};

const cleanText = (value: unknown): string | null => {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed || null;
};

const asObject = (value: unknown): JsonObject =>
  value && typeof value === 'object' && !Array.isArray(value)
    ? value as JsonObject
    : {};

const asArray = (value: unknown): unknown[] =>
  Array.isArray(value) ? value : [];

const asInt = (value: unknown): number | null => {
  if (value === null || value === undefined || value === '') return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? Math.trunc(parsed) : null;
};

const normalizeDateOnly = (value: unknown): string | null => {
  if (value instanceof Date && !Number.isNaN(value.getTime())) {
    return value.toISOString().slice(0, 10);
  }
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  if (!trimmed) return null;
  const directMatch = trimmed.match(/^(\d{4}-\d{2}-\d{2})/);
  if (directMatch) return directMatch[1];
  const parsed = new Date(trimmed);
  if (Number.isNaN(parsed.getTime())) return trimmed;
  return parsed.toISOString().slice(0, 10);
};

const readEventDays = (payload: JsonObject): EventDayPayload[] =>
  asArray(payload.eventDays)
    .map((item) => asObject(item))
    .map((item) => ({
      eventDayId: cleanText(item.eventDayId) || cleanText(item.id) || '',
      weekIndex: asInt(item.weekIndex),
      dayIndexInWeek: asInt(item.dayIndexInWeek),
      overallDayIndex: asInt(item.overallDayIndex),
      date: normalizeDateOnly(item.date),
    }))
    .filter((item) => item.eventDayId);

const diagnosePayload = (payload: JsonObject) => {
  const eventDays = readEventDays(payload);
  const eventDayById = new Map(eventDays.map((day) => [day.eventDayId, day]));
  const slots = asArray(payload.lineupSlots).map((item) => asObject(item));

  const mismatches: SlotMismatch[] = slots.map((slot, index) => {
    const eventDayId = cleanText(slot.eventDayId);
    const eventDay = eventDayId ? eventDayById.get(eventDayId) ?? null : null;
    const raw = {
      eventDayId,
      weekIndex: asInt(slot.weekIndex),
      dayIndexInWeek: asInt(slot.dayIndexInWeek),
      overallDayIndex: asInt(slot.overallDayIndex),
      festivalDayIndex: asInt(slot.festivalDayIndex),
      localDate: normalizeDateOnly(slot.localDate),
    };
    const expected = eventDay
      ? {
          weekIndex: eventDay.weekIndex,
          dayIndexInWeek: eventDay.dayIndexInWeek,
          overallDayIndex: eventDay.overallDayIndex,
          festivalDayIndex: eventDay.overallDayIndex,
          localDate: eventDay.date,
        }
      : null;

    const problems: string[] = [];
    if (!eventDayId) {
      problems.push('missing eventDayId');
    } else if (!eventDay) {
      problems.push(`eventDayId ${eventDayId} not found in payload.eventDays`);
    } else {
      if (raw.weekIndex !== null && raw.weekIndex !== eventDay.weekIndex) {
        problems.push(`weekIndex=${raw.weekIndex} expected=${eventDay.weekIndex}`);
      }
      if (raw.dayIndexInWeek !== null && raw.dayIndexInWeek !== eventDay.dayIndexInWeek) {
        problems.push(`dayIndexInWeek=${raw.dayIndexInWeek} expected=${eventDay.dayIndexInWeek}`);
      }
      if (raw.overallDayIndex !== null && raw.overallDayIndex !== eventDay.overallDayIndex) {
        problems.push(`overallDayIndex=${raw.overallDayIndex} expected=${eventDay.overallDayIndex}`);
      }
      if (raw.festivalDayIndex !== null && raw.festivalDayIndex !== eventDay.overallDayIndex) {
        problems.push(`festivalDayIndex=${raw.festivalDayIndex} expected=${eventDay.overallDayIndex}`);
      }
      if (raw.localDate !== null && raw.localDate !== eventDay.date) {
        problems.push(`localDate=${raw.localDate} expected=${eventDay.date}`);
      }
    }

    return {
      slotIndex: index,
      slotId: cleanText(slot.id),
      djName: cleanText(slot.djName),
      stageName: cleanText(slot.stageName),
      startTime: cleanText(slot.startTime),
      endTime: cleanText(slot.endTime),
      eventDayId,
      problems,
      raw,
      expected,
    };
  }).filter((slot) => slot.problems.length > 0);

  return {
    targetEventId: cleanText(payload.targetEventId) || cleanText(payload.editTargetEventId),
    schedule: asObject(payload.schedule),
    eventDays,
    lineupSlotCount: slots.length,
    mismatches,
  };
};

const main = async (): Promise<void> => {
  const submissionId = cleanText(process.argv[2]);
  if (!submissionId) {
    throw new Error('Usage: pnpm content-submissions:event-submission:diagnose <submissionId>');
  }

  const submission = await prisma.contentSubmission.findUnique({
    where: { id: submissionId },
    include: {
      processingJobs: {
        orderBy: [{ createdAt: 'asc' }],
      },
      versions: {
        orderBy: [{ version: 'desc' }],
      },
      submitter: {
        select: {
          id: true,
          username: true,
          displayName: true,
        },
      },
    },
  });

  if (!submission) {
    throw new Error(`Submission not found: ${submissionId}`);
  }

  const currentPayload = asObject(submission.payload);
  const currentDiagnosis = diagnosePayload(currentPayload);
  const versionDiagnoses = submission.versions.map((version) => ({
    version: version.version,
    submittedAt: version.submittedAt.toISOString(),
    submittedBy: version.submittedBy,
    changeNote: version.changeNote,
    diagnosis: diagnosePayload(asObject(version.payload)),
  }));

  const output = {
    submission: {
      id: submission.id,
      entityType: submission.entityType,
      status: submission.status,
      title: submission.title,
      createdAt: submission.createdAt.toISOString(),
      updatedAt: submission.updatedAt.toISOString(),
      reviewedAt: submission.reviewedAt?.toISOString() ?? null,
      reviewReason: submission.reviewReason,
      submitter: submission.submitter,
    },
    processingJobs: submission.processingJobs.map((job) => ({
      id: job.id,
      jobType: job.jobType,
      status: job.status,
      attempts: job.attempts,
      maxAttempts: job.maxAttempts,
      availableAt: job.availableAt.toISOString(),
      startedAt: job.startedAt?.toISOString() ?? null,
      completedAt: job.completedAt?.toISOString() ?? null,
      failedAt: job.failedAt?.toISOString() ?? null,
      lastError: job.lastError,
      metadata: job.metadata,
    })),
    currentPayloadDiagnosis: currentDiagnosis,
    versionDiagnoses,
  };

  console.log(JSON.stringify(output, null, 2));
};

main()
  .catch((error) => {
    console.error('[content-submission-event-submission-diagnose] failed:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
