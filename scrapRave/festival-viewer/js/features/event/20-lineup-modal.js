const eventLineupModalState = {
  currentFest: null,
  currentRowEl: null,
  editMode: false,
  saving: false,
  searchRows: [],
  searchQuery: '',
  manualName: '',
};

function getEventLineupArtistsForFest(fest) {
  if (!fest?.info || typeof buildEventLineupArtistsFromArchive !== 'function') return [];
  return buildEventLineupArtistsFromArchive(fest.info.lineupArtists || [], fest.info.lineup || []);
}

function sortEventLineupArtistsByName(items) {
  return [...(Array.isArray(items) ? items : [])].sort((a, b) => {
    const left = String(a?.djName || a?.name || '').trim();
    const right = String(b?.djName || b?.name || '').trim();
    return left.localeCompare(right, 'zh-Hans-CN', { sensitivity: 'base' });
  }).map((item, index) => ({
    ...item,
    sortOrder: index + 1,
  }));
}

function findDJLibraryItemById(djId) {
  const id = String(djId || '').trim();
  if (!id) return null;
  const source = Array.isArray(djLibraryState?.allItems) ? djLibraryState.allItems : [];
  return source.find((item) => String(item?.id || '').trim() === id) || null;
}

function eventLineupResolveAvatarUrl(artist) {
  const libraryItem = findDJLibraryItemById(artist?.djId);
  return String(
    libraryItem?.avatarUrl
    || libraryItem?.avatarDisplayUrl
    || artist?.avatarUrl
    || artist?.avatar
    || ''
  ).trim();
}

function eventLineupRenderAvatar(name, avatarUrl, className = 'event-lineup-avatar') {
  if (avatarUrl) {
    return `<span class="${className}"><img src="${escapeHtml(avatarUrl)}" alt="${escapeHtml(name)}" loading="lazy"></span>`;
  }
  return `<span class="${className} is-empty" aria-hidden="true"></span>`;
}

function setEventLineupModalStatus(text, isError = false) {
  const el = document.getElementById('event-lineup-modal-status');
  if (!el) return;
  el.textContent = String(text || '');
  el.style.color = isError ? 'var(--accent2)' : 'var(--text-dim)';
}

function syncEventLineupModalActions() {
  const editBtn = document.getElementById('event-lineup-modal-edit-btn');
  const saveBtn = document.getElementById('event-lineup-modal-save-btn');
  const cancelBtn = document.getElementById('event-lineup-modal-cancel-btn');
  if (!editBtn || !saveBtn || !cancelBtn) return;
  editBtn.style.display = eventLineupModalState.editMode ? 'none' : '';
  saveBtn.style.display = eventLineupModalState.editMode ? '' : 'none';
  cancelBtn.style.display = eventLineupModalState.editMode ? '' : 'none';
  editBtn.disabled = eventLineupModalState.saving;
  saveBtn.disabled = eventLineupModalState.saving;
  cancelBtn.disabled = eventLineupModalState.saving;
}

function renderEventLineupModalReadView(fest) {
  const body = document.getElementById('event-lineup-modal-body');
  if (!body) return;
  const artists = sortEventLineupArtistsByName(getEventLineupArtistsForFest(fest));
  if (!artists.length) {
    body.innerHTML = '<div class="event-lineup-empty">暂无 DJ 阵容。</div>';
    return;
  }
  const boundCount = artists.filter((item) => String(item?.djId || '').trim()).length;
  body.innerHTML = `
    <div class="event-lineup-modal-summary">
      <div class="event-lineup-modal-stat"><strong>${artists.length}</strong><span>总 DJ</span></div>
      <div class="event-lineup-modal-stat"><strong>${boundCount}</strong><span>已绑定 DJ 库</span></div>
      <div class="event-lineup-modal-stat"><strong>${artists.length - boundCount}</strong><span>仅名字</span></div>
    </div>
    <div class="event-lineup-modal-chip-grid">
      ${artists.map((artist, index) => {
        const hasBinding = !!String(artist?.djId || '').trim();
        const name = String(artist?.djName || 'Unknown DJ').trim() || 'Unknown DJ';
        const avatarUrl = eventLineupResolveAvatarUrl(artist);
        return `
          <button class="event-lineup-modal-chip${hasBinding ? '' : ' is-unbound'}" type="button" data-lineup-modal-action="${hasBinding ? 'open-dj-profile' : 'bind-dj'}" data-index="${index}">
            ${eventLineupRenderAvatar(name, avatarUrl, 'event-lineup-modal-avatar')}
            <span class="event-lineup-modal-chip-name">${escapeHtml(name)}</span>
            <span class="event-lineup-modal-chip-badge">${hasBinding ? '已绑定' : '仅名字'}</span>
          </button>
        `;
      }).join('')}
    </div>
  `;
}

