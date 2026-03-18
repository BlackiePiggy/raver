import { Request, Response } from 'express';
import { squadService } from '../services/squad.service';

interface AuthRequest extends Request {
  user?: {
    userId: string;
    email: string;
    role: string;
  };
}

export const squadController = {
  // 创建小队
  async createSquad(req: Request, res: Response): Promise<void> {
    try {
      const { name, description, isPublic, maxMembers } = req.body;
      const userId = (req as AuthRequest).user?.userId;

      if (!userId) {
        res.status(401).json({ error: '未登录' });
        return;
      }

      if (!name || name.trim().length === 0) {
        res.status(400).json({ error: '小队名称不能为空' });
        return;
      }

      const squad = await squadService.createSquad({
        name: name.trim(),
        description: description?.trim(),
        leaderId: userId,
        isPublic,
        maxMembers,
      });

      res.status(201).json(squad);
    } catch (error: any) {
      console.error('创建小队失败:', error);
      res.status(500).json({ error: error.message || '创建小队失败' });
    }
  },

  // 获取小队列表
  async getSquads(req: Request, res: Response): Promise<void> {
    try {
      const { my, search, isPublic } = req.query;
      const userId = (req as AuthRequest).user?.userId;

      const filters: any = {};

      if (my === 'true' && userId) {
        filters.userId = userId;
      }

      if (search) {
        filters.search = search as string;
      }

      if (isPublic !== undefined) {
        filters.isPublic = isPublic === 'true';
      }

      const squads = await squadService.getSquads(filters);
      res.json(squads);
    } catch (error: any) {
      console.error('获取小队列表失败:', error);
      res.status(500).json({ error: error.message || '获取小队列表失败' });
    }
  },

  // 获取小队详情
  async getSquadById(req: Request, res: Response): Promise<void> {
    try {
      const { id } = req.params;
      const userId = (req as AuthRequest).user?.userId;

      const squad = await squadService.getSquadById(id as string, userId);

      if (!squad) {
        res.status(404).json({ error: '小队不存在' });
        return;
      }

      // 如果是私密小队且用户不是成员，不返回详细信息
      if (!squad.isPublic && !squad.isMember) {
        res.status(403).json({ error: '无权查看此小队' });
        return;
      }

      res.json(squad);
    } catch (error: any) {
      console.error('获取小队详情失败:', error);
      res.status(500).json({ error: error.message || '获取小队详情失败' });
    }
  },

  // 邀请用户
  async inviteUser(req: Request, res: Response): Promise<void> {
    try {
      const { id } = req.params;
      const { inviteeId } = req.body;
      const userId = (req as AuthRequest).user?.userId;

      if (!userId) {
        res.status(401).json({ error: '未登录' });
        return;
      }

      if (!inviteeId) {
        res.status(400).json({ error: '请指定被邀请用户' });
        return;
      }

      const invite = await squadService.inviteUser({
        squadId: id as string,
        inviterId: userId,
        inviteeId,
      });

      res.status(201).json(invite);
    } catch (error: any) {
      console.error('邀请用户失败:', error);
      res.status(400).json({ error: error.message || '邀请用户失败' });
    }
  },

  // 获取用户的邀请
  async getUserInvites(req: Request, res: Response): Promise<void> {
    try {
      const userId = (req as AuthRequest).user?.userId;

      if (!userId) {
        res.status(401).json({ error: '未登录' });
        return;
      }

      const invites = await squadService.getUserInvites(userId);
      res.json(invites);
    } catch (error: any) {
      console.error('获取邀请列表失败:', error);
      res.status(500).json({ error: error.message || '获取邀请列表失败' });
    }
  },

  // 处理邀请
  async handleInvite(req: Request, res: Response): Promise<void> {
    try {
      const { inviteId } = req.params;
      const { accept } = req.body;
      const userId = (req as AuthRequest).user?.userId;

      if (!userId) {
        res.status(401).json({ error: '未登录' });
        return;
      }

      if (accept === undefined) {
        res.status(400).json({ error: '请指定是否接受邀请' });
        return;
      }

      const result = await squadService.handleInvite(inviteId as string, userId, accept);
      res.json(result);
    } catch (error: any) {
      console.error('处理邀请失败:', error);
      res.status(400).json({ error: error.message || '处理邀请失败' });
    }
  },

  // 发送消息
  async sendMessage(req: Request, res: Response): Promise<void> {
    try {
      const { id } = req.params;
      const { content, type, imageUrl } = req.body;
      const userId = (req as AuthRequest).user?.userId;

      if (!userId) {
        res.status(401).json({ error: '未登录' });
        return;
      }

      if (!content || content.trim().length === 0) {
        res.status(400).json({ error: '消息内容不能为空' });
        return;
      }

      const message = await squadService.sendMessage({
        squadId: id as string,
        userId,
        content: content.trim(),
        type,
        imageUrl,
      });

      res.status(201).json(message);
    } catch (error: any) {
      console.error('发送消息失败:', error);
      res.status(400).json({ error: error.message || '发送消息失败' });
    }
  },

  // 获取消息
  async getMessages(req: Request, res: Response): Promise<void> {
    try {
      const { id } = req.params;
      const { limit, before } = req.query;
      const userId = (req as AuthRequest).user?.userId;

      if (!userId) {
        res.status(401).json({ error: '未登录' });
        return;
      }

      const messages = await squadService.getMessages(
        id as string,
        userId,
        limit ? parseInt(limit as string) : 50,
        before as string | undefined
      );

      res.json(messages);
    } catch (error: any) {
      console.error('获取消息失败:', error);
      res.status(400).json({ error: error.message || '获取消息失败' });
    }
  },

  // 离开小队
  async leaveSquad(req: Request, res: Response): Promise<void> {
    try {
      const { id } = req.params;
      const userId = (req as AuthRequest).user?.userId;

      if (!userId) {
        res.status(401).json({ error: '未登录' });
        return;
      }

      const result = await squadService.leaveSquad(id as string, userId);
      res.json(result);
    } catch (error: any) {
      console.error('离开小队失败:', error);
      res.status(400).json({ error: error.message || '离开小队失败' });
    }
  },
};
