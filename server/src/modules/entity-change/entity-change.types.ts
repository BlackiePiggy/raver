import type { Prisma, PrismaClient } from '@prisma/client';

export type EntityChangeEntityType = 'event' | 'dj' | 'brand' | 'djSet' | 'news' | 'post' | 'label';

export type EntityChangeOperationType = 'create' | 'update' | 'delete' | 'system_sync';

export type EntityChangeAudience = 'private' | 'operator' | 'public';

export type EntityChangeKind = 'added' | 'removed' | 'updated' | 'reordered';

export type EntityChangeDb = PrismaClient | Prisma.TransactionClient;

export type EntityChangeSnapshotRole = 'before' | 'after';

export type EntitySnapshot = {
  entityType: EntityChangeEntityType;
  entityId: string;
  displayName: string;
  revision: number | null;
  schemaVersion: number;
  capturedAt: string;
  data: Record<string, unknown>;
};

export type ArrayDiffStrategy =
  | { type: 'set'; itemIdentity?: 'value' | 'hash' }
  | { type: 'ordered-list'; itemIdentity?: 'index' | 'key'; keyPath?: string }
  | { type: 'keyed-list'; keyPath: string; orderMatters: boolean };

export type FormattedValue = {
  zh: string | null;
  en: string | null;
  ja?: string | null;
};

export type ValueFormatter = (value: unknown, context: {
  path: string;
  entityType: EntityChangeEntityType;
  snapshot?: EntitySnapshot | null;
}) => FormattedValue;

export type ChangePathConfig = {
  labelZh: string;
  labelEn: string;
  labelJa?: string;
  category: string;
  audience: EntityChangeAudience;
  publicSafe: boolean;
  sensitive?: boolean;
  arrayStrategy?: ArrayDiffStrategy;
  emptyStringEqualsNull?: boolean;
  formatter?: ValueFormatter;
  priority?: number;
};

export type EntityChange = {
  id: string;
  kind: EntityChangeKind;
  path: string;
  pathLabelZh: string;
  pathLabelEn: string;
  pathLabelJa: string;
  category: string;
  audience: EntityChangeAudience;
  publicSafe: boolean;
  sensitive: boolean;
  before: unknown;
  after: unknown;
  beforeDisplayZh: string | null;
  afterDisplayZh: string | null;
  beforeDisplayEn: string | null;
  afterDisplayEn: string | null;
  beforeDisplayJa: string | null;
  afterDisplayJa: string | null;
  itemKey?: string | null;
  itemLabelZh?: string | null;
  itemLabelEn?: string | null;
};

export type PublicEntityChange = {
  path: string;
  label: string;
  labelZh: string;
  labelEn: string;
  labelJa: string;
  kind: EntityChangeKind;
  before: string | null;
  after: string | null;
  beforeEn: string | null;
  afterEn: string | null;
  beforeJa: string | null;
  afterJa: string | null;
};

export type EntityChangeSummary = {
  privateSummaryZh: string | null;
  operatorSummaryZh: string | null;
  publicSummaryZh: string | null;
  privateSummaryEn: string | null;
  operatorSummaryEn: string | null;
  publicSummaryEn: string | null;
  privateSummaryJa: string | null;
  operatorSummaryJa: string | null;
  publicSummaryJa: string | null;
};

export type EntityChangeResult = {
  entityType: EntityChangeEntityType;
  entityId: string;
  operationType: EntityChangeOperationType;
  displayName: string;
  snapshotSchemaVersion: number;
  diffSchemaVersion: number;
  revisionBefore: number | null;
  revisionAfter: number | null;
  beforeHash: string | null;
  afterHash: string | null;
  changed: boolean;
  changeCount: number;
  changes: EntityChange[];
  publicChanges: PublicEntityChange[];
  summary: EntityChangeSummary;
};

export type EntityChangeDefinition = {
  entityType: EntityChangeEntityType;
  snapshotSchemaVersion: number;
  buildSnapshot: (input: {
    entityId: string;
    db: EntityChangeDb;
  }) => Promise<EntitySnapshot | null>;
  paths: Record<string, ChangePathConfig>;
};

export type PersistEntityChangeInput = {
  result: EntityChangeResult;
  snapshots?: {
    before?: EntitySnapshot | null;
    after?: EntitySnapshot | null;
  };
  snapshotArchiveRetentionDays?: number;
  actorId?: string | null;
  actorRole?: string | null;
  source?: string | null;
  sourceRoute?: string | null;
  requestId?: string | null;
  metadata?: Record<string, unknown>;
};

export type EntityChangeLogRecord = {
  id: string;
  entityType: string;
  entityId: string;
  operationType: string;
  changeCount: number;
  publicSummaryZh: string | null;
  createdAt: Date;
};
