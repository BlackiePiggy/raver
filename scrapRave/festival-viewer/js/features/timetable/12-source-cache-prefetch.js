// Feature module extracted from monolith (timetable source cache prefetch)
function ttCreateSourceGroupState(status, message, items = [], selectedIndex = -1, fetchedAt = 0) {
  const normalizedItems = Array.isArray(items)
    ? items
      .map((item) => ttCreateDisplayCandidate(item))
      .filter(Boolean)
      .slice(0, DJ_SOURCE_CACHE_MAX_ITEMS_PER_SOURCE)
    : [];
  const idx = normalizedItems.length ? Math.max(0, Math.min(Number(selectedIndex || 0), normalizedItems.length - 1)) : -1;
  return {
    status: String(status || 'idle'),
    message: String(message || ''),
    items: normalizedItems,
    selectedIndex: idx,
    fetchedAt: Number(fetchedAt || 0) || 0,
  };
}

function ttSourceAlreadyFetched(group, options = {}) {
  if (!group || typeof group !== 'object') return false;
  const st = String(group.status || '').trim().toLowerCase();
  if (Number(group.fetchedAt || 0) > 0) {
    if (st === 'err') return !!options.includeError;
    return true;
  }
  if (st === 'err') return !!options.includeError;
  return ['ok', 'empty'].includes(st);
}

function ttSourceTitle(sourceKey) {
  switch (String(sourceKey || '').trim()) {
    case 'spotify': return 'Spotify';
    case 'discogs': return 'Discogs';
    case 'soundcloud': return 'SoundCloud';
    default: return sourceKey;
  }
}

async function ttFetchImportCandidatesBySource(sourceKey, query, headers) {
  const normalized = String(sourceKey || '').trim().toLowerCase();
  if (normalized === 'spotify') return ttFetchSpotifyImportCandidates(query, headers);
  if (normalized === 'discogs') return ttFetchDiscogsImportCandidates(query, headers);
  if (normalized === 'soundcloud') return ttFetchSoundCloudImportCandidates(query, headers);
  throw new Error(`不支持的来源: ${sourceKey}`);
}

async function ttFetchImportCandidatesBySourceWithRetry(sourceKey, query, headers, options = {}) {
  const retryTimes = Math.max(0, Math.floor(Number(options.retryTimes ?? DJ_SOURCE_CACHE_RETRY_TIMES)));
  const retryIntervalMs = Math.max(0, Math.floor(Number(options.retryIntervalMs ?? DJ_SOURCE_CACHE_RETRY_INTERVAL_MS)));
  const retryOnEmpty = !!options.retryOnEmpty;
  let lastError = null;
  const maxAttempt = retryTimes + 1;
  for (let attempt = 1; attempt <= maxAttempt; attempt += 1) {
    try {
      const items = await ttFetchImportCandidatesBySource(sourceKey, query, headers);
      if (retryOnEmpty && (!Array.isArray(items) || items.length === 0) && attempt < maxAttempt) {
        await ttAppendSourceCacheLog({
          level: 'warn',
          action: 'source_fetch_retry_empty',
          query,
          source: sourceKey,
          message: `第 ${attempt}/${maxAttempt} 次返回空结果，${Math.floor(retryIntervalMs / 1000)}s 后重试`,
        }).catch(() => {});
        await ttSleep(retryIntervalMs);
        continue;
      }
      return { ok: true, items: Array.isArray(items) ? items : [], attempts: attempt };
    } catch (error) {
      lastError = error;
      await ttAppendSourceCacheLog({
        level: 'warn',
        action: 'source_fetch_retry',
        query,
        source: sourceKey,
        message: `第 ${attempt}/${maxAttempt} 次抓取失败：${String(error?.message || '未知错误')}`,
      }).catch(() => {});
      if (attempt < maxAttempt) {
        await ttSleep(retryIntervalMs);
      }
    }
  }
  return {
    ok: false,
    items: [],
    attempts: maxAttempt,
    errorMessage: String(lastError?.message || '抓取失败'),
  };
}

async function ttFetchAvatarBlobByProxy(remoteUrl) {
  const avatarUrl = String(remoteUrl || '').trim();
  if (!avatarUrl) throw new Error('头像链接为空');
  const candidates = ttGetAvatarDownloadCandidates(avatarUrl);
  let lastError = null;
  for (const candidateUrl of candidates) {
    const proxyUrl = `${getScraperApiBase()}/api/proxy-image?url=${encodeURIComponent(candidateUrl)}`;
    try {
      const resp = await fetch(proxyUrl);
      if (!resp.ok) {
        lastError = new Error(`status ${resp.status}`);
        continue;
      }
      const blob = await resp.blob();
      if (blob instanceof Blob && blob.size > 0) {
        return { blob, fromUrl: candidateUrl };
      }
      lastError = new Error('empty blob');
    } catch (error) {
      lastError = error;
    }
  }
  throw lastError || new Error('下载头像失败');
}

