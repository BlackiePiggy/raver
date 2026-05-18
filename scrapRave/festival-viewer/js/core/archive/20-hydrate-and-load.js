async function hydrateFestivalImageCacheForRow(fest, row) {
  if (!fest || !row || !rootDirHandle) return;
  if (!fest.backendEventId) return;
  if (fest.cacheHydrating) return;
  fest.cacheHydrating = true;
  try {
    if (!fest.cacheReconciled) {
      await reconcileFestivalEventImageCache(fest);
      fest.cacheReconciled = true;
    }
    const images = Array.isArray(fest.images) ? fest.images : [];
    for (let idx = 0; idx < images.length; idx += 1) {
      const img = images[idx];
      const remoteUrl = String(img?.remoteUrl || img?.url || '').trim();
      if (!remoteUrl) continue;
      const domImg = row.querySelector(`img[data-img-idx="${idx}"]`);
      const localObjectUrl = await ensureEventImageCachedObjectUrl(fest.backendEventId, img.filename, remoteUrl);
      if (localObjectUrl) {
        img.url = localObjectUrl;
        img.cacheHydrated = true;
        if (domImg && domImg.src !== localObjectUrl) {
          domImg.src = localObjectUrl;
        }
        continue;
      }
      const fallbackUrl = ttToAbsoluteLocalUrl(remoteUrl);
      img.url = fallbackUrl;
      img.cacheHydrated = false;
      if (domImg && domImg.src !== fallbackUrl) {
        domImg.src = fallbackUrl;
      }
    }
    fest.cacheHydrated = true;
  } catch (_error) {
    // keep remote urls as fallback
  } finally {
    fest.cacheHydrating = false;
  }
}

async function loadArchiveEventsFromBackend(options = {}) {
  const preserveView = !!options.preserveView;
  const prevView = preserveView ? {
    year: activeYear,
    months: [...activeMonths],
    searchText: (document.getElementById('search-input')?.value || ''),
    globalSearchText: (document.getElementById('global-search-input')?.value || ''),
    countryFilterKeys: [...activeCountryFilterKeys],
    eventTypeFilterKeys: [...activeEventTypeFilterKeys],
  } : (options.prevView || null);

  document.getElementById('pick-zone').style.display = 'none';
  document.getElementById('loading').style.display = 'block';
  setLoadingDetail(options.detail || '正在读取后端活动数据...');
  releaseAllFestivalImageObjectUrls();
  allData = {};
  archiveYearLoadState = {};

  archiveYearMeta = await fetchBackendEventYears();
  const availableYears = archiveYearMeta.map((item) => item.year);
  const preferredYear = Number(prevView?.year);
  activeYear = preserveView && availableYears.includes(preferredYear)
    ? preferredYear
    : (availableYears[0] ?? new Date().getFullYear());
  archiveYearMeta.forEach((item) => {
    allData[item.year] = {};
    archiveYearLoadState[item.year] = {
      page: 0,
      totalPages: Math.max(1, Math.ceil(Number(item.count || 0) / archiveLazyPageSize)),
      total: Number(item.count || 0),
      loading: false,
      loaded: false,
    };
  });

  await loadArchiveYearPage(activeYear, { reset: true, silent: true });

  document.getElementById('loading').style.display = 'none';
  setHeaderCounter(countTotalFestivals(), 'FESTIVALS FROM DB');
  buildUI({ preserveView, prevView });
  if (eventBrandBindingState.initialized) {
    refreshEventBrandRowsFromSource();
    if (currentAppPage === 'event-brand') {
      renderEventBrandBindingTable();
    }
  }
  applyAppPageVisibility();
}

function insertArchiveEvents(events) {
  for (const event of events) {
    const fest = mapBackendEventToFestival(event);
    if (!allData[fest.year]) allData[fest.year] = {};
    if (!allData[fest.year][fest.month]) allData[fest.year][fest.month] = [];
    const list = allData[fest.year][fest.month];
    if (list.some((item) => String(item?.backendEventId || '') === String(fest.backendEventId || ''))) continue;
    allData[fest.year][fest.month].push(fest);
  }
  sortArchiveData();
}

function sortArchiveData() {
  for (const yearData of Object.values(allData)) {
    for (const list of Object.values(yearData)) {
      list.sort((a, b) => {
        const aStart = String(a?.info?.startDate || '');
        const bStart = String(b?.info?.startDate || '');
        if (aStart !== bStart) return aStart.localeCompare(bStart);
        return String(a?.name || '').localeCompare(String(b?.name || ''));
      });
    }
  }
}

async function loadArchiveYearPage(year, options = {}) {
  const targetYear = Number(year);
  if (!Number.isInteger(targetYear)) return false;
  const state = archiveYearLoadState[targetYear] || { page: 0, totalPages: 1, total: 0, loading: false, loaded: false };
  if (state.loading) return false;
  if (!options.reset && state.loaded) return false;
  if (options.reset) {
    allData[targetYear] = {};
    state.page = 0;
    state.loaded = false;
  }
  state.loading = true;
  archiveYearLoadState[targetYear] = state;
  archiveLazyLoading = true;
  if (!options.silent) setLoadingDetail(`正在加载 ${targetYear} 年活动第 ${state.page + 1} 页...`);
  try {
    const payload = await fetchBackendEventsPage({
      year: targetYear,
      page: state.page + 1,
      limit: archiveLazyPageSize,
    });
    insertArchiveEvents(payload.items);
    state.page = Number(payload.pagination.page || state.page + 1);
    state.totalPages = Math.max(1, Number(payload.pagination.totalPages || state.totalPages || 1));
    state.total = Number(payload.pagination.total || state.total || payload.items.length || 0);
    state.loaded = state.page >= state.totalPages;
    archiveYearLoadState[targetYear] = state;
    setHeaderCounter(countTotalFestivals(), 'FESTIVALS FROM DB');
    return true;
  } finally {
    state.loading = false;
    archiveLazyLoading = false;
  }
}

async function loadMoreArchiveYearEvents() {
  const loaded = await loadArchiveYearPage(activeYear);
  if (loaded) {
    renderYear();
    if (eventBrandBindingState.initialized) refreshEventBrandRowsFromSource();
  }
  return loaded;
}

function getArchiveYearLoadState(year = activeYear) {
  return archiveYearLoadState[Number(year)] || { page: 0, totalPages: 1, total: 0, loading: false, loaded: true };
}
