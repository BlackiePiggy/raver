// DJ profile editor module extracted from 00-edit-and-source (source state + compare + fetch)
function createDJProfileSourceReplaceState(detail = null) {
  return {
    djId: String(djProfileState.djId || '').trim(),
    query: String(detail?.name || '').trim(),
    sourceEnabled: { spotify: true, discogs: true, soundcloud: true },
    loading: false,
    statusText: '',
    statusType: '',
    sources: {
      spotify: { status: 'idle', message: '未抓取', items: [], selectedIndex: -1 },
      discogs: { status: 'idle', message: '未抓取', items: [], selectedIndex: -1 },
      soundcloud: { status: 'idle', message: '未抓取', items: [], selectedIndex: -1 },
    },
    fieldSource: Object.fromEntries(DJ_PROFILE_REPLACE_FIELDS.map((field) => [field.key, 'keep'])),
    avatarSource: 'keep',
  };
}

function setDJSourceReplaceStatus(text, type = '') {
  const st = djProfileState.sourceReplace;
  if (st) {
    st.statusText = String(text || '');
    st.statusType = type ? String(type) : '';
  }
  const el = document.getElementById('dj-source-replace-status');
  if (!el) return;
  el.textContent = String(text || '');
  el.classList.remove('err', 'ok');
  if (type) el.classList.add(type);
}

function ensureDJProfileSourceReplaceState(detail = null) {
  const currentDJId = String(djProfileState.djId || '').trim();
  if (!currentDJId) return null;
  const existing = djProfileState.sourceReplace;
  if (existing && String(existing.djId || '').trim() === currentDJId) {
    return existing;
  }
  const next = createDJProfileSourceReplaceState(detail || djProfileState.detail || null);
  djProfileState.sourceReplace = next;
  return next;
}

function getDJProfileCurrentEditDraft() {
  const detail = djProfileState.detail || {};
  const countryBi = normalizeCountryBiTextValue(
    detail?.countryI18n ?? detail?.country_i18n ?? detail?.country ?? '',
    detail?.country || ''
  );
  const bioBi = normalizeBiTextValue(
    detail?.bioI18n ?? detail?.bio_i18n ?? detail?.bio ?? '',
    detail?.bio || ''
  );
  const read = (id, fallback = '') => {
    const el = document.getElementById(id);
    if (el && 'value' in el) return String(el.value || '').trim();
    return String(fallback ?? '').trim();
  };
  return {
    name: read('dj-edit-name', detail?.name || ''),
    aliases: read('dj-edit-aliases', Array.isArray(detail?.aliases) ? detail.aliases.join(', ') : ''),
    genres: read('dj-edit-genres', Array.isArray(detail?.genres) ? detail.genres.join(', ') : ''),
    bio: read('dj-edit-bio-en', bioBi.en || detail?.bio || ''),
    bioZh: read('dj-edit-bio-zh', bioBi.zh || ''),
    country: read('dj-edit-country-en', countryBi.en || detail?.country || ''),
    countryEnFull: read('dj-edit-country-en-full', countryBi.enFull || countryBi.en || detail?.country || ''),
    countryZh: read('dj-edit-country-zh', countryBi.zh || ''),
    website: read('dj-edit-website', detail?.website || ''),
    spotifyUrl: read('dj-edit-spotify-url', detail?.spotifyUrl || ''),
    spotifyId: read('dj-edit-spotify-id', detail?.spotifyId || ''),
    spotifyFollowers: read('dj-edit-spotify-followers', detail?.spotifyFollowers ?? ''),
    appleMusicId: read('dj-edit-apple-music-id', detail?.appleMusicId || ''),
    instagramUrl: read('dj-edit-instagram-url', detail?.instagramUrl || ''),
    facebookUrl: read('dj-edit-facebook-url', detail?.facebookUrl || ''),
    twitterUrl: read('dj-edit-twitter-url', detail?.twitterUrl || ''),
    youtubeUrl: read('dj-edit-youtube-url', detail?.youtubeUrl || ''),
    soundcloudUrl: read('dj-edit-soundcloud-url', detail?.soundcloudUrl || ''),
    soundcloudId: read('dj-edit-soundcloud-id', detail?.soundcloudId || detail?.soundCloudId || ''),
    neteaseUrl: read('dj-edit-netease-url', detail?.neteaseUrl || ''),
    qqMusicUrl: read('dj-edit-qqmusic-url', detail?.qqMusicUrl || ''),
    sourceWikipedia: read('dj-edit-source-wikipedia', detail?.sourceWikipedia || ''),
    sourceWebsite: read('dj-edit-source-website', detail?.sourceWebsite || ''),
    sourceSameAs: read('dj-edit-source-sameas', Array.isArray(detail?.sourceSameAs) ? detail.sourceSameAs.join('\n') : ''),
    trackCount: read('dj-edit-track-count', detail?.trackCount ?? detail?.track_count ?? ''),
    playlistCount: read('dj-edit-playlist-count', detail?.playlistCount ?? detail?.playlist_count ?? ''),
    soundCloudFollowers: read('dj-edit-soundcloud-followers', detail?.soundCloudFollowers ?? detail?.followers_count ?? ''),
    soundCloudFavorites: read('dj-edit-soundcloud-favorites', detail?.soundCloudFavorites ?? detail?.public_favorites_count ?? ''),
  };
}

