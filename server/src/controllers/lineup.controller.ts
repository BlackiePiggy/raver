import { Response } from 'express';
import { PrismaClient } from '@prisma/client';
import { AuthRequest } from '../middleware/auth';

const prisma = new PrismaClient();

const paramString = (value: string | string[] | undefined): string => Array.isArray(value) ? String(value[0] || '') : String(value || '');
const normalizeDjIds = (value: unknown, fallback: string | null = null): string[] => {
  const ids = Array.isArray(value) ? value : [];
  const out = ids.map((id) => String(id || '').trim()).filter(Boolean);
  if (fallback && !out.includes(fallback)) out.unshift(fallback);
  return out;
};

async function assertEventAccess(eventId: string, userId: string, role: string | undefined): Promise<{ id: string; organizerId: string | null } | null> {
  const event = await prisma.event.findUnique({
    where: { id: eventId },
    select: { id: true, organizerId: true },
  });
  if (!event) return null;
  if (role !== 'admin' && event.organizerId !== userId) return null;
  return event;
}

export const getLineup = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const eventId = paramString(req.params.eventId);
    const artists = await prisma.eventLineupArtist.findMany({
      where: { eventId },
      orderBy: { sortOrder: 'asc' },
      include: {
        dj: { select: { id: true, name: true, avatarUrl: true } },
      },
    });
    res.json({ artists });
  } catch (error) {
    console.error('Get lineup error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const addLineupArtist = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const eventId = paramString(req.params.eventId);
    const userId = req.user?.userId;
    const role = req.user?.role;
    if (!userId) { res.status(401).json({ error: 'Unauthorized' }); return; }

    const event = await assertEventAccess(eventId, userId, role);
    if (!event) { res.status(404).json({ error: 'Event not found or access denied' }); return; }

    const { djId, djIds, djName, sortOrder } = req.body;
    const name = String(djName || '').trim();
    const normalizedDjId = String(djId || '').trim() || null;
    if (!name) { res.status(400).json({ error: 'djName is required' }); return; }

    const count = await prisma.eventLineupArtist.count({ where: { eventId } });
    const artist = await prisma.eventLineupArtist.create({
      data: {
        eventId,
        djId: normalizedDjId,
        djIds: normalizeDjIds(djIds, normalizedDjId),
        djName: name,
        sortOrder: typeof sortOrder === 'number' ? sortOrder : count + 1,
      },
      include: { dj: { select: { id: true, name: true, avatarUrl: true } } },
    });
    res.status(201).json(artist);
  } catch (error) {
    console.error('Add lineup artist error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const updateLineupArtist = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const eventId = paramString(req.params.eventId);
    const artistId = paramString(req.params.artistId);
    const userId = req.user?.userId;
    const role = req.user?.role;
    if (!userId) { res.status(401).json({ error: 'Unauthorized' }); return; }

    const event = await assertEventAccess(eventId, userId, role);
    if (!event) { res.status(404).json({ error: 'Event not found or access denied' }); return; }

    const existing = await prisma.eventLineupArtist.findFirst({ where: { id: artistId, eventId } });
    if (!existing) { res.status(404).json({ error: 'Lineup artist not found' }); return; }

    const { djId, djIds, djName, sortOrder } = req.body;
    const normalizedDjId = String(djId || '').trim() || null;
    const artist = await prisma.eventLineupArtist.update({
      where: { id: artistId },
      data: {
        djId: djId !== undefined ? normalizedDjId : undefined,
        djIds: djIds !== undefined || djId !== undefined ? normalizeDjIds(djIds, normalizedDjId) : undefined,
        djName: djName ? String(djName).trim() : undefined,
        sortOrder: typeof sortOrder === 'number' ? sortOrder : undefined,
      },
      include: { dj: { select: { id: true, name: true, avatarUrl: true } } },
    });
    res.json(artist);
  } catch (error) {
    console.error('Update lineup artist error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const deleteLineupArtist = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const eventId = paramString(req.params.eventId);
    const artistId = paramString(req.params.artistId);
    const userId = req.user?.userId;
    const role = req.user?.role;
    if (!userId) { res.status(401).json({ error: 'Unauthorized' }); return; }

    const event = await assertEventAccess(eventId, userId, role);
    if (!event) { res.status(404).json({ error: 'Event not found or access denied' }); return; }

    const existing = await prisma.eventLineupArtist.findFirst({ where: { id: artistId, eventId } });
    if (!existing) { res.status(404).json({ error: 'Lineup artist not found' }); return; }

    // Strict mode: block deletion if timetable slots exist
    const slotCount = await prisma.eventTimetableSlot.count({ where: { lineupArtistId: artistId } });
    if (slotCount > 0) {
      res.status(409).json({
        error: `该 DJ 下还有 ${slotCount} 条时间表演出，请先删除时间表条目后再删除阵容。`,
      });
      return;
    }

    await prisma.eventLineupArtist.delete({ where: { id: artistId } });
    res.status(204).send();
  } catch (error) {
    console.error('Delete lineup artist error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};
