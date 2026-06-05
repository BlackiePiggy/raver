import type { EntityChangeEntityType } from './entity-change.types';

export type EntityChangeRevisionConflictDetails = {
  entityType: EntityChangeEntityType;
  entityId: string;
  expectedRevision: number | null;
  currentRevision: number | null;
};

export class EntityChangeInvalidRevisionError extends Error {
  readonly code = 'ENTITY_CHANGE_INVALID_REVISION';
  readonly details: {
    rawRevision: unknown;
  };

  constructor(rawRevision: unknown) {
    super('Invalid expected revision');
    this.name = 'EntityChangeInvalidRevisionError';
    this.details = { rawRevision };
  }
}

export class EntityChangeRevisionConflictError extends Error {
  readonly code = 'ENTITY_CHANGE_REVISION_CONFLICT';
  readonly details: EntityChangeRevisionConflictDetails;

  constructor(message: string, details: EntityChangeRevisionConflictDetails) {
    super(message);
    this.name = 'EntityChangeRevisionConflictError';
    this.details = details;
  }
}

export const parseExpectedEntityRevision = (value: unknown): number | null => {
  if (value === null || value === undefined || value === '') return null;
  const parsed = typeof value === 'number'
    ? value
    : typeof value === 'string'
      ? Number(value.trim())
      : NaN;
  if (!Number.isInteger(parsed) || parsed < 0) {
    throw new EntityChangeInvalidRevisionError(value);
  }
  return parsed;
};

export const assertEntityRevisionMatches = (input: {
  entityType: EntityChangeEntityType;
  entityId: string;
  expectedRevision?: number | null;
  currentRevision: number | null;
  message?: string;
}): void => {
  if (input.expectedRevision === null || input.expectedRevision === undefined) return;
  if (input.currentRevision === input.expectedRevision) return;
  throw new EntityChangeRevisionConflictError(
    input.message ?? 'Entity was updated by another operation. Please refresh and retry.',
    {
      entityType: input.entityType,
      entityId: input.entityId,
      expectedRevision: input.expectedRevision,
      currentRevision: input.currentRevision,
    }
  );
};
