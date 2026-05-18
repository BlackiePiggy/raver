// Core map loader (Geoapify + MapLibre GL)
let geoapifyRuntimeConfigCache = null;
let geoapifyRuntimeConfigPromise = null;
let geoapifyLoadPromise = null;
let geoapifyCssLoadPromise = null;
let geoapifyRuntimeConfigLastError = '';

function getGeoapifyRuntimeConfigFromWindow() {
  const fromWindow = window.__RAVER_VIEWER_RUNTIME_CONFIG__;
  const geoapify = fromWindow && typeof fromWindow === 'object' ? fromWindow.geoapify : null;
  if (!geoapify || typeof geoapify !== 'object') return null;
  const apiKey = String(geoapify.apiKey || geoapify.key || '').trim();
  if (!apiKey) return null;
  return { apiKey };
}

async function getGeoapifyRuntimeConfig(force = false) {
  if (!force && geoapifyRuntimeConfigCache) return geoapifyRuntimeConfigCache;
  if (!force && geoapifyRuntimeConfigPromise) return geoapifyRuntimeConfigPromise;
  geoapifyRuntimeConfigPromise = (async () => {
    const fallback = getGeoapifyRuntimeConfigFromWindow();
    try {
      const resp = await apiGet('/api/viewer/runtime-config');
      const data = resp && typeof resp === 'object' ? (resp.data || {}) : {};
      const geoapify = data && typeof data === 'object' ? data.geoapify : null;
      const apiKey = String(geoapify?.apiKey || geoapify?.key || '').trim();
      geoapifyRuntimeConfigCache = apiKey ? { apiKey } : (fallback || { apiKey: '' });
      geoapifyRuntimeConfigLastError = '';
    } catch (error) {
      geoapifyRuntimeConfigLastError = String(error?.message || '').trim();
      geoapifyRuntimeConfigCache = fallback || { apiKey: '' };
    } finally {
      geoapifyRuntimeConfigPromise = null;
    }
    return geoapifyRuntimeConfigCache;
  })();
  return geoapifyRuntimeConfigPromise;
}

function loadGeoapifyCss() {
  if (geoapifyCssLoadPromise) return geoapifyCssLoadPromise;
  const existing = document.querySelector('link[data-geoapify-loader-css="1"]');
  if (existing) return Promise.resolve();
  geoapifyCssLoadPromise = new Promise((resolve) => {
    const link = document.createElement('link');
    link.rel = 'stylesheet';
    link.href = 'https://unpkg.com/maplibre-gl@4.7.1/dist/maplibre-gl.css';
    link.setAttribute('data-geoapify-loader-css', '1');
    link.onload = () => resolve();
    link.onerror = () => resolve();
    document.head.appendChild(link);
  }).finally(() => {
    geoapifyCssLoadPromise = null;
  });
  return geoapifyCssLoadPromise;
}

function loadGeoapifyScript() {
  if (window.maplibregl && typeof window.maplibregl.Map === 'function') {
    return Promise.resolve(window.maplibregl);
  }
  if (geoapifyLoadPromise) return geoapifyLoadPromise;
  geoapifyLoadPromise = new Promise((resolve, reject) => {
    const existing = document.querySelector('script[data-geoapify-loader="1"]');
    if (existing) {
      existing.addEventListener('load', () => {
        if (!window.maplibregl || typeof window.maplibregl.Map !== 'function') {
          reject(new Error('MapLibre 脚本已加载但 maplibregl 对象不可用'));
          return;
        }
        resolve(window.maplibregl);
      }, { once: true });
      existing.addEventListener('error', () => reject(new Error('MapLibre 脚本加载失败')), { once: true });
      return;
    }
    const script = document.createElement('script');
    script.src = 'https://unpkg.com/maplibre-gl@4.7.1/dist/maplibre-gl.js';
    script.async = true;
    script.defer = true;
    script.setAttribute('data-geoapify-loader', '1');
    script.onload = () => {
      if (!window.maplibregl || typeof window.maplibregl.Map !== 'function') {
        reject(new Error('MapLibre 脚本已加载但 maplibregl 对象不可用'));
        return;
      }
      resolve(window.maplibregl);
    };
    script.onerror = () => reject(new Error('MapLibre 脚本加载失败'));
    document.head.appendChild(script);
  }).finally(() => {
    geoapifyLoadPromise = null;
  });
  return geoapifyLoadPromise;
}

async function ensureGeoapifyLoaded() {
  if (location.protocol === 'file:') {
    throw new Error(
      '检测到当前页面使用 file:// 打开。Geoapify 依赖网络安全上下文与统一源请求。' +
      '请改用 http://127.0.0.1:8000/festival-viewer.html 打开页面。'
    );
  }
  const cfg = await getGeoapifyRuntimeConfig(false);
  const apiKey = String(cfg?.apiKey || '').trim();
  if (!apiKey) {
    const runtimeBase = typeof getScraperApiBase === 'function' ? getScraperApiBase() : 'http://127.0.0.1:8000';
    const apiUrl = `${String(runtimeBase || '').replace(/\/+$/, '')}/api/viewer/runtime-config`;
    const detail = geoapifyRuntimeConfigLastError ? `；原始错误：${geoapifyRuntimeConfigLastError}` : '';
    throw new Error(`未获取到 Geoapify API Key。请检查 ${apiUrl} 与 .env.local（GEOAPIFY_API_KEY）${detail}`);
  }
  await loadGeoapifyCss();
  const maplibregl = await loadGeoapifyScript();
  return maplibregl;
}
