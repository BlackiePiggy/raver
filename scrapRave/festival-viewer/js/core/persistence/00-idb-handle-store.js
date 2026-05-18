// ── FILE SYSTEM ACCESS API ──
function supportsFolderPersistence() {
  return !!window.indexedDB && typeof window.showDirectoryPicker === 'function';
}

function openHandleDb() {
  return new Promise((resolve, reject) => {
    if (!supportsFolderPersistence()) {
      reject(new Error('当前环境不支持目录句柄持久化'));
      return;
    }
    const req = indexedDB.open(HANDLE_DB_NAME, 1);
    req.onupgradeneeded = () => {
      const db = req.result;
      if (!db.objectStoreNames.contains(HANDLE_DB_STORE)) {
        db.createObjectStore(HANDLE_DB_STORE);
      }
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error || new Error('打开 IndexedDB 失败'));
  });
}

function dbGet(db, key) {
  return new Promise((resolve, reject) => {
    const tx = db.transaction(HANDLE_DB_STORE, 'readonly');
    const store = tx.objectStore(HANDLE_DB_STORE);
    const req = store.get(key);
    req.onsuccess = () => resolve(req.result ?? null);
    req.onerror = () => reject(req.error || new Error('读取失败'));
  });
}

function dbPut(db, key, value) {
  return new Promise((resolve, reject) => {
    const tx = db.transaction(HANDLE_DB_STORE, 'readwrite');
    const store = tx.objectStore(HANDLE_DB_STORE);
    const req = store.put(value, key);
    req.onsuccess = () => resolve();
    req.onerror = () => reject(req.error || new Error('写入失败'));
  });
}

function dbDelete(db, key) {
  return new Promise((resolve, reject) => {
    const tx = db.transaction(HANDLE_DB_STORE, 'readwrite');
    const store = tx.objectStore(HANDLE_DB_STORE);
    const req = store.delete(key);
    req.onsuccess = () => resolve();
    req.onerror = () => reject(req.error || new Error('删除失败'));
  });
}

async function saveRememberedRootHandle(handle) {
  if (!supportsFolderPersistence() || !handle) return;
  const db = await openHandleDb();
  try {
    await dbPut(db, HANDLE_DB_ROOT_KEY, handle);
    await dbPut(db, HANDLE_DB_META_KEY, {
      name: String(handle.name || '').trim(),
      savedAt: Date.now()
    });
  } finally {
    db.close();
  }
}

async function loadRememberedRootHandle() {
  if (!supportsFolderPersistence()) return { handle: null, meta: null };
  const db = await openHandleDb();
  try {
    const handle = await dbGet(db, HANDLE_DB_ROOT_KEY);
    const meta = await dbGet(db, HANDLE_DB_META_KEY);
    return { handle, meta };
  } finally {
    db.close();
  }
}

async function clearRememberedRootHandle() {
  if (!supportsFolderPersistence()) return;
  const db = await openHandleDb();
  try {
    await dbDelete(db, HANDLE_DB_ROOT_KEY);
    await dbDelete(db, HANDLE_DB_META_KEY);
  } finally {
    db.close();
  }
}

async function ensureDirPermission(handle, withWrite = true, request = false) {
  if (!handle) return false;
  const opts = withWrite ? { mode: 'readwrite' } : {};
  if (typeof handle.queryPermission === 'function') {
    const q = await handle.queryPermission(opts);
    if (q === 'granted') return true;
  }
  if (!request || typeof handle.requestPermission !== 'function') return false;
  return (await handle.requestPermission(opts)) === 'granted';
}
