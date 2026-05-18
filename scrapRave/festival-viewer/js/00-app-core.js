const VIEWER_THEME_STORAGE_KEY = 'festivalViewerTheme';
const VIEWER_SIDEBAR_STORAGE_KEY = 'festivalViewerSidebarCollapsed';

function getAppSidebarCollapsed() {
  const current = String(document.body?.dataset?.sidebarCollapsed || '').trim().toLowerCase();
  if (current === 'true') return true;
  try {
    return localStorage.getItem(VIEWER_SIDEBAR_STORAGE_KEY) === 'true';
  } catch (_) {
    return false;
  }
}

function applyAppSidebarCollapsed(collapsed) {
  const normalized = Boolean(collapsed);
  if (document.body) document.body.dataset.sidebarCollapsed = normalized ? 'true' : 'false';
  const nav = document.getElementById('app-page-nav');
  const toggle = document.querySelector('#app-page-nav .app-page-nav-toggle');
  if (nav) nav.classList.toggle('collapsed', normalized);
  if (toggle) {
    toggle.textContent = normalized ? '›' : '‹';
    toggle.setAttribute('aria-label', normalized ? '展开侧栏' : '收起侧栏');
    toggle.setAttribute('title', normalized ? '展开侧栏' : '收起侧栏');
  }
  try {
    localStorage.setItem(VIEWER_SIDEBAR_STORAGE_KEY, normalized ? 'true' : 'false');
  } catch (_) {}
  if (typeof syncReviewPendingBadge === 'function') {
    syncReviewPendingBadge();
  }
}

function toggleAppSidebar() {
  applyAppSidebarCollapsed(!getAppSidebarCollapsed());
}

function getViewerTheme() {
  const current = String(document.documentElement?.dataset?.theme || '').trim().toLowerCase();
  return current === 'dark' ? 'dark' : 'light';
}

function applyViewerTheme(theme) {
  const normalized = String(theme || '').trim().toLowerCase() === 'dark' ? 'dark' : 'light';
  document.documentElement.dataset.theme = normalized;
  try {
    localStorage.setItem(VIEWER_THEME_STORAGE_KEY, normalized);
  } catch (_) {}
  const btn = document.getElementById('theme-toggle-btn');
  const iconEl = document.querySelector('#theme-toggle-btn .theme-toggle-icon');
  if (btn) {
    const nextThemeLabel = normalized === 'light' ? '切换暗色主题' : '切换亮色主题';
    btn.setAttribute('aria-label', nextThemeLabel);
    btn.setAttribute('title', nextThemeLabel);
  }
  if (iconEl) iconEl.textContent = normalized === 'light' ? '☾' : '☀';
}

function toggleViewerTheme() {
  applyViewerTheme(getViewerTheme() === 'light' ? 'dark' : 'light');
}

function setHeaderCounter(countText, labelText) {
  const countEl = document.getElementById('total-count');
  const labelEl = document.getElementById('total-label');
  if (countEl) countEl.textContent = String(countText ?? '—');
  if (labelEl) labelEl.textContent = String(labelText ?? '');
}

function setArchiveHeaderCounter() {
  const hasData = Object.keys(allData || {}).length > 0;
  const total = hasData ? countTotalFestivals() : '—';
  setHeaderCounter(total, 'FESTIVALS LOADED');
}

function setBrandHeaderCounter() {
  const total = brandPageState.loaded ? brandPageState.allItems.length : '—';
  setHeaderCounter(total, 'BRANDS LOADED');
}

function setEventBrandHeaderCounter() {
  const total = Array.isArray(eventBrandBindingState.allRows) ? eventBrandBindingState.allRows.length : countTotalFestivals();
  setHeaderCounter(total || '—', 'EVENT↔BRAND LINKS');
}

function setRankingHeaderCounter() {
  const total = rankingPageState.loaded ? rankingPageState.entries.length : '—';
  setHeaderCounter(total, 'RANKING ENTRIES');
}

function setNewsHeaderCounter() {
  const total = newsPageState.loaded ? newsPageState.filteredItems.length : '—';
  setHeaderCounter(total, 'NEWS ITEMS');
}

function setReviewHeaderCounter() {
  const total = reviewPageState.loaded ? reviewPageState.items.length : '—';
  setHeaderCounter(total, 'CONTENT REVIEWS');
}

