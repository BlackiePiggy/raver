function ttCloneImportCandidate(item) {
  if (!item || typeof item !== 'object') return null;
  return {
    ...item,
    aliases: Array.isArray(item.aliases) ? [...item.aliases] : [],
    genres: Array.isArray(item.genres) ? [...item.genres] : [],
  };
}

function ttCloneSourceSnapshot(snapshot) {
  if (!snapshot || typeof snapshot !== 'object') return null;
  const out = {};
  for (const sourceKey of ['spotify', 'discogs', 'soundcloud']) {
    const group = snapshot[sourceKey];
    const items = Array.isArray(group?.items)
      ? group.items
        .map((item) => {
          const cloned = ttCloneImportCandidate(item);
          if (!cloned) return null;
          const normalized = ttNormalizeImportCandidate(sourceKey, cloned);
          if (!normalized) return null;
          const avatarDisplayUrl = String(cloned.avatarDisplayUrl || '').trim();
          if (avatarDisplayUrl && !normalized.avatarDisplayUrl) {
            normalized.avatarDisplayUrl = avatarDisplayUrl;
          }
          return normalized;
        })
        .filter(Boolean)
      : [];
    out[sourceKey] = {
      status: String(group?.status || 'idle'),
      message: String(group?.message || '未抓取'),
      fetchedAt: Number(group?.fetchedAt || 0) || 0,
      items,
      selectedIndex: items.length ? Math.max(0, Math.min(Number(group?.selectedIndex || 0), items.length - 1)) : -1,
    };
  }
  return out;
}

async function ttLoadSourceCacheSnapshot(query) {
  const cacheKey = ttBuildSourceCacheKey(query);
  if (!cacheKey) return null;
  const headers = getViewerAuthHeaders();
  try {
    const resp = await apiGet(`/api/dj-source-cache/query?q=${encodeURIComponent(String(query || '').trim())}`, headers);
    const rec = resp?.cache;
    if (!rec || typeof rec !== 'object') return null;
    const sources = ttCloneSourceSnapshot(rec.sources);
    if (!sources) return null;
    return {
      query: String(rec.query || query || '').trim(),
      normalizedQuery: String(rec.normalizedQuery || ttNormalizeSourceCacheQuery(query)),
      updatedAt: Number(rec.updatedAt || 0) || 0,
      sources,
    };
  } catch (_error) {
    if (!ttSupportsIndexedDbCache()) return null;
    const db = await openDJSourceCacheDb();
    try {
      const rec = await idbStoreGet(db, DJ_SOURCE_CACHE_STORE_QUERY, cacheKey);
      if (!rec || typeof rec !== 'object') return null;
      const sources = ttCloneSourceSnapshot(rec.sources);
      if (!sources) return null;
      return {
        query: String(rec.query || query || '').trim(),
        normalizedQuery: String(rec.normalizedQuery || ttNormalizeSourceCacheQuery(query)),
        updatedAt: Number(rec.updatedAt || 0) || 0,
        sources,
      };
    } finally {
      db.close();
    }
  }
}

async function ttSaveSourceCacheSnapshot(query, sourcesSnapshot) {
  const cacheKey = ttBuildSourceCacheKey(query);
  if (!cacheKey) return null;
  const normalizedQuery = ttNormalizeSourceCacheQuery(query);
  const now = Date.now();
  const headers = getViewerAuthHeaders();
  try {
    const resp = await apiPost(
      '/api/dj-source-cache/query/save',
      {
        query: String(query || '').trim(),
        normalizedQuery,
        cacheKey,
        schemaVersion: DJ_SOURCE_CACHE_SCHEMA_VERSION,
        updatedAt: now,
        cacheAvatars: true,
        sources: ttCloneSourceSnapshot(sourcesSnapshot || {}),
      },
      headers
    );
    const rec = resp?.cache;
    if (!rec || typeof rec !== 'object') return null;
    const sources = ttCloneSourceSnapshot(rec.sources);
    if (!sources) return null;
    return {
      query: String(rec.query || query || '').trim(),
      normalizedQuery: String(rec.normalizedQuery || normalizedQuery),
      updatedAt: Number(rec.updatedAt || now) || now,
      sources,
    };
  } catch (_error) {
    if (!ttSupportsIndexedDbCache()) return null;
    const db = await openDJSourceCacheDb();
    try {
      await idbStorePut(db, DJ_SOURCE_CACHE_STORE_QUERY, {
        cacheKey,
        query: String(query || '').trim(),
        normalizedQuery,
        schemaVersion: DJ_SOURCE_CACHE_SCHEMA_VERSION,
        updatedAt: now,
        sources: ttCloneSourceSnapshot(sourcesSnapshot || {}),
      });
      return {
        query: String(query || '').trim(),
        normalizedQuery,
        updatedAt: now,
        sources: ttCloneSourceSnapshot(sourcesSnapshot || {}),
      };
    } finally {
      db.close();
    }
  }
}

async function ttAppendSourceCacheLog(payload) {
  const logPayload = payload && typeof payload === 'object' ? payload : {};
  const record = {
    id: `log-${Date.now()}-${Math.random().toString(36).slice(2, 9)}`,
    at: Date.now(),
    level: String(logPayload.level || 'warn'),
    action: String(logPayload.action || 'source_fetch'),
    query: String(logPayload.query || '').trim(),
    source: String(logPayload.source || '').trim(),
    message: String(logPayload.message || '').trim(),
    detail: logPayload.detail || null,
  };
  if (record.level === 'error' || record.level === 'warn') {
    console.warn('[dj-source-cache]', record);
  } else {
    console.log('[dj-source-cache]', record);
  }
  try {
    await apiPost('/api/dj-source-cache/log', record, getViewerAuthHeaders());
    return;
  } catch (_error) {
    if (!ttSupportsIndexedDbCache()) return;
    const db = await openDJSourceCacheDb();
    try {
      await idbStorePut(db, DJ_SOURCE_CACHE_STORE_LOG, record);
    } finally {
      db.close();
    }
  }
}

async function ttLoadRecentSourceCacheLogs(limit = 20) {
  const size = Math.max(1, Math.floor(Number(limit) || 20));
  try {
    const resp = await apiGet(`/api/dj-source-cache/logs?limit=${encodeURIComponent(String(size))}`, getViewerAuthHeaders());
    const logs = Array.isArray(resp?.logs) ? resp.logs : [];
    return logs;
  } catch (_error) {
    if (!ttSupportsIndexedDbCache()) return [];
    const db = await openDJSourceCacheDb();
    try {
      const all = await idbStoreGetAll(db, DJ_SOURCE_CACHE_STORE_LOG);
      return all
        .sort((a, b) => Number(b?.at || 0) - Number(a?.at || 0))
        .slice(0, size);
    } finally {
      db.close();
    }
  }
}

async function ttDumpSourceCacheLogs(limit = 30) {
  const rows = await ttLoadRecentSourceCacheLogs(limit);
  if (typeof console?.table === 'function') {
    console.table(rows.map((x) => ({
      at: x?.at ? new Date(x.at).toLocaleString() : '',
      level: x?.level || '',
      action: x?.action || '',
      source: x?.source || '',
      query: x?.query || '',
      message: x?.message || '',
    })));
  } else {
    console.log('[dj-source-cache] recent logs', rows);
  }
  return rows;
}

