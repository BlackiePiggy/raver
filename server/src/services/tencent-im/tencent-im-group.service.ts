import { PrismaClient } from '@prisma/client';
import { TencentIMClientError, tencentIMClient } from './tencent-im-client';
import { toTencentIMEventGroupID, toTencentIMSquadGroupID, toTencentIMUserID } from './tencent-im-id';
import type { TencentIMEventGroupProfile, TencentIMSquadGroupProfile } from './tencent-im-types';
import { tencentIMUserService } from './tencent-im-user.service';

interface SquadGroupInput {
  squadId: string;
  ownerUserId: string;
  memberUserIds: string[];
  name: string;
  introduction?: string | null;
  notification?: string | null;
}

interface EventGroupInput {
  eventId: string;
  ownerUserId: string;
  name: string;
  introduction?: string | null;
}

const prisma = new PrismaClient();

const toTencentRESTGroupType = (type: TencentIMSquadGroupProfile['type'] | TencentIMEventGroupProfile['type']): string => {
  if (type === 'Meeting') {
    return 'ChatRoom';
  }
  return type;
};

const isGroupAlreadyExistsError = (error: unknown): boolean => {
  if (!(error instanceof TencentIMClientError)) {
    return false;
  }
  return error.errorCode === 10025 || /already.*group id|group id.*used/i.test(error.message);
};

