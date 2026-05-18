// Feature module extracted from monolith (news binding + crud)
function newsUpsertLookup(type, candidate) {
  if (!candidate || typeof candidate !== 'object') return;
  const id = String(candidate.id || '').trim();
  if (!id) return;
  if (type === 'brand') {
    newsPageState.brandLookupById[id] = String(candidate.name || id).trim() || id;
  } else if (type === 'event') {
    newsPageState.eventLookupById[id] = String(candidate.name || id).trim() || id;
  } else {
    newsPageState.djLookupById[id] = String(candidate.name || id).trim() || id;
  }
}

async function newsFetchBindCandidates(type, query) {
  const q = String(query || '').trim();
  if (!q) {
    newsPageState.bindSearch[type] = [];
    newsUpdateBindDatalist(type);
    return;
  }
  const limit = type === 'brand' ? 30 : 20;
  const rows = await fetchEntityAssociationCandidates(type, q, {
    headers: getViewerAuthHeaders(),
    limit,
  });
  newsPageState.bindSearch[type] = rows;
  rows.forEach((row) => newsUpsertLookup(type, row));
  newsUpdateBindDatalist(type);
}

const newsBindSuggestState = {
  dj: { open: false, activeIndex: -1, hideTimer: null },
  brand: { open: false, activeIndex: -1, hideTimer: null },
  event: { open: false, activeIndex: -1, hideTimer: null },
};

function newsBindTypeLabel(type) {
  if (type === 'brand') return 'BRAND';
  if (type === 'event') return 'EVENT';
  return 'DJ';
}

function newsGetBindInput(type) {
  return document.getElementById(`news-bind-${type}-input`);
}

function newsGetBindSuggestEl(type) {
  return document.getElementById(`news-bind-${type}-suggest`);
}

function newsCancelBindSuggestHide(type) {
  const state = newsBindSuggestState[type];
  if (!state) return;
  if (state.hideTimer) {
    clearTimeout(state.hideTimer);
    state.hideTimer = null;
  }
}

function newsCloseBindSuggest(type) {
  const state = newsBindSuggestState[type];
  if (!state) return;
  newsCancelBindSuggestHide(type);
  state.open = false;
  state.activeIndex = -1;
  newsUpdateBindDatalist(type);
}

function newsScheduleBindSuggestHide(type, delay = 140) {
  const state = newsBindSuggestState[type];
  if (!state) return;
  newsCancelBindSuggestHide(type);
  state.hideTimer = setTimeout(() => {
    state.hideTimer = null;
    newsCloseBindSuggest(type);
  }, Math.max(0, Number(delay) || 0));
}

function newsOpenBindSuggest(type) {
  const state = newsBindSuggestState[type];
  if (!state) return;
  newsCancelBindSuggestHide(type);
  state.open = true;
  if (!Number.isInteger(state.activeIndex)) state.activeIndex = -1;
  newsUpdateBindDatalist(type);
}

function newsPickBindSuggestMeta(row) {
  const id = String(row?.id || '').trim();
  const aliases = Array.isArray(row?.aliases) ? row.aliases.map((x) => String(x || '').trim()).filter(Boolean) : [];
  const aliasText = aliases.slice(0, 2).join(' / ');
  if (id && aliasText) return `ID: ${id} · 别名: ${aliasText}`;
  if (id) return `ID: ${id}`;
  if (aliasText) return `别名: ${aliasText}`;
  return '—';
}

function newsUpdateBindDatalist(type) {
  const suggest = newsGetBindSuggestEl(type);
  const input = newsGetBindInput(type);
  const state = newsBindSuggestState[type];
  if (!suggest || !input || !state) return;
  const rows = Array.isArray(newsPageState.bindSearch?.[type]) ? newsPageState.bindSearch[type] : [];
  const q = String(input.value || '').trim();
  const showEmpty = state.open && !!q && rows.length === 0;
  const showList = state.open && rows.length > 0;
  if (!showEmpty && !showList) {
    suggest.classList.remove('open');
    suggest.innerHTML = '';
    return;
  }
  suggest.classList.add('open');
  if (showEmpty) {
    suggest.innerHTML = '<div class="news-bind-suggest-empty">未匹配到候选，可直接输入 ID 后点击添加</div>';
    return;
  }

  const maxRows = Math.min(60, rows.length);
  if (state.activeIndex >= maxRows) state.activeIndex = maxRows - 1;
  if (state.activeIndex < -1) state.activeIndex = -1;
  suggest.innerHTML = `
    <div class="news-bind-suggest-list">
      ${rows.slice(0, maxRows).map((row, idx) => `
        <button
          type="button"
          class="news-bind-suggest-item ${state.activeIndex === idx ? 'active' : ''}"
          data-bind-suggest-type="${escapeHtml(type)}"
          data-bind-suggest-idx="${idx}"
        >
          <span class="news-bind-suggest-main">
            <span class="news-bind-suggest-type">${newsBindTypeLabel(type)}</span>
            <span class="news-bind-suggest-name">${escapeHtml(String(row?.name || '').trim() || String(row?.id || '').trim())}</span>
          </span>
          <span class="news-bind-suggest-meta">${escapeHtml(newsPickBindSuggestMeta(row))}</span>
        </button>
      `).join('')}
    </div>
  `;
}

function newsSelectBindSuggestion(type, idx) {
  const input = newsGetBindInput(type);
  const rows = Array.isArray(newsPageState.bindSearch?.[type]) ? newsPageState.bindSearch[type] : [];
  const row = rows[Number(idx)];
  if (!input || !row) return false;
  const id = String(row?.id || '').trim();
  const name = String(row?.name || id).trim() || id;
  if (!id) return false;
  input.value = `${name} | ${id}`;
  const state = newsBindSuggestState[type];
  if (state) state.activeIndex = Number(idx);
  newsCloseBindSuggest(type);
  input.focus();
  return true;
}

function newsMoveBindSuggestionActive(type, step) {
  const rows = Array.isArray(newsPageState.bindSearch?.[type]) ? newsPageState.bindSearch[type] : [];
  if (!rows.length) return false;
  const state = newsBindSuggestState[type];
  if (!state) return false;
  newsOpenBindSuggest(type);
  const delta = Number(step) || 0;
  if (!delta) return false;
  if (state.activeIndex < 0) {
    state.activeIndex = delta > 0 ? 0 : rows.length - 1;
  } else {
    state.activeIndex = (state.activeIndex + delta + rows.length) % rows.length;
  }
  newsUpdateBindDatalist(type);
  return true;
}

function newsSelectActiveBindSuggestion(type) {
  const state = newsBindSuggestState[type];
  if (!state) return false;
  if (state.activeIndex < 0) return false;
  return newsSelectBindSuggestion(type, state.activeIndex);
}

function newsBindSuggestContainerEvents(type) {
  const suggest = newsGetBindSuggestEl(type);
  if (!suggest || suggest.dataset.bound === '1') return;
  suggest.dataset.bound = '1';
  suggest.addEventListener('mousedown', (event) => {
    event.preventDefault();
  });
  suggest.addEventListener('click', (event) => {
    const btn = event.target.closest('[data-bind-suggest-idx]');
    if (!btn) return;
    const idx = Number(btn.getAttribute('data-bind-suggest-idx'));
    if (!Number.isInteger(idx) || idx < 0) return;
    newsSelectBindSuggestion(type, idx);
  });
}

function newsScheduleBindSearch(type, value) {
  if (!['dj', 'brand', 'event'].includes(String(type))) return;
  newsBindSuggestContainerEvents(type);
  if (newsBindSearchTimers[type]) {
    clearTimeout(newsBindSearchTimers[type]);
    newsBindSearchTimers[type] = null;
  }
  const seq = Number(newsBindSearchSeq[type] || 0) + 1;
  newsBindSearchSeq[type] = seq;
  newsBindSearchTimers[type] = setTimeout(async () => {
    try {
      await newsFetchBindCandidates(type, value);
    } catch (_error) {
      if (newsBindSearchSeq[type] !== seq) return;
      newsPageState.bindSearch[type] = [];
      newsUpdateBindDatalist(type);
    }
  }, 180);
}

function newsResolveBindCandidate(type, raw) {
  const rows = Array.isArray(newsPageState.bindSearch?.[type]) ? newsPageState.bindSearch[type] : [];
  return resolveEntityAssociationCandidate(type, raw, rows, { allowIdFallback: true });
}

async function newsAddBindingByInput(type) {
  const draft = newsPageState.editorDraft;
  if (!draft) return;
  const input = document.getElementById(`news-bind-${type}-input`);
  if (!input) return;
  let hit = newsResolveBindCandidate(type, input.value);
  if (!hit && String(input.value || '').trim()) {
    try {
      await newsFetchBindCandidates(type, input.value);
    } catch (_error) {}
    hit = newsResolveBindCandidate(type, input.value);
  }
  if (!hit || !String(hit.id || '').trim()) {
    setNewsEditStatus('请先选择一个存在的绑定对象。', 'err');
    return;
  }
  const key = type === 'brand' ? 'boundBrandIDs' : (type === 'event' ? 'boundEventIDs' : 'boundDjIDs');
  draft[key] = newsDedupIDs([...(Array.isArray(draft[key]) ? draft[key] : []), String(hit.id).trim()]);
  newsUpsertLookup(type, hit);
  input.value = '';
  newsCloseBindSuggest(type);
  setNewsEditStatus('');
  renderNewsBindingChips(type);
  newsSaveEditorDraftSnapshot();
}

function newsRemoveBinding(type, rawId) {
  const draft = newsPageState.editorDraft;
  if (!draft) return;
  const id = String(rawId || '').trim();
  if (!id) return;
  const key = type === 'brand' ? 'boundBrandIDs' : (type === 'event' ? 'boundEventIDs' : 'boundDjIDs');
  draft[key] = (Array.isArray(draft[key]) ? draft[key] : []).filter((x) => String(x || '').trim() !== id);
  renderNewsBindingChips(type);
  newsSaveEditorDraftSnapshot();
}

function collectNewsEditorPayload() {
  const draft = newsPageState.editorDraft;
  if (!draft) throw new Error('编辑器未初始化');
  const title = newsSingleLine(draft.title);
  const category = newsSingleLine(draft.category);
  const source = newsSingleLine(draft.source);
  const summary = newsSingleLine(draft.summary);
  if (!title) throw new Error('标题为必填项');
  if (!category) throw new Error('主题分类为必填项');
  if (!source) throw new Error('发布方为必填项');
  if (!summary) throw new Error('摘要为必填项');
  const displayPublishedAt = String(draft.displayPublishedAt || '').trim();
  let displayPublishedAtISO = '';
  if (displayPublishedAt) {
    const parsed = new Date(displayPublishedAt);
    if (Number.isNaN(parsed.getTime())) {
      throw new Error('展示发布时间格式不合法');
    }
    displayPublishedAtISO = parsed.toISOString();
  }
  const content = newsEncodeContent(draft);
  const images = newsDraftAllImageResources(draft);
  return {
    content,
    images,
    location: String(draft.location || '').trim(),
    displayPublishedAt: displayPublishedAtISO || null,
    boundDjIDs: newsDedupIDs(draft.boundDjIDs),
    boundBrandIDs: newsDedupIDs(draft.boundBrandIDs),
    boundEventIDs: newsDedupIDs(draft.boundEventIDs),
  };
}

async function saveNewsEditor() {
  const draft = newsPageState.editorDraft;
  if (!draft || newsPageState.editorSaving || newsPageState.editorUploading) return;
  const headers = getViewerAuthHeaders();
  if (!headers.Authorization) {
    openViewerLogin();
    setNewsEditStatus('请先登录后再保存', 'err');
    return;
  }
  let payload;
  try {
    payload = collectNewsEditorPayload();
  } catch (error) {
    setNewsEditStatus(String(error?.message || '参数错误'), 'err');
    return;
  }
  newsPageState.editorSaving = true;
  renderNewsEditorFromDraft();
  setNewsEditStatus('正在保存...');
  try {
    if (draft.isNew) {
      await apiPost('/api/raver/feed/posts', payload, headers);
    } else {
      await apiPost(`/api/raver/feed/posts/${encodeURIComponent(String(draft.id || ''))}/update`, payload, headers);
    }
    draft.sessionUploadedResources = [];
    setNewsEditStatus('保存成功', 'ok');
    await ensureNewsPageLoaded(true);
    await closeNewsEditor({ cleanupMedia: false, clearSnapshot: true });
  } catch (error) {
    setNewsEditStatus(`保存失败：${String(error?.message || '未知错误')}`, 'err');
  } finally {
    newsPageState.editorSaving = false;
    renderNewsEditorFromDraft();
  }
}

