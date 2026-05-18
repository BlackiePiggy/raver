function normalizeWikiFestivalSearchToken(value) {
  return String(value || '').trim().toLowerCase();
}

function eventBrandDisplayName(brand) {
  if (!brand || typeof brand !== 'object') return '';
  const bi = normalizeBiTextValue(brand.nameI18n ?? brand.name, String(brand.name || '').trim());
  return String(bi.zh || bi.en || brand.name || '').trim();
}

function eventBrandCandidatesByQuery(query) {
  const token = normalizeWikiFestivalSearchToken(query);
  const source = Array.isArray(brandPageState.allItems) ? brandPageState.allItems : [];
  const rows = source.filter((item) => {
    if (!item || typeof item !== 'object') return false;
    if (!token) return true;
    const nameBi = normalizeBiTextValue(item.nameI18n ?? item.name, String(item.name || '').trim());
    const pool = [
      String(item.id || '').trim(),
      String(nameBi.en || '').trim(),
      String(nameBi.zh || '').trim(),
      ...(Array.isArray(item.aliases) ? item.aliases.map((x) => String(x || '').trim()) : []),
      String(item.country || '').trim(),
      String(item.city || '').trim(),
    ]
      .join(' ')
      .toLowerCase();
    return pool.includes(token);
  });
  return rows
    .slice(0, 50)
    .map((item) => ({
      id: String(item.id || '').trim(),
      name: eventBrandDisplayName(item),
      aliases: Array.isArray(item.aliases) ? item.aliases.map((x) => String(x || '').trim()).filter(Boolean) : [],
      raw: item,
    }))
    .filter((item) => item.id && item.name);
}

async function ensureEventBrandBindingUI(panelEl, presetInfo = null) {
  if (!panelEl) return;
  const nameInput = panelEl.querySelector('.fest-info-edit [data-field="wikiFestivalName"]');
  const idInput = panelEl.querySelector('.fest-info-edit [data-field="wikiFestivalId"]');
  if (!nameInput || !idInput) return;

  try { await ensureBrandPageLoaded(false); } catch (_error) {}
  const existingListId = String(nameInput.getAttribute('list') || '').trim();
  const listId = existingListId || `wiki-brand-bind-list-${Math.random().toString(36).slice(2)}`;
  let dataList = document.getElementById(listId);
  if (!dataList) {
    dataList = document.createElement('datalist');
    dataList.id = listId;
    document.body.appendChild(dataList);
  }
  nameInput.setAttribute('list', listId);

  const syncList = () => {
    const rows = eventBrandCandidatesByQuery(nameInput.value || '');
    dataList.innerHTML = rows
      .map((row) => `<option value="${escapeHtml(row.name)}" label="${escapeHtml(`${row.id}${row.aliases.length ? ` · ${row.aliases.slice(0, 2).join(' / ')}` : ''}`)}"></option>`)
      .join('');
  };

  if (presetInfo && typeof presetInfo === 'object') {
    const brand = presetInfo.wikiFestival && typeof presetInfo.wikiFestival === 'object' ? presetInfo.wikiFestival : null;
    const brandId = String(presetInfo.wikiFestivalId || brand?.id || '').trim();
    const brandName = brand ? eventBrandDisplayName(brand) : '';
    idInput.value = brandId;
    nameInput.value = brandName || nameInput.value || '';
  }

  if (!nameInput.dataset.brandBindBound) {
    nameInput.dataset.brandBindBound = '1';
    nameInput.addEventListener('input', () => {
      syncList();
      idInput.value = '';
    });
    nameInput.addEventListener('change', () => {
      // Manual selection only: only resolve on explicit change (datalist pick / exact value).
      const typed = String(nameInput.value || '').trim();
      const token = normalizeWikiFestivalSearchToken(typed);
      const candidates = eventBrandCandidatesByQuery(typed);
      const hit = candidates.find((item) => {
        if (normalizeWikiFestivalSearchToken(item.id) === token) return true;
        if (normalizeWikiFestivalSearchToken(item.name) === token) return true;
        return item.aliases.some((alias) => normalizeWikiFestivalSearchToken(alias) === token);
      });
      if (hit) {
        idInput.value = hit.id;
        nameInput.value = hit.name;
      } else {
        idInput.value = '';
      }
      syncList();
    });
  }
  syncList();
}

