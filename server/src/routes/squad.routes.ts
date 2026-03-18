import { Router } from 'express';
import { squadController } from '../controllers/squad.controller';
import { authenticate } from '../middleware/auth';

const router: Router = Router();

// 获取我的邀请（需要在 /:id 之前，避免被匹配）
router.get('/invites/me', authenticate, squadController.getUserInvites);

// 处理邀请
router.post('/invites/:inviteId/handle', authenticate, squadController.handleInvite);

// 获取小队列表（公开接口，但可以通过 my=true 获取我的小队）
router.get('/', squadController.getSquads);

// 获取小队详情
router.get('/:id', squadController.getSquadById);

// 以下接口需要登录
router.use(authenticate);

// 创建小队
router.post('/', squadController.createSquad);

// 邀请用户
router.post('/:id/invite', squadController.inviteUser);

// 发送消息
router.post('/:id/messages', squadController.sendMessage);

// 获取消息
router.get('/:id/messages', squadController.getMessages);

// 离开小队
router.post('/:id/leave', squadController.leaveSquad);

export default router;
