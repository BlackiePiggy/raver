// Feature module extracted from monolith (ranking dashboard)
function setRankingStatus(text, isError = false) {
  const el = document.getElementById('ranking-status');
  if (!el) return;
  el.textContent = String(text || '');
  el.classList.toggle('error', !!isError);
}

function updateRankingToolbarMeta() {
  const el = document.getElementById('ranking-toolbar-meta');
  if (!el) return;
  const board = (rankingPageState.boards || []).find((item) => item.id === rankingPageState.activeBoardId) || null;
  const boardTitle = board?.title || '-';
  const boardType = board?.entityType === 'festival' ? 'Brand' : 'DJ';
  const year = rankingPageState.activeYear || '-';
  const count = Array.isArray(rankingPageState.entries) ? rankingPageState.entries.length : 0;
  el.textContent = `${boardTitle} · ${boardType} · ${year} · ${count} 条`;
}

function renderRankingBoardSummary() {
  const el = document.getElementById('ranking-board-summary');
  if (!el) return;
  const board = getActiveRankingBoard();
  if (!board) {
    el.classList.remove('open');
    el.innerHTML = '';
    return;
  }
  const coverUrl = ttToAbsoluteLocalUrl(String(board.coverImageUrl || '').trim());
  const subtitle = String(board.subtitle || '').trim();
  const description = String(board.description || '').trim();
  if (!coverUrl && !subtitle && !description) {
    el.classList.remove('open');
    el.innerHTML = '';
    return;
  }
  el.classList.add('open');
  const descText = description;
  el.innerHTML = `
    <div class="ranking-board-summary-cover">
      ${coverUrl ? `<img src="${escapeHtml(coverUrl)}" alt="${escapeHtml(board.title || board.id || '')}" loading="lazy">` : '<div class="ranking-entry-avatar-fallback">RANK</div>'}
    </div>
    <div class="ranking-board-summary-meta">
      <div class="ranking-board-summary-title">${escapeHtml(String(board.title || board.id || ''))}</div>
      ${subtitle ? `<div class="ranking-board-summary-sub">${escapeHtml(subtitle)}</div>` : ''}
      ${descText ? `<div class="ranking-board-summary-sub">${escapeHtml(descText)}</div>` : ''}
    </div>
  `;
}

function getActiveRankingBoard() {
  const boards = Array.isArray(rankingPageState.boards) ? rankingPageState.boards : [];
  return boards.find((item) => item.id === rankingPageState.activeBoardId) || boards[0] || null;
}

function renderRankingBoardStrip() {
  const strip = document.getElementById('ranking-board-strip');
  if (!strip) return;
  const boards = Array.isArray(rankingPageState.boards) ? rankingPageState.boards : [];
  strip.innerHTML = '';
  if (!boards.length) return;
  const frag = document.createDocumentFragment();
  for (const board of boards) {
    const btn = document.createElement('button');
    btn.className = `ranking-board-chip${board.id === rankingPageState.activeBoardId ? ' active' : ''}`;
    btn.type = 'button';
    btn.textContent = String(board.title || board.id || '').trim() || board.id;
    btn.addEventListener('click', () => {
      onRankingBoardChanged(board.id);
    });
    frag.appendChild(btn);
  }
  strip.appendChild(frag);
}

function renderRankingYearSelect() {
  const select = document.getElementById('ranking-year-select');
  const strip = document.getElementById('ranking-year-strip');
  if (!select && !strip) return;
  const board = getActiveRankingBoard();
  const years = (Array.isArray(board?.years) ? board.years.slice() : [])
    .map((year) => Number(year))
    .filter((year) => Number.isFinite(year))
    .sort((a, b) => Number(b) - Number(a));
  if (select) select.innerHTML = '';
  if (strip) strip.innerHTML = '';
  if (!years.length) {
    if (select) {
      const option = document.createElement('option');
      option.value = '';
      option.textContent = '无年份';
      select.appendChild(option);
    }
    if (strip) {
      const empty = document.createElement('div');
      empty.className = 'ranking-year-empty';
      empty.textContent = '暂无年份';
      strip.appendChild(empty);
    }
    return;
  }
  if (!years.includes(Number(rankingPageState.activeYear))) {
    rankingPageState.activeYear = years[0];
  }
  years.forEach((year) => {
    if (select) {
      const option = document.createElement('option');
      option.value = String(year);
      option.textContent = String(year);
      if (Number(year) === Number(rankingPageState.activeYear)) {
        option.selected = true;
      }
      select.appendChild(option);
    }
    if (strip) {
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = `ranking-year-chip${Number(year) === Number(rankingPageState.activeYear) ? ' active' : ''}`;
      btn.textContent = String(year);
      btn.addEventListener('click', () => onRankingYearChanged(year));
      strip.appendChild(btn);
    }
  });
}

