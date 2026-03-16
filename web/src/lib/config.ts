// API配置
export const API_BASE_URL =
  typeof window !== 'undefined'
    ? 'http://localhost:3001/api' // 浏览器端
    : process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001/api'; // 服务端

export const getApiUrl = (path: string) => {
  const baseUrl = API_BASE_URL;
  return `${baseUrl}${path.startsWith('/') ? path : `/${path}`}`;
};