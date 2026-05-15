import { Response } from 'express';
import { PrismaClient } from '@prisma/client';
import { AuthRequest } from '../middleware/auth';
import { normalizeEventTimeZone, parseEventDateInput } from '../utils/event-timezone';

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
    const slots = await prisma.eventTimetableSlot.findMany({
      where: { eventId },
      orderBy: { startTime: 'asc' },
      include: {
        dj: { select: { id: true, name: true, avatarUrl: true } },
        lineupArtist: { select: { id: true, djName: true, djId: true } },
      },
    });
    res.json({ slots });
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

    // Resolve or auto-create lineup artist
    let resolvedLineupArtistId: string | null = String(lineupArtistId || '').trim() || null;
    let resolvedDjId: string | null = String(djId || '').trim() || null;
    let resolvedDjIds = normalizeDjIds(djIds, resolvedDjId);

    if (!resolvedLineupArtistId) {
      // Try to find existing lineup artist by djId or djName
      let existing = null;
      if (resolvedDjId) {
        existing = await prisma.eventLineupArtist.findFirst({
          where: { eventId, djId: resolvedDjId },
        });
      }
      if (!existing) {
        existing = await prisma.eventLineupArtist.findFirst({
          where: { eventId, djName: nameStr },
        });
      }
      if (existing) {
        resolvedLineupArtistId = existing.id;
        if (!resolvedDjId && existing.djId) resolvedDjId = existing.djId;
        resolvedDjIds = normalizeDjIds(djIds, resolvedDjId);
      } else {
        // Auto-create lineup artist
        const count = await prisma.eventLineupArtist.count({ where: { eventId } });
        const created = await prisma.eventLineupArtist.create({
          data: {
            eventId,
            djId: resolvedDjId,
            djIds: resolvedDjIds,
            djName: nameStr,
            sortOrder: count + 1,
          },
        });
        resolvedLineupArtistId = created.id;
      }
    } else {
      // Verify lineupArtistId belongs to this event
      const artist = await prisma.eventLineupArtist.findFirst({
        where: { id: resolvedLineupArtistId, eventId },
      });
      if (!artist) {
        res.status(400).json({ error: 'lineupArtistId does not belong to this event' });
        return;
      }
      if (!resolvedDjId && artist.djId) resolvedDjId = artist.djId;
      resolvedDjIds = normalizeDjIds(djIds, resolvedDjId);
    }

    const count = await prisma.eventTimetableSlot.count({ where: { eventId } });
    const slot = await prisma.eventTimetableSlot.create({
      data: {
        eventId,
        lineupArtistId: resolvedLineupArtistId,
        djId: resolvedDjId,
        djIds: resolvedDjIds,
        djNameSnapshot: nameStr,
        stageName: stageName || null,
        festivalDayIndex: typeof festivalDayIndex === 'number' ? festivalDayIndex : null,
        startTime: parsedStart,
        endTime: parsedEnd,
        sortOrder: typeof sortOrder === 'number' ? sortOrder : count + 1,
      },
      include: {
        dj: { select: { id: true, name: true, avatarUrl: true } },
        lineupArtist: { select: { id: true, djName: true, djId: true } },
      },
    });
    res.status(201).json(slot);
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

    const existing = await prisma.eventTimetableSlot.findFirst({ where: { id: slotId, eventId } });
    if (!existing) { res.status(404).json({ error: 'Timetable slot not found' }); return; }

    const { djId, djIds, djName, lineupArtistId, stageName, festivalDayIndex, startTime, endTime, sortOrder } = req.body;
    const normalizedDjId = String(djId || '').trim() || null;

    const parsedStart = startTime ? parseOptionalDate(startTime, event.timeZone) : null;
    const parsedEnd = endTime ? parseOptionalDate(endTime, event.timeZone) : null;

    if (lineupArtistId !== undefined && lineupArtistId !== null) {
      const artist = await prisma.eventLineupArtist.findFirst({ where: { id: String(lineupArtistId), eventId } });
      if (!artist) { res.status(400).json({ error: 'lineupArtistId does not belong to this event' }); return; }
    }

    const slot = await prisma.eventTimetableSlot.update({
      where: { id: slotId },
      data: {
        djId: djId !== undefined ? normalizedDjId : undefined,
        djIds: djIds !== undefined || djId !== undefined ? normalizeDjIds(djIds, normalizedDjId) : undefined,
        djNameSnapshot: djName ? String(djName).trim() : undefined,
        lineupArtistId: lineupArtistId !== undefined ? (String(lineupArtistId || '').trim() || null) : undefined,
        stageName: stageName !== undefined ? (stageName || null) : undefined,
        festivalDayIndex: festivalDayIndex !== undefined ? (typeof festivalDayIndex === 'number' ? festivalDayIndex : null) : undefined,
        startTime: parsedStart ?? undefined,
        endTime: parsedEnd ?? undefined,
        sortOrder: typeof sortOrder === 'number' ? sortOrder : undefined,
      },
      include: {
        dj: { select: { id: true, name: true, avatarUrl: true } },
        lineupArtist: { select: { id: true, djName: true, djId: true } },
      },
    });
    res.json(slot);
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

    const existing = await prisma.eventTimetableSlot.findFirst({ where: { id: slotId, eventId } });
    if (!existing) { res.status(404).json({ error: 'Timetable slot not found' }); return; }

    await prisma.eventTimetableSlot.delete({ where: { id: slotId } });
    res.status(204).send();
  } catch (error) {
    console.error('Delete timetable slot error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};