async function ttEnsureAvatarCached(remoteUrl, context = {}) {
  const urlKey = ttBuildAvatarCacheKey(remoteUrl);
  if (!urlKey) return { ok: false, reason: 'empty_url' };
  const existed = await ttGetAvatarCacheRecord(urlKey).catch(() => null);
  if (existed?.blob) return { ok: true, cached: true };
  try {
    const { blob } = await ttFetchAvatarBlobByProxy(urlKey);
    await ttPutAvatarCacheRecord(urlKey, blob, context);
    return { ok: true, cached: false };
  } catch (error) {
    await ttAppendSourceCacheLog({
      level: 'warn',
      action: 'avatar_cache',
      query: context?.query || '',
      source: context?.source || '',
      message: `头像缓存失败: ${String(error?.message || '未知错误')}`,
      detail: { url: urlKey },
    }).catch(() => {});
    return { ok: false, reason: String(error?.message || '头像缓存失败') };
  }
}

async function ttPrimeAvatarCacheForCandidates(items, context = {}) {
  const list = Array.isArray(items) ? items : [];
  const uniqueUrls = [];
  const seen = new Set();
  for (const item of list) {
    const url = String(item?.avatarUrl || '').trim();
    if (!url || seen.has(url)) continue;
    seen.add(url);
    uniqueUrls.push(url);
  }
  let cached = 0;
  let failed = 0;
  for (const url of uniqueUrls) {
    const result = await ttEnsureAvatarCached(url, context);
    if (result.ok) cached += 1;
    else failed += 1;
  }
  return { total: uniqueUrls.length, cached, failed };
}

async function ttDecorateCandidatesWithAvatarCache(items) {
  const list = Array.isArray(items) ? items : [];
  const out = [];
  for (const raw of list) {
    const next = ttCreateDisplayCandidate(raw);
    if (!next) continue;
    const avatarUrl = String(next.avatarUrl || '').trim();
    if (avatarUrl) {
      const cachedObjectUrl = await ttGetAvatarObjectUrlFromCache(avatarUrl).catch(() => '');
      if (cachedObjectUrl) next.avatarDisplayUrl = cachedObjectUrl;
    }
    out.push(next);
  }
  return out;
}

function ttBuildCacheMessage(group, fallback = '') {
  const fetchedAt = Number(group?.fetchedAt || 0);
  const count = Array.isArray(group?.items) ? group.items.length : 0;
  if (fetchedAt > 0) {
    const dt = new Date(fetchedAt);
    const timeText = Number.isFinite(dt.getTime()) ? dt.toLocaleString() : '';
    return `缓存 ${count} 条${timeText ? ` · ${timeText}` : ''}`;
  }
  if (group?.message) return String(group.message);
  return fallback || '未抓取';
}

async function ttApplySourceSnapshotToImportState(st, snapshot, enabledSources = null) {
  if (!st || !snapshot) return;
  const allowed = enabledSources && typeof enabledSources === 'object'
    ? enabledSources
    : { spotify: true, discogs: true, soundcloud: true };
  for (const sourceKey of ['spotify', 'discogs', 'soundcloud']) {
    if (!allowed[sourceKey]) continue;
    const group = snapshot[sourceKey];
    const items = await ttDecorateCandidatesWithAvatarCache(Array.isArray(group?.items) ? group.items : []);
    st.sources[sourceKey] = ttCreateSourceGroupState(
      String(group?.status || 'ok'),
      ttBuildCacheMessage(group, '缓存结果'),
      items,
      Number(group?.selectedIndex || 0),
      Number(group?.fetchedAt || 0)
    );
  }
}

function ttBuildCurrentSourceSnapshotForCache(st) {
  const out = {};
  for (const sourceKey of ['spotify', 'discogs', 'soundcloud']) {
    const group = st?.sources?.[sourceKey];
    const items = Array.isArray(group?.items)
      ? group.items.map((item) => {
          const cloned = ttCloneImportCandidate(item);
          if (cloned && Object.prototype.hasOwnProperty.call(cloned, 'avatarDisplayUrl')) {
            delete cloned.avatarDisplayUrl;
          }
          return cloned;
        }).filter(Boolean).slice(0, DJ_SOURCE_CACHE_MAX_ITEMS_PER_SOURCE)
      : [];
    out[sourceKey] = {
      status: String(group?.status || 'idle'),
      message: String(group?.message || ''),
      items,
      selectedIndex: items.length ? Math.max(0, Math.min(Number(group?.selectedIndex || 0), items.length - 1)) : -1,
      fetchedAt: Number(group?.fetchedAt || 0) || 0,
    };
  }
  return out;
}

