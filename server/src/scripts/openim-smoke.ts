import 'dotenv/config';
import { openIMConfig } from '../services/openim/openim-config';
import { openIMClient } from '../services/openim/openim-client';
import { openIMTokenService } from '../services/openim/openim-token.service';
import { openIMGroupService } from '../services/openim/openim-group.service';

const maskToken = (value: string): string => {
  if (value.length <= 12) {
    return `${value.slice(0, 3)}...`;
  }
  return `${value.slice(0, 6)}...${value.slice(-6)}`;
};

const readList = (value: string | undefined): string[] => {
  return (value || '')
    .split(',')
    .map((item) => item.trim())
    .filter((item) => item.length > 0);
};

const readBoolean = (value: string | undefined): boolean => {
  return ['1', 'true', 'yes', 'on'].includes((value || '').trim().toLowerCase());
};

const main = async (): Promise<void> => {
  console.log('[openim-smoke] config', {
    enabled: openIMConfig.enabled,
    apiBaseUrl: openIMConfig.apiBaseUrl,
    wsUrl: openIMConfig.wsUrl,
    platformId: openIMConfig.platformId,
    adminUserId: openIMConfig.adminUserId,
    tolerateKickMaxSeqIssue: openIMConfig.tolerateKickMaxSeqIssue,
    paths: openIMConfig.paths,
  });

  if (!openIMConfig.enabled) {
    console.log('[openim-smoke] skipped; set OPENIM_ENABLED=true to run OpenIM checks.');
    return;
  }

  const adminToken = await openIMClient.getAdminToken();
  console.log('[openim-smoke] admin token ok', maskToken(adminToken));

  const userId = (process.env.OPENIM_SMOKE_USER_ID || '').trim();
  if (userId) {
    const bootstrap = await openIMTokenService.bootstrapForUser(userId);
    console.log('[openim-smoke] user bootstrap ok', {
      userID: bootstrap.userID,
      token: bootstrap.token ? maskToken(bootstrap.token) : null,
      expiresAt: bootstrap.expiresAt,
    });
  } else {
    console.log('[openim-smoke] skipped user bootstrap; set OPENIM_SMOKE_USER_ID to test it.');
  }

  const shouldCreateGroup = readBoolean(process.env.OPENIM_SMOKE_CREATE_GROUP);
  if (!shouldCreateGroup) {
    console.log('[openim-smoke] skipped group creation; set OPENIM_SMOKE_CREATE_GROUP=true to test it.');
    return;
  }

  const ownerUserId = (process.env.OPENIM_SMOKE_GROUP_OWNER_ID || '').trim();
  const memberUserIds = readList(process.env.OPENIM_SMOKE_GROUP_MEMBER_IDS);
  const groupId = (process.env.OPENIM_SMOKE_GROUP_ID || '').trim() || `raver_smoke_${Date.now()}`;
  const allowKickKnownIssue = readBoolean(process.env.OPENIM_SMOKE_ALLOW_KICK_KNOWN_ISSUE);

  if (!ownerUserId || memberUserIds.length < 2) {
    throw new Error('Group smoke test requires OPENIM_SMOKE_GROUP_OWNER_ID and at least 2 OPENIM_SMOKE_GROUP_MEMBER_IDS.');
  }

  await openIMGroupService.createSquadGroup({
    squadId: groupId,
    name: `Raver Smoke ${new Date().toISOString()}`,
    ownerUserId,
    memberUserIds,
    description: 'Raver OpenIM smoke test group',
    verified: false,
  });

  console.log('[openim-smoke] group creation ok', {
    groupId,
    ownerUserId,
    memberUserIds,
  });

  const shouldSyncProfile = readBoolean(process.env.OPENIM_SMOKE_SYNC_GROUP_INFO);
  if (shouldSyncProfile) {
    const profileSuffix = Date.now();
    await openIMGroupService.syncSquadGroupProfile({
      squadId: groupId,
      name: `Raver Smoke ${profileSuffix}`,
      description: `Raver OpenIM smoke group profile sync ${profileSuffix}`,
      notice: `notice-${profileSuffix}`,
      isPublic: false,
      verified: false,
    });
    console.log('[openim-smoke] group profile sync ok', {
      groupId,
    });
  } else {
    console.log('[openim-smoke] skipped group profile sync; set OPENIM_SMOKE_SYNC_GROUP_INFO=true to test it.');
  }

  const promoteAdminUserId = (process.env.OPENIM_SMOKE_PROMOTE_ADMIN_USER_ID || '').trim();
  if (promoteAdminUserId) {
    await openIMGroupService.updateGroupMemberRole(groupId, promoteAdminUserId, 'admin');
    console.log('[openim-smoke] promote admin ok', {
      groupId,
      promoteAdminUserId,
    });
  } else {
    console.log('[openim-smoke] skipped admin promotion; set OPENIM_SMOKE_PROMOTE_ADMIN_USER_ID to test it.');
  }

  const transferGroupToUserId = (process.env.OPENIM_SMOKE_TRANSFER_GROUP_TO_USER_ID || '').trim();
  let currentOwnerUserId = ownerUserId;
  if (transferGroupToUserId) {
    await openIMGroupService.transferGroupOwner(groupId, currentOwnerUserId, transferGroupToUserId);
    currentOwnerUserId = transferGroupToUserId;
    console.log('[openim-smoke] transfer owner ok', {
      groupId,
      ownerUserId: currentOwnerUserId,
    });
  } else {
    console.log('[openim-smoke] skipped owner transfer; set OPENIM_SMOKE_TRANSFER_GROUP_TO_USER_ID to test it.');
  }

  const kickMemberUserIds = readList(process.env.OPENIM_SMOKE_KICK_GROUP_MEMBER_IDS);
  if (kickMemberUserIds.length > 0) {
    const kickResult = await openIMGroupService.removeGroupMembers(
      groupId,
      kickMemberUserIds,
      'openim smoke kick members',
      { tolerateKnownKickIssue: allowKickKnownIssue }
    );
    const eventName = kickResult.toleratedKnownIssue
      ? '[openim-smoke] kick members tolerated known issue'
      : '[openim-smoke] kick members ok';
    console.log(eventName, {
      groupId,
      kickedUserIds: kickMemberUserIds,
      currentOwnerUserId,
      allowKickKnownIssue,
    });
  } else {
    console.log('[openim-smoke] skipped kick members; set OPENIM_SMOKE_KICK_GROUP_MEMBER_IDS to test it.');
  }
};

main().catch((error) => {
  console.error('[openim-smoke] failed', error);
  process.exitCode = 1;
});
