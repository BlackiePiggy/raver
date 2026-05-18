async function ttGetAvatarCacheRecord(url) {
  const urlKey = ttBuildAvatarCacheKey(url);
  if (!urlKey) return null;
  try {
    const resp = await apiGet(
      `/api/dj-source-cache/avatar/resolve?url=${encodeURIComponent(urlKey)}`,
      getViewerAuthHeaders()
    );
    const localUrl = ttToAbsoluteLocalUrl(resp?.localUrl || '');
    if (localUrl) return { urlKey, localUrl };
  } catch (_error) {
    // fallback to local indexeddb below
  }
  if (!ttSupportsIndexedDbCache()) return null;
  const db = await openDJSourceCacheDb();
  try {
    const rec = await idbStoreGet(db, DJ_SOURCE_CACHE_STORE_AVATAR, urlKey);
    if (!rec || !(rec.blob instanceof Blob)) return null;
    return rec;
  } finally {
    db.close();
  }
}

async function ttPutAvatarCacheRecord(url, blob, meta = {}) {
  const urlKey = ttBuildAvatarCacheKey(url);
  if (!urlKey || !(blob instanceof Blob) || !ttSupportsIndexedDbCache()) return;
  const db = await openDJSourceCacheDb();
  try {
    await idbStorePut(db, DJ_SOURCE_CACHE_STORE_AVATAR, {
      urlKey,
      sourceUrl: urlKey,
      blob,
      contentType: String(blob.type || meta.contentType || ''),
      fetchedAt: Date.now(),
      source: String(meta.source || '').trim(),
      query: String(meta.query || '').trim(),
    });
  } finally {
    db.close();
  }
}

async function ttGetAvatarObjectUrlFromCache(url) {
  const key = ttBuildAvatarCacheKey(url);
  if (!key) return '';
  if (ttAvatarBlobObjectUrlMap.has(key)) {
    return String(ttAvatarBlobObjectUrlMap.get(key) || '');
  }
  const record = await ttGetAvatarCacheRecord(key);
  if (record?.localUrl) {
    const resolved = ttToAbsoluteLocalUrl(record.localUrl);
    ttAvatarBlobObjectUrlMap.set(key, resolved);
    return resolved;
  }
  if (!record?.blob) return '';
  const objectUrl = URL.createObjectURL(record.blob);
  ttAvatarBlobObjectUrlMap.set(key, objectUrl);
  return objectUrl;
}

function ttCreateDisplayCandidate(item) {
  const cloned = ttCloneImportCandidate(item);
  if (!cloned) return null;
  cloned.avatarDisplayUrl = ttToAbsoluteLocalUrl(
    String(cloned.avatarDisplayUrl || cloned.avatarUrl || '').trim()
  );
  return cloned;
}

