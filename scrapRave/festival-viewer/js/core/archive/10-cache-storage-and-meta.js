function releaseFestivalImageObjectUrls(fest) {
  const images = Array.isArray(fest?.images) ? fest.images : [];
  for (const img of images) {
    const key = buildEventImageCacheKey(fest?.backendEventId, img?.filename);
    const localUrl = eventImageBlobObjectUrlMap.get(key);
    if (!localUrl || typeof localUrl !== 'string' || !localUrl.startsWith('blob:')) continue;
    try { URL.revokeObjectURL(localUrl); } catch (_error) {}
    eventImageBlobObjectUrlMap.delete(key);
  }
}

function releaseAllFestivalImageObjectUrls() {
  for (const yearData of Object.values(allData || {})) {
    for (const list of Object.values(yearData || {})) {
      for (const fest of (Array.isArray(list) ? list : [])) {
        releaseFestivalImageObjectUrls(fest);
      }
    }
  }
  eventImageBlobObjectUrlMap.clear();
  eventImageCacheMetaByEventId.clear();
}

function buildEventImageCacheKey(eventId, fileName) {
  const safeEventId = String(eventId || '').trim();
  const safeFileName = sanitizeEventImageFileName(String(fileName || '').trim(), '');
  return `${safeEventId}::${safeFileName}`;
}

function releaseEventImageBlobObjectUrl(eventId, fileName) {
  const key = buildEventImageCacheKey(eventId, fileName);
  const value = eventImageBlobObjectUrlMap.get(key);
  if (!value || typeof value !== 'string' || !value.startsWith('blob:')) {
    eventImageBlobObjectUrlMap.delete(key);
    return;
  }
  try { URL.revokeObjectURL(value); } catch (_error) {}
  eventImageBlobObjectUrlMap.delete(key);
}

async function getEventCacheRootHandle(create = false) {
  if (!rootDirHandle) return null;
  try {
    const top = await rootDirHandle.getDirectoryHandle(EVENT_IMAGE_CACHE_DIRNAME, { create });
    return await top.getDirectoryHandle(EVENT_IMAGE_CACHE_EVENTS_DIRNAME, { create });
  } catch (_error) {
    return null;
  }
}

async function getEventCacheEventDirHandle(eventId, create = false) {
  const root = await getEventCacheRootHandle(create);
  if (!root) return null;
  const safeEventId = normalizeEventCacheEventId(eventId);
  try {
    return await root.getDirectoryHandle(safeEventId, { create });
  } catch (_error) {
    return null;
  }
}

function normalizeEventCacheEventId(eventId) {
  return String(eventId || '').trim().replace(/[^a-zA-Z0-9-_]/g, '').slice(0, 80) || 'unknown-event';
}

async function removeEventCacheEventDir(eventId) {
  const root = await getEventCacheRootHandle(false);
  if (!root) return false;
  const safeEventId = normalizeEventCacheEventId(eventId);
  try {
    await root.removeEntry(safeEventId, { recursive: true });
  } catch (_error) {
    // ignore missing folder
  }
  eventImageCacheMetaByEventId.delete(String(eventId || '').trim());
  return true;
}

async function readEventCacheFile(eventId, fileName) {
  const dir = await getEventCacheEventDirHandle(eventId, false);
  if (!dir) return null;
  try {
    const handle = await dir.getFileHandle(fileName, { create: false });
    return await handle.getFile();
  } catch (_error) {
    return null;
  }
}

async function writeEventCacheFile(eventId, fileName, blob) {
  const dir = await getEventCacheEventDirHandle(eventId, true);
  if (!dir) return;
  const handle = await dir.getFileHandle(fileName, { create: true });
  const writable = await handle.createWritable();
  await writable.write(blob);
  await writable.close();
}

async function deleteEventCacheFile(eventId, fileName) {
  const dir = await getEventCacheEventDirHandle(eventId, false);
  if (!dir) return false;
  try {
    await dir.removeEntry(fileName);
    return true;
  } catch (_error) {
    return false;
  }
}

function normalizeEventCacheMeta(raw) {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return {};
  const out = {};
  for (const [k, v] of Object.entries(raw)) {
    const key = sanitizeEventImageFileName(String(k || '').trim(), '');
    const url = String(v || '').trim();
    if (!key || !url) continue;
    out[key] = url;
  }
  return out;
}

async function readEventCacheMeta(eventId) {
  const eventKey = String(eventId || '').trim();
  if (!eventKey) return {};
  if (eventImageCacheMetaByEventId.has(eventKey)) {
    return { ...(eventImageCacheMetaByEventId.get(eventKey) || {}) };
  }
  const dir = await getEventCacheEventDirHandle(eventKey, false);
  if (!dir) {
    eventImageCacheMetaByEventId.set(eventKey, {});
    return {};
  }
  try {
    const handle = await dir.getFileHandle(EVENT_IMAGE_CACHE_META_FILENAME, { create: false });
    const file = await handle.getFile();
    const text = await file.text();
    const parsed = normalizeEventCacheMeta(JSON.parse(text || '{}'));
    eventImageCacheMetaByEventId.set(eventKey, parsed);
    return { ...parsed };
  } catch (_error) {
    eventImageCacheMetaByEventId.set(eventKey, {});
    return {};
  }
}

