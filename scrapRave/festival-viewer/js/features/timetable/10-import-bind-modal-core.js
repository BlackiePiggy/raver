// Feature module extracted from monolith (timetable import bind modal core)
function ttRenderExistingDJList() {
  const listEl = document.getElementById('tt-dj-existing-list');
  const searchInput = document.getElementById('tt-dj-existing-search');
  if (!listEl) return;
  const query = String(searchInput?.value || ttDJBindState.existingSearch || '').trim().toLowerCase();
  ttDJBindState.existingSearch = query;
  const source = Array.isArray(djLibraryState.allItems) ? djLibraryState.allItems : [];
  const filtered = source
    .filter((item) => {
      if (!query) return true;
      const name = String(item?.name || '').toLowerCase();
      if (name.includes(query)) return true;
      const aliases = Array.isArray(item?.aliases) ? item.aliases : [];
      return aliases.some((alias) => String(alias || '').toLowerCase().includes(query));
    })
    .sort((a, b) => String(a?.name || '').localeCompare(String(b?.name || ''), 'en', { sensitivity: 'base' }))
    .slice(0, 300);

  if (!filtered.length) {
    listEl.innerHTML = `<div class="tt-dj-empty-note">没有匹配 DJ，建议切到“导入新 DJ”页创建新资料。</div>`;
    return;
  }

  listEl.innerHTML = filtered.map((item) => {
    const id = String(item?.id || '').trim();
    const name = String(item?.name || 'Unknown DJ').trim();
    const aliases = Array.isArray(item?.aliases) ? item.aliases.filter(Boolean).slice(0, 3).join(' / ') : '';
    const country = String(item?.country || '').trim();
    const avatarUrl = String(item?.avatarUrl || '').trim();
    const selected = id && id === ttDJBindState.existingSelectedId;
    return `
      <label class="tt-dj-existing-item ${selected ? 'selected' : ''}" onclick="ttChooseExistingDJ('${escapeHtml(id)}')">
        <div class="tt-dj-existing-avatar">
          ${avatarUrl
            ? `<img src="${escapeHtml(avatarUrl)}" alt="${escapeHtml(name)}" loading="lazy">`
            : `<span class="tt-dj-existing-avatar-fallback">${escapeHtml((name.charAt(0) || '?').toUpperCase())}</span>`
          }
        </div>
        <div>
          <div class="tt-dj-existing-name">${escapeHtml(name)}</div>
          <div class="tt-dj-existing-meta">${escapeHtml(aliases || '无别名')}${country ? ` · ${escapeHtml(country)}` : ''}</div>
        </div>
      </label>
    `;
  }).join('');
}

function ttChooseExistingDJ(id) {
  ttDJBindState.existingSelectedId = String(id || '').trim();
  ttRenderExistingDJList();
}

function ttDJBindSelectAllExisting(_flag) {
  ttDJBindState.existingSelectedId = '';
  ttRenderExistingDJList();
}

function ttCurrentBindSlotSummary(slot) {
  if (!slot) return '未选择表演';
  const date = String(slot.date || '未知');
  const time = String(slot.time || '未知');
  const stage = String(slot.stage || '主舞台');
  const musician = String(slot.musician || '未知');
  const performerName = String(ttDJBindState.performerName || '').trim();
  const performerSuffix = performerName ? ` · 目标成员: ${performerName}` : '';
  return `${musician} · ${date} · ${time} · ${stage}${performerSuffix}`;
}

