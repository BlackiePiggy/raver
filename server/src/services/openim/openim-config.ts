import type { OpenIMConfig } from './openim-types';

const cleanEnv = (value: string | undefined): string => {
  return (value || '').trim();
};

const parseBoolean = (value: string | undefined): boolean => {
  return ['1', 'true', 'yes', 'on'].includes(cleanEnv(value).toLowerCase());
};

const parseNumber = (value: string | undefined, fallback: number): number => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
};

const parseStringList = (value: string | undefined): string[] => {
  return cleanEnv(value)
    .split(',')
    .map((item) => item.trim().toLowerCase())
    .filter((item) => item.length > 0);
};

const parseRawStringList = (value: string | undefined): string[] => {
  return cleanEnv(value)
    .split(',')
    .map((item) => item.trim())
    .filter((item) => item.length > 0);
};

const webhookSecret = cleanEnv(process.env.OPENIM_WEBHOOK_SECRET);
const webhookRequireSignature = process.env.OPENIM_WEBHOOK_REQUIRE_SIGNATURE
  ? parseBoolean(process.env.OPENIM_WEBHOOK_REQUIRE_SIGNATURE)
  : webhookSecret.length > 0;

export const openIMConfig: OpenIMConfig = {
  enabled: parseBoolean(process.env.OPENIM_ENABLED),
  apiBaseUrl: cleanEnv(process.env.OPENIM_API_BASE_URL) || 'http://localhost:10002',
  wsUrl: cleanEnv(process.env.OPENIM_WS_URL) || 'ws://localhost:10001',
  clientApiBaseUrl:
    cleanEnv(process.env.OPENIM_CLIENT_API_BASE_URL)
    || cleanEnv(process.env.OPENIM_API_BASE_URL)
    || 'http://localhost:10002',
  clientWsUrl:
    cleanEnv(process.env.OPENIM_CLIENT_WS_URL)
    || cleanEnv(process.env.OPENIM_WS_URL)
    || 'ws://localhost:10001',
  adminUserId: cleanEnv(process.env.OPENIM_ADMIN_USER_ID) || 'imAdmin',
  adminSecret: cleanEnv(process.env.OPENIM_ADMIN_SECRET),
  platformId: parseNumber(process.env.OPENIM_PLATFORM_ID, 1),
  systemUserId: cleanEnv(process.env.OPENIM_SYSTEM_USER_ID) || 'raver_system',
  requestTimeoutMs: parseNumber(process.env.OPENIM_REQUEST_TIMEOUT_MS, 10000),
  tolerateKickMaxSeqIssue: parseBoolean(process.env.OPENIM_TOLERATE_KICK_MAXSEQ_ISSUE),
  syncWorkerEnabled: parseBoolean(process.env.OPENIM_SYNC_WORKER_ENABLED || 'true'),
  syncWorkerIntervalMs: parseNumber(process.env.OPENIM_SYNC_WORKER_INTERVAL_MS, 5000),
  syncWorkerBatchSize: parseNumber(process.env.OPENIM_SYNC_WORKER_BATCH_SIZE, 20),
  syncLockTimeoutMs: parseNumber(process.env.OPENIM_SYNC_LOCK_TIMEOUT_MS, 60000),
  syncDefaultMaxAttempts: parseNumber(process.env.OPENIM_SYNC_DEFAULT_MAX_ATTEMPTS, 5),
  webhookSecret,
  webhookRequireSignature,
  webhookToleranceSeconds: parseNumber(process.env.OPENIM_WEBHOOK_TOLERANCE_SECONDS, 300),
  webhookBlockSensitiveWords: parseBoolean(process.env.OPENIM_WEBHOOK_BLOCK_SENSITIVE_WORDS),
  webhookBlockImageHits: parseBoolean(process.env.OPENIM_WEBHOOK_BLOCK_IMAGE_HITS),
  sensitiveWords: parseStringList(process.env.OPENIM_SENSITIVE_WORDS),
  sensitivePatterns: parseRawStringList(process.env.OPENIM_SENSITIVE_PATTERNS),
  imageModerationEnabled: parseBoolean(process.env.OPENIM_IMAGE_MODERATION_ENABLED),
  imageModerationBlockKeywords: parseStringList(process.env.OPENIM_IMAGE_MODERATION_BLOCK_KEYWORDS),
  imageModerationAllowedHosts: parseStringList(process.env.OPENIM_IMAGE_MODERATION_ALLOWED_HOSTS),
  imageModerationMaxUrls: parseNumber(process.env.OPENIM_IMAGE_MODERATION_MAX_URLS, 10),
  paths: {
    getAdminToken: cleanEnv(process.env.OPENIM_PATH_GET_ADMIN_TOKEN) || '/auth/get_admin_token',
    getUserToken: cleanEnv(process.env.OPENIM_PATH_GET_USER_TOKEN) || '/auth/get_user_token',
    userRegister: cleanEnv(process.env.OPENIM_PATH_USER_REGISTER) || '/user/user_register',
    updateUserInfo: cleanEnv(process.env.OPENIM_PATH_UPDATE_USER_INFO) || '/user/update_user_info_ex',
    createGroup: cleanEnv(process.env.OPENIM_PATH_CREATE_GROUP) || '/group/create_group',
    inviteUserToGroup:
      cleanEnv(process.env.OPENIM_PATH_INVITE_USER_TO_GROUP) || '/group/invite_user_to_group',
    kickGroup: cleanEnv(process.env.OPENIM_PATH_KICK_GROUP) || '/group/kick_group',
    setGroupInfo: cleanEnv(process.env.OPENIM_PATH_SET_GROUP_INFO) || '/group/set_group_info_ex',
    setGroupMemberInfo:
      cleanEnv(process.env.OPENIM_PATH_SET_GROUP_MEMBER_INFO) || '/group/set_group_member_info',
    transferGroup: cleanEnv(process.env.OPENIM_PATH_TRANSFER_GROUP) || '/group/transfer_group',
    dismissGroup: cleanEnv(process.env.OPENIM_PATH_DISMISS_GROUP) || '/group/dismiss_group',
    sendMessage: cleanEnv(process.env.OPENIM_PATH_SEND_MESSAGE) || '/msg/send_msg',
    revokeMessage: cleanEnv(process.env.OPENIM_PATH_REVOKE_MESSAGE) || '/msg/revoke_msg',
    deleteMessage: cleanEnv(process.env.OPENIM_PATH_DELETE_MESSAGE) || '/msg/delete_msg',
  },
};
