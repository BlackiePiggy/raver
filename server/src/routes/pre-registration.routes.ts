import { Router } from 'express';
import {
  applyPreRegistrationDecisions,
  createPreRegistration,
  createPreRegistrationBatch,
  createPreRegistrationNotifications,
  getPreRegistrationBatchResults,
  listPreRegistrationBatches,
  listPreRegistrations,
} from '../controllers/pre-registration.controller';
import { authenticate, authorize } from '../middleware/auth';

const router: Router = Router();

router.post('/pre-registrations', createPreRegistration);

router.get('/admin/pre-registrations', authenticate, authorize('admin', 'operator'), listPreRegistrations);
router.get('/admin/pre-registration-batches', authenticate, authorize('admin', 'operator'), listPreRegistrationBatches);
router.post('/admin/pre-registration-batches', authenticate, authorize('admin', 'operator'), createPreRegistrationBatch);
router.get('/admin/pre-registration-batches/:batchId/results', authenticate, authorize('admin', 'operator'), getPreRegistrationBatchResults);
router.post('/admin/pre-registration-batches/:batchId/decisions', authenticate, authorize('admin', 'operator'), applyPreRegistrationDecisions);
router.post('/admin/pre-registration-notifications', authenticate, authorize('admin', 'operator'), createPreRegistrationNotifications);

export default router;
