export const isSafeInternalRedirectPath = (value: string | null | undefined): value is string => {
  if (!value) return false;
  return value.startsWith('/') && !value.startsWith('//');
};

export const resolveLoginRedirectPath = (
  value: string | null | undefined,
  fallback = '/'
): string => (isSafeInternalRedirectPath(value) ? value : fallback);

export const createLoginHref = (nextPath: string | null | undefined = '/'): string => {
  const safeNextPath = resolveLoginRedirectPath(nextPath);
  return `/login?next=${encodeURIComponent(safeNextPath)}`;
};
