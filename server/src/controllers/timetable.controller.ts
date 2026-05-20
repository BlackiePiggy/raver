import { randomUUID } from 'node:crypto';
import { Response } from 'express';
import { PrismaClient } from '@prisma/client';
import { AuthRequest } from '../middleware/auth';
import { normalizeEventTimeZone, parseEventDateInput } from '../utils/event-timezone';
import {
  loadCanonicalEventLineupSnapshot,
  syncCanonicalEventLineupAndTimetable,
} from '../services/event-lineup-canonical.service';

const prisma = new PrismaClient();

const paramString = (value: string | string[] | undefined): string => Array.isArray(value) ? String(value[0] || '') : String(value || '');
const normalizeDjIds = (value: unknown, fallback: string | null = null): string[] => {
  const ids = Array.isArray(value) ? value : [];
  const out = ids.map((id) => String(id || '').trim()).filter(Boolean);
  if (fallback && !out.includes(fallback)) out.unshift(fallback);
  return out;
};

async function assertEventAccess(eventId: string, userId: string, role: string | undefined): Promise<{ id: string; organizerId: string | null; timeZone: string } | null> {
  const event = await prisma.event.findUnique({
    where: { id: eventId },
    select: { id: true, organizerId: true, startDate: true, dayRolloverHour: true, timeZone: true },
  });
  if (!event) return null;
  if (role !== 'admin' && event.organizerId !== userId) return null;
  return event;
}

const parseOptionalDate = (value: unknown, timeZoneRaw: unknown): Date | null => {
  if (value instanceof Date && !Number.isNaN(value.getTime())) return value;
  if (typeof value !== 'string') return null;
  return parseEventDateInput(value, normalizeEventTimeZone(timeZoneRaw), 'start');
};