async function writeEventCacheMeta(eventId, meta) {
  const eventKey = String(eventId || '').trim();
  if (!eventKey) return;
  const normalized = normalizeEventCacheMeta(meta);
  eventImageCacheMetaByEventId.set(eventKey, normalized);
  const dir = await getEventCacheEventDirHandle(eventKey, true);
  if (!dir) return;
  const handle = await dir.getFileHandle(EVENT_IMAGE_CACHE_META_FILENAME, { create: true });
  const writable = await handle.createWritable();
  await writable.write(JSON.stringify(normalized, null, 2));
  await writable.close();
}

async function upsertEventCacheMetaEntry(eventId, fileName, remoteUrl) {
  const safeName = sanitizeEventImageFileName(fileName || '', '');
  const safeUrl = String(remoteUrl || '').trim();
  if (!safeName || !safeUrl) return;
  const meta = await readEventCacheMeta(eventId);
  if (meta[safeName] === safeUrl) return;
  meta[safeName] = safeUrl;
  await writeEventCacheMeta(eventId, meta);
}

async function removeEventCacheMetaEntry(eventId, fileName) {
  const safeName = sanitizeEventImageFileName(fileName || '', '');
  if (!safeName) return;
  const meta = await readEventCacheMeta(eventId);
  if (!Object.prototype.hasOwnProperty.call(meta, safeName)) return;
  delete meta[safeName];
  await writeEventCacheMeta(eventId, meta);
}

async function reconcileFestivalEventImageCache(fest) {
  if (!fest?.backendEventId) return;
  const eventId = String(fest.backendEventId).trim();
  if (!eventId) return;
  const expected = {};
  const images = Array.isArray(fest.images) ? fest.images : [];
  for (const img of images) {
    const remoteUrl = String(img?.remoteUrl || img?.url || '').trim();
    if (!remoteUrl) continue;
    const safeName = sanitizeEventImageFileName(
      img?.filename || pathBaseNameFromUrl(remoteUrl) || `image${guessImageExtFromNameOrUrl(remoteUrl)}`
    );
    if (!safeName) continue;
    expected[safeName] = remoteUrl;
  }

  const dir = await getEventCacheEventDirHandle(eventId, false);
  const nextMeta = await readEventCacheMeta(eventId);
  if (dir) {
    for await (const [entryName, entryHandle] of dir.entries()) {
      if (entryHandle.kind !== 'file') continue;
      if (entryName === EVENT_IMAGE_CACHE_META_FILENAME || entryName === DEFAULT_INFO_FILENAME) continue;
      if (Object.prototype.hasOwnProperty.call(expected, entryName)) continue;
      await deleteEventCacheFile(eventId, entryName);
      releaseEventImageBlobObjectUrl(eventId, entryName);
      delete nextMeta[entryName];
    }
  }

  let metaChanged = false;
  for (const [safeName, remoteUrl] of Object.entries(expected)) {
    if (nextMeta[safeName] === remoteUrl) continue;
    nextMeta[safeName] = remoteUrl;
    metaChanged = true;
  }
  for (const key of Object.keys(nextMeta)) {
    if (Object.prototype.hasOwnProperty.call(expected, key)) continue;
    delete nextMeta[key];
    metaChanged = true;
  }
  if (metaChanged) {
    await writeEventCacheMeta(eventId, nextMeta);
  }
}

async function fetchImageBlobFromRemote(url) {
  const remoteUrl = String(url || '').trim();
  if (!remoteUrl) throw new Error('远程图片 URL 为空');
  const resolvedUrl = ttToAbsoluteLocalUrl(remoteUrl);
  const proxyUrl = `${getScraperApiBase()}/api/proxy-image?url=${encodeURIComponent(resolvedUrl)}`;
  const resp = await fetch(proxyUrl);
  if (!resp.ok) throw new Error(`下载远程图片失败 (${resp.status})`);
  return await resp.blob();
}

async function ensureEventImageCachedObjectUrl(eventId, fileName, remoteUrl) {
  const safeRemoteUrl = String(remoteUrl || '').trim();
  const safeName = sanitizeEventImageFileName(
    fileName || pathBaseNameFromUrl(safeRemoteUrl) || `image${guessImageExtFromNameOrUrl(safeRemoteUrl)}`
  );
  if (!safeName || !safeRemoteUrl) return '';
  const cacheKey = buildEventImageCacheKey(eventId, safeName);
  const meta = await readEventCacheMeta(eventId);
  const previousRemote = String(meta[safeName] || '').trim();
  const existing = eventImageBlobObjectUrlMap.get(cacheKey);
  if (existing && previousRemote && previousRemote === safeRemoteUrl) {
    return existing;
  }

  if (previousRemote && previousRemote !== safeRemoteUrl) {
    await deleteEventCacheFile(eventId, safeName);
    await removeEventCacheMetaEntry(eventId, safeName);
    releaseEventImageBlobObjectUrl(eventId, safeName);
  }
  let file = await readEventCacheFile(eventId, safeName);
  if (!file) {
    const blob = await fetchImageBlobFromRemote(safeRemoteUrl);
    await writeEventCacheFile(eventId, safeName, blob);
    file = await readEventCacheFile(eventId, safeName);
  }
  if (!file) return '';
  await upsertEventCacheMetaEntry(eventId, safeName, safeRemoteUrl);
  releaseEventImageBlobObjectUrl(eventId, safeName);
  const objectUrl = URL.createObjectURL(file);
  eventImageBlobObjectUrlMap.set(cacheKey, objectUrl);
  return objectUrl;
}

