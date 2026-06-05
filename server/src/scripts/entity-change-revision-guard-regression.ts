import {
  EntityChangeInvalidRevisionError,
  EntityChangeRevisionConflictError,
  assertEntityRevisionMatches,
  parseExpectedEntityRevision,
} from '../modules/entity-change';

function assert(condition: boolean, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

const run = (): void => {
  assert(parseExpectedEntityRevision(undefined) === null, 'undefined revision should be optional');
  assert(parseExpectedEntityRevision(null) === null, 'null revision should be optional');
  assert(parseExpectedEntityRevision('') === null, 'empty revision should be optional');
  assert(parseExpectedEntityRevision(7) === 7, 'number revision should parse');
  assert(parseExpectedEntityRevision('8') === 8, 'string revision should parse');

  let invalidThrown = false;
  try {
    parseExpectedEntityRevision('8.5');
  } catch (error) {
    invalidThrown = error instanceof EntityChangeInvalidRevisionError
      && error.code === 'ENTITY_CHANGE_INVALID_REVISION';
  }
  assert(invalidThrown, 'non-integer revision should throw invalid revision error');

  assertEntityRevisionMatches({
    entityType: 'event',
    entityId: 'revision-guard-regression',
    expectedRevision: 3,
    currentRevision: 3,
  });
  assertEntityRevisionMatches({
    entityType: 'event',
    entityId: 'revision-guard-regression',
    expectedRevision: null,
    currentRevision: 4,
  });

  let conflict: EntityChangeRevisionConflictError | null = null;
  try {
    assertEntityRevisionMatches({
      entityType: 'brand',
      entityId: 'brand-revision-guard-regression',
      expectedRevision: 5,
      currentRevision: 6,
      message: 'stale brand edit',
    });
  } catch (error) {
    if (error instanceof EntityChangeRevisionConflictError) conflict = error;
  }
  assert(conflict !== null, 'revision mismatch should throw conflict');
  assert(conflict.code === 'ENTITY_CHANGE_REVISION_CONFLICT', 'conflict code should be stable');
  assert(conflict.details.entityType === 'brand', 'conflict should preserve entity type');
  assert(conflict.details.expectedRevision === 5, 'conflict should preserve expected revision');
  assert(conflict.details.currentRevision === 6, 'conflict should preserve current revision');

  console.log('[entity-change-revision-guard-regression] ok');
};

try {
  run();
} catch (error) {
  console.error('[entity-change-revision-guard-regression] failed:', error);
  process.exit(1);
}
