// Brand admin module extracted from 00-brand-admin (model + grid + loading)
function normalizeBrandSearchText(value) {
  return String(value || '')
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .trim();
}

function normalizeBrandAliasesInput(value) {
  const raw = Array.isArray(value) ? value.join(',') : String(value || '');
  const out = [];
  const seen = new Set();
  for (const part of raw.split(/[,\uFF0C\/\u3001]/g)) {
    const text = String(part || '').trim();
    if (!text) continue;
    const key = text.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(text);
  }
  return out;
}

function normalizeBrandLinksInput(value) {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => {
      if (!item || typeof item !== 'object') return null;
      const title = String(item.title || '').trim();
      const icon = String(item.icon || '').trim() || 'link';
      const url = String(item.url || '').trim();
      if (!title || !url) return null;
      return { title, icon, url };
    })
    .filter(Boolean);
}

function parseBrandLinksTextarea(raw) {
  const text = String(raw || '').trim();
  if (!text) return [];
  let parsed;
  try {
    parsed = JSON.parse(text);
  } catch (_error) {
    throw new Error('links JSON 格式无效');
  }
  if (!Array.isArray(parsed)) {
    throw new Error('links 必须是 JSON 数组');
  }
  return normalizeBrandLinksInput(parsed);
}

function stringifyBrandLinks(links) {
  const safe = normalizeBrandLinksInput(links);
  if (!safe.length) return '';
  try {
    return JSON.stringify(safe, null, 2);
  } catch (_error) {
    return '';
  }
}

function cloneBrandItem(item) {
  if (!item || typeof item !== 'object') return null;
  const nameI18n = normalizeBiTextValue(item.nameI18n ?? item.name_i18n ?? item.name, String(item.name || '').trim());
  const countryI18n = normalizeBiTextValue(item.countryI18n ?? item.country_i18n ?? item.country, String(item.country || '').trim());
  const cityI18n = normalizeBiTextValue(item.cityI18n ?? item.city_i18n ?? item.city, String(item.city || '').trim());
  const frequencyI18n = normalizeBiTextValue(item.frequencyI18n ?? item.frequency_i18n ?? item.frequency, String(item.frequency || '').trim());
  const descriptionI18n = normalizeBiTextValue(
    item.descriptionI18n ?? item.description_i18n ?? item.introduction,
    String(item.introduction || '').trim()
  );

  return {
    id: String(item.id || '').trim(),
    name: String(nameI18n.zh || nameI18n.en || item.name || '').trim(),
    nameI18n,
    aliases: Array.isArray(item.aliases) ? item.aliases.map((x) => String(x || '').trim()).filter(Boolean) : [],
    country: String(countryI18n.zh || countryI18n.en || item.country || '').trim(),
    countryI18n,
    city: String(cityI18n.zh || cityI18n.en || item.city || '').trim(),
    cityI18n,
    foundedYear: String(item.foundedYear || '').trim(),
    frequency: String(frequencyI18n.zh || frequencyI18n.en || item.frequency || '').trim(),
    frequencyI18n,
    tagline: String(item.tagline || '').trim(),
    introduction: String(descriptionI18n.zh || descriptionI18n.en || item.introduction || '').trim(),
    descriptionI18n,
    avatarUrl: String(item.avatarUrl || '').trim(),
    backgroundUrl: String(item.backgroundUrl || '').trim(),
    links: normalizeBrandLinksInput(item.links),
    contributors: Array.isArray(item.contributors) ? item.contributors : [],
    canEdit: item.canEdit !== false,
    createdAt: item.createdAt || null,
    updatedAt: item.updatedAt || null,
  };
}

function setBrandStatus(text, isError = false) {
  const el = document.getElementById('brand-status');
  if (!el) return;
  el.textContent = String(text || '');
  el.classList.toggle('error', !!isError);
}

function setBrandEditStatus(text, level = '') {
  const el = document.getElementById('brand-edit-status');
  if (!el) return;
  el.textContent = String(text || '');
  el.classList.remove('err', 'ok');
  if (level === 'err') el.classList.add('err');
  if (level === 'ok') el.classList.add('ok');
}

function updateBrandToolbarMeta() {
  const el = document.getElementById('brand-toolbar-meta');
  if (!el) return;
  const total = Array.isArray(brandPageState.allItems) ? brandPageState.allItems.length : 0;
  const visible = Array.isArray(brandPageState.filteredItems) ? brandPageState.filteredItems.length : 0;
  el.textContent = `总计 ${total} · 当前 ${visible}`;
}

function brandMatchesSearch(item, query) {
  if (!query) return true;
  const pool = [
    item?.name,
    ...(Array.isArray(item?.aliases) ? item.aliases : []),
    item?.country,
    item?.city,
    item?.tagline,
    item?.introduction,
  ]
    .map((x) => String(x || ''))
    .join(' ');
  return normalizeBrandSearchText(pool).includes(query);
}


