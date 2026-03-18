import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

export const notificationService = {
  // 获取未读通知数量
  async getUnreadCount(userId: string) {
    const [
      squadInvites,
      // 未来可以添加更多通知类型
    ] = await Promise.all([
      // 小队邀请
      prisma.squadInvite.count({
        where: {
          inviteeId: userId,
          status: 'pending',
          expiresAt: {
            gt: new Date(),
          },
        },
      }),
    ]);

    return {
      total: squadInvites,
      squadInvites,
      friendRequests: 0, // 待实现
      messages: 0, // 待实现
      likes: 0, // 待实现
      comments: 0, // 待实现
    };
  },

  // 获取所有通知
  async getNotifications(userId: string, limit = 20) {
    const squadInvites = await prisma.squadInvite.findMany({
      where: {
        inviteeId: userId,
        status: 'pending',
        expiresAt: {
          gt: new Date(),
        },
      },
      include: {
        squad: {
          select: {
            id: true,
            name: true,
            avatarUrl: true,
          },
        },
        inviter: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
      take: limit,
    });

    return {
      squadInvites,
      // 未来添加更多通知类型
    };
  },
};
