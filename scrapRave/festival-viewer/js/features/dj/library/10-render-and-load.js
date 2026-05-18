function getDJLibraryPageSize() {
  const n = Number(djLibraryState.perPage || 42);
  return Number.isFinite(n) && n > 0 ? Math.min(42, Math.floor(n)) : 42;
}

function syncDJLibraryPagination(totalItems) {
  const perPage = getDJLibraryPageSize();
  const total = Math.max(0, Number(totalItems || 0));
  const totalPages = Math.max(1, Math.ceil(total / perPage));
  const current = Math.max(1, Math.min(totalPages, Number(djLibraryState.page || 1)));
  djLibraryState.perPage = perPage;
  djLibraryState.page = current;
  djLibraryState.totalPages = totalPages;
  return {
    page: current,
    perPage,
    totalPages,
    start: (current - 1) * perPage,
    end: current * perPage,
  };
}

function ensureDJPagerElement(grid) {
  const wrap = grid?.closest('.dj-grid-wrap') || grid?.parentElement;
  if (!wrap) return null;
  let pager = wrap.querySelector('#dj-pagination');
  if (!pager) {
    pager = document.createElement('div');
    pager.id = 'dj-pagination';
    pager.className = 'dj-pagination';
    wrap.appendChild(pager);
  }
  return pager;
}

function renderDJPagination(totalItems) {
  const grid = document.getElementById('dj-grid');
  if (!grid) return;
  const pager = ensureDJPagerElement(grid);
  if (!pager) return;
  const page = Math.max(1, Number(djLibraryState.page || 1));
  const totalPages = Math.max(1, Number(djLibraryState.totalPages || 1));
  const perPage = getDJLibraryPageSize();
  if (totalItems <= perPage) {
    pager.innerHTML = '';
    pager.classList.remove('open');
    return;
  }
  pager.classList.add('open');
  const start = (page - 1) * perPage + 1;
  const end = Math.min(totalItems, page * perPage);
  const windowSize = 5;
  let first = Math.max(1, page - Math.floor(windowSize / 2));
  let last = Math.min(totalPages, first + windowSize - 1);
  first = Math.max(1, last - windowSize + 1);
  const pageButtons = [];
  for (let i = first; i <= last; i += 1) {
    pageButtons.push(`<button class="dj-page-btn ${i === page ? 'active' : ''}" type="button" data-dj-page="${i}" ${i === page ? 'aria-current="page"' : ''}>${i}</button>`);
  }
  pager.innerHTML = `
    <div class="dj-pagination-meta">SHOWING ${start}-${end} / ${totalItems} · 42 PER PAGE</div>
    <div class="dj-pagination-actions">
      <button class="dj-page-btn" type="button" data-dj-page="prev" ${page <= 1 ? 'disabled' : ''}>PREV</button>
      ${first > 1 ? '<button class="dj-page-btn" type="button" data-dj-page="1">1</button><span class="dj-page-ellipsis">...</span>' : ''}
      ${pageButtons.join('')}
      ${last < totalPages ? `<span class="dj-page-ellipsis">...</span><button class="dj-page-btn" type="button" data-dj-page="${totalPages}">${totalPages}</button>` : ''}
      <button class="dj-page-btn" type="button" data-dj-page="next" ${page >= totalPages ? 'disabled' : ''}>NEXT</button>
    </div>
  `;
}

function setDJLibraryPage(nextPage) {
  const totalPages = Math.max(1, Number(djLibraryState.totalPages || 1));
  let page = Number(nextPage);
  if (nextPage === 'prev') page = Number(djLibraryState.page || 1) - 1;
  if (nextPage === 'next') page = Number(djLibraryState.page || 1) + 1;
  if (!Number.isFinite(page)) return;
  djLibraryState.page = Math.max(1, Math.min(totalPages, Math.floor(page)));
  void loadDJLibraryPage();
}

function bindDJLibraryPagerEvents() {
  const grid = document.getElementById('dj-grid');
  const pager = grid ? ensureDJPagerElement(grid) : null;
  if (!pager || pager.dataset.bound) return;
  pager.dataset.bound = 'true';
  pager.addEventListener('click', (event) => {
    const target = event.target instanceof Element ? event.target.closest('[data-dj-page]') : null;
    if (!target || target.hasAttribute('disabled')) return;
    event.preventDefault();
    setDJLibraryPage(target.getAttribute('data-dj-page'));
  });
}