function onBrandSearchInputChanged(value) {
  brandPageState.searchQuery = String(value || '');
  renderBrandGrid();
}

function renderBrandGrid() {
  const grid = document.getElementById('brand-grid');
  if (!grid) return;
  const query = normalizeBrandSearchText(brandPageState.searchQuery);
  const all = Array.isArray(brandPageState.allItems) ? brandPageState.allItems : [];
  const filtered = all.filter((item) => brandMatchesSearch(item, query));
  brandPageState.filteredItems = filtered;
  updateBrandToolbarMeta();

  if (!filtered.length) {
    grid.innerHTML = '<div class="brand-empty">没有匹配品牌，尝试更换关键词。</div>';
    return;
  }

  grid.innerHTML = '';
  const frag = document.createDocumentFragment();
  for (const item of filtered) {
    const card = document.createElement('article');
    card.className = 'brand-card';
    const coverUrl = ttToAbsoluteLocalUrl(item.backgroundUrl || '');
    const avatarUrl = ttToAbsoluteLocalUrl(item.avatarUrl || '');
    const fallback = escapeHtml(String(item.name || '?').trim().charAt(0).toUpperCase() || '?');
    const metaA = [item.country, item.city].filter(Boolean).join(' · ') || '国家/城市待补充';
    const metaB = item.tagline || item.introduction || '暂无介绍';
    const aliases = Array.isArray(item.aliases) && item.aliases.length ? `别名：${item.aliases.slice(0, 3).join(' / ')}` : '别名：—';
    const editBtn = item.canEdit === false ? '只读' : '编辑';
    card.innerHTML = `
      <div class="brand-card-cover">
        ${coverUrl ? `<img src="${escapeHtml(coverUrl)}" alt="${escapeHtml(item.name || '')}" loading="lazy">` : ''}
        <div class="brand-card-avatar">
          ${avatarUrl
            ? `<img src="${escapeHtml(avatarUrl)}" alt="${escapeHtml(item.name || '')}" loading="lazy">`
            : `<div class="brand-card-avatar-fallback">${fallback}</div>`}
        </div>
      </div>
      <div class="brand-card-body">
        <div class="brand-card-name">${escapeHtml(item.name || item.id || 'Unknown Brand')}</div>
        <div class="brand-card-meta">${escapeHtml(metaA)}</div>
        <div class="brand-card-meta">${escapeHtml(metaB)}</div>
        <div class="brand-card-meta">${escapeHtml(aliases)}</div>
        <div class="brand-card-actions">
          <button class="brand-card-edit-btn" type="button">${editBtn}</button>
        </div>
      </div>
    `;
    card.addEventListener('click', () => openBrandEditorEdit(item.id));
    const btn = card.querySelector('.brand-card-edit-btn');
    if (btn) {
      btn.addEventListener('click', (event) => {
        event.stopPropagation();
        openBrandEditorEdit(item.id);
      });
    }
    frag.appendChild(card);
  }
  grid.appendChild(frag);
}

async function ensureBrandPageLoaded(force = false) {
  if (brandPageState.loading) return;
  if (brandPageState.loaded && !force) {
    renderBrandGrid();
    setBrandStatus('');
    if (currentAppPage === 'brand') setBrandHeaderCounter();
    return;
  }
  brandPageState.loading = true;
  setBrandStatus('正在加载品牌数据...');
  try {
    const resp = await apiGet('/api/raver/learn/festivals', getViewerAuthHeaders());
    const data = (resp && typeof resp === 'object' && resp.data && typeof resp.data === 'object') ? resp.data : resp;
    const items = Array.isArray(data?.items) ? data.items : [];
    brandPageState.allItems = items.map((item) => cloneBrandItem(item)).filter(Boolean);
    brandPageState.loaded = true;
    brandPageState.loadError = '';
    renderBrandGrid();
    if (eventBrandBindingState.initialized) {
      refreshEventBrandRowsFromSource();
      if (currentAppPage === 'event-brand') {
        renderEventBrandBindingTable();
      }
    }
    setBrandStatus(`已加载 ${brandPageState.allItems.length} 个品牌`);
    if (currentAppPage === 'brand') setBrandHeaderCounter();
  } catch (error) {
    brandPageState.loadError = String(error?.message || 'unknown');
    brandPageState.allItems = [];
    brandPageState.filteredItems = [];
    brandPageState.loaded = false;
    renderBrandGrid();
    if (eventBrandBindingState.initialized && currentAppPage === 'event-brand') {
      refreshEventBrandRowsFromSource();
      renderEventBrandBindingTable();
    }
    setBrandStatus(`品牌数据加载失败：${brandPageState.loadError}`, true);
  } finally {
    brandPageState.loading = false;
    updateBrandToolbarMeta();
  }
}

async function refreshBrandPage(force = false) {
  await ensureBrandPageLoaded(!!force);
}
