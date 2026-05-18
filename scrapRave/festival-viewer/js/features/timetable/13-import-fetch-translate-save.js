// Feature module extracted from monolith (timetable import fetch translate save)
async function ttFetchSpotifyImportCandidates(query, headers) {
  const resp = await apiGet(`/api/raver/djs/spotify/search?q=${encodeURIComponent(query)}&limit=8`, headers);
  const items = Array.isArray(resp?.data?.items) ? resp.data.items : [];
  return items
    .map((item) => ttNormalizeImportCandidate('spotify', item))
    .slice(0, DJ_SOURCE_CACHE_MAX_ITEMS_PER_SOURCE);
}

async function ttFetchDiscogsImportCandidates(query, headers) {
  const resp = await apiGet(`/api/raver/djs/discogs/search?q=${encodeURIComponent(query)}&limit=8`, headers);
  const items = Array.isArray(resp?.data?.items) ? resp.data.items : [];
  const enriched = await Promise.all(items.map(async (item) => {
    const artistId = Number(item?.artistId);
    if (!Number.isFinite(artistId) || artistId <= 0) {
      return ttNormalizeImportCandidate('discogs', item);
    }
    try {
      const detailResp = await apiGet(`/api/raver/djs/discogs/artists/${encodeURIComponent(String(Math.floor(artistId)))}`, headers);
      const detail = detailResp?.data || null;
      return ttNormalizeImportCandidate('discogs', {
        ...item,
        ...(detail || {}),
        artistId,
      });
    } catch (_error) {
      return ttNormalizeImportCandidate('discogs', item);
    }
  }));
  return enriched.slice(0, DJ_SOURCE_CACHE_MAX_ITEMS_PER_SOURCE);
}

async function ttFetchSoundCloudImportCandidates(query, headers) {
  const resp = await apiGet(`/api/raver/djs/soundcloud/search?q=${encodeURIComponent(query)}&limit=20`, headers);
  const items = Array.isArray(resp?.data?.items) ? resp.data.items : [];
  const normalized = items.map((item) => ttNormalizeImportCandidate('soundcloud', item));
  normalized.sort((lhs, rhs) => {
    const leftFollowers = Number(lhs?.followersCount ?? lhs?.followers_count ?? 0);
    const rightFollowers = Number(rhs?.followersCount ?? rhs?.followers_count ?? 0);
    if (Number.isFinite(rightFollowers - leftFollowers) && rightFollowers !== leftFollowers) {
      return rightFollowers - leftFollowers;
    }
    return String(lhs?.name || '').localeCompare(String(rhs?.name || ''), 'en', { sensitivity: 'base' });
  });
  return normalized.slice(0, DJ_SOURCE_CACHE_MAX_ITEMS_PER_SOURCE);
}

async function ttFetchImportSourcesNoCache() {
  return ttFetchImportSources({ preferCache: false, forceRefresh: true });
}

