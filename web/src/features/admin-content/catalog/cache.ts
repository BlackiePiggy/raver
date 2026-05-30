export type AdminCatalogCacheEnvelope<T> = {
  version: 1;
  fetchedAt: string;
  expiresAt: string;
  data: T;
};

export type AdminCatalogCacheReadResult<T> = {
  data: T;
  fetchedAt: string;
  expiresAt: string;
  isStale: boolean;
};

const STORAGE_PREFIX = 'raver-admin-catalog-cache';

const resolveStorageKey = (key: string): string => `${STORAGE_PREFIX}:${key}`;

export const buildAdminCatalogCacheKey = (
  scope: string,
  params: Record<string, string | number | boolean | null | undefined>
): string => {
  const search = new URLSearchParams();
  Object.entries(params)
    .filter(([, value]) => value !== undefined && value !== null && value !== '')
    .sort(([left], [right]) => left.localeCompare(right))
    .forEach(([key, value]) => {
      search.set(key, String(value));
    });

  const suffix = search.toString();
  return suffix ? `${scope}?${suffix}` : scope;
};

export const readAdminCatalogCache = <T>(key: string): AdminCatalogCacheReadResult<T> | null => {
  if (typeof window === 'undefined') return null;

  try {
    const raw = window.localStorage.getItem(resolveStorageKey(key));
    if (!raw) return null;
    const parsed = JSON.parse(raw) as AdminCatalogCacheEnvelope<T>;
    if (!parsed || parsed.version !== 1 || !parsed.fetchedAt || !parsed.expiresAt) {
      window.localStorage.removeItem(resolveStorageKey(key));
      return null;
    }

    return {
      data: parsed.data,
      fetchedAt: parsed.fetchedAt,
      expiresAt: parsed.expiresAt,
      isStale: Date.now() > Date.parse(parsed.expiresAt),
    };
  } catch {
    return null;
  }
};

export const writeAdminCatalogCache = <T>(key: string, data: T, ttlMs: number): AdminCatalogCacheReadResult<T> => {
  const fetchedAt = new Date().toISOString();
  const expiresAt = new Date(Date.now() + ttlMs).toISOString();
  const payload: AdminCatalogCacheEnvelope<T> = {
    version: 1,
    fetchedAt,
    expiresAt,
    data,
  };

  if (typeof window !== 'undefined') {
    try {
      window.localStorage.setItem(resolveStorageKey(key), JSON.stringify(payload));
    } catch {
      // ignore write failures so the catalog can still render from live data
    }
  }

  return {
    data,
    fetchedAt,
    expiresAt,
    isStale: false,
  };
};

export const clearAdminCatalogCache = (key: string): void => {
  if (typeof window === 'undefined') return;
  window.localStorage.removeItem(resolveStorageKey(key));
};
