import { PrismaClient } from '@prisma/client';
import { openIMConfig } from './openim-config';
import { openIMClient } from './openim-client';
import { OpenIMClientError } from './openim-client';
import { toOpenIMUserID } from './openim-id';
import type { OpenIMUserProfile } from './openim-types';

const prisma = new PrismaClient();
const LEGACY_OPENIM_UPDATE_USER_INFO_PATH = '/user/update_user_info';

interface RaverUserForOpenIM {
  id: string;
  username: string;
  displayName: string | null;
  avatarUrl: string | null;
}

const toOpenIMUser = (user: RaverUserForOpenIM): OpenIMUserProfile => {
  return {
    userID: toOpenIMUserID(user.id),
    nickname: user.displayName || user.username,
    faceURL: user.avatarUrl,
  };
};

const updateUserProfile = async (user: RaverUserForOpenIM): Promise<void> => {
  const profile = toOpenIMUser(user);
  const payload = {
    userInfo: {
      userID: profile.userID,
      nickname: profile.nickname,
      faceURL: profile.faceURL || '',
      ex: JSON.stringify({
        raver: {
          userID: user.id,
        },
      }),
    },
  };

  try {
    await openIMClient.post(openIMConfig.paths.updateUserInfo, {
      ...payload,
      operationID: openIMClient.createOperationId('update-user-info'),
    });
  } catch (error) {
    const shouldFallbackToLegacyPath =
      error instanceof OpenIMClientError &&
      error.status === 404 &&
      openIMConfig.paths.updateUserInfo !== LEGACY_OPENIM_UPDATE_USER_INFO_PATH;

    if (!shouldFallbackToLegacyPath) {
      throw error;
    }

    await openIMClient.post(LEGACY_OPENIM_UPDATE_USER_INFO_PATH, {
      ...payload,
      operationID: openIMClient.createOperationId('update-user-info'),
    });
  }
};

export const openIMUserService = {
  async ensureUser(user: RaverUserForOpenIM): Promise<void> {
    if (!openIMConfig.enabled) {
      return;
    }

    const profile = toOpenIMUser(user);
    try {
      await openIMClient.post(openIMConfig.paths.userRegister, {
        users: [profile],
        operationID: openIMClient.createOperationId('user-register'),
      });
    } catch (error) {
      if (error instanceof OpenIMClientError && error.errCode === 1102) {
        return;
      }
      throw error;
    }
  },

  async syncUserProfile(user: RaverUserForOpenIM): Promise<void> {
    if (!openIMConfig.enabled) {
      return;
    }

    await this.ensureUser(user);
    await updateUserProfile(user);
  },

  async syncUserById(userId: string): Promise<void> {
    if (!openIMConfig.enabled) {
      return;
    }

    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        username: true,
        displayName: true,
        avatarUrl: true,
        isActive: true,
      },
    });

    if (!user || !user.isActive) {
      throw new Error(`OpenIM user sync failed for user ID: ${userId}`);
    }

    await this.syncUserProfile(user);
  },

  async ensureUsersByIds(userIds: string[]): Promise<void> {
    if (!openIMConfig.enabled) {
      return;
    }

    const normalizedUserIds = Array.from(
      new Set(userIds.map((userId) => userId.trim()).filter((userId) => userId.length > 0))
    );

    if (normalizedUserIds.length === 0) {
      return;
    }

    const users = await prisma.user.findMany({
      where: {
        id: { in: normalizedUserIds },
      },
      select: {
        id: true,
        username: true,
        displayName: true,
        avatarUrl: true,
        isActive: true,
      },
    });

    const activeUsers = users.filter((user) => user.isActive);
    if (activeUsers.length !== normalizedUserIds.length) {
      const activeUserIds = new Set(activeUsers.map((user) => user.id));
      const missingUserIds = normalizedUserIds.filter((userId) => !activeUserIds.has(userId));
      throw new Error(`OpenIM user bootstrap failed for user IDs: ${missingUserIds.join(', ')}`);
    }

    await Promise.all(activeUsers.map((user) => this.ensureUser(user)));
  },
};
