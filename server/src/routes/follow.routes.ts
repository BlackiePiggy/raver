import { Router } from 'express';
import {
  followDJ,
  unfollowDJ,
  getMyFollowedDJs,
  checkFollowStatus,
} from '../controllers/follow.controller';
import { authenticate } from '../middleware/auth';

const router: Router = Router();

router.post('/dj', authenticate, followDJ);
router.delete('/dj/:djId', authenticate, unfollowDJ);
router.get('/my/djs', authenticate, getMyFollowedDJs);
router.get('/dj/:djId/status', authenticate, checkFollowStatus);

export default router;