function ttCollectUnmatchedTimetableDJNames() {
  const festivals = listAllFestivalsInLibrary();
  const namesByKey = new Map();
  for (const fest of festivals) {
    const lineup = Array.isArray(fest?.info?.lineup) ? fest.info.lineup : [];
    for (const slot of lineup) {
      const musician = String(slot?.musician || '').trim();
      if (!musician) continue;
      const splitPerformers = ttExtractCollaborativePerformers(musician);
      const names = splitPerformers.length >= 2 ? splitPerformers : [musician];
      for (const name of names) {
        const trimmed = String(name || '').trim();
        if (!trimmed) continue;
        if (ttFindMatchedDJByMusicianName(trimmed)?.id) continue;
        const key = ttNormalizeDJNameKey(trimmed);
        if (!key || namesByKey.has(key)) continue;
        namesByKey.set(key, trimmed);
      }
    }
  }
  return [...namesByKey.values()].sort((a, b) => a.localeCompare(b, 'en', { sensitivity: 'base' }));
}

async function ttPrefetchOneDJNameSources(query, headers) {
  const normalizedQuery = ttNormalizeSourceCacheQuery(query);
  if (!normalizedQuery) {
    return {
      status: 'skip',
      message: 'empty query',
      sourceCounts: { spotify: 0, discogs: 0, soundcloud: 0 },
      failedSources: [],
    };
  }
  const sourceKeys = ['spotify', 'discogs', 'soundcloud'];
  const loadedCache = await ttLoadSourceCacheSnapshot(query).catch(() => null);
  const baseSnapshot = ttCloneSourceSnapshot(loadedCache?.sources || {}) || {};
  let networkRequested = false;
  let sourceErrorCount = 0;

  for (const sourceKey of sourceKeys) {
    const existing = baseSnapshot[sourceKey];
    if (ttSourceAlreadyFetched(existing, { includeError: true })) continue;
    networkRequested = true;
    const fetchResult = await ttFetchImportCandidatesBySourceWithRetry(sourceKey, query, headers, {
      retryTimes: DJ_SOURCE_CACHE_RETRY_TIMES,
      retryIntervalMs: DJ_SOURCE_CACHE_RETRY_INTERVAL_MS,
      retryOnEmpty: true,
    });
    const fetchedAt = Date.now();
    if (fetchResult.ok) {
      const items = Array.isArray(fetchResult.items)
        ? fetchResult.items.slice(0, DJ_SOURCE_CACHE_MAX_ITEMS_PER_SOURCE)
        : [];
      baseSnapshot[sourceKey] = {
        status: 'ok',
        message: items.length ? `抓取 ${items.length} 条` : '无结果',
        items,
        selectedIndex: items.length ? 0 : -1,
        fetchedAt,
      };
      await ttPrimeAvatarCacheForCandidates(items, { query, source: sourceKey });
    } else {
      sourceErrorCount += 1;
      baseSnapshot[sourceKey] = {
        status: 'err',
        message: String(fetchResult.errorMessage || '抓取失败'),
        items: [],
        selectedIndex: -1,
        fetchedAt,
      };
      await ttAppendSourceCacheLog({
        level: 'error',
        action: 'prefetch_source_failed',
        query,
        source: sourceKey,
        message: String(fetchResult.errorMessage || '抓取失败'),
      }).catch(() => {});
    }
  }

  await ttSaveSourceCacheSnapshot(query, baseSnapshot);
  const sourceCounts = { spotify: 0, discogs: 0, soundcloud: 0 };
  const failedSources = [];
  for (const sourceKey of sourceKeys) {
    const group = baseSnapshot[sourceKey] || {};
    const status = String(group.status || 'idle');
    const items = Array.isArray(group.items) ? group.items : [];
    sourceCounts[sourceKey] = status === 'ok' ? items.length : 0;
    if (status === 'err') {
      failedSources.push({
        source: sourceKey,
        reason: String(group.message || '抓取失败'),
      });
    }
  }
  if (!networkRequested) {
    return {
      status: 'skip',
      message: 'all sources cached',
      sourceCounts,
      failedSources,
    };
  }
  if (sourceErrorCount > 0) {
    return {
      status: 'partial',
      message: `部分失败(${sourceErrorCount})`,
      sourceCounts,
      failedSources,
    };
  }
  return {
    status: 'ok',
    message: 'completed',
    sourceCounts,
    failedSources,
  };
}

function ttPrefetchSummaryText() {
  const st = ttDJSourceCacheState;
  const elapsedMs = st.startedAt > 0 ? Math.max(0, Date.now() - st.startedAt) : 0;
  const seconds = Math.floor(elapsedMs / 1000);
  return `总计 ${st.total}，已处理 ${st.processed}，成功 ${st.success}，部分失败 ${st.failed}，已缓存跳过 ${st.skipped}，耗时 ${seconds}s`;
}

