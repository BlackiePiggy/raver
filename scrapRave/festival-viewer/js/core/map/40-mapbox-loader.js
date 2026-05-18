// Core map loader (Mapbox GL JS)
let mapboxRuntimeConfigCache = null;
let mapboxRuntimeConfigPromise = null;
let mapboxLoadPromise = null;
let mapboxCssLoadPromise = null;
let mapboxRuntimeConfigLastError = '';

function getMapboxRuntimeConfigFromWindow() {
  const fromWindow = window.__RAVER_VIEWER_RUNTIME_CONFIG__;
  const mapbox = fromWindow && typeof fromWindow === 'object' ? fromWindow.mapbox : null;
  if (!mapbox || typeof mapbox !== 'object') return null;
  const accessToken = String(mapbox.accessToken || mapbox.token || '').trim();
  if (!accessToken) return null;
  return { accessToken };
}

async function getMapboxRuntimeConfig(force = false) {
  if (!force && mapboxRuntimeConfigCache) return mapboxRuntimeConfigCache;
  if (!force && mapboxRuntimeConfigPromise) return mapboxRuntimeConfigPromise;
  mapboxRuntimeConfigPromise = (async () => {
    const fallback = getMapboxRuntimeConfigFromWindow();
    try {
      const resp = await apiGet('/api/viewer/runtime-config');
      const data = resp && typeof resp === 'object' ? (resp.data || {}) : {};
      const mapbox = data && typeof data === 'object' ? data.mapbox : null;
      const accessToken = String(mapbox?.accessToken || mapbox?.token || '').trim();
      mapboxRuntimeConfigCache = accessToken ? { accessToken } : (fallback || { accessToken: '' });
      mapboxRuntimeConfigLastError = '';
    } catch (error) {
      mapboxRuntimeConfigLastError = String(error?.message || '').trim();
      mapboxRuntimeConfigCache = fallback || { accessToken: '' };
    } finally {
      mapboxRuntimeConfigPromise = null;
    }
    return mapboxRuntimeConfigCache;
  })();
  return mapboxRuntimeConfigPromise;
}

function loadMapboxCss() {
  if (mapboxCssLoadPromise) return mapboxCssLoadPromise;
  const existing = document.querySelector('link[data-mapbox-loader-css="1"]');
  if (existing) return Promise.resolve();
  mapboxCssLoadPromise = new Promise((resolve) => {
    const link = document.createElement('link');
    link.rel = 'stylesheet';
    link.href = 'https://api.mapbox.com/mapbox-gl-js/v3.4.0/mapbox-gl.css';
    link.setAttribute('data-mapbox-loader-css', '1');
    link.onload = () => resolve();
    link.onerror = () => resolve();
    document.head.appendChild(link);
  }).finally(() => {
    mapboxCssLoadPromise = null;
  });
  return mapboxCssLoadPromise;
}

function loadMapboxScriptByToken(accessToken) {
  const token = String(accessToken || '').trim();
  if (!token) throw new Error('未配置 Mapbox access token');
  if (window.mapboxgl && typeof window.mapboxgl.Map === 'function') {
    window.mapboxgl.accessToken = token;
    return Promise.resolve(window.mapboxgl);
  }
  if (mapboxLoadPromise) return mapboxLoadPromise;
  mapboxLoadPromise = new Promise((resolve, reject) => {
    const existing = document.querySelector('script[data-mapbox-loader="1"]');
    if (existing) {
      existing.addEventListener('load', () => {
        if (!window.mapboxgl) {
          reject(new Error('Mapbox 脚本已加载但 mapboxgl 对象不存在'));
          return;
        }
        window.mapboxgl.accessToken = token;
        resolve(window.mapboxgl);
      }, { once: true });
      existing.addEventListener('error', () => reject(new Error('Mapbox 脚本加载失败')), { once: true });
      return;
    }
    const script = document.createElement('script');
    script.src = 'https://api.mapbox.com/mapbox-gl-js/v3.4.0/mapbox-gl.js';
    script.async = true;
    script.defer = true;
    script.setAttribute('data-mapbox-loader', '1');
    script.onload = () => {
      if (!window.mapboxgl || typeof window.mapboxgl.Map !== 'function') {
        reject(new Error('Mapbox 脚本已加载但 mapboxgl 对象不可用'));
        return;
      }
      window.mapboxgl.accessToken = token;
      resolve(window.mapboxgl);
    };
    script.onerror = () => reject(new Error('Mapbox 脚本加载失败'));
    document.head.appendChild(script);
  }).finally(() => {
    mapboxLoadPromise = null;
  });
  return mapboxLoadPromise;
}

async function ensureMapboxLoaded() {
  if (location.protocol === 'file:') {
    throw new Error(
      '检测到当前页面使用 file:// 打开。Mapbox 依赖网络安全上下文与统一源请求。' +
      '请改用 http://127.0.0.1:8000/festival-viewer.html 打开页面。'
    );
  }
  const cfg = await getMapboxRuntimeConfig(false);
  const accessToken = String(cfg?.accessToken || '').trim();
  if (!accessToken) {
    const runtimeBase = typeof getScraperApiBase === 'function' ? getScraperApiBase() : 'http://127.0.0.1:8000';
    const apiUrl = `${String(runtimeBase || '').replace(/\/+$/, '')}/api/viewer/runtime-config`;
    const detail = mapboxRuntimeConfigLastError ? `；原始错误：${mapboxRuntimeConfigLastError}` : '';
    throw new Error(`未获取到 Mapbox Token。请检查 ${apiUrl} 与 .env.local（MAPBOX_ACCESS_TOKEN）${detail}`);
  }
  await loadMapboxCss();
  const mapboxgl = await loadMapboxScriptByToken(accessToken);
  mapboxgl.accessToken = accessToken;
  return mapboxgl;
}