function renderRankingGrid() {
  const grid = document.getElementById('ranking-grid');
  if (!grid) return;
  const board = getActiveRankingBoard();
  const isFestivalBoard = board?.entityType === 'festival';
  const entries = Array.isArray(rankingPageState.entries) ? rankingPageState.entries : [];
  if (!entries.length) {
    grid.innerHTML = '<div class="brand-empty">当前榜单暂无数据。</div>';
    return;
  }
  grid.innerHTML = '';
  const frag = document.createDocumentFragment();
  for (const entry of entries) {
    const rank = Number(entry?.rank || 0) || '-';
    const dj = entry?.dj && typeof entry.dj === 'object' ? entry.dj : null;
    const festival = entry?.festival && typeof entry.festival === 'object' ? entry.festival : null;
    const name = String(entry?.name || festival?.name || dj?.name || '').trim() || 'Unknown';
    const avatarUrl = ttToAbsoluteLocalUrl(
      String((isFestivalBoard ? (festival?.backgroundUrl || festival?.avatarUrl || '') : (dj?.avatarUrl || ''))).trim()
    );
    const followerText = Number.isFinite(Number(dj?.followerCount))
      ? Number(dj?.followerCount || 0).toLocaleString()
      : '-';
    const delta = Number(entry?.delta);
    const deltaText = Number.isFinite(delta)
      ? (delta > 0 ? `↑ ${delta}` : (delta < 0 ? `↓ ${Math.abs(delta)}` : '→ 0'))
      : 'NEW';
    const locationText = [festival?.country, festival?.city].filter(Boolean).join(' · ') || '国家未知';
    const hasLinkedEntity = Boolean(dj?.id || festival?.id);

    const card = document.createElement('article');
    card.className = `ranking-entry-card${hasLinkedEntity ? '' : ' no-media'}`;
    const mediaHtml = hasLinkedEntity
      ? `<div class="ranking-entry-avatar">
          ${avatarUrl
            ? `<img src="${escapeHtml(avatarUrl)}" alt="${escapeHtml(name)}" loading="lazy">`
            : `<div class="ranking-entry-avatar-fallback">${escapeHtml(String(name).charAt(0).toUpperCase() || '?')}</div>`}
        </div>`
      : '';
    card.innerHTML = `
      <div class="ranking-entry-rank">#${escapeHtml(rank)}</div>
      ${mediaHtml}
      <div class="ranking-entry-body">
        <div class="ranking-entry-name">${escapeHtml(name)}</div>
        <div class="ranking-entry-meta">${escapeHtml(String(isFestivalBoard ? locationText : (dj?.country || '国家未知')))}</div>
        <div class="ranking-entry-meta">${
          isFestivalBoard
            ? `变化: ${escapeHtml(deltaText)}`
            : `Followers: ${escapeHtml(followerText)} · ${escapeHtml(deltaText)}`
        }</div>
      </div>
    `;
    if (dj?.id) {
      card.addEventListener('click', () => openDJProfileById(dj.id));
    } else if (festival?.id) {
      card.addEventListener('click', async () => {
        await ensureBrandPageLoaded();
        switchAppPage('brand');
        openBrandEditorEdit(festival.id);
      });
    } else {
      card.style.cursor = 'default';
    }
    frag.appendChild(card);
  }
  grid.appendChild(frag);
}

function renderRankingPage() {
  renderRankingBoardStrip();
  renderRankingYearSelect();
  renderRankingBoardSummary();
  renderRankingGrid();
  updateRankingToolbarMeta();
  if (currentAppPage === 'ranking') setRankingHeaderCounter();
}

