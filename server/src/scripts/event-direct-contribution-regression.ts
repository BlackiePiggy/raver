import 'dotenv/config';
import fs from 'node:fs';
import path from 'node:path';
import { PrismaClient } from '@prisma/client';
import { fetchContributorEntriesForEntity, fetchContributionHistoryPage } from '../services/contribution.service';

const prisma = new PrismaClient();

const createdUserIds = new Set<string>();
const createdEventIds = new Set<string>();

const assert = (condition: boolean, message: string): void => {
  if (!condition) {
    throw new Error(message);
  }
};

const logStep = (step: string, detail?: Record<string, unknown>): void => {
  console.log('[event-direct-contribution-regression]', step, detail || {});
};

const fixtureDir = path.resolve(__dirname, '../../../contracts/fixtures/event/golden');

const loadFixture = (name: string): Record<string, unknown> =>
  JSON.parse(fs.readFileSync(path.join(fixtureDir, name), 'utf8')) as Record<string, unknown>;

const cleanup = async (): Promise<void> => {
  if (createdEventIds.size > 0) {
    await prisma.event.deleteMany({
      where: { id: { in: Array.from(createdEventIds) } },
    });
  }

  if (createdUserIds.size > 0) {
    await prisma.user.deleteMany({
      where: { id: { in: Array.from(createdUserIds) } },
    });
  }
};

const run = async (): Promise<void> => {
  const { createEvent, updateEvent } = await import('../controllers/event.controller');

  const suffix = Date.now().toString(36);
  const admin = await prisma.user.create({
    data: {
      username: `event_direct_contribution_admin_${suffix}`,
      email: `event_direct_contribution_admin_${suffix}@example.com`,
      passwordHash: 'regression-only',
      displayName: `Event Direct Contribution Admin ${suffix}`,
      displayNameNormalized: `event direct contribution admin ${suffix}`,
      role: 'admin',
      isVerified: true,
      regionCode: 'US',
      birthYear: 1990,
      ageBand: 'adult',
      ageDeclaredAt: new Date(),
    },
    select: { id: true },
  });
  createdUserIds.add(admin.id);

  const createFixture = loadFixture('create-map-poi.json');
  const updateFixture = loadFixture('update-clear-location.json');
  delete createFixture.timeZoneCity;
  delete createFixture.timeZoneProvince;
  delete createFixture.timeZoneCountry;
  delete createFixture.timeZoneStateAnsi;
  delete createFixture.timeZoneLat;
  delete createFixture.timeZoneLng;
  delete updateFixture.timeZoneCity;
  delete updateFixture.timeZoneProvince;
  delete updateFixture.timeZoneCountry;
  delete updateFixture.timeZoneStateAnsi;
  delete updateFixture.timeZoneLat;
  delete updateFixture.timeZoneLng;

  let createStatus = 0;
  let createBody: any = null;

  const createReq = {
    user: {
      userId: admin.id,
      role: 'admin',
    },
    body: {
      ...createFixture,
      name: `Direct Contribution Event ${suffix}`,
      organizerName: `Direct Contribution Organizer ${suffix}`,
      sourceEventUrl: `https://example.com/events/direct-contribution-${suffix}`,
      coverImageUrl: `https://example.com/direct-contribution-event-${suffix}.jpg`,
      imageAssets: [
        {
          url: `https://example.com/direct-contribution-event-${suffix}.jpg`,
          type: 'cover',
          label: 'COVER',
          sort: 1,
          order: 1,
          source: 'regression',
          fileName: 'cover.jpg',
        },
      ],
    },
  } as any;

  const createRes = {
    status(code: number) {
      createStatus = code;
      return this;
    },
    json(payload: unknown) {
      createBody = payload;
      return this;
    },
  } as any;

  await createEvent(createReq, createRes);

  assert(
    createStatus === 201,
    `direct event create should return 201, got ${createStatus}, body=${JSON.stringify(createBody)}`
  );
  assert(createBody?.id, 'direct event create should return event payload');

  const eventId = String(createBody.id);
  createdEventIds.add(eventId);

  const contributorsAfterCreate = await fetchContributorEntriesForEntity(prisma, 'event', eventId);
  assert(contributorsAfterCreate.length === 1, 'direct event create should create exactly one contributor row');
  assert(contributorsAfterCreate[0]?.id === admin.id, 'direct event create should write creator into contributors');
  assert(contributorsAfterCreate[0]?.role === 'creator', 'direct event create should mark creator role');

  const historyAfterCreate = await fetchContributionHistoryPage(prisma, admin.id, {
    entityType: 'event',
    limit: 10,
  });
  const createdEntry = historyAfterCreate.items.find((item) => item.entityId === eventId && item.actionType === 'create');
  assert(Boolean(createdEntry), 'direct event create should write contribution history create entry');

  let updateStatus = 0;
  let updateBody: any = null;

  const updateReq = {
    params: { id: eventId },
    user: {
      userId: admin.id,
      role: 'admin',
    },
    body: {
      ...updateFixture,
      name: `Direct Contribution Event ${suffix} Updated`,
      organizerName: `Direct Contribution Organizer ${suffix}`,
      sourceEventUrl: `https://example.com/events/direct-contribution-${suffix}-updated`,
      coverImageUrl: `https://example.com/direct-contribution-event-${suffix}-updated.jpg`,
      imageAssets: [
        {
          url: `https://example.com/direct-contribution-event-${suffix}-updated.jpg`,
          type: 'cover',
          label: 'COVER',
          sort: 1,
          order: 1,
          source: 'regression',
          fileName: 'cover-updated.jpg',
        },
      ],
      clearWikiFestivalId: true,
      clearManualLocation: true,
      clearLocationPoint: true,
      clearLatitude: true,
      clearLongitude: true,
      clearSocialLinks: true,
      clearStageOrder: true,
      clearLineupSlots: true,
      expectedRevision: createBody.revision,
    },
  } as any;

  const updateRes = {
    status(code: number) {
      updateStatus = code;
      return this;
    },
    json(payload: unknown) {
      updateBody = payload;
      return this;
    },
  } as any;

  await updateEvent(updateReq, updateRes);

  assert(updateStatus === 0 || updateStatus === 200, `direct event update should succeed, got status ${updateStatus}`);
  assert(updateBody?.id === eventId, 'direct event update should return updated event');

  const contributorsAfterUpdate = await fetchContributorEntriesForEntity(prisma, 'event', eventId);
  assert(contributorsAfterUpdate.length === 1, 'same user direct update should still keep one contributor row');
  assert(contributorsAfterUpdate[0]?.id === admin.id, 'same user direct update should keep creator row');
  assert(contributorsAfterUpdate[0]?.role === 'creator', 'creator role should not be downgraded after direct edit');
  assert(contributorsAfterUpdate[0]?.contributionCount === 2, 'same user direct update should increment contribution count');

  const historyAfterUpdate = await fetchContributionHistoryPage(prisma, admin.id, {
    entityType: 'event',
    limit: 10,
  });
  const eventHistory = historyAfterUpdate.items.filter((item) => item.entityId === eventId);
  assert(eventHistory.some((item) => item.actionType === 'create'), 'direct event history should retain create entry');
  assert(eventHistory.some((item) => item.actionType === 'edit'), 'direct event history should append edit entry');

  logStep('ok', {
    eventId,
    userId: admin.id,
  });
};

const main = async (): Promise<void> => {
  try {
    await run();
  } finally {
    await cleanup();
    await prisma.$disconnect();
  }
};

main().catch((error) => {
  console.error('[event-direct-contribution-regression] failed:', error);
  process.exit(1);
});
