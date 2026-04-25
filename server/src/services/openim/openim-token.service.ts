import { PrismaClient } from '@prisma/client';
import { openIMConfig } from './openim-config';
import { openIMClient } from './openim-client';
import { toOpenIMUserID } from './openim-id';
import { openIMUserService } from './openim-user.service';
import type { OpenIMBootstrap, OpenIMUserTokenData } from './openim-types';

const prisma = new PrismaClient();

const getExpiresAt = (data: OpenIMUserTokenData): string | null => {
  const expireSeconds = data.expireTimeSeconds || data.expireTime;
  if (!expireSeconds) {
    return null;
  }
  return new Date(Date.now() + expireSeconds * 1000).toISOString();
};

export const openIMTokenService = {
  async bootstrapForUser(userId: string): Promise<OpenIMBootstrap> {
    const openIMUserID = toOpenIMUserID(userId);
    const disabledBootstrap = {
      enabled: false,
      userID: openIMUserID,
      token: null,
      apiURL: openIMConfig.clientApiBaseUrl,
      wsURL: openIMConfig.clientWsUrl,
      platformID: openIMConfig.platformId,
      systemUserID: openIMConfig.systemUserId,
      expiresAt: null,
    };

    if (!openIMConfig.enabled) {
      return disabledBootstrap;
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
      throw new Error('OpenIM token cannot be issued for inactive user');
    }

    await openIMUserService.ensureUser(user);

    const tokenData = await openIMClient.post<OpenIMUserTokenData>(openIMConfig.paths.getUserToken, {
      userID: openIMUserID,
      platformID: openIMConfig.platformId,
      operationID: openIMClient.createOperationId('user-token'),
    });

    return {
      enabled: true,
      userID: openIMUserID,
      token: tokenData.token,
      apiURL: openIMConfig.clientApiBaseUrl,
      wsURL: openIMConfig.clientWsUrl,
      platformID: openIMConfig.platformId,
      systemUserID: openIMConfig.systemUserId,
      expiresAt: getExpiresAt(tokenData),
    };
  },
};
