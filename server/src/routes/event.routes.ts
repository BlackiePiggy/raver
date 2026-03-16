import { Router } from 'express';
import {
  getEvents,
  getEvent,
  createEvent,
  updateEvent,
  deleteEvent,
} from '../controllers/event.controller';
import { authenticate, authorize } from '../middleware/auth';

const router: Router = Router();

router.get('/', getEvents);
router.get('/:id', getEvent);
router.post('/', authenticate, authorize('admin', 'user'), createEvent);
router.put('/:id', authenticate, authorize('admin'), updateEvent);
router.delete('/:id', authenticate, authorize('admin'), deleteEvent);

export default router;
