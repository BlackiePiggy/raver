import { randomUUID } from 'node:crypto';
import { Response } from 'express';
import { PrismaClient } from '@prisma/client';
import { AuthRequest } from '../middleware/auth';
import {
  loadCanonicalEventLineupSnapshot,
  syncCanonicalEventLineupAndTimetable,
  type CanonicalLineupArtistInput,
} from '../services/event-lineup-canonical.service';

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

const toArtistResponse = (
  artist: CanonicalLineupArtistInput,
  djMap: Map<string, { id: string; name: string; avatarUrl: string | null }>
) => ({
  id: artist.id || '',
  eventId: '',
  djId: artist.djId,
  djIds: artist.djIds,
  djName: artist.djName,
  sortOrder: artist.sortOrder,
  dj: artist.djId ? (djMap.get(artist.djId) ?? null) : null,
});

export const getLineup = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const eventId = paramString(req.params.eventId);
    const snapshot = await loadCanonicalEventLineupSnapshot(prisma, eventId);
    const djIds = Array.from(new Set(snapshot.artists.flatMap((artist) => artist.djId ? [artist.djId] : [])));
    const djs = djIds.length
      ? await prisma.dJ.findMany({ where: { id: { in: djIds } }, select: { id: true, name: true, avatarUrl: true } })
      : [];
    const djMap = new Map(djs.map((dj) => [dj.id, dj]));
    res.json({
      artists: snapshot.artists.map((artist) => ({
        ...toArtistResponse(artist, djMap),
        eventId,
      })),
    });
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

    const createdArtistId = randomUUID();
    const artist = await prisma.$transaction(async (tx) => {
      const snapshot = await loadCanonicalEventLineupSnapshot(tx, eventId);
      const nextArtists = [
        ...snapshot.artists,
        {
          id: createdArtistId,
          djId: normalizedDjId,
          djIds: normalizeDjIds(djIds, normalizedDjId),
          djName: name,
          sortOrder: typeof sortOrder === 'number' ? sortOrder : snapshot.artists.length + 1,
        },
      ];
      await syncCanonicalEventLineupAndTimetable(tx, eventId, snapshot.slots, nextArtists);
      return nextArtists.find((item) => item.id === createdArtistId) || null;
    });

    if (!artist) {
      res.status(500).json({ error: 'Failed to create lineup artist' });
      return;
    }

    const dj = artist.djId
      ? await prisma.dJ.findUnique({ where: { id: artist.djId }, select: { id: true, name: true, avatarUrl: true } })
      : null;
    res.status(201).json({
      ...toArtistResponse(artist, new Map(dj ? [[dj.id, dj]] : [])),
      eventId,
    });
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

    const { djId, djIds, djName, sortOrder } = req.body;
    const normalizedDjId = String(djId || '').trim() || null;
    const updatedArtist = await prisma.$transaction(async (tx) => {
      const snapshot = await loadCanonicalEventLineupSnapshot(tx, eventId);
      const existing = snapshot.artists.find((artist) => artist.id === artistId);
      if (!existing) return null;

      const nextArtists = snapshot.artists.map((artist) => (
        artist.id === artistId
          ? {
              ...artist,
              djId: djId !== undefined ? normalizedDjId : artist.djId,
              djIds: djIds !== undefined || djId !== undefined ? normalizeDjIds(djIds, normalizedDjId) : artist.djIds,
              djName: djName ? String(djName).trim() : artist.djName,
              sortOrder: typeof sortOrder === 'number' ? sortOrder : artist.sortOrder,
            }
          : artist
      ));
      await syncCanonicalEventLineupAndTimetable(tx, eventId, snapshot.slots, nextArtists);
      return nextArtists.find((artist) => artist.id === artistId) || null;
    });

    if (!updatedArtist) { res.status(404).json({ error: 'Lineup artist not found' }); return; }

    const dj = updatedArtist.djId
      ? await prisma.dJ.findUnique({ where: { id: updatedArtist.djId }, select: { id: true, name: true, avatarUrl: true } })
      : null;
    res.json({
      ...toArtistResponse(updatedArtist, new Map(dj ? [[dj.id, dj]] : [])),
      eventId,
    });
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

    const result = await prisma.$transaction(async (tx) => {
      const snapshot = await loadCanonicalEventLineupSnapshot(tx, eventId);
      const existing = snapshot.artists.find((artist) => artist.id === artistId);
      if (!existing) return 'missing' as const;
      const slotCount = snapshot.slots.filter((slot) => slot.lineupArtistId === artistId).length;
      if (slotCount > 0) return slotCount;

      await syncCanonicalEventLineupAndTimetable(
        tx,
        eventId,
        snapshot.slots,
        snapshot.artists.filter((artist) => artist.id !== artistId)
      );
      return 0;
    });

    if (result === 'missing') { res.status(404).json({ error: 'Lineup artist not found' }); return; }
    if (typeof result === 'number' && result > 0) {
      res.status(409).json({
        error: `该 DJ 下还有 ${result} 条时间表演出，请先删除时间表条目后再删除阵容。`,
      });
      return;
    }

    res.status(204).send();
  } catch (error) {
    console.error('Delete lineup artist error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};