function ttSyncDJBindModalModeUI() {
  const isLibraryMode = ttIsLibraryImportMode();
  const titleEl = document.getElementById('tt-dj-bind-title');
  const subEl = document.getElementById('tt-dj-bind-sub');
  const tabbarEl = document.getElementById('tt-dj-bind-tabbar');
  const existingTab = document.getElementById('tt-dj-bind-tab-existing');
  const importTab = document.getElementById('tt-dj-bind-tab-import');
  const existingPanel = document.getElementById('tt-dj-bind-panel-existing');
  const importPanel = document.getElementById('tt-dj-bind-panel-import');
  const confirmBtn = document.getElementById('tt-dj-import-confirm-btn');
  const translateBtn = document.getElementById('tt-dj-translate-btn');
  const timetableAutoMatchBtn = document.getElementById('tt-timetable-auto-match-btn');

  if (titleEl) titleEl.textContent = isLibraryMode ? '导入新 DJ' : '绑定表演 DJ';
  if (subEl && isLibraryMode) {
    subEl.textContent = '将当前信息保存到 DJ 数据库（无需绑定 timetable）。';
  }
  if (tabbarEl) tabbarEl.style.display = isLibraryMode ? 'none' : '';
  if (existingTab) {
    existingTab.disabled = isLibraryMode;
    existingTab.style.display = isLibraryMode ? 'none' : '';
  }
  if (importTab) {
    importTab.style.display = '';
    importTab.textContent = '导入新 DJ';
  }
  if (existingPanel) existingPanel.style.display = isLibraryMode ? 'none' : '';
  if (importPanel) importPanel.style.display = 'grid';
  if (translateBtn) {
    const showTranslate = isLibraryMode || ttDJBindState.tab === 'import';
    translateBtn.style.display = showTranslate ? '' : 'none';
  }
  if (timetableAutoMatchBtn) {
    timetableAutoMatchBtn.style.display = isLibraryMode ? 'none' : '';
  }
  if (confirmBtn) confirmBtn.textContent = isLibraryMode ? '保存入库' : '保存并绑定';
}

async function ttOpenDJBindModal(rid, preferredTab = 'existing', options = null) {
  const slot = ttGetDraftSlotByRid(rid);
  if (!slot) return;
  const opts = (options && typeof options === 'object') ? options : {};
  const performerIndex = Number.isInteger(opts.performerIndex) ? opts.performerIndex : null;
  const performerName = String(opts.performerName || '').trim();
  await ensureTtDJMatchMapLoaded();
  const explicitPerformerID =
    performerIndex != null && Array.isArray(slot?.djIds)
      ? String(slot.djIds[performerIndex] || '').trim()
      : '';
  const fallbackSlotID =
    performerIndex == null || performerIndex === 0
      ? String(slot?.djId || '').trim()
      : '';
  const preferredExistingId =
    explicitPerformerID ||
    fallbackSlotID;
  ttDJBindState.open = true;
  ttDJBindState.mode = 'bind';
  ttDJBindState.rid = rid;
  ttDJBindState.tab = preferredTab === 'import' ? 'import' : 'existing';
  ttDJBindState.performerName = performerName;
  ttDJBindState.performerIndex = performerIndex;
  ttDJBindState.existingSearch = '';
  ttDJBindState.existingSelectedId = preferredExistingId;
  ttDJBindState.onImported = null;
  ttDJBindState.importState = ttCreateEmptyImportState(slot, performerName);

  const subEl = document.getElementById('tt-dj-bind-sub');
  if (subEl) subEl.textContent = ttCurrentBindSlotSummary(slot);

  const existingInput = document.getElementById('tt-dj-existing-search');
  if (existingInput) existingInput.value = '';
  const importInput = document.getElementById('tt-dj-import-query');
  if (importInput) importInput.value = String(ttDJBindState.importState.query || '');
  const spotifyToggle = document.getElementById('tt-dj-src-spotify');
  const discogsToggle = document.getElementById('tt-dj-src-discogs');
  const soundcloudToggle = document.getElementById('tt-dj-src-soundcloud');
  const avatarInput = document.getElementById('tt-dj-avatar-file');
  const translateBtn = document.getElementById('tt-dj-translate-btn');
  if (spotifyToggle) spotifyToggle.checked = !!ttDJBindState.importState.sourceEnabled.spotify;
  if (discogsToggle) discogsToggle.checked = !!ttDJBindState.importState.sourceEnabled.discogs;
  if (soundcloudToggle) soundcloudToggle.checked = !!ttDJBindState.importState.sourceEnabled.soundcloud;
  if (avatarInput) avatarInput.value = '';
  if (translateBtn) translateBtn.disabled = false;

  ttWriteImportDraftToForm(ttGetImportManualDraft(slot, performerName));
  ttRenderImportSourceGrid();
  ttRenderImportCompareTable();
  ttRenderImportAvatarPreview();
  ttRenderExistingDJList();
  switchTtDJBindTab(ttDJBindState.tab);
  ttSyncDJBindModalModeUI();
  ttCloseBindStatus();

  const overlay = document.getElementById('tt-dj-bind-overlay');
  if (overlay) overlay.classList.add('open');
  document.body.style.overflow = 'hidden';
}

