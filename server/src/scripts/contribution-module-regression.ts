import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import {
  InvalidContributionHistoryCursorError,
  fetchContributionCenterSummary,
  fetchContributionHistoryPage,
  fetchContributorEntriesForEntity,
  fetchContributorInfoMap,
  recordDJContribution,
  recordEventContribution,
} from '../services/contribution.service';

const prisma = new PrismaClient();

const createdUserIds = new Set<string>();
const createdEventIds = new Set<string>();
const createdDJIds = new Set<string>();

const assert = (condition: boolean, message: string): void => {
  if (!condition) {
    throw new Error(message);
  }
};

const logStep = (step: string, detail?: Record<string, unknown>): void => {
  console.log('[contribution-module-regression]', step, detail || {});
};

const createUser = async (suffix: string, label: string) => {
  const user = await prisma.user.create({
    data: {
      username: `contribution_module_${label}_${suffix}`,
      email: `contribution_module_${label}_${suffix}@example.com`,
      passwordHash: 'regression-only',
      displayName: `Contribution ${label} ${suffix}`,
      displayNameNormalized: `contribution ${label} ${suffix}`.toLowerCase(),
      role: 'user',
      isVerified: true,
      regionCode: 'US',
      birthYear: 1992,
      ageBand: 'adult',
      ageDeclaredAt: new Date(),
    },
    select: {
      id: true,
      username: true,
      displayName: true,
      avatarUrl: true,
    },
  });

  createdUserIds.add(user.id);
  return user;
};

const createEvent = async (suffix: string, organizerId: string) => {
  const event = await prisma.event.create({
    data: {
      organizerId,
      name: `Contribution Module Event ${suffix}`,
      slug: `contribution-module-event-${suffix}`,
      coverImageUrl: `https://example.com/contribution-module-event-${suffix}.jpg`,
      startDate: new Date('2026-06-01T10:00:00.000Z'),
      endDate: new Date('2026-06-01T18:00:00.000Z'),
      isCancelled: false,
      visibility: 'visible',
    },
    select: {
      id: true,
      name: true,
      coverImageUrl: true,
    },
  });

  createdEventIds.add(event.id);
  return event;
};

const createDJ = async (suffix: string) => {
  const dj = await prisma.dJ.create({
    data: {
      name: `Contribution Module DJ ${suffix}`,
      slug: `contribution-module-dj-${suffix}`,
      avatarUrl: `https://example.com/contribution-module-dj-${suffix}.jpg`,
      genres: ['House'],
    },
    select: {
      id: true,
      name: true,
      avatarUrl: true,
    },
  });

  createdDJIds.add(dj.id);
  return dj;
};

const cleanup = async (): Promise<void> => {
  if (createdEventIds.size > 0) {
    await prisma.event.deleteMany({
      where: { id: { in: Array.from(createdEventIds) } },
    });
  }

  if (createdDJIds.size > 0) {
    await prisma.dJ.deleteMany({
      where: { id: { in: Array.from(createdDJIds) } },
    });
  }

  if (createdUserIds.size > 0) {
    await prisma.user.deleteMany({
      where: { id: { in: Array.from(createdUserIds) } },
    });
  }
};

