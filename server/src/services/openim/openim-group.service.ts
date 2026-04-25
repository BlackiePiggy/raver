import { openIMConfig } from './openim-config';
import { openIMClient, OpenIMClientError } from './openim-client';
import { toOpenIMGroupID, toOpenIMUserID } from './openim-id';
import { openIMUserService } from './openim-user.service';

interface CreateSquadGroupInput {
  squadId: string;
  name: string;
  ownerUserId: string;
  memberUserIds: string[];
  avatarUrl?: string | null;
  description?: string | null;
  notice?: string | null;
  verified?: boolean;
}

interface SyncSquadGroupProfileInput {
  squadId: string;
  name: string;
  avatarUrl?: string | null;
  description?: string | null;
  notice?: string | null;
  bannerUrl?: string | null;
  qrCodeUrl?: string | null;
  isPublic?: boolean;
  verified?: boolean;
}

interface RemoveGroupMembersOptions {
  tolerateKnownKickIssue?: boolean;
}

export interface RemoveGroupMembersResult {
  toleratedKnownIssue: boolean;
}

const toGroupMemberRoleLevel = (role: 'admin' | 'member'): number => {
  return role === 'admin' ? 60 : 20;
};

const isKickMaxSeqKnownIssue = (error: unknown): boolean => {
  if (!(error instanceof OpenIMClientError)) {
    return false;
  }
  if (error.errCode !== 1001) {
    return false;
  }
  const message = String(error.message || '');
  return /maxSeq\s+is\s+invalid/i.test(message) || /ArgsError/i.test(message);
};

const isDismissGroupAlreadyGone = (error: unknown): boolean => {
  if (!(error instanceof OpenIMClientError)) {
    return false;
  }
  const message = String(error.message || '');
  return /group.*not.*exist/i.test(message) || /group.*not.*found/i.test(message);
};

