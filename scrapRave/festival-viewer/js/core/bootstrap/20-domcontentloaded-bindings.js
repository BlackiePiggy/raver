let bootstrapEventBusBound = false;

function getBootstrapEventBus() {
  return window.AppEventBus || null;
}

function getBootstrapEventName(key, fallback) {
  return String(window.AppEvents?.[key] || fallback);
}

function emitBootstrapEvent(key, fallback, detail = {}) {
  const bus = getBootstrapEventBus();
  if (!bus || typeof bus.emit !== 'function') return;
  bus.emit(getBootstrapEventName(key, fallback), detail);
}

function bindBootstrapEventBusHandlers() {
  if (bootstrapEventBusBound) return;
  const bus = getBootstrapEventBus();
  if (!bus || typeof bus.on !== 'function') return;
  bootstrapEventBusBound = true;

  bus.on(getBootstrapEventName('UI_REQUEST_CLOSE', 'ui:request-close'), (detail) => {
    const target = String(detail?.target || '').trim();
    if (!target) return;
    if (target === 'dj-source-replace' && typeof closeDJSourceReplaceModal === 'function') closeDJSourceReplaceModal();
    else if (target === 'dj-profile' && typeof closeDJProfileModal === 'function') closeDJProfileModal();
    else if (target === 'brand-editor' && typeof closeBrandEditor === 'function') closeBrandEditor();
    else if (target === 'news-editor' && typeof closeNewsEditor === 'function') closeNewsEditor();
    else if (target === 'ranking-board-editor' && typeof closeRankingBoardEditor === 'function') closeRankingBoardEditor();
    else if (target === 'ranking-entries-editor' && typeof closeRankingEntriesEditor === 'function') closeRankingEntriesEditor();
    else if (target === 'add-event' && typeof closeAddEventModal === 'function') closeAddEventModal();
    else if (target === 'translate-batch' && typeof closeTranslateBatchModal === 'function') closeTranslateBatchModal();
    else if (target === 'poster-review' && typeof closePosterReviewModal === 'function') closePosterReviewModal();
    else if (target === 'coze-review' && typeof closeCozeReviewModal === 'function') closeCozeReviewModal();
    else if (target === 'event-editor' && typeof closeActiveEventEditorByCancel === 'function') closeActiveEventEditorByCancel();
    else if (target === 'event-lineup' && typeof closeEventLineupModal === 'function') closeEventLineupModal();
    else if (target === 'tt-dj-bind' && typeof closeTtDJBindModal === 'function') closeTtDJBindModal();
    else if (target === 'tt-modal' && typeof closeTtModal === 'function') closeTtModal();
    else if (target === 'lightbox' && typeof closeLightbox === 'function') closeLightbox();
  });

  bus.on(getBootstrapEventName('LIGHTBOX_CLOSE', 'lightbox:close'), () => {
    if (typeof closeLightbox === 'function') closeLightbox();
  });
  bus.on(getBootstrapEventName('LIGHTBOX_NAVIGATE', 'lightbox:navigate'), (detail) => {
    const direction = Number(detail?.direction || 0);
    if (!Number.isFinite(direction) || direction === 0) return;
    if (typeof lbNavigate === 'function') lbNavigate(direction < 0 ? -1 : 1);
  });
}

