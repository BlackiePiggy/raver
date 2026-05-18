// UI archive module extracted from 50-ui-render (filter panels + matching)
function normalizeCountryFilterKey(value) {
  return String(value || '')
    .trim()
    .replace(/\s+/g, ' ')
    .toLowerCase();
}

function getFestivalCountryFilterMeta(fest) {
  const info = fest?.info || {};
  const countryBi = normalizeBiTextValue(info.countryI18n ?? info.country ?? '', String(info.country || '').trim());
  const zh = String(countryBi.zh || '').trim();
  const en = String(countryBi.en || '').trim();
  const label = (zh && en && zh !== en) ? `${zh} / ${en}` : (zh || en || '未知');
  const key = normalizeCountryFilterKey(en || zh || '');
  return { key, label };
}

function collectCountryFilterOptions() {
  const map = new Map();
  for (const yearData of Object.values(allData || {})) {
    for (const list of Object.values(yearData || {})) {
      for (const fest of (Array.isArray(list) ? list : [])) {
        const meta = getFestivalCountryFilterMeta(fest);
        if (!meta.key) continue;
        const prev = map.get(meta.key) || { key: meta.key, label: meta.label, count: 0 };
        prev.count += 1;
        if (!prev.label || prev.label === '未知') prev.label = meta.label;
        map.set(meta.key, prev);
      }
    }
  }
  return Array.from(map.values()).sort((a, b) => a.label.localeCompare(b.label, 'zh-Hans-CN'));
}

function normalizeEventTypeFilterKey(value) {
  return String(value || '')
    .trim()
    .replace(/\s+/g, ' ')
    .toLowerCase();
}

function eventTypeLabelForKey(key) {
  const normalized = normalizeEventTypeFilterKey(key);
  if (!normalized) return '未设置';
  const knownLabels = {
    festival: 'Festival',
    concert: 'Concert',
    rave: 'Rave',
    party: 'Party',
    club: 'Club',
    showcase: 'Showcase',
    tour: 'Tour',
    other: 'Other',
  };
  if (knownLabels[normalized]) return knownLabels[normalized];
  return normalized
    .split(/[\s_-]+/)
    .filter(Boolean)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ');
}

function getFestivalEventTypeFilterMeta(fest) {
  const info = fest?.info || {};
  const rawKey = normalizeEventTypeFilterKey(info.eventType);
  const key = rawKey || '__unknown__';
  const label = rawKey ? eventTypeLabelForKey(rawKey) : '未设置';
  return { key, label };
}

function collectEventTypeFilterOptions() {
  const map = new Map();
  for (const yearData of Object.values(allData || {})) {
    for (const list of Object.values(yearData || {})) {
      for (const fest of (Array.isArray(list) ? list : [])) {
        const meta = getFestivalEventTypeFilterMeta(fest);
        if (!meta.key) continue;
        const prev = map.get(meta.key) || { key: meta.key, label: meta.label, count: 0 };
        prev.count += 1;
        map.set(meta.key, prev);
      }
    }
  }
  return Array.from(map.values()).sort((a, b) => a.label.localeCompare(b.label, 'en'));
}

function setCountryFilterPanelOpen(open) {
  const panel = document.getElementById('country-filter-panel');
  if (!panel) return;
  panel.classList.toggle('open', !!open);
}

function setEventTypeFilterPanelOpen(open) {
  const panel = document.getElementById('event-type-filter-panel');
  if (!panel) return;
  panel.classList.toggle('open', !!open);
}

function renderCountryFilterOptions() {
  const triggerEl = document.getElementById('country-filter-trigger');
  const optionsEl = document.getElementById('country-filter-options');
  if (!triggerEl || !optionsEl) return;

  const options = collectCountryFilterOptions();
  const optionKeys = new Set(options.map((item) => item.key));
  activeCountryFilterKeys = new Set([...activeCountryFilterKeys].filter((key) => optionKeys.has(key)));
  const selectedCount = activeCountryFilterKeys.size;
  triggerEl.textContent = selectedCount > 0 ? `国家筛选 (${selectedCount})` : '国家筛选';

  if (!options.length) {
    optionsEl.innerHTML = '<div class="country-filter-empty">暂无可筛选国家</div>';
    return;
  }

  optionsEl.innerHTML = options.map((item) => `
    <label class="country-filter-item">
      <input type="checkbox" data-country-key="${escapeHtml(item.key)}" ${activeCountryFilterKeys.has(item.key) ? 'checked' : ''}>
      <span class="country-label">${escapeHtml(item.label)}</span>
      <span class="country-count">${item.count}</span>
    </label>
  `).join('');
}

function renderEventTypeFilterOptions() {
  const triggerEl = document.getElementById('event-type-filter-trigger');
  const optionsEl = document.getElementById('event-type-filter-options');
  if (!triggerEl || !optionsEl) return;

  const options = collectEventTypeFilterOptions();
  const optionKeys = new Set(options.map((item) => item.key));
  activeEventTypeFilterKeys = new Set([...activeEventTypeFilterKeys].filter((key) => optionKeys.has(key)));
  const selectedCount = activeEventTypeFilterKeys.size;
  triggerEl.textContent = selectedCount > 0 ? `活动类型筛选 (${selectedCount})` : '活动类型筛选';

  if (!options.length) {
    optionsEl.innerHTML = '<div class="country-filter-empty">暂无可筛选活动类型</div>';
    return;
  }

  optionsEl.innerHTML = options.map((item) => `
    <label class="country-filter-item">
      <input type="checkbox" data-event-type-key="${escapeHtml(item.key)}" ${activeEventTypeFilterKeys.has(item.key) ? 'checked' : ''}>
      <span class="country-label">${escapeHtml(item.label)}</span>
      <span class="country-count">${item.count}</span>
    </label>
  `).join('');
}

