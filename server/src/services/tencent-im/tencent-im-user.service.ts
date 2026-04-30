import { PrismaClient } from '@prisma/client';
import { tencentIMClient } from './tencent-im-client';
import { toTencentIMUserID } from './tencent-im-id';
import type { TencentIMUserProfile } from './tencent-im-types';

interface RaverUserForTencentIM {
  id: string;
  username: string;
  displayName: string | null;
  avatarUrl: string | null;
}

const prisma = new PrismaClient();

const toTencentIMUserProfile = (user: RaverUserForTencentIM): TencentIMUserProfile => {
  return {
    userID: toTencentIMUserID(user.id),
    nickname: user.displayName?.trim() || user.username.trim() || `user_${user.id.slice(0, 8)}`,
    avatar: user.avatarUrl,
  };
};

export const tencentIMUserService = {
  buildProfile(user: RaverUserForTencentIM): TencentIMUserProfile {
    return toTencentIMUserProfile(user);
  },

  async ensureUser(user: RaverUserForTencentIM): Promise<TencentIMUserProfile> {
    const profile = toTencentIMUserProfile(user);

    await tencentIMClient.post('v4/im_open_login_svc/account_import', {
      Identifier: profile.userID,
    });

    const profileItems = [
      {
        Tag: 'Tag_Profile_IM_Nick',
        Value: profile.nickname,
      },
      {
        Tag: 'Tag_Profile_IM_Image',
        Value: profile.avatar || '',
      },
    ];

    await tencentIMClient.post('v4/profile/portrait_set', {
      From_Account: profile.userID,
      ProfileItem: profileItems,
    });

    return profile;
  },

  async ensureUsersByIds(userIds: string[]): Promise<TencentIMUserProfile[]> {
    const normalized = Array.from(new Set(userIds.map((item) => item.trim()).filter((item) => item.length > 0)));
    if (normalized.length === 0) {
      return [];
    }

    const users = await prisma.user.findMany({
      where: {
        id: { in: normalized },
        isActive: true,
      },
      select: {
        id: true,
        username: true,
        displayName: true,
        avatarUrl: true,
      },
    });

    const byId = new Map(users.map((user) => [user.id, user]));
    const missing = normalized.filter((id) => !byId.has(id));
    if (missing.length > 0) {
      throw new Error(`Tencent IM user sync failed: user not found or inactive (${missing.join(', ')})`);
    }

    const profiles: TencentIMUserProfile[] = [];
    for (const userId of normalized) {
      const user = byId.get(userId);
      if (!user) {
        continue;
      }
      profiles.push(await this.ensureUser(user));
    }
    return profiles;
  },
};
