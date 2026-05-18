// Timetable import compare: source grid and compare table rendering.
function ttRenderImportSourceGrid() {
  const box = document.getElementById('tt-dj-source-grid');
  if (!box) return;
  const st = ttGetImportStateFromFacade();
  if (!st) {
    box.innerHTML = '<div class="tt-dj-empty-note">未初始化导入状态</div>';
    return;
  }
  const sourceTitles = {
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
      ? items.map((item, idx) => {
          const selected = idx === group.selectedIndex;
          const name = String(item?.name || 'Unknown').trim();
          const avatar = String(item?.avatarDisplayUrl || item?.avatarUrl || '').trim();
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
            item?.sourceId ? `id:${item.sourceId}` : '',
            locationText,
          ]
            .filter(Boolean)
            .join(' · ');
          return `
            <div class="tt-dj-source-item ${selected ? 'selected' : ''}" onclick="ttSelectImportSourceItem('${key}', ${idx})">
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
          <div class="tt-dj-source-title">${sourceTitles[key]}</div>
          <div class="tt-dj-source-head-right">
            <div class="tt-dj-source-status">${escapeHtml(group?.message || '未抓取')}</div>
            <button class="tt-dj-source-apply-btn" type="button" onclick="ttApplyAllImportFieldsFromSource('${key}')">应用全部</button>
          </div>
        </div>
        <div class="tt-dj-source-list">${listHtml}</div>
      </div>
    `);
  }
  box.innerHTML = parts.join('');
}

function ttRenderImportCompareTable() {
  const tbody = document.getElementById('tt-dj-compare-tbody');
  if (!tbody) return;
  const st = ttGetImportStateFromFacade();
  if (!st) {
    tbody.innerHTML = '';
    return;
  }
  ttNormalizeImportSelections();
  const manual = ttReadImportDraftFromForm();
  const sourceCellHtml = (fieldKey, sourceKey, selectedSource) => {
    const canSelect = ttCanSelectImportSource(sourceKey, fieldKey);
    const selected = selectedSource === sourceKey;
    const className = [
      'tt-dj-compare-source-cell',
      selected ? 'selected' : '',
      canSelect ? '' : 'disabled',
    ].filter(Boolean).join(' ');

    const onClick =
      !canSelect
        ? ''
        : fieldKey === 'avatar'
          ? ` onclick="ttSelectImportAvatarSource('${sourceKey}')"`
          : ` onclick="ttSelectImportFieldSource('${fieldKey}', '${sourceKey}')"`;

    if (fieldKey === 'avatar') {
      const file = document.getElementById('tt-dj-avatar-file')?.files?.[0] || null;
      let avatarHtml = '<div class="tt-dj-compare-source-empty">—</div>';
      if (sourceKey === 'manual') {
        avatarHtml = file
          ? `<div class="tt-dj-compare-avatar-cell"><div class="tt-dj-compare-avatar-thumb"><span class="tt-dj-existing-avatar-fallback">M</span></div><div class="tt-dj-compare-avatar-note">已上传手动头像</div></div>`
          : `<div class="tt-dj-compare-avatar-cell"><div class="tt-dj-compare-avatar-thumb"><span class="tt-dj-existing-avatar-fallback">M</span></div><div class="tt-dj-compare-avatar-note">使用手动上传</div></div>`;
      } else {
        const avatarUrl = ttGetImportAvatarDisplayUrlFromSource(sourceKey);
        avatarHtml = avatarUrl
          ? `<div class="tt-dj-compare-avatar-cell"><div class="tt-dj-compare-avatar-thumb"><img src="${escapeHtml(avatarUrl)}" alt="avatar"></div><div class="tt-dj-compare-avatar-note">使用${escapeHtml(sourceKey.toUpperCase())}头像</div></div>`
          : `<div class="tt-dj-compare-source-empty">${escapeHtml(st.sourceEnabled?.[sourceKey] ? '无头像' : '未启用')}</div>`;
      }
      return `<td><div class="${className}"${onClick}>${avatarHtml}</div></td>`;
    }

    const raw = ttGetImportSourceFieldValue(fieldKey, sourceKey, manual);
    const content = raw
      ? `<div class="tt-dj-compare-source-value">${escapeHtml(String(raw))}</div>`
      : `<div class="tt-dj-compare-source-empty">${escapeHtml(canSelect ? '空值' : (sourceKey === 'manual' ? '—' : (st.sourceEnabled?.[sourceKey] ? '未选择候选' : '未启用')))}</div>`;
    return `<td><div class="${className}"${onClick}>${content}</div></td>`;
  };

  const fieldRows = TT_DJ_IMPORT_FIELDS.map((field) => {
    const selectedSource = String(st.fieldSource?.[field.key] || 'manual');
    const finalValue = ttResolveImportFieldValue(field.key);
    const sourceCols = TT_DJ_IMPORT_SOURCE_KEYS.map((sourceKey) => sourceCellHtml(field.key, sourceKey, selectedSource)).join('');
    return `
      <tr>
        <td class="tt-dj-compare-cell-label">${escapeHtml(field.label)}</td>
        ${sourceCols}
        <td><div class="tt-dj-compare-source-value">${escapeHtml(typeof finalValue === 'string' ? finalValue : String(finalValue ?? '')) || '—'}</div></td>
      </tr>
    `;
  }).join('');

  const selectedAvatarSource = String(st.avatarSource || 'manual');
  const avatarFinalUrl =
    selectedAvatarSource === 'manual'
      ? ''
      : ttGetImportAvatarDisplayUrlFromSource(selectedAvatarSource);
  const avatarFinal = avatarFinalUrl
    ? `<div class="tt-dj-compare-avatar-cell"><div class="tt-dj-compare-avatar-thumb"><img src="${escapeHtml(avatarFinalUrl)}" alt="avatar"></div><div class="tt-dj-compare-avatar-note">${escapeHtml(selectedAvatarSource.toUpperCase())}</div></div>`
    : `<div class="tt-dj-compare-source-empty">${selectedAvatarSource === 'manual' ? '手动上传' : '未提供'}</div>`;

  const avatarRow = `
    <tr>
      <td class="tt-dj-compare-cell-label">头像</td>
      ${TT_DJ_IMPORT_SOURCE_KEYS.map((sourceKey) => sourceCellHtml('avatar', sourceKey, selectedAvatarSource)).join('')}
      <td>${avatarFinal}</td>
    </tr>
  `;

  tbody.innerHTML = avatarRow + fieldRows;
}
