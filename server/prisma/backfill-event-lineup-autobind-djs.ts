import fs from 'node:fs';
import path from 'node:path';
import { PrismaClient } from '@prisma/client';
import dotenv from 'dotenv';
import {
  loadCanonicalEventLineupSnapshot,
  syncCanonicalEventLineupAndTimetable,
} from '../src/services/event-lineup-canonical.service';

dotenv.config();

const prisma = new PrismaClient();

const LINEUP_DJ_ID_PLACEHOLDER = '__UNBOUND__';

type DJLite = {
  id: string;
  name: string;
  aliases: string[];
  avatarUrl: string | null;
  isVerified: boolean;
};

type SlotLite = {
  id: string;
  eventId: string;
  lineupArtistId?: string | null;
  djId: string | null;
  djIds: string[];
  djName: string;
};

type SlotResult = {
  lineupArtistId?: string | null;
  nextDjId: string | null;
  nextDjIds: string[];
  changed: boolean;
  appliedCount: number;
};

const DRY_RUN = process.env.LINEUP_AUTOBIND_DRY_RUN === '1';
const LIMIT = Number(process.env.LINEUP_AUTOBIND_LIMIT || 0);
const EVENT_ID = String(process.env.LINEUP_AUTOBIND_EVENT_ID || '').trim();
const TAKE = Math.max(100, Number(process.env.LINEUP_AUTOBIND_BATCH_SIZE || 1000));
const TX_CHUNK = Math.max(20, Number(process.env.LINEUP_AUTOBIND_TX_CHUNK || 200));

const nowTag = new Date().toISOString().replace(/[:.]/g, '-');
const logDir = path.join(process.cwd(), 'prisma', '.cache');
const logPath = path.join(logDir, `event-lineup-autobind-${nowTag}.json`);

const normalizeNameKey = (name: string): string =>
  String(name || '')
    .trim()
    .toLowerCase()
    .replace(/\s+/g, ' ');

const normalizeDjId = (value: unknown): string => {
  const id = String(value || '').trim();
  if (!id) return '';
  if (id === LINEUP_DJ_ID_PLACEHOLDER) return '';
  return id;
};

const choosePreferredDJ = (current: DJLite | null, candidate: DJLite): DJLite => {
  if (!current) return candidate;
  const currentHasAvatar = !!String(current.avatarUrl || '').trim();
  const candidateHasAvatar = !!String(candidate.avatarUrl || '').trim();
  if (!currentHasAvatar && candidateHasAvatar) return candidate;
  if (!current.isVerified && candidate.isVerified) return candidate;
  return current;
};

const extractCollaborativePerformers = (rawName: string): string[] => {
  const name = String(rawName || '').trim();
  if (!name) return [];
  if (!/\bb(?:2|3)b\b/i.test(name)) return [];
  const token = '__LINEUP_SPLIT__';
  const replaced = name.replace(/\s*b(?:2|3)b\s*/gi, token);
  const parts = replaced
    .split(token)
    .map((part) => String(part || '').trim())
    .filter(Boolean);
  return parts.length >= 2 ? parts : [];
};

const sameIdArray = (a: string[], b: string[]): boolean => {
  if (a.length !== b.length) return false;
  for (let i = 0; i < a.length; i += 1) {
    if (a[i] !== b[i]) return false;
  }
  return true;
};

const buildMatchMap = (djs: DJLite[]): Map<string, DJLite> => {
  const map = new Map<string, DJLite>();
  for (const item of djs) {
    const id = normalizeDjId(item.id);
    if (!id) continue;
    const keys = new Set<string>();
    const nameKey = normalizeNameKey(item.name);
    if (nameKey) keys.add(nameKey);
    for (const alias of Array.isArray(item.aliases) ? item.aliases : []) {
      const aliasKey = normalizeNameKey(alias);
      if (aliasKey) keys.add(aliasKey);
    }
    for (const key of keys) {
      const current = map.get(key) || null;
      map.set(key, choosePreferredDJ(current, item));
    }
  }
  return map;
};

