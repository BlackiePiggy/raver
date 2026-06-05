import type { EntityChange, PublicEntityChange } from './entity-change.types';

export const toPublicChanges = (changes: EntityChange[]): PublicEntityChange[] =>
  changes
    .filter((change) => change.publicSafe && change.audience === 'public')
    .map((change) => ({
      path: change.path,
      label: change.pathLabelZh,
      labelZh: change.pathLabelZh,
      labelEn: change.pathLabelEn,
      labelJa: change.pathLabelJa,
      kind: change.kind,
      before: change.beforeDisplayZh,
      after: change.afterDisplayZh,
      beforeEn: change.beforeDisplayEn,
      afterEn: change.afterDisplayEn,
      beforeJa: change.beforeDisplayJa,
      afterJa: change.afterDisplayJa,
    }));