function getDJProfileSelectedSourceCandidate(sourceKey) {
  const st = djProfileState.sourceReplace;
  if (!st) return null;
  const group = st.sources?.[sourceKey];
  if (!group || group.selectedIndex < 0) return null;
  return group.items[group.selectedIndex] || null;
}

function getDJProfileCurrentAvatarUrl() {
  return String(djProfileState?.detail?.avatarUrl || '').trim();
}

function getDJProfileSourceAvatarUrl(sourceKey) {
  if (sourceKey === 'keep') return getDJProfileCurrentAvatarUrl();
  const selected = getDJProfileSelectedSourceCandidate(sourceKey);
  return String(selected?.avatarUrl || '').trim();
}

function djProfileFieldValueToText(fieldKey, value) {
  if (value === null || value === undefined) return '';
  if ((fieldKey === 'aliases' || fieldKey === 'genres') && Array.isArray(value)) {
    return value.filter(Boolean).join(', ');
  }
  return String(value).trim();
}

function getDJProfileSourceFieldValue(fieldKey, sourceKey, currentDraft = null) {
  const draft = currentDraft || getDJProfileCurrentEditDraft();
  if (sourceKey === 'keep') return draft[fieldKey] ?? '';
  const selected = getDJProfileSelectedSourceCandidate(sourceKey);
  if (!selected) return '';
  return djProfileFieldValueToText(fieldKey, selected[fieldKey]);
}

function canSelectDJProfileSourceField(fieldKey, sourceKey) {
  const st = djProfileState.sourceReplace;
  if (!st) return false;
  if (sourceKey === 'keep') return true;
  if (!st.sourceEnabled?.[sourceKey]) return false;
  const selected = getDJProfileSelectedSourceCandidate(sourceKey);
  if (!selected) return false;
  if (fieldKey === 'avatar') {
    return !!String(selected?.avatarUrl || '').trim();
  }
  return true;
}

function normalizeDJProfileSourceSelections() {
  const st = djProfileState.sourceReplace;
  if (!st) return;
  for (const field of DJ_PROFILE_REPLACE_FIELDS) {
    const source = String(st.fieldSource?.[field.key] || 'keep');
    if (!canSelectDJProfileSourceField(field.key, source)) {
      st.fieldSource[field.key] = 'keep';
    }
  }
  const avatarSource = String(st.avatarSource || 'keep');
  if (!canSelectDJProfileSourceField('avatar', avatarSource)) {
    st.avatarSource = 'keep';
  }
}

