import 'dotenv/config';
import {
  canonicalizeValue,
  hashCanonicalValue,
} from '../modules/entity-change/entity-change-canonicalizer';
import { diffEntitySnapshots } from '../modules/entity-change/entity-change-diff-engine';
import { buildEntityChangeSummary } from '../modules/entity-change/entity-change-summarizer';
import type {
  EntityChangeDefinition,
  EntitySnapshot,
} from '../modules/entity-change';

const assert = (condition: boolean, message: string): void => {
  if (!condition) throw new Error(message);
};

const definition: EntityChangeDefinition = {
  entityType: 'dj',
  snapshotSchemaVersion: 1,
  buildSnapshot: async () => null,
  paths: {
    'profile.name': {
      labelZh: '名称',
      labelEn: 'Name',
      category: 'profile',
      audience: 'public',
      publicSafe: true,
    },
    'profile.tags': {
      labelZh: '标签',
      labelEn: 'Tags',
      category: 'profile',
      audience: 'public',
      publicSafe: true,
      arrayStrategy: { type: 'set' },
    },
    'profile.steps': {
      labelZh: '步骤',
      labelEn: 'Steps',
      category: 'profile',
      audience: 'public',
      publicSafe: true,
      arrayStrategy: { type: 'ordered-list' },
    },
  },
};

const snapshot = (data: Record<string, unknown>): EntitySnapshot => ({
  entityType: 'dj',
  entityId: 'core-regression',
  displayName: 'Core Regression',
  revision: null,
  schemaVersion: 1,
  capturedAt: new Date().toISOString(),
  data,
});

const run = (): void => {
  const left = canonicalizeValue(
    { profile: { tags: ['b', 'a'], name: '  Core   Regression  ' } },
    '',
    definition.paths
  );
  const right = canonicalizeValue(
    { profile: { name: 'Core Regression', tags: ['a', 'b'] } },
    '',
    definition.paths
  );
  assert(hashCanonicalValue(left) === hashCanonicalValue(right), 'canonical hash should ignore object key and set order');

  const scalarDiff = diffEntitySnapshots({
    definition,
    before: snapshot({ profile: { name: 'Before', tags: ['a'], steps: ['one', 'two'] } }),
    after: snapshot({ profile: { name: 'After', tags: ['a'], steps: ['one', 'two'] } }),
  });
  assert(scalarDiff.changes.length === 1, 'scalar name edit should create one change');
  assert(scalarDiff.publicChanges[0]?.before === 'Before', 'scalar diff should expose old value');
  assert(scalarDiff.publicChanges[0]?.after === 'After', 'scalar diff should expose new value');
  assert(scalarDiff.publicChanges[0]?.labelEn === 'Name', 'public diff should expose English label');
  assert(scalarDiff.publicChanges[0]?.labelJa === '名称', 'public diff should expose Japanese label fallback');

  const summary = buildEntityChangeSummary({
    entityType: 'dj',
    displayName: 'Core Regression',
    changes: scalarDiff.changes,
    publicChanges: scalarDiff.publicChanges,
  });
  assert(summary.publicSummaryEn?.includes('DJ "Core Regression" was updated') === true, 'English summary should be generated');
  assert(summary.publicSummaryJa?.includes('DJ「Core Regression」が更新されました') === true, 'Japanese summary should be generated');
  const publicDetailPayload = {
    id: 'core-change-log',
    entityType: 'dj',
    entityId: 'core-regression',
    operationType: 'update',
    changeCount: scalarDiff.changes.length,
    summaries: {
      zh: summary.publicSummaryZh,
      en: summary.publicSummaryEn ?? summary.publicSummaryZh,
      ja: summary.publicSummaryJa ?? summary.publicSummaryZh,
    },
    publicChanges: scalarDiff.publicChanges,
    createdAt: new Date('2026-06-05T00:00:00.000Z').toISOString(),
  };
  assert(publicDetailPayload.summaries.en?.includes('Core Regression') === true, 'public detail payload should include English summary');
  assert(publicDetailPayload.summaries.ja?.includes('Core Regression') === true, 'public detail payload should include Japanese summary');
  assert(publicDetailPayload.publicChanges[0]?.labelEn === 'Name', 'public detail payload should include English public change label');
  assert(publicDetailPayload.publicChanges[0]?.labelJa === '名称', 'public detail payload should include Japanese public change label');
  assert(
    !Object.prototype.hasOwnProperty.call(publicDetailPayload, 'changes'),
    'public detail payload must not expose private changes'
  );

  const orderedDiff = diffEntitySnapshots({
    definition,
    before: snapshot({ profile: { name: 'Core', tags: ['a'], steps: ['one', 'two'] } }),
    after: snapshot({ profile: { name: 'Core', tags: ['a'], steps: ['two', 'one'] } }),
  });
  assert(
    orderedDiff.changes.some((change) => change.kind === 'reordered' && change.path === 'profile.steps'),
    'ordered-list reorder should create reordered change'
  );

  console.log('[entity-change-core-regression] ok');
};

try {
  run();
} catch (error) {
  console.error('[entity-change-core-regression] failed:', error);
  process.exit(1);
}
