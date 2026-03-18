// API配置
export const API_BASE_URL =
  typeof window !== 'undefined'
    ? '/api'
    : process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001/api';

export const getApiUrl = (path: string) => {
  const baseUrl = API_BASE_URL;
  return `${baseUrl}${path.startsWith('/') ? path : `/${path}`}`;
};

export const resolveMediaUrl = (url?: string | null): string => {
  if (!url) return '';
  if (url.startsWith('/uploads/')) return url;

  const marker = '/uploads/';
  const idx = url.indexOf(marker);
  if (idx >= 0) {
    return url.slice(idx);
  }

  return url;
};
