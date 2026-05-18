// Feature module extracted from monolith (timetable bind core)
function ttNormalizeDJNameKey(name) {
  return String(name || '')
    .trim()
    .toLowerCase()
    .replace(/\s+/g, ' ');
}

function ttChoosePreferredDJ(current, candidate) {
  if (!current) return candidate;
  const currentHasAvatar = !!String(current?.avatarUrl || '').trim();
  const candidateHasAvatar = !!String(candidate?.avatarUrl || '').trim();
  if (!currentHasAvatar && candidateHasAvatar) return candidate;
  const currentVerified = !!current?.isVerified;
  const candidateVerified = !!candidate?.isVerified;
  if (!currentVerified && candidateVerified) return candidate;
  return current;
}

function ttBuildDJMatchMap(items) {
  const map = new Map();
  for (const item of (Array.isArray(items) ? items : [])) {
    const id = String(item?.id || '').trim();
    if (!id) continue;
    const keys = new Set();
    const nameKey = ttNormalizeDJNameKey(item?.name || '');
    if (nameKey) keys.add(nameKey);
    const aliases = Array.isArray(item?.aliases) ? item.aliases : [];
    aliases.forEach((alias) => {
      const aliasKey = ttNormalizeDJNameKey(alias);
      if (aliasKey) keys.add(aliasKey);
    });
    keys.forEach((key) => {
      const current = map.get(key) || null;
      map.set(key, ttChoosePreferredDJ(current, item));
    });
  }
  return map;
}

function ttRebuildDJMatchMapFromState() {
  ttDjMatchMap = ttBuildDJMatchMap(djLibraryState.allItems || []);
  const byId = new Map();
  for (const item of (Array.isArray(djLibraryState.allItems) ? djLibraryState.allItems : [])) {
    const id = String(item?.id || '').trim();
    if (!id || byId.has(id)) continue;
    byId.set(id, item);
  }
  ttDjByIdMap = byId;
}

async function ensureTtDJMatchMapLoaded(force = false) {
  if (ttDjMatchLoading) return;
  if (ttDjMatchLoaded && !force) return;
  ttDjMatchLoading = true;
  try {
    if (!force && djLibraryState.allItemsComplete && Array.isArray(djLibraryState.allItems) && djLibraryState.allItems.length) {
      ttRebuildDJMatchMapFromState();
      ttDjMatchLoaded = true;
      return;
    }
    const items = await fetchAllDJItems();
    if (Array.isArray(items)) {
      djLibraryState.allItems = items;
      djLibraryState.allItemsComplete = true;
      djLibraryState.loaded = true;
      ttRebuildDJMatchMapFromState();
      ttDjMatchLoaded = true;
    }
  } catch (error) {
    console.warn('tt dj match preload failed:', error);
  } finally {
    ttDjMatchLoading = false;
  }
}

function ttFindMatchedDJByMusicianName(name) {
  if (!ttDjMatchLoaded) return null;
  const key = ttNormalizeDJNameKey(name);
  if (!key) return null;
  return ttDjMatchMap.get(key) || null;
}

function ttDJMatchesPerformerName(dj, performerName) {
  const target = ttNormalizeDJNameKey(performerName);
  if (!target || !dj) return false;
  if (ttNormalizeDJNameKey(dj?.name || '') === target) return true;
  const aliases = Array.isArray(dj?.aliases) ? dj.aliases : [];
  return aliases.some((alias) => ttNormalizeDJNameKey(alias) === target);
}

function ttNormalizeDJId(rawId) {
  const id = String(rawId || '').trim();
  if (!id) return '';
  if (isLineupDjIdPlaceholder(id)) return '';
  return id;
}

function ttGetExplicitSlotDJId(slot) {
  const direct = ttNormalizeDJId(slot?.djId);
  if (direct) return direct;
  if (Array.isArray(slot?.djIds)) {
    const first = ttNormalizeDJId(slot.djIds[0]);
    if (first) return first;
  }
  return '';
}

function ttGetExplicitPerformerDJId(slot, performerIndex) {
  const index = Number.isInteger(performerIndex) ? performerIndex : -1;
  if (index >= 0 && Array.isArray(slot?.djIds)) {
    const explicit = ttNormalizeDJId(slot.djIds[index]);
    if (explicit) return explicit;
  }
  if (index === 0) {
    return ttGetExplicitSlotDJId(slot);
  }
  return '';
}

function ttFindBoundDJById(rawId) {
  if (!ttDjMatchLoaded) return null;
  const id = ttNormalizeDJId(rawId);
  if (!id || !ttDjByIdMap.has(id)) return null;
  return ttDjByIdMap.get(id) || null;
}

function ttFindLinkedDJForSlot(slot) {
  return ttFindBoundDJById(ttGetExplicitSlotDJId(slot));
}

function ttExtractCollaborativePerformers(rawName) {
  const name = String(rawName || '').trim();
  if (!name) return [];
  if (!/\bb(?:2|3)b\b/i.test(name)) return [];
  const token = '__TT_ACT_SPLIT__';
  const replaced = name.replace(/\s*b(?:2|3)b\s*/gi, token);
  const performers = replaced
    .split(token)
    .map((part) => String(part || '').trim())
    .filter(Boolean);
  return performers.length >= 2 ? performers : [];
}

function ttExtractCollaborativeActLabel(rawName) {
  const name = String(rawName || '').trim();
  if (!name) return '';
  const match = name.match(/\bb(?:2|3)b\b/i);
  return match ? String(match[0]).toUpperCase() : '';
}

function ttFindBoundDJForPerformer(slot, performerIndex) {
  return ttFindBoundDJById(ttGetExplicitPerformerDJId(slot, performerIndex));
}

function ttFindCandidateDJForPerformerName(performerName) {
  return ttFindMatchedDJByMusicianName(performerName);
}

function ttBuildCollaborativeDjIds(slot) {
  const ids = Array.isArray(slot?.djIds)
    ? slot.djIds.map((id) => String(id || '').trim())
    : [];
  const fallbackPrimary = ttNormalizeDJId(slot?.djId);
  if (fallbackPrimary && !ttNormalizeDJId(ids[0])) {
    ids[0] = fallbackPrimary;
  }
  return ids;
}