function renderDJLetterNav() {
  const nav = document.getElementById('dj-letter-nav');
  if (!nav) return;

  nav.innerHTML = '';
  const total = Number(djLibraryState.searchTotalItems || djLibraryState.totalItems || 0);
  const defs = [{ key: 'ALL', label: 'ALL', count: total }];
  for (const letter of DJ_LIBRARY_LETTERS) {
    defs.push({ key: letter, label: letter, count: null });
  }

  defs.forEach((def) => {
    const btn = document.createElement('button');
    btn.className = 'dj-letter-btn' + (djLibraryState.activeLetter === def.key ? ' active' : '');
    btn.textContent = def.key === 'ALL' ? `${def.label} ${def.count}` : def.label;
    btn.onclick = () => {
      djLibraryState.activeLetter = def.key;
      djLibraryState.page = 1;
      void loadDJLibraryPage();
      renderDJLetterNav();
    };
    nav.appendChild(btn);
  });
}

function renderDJGrid() {
  const grid = document.getElementById('dj-grid');
  if (!grid) return;
  const pageItems = Array.isArray(djLibraryState.pageItems) ? djLibraryState.pageItems : [];
  const totalItems = Number(djLibraryState.totalItems || pageItems.length || 0);
  syncDJLibraryPagination(totalItems);
  djLibraryState.filteredItems = pageItems;
  djLibraryState.pageItems = pageItems;
  syncDJSelectedIdsWithLibrary();
  updateDJToolbarMeta();
  bindDJLibraryPagerEvents();
  renderDJPagination(totalItems);

  if (!pageItems.length) {
    grid.innerHTML = '<div class="dj-card-empty">没有匹配 DJ，尝试更换关键词或字母筛选。</div>';
    return;
  }

  grid.innerHTML = '';
  const frag = document.createDocumentFragment();
  pageItems.forEach((item) => {
    const djId = normalizeDJLibraryId(item?.id);
    const selected = djLibraryState.selectionMode && isDJSelected(djId);
    const card = document.createElement('article');
    card.className = `dj-card${djLibraryState.showAvatar ? '' : ' no-avatar'}${selected ? ' selected' : ''}`;

    const aliases = Array.isArray(item?.aliases) ? item.aliases.filter(Boolean) : [];
    const aliasText = aliases.length ? aliases.slice(0, 2).join(' / ') : '无别名';
    const verified = item?.isVerified ? ' · 已认证' : '';
    const country = String(item?.country || '未知');
    const followers = Number(item?.spotifyFollowers ?? item?.followerCount ?? 0).toLocaleString();
    const title = escapeHtml(item?.name || 'Unknown DJ');

    let avatarHtml = '';
    if (djLibraryState.showAvatar) {
      if (item?.avatarUrl) {
        avatarHtml = `
          <button class="dj-avatar-btn" type="button" aria-label="打开 ${title} 的资料">
            <img src="${escapeHtml(item.avatarUrl)}" alt="${title}" loading="lazy">
          </button>
        `;
      } else {
        const initial = escapeHtml(String(item?.name || '?').trim().charAt(0).toUpperCase() || '?');
        avatarHtml = `
          <button class="dj-avatar-btn" type="button" aria-label="打开 ${title} 的资料">
            <div class="dj-avatar-fallback">${initial}</div>
          </button>
        `;
      }
    }

    const checkboxHtml = djLibraryState.selectionMode
      ? `
      <label class="dj-card-select-wrap" title="选择此 DJ">
        <input class="dj-card-select" type="checkbox" ${selected ? 'checked' : ''}>
      </label>
      `
      : '';

    card.innerHTML = `
      ${checkboxHtml}
      ${avatarHtml}
      <div>
        <div class="dj-card-name">${title}</div>
        <div class="dj-card-meta">${escapeHtml(aliasText)}</div>
        <div class="dj-card-meta">${escapeHtml(country)} · Spotify Followers ${followers}${verified}</div>
      </div>
    `;

    card.onclick = () => openDJProfileById(item.id);
    const avatarBtn = card.querySelector('.dj-avatar-btn');
    if (avatarBtn) {
      avatarBtn.addEventListener('click', (event) => {
        event.stopPropagation();
        openDJProfileById(item.id);
      });
    }
    const checkbox = card.querySelector('.dj-card-select');
    const checkboxWrap = card.querySelector('.dj-card-select-wrap');
    if (checkboxWrap) {
      checkboxWrap.addEventListener('click', (event) => {
        event.stopPropagation();
      });
    }
    if (checkbox) {
      checkbox.addEventListener('click', (event) => {
        event.stopPropagation();
      });
      checkbox.addEventListener('change', (event) => {
        event.stopPropagation();
        const next = !!event.target?.checked;
        setDJSelected(djId, next);
        card.classList.toggle('selected', next);
      });
    }
    frag.appendChild(card);
  });
  grid.appendChild(frag);
}

