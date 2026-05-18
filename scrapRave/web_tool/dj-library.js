const searchInput = document.getElementById('searchInput');
const countryInput = document.getElementById('countryInput');
const sortBySelect = document.getElementById('sortBySelect');
const limitSelect = document.getElementById('limitSelect');
const verifiedSelect = document.getElementById('verifiedSelect');
const searchBtn = document.getElementById('searchBtn');
const resetBtn = document.getElementById('resetBtn');
const prevPageBtn = document.getElementById('prevPageBtn');
const nextPageBtn = document.getElementById('nextPageBtn');
const statusText = document.getElementById('statusText');
const pageInfo = document.getElementById('pageInfo');
const djList = document.getElementById('djList');
const djDetail = document.getElementById('djDetail');

const state = {
  page: 1,
  limit: 20,
  totalPages: 1,
  total: 0,
  selectedDJId: null,
  items: [],
  filters: {
    search: '',
    country: '',
    sortBy: 'followerCount',
    verified: 'all',
  },
};

function escapeHTML(s) {
  return String(s ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

function setStatus(text) {
  statusText.textContent = text || '';
}

function formatDateText(value) {
  if (!value) return '-';
  const dt = new Date(value);
  if (Number.isNaN(dt.getTime())) return '-';
  return dt.toLocaleString();
}

async function getJSON(url) {
  const resp = await fetch(url);
  const data = await resp.json().catch(() => ({}));
  if (!resp.ok) {
    throw new Error(data.error || `请求失败：${resp.status}`);
  }
  return data;
}

function buildListQuery() {
  const params = new URLSearchParams();
  params.set('page', String(state.page));
  params.set('limit', String(state.limit));
  params.set('sortBy', state.filters.sortBy);
  if (state.filters.search) params.set('search', state.filters.search);
  if (state.filters.country) params.set('country', state.filters.country);
  return params.toString();
}

function matchesVerifiedFilter(item) {
  if (state.filters.verified === 'verified') return Boolean(item.isVerified);
  if (state.filters.verified === 'unverified') return !item.isVerified;
  return true;
}

function renderAvatar(avatarUrl, name, extraClass = '') {
  if (avatarUrl) {
    return `<img class="dj-avatar ${extraClass}" src="${escapeHTML(avatarUrl)}" alt="${escapeHTML(name || '')}" loading="lazy" />`;
  }
  const initial = String(name || '?').trim().slice(0, 1).toUpperCase() || '?';
  return `<div class="dj-avatar fallback ${extraClass}">${escapeHTML(initial)}</div>`;
}

function renderList() {
  djList.innerHTML = '';
  if (!state.items.length) {
    djList.innerHTML = '<div class="meta">当前条件下没有结果。</div>';
    return;
  }

  const frag = document.createDocumentFragment();
  state.items.forEach((item) => {
    const card = document.createElement('article');
    card.className = `dj-card${state.selectedDJId === item.id ? ' selected' : ''}`;
    card.dataset.djId = item.id;

    const aliases = Array.isArray(item.aliases) ? item.aliases.slice(0, 2) : [];
    card.innerHTML = `
      ${renderAvatar(item.avatarUrl, item.name)}
      <div>
        <div class="dj-name-row">
          <span class="dj-name">${escapeHTML(item.name || '-')}</span>
          ${item.isVerified ? '<span class="dj-verified">✓</span>' : ''}
        </div>
        <div class="meta">ID: ${escapeHTML(item.id || '-')}</div>
        <div class="meta">国家: ${escapeHTML(item.country || '-')} · 粉丝: ${Number(item.followerCount || 0).toLocaleString()}</div>
        ${aliases.length ? `<div class="meta">别名: ${escapeHTML(aliases.join(' / '))}</div>` : ''}
      </div>
    `;

    card.addEventListener('click', () => selectDJ(item.id));
    frag.appendChild(card);
  });
  djList.appendChild(frag);
}

function renderPageInfo() {
  pageInfo.textContent = `第 ${state.page} / ${state.totalPages} 页 · 总计 ${state.total} 条`;
  prevPageBtn.disabled = state.page <= 1;
  nextPageBtn.disabled = state.page >= state.totalPages;
}

async function fetchList() {
  setStatus('正在加载 DJ 列表...');
  searchBtn.disabled = true;
  resetBtn.disabled = true;

  try {
    const query = buildListQuery();
    const payload = await getJSON(`/api/raver/djs?${query}`);
    const allItems = payload?.data?.items || [];
    const filteredItems = allItems.filter(matchesVerifiedFilter);
    state.items = filteredItems;
    state.total = Number(payload?.pagination?.total || 0);
    state.totalPages = Math.max(1, Number(payload?.pagination?.totalPages || 1));

    renderList();
    renderPageInfo();

    if (!state.items.length) {
      state.selectedDJId = null;
      djDetail.innerHTML = `<div class="dj-detail-body"><p class="meta">当前条件下没有结果。</p></div>`;
    } else {
      if (!state.selectedDJId || !state.items.some((item) => item.id === state.selectedDJId)) {
        state.selectedDJId = state.items[0].id;
      }
      renderList();
      await loadDJDetail(state.selectedDJId);
    }

    const postfix =
      state.filters.verified === 'all'
        ? ''
        : `（当前页按认证状态过滤后显示 ${state.items.length} 条）`;
    setStatus(`加载完成。${postfix}`);
  } catch (err) {
    state.items = [];
    renderList();
    renderPageInfo();
    state.selectedDJId = null;
    djDetail.innerHTML = `<div class="dj-detail-body"><p class="meta">加载失败。</p></div>`;
    setStatus(`加载失败：${err.message}`);
  } finally {
    searchBtn.disabled = false;
    resetBtn.disabled = false;
  }
}

function renderSets(items) {
  if (!items.length) return '<div class="meta">暂无 Sets 数据</div>';
  return `
    <div class="mini-list">
      ${items.slice(0, 8).map((item) => `
        <div class="mini-item">
          <div><strong>${escapeHTML(item.title || 'Untitled Set')}</strong></div>
          <div class="meta">上传时间: ${escapeHTML(formatDateText(item.createdAt))}</div>
          <div class="meta">点赞: ${Number(item.likeCount || 0)} · 评论: ${Number(item.commentCount || 0)}</div>
        </div>
      `).join('')}
    </div>
  `;
}

function renderEvents(items) {
  if (!items.length) return '<div class="meta">暂无关联活动</div>';
  return `
    <div class="mini-list">
      ${items.slice(0, 8).map((item) => `
        <div class="mini-item">
          <div><strong>${escapeHTML(item.name || '-')}</strong></div>
          <div class="meta">时间: ${escapeHTML(formatDateText(item.startDate))} - ${escapeHTML(formatDateText(item.endDate))}</div>
          <div class="meta">地点: ${escapeHTML([item.city, item.country].filter(Boolean).join(' / ') || '-')}</div>
        </div>
      `).join('')}
    </div>
  `;
}

function renderDJDetail(detail, sets, events) {
  const aliases = Array.isArray(detail.aliases) ? detail.aliases : [];
  const dataSources = Array.isArray(detail.dataSources)
    ? detail.dataSources
    : (typeof detail.sourceDataSource === 'string'
      ? detail.sourceDataSource.split(/[|,;]+/).map((item) => item.trim()).filter(Boolean)
      : []);
  const socialLinks = [
    detail.soundcloudUrl ? { key: 'SoundCloud', url: detail.soundcloudUrl } : null,
    detail.instagramUrl ? { key: 'Instagram', url: detail.instagramUrl } : null,
    detail.twitterUrl ? { key: 'X/Twitter', url: detail.twitterUrl } : null,
    detail.youtubeUrl ? { key: 'YouTube', url: detail.youtubeUrl } : null,
    detail.spotifyUrl ? { key: 'Spotify', url: detail.spotifyUrl } : null,
    detail.discogsUrl ? { key: 'Discogs', url: detail.discogsUrl } : null,
  ].filter(Boolean);

  const coverURL = detail.bannerUrl || detail.avatarUrl;
  djDetail.innerHTML = `
    <div class="dj-detail-cover">
      ${coverURL ? `<img src="${escapeHTML(coverURL)}" alt="${escapeHTML(detail.name || '')}" loading="lazy" />` : ''}
    </div>
    <div class="dj-detail-body">
      <div class="dj-profile">
        ${renderAvatar(detail.avatarUrl, detail.name)}
        <div>
          <div class="dj-name-row">
            <div class="dj-name">${escapeHTML(detail.name || '-')}</div>
            ${detail.isVerified ? '<span class="dj-verified">✓</span>' : ''}
          </div>
          <div class="meta">ID: ${escapeHTML(detail.id || '-')}</div>
          <div class="meta">国家: ${escapeHTML(detail.country || '-')} · 粉丝: ${Number(detail.followerCount || 0).toLocaleString()}</div>
          <div class="meta">创建时间: ${escapeHTML(formatDateText(detail.createdAt))}</div>
        </div>
      </div>

      <div class="detail-block">
        <h3 class="detail-title">基础信息</h3>
        <div class="kv-grid">
          <div class="meta">简介: ${escapeHTML(detail.bio || '暂无')}</div>
          <div class="pill-row">${aliases.map((name) => `<span class="pill">${escapeHTML(name)}</span>`).join('') || '<span class="meta">无别名</span>'}</div>
          <div class="pill-row">${dataSources.map((item) => `<span class="pill">${escapeHTML(item)}</span>`).join('') || '<span class="meta">无数据来源标记</span>'}</div>
        </div>
      </div>

      <div class="detail-block">
        <h3 class="detail-title">社交链接</h3>
        <div class="mini-list">
          ${socialLinks.length
            ? socialLinks
              .map((item) => `<div class="mini-item"><a href="${escapeHTML(item.url)}" target="_blank" rel="noreferrer">${escapeHTML(item.key)}</a></div>`)
              .join('')
            : '<div class="meta">暂无社交链接</div>'}
        </div>
      </div>

      <div class="detail-block">
        <h3 class="detail-title">关联 Sets</h3>
        ${renderSets(sets)}
      </div>

      <div class="detail-block">
        <h3 class="detail-title">关联活动</h3>
        ${renderEvents(events)}
      </div>
    </div>
  `;
}

async function loadDJDetail(djId) {
  if (!djId) return;
  state.selectedDJId = djId;
  renderList();
  djDetail.innerHTML = '<div class="dj-detail-body"><p class="meta">正在加载 DJ 详情...</p></div>';

  try {
    const [detailResp, setsResp, eventsResp] = await Promise.all([
      getJSON(`/api/raver/djs/${encodeURIComponent(djId)}`),
      getJSON(`/api/raver/djs/${encodeURIComponent(djId)}/sets`),
      getJSON(`/api/raver/djs/${encodeURIComponent(djId)}/events`),
    ]);

    const detail = detailResp?.data || {};
    const sets = setsResp?.data?.items || [];
    const events = eventsResp?.data?.items || [];
    renderDJDetail(detail, sets, events);
  } catch (err) {
    djDetail.innerHTML = `<div class="dj-detail-body"><p class="meta">详情加载失败：${escapeHTML(err.message)}</p></div>`;
  }
}

async function selectDJ(djId) {
  if (!djId) return;
  if (state.selectedDJId === djId) return;
  await loadDJDetail(djId);
}

function syncFiltersFromUI() {
  state.filters.search = searchInput.value.trim();
  state.filters.country = countryInput.value.trim();
  state.filters.sortBy = sortBySelect.value || 'followerCount';
  state.filters.verified = verifiedSelect.value || 'all';
  state.limit = Number(limitSelect.value || 20);
}

function resetFilters() {
  searchInput.value = '';
  countryInput.value = '';
  sortBySelect.value = 'followerCount';
  verifiedSelect.value = 'all';
  limitSelect.value = '20';
  syncFiltersFromUI();
  state.page = 1;
}

searchBtn.addEventListener('click', async () => {
  syncFiltersFromUI();
  state.page = 1;
  await fetchList();
});

resetBtn.addEventListener('click', async () => {
  resetFilters();
  await fetchList();
});

prevPageBtn.addEventListener('click', async () => {
  if (state.page <= 1) return;
  state.page -= 1;
  await fetchList();
});

nextPageBtn.addEventListener('click', async () => {
  if (state.page >= state.totalPages) return;
  state.page += 1;
  await fetchList();
});

searchInput.addEventListener('keydown', async (event) => {
  if (event.key !== 'Enter') return;
  event.preventDefault();
  syncFiltersFromUI();
  state.page = 1;
  await fetchList();
});

countryInput.addEventListener('keydown', async (event) => {
  if (event.key !== 'Enter') return;
  event.preventDefault();
  syncFiltersFromUI();
  state.page = 1;
  await fetchList();
});

resetFilters();
fetchList();