function renderEventLineupModalEditView(fest) {
  const body = document.getElementById('event-lineup-modal-body');
  if (!body) return;
  body.innerHTML = `
    <div class="event-lineup-modal-editor">
      <div class="event-lineup-editor-tools event-lineup-modal-tools">
        <input class="edit-input" id="event-lineup-modal-search" type="text" placeholder="搜索 DJ 库，如 Charlotte de Witte" value="${escapeHtml(eventLineupModalState.searchQuery)}">
        <button class="edit-btn" type="button" data-lineup-modal-action="search">搜索 DJ 库</button>
        <input class="edit-input" id="event-lineup-modal-manual" type="text" placeholder="库里没有，只填 DJ 名字" value="${escapeHtml(eventLineupModalState.manualName)}">
        <button class="edit-btn" type="button" data-lineup-modal-action="add-name">添加名字</button>
      </div>
      <div class="event-lineup-search-results" id="event-lineup-modal-search-results"></div>
      <div class="event-lineup-artist-list event-lineup-modal-artist-list" id="event-lineup-modal-artist-list"></div>
      <div class="event-lineup-modal-footnote">点击已绑定 DJ 可进入资料页；未绑定 DJ 可直接进入导入/绑定流程。删除仅影响 DJ 阵容本身；若该 DJ 已挂 timetable，后端会阻止删除并提示先清理 timetable。</div>
    </div>
  `;
  const tempPanel = document.createElement('div');
  tempPanel.innerHTML = `
    <div class="fest-info-edit">
      <textarea data-field="lineupArtists">${escapeHtml(JSON.stringify({ lineup_artists: sortEventLineupArtistsByName(getEventLineupArtistsForFest(fest)) }))}</textarea>
    </div>
    <div data-lineup-artist-list></div>
    <div data-lineup-search-results></div>
  `;
  renderEventLineupArtistEditor(tempPanel, sortEventLineupArtistsByName(getEventLineupArtistsForFest(fest)));
  const renderedList = tempPanel.querySelector('[data-lineup-artist-list]');
  const targetList = document.getElementById('event-lineup-modal-artist-list');
  if (renderedList && targetList) targetList.innerHTML = renderedList.innerHTML;
  const targetResults = document.getElementById('event-lineup-modal-search-results');
  if (targetResults) targetResults.innerHTML = '';
  if (Array.isArray(eventLineupModalState.searchRows) && eventLineupModalState.searchRows.length && targetResults) {
    targetResults.innerHTML = eventLineupModalState.searchRows.map((row, index) => `
      <button class="event-lineup-result" type="button" data-lineup-modal-action="add-search-result" data-index="${index}">
        <span>${escapeHtml(row.name || row.id)}</span>
        <small>${escapeHtml(row.id || '')}</small>
      </button>
    `).join('');
  }
}

function renderEventLineupModalBody() {
  const fest = eventLineupModalState.currentFest;
  if (!fest) return;
  if (eventLineupModalState.editMode) renderEventLineupModalEditView(fest);
  else renderEventLineupModalReadView(fest);
}

async function openEventLineupModal(fest, rowEl = null) {
  eventLineupModalState.currentFest = fest;
  eventLineupModalState.currentRowEl = rowEl || null;
  eventLineupModalState.editMode = false;
  eventLineupModalState.saving = false;
  eventLineupModalState.searchRows = [];
  eventLineupModalState.searchQuery = '';
  eventLineupModalState.manualName = '';
  const titleBi = normalizeBiTextValue(fest.info.nameI18n ?? fest.info.name ?? fest.name ?? fest.folder, fest.folder);
  document.getElementById('event-lineup-modal-title').innerHTML = renderBiTextHtml(titleBi, { compact: true, fallback: fest.folder });
  document.getElementById('event-lineup-modal-sub').textContent =
    [fest.info.location || fest.location, `${sortEventLineupArtistsByName(getEventLineupArtistsForFest(fest)).length} 位 DJ`].filter(Boolean).join('  ·  ');
  setEventLineupModalStatus('正在加载 DJ 头像...');
  syncEventLineupModalActions();
  renderEventLineupModalBody();
  document.getElementById('event-lineup-modal-overlay').classList.add('open');
  document.body.style.overflow = 'hidden';
  try {
    if (typeof ensureDJLibraryLoaded === 'function') await ensureDJLibraryLoaded();
    if (eventLineupModalState.currentFest !== fest) return;
    setEventLineupModalStatus('');
    renderEventLineupModalBody();
  } catch (_error) {
    if (eventLineupModalState.currentFest !== fest) return;
    setEventLineupModalStatus('');
  }
}

