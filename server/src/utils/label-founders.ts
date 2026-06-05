import { Prisma } from '@prisma/client';
import { INPUT_LIMITS, normalizeSingleLine, normalizeStringArray } from './input-rules';

export type LabelFounderRecord = {
  name: string | null;
  djId: string | null;
};

export type HydratedLabelFounder<TDj> = LabelFounderRecord & {
  dj: TDj | null;
};

const isRecord = (value: unknown): value is Record<string, unknown> =>
  Boolean(value) && typeof value === 'object' && !Array.isArray(value);

export const normalizeLabelFounders = (value: unknown): LabelFounderRecord[] => {
  if (!Array.isArray(value)) return [];

  const founders: LabelFounderRecord[] = [];
  const seen = new Set<string>();

  for (const item of value) {
    if (!isRecord(item)) continue;

    const name = normalizeSingleLine(item.name).slice(0, INPUT_LIMITS.label.founderName) || null;
    const djId = normalizeSingleLine(item.djId).slice(0, INPUT_LIMITS.common.externalId) || null;

    if (!name && !djId) continue;

    const identityKey = `${djId ?? ''}::${(name ?? '').toLowerCase()}`;
    if (seen.has(identityKey)) continue;
    seen.add(identityKey);

    founders.push({ name, djId });

    if (founders.length >= INPUT_LIMITS.label.foundersMaxItems) {
      break;
    }
  }

  return founders;
};

export const normalizeLegacyLabelFounders = (input: {
  founderName?: unknown;
  founderDjIds?: unknown;
}): LabelFounderRecord[] => {
  const founderName = normalizeSingleLine(input.founderName).slice(0, INPUT_LIMITS.label.founderName) || null;
  const founderDjIds = normalizeStringArray(input.founderDjIds, {
    itemMax: INPUT_LIMITS.common.externalId,
    maxItems: INPUT_LIMITS.label.foundersMaxItems,
  });

  if (founderDjIds.length === 0) {
    return founderName ? [{ name: founderName, djId: null }] : [];
  }

  if (founderDjIds.length === 1) {
    return [{ name: founderName, djId: founderDjIds[0] }];
  }

  return normalizeLabelFounders([
    ...founderDjIds.map((djId) => ({ name: null, djId })),
    ...(founderName ? [{ name: founderName, djId: null }] : []),
  ]);
};

export const collectLabelFounderDjIds = (founders: LabelFounderRecord[]): string[] =>
  Array.from(new Set(founders.map((item) => item.djId).filter((item): item is string => Boolean(item))));

export const hydrateLabelFounders = <TDj extends { id: string; name?: string | null }>(
  founders: LabelFounderRecord[],
  djById: Map<string, TDj>
): HydratedLabelFounder<TDj>[] =>
  founders
    .map((item) => {
      const dj = item.djId ? djById.get(item.djId) ?? null : null;
      const djName = typeof dj?.name === 'string' ? dj.name.trim() : '';
      const name = item.name || djName || null;
      if (!name && !item.djId) return null;
      return {
        name,
        djId: item.djId,
        dj,
      };
    })
    .filter((item): item is HydratedLabelFounder<TDj> => Boolean(item));

export const labelFoundersToJson = (founders: LabelFounderRecord[]): Prisma.InputJsonValue =>
  founders.map((item) => ({
    name: item.name,
    djId: item.djId,
  })) as Prisma.InputJsonValue;
