import { Router } from 'express';
import {
  getDJs,
  getDJ,
  createDJ,
  updateDJ,
  deleteDJ,
} from '../controllers/dj.controller';
import { authenticate, authorize } from '../middleware/auth';

const router: Router = Router();

router.get('/', getDJs);
router.get('/:id', getDJ);
router.post('/', authenticate, authorize('admin', 'user'), createDJ);
router.put('/:id', authenticate, authorize('admin'), updateDJ);
router.delete('/:id', authenticate, authorize('admin'), deleteDJ);

export default router;
