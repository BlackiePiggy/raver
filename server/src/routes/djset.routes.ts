import { Router, Request, Response } from 'express';
import type { IRouter } from 'express';
import multer from 'multer';
import fs from 'fs';
import path from 'path';
import djSetService from '../services/djset.service';
import { authenticate, AuthRequest } from '../middleware/auth';

const router: IRouter = Router();

const uploadDir = path.join(process.cwd(), 'uploads', 'dj-sets');
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, uploadDir),
  filename: (_req, file, cb) => {
    const ext = path.extname(file.originalname || '').toLowerCase();
    const safeExt = ext && ext.length <= 8 ? ext : '.jpg';
    cb(null, `${Date.now()}-${Math.random().toString(36).slice(2, 10)}${safeExt}`);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    if (!file.mimetype.startsWith('image/')) {
      cb(new Error('Only image files are allowed'));
      return;
    }
    cb(null, true);
  },
});

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
router.post('/', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { djId, djIds, customDjNames, title, videoUrl, thumbnailUrl, description, recordedAt, venue, eventName } = req.body;

    if (!djId || !title || !videoUrl) {
      res.status(400).json({ error: 'Missing required fields' });
      return;
    }

    const djSet = await djSetService.createDJSet({
      djId,
      djIds: Array.isArray(djIds) ? djIds : undefined,
      customDjNames: Array.isArray(customDjNames) ? customDjNames : undefined,
      uploadedById: userId,
      title,
      videoUrl,
      thumbnailUrl,
      description,
      recordedAt: recordedAt ? new Date(recordedAt) : undefined,
      venue,
      eventName,
    });

    res.status(201).json(djSet);
  } catch (error) {
    console.error('Create DJ set error:', error);
    const message = (error as Error).message || 'Failed to create DJ set';
    if (message.toLowerCase().includes('foreign key')) {
      res.status(400).json({ error: 'DJ ID 无效，请先选择有效的 DJ' });
      return;
    }
    res.status(500).json({ error: message });
  }
});

/**
 * GET /api/dj-sets/preview
 * Get video preview metadata
 */
router.get('/preview', async (req: Request, res: Response): Promise<void> => {
  try {
    const { videoUrl } = req.query;

    if (!videoUrl || typeof videoUrl !== 'string') {
      res.status(400).json({ error: 'videoUrl is required' });
      return;
    }

    const preview = await djSetService.getVideoPreview(videoUrl);
    res.json(preview);
  } catch (error) {
    console.error('Get DJ set preview error:', error);
    res.status(500).json({ error: (error as Error).message });
  }
});

/**
 * POST /api/dj-sets/upload-thumbnail
 * Upload DJ set cover image
 */
router.post('/upload-thumbnail', authenticate, upload.single('image'), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const file = (req as Request & { file?: Express.Multer.File }).file;
    if (!file) {
      res.status(400).json({ error: 'No file uploaded' });
      return;
    }

    const publicUrl = `/uploads/dj-sets/${file.filename}`;

    res.status(201).json({
      url: publicUrl,
      filename: file.filename,
      originalName: file.originalname,
      size: file.size,
      mimeType: file.mimetype,
    });
  } catch (error) {
    console.error('Upload DJ set thumbnail error:', error);
    res.status(500).json({ error: 'Failed to upload thumbnail' });
  }
});

/**
 * GET /api/dj-sets/mine
 * Get all DJ sets uploaded by current user
 */
router.get('/mine', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const sets = await djSetService.getDJSetsByUploader(userId);
    res.json(sets);
  } catch (error) {
    console.error('Get my DJ sets error:', error);
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
 * PUT /api/dj-sets/:id
 * Update DJ set basic info by uploader
 */
router.put('/:id', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const {
      djId,
      djIds,
      customDjNames,
      title,
      description,
      videoUrl,
      thumbnailUrl,
      venue,
      eventName,
      recordedAt,
    } = req.body;

    const updated = await djSetService.updateDJSetByUploader(req.params.id as string, userId, {
      djId,
      djIds: Array.isArray(djIds) ? djIds : undefined,
      customDjNames: Array.isArray(customDjNames) ? customDjNames : undefined,
      title,
      description,
      videoUrl,
      thumbnailUrl,
      venue,
      eventName,
      recordedAt: recordedAt ? new Date(recordedAt) : undefined,
    });
    res.json(updated);
  } catch (error) {
    const message = (error as Error).message || 'Failed to update DJ set';
    if (message === 'Forbidden') {
      res.status(403).json({ error: 'You can only edit your own DJ set' });
      return;
    }
    if (message === 'DJ set not found') {
      res.status(404).json({ error: message });
      return;
    }
    if (message === 'Invalid video URL') {
      res.status(400).json({ error: message });
      return;
    }
    console.error('Update DJ set error:', error);
    res.status(500).json({ error: message });
  }
});

