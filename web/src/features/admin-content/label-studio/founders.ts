import type {
  LabelStudioFounderBinding,
  LabelStudioFounderCreateItem,
  LabelStudioFounderDraftItem,
  LabelStudioLoadedFounderItem,
} from './types';
import { INPUT_LIMITS, normalizeSingleLine } from '@/lib/input-rules';

export const createEmptyFounderDraftItem = (): LabelStudioFounderDraftItem => ({
  id: crypto.randomUUID(),
  name: '',
  djId: null,
  dj: null,
});

export const createBoundFounderDraftItem = (
  binding: LabelStudioFounderBinding
): LabelStudioFounderDraftItem => ({
  id: crypto.randomUUID(),
  name: binding.name,
  djId: binding.id,
  dj: binding,
});

export const hydrateFounderDraftItems = (
  founders: LabelStudioLoadedFounderItem[]
): LabelStudioFounderDraftItem[] =>
  founders.map((item) => ({
    id: crypto.randomUUID(),
    name: item.name || item.dj?.name || '',
    djId: item.djId || item.dj?.id || null,
    dj: item.dj || null,
  }));

export const appendBoundFounderDraftItem = (
  current: LabelStudioFounderDraftItem[],
  binding: LabelStudioFounderBinding
): LabelStudioFounderDraftItem[] => {
  if (current.some((item) => item.djId === binding.id)) return current;
  if (current.length >= INPUT_LIMITS.label.foundersMaxItems) return current;
  return [...current, createBoundFounderDraftItem(binding)];
};

export const normalizeFounderCreateItems = (
  founders: LabelStudioFounderDraftItem[]
): LabelStudioFounderCreateItem[] => {
  const next: LabelStudioFounderCreateItem[] = [];
  const seen = new Set<string>();

  for (const founder of founders) {
    const name = normalizeSingleLine(founder.name).slice(0, INPUT_LIMITS.label.founderName) || null;
    const djId = normalizeSingleLine(founder.djId).slice(0, INPUT_LIMITS.common.externalId) || null;
    const fallbackName = founder.dj ? normalizeSingleLine(founder.dj.name).slice(0, INPUT_LIMITS.label.founderName) : '';
    const resolvedName = name || fallbackName || null;
    if (!resolvedName && !djId) continue;

    const identityKey = `${djId ?? ''}::${(resolvedName ?? '').toLowerCase()}`;
    if (seen.has(identityKey)) continue;
    seen.add(identityKey);

    next.push({
      name: resolvedName,
      djId,
    });

    if (next.length >= INPUT_LIMITS.label.foundersMaxItems) {
      break;
    }
  }

  return next;
};
