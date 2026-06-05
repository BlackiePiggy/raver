import 'dotenv/config';
import { entityChangeService, type EntitySnapshot } from '../modules/entity-change';

const assert = (condition: boolean, message: string): void => {
  if (!condition) throw new Error(message);
};

const snapshot = (data: Record<string, unknown>): EntitySnapshot => ({
  entityType: 'dj',
  entityId: 'regression-dj',
  displayName: 'Regression DJ',
  revision: null,
  schemaVersion: 1,
  capturedAt: new Date().toISOString(),
  data,
});

const baseData = {
  profile: {
    name: 'Regression DJ',
    aliases: ['Alias A', 'Alias B'],
    genres: ['Techno', 'House'],
    bio: 'Original bio',
    country: 'Germany',
    isVerified: true,
  },
  media: {
    avatarUrl: 'https://example.com/avatar-a.jpg',
  },
  links: {},
  platform: {},
  source: {},
};

const run = async (): Promise<void> => {
  const reordered = await entityChangeService.diffSnapshots({
    entityType: 'dj',
    entityId: 'regression-dj',
    operationType: 'update',
    before: snapshot(baseData),
    after: snapshot({
      ...baseData,
      profile: {
        ...baseData.profile,
        genres: ['House', 'Techno'],
        aliases: ['Alias B', 'Alias A'],
      },
    }),
  });
  assert(reordered.changeCount === 0, 'DJ genres/aliases reorder should not create changes');

  const changed = await entityChangeService.diffSnapshots({
    entityType: 'dj',
    entityId: 'regression-dj',
    operationType: 'update',
    before: snapshot(baseData),
    after: snapshot({
      ...baseData,
      profile: {
        ...baseData.profile,
        genres: ['Techno', 'House', 'Hard Techno'],
      },
    }),
  });
  assert(changed.changeCount === 1, 'DJ genre add should create one change');
  assert(changed.publicChanges[0]?.after === 'Hard Techno', 'DJ genre add should expose public after value');
  console.log('[entity-change-dj-regression] ok');
};

run().catch((error) => {
  console.error('[entity-change-dj-regression] failed:', error);
  process.exit(1);
});