/**
 * DELETE /api/dj-sets/:id
 * Delete DJ set by uploader
 */
router.delete('/:id', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    const role = req.user?.role;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    await djSetService.deleteDJSetByUploader(req.params.id as string, userId, role);
    res.status(204).send();
  } catch (error) {
    const message = (error as Error).message || 'Failed to delete DJ set';
    if (message === 'Forbidden') {
      res.status(403).json({ error: 'You can only delete your own DJ set' });
      return;
    }
    if (message === 'DJ set not found') {
      res.status(404).json({ error: message });
      return;
    }
    console.error('Delete DJ set error:', error);
    res.status(500).json({ error: message });
  }
});

/**
 * POST /api/dj-sets/:id/tracks
 * Add a track to a DJ set
 */
router.post('/:id/tracks', authenticate, async (req: Request, res: Response): Promise<void> => {
  try {
    const {
      position,
      startTime,
      endTime,
      title,
      artist,
      status,
      spotifyUrl,
      spotifyId,
      spotifyUri,
      neteaseUrl,
      neteaseId,
    } = req.body;

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
      spotifyUrl,
      spotifyId,
      spotifyUri,
      neteaseUrl,
      neteaseId,
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
router.post('/:id/tracks/batch', authenticate, async (req: Request, res: Response): Promise<void> => {
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
 * PUT /api/dj-sets/:id/tracks
 * Replace tracklist by uploader
 */
router.put('/:id/tracks', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { tracks } = req.body;
    if (!Array.isArray(tracks)) {
      res.status(400).json({ error: 'tracks must be an array' });
      return;
    }

    const updated = await djSetService.replaceTracksByUploader(req.params.id as string, userId, tracks);
    res.json(updated);
  } catch (error) {
    const message = (error as Error).message || 'Failed to update tracklist';
    if (message === 'Forbidden') {
      res.status(403).json({ error: 'You can only edit your own DJ set' });
      return;
    }
    if (message === 'DJ set not found') {
      res.status(404).json({ error: message });
      return;
    }
    console.error('Replace tracks error:', error);
    res.status(500).json({ error: message });
  }
});

/**
 * POST /api/dj-sets/:id/auto-link
 * Auto-link tracks to streaming platforms
 */
router.post('/:id/auto-link', authenticate, async (req: Request, res: Response): Promise<void> => {
  try {
    await djSetService.autoLinkTracks(req.params.id as string);
    res.json({ message: 'Tracks linked successfully' });
  } catch (error) {
    console.error('Auto-link tracks error:', error);
    res.status(500).json({ error: (error as Error).message });
  }
});

/**
 * GET /api/dj-sets/:id/tracklists
 * Get all tracklists for a DJ set
 */
router.get('/:id/tracklists', async (req: Request, res: Response): Promise<void> => {
  try {
    const tracklists = await djSetService.getTracklists(req.params.id as string);
    res.json(tracklists);
  } catch (error) {
    console.error('Get tracklists error:', error);
    res.status(500).json({ error: (error as Error).message });
  }
});

/**
 * POST /api/dj-sets/:id/tracklists
 * Create a new tracklist for a DJ set
 */
router.post('/:id/tracklists', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { title, tracks } = req.body;

    if (!Array.isArray(tracks) || tracks.length === 0) {
      res.status(400).json({ error: 'tracks is required and must be a non-empty array' });
      return;
    }

    const tracklist = await djSetService.createTracklist(req.params.id as string, userId, title, tracks);
    res.status(201).json(tracklist);
  } catch (error) {
    console.error('Create tracklist error:', error);
    res.status(500).json({ error: (error as Error).message });
  }
});

/**
 * GET /api/dj-sets/:setId/tracklists/:tracklistId
 * Get a specific tracklist with tracks
 */
router.get('/:setId/tracklists/:tracklistId', async (req: Request, res: Response): Promise<void> => {
  try {
    const tracklist = await djSetService.getTracklistById(req.params.tracklistId as string);
    if (!tracklist) {
      res.status(404).json({ error: 'Tracklist not found' });
      return;
    }
    res.json(tracklist);
  } catch (error) {
    console.error('Get tracklist error:', error);
    res.status(500).json({ error: (error as Error).message });
  }
});

export default router;
