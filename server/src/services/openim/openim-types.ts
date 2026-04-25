export interface OpenIMConfig {
  enabled: boolean;
  apiBaseUrl: string;
  wsUrl: string;
  clientApiBaseUrl: string;
  clientWsUrl: string;
  adminUserId: string;
  adminSecret: string;
  platformId: number;
  systemUserId: string;
  requestTimeoutMs: number;
  tolerateKickMaxSeqIssue: boolean;
  syncWorkerEnabled: boolean;
  syncWorkerIntervalMs: number;
  syncWorkerBatchSize: number;
  syncLockTimeoutMs: number;
  syncDefaultMaxAttempts: number;
  webhookSecret: string;
  webhookRequireSignature: boolean;
  webhookToleranceSeconds: number;
  webhookBlockSensitiveWords: boolean;
  webhookBlockImageHits: boolean;
  sensitiveWords: string[];
  sensitivePatterns: string[];
  imageModerationEnabled: boolean;
  imageModerationBlockKeywords: string[];
  imageModerationAllowedHosts: string[];
  imageModerationMaxUrls: number;
  paths: {
    getAdminToken: string;
    getUserToken: string;
    userRegister: string;
    updateUserInfo: string;
    createGroup: string;
    inviteUserToGroup: string;
    kickGroup: string;
    setGroupInfo: string;
    setGroupMemberInfo: string;
    transferGroup: string;
    dismissGroup: string;
    sendMessage: string;
    revokeMessage: string;
    deleteMessage: string;
  };
}

export interface OpenIMUserProfile {
  userID: string;
  nickname: string;
  faceURL?: string | null;
}

export interface OpenIMBootstrap {
  enabled: boolean;
  userID: string;
  token: string | null;
  apiURL: string;
  wsURL: string;
  platformID: number;
  systemUserID: string;
  expiresAt: string | null;
}

export interface OpenIMAdminTokenData {
  token: string;
  expireTimeSeconds?: number;
  expireTime?: number;
}

export interface OpenIMUserTokenData {
  token: string;
  expireTimeSeconds?: number;
  expireTime?: number;
}

export interface OpenIMApiResponse<T> {
  errCode?: number;
  errMsg?: string;
  data?: T;
}
