import { Router } from 'express';
import { notificationController } from '../controllers/notification.controller';
import { authenticate } from '../middleware/auth';

const router: Router = Router();

// 所有通知接口都需要登录
router.use(authenticate);

// 获取未读通知数量
router.get('/unread-count', notificationController.getUnreadCount);

// 获取所有通知
router.get('/', notificationController.getNotifications);

export default router;
