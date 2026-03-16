import { Router, Request, Response } from 'express';
import type { IRouter } from 'express';
import djSetService from '../services/djset.service';

const router: IRouter = Router();

/**
 * GET /api/dj-sets
 * Get all DJ sets
 */
router.get('/', async (_req: Request, res: Response): Promise<void> => {
  try {
    const sets = await djSetService.getAllDJSets();
    res.json(sets);
  } catch (error) {
    console.error('Get all DJ sets error:', error);
    res.status(500).json({ error: (error as Error).message });
  }
});

/**
 * POST /api/dj-sets
 * Create a new DJ set
 */
router.post('/', async (req: Request, res: Response): Promise<void> => {
  try {
    const { djId, title, videoUrl, description, recordedAt, venue, eventName } = req.body;

    if (!djId || !title || !videoUrl) {
      res.status(400).json({ error: 'Missing required fields' });
      return;
    }

    const djSet = await djSetService.createDJSet({
      djId,
      title,
      videoUrl,
      description,
      recordedAt: recordedAt ? new Date(recordedAt) : undefined,
      venue,
      eventName,
    });

    res.status(201).json(djSet);
  } catch (error) {
    console.error('Create DJ set error:', error);
    res.status(500).json({ error: (error as Error).message });
  }
});

/**
 * GET /api/dj-sets/:id
 * Get DJ set by ID with tracks
 */
router.get('/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const djSet = await djSetService.getDJSet(req.params.id as string);
    if (!djSet) {
      res.status(404).json({ error: 'DJ set not found' });
      return;
    }
    res.json(djSet);
  } catch (error) {
    console.error('Get DJ set error:', error);
    res.status(500).json({ error: (error as Error).message });
  }
});

/**
 * GET /api/dj-sets/dj/:djId
 * Get all DJ sets by DJ ID
 */
router.get('/dj/:djId', async (req: Request, res: Response): Promise<void> => {
  try {
    const djSets = await djSetService.getDJSetsByDJ(req.params.djId as string);
    res.json(djSets);
  } catch (error) {
    console.error('Get DJ sets error:', error);
    res.status(500).json({ error: (error as Error).message });
  }
});

/**
 * POST /api/dj-sets/:id/tracks
 * Add a track to a DJ set
 */
router.post('/:id/tracks', async (req: Request, res: Response): Promise<void> => {
  try {
    const { position, startTime, endTime, title, artist, status } = req.body;

    if (!position || startTime === undefined || !title || !artist) {
      res.status(400).json({ error: 'Missing required fields' });
      return;
    }

    const track = await djSetService.addTrack({
      setId: req.params.id as string,
      position,
      startTime,
      endTime,
      title,
      artist,
      status,
    });

    res.status(201).json(track);
  } catch (error) {
    console.error('Add track error:', error);
    res.status(500).json({ error: (error as Error).message });
  }
});

/**
 * POST /api/dj-sets/:id/tracks/batch
 * Batch add tracks to a DJ set
 */
router.post('/:id/tracks/batch', async (req: Request, res: Response): Promise<void> => {
  try {
    const { tracks } = req.body;

    if (!Array.isArray(tracks) || tracks.length === 0) {
      res.status(400).json({ error: 'Invalid tracks data' });
      return;
    }

    await djSetService.batchAddTracks(req.params.id as string, tracks);
    res.status(201).json({ message: 'Tracks added successfully' });
  } catch (error) {
    console.error('Batch add tracks error:', error);
    res.status(500).json({ error: (error as Error).message });
  }
});

/**
 * POST /api/dj-sets/:id/auto-link
 * Auto-link tracks to streaming platforms
 */
router.post('/:id/auto-link', async (req: Request, res: Response): Promise<void> => {
  try {
    await djSetService.autoLinkTracks(req.params.id as string);
    res.json({ message: 'Tracks linked successfully' });
  } catch (error) {
    console.error('Auto-link tracks error:', error);
    res.status(500).json({ error: (error as Error).message });
  }
});

export default router;