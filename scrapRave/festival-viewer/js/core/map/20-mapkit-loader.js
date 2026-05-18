// Core map loader (Apple MapKit JS)
let mapkitRuntimeConfigCache = null;
let mapkitRuntimeConfigPromise = null;
let mapkitLoadPromise = null;
let mapkitRuntimeConfigLastError = '';
const MAPKIT_REQUIRED_LIBRARIES = ['map', 'annotations', 'services'];

function isMapkitLibraryReady(lib) {
  if (!window.mapkit) return false;
  const loaded = Array.isArray(window.mapkit.loadedLibraries) ? window.mapkit.loadedLibraries : [];
  return loaded.includes(String(lib || '').trim());
}

function areMapkitLibrariesReady(required = MAPKIT_REQUIRED_LIBRARIES) {
  if (!window.mapkit) return false;
  const list = Array.isArray(required) ? required : [];
  return list.every((lib) => isMapkitLibraryReady(lib));
}

function waitMapkitLibrariesReady(required = MAPKIT_REQUIRED_LIBRARIES, timeoutMs = 12000) {
  if (areMapkitLibrariesReady(required)) return Promise.resolve(window.mapkit);
  return new Promise((resolve, reject) => {
    const startedAt = Date.now();
    const tick = () => {
      if (areMapkitLibrariesReady(required)) {
        resolve(window.mapkit);
        return;
      }
      if ((Date.now() - startedAt) >= timeoutMs) {
        reject(new Error(`Apple MapKit 库加载超时，缺失: ${required.filter((lib) => !isMapkitLibraryReady(lib)).join(', ')}`));
        return;
      }
      setTimeout(tick, 80);
    };
    tick();
  });
}

function getMapkitRuntimeConfigFromWindow() {
  const fromWindow = window.__RAVER_VIEWER_RUNTIME_CONFIG__;
  const mapkit = fromWindow && typeof fromWindow === 'object' ? fromWindow.mapkit : null;
  if (!mapkit || typeof mapkit !== 'object') return null;
  const jsToken = String(mapkit.jsToken || '').trim();
  if (!jsToken) return null;
  return { jsToken };
}

async function getMapkitRuntimeConfig(force = false) {
  if (!force && mapkitRuntimeConfigCache) return mapkitRuntimeConfigCache;
  if (!force && mapkitRuntimeConfigPromise) return mapkitRuntimeConfigPromise;
  mapkitRuntimeConfigPromise = (async () => {
    const fallback = getMapkitRuntimeConfigFromWindow();
    try {
      const resp = await apiGet('/api/viewer/runtime-config');
      const data = resp && typeof resp === 'object' ? (resp.data || {}) : {};
      const mapkit = data && typeof data === 'object' ? data.mapkit : null;
      const jsToken = String(mapkit?.jsToken || '').trim();
      mapkitRuntimeConfigCache = jsToken ? { jsToken } : (fallback || { jsToken: '' });
      mapkitRuntimeConfigLastError = '';
    } catch (error) {
      mapkitRuntimeConfigLastError = String(error?.message || '').trim();
      mapkitRuntimeConfigCache = fallback || { jsToken: '' };
    } finally {
      mapkitRuntimeConfigPromise = null;
    }
    return mapkitRuntimeConfigCache;
  })();
  return mapkitRuntimeConfigPromise;
}

function loadMapkitScriptByToken(jsToken) {
  const token = String(jsToken || '').trim();
  if (!token) throw new Error('未配置 Apple MapKit Token');
  if (areMapkitLibrariesReady(MAPKIT_REQUIRED_LIBRARIES)) return Promise.resolve(window.mapkit);
  if (mapkitLoadPromise) return mapkitLoadPromise;
  mapkitLoadPromise = new Promise((resolve, reject) => {
    const existing = document.querySelector('script[data-mapkit-loader="1"]');
    const libsText = MAPKIT_REQUIRED_LIBRARIES.join(',');
    const callbackName = '__raverMapkitReadyCallback';
    let settled = false;
    const finish = (fn, value) => {
      if (settled) return;
      settled = true;
      fn(value);
    };
    const onReady = async () => {
      try {
        await waitMapkitLibrariesReady(MAPKIT_REQUIRED_LIBRARIES);
        finish(resolve, window.mapkit);
      } catch (error) {
        finish(reject, error);
      }
    };
    window[callbackName] = onReady;

    const ensureScriptMatches = (scriptEl) => {
      if (!scriptEl) return null;
      const hasRequiredLibs = String(scriptEl.getAttribute('data-libraries') || '')
        .split(',')
        .map((x) => String(x || '').trim())
        .filter(Boolean)
        .every((x) => MAPKIT_REQUIRED_LIBRARIES.includes(x)) && MAPKIT_REQUIRED_LIBRARIES.every((x) =>
          String(scriptEl.getAttribute('data-libraries') || '').includes(x)
        );
      const sameToken = String(scriptEl.getAttribute('data-token') || '').trim() === token;
      if (hasRequiredLibs && sameToken) return scriptEl;
      scriptEl.remove();
      return null;
    };

    const matched = ensureScriptMatches(existing);
    if (matched) {
      waitMapkitLibrariesReady(MAPKIT_REQUIRED_LIBRARIES)
        .then(() => finish(resolve, window.mapkit))
        .catch((error) => finish(reject, error));
      return;
    }

    const script = document.createElement('script');
    script.src = 'https://cdn.apple-mapkit.com/mk/5.x.x/mapkit.core.js';
    script.async = true;
    script.defer = true;
    script.crossOrigin = 'anonymous';
    script.setAttribute('data-callback', callbackName);
    script.setAttribute('data-libraries', libsText);
    script.setAttribute('data-token', token);
    script.setAttribute('data-mapkit-loader', '1');
    script.onload = () => {
      onReady();
    };
    script.onerror = () => finish(reject, new Error('Apple MapKit 脚本加载失败'));
    document.head.appendChild(script);
  }).finally(() => {
    mapkitLoadPromise = null;
    try { delete window.__raverMapkitReadyCallback; } catch (_error) {}
  });
  return mapkitLoadPromise;
}

async function ensureMapkitLoaded() {
  if (location.protocol === 'file:') {
    throw new Error(
      '检测到当前页面使用 file:// 打开。MapKit JS 依赖网络安全上下文与统一源请求。' +
      '请改用 http://127.0.0.1:8000/festival-viewer.html 打开页面。'
    );
  }
  const cfg = await getMapkitRuntimeConfig(false);
  const jsToken = String(cfg?.jsToken || '').trim();
  if (!jsToken) {
    const runtimeBase = typeof getScraperApiBase === 'function' ? getScraperApiBase() : 'http://127.0.0.1:8000';
    const apiUrl = `${String(runtimeBase || '').replace(/\/+$/, '')}/api/viewer/runtime-config`;
    const detail = mapkitRuntimeConfigLastError ? `；原始错误：${mapkitRuntimeConfigLastError}` : '';
    throw new Error(`未获取到 Apple MapKit Token。请检查 ${apiUrl} 与 .env.local（MAPKIT_JS_TOKEN）${detail}`);
  }
  const mapkit = await loadMapkitScriptByToken(jsToken);
  await waitMapkitLibrariesReady(MAPKIT_REQUIRED_LIBRARIES);
  return mapkit;
}
