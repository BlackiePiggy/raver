import { tencentIMConfig } from './tencent-im-config';

const TENCENT_IM_IDENTIFIER_PATTERN = /^[A-Za-z0-9_-]{1,32}$/;
type TLSSigAPIv2Module = {
  Api: new (sdkAppId: number, secretKey: string) => {
    genUserSig: (userID: string, expireSeconds: number) => string;
  };
};

const TLSSigAPIv2 = require('tls-sig-api-v2') as TLSSigAPIv2Module;

export const tencentIMUserSigService = {
  generate(identifier: string, expireSeconds = tencentIMConfig.userSigExpireSeconds): string {
    if (!tencentIMConfig.isConfigured) {
      throw new Error('Tencent IM is not fully configured');
    }

    if (!TENCENT_IM_IDENTIFIER_PATTERN.test(identifier)) {
      throw new Error(`Tencent IM userID is invalid: ${identifier}`);
    }

    const api = new TLSSigAPIv2.Api(tencentIMConfig.sdkAppId, tencentIMConfig.secretKey);
    return api.genUserSig(identifier, expireSeconds);
  },

  expiresAt(expireSeconds = tencentIMConfig.userSigExpireSeconds): string {
    return new Date(Date.now() + expireSeconds * 1000).toISOString();
  },
};