function renderDJProfileSourceGrid() {
  const box = document.getElementById('dj-source-grid');
  if (!box) return;
  const st = djProfileState.sourceReplace;
  if (!st) {
    box.innerHTML = '<div class="tt-dj-empty-note">未初始化替换状态</div>';
    return;
  }

  const titles = {
    spotify: 'Spotify',
    discogs: 'Discogs',
    soundcloud: 'SoundCloud',
  };
  const parts = [];
  for (const key of ['spotify', 'discogs', 'soundcloud']) {
    if (!st.sourceEnabled[key]) continue;
    const group = st.sources[key];
    const items = Array.isArray(group?.items) ? group.items : [];
    const listHtml = items.length
      ? items.map((item, index) => {
          const selected = index === group.selectedIndex;
          const name = String(item?.name || 'Unknown').trim();
          const avatar = String(item?.avatarUrl || '').trim();
          const followersCount = Number(item?.followersCount ?? item?.followers_count);
          const followersText = Number.isFinite(followersCount) && followersCount > 0
            ? `粉丝:${Math.floor(followersCount).toLocaleString()}`
            : '';
          const locationText = [String(item?.city || '').trim(), String(item?.country || '').trim()]
            .filter(Boolean)
            .join(', ');
          const metaLine = [
            followersText,
            item?.trackCount || item?.track_count ? `曲目:${Number(item?.trackCount ?? item?.track_count ?? 0)}` : '',
            item?.playlistCount || item?.playlist_count ? `歌单:${Number(item?.playlistCount ?? item?.playlist_count ?? 0)}` : '',
            item?.soundCloudFavorites || item?.public_favorites_count
              ? `点赞:${Number(item?.soundCloudFavorites ?? item?.public_favorites_count ?? 0)}`
              : '',
            item?.spotifyId ? `spotify:${item.spotifyId}` : '',
            item?.soundcloudId || item?.soundcloudid ? `sc:${item.soundcloudId || item.soundcloudid}` : '',
            locationText,
          ]
            .filter(Boolean)
            .join(' · ');
          return `
            <div class="tt-dj-source-item ${selected ? 'selected' : ''}" onclick="djSelectProfileSourceItem('${key}', ${index})">
              <div class="tt-dj-source-avatar">
                ${avatar
                  ? `<img src="${escapeHtml(avatar)}" alt="${escapeHtml(name)}" loading="lazy">`
                  : `<span class="tt-dj-existing-avatar-fallback">${escapeHtml((name.charAt(0) || '?').toUpperCase())}</span>`
                }
              </div>
              <div>
                <div class="tt-dj-source-name">${escapeHtml(name)}</div>
                <div class="tt-dj-source-meta">${escapeHtml(metaLine || '点击选择该源候选')}</div>
              </div>
            </div>
          `;
        }).join('')
      : `<div class="tt-dj-empty-note">${escapeHtml(group?.message || '暂无结果')}</div>`;

    parts.push(`
      <div class="tt-dj-source-card">
        <div class="tt-dj-source-head">
          <div class="tt-dj-source-title">${titles[key]}</div>
          <div class="tt-dj-source-head-right">
            <div class="tt-dj-source-status">${escapeHtml(group?.message || '未抓取')}</div>
            <button class="tt-dj-source-apply-btn" type="button" onclick="djApplyAllProfileFieldsFromSource('${key}')">应用全部</button>
          </div>
        </div>
        <div class="tt-dj-source-list">${listHtml}</div>
      </div>
    `);
  }
  box.innerHTML = parts.join('') || '<div class="tt-dj-empty-note">请先启用并抓取数据源</div>';
}

function renderDJProfileSourceCompareTable() {
  const tbody = document.getElementById('dj-source-compare-tbody');
  if (!tbody) return;
  const st = djProfileState.sourceReplace;
  if (!st) {
    tbody.innerHTML = '';
    return;
  }
  normalizeDJProfileSourceSelections();
  const draft = getDJProfileCurrentEditDraft();
  const sourceKeys = ['keep', 'spotify', 'discogs', 'soundcloud'];

  const sourceCellHtml = (fieldKey, sourceKey, selectedSource) => {
    const canSelect = canSelectDJProfileSourceField(fieldKey, sourceKey);
    const selected = selectedSource === sourceKey;
    const className = [
      'tt-dj-compare-source-cell',
      selected ? 'selected' : '',
      canSelect ? '' : 'disabled',
    ].filter(Boolean).join(' ');

    const onClick = !canSelect
      ? ''
      : fieldKey === 'avatar'
        ? ` onclick="djSelectProfileAvatarSource('${sourceKey}')"`
        : ` onclick="djSelectProfileFieldSource('${fieldKey}', '${sourceKey}')"`;

    if (fieldKey === 'avatar') {
      const avatarUrl = getDJProfileSourceAvatarUrl(sourceKey);
      const avatarHtml = avatarUrl
        ? `<div class="tt-dj-compare-avatar-cell"><div class="tt-dj-compare-avatar-thumb"><img src="${escapeHtml(avatarUrl)}" alt="avatar"></div><div class="tt-dj-compare-avatar-note">${escapeHtml(sourceKey === 'keep' ? '保持当前头像' : `使用${sourceKey.toUpperCase()}头像`)}</div></div>`
        : `<div class="tt-dj-compare-source-empty">${escapeHtml(canSelect ? '无头像' : '不可选')}</div>`;
      return `<td><div class="${className}"${onClick}>${avatarHtml}</div></td>`;
    }

    const raw = getDJProfileSourceFieldValue(fieldKey, sourceKey, draft);
    const content = raw
      ? `<div class="tt-dj-compare-source-value">${escapeHtml(String(raw))}</div>`
      : `<div class="tt-dj-compare-source-empty">${escapeHtml(canSelect ? '空值' : '不可选')}</div>`;
    return `<td><div class="${className}"${onClick}>${content}</div></td>`;
  };

  const selectedAvatarSource = String(st.avatarSource || 'keep');
  const avatarPreviewUrl = getDJProfileSourceAvatarUrl(selectedAvatarSource);
  const avatarPreview = avatarPreviewUrl
    ? `<div class="tt-dj-compare-avatar-cell"><div class="tt-dj-compare-avatar-thumb"><img src="${escapeHtml(avatarPreviewUrl)}" alt="avatar"></div><div class="tt-dj-compare-avatar-note">${escapeHtml(selectedAvatarSource === 'keep' ? '当前头像' : selectedAvatarSource.toUpperCase())}</div></div>`
    : `<div class="tt-dj-compare-source-empty">${escapeHtml(selectedAvatarSource === 'keep' ? '当前无头像' : '该来源无头像')}</div>`;

  const avatarRow = `
    <tr>
      <td class="tt-dj-compare-cell-label">头像</td>
      ${sourceKeys.map((sourceKey) => sourceCellHtml('avatar', sourceKey, selectedAvatarSource)).join('')}
      <td>${avatarPreview}</td>
    </tr>
  `;

  const fieldRows = DJ_PROFILE_REPLACE_FIELDS.map((field) => {
    const selectedSource = String(st.fieldSource?.[field.key] || 'keep');
    const preview = getDJProfileSourceFieldValue(field.key, selectedSource, draft);
    return `
      <tr>
        <td class="tt-dj-compare-cell-label">${escapeHtml(field.label)}</td>
        ${sourceKeys.map((sourceKey) => sourceCellHtml(field.key, sourceKey, selectedSource)).join('')}
        <td><div class="tt-dj-compare-source-value">${escapeHtml(String(preview || '')) || '—'}</div></td>
      </tr>
    `;
  }).join('');

  tbody.innerHTML = avatarRow + fieldRows;
}