export const tencentIMGroupService = {
  buildSquadGroupProfile(input: SquadGroupInput): TencentIMSquadGroupProfile {
    const ownerUserID = toTencentIMUserID(input.ownerUserId);
    const memberUserIDs = Array.from(
      new Set([ownerUserID, ...input.memberUserIds.map((userId) => toTencentIMUserID(userId))])
    );

    return {
      groupID: toTencentIMSquadGroupID(input.squadId),
      ownerUserID,
      memberUserIDs,
      type: 'Public',
      name: input.name.trim(),
      introduction: input.introduction ?? null,
      notification: input.notification ?? null,
    };
  },

  buildEventGroupProfile(input: EventGroupInput): TencentIMEventGroupProfile {
    return {
      groupID: toTencentIMEventGroupID(input.eventId),
      ownerUserID: toTencentIMUserID(input.ownerUserId),
      type: 'Meeting',
      name: input.name.trim(),
      introduction: input.introduction ?? null,
    };
  },

  async ensureSquadGroupById(squadId: string): Promise<TencentIMSquadGroupProfile> {
    const squad = await prisma.squad.findUnique({
      where: { id: squadId },
      include: {
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
      },
    });

    if (!squad) {
      throw new Error(`Tencent IM squad sync failed: squad ${squadId} not found`);
    }

    const memberUserIds = squad.members.map((member) => member.userId);
    await tencentIMUserService.ensureUsersByIds(memberUserIds);

    const profile = this.buildSquadGroupProfile({
      squadId: squad.id,
      ownerUserId: squad.leaderId,
      memberUserIds: memberUserIds.filter((userId) => userId !== squad.leaderId),
      name: squad.name,
      introduction: squad.description,
      notification: squad.notice,
    });

    const memberList = squad.members
      .filter((member) => member.userId !== squad.leaderId)
      .map((member) => ({
        Member_Account: toTencentIMUserID(member.userId),
      }));

    try {
      await tencentIMClient.post('v4/group_open_http_svc/create_group', {
        Owner_Account: profile.ownerUserID,
        Type: toTencentRESTGroupType(profile.type),
        GroupId: profile.groupID,
        Name: profile.name,
        Introduction: profile.introduction || '',
        Notification: profile.notification || '',
        FaceUrl: squad.avatarUrl || '',
        MaxMemberNum: squad.maxMembers,
        ApplyJoinOption: squad.isPublic ? 'FreeAccess' : 'NeedPermission',
        MemberList: memberList,
      });
    } catch (error) {
      if (!isGroupAlreadyExistsError(error)) {
        throw error;
      }
    }

    await tencentIMClient.post('v4/group_open_http_svc/modify_group_base_info', {
      GroupId: profile.groupID,
      Name: profile.name,
      Introduction: profile.introduction || '',
      Notification: profile.notification || '',
      FaceUrl: squad.avatarUrl || '',
      MaxMemberNum: squad.maxMembers,
      ApplyJoinOption: squad.isPublic ? 'FreeAccess' : 'NeedPermission',
    });

    if (memberList.length > 0) {
      await tencentIMClient.post<{ Member_Account: string; Result: number }[]>(
        'v4/group_open_http_svc/add_group_member',
        {
          GroupId: profile.groupID,
          Silence: 1,
          MemberList: memberList,
        }
      );
    }

    return profile;
  },

  async removeGroupMembers(squadId: string, memberUserIds: string[], reason?: string): Promise<void> {
    const normalized = Array.from(new Set(memberUserIds.map((item) => item.trim()).filter((item) => item.length > 0)));
    if (normalized.length === 0) {
      return;
    }

    await tencentIMClient.post('v4/group_open_http_svc/delete_group_member', {
      GroupId: toTencentIMSquadGroupID(squadId),
      Silence: 1,
      Reason: reason || '',
      MemberToDel_Account: normalized.map((userId) => toTencentIMUserID(userId)),
    });
  },

  async addGroupMembers(squadId: string, memberUserIds: string[], reason?: string): Promise<void> {
    const normalized = Array.from(new Set(memberUserIds.map((item) => item.trim()).filter((item) => item.length > 0)));
    if (normalized.length === 0) {
      return;
    }

    await tencentIMUserService.ensureUsersByIds(normalized);
    await tencentIMClient.post<{ Member_Account: string; Result: number; ResultMsg?: string }[]>(
      'v4/group_open_http_svc/add_group_member',
      {
        GroupId: toTencentIMSquadGroupID(squadId),
        Silence: 1,
        Reason: reason || '',
        MemberList: normalized.map((userId) => ({
          Member_Account: toTencentIMUserID(userId),
        })),
      }
    );
  },

  async dismissSquadGroup(squadId: string): Promise<void> {
    await tencentIMClient.post('v4/group_open_http_svc/destroy_group', {
      GroupId: toTencentIMSquadGroupID(squadId),
    });
  },

  async transferSquadGroupOwner(squadId: string, newOwnerUserId: string): Promise<void> {
    await tencentIMUserService.ensureUsersByIds([newOwnerUserId]);
    await tencentIMClient.post('v4/group_open_http_svc/change_group_owner', {
      GroupId: toTencentIMSquadGroupID(squadId),
      NewOwner_Account: toTencentIMUserID(newOwnerUserId),
    });
  },

  async updateGroupMemberRole(squadId: string, memberUserId: string, role: 'admin' | 'member'): Promise<void> {
    await tencentIMUserService.ensureUsersByIds([memberUserId]);
    await tencentIMClient.post('v4/group_open_http_svc/modify_group_member_info', {
      GroupId: toTencentIMSquadGroupID(squadId),
      Member_Account: toTencentIMUserID(memberUserId),
      Role: role === 'admin' ? 'Admin' : 'Member',
      Silence: 1,
    });
  },

  async sendSquadTextMessage(squadId: string, senderUserId: string, text: string): Promise<void> {
    const content = text.trim();
    if (!content) {
      throw new Error('Tencent IM test message text cannot be empty');
    }

    await tencentIMClient.post('v4/group_open_http_svc/send_group_msg', {
      GroupId: toTencentIMSquadGroupID(squadId),
      From_Account: toTencentIMUserID(senderUserId),
      Random: Math.floor(Math.random() * 0x7fffffff),
      MsgBody: [
        {
          MsgType: 'TIMTextElem',
          MsgContent: {
            Text: content,
          },
        },
      ],
    });
  },
};
