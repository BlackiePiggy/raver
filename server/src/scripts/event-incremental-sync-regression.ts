import 'dotenv/config';
import crypto from 'node:crypto';
import { Prisma, PrismaClient } from '@prisma/client';
import {
  loadCanonicalEventLineupSnapshot,
  syncCanonicalEventLineupAndTimetable,
  type CanonicalLineupArtistInput,
  type CanonicalLineupSlotInput,
} from '../services/event-lineup-canonical.service';
import {
  createOrUpdateEventFromSubmission,
} from '../services/content-submission-event.service';
import { processContentSubmission } from '../services/content-submission-processing.service';

const prisma = new PrismaClient();

const assert = (condition: boolean, message: string): void => {
  if (!condition) throw new Error(message);
};

const logStep = (step: string, detail?: Record<string, unknown>): void => {
  console.log('[event-incremental-sync-regression]', step, detail || {});
};

const minutesAfter = (base: Date, minutes: number): Date =>
  new Date(base.getTime() + minutes * 60_000);

const REGRESSION_TIME_ZONE = 'Asia/Shanghai';

type RegressionSchedulePayload = {
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

const buildSingleDaySchedule = (date: string): RegressionSchedulePayload => ({
  schedule: {
    mode: 'single_day',
    timeZone: REGRESSION_TIME_ZONE,
    dayRolloverHour: 6,
  },
  weeks: [
    {
      weekIndex: 1,
      label: 'Week 1',
      startDate: date,
      endDate: date,
      sortOrder: 1,
    },
  ],
  eventDays: [
    {
      eventDayId: 'w1d1',
      weekIndex: 1,
      dayIndexInWeek: 1,
      overallDayIndex: 1,
      label: 'Day 1',
      weekday: 'thursday',
      date,
      sortOrder: 1,
    },
  ],
});

const buildAugustMultiDaySchedule = (): RegressionSchedulePayload => ({
  schedule: {
    mode: 'multi_day',
    timeZone: REGRESSION_TIME_ZONE,
    dayRolloverHour: 6,
  },
  weeks: [
    {
      weekIndex: 1,
      label: 'Weekend 1',
      startDate: '2026-08-01',
      endDate: '2026-08-02',
      sortOrder: 1,
    },
  ],
  eventDays: [
    {
      eventDayId: 'w1d1',
      weekIndex: 1,
      dayIndexInWeek: 1,
      overallDayIndex: 1,
      label: 'Day 1',
      weekday: 'saturday',
      date: '2026-08-01',
      sortOrder: 1,
    },
    {
      eventDayId: 'w1d2',
      weekIndex: 1,
      dayIndexInWeek: 2,
      overallDayIndex: 2,
      label: 'Day 2',
      weekday: 'sunday',
      date: '2026-08-02',
      sortOrder: 2,
    },
  ],
});

const buildSeptemberMultiWeekSchedule = (): RegressionSchedulePayload => ({
  schedule: {
    mode: 'multi_week',
    timeZone: REGRESSION_TIME_ZONE,
    dayRolloverHour: 6,
  },
  weeks: [
    {
      weekIndex: 1,
      label: 'Weekend 1',
      startDate: '2026-09-04',
      endDate: '2026-09-06',
      sortOrder: 1,
    },
    {
      weekIndex: 2,
      label: 'Weekend 2',
      startDate: '2026-09-11',
      endDate: '2026-09-13',
      sortOrder: 2,
    },
  ],
  eventDays: [
    {
      eventDayId: 'w1d1',
      weekIndex: 1,
      dayIndexInWeek: 1,
      overallDayIndex: 1,
      label: 'Week 1 Day 1',
      weekday: 'friday',
      date: '2026-09-04',
      sortOrder: 1,
    },
    {
      eventDayId: 'w1d2',
      weekIndex: 1,
      dayIndexInWeek: 2,
      overallDayIndex: 2,
      label: 'Week 1 Day 2',
      weekday: 'saturday',
      date: '2026-09-05',
      sortOrder: 2,
    },
    {
      eventDayId: 'w1d3',
      weekIndex: 1,
      dayIndexInWeek: 3,
      overallDayIndex: 3,
      label: 'Week 1 Day 3',
      weekday: 'sunday',
      date: '2026-09-06',
      sortOrder: 3,
    },
    {
      eventDayId: 'w2d1',
      weekIndex: 2,
      dayIndexInWeek: 1,
      overallDayIndex: 4,
      label: 'Week 2 Day 1',
      weekday: 'friday',
      date: '2026-09-11',
      sortOrder: 4,
    },
    {
      eventDayId: 'w2d2',
      weekIndex: 2,
      dayIndexInWeek: 2,
      overallDayIndex: 5,
      label: 'Week 2 Day 2',
      weekday: 'saturday',
      date: '2026-09-12',
      sortOrder: 5,
    },
    {
      eventDayId: 'w2d3',
      weekIndex: 2,
      dayIndexInWeek: 3,
      overallDayIndex: 6,
      label: 'Week 2 Day 3',
      weekday: 'sunday',
      date: '2026-09-13',
      sortOrder: 6,
    },
  ],
});

const shanghaiIsoAt = (date: string, totalMinutes: number): string => {
  const normalizedMinutes = ((totalMinutes % 1_440) + 1_440) % 1_440;
  const hour = Math.floor(normalizedMinutes / 60);
  const minute = normalizedMinutes % 60;
  return `${date}T${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}:00+08:00`;
};

const buildArtist = (index: number, id?: string): CanonicalLineupArtistInput => ({
  ...(id ? { id } : {}),
  djId: null,
  memberDjIds: [],
  memberNames: [`Regression DJ ${String(index).padStart(3, '0')}`],
  djName: `Regression DJ ${String(index).padStart(3, '0')}`,
  sortOrder: index,
});

const buildSlot = (
  index: number,
  artist: CanonicalLineupArtistInput,
  baseTime: Date,
  id?: string
): CanonicalLineupSlotInput => ({
  ...(id ? { id } : {}),
  lineupArtistId: artist.id ?? null,
  djId: artist.djId,
  memberDjIds: artist.memberDjIds ?? [],
  djName: artist.djName,
  stageName: index % 2 === 0 ? 'Main Stage' : 'Second Stage',
  festivalDayIndex: 1,
  startTime: minutesAfter(baseTime, index * 60),
  endTime: minutesAfter(baseTime, index * 60 + 45),
  sortOrder: index,
});

const createRegressionUserAndEvent = async (suffix: string): Promise<{ userId: string; eventId: string }> => {
  const user = await prisma.user.create({
    data: {
      username: `event_incremental_${suffix}`,
      email: `event_incremental_${suffix}@example.com`,
      passwordHash: 'regression-only',
      displayName: `Event Incremental ${suffix}`,
      displayNameNormalized: `event incremental ${suffix}`,
      role: 'user',
      isVerified: true,
      regionCode: 'US',
      birthYear: 1990,
      ageBand: 'adult',
      ageDeclaredAt: new Date(),
    },
    select: { id: true },
  });

  const event = await prisma.event.create({
    data: {
      organizerId: user.id,
      slug: `event-incremental-${suffix}`,
      name: `Event Incremental Regression ${suffix}`,
      city: 'Shanghai',
      country: 'China',
      startDate: new Date('2026-08-01T00:00:00.000Z'),
      endDate: new Date('2026-08-02T23:59:59.000Z'),
      timeZone: 'Asia/Shanghai',
      coverImageUrl: 'https://example.com/regression-cover.jpg',
      lineupImageUrl: 'https://example.com/regression-lineup.jpg',
      imageAssets: [
        {
          type: 'poster',
          label: 'POSTER',
          url: 'https://example.com/regression-poster.jpg',
        },
      ],
      status: 'upcoming',
      isVerified: true,
    },
    select: { id: true },
  });

  return { userId: user.id, eventId: event.id };
};

const createRegressionUser = async (
  suffix: string,
  role: 'user' | 'admin' | 'operator' = 'user'
): Promise<string> => {
  const user = await prisma.user.create({
    data: {
      username: `event_incremental_${role}_${suffix}`,
      email: `event_incremental_${role}_${suffix}@example.com`,
      passwordHash: 'regression-only',
      displayName: `Event Incremental ${role} ${suffix}`,
      displayNameNormalized: `event incremental ${role} ${suffix}`,
      role,
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

const seedNinetyNine = async (eventId: string, baseTime: Date): Promise<void> => {
  const artists = Array.from({ length: 99 }, (_, index) => buildArtist(index + 1, crypto.randomUUID()));
  const slots = artists.map((artist, index) => buildSlot(index + 1, artist, baseTime, crypto.randomUUID()));
  await prisma.$transaction(async (tx) => {
    await syncCanonicalEventLineupAndTimetable(tx, eventId, slots, artists, ['Main Stage', 'Second Stage']);
  }, { timeout: 30_000, maxWait: 10_000 });
};

const assertExistingRowsStable = async (
  eventId: string,
  artistIds: string[],
  performanceIds: string[]
): Promise<void> => {
  const [artists, performances] = await Promise.all([
    prisma.eventArtist.findMany({
      where: { eventId, id: { in: artistIds } },
      select: { id: true },
    }),
    prisma.eventPerformance.findMany({
      where: { eventId, id: { in: performanceIds } },
      select: { id: true },
    }),
  ]);
  assert(artists.length === artistIds.length, 'existing artist rows were deleted or recreated');
  assert(performances.length === performanceIds.length, 'existing performance rows were deleted or recreated');
};

const runDirectCanonicalRegression = async (eventId: string): Promise<void> => {
  const baseTime = new Date('2026-08-01T10:00:00.000Z');
  await seedNinetyNine(eventId, baseTime);

  const seeded = await loadCanonicalEventLineupSnapshot(prisma, eventId);
  assert(seeded.artists.length === 99, `expected 99 artists, got ${seeded.artists.length}`);
  assert(seeded.slots.length === 99, `expected 99 slots, got ${seeded.slots.length}`);
  const seededArtistIds = seeded.artists.map((artist) => artist.id).filter((id): id is string => Boolean(id));
  const seededPerformanceIds = seeded.slots.map((slot) => slot.id).filter((id): id is string => Boolean(id));

  logStep('direct canonical 99 + 1');
  const addedArtist = buildArtist(100, crypto.randomUUID());
  const addedSlot = buildSlot(100, addedArtist, baseTime, crypto.randomUUID());
  await prisma.$transaction(async (tx) => {
    await syncCanonicalEventLineupAndTimetable(
      tx,
      eventId,
      [...seeded.slots, addedSlot],
      [...seeded.artists, addedArtist],
      seeded.stageOrder
    );
  }, { timeout: 30_000, maxWait: 10_000 });

  const afterAdd = await loadCanonicalEventLineupSnapshot(prisma, eventId);
  assert(afterAdd.artists.length === 100, `expected 100 artists after add, got ${afterAdd.artists.length}`);
  assert(afterAdd.slots.length === 100, `expected 100 slots after add, got ${afterAdd.slots.length}`);
  await assertExistingRowsStable(eventId, seededArtistIds, seededPerformanceIds);

  logStep('direct canonical single-slot update');
  const slotToUpdate = afterAdd.slots[42];
  assert(Boolean(slotToUpdate?.id), 'slot to update missing stable id');
  const nextStart = minutesAfter(slotToUpdate.startTime, 15);
  const nextEnd = minutesAfter(slotToUpdate.endTime, 15);
  await prisma.$transaction(async (tx) => {
    await syncCanonicalEventLineupAndTimetable(
      tx,
      eventId,
      afterAdd.slots.map((slot) => (
        slot.id === slotToUpdate.id
          ? { ...slot, startTime: nextStart, endTime: nextEnd }
          : slot
      )),
      afterAdd.artists,
      afterAdd.stageOrder
    );
  }, { timeout: 30_000, maxWait: 10_000 });

  const afterSlotUpdate = await loadCanonicalEventLineupSnapshot(prisma, eventId);
  assert(afterSlotUpdate.artists.length === 100, 'single-slot update changed artist count');
  assert(afterSlotUpdate.slots.length === 100, 'single-slot update changed slot count');
  await assertExistingRowsStable(eventId, afterAdd.artists.map((artist) => artist.id).filter((id): id is string => Boolean(id)), afterAdd.slots.map((slot) => slot.id).filter((id): id is string => Boolean(id)));
  const updatedSlot = afterSlotUpdate.slots.find((slot) => slot.id === slotToUpdate.id);
  assert(updatedSlot?.startTime.getTime() === nextStart.getTime(), 'single-slot update did not persist updated start time');

  logStep('direct canonical single-artist and single-slot delete');
  await prisma.$transaction(async (tx) => {
    await syncCanonicalEventLineupAndTimetable(
      tx,
      eventId,
      afterSlotUpdate.slots.filter((slot) => slot.id !== addedSlot.id),
      afterSlotUpdate.artists.filter((artist) => artist.id !== addedArtist.id),
      afterSlotUpdate.stageOrder
    );
  }, { timeout: 30_000, maxWait: 10_000 });

  const afterDelete = await loadCanonicalEventLineupSnapshot(prisma, eventId);
  assert(afterDelete.artists.length === 99, `expected 99 artists after delete, got ${afterDelete.artists.length}`);
  assert(afterDelete.slots.length === 99, `expected 99 slots after delete, got ${afterDelete.slots.length}`);
  assert(!afterDelete.artists.some((artist) => artist.id === addedArtist.id), 'deleted artist still exists');
  assert(!afterDelete.slots.some((slot) => slot.id === addedSlot.id), 'deleted slot still exists');
  await assertExistingRowsStable(eventId, seededArtistIds, seededPerformanceIds);
};

const runManualReviewPatchRegression = async (eventId: string, userId: string): Promise<void> => {
  logStep('manual review patch apply path');
  const before = await loadCanonicalEventLineupSnapshot(prisma, eventId);
  const eventBefore = await prisma.event.findUniqueOrThrow({
    where: { id: eventId },
    select: { revision: true },
  });
  const schedule = buildAugustMultiDaySchedule();
  const beforeArtistIds = before.artists.map((artist) => artist.id).filter((id): id is string => Boolean(id));
  const beforePerformanceIds = before.slots.map((slot) => slot.id).filter((id): id is string => Boolean(id));
  const artistName = 'Regression Manual Approval DJ';

  await createOrUpdateEventFromSubmission(prisma, {
    targetEventId: eventId,
    baseEventRevision: eventBefore.revision,
    editMode: 'patch',
    name: `Event Incremental Regression Approved ${Date.now()}`,
    ...schedule,
    imageAssets: [
      {
        type: 'poster',
        label: 'POSTER',
        url: 'https://example.com/regression-poster.jpg',
      },
    ],
    lineupChanges: [
      {
        op: 'add',
        artist: {
          djName: artistName,
          memberNames: [artistName],
          sortOrder: before.artists.length + 1,
        },
      },
    ],
    timetableChanges: [
      {
        op: 'add',
        slot: {
          eventDayId: schedule.eventDays[1].eventDayId,
          weekIndex: schedule.eventDays[1].weekIndex,
          dayIndexInWeek: schedule.eventDays[1].dayIndexInWeek,
          overallDayIndex: schedule.eventDays[1].overallDayIndex,
          localDate: schedule.eventDays[1].date,
          djName: artistName,
          memberNames: [artistName],
          stageName: 'Main Stage',
          festivalDayIndex: schedule.eventDays[1].overallDayIndex,
          startTime: '2026-08-02T18:00:00+08:00',
          endTime: '2026-08-02T19:00:00+08:00',
          sortOrder: before.slots.length + 1,
        },
      },
    ],
    stageOrder: before.stageOrder,
  }, userId);

  const after = await loadCanonicalEventLineupSnapshot(prisma, eventId);
  assert(after.artists.length === before.artists.length + 1, 'manual review patch did not add exactly one artist');
  assert(after.slots.length === before.slots.length + 1, 'manual review patch did not add exactly one timetable slot');
  assert(after.artists.some((artist) => artist.djName === artistName), 'manual review patch artist missing');
  assert(after.slots.some((slot) => slot.djName === artistName), 'manual review patch slot missing');
  await assertExistingRowsStable(eventId, beforeArtistIds, beforePerformanceIds);
};

const runSingleStageLegacyRenameRegression = async (userId: string): Promise<void> => {
  logStep('single stage legacy rename compatibility path');
  const suffix = `${Date.now()}_${crypto.randomInt(1000, 9999)}`;
  let eventId = '';
  const schedule = buildSingleDaySchedule('2026-11-01');

  try {
    const event = await prisma.event.create({
      data: {
        organizerId: userId,
        slug: `event-incremental-single-stage-${suffix}`,
        name: `Event Incremental Single Stage ${suffix}`,
        city: 'Shanghai',
        country: 'China',
        startDate: new Date('2026-11-01T00:00:00.000Z'),
        endDate: new Date('2026-11-01T23:59:59.000Z'),
        timeZone: 'Asia/Shanghai',
        coverImageUrl: 'https://example.com/regression-cover.jpg',
        lineupImageUrl: 'https://example.com/regression-lineup.jpg',
        imageAssets: [
          {
            type: 'poster',
            label: 'POSTER',
            url: 'https://example.com/regression-poster.jpg',
          },
        ],
        status: 'upcoming',
        isVerified: true,
      },
      select: { id: true, revision: true },
    });
    eventId = event.id;

    const artist = {
      id: crypto.randomUUID(),
      djId: null,
      memberDjIds: [],
      memberNames: ['Regression Legacy Rename DJ'],
      djName: 'Regression Legacy Rename DJ',
      sortOrder: 1,
    } satisfies CanonicalLineupArtistInput;
    const slot = {
      id: crypto.randomUUID(),
      lineupArtistId: artist.id,
      djId: null,
      memberDjIds: [],
      djName: artist.djName,
      stageName: 'Main Stage',
      festivalDayIndex: 1,
      startTime: new Date('2026-11-01T12:00:00.000Z'),
      endTime: new Date('2026-11-01T13:00:00.000Z'),
      sortOrder: 1,
    } satisfies CanonicalLineupSlotInput;

    await prisma.$transaction(async (tx) => {
      await syncCanonicalEventLineupAndTimetable(tx, eventId, [slot], [artist], ['Main Stage']);
    });

    await createOrUpdateEventFromSubmission(prisma, {
      targetEventId: eventId,
      baseEventRevision: event.revision,
      editMode: 'patch',
      name: `Event Incremental Single Stage Rename ${suffix}`,
      ...schedule,
      imageAssets: [
        {
          type: 'poster',
          label: 'POSTER',
          url: 'https://example.com/regression-poster.jpg',
        },
      ],
      stageChanges: [
        {
          op: 'rename',
          name: '百威风暴电音节主舞台',
          nextName: 'Single Stage From Legacy Rename',
        },
      ],
      stageOrder: ['Main Stage'],
    }, userId);

    const after = await loadCanonicalEventLineupSnapshot(prisma, eventId);
    assert(after.stageOrder.length === 1, 'single stage legacy rename changed stage count');
    assert(after.stageOrder[0] === 'Single Stage From Legacy Rename', 'single stage legacy rename did not update stage order');
    assert(after.slots.every((candidate) => candidate.stageName === 'Single Stage From Legacy Rename'), 'single stage legacy rename did not relabel slot stages');
  } finally {
    if (eventId) {
      await prisma.event.deleteMany({ where: { id: eventId } });
    }
  }
};

const runPatchClearAllTimetableRegression = async (eventId: string, userId: string): Promise<void> => {
  logStep('patch clear all timetable path');
  const before = await loadCanonicalEventLineupSnapshot(prisma, eventId);
  const eventBefore = await prisma.event.findUniqueOrThrow({
    where: { id: eventId },
    select: { revision: true },
  });
  const schedule = buildAugustMultiDaySchedule();

  assert(before.stageOrder.length > 0, 'patch clear all regression requires seeded stages');
  assert(before.slots.length > 0, 'patch clear all regression requires seeded slots');

  await createOrUpdateEventFromSubmission(prisma, {
    targetEventId: eventId,
    baseEventRevision: eventBefore.revision,
    editMode: 'patch',
    name: `Event Incremental Clear All ${Date.now()}`,
    ...schedule,
    imageAssets: [
      {
        type: 'poster',
        label: 'POSTER',
        url: 'https://example.com/regression-poster.jpg',
      },
    ],
    lineupChanges: before.artists
      .filter((artist) => Boolean(artist.id))
      .map((artist) => ({
        op: 'delete',
        artistId: artist.id as string,
      })),
    timetableChanges: before.slots
      .filter((slot) => Boolean(slot.id))
      .map((slot) => ({
        op: 'delete',
        slotId: slot.id as string,
      })),
    stageChanges: before.stageOrder.map((stageName) => ({
      op: 'delete',
      name: stageName,
      confirmDeleteLinkedPerformances: true,
    })),
    stageOrder: before.stageOrder,
  }, userId);

  const after = await loadCanonicalEventLineupSnapshot(prisma, eventId);
  assert(after.artists.length === 0, 'patch clear all regression did not remove artists');
  assert(after.slots.length === 0, 'patch clear all regression did not remove slots');
  assert(after.stageOrder.length === 0, 'patch clear all regression did not remove stage order');
};

const runTimetableIncrementalFillPatchRegression = async (eventId: string, userId: string): Promise<void> => {
  logStep('timetable incremental fill patch path');
  const before = await loadCanonicalEventLineupSnapshot(prisma, eventId);
  const eventBefore = await prisma.event.findUniqueOrThrow({
    where: { id: eventId },
    select: { revision: true },
  });
  const schedule = buildAugustMultiDaySchedule();
  const slotToRewrite = before.slots[1];
  assert(Boolean(slotToRewrite?.id), 'timetable incremental fill slot missing stable id');
  assert(Boolean(slotToRewrite?.lineupArtistId), 'timetable incremental fill slot missing linked lineup artist id');
  const previousArtistName = slotToRewrite.djName;
  const nextArtistName = 'Regression Timetable Incremental Fill DJ';
  const unaffectedArtistIds = before.artists
    .map((artist) => artist.id)
    .filter((id): id is string => Boolean(id && id !== slotToRewrite.lineupArtistId));
  const stablePerformanceIds = before.slots.map((slot) => slot.id).filter((id): id is string => Boolean(id));

  await createOrUpdateEventFromSubmission(prisma, {
    targetEventId: eventId,
    baseEventRevision: eventBefore.revision,
    editMode: 'patch',
    name: `Event Incremental Timetable Source ${Date.now()}`,
    ...schedule,
    imageAssets: [
      {
        type: 'poster',
        label: 'POSTER',
        url: 'https://example.com/regression-poster.jpg',
      },
    ],
    timetableChanges: [
      {
        op: 'update',
        slotId: slotToRewrite.id,
        patch: {
          djName: nextArtistName,
          memberNames: [nextArtistName],
          memberDjIds: [],
          djId: null,
        },
      },
    ],
    stageOrder: before.stageOrder,
  }, userId);

  const after = await loadCanonicalEventLineupSnapshot(prisma, eventId);
  assert(after.slots.length === before.slots.length, 'timetable incremental fill changed slot count');
  assert(after.artists.length === before.artists.length + 1, 'timetable incremental fill should append one new lineup artist');
  assert(after.slots.some((slot) => slot.id === slotToRewrite.id && slot.djName === nextArtistName), 'timetable incremental fill did not update slot artist');
  assert(after.artists.some((artist) => artist.djName === nextArtistName), 'timetable incremental fill did not append the rewritten timetable artist');
  assert(after.artists.some((artist) => artist.djName === previousArtistName), 'timetable incremental fill should preserve the previous lineup artist');
  await assertExistingRowsStable(eventId, unaffectedArtistIds, stablePerformanceIds);
};

const runNormalReviewApprovalRegression = async (eventId: string, userId: string): Promise<void> => {
  logStep('normal review approval path');
  const before = await loadCanonicalEventLineupSnapshot(prisma, eventId);
  const eventBefore = await prisma.event.findUniqueOrThrow({
    where: { id: eventId },
    select: { revision: true },
  });
  const schedule = buildAugustMultiDaySchedule();
  const beforeArtistIds = before.artists.map((artist) => artist.id).filter((id): id is string => Boolean(id));
  const beforePerformanceIds = before.slots.map((slot) => slot.id).filter((id): id is string => Boolean(id));
  const slotToUpdate = before.slots[0];
  assert(Boolean(slotToUpdate?.id), 'normal review slot to update missing stable id');
  const nextStart = minutesAfter(slotToUpdate.startTime, 5);
  const nextEnd = minutesAfter(slotToUpdate.endTime, 5);
  const payload = {
    targetEventId: eventId,
    baseEventRevision: eventBefore.revision,
    editMode: 'patch',
    name: `Event Incremental Normal Review ${Date.now()}`,
    ...schedule,
    imageAssets: [
      {
        type: 'poster',
        label: 'POSTER',
        url: 'https://example.com/regression-poster.jpg',
      },
    ],
    timetableChanges: [
      {
        op: 'update',
        slotId: slotToUpdate.id,
        patch: {
          startTime: nextStart.toISOString(),
          endTime: nextEnd.toISOString(),
        },
      },
    ],
    stageOrder: before.stageOrder,
  };

  const submission = await prisma.contentSubmission.create({
    data: {
      submitterId: userId,
      entityType: 'event',
      status: 'reviewing',
      title: payload.name,
      payload,
      reviewReason: null,
    },
    select: { id: true },
  });

  const created = await createOrUpdateEventFromSubmission(prisma, payload, userId);
  await prisma.contentSubmission.update({
    where: { id: submission.id },
    data: {
      status: 'approved',
      reviewedAt: new Date(),
      reviewedBy: userId,
      createdEntityId: created.id,
    },
  });

  const after = await loadCanonicalEventLineupSnapshot(prisma, eventId);
  assert(after.artists.length === before.artists.length, 'normal review approval changed artist count');
  assert(after.slots.length === before.slots.length, 'normal review approval changed slot count');
  await assertExistingRowsStable(eventId, beforeArtistIds, beforePerformanceIds);
  const updatedSlot = after.slots.find((slot) => slot.id === slotToUpdate.id);
  assert(updatedSlot?.startTime.getTime() === nextStart.getTime(), 'normal review approval did not apply slot update');

  const approved = await prisma.contentSubmission.findUnique({
    where: { id: submission.id },
    select: { status: true, createdEntityId: true },
  });
  assert(approved?.status === 'approved', 'normal review submission was not marked approved');
  assert(approved?.createdEntityId === eventId, 'normal review submission did not link approved event');
};

const runFullPayloadIncrementalFillRegression = async (eventId: string, userId: string): Promise<void> => {
  logStep('full payload incremental fill path');
  const before = await loadCanonicalEventLineupSnapshot(prisma, eventId);
  const eventBefore = await prisma.event.findUniqueOrThrow({
    where: { id: eventId },
    select: { revision: true },
  });
  const schedule = buildAugustMultiDaySchedule();
  const slotToRewrite = before.slots[2];
  assert(Boolean(slotToRewrite?.id), 'full payload incremental fill slot missing stable id');
  assert(Boolean(slotToRewrite?.lineupArtistId), 'full payload incremental fill slot missing lineup artist id');
  const previousArtistName = slotToRewrite.djName;
  const nextArtistName = 'Regression Full Payload Incremental Fill DJ';
  const unaffectedArtistIds = before.artists
    .map((artist) => artist.id)
    .filter((id): id is string => Boolean(id && id !== slotToRewrite.lineupArtistId));
  const stablePerformanceIds = before.slots.map((slot) => slot.id).filter((id): id is string => Boolean(id));

  await createOrUpdateEventFromSubmission(prisma, {
    targetEventId: eventId,
    baseEventRevision: eventBefore.revision,
    name: `Event Incremental Full Payload ${Date.now()}`,
    ...schedule,
    imageAssets: [
      {
        type: 'poster',
        label: 'POSTER',
        url: 'https://example.com/regression-poster.jpg',
      },
    ],
    lineupArtists: before.artists.map((artist) => ({
      id: artist.id,
      djId: artist.djId,
      memberDjIds: artist.memberDjIds,
      memberNames: artist.memberNames,
      djName: artist.djName,
      sortOrder: artist.sortOrder,
    })),
    lineupSlots: before.slots.map((slot) => ({
      ...schedule.eventDays[(slot.sortOrder - 1) % schedule.eventDays.length],
      id: slot.id,
      lineupArtistId: slot.lineupArtistId,
      eventDayId: schedule.eventDays[(slot.sortOrder - 1) % schedule.eventDays.length].eventDayId,
      weekIndex: schedule.eventDays[(slot.sortOrder - 1) % schedule.eventDays.length].weekIndex,
      dayIndexInWeek: schedule.eventDays[(slot.sortOrder - 1) % schedule.eventDays.length].dayIndexInWeek,
      overallDayIndex: schedule.eventDays[(slot.sortOrder - 1) % schedule.eventDays.length].overallDayIndex,
      localDate: schedule.eventDays[(slot.sortOrder - 1) % schedule.eventDays.length].date,
      djId: slot.id === slotToRewrite.id ? null : slot.djId,
      memberDjIds: slot.id === slotToRewrite.id ? [] : slot.memberDjIds,
      djName: slot.id === slotToRewrite.id ? nextArtistName : slot.djName,
      stageName: slot.stageName,
      festivalDayIndex: schedule.eventDays[(slot.sortOrder - 1) % schedule.eventDays.length].overallDayIndex,
      startTime: shanghaiIsoAt(schedule.eventDays[(slot.sortOrder - 1) % schedule.eventDays.length].date, 12 * 60 + (((slot.sortOrder - 1) % 8) * 45)),
      endTime: shanghaiIsoAt(schedule.eventDays[(slot.sortOrder - 1) % schedule.eventDays.length].date, 12 * 60 + (((slot.sortOrder - 1) % 8) * 45) + 40),
      sortOrder: slot.sortOrder,
    })),
    stageOrder: before.stageOrder,
  } as any, userId);

  const after = await loadCanonicalEventLineupSnapshot(prisma, eventId);
  assert(after.slots.length === before.slots.length, 'full payload incremental fill changed slot count');
  assert(after.artists.length === before.artists.length + 1, 'full payload incremental fill should append one new lineup artist');
  assert(after.slots.some((slot) => slot.id === slotToRewrite.id && slot.djName === nextArtistName), 'full payload incremental fill did not update slot artist');
  assert(after.artists.some((artist) => artist.djName === nextArtistName), 'full payload incremental fill did not append the rewritten timetable artist');
  assert(after.artists.some((artist) => artist.djName === previousArtistName), 'full payload incremental fill should preserve the previous lineup artist');
  await assertExistingRowsStable(eventId, unaffectedArtistIds, stablePerformanceIds);
};

const runFullPayloadExactAlignRegression = async (eventId: string, userId: string): Promise<void> => {
  logStep('full payload exact align path');
  const before = await loadCanonicalEventLineupSnapshot(prisma, eventId);
  const eventBefore = await prisma.event.findUniqueOrThrow({
    where: { id: eventId },
    select: { revision: true },
  });
  const schedule = buildAugustMultiDaySchedule();
  const slotToRewrite = before.slots[0];
  assert(Boolean(slotToRewrite?.id), 'full payload exact align slot missing stable id');
  const previousArtistName = slotToRewrite.djName;
  const nextArtistName = 'Regression Full Payload Exact Align DJ';

  await createOrUpdateEventFromSubmission(prisma, {
    targetEventId: eventId,
    baseEventRevision: eventBefore.revision,
    lineupSyncMode: 'exact_align',
    name: `Event Incremental Full Payload Exact Align ${Date.now()}`,
    ...schedule,
    imageAssets: [
      {
        type: 'poster',
        label: 'POSTER',
        url: 'https://example.com/regression-poster.jpg',
      },
    ],
    lineupArtists: before.artists.map((artist) => ({
      id: artist.id,
      djId: artist.djId,
      memberDjIds: artist.memberDjIds,
      memberNames: artist.memberNames,
      djName: artist.djName,
      sortOrder: artist.sortOrder,
    })),
    lineupSlots: before.slots.map((slot) => ({
      ...schedule.eventDays[(slot.sortOrder - 1) % schedule.eventDays.length],
      id: slot.id,
      lineupArtistId: slot.lineupArtistId,
      eventDayId: schedule.eventDays[(slot.sortOrder - 1) % schedule.eventDays.length].eventDayId,
      weekIndex: schedule.eventDays[(slot.sortOrder - 1) % schedule.eventDays.length].weekIndex,
      dayIndexInWeek: schedule.eventDays[(slot.sortOrder - 1) % schedule.eventDays.length].dayIndexInWeek,
      overallDayIndex: schedule.eventDays[(slot.sortOrder - 1) % schedule.eventDays.length].overallDayIndex,
      localDate: schedule.eventDays[(slot.sortOrder - 1) % schedule.eventDays.length].date,
      djId: slot.id === slotToRewrite.id ? null : slot.djId,
      memberDjIds: slot.id === slotToRewrite.id ? [] : slot.memberDjIds,
      djName: slot.id === slotToRewrite.id ? nextArtistName : slot.djName,
      stageName: slot.stageName,
      festivalDayIndex: schedule.eventDays[(slot.sortOrder - 1) % schedule.eventDays.length].overallDayIndex,
      startTime: shanghaiIsoAt(schedule.eventDays[(slot.sortOrder - 1) % schedule.eventDays.length].date, 14 * 60 + (((slot.sortOrder - 1) % 6) * 50)),
      endTime: shanghaiIsoAt(schedule.eventDays[(slot.sortOrder - 1) % schedule.eventDays.length].date, 14 * 60 + (((slot.sortOrder - 1) % 6) * 50) + 45),
      sortOrder: slot.sortOrder,
    })),
    stageOrder: before.stageOrder,
  } as any, userId);

  const after = await loadCanonicalEventLineupSnapshot(prisma, eventId);
  const distinctSlotNames = new Set(after.slots.map((slot) => slot.djName));
  assert(after.slots.length === before.slots.length, 'full payload exact align changed slot count');
  assert(after.slots.some((slot) => slot.id === slotToRewrite.id && slot.djName === nextArtistName), 'full payload exact align did not update slot artist');
  assert(after.artists.some((artist) => artist.djName === nextArtistName), 'full payload exact align did not keep the rewritten artist');
  assert(!after.artists.some((artist) => artist.djName === previousArtistName), 'full payload exact align should remove the previous lineup artist');
  assert(after.artists.length === distinctSlotNames.size, 'full payload exact align should collapse lineup to the timetable-derived artist set');
};

const runFullPayloadLargeMixedRegression = async (eventId: string, userId: string): Promise<void> => {
  logStep('full payload large mixed multi-week path');
  const before = await loadCanonicalEventLineupSnapshot(prisma, eventId);
  const schedule = buildSeptemberMultiWeekSchedule();
  const stageOrder = ['North Stage', 'South Stage', 'After Stage'];
  const largeRewriteName = 'Regression Large Mixed Rewrite DJ';
  const lineupArtists = [
    ...before.artists.map((artist) => ({
      id: artist.id,
      djId: artist.djId,
      memberDjIds: artist.memberDjIds,
      memberNames: artist.memberNames,
      djName: artist.djName,
      sortOrder: artist.sortOrder,
    })),
    {
      djName: 'Regression Large Lineup Only DJ',
      memberNames: ['Regression Large Lineup Only DJ'],
      sortOrder: before.artists.length + 1,
    },
  ];
  const lineupSlots = Array.from({ length: 180 }, (_, index) => {
    const seeded = before.slots[index % before.slots.length];
    const eventDay = schedule.eventDays[index % schedule.eventDays.length];
    const startMinute = 12 * 60 + ((index % 9) * 55);
    const shouldRewriteArtist = index === 37;
    return {
      id: index < before.slots.length ? seeded.id : crypto.randomUUID(),
      lineupArtistId: index < before.slots.length ? seeded.lineupArtistId : null,
      eventDayId: eventDay.eventDayId,
      weekIndex: eventDay.weekIndex,
      dayIndexInWeek: eventDay.dayIndexInWeek,
      overallDayIndex: eventDay.overallDayIndex,
      localDate: eventDay.date,
      djId: shouldRewriteArtist ? null : seeded.djId,
      memberDjIds: shouldRewriteArtist ? [] : seeded.memberDjIds,
      djName: shouldRewriteArtist ? largeRewriteName : seeded.djName,
      stageName: stageOrder[index % stageOrder.length],
      festivalDayIndex: eventDay.overallDayIndex,
      startTime: shanghaiIsoAt(eventDay.date, startMinute),
      endTime: shanghaiIsoAt(eventDay.date, startMinute + 45),
      sortOrder: index + 1,
    };
  });

  const payload = {
    targetEventId: eventId,
    name: `Event Incremental Large Mixed ${Date.now()}`,
    ...schedule,
    imageAssets: [
      {
        type: 'poster',
        label: 'POSTER',
        url: 'https://example.com/regression-poster.jpg',
      },
    ],
    lineupArtists,
    lineupSlots,
    stageOrder,
  } as any;

  await createOrUpdateEventFromSubmission(prisma, payload, userId);

  const [afterSnapshot, weeksCount, daysCount] = await Promise.all([
    loadCanonicalEventLineupSnapshot(prisma, eventId),
    prisma.eventWeek.count({ where: { eventId } }),
    prisma.eventDay.count({ where: { eventId } }),
  ]);

  assert(weeksCount === schedule.weeks.length, `expected ${schedule.weeks.length} weeks after large mixed update, got ${weeksCount}`);
  assert(daysCount === schedule.eventDays.length, `expected ${schedule.eventDays.length} event days after large mixed update, got ${daysCount}`);
  assert(afterSnapshot.slots.length === lineupSlots.length, `expected ${lineupSlots.length} slots after large mixed update, got ${afterSnapshot.slots.length}`);
  assert(afterSnapshot.stageOrder.join('|') === stageOrder.join('|'), 'large mixed update did not rewrite stage order');
  assert(afterSnapshot.slots.some((slot) => slot.djName === largeRewriteName), 'large mixed update did not persist rewritten slot artist');
  assert(afterSnapshot.artists.some((artist) => artist.djName === largeRewriteName), 'large mixed update did not append rewritten lineup artist');

  const firstPerformanceIds = afterSnapshot.slots
    .map((slot) => slot.id)
    .filter((id): id is string => Boolean(id))
    .sort();

  await createOrUpdateEventFromSubmission(prisma, payload, userId);

  const replaySnapshot = await loadCanonicalEventLineupSnapshot(prisma, eventId);
  const replayPerformanceIds = replaySnapshot.slots
    .map((slot) => slot.id)
    .filter((id): id is string => Boolean(id))
    .sort();
  assert(replaySnapshot.slots.length === afterSnapshot.slots.length, 'large mixed replay changed slot count');
  assert(replaySnapshot.artists.length === afterSnapshot.artists.length, 'large mixed replay changed artist count');
  assert(replayPerformanceIds.join('|') === firstPerformanceIds.join('|'), 'large mixed replay should preserve stable performance ids');
};

const runPatchDeleteTimetableKeepsLineupRegression = async (eventId: string, userId: string): Promise<void> => {
  logStep('patch delete timetable keeps lineup path');
  const before = await loadCanonicalEventLineupSnapshot(prisma, eventId);
  const eventBefore = await prisma.event.findUniqueOrThrow({
    where: { id: eventId },
    select: { revision: true },
  });
  const schedule = buildAugustMultiDaySchedule();
  const slotToDelete = before.slots[0];
  assert(Boolean(slotToDelete?.id), 'patch delete timetable keeps lineup requires a stable slot id');
  const deletedArtistName = slotToDelete.djName;
  const beforeArtistIds = before.artists.map((artist) => artist.id).filter((id): id is string => Boolean(id));

  await createOrUpdateEventFromSubmission(prisma, {
    targetEventId: eventId,
    baseEventRevision: eventBefore.revision,
    editMode: 'patch',
    name: `Event Incremental Delete Slot ${Date.now()}`,
    ...schedule,
    imageAssets: [
      {
        type: 'poster',
        label: 'POSTER',
        url: 'https://example.com/regression-poster.jpg',
      },
    ],
    timetableChanges: [
      {
        op: 'delete',
        slotId: slotToDelete.id,
      },
    ],
    stageOrder: before.stageOrder,
  }, userId);

  const after = await loadCanonicalEventLineupSnapshot(prisma, eventId);
  assert(after.slots.length === before.slots.length - 1, 'patch delete timetable should remove exactly one slot');
  assert(after.artists.length === before.artists.length, 'patch delete timetable should keep lineup artist count unchanged');
  assert(!after.slots.some((slot) => slot.id === slotToDelete.id), 'patch delete timetable did not remove the target slot');
  assert(after.artists.some((artist) => artist.djName === deletedArtistName), 'patch delete timetable should preserve the removed slot lineup artist');
  await assertExistingRowsStable(eventId, beforeArtistIds, after.slots.map((slot) => slot.id).filter((id): id is string => Boolean(id)));
};

const runCreatePayloadIncrementalFillRegression = async (userId: string): Promise<void> => {
  logStep('create payload incremental fill path');
  const suffix = `${Date.now()}_${crypto.randomInt(1000, 9999)}`;
  const lineupOnlyName = `Create Lineup Only DJ ${suffix}`;
  const timetableOnlyName = `Create Timetable Only DJ ${suffix}`;
  const schedule = buildSingleDaySchedule('2026-09-10');
  let createdEventId = '';

  try {
    const created = await createOrUpdateEventFromSubmission(prisma, {
      name: `Event Incremental Create Fill ${suffix}`,
      ...schedule,
      imageAssets: [
        {
          type: 'poster',
          label: 'POSTER',
          url: 'https://example.com/regression-poster.jpg',
        },
      ],
      lineupArtists: [
        {
          djName: lineupOnlyName,
          memberNames: [lineupOnlyName],
          sortOrder: 1,
        },
      ],
      lineupSlots: [
        {
          eventDayId: schedule.eventDays[0].eventDayId,
          weekIndex: schedule.eventDays[0].weekIndex,
          dayIndexInWeek: schedule.eventDays[0].dayIndexInWeek,
          overallDayIndex: schedule.eventDays[0].overallDayIndex,
          localDate: schedule.eventDays[0].date,
          djName: timetableOnlyName,
          memberNames: [timetableOnlyName],
          memberDjIds: [],
          stageName: 'Main Stage',
          festivalDayIndex: schedule.eventDays[0].overallDayIndex,
          startTime: '2026-09-10T18:00:00+08:00',
          endTime: '2026-09-10T19:00:00+08:00',
          sortOrder: 1,
        },
      ],
      stageOrder: ['Main Stage'],
    } as Prisma.JsonObject, userId);
    createdEventId = created.id;

    const snapshot = await loadCanonicalEventLineupSnapshot(prisma, created.id);
    assert(snapshot.slots.length === 1, 'create payload incremental fill should create one timetable slot');
    assert(snapshot.artists.length === 2, 'create payload incremental fill should keep lineup-only artist and append timetable-only artist');
    assert(snapshot.artists.some((artist) => artist.djName === lineupOnlyName), 'create payload incremental fill lost the original lineup-only artist');
    assert(snapshot.artists.some((artist) => artist.djName === timetableOnlyName), 'create payload incremental fill did not append the timetable-only artist');
  } finally {
    if (createdEventId) {
      await prisma.event.deleteMany({ where: { id: createdEventId } });
    }
  }
};

const runStaleBaseRevisionIgnoredRegression = async (eventId: string, userId: string): Promise<void> => {
  logStep('stale base revision ignored path');
  const eventBefore = await prisma.event.findUniqueOrThrow({
    where: { id: eventId },
    select: { revision: true },
  });
  const schedule = buildAugustMultiDaySchedule();
  const staleBaseEventRevision = Math.max(0, eventBefore.revision - 1);

  await createOrUpdateEventFromSubmission(prisma, {
    targetEventId: eventId,
    baseEventRevision: staleBaseEventRevision,
    editMode: 'patch',
    name: `Event Incremental Stale Conflict ${Date.now()}`,
    ...schedule,
    imageAssets: [
      {
        type: 'poster',
        label: 'POSTER',
        url: 'https://example.com/regression-poster.jpg',
      },
    ],
    timetableChanges: [],
    stageOrder: ['Main Stage', 'Second Stage'],
  }, userId);

  const eventAfter = await prisma.event.findUniqueOrThrow({
    where: { id: eventId },
    select: { revision: true },
  });
  assert(eventAfter.revision === eventBefore.revision + 1, 'stale base revision should no longer block the event edit mainline');
};

const runCreateSubmissionIdempotencyRegression = async (userId: string): Promise<void> => {
  logStep('create submission idempotency path');
  const suffix = `${Date.now()}_${crypto.randomInt(1000, 9999)}`;
  const schedule = buildSingleDaySchedule('2026-09-01');
  const payload = {
    name: `Event Incremental Create Idempotency ${suffix}`,
    ...schedule,
    imageAssets: [
      {
        type: 'poster',
        label: 'POSTER',
        url: 'https://example.com/regression-poster.jpg',
      },
    ],
    lineupArtists: [
      {
        djName: 'Create Idempotency DJ',
        memberNames: ['Create Idempotency DJ'],
        sortOrder: 1,
      },
    ],
    lineupSlots: [
      {
        eventDayId: schedule.eventDays[0].eventDayId,
        weekIndex: schedule.eventDays[0].weekIndex,
        dayIndexInWeek: schedule.eventDays[0].dayIndexInWeek,
        overallDayIndex: schedule.eventDays[0].overallDayIndex,
        localDate: schedule.eventDays[0].date,
        djName: 'Create Idempotency DJ',
        memberDjIds: [],
        stageName: 'Main Stage',
        festivalDayIndex: schedule.eventDays[0].overallDayIndex,
        startTime: '2026-09-01T18:00:00+08:00',
        endTime: '2026-09-01T19:00:00+08:00',
        sortOrder: 1,
      },
    ],
    stageOrder: ['Main Stage'],
  } as Prisma.JsonObject;

  const submission = await prisma.contentSubmission.create({
    data: {
      submitterId: userId,
      entityType: 'event',
      status: 'processing',
      title: payload.name as string,
      payload,
      reviewReason: null,
    },
    select: { id: true },
  });

  const first = await createOrUpdateEventFromSubmission(prisma, payload, userId, {
    submissionId: submission.id,
  });
  const second = await createOrUpdateEventFromSubmission(prisma, payload, userId, {
    submissionId: submission.id,
  });

  assert(first.id === second.id, 'create submission idempotency did not reuse the same event id');
  const duplicateCount = await prisma.event.count({
    where: {
      organizerId: userId,
      name: payload.name as string,
    },
  });
  assert(duplicateCount === 1, `expected exactly one created event, got ${duplicateCount}`);

  const firstSnapshot = await loadCanonicalEventLineupSnapshot(prisma, first.id);
  const secondSnapshot = await loadCanonicalEventLineupSnapshot(prisma, second.id);
  const firstPerformanceIds = firstSnapshot.slots.map((slot) => slot.id).filter((id): id is string => Boolean(id));
  const secondPerformanceIds = secondSnapshot.slots.map((slot) => slot.id).filter((id): id is string => Boolean(id));
  assert(firstPerformanceIds.length === 1, `expected exactly one performance after create idempotency first apply, got ${firstPerformanceIds.length}`);
  assert(secondPerformanceIds.length === 1, `expected exactly one performance after create idempotency replay, got ${secondPerformanceIds.length}`);
  assert(firstPerformanceIds[0] === secondPerformanceIds[0], 'create idempotency replay should preserve the same generated performance id');

  await prisma.contentSubmission.deleteMany({ where: { id: submission.id } });
  await prisma.event.deleteMany({ where: { id: first.id } });
};

const runAutoApprovalResumeRegression = async (): Promise<void> => {
  logStep('auto approval resume path');
  const suffix = `${Date.now()}_${crypto.randomInt(1000, 9999)}`;
  const adminUserId = await createRegressionUser(suffix, 'admin');
  const schedule = buildSingleDaySchedule('2026-10-01');
  let submissionId = '';
  let createdEventId = '';

  try {
    const payload = {
      name: `Event Incremental Auto Resume ${suffix}`,
      ...schedule,
      imageAssets: [
        {
          type: 'poster',
          label: 'POSTER',
          url: 'https://example.com/regression-poster.jpg',
        },
      ],
      lineupArtists: [
        {
          djName: 'Auto Resume DJ',
          memberNames: ['Auto Resume DJ'],
          sortOrder: 1,
        },
      ],
      lineupSlots: [
        {
          eventDayId: schedule.eventDays[0].eventDayId,
          weekIndex: schedule.eventDays[0].weekIndex,
          dayIndexInWeek: schedule.eventDays[0].dayIndexInWeek,
          overallDayIndex: schedule.eventDays[0].overallDayIndex,
          localDate: schedule.eventDays[0].date,
          djName: 'Auto Resume DJ',
          memberDjIds: [],
          stageName: 'Main Stage',
          festivalDayIndex: schedule.eventDays[0].overallDayIndex,
          startTime: '2026-10-01T18:00:00+08:00',
          endTime: '2026-10-01T19:00:00+08:00',
          sortOrder: 1,
        },
      ],
      stageOrder: ['Main Stage'],
    } as Prisma.JsonObject;

    const submission = await prisma.contentSubmission.create({
      data: {
        submitterId: adminUserId,
        entityType: 'event',
        status: 'reviewing',
        title: payload.name as string,
        payload,
        reviewReason: null,
      },
      select: { id: true },
    });
    submissionId = submission.id;

    const result = await processContentSubmission(submission.id, {
      db: prisma,
      markFailedOnError: false,
    });
    assert(result.status === 'succeeded', 'auto approval resume did not succeed');
    assert(result.submissionStatus === 'approved', 'auto approval resume did not finalize approved state');

    const timetableJobResult = await processContentSubmission(submission.id, {
      db: prisma,
      markFailedOnError: false,
      jobType: 'apply_event_timetable',
    } as any);
    assert(timetableJobResult.status === 'succeeded', 'event timetable phase-b job did not succeed');

    const updated = await prisma.contentSubmission.findUniqueOrThrow({
      where: { id: submission.id },
      select: {
        status: true,
        createdEntityId: true,
      },
    });
    assert(updated.status === 'approved', 'auto approval resume left submission unapproved');
    assert(Boolean(updated.createdEntityId), 'auto approval resume did not create or link event');
    createdEventId = updated.createdEntityId || '';
  } finally {
    if (submissionId) {
      await prisma.contentSubmission.deleteMany({ where: { id: submissionId } });
    }
    if (createdEventId) {
      await prisma.event.deleteMany({ where: { id: createdEventId } });
    }
    await prisma.user.deleteMany({ where: { id: adminUserId } });
  }
};

const runPhaseBFailureRecoveryRegression = async (): Promise<void> => {
  logStep('phase-b failure recovery path');
  const suffix = `${Date.now()}_${crypto.randomInt(1000, 9999)}`;
  const adminUserId = await createRegressionUser(`${suffix}_phase_b`, 'admin');
  const schedule = buildSingleDaySchedule('2026-10-08');
  let submissionId = '';
  let createdEventId = '';

  try {
    const invalidPayload = {
      name: `Event Incremental Phase B Failure ${suffix}`,
      ...schedule,
      imageAssets: [
        {
          type: 'poster',
          label: 'POSTER',
          url: 'https://example.com/regression-poster.jpg',
        },
      ],
      lineupArtists: [
        {
          djName: 'Phase B Recovery DJ',
          memberNames: ['Phase B Recovery DJ'],
          sortOrder: 1,
        },
      ],
      lineupSlots: [
        {
          eventDayId: 'missing-day-id',
          weekIndex: 1,
          dayIndexInWeek: 1,
          overallDayIndex: 1,
          localDate: schedule.eventDays[0].date,
          djName: 'Phase B Recovery DJ',
          memberDjIds: [],
          stageName: 'Broken Stage',
          festivalDayIndex: 1,
          startTime: '2026-10-08T20:00:00+08:00',
          endTime: '2026-10-08T21:00:00+08:00',
          sortOrder: 1,
        },
      ],
      stageOrder: ['Broken Stage'],
    } as Prisma.JsonObject;

    const submission = await prisma.contentSubmission.create({
      data: {
        submitterId: adminUserId,
        entityType: 'event',
        status: 'reviewing',
        title: invalidPayload.name as string,
        payload: invalidPayload,
        reviewReason: null,
      },
      select: { id: true },
    });
    submissionId = submission.id;

    const phaseAResult = await processContentSubmission(submission.id, {
      db: prisma,
      markFailedOnError: false,
    });
    assert(phaseAResult.status === 'succeeded', 'phase-b recovery phase-a apply did not succeed');
    assert(phaseAResult.submissionStatus === 'approved', 'phase-b recovery phase-a did not preserve approved submission state');

    const firstPhaseBResult = await processContentSubmission(submission.id, {
      db: prisma,
      markFailedOnError: false,
      jobType: 'apply_event_timetable',
    } as any).catch((error) => {
      throw error;
    });
    assert(firstPhaseBResult.status === 'failed', 'phase-b recovery should fail on invalid timetable payload');

    const afterFailure = await prisma.contentSubmission.findUniqueOrThrow({
      where: { id: submission.id },
      select: {
        status: true,
        createdEntityId: true,
        reviewNotes: true,
      },
    });
    assert(afterFailure.status === 'approved', 'phase-b failure should not roll approved submission back to failed');
    createdEventId = afterFailure.createdEntityId || '';
    const failedNotes = (afterFailure.reviewNotes ?? {}) as Record<string, unknown>;
    assert(Boolean(failedNotes.phaseBFailure), 'phase-b failure should record reviewNotes.phaseBFailure');

    const repairedPayload = {
      ...invalidPayload,
      lineupSlots: [
        {
          eventDayId: schedule.eventDays[0].eventDayId,
          weekIndex: schedule.eventDays[0].weekIndex,
          dayIndexInWeek: schedule.eventDays[0].dayIndexInWeek,
          overallDayIndex: schedule.eventDays[0].overallDayIndex,
          localDate: schedule.eventDays[0].date,
          djName: 'Phase B Recovery DJ',
          memberDjIds: [],
          stageName: 'Recovered Stage',
          festivalDayIndex: schedule.eventDays[0].overallDayIndex,
          startTime: '2026-10-08T20:00:00+08:00',
          endTime: '2026-10-08T21:00:00+08:00',
          sortOrder: 1,
        },
      ],
      stageOrder: ['Recovered Stage'],
    } as Prisma.JsonObject;

    await prisma.contentSubmission.update({
      where: { id: submission.id },
      data: {
        payload: repairedPayload,
      },
    });

    const secondPhaseBResult = await processContentSubmission(submission.id, {
      db: prisma,
      markFailedOnError: false,
      jobType: 'apply_event_timetable',
    } as any);
    assert(secondPhaseBResult.status === 'succeeded', 'phase-b recovery should succeed after payload is repaired');

    const afterRecovery = await prisma.contentSubmission.findUniqueOrThrow({
      where: { id: submission.id },
      select: {
        status: true,
        reviewNotes: true,
      },
    });
    assert(afterRecovery.status === 'approved', 'phase-b recovery should keep submission approved');
    const recoveredNotes = (afterRecovery.reviewNotes ?? {}) as Record<string, unknown>;
    assert(!Object.prototype.hasOwnProperty.call(recoveredNotes, 'phaseBFailure'), 'phase-b recovery should clear reviewNotes.phaseBFailure');
  } finally {
    if (submissionId) {
      await prisma.contentSubmission.deleteMany({ where: { id: submissionId } });
    }
    if (createdEventId) {
      await prisma.event.deleteMany({ where: { id: createdEventId } });
    }
    await prisma.user.deleteMany({ where: { id: adminUserId } });
  }
};

const cleanup = async (eventId: string, userId: string): Promise<void> => {
  await prisma.event.deleteMany({ where: { id: eventId } });
  await prisma.user.deleteMany({ where: { id: userId } });
};

const main = async (): Promise<void> => {
  const suffix = `${Date.now()}_${crypto.randomInt(1000, 9999)}`;
  let eventId = '';
  let userId = '';
  try {
    const seeded = await createRegressionUserAndEvent(suffix);
    eventId = seeded.eventId;
    userId = seeded.userId;
    await runDirectCanonicalRegression(eventId);
    await runManualReviewPatchRegression(eventId, userId);
    await runTimetableIncrementalFillPatchRegression(eventId, userId);
    await runNormalReviewApprovalRegression(eventId, userId);
    await runFullPayloadIncrementalFillRegression(eventId, userId);
    await runFullPayloadExactAlignRegression(eventId, userId);
    await runFullPayloadLargeMixedRegression(eventId, userId);
    await runPatchDeleteTimetableKeepsLineupRegression(eventId, userId);
    await runPatchClearAllTimetableRegression(eventId, userId);
    await runStaleBaseRevisionIgnoredRegression(eventId, userId);
    await runSingleStageLegacyRenameRegression(userId);
    await runCreateSubmissionIdempotencyRegression(userId);
    await runCreatePayloadIncrementalFillRegression(userId);
    await runAutoApprovalResumeRegression();
    await runPhaseBFailureRecoveryRegression();
    logStep('passed', { eventId });
  } finally {
    if (eventId && userId && process.env.EVENT_INCREMENTAL_REGRESSION_KEEP_DATA !== '1') {
      await cleanup(eventId, userId);
    }
    await prisma.$disconnect();
  }
};

main().catch(async (error) => {
  console.error('[event-incremental-sync-regression] failed', error);
  await prisma.$disconnect();
  process.exit(1);
});
