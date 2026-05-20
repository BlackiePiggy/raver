import { Prisma } from '@prisma/client';

export type CanonicalLineupArtistInput = {
  id?: string;
  djId: string | null;
  djIds: string[];
  djName: string;
  sortOrder: number;
};

export type CanonicalLineupSlotInput = {
  id?: string;
  lineupArtistId?: string | null;
  djId: string | null;
  djIds: string[];
  djName: string;
  stageName: string | null;
  festivalDayIndex: number | null;
  startTime: Date;
  endTime: Date;
  sortOrder: number;
};

type CanonicalLineupSnapshot = {
  artists: CanonicalLineupArtistInput[];
  slots: CanonicalLineupSlotInput[];
  stageOrder: string[];
};

const uniqueIds = (values: Array<string | null | undefined>): string[] => {
  const seen = new Set<string>();
  const result: string[] = [];
  for (const value of values) {
    const id = String(value || '').trim();
    if (!id || seen.has(id)) continue;
    seen.add(id);
    result.push(id);
  }
  return result;
};

export const normalizeCanonicalLineupName = (value: string): string =>
  value
    .trim()
    .toLowerCase()
    .replace(/\s+/g, ' ');

const canonicalLineupKey = (artist: Pick<CanonicalLineupArtistInput, 'djId' | 'djName'>): string =>
  artist.djId ? `id:${artist.djId}` : `name:${normalizeCanonicalLineupName(artist.djName)}`;

export const buildCanonicalLineupArtistsFromSlots = (
  slots: CanonicalLineupSlotInput[]
): CanonicalLineupArtistInput[] => {
  const byKey = new Map<string, CanonicalLineupArtistInput>();
  for (const [index, slot] of slots.entries()) {
    const djName = String(slot.djName || '').trim();
    if (!djName) continue;
    const djIds = uniqueIds(slot.djIds);
    const primaryDjId = slot.djId || djIds[0] || null;
    const key = primaryDjId ? `id:${primaryDjId}` : `name:${normalizeCanonicalLineupName(djName)}`;
    const existing = byKey.get(key);
    if (existing) {
      existing.djIds = uniqueIds([...existing.djIds, ...djIds, primaryDjId]);
      if (!existing.djId && primaryDjId) existing.djId = primaryDjId;
      existing.sortOrder = Math.min(existing.sortOrder, slot.sortOrder || index + 1);
      continue;
    }
    byKey.set(key, {
      djId: primaryDjId,
      djIds: uniqueIds([...djIds, primaryDjId]),
      djName,
      sortOrder: slot.sortOrder || index + 1,
    });
  }
  return Array.from(byKey.values()).sort((a, b) => a.sortOrder - b.sortOrder);
};

export const normalizeCanonicalLineupArtists = (
  artists: CanonicalLineupArtistInput[],
  fallbackSlots: CanonicalLineupSlotInput[] = []
): CanonicalLineupArtistInput[] => {
  if (!artists.length) return buildCanonicalLineupArtistsFromSlots(fallbackSlots);

  const byKey = new Map<string, CanonicalLineupArtistInput>();
  for (const [index, raw] of artists.entries()) {
    const djName = String(raw.djName || '').trim();
    if (!djName) continue;
    const djIds = uniqueIds(raw.djIds);
    const djId = raw.djId || djIds[0] || null;
    const mergedIds = uniqueIds([...djIds, djId]);
    const sortOrder = Number.isFinite(raw.sortOrder) ? raw.sortOrder : index + 1;
    const key = djId ? `id:${djId}` : `name:${normalizeCanonicalLineupName(djName)}`;
    const existing = byKey.get(key);
    if (existing) {
      existing.djIds = uniqueIds([...existing.djIds, ...mergedIds]);
      existing.sortOrder = Math.min(existing.sortOrder, sortOrder);
      if (!existing.id && raw.id) existing.id = raw.id;
      continue;
    }
    byKey.set(key, {
      id: raw.id,
      djId,
      djIds: mergedIds,
      djName,
      sortOrder,
    });
  }
  return Array.from(byKey.values()).sort((a, b) => a.sortOrder - b.sortOrder);
};

export const loadCanonicalEventLineupSnapshot = async (
  db: Prisma.TransactionClient | Prisma.DefaultPrismaClient,
  eventId: string
): Promise<CanonicalLineupSnapshot> => {
  const [artists, stages, performances] = await Promise.all([
    db.eventArtist.findMany({
      where: { eventId },
      include: {
        members: {
          orderBy: { memberOrder: 'asc' },
          select: { djId: true, memberNameSnapshot: true },
        },
      },
      orderBy: [{ billingOrder: 'asc' }, { createdAt: 'asc' }],
    }),
    db.eventStage.findMany({
      where: { eventId },
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
    }),
    db.eventPerformance.findMany({
      where: { eventId },
      include: {
        eventArtist: {
          select: {
            id: true,
            displayName: true,
            primaryDjId: true,
            members: {
              orderBy: { memberOrder: 'asc' },
              select: { djId: true },
            },
          },
        },
      },
      orderBy: [{ startAt: 'asc' }, { sortOrder: 'asc' }, { createdAt: 'asc' }],
    }),
  ]);

  const stageNameById = new Map(stages.map((stage) => [stage.id, stage.name]));

  return {
    artists: artists.map((artist) => ({
      id: artist.id,
      djId: artist.primaryDjId,
      djIds: uniqueIds(artist.members.map((member) => member.djId)),
      djName: artist.displayName,
      sortOrder: artist.billingOrder,
    })),
    slots: performances.map((slot) => ({
      id: slot.id,
      lineupArtistId: slot.eventArtistId,
      djId: slot.eventArtist.primaryDjId,
      djIds: uniqueIds(slot.eventArtist.members.map((member) => member.djId)),
      djName: slot.displayNameSnapshot || slot.eventArtist.displayName,
      stageName: slot.stageId ? stageNameById.get(slot.stageId) ?? null : null,
      festivalDayIndex: slot.festivalDayIndex ?? null,
      startTime: slot.startAt ?? slot.createdAt,
      endTime: slot.endAt ?? slot.startAt ?? slot.createdAt,
      sortOrder: slot.sortOrder,
    })),
    stageOrder: stages.map((stage) => stage.name),
  };
};