function syncAppPageTabs() {
  const archiveTab = document.getElementById('tab-archive');
  const djTab = document.getElementById('tab-dj');
  const brandTab = document.getElementById('tab-brand');
  const eventBrandTab = document.getElementById('tab-event-brand');
  const newsTab = document.getElementById('tab-news');
  const rankingTab = document.getElementById('tab-ranking');
  const genreTab = document.getElementById('tab-genre');
  const reviewTab = document.getElementById('tab-review');
  if (archiveTab) archiveTab.classList.toggle('active', currentAppPage === 'archive');
  if (djTab) djTab.classList.toggle('active', currentAppPage === 'dj');
  if (brandTab) brandTab.classList.toggle('active', currentAppPage === 'brand');
  if (eventBrandTab) eventBrandTab.classList.toggle('active', currentAppPage === 'event-brand');
  if (newsTab) newsTab.classList.toggle('active', currentAppPage === 'news');
  if (rankingTab) rankingTab.classList.toggle('active', currentAppPage === 'ranking');
  if (genreTab) genreTab.classList.toggle('active', currentAppPage === 'genre');
  if (reviewTab) reviewTab.classList.toggle('active', currentAppPage === 'review');
  if (typeof syncReviewPendingBadge === 'function') {
    syncReviewPendingBadge();
  }
  applyAppSidebarCollapsed(getAppSidebarCollapsed());
}

function applyAppPageVisibility() {
  const archivePage = document.getElementById('archive-page');
  const djPage = document.getElementById('dj-page');
  const brandPage = document.getElementById('brand-page');
  const eventBrandPage = document.getElementById('event-brand-page');
  const newsPage = document.getElementById('news-page');
  const rankingPage = document.getElementById('ranking-page');
  const genrePage = document.getElementById('genre-page');
  const reviewPage = document.getElementById('review-page');
  const translateBtn = document.getElementById('global-translate-btn');
  const addEventBtn = document.getElementById('global-add-event-btn');

  if (archivePage) archivePage.style.display = currentAppPage === 'archive' ? '' : 'none';
  if (djPage) djPage.style.display = currentAppPage === 'dj' ? 'block' : 'none';
  if (brandPage) brandPage.style.display = currentAppPage === 'brand' ? 'block' : 'none';
  if (eventBrandPage) eventBrandPage.style.display = currentAppPage === 'event-brand' ? 'block' : 'none';
  if (newsPage) newsPage.style.display = currentAppPage === 'news' ? 'block' : 'none';
  if (rankingPage) rankingPage.style.display = currentAppPage === 'ranking' ? 'block' : 'none';
  if (genrePage) genrePage.style.display = currentAppPage === 'genre' ? 'block' : 'none';
  if (reviewPage) reviewPage.style.display = currentAppPage === 'review' ? 'block' : 'none';
  if (translateBtn) translateBtn.style.display = currentAppPage === 'archive' ? '' : 'none';
  if (addEventBtn) addEventBtn.style.display = currentAppPage === 'archive' ? '' : 'none';

  if (currentAppPage !== 'dj') {
    closeDJProfileModal();
  }
  if (currentAppPage !== 'brand') {
    closeBrandEditor();
  }
  if (currentAppPage !== 'news') {
    closeNewsEditor();
  }
  if (currentAppPage !== 'archive') {
    closeActiveEventEditorByCancel();
  }

  if (currentAppPage === 'archive') {
    setArchiveHeaderCounter();
  } else if (currentAppPage === 'dj') {
    setHeaderCounter(
      djLibraryState.loaded ? djLibraryState.allItems.length : '—',
      'DJS LOADED'
    );
  } else if (currentAppPage === 'brand') {
    setBrandHeaderCounter();
  } else if (currentAppPage === 'event-brand') {
    setEventBrandHeaderCounter();
  } else if (currentAppPage === 'news') {
    setNewsHeaderCounter();
  } else if (currentAppPage === 'ranking') {
    setRankingHeaderCounter();
  } else if (currentAppPage === 'genre') {
    setHeaderCounter(
      window.genreAdminState?.loaded ? window.genreAdminState.items.length : '—',
      'GENRES LOADED'
    );
  } else if (currentAppPage === 'review') {
    setReviewHeaderCounter();
  }

  syncAppPageTabs();
}