async function deleteNewsEditor() {
  const draft = newsPageState.editorDraft;
  if (!draft || draft.isNew || newsPageState.editorDeleting || newsPageState.editorUploading) return;
  if (!window.confirm(`确认删除资讯「${draft.title || draft.id}」吗？此操作不可恢复。`)) return;
  const headers = getViewerAuthHeaders();
  if (!headers.Authorization) {
    openViewerLogin();
    setNewsEditStatus('请先登录后再删除', 'err');
    return;
  }
  newsPageState.editorDeleting = true;
  renderNewsEditorFromDraft();
  setNewsEditStatus('正在删除...');
  try {
    await apiPost(`/api/raver/feed/posts/${encodeURIComponent(String(draft.id || ''))}/delete`, {}, headers);
    setNewsEditStatus('删除成功', 'ok');
    await ensureNewsPageLoaded(true);
    await closeNewsEditor({ cleanupMedia: false, clearSnapshot: true });
  } catch (error) {
    setNewsEditStatus(`删除失败：${String(error?.message || '未知错误')}`, 'err');
  } finally {
    newsPageState.editorDeleting = false;
    renderNewsEditorFromDraft();
  }
}

async function quickDeleteNewsById(newsId) {
  const id = String(newsId || '').trim();
  if (!id) return;
  const row = (Array.isArray(newsPageState.allItems) ? newsPageState.allItems : []).find((item) => String(item?.id || '').trim() === id);
  const title = String(row?.title || id);
  if (!window.confirm(`确认删除资讯「${title}」吗？`)) return;
  const headers = getViewerAuthHeaders();
  if (!headers.Authorization) {
    openViewerLogin();
    setNewsStatus('请先登录后再删除', 'error');
    return;
  }
  try {
    setNewsStatus(`正在删除：${title}`);
    await apiPost(`/api/raver/feed/posts/${encodeURIComponent(id)}/delete`, {}, headers);
    await ensureNewsPageLoaded(true);
    setNewsStatus(`已删除：${title}`, 'ok');
  } catch (error) {
    setNewsStatus(`删除失败：${String(error?.message || '未知错误')}`, 'error');
  }
}

async function ensureNewsPageLoaded(force = false) {
  if (newsPageState.loading) return;
  if (newsPageState.loaded && !force) {
    newsBuildLookupMaps();
    newsRefreshFilterSelects();
    newsApplyFiltersSortAndRender();
    setNewsStatus('');
    return;
  }
  const headers = getViewerAuthHeaders();
  if (!headers.Authorization) {
    openViewerLogin();
    setNewsStatus('请先登录后查看资讯管理。', 'error');
    return;
  }
  newsPageState.loading = true;
  setNewsStatus('正在加载资讯列表...');
  const maxPages = 80;
  const limit = 50;
  let cursor = '';
  let pageCount = 0;
  const collected = [];
  try {
    if (!brandPageState.loaded) {
      try { await ensureBrandPageLoaded(); } catch (_error) {}
    }
    while (pageCount < maxPages) {
      const qs = new URLSearchParams({ limit: String(limit) });
      if (cursor) qs.set('cursor', cursor);
      const resp = await apiGet(`/api/raver/feed?${qs.toString()}`, headers);
      const posts = Array.isArray(resp?.posts) ? resp.posts : [];
      for (const post of posts) {
        const parsed = newsParsePost(post);
        if (parsed?.id) collected.push(parsed);
      }
      const nextCursor = String(resp?.nextCursor || '').trim();
      pageCount += 1;
      if (!nextCursor || nextCursor === cursor) break;
      cursor = nextCursor;
    }
    const byId = new Map();
    for (const item of collected) {
      if (!item?.id || byId.has(item.id)) continue;
      byId.set(item.id, item);
    }
    newsPageState.allItems = [...byId.values()];
    newsPageState.loaded = true;
    newsPageState.loadError = '';
    newsBuildLookupMaps();
    newsRefreshFilterSelects();
    newsApplyFiltersSortAndRender();
    setNewsStatus(`已加载 ${newsPageState.allItems.length} 条资讯`, 'ok');
  } catch (error) {
    newsPageState.allItems = [];
    newsPageState.filteredItems = [];
    newsPageState.loaded = false;
    newsPageState.loadError = String(error?.message || 'unknown');
    renderNewsList();
    updateNewsToolbarMeta();
    setNewsStatus(`资讯加载失败：${newsPageState.loadError}`, 'error');
  } finally {
    newsPageState.loading = false;
  }
}

async function refreshNewsPage(force = false) {
  await ensureNewsPageLoaded(!!force);
}
