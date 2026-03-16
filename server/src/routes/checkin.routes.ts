import { Router } from 'express';
import {
  createCheckin,
  getCheckins,
  getMyCheckins,
  deleteCheckin,
} from '../controllers/checkin.controller';
import { authenticate } from '../middleware/auth';

const router: Router = Router();

router.post('/', authenticate, createCheckin);
router.get('/', getCheckins);
router.get('/my', authenticate, getMyCheckins);
router.delete('/:id', authenticate, deleteCheckin);

export default router;