function switchAppPage(page) {
  const nextPage = ['archive', 'dj', 'brand', 'event-brand', 'news', 'ranking', 'genre', 'review'].includes(String(page || '')) ? page : 'archive';
  currentAppPage = nextPage;
  applyAppPageVisibility();

  if (nextPage === 'dj') {
    ensureDJLibraryLoaded();
  } else if (nextPage === 'brand') {
    ensureBrandPageLoaded();
  } else if (nextPage === 'event-brand') {
    ensureEventBrandBindingPageLoaded();
  } else if (nextPage === 'news') {
    ensureNewsPageLoaded();
  } else if (nextPage === 'ranking') {
    ensureRankingPageLoaded();
  } else if (nextPage === 'genre' && typeof ensureGenreAdminPageLoaded === 'function') {
    ensureGenreAdminPageLoaded();
  } else if (nextPage === 'review') {
    ensureReviewPageLoaded();
  }
}

function openDJLibraryPage() {
  switchAppPage('dj');
}

async function openDJLibraryImportModal() {
  return openDJLibraryImportModalWithOptions({});
}

async function openDJLibraryImportModalWithOptions(options = {}) {
  const opts = (options && typeof options === 'object') ? options : {};
  const initialName = String(opts.initialName || '').trim();
  const onImported = (typeof opts.onImported === 'function') ? opts.onImported : null;
  await ensureDJLibraryLoaded();
  await ensureTtDJMatchMapLoaded();

  ttDJBindState.open = true;
  ttDJBindState.mode = 'library_import';
  ttDJBindState.rid = null;
  ttDJBindState.tab = 'import';
  ttDJBindState.performerName = '';
  ttDJBindState.performerIndex = null;
  ttDJBindState.existingSearch = '';
  ttDJBindState.existingSelectedId = '';
  ttDJBindState.onImported = onImported;
  ttDJBindState.importState = ttCreateEmptyImportState(null, initialName);

  const subEl = document.getElementById('tt-dj-bind-sub');
  if (subEl) subEl.textContent = '将当前信息保存到 DJ 数据库（无需绑定 timetable）。';

  const existingInput = document.getElementById('tt-dj-existing-search');
  if (existingInput) existingInput.value = '';
  const importInput = document.getElementById('tt-dj-import-query');
  if (importInput) importInput.value = initialName;
  const spotifyToggle = document.getElementById('tt-dj-src-spotify');
  const discogsToggle = document.getElementById('tt-dj-src-discogs');
  const soundcloudToggle = document.getElementById('tt-dj-src-soundcloud');
  const avatarInput = document.getElementById('tt-dj-avatar-file');
  const translateBtn = document.getElementById('tt-dj-translate-btn');
  if (spotifyToggle) spotifyToggle.checked = true;
  if (discogsToggle) discogsToggle.checked = true;
  if (soundcloudToggle) soundcloudToggle.checked = true;
  if (avatarInput) avatarInput.value = '';
  if (translateBtn) translateBtn.disabled = false;

  ttWriteImportDraftToForm(ttGetImportManualDraft(null, initialName));
  ttRenderImportSourceGrid();
  ttRenderImportCompareTable();
  ttRenderImportAvatarPreview();
  ttRenderExistingDJList();
  switchTtDJBindTab('import');
  ttSyncDJBindModalModeUI();
  ttCloseBindStatus();

  const overlay = document.getElementById('tt-dj-bind-overlay');
  if (overlay) overlay.classList.add('open');
  document.body.style.overflow = 'hidden';
}

function switchToArchivePage() {
  switchAppPage('archive');
}

async function startViewerAppIfNeeded() {
  if (appBootstrapped) return;
  appBootstrapped = true;
  applyAppSidebarCollapsed(getAppSidebarCollapsed());
  const hash = String(location.hash || '').toLowerCase();
  let initialPage = 'archive';
  if (hash.includes('review')) initialPage = 'review';
  else if (hash.includes('dj')) initialPage = 'dj';
  else if (hash.includes('event-brand') || hash.includes('eventbrand')) initialPage = 'event-brand';
  else if (hash.includes('news')) initialPage = 'news';
  else if (hash.includes('brand')) initialPage = 'brand';
  else if (hash.includes('ranking')) initialPage = 'ranking';
  switchAppPage(initialPage);
  await bootstrapFolderSelection();
  applyAppPageVisibility();
}
