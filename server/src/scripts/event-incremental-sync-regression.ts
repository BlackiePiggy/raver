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
  EventSubmissionConflictError,
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
  const beforeArtistIds = before.artists.map((artist) => artist.id).filter((id): id is string => Boolean(id));
  const beforePerformanceIds = before.slots.map((slot) => slot.id).filter((id): id is string => Boolean(id));
  const artistName = 'Regression Manual Approval DJ';

  await createOrUpdateEventFromSubmission(prisma, {
    targetEventId: eventId,
    baseEventRevision: eventBefore.revision,
    editMode: 'patch',
    name: `Event Incremental Regression Approved ${Date.now()}`,
    startDate: '2026-08-01',
    endDate: '2026-08-02',
    timeZone: 'Asia/Shanghai',
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
          djName: artistName,
          memberNames: [artistName],
          stageName: 'Main Stage',
          festivalDayIndex: 1,
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

const runTimetableSourceOfTruthRegression = async (eventId: string, userId: string): Promise<void> => {
  logStep('timetable source of truth patch path');
  const before = await loadCanonicalEventLineupSnapshot(prisma, eventId);
  const eventBefore = await prisma.event.findUniqueOrThrow({
    where: { id: eventId },
    select: { revision: true },
  });
  const slotToRewrite = before.slots[1];
  assert(Boolean(slotToRewrite?.id), 'timetable source of truth slot missing stable id');
  assert(Boolean(slotToRewrite?.lineupArtistId), 'timetable source of truth slot missing linked lineup artist id');
  const previousArtistName = slotToRewrite.djName;
  const nextArtistName = 'Regression Timetable Source Of Truth DJ';
  const unaffectedArtistIds = before.artists
    .map((artist) => artist.id)
    .filter((id): id is string => Boolean(id && id !== slotToRewrite.lineupArtistId));
  const stablePerformanceIds = before.slots.map((slot) => slot.id).filter((id): id is string => Boolean(id));

  await createOrUpdateEventFromSubmission(prisma, {
    targetEventId: eventId,
    baseEventRevision: eventBefore.revision,
    editMode: 'patch',
    name: `Event Incremental Timetable Source ${Date.now()}`,
    startDate: '2026-08-01',
    endDate: '2026-08-02',
    timeZone: 'Asia/Shanghai',
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
  assert(after.slots.length === before.slots.length, 'timetable source of truth changed slot count');
  assert(after.artists.length === before.artists.length, 'timetable source of truth changed artist count');
  assert(after.slots.some((slot) => slot.id === slotToRewrite.id && slot.djName === nextArtistName), 'timetable source of truth did not update slot artist');
  assert(after.artists.some((artist) => artist.djName === nextArtistName), 'timetable source of truth did not auto-align lineup artist');
  assert(!after.artists.some((artist) => artist.djName === previousArtistName), 'timetable source of truth left stale lineup artist behind');
  await assertExistingRowsStable(eventId, unaffectedArtistIds, stablePerformanceIds);
};

const runNormalReviewApprovalRegression = async (eventId: string, userId: string): Promise<void> => {
  logStep('normal review approval path');
  const before = await loadCanonicalEventLineupSnapshot(prisma, eventId);
  const eventBefore = await prisma.event.findUniqueOrThrow({
    where: { id: eventId },
    select: { revision: true },
  });
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
    startDate: '2026-08-01',
    endDate: '2026-08-02',
    timeZone: 'Asia/Shanghai',
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

const runFullPayloadTargetedSyncRegression = async (eventId: string, userId: string): Promise<void> => {
  logStep('full payload targeted sync path');
  const before = await loadCanonicalEventLineupSnapshot(prisma, eventId);
  const eventBefore = await prisma.event.findUniqueOrThrow({
    where: { id: eventId },
    select: { revision: true },
  });
  const slotToRewrite = before.slots[2];
  assert(Boolean(slotToRewrite?.id), 'full payload targeted sync slot missing stable id');
  assert(Boolean(slotToRewrite?.lineupArtistId), 'full payload targeted sync slot missing lineup artist id');
  const previousArtistName = slotToRewrite.djName;
  const nextArtistName = 'Regression Full Payload Targeted Sync DJ';
  const unaffectedArtistIds = before.artists
    .map((artist) => artist.id)
    .filter((id): id is string => Boolean(id && id !== slotToRewrite.lineupArtistId));
  const stablePerformanceIds = before.slots.map((slot) => slot.id).filter((id): id is string => Boolean(id));

  await createOrUpdateEventFromSubmission(prisma, {
    targetEventId: eventId,
    baseEventRevision: eventBefore.revision,
    name: `Event Incremental Full Payload ${Date.now()}`,
    startDate: '2026-08-01',
    endDate: '2026-08-02',
    timeZone: 'Asia/Shanghai',
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
      id: slot.id,
      lineupArtistId: slot.lineupArtistId,
      djId: slot.id === slotToRewrite.id ? null : slot.djId,
      memberDjIds: slot.id === slotToRewrite.id ? [] : slot.memberDjIds,
      djName: slot.id === slotToRewrite.id ? nextArtistName : slot.djName,
      stageName: slot.stageName,
      festivalDayIndex: slot.festivalDayIndex,
      startTime: slot.startTime.toISOString(),
      endTime: slot.endTime.toISOString(),
      sortOrder: slot.sortOrder,
    })),
    stageOrder: before.stageOrder,
  } as any, userId);

  const after = await loadCanonicalEventLineupSnapshot(prisma, eventId);
  assert(after.slots.length === before.slots.length, 'full payload targeted sync changed slot count');
  assert(after.artists.length === before.artists.length, 'full payload targeted sync changed artist count');
  assert(after.slots.some((slot) => slot.id === slotToRewrite.id && slot.djName === nextArtistName), 'full payload targeted sync did not update slot artist');
  assert(after.artists.some((artist) => artist.djName === nextArtistName), 'full payload targeted sync did not update affected lineup artist');
  assert(!after.artists.some((artist) => artist.djName === previousArtistName), 'full payload targeted sync left stale lineup artist behind');
  await assertExistingRowsStable(eventId, unaffectedArtistIds, stablePerformanceIds);
};

const runStaleEditConflictRegression = async (eventId: string, userId: string): Promise<void> => {
  logStep('stale edit conflict path');
  const eventBefore = await prisma.event.findUniqueOrThrow({
    where: { id: eventId },
    select: { revision: true },
  });
  const staleBaseEventRevision = Math.max(0, eventBefore.revision - 1);

  let threwConflict = false;
  try {
    await createOrUpdateEventFromSubmission(prisma, {
      targetEventId: eventId,
      baseEventRevision: staleBaseEventRevision,
      editMode: 'patch',
      name: `Event Incremental Stale Conflict ${Date.now()}`,
      startDate: '2026-08-01',
      endDate: '2026-08-02',
      timeZone: 'Asia/Shanghai',
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
  } catch (error) {
    threwConflict = error instanceof EventSubmissionConflictError;
  }

  assert(threwConflict, 'stale edit regression did not reject outdated baseEventRevision');
};

const runCreateSubmissionIdempotencyRegression = async (userId: string): Promise<void> => {
  logStep('create submission idempotency path');
  const suffix = `${Date.now()}_${crypto.randomInt(1000, 9999)}`;
  const payload = {
    name: `Event Incremental Create Idempotency ${suffix}`,
    startDate: '2026-09-01',
    endDate: '2026-09-02',
    timeZone: 'Asia/Shanghai',
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
        djName: 'Create Idempotency DJ',
        memberDjIds: [],
        stageName: 'Main Stage',
        festivalDayIndex: 1,
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

  await prisma.contentSubmission.deleteMany({ where: { id: submission.id } });
  await prisma.event.deleteMany({ where: { id: first.id } });
};

const runAutoApprovalResumeRegression = async (): Promise<void> => {
  logStep('auto approval resume path');
  const suffix = `${Date.now()}_${crypto.randomInt(1000, 9999)}`;
  const adminUserId = await createRegressionUser(suffix, 'admin');
  let submissionId = '';
  let createdEventId = '';

  try {
    const payload = {
      name: `Event Incremental Auto Resume ${suffix}`,
      startDate: '2026-10-01',
      endDate: '2026-10-02',
      timeZone: 'Asia/Shanghai',
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
          djName: 'Auto Resume DJ',
          memberDjIds: [],
          stageName: 'Main Stage',
          festivalDayIndex: 1,
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
    await runTimetableSourceOfTruthRegression(eventId, userId);
    await runNormalReviewApprovalRegression(eventId, userId);
    await runFullPayloadTargetedSyncRegression(eventId, userId);
    await runStaleEditConflictRegression(eventId, userId);
    await runCreateSubmissionIdempotencyRegression(userId);
    await runAutoApprovalResumeRegression();
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