function eventLineupEditorParseArtistsFromJson(panelEl) {
  const textarea = panelEl?.querySelector('.fest-info-edit [data-field="lineupArtists"]');
  const raw = String(textarea?.value || '').trim();
  if (!raw) return [];
  try {
    const parsed = JSON.parse(raw);
    if (Array.isArray(parsed)) return buildEventLineupArtistsFromArchive(parsed, []);
    if (parsed && Array.isArray(parsed.lineup_artists)) return buildEventLineupArtistsFromArchive(parsed.lineup_artists, []);
    if (parsed && Array.isArray(parsed.artists)) return buildEventLineupArtistsFromArchive(parsed.artists, []);
    if (parsed && typeof parsed === 'object') {
      const key = Object.keys(parsed).find((k) => Array.isArray(parsed[k]));
      if (key) return buildEventLineupArtistsFromArchive(parsed[key], []);
    }
  } catch (_error) {}
  return [];
}

function eventLineupEditorWriteArtists(panelEl, artists) {
  const normalized = (typeof sortEventLineupArtistsByName === 'function')
    ? sortEventLineupArtistsByName(buildEventLineupArtistsFromArchive(artists || [], []))
    : buildEventLineupArtistsFromArchive(artists || [], []);
  const textarea = panelEl?.querySelector('.fest-info-edit [data-field="lineupArtists"]');
  if (textarea) textarea.value = normalized.length ? JSON.stringify({ lineup_artists: normalized }, null, 2) : '';
  renderEventLineupArtistEditor(panelEl, normalized);
  if (typeof refreshEventLineupModalIfCurrent === 'function') refreshEventLineupModalIfCurrent();
}

function eventLineupEditorCurrentArtists(panelEl) {
  return eventLineupEditorParseArtistsFromJson(panelEl);
}

function eventLineupEditorAddArtist(panelEl, artist) {
  const djName = String(artist?.djName || artist?.name || '').trim();
  if (!djName) return false;
  const current = eventLineupEditorCurrentArtists(panelEl);
  const next = buildEventLineupArtistsFromArchive([...current, {
    djId: String(artist?.djId || artist?.id || '').trim() || undefined,
    djIds: Array.isArray(artist?.djIds) ? artist.djIds : (artist?.id ? [String(artist.id)] : []),
    djName,
    sortOrder: current.length + 1,
  }], []);
  eventLineupEditorWriteArtists(panelEl, next);
  return true;
}

function eventLineupEditorRemoveArtist(panelEl, index) {
  const current = eventLineupEditorCurrentArtists(panelEl);
  const next = current.filter((_item, idx) => idx !== Number(index)).map((item, idx) => ({ ...item, sortOrder: idx + 1 }));
  eventLineupEditorWriteArtists(panelEl, next);
}

