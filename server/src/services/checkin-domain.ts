import { Prisma } from '@prisma/client';

export type EventBiTextPayload = {
  en: string;
  zh: string;
  enFull?: string;
};

export type NormalizedSelectionDJ = {
  djId: string | null;
  displayName: string;
  rawName: string;
  actType: 'solo' | 'b2b' | 'b3b';
  performerIndex: number;
  actGroupId: string;
};

export type NormalizedSelection = {
  dayId: string;
  dayIndex: number;
  djs: NormalizedSelectionDJ[];
};

export type CheckinSelectionInput = {
  dayId?: string | null;
  dayIndex?: number | null;
  djs?: Array<{
    djId?: string | null;
    displayName?: string | null;
    actType?: string | null;
    performerIndex?: number | null;
    actGroupId?: string | null;
  }> | null;
};

export type SnapshotEventLite = {
  name: string;
  nameI18n: Prisma.JsonValue | null;
  coverImageUrl: string | null;
  city: string | null;
  country: string | null;
  venueAddress: string | null;
  manualLocation: Prisma.JsonValue | null;
  startDate: Date;
  endDate: Date;
} | null;

export type SnapshotDJLite = {
  name: string;
  nameI18n: Prisma.JsonValue | null;
  avatarUrl: string | null;
  country: string | null;
} | null;

type StoredSelectionLite = {
  dayId: string;
  dayIndex: number;
  djs: Array<{
    djId: string | null;
    displayName: string;
    rawName: string;
    actType: string | null;
    performerIndex: number;
    actGroupId: string | null;
  }>;
};

const normalizeText = (value: unknown): string => {
  if (typeof value !== 'string') return '';
  return value.trim();
};

export const normalizeNullableText = (value: unknown): string | null => {
  const normalized = normalizeText(value);
  return normalized.length > 0 ? normalized : null;
};

export const normalizeActType = (value: unknown): 'solo' | 'b2b' | 'b3b' | null => {
  const normalized = normalizeText(value).toLowerCase();
  if (normalized === 'solo' || normalized === 'b2b' || normalized === 'b3b') {
    return normalized;
  }
  return null;
};

export const normalizeInt = (value: unknown, fallback = 0): number => {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.max(0, Math.floor(parsed));
};

export const normalizeBiText = (value: unknown, fallback = ''): EventBiTextPayload | null => {
  const fallbackText = normalizeText(fallback);
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    const row = value as Record<string, unknown>;
    const en = normalizeText(row.en ?? row.EN ?? row.english) || fallbackText;
    const zh = normalizeText(row.zh ?? row.ZH ?? row.cn ?? row.chinese) || en || fallbackText;
    const enFull = normalizeText(
      row.enFull ?? row.en_full ?? row.englishFull ?? row.country_en_full
    );
    const normalizedEn = en || zh || fallbackText;
    const normalizedZh = zh || en || fallbackText;
    if (!normalizedEn && !normalizedZh) return null;
    const out: EventBiTextPayload = {
      en: normalizedEn,
      zh: normalizedZh,
    };
    if (enFull) out.enFull = enFull;
    return out;
  }

  const plain = normalizeText(value) || fallbackText;
  if (!plain) return null;
  return {
    en: plain,
    zh: plain,
  };
};

export const resolveEventAddress = (event: {
  venueAddress?: string | null;
  manualLocation?: Prisma.JsonValue | null;
  city?: string | null;
  country?: string | null;
} | null): string | null => {
  if (!event) return null;
  const venueAddress = normalizeText(event.venueAddress);
  if (venueAddress) return venueAddress;
  const manualLocation =
    event.manualLocation && typeof event.manualLocation === 'object' && !Array.isArray(event.manualLocation)
      ? (event.manualLocation as Record<string, unknown>)
      : null;
  const manualAddress = normalizeText(
    manualLocation?.address ?? manualLocation?.formattedAddress ?? manualLocation?.displayName
  );
  if (manualAddress) return manualAddress;
  const city = normalizeText(event.city);
  const country = normalizeText(event.country);
  const fallback = [city, country].filter(Boolean).join(', ');
  return fallback || null;
};