function djSelectProfileSourceItem(sourceKey, index) {
  const st = djProfileState.sourceReplace;
  if (!st || !st.sources[sourceKey]) return;
  const group = st.sources[sourceKey];
  const items = Array.isArray(group.items) ? group.items : [];
  if (index < 0 || index >= items.length) return;
  group.selectedIndex = index;
  normalizeDJProfileSourceSelections();
  renderDJProfileSourceGrid();
  renderDJProfileSourceCompareTable();
}

function djSelectProfileFieldSource(fieldKey, sourceKey) {
  const st = djProfileState.sourceReplace;
  if (!st) return;
  if (!canSelectDJProfileSourceField(fieldKey, sourceKey)) return;
  st.fieldSource[fieldKey] = sourceKey;
  renderDJProfileSourceCompareTable();
}

function djSelectProfileAvatarSource(sourceKey) {
  const st = djProfileState.sourceReplace;
  if (!st) return;
  if (!canSelectDJProfileSourceField('avatar', sourceKey)) return;
  st.avatarSource = String(sourceKey || 'keep');
  renderDJProfileSourceCompareTable();
}

function djApplyAllProfileFieldsFromSource(sourceKey) {
  const st = djProfileState.sourceReplace;
  if (!st) return;
  const normalizedSource = String(sourceKey || '').trim().toLowerCase();
  if (!['spotify', 'discogs', 'soundcloud'].includes(normalizedSource)) return;
  let appliedCount = 0;
  for (const field of DJ_PROFILE_REPLACE_FIELDS) {
    if (canSelectDJProfileSourceField(field.key, normalizedSource)) {
      st.fieldSource[field.key] = normalizedSource;
      appliedCount += 1;
    } else {
      st.fieldSource[field.key] = 'keep';
    }
  }
  st.avatarSource = canSelectDJProfileSourceField('avatar', normalizedSource) ? normalizedSource : 'keep';
  renderDJProfileSourceCompareTable();
  if (appliedCount > 0) {
    setDJSourceReplaceStatus(`已应用 ${normalizedSource.toUpperCase()} 源的 ${appliedCount} 个字段。`, 'ok');
  } else {
    setDJSourceReplaceStatus(`${normalizedSource.toUpperCase()} 当前没有可应用字段。`, '');
  }
}

function djResetProfileFieldSourceSelection() {
  const st = djProfileState.sourceReplace;
  if (!st) return;
  for (const field of DJ_PROFILE_REPLACE_FIELDS) {
    st.fieldSource[field.key] = 'keep';
  }
  st.avatarSource = 'keep';
  setDJSourceReplaceStatus('已重置为保持当前值。', 'ok');
  renderDJProfileSourceCompareTable();
}

