import * as Keychain from 'react-native-keychain';

const tokenService = 'com.raver.rn.session';
const tokenAccount = 'session';

export type StoredSessionTokens = {
  accessToken: string;
  refreshToken?: string;
};

export async function saveSessionTokens(tokens: StoredSessionTokens): Promise<void> {
  await Keychain.setGenericPassword(tokenAccount, JSON.stringify(tokens), {
    accessible: Keychain.ACCESSIBLE.WHEN_UNLOCKED_THIS_DEVICE_ONLY,
    service: tokenService,
  });
}

export async function loadSessionTokens(): Promise<StoredSessionTokens | null> {
  const credentials = await Keychain.getGenericPassword({ service: tokenService });
  if (!credentials) {
    return null;
  }

  try {
    return JSON.parse(credentials.password) as StoredSessionTokens;
  } catch {
    await clearSessionTokens();
    return null;
  }
}

export async function clearSessionTokens(): Promise<void> {
  await Keychain.resetGenericPassword({ service: tokenService });
}
