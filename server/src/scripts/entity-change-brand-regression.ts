import 'dotenv/config';
import { entityChangeService, type EntitySnapshot } from '../modules/entity-change';

const assert = (condition: boolean, message: string): void => {
  if (!condition) throw new Error(message);
};

const snapshot = (data: Record<string, unknown>): EntitySnapshot => ({
  entityType: 'brand',
  entityId: 'regression-brand',
  displayName: 'Regression Brand',
  revision: 1,
  schemaVersion: 1,
  capturedAt: new Date().toISOString(),
  data,
});

const baseData = {
  profile: {
    name: 'Regression Brand',
    aliases: ['RB', 'Regression'],
    tagline: 'Original tagline',
    introduction: 'Original intro',
    isActive: true,
  },
  region: {
    country: 'Belgium',
    city: 'Boom',
  },
  basics: {
    foundedYear: '2005',
    frequency: 'annual',
  },
  media: {},
  links: {
    links: [],
  },
  bindings: {
    eventIds: [],
    postIds: [],
    newsIds: [],
  },
};

const run = async (): Promise<void> => {
  const reordered = await entityChangeService.diffSnapshots({
    entityType: 'brand',
    entityId: 'regression-brand',
    operationType: 'update',
    before: snapshot(baseData),
    after: snapshot({
      ...baseData,
      profile: {
        ...baseData.profile,
        aliases: ['Regression', 'RB'],
      },
    }),
  });
  assert(reordered.changeCount === 0, 'Brand aliases reorder should not create changes');

  const changed = await entityChangeService.diffSnapshots({
    entityType: 'brand',
    entityId: 'regression-brand',
    operationType: 'update',
    before: snapshot(baseData),
    after: snapshot({
      ...baseData,
      region: {
        ...baseData.region,
        city: 'Antwerp',
      },
    }),
  });
  assert(changed.changeCount === 1, 'Brand city change should create one change');
  assert(changed.publicChanges[0]?.before === 'Boom', 'Brand city change should expose old value');
  assert(changed.publicChanges[0]?.after === 'Antwerp', 'Brand city change should expose new value');
  console.log('[entity-change-brand-regression] ok');
};

run().catch((error) => {
  console.error('[entity-change-brand-regression] failed:', error);
  process.exit(1);
});