export const openIMGroupService = {
  async createSquadGroup(input: CreateSquadGroupInput): Promise<void> {
    if (!openIMConfig.enabled) {
      return;
    }

    await openIMUserService.ensureUsersByIds([input.ownerUserId, ...input.memberUserIds]);

    const ownerUserID = toOpenIMUserID(input.ownerUserId);
    const allUserIDs = Array.from(
      new Set([ownerUserID, ...input.memberUserIds.map((userId) => toOpenIMUserID(userId))])
    );
    const groupID = toOpenIMGroupID(input.squadId);

    if (allUserIDs.length < 3) {
      throw new Error('OpenIM group creation requires at least 3 members');
    }

    await openIMClient.post(openIMConfig.paths.createGroup, {
      memberUserIDs: allUserIDs.filter((userID) => userID !== ownerUserID),
      ownerUserID,
      adminUserIDs: [],
      groupInfo: {
        groupID,
        groupName: input.name,
        faceURL: input.avatarUrl || '',
        introduction: input.description || '',
        notification: input.notice || '',
        ex: JSON.stringify({
          raver: {
            squadID: input.squadId,
            openIMGroupID: groupID,
            verified: Boolean(input.verified),
          },
        }),
        groupType: 2,
        needVerification: 0,
        lookMemberInfo: 0,
        applyMemberFriend: 0,
      },
      operationID: openIMClient.createOperationId('create-squad-group'),
    });
  },

  async addGroupMembers(groupOwnerRaverUserId: string, squadId: string, memberUserIds: string[], reason?: string): Promise<void> {
    if (!openIMConfig.enabled) {
      return;
    }

    const normalizedMemberUserIds = Array.from(
      new Set(memberUserIds.map((userId) => userId.trim()).filter((userId) => userId.length > 0))
    );

    if (normalizedMemberUserIds.length === 0) {
      return;
    }

    await openIMUserService.ensureUsersByIds([groupOwnerRaverUserId, ...normalizedMemberUserIds]);

    await openIMClient.post(openIMConfig.paths.inviteUserToGroup, {
      groupID: toOpenIMGroupID(squadId),
      invitedUserIDs: normalizedMemberUserIds.map((userId) => toOpenIMUserID(userId)),
      reason: reason || '',
      operationID: openIMClient.createOperationId('invite-squad-members'),
    });
  },

  async removeGroupMembers(
    squadId: string,
    memberUserIds: string[],
    reason?: string,
    options?: RemoveGroupMembersOptions
  ): Promise<RemoveGroupMembersResult> {
    if (!openIMConfig.enabled) {
      return { toleratedKnownIssue: false };
    }

    const normalizedMemberUserIds = Array.from(
      new Set(memberUserIds.map((userId) => userId.trim()).filter((userId) => userId.length > 0))
    );

    if (normalizedMemberUserIds.length === 0) {
      return { toleratedKnownIssue: false };
    }

    try {
      await openIMClient.post(openIMConfig.paths.kickGroup, {
        groupID: toOpenIMGroupID(squadId),
        kickedUserIDs: normalizedMemberUserIds.map((userId) => toOpenIMUserID(userId)),
        reason: reason || '',
        operationID: openIMClient.createOperationId('kick-squad-members'),
      });
      return { toleratedKnownIssue: false };
    } catch (error) {
      const shouldTolerate = Boolean(options?.tolerateKnownKickIssue || openIMConfig.tolerateKickMaxSeqIssue);
      if (shouldTolerate && isKickMaxSeqKnownIssue(error)) {
        console.warn('[openim] kick_group tolerated due to known maxSeq issue', {
          squadId,
          kickedUserIds: normalizedMemberUserIds,
          reason: reason || '',
        });
        return { toleratedKnownIssue: true };
      }
      throw error;
    }
  },

  async syncSquadGroupProfile(input: SyncSquadGroupProfileInput): Promise<void> {
    if (!openIMConfig.enabled) {
      return;
    }

    const groupID = toOpenIMGroupID(input.squadId);

    await openIMClient.post(openIMConfig.paths.setGroupInfo, {
      groupID,
      groupName: input.name,
      faceURL: input.avatarUrl || '',
      introduction: input.description || '',
      notification: input.notice || '',
      ex: JSON.stringify({
        raver: {
          squadID: input.squadId,
          openIMGroupID: groupID,
          bannerUrl: input.bannerUrl || '',
          qrCodeUrl: input.qrCodeUrl || '',
          isPublic: Boolean(input.isPublic),
          verified: Boolean(input.verified),
        },
      }),
      needVerification: 0,
      lookMemberInfo: 0,
      applyMemberFriend: 0,
      operationID: openIMClient.createOperationId('sync-squad-group-profile'),
    });
  },

  async updateGroupMemberRole(squadId: string, memberUserId: string, role: 'admin' | 'member'): Promise<void> {
    if (!openIMConfig.enabled) {
      return;
    }

    await openIMClient.post(openIMConfig.paths.setGroupMemberInfo, {
      members: [
        {
          groupID: toOpenIMGroupID(squadId),
          userID: toOpenIMUserID(memberUserId),
          roleLevel: toGroupMemberRoleLevel(role),
          ex: JSON.stringify({
            raver: {
              squadID: squadId,
              role,
            },
          }),
        },
      ],
      operationID: openIMClient.createOperationId('set-squad-member-role'),
    });
  },

  async transferGroupOwner(squadId: string, oldOwnerUserId: string, newOwnerUserId: string): Promise<void> {
    if (!openIMConfig.enabled) {
      return;
    }

    await openIMUserService.ensureUsersByIds([oldOwnerUserId, newOwnerUserId]);

    await openIMClient.post(openIMConfig.paths.transferGroup, {
      groupID: toOpenIMGroupID(squadId),
      oldOwnerUserID: toOpenIMUserID(oldOwnerUserId),
      newOwnerUserID: toOpenIMUserID(newOwnerUserId),
      operationID: openIMClient.createOperationId('transfer-squad-owner'),
    });
  },

  async dismissSquadGroup(squadId: string): Promise<void> {
    if (!openIMConfig.enabled) {
      return;
    }

    try {
      await openIMClient.post(openIMConfig.paths.dismissGroup, {
        groupID: toOpenIMGroupID(squadId),
        operationID: openIMClient.createOperationId('dismiss-squad-group'),
      });
    } catch (error) {
      if (isDismissGroupAlreadyGone(error)) {
        console.warn('[openim] dismiss_group tolerated: group already absent', { squadId });
        return;
      }
      throw error;
    }
  },
};
