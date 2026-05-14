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
import { authenticate } from '../middleware/auth';
import { requireAdminOrOperator } from '../modules/admin/admin-auth.policy';

const router: Router = Router();

router.post('/pre-registrations', createPreRegistration);

router.get('/admin/pre-registrations', authenticate, requireAdminOrOperator, listPreRegistrations);
router.get('/admin/pre-registration-batches', authenticate, requireAdminOrOperator, listPreRegistrationBatches);
router.post('/admin/pre-registration-batches', authenticate, requireAdminOrOperator, createPreRegistrationBatch);
router.get('/admin/pre-registration-batches/:batchId/results', authenticate, requireAdminOrOperator, getPreRegistrationBatchResults);
router.post('/admin/pre-registration-batches/:batchId/decisions', authenticate, requireAdminOrOperator, applyPreRegistrationDecisions);
router.post('/admin/pre-registration-notifications', authenticate, requireAdminOrOperator, createPreRegistrationNotifications);

export default router;