export const getTimetable = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const eventId = paramString(req.params.eventId);
    const snapshot = await loadCanonicalEventLineupSnapshot(prisma, eventId);
    const djIds = Array.from(new Set(snapshot.slots.flatMap((slot) => slot.djId ? [slot.djId] : [])));
    const djs = djIds.length
      ? await prisma.dJ.findMany({ where: { id: { in: djIds } }, select: { id: true, name: true, avatarUrl: true } })
      : [];
    const djMap = new Map(djs.map((dj) => [dj.id, dj]));
    res.json({
      slots: snapshot.slots.map((slot) => ({
        id: slot.id || '',
        eventId,
        lineupArtistId: slot.lineupArtistId ?? null,
        djId: slot.djId,
        djIds: slot.djIds,
        djNameSnapshot: slot.djName,
        stageName: slot.stageName,
        festivalDayIndex: slot.festivalDayIndex,
        startTime: slot.startTime,
        endTime: slot.endTime,
        sortOrder: slot.sortOrder,
        dj: slot.djId ? (djMap.get(slot.djId) ?? null) : null,
        lineupArtist: slot.lineupArtistId
          ? (() => {
              const artist = snapshot.artists.find((item) => item.id === slot.lineupArtistId);
              return artist ? { id: artist.id, djName: artist.djName, djId: artist.djId } : null;
            })()
          : null,
      })),
    });
  } catch (error) {
    console.error('Get timetable error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const addTimetableSlot = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const eventId = paramString(req.params.eventId);
    const userId = req.user?.userId;
    const role = req.user?.role;
    if (!userId) { res.status(401).json({ error: 'Unauthorized' }); return; }

    const event = await assertEventAccess(eventId, userId, role);
    if (!event) { res.status(404).json({ error: 'Event not found or access denied' }); return; }

    const { djId, djIds, djName, lineupArtistId, stageName, festivalDayIndex, startTime, endTime, sortOrder } = req.body;
    const parsedStart = parseOptionalDate(startTime, event.timeZone);
    const parsedEnd = parseOptionalDate(endTime, event.timeZone);
    if (!parsedStart || !parsedEnd) {
      res.status(400).json({ error: 'startTime and endTime are required' });
      return;
    }

    const nameStr = String(djName || '').trim();
    if (!nameStr) { res.status(400).json({ error: 'djName is required' }); return; }

    const createdSlotId = randomUUID();
    const createdSlot = await prisma.$transaction(async (tx) => {
      const snapshot = await loadCanonicalEventLineupSnapshot(tx, eventId);
      let resolvedLineupArtistId = String(lineupArtistId || '').trim() || null;
      let resolvedDjId = String(djId || '').trim() || null;
      let resolvedDjIds = normalizeDjIds(djIds, resolvedDjId);
      const nextArtists = [...snapshot.artists];

      if (resolvedLineupArtistId) {
        const exists = nextArtists.some((artist) => artist.id === resolvedLineupArtistId);
        if (!exists) return 'invalid-lineup-artist' as const;
      } else {
        const matched = nextArtists.find((artist) => (
          (resolvedDjId && artist.djId === resolvedDjId)
          || artist.djName === nameStr
        ));
        if (matched) {
          resolvedLineupArtistId = matched.id || null;
          if (!resolvedDjId && matched.djId) resolvedDjId = matched.djId;
          resolvedDjIds = normalizeDjIds(djIds, resolvedDjId);
        } else {
          resolvedLineupArtistId = randomUUID();
          nextArtists.push({
            id: resolvedLineupArtistId,
            djId: resolvedDjId,
            djIds: resolvedDjIds,
            djName: nameStr,
            sortOrder: nextArtists.length + 1,
          });
        }
      }

      const nextSlots = [
        ...snapshot.slots,
        {
          id: createdSlotId,
          lineupArtistId: resolvedLineupArtistId,
          djId: resolvedDjId,
          djIds: resolvedDjIds,
          djName: nameStr,
          stageName: typeof stageName === 'string' && stageName.trim() ? stageName.trim() : null,
          festivalDayIndex: typeof festivalDayIndex === 'number' ? festivalDayIndex : null,
          startTime: parsedStart,
          endTime: parsedEnd,
          sortOrder: typeof sortOrder === 'number' ? sortOrder : snapshot.slots.length + 1,
        },
      ];
      await syncCanonicalEventLineupAndTimetable(tx, eventId, nextSlots, nextArtists);
      return nextSlots.find((slot) => slot.id === createdSlotId) || null;
    });

    if (createdSlot === 'invalid-lineup-artist') {
      res.status(400).json({ error: 'lineupArtistId does not belong to this event' });
      return;
    }
    if (!createdSlot) {
      res.status(500).json({ error: 'Failed to create timetable slot' });
      return;
    }

    const dj = createdSlot.djId
      ? await prisma.dJ.findUnique({ where: { id: createdSlot.djId }, select: { id: true, name: true, avatarUrl: true } })
      : null;
    res.status(201).json({
      id: createdSlot.id,
      eventId,
      lineupArtistId: createdSlot.lineupArtistId ?? null,
      djId: createdSlot.djId,
      djIds: createdSlot.djIds,
      djNameSnapshot: createdSlot.djName,
      stageName: createdSlot.stageName,
      festivalDayIndex: createdSlot.festivalDayIndex,
      startTime: createdSlot.startTime,
      endTime: createdSlot.endTime,
      sortOrder: createdSlot.sortOrder,
      dj,
      lineupArtist: createdSlot.lineupArtistId
        ? await prisma.eventArtist.findUnique({
            where: { id: createdSlot.lineupArtistId },
            select: { id: true, displayName: true, primaryDjId: true },
          }).then((artist) => artist ? {
            id: artist.id,
            djName: artist.displayName,
            djId: artist.primaryDjId,
          } : null)
        : null,
    });
  } catch (error) {
    console.error('Add timetable slot error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const updateTimetableSlot = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const eventId = paramString(req.params.eventId);
    const slotId = paramString(req.params.slotId);
    const userId = req.user?.userId;
    const role = req.user?.role;
    if (!userId) { res.status(401).json({ error: 'Unauthorized' }); return; }

    const event = await assertEventAccess(eventId, userId, role);
    if (!event) { res.status(404).json({ error: 'Event not found or access denied' }); return; }

    const { djId, djIds, djName, lineupArtistId, stageName, festivalDayIndex, startTime, endTime, sortOrder } = req.body;
    const normalizedDjId = String(djId || '').trim() || null;
    const parsedStart = startTime ? parseOptionalDate(startTime, event.timeZone) : null;
    const parsedEnd = endTime ? parseOptionalDate(endTime, event.timeZone) : null;

    const updatedSlot = await prisma.$transaction(async (tx) => {
      const snapshot = await loadCanonicalEventLineupSnapshot(tx, eventId);
      const existing = snapshot.slots.find((slot) => slot.id === slotId);
      if (!existing) return 'missing' as const;

      if (lineupArtistId !== undefined && lineupArtistId !== null) {
        const artist = snapshot.artists.find((item) => item.id === String(lineupArtistId));
        if (!artist) return 'invalid-lineup-artist' as const;
      }

      const nextSlots = snapshot.slots.map((slot) => (
        slot.id === slotId
          ? {
              ...slot,
              djId: djId !== undefined ? normalizedDjId : slot.djId,
              djIds: djIds !== undefined || djId !== undefined ? normalizeDjIds(djIds, normalizedDjId) : slot.djIds,
              djName: djName ? String(djName).trim() : slot.djName,
              lineupArtistId: lineupArtistId !== undefined ? (String(lineupArtistId || '').trim() || null) : slot.lineupArtistId,
              stageName: stageName !== undefined ? (typeof stageName === 'string' && stageName.trim() ? stageName.trim() : null) : slot.stageName,
              festivalDayIndex: festivalDayIndex !== undefined ? (typeof festivalDayIndex === 'number' ? festivalDayIndex : null) : slot.festivalDayIndex,
              startTime: parsedStart ?? slot.startTime,
              endTime: parsedEnd ?? slot.endTime,
              sortOrder: typeof sortOrder === 'number' ? sortOrder : slot.sortOrder,
            }
          : slot
      ));
      await syncCanonicalEventLineupAndTimetable(tx, eventId, nextSlots, snapshot.artists);
      return nextSlots.find((slot) => slot.id === slotId) || null;
    });

    if (updatedSlot === 'missing') { res.status(404).json({ error: 'Timetable slot not found' }); return; }
    if (updatedSlot === 'invalid-lineup-artist') { res.status(400).json({ error: 'lineupArtistId does not belong to this event' }); return; }
    if (!updatedSlot) { res.status(500).json({ error: 'Failed to update timetable slot' }); return; }

    const dj = updatedSlot.djId
      ? await prisma.dJ.findUnique({ where: { id: updatedSlot.djId }, select: { id: true, name: true, avatarUrl: true } })
      : null;
    res.json({
      id: updatedSlot.id,
      eventId,
      lineupArtistId: updatedSlot.lineupArtistId ?? null,
      djId: updatedSlot.djId,
      djIds: updatedSlot.djIds,
      djNameSnapshot: updatedSlot.djName,
      stageName: updatedSlot.stageName,
      festivalDayIndex: updatedSlot.festivalDayIndex,
      startTime: updatedSlot.startTime,
      endTime: updatedSlot.endTime,
      sortOrder: updatedSlot.sortOrder,
      dj,
      lineupArtist: updatedSlot.lineupArtistId
        ? await prisma.eventArtist.findUnique({
            where: { id: updatedSlot.lineupArtistId },
            select: { id: true, displayName: true, primaryDjId: true },
          }).then((artist) => artist ? {
            id: artist.id,
            djName: artist.displayName,
            djId: artist.primaryDjId,
          } : null)
        : null,
    });
  } catch (error) {
    console.error('Update timetable slot error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const deleteTimetableSlot = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const eventId = paramString(req.params.eventId);
    const slotId = paramString(req.params.slotId);
    const userId = req.user?.userId;
    const role = req.user?.role;
    if (!userId) { res.status(401).json({ error: 'Unauthorized' }); return; }

    const event = await assertEventAccess(eventId, userId, role);
    if (!event) { res.status(404).json({ error: 'Event not found or access denied' }); return; }

    const deleted = await prisma.$transaction(async (tx) => {
      const snapshot = await loadCanonicalEventLineupSnapshot(tx, eventId);
      const existing = snapshot.slots.find((slot) => slot.id === slotId);
      if (!existing) return false;
      await syncCanonicalEventLineupAndTimetable(
        tx,
        eventId,
        snapshot.slots.filter((slot) => slot.id !== slotId),
        snapshot.artists
      );
      return true;
    });

    if (!deleted) { res.status(404).json({ error: 'Timetable slot not found' }); return; }

    res.status(204).send();
  } catch (error) {
    console.error('Delete timetable slot error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};