function renderDJLibrary() {
  renderDJLetterNav();
  renderDJGrid();
}

function extractDJListPayload(resp) {
  const data = (resp && typeof resp === 'object' && resp.data && typeof resp.data === 'object') ? resp.data : resp;
  const items = Array.isArray(data?.items) ? data.items : (Array.isArray(data?.djs) ? data.djs : []);
  const pagination = resp?.pagination || data?.pagination || {};
  return {
    items,
    pagination: {
      page: Number(pagination.page || 1),
      limit: Number(pagination.limit || getDJLibraryPageSize()),
      total: Number(pagination.total || items.length),
      totalPages: Number(pagination.totalPages || 1),
    },
  };
}

function buildDJLibraryPageQuery(page = djLibraryState.page) {
  const qs = new URLSearchParams();
  qs.set('page', String(Math.max(1, Number(page || 1))));
  qs.set('limit', String(getDJLibraryPageSize()));
  qs.set('sortBy', 'name');
  qs.set('live', 'false');
  const search = String(djLibraryState.searchQuery || '').trim();
  if (search) qs.set('search', search);
  const letter = String(djLibraryState.activeLetter || 'ALL').trim().toUpperCase();
  if (/^[A-Z]$/.test(letter)) qs.set('letter', letter);
  return qs;
}

async function fetchDJLibraryPage(page = djLibraryState.page) {
  const qs = buildDJLibraryPageQuery(page);
  const resp = await apiGet(`/api/raver/djs?${qs.toString()}`, getViewerAuthHeaders());
  return extractDJListPayload(resp);
}

async function loadDJLibraryPage() {
  const seq = Number(djLibraryState.pageRequestSeq || 0) + 1;
  djLibraryState.pageRequestSeq = seq;
  djLibraryState.loading = true;
  djLibraryState.loadError = '';
  const grid = document.getElementById('dj-grid');
  if (grid) grid.innerHTML = '<div class="dj-card-empty">DJ 数据加载中...</div>';

  try {
    const payload = await fetchDJLibraryPage(djLibraryState.page);
    if (seq !== djLibraryState.pageRequestSeq) return;
    const items = Array.isArray(payload.items) ? payload.items : [];
    const pagination = payload.pagination || {};
    djLibraryState.pageItems = items;
    djLibraryState.filteredItems = items;
    djLibraryState.allItems = items;
    djLibraryState.allItemsComplete = false;
    djLibraryState.totalItems = Number(pagination.total || items.length || 0);
    djLibraryState.searchTotalItems = djLibraryState.activeLetter === 'ALL'
      ? djLibraryState.totalItems
      : Number(djLibraryState.searchTotalItems || djLibraryState.totalItems || 0);
    djLibraryState.totalPages = Math.max(1, Number(pagination.totalPages || 1));
    djLibraryState.page = Math.max(1, Number(pagination.page || djLibraryState.page || 1));
    djLibraryState.perPage = getDJLibraryPageSize();
    djLibraryState.loaded = true;
    syncDJSelectedIdsWithLibrary();
    setDJStatus(`DJ 数据加载完成：本页 ${items.length} 条 / 共 ${djLibraryState.totalItems} 条。`);
    renderDJLibrary();
  } catch (error) {
    if (seq !== djLibraryState.pageRequestSeq) return;
    djLibraryState.loadError = String(error?.message || '未知错误');
    djLibraryState.pageItems = [];
    djLibraryState.filteredItems = [];
    djLibraryState.allItems = [];
    djLibraryState.allItemsComplete = false;
    djLibraryState.totalItems = 0;
    djLibraryState.totalPages = 1;
    djLibraryState.loaded = false;
    setDJStatus(`DJ 数据加载失败：${djLibraryState.loadError}`, true);
    if (grid) grid.innerHTML = '<div class="dj-card-empty">加载失败，请确认后端和 web_tool 服务已启动。</div>';
  } finally {
    if (seq === djLibraryState.pageRequestSeq) {
      djLibraryState.loading = false;
      applyAppPageVisibility();
    }
  }
}

