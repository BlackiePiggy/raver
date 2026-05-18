async function buildRankingEntityCatalog(entityType) {
  if (entityType === 'festival') {
    await ensureBrandPageLoaded();
    const source = Array.isArray(brandPageState.allItems) ? brandPageState.allItems : [];
    return source
      .map((item) => ({
        id: String(item?.id || '').trim(),
        name: String(item?.name || '').trim(),
        aliases: Array.isArray(item?.aliases) ? item.aliases.map((x) => String(x || '').trim()).filter(Boolean) : [],
      }))
      .filter((item) => item.id && item.name)
      .sort((a, b) => a.name.localeCompare(b.name));
  }
  await ensureDJLibraryLoaded();
  const source = Array.isArray(djLibraryState.allItems) ? djLibraryState.allItems : [];
  return source
    .map((item) => ({
      id: String(item?.id || '').trim(),
      name: String(item?.name || '').trim(),
      aliases: Array.isArray(item?.aliases) ? item.aliases.map((x) => String(x || '').trim()).filter(Boolean) : [],
    }))
    .filter((item) => item.id && item.name)
    .sort((a, b) => a.name.localeCompare(b.name));
}

function rankingEntityDisplayById(entityId, catalog) {
  const id = String(entityId || '').trim();
  if (!id) return '';
  const hit = (Array.isArray(catalog) ? catalog : []).find((item) => String(item?.id || '') === id);
  if (!hit) return id;
  return `${hit.name} | ${hit.id}`;
}

function parseRankingEntityInputToId(rawValue, catalog) {
  const raw = String(rawValue || '').trim();
  if (!raw) return '';
  const candidates = [
    ...(Array.isArray(catalog) ? catalog : []),
    ...(Array.isArray(rankingPageState.entriesEditorSearchResults) ? rankingPageState.entriesEditorSearchResults : []),
  ];

  // 1) Exact ID match first (supports short IDs and underscores).
  const exactIdHit = candidates.find((item) => String(item?.id || '').trim() === raw);
  if (exactIdHit?.id) return String(exactIdHit.id).trim();

  // 2) If input is "Name | ID", parse trailing ID token by delimiter.
  const pipeParts = raw.split('|');
  if (pipeParts.length >= 2) {
    const trailing = String(pipeParts[pipeParts.length - 1] || '').trim();
    if (trailing) {
      const byTrailingId = candidates.find((item) => String(item?.id || '').trim() === trailing);
      if (byTrailingId?.id) return String(byTrailingId.id).trim();
      // Accept canonical id-like token even if catalog misses it (fallback).
      if (/^[A-Za-z0-9_-]{2,}$/i.test(trailing)) return trailing;
    }
  }

  // 3) Generic ID-like token fallback (UUID / slug / short code).
  if (/^[A-Za-z0-9_-]{2,}$/i.test(raw)) return raw;

  const normalized = normalizeRankingEntitySearchKey(raw);
  const hit = candidates.find((item) => {
    const name = normalizeRankingEntitySearchKey(item?.name || '');
    if (name && name === normalized) return true;
    const aliases = Array.isArray(item?.aliases) ? item.aliases : [];
    return aliases.some((alias) => normalizeRankingEntitySearchKey(alias) === normalized);
  });
  return String(hit?.id || '').trim();
}