const run = async (): Promise<void> => {
  const suffix = Date.now().toString(36);
  const creator = await createUser(suffix, 'creator');
  const editor = await createUser(suffix, 'editor');
  const event = await createEvent(suffix, creator.id);
  const dj = await createDJ(suffix);

  const eventCreateAt = new Date('2026-06-01T10:00:00.000Z');
  const eventEditAt = new Date('2026-06-02T10:00:00.000Z');
  const eventSecondEditAt = new Date('2026-06-03T10:00:00.000Z');
  const djCreateAt = new Date('2026-06-01T12:00:00.000Z');
  const djEditAt = new Date('2026-06-04T12:00:00.000Z');

  await recordEventContribution(prisma, {
    entityId: event.id,
    userId: creator.id,
    title: event.name,
    coverImageUrl: event.coverImageUrl,
    role: 'creator',
    actionType: 'create',
    source: 'regression_create',
    occurredAt: eventCreateAt,
    approvedAt: eventCreateAt,
    versionAfter: 1,
    changeSummary: 'Created event',
    metadata: { regression: true, entityType: 'event', step: 'create' },
  });

  await recordEventContribution(prisma, {
    entityId: event.id,
    userId: editor.id,
    title: event.name,
    coverImageUrl: event.coverImageUrl,
    role: 'editor',
    actionType: 'edit',
    source: 'regression_edit',
    occurredAt: eventEditAt,
    approvedAt: eventEditAt,
    versionAfter: 2,
    changeSummary: 'Updated event intro',
    metadata: { regression: true, entityType: 'event', step: 'edit_1' },
  });

  await recordEventContribution(prisma, {
    entityId: event.id,
    userId: editor.id,
    title: null,
    coverImageUrl: null,
    role: 'editor',
    actionType: 'edit',
    source: 'regression_edit',
    occurredAt: eventSecondEditAt,
    approvedAt: eventSecondEditAt,
    versionAfter: 3,
    changeSummary: 'Updated event links',
    metadata: { regression: true, entityType: 'event', step: 'edit_2' },
  });

  await recordDJContribution(prisma, {
    entityId: dj.id,
    userId: creator.id,
    title: dj.name,
    coverImageUrl: dj.avatarUrl,
    role: 'creator',
    actionType: 'create',
    source: 'regression_create',
    occurredAt: djCreateAt,
    approvedAt: djCreateAt,
    versionAfter: 1,
    changeSummary: 'Created DJ',
    metadata: { regression: true, entityType: 'dj', step: 'create' },
  });

  await recordDJContribution(prisma, {
    entityId: dj.id,
    userId: editor.id,
    title: null,
    coverImageUrl: null,
    role: 'editor',
    actionType: 'edit',
    source: 'regression_edit',
    occurredAt: djEditAt,
    approvedAt: djEditAt,
    versionAfter: 2,
    changeSummary: 'Updated DJ profile',
    metadata: { regression: true, entityType: 'dj', step: 'edit_1' },
  });

  const contributorMap = await fetchContributorInfoMap(prisma, 'event', [event.id]);
  const eventInfo = contributorMap.get(event.id);
  assert(Boolean(eventInfo), 'event contributor info should exist');
  assert(eventInfo?.summary.totalCount === 2, 'event contributor summary should contain creator and editor');
  assert(eventInfo?.summary.creator?.id === creator.id, 'event contributor summary should keep creator');
  assert(eventInfo?.summary.previewUsers[0]?.id === creator.id, 'summary preview should prioritize creator ordering');

  const eventContributors = await fetchContributorEntriesForEntity(prisma, 'event', event.id);
  assert(eventContributors.length === 2, 'event contributor list should contain two entries');
  assert(eventContributors[0]?.id === editor.id, 'event contributor list should be sorted by latest edit first');
  assert(eventContributors[0]?.contributionCount === 2, 'event editor contribution count should aggregate repeated edits');
  assert(eventContributors[1]?.id === creator.id, 'event creator should remain in contributor list');
  assert(eventContributors[1]?.role === 'creator', 'event creator role should be preserved');

  const djContributors = await fetchContributorEntriesForEntity(prisma, 'dj', dj.id);
  assert(djContributors.length === 2, 'dj contributor list should contain two entries');
  assert(djContributors[0]?.id === editor.id, 'dj contributor list should be sorted by latest edit first');
  assert(djContributors[1]?.id === creator.id, 'dj creator should remain in contributor list');

  const creatorSummary = await fetchContributionCenterSummary(prisma, creator.id);
  assert(creatorSummary.totalContributionCount === 2, 'creator summary should count event and dj create records');
  assert(creatorSummary.contributedEventCount === 1, 'creator summary should count one event');
  assert(creatorSummary.contributedDJCount === 1, 'creator summary should count one dj');
  assert(creatorSummary.recentItems[0]?.entityType === 'dj', 'creator recent history should sort by latest occurredAt');

  const editorPage = await fetchContributionHistoryPage(prisma, editor.id, {
    entityType: 'all',
    limit: 2,
  });
  assert(editorPage.items.length === 2, 'editor first page should respect limit');
  assert(editorPage.hasMore === true, 'editor page should expose hasMore when extra records exist');
  assert(Boolean(editorPage.nextCursor), 'editor page should expose nextCursor when extra records exist');
  assert(editorPage.items[0]?.entityType === 'dj', 'editor history should sort latest contribution first');
  assert(editorPage.items[1]?.entityType === 'event', 'editor history second item should be the second latest event edit');
  assert(
    editorPage.items[1]?.entityTitle === event.name && editorPage.items[1]?.entityCoverImageUrl === event.coverImageUrl,
    'event history should fall back to live snapshot when stored snapshot is empty'
  );

  const editorSecondPage = await fetchContributionHistoryPage(prisma, editor.id, {
    entityType: 'all',
    limit: 2,
    cursor: editorPage.nextCursor,
  });
  assert(editorSecondPage.items.length === 1, 'editor second page should contain the remaining record');
  assert(editorSecondPage.items[0]?.entityType === 'event', 'editor second page should return the oldest event edit');
  assert(editorSecondPage.hasMore === false, 'editor second page should end pagination');

  const eventOnlyPage = await fetchContributionHistoryPage(prisma, editor.id, {
    entityType: 'event',
    limit: 10,
  });
  assert(eventOnlyPage.items.length === 2, 'event filter should only include event edits');
  assert(eventOnlyPage.items.every((item) => item.entityType === 'event'), 'event filter should exclude dj history');

  const djOnlyPage = await fetchContributionHistoryPage(prisma, editor.id, {
    entityType: 'dj',
    limit: 10,
  });
  assert(djOnlyPage.items.length === 1, 'dj filter should only include dj edits');
  assert(djOnlyPage.items[0]?.entityId === dj.id, 'dj filter should point to created dj');

  let invalidCursorThrown = false;
  try {
    await fetchContributionHistoryPage(prisma, editor.id, {
      entityType: 'all',
      limit: 10,
      cursor: 'invalid-cursor',
    });
  } catch (error) {
    invalidCursorThrown = error instanceof InvalidContributionHistoryCursorError;
  }
  assert(invalidCursorThrown, 'invalid cursor should throw InvalidContributionHistoryCursorError');

  logStep('ok', {
    eventId: event.id,
    djId: dj.id,
    creatorUserId: creator.id,
    editorUserId: editor.id,
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
  console.error('[contribution-module-regression] failed:', error);
  process.exit(1);
});
