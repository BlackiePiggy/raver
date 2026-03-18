import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

export const squadService = {
  // 创建小队
  async createSquad(data: {
    name: string;
    description?: string;
    leaderId: string;
    isPublic?: boolean;
    maxMembers?: number;
  }) {
    const squad = await prisma.squad.create({
      data: {
        name: data.name,
        description: data.description,
        leaderId: data.leaderId,
        isPublic: data.isPublic ?? false,
        maxMembers: data.maxMembers ?? 50,
      },
      include: {
        leader: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
        members: {
          include: {
            user: {
              select: {
                id: true,
                username: true,
                displayName: true,
                avatarUrl: true,
              },
            },
          },
        },
      },
    });

    // 自动添加队长为成员
    await prisma.squadMember.create({
      data: {
        squadId: squad.id,
        userId: data.leaderId,
        role: 'leader',
      },
    });

    return squad;
  },

  // 获取小队列表
  async getSquads(filters?: {
    userId?: string;
    isPublic?: boolean;
    search?: string;
  }) {
    const where: any = {};

    if (filters?.isPublic !== undefined) {
      where.isPublic = filters.isPublic;
    }

    if (filters?.search) {
      where.OR = [
        { name: { contains: filters.search, mode: 'insensitive' } },
        { description: { contains: filters.search, mode: 'insensitive' } },
      ];
    }

    if (filters?.userId) {
      where.members = {
        some: {
          userId: filters.userId,
        },
      };
    }

    const squads = await prisma.squad.findMany({
      where,
      include: {
        leader: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
        members: {
          include: {
            user: {
              select: {
                id: true,
                username: true,
                displayName: true,
                avatarUrl: true,
              },
            },
          },
        },
        _count: {
          select: {
            members: true,
            messages: true,
          },
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    return squads;
  },

  // 获取小队详情
  async getSquadById(squadId: string, userId?: string) {
    const squad = await prisma.squad.findUnique({
      where: { id: squadId },
      include: {
        leader: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
        members: {
          include: {
            user: {
              select: {
                id: true,
                username: true,
                displayName: true,
                avatarUrl: true,
              },
            },
          },
          orderBy: {
            joinedAt: 'asc',
          },
        },
        _count: {
          select: {
            messages: true,
            activities: true,
            albums: true,
          },
        },
      },
    });

    if (!squad) {
      return null;
    }

    // 检查用户是否是成员
    let isMember = false;
    if (userId) {
      isMember = squad.members.some(m => m.userId === userId);
    }

    return {
      ...squad,
      isMember,
    };
  },

  // 邀请用户加入小队
  async inviteUser(data: {
    squadId: string;
    inviterId: string;
    inviteeId: string;
  }) {
    // 检查邀请者是否是小队成员
    const member = await prisma.squadMember.findUnique({
      where: {
        squadId_userId: {
          squadId: data.squadId,
          userId: data.inviterId,
        },
      },
    });

    if (!member) {
      throw new Error('只有小队成员才能邀请其他用户');
    }

    // 检查被邀请者是否已经是成员
    const existingMember = await prisma.squadMember.findUnique({
      where: {
        squadId_userId: {
          squadId: data.squadId,
          userId: data.inviteeId,
        },
      },
    });

    if (existingMember) {
      throw new Error('该用户已经是小队成员');
    }

    // 检查是否已有待处理的邀请
    const existingInvite = await prisma.squadInvite.findUnique({
      where: {
        squadId_inviteeId: {
          squadId: data.squadId,
          inviteeId: data.inviteeId,
        },
      },
    });

    if (existingInvite && existingInvite.status === 'pending') {
      throw new Error('该用户已有待处理的邀请');
    }

    // 创建邀请（7天有效期）
    const invite = await prisma.squadInvite.create({
      data: {
        squadId: data.squadId,
        inviterId: data.inviterId,
        inviteeId: data.inviteeId,
        expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
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
    });

    return invite;
  },

  // 处理邀请（接受/拒绝）
  async handleInvite(inviteId: string, userId: string, accept: boolean) {
    const invite = await prisma.squadInvite.findUnique({
      where: { id: inviteId },
      include: {
        squad: true,
      },
    });

    if (!invite) {
      throw new Error('邀请不存在');
    }

    if (invite.inviteeId !== userId) {
      throw new Error('无权处理此邀请');
    }

    if (invite.status !== 'pending') {
      throw new Error('邀请已被处理');
    }

    if (new Date() > invite.expiresAt) {
      throw new Error('邀请已过期');
    }

    // 更新邀请状态
    await prisma.squadInvite.update({
      where: { id: inviteId },
      data: {
        status: accept ? 'accepted' : 'rejected',
      },
    });

    // 如果接受，添加为成员
    if (accept) {
      // 检查小队是否已满
      const memberCount = await prisma.squadMember.count({
        where: { squadId: invite.squadId },
      });

      if (memberCount >= invite.squad.maxMembers) {
        throw new Error('小队已满');
      }

      await prisma.squadMember.create({
        data: {
          squadId: invite.squadId,
          userId: userId,
          role: 'member',
        },
      });

      // 发送系统消息
      await prisma.squadMessage.create({
        data: {
          squadId: invite.squadId,
          userId: userId,
          content: '加入了小队',
          type: 'system',
        },
      });
    }

    return { success: true, accepted: accept };
  },

  // 获取用户的邀请列表
  async getUserInvites(userId: string) {
    const invites = await prisma.squadInvite.findMany({
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
            description: true,
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
    });

    return invites;
  },

  // 发送消息
  async sendMessage(data: {
    squadId: string;
    userId: string;
    content: string;
    type?: string;
    imageUrl?: string;
  }) {
    // 检查用户是否是成员
    const member = await prisma.squadMember.findUnique({
      where: {
        squadId_userId: {
          squadId: data.squadId,
          userId: data.userId,
        },
      },
    });

    if (!member) {
      throw new Error('只有小队成员才能发送消息');
    }

    const message = await prisma.squadMessage.create({
      data: {
        squadId: data.squadId,
        userId: data.userId,
        content: data.content,
        type: data.type ?? 'text',
        imageUrl: data.imageUrl,
      },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
      },
    });

    return message;
  },

  // 获取小队消息
  async getMessages(squadId: string, userId: string, limit = 50, before?: string) {
    // 检查用户是否是成员
    const member = await prisma.squadMember.findUnique({
      where: {
        squadId_userId: {
          squadId: squadId,
          userId: userId,
        },
      },
    });

    if (!member) {
      throw new Error('只有小队成员才能查看消息');
    }

    const where: any = { squadId };
    if (before) {
      where.createdAt = { lt: new Date(before) };
    }

    const messages = await prisma.squadMessage.findMany({
      where,
      include: {
        user: {
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

    return messages.reverse();
  },

  // 离开小队
  async leaveSquad(squadId: string, userId: string) {
    const squad = await prisma.squad.findUnique({
      where: { id: squadId },
    });

    if (!squad) {
      throw new Error('小队不存在');
    }

    if (squad.leaderId === userId) {
      throw new Error('队长不能离开小队，请先转让队长');
    }

    await prisma.squadMember.delete({
      where: {
        squadId_userId: {
          squadId: squadId,
          userId: userId,
        },
      },
    });

    // 发送系统消息
    await prisma.squadMessage.create({
      data: {
        squadId: squadId,
        userId: userId,
        content: '离开了小队',
        type: 'system',
      },
    });

    return { success: true };
  },
};