function closeTtDJBindModal() {
  const overlay = document.getElementById('tt-dj-bind-overlay');
  if (overlay) overlay.classList.remove('open');
  const shouldResetQuickBind = ttQuickBindMode && !ttSaving;
  ttDJBindState.open = false;
  ttDJBindState.mode = 'bind';
  ttDJBindState.rid = null;
  ttDJBindState.performerName = '';
  ttDJBindState.performerIndex = null;
  ttDJBindState.onImported = null;
  ttDJBindState.importState = null;
  ttCloseBindStatus();
  if (shouldResetQuickBind) {
    ttQuickBindMode = false;
    ttDraftLineup = [];
  }
  if (document.getElementById('tt-modal-overlay')?.classList.contains('open')) {
    document.body.style.overflow = 'hidden';
  } else {
    document.body.style.overflow = '';
  }
}

function handleTtDJBindOverlayClick(event) {
  if (event.target === document.getElementById('tt-dj-bind-overlay')) {
    closeTtDJBindModal();
  }
}

function switchTtDJBindTab(tab) {
  const nextTab = ttIsLibraryImportMode() ? 'import' : (tab === 'import' ? 'import' : 'existing');
  ttDJBindState.tab = nextTab;
  const existingPanel = document.getElementById('tt-dj-bind-panel-existing');
  const importPanel = document.getElementById('tt-dj-bind-panel-import');
  const existingTab = document.getElementById('tt-dj-bind-tab-existing');
  const importTab = document.getElementById('tt-dj-bind-tab-import');
  const showExisting = !ttIsLibraryImportMode() && nextTab === 'existing';
  if (existingPanel) existingPanel.classList.toggle('active', showExisting);
  if (importPanel) importPanel.classList.toggle('active', nextTab === 'import');
  if (existingTab) existingTab.classList.toggle('active', showExisting);
  if (importTab) importTab.classList.toggle('active', nextTab === 'import');
  ttSyncDJBindModalModeUI();
}

function ttConfirmBindExistingDJ() {
  if (ttIsLibraryImportMode()) {
    ttSetBindStatus('当前入口仅支持导入新 DJ，请在导入页保存入库。', 'err');
    switchTtDJBindTab('import');
    return;
  }
  const rid = ttDJBindState.rid;
  const slot = ttGetDraftSlotByRid(rid);
  if (!slot) return;
  const id = String(ttDJBindState.existingSelectedId || '').trim();
  if (!id) {
    ttSetBindStatus('请先选择一个 DJ。', 'err');
    return;
  }
  const dj = (djLibraryState.allItems || []).find((item) => String(item?.id || '') === id);
  if (!dj) {
    ttSetBindStatus('所选 DJ 不存在，请刷新 DJ 库后重试。', 'err');
    return;
  }
  ttBindSlotToDJ(slot, dj);
  closeTtDJBindModal();
}

function ttGetImportManualDraft(slot = null, preferredName = '') {
  const preferred = String(preferredName || '').trim();
  const baseName = preferred || String(slot?.musician || '').trim();
  return {
    name: baseName && baseName !== '未知' ? baseName : '',
    aliases: '',
    genres: '',
    bio: '',
    country: '',
    countryEn: '',
    countryZh: '',
    bioEn: '',
    bioZh: '',
    website: '',
    spotifyId: '',
    spotifyFollowers: '',
    instagramUrl: '',
    facebookUrl: '',
    soundcloudUrl: '',
    soundcloudId: '',
    trackCount: '',
    playlistCount: '',
    soundCloudFollowers: '',
    soundCloudFavorites: '',
    twitterUrl: '',
    youtubeUrl: '',
    isVerified: true,
  };
}

function ttReadImportDraftFromForm() {
  const read = (id) => String(document.getElementById(id)?.value || '').trim();
  return {
    name: read('tt-dj-manual-name'),
    aliases: read('tt-dj-manual-aliases'),
    genres: read('tt-dj-manual-genres'),
    bio: read('tt-dj-manual-bio'),
    country: read('tt-dj-manual-country'),
    countryEn: read('tt-dj-manual-country-en'),
    countryZh: read('tt-dj-manual-country-zh'),
    bioEn: read('tt-dj-manual-bio-en'),
    bioZh: read('tt-dj-manual-bio-zh'),
    website: read('tt-dj-manual-website'),
    spotifyId: read('tt-dj-manual-spotify-id'),
    spotifyFollowers: read('tt-dj-manual-spotify-followers'),
    instagramUrl: read('tt-dj-manual-instagram-url'),
    facebookUrl: read('tt-dj-manual-facebook-url'),
    soundcloudUrl: read('tt-dj-manual-soundcloud-url'),
    soundcloudId: read('tt-dj-manual-soundcloud-id'),
    trackCount: read('tt-dj-manual-track-count'),
    playlistCount: read('tt-dj-manual-playlist-count'),
    soundCloudFollowers: read('tt-dj-manual-soundcloud-followers'),
    soundCloudFavorites: read('tt-dj-manual-soundcloud-favorites'),
    twitterUrl: read('tt-dj-manual-twitter-url'),
    youtubeUrl: read('tt-dj-manual-youtube-url'),
    isVerified: !!document.getElementById('tt-dj-manual-verified')?.checked,
  };
}

