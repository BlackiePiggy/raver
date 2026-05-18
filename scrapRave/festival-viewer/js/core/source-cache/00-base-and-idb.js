// Core module extracted from monolith (source cache common)
function ttSleep(ms) {
  const waitMs = Math.max(0, Number(ms) || 0);
  return new Promise((resolve) => setTimeout(resolve, waitMs));
}

function ttToAbsoluteLocalUrl(url) {
  const raw = String(url || '').trim();
  if (!raw) return '';
  if (/^(?:https?:|blob:|data:)/i.test(raw)) return raw;
  if (!raw.startsWith('/')) return raw;
  if (raw.startsWith('/uploads/')) {
    const bffBase = getRaverBffBase();
    return bffBase ? `${bffBase}${raw}` : raw;
  }
  const base = getScraperApiBase();
  return base ? `${base}${raw}` : raw;
}

function ttNormalizeSourceCacheQuery(query) {
  return String(query || '')
    .trim()
    .toLowerCase()
    .replace(/\s+/g, ' ');
}

function ttBuildSourceCacheKey(query) {
  const normalized = ttNormalizeSourceCacheQuery(query);
  return normalized ? `query:${normalized}` : '';
}

function ttBuildAvatarCacheKey(url) {
  return String(url || '').trim();
}

function ttSupportsIndexedDbCache() {
  return !!window.indexedDB;
}

function openDJSourceCacheDb() {
  return new Promise((resolve, reject) => {
    if (!ttSupportsIndexedDbCache()) {
      reject(new Error('当前环境不支持 IndexedDB 缓存'));
      return;
    }
    const req = indexedDB.open(DJ_SOURCE_CACHE_DB_NAME, DJ_SOURCE_CACHE_DB_VERSION);
    req.onupgradeneeded = () => {
      const db = req.result;
      if (!db.objectStoreNames.contains(DJ_SOURCE_CACHE_STORE_QUERY)) {
        db.createObjectStore(DJ_SOURCE_CACHE_STORE_QUERY, { keyPath: 'cacheKey' });
      }
      if (!db.objectStoreNames.contains(DJ_SOURCE_CACHE_STORE_AVATAR)) {
        db.createObjectStore(DJ_SOURCE_CACHE_STORE_AVATAR, { keyPath: 'urlKey' });
      }
      if (!db.objectStoreNames.contains(DJ_SOURCE_CACHE_STORE_LOG)) {
        db.createObjectStore(DJ_SOURCE_CACHE_STORE_LOG, { keyPath: 'id' });
      }
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error || new Error('打开 DJ 缓存数据库失败'));
  });
}

function idbStoreGet(db, storeName, key) {
  return new Promise((resolve, reject) => {
    const tx = db.transaction(storeName, 'readonly');
    const store = tx.objectStore(storeName);
    const req = store.get(key);
    req.onsuccess = () => resolve(req.result ?? null);
    req.onerror = () => reject(req.error || new Error(`读取缓存失败: ${storeName}`));
  });
}

function idbStorePut(db, storeName, value) {
  return new Promise((resolve, reject) => {
    const tx = db.transaction(storeName, 'readwrite');
    const store = tx.objectStore(storeName);
    const req = store.put(value);
    req.onsuccess = () => resolve();
    req.onerror = () => reject(req.error || new Error(`写入缓存失败: ${storeName}`));
  });
}

function idbStoreGetAll(db, storeName) {
  return new Promise((resolve, reject) => {
    const tx = db.transaction(storeName, 'readonly');
    const store = tx.objectStore(storeName);
    const req = store.getAll();
    req.onsuccess = () => resolve(Array.isArray(req.result) ? req.result : []);
    req.onerror = () => reject(req.error || new Error(`读取缓存列表失败: ${storeName}`));
  });
}