function closeEventLineupModal() {
  if (eventLineupModalState.saving) return;
  document.getElementById('event-lineup-modal-overlay')?.classList.remove('open');
  document.body.style.overflow = document.getElementById('tt-modal-overlay')?.classList.contains('open')
    || document.getElementById('tt-dj-bind-overlay')?.classList.contains('open')
    ? 'hidden'
    : '';
  eventLineupModalState.currentFest = null;
  eventLineupModalState.currentRowEl = null;
  eventLineupModalState.editMode = false;
  eventLineupModalState.searchRows = [];
  eventLineupModalState.searchQuery = '';
  eventLineupModalState.manualName = '';
  setEventLineupModalStatus('');
}

function handleEventLineupOverlayClick(event) {
  if (event.target === document.getElementById('event-lineup-modal-overlay')) closeEventLineupModal();
}

function enterEventLineupEditMode() {
  if (!eventLineupModalState.currentFest || eventLineupModalState.saving) return;
  eventLineupModalState.editMode = true;
  setEventLineupModalStatus('已进入编辑模式，可搜索 DJ 库或补 name-only DJ。');
  syncEventLineupModalActions();
  renderEventLineupModalBody();
}

function cancelEventLineupEditMode() {
  if (eventLineupModalState.saving) return;
  eventLineupModalState.editMode = false;
  eventLineupModalState.searchRows = [];
  eventLineupModalState.searchQuery = '';
  eventLineupModalState.manualName = '';
  setEventLineupModalStatus('');
  syncEventLineupModalActions();
  renderEventLineupModalBody();
}

async function eventLineupModalSearchDj() {
  const input = document.getElementById('event-lineup-modal-search');
  const query = String(input?.value || '').trim();
  eventLineupModalState.searchQuery = query;
  const resultsEl = document.getElementById('event-lineup-modal-search-results');
  if (!query) {
    eventLineupModalState.searchRows = [];
    if (resultsEl) resultsEl.innerHTML = '<div class="event-lineup-empty">请输入 DJ 名称再搜索。</div>';
    return;
  }
  if (resultsEl) resultsEl.innerHTML = '<div class="event-lineup-empty">正在搜索 DJ 库...</div>';
  try {
    const rows = await fetchEntityAssociationCandidates('dj', query, { limit: 12, headers: getViewerAuthHeaders() });
    eventLineupModalState.searchRows = Array.isArray(rows) ? rows : [];
    renderEventLineupModalBody();
  } catch (error) {
    eventLineupModalState.searchRows = [];
    if (resultsEl) resultsEl.innerHTML = `<div class="event-lineup-empty">搜索失败：${escapeHtml(String(error?.message || error))}</div>`;
  }
}

function eventLineupModalUpdateArtists(nextArtists) {
  const fest = eventLineupModalState.currentFest;
  if (!fest) return;
  fest.info.lineupArtists = buildEventLineupArtistsFromArchive(sortEventLineupArtistsByName(nextArtists || []), fest.info.lineup || []);
  if (eventLineupModalState.currentRowEl && typeof refreshFestHeaderDisplay === 'function') {
    refreshFestHeaderDisplay(eventLineupModalState.currentRowEl, fest);
  }
  renderEventLineupModalBody();
}

function eventLineupModalAddArtist(artist) {
  const fest = eventLineupModalState.currentFest;
  if (!fest) return;
  const current = getEventLineupArtistsForFest(fest);
  const next = buildEventLineupArtistsFromArchive([...current, {
    djId: String(artist?.djId || artist?.id || '').trim() || undefined,
    djIds: Array.isArray(artist?.djIds) ? artist.djIds : (artist?.id ? [String(artist.id)] : []),
    djName: String(artist?.djName || artist?.name || '').trim(),
    sortOrder: current.length + 1,
  }], fest.info.lineup || []);
  eventLineupModalUpdateArtists(next);
}

function eventLineupModalRemoveArtist(index) {
  const fest = eventLineupModalState.currentFest;
  if (!fest) return;
  const next = getEventLineupArtistsForFest(fest)
    .filter((_item, idx) => idx !== Number(index))
    .map((item, idx) => ({ ...item, sortOrder: idx + 1 }));
  eventLineupModalUpdateArtists(next);
}

