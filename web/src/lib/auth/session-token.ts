let accessToken: string | null = null;

export const authSessionToken = {
  get(): string | null {
    return accessToken;
  },

  set(nextToken: string | null): void {
    accessToken = nextToken;
  },

  clearLegacyStorage(): void {
    if (typeof window === 'undefined') return;
    localStorage.removeItem('token');
  },
};

export const requireAccessToken = (): string => {
  const token = authSessionToken.get();
  if (!token) {
    throw new Error('请先登录');
  }
  return token;
};
