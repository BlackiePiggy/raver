import 'dotenv/config';
import { entityChangeService, type EntitySnapshot } from '../modules/entity-change';

const assert = (condition: boolean, message: string): void => {
  if (!condition) throw new Error(message);
};

const snapshot = (data: Record<string, unknown>): EntitySnapshot => ({
  entityType: 'event',
  entityId: 'regression-event',
  displayName: 'Regression Event',
  revision: 1,
  schemaVersion: 1,
  capturedAt: new Date().toISOString(),
  data,
});

const baseData = {
  profile: {
    name: 'Regression Event',
    status: 'upcoming',
  },
  media: {},
  organizer: {},
  location: {
    venueName: 'Club A',
  },
  schedule: {
    startDate: '2026-06-01T12:00:00.000Z',
    endDate: '2026-06-02T12:00:00.000Z',
    scheduleMode: 'single_day',
    timeZone: 'Asia/Shanghai',
    startTime: '20:00:00',
    endTime: '23:59:59',
    dayRolloverHour: 6,
    weeks: [],
    eventDays: [],
  },
  tickets: {
    tiers: [],
  },
  lineup: {
    stages: [{ normalizedName: 'main', name: 'Main', sortOrder: 1 }],
    artists: [{ artistIdentity: 'dj-a', displayName: 'DJ A', billingOrder: 1 }],
    performances: [
      {
        identityKey: 'perf-a',
        displayNameSnapshot: 'DJ A',
        stageName: 'Main',
        startAt: '2026-06-01T14:00:00.000Z',
        endAt: '2026-06-01T15:00:00.000Z',
      },
    ],
  },
  links: {
    referenceLinks: [],
  },
};

const run = async (): Promise<void> => {
  const changed = await entityChangeService.diffSnapshots({
    entityType: 'event',
    entityId: 'regression-event',
    operationType: 'update',
    before: snapshot(baseData),
    after: snapshot({
      ...baseData,
      lineup: {
        ...baseData.lineup,
        performances: [
          {
            ...baseData.lineup.performances[0],
            stageName: 'Warehouse',
            startAt: '2026-06-01T15:00:00.000Z',
          },
        ],
      },
    }),
  });
  assert(changed.changeCount >= 2, 'Event performance stage/time edits should create specific changes');
  assert(
    changed.publicChanges.some((change) => change.path.includes('lineup.performances.perf-a.stageName')),
    'Event performance stage change should be keyed by identityKey'
  );
  assert(
    changed.publicChanges.some((change) => change.before === 'Main' && change.after === 'Warehouse'),
    'Event performance stage change should expose old/new values'
  );
  console.log('[entity-change-event-regression] ok');
};

run().catch((error) => {
  console.error('[entity-change-event-regression] failed:', error);
  process.exit(1);
});