function renderEventLineupArtistEditor(panelEl, artists = null) {
  if (!panelEl) return;
  const listEl = panelEl.querySelector('[data-lineup-artist-list]');
  if (!listEl) return;
  const rows = (typeof sortEventLineupArtistsByName === 'function')
    ? sortEventLineupArtistsByName(artists || eventLineupEditorCurrentArtists(panelEl))
    : (artists || eventLineupEditorCurrentArtists(panelEl));
  if (!rows.length) {
    listEl.innerHTML = '<div class="event-lineup-empty">暂无 DJ 阵容，可搜索 DJ 库或只添加名字。</div>';
    return;
  }
  const summaryHtml = `
    <div class="event-lineup-chip-summary">
      <span class="event-lineup-chip-summary-count">${rows.length}</span>
      <span class="event-lineup-chip-summary-label">位 DJ</span>
    </div>
  `;
  listEl.innerHTML = rows.map((artist, index) => {
    const hasBinding = !!String(artist?.djId || '').trim();
    const idText = hasBinding ? String(artist.djId).trim() : '未绑定';
    const name = String(artist?.djName || 'Unknown DJ').trim() || 'Unknown DJ';
    const avatarHtml = typeof eventLineupRenderAvatar === 'function'
      ? eventLineupRenderAvatar(name, typeof eventLineupResolveAvatarUrl === 'function' ? eventLineupResolveAvatarUrl(artist) : '', 'event-lineup-avatar')
      : '';
    return `
      <div class="event-lineup-artist-chip${hasBinding ? '' : ' is-unbound'}">
        <button class="event-lineup-artist-chip-link" type="button" data-action="${hasBinding ? 'lineup-open-profile' : 'lineup-bind-artist'}" data-index="${index}">
          ${avatarHtml}
          <div class="event-lineup-artist-chip-body">
            <span class="event-lineup-artist-name">${escapeHtml(name)}</span>
            <span class="event-lineup-artist-meta${hasBinding ? '' : ' is-unbound'}">${escapeHtml(idText)}</span>
          </div>
        </button>
        <button class="event-lineup-chip-remove" type="button" aria-label="删除 ${escapeHtml(artist.djName || 'DJ')}" data-action="lineup-remove-artist" data-index="${index}">×</button>
      </div>
    `;
  }).join('');
  listEl.innerHTML = summaryHtml + listEl.innerHTML;
}

function renderEventLineupSearchResults(panelEl, rows, query) {
  const resultsEl = panelEl?.querySelector('[data-lineup-search-results]');
  if (!resultsEl) return;
  const q = String(query || '').trim();
  if (!q) {
    resultsEl.innerHTML = '';
    return;
  }
  if (!Array.isArray(rows) || !rows.length) {
    resultsEl.innerHTML = `<div class="event-lineup-empty">DJ 库里没有找到 “${escapeHtml(q)}”，可以用右侧名字输入直接添加。</div>`;
    return;
  }
  resultsEl.innerHTML = rows.map((row, index) => `
    <button class="event-lineup-result" type="button" data-action="lineup-add-search-result" data-index="${index}">
      <span>${escapeHtml(row.name || row.id)}</span>
      <small>${escapeHtml(row.id || '')}</small>
    </button>
  `).join('');
  resultsEl._lineupSearchRows = rows;
}

async function eventLineupEditorSearchDj(panelEl) {
  const input = panelEl?.querySelector('[data-lineup-dj-search]');
  const query = String(input?.value || '').trim();
  const resultsEl = panelEl?.querySelector('[data-lineup-search-results]');
  if (!query) {
    if (resultsEl) resultsEl.innerHTML = '<div class="event-lineup-empty">请输入 DJ 名称再搜索。</div>';
    return;
  }
  if (resultsEl) resultsEl.innerHTML = '<div class="event-lineup-empty">正在搜索 DJ 库...</div>';
  try {
    const rows = await fetchEntityAssociationCandidates('dj', query, { limit: 12, headers: getViewerAuthHeaders() });
    renderEventLineupSearchResults(panelEl, rows, query);
  } catch (error) {
    if (resultsEl) resultsEl.innerHTML = `<div class="event-lineup-empty">搜索失败：${escapeHtml(String(error?.message || error))}</div>`;
  }
}