window.addEventListener('DOMContentLoaded', async () => {
  bindBootstrapEventBusHandlers();
  emitBootstrapEvent('APP_DOM_READY', 'app:dom-ready', { at: Date.now() });
  if (typeof applyViewerTheme === 'function') {
    applyViewerTheme(document.documentElement?.dataset?.theme || 'light');
  }

  const djSearchInput = document.getElementById('dj-search-input');
  if (djSearchInput) {
    djSearchInput.addEventListener('input', (event) => {
      onDJSearchInputChanged(event.target?.value || '');
    });
  }
  const brandSearchInput = document.getElementById('brand-search-input');
  if (brandSearchInput) {
    brandSearchInput.addEventListener('input', (event) => {
      onBrandSearchInputChanged(event.target?.value || '');
    });
  }
  const eventBrandSearchInput = document.getElementById('event-brand-search-input');
  if (eventBrandSearchInput) {
    eventBrandSearchInput.addEventListener('input', (event) => {
      onEventBrandSearchInputChanged(event.target?.value || '');
    });
  }
  const eventBrandFilterSelect = document.getElementById('event-brand-filter-select');
  if (eventBrandFilterSelect) {
    eventBrandFilterSelect.addEventListener('change', (event) => {
      onEventBrandFilterModeChanged(event.target?.value || 'all');
    });
  }
  const newsSearchInput = document.getElementById('news-search-input');
  if (newsSearchInput) {
    newsSearchInput.addEventListener('input', (event) => {
      newsPageState.searchQuery = String(event.target?.value || '');
      newsApplyFiltersSortAndRender();
    });
  }
  const newsSortSelect = document.getElementById('news-sort-select');
  if (newsSortSelect) {
    newsSortSelect.addEventListener('change', (event) => {
      newsPageState.sortMode = String(event.target?.value || 'published_desc');
      newsApplyFiltersSortAndRender();
    });
  }
  const newsGroupSelect = document.getElementById('news-group-select');
  if (newsGroupSelect) {
    newsGroupSelect.addEventListener('change', (event) => {
      newsPageState.groupMode = String(event.target?.value || 'none');
      newsApplyFiltersSortAndRender();
    });
  }
  const newsCategoryFilterSelect = document.getElementById('news-category-filter-select');
  if (newsCategoryFilterSelect) {
    newsCategoryFilterSelect.addEventListener('change', (event) => {
      newsPageState.categoryFilter = String(event.target?.value || 'all');
      newsApplyFiltersSortAndRender();
    });
  }
  const newsSourceFilterSelect = document.getElementById('news-source-filter-select');
  if (newsSourceFilterSelect) {
    newsSourceFilterSelect.addEventListener('change', (event) => {
      newsPageState.sourceFilter = String(event.target?.value || 'all');
      newsApplyFiltersSortAndRender();
    });
  }
  const newsBindingFilterSelect = document.getElementById('news-binding-filter-select');
  if (newsBindingFilterSelect) {
    newsBindingFilterSelect.addEventListener('change', (event) => {
      newsPageState.bindingFilter = String(event.target?.value || 'all');
      newsApplyFiltersSortAndRender();
    });
  }
  const newsBrandFilterSelect = document.getElementById('news-brand-filter-select');
  if (newsBrandFilterSelect) {
    newsBrandFilterSelect.addEventListener('change', (event) => {
      newsPageState.brandFilter = String(event.target?.value || 'all');
      newsApplyFiltersSortAndRender();
    });
  }
  const newsEditFieldMap = [
    ['news-edit-title-input', 'title'],
    ['news-edit-category-input', 'category'],
    ['news-edit-source-input', 'source'],
    ['news-edit-summary-input', 'summary'],
    ['news-edit-body-input', 'body'],
    ['news-edit-link-input', 'link'],
    ['news-edit-cover-input', 'coverImageURL'],
    ['news-edit-location-input', 'location'],
    ['news-edit-display-published-at-input', 'displayPublishedAt'],
    ['news-wechat-link-input', 'importWechatUrl'],
  ];
  for (const [id, field] of newsEditFieldMap) {
    const el = document.getElementById(id);
    if (!el) continue;
    const handleFieldChange = (event) => onNewsEditorInputChanged(field, event.target?.value || '');
    el.addEventListener('input', handleFieldChange);
    el.addEventListener('change', handleFieldChange);
  }
  const newsCoverFileInput = document.getElementById('news-media-file-input');
  if (newsCoverFileInput) {
    newsCoverFileInput.addEventListener('change', () => {
      renderNewsEditorFromDraft();
    });
  }
  const newsWechatLinkInput = document.getElementById('news-wechat-link-input');
  if (newsWechatLinkInput) {
    newsWechatLinkInput.addEventListener('keydown', (event) => {
      if (event.key !== 'Enter') return;
      event.preventDefault();
      importNewsFromWechatLink();
    });
  }
  const newsBindTypes = ['dj', 'brand', 'event'];
  for (const type of newsBindTypes) {
    const input = document.getElementById(`news-bind-${type}-input`);
    if (!input) continue;
    if (typeof newsBindSuggestContainerEvents === 'function') {
      newsBindSuggestContainerEvents(type);
    }
    input.addEventListener('input', (event) => {
      if (typeof newsOpenBindSuggest === 'function') newsOpenBindSuggest(type);
      newsScheduleBindSearch(type, event.target?.value || '');
    });
    input.addEventListener('focus', (event) => {
      if (typeof newsOpenBindSuggest === 'function') newsOpenBindSuggest(type);
      newsScheduleBindSearch(type, event.target?.value || '');
    });
    input.addEventListener('blur', () => {
      if (typeof newsScheduleBindSuggestHide === 'function') newsScheduleBindSuggestHide(type);
    });
    input.addEventListener('keydown', (event) => {
      if (event.key === 'ArrowDown') {
        if (typeof newsMoveBindSuggestionActive === 'function') {
          const moved = newsMoveBindSuggestionActive(type, 1);
          if (moved) event.preventDefault();
        }
        return;
      }
      if (event.key === 'ArrowUp') {
        if (typeof newsMoveBindSuggestionActive === 'function') {
          const moved = newsMoveBindSuggestionActive(type, -1);
          if (moved) event.preventDefault();
        }
        return;
      }
      if (event.key === 'Escape') {
        if (typeof newsCloseBindSuggest === 'function') newsCloseBindSuggest(type);
        return;
      }
      if (event.key === 'Enter') {
        event.preventDefault();
        if (typeof newsSelectActiveBindSuggestion === 'function') {
          const selected = newsSelectActiveBindSuggestion(type);
          if (selected) {
            newsAddBindingByInput(type);
            return;
          }
        }
        newsAddBindingByInput(type);
      }
    });
  }
  bindEventBrandBatchInputBehavior();
  clearDJBulkLogs();
  appendDJBulkLog('批量双语化日志已就绪。');
  updateDJBulkProgressUI({
    status: 'idle',
    total: 0,
    processed: 0,
    updated: 0,
    failed: 0,
    skipped: 0,
  });
  updateDJBulkSelectionButtons();
  const ttExistingSearchInput = document.getElementById('tt-dj-existing-search');
  if (ttExistingSearchInput) {
    ttExistingSearchInput.addEventListener('input', () => {
      if (ttDJBindState.open) ttRenderExistingDJList();
    });
  }
  const ttImportQueryInput = document.getElementById('tt-dj-import-query');
  if (ttImportQueryInput) {
    ttImportQueryInput.addEventListener('keydown', (event) => {
      if (event.key === 'Enter') {
        event.preventDefault();
        if (ttDJBindState.open) ttFetchImportSources();
      }
    });
  }
  const ttAvatarFileInput = document.getElementById('tt-dj-avatar-file');
  if (ttAvatarFileInput) {
    ttAvatarFileInput.addEventListener('change', () => {
      if (!ttDJBindState.open) return;
      if (ttDJBindState.importState) ttDJBindState.importState.avatarSource = 'manual';
      ttRenderImportCompareTable();
      ttRenderImportAvatarPreview();
    });
  }
  const ttSourceToggleIds = ['tt-dj-src-spotify', 'tt-dj-src-discogs', 'tt-dj-src-soundcloud'];
  for (const toggleId of ttSourceToggleIds) {
    const toggleEl = document.getElementById(toggleId);
    if (!toggleEl) continue;
    toggleEl.addEventListener('change', () => {
      if (!ttDJBindState.open || !ttDJBindState.importState) return;
      ttDJBindState.importState.sourceEnabled.spotify = !!document.getElementById('tt-dj-src-spotify')?.checked;
      ttDJBindState.importState.sourceEnabled.discogs = !!document.getElementById('tt-dj-src-discogs')?.checked;
      ttDJBindState.importState.sourceEnabled.soundcloud = !!document.getElementById('tt-dj-src-soundcloud')?.checked;
      ttNormalizeImportSelections();
      ttRenderImportSourceGrid();
      ttRenderImportCompareTable();
      ttRenderImportAvatarPreview();
    });
  }
  const ttManualFields = [
    'tt-dj-manual-name',
    'tt-dj-manual-aliases',
    'tt-dj-manual-genres',
    'tt-dj-manual-bio',
    'tt-dj-manual-country',
    'tt-dj-manual-website',
    'tt-dj-manual-spotify-id',
    'tt-dj-manual-spotify-followers',
    'tt-dj-manual-instagram-url',
    'tt-dj-manual-facebook-url',
    'tt-dj-manual-soundcloud-url',
    'tt-dj-manual-soundcloud-id',
    'tt-dj-manual-track-count',
    'tt-dj-manual-playlist-count',
    'tt-dj-manual-soundcloud-followers',
    'tt-dj-manual-soundcloud-favorites',
    'tt-dj-manual-twitter-url',
    'tt-dj-manual-youtube-url',
    'tt-dj-manual-verified',
  ];
  for (const fieldId of ttManualFields) {
    const el = document.getElementById(fieldId);
    if (!el) continue;
    const evt = (el.tagName === 'INPUT' && el.type === 'checkbox') ? 'change' : 'input';
    el.addEventListener(evt, () => {
      if (!ttDJBindState.open) return;
      ttRenderImportCompareTable();
      ttRenderImportAvatarPreview();
    });
  }
  const authPasswordInput = document.getElementById('auth-login-password');
  if (authPasswordInput) {
    authPasswordInput.addEventListener('keydown', (event) => {
      if (event.key === 'Enter') {
        event.preventDefault();
        submitViewerLogin();
      }
    });
  }
  const authIdentifierInput = document.getElementById('auth-login-identifier');
  if (authIdentifierInput) {
    authIdentifierInput.addEventListener('keydown', (event) => {
      if (event.key === 'Enter') {
        event.preventDefault();
        submitViewerLogin();
      }
    });
  }

  const authReady = await restoreViewerAuth();
  if (authReady) {
    await startViewerAppIfNeeded();
  } else {
    applyAppPageVisibility();
  }
  emitBootstrapEvent('APP_AUTH_READY', 'app:auth-ready', { ready: !!authReady });
});