async function loadRankingEntries() {
  const board = getActiveRankingBoard();
  if (!board) {
    rankingPageState.entries = [];
    renderRankingPage();
    setRankingStatus('暂无榜单配置');
    return;
  }
  const years = Array.isArray(board.years) ? board.years : [];
  if (!years.length) {
    rankingPageState.entries = [];
    renderRankingPage();
    setRankingStatus('当前榜单暂无年份数据');
    return;
  }
  if (!years.includes(Number(rankingPageState.activeYear))) {
    rankingPageState.activeYear = years.slice().sort((a, b) => Number(b) - Number(a))[0];
  }
  rankingPageState.loadingEntries = true;
  renderRankingPage();
  setRankingStatus(`正在加载 ${board.title} ${rankingPageState.activeYear}...`);
  try {
    const qs = new URLSearchParams({ year: String(rankingPageState.activeYear) });
    const resp = await apiGet(`/api/raver/learn/rankings/${encodeURIComponent(board.id)}?${qs.toString()}`, getViewerAuthHeaders());
    const data = (resp && typeof resp === 'object' && resp.data && typeof resp.data === 'object') ? resp.data : resp;
    rankingPageState.entries = Array.isArray(data?.entries) ? data.entries : [];
    if (Number.isFinite(Number(data?.year))) {
      rankingPageState.activeYear = Number(data.year);
    }
    if (Array.isArray(data?.years) && data.years.length) {
      board.years = data.years;
    }
    rankingPageState.loaded = true;
    rankingPageState.loadError = '';
    renderRankingPage();
    setRankingStatus(`已加载 ${rankingPageState.entries.length} 条榜单数据`);
  } catch (error) {
    rankingPageState.entries = [];
    rankingPageState.loadError = String(error?.message || 'unknown');
    renderRankingPage();
    setRankingStatus(`榜单数据加载失败：${rankingPageState.loadError}`, true);
  } finally {
    rankingPageState.loadingEntries = false;
  }
}

async function ensureRankingPageLoaded(force = false) {
  if (rankingPageState.loadingBoards) return;
  if (rankingPageState.loaded && !force && rankingPageState.boards.length) {
    renderRankingPage();
    return;
  }
  rankingPageState.loadingBoards = true;
  setRankingStatus('正在加载榜单列表...');
  try {
    const resp = await apiGet('/api/raver/learn/rankings', getViewerAuthHeaders());
    const rows = Array.isArray(resp?.data)
      ? resp.data
      : (Array.isArray(resp) ? resp : []);
    rankingPageState.boards = rows.map((item) => ({
      id: String(item?.id || '').trim(),
      title: String(item?.title || '').trim() || String(item?.id || '').trim(),
      subtitle: String(item?.subtitle || '').trim(),
      description: String(item?.description || '').trim(),
      coverImageUrl: String(item?.coverImageUrl || '').trim(),
      entityType: String(item?.entityType || '').trim() === 'festival' ? 'festival' : 'dj',
      years: Array.isArray(item?.years)
        ? item.years.map((x) => Number(x)).filter((x) => Number.isFinite(x))
        : [],
      createdAt: String(item?.createdAt || '').trim(),
      updatedAt: String(item?.updatedAt || '').trim(),
    })).filter((item) => !!item.id);
    if (!rankingPageState.boards.length) {
      rankingPageState.activeBoardId = '';
      rankingPageState.activeYear = null;
      rankingPageState.entries = [];
      rankingPageState.loaded = true;
      renderRankingPage();
      setRankingStatus('暂无榜单数据');
      return;
    }
    if (!rankingPageState.boards.some((item) => item.id === rankingPageState.activeBoardId)) {
      rankingPageState.activeBoardId = rankingPageState.boards[0].id;
      rankingPageState.activeYear = null;
    }
    await loadRankingEntries();
  } catch (error) {
    rankingPageState.loaded = false;
    rankingPageState.loadError = String(error?.message || 'unknown');
    setRankingStatus(`榜单列表加载失败：${rankingPageState.loadError}`, true);
  } finally {
    rankingPageState.loadingBoards = false;
    updateRankingToolbarMeta();
  }
}

async function refreshRankingPage(force = false) {
  await ensureRankingPageLoaded(!!force);
}
