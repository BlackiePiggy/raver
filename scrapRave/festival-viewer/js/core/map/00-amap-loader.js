// Core map loader (AMap JSAPI v2)
let amapRuntimeConfigCache = null;
let amapRuntimeConfigPromise = null;
let amapLoadPromise = null;
let amapRuntimeConfigLastError = '';

function getAmapRuntimeConfigFromWindow() {
  const fromWindow = window.__RAVER_VIEWER_RUNTIME_CONFIG__;
  const amap = fromWindow && typeof fromWindow === 'object' ? fromWindow.amap : null;
  if (!amap || typeof amap !== 'object') return null;
  const jsApiKey = String(amap.jsApiKey || '').trim();
  const securityJsCode = String(amap.securityJsCode || '').trim();
  if (!jsApiKey) return null;
  return { jsApiKey, securityJsCode };
}

async function getAmapRuntimeConfig(force = false) {
  if (!force && amapRuntimeConfigCache) return amapRuntimeConfigCache;
  if (!force && amapRuntimeConfigPromise) return amapRuntimeConfigPromise;
  amapRuntimeConfigPromise = (async () => {
    const fallback = getAmapRuntimeConfigFromWindow();
    try {
      const resp = await apiGet('/api/viewer/runtime-config');
      const data = resp && typeof resp === 'object' ? (resp.data || {}) : {};
      const amap = data && typeof data === 'object' ? data.amap : null;
      const jsApiKey = String(amap?.jsApiKey || '').trim();
      const securityJsCode = String(amap?.securityJsCode || '').trim();
      if (!jsApiKey && fallback) {
        amapRuntimeConfigCache = fallback;
      } else {
        amapRuntimeConfigCache = { jsApiKey, securityJsCode };
      }
      amapRuntimeConfigLastError = '';
    } catch (error) {
      amapRuntimeConfigLastError = String(error?.message || '').trim();
      amapRuntimeConfigCache = fallback || { jsApiKey: '', securityJsCode: '' };
    } finally {
      amapRuntimeConfigPromise = null;
    }
    return amapRuntimeConfigCache;
  })();
  return amapRuntimeConfigPromise;
}

function applyAmapSecurityConfig(securityJsCode) {
  const code = String(securityJsCode || '').trim();
  if (!code) return;
  window._AMapSecurityConfig = { securityJsCode: code };
}

function loadAmapScriptByKey(jsApiKey) {
  const key = String(jsApiKey || '').trim();
  if (!key) throw new Error('未配置高德地图 API Key');
  if (window.AMap) return Promise.resolve(window.AMap);
  if (amapLoadPromise) return amapLoadPromise;
  amapLoadPromise = new Promise((resolve, reject) => {
    const existing = document.querySelector('script[data-amap-loader="1"]');
    if (existing) {
      existing.addEventListener('load', () => resolve(window.AMap), { once: true });
      existing.addEventListener('error', () => reject(new Error('高德地图脚本加载失败')), { once: true });
      return;
    }
    const script = document.createElement('script');
    script.src = `https://webapi.amap.com/maps?v=2.0&key=${encodeURIComponent(key)}`;
    script.async = true;
    script.defer = true;
    script.setAttribute('data-amap-loader', '1');
    script.onload = () => {
      if (!window.AMap) {
        reject(new Error('高德地图脚本已加载但 AMap 对象不存在'));
        return;
      }
      resolve(window.AMap);
    };
    script.onerror = () => reject(new Error('高德地图脚本加载失败'));
    document.head.appendChild(script);
  }).finally(() => {
    amapLoadPromise = null;
  });
  return amapLoadPromise;
}

async function ensureAmapLoaded() {
  if (window.AMap) return window.AMap;
  if (location.protocol === 'file:') {
    throw new Error(
      '检测到当前页面使用 file:// 打开。高德地图资源会被解析成 file://webapi.amap.com 导致加载失败。' +
      '请改用 http://127.0.0.1:8000/festival-viewer.html 打开页面。'
    );
  }
  const cfg = await getAmapRuntimeConfig(false);
  if (!cfg || !cfg.jsApiKey) {
    const runtimeBase = typeof getScraperApiBase === 'function' ? getScraperApiBase() : 'http://127.0.0.1:8000';
    const apiUrl = `${String(runtimeBase || '').replace(/\/+$/, '')}/api/viewer/runtime-config`;
    const detail = amapRuntimeConfigLastError ? `；原始错误：${amapRuntimeConfigLastError}` : '';
    throw new Error(
      `未获取到高德地图配置。请检查 ${apiUrl} 是否可访问且带有 CORS 头。` +
      '如果你是 file:// 打开页面，请确认 8000 端口运行的是当前项目的 web_tool/server.py。' +
      detail
    );
  }
  applyAmapSecurityConfig(cfg.securityJsCode);
  await loadAmapScriptByKey(cfg.jsApiKey);
  return window.AMap;
}

async function ensureAmapPlugins(plugins) {
  const list = Array.isArray(plugins) ? plugins.map((x) => String(x || '').trim()).filter(Boolean) : [];
  const AMap = await ensureAmapLoaded();
  if (!list.length) return AMap;
  await new Promise((resolve) => {
    AMap.plugin(list, () => resolve());
  });
  return AMap;
}
