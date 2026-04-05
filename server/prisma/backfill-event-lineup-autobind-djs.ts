import fs from 'node:fs';
import path from 'node:path';
import { PrismaClient } from '@prisma/client';
import dotenv from 'dotenv';

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
  djId: string | null;
  djIds: string[];
  djName: string;
};

type SlotResult = {
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

  const slotWhere = EVENT_ID ? { eventId: EVENT_ID } : {};
  const totalSlots = await prisma.eventLineupSlot.count({ where: slotWhere });
  console.log(`[lineup-autobind] totalSlots=${totalSlots}`);

  let cursorId: string | undefined;
  let scanned = 0;
  let touched = 0;
  let appliedBindings = 0;
  const perEventTouched = new Map<string, number>();
  const updates: Array<{ id: string; eventId: string; data: { djId: string | null; djIds: string[] } }> = [];
  const samples: Array<Record<string, unknown>> = [];

  while (true) {
    const rows = await prisma.eventLineupSlot.findMany({
      where: slotWhere,
      orderBy: { id: 'asc' },
      take: TAKE,
      ...(cursorId ? { skip: 1, cursor: { id: cursorId } } : {}),
      select: {
        id: true,
        eventId: true,
        djId: true,
        djIds: true,
        djName: true,
      },
    });
    if (!rows.length) break;
    cursorId = rows[rows.length - 1]?.id;

    for (const row of rows) {
      scanned += 1;
      if (LIMIT > 0 && scanned > LIMIT) break;

      const result = computeSlotBinding(row as SlotLite, matchMap);
      if (!result.changed) continue;

      touched += 1;
      appliedBindings += result.appliedCount;
      perEventTouched.set(row.eventId, (perEventTouched.get(row.eventId) || 0) + 1);
      updates.push({
        id: row.id,
        eventId: row.eventId,
        data: {
          djId: result.nextDjId,
          djIds: result.nextDjIds,
        },
      });

      if (samples.length < 60) {
        samples.push({
          slotId: row.id,
          eventId: row.eventId,
          djName: row.djName,
          before: { djId: row.djId, djIds: row.djIds },
          after: { djId: result.nextDjId, djIds: result.nextDjIds },
          appliedCount: result.appliedCount,
        });
      }
    }

    if (LIMIT > 0 && scanned >= LIMIT) break;
    if (scanned % 2000 === 0) {
      console.log(`[lineup-autobind] scanned=${scanned}/${totalSlots} touched=${touched} applied=${appliedBindings}`);
    }
  }

  if (!DRY_RUN && updates.length) {
    console.log(`[lineup-autobind] writing updates=${updates.length} ...`);
    for (let i = 0; i < updates.length; i += TX_CHUNK) {
      const chunk = updates.slice(i, i + TX_CHUNK);
      await prisma.$transaction(
        chunk.map((item) =>
          prisma.eventLineupSlot.update({
            where: { id: item.id },
            data: item.data,
          })
        )
      );
      console.log(`[lineup-autobind] committed ${Math.min(i + TX_CHUNK, updates.length)}/${updates.length}`);
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
      updatesWritten: DRY_RUN ? 0 : updates.length,
      affectedEvents: perEventTouched.size,
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