async function ttFetchImportSources(options = {}) {
  const st = ttGetImportStateFromFacade();
  if (!st || st.saving) return;
  const preferCache = options?.preferCache !== false;
  const forceRefresh = !!options?.forceRefresh;
  const queryInput = document.getElementById('tt-dj-import-query');
  const query = String(queryInput?.value || '').trim();
  st.query = query;
  if (!query) {
    ttSetBindStatus('请先输入 DJ 名称再抓取。', 'err');
    return;
  }
  const headers = getViewerAuthHeaders();
  if (!headers.Authorization) {
    ttSetBindStatus('请先登录后再抓取多源数据。', 'err');
    openViewerLogin();
    return;
  }
  const sourceToggles = {
    spotify: !!document.getElementById('tt-dj-src-spotify')?.checked,
    discogs: !!document.getElementById('tt-dj-src-discogs')?.checked,
    soundcloud: !!document.getElementById('tt-dj-src-soundcloud')?.checked,
  };
  if (!sourceToggles.spotify && !sourceToggles.discogs && !sourceToggles.soundcloud) {
    ttSetBindStatus('请至少选择一个抓取渠道。', 'err');
    return;
  }
  st.sourceEnabled = sourceToggles;
  for (const key of ['spotify', 'discogs', 'soundcloud']) {
    if (!sourceToggles[key]) {
      st.sources[key] = ttCreateSourceGroupState('idle', '未启用', [], -1, 0);
      continue;
    }
    const existing = st.sources[key];
    st.sources[key] = ttCreateSourceGroupState(
      'loading',
      '抓取中...',
      Array.isArray(existing?.items) ? existing.items : [],
      Number(existing?.selectedIndex ?? -1),
      Number(existing?.fetchedAt || 0)
    );
  }
  ttRenderImportSourceGrid();
  ttSetBindStatus(preferCache && !forceRefresh ? '正在抓取多源信息...' : '正在实时抓取（忽略缓存）...', '');

  const pendingSources = new Set(
    ['spotify', 'discogs', 'soundcloud'].filter((sourceKey) => !!sourceToggles[sourceKey])
  );
  let loadedFromCache = false;

  if (preferCache && !forceRefresh) {
    const cached = await ttLoadSourceCacheSnapshot(query).catch(() => null);
    if (cached?.sources) {
      await ttApplySourceSnapshotToImportState(st, cached.sources, sourceToggles);
      loadedFromCache = true;
      for (const sourceKey of [...pendingSources]) {
        if (ttSourceAlreadyFetched(cached.sources[sourceKey])) pendingSources.delete(sourceKey);
      }
      ttNormalizeImportSelections();
      ttRenderImportSourceGrid();
      ttRenderImportCompareTable();
      ttRenderImportAvatarPreview();
      if (!pendingSources.size) {
        ttAutoPrefillImportDraftFromSources();
        ttSetBindStatus('已从本地缓存加载多源候选，可直接选择后入库。', 'ok');
        return;
      }
      ttSetBindStatus('已加载本地缓存，正在补抓缺失来源...', '');
    }
  }

  const tasks = [];
  const failedSources = [];
  for (const sourceKey of pendingSources) {
    tasks.push((async () => {
      const fetchedAt = Date.now();
      const result = await ttFetchImportCandidatesBySourceWithRetry(sourceKey, query, headers, {
        retryTimes: DJ_SOURCE_CACHE_RETRY_TIMES,
        retryIntervalMs: DJ_SOURCE_CACHE_RETRY_INTERVAL_MS,
        retryOnEmpty: true,
      });
      if (result.ok) {
        await ttPrimeAvatarCacheForCandidates(result.items, { query, source: sourceKey });
        const displayItems = await ttDecorateCandidatesWithAvatarCache(result.items);
        st.sources[sourceKey] = ttCreateSourceGroupState(
          'ok',
          displayItems.length ? `抓取 ${displayItems.length} 条` : '无结果',
          displayItems,
          displayItems.length ? 0 : -1,
          fetchedAt
        );
      } else {
        failedSources.push(sourceKey);
        st.sources[sourceKey] = ttCreateSourceGroupState(
          'err',
          String(result.errorMessage || '抓取失败'),
          [],
          -1,
          fetchedAt
        );
        await ttAppendSourceCacheLog({
          level: 'error',
          action: 'manual_fetch_source_failed',
          query,
          source: sourceKey,
          message: String(result.errorMessage || '抓取失败'),
        }).catch(() => {});
      }
    })());
  }

  await Promise.all(tasks);
  const savedSnapshot = await ttSaveSourceCacheSnapshot(
    query,
    ttBuildCurrentSourceSnapshotForCache(st)
  ).catch(() => null);
  if (savedSnapshot?.sources) {
    await ttApplySourceSnapshotToImportState(st, savedSnapshot.sources, sourceToggles);
  }
  ttAutoPrefillImportDraftFromSources();
  ttNormalizeImportSelections();
  ttRenderImportSourceGrid();
  ttRenderImportCompareTable();
  ttRenderImportAvatarPreview();
  if (failedSources.length) {
    ttSetBindStatus(
      `抓取完成（失败来源：${failedSources.map((key) => ttSourceTitle(key)).join(', ')}）。可直接使用已有结果。`,
      loadedFromCache ? '' : 'err'
    );
    return;
  }
  ttSetBindStatus(
    loadedFromCache ? '抓取完成，缓存与最新结果均已准备好。' : '抓取完成，可按字段选择来源后入库。',
    'ok'
  );
}

function ttSplitAliases(value) {
  return String(value || '')
    .split(/[\n,，、]/)
    .map((item) => item.trim())
    .filter(Boolean);
}

function ttSplitGenres(value) {
  return String(value || '')
    .split(/[\n,，、|;/]+/)
    .map((item) => item.trim())
    .filter(Boolean);
}

