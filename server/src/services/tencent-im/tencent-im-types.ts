export type TencentIMGroupType = 'Public' | 'Private' | 'ChatRoom' | 'AVChatRoom' | 'Community' | 'Meeting';

export interface TencentIMConfig {
  enabled: boolean;
  isConfigured: boolean;
  sdkAppId: number;
  secretKey: string;
  adminIdentifier: string;
  apiBaseUrl: string;
  region: string;
  requestTimeoutMs: number;
  userSigExpireSeconds: number;
  callbackSecret: string;
}

export interface TencentIMBootstrap {
  enabled: boolean;
  sdkAppID: number;
  userID: string;
  userSig: string | null;
  expiresAt: string | null;
  region: string;
  adminIdentifier: string;
}

export interface TencentIMUserProfile {
  userID: string;
  nickname: string;
  avatar?: string | null;
}

export interface TencentIMSquadGroupProfile {
  groupID: string;
  ownerUserID: string;
  memberUserIDs: string[];
  type: TencentIMGroupType;
  name: string;
  introduction?: string | null;
  notification?: string | null;
}

export interface TencentIMEventGroupProfile {
  groupID: string;
  ownerUserID: string;
  type: TencentIMGroupType;
  name: string;
  introduction?: string | null;
}
