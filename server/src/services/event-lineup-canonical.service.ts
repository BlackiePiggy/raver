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

export type CanonicalLineupSnapshot = {
  artists: CanonicalLineupArtistInput[];
  slots: CanonicalLineupSlotInput[];
  stageOrder: string[];
};

type CanonicalArtistRow = {
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

type CanonicalMemberRow = {
  eventArtistId: string;
  djId: string | null;
  memberNameSnapshot: string;
  memberOrder: number;
  role: string;
};

type CanonicalStageRow = {
  id: string;
  eventId: string;
  name: string;
  normalizedName: string;
  sortOrder: number;
};

type CanonicalPerformanceRow = {
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

const dateTimeValue = (value: Date | null | undefined): number | null => {
  if (!value) return null;
  const time = value.getTime();
  return Number.isFinite(time) ? time : null;
};

const nullableString = (value: string | null | undefined): string | null => {
  const text = String(value || '').trim();
  return text || null;
};

const memberSignature = (members: Array<{ djId: string | null; memberNameSnapshot: string; memberOrder: number }>): string =>
  members
    .slice()
    .sort((a, b) => a.memberOrder - b.memberOrder)
    .map((member) => `${member.memberOrder}:${member.djId || ''}:${normalizeCanonicalLineupName(member.memberNameSnapshot || '')}`)
    .join('|');

const desiredMemberSignature = (members: CanonicalMemberRow[]): string =>
  members
    .slice()
    .sort((a, b) => a.memberOrder - b.memberOrder)
    .map((member) => `${member.memberOrder}:${member.djId || ''}:${normalizeCanonicalLineupName(member.memberNameSnapshot || '')}`)
    .join('|');

const performanceSemanticKey = (row: {
  eventArtistId: string;
  stageId: string | null;
  festivalDayIndex: number | null;
  startAt: Date | null;
  endAt: Date | null;
}): string =>
  [
    row.eventArtistId,
    row.stageId || '',
    row.festivalDayIndex ?? '',
    dateTimeValue(row.startAt) ?? '',
    dateTimeValue(row.endAt) ?? '',
  ].join('|');

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

const buildCanonicalTargetRows = (
  eventId: string,
  slots: CanonicalLineupSlotInput[],
  artists: CanonicalLineupArtistInput[],
  explicitStageOrder: string[] = []
): {
  artistRows: CanonicalArtistRow[];
  memberRows: CanonicalMemberRow[];
  stageRows: CanonicalStageRow[];
  performanceRows: CanonicalPerformanceRow[];
} => {
  const canonicalArtists = normalizeCanonicalLineupArtists(artists, slots);
  const artistIdsByKey = new Map<string, string>();
  const artistRows: CanonicalArtistRow[] = [];
  const memberRows: CanonicalMemberRow[] = [];

  for (const [index, artist] of canonicalArtists.entries()) {
    const memberDjIds = normalizeMemberDjIds(artist);
    const memberIds = uniqueIds(memberDjIds);
    const memberNames = normalizeMemberNames(artist);
    const memberCount = Math.max(memberDjIds.length, memberIds.length, memberNames.length, 1);
    const artistId = artist.id || crypto.randomUUID();
    artistRows.push({
      id: artistId,
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
        eventArtistId: artistId,
        djId: memberDjIds[memberIndex] ?? null,
        memberNameSnapshot: memberNames[memberIndex] ?? artist.djName,
        memberOrder: memberIndex + 1,
        role: 'performer',
      });
    }
    artistIdsByKey.set(canonicalLineupKey(artist), artistId);
    artistIdsByKey.set(`name:${normalizeCanonicalLineupName(artist.djName)}`, artistId);
    if (artist.djId) artistIdsByKey.set(`id:${artist.djId}`, artistId);
  }

  const orderedStageNames = uniqueIds([
    ...explicitStageOrder,
    ...slots.map((slot) => slot.stageName).filter((value): value is string => Boolean(value)),
  ]);
  const stageIdsByName = new Map<string, string>();
  const stageRows: CanonicalStageRow[] = [];
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

  const performanceRows: CanonicalPerformanceRow[] = [];
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

  return {
    artistRows,
    memberRows,
    stageRows,
    performanceRows,
  };
};

export const syncCanonicalEventLineupAndTimetable = async (
  tx: Prisma.TransactionClient,
  eventId: string,
  slots: CanonicalLineupSlotInput[],
  artists: CanonicalLineupArtistInput[],
  explicitStageOrder: string[] = []
): Promise<void> => {
  const existingArtists = await tx.eventArtist.findMany({
    where: { eventId },
    include: {
      members: {
        orderBy: { memberOrder: 'asc' },
      },
    },
  });
  const existingStages = await tx.eventStage.findMany({ where: { eventId } });
  const existingPerformances = await tx.eventPerformance.findMany({ where: { eventId } });

  const existingArtistById = new Map(existingArtists.map((artist) => [artist.id, artist]));
  const existingArtistByKey = new Map<string, string>();
  for (const artist of existingArtists) {
    if (artist.primaryDjId) existingArtistByKey.set(`id:${artist.primaryDjId}`, artist.id);
    const normalizedName = artist.normalizedName || normalizeCanonicalLineupName(artist.displayName);
    existingArtistByKey.set(`name:${normalizedName}`, artist.id);
    const memberIds = uniqueIds(artist.members.map((member) => member.djId));
    if (memberIds.length > 1) existingArtistByKey.set(`group:${memberIds.sort().join('|')}`, artist.id);
    const memberNames = artist.members.map((member) => normalizeCanonicalLineupName(member.memberNameSnapshot)).filter(Boolean);
    if (memberNames.length > 1) existingArtistByKey.set(`fallback-group:${memberNames.sort().join('|')}`, artist.id);
  }

  const existingStageById = new Map(existingStages.map((stage) => [stage.id, stage]));
  const existingStageByName = new Map(existingStages.map((stage) => [stage.normalizedName, stage]));

  const target = buildCanonicalTargetRows(eventId, slots, artists, explicitStageOrder);

  for (const artist of target.artistRows) {
    if (existingArtistById.has(artist.id)) continue;
    let matchedId: string | undefined;
    if (artist.primaryDjId) matchedId = existingArtistByKey.get(`id:${artist.primaryDjId}`);
    matchedId ||= existingArtistByKey.get(`name:${artist.normalizedName}`);
    const desiredMembers = target.memberRows.filter((member) => member.eventArtistId === artist.id);
    const memberIds = uniqueIds(desiredMembers.map((member) => member.djId));
    if (!matchedId && memberIds.length > 1) matchedId = existingArtistByKey.get(`group:${memberIds.sort().join('|')}`);
    const memberNames = desiredMembers.map((member) => normalizeCanonicalLineupName(member.memberNameSnapshot)).filter(Boolean);
    if (!matchedId && memberNames.length > 1) matchedId = existingArtistByKey.get(`fallback-group:${memberNames.sort().join('|')}`);
    if (!matchedId) continue;
    const oldId = artist.id;
    artist.id = matchedId;
    for (const member of target.memberRows) {
      if (member.eventArtistId === oldId) member.eventArtistId = matchedId;
    }
    for (const performance of target.performanceRows) {
      if (performance.eventArtistId === oldId) performance.eventArtistId = matchedId;
    }
  }

  for (const stage of target.stageRows) {
    if (existingStageById.has(stage.id)) continue;
    const matched = existingStageByName.get(stage.normalizedName);
    if (!matched) continue;
    const oldId = stage.id;
    stage.id = matched.id;
    for (const performance of target.performanceRows) {
      if (performance.stageId === oldId) performance.stageId = matched.id;
    }
  }

  const targetArtistIds = new Set(target.artistRows.map((artist) => artist.id));
  const targetStageIds = new Set(target.stageRows.map((stage) => stage.id));
  const targetPerformanceIds = new Set(target.performanceRows.map((performance) => performance.id));

  const existingPerformanceById = new Map(existingPerformances.map((performance) => [performance.id, performance]));
  const existingPerformanceBySemanticKey = new Map(existingPerformances.map((performance) => [
    performanceSemanticKey({
      eventArtistId: performance.eventArtistId,
      stageId: performance.stageId,
      festivalDayIndex: performance.festivalDayIndex,
      startAt: performance.startAt,
      endAt: performance.endAt,
    }),
    performance,
  ]));
  for (const performance of target.performanceRows) {
    if (existingPerformanceById.has(performance.id)) continue;
    const matched = existingPerformanceBySemanticKey.get(performanceSemanticKey(performance));
    if (!matched) continue;
    performance.id = matched.id;
    targetPerformanceIds.add(matched.id);
  }

  const performancesToDelete = existingPerformances
    .filter((performance) => !targetPerformanceIds.has(performance.id))
    .map((performance) => performance.id);
  if (performancesToDelete.length > 0) {
    await tx.eventPerformance.deleteMany({ where: { id: { in: performancesToDelete } } });
  }

  const artistsToDelete = existingArtists
    .filter((artist) => !targetArtistIds.has(artist.id))
    .map((artist) => artist.id);
  const stagesToDelete = existingStages
    .filter((stage) => !targetStageIds.has(stage.id))
    .map((stage) => stage.id);

  const existingArtistIds = new Set(existingArtists.map((artist) => artist.id));
  const artistRowsToCreate = target.artistRows.filter((artist) => !existingArtistIds.has(artist.id));
  if (artistRowsToCreate.length > 0) {
    await tx.eventArtist.createMany({ data: artistRowsToCreate });
  }
  for (const artist of target.artistRows.filter((row) => existingArtistIds.has(row.id))) {
    const existing = existingArtistById.get(artist.id);
    if (!existing) continue;
    if (
      existing.displayName !== artist.displayName
      || nullableString(existing.normalizedName) !== artist.normalizedName
      || existing.actType !== artist.actType
      || nullableString(existing.primaryDjId) !== nullableString(artist.primaryDjId)
      || existing.billingOrder !== artist.billingOrder
      || existing.sourceType !== artist.sourceType
      || existing.isTimetableOnly !== artist.isTimetableOnly
    ) {
      await tx.eventArtist.update({
        where: { id: artist.id },
        data: {
          displayName: artist.displayName,
          normalizedName: artist.normalizedName,
          actType: artist.actType,
          primaryDjId: artist.primaryDjId,
          billingOrder: artist.billingOrder,
          sourceType: artist.sourceType,
          isTimetableOnly: artist.isTimetableOnly,
        },
      });
    }
  }

  const memberRowsToRewrite: CanonicalMemberRow[] = [];
  const artistIdsWithChangedMembers: string[] = [];
  for (const artist of target.artistRows) {
    const desiredMembers = target.memberRows.filter((member) => member.eventArtistId === artist.id);
    const existing = existingArtistById.get(artist.id);
    if (!existing || memberSignature(existing.members) !== desiredMemberSignature(desiredMembers)) {
      artistIdsWithChangedMembers.push(artist.id);
      memberRowsToRewrite.push(...desiredMembers);
    }
  }
  if (artistIdsWithChangedMembers.length > 0) {
    await tx.eventArtistMember.deleteMany({ where: { eventArtistId: { in: artistIdsWithChangedMembers } } });
    if (memberRowsToRewrite.length > 0) {
      await tx.eventArtistMember.createMany({ data: memberRowsToRewrite });
    }
  }

  const existingStageIds = new Set(existingStages.map((stage) => stage.id));
  const stageRowsToCreate = target.stageRows.filter((stage) => !existingStageIds.has(stage.id));
  if (stageRowsToCreate.length > 0) {
    await tx.eventStage.createMany({ data: stageRowsToCreate });
  }
  for (const stage of target.stageRows.filter((row) => existingStageIds.has(row.id))) {
    const existing = existingStageById.get(stage.id);
    if (!existing) continue;
    if (
      existing.name !== stage.name
      || existing.normalizedName !== stage.normalizedName
      || existing.sortOrder !== stage.sortOrder
    ) {
      await tx.eventStage.update({
        where: { id: stage.id },
        data: {
          name: stage.name,
          normalizedName: stage.normalizedName,
          sortOrder: stage.sortOrder,
        },
      });
    }
  }

  const existingPerformanceIds = new Set(existingPerformances.map((performance) => performance.id));
  const performanceRowsToCreate = target.performanceRows.filter((performance) => !existingPerformanceIds.has(performance.id));
  if (performanceRowsToCreate.length > 0) {
    await tx.eventPerformance.createMany({ data: performanceRowsToCreate });
  }
  for (const performance of target.performanceRows.filter((row) => existingPerformanceIds.has(row.id))) {
    const existing = existingPerformanceById.get(performance.id);
    if (!existing) continue;
    if (
      existing.eventArtistId !== performance.eventArtistId
      || nullableString(existing.stageId) !== nullableString(performance.stageId)
      || existing.displayNameSnapshot !== performance.displayNameSnapshot
      || existing.festivalDayIndex !== performance.festivalDayIndex
      || dateTimeValue(existing.startAt) !== dateTimeValue(performance.startAt)
      || dateTimeValue(existing.endAt) !== dateTimeValue(performance.endAt)
      || existing.sortOrder !== performance.sortOrder
      || existing.status !== performance.status
      || existing.sourceType !== performance.sourceType
    ) {
      await tx.eventPerformance.update({
        where: { id: performance.id },
        data: {
          eventArtistId: performance.eventArtistId,
          stageId: performance.stageId,
          displayNameSnapshot: performance.displayNameSnapshot,
          festivalDayIndex: performance.festivalDayIndex,
          startAt: performance.startAt,
          endAt: performance.endAt,
          sortOrder: performance.sortOrder,
          status: performance.status,
          sourceType: performance.sourceType,
        },
      });
    }
  }

  if (artistsToDelete.length > 0) {
    await tx.eventArtistMember.deleteMany({ where: { eventArtistId: { in: artistsToDelete } } });
    await tx.eventArtist.deleteMany({ where: { id: { in: artistsToDelete } } });
  }

  if (stagesToDelete.length > 0) {
    await tx.eventStage.deleteMany({ where: { id: { in: stagesToDelete } } });
  }
};