export const normalizeSelections = (
  raw: unknown
): {
  normalizedSelections: NormalizedSelection[];
  validationError: string | null;
} => {
  if (raw == null) {
    return { normalizedSelections: [], validationError: null };
  }

  if (!Array.isArray(raw)) {
    return { normalizedSelections: [], validationError: 'selections must be an array' };
  }

  const normalizedSelections: NormalizedSelection[] = [];

  for (let selectionIndex = 0; selectionIndex < raw.length; selectionIndex += 1) {
    const selection = raw[selectionIndex];
    if (!selection || typeof selection !== 'object' || Array.isArray(selection)) {
      return { normalizedSelections: [], validationError: `selection[${selectionIndex}] must be an object` };
    }

    const row = selection as CheckinSelectionInput;
    const dayId = normalizeText(row.dayId) || `day-${selectionIndex + 1}`;
    const dayIndex = normalizeInt(row.dayIndex, selectionIndex + 1);
    const sourceDJs = Array.isArray(row.djs) ? row.djs : [];
    const normalizedDJs: NormalizedSelectionDJ[] = [];

    for (let djIndex = 0; djIndex < sourceDJs.length; djIndex += 1) {
      const sourceDJ = sourceDJs[djIndex] ?? {};
      const djId = normalizeNullableText(sourceDJ.djId);
      const displayName = normalizeText(sourceDJ.displayName);
      if (!displayName) {
        return {
          normalizedSelections: [],
          validationError: `selection[${selectionIndex}].djs[${djIndex}] must include displayName`,
        };
      }

      const actType = normalizeActType(sourceDJ.actType) ?? 'solo';
      const actGroupId =
        normalizeText(sourceDJ.actGroupId) || `${dayId}-act-${selectionIndex + 1}-${djIndex + 1}`;
      const performerIndex = normalizeInt(sourceDJ.performerIndex, djIndex);

      normalizedDJs.push({
        djId,
        displayName,
        rawName: displayName,
        actType,
        performerIndex,
        actGroupId,
      });
    }

    normalizedSelections.push({
      dayId,
      dayIndex,
      djs: normalizedDJs,
    });
  }

  return { normalizedSelections, validationError: null };
};

export const hydrateStoredSelections = (selections: StoredSelectionLite[]): NormalizedSelection[] =>
  selections.map((selection) => ({
    dayId: selection.dayId,
    dayIndex: selection.dayIndex,
    djs: selection.djs.map((dj, index) => ({
      djId: dj.djId,
      displayName: dj.displayName,
      rawName: dj.rawName,
      actType: normalizeActType(dj.actType) ?? 'solo',
      performerIndex: dj.performerIndex,
      actGroupId: normalizeText(dj.actGroupId) || `${selection.dayId}-act-${selection.dayIndex}-${index + 1}`,
    })),
  }));

export const buildSelectionSummary = (selections: NormalizedSelection[]): Prisma.JsonObject => {
  const artistIds = Array.from(
    new Set(
      selections.flatMap((selection) =>
        selection.djs.map((dj) => dj.djId).filter((value): value is string => Boolean(value))
      )
    )
  );

  const performanceGroups = Array.from(
    new Set(
      selections.flatMap((selection) =>
        selection.djs.map((dj) => `${selection.dayId}:${dj.actGroupId}`)
      )
    )
  );

  return {
    dayCount: selections.length,
    artistIds,
    performanceGroups,
    days: selections.map((selection) => ({
      dayId: selection.dayId,
      dayIndex: selection.dayIndex,
      djs: selection.djs.map((dj) => ({
        djId: dj.djId,
        displayName: dj.displayName,
        rawName: dj.rawName,
        actType: dj.actType,
        performerIndex: dj.performerIndex,
        actGroupId: dj.actGroupId,
      })),
    })),
  };
};

export const createSnapshotData = (
  userDisplayName: string | null,
  visibility: 'private' | 'visible',
  selections: NormalizedSelection[],
  event: SnapshotEventLite,
  dj: SnapshotDJLite
): Omit<Prisma.CheckinSnapshotUncheckedCreateInput, 'checkinId'> => {
  const primarySelectionDJ = selections.flatMap((selection) => selection.djs)[0] ?? null;
  const eventNameI18n = normalizeBiText(event?.nameI18n, event?.name ?? '');
  const primaryDjNameI18n = normalizeBiText(
    dj?.nameI18n,
    dj?.name ?? primarySelectionDJ?.displayName ?? ''
  );

  return {
    userDisplayName,
    eventName: event?.name ?? null,
    eventNameI18n: eventNameI18n ? (eventNameI18n as Prisma.InputJsonValue) : Prisma.DbNull,
    eventCoverUrl: event?.coverImageUrl ?? null,
    eventCity: event?.city ?? null,
    eventCountry: event?.country ?? null,
    eventAddress: resolveEventAddress(event) ?? null,
    eventStartAt: event?.startDate ?? null,
    eventEndAt: event?.endDate ?? null,
    primaryDjName: dj?.name ?? primarySelectionDJ?.displayName ?? null,
    primaryDjNameI18n: primaryDjNameI18n
      ? (primaryDjNameI18n as Prisma.InputJsonValue)
      : Prisma.DbNull,
    primaryDjAvatarUrl: dj?.avatarUrl ?? null,
    primaryDjCountry: dj?.country ?? null,
    selectionSummary: buildSelectionSummary(selections) as Prisma.InputJsonValue,
    visibilityResolved: visibility,
    snapshotVersion: 1,
    generatedAt: new Date(),
  };
};
