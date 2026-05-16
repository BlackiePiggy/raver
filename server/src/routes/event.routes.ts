import { Router } from 'express';
import multer from 'multer';
import path from 'path';
import fs from 'fs';
import {
  getEvents,
  getEventYears,
  getMyEvents,
  getEvent,
  createEvent,
  updateEvent,
  deleteEvent,
  uploadEventImage,
} from '../modules/events';
import {
  getLineup,
  addLineupArtist,
  updateLineupArtist,
  deleteLineupArtist,
} from '../modules/events';
import {
  getTimetable,
  addTimetableSlot,
  updateTimetableSlot,
  deleteTimetableSlot,
} from '../modules/events';
import { authenticate } from '../middleware/auth';

const router: Router = Router();

const uploadDir = path.join(process.cwd(), 'uploads', 'events');
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => {
    cb(null, uploadDir);
  },
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

router.get('/', getEvents);
router.get('/years', getEventYears);
router.get('/mine', authenticate, getMyEvents);
router.post('/upload-image', authenticate, upload.single('image'), uploadEventImage);
router.get('/:eventId/lineup', getLineup);
router.post('/:eventId/lineup', authenticate, addLineupArtist);
router.patch('/:eventId/lineup/:artistId', authenticate, updateLineupArtist);
router.delete('/:eventId/lineup/:artistId', authenticate, deleteLineupArtist);
router.get('/:eventId/timetable', getTimetable);
router.post('/:eventId/timetable', authenticate, addTimetableSlot);
router.patch('/:eventId/timetable/:slotId', authenticate, updateTimetableSlot);
router.delete('/:eventId/timetable/:slotId', authenticate, deleteTimetableSlot);
router.get('/:id', getEvent);
router.post('/', authenticate, createEvent);
router.put('/:id', authenticate, updateEvent);
router.delete('/:id', authenticate, deleteEvent);

export default router;