function autoBindRankingRowsByName(rows, catalog) {
  const sourceRows = Array.isArray(rows) ? rows : [];
  const sourceCatalog = Array.isArray(catalog) ? catalog : [];
  const directNameMap = new Map();
  const aliasMap = new Map();
  for (const item of sourceCatalog) {
    const id = String(item?.id || '').trim();
    const name = String(item?.name || '').trim();
    if (!id || !name) continue;
    const normalizedName = normalizeRankingEntitySearchKey(name);
    if (!directNameMap.has(normalizedName)) directNameMap.set(normalizedName, id);
    const aliases = Array.isArray(item?.aliases) ? item.aliases : [];
    for (const alias of aliases) {
      const normalizedAlias = normalizeRankingEntitySearchKey(alias);
      if (!normalizedAlias || aliasMap.has(normalizedAlias)) continue;
      aliasMap.set(normalizedAlias, id);
    }
  }

  let matched = 0;
  let unmatched = 0;
  const nextRows = sourceRows.map((row) => {
    const name = String(row?.name || '').trim();
    const currentEntityId = String(row?.entityId || '').trim();
    if (currentEntityId) {
      matched += 1;
      return { ...row, autoBound: true };
    }
    const key = normalizeRankingEntitySearchKey(name);
    const byName = directNameMap.get(key) || aliasMap.get(key) || '';
    if (byName) {
      matched += 1;
      return { ...row, entityId: byName, autoBound: true };
    }
    unmatched += 1;
    return { ...row, entityId: '', autoBound: false };
  });
  return { rows: nextRows, matched, unmatched };
}

function normalizeRankingEntitySearchKey(value) {
  return String(value || '')
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9\u4e00-\u9fa5]+/g, ' ')
    .trim()
    .replace(/\s+/g, ' ');
}

function refreshRankingEntityDatalist(catalog) {
  const datalist = document.getElementById('ranking-entity-datalist');
  if (!datalist) return;
  const rows = Array.isArray(catalog) ? catalog : [];
  datalist.innerHTML = rows
    .slice(0, 4000)
    .map((item) => `<option value="${escapeHtml(`${item.name} | ${item.id}`)}"></option>`)
    .join('');
}

async function fetchRankingEntitySearchCandidates(query) {
  const board = getActiveRankingBoard();
  if (!board) return [];
  const q = String(query || '').trim();
  if (!q) return Array.isArray(rankingPageState.entriesEditorCatalog) ? rankingPageState.entriesEditorCatalog.slice(0, 200) : [];

  if (board.entityType === 'dj') {
    return fetchEntityAssociationCandidates('dj', q, {
      headers: getViewerAuthHeaders(),
      limit: 30,
    });
  }

  if (board.entityType === 'festival') {
    return fetchEntityAssociationCandidates('brand', q, {
      headers: getViewerAuthHeaders(),
      limit: 50,
    });
  }

  const source = Array.isArray(rankingPageState.entriesEditorCatalog) ? rankingPageState.entriesEditorCatalog : [];
  const key = normalizeRankingEntitySearchKey(q);
  return source
    .filter((item) => {
      const nameKey = normalizeRankingEntitySearchKey(item?.name || '');
      if (nameKey.includes(key)) return true;
      const aliases = Array.isArray(item?.aliases) ? item.aliases : [];
      return aliases.some((alias) => normalizeRankingEntitySearchKey(alias).includes(key));
    })
    .slice(0, 50);
}

function scheduleRankingEntitySearch(query) {
  const q = String(query || '').trim();
  rankingPageState.entriesEditorSearchQuery = q;
  if (rankingPageState.entriesEditorSearchTimer) {
    clearTimeout(rankingPageState.entriesEditorSearchTimer);
    rankingPageState.entriesEditorSearchTimer = null;
  }
  const seq = Number(rankingPageState.entriesEditorSearchSeq || 0) + 1;
  rankingPageState.entriesEditorSearchSeq = seq;
  rankingPageState.entriesEditorSearchTimer = setTimeout(async () => {
    try {
      const results = await fetchRankingEntitySearchCandidates(q);
      if (rankingPageState.entriesEditorSearchSeq !== seq) return;
      rankingPageState.entriesEditorSearchResults = results;
      refreshRankingEntityDatalist(results.length > 0 ? results : rankingPageState.entriesEditorCatalog);
    } catch (_error) {
      if (rankingPageState.entriesEditorSearchSeq !== seq) return;
      rankingPageState.entriesEditorSearchResults = [];
      refreshRankingEntityDatalist(rankingPageState.entriesEditorCatalog);
    }
  }, 180);
}

function onRankingEntityInputFocus(_index, value) {
  scheduleRankingEntitySearch(value || '');
}

function onRankingEntityInputChanged(_index, value) {
  scheduleRankingEntitySearch(value || '');
}
