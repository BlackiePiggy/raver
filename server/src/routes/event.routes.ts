import { Router } from 'express';
import multer from 'multer';
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

const upload = multer({
  storage: multer.memoryStorage(),
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