export const syncCanonicalEventLineupAndTimetable = async (
  tx: Prisma.TransactionClient,
  eventId: string,
  slots: CanonicalLineupSlotInput[],
  artists: CanonicalLineupArtistInput[],
  explicitStageOrder: string[] = []
): Promise<void> => {
  await tx.eventPerformance.deleteMany({ where: { eventId } });
  await tx.eventArtistMember.deleteMany({ where: { eventArtist: { eventId } } });
  await tx.eventArtist.deleteMany({ where: { eventId } });
  await tx.eventStage.deleteMany({ where: { eventId } });

  const canonicalArtists = normalizeCanonicalLineupArtists(artists, slots);
  const artistIdsByKey = new Map<string, string>();
  for (const [index, artist] of canonicalArtists.entries()) {
    const memberIds = uniqueIds([...(artist.djIds || []), artist.djId]);
    const created = await tx.eventArtist.create({
      data: {
        ...(artist.id ? { id: artist.id } : {}),
        eventId,
        displayName: artist.djName,
        normalizedName: normalizeCanonicalLineupName(artist.djName),
        actType: memberIds.length > 1 ? 'group' : 'solo',
        primaryDjId: artist.djId,
        billingOrder: artist.sortOrder || index + 1,
        sourceType: 'manual',
        isTimetableOnly: false,
        members: {
          create: (memberIds.length ? memberIds : [null]).map((djId, memberIndex) => ({
            djId,
            memberNameSnapshot: artist.djName,
            memberOrder: memberIndex + 1,
            role: 'performer',
          })),
        },
      },
    });
    artistIdsByKey.set(canonicalLineupKey(artist), created.id);
    artistIdsByKey.set(`name:${normalizeCanonicalLineupName(artist.djName)}`, created.id);
    if (artist.djId) artistIdsByKey.set(`id:${artist.djId}`, created.id);
  }

  const orderedStageNames = uniqueIds([
    ...explicitStageOrder,
    ...slots.map((slot) => slot.stageName).filter((value): value is string => Boolean(value)),
  ]);
  const stageIdsByName = new Map<string, string>();
  for (const [index, name] of orderedStageNames.entries()) {
    const normalizedName = normalizeCanonicalLineupName(name);
    const stage = await tx.eventStage.create({
      data: {
        eventId,
        name,
        normalizedName,
        sortOrder: index + 1,
      },
    });
    stageIdsByName.set(normalizedName, stage.id);
  }

  for (const [index, slot] of slots.entries()) {
    const slotName = slot.djName || 'Unknown DJ';
    let eventArtistId =
      (slot.lineupArtistId && canonicalArtists.some((artist) => artist.id === slot.lineupArtistId) ? slot.lineupArtistId : null)
      || artistIdsByKey.get(canonicalLineupKey({ djId: slot.djId, djName: slotName }))
      || artistIdsByKey.get(`name:${normalizeCanonicalLineupName(slotName)}`);

    if (!eventArtistId) {
      const memberIds = uniqueIds([...(slot.djIds || []), slot.djId]);
      const created = await tx.eventArtist.create({
        data: {
          eventId,
          displayName: slotName,
          normalizedName: normalizeCanonicalLineupName(slotName),
          actType: memberIds.length > 1 ? 'group' : 'solo',
          primaryDjId: slot.djId,
          billingOrder: canonicalArtists.length + index + 1,
          sourceType: 'manual',
          isTimetableOnly: true,
          members: {
            create: (memberIds.length ? memberIds : [null]).map((djId, memberIndex) => ({
              djId,
              memberNameSnapshot: slotName,
              memberOrder: memberIndex + 1,
              role: 'performer',
            })),
          },
        },
      });
      eventArtistId = created.id;
      artistIdsByKey.set(`name:${normalizeCanonicalLineupName(slotName)}`, created.id);
      if (slot.djId) artistIdsByKey.set(`id:${slot.djId}`, created.id);
    }

    const stageId = slot.stageName ? stageIdsByName.get(normalizeCanonicalLineupName(slot.stageName)) ?? null : null;
    await tx.eventPerformance.create({
      data: {
        ...(slot.id ? { id: slot.id } : {}),
        eventId,
        eventArtistId,
        stageId,
        displayNameSnapshot: slotName,
        festivalDayIndex: slot.festivalDayIndex ?? null,
        startAt: slot.startTime,
        endAt: slot.endTime,
        sortOrder: slot.sortOrder || index + 1,
        status: 'scheduled',
        sourceType: 'manual',
      },
    });
  }
};