function bindCountryFilterHandlers() {
  if (countryFilterHandlersBound) return;
  const wrapEl = document.getElementById('country-filter-wrap');
  const triggerEl = document.getElementById('country-filter-trigger');
  const panelEl = document.getElementById('country-filter-panel');
  const clearEl = document.getElementById('country-filter-clear');
  const optionsEl = document.getElementById('country-filter-options');
  if (!wrapEl || !triggerEl || !panelEl || !clearEl || !optionsEl) return;

  triggerEl.addEventListener('click', (event) => {
    event.stopPropagation();
    setCountryFilterPanelOpen(!panelEl.classList.contains('open'));
  });
  panelEl.addEventListener('click', (event) => event.stopPropagation());
  optionsEl.addEventListener('change', (event) => {
    const checkbox = event.target.closest('input[data-country-key]');
    if (!checkbox) return;
    const key = normalizeCountryFilterKey(checkbox.getAttribute('data-country-key') || '');
    if (!key) return;
    if (checkbox.checked) activeCountryFilterKeys.add(key);
    else activeCountryFilterKeys.delete(key);
    renderCountryFilterOptions();
    renderYear();
  });
  clearEl.addEventListener('click', (event) => {
    event.preventDefault();
    activeCountryFilterKeys.clear();
    renderCountryFilterOptions();
    renderYear();
  });
  document.addEventListener('click', (event) => {
    if (!wrapEl.contains(event.target)) setCountryFilterPanelOpen(false);
  });
  countryFilterHandlersBound = true;
}

function bindEventTypeFilterHandlers() {
  if (eventTypeFilterHandlersBound) return;
  const wrapEl = document.getElementById('event-type-filter-wrap');
  const triggerEl = document.getElementById('event-type-filter-trigger');
  const panelEl = document.getElementById('event-type-filter-panel');
  const clearEl = document.getElementById('event-type-filter-clear');
  const optionsEl = document.getElementById('event-type-filter-options');
  if (!wrapEl || !triggerEl || !panelEl || !clearEl || !optionsEl) return;

  triggerEl.addEventListener('click', (event) => {
    event.stopPropagation();
    setEventTypeFilterPanelOpen(!panelEl.classList.contains('open'));
  });
  panelEl.addEventListener('click', (event) => event.stopPropagation());
  optionsEl.addEventListener('change', (event) => {
    const checkbox = event.target.closest('input[data-event-type-key]');
    if (!checkbox) return;
    const key = normalizeEventTypeFilterKey(checkbox.getAttribute('data-event-type-key') || '');
    if (!key) return;
    if (checkbox.checked) activeEventTypeFilterKeys.add(key);
    else activeEventTypeFilterKeys.delete(key);
    renderEventTypeFilterOptions();
    renderYear();
  });
  clearEl.addEventListener('click', (event) => {
    event.preventDefault();
    activeEventTypeFilterKeys.clear();
    renderEventTypeFilterOptions();
    renderYear();
  });
  document.addEventListener('click', (event) => {
    if (!wrapEl.contains(event.target)) setEventTypeFilterPanelOpen(false);
  });
  eventTypeFilterHandlersBound = true;
}

function festivalMatchesSearchQuery(fest, query) {
  const target = String(query || '').trim().toLowerCase();
  if (!target) return true;
  const info = fest?.info || {};
  const nameBi = normalizeBiTextValue(info.nameI18n ?? info.name ?? fest?.name ?? '', fest?.name || '');
  const locationBi = normalizeBiTextValue(info.locationI18n ?? info.location ?? fest?.location ?? '', fest?.location || '');
  const corpus = [
    fest?.name,
    fest?.location,
    fest?.folder,
    info?.name,
    info?.location,
    nameBi.en,
    nameBi.zh,
    locationBi.en,
    locationBi.zh,
  ]
    .filter(Boolean)
    .join(' ')
    .toLowerCase();
  return corpus.includes(target);
}

function festivalMatchesArchiveFilters(fest) {
  if (!festivalMatchesSearchQuery(fest, searchQuery)) return false;
  if (!festivalMatchesSearchQuery(fest, globalSearchQuery)) return false;
  if (activeCountryFilterKeys.size > 0) {
    const countryKey = getFestivalCountryFilterMeta(fest).key;
    if (!countryKey || !activeCountryFilterKeys.has(countryKey)) return false;
  }
  if (activeEventTypeFilterKeys.size > 0) {
    const eventTypeKey = getFestivalEventTypeFilterMeta(fest).key;
    if (!eventTypeKey || !activeEventTypeFilterKeys.has(eventTypeKey)) return false;
  }
  return true;
}

function escapeHtml(str) {
  return String(str ?? '').replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;').replaceAll("'","&#39;");
}