function ttBuildOptionalI18n(enValue, zhValue, fallbackEn = '') {
  const en = String(enValue || '').trim();
  const zh = String(zhValue || '').trim();
  const fallback = String(fallbackEn || '').trim();
  if (!en && !zh) return null;
  return {
    en: en || fallback,
    zh: zh || '',
  };
}

async function ttTranslateImportDraftBilingual() {
  const st = ttGetImportStateFromFacade();
  if (!st || st.saving || st.translating) return;

  const btn = document.getElementById('tt-dj-translate-btn');
  const manual = ttReadImportDraftFromForm();
  const country = String(ttResolveImportFieldValue('country') || manual.country || '').trim();
  const bio = String(ttResolveImportFieldValue('bio') || manual.bio || '').trim();
  if (!country && !bio) {
    ttSetBindStatus('country / bio 至少需要一个非空值才能双语化。', 'err');
    return;
  }

  st.translating = true;
  if (btn) btn.disabled = true;
  ttSetBindStatus('正在调用 Coze 生成双语 country/bio...', '');
  try {
    const authHeaders = getViewerAuthHeaders();
    const resp = await apiPost(
      '/api/coze/translate-dj-fields',
      { fields: { country, bio } },
      authHeaders
    );
    const translated = (resp && typeof resp.translated === 'object') ? resp.translated : {};
    const fieldsCn = (translated && typeof translated.fields_cn === 'object') ? translated.fields_cn : {};
    const fieldsEn = (translated && typeof translated.fields_en === 'object') ? translated.fields_en : {};

    const nextCountryEn = String(fieldsEn.country || '').trim();
    const nextCountryZh = String(fieldsCn.country || '').trim();
    const nextBioEn = String(fieldsEn.bio || '').trim();
    const nextBioZh = String(fieldsCn.bio || '').trim();

    const draft = ttReadImportDraftFromForm();
    if (!draft.country && country) draft.country = country;
    if (!draft.bio && bio) draft.bio = bio;
    draft.countryEn = nextCountryEn || draft.countryEn || draft.country || country;
    draft.countryZh = nextCountryZh || draft.countryZh;
    draft.bioEn = nextBioEn || draft.bioEn || draft.bio || bio;
    draft.bioZh = nextBioZh || draft.bioZh;
    ttWriteImportDraftToForm(draft);
    ttRenderImportCompareTable();
    ttRenderImportAvatarPreview();
    ttSetBindStatus('双语字段已生成并自动回填。', 'ok');
  } catch (error) {
    ttSetBindStatus(`双语化失败：${String(error?.message || '未知错误')}`, 'err');
  } finally {
    st.translating = false;
    if (btn) btn.disabled = false;
  }
}

function ttBuildFinalImportPayload() {
  const manual = ttReadImportDraftFromForm();
  const resolvedSpotifyId = String(ttResolveImportFieldValue('spotifyId') || '').trim();
  const spotifyIdFallback = [
    String(manual?.spotifyId || '').trim(),
    String(ttGetSelectedImportCandidate('spotify')?.spotifyId || '').trim(),
    ttExtractSpotifyArtistId(ttGetSelectedImportCandidate('spotify')?.spotifyUrl || ''),
    String(ttGetSelectedImportCandidate('soundcloud')?.spotifyId || '').trim(),
    ttExtractSpotifyArtistId(ttGetSelectedImportCandidate('soundcloud')?.spotifyUrl || ''),
    String(ttGetSelectedImportCandidate('discogs')?.spotifyId || '').trim(),
    ttExtractSpotifyArtistId(ttGetSelectedImportCandidate('discogs')?.spotifyUrl || ''),
  ].find((item) => String(item || '').trim()) || '';
  const payload = {
    name: String(ttResolveImportFieldValue('name') || '').trim(),
    aliases: ttSplitAliases(ttResolveImportFieldValue('aliases') || manual.aliases || ''),
    genres: ttSplitGenres(ttResolveImportFieldValue('genres') || manual.genres || ''),
    bio: String(ttResolveImportFieldValue('bio') || '').trim(),
    country: String(ttResolveImportFieldValue('country') || '').trim(),
    website: String(ttResolveImportFieldValue('website') || '').trim(),
    spotifyId: String(resolvedSpotifyId || spotifyIdFallback || '').trim(),
    spotifyFollowers: parseOptionalNonNegativeInt(ttResolveImportFieldValue('spotifyFollowers') || manual.spotifyFollowers || ''),
    instagramUrl: String(ttResolveImportFieldValue('instagramUrl') || '').trim(),
    facebookUrl: String(ttResolveImportFieldValue('facebookUrl') || '').trim(),
    soundcloudUrl: String(ttResolveImportFieldValue('soundcloudUrl') || '').trim(),
    soundcloudId: String(ttResolveImportFieldValue('soundcloudId') || '').trim(),
    trackCount: parseOptionalNonNegativeInt(ttResolveImportFieldValue('trackCount') || manual.trackCount || ''),
    playlistCount: parseOptionalNonNegativeInt(ttResolveImportFieldValue('playlistCount') || manual.playlistCount || ''),
    soundCloudFollowers: parseOptionalNonNegativeInt(
      ttResolveImportFieldValue('soundCloudFollowers') || manual.soundCloudFollowers || ''
    ),
    soundCloudFavorites: parseOptionalNonNegativeInt(
      ttResolveImportFieldValue('soundCloudFavorites') || manual.soundCloudFavorites || ''
    ),
    twitterUrl: String(ttResolveImportFieldValue('twitterUrl') || '').trim(),
    youtubeUrl: String(ttResolveImportFieldValue('youtubeUrl') || '').trim(),
    isVerified: !!manual.isVerified,
  };
  const countryI18n = ttBuildOptionalI18n(manual.countryEn, manual.countryZh, payload.country);
  const bioI18n = ttBuildOptionalI18n(manual.bioEn, manual.bioZh, payload.bio);
  if (countryI18n) payload.countryI18n = countryI18n;
  if (bioI18n) payload.bioI18n = bioI18n;
  return payload;
}