function djApplyProfileSourceSelectionToEditor() {
  const st = djProfileState.sourceReplace;
  if (!st) return;
  normalizeDJProfileSourceSelections();
  const draft = getDJProfileCurrentEditDraft();
  for (const field of DJ_PROFILE_REPLACE_FIELDS) {
    const source = String(st.fieldSource?.[field.key] || 'keep');
    if (source === 'keep') continue;
    const el = document.getElementById(field.inputId);
    if (!el || !('value' in el)) continue;
    const next = getDJProfileSourceFieldValue(field.key, source, draft);
    el.value = String(next || '');
  }
  setDJSourceReplaceStatus('字段已应用到编辑表单；头像来源会在点击“保存到数据库”时生效。', 'ok');
  renderDJProfileSourceCompareTable();
}

async function djFetchProfileSourceCandidates() {
  const st = ensureDJProfileSourceReplaceState();
  if (!st || st.loading) return;
  const queryInput = document.getElementById('dj-source-query');
  const query = String(queryInput?.value || st.query || '').trim();
  st.query = query;
  if (!query) {
    setDJSourceReplaceStatus('请先输入 DJ 名称再抓取。', 'err');
    return;
  }
  const headers = getViewerAuthHeaders();
  if (!headers.Authorization) {
    setDJSourceReplaceStatus('请先登录后再抓取多源数据。', 'err');
    openViewerLogin();
    return;
  }

  const sourceToggles = {
    spotify: !!document.getElementById('dj-source-toggle-spotify')?.checked,
    discogs: !!document.getElementById('dj-source-toggle-discogs')?.checked,
    soundcloud: !!document.getElementById('dj-source-toggle-soundcloud')?.checked,
  };
  if (!sourceToggles.spotify && !sourceToggles.discogs && !sourceToggles.soundcloud) {
    setDJSourceReplaceStatus('请至少选择一个抓取渠道。', 'err');
    return;
  }

  st.sourceEnabled = sourceToggles;
  st.loading = true;
  for (const key of ['spotify', 'discogs', 'soundcloud']) {
    if (!sourceToggles[key]) {
      st.sources[key] = { status: 'idle', message: '未启用', items: [], selectedIndex: -1 };
      continue;
    }
    st.sources[key] = { status: 'loading', message: '抓取中...', items: [], selectedIndex: -1 };
  }
  renderDJProfileSourceGrid();
  renderDJProfileSourceCompareTable();
  setDJSourceReplaceStatus('正在抓取多源信息...', '');

  const tasks = [];
  if (sourceToggles.spotify) {
    tasks.push((async () => {
      try {
        const items = await ttFetchSpotifyImportCandidates(query, headers);
        st.sources.spotify = {
          status: 'ok',
          message: items.length ? `抓取 ${items.length} 条` : '无结果',
          items,
          selectedIndex: items.length ? 0 : -1,
        };
      } catch (error) {
        st.sources.spotify = { status: 'err', message: String(error?.message || '抓取失败'), items: [], selectedIndex: -1 };
      }
    })());
  }
  if (sourceToggles.discogs) {
    tasks.push((async () => {
      try {
        const items = await ttFetchDiscogsImportCandidates(query, headers);
        st.sources.discogs = {
          status: 'ok',
          message: items.length ? `抓取 ${items.length} 条` : '无结果',
          items,
          selectedIndex: items.length ? 0 : -1,
        };
      } catch (error) {
        st.sources.discogs = { status: 'err', message: String(error?.message || '抓取失败'), items: [], selectedIndex: -1 };
      }
    })());
  }
  if (sourceToggles.soundcloud) {
    tasks.push((async () => {
      try {
        const items = await ttFetchSoundCloudImportCandidates(query, headers);
        st.sources.soundcloud = {
          status: 'ok',
          message: items.length ? `抓取 ${items.length} 条` : '无结果',
          items,
          selectedIndex: items.length ? 0 : -1,
        };
      } catch (error) {
        st.sources.soundcloud = { status: 'err', message: String(error?.message || '抓取失败'), items: [], selectedIndex: -1 };
      }
    })());
  }

  await Promise.all(tasks);
  st.loading = false;
  normalizeDJProfileSourceSelections();
  renderDJProfileSourceGrid();
  renderDJProfileSourceCompareTable();
  setDJSourceReplaceStatus('抓取完成，可逐字段选择来源并应用。', 'ok');
}
