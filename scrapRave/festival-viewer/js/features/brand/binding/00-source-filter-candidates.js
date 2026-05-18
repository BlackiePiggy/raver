// Event-brand binding module extracted from 10-event-brand-binding (source + filters + candidates)
function setEventBrandStatus(text, level = '') {
  const el = document.getElementById('event-brand-status');
  if (!el) return;
  el.textContent = String(text || '');
  el.classList.remove('error', 'ok');
  if (level === 'error') el.classList.add('error');
  if (level === 'ok') el.classList.add('ok');
}

function normalizeEventBrandSearchQuery(value) {
  return String(value || '')
    .trim()
    .toLowerCase()
    .replace(/\s+/g, ' ');
}

function eventBrandRowKey(row) {
  return String(row?.eventId || row?.festivalId || '').trim();
}

function collectAllFestivalRows() {
  const rows = [];
  for (const [year, yearData] of Object.entries(allData || {})) {
    for (const [month, list] of Object.entries(yearData || {})) {
      for (const fest of (Array.isArray(list) ? list : [])) {
        rows.push({
          year: Number(year),
          month: Number(month),
          fest,
        });
      }
    }
  }
  return rows;
}

function buildEventBrandBindingRows() {
  const rows = collectAllFestivalRows()
    .map((entry) => {
      const fest = entry.fest || {};
      const info = fest?.info || {};
      const nameBi = normalizeBiTextValue(info.nameI18n ?? info.name ?? fest.name ?? fest.folder, fest.name || fest.folder || '');
      const wikiFestivalId = String(info.wikiFestivalId || info?.wikiFestival?.id || '').trim();
      const wikiFestival = (info.wikiFestival && typeof info.wikiFestival === 'object') ? info.wikiFestival : null;
      const fallbackBrand = wikiFestivalId
        ? (Array.isArray(brandPageState.allItems) ? brandPageState.allItems.find((item) => String(item?.id || '').trim() === wikiFestivalId) : null)
        : null;
      const brandObject = wikiFestival || fallbackBrand || null;
      const brandName = brandObject ? eventBrandDisplayName(brandObject) : '';
      return {
        eventId: String(fest?.backendEventId || info?.backendEventId || '').trim(),
        festivalId: String(info?.festivalId || fest?.folder || '').trim(),
        nameBi,
        nameDisplay: String(nameBi.zh || nameBi.en || info?.name || fest?.folder || 'Unknown Event').trim(),
        nameSearchBlob: [
          String(nameBi.zh || '').trim(),
          String(nameBi.en || '').trim(),
          String(info?.name || '').trim(),
          String(fest?.folder || '').trim(),
          String(info?.festivalId || '').trim(),
          String(info?.archiveFestivalId || '').trim(),
        ].join(' ').toLowerCase(),
        startDate: String(info?.startDate || '').trim(),
        wikiFestivalId,
        wikiFestivalName: brandName,
        wikiFestival: brandObject,
        fest,
      };
    })
    .sort((a, b) => {
      const leftDate = String(a.startDate || '');
      const rightDate = String(b.startDate || '');
      if (leftDate !== rightDate) return rightDate.localeCompare(leftDate);
      return String(a.nameDisplay || '').localeCompare(String(b.nameDisplay || ''), 'zh-Hans-CN');
    });
  return rows;
}

function eventBrandBindingMatchesFilter(row, query) {
  if (!query) return true;
  return String(row?.nameSearchBlob || '').includes(query);
}

function ensureEventBrandBindingDatalist(query = '') {
  const listId = 'event-brand-bind-datalist';
  let list = document.getElementById(listId);
  if (!list) {
    list = document.createElement('datalist');
    list.id = listId;
    document.body.appendChild(list);
  }
  const rows = eventBrandCandidatesByQuery(query).slice(0, 80);
  list.innerHTML = rows
    .map((row) => `<option value="${escapeHtml(row.name)}" label="${escapeHtml(`${row.id}${row.aliases.length ? ` · ${row.aliases.slice(0, 2).join(' / ')}` : ''}`)}"></option>`)
    .join('');
  return listId;
}

function resolveEventBrandCandidateByText(value) {
  const typed = String(value || '').trim();
  if (!typed) return null;
  const token = normalizeWikiFestivalSearchToken(typed);
  const candidates = eventBrandCandidatesByQuery(typed);
  return candidates.find((item) => (
    normalizeWikiFestivalSearchToken(item.id) === token
    || normalizeWikiFestivalSearchToken(item.name) === token
    || item.aliases.some((alias) => normalizeWikiFestivalSearchToken(alias) === token)
  )) || null;
}

function setEventBrandViewMode(mode) {
  const nextMode = (mode === 'cluster') ? 'cluster' : 'list';
  eventBrandBindingState.viewMode = nextMode;
  const listBtn = document.getElementById('event-brand-view-list-btn');
  const clusterBtn = document.getElementById('event-brand-view-cluster-btn');
  if (listBtn) listBtn.classList.toggle('active', nextMode === 'list');
  if (clusterBtn) clusterBtn.classList.toggle('active', nextMode === 'cluster');
  renderEventBrandBindingTable();
}

function updateEventBrandToolbarMeta() {
  const el = document.getElementById('event-brand-toolbar-meta');
  if (!el) return;
  const total = Array.isArray(eventBrandBindingState.allRows) ? eventBrandBindingState.allRows.length : 0;
  const visible = Array.isArray(eventBrandBindingState.filteredRows) ? eventBrandBindingState.filteredRows.length : 0;
  const selected = eventBrandBindingState.selectedEventIds instanceof Set ? eventBrandBindingState.selectedEventIds.size : 0;
  el.textContent = `总计 ${total} · 当前 ${visible} · 已选 ${selected}`;
}

function recomputeEventBrandFilteredRows() {
  const query = normalizeEventBrandSearchQuery(eventBrandBindingState.searchQuery);
  const mode = String(eventBrandBindingState.filterMode || 'all').trim();
  const source = Array.isArray(eventBrandBindingState.allRows) ? eventBrandBindingState.allRows : [];
  const filtered = source.filter((row) => {
    if (!eventBrandBindingMatchesFilter(row, query)) return false;
    const isMatched = !!String(row?.wikiFestivalId || '').trim();
    if (mode === 'matched') return isMatched;
    if (mode === 'unmatched') return !isMatched;
    return true;
  });
  eventBrandBindingState.filteredRows = filtered;
}

function updateEventBrandRowSelection(row, checked) {
  const key = eventBrandRowKey(row);
  if (!key) return;
  if (checked) eventBrandBindingState.selectedEventIds.add(key);
  else eventBrandBindingState.selectedEventIds.delete(key);
  updateEventBrandToolbarMeta();
}