function bindEventLineupArtistEditor(panelEl, info = null) {
  if (!panelEl || panelEl.dataset.lineupEditorBound === '1') {
    renderEventLineupArtistEditor(panelEl);
    return;
  }
  panelEl.dataset.lineupEditorBound = '1';
  const textarea = panelEl.querySelector('.fest-info-edit [data-field="lineupArtists"]');
  if (textarea) {
    textarea.addEventListener('change', () => renderEventLineupArtistEditor(panelEl));
    textarea.addEventListener('blur', () => renderEventLineupArtistEditor(panelEl));
  }
  panelEl.addEventListener('click', (event) => {
    const target = event.target instanceof Element ? event.target.closest('[data-action]') : null;
    if (!target) return;
    const action = String(target.getAttribute('data-action') || '');
    if (action === 'lineup-search-dj') {
      event.preventDefault();
      void eventLineupEditorSearchDj(panelEl);
    } else if (action === 'lineup-add-name') {
      event.preventDefault();
      const input = panelEl.querySelector('[data-lineup-manual-name]');
      const name = String(input?.value || '').trim();
      if (!name) return;
      if (eventLineupEditorAddArtist(panelEl, { djName: name })) input.value = '';
    } else if (action === 'lineup-add-search-result') {
      event.preventDefault();
      const rows = panelEl.querySelector('[data-lineup-search-results]')?._lineupSearchRows || [];
      const row = rows[Number(target.getAttribute('data-index'))];
      if (row && eventLineupEditorAddArtist(panelEl, { id: row.id, djId: row.id, djName: row.name })) {
        const resultsEl = panelEl.querySelector('[data-lineup-search-results]');
        if (resultsEl) resultsEl.innerHTML = '';
      }
    } else if (action === 'lineup-open-profile') {
      event.preventDefault();
      const rows = eventLineupEditorCurrentArtists(panelEl);
      const artist = rows[Number(target.getAttribute('data-index'))];
      const djId = String(artist?.djId || '').trim();
      if (djId) void openDJProfileById(djId);
    } else if (action === 'lineup-bind-artist') {
      event.preventDefault();
      const rows = eventLineupEditorCurrentArtists(panelEl);
      const artist = rows[Number(target.getAttribute('data-index'))];
      const name = String(artist?.djName || '').trim();
      if (!name) return;
      void openDJLibraryImportModalWithOptions({
        initialName: name,
        onImported: async (dj) => {
          const current = eventLineupEditorCurrentArtists(panelEl);
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
          eventLineupEditorWriteArtists(panelEl, next);
        },
      });
    } else if (action === 'lineup-remove-artist') {
      event.preventDefault();
      eventLineupEditorRemoveArtist(panelEl, target.getAttribute('data-index'));
    }
  });
  panelEl.addEventListener('keydown', (event) => {
    if (event.key !== 'Enter') return;
    const target = event.target;
    if (!(target instanceof Element)) return;
    if (target.matches('[data-lineup-dj-search]')) {
      event.preventDefault();
      void eventLineupEditorSearchDj(panelEl);
    } else if (target.matches('[data-lineup-manual-name]')) {
      event.preventDefault();
      const name = String(target.value || '').trim();
      if (name && eventLineupEditorAddArtist(panelEl, { djName: name })) target.value = '';
    }
  });
  renderEventLineupArtistEditor(panelEl, buildEventLineupArtistsFromArchive(info?.lineupArtists || [], info?.lineup || []));
}