async function ttRunDJSourcePrefetch() {
  if (ttDJSourceCacheState.running) return;
  const headers = getViewerAuthHeaders();
  if (!headers.Authorization) {
    ttSetDJPrefetchStatus('请先登录后再执行 DJ 预抓取任务。', 'err');
    openViewerLogin();
    return;
  }
  await ensureTtDJMatchMapLoaded();
  const missingNames = ttCollectUnmatchedTimetableDJNames();
  if (!missingNames.length) {
    ttSetDJPrefetchStatus('未发现未绑定的 DJ 名称，无需预抓取。', 'ok');
    return;
  }

  ttDJSourceCacheState.running = true;
  ttDJSourceCacheState.stopRequested = false;
  ttDJSourceCacheState.startedAt = Date.now();
  ttDJSourceCacheState.total = missingNames.length;
  ttDJSourceCacheState.processed = 0;
  ttDJSourceCacheState.success = 0;
  ttDJSourceCacheState.failed = 0;
  ttDJSourceCacheState.skipped = 0;
  ttSyncDJPrefetchButton();
  ttSetDJPrefetchStatus(`DJ 候选缓存任务启动：共 ${missingNames.length} 个未绑定 DJ。`);

  try {
    for (let i = 0; i < missingNames.length; i += 1) {
      if (ttDJSourceCacheState.stopRequested) break;
      const name = missingNames[i];
      ttSetDJPrefetchStatus(
        `处理中 ${i + 1}/${missingNames.length}：${name}（每个 DJ 间隔 ${Math.floor(DJ_SOURCE_CACHE_DJ_INTERVAL_MS / 1000)}s）`
      );
      const result = await ttPrefetchOneDJNameSources(name, headers);
      const sourceCounts = result?.sourceCounts || { spotify: 0, discogs: 0, soundcloud: 0 };
      const failedSources = Array.isArray(result?.failedSources) ? result.failedSources : [];
      const failedSourceText = failedSources.length
        ? failedSources
          .map((item) => `${ttSourceTitle(item?.source)}(${String(item?.reason || '失败')})`)
          .join(', ')
        : '无';
      await ttAppendSourceCacheLog({
        level: failedSources.length ? 'warn' : 'info',
        action: 'prefetch_dj_result',
        query: name,
        message: [
          `第 ${i + 1}/${missingNames.length} 个 DJ：${name}`,
          `Spotify=${Number(sourceCounts.spotify || 0)} 条`,
          `Discogs=${Number(sourceCounts.discogs || 0)} 条`,
          `SoundCloud=${Number(sourceCounts.soundcloud || 0)} 条`,
          `失败源：${failedSourceText}`,
        ].join(' | '),
        detail: {
          index: i + 1,
          total: missingNames.length,
          djName: name,
          status: String(result?.status || ''),
          sourceCounts: {
            spotify: Number(sourceCounts.spotify || 0),
            discogs: Number(sourceCounts.discogs || 0),
            soundcloud: Number(sourceCounts.soundcloud || 0),
          },
          failedSources,
        },
      }).catch(() => {});
      if (result.status === 'ok') ttDJSourceCacheState.success += 1;
      else if (result.status === 'skip') ttDJSourceCacheState.skipped += 1;
      else ttDJSourceCacheState.failed += 1;
      ttDJSourceCacheState.processed += 1;

      const isLast = i >= missingNames.length - 1;
      if (!isLast && !ttDJSourceCacheState.stopRequested) {
        await ttSleep(DJ_SOURCE_CACHE_DJ_INTERVAL_MS);
      }
    }
    const stopped = ttDJSourceCacheState.stopRequested;
    const suffix = stopped ? '（已手动停止）' : '（已完成）';
    ttSetDJPrefetchStatus(`DJ 候选缓存任务结束${suffix}：${ttPrefetchSummaryText()}`, stopped ? '' : 'ok');
  } catch (error) {
    await ttAppendSourceCacheLog({
      level: 'error',
      action: 'prefetch_fatal',
      message: String(error?.message || '未知错误'),
    }).catch(() => {});
    ttSetDJPrefetchStatus(`DJ 候选缓存任务异常终止：${String(error?.message || '未知错误')}`, 'err');
  } finally {
    ttDJSourceCacheState.running = false;
    ttDJSourceCacheState.stopRequested = false;
    ttSyncDJPrefetchButton();
  }
}

function ttToggleDJSourcePrefetch() {
  if (ttDJSourceCacheState.running) {
    ttDJSourceCacheState.stopRequested = true;
    ttSetDJPrefetchStatus(`正在停止 DJ 候选缓存任务... ${ttPrefetchSummaryText()}`);
    return;
  }
  void ttRunDJSourcePrefetch();
}

