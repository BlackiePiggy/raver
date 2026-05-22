import { Prisma } from '@prisma/client';

export type CanonicalLineupArtistInput = {
  id?: string;
  djId: string | null;
  memberDjIds?: Array<string | null>;
  memberNames?: string[];
  djName: string;
  sortOrder: number;
};

export type CanonicalLineupSlotInput = {
  id?: string;
  lineupArtistId?: string | null;
  djId: string | null;
  memberDjIds: Array<string | null>;
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

const splitCollaborativeLineupName = (value: string): string[] => {
  const name = String(value || '').trim();
  if (!name) return [];
  const parts = name
    .replace(/\s+b3b\s+/ig, '[[B3B]]')
    .replace(/\s+b2b\s+/ig, '[[B2B]]')
    .split(/\[\[(?:B2B|B3B)\]\]/)
    .map((item) => item.trim())
    .filter(Boolean);
  return parts.length > 1 ? parts : [name];
};

const normalizeMemberNames = (artist: Pick<CanonicalLineupArtistInput, 'memberNames' | 'djName'>): string[] => {
  const explicit = Array.isArray(artist.memberNames)
    ? artist.memberNames.map((item) => String(item || '').trim()).filter(Boolean)
    : [];
  return explicit.length ? explicit : splitCollaborativeLineupName(artist.djName);
};

const normalizeMemberDjIds = (artist: Pick<CanonicalLineupArtistInput, 'memberDjIds' | 'djId'>): Array<string | null> => {
  if (Array.isArray(artist.memberDjIds)) {
    return artist.memberDjIds.map((item) => {
      const id = String(item || '').trim();
      return id || null;
    });
  }
  return artist.djId ? [artist.djId] : [];
};

export const buildCanonicalLineupArtistsFromSlots = (
  slots: CanonicalLineupSlotInput[]
): CanonicalLineupArtistInput[] => {
  const byKey = new Map<string, CanonicalLineupArtistInput>();
  for (const [index, slot] of slots.entries()) {
    const djName = String(slot.djName || '').trim();
    if (!djName) continue;
    const memberDjIds = Array.isArray(slot.memberDjIds)
      ? slot.memberDjIds.map((id) => String(id || '').trim() || null)
      : [];
    const primaryDjId = slot.djId || uniqueIds(memberDjIds)[0] || null;
    const key = primaryDjId ? `id:${primaryDjId}` : `name:${normalizeCanonicalLineupName(djName)}`;
    const existing = byKey.get(key);
    if (existing) {
      if (!existing.djId && primaryDjId) existing.djId = primaryDjId;
      existing.memberDjIds = existing.memberDjIds?.length ? existing.memberDjIds : memberDjIds;
      existing.sortOrder = Math.min(existing.sortOrder, slot.sortOrder || index + 1);
      continue;
    }
    byKey.set(key, {
      djId: primaryDjId,
      memberDjIds,
      memberNames: splitCollaborativeLineupName(djName),
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
    const memberDjIds = normalizeMemberDjIds(raw);
    const djId = raw.djId || uniqueIds(memberDjIds)[0] || null;
    const sortOrder = Number.isFinite(raw.sortOrder) ? raw.sortOrder : index + 1;
    const key = djId ? `id:${djId}` : `name:${normalizeCanonicalLineupName(djName)}`;
    const existing = byKey.get(key);
    if (existing) {
      existing.memberDjIds = normalizeMemberDjIds(existing);
      existing.memberNames = normalizeMemberNames(existing);
      existing.sortOrder = Math.min(existing.sortOrder, sortOrder);
      if (!existing.id && raw.id) existing.id = raw.id;
      continue;
    }
    byKey.set(key, {
      id: raw.id,
      djId,
      memberDjIds,
      memberNames: normalizeMemberNames(raw),
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
      memberDjIds: artist.members.map((member) => {
        const id = String(member.djId || '').trim();
        return id || null;
      }),
      memberNames: artist.members.map((member) => member.memberNameSnapshot).filter(Boolean),
      djName: artist.displayName,
      sortOrder: artist.billingOrder,
    })),
    slots: performances.map((slot) => ({
      id: slot.id,
      lineupArtistId: slot.eventArtistId,
      djId: slot.eventArtist.primaryDjId,
      memberDjIds: slot.eventArtist.members.map((member) => {
        const id = String(member.djId || '').trim();
        return id || null;
      }),
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
  type EventArtistRow = {
    id: string;
    eventId: string;
    displayName: string;
    normalizedName: string;
    actType: string;
    primaryDjId: string | null;
    billingOrder: number;
    sourceType: string;
    isTimetableOnly: boolean;
  };
  type EventArtistMemberRow = {
    eventArtistId: string;
    djId: string | null;
    memberNameSnapshot: string;
    memberOrder: number;
    role: string;
  };
  type EventStageRow = {
    id: string;
    eventId: string;
    name: string;
    normalizedName: string;
    sortOrder: number;
  };
  type EventPerformanceRow = {
    id: string;
    eventId: string;
    eventArtistId: string;
    stageId: string | null;
    displayNameSnapshot: string;
    festivalDayIndex: number | null;
    startAt: Date;
    endAt: Date;
    sortOrder: number;
    status: string;
    sourceType: string;
  };

  const artistIdsByKey = new Map<string, string>();
  const artistRows: EventArtistRow[] = [];
  const memberRows: EventArtistMemberRow[] = [];
  for (const [index, artist] of canonicalArtists.entries()) {
    const memberDjIds = normalizeMemberDjIds(artist);
    const memberIds = uniqueIds(memberDjIds);
    const memberNames = normalizeMemberNames(artist);
    const memberCount = Math.max(memberDjIds.length, memberIds.length, memberNames.length, 1);
    const createdId = artist.id || crypto.randomUUID();
    artistRows.push({
      id: createdId,
      eventId,
      displayName: artist.djName,
      normalizedName: normalizeCanonicalLineupName(artist.djName),
      actType: memberCount > 1 ? 'group' : 'solo',
      primaryDjId: artist.djId,
      billingOrder: artist.sortOrder || index + 1,
      sourceType: 'manual',
      isTimetableOnly: false,
    });
    for (const [memberIndex] of Array.from({ length: memberCount }).entries()) {
      memberRows.push({
        eventArtistId: createdId,
        djId: memberDjIds[memberIndex] ?? null,
        memberNameSnapshot: memberNames[memberIndex] ?? artist.djName,
        memberOrder: memberIndex + 1,
        role: 'performer',
      });
    }
    artistIdsByKey.set(canonicalLineupKey(artist), createdId);
    artistIdsByKey.set(`name:${normalizeCanonicalLineupName(artist.djName)}`, createdId);
    if (artist.djId) artistIdsByKey.set(`id:${artist.djId}`, createdId);
  }

  const orderedStageNames = uniqueIds([
    ...explicitStageOrder,
    ...slots.map((slot) => slot.stageName).filter((value): value is string => Boolean(value)),
  ]);
  const stageIdsByName = new Map<string, string>();
  const stageRows: EventStageRow[] = [];
  for (const [index, name] of orderedStageNames.entries()) {
    const normalizedName = normalizeCanonicalLineupName(name);
    const stageId = crypto.randomUUID();
    stageRows.push({
      id: stageId,
      eventId,
      name,
      normalizedName,
      sortOrder: index + 1,
    });
    stageIdsByName.set(normalizedName, stageId);
  }

  const performanceRows: EventPerformanceRow[] = [];
  for (const [index, slot] of slots.entries()) {
    const slotName = slot.djName || 'Unknown DJ';
    let eventArtistId =
      (slot.lineupArtistId && canonicalArtists.some((artist) => artist.id === slot.lineupArtistId) ? slot.lineupArtistId : null)
      || artistIdsByKey.get(canonicalLineupKey({ djId: slot.djId, djName: slotName }))
      || artistIdsByKey.get(`name:${normalizeCanonicalLineupName(slotName)}`);

    if (!eventArtistId) {
      const memberDjIds = slot.memberDjIds?.length ? slot.memberDjIds : (slot.djId ? [slot.djId] : []);
      const memberIds = uniqueIds(memberDjIds);
      const memberNames = splitCollaborativeLineupName(slotName);
      eventArtistId = crypto.randomUUID();
      artistRows.push({
        id: eventArtistId,
        eventId,
        displayName: slotName,
        normalizedName: normalizeCanonicalLineupName(slotName),
        actType: memberIds.length > 1 ? 'group' : 'solo',
        primaryDjId: slot.djId,
        billingOrder: canonicalArtists.length + index + 1,
        sourceType: 'manual',
        isTimetableOnly: true,
      });
      for (const [memberIndex] of Array.from({ length: Math.max(memberDjIds.length, memberNames.length, 1) }).entries()) {
        memberRows.push({
          eventArtistId,
          djId: memberDjIds[memberIndex] ?? null,
          memberNameSnapshot: memberNames[memberIndex] ?? slotName,
          memberOrder: memberIndex + 1,
          role: 'performer',
        });
      }
      artistIdsByKey.set(`name:${normalizeCanonicalLineupName(slotName)}`, eventArtistId);
      if (slot.djId) artistIdsByKey.set(`id:${slot.djId}`, eventArtistId);
    }

    const stageId = slot.stageName ? stageIdsByName.get(normalizeCanonicalLineupName(slot.stageName)) ?? null : null;
    performanceRows.push({
      id: slot.id || crypto.randomUUID(),
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
    });
  }

  if (artistRows.length > 0) {
    await tx.eventArtist.createMany({ data: artistRows });
  }
  if (memberRows.length > 0) {
    await tx.eventArtistMember.createMany({ data: memberRows });
  }
  if (stageRows.length > 0) {
    await tx.eventStage.createMany({ data: stageRows });
  }
  if (performanceRows.length > 0) {
    await tx.eventPerformance.createMany({ data: performanceRows });
  }
};
