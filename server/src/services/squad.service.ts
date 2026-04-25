import { PrismaClient } from '@prisma/client';
import { openIMGroupService } from './openim/openim-group.service';
import { notificationCenterService } from './notification-center';

const prisma = new PrismaClient();
const MIN_SQUAD_INITIAL_MEMBERS = 3;
const MIN_SQUAD_INVITED_MEMBERS = MIN_SQUAD_INITIAL_MEMBERS - 1;

export const squadService = {
  // 创建小队
  async createSquad(data: {
    name: string;
    description?: string;
    leaderId: string;
    memberIds?: string[];
    isPublic?: boolean;
    maxMembers?: number;
  }) {
    const memberIds = Array.from(
      new Set((data.memberIds ?? []).map((id) => id.trim()).filter((id) => id.length > 0 && id !== data.leaderId))
    );

    if (memberIds.length < MIN_SQUAD_INVITED_MEMBERS) {
      throw new Error('创建小队至少需要 3 人，请至少选择 2 位好友');
    }

    const maxMembers = data.maxMembers ?? 50;
    if (maxMembers < MIN_SQUAD_INITIAL_MEMBERS) {
      throw new Error('小队最大成员数不能小于 3 人');
    }
    if (maxMembers < memberIds.length + 1) {
      throw new Error('小队最大成员数不能小于初始成员数');
    }

    const squad = await prisma.$transaction(async (tx) => {
      const created = await tx.squad.create({
        data: {
          name: data.name,
          description: data.description,
          leaderId: data.leaderId,
          isPublic: data.isPublic ?? false,
          maxMembers,
        },
      });

      await tx.squadMember.createMany({
        data: [
          {
            squadId: created.id,
            userId: data.leaderId,
            role: 'leader',
          },
          ...memberIds.map((memberId) => ({
            squadId: created.id,
            userId: memberId,
            role: 'member',
          })),
        ],
      });

      return tx.squad.findUniqueOrThrow({
        where: { id: created.id },
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
    });

    try {
      await openIMGroupService.createSquadGroup({
        squadId: squad.id,
        name: squad.name,
        ownerUserId: data.leaderId,
        memberUserIds: memberIds,
        avatarUrl: squad.avatarUrl,
        description: squad.description,
        verified: false,
      });
    } catch (error) {
      await prisma.$transaction(async (tx) => {
        await tx.squadMember.deleteMany({
          where: { squadId: squad.id },
        });
        await tx.squad.delete({
          where: { id: squad.id },
        });
      });
      throw error;
    }

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

    if (invite.inviteeId !== invite.inviterId) {
      void notificationCenterService
        .publish({
          category: 'community_interaction',
          targets: [{ userId: invite.inviteeId }],
          channels: ['in_app', 'apns'],
          payload: {
            title: '社区互动',
            body: `你收到了加入小队「${invite.squad.name}」的邀请`,
            deeplink: `raver://squad/${invite.squad.id}`,
            metadata: {
              source: 'squad_invite',
              inviteID: invite.id,
              squadID: invite.squad.id,
              inviterUserID: invite.inviter.id,
            },
          },
          dedupeKey: `community:squad_invite:${invite.id}`,
        })
        .catch((error) => {
          const message = error instanceof Error ? error.message : String(error);
          console.error(`[notification-center] squad invite publish failed: ${message}`);
        });
    }

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

    if (!accept) {
      await prisma.squadInvite.update({
        where: { id: inviteId },
        data: {
          status: 'rejected',
        },
      });

      return { success: true, accepted: false };
    }

    // 检查小队是否已满
    const memberCount = await prisma.squadMember.count({
      where: { squadId: invite.squadId },
    });

    if (memberCount >= invite.squad.maxMembers) {
      throw new Error('小队已满');
    }

    const acceptedInvite = await prisma.$transaction(async (tx) => {
      await tx.squadInvite.update({
        where: { id: inviteId },
        data: {
          status: 'accepted',
        },
      });

      const membership = await tx.squadMember.create({
        data: {
          squadId: invite.squadId,
          userId: userId,
          role: 'member',
        },
      });

      const message = await tx.squadMessage.create({
        data: {
          squadId: invite.squadId,
          userId: userId,
          content: '加入了小队',
          type: 'system',
        },
      });

      return {
        membershipId: membership.id,
        messageId: message.id,
      };
    });

    try {
      await openIMGroupService.addGroupMembers(invite.squad.leaderId, invite.squadId, [userId], 'invite accepted');
    } catch (error) {
      await prisma.$transaction(async (tx) => {
        await tx.squadMessage.delete({
          where: { id: acceptedInvite.messageId },
        });
        await tx.squadMember.delete({
          where: { id: acceptedInvite.membershipId },
        });
        await tx.squadInvite.update({
          where: { id: inviteId },
          data: {
            status: 'pending',
          },
        });
      });
      throw error;
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

    const [squad, targetMembers] = await Promise.all([
      prisma.squad.findUnique({
        where: { id: data.squadId },
        select: { id: true, name: true },
      }),
      prisma.squadMember.findMany({
        where: {
          squadId: data.squadId,
          userId: { not: data.userId },
          notificationsEnabled: true,
        },
        select: { userId: true },
      }),
    ]);

    const senderDisplayName = message.user.displayName || message.user.username || '新消息';
    if (targetMembers.length > 0) {
      void notificationCenterService
        .publish({
          category: 'chat_message',
          targets: targetMembers.map((item) => ({ userId: item.userId })),
          channels: ['in_app', 'apns'],
          payload: {
            title: squad?.name || '小队消息',
            body: `${senderDisplayName}: ${data.content.slice(0, 100)}`,
            deeplink: `raver://messages/conversation/${data.squadId}`,
            metadata: {
              scope: 'group',
              conversationID: data.squadId,
              messageID: message.id,
              senderUserID: data.userId,
            },
          },
          dedupeKey: `chat:group:${message.id}`,
        })
        .catch((error) => {
          const messageError = error instanceof Error ? error.message : String(error);
          console.error(`[notification-center] squad message publish failed: ${messageError}`);
        });
    }

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

    const existingMembership = await prisma.squadMember.findUnique({
      where: {
        squadId_userId: {
          squadId,
          userId,
        },
      },
    });

    if (!existingMembership) {
      throw new Error('你不是该小队成员');
    }

    const leaveResult = await prisma.$transaction(async (tx) => {
      await tx.squadMember.delete({
        where: {
          squadId_userId: {
            squadId,
            userId,
          },
        },
      });

      const message = await tx.squadMessage.create({
        data: {
          squadId,
          userId,
          content: '离开了小队',
          type: 'system',
        },
      });

      return { messageId: message.id };
    });

    try {
      await openIMGroupService.removeGroupMembers(squadId, [userId], 'member left squad');
    } catch (error) {
      await prisma.$transaction(async (tx) => {
        await tx.squadMessage.delete({
          where: { id: leaveResult.messageId },
        });
        await tx.squadMember.create({
          data: {
            squadId,
            userId,
            role: existingMembership.role,
            lastReadAt: existingMembership.lastReadAt,
          },
        });
      });
      throw error;
    }

    return { success: true };
  },
};