const computeSlotBinding = (slot: SlotLite, matchMap: Map<string, DJLite>): SlotResult => {
  const originalDjId = normalizeDjId(slot.djId);
  const originalDjIds = Array.isArray(slot.djIds)
    ? slot.djIds.map((id) => normalizeDjId(id)).filter(Boolean)
    : [];

  const performers = extractCollaborativePerformers(slot.djName);
  let nextDjId = originalDjId || null;
  let nextDjIds = [...originalDjIds];
  let appliedCount = 0;

  if (performers.length >= 2) {
    if (!nextDjIds.length && nextDjId) nextDjIds = [nextDjId];
    if (!normalizeDjId(nextDjIds[0]) && nextDjId) nextDjIds[0] = nextDjId;

    for (let i = 0; i < performers.length; i += 1) {
      if (normalizeDjId(nextDjIds[i])) continue;
      while (nextDjIds.length < i) nextDjIds.push(LINEUP_DJ_ID_PLACEHOLDER);
      const performerName = performers[i];
      const candidate = matchMap.get(normalizeNameKey(performerName));
      const candidateId = normalizeDjId(candidate?.id);
      if (!candidateId) continue;
      nextDjIds[i] = candidateId;
      appliedCount += 1;
    }

    while (nextDjIds.length && !normalizeDjId(nextDjIds[nextDjIds.length - 1])) {
      nextDjIds.pop();
    }
    nextDjId = normalizeDjId(nextDjIds[0]) || null;
  } else {
    const singleExisting = originalDjId || normalizeDjId(originalDjIds[0]);
    if (singleExisting) {
      nextDjId = singleExisting;
      nextDjIds = originalDjIds.length ? [...originalDjIds] : [singleExisting];
    } else {
      const candidate = matchMap.get(normalizeNameKey(slot.djName));
      const candidateId = normalizeDjId(candidate?.id);
      if (candidateId) {
        nextDjId = candidateId;
        nextDjIds = [candidateId];
        appliedCount += 1;
      }
    }
  }

  const normalizedNextDjId = normalizeDjId(nextDjId);
  const finalDjId = normalizedNextDjId || null;
  const finalDjIds = nextDjIds.map((id) => normalizeDjId(id)).filter(Boolean);

  const changed =
    normalizeDjId(originalDjId) !== normalizeDjId(finalDjId) ||
    !sameIdArray(originalDjIds, finalDjIds);

  return {
    lineupArtistId: slot.lineupArtistId ?? null,
    nextDjId: finalDjId,
    nextDjIds: finalDjIds,
    changed,
    appliedCount,
  };
};

