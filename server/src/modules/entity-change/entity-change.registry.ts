import type {
  EntityChangeDefinition,
  EntityChangeEntityType,
} from './entity-change.types';

const definitions = new Map<EntityChangeEntityType, EntityChangeDefinition>();

export const registerEntityChangeDefinition = (definition: EntityChangeDefinition): void => {
  definitions.set(definition.entityType, definition);
};

export const getEntityChangeDefinition = (entityType: EntityChangeEntityType): EntityChangeDefinition => {
  const definition = definitions.get(entityType);
  if (!definition) {
    throw new Error(`Entity change definition is not registered: ${entityType}`);
  }
  return definition;
};

export const listEntityChangeDefinitions = (): EntityChangeDefinition[] =>
  Array.from(definitions.values());