function ttGetPreferredAvatarCandidateUrl() {
  const st = ttGetImportStateFromFacade();
  const source = String(st?.avatarSource || '').trim();
  if (!['spotify', 'discogs', 'soundcloud'].includes(source)) return '';
  const displayUrl = ttGetImportAvatarDisplayUrlFromSource(source);
  if (displayUrl && /\/api\/dj-source-cache\/avatar\//i.test(displayUrl)) {
    return ttToAbsoluteLocalUrl(displayUrl);
  }
  return ttGetImportAvatarUrlFromSource(source);
}

function ttBuildSoundCloudAvatarVariantUrl(rawUrl, variant) {
  const base = String(rawUrl || '').trim();
  const targetVariant = String(variant || '').trim();
  if (!base || !targetVariant) return '';
  try {
    const parsed = new URL(base);
    const pathname = parsed.pathname || '';
    const replaced = pathname.replace(
      /-(?:tiny|small|large|t\d+x\d+|crop|original)\.(jpe?g|png|webp)$/i,
      `-${targetVariant}.$1`
    );
    if (!replaced || replaced === pathname) return '';
    parsed.pathname = replaced;
    return parsed.toString();
  } catch (_error) {
    return '';
  }
}

function ttGetAvatarDownloadCandidates(imageUrl) {
  const base = String(imageUrl || '').trim();
  if (!base) return [];
  const lower = base.toLowerCase();
  const isSoundCloudAvatar = lower.includes('sndcdn.com/avatars-');
  if (!isSoundCloudAvatar) return [base];

  const candidates = [
    ttBuildSoundCloudAvatarVariantUrl(base, 'original'),
    ttBuildSoundCloudAvatarVariantUrl(base, 't500x500'),
    base,
  ].filter(Boolean);
  return Array.from(new Set(candidates));
}

async function ttUploadDJAvatar(djId, file, headers) {
  const form = new FormData();
  form.append('djId', String(djId || ''));
  form.append('usage', 'avatar');
  form.append('image', file);
  await apiPostForm('/api/raver/djs/upload-image', form, headers);
}