async function main() {
  await fs.promises.mkdir(logDir, { recursive: true });

  const startedAt = new Date();
  console.log(`[lineup-autobind] start dryRun=${DRY_RUN} limit=${LIMIT || 'ALL'} eventId=${EVENT_ID || 'ALL'}`);

  const djsRaw = await prisma.dJ.findMany({
    select: {
      id: true,
      name: true,
      aliases: true,
      avatarUrl: true,
      isVerified: true,
    },
  });
  const djs: DJLite[] = djsRaw.map((item) => ({
    id: item.id,
    name: item.name,
    aliases: Array.isArray(item.aliases) ? item.aliases : [],
    avatarUrl: item.avatarUrl ?? null,
    isVerified: !!item.isVerified,
  }));
  const matchMap = buildMatchMap(djs);
  console.log(`[lineup-autobind] dj loaded=${djs.length} keys=${matchMap.size}`);

  const eventRows = EVENT_ID
    ? [{ id: EVENT_ID }]
    : await prisma.event.findMany({
        select: { id: true },
        orderBy: { id: 'asc' },
      });

  const snapshots = await Promise.all(
    eventRows.map(async (event) => ({
      eventId: event.id,
      snapshot: await loadCanonicalEventLineupSnapshot(prisma, event.id),
    }))
  );
  const totalSlots = snapshots.reduce((sum, item) => sum + item.snapshot.slots.length, 0);
  console.log(`[lineup-autobind] totalEvents=${snapshots.length} totalSlots=${totalSlots}`);

  let scanned = 0;
  let touched = 0;
  let appliedBindings = 0;
  const perEventTouched = new Map<string, number>();
  const samples: Array<Record<string, unknown>> = [];
  const eventUpdates = new Map<string, {
    artists: Awaited<ReturnType<typeof loadCanonicalEventLineupSnapshot>>['artists'];
    slots: Awaited<ReturnType<typeof loadCanonicalEventLineupSnapshot>>['slots'];
  }>();

  for (const { eventId, snapshot } of snapshots) {
    const nextSlots = snapshot.slots.map((slot) => ({ ...slot }));
    const nextArtists = snapshot.artists.map((artist) => ({ ...artist, djIds: [...artist.djIds] }));
    let eventChanged = false;

    for (const row of nextSlots) {
      scanned += 1;
      if (LIMIT > 0 && scanned > LIMIT) break;

      const result = computeSlotBinding({
        id: row.id || '',
        eventId,
        lineupArtistId: row.lineupArtistId ?? null,
        djId: row.djId,
        djIds: row.djIds,
        djName: row.djName,
      }, matchMap);
      if (!result.changed) continue;

      touched += 1;
      appliedBindings += result.appliedCount;
      eventChanged = true;
      perEventTouched.set(eventId, (perEventTouched.get(eventId) || 0) + 1);

      row.djId = result.nextDjId;
      row.djIds = result.nextDjIds;

      if (result.lineupArtistId) {
        const artist = nextArtists.find((item) => item.id === result.lineupArtistId);
        if (artist) {
          artist.djId = result.nextDjId;
          artist.djIds = result.nextDjIds;
        }
      }

      if (samples.length < 60) {
        samples.push({
          slotId: row.id || '',
          eventId,
          djName: row.djName,
          before: { djId: snapshot.slots.find((item) => item.id === row.id)?.djId ?? null, djIds: snapshot.slots.find((item) => item.id === row.id)?.djIds ?? [] },
          after: { djId: result.nextDjId, djIds: result.nextDjIds },
          appliedCount: result.appliedCount,
        });
      }
    }

    if (eventChanged) {
      eventUpdates.set(eventId, { artists: nextArtists, slots: nextSlots });
    }

    if (LIMIT > 0 && scanned >= LIMIT) break;
    if (scanned % 2000 === 0) {
      console.log(`[lineup-autobind] scanned=${scanned}/${totalSlots} touched=${touched} applied=${appliedBindings}`);
    }
  }

  if (!DRY_RUN && eventUpdates.size) {
    const entries = Array.from(eventUpdates.entries());
    console.log(`[lineup-autobind] writing events=${entries.length} ...`);
    for (let i = 0; i < entries.length; i += TX_CHUNK) {
      const chunk = entries.slice(i, i + TX_CHUNK);
      await Promise.all(chunk.map(async ([eventId, data]) => {
        await prisma.$transaction(async (tx) => {
          await syncCanonicalEventLineupAndTimetable(tx, eventId, data.slots, data.artists);
        });
      }));
      console.log(`[lineup-autobind] committed ${Math.min(i + TX_CHUNK, entries.length)}/${entries.length} events`);
    }
  }

  const finishedAt = new Date();
  const summary = {
    startedAt: startedAt.toISOString(),
    finishedAt: finishedAt.toISOString(),
    durationMs: finishedAt.getTime() - startedAt.getTime(),
    config: {
      dryRun: DRY_RUN,
      limit: LIMIT || null,
      eventId: EVENT_ID || null,
      batchSize: TAKE,
      txChunk: TX_CHUNK,
    },
    totals: {
      totalSlots,
      scanned,
      touchedSlots: touched,
      appliedBindings,
      updatesWritten: DRY_RUN ? 0 : eventUpdates.size,
      affectedEvents: eventUpdates.size,
    },
    topAffectedEvents: Array.from(perEventTouched.entries())
      .sort((a, b) => b[1] - a[1])
      .slice(0, 100)
      .map(([eventId, slotCount]) => ({ eventId, slotCount })),
    samples,
  };

  await fs.promises.writeFile(logPath, JSON.stringify(summary, null, 2), 'utf8');
  console.log(`[lineup-autobind] done touched=${touched} applied=${appliedBindings} log=${logPath}`);
}

main()
  .catch((error) => {
    console.error('[lineup-autobind] fatal:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