async function fetchAllDJItems() {
  const limit = 100;
  let page = 1;
  let totalPages = 1;
  const merged = [];

  while (page <= totalPages) {
    const resp = await apiGet(`/api/raver/djs?page=${page}&limit=${limit}&sortBy=name`);
    const items = Array.isArray(resp?.data?.items) ? resp.data.items : [];
    const pgTotal = Number(resp?.pagination?.totalPages || 1);
    totalPages = Number.isFinite(pgTotal) && pgTotal > 0 ? pgTotal : 1;
    merged.push(...items);
    page += 1;
    if (page > 400) break;
  }

  const byId = new Map();
  for (const item of merged) {
    const id = String(item?.id || '').trim();
    if (!id || byId.has(id)) continue;
    byId.set(id, item);
  }
  const items = [...byId.values()];
  djLibraryState.allItems = items;
  djLibraryState.allItemsComplete = true;
  return items;
}

async function ensureDJLibraryLoaded(force = false) {
  if (djLibraryState.loading) return;
  if (djLibraryState.loaded && !force) {
    renderDJLibrary();
    if (typeof renderDJEnrichmentJobProgress === 'function') {
      renderDJEnrichmentJobProgress(djEnrichmentJobState.lastJob);
    }
    if (typeof refreshDJEnrichmentJobs === 'function') {
      void refreshDJEnrichmentJobs(false);
    }
    if (typeof refreshDJEnrichmentJobProgress === 'function' && djEnrichmentJobState.lastJobId) {
      void refreshDJEnrichmentJobProgress(false);
    }
    applyAppPageVisibility();
    return;
  }

  if (force) {
    djLibraryState.page = 1;
    djLibraryState.activeLetter = 'ALL';
  }
  setDJStatus('正在按页加载 DJ 列表...');
  await loadDJLibraryPage();
  if (typeof renderDJEnrichmentJobProgress === 'function') {
    renderDJEnrichmentJobProgress(djEnrichmentJobState.lastJob);
  }
  if (typeof refreshDJEnrichmentJobs === 'function') {
    void refreshDJEnrichmentJobs(false);
  }
  if (typeof refreshDJEnrichmentJobProgress === 'function' && djEnrichmentJobState.lastJobId) {
    void refreshDJEnrichmentJobProgress(false);
  }
}

function refreshDJLibrary() {
  void ensureDJLibraryLoaded(true);
}

function toggleDJAvatarVisibility() {
  djLibraryState.showAvatar = !djLibraryState.showAvatar;
  const btn = document.getElementById('dj-avatar-toggle-btn');
  if (btn) {
    btn.textContent = djLibraryState.showAvatar ? '隐藏头像' : '加载头像';
    btn.classList.toggle('active', djLibraryState.showAvatar);
  }
  renderDJGrid();
}

function onDJSearchInputChanged(value) {
  djLibraryState.searchQuery = String(value || '').trim();
  djLibraryState.page = 1;
  djLibraryState.activeLetter = 'ALL';
  djLibraryState.searchTotalItems = 0;
  window.clearTimeout(djLibraryState.searchTimer);
  djLibraryState.searchTimer = window.setTimeout(() => {
    void loadDJLibraryPage();
  }, 220);
}