async function saveEventLineupModalChanges() {
  const fest = eventLineupModalState.currentFest;
  if (!fest) return;
  eventLineupModalState.saving = true;
  syncEventLineupModalActions();
  setEventLineupModalStatus('正在保存 DJ 阵容...');
  const panelEl = eventLineupModalState.currentRowEl?.querySelector('.fest-info-panel');
  const saveBtn = document.getElementById('event-lineup-modal-save-btn');
  try {
    const payload = {
      ...(fest.info || {}),
      lineupArtists: getEventLineupArtistsForFest(fest),
    };
    const syncResult = await persistFestivalPayload(fest, payload, { imageZoneDraft: null, existingAssetDraft: null });
    if (syncResult?.event) patchFestivalFromBackendEvent(fest, syncResult.event);
    if (panelEl && typeof renderInfoView === 'function') renderInfoView(panelEl, fest.info);
    if (panelEl && typeof setEditInputs === 'function') setEditInputs(panelEl, fest.info);
    eventLineupModalState.editMode = false;
    eventLineupModalState.searchRows = [];
    eventLineupModalState.searchQuery = '';
    eventLineupModalState.manualName = '';
    syncEventLineupModalActions();
    renderEventLineupModalBody();
    setEventLineupModalStatus(`已保存 ${new Date().toLocaleTimeString()}`);
  } catch (error) {
    setEventLineupModalStatus(`保存失败：${String(error?.message || error)}`, true);
  } finally {
    eventLineupModalState.saving = false;
    if (saveBtn) saveBtn.disabled = false;
    syncEventLineupModalActions();
  }
}

function refreshEventLineupModalIfCurrent() {
  if (!eventLineupModalState.currentFest) return;
  renderEventLineupModalBody();
}

document.addEventListener('click', (event) => {
  const modalOverlay = document.getElementById('event-lineup-modal-overlay');
  if (!modalOverlay?.classList.contains('open')) return;
  const target = event.target instanceof Element
    ? (event.target.closest('[data-lineup-modal-action]') || event.target.closest('[data-action="lineup-remove-artist"]'))
    : null;
  if (!target) return;
  const action = String(
    target.getAttribute('data-lineup-modal-action')
    || target.getAttribute('data-action')
    || ''
  ).trim();
  if (action === 'search') {
    event.preventDefault();
    void eventLineupModalSearchDj();
    return;
  }
  if (action === 'add-name') {
    event.preventDefault();
    const input = document.getElementById('event-lineup-modal-manual');
    const name = String(input?.value || '').trim();
    if (!name) return;
    eventLineupModalAddArtist({ djName: name });
    eventLineupModalState.manualName = '';
    if (input) input.value = '';
    return;
  }
  if (action === 'add-search-result') {
    event.preventDefault();
    const row = eventLineupModalState.searchRows[Number(target.getAttribute('data-index'))];
    if (!row) return;
    eventLineupModalAddArtist({ djId: row.id, id: row.id, djName: row.name });
    eventLineupModalState.searchRows = [];
    eventLineupModalState.searchQuery = '';
    renderEventLineupModalBody();
    return;
  }
  if (action === 'open-dj-profile') {
    event.preventDefault();
    const artist = sortEventLineupArtistsByName(getEventLineupArtistsForFest(eventLineupModalState.currentFest))[Number(target.getAttribute('data-index'))];
    const djId = String(artist?.djId || '').trim();
    if (!djId) return;
    void openDJProfileById(djId);
    return;
  }
  if (action === 'bind-dj') {
    event.preventDefault();
    const artist = sortEventLineupArtistsByName(getEventLineupArtistsForFest(eventLineupModalState.currentFest))[Number(target.getAttribute('data-index'))];
    const name = String(artist?.djName || '').trim();
    if (!name) return;
    void openDJLibraryImportModalWithOptions({
      initialName: name,
      onImported: async (dj) => {
        const current = sortEventLineupArtistsByName(getEventLineupArtistsForFest(eventLineupModalState.currentFest));
        const targetName = String(artist?.djName || '').trim().toLowerCase();
        const next = current.map((item) => {
          const itemName = String(item?.djName || '').trim().toLowerCase();
          if (itemName !== targetName || String(item?.djId || '').trim()) return item;
          return {
            ...item,
            djId: String(dj?.id || '').trim() || item.djId,
            djIds: dj?.id ? [String(dj.id)] : (Array.isArray(item?.djIds) ? item.djIds : []),
            djName: String(dj?.name || item?.djName || '').trim() || item.djName,
            avatarUrl: String(dj?.avatarUrl || '').trim() || item.avatarUrl,
          };
        });
        eventLineupModalUpdateArtists(next);
      },
    });
    return;
  }
  if (action === 'lineup-remove-artist') {
    event.preventDefault();
    eventLineupModalRemoveArtist(target.getAttribute('data-index'));
  }
});

document.addEventListener('keydown', (event) => {
  if (event.key !== 'Enter') return;
  if (document.getElementById('event-lineup-modal-overlay')?.classList.contains('open') !== true) return;
  const target = event.target;
  if (!(target instanceof Element)) return;
  if (target.id === 'event-lineup-modal-search') {
    event.preventDefault();
    void eventLineupModalSearchDj();
  } else if (target.id === 'event-lineup-modal-manual') {
    event.preventDefault();
    const name = String(target.value || '').trim();
    if (!name) return;
    eventLineupModalAddArtist({ djName: name });
    target.value = '';
  }
});
