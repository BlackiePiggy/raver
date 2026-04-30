declare module 'tls-sig-api-v2' {
  export class Api {
    constructor(sdkAppId: number, secretKey: string);
    genSig(userID: string, expireSeconds: number, userBuf?: Buffer | null): string;
    genUserSig(userID: string, expireSeconds: number): string;
  }

  const TLSSigAPIv2: {
    Api: typeof Api;
  };

  export default TLSSigAPIv2;
}
