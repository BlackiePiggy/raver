import { Request, Response } from 'express';
import { notificationService } from '../services/notification.service';

interface AuthRequest extends Request {
  user?: {
    userId: string;
    email: string;
    role: string;
  };
}

export const notificationController = {
  // 获取未读通知数量
  async getUnreadCount(req: Request, res: Response): Promise<void> {
    try {
      const userId = (req as AuthRequest).user?.userId;

      if (!userId) {
        res.status(401).json({ error: '未登录' });
        return;
      }

      const count = await notificationService.getUnreadCount(userId);
      res.json(count);
    } catch (error: any) {
      console.error('获取未读通知数量失败:', error);
      res.status(500).json({ error: error.message || '获取未读通知数量失败' });
    }
  },

  // 获取所有通知
  async getNotifications(req: Request, res: Response): Promise<void> {
    try {
      const userId = (req as AuthRequest).user?.userId;
      const { limit } = req.query;

      if (!userId) {
        res.status(401).json({ error: '未登录' });
        return;
      }

      const notifications = await notificationService.getNotifications(
        userId,
        limit ? parseInt(limit as string) : 20
      );

      res.json(notifications);
    } catch (error: any) {
      console.error('获取通知失败:', error);
      res.status(500).json({ error: error.message || '获取通知失败' });
    }
  },
};