async function ttUploadDJAvatarFromUrl(djId, imageUrl, headers) {
  const candidates = ttGetAvatarDownloadCandidates(imageUrl);
  for (const candidateUrl of candidates) {
    const record = await ttGetAvatarCacheRecord(candidateUrl).catch(() => null);
    let blob = null;
    if (record?.blob) {
      blob = record.blob;
    } else if (record?.localUrl) {
      const localResp = await fetch(ttToAbsoluteLocalUrl(record.localUrl)).catch(() => null);
      if (localResp?.ok) {
        blob = await localResp.blob().catch(() => null);
      }
    }
    if (!(blob instanceof Blob)) continue;
    const ext = (blob.type || '').includes('png') ? 'png' : (blob.type || '').includes('webp') ? 'webp' : 'jpg';
    const file = new File([blob], `import-avatar.${ext}`, { type: blob.type || 'image/jpeg' });
    await ttUploadDJAvatar(djId, file, headers);
    return;
  }

  let lastStatus = 0;
  for (const candidateUrl of candidates) {
    const proxyUrl = `${getScraperApiBase()}/api/proxy-image?url=${encodeURIComponent(candidateUrl)}`;
    const resp = await fetch(proxyUrl);
    if (!resp.ok) {
      lastStatus = resp.status;
      continue;
    }
    const blob = await resp.blob();
    await ttPutAvatarCacheRecord(candidateUrl, blob, { source: 'import_upload', query: '' }).catch(() => {});
    const ext = (blob.type || '').includes('png') ? 'png' : (blob.type || '').includes('webp') ? 'webp' : 'jpg';
    const file = new File([blob], `import-avatar.${ext}`, { type: blob.type || 'image/jpeg' });
    await ttUploadDJAvatar(djId, file, headers);
    return;
  }
  throw new Error(`下载来源头像失败 (${lastStatus || 'unknown'})`);
}

function ttUpsertDJItemInLibrary(dj) {
  if (!dj?.id) return;
  const id = String(dj.id);
  const idx = (djLibraryState.allItems || []).findIndex((item) => String(item?.id || '') === id);
  if (idx >= 0) {
    djLibraryState.allItems[idx] = { ...djLibraryState.allItems[idx], ...dj };
  } else {
    djLibraryState.allItems.push(dj);
  }
  ttRebuildDJMatchMapFromState();
  ttDjMatchLoaded = true;
}

async function ttConfirmImportAndBind() {
  const st = ttGetImportStateFromFacade();
  const isLibraryMode = ttIsLibraryImportMode();
  const bindState = ttGetTimetableBindStateFromFacade();
  const rid = String(bindState?.rid || '').trim();
  const slot = isLibraryMode ? null : ttGetDraftSlotByRid(rid);
  if (!st || st.saving || (!isLibraryMode && !slot)) return;
  const headers = getViewerAuthHeaders();
  if (!headers.Authorization) {
    ttSetBindStatus('请先登录后再入库。', 'err');
    openViewerLogin();
    return;
  }
  const payload = ttBuildFinalImportPayload();
  if (!payload.name) {
    ttSetBindStatus('名称不能为空，请填写或从来源字段中选择。', 'err');
    return;
  }

  st.saving = true;
  ttSetBindStatus(isLibraryMode ? '正在入库 DJ...' : '正在入库并绑定 DJ...', '');
  try {
    const importResp = await apiPost('/api/raver/djs/manual/import', payload, headers);
    const createdDJ = importResp?.data?.dj || null;
    if (!createdDJ?.id) {
      throw new Error('入库成功但未返回 DJ');
    }

    const avatarFile = document.getElementById('tt-dj-avatar-file')?.files?.[0] || null;
    const avatarSource = String(st.avatarSource || 'manual');
    if (avatarSource === 'manual' && avatarFile) {
      await ttUploadDJAvatar(createdDJ.id, avatarFile, headers);
    } else if (avatarSource !== 'manual') {
      const avatarFromSource = ttGetPreferredAvatarCandidateUrl();
      if (avatarFromSource) {
      await ttUploadDJAvatarFromUrl(createdDJ.id, avatarFromSource, headers);
      }
    }

    let finalDJ = createdDJ;
    try {
      const detailResp = await apiGet(`/api/raver/djs/${encodeURIComponent(createdDJ.id)}`, headers);
      finalDJ = detailResp?.data || createdDJ;
    } catch (_error) {
      finalDJ = createdDJ;
    }

    ttUpsertDJItemInLibrary(finalDJ);
    const importedCallback = (typeof bindState?.onImported === 'function') ? bindState.onImported : null;
    if (importedCallback) {
      await importedCallback(finalDJ);
    }
    if (isLibraryMode) {
      renderDJLibrary();
      setDJStatus(`已导入 DJ：${String(finalDJ?.name || finalDJ?.id || '未知')}`, false);
      ttSetBindStatus('已成功入库到 DJ 库。', 'ok');
    } else {
      ttBindSlotToDJ(slot, finalDJ);
      ttSetBindStatus('已入库并完成绑定。', 'ok');
    }
    closeTtDJBindModal();
  } catch (error) {
    ttSetBindStatus(`入库失败：${String(error?.message || '未知错误')}`, 'err');
  } finally {
    st.saving = false;
  }
}
