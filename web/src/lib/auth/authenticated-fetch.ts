import { authSessionToken } from './session-token';

const AUTH_EXPIRED_EVENT = 'raver-auth-expired';

const parseJsonSafe = async (response: Response): Promise<unknown> => {
  try {
    return await response.json();
  } catch {
    return null;
  }
};

const buildAuthHeaders = (headers?: HeadersInit): Headers => {
  const nextHeaders = new Headers(headers || {});
  const token = authSessionToken.get();
  if (token) {
    nextHeaders.set('Authorization', `Bearer ${token}`);
  }
  if (!nextHeaders.has('Content-Type')) {
    nextHeaders.set('Content-Type', 'application/json');
  }
  return nextHeaders;
};

const notifyAuthExpired = (): void => {
  authSessionToken.set(null);
  authSessionToken.clearLegacyStorage();
  if (typeof window !== 'undefined') {
    window.dispatchEvent(new Event(AUTH_EXPIRED_EVENT));
  }
};

const refreshAccessToken = async (): Promise<string | null> => {
  const response = await fetch('/v1/auth/refresh', {
    method: 'POST',
    credentials: 'include',
    headers: {
      'Content-Type': 'application/json',
      'x-raver-client-type': 'web_admin',
      'x-raver-platform': 'web',
    },
    body: JSON.stringify({ clientType: 'web_admin' }),
  });

  if (!response.ok) {
    notifyAuthExpired();
    return null;
  }

  const data = (await parseJsonSafe(response)) as { accessToken?: string; token?: string } | null;
  const nextToken = data?.accessToken || data?.token || null;
  if (!nextToken) {
    notifyAuthExpired();
    return null;
  }

  authSessionToken.set(nextToken);
  return nextToken;
};

export const authenticatedFetch = async (input: RequestInfo | URL, init?: RequestInit): Promise<Response> => {
  const attempt = async (): Promise<Response> =>
    fetch(input, {
      ...init,
      credentials: 'include',
      headers: buildAuthHeaders(init?.headers),
    });

  let response = await attempt();
  if (response.status !== 401) {
    return response;
  }

  const nextToken = await refreshAccessToken();
  if (!nextToken) {
    return response;
  }

  response = await attempt();
  if (response.status === 401) {
    notifyAuthExpired();
  }
  return response;
};

export const authenticatedJsonFetch = async <T>(input: RequestInfo | URL, init?: RequestInit): Promise<T> => {
  const response = await authenticatedFetch(input, init);
  if (!response.ok) {
    const error = (await parseJsonSafe(response)) as { error?: string; message?: string } | null;
    throw new Error(error?.error || error?.message || `Request failed (${response.status})`);
  }
  return response.json();
};

export { AUTH_EXPIRED_EVENT };