function ttWriteImportDraftToForm(draft) {
  const write = (id, value) => {
    const el = document.getElementById(id);
    if (el) el.value = String(value || '');
  };
  write('tt-dj-manual-name', draft?.name);
  write('tt-dj-manual-aliases', draft?.aliases);
  write('tt-dj-manual-genres', draft?.genres);
  write('tt-dj-manual-bio', draft?.bio);
  write('tt-dj-manual-country', draft?.country);
  write('tt-dj-manual-country-en', draft?.countryEn);
  write('tt-dj-manual-country-zh', draft?.countryZh);
  write('tt-dj-manual-bio-en', draft?.bioEn);
  write('tt-dj-manual-bio-zh', draft?.bioZh);
  write('tt-dj-manual-website', draft?.website);
  write('tt-dj-manual-spotify-id', draft?.spotifyId);
  write('tt-dj-manual-spotify-followers', draft?.spotifyFollowers);
  write('tt-dj-manual-instagram-url', draft?.instagramUrl);
  write('tt-dj-manual-facebook-url', draft?.facebookUrl);
  write('tt-dj-manual-soundcloud-url', draft?.soundcloudUrl);
  write('tt-dj-manual-soundcloud-id', draft?.soundcloudId);
  write('tt-dj-manual-track-count', draft?.trackCount);
  write('tt-dj-manual-playlist-count', draft?.playlistCount);
  write('tt-dj-manual-soundcloud-followers', draft?.soundCloudFollowers);
  write('tt-dj-manual-soundcloud-favorites', draft?.soundCloudFavorites);
  write('tt-dj-manual-twitter-url', draft?.twitterUrl);
  write('tt-dj-manual-youtube-url', draft?.youtubeUrl);
  const verified = document.getElementById('tt-dj-manual-verified');
  if (verified) verified.checked = draft?.isVerified !== false;
}

function ttExtractSpotifyArtistId(value) {
  const rawText = String(value || '').trim();
  if (!rawText) return '';

  const pickFromText = (text) => {
    const normalized = String(text || '').trim();
    if (!normalized) return '';
    const uriMatch = normalized.match(/spotify:artist:([A-Za-z0-9]{10,64})/i);
    if (uriMatch?.[1]) return uriMatch[1];
    const pathMatch = normalized.match(/\/artist\/([A-Za-z0-9]{10,64})/i);
    if (pathMatch?.[1]) return pathMatch[1];
    return '';
  };

  let parsed = pickFromText(rawText);
  if (parsed) return parsed;

  let decoded = rawText;
  for (let i = 0; i < 3; i += 1) {
    try {
      const next = decodeURIComponent(decoded);
      if (next === decoded) break;
      decoded = next;
      parsed = pickFromText(decoded);
      if (parsed) return parsed;
    } catch (_error) {
      break;
    }
  }

  try {
    const maybeUrl = /^https?:\/\//i.test(rawText) ? rawText : `https://${rawText}`;
    const u = new URL(maybeUrl);
    parsed = pickFromText(u.pathname || '');
    if (parsed) return parsed;
    const maybeUri = u.searchParams.get('uri')
      || u.searchParams.get('spotify_uri')
      || u.searchParams.get('spotify');
    parsed = pickFromText(maybeUri || '');
    if (parsed) return parsed;
    const maybeId = String(
      u.searchParams.get('artist')
      || u.searchParams.get('artist_id')
      || u.searchParams.get('spotifyArtistId')
      || ''
    ).trim();
    if (/^[A-Za-z0-9]{10,64}$/.test(maybeId)) return maybeId;
  } catch (_error) {
    // ignore parse error
  }

  return '';
}

