import { PrismaClient } from '@prisma/client';
import { tencentIMConfig } from './tencent-im-config';
import { toTencentIMUserID } from './tencent-im-id';
import type { TencentIMBootstrap } from './tencent-im-types';
import { tencentIMUserService } from './tencent-im-user.service';
import { tencentIMUserSigService } from './tencent-im-usersig.service';

const prisma = new PrismaClient();

const buildDisabledBootstrap = (userId: string): TencentIMBootstrap => {
  return {
    enabled: false,
    sdkAppID: tencentIMConfig.sdkAppId,
    userID: toTencentIMUserID(userId),
    userSig: null,
    expiresAt: null,
    region: tencentIMConfig.region,
    adminIdentifier: tencentIMConfig.adminIdentifier,
  };
};

export const tencentIMTokenService = {
  async bootstrapForUser(userId: string): Promise<TencentIMBootstrap> {
    if (!tencentIMConfig.enabled) {
      return buildDisabledBootstrap(userId);
    }

    if (!tencentIMConfig.isConfigured) {
      throw new Error('Tencent IM is enabled but missing SDKAppID or SecretKey');
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
      throw new Error('Tencent IM bootstrap cannot be issued for inactive user');
    }

    const profile = await tencentIMUserService.ensureUser(user);
    const userSig = tencentIMUserSigService.generate(profile.userID);

    return {
      enabled: true,
      sdkAppID: tencentIMConfig.sdkAppId,
      userID: profile.userID,
      userSig,
      expiresAt: tencentIMUserSigService.expiresAt(),
      region: tencentIMConfig.region,
      adminIdentifier: tencentIMConfig.adminIdentifier,
    };
  },
};
