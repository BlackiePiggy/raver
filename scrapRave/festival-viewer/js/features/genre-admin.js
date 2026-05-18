(function () {
  const state = {
    loaded: false,
    loading: false,
    items: [],
    filteredItems: [],
    selectedId: '',
    expandedIds: new Set(),
    djs: [],
    djLoaded: false,
    searchQuery: '',
    bindingSearchSeq: 0,
  };

  window.genreAdminState = state;

  function esc(value) {
    return String(value ?? '').replace(/[&<>"']/g, (ch) => ({
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      '"': '&quot;',
      "'": '&#39;',
    }[ch] || ch));
  }

  function normalize(value) {
    return String(value || '').trim().toLowerCase();
  }

  function cssEsc(value) {
    const text = String(value ?? '');
    return window.CSS && typeof window.CSS.escape === 'function'
      ? window.CSS.escape(text)
      : text.replace(/["\\]/g, '\\$&');
  }

  function setGenreStatus(message, isError = false) {
    const el = document.getElementById('genre-admin-status');
    if (!el) return;
    el.textContent = message;
    el.classList.toggle('error', Boolean(isError));
  }

  function resolveAvatarUrl(dj) {
    const raw = String(dj?.avatarMediumUrl || dj?.avatarUrl || '').trim();
    if (!raw) return '';
    return typeof ttToAbsoluteLocalUrl === 'function' ? ttToAbsoluteLocalUrl(raw) : raw;
  }

  function resolveBindingDJ(binding) {
    if (binding?.dj && typeof binding.dj === 'object') return binding.dj;
    const djId = String(binding?.djId || '').trim();
    if (!djId) return null;
    return state.djs.find((dj) => String(dj?.id || '') === djId) || null;
  }

  function childrenByParent() {
    const map = new Map();
    for (const item of state.filteredItems) {
      const key = item.parentId || '__root__';
      const rows = map.get(key) || [];
      rows.push(item);
      map.set(key, rows);
    }
    return map;
  }

  function depthFor(item) {
    return String(item.path || '').split('/').filter(Boolean).length - 1;
  }

  function itemById(id) {
    const targetId = String(id || '').trim();
    if (!targetId) return null;
    return state.items.find((item) => String(item?.id || '') === targetId) || null;
  }

  function ensureExpandedIds(nextIds) {
    const ids = nextIds instanceof Set ? nextIds : new Set(nextIds || []);
    state.expandedIds = ids;
  }

  function expandGenreAncestors(id) {
    const next = new Set(state.expandedIds);
    let cursor = itemById(id);
    while (cursor && cursor.parentId) {
      const parentId = String(cursor.parentId).trim();
      if (!parentId) break;
      next.add(parentId);
      cursor = itemById(parentId);
    }
    ensureExpandedIds(next);
  }

  function syncGenreTreeExpansion() {
    const next = new Set();
    for (const item of state.filteredItems) {
      const id = String(item?.id || '').trim();
      if (id && state.expandedIds.has(id)) next.add(id);
    }
    state.expandedIds = next;
    if (state.searchQuery) {
      for (const item of state.filteredItems) {
        if (item?.parentId) next.add(String(item.parentId).trim());
      }
    }
    if (state.selectedId) expandGenreAncestors(state.selectedId);
  }

  function toggleGenreTreeNode(id) {
    const targetId = String(id || '').trim();
    if (!targetId) return;
    const next = new Set(state.expandedIds);
    if (next.has(targetId)) next.delete(targetId);
    else next.add(targetId);
    ensureExpandedIds(next);
    renderTree();
  }

  function renderTree() {
    const root = document.getElementById('genre-admin-tree');
    if (!root) return;
    const tree = childrenByParent();
    const sortRows = (rows) => [...rows].sort((a, b) => {
      const pa = String(a.path || '');
      const pb = String(b.path || '');
      return pa.localeCompare(pb);
    });
    const renderBranch = (parentId = '__root__', level = 0) => {
      const rows = sortRows(tree.get(parentId) || []);
      if (!rows.length) return '';
      return rows.map((item) => {
        const id = String(item.id || '').trim();
        const indentRem = (Math.max(0, level) * 1.16).toFixed(2);
        const count = Array.isArray(item.keyArtists) ? item.keyArtists.length : 0;
        const childRows = sortRows(tree.get(id) || []);
        const hasChildren = childRows.length > 0;
        const expanded = hasChildren && state.expandedIds.has(id);
        return `
          <div class="genre-tree-node ${expanded ? 'expanded' : ''}" style="--tree-indent:${indentRem}rem">
            <div class="genre-tree-row ${id === state.selectedId ? 'active' : ''}" data-node-id="${esc(id)}">
              ${hasChildren
                ? `<button class="genre-tree-toggle" type="button" data-action="genre-tree-toggle" data-id="${esc(id)}" aria-label="${expanded ? '收起子层级' : '展开子层级'}" aria-expanded="${expanded ? 'true' : 'false'}"></button>`
                : '<span class="genre-tree-toggle-spacer"></span>'}
              <button class="genre-tree-select" type="button" data-action="genre-tree-select" data-id="${esc(id)}">
                <span class="genre-tree-name">${esc(item.name)}</span>
                <span class="genre-tree-meta">${count} artists</span>
              </button>
            </div>
            ${hasChildren && expanded ? `<div class="genre-tree-children">${renderBranch(id, level + 1)}</div>` : ''}
          </div>
        `;
      }).join('');
    };
    root.innerHTML = renderBranch();
  }

  function parentChainIds(item) {
    const ids = [];
    let cursor = item;
    while (cursor?.parentId) {
      const parentId = String(cursor.parentId || '').trim();
      if (!parentId) break;
      ids.push(parentId);
      cursor = itemById(parentId);
    }
    return ids;
  }

  function searchMatches(item, query) {
    const text = [
      item.name,
      item.path,
      item.description,
      item.example,
      ...(item.keyArtists || []),
    ].join(' ').toLowerCase();
    return text.includes(query);
  }

  function djAvatarHTML(dj, name) {
    const src = resolveAvatarUrl(dj);
    if (src) {
      return `<img class="genre-artist-avatar" src="${esc(src)}" alt="">`;
    }
    return `<span class="genre-artist-avatar fallback">${esc(String(name || '?').slice(0, 1).toUpperCase())}</span>`;
  }

  function renderArtistCapsule(binding) {
    const dj = resolveBindingDJ(binding);
    const djId = String(dj?.id || binding?.djId || '').trim();
    const name = dj?.name || binding.name;
    const tagName = djId ? 'button' : 'span';
    const actionAttrs = djId
      ? ` type="button" data-action="genre-open-dj-profile" data-dj-id="${esc(djId)}" title="打开 ${esc(name)} 的 DJ 详情"`
      : '';
    return `
      <${tagName} class="genre-artist-capsule ${djId ? 'bound' : 'unbound'}"${actionAttrs}>
        ${djAvatarHTML(dj, name)}
        <span class="genre-artist-name">${esc(name)}</span>
        ${djId ? '<span class="genre-artist-bound">BOUND</span>' : '<span class="genre-artist-bound muted">UNBOUND</span>'}
      </${tagName}>
    `;
  }

  function i18nValue(item, key, locale) {
    const direct = item?.[`${key}I18n`];
    const value = direct && typeof direct === 'object' ? direct[locale] : '';
    return String(value || (locale === 'en' ? item?.[key] : '') || '').trim();
  }

  function renderI18nEditor(item, key, title, rows = 5) {
    const fields = [
      { locale: 'en', label: 'EN' },
      { locale: 'zh', label: '中文' },
      { locale: 'ja', label: '日本語' },
    ];
    return `
      <div class="genre-i18n-panel">
        <div class="genre-panel-title">${esc(title)}</div>
        <div class="genre-i18n-grid">
          ${fields.map((field) => `
            <label class="genre-i18n-field">
              <span>${esc(field.label)}</span>
              <textarea data-content-field="${esc(key)}" data-locale="${esc(field.locale)}" rows="${rows}">${esc(i18nValue(item, key, field.locale))}</textarea>
            </label>
          `).join('')}
        </div>
      </div>
    `;
  }

  function bindingRowsForGenre(item) {
    if (!item) return [];
    const rows = [];
    const seen = new Set();
    const pushRow = (binding) => {
      const name = String(binding?.name || '').trim();
      if (!name) return;
      const key = name.toLowerCase();
      if (seen.has(key)) return;
      seen.add(key);
      rows.push({
        name,
        djId: String(binding?.djId || '').trim() || null,
        dj: binding?.dj || null,
      });
    };
    if (Array.isArray(item.keyArtistBindings)) item.keyArtistBindings.forEach(pushRow);
    (item.keyArtists || []).forEach((name) => pushRow({ name, djId: '', dj: null }));
    return rows;
  }

  function renderBindingSearchRow(binding, index) {
    const dj = resolveBindingDJ(binding);
    const djId = String(dj?.id || binding?.djId || '').trim();
    const artistName = String(binding?.name || '').trim();
    const selectedHtml = djId
      ? renderArtistCapsule({ name: artistName, djId, dj })
      : `<span class="genre-binding-empty">未绑定 DJ</span>`;
    const placeholder = dj?.name || artistName || '搜索 DJ';
    const importButtonHtml = !djId
      ? `<button class="genre-binding-search-btn genre-binding-import-btn" type="button" data-action="genre-import-dj" data-index="${index}">搜索入库</button>`
      : '';
    return `
      <div class="genre-binding-row" data-artist="${esc(artistName)}" data-index="${index}" data-dj-id="${esc(djId)}">
        <div class="genre-binding-artist">${renderArtistCapsule(binding)}</div>
        <div class="genre-binding-control">
          <div class="genre-binding-current">
            ${selectedHtml}
            ${djId ? `<button class="genre-binding-clear" type="button" data-action="genre-clear-dj-binding" data-index="${index}">解绑</button>` : ''}
          </div>
          <div class="genre-binding-search-wrap">
            <input class="genre-dj-search-input" type="text" data-action="genre-dj-search-input" data-index="${index}" placeholder="${esc(`搜索并绑定 ${placeholder}`)}" autocomplete="off">
            <button class="genre-binding-search-btn" type="button" data-action="genre-search-dj" data-index="${index}">搜索</button>
            ${importButtonHtml}
          </div>
          <div class="genre-dj-suggest" data-genre-dj-suggest="${index}"></div>
        </div>
      </div>
    `;
  }

  function selectedGenre() {
    return state.items.find((item) => item.id === state.selectedId) || state.items[0] || null;
  }

  function renderDetail() {
    const el = document.getElementById('genre-admin-detail');
    if (!el) return;
    const item = selectedGenre();
    if (!item) {
      el.innerHTML = '<div class="genre-empty">暂无 genre 数据</div>';
      return;
    }
    const bindings = bindingRowsForGenre(item);
    el.innerHTML = `
      <div class="genre-detail-head">
        <div>
          <div class="genre-detail-title">${esc(item.name)}</div>
          <div class="genre-detail-path">${esc(item.path || '')}</div>
        </div>
        <button class="dj-tool-btn primary" onclick="saveGenreContentAndArtists()">保存内容与绑定</button>
      </div>
      ${renderI18nEditor(item, 'description', 'Genre intro', 6)}
      <div class="genre-artist-panel">
        <div class="genre-panel-title">Key artists</div>
        <div class="genre-artist-cloud">${bindings.map(renderArtistCapsule).join('') || '<span class="genre-muted">No key artists</span>'}</div>
      </div>
      <div class="genre-add-artist">
        <input class="genre-add-artist-input" type="text" placeholder="添加新的 key artist / DJ 名称" autocomplete="off">
        <button class="genre-binding-search-btn" type="button" data-action="genre-add-key-artist">添加 DJ</button>
      </div>
      <div class="genre-binding-list">
        ${bindings.map(renderBindingSearchRow).join('')}
      </div>
      ${renderI18nEditor(item, 'example', 'Sound cue', 2)}
    `;
  }

  function applyFilter() {
    const query = normalize(state.searchQuery);
    if (!query) {
      state.filteredItems = [...state.items];
    } else {
      const visibleIds = new Set();
      state.items.forEach((item) => {
        if (!searchMatches(item, query)) return;
        const id = String(item?.id || '').trim();
        if (id) visibleIds.add(id);
        parentChainIds(item).forEach((parentId) => visibleIds.add(parentId));
      });
      state.filteredItems = state.items.filter((item) => visibleIds.has(String(item?.id || '').trim()));
    }
    if (!state.filteredItems.some((item) => item.id === state.selectedId)) {
      state.selectedId = state.filteredItems[0]?.id || state.items[0]?.id || '';
    }
    syncGenreTreeExpansion();
    renderTree();
    renderDetail();
  }

  async function ensureGenreDJsLoaded() {
    if (state.djLoaded) return;
    const resp = await apiGet('/api/raver/djs?page=1&limit=100&sortBy=name', getViewerAuthHeaders());
    const data = (resp && typeof resp === 'object' && resp.data && typeof resp.data === 'object') ? resp.data : resp;
    state.djs = Array.isArray(data?.items) ? data.items : [];
    state.djLoaded = true;
  }

  async function ensureGenreAdminPageLoaded(force = false) {
    if (state.loading || (state.loaded && !force)) return;
    state.loading = true;
    setGenreStatus('正在加载 genre tree...');
    try {
      const [treeResp] = await Promise.all([
        apiGet('/api/raver/learn/genres/admin/tree', getViewerAuthHeaders()),
        ensureGenreDJsLoaded(),
      ]);
      const data = (treeResp && typeof treeResp === 'object' && treeResp.data && typeof treeResp.data === 'object') ? treeResp.data : treeResp;
      state.items = Array.isArray(data?.items) ? data.items : [];
      state.filteredItems = [...state.items];
      state.loaded = true;
      state.selectedId = state.selectedId || state.items[0]?.id || '';
      syncGenreTreeExpansion();
      setGenreStatus(`已加载 ${state.items.length} 个 genre`);
      renderTree();
      renderDetail();
      setHeaderCounter(state.items.length, 'GENRES LOADED');
    } catch (error) {
      setGenreStatus(error?.message || '加载失败', true);
    } finally {
      state.loading = false;
    }
  }

  async function refreshGenreAdminPage() {
    state.loaded = false;
    await ensureGenreAdminPageLoaded(true);
  }

  function selectGenreAdminNode(id) {
    state.selectedId = String(id || '');
    expandGenreAncestors(state.selectedId);
    renderTree();
    renderDetail();
  }

  async function saveGenreArtistBindings() {
    const item = selectedGenre();
    if (!item) return;
    const rows = Array.from(document.querySelectorAll('.genre-binding-row'));
    const bindings = rows.map((row) => ({
      name: String(row.getAttribute('data-artist') || '').trim(),
      djId: String(row.getAttribute('data-dj-id') || '').trim() || null,
    })).filter((row) => row.name);
    const keyArtists = bindings.map((row) => row.name);
    setGenreStatus(`正在保存 ${item.name} 的 artist 绑定...`);
    try {
      const resp = await apiPost(
        `/api/raver/learn/genres/${encodeURIComponent(item.id)}/key-artist-bindings`,
        { keyArtists, bindings },
        getViewerAuthHeaders()
      );
      const data = (resp && typeof resp === 'object' && resp.data && typeof resp.data === 'object') ? resp.data : resp;
      item.keyArtists = Array.isArray(data?.keyArtists) ? data.keyArtists : keyArtists;
      item.keyArtistBindings = Array.isArray(data?.keyArtistBindings) ? data.keyArtistBindings : bindings;
      setGenreStatus(`已保存 ${item.name}`);
      renderDetail();
    } catch (error) {
      setGenreStatus(error?.message || '保存失败', true);
    }
  }

  function collectGenreContentPayload() {
    const detail = document.getElementById('genre-admin-detail');
    const readI18n = (field) => {
      const result = {};
      detail?.querySelectorAll(`[data-content-field="${cssEsc(field)}"]`).forEach((node) => {
        const locale = String(node.getAttribute('data-locale') || '').trim();
        if (locale) result[locale] = String(node.value || '').trim();
      });
      return result;
    };
    const descriptionI18n = readI18n('description');
    const exampleI18n = readI18n('example');
    return {
      description: descriptionI18n.en || '',
      descriptionI18n,
      example: exampleI18n.en || '',
      exampleI18n,
    };
  }

  async function saveGenreContent() {
    const item = selectedGenre();
    if (!item) return null;
    const resp = await apiPost(
      `/api/raver/learn/genres/${encodeURIComponent(item.id)}/content`,
      collectGenreContentPayload(),
      getViewerAuthHeaders()
    );
    const data = (resp && typeof resp === 'object' && resp.data && typeof resp.data === 'object') ? resp.data : resp;
    item.description = String(data?.description || '');
    item.descriptionI18n = data?.descriptionI18n || collectGenreContentPayload().descriptionI18n;
    item.example = String(data?.example || '');
    item.exampleI18n = data?.exampleI18n || collectGenreContentPayload().exampleI18n;
    return data;
  }

  async function saveGenreContentAndArtists() {
    const item = selectedGenre();
    if (!item) return;
    setGenreStatus(`正在保存 ${item.name} 的多语言内容与 DJ 绑定...`);
    try {
      await saveGenreContent();
      await saveGenreArtistBindings();
      setGenreStatus(`已保存 ${item.name} 的多语言内容与 DJ 绑定`);
    } catch (error) {
      setGenreStatus(error?.message || '保存失败', true);
    }
  }

  function addKeyArtistToSelectedGenre(name) {
    const item = selectedGenre();
    const artistName = String(name || '').trim();
    if (!item || !artistName) return;
    const bindings = bindingRowsForGenre(item);
    if (bindings.some((binding) => String(binding.name || '').trim().toLowerCase() === artistName.toLowerCase())) {
      setGenreStatus(`${artistName} 已经在当前 genre 中`, true);
      return;
    }
    bindings.push({ name: artistName, djId: null, dj: null });
    item.keyArtists = bindings.map((binding) => binding.name);
    item.keyArtistBindings = bindings;
    setGenreStatus(`已添加 ${artistName}，绑定 DJ 后记得保存。`);
    renderDetail();
  }

  function getSelectedBinding(index) {
    const item = selectedGenre();
    const bindings = bindingRowsForGenre(item);
    return bindings[Number(index)] || null;
  }

  function setSelectedBinding(index, dj) {
    const item = selectedGenre();
    if (!item) return;
    const bindings = bindingRowsForGenre(item).map((binding) => ({ ...binding }));
    const rowIndex = Number(index);
    const binding = bindings[rowIndex];
    if (!binding) return;
    const djId = String(dj?.id || '').trim();
    binding.djId = djId || null;
    binding.dj = djId
      ? {
          id: djId,
          name: String(dj?.name || binding.name || '').trim() || binding.name,
          avatarUrl: String(dj?.avatarUrl || '').trim() || null,
          avatarMediumUrl: String(dj?.avatarMediumUrl || '').trim() || null,
        }
      : null;
    bindings[rowIndex] = binding;
    item.keyArtistBindings = bindings;
    renderDetail();
  }

  function clearSelectedBinding(index) {
    const binding = getSelectedBinding(index);
    if (!binding) return;
    setSelectedBinding(index, null);
  }

  async function importGenreBindingDJ(index) {
    const binding = getSelectedBinding(index);
    if (!binding) return;
    const artistName = String(binding?.name || '').trim();
    if (!artistName) {
      setGenreStatus('当前 artist 名称为空，无法触发搜索入库。', true);
      return;
    }
    if (typeof openDJLibraryImportModalWithOptions !== 'function') {
      setGenreStatus('DJ 入库能力未加载完成，请稍后重试。', true);
      return;
    }
    setGenreStatus(`正在为 ${artistName} 打开 DJ 搜索入库...`);
    await openDJLibraryImportModalWithOptions({
      initialName: artistName,
      onImported: async (dj) => {
        setSelectedBinding(index, dj);
        const djName = String(dj?.name || dj?.id || artistName).trim();
        setGenreStatus(`已导入并绑定 ${djName}`);
      },
    });
  }

  function renderDJSuggestions(index, rows, query) {
    const suggest = document.querySelector(`[data-genre-dj-suggest="${cssEsc(index)}"]`);
    if (!suggest) return;
    const q = String(query || '').trim();
    if (!q) {
      suggest.classList.remove('open');
      suggest.innerHTML = '';
      suggest._genreDJRows = [];
      return;
    }
    suggest.classList.add('open');
    suggest._genreDJRows = Array.isArray(rows) ? rows : [];
    if (!suggest._genreDJRows.length) {
      suggest.innerHTML = `<div class="genre-dj-suggest-empty">没有找到 “${esc(q)}”，换个别名或英文名试试。</div>`;
      return;
    }
    suggest.innerHTML = `
      <div class="genre-dj-suggest-list">
        ${suggest._genreDJRows.map((row, rowIndex) => {
          const avatar = resolveAvatarUrl(row);
          const aliases = Array.isArray(row.aliases) ? row.aliases.filter(Boolean).slice(0, 2).join(' / ') : '';
          return `
            <button class="genre-dj-suggest-item" type="button" data-action="genre-select-dj-suggestion" data-index="${esc(index)}" data-suggest-index="${rowIndex}">
              ${avatar ? `<img class="genre-dj-suggest-avatar" src="${esc(avatar)}" alt="">` : `<span class="genre-dj-suggest-avatar fallback">${esc(String(row.name || '?').slice(0, 1).toUpperCase())}</span>`}
              <span class="genre-dj-suggest-main">
                <span class="genre-dj-suggest-name">${esc(row.name || row.id)}</span>
                <span class="genre-dj-suggest-meta">${esc(aliases || row.id || '')}</span>
              </span>
            </button>
          `;
        }).join('')}
      </div>
    `;
  }

  async function searchGenreBindingDJ(index, query) {
    const q = String(query || '').trim();
    const suggest = document.querySelector(`[data-genre-dj-suggest="${cssEsc(index)}"]`);
    if (!q) {
      renderDJSuggestions(index, [], '');
      return;
    }
    const seq = ++state.bindingSearchSeq;
    if (suggest) {
      suggest.classList.add('open');
      suggest.innerHTML = '<div class="genre-dj-suggest-empty">正在搜索全量 DJ 库...</div>';
    }
    try {
      const rows = await fetchGenreDJCandidates(q, 12);
      if (seq !== state.bindingSearchSeq) return;
      renderDJSuggestions(index, rows, q);
    } catch (error) {
      if (seq !== state.bindingSearchSeq) return;
      if (suggest) {
        suggest.classList.add('open');
        suggest.innerHTML = `<div class="genre-dj-suggest-empty">搜索失败：${esc(error?.message || '未知错误')}</div>`;
      }
    }
  }

  async function fetchGenreDJCandidates(query, limit = 12) {
    const rows = typeof fetchEntityAssociationCandidates === 'function'
      ? await fetchEntityAssociationCandidates('dj', query, { limit, headers: getViewerAuthHeaders() })
      : [];
    const ids = rows.map((row) => String(row?.id || '').trim()).filter(Boolean);
    const detailById = new Map();
    if (ids.length) {
      const detailRows = await Promise.all(ids.map(async (id) => {
        try {
          const resp = await apiGet(`/api/raver/djs/${encodeURIComponent(id)}`, getViewerAuthHeaders());
          const data = (resp && typeof resp === 'object' && resp.data && typeof resp.data === 'object') ? resp.data : resp;
          return data && data.id ? data : null;
        } catch (_error) {
          return null;
        }
      }));
      detailRows.filter(Boolean).forEach((dj) => detailById.set(String(dj.id), dj));
    }
    return rows.map((row) => ({
      ...row,
      ...(detailById.get(String(row.id)) || {}),
      id: String(row.id || '').trim(),
      name: String(detailById.get(String(row.id))?.name || row.name || '').trim(),
    })).filter((row) => row.id && row.name);
  }

  async function runGenreArtistAutoMatch() {
    const btn = document.getElementById('genre-admin-auto-match-btn');
    if (btn) btn.disabled = true;
    setGenreStatus('正在一键匹配所有 key artists...');
    try {
      const resp = await apiPost('/api/raver/learn/genres/key-artists/auto-match', {}, getViewerAuthHeaders());
      const data = (resp && typeof resp === 'object' && resp.data && typeof resp.data === 'object') ? resp.data : resp;
      setGenreStatus(`匹配完成：${data.matched || 0}/${data.totalArtists || 0} artists，更新 ${data.updatedGenres || 0} 个 genre`);
      await refreshGenreAdminPage();
    } catch (error) {
      setGenreStatus(error?.message || '一键匹配失败', true);
    } finally {
      if (btn) btn.disabled = false;
    }
  }

  function bindGenreAdminEvents() {
    const input = document.getElementById('genre-admin-search');
    if (input && !input.dataset.bound) {
      input.dataset.bound = 'true';
      input.addEventListener('input', () => {
        state.searchQuery = input.value || '';
        applyFilter();
      });
    }
    const tree = document.getElementById('genre-admin-tree');
    if (tree && !tree.dataset.genreTreeBound) {
      tree.dataset.genreTreeBound = 'true';
      tree.addEventListener('click', (event) => {
        const target = event.target instanceof Element ? event.target.closest('[data-action]') : null;
        if (!target) return;
        const action = String(target.getAttribute('data-action') || '');
        if (action === 'genre-tree-toggle') {
          event.preventDefault();
          event.stopPropagation();
          toggleGenreTreeNode(target.getAttribute('data-id'));
        } else if (action === 'genre-tree-select') {
          event.preventDefault();
          selectGenreAdminNode(target.getAttribute('data-id'));
        }
      });
    }
    const detail = document.getElementById('genre-admin-detail');
    if (detail && !detail.dataset.genreProfileBound) {
      detail.dataset.genreProfileBound = 'true';
      detail.addEventListener('click', (event) => {
        const target = event.target instanceof Element ? event.target.closest('[data-action]') : null;
        if (!target) return;
        const action = String(target.getAttribute('data-action') || '');
        if (action === 'genre-open-dj-profile') {
          event.preventDefault();
          const djId = String(target.getAttribute('data-dj-id') || '').trim();
          if (djId && typeof openDJProfileById === 'function') {
            void openDJProfileById(djId);
          }
        } else if (action === 'genre-import-dj') {
          event.preventDefault();
          void importGenreBindingDJ(target.getAttribute('data-index'));
        } else if (action === 'genre-search-dj') {
          event.preventDefault();
          const index = target.getAttribute('data-index');
          const input = detail.querySelector(`.genre-dj-search-input[data-index="${cssEsc(index)}"]`);
          void searchGenreBindingDJ(index, input?.value || '');
        } else if (action === 'genre-select-dj-suggestion') {
          event.preventDefault();
          const index = target.getAttribute('data-index');
          const suggestIndex = Number(target.getAttribute('data-suggest-index'));
          const suggest = detail.querySelector(`[data-genre-dj-suggest="${cssEsc(index)}"]`);
          const row = suggest?._genreDJRows?.[suggestIndex];
          if (row) setSelectedBinding(index, row);
        } else if (action === 'genre-clear-dj-binding') {
          event.preventDefault();
          clearSelectedBinding(target.getAttribute('data-index'));
        } else if (action === 'genre-add-key-artist') {
          event.preventDefault();
          const input = detail.querySelector('.genre-add-artist-input');
          addKeyArtistToSelectedGenre(input?.value || '');
        }
      });
      detail.addEventListener('input', (event) => {
        const target = event.target instanceof Element ? event.target.closest('[data-action="genre-dj-search-input"]') : null;
        if (!target) return;
        const index = target.getAttribute('data-index');
        window.clearTimeout(target._genreSearchTimer);
        target._genreSearchTimer = window.setTimeout(() => {
          void searchGenreBindingDJ(index, target.value || '');
        }, 180);
      });
      detail.addEventListener('keydown', (event) => {
        const target = event.target instanceof Element ? event.target.closest('[data-action="genre-dj-search-input"]') : null;
        if (!target || event.key !== 'Enter') return;
        event.preventDefault();
        void searchGenreBindingDJ(target.getAttribute('data-index'), target.value || '');
      });
    }
  }

  document.addEventListener('DOMContentLoaded', bindGenreAdminEvents);
  window.ensureGenreAdminPageLoaded = ensureGenreAdminPageLoaded;
  window.refreshGenreAdminPage = refreshGenreAdminPage;
  window.selectGenreAdminNode = selectGenreAdminNode;
  window.saveGenreArtistBindings = saveGenreArtistBindings;
  window.saveGenreContentAndArtists = saveGenreContentAndArtists;
  window.runGenreArtistAutoMatch = runGenreArtistAutoMatch;
})();
