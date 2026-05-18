function normalizeEntityAssociationSearchToken(value) {
  return String(value || '')
    .replace(/([A-Za-z0-9])([\u4e00-\u9fff])/g, '$1 $2')
    .replace(/([\u4e00-\u9fff])([A-Za-z0-9])/g, '$1 $2')
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();
}

function entityAssociationIdLike(value) {
  return /^[A-Za-z0-9_-]{2,}$/i.test(String(value || '').trim());
}

function entityAssociationPickBiDisplay(value, fallback = '') {
  const obj = (value && typeof value === 'object' && !Array.isArray(value)) ? value : {};
  const zh = String(obj.zh || '').trim();
  const en = String(obj.en || '').trim();
  return zh || en || String(fallback || '').trim();
}

function entityAssociationBuildRowsFromBrands(query = '', limit = 30) {
  const source = Array.isArray(brandPageState?.allItems) ? brandPageState.allItems : [];
  const key = normalizeEntityAssociationSearchToken(query);
  const rows = source
    .map((item) => {
      const id = String(item?.id || '').trim();
      const fallbackName = String(item?.name || id).trim();
      const name = entityAssociationPickBiDisplay(item?.nameI18n ?? item?.name, fallbackName);
      const aliases = Array.isArray(item?.aliases) ? item.aliases.map((x) => String(x || '').trim()).filter(Boolean) : [];
      return {
        id,
        name,
        aliases,
      };
    })
    .filter((row) => row.id && row.name)
    .sort((a, b) => String(a.name || '').localeCompare(String(b.name || ''), 'zh-Hans-CN'));
  if (!key) return rows.slice(0, limit);
  return rows
    .filter((row) => {
      const blob = [row.name].concat(row.aliases || []).join(' ');
      return normalizeEntityAssociationSearchToken(blob).includes(key);
    })
    .slice(0, limit);
}

function buildEntityAssociationSearchVariants(query) {
  const raw = String(query || '').trim();
  if (!raw) return [];
  const variants = [];
  const pushVariant = (value) => {
    const text = String(value || '').trim();
    if (!text) return;
    if (variants.includes(text)) return;
    variants.push(text);
  };
  pushVariant(raw);
  const boundarySpaced = raw
    .replace(/([A-Za-z0-9])([\u4e00-\u9fff])/g, '$1 $2')
    .replace(/([\u4e00-\u9fff])([A-Za-z0-9])/g, '$1 $2')
    .replace(/\s+/g, ' ')
    .trim();
  pushVariant(boundarySpaced);
  pushVariant(raw.replace(/\s+/g, ''));
  return variants.slice(0, 3);
}

async function fetchEntityAssociationRemoteRows(type, query, limit, headers) {
  const q = String(query || '').trim();
  if (!q) return [];

  if (type === 'dj') {
    const qs = new URLSearchParams({
      page: '1',
      limit: String(limit),
      search: q,
      sortBy: 'followerCount',
    });
    const resp = await apiGet(`/api/raver/djs?${qs.toString()}`, headers);
    const data = (resp && typeof resp === 'object' && resp.data && typeof resp.data === 'object') ? resp.data : resp;
    const items = Array.isArray(data?.items) ? data.items : [];
    return items
      .map((item) => ({
        id: String(item?.id || '').trim(),
        name: String(item?.name || '').trim(),
        aliases: Array.isArray(item?.aliases) ? item.aliases.map((x) => String(x || '').trim()).filter(Boolean) : [],
      }))
      .filter((row) => row.id && row.name);
  }

  if (type === 'event') {
    const qs = new URLSearchParams({
      page: '1',
      limit: String(limit),
      search: q,
      status: 'all',
    });
    const resp = await apiGet(`/api/raver/events?${qs.toString()}`, headers);
    const data = (resp && typeof resp === 'object' && resp.data && typeof resp.data === 'object') ? resp.data : resp;
    const items = Array.isArray(data?.items) ? data.items : [];
    return items
      .map((item) => {
        const id = String(item?.id || '').trim();
        const fallbackName = String(item?.name || id).trim();
        const name = entityAssociationPickBiDisplay(item?.nameI18n ?? item?.name, fallbackName);
        const aliases = [
          String(item?.festivalId || '').trim(),
          String(item?.archiveFestivalId || '').trim(),
          entityAssociationPickBiDisplay(item?.cityI18n ?? item?.city, String(item?.city || '').trim()),
          entityAssociationPickBiDisplay(item?.countryI18n ?? item?.country, String(item?.country || '').trim()),
        ].filter(Boolean);
        return {
          id,
          name,
          aliases: Array.from(new Set(aliases)),
        };
      })
      .filter((row) => row.id && row.name);
  }

  return [];
}

async function fetchEntityAssociationCandidates(type, query, options = {}) {
  const entityType = String(type || '').trim().toLowerCase();
  const q = String(query || '').trim();
  const limit = Math.max(1, Math.min(100, Number(options?.limit || 30) || 30));
  const headers = (options?.headers && typeof options.headers === 'object')
    ? options.headers
    : (typeof getViewerAuthHeaders === 'function' ? getViewerAuthHeaders() : {});

  if (entityType === 'brand') {
    await ensureBrandPageLoaded();
    return entityAssociationBuildRowsFromBrands(q, limit);
  }

  if (!q) return [];

  if (entityType === 'dj' || entityType === 'event') {
    const variants = buildEntityAssociationSearchVariants(q);
    const merged = [];
    const seen = new Set();
    for (const variant of variants) {
      const rows = await fetchEntityAssociationRemoteRows(entityType, variant, limit, headers);
      for (const row of rows) {
        const id = String(row?.id || '').trim();
        if (!id || seen.has(id)) continue;
        seen.add(id);
        merged.push(row);
      }
      if (merged.length >= limit) break;
    }
    return merged.slice(0, limit);
  }

  return [];
}

function resolveEntityAssociationCandidate(type, raw, candidates, options = {}) {
  const text = String(raw || '').trim();
  if (!text) return null;
  const rows = Array.isArray(candidates) ? candidates : [];
  const token = normalizeEntityAssociationSearchToken(text);
  const allowIdFallback = options?.allowIdFallback !== false;

  const directId = rows.find((row) => String(row?.id || '').trim() === text);
  if (directId) return directId;

  const pipeParts = text.split(/[|｜]/);
  if (pipeParts.length >= 2) {
    const maybeId = String(pipeParts[pipeParts.length - 1] || '').trim();
    const byId = rows.find((row) => String(row?.id || '').trim() === maybeId);
    if (byId) return byId;
    if (allowIdFallback && entityAssociationIdLike(maybeId)) {
      const leadingName = String(pipeParts.slice(0, -1).join('|') || '').trim();
      return {
        id: maybeId,
        name: leadingName || maybeId,
        aliases: [],
      };
    }
  }

  const byName = rows.find((row) => normalizeEntityAssociationSearchToken(row?.name || '') === token);
  if (byName) return byName;

  const byAlias = rows.find((row) => {
    const aliases = Array.isArray(row?.aliases) ? row.aliases : [];
    return aliases.some((alias) => normalizeEntityAssociationSearchToken(alias) === token);
  });
  if (byAlias) return byAlias;

  if (allowIdFallback && entityAssociationIdLike(text)) {
    return { id: text, name: text, aliases: [] };
  }
  return null;
}