function setEditInputs(panelEl, info) {
  const set = (key, val) => {
    const el = panelEl.querySelector(`.fest-info-edit [data-field="${key}"]`);
    if (el) el.value = val || '';
  };
  const ensureSelectHasOption = (key, value) => {
    const selectEl = panelEl.querySelector(`.fest-info-edit [data-field="${key}"]`);
    if (!selectEl || !String(value || '').trim()) return;
    const normalizedValue = String(value).trim();
    const hasOption = Array.from(selectEl.options || []).some((opt) => String(opt.value || '').trim() === normalizedValue);
    if (hasOption) return;
    const option = document.createElement('option');
    option.value = normalizedValue;
    option.textContent = normalizedValue;
    selectEl.appendChild(option);
  };
  const nameBi = normalizeBiTextValue(info.nameI18n ?? info.name, info.name);
  const cityBi = normalizeBiTextValue(info.cityI18n ?? info.city, info.city);
  const countryBi = normalizeCountryBiTextValue(info.countryI18n ?? info.country, info.country);
  const manualLocation = (typeof normalizeFestivalManualLocation === 'function')
    ? normalizeFestivalManualLocation(info?.manualLocation || info?.manual_location || null, null)
    : (info?.manualLocation || null);
  const cityRaw = (typeof normalizeScalarText === 'function') ? normalizeScalarText(info?.city) : String(info?.city || '').trim();
  const countryRaw = (typeof normalizeScalarText === 'function') ? normalizeScalarText(info?.country) : String(info?.country || '').trim();
  const cityEn = String(cityBi.en || cityRaw || '').trim();
  const cityZh = String(cityBi.zh || cityRaw || '').trim();
  const countryEn = String(countryBi.en || countryRaw || '').trim();
  const countryEnFull = String(countryBi.enFull || countryEn || countryRaw || '').trim();
  const countryZh = String(countryBi.zh || countryRaw || '').trim();
  const detailAddressEn = String(
    manualLocation?.detailAddressI18n?.en
    || manualLocation?.formattedAddressI18n?.en
    || ''
  ).trim();
  const detailAddressZh = String(
    manualLocation?.detailAddressI18n?.zh
    || manualLocation?.formattedAddressI18n?.zh
    || detailAddressEn
  ).trim();
  set('nameEn', nameBi.en);
  set('nameZh', nameBi.zh);
  set('cityEn', cityEn);
  set('cityZh', cityZh);
  set('countryEn', countryEn);
  set('countryEnFull', countryEnFull);
  set('countryZh', countryZh);
  set('detailAddressEn', detailAddressEn);
  set('detailAddressZh', detailAddressZh);
  set('wikiFestivalId', info.wikiFestivalId || info?.wikiFestival?.id || '');
  set('wikiFestivalName', eventBrandDisplayName(info.wikiFestival || null));
  set('canceled', info.canceled ? 'true' : 'false');
  const statusValue = normalizeArchiveEventStatus(info.status, info.canceled ? 'cancelled' : 'upcoming') || (info.canceled ? 'cancelled' : 'upcoming');
  ensureSelectHasOption('status', statusValue);
  set('status', statusValue);
  const eventTypeValue = String(info.eventType || 'festival').trim() || 'festival';
  ensureSelectHasOption('eventType', eventTypeValue);
  set('eventType', eventTypeValue);
  const timeZoneValue = String(info.timeZone || info.timezone || Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC').trim() || 'UTC';
  ensureSelectHasOption('timeZone', timeZoneValue);
  set('timeZone', timeZoneValue);
  set('startDate', info.startDate);
  set('endDate', info.endDate);
  set('ticketPriceMin', info.ticketPriceMin === null || info.ticketPriceMin === undefined ? '' : String(info.ticketPriceMin));
  set('ticketPriceMax', info.ticketPriceMax === null || info.ticketPriceMax === undefined ? '' : String(info.ticketPriceMax));
  set('ticketCurrency', info.ticketCurrency || '');
  set('ticketUrl', info.ticketUrl || '');
  set('ticketNotes', info.ticketNotes || '');
  set('socialLinks', normalizeSocialLinks(info.socialLinks || []).map(x => x.url).join('\n'));
  set('relatedLinks', (info.relatedLinks||[]).join('\n'));
  const artists = buildEventLineupArtistsFromArchive(info.lineupArtists || [], info.lineup || []);
  set('lineupArtists', artists.length ? JSON.stringify({ lineup_artists: artists }, null, 2) : '');
  renderEventLineupArtistEditor(panelEl, artists);
  // Lineup: show pretty JSON if has data
  const lu = Array.isArray(info.lineup) && info.lineup.length ? info.lineup : null;
  set('lineup', lu ? JSON.stringify({ lineup_info: lu }, null, 2) : '');
  if (typeof setEventLocationDraftFromInfo === 'function') {
    setEventLocationDraftFromInfo(panelEl, info);
  } else {
    set('locationPointJson', info?.locationPoint ? JSON.stringify(info.locationPoint) : '');
  }
  ensureEventBrandBindingUI(panelEl, info);
  bindEventLineupArtistEditor(panelEl, info);
}
