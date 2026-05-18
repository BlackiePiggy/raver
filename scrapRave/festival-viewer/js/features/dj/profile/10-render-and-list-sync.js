function syncDJListItem(updated) {
  if (!updated || !updated.id) return;
  const idx = djLibraryState.allItems.findIndex((item) => item?.id === updated.id);
  if (idx < 0) return;
  djLibraryState.allItems[idx] = {
    ...djLibraryState.allItems[idx],
    ...updated,
  };
  ttRebuildDJMatchMapFromState();
  ttDjMatchLoaded = true;
}

function removeDJListItemById(djId) {
  const id = String(djId || '').trim();
  if (!id) return;
  djLibraryState.allItems = (Array.isArray(djLibraryState.allItems) ? djLibraryState.allItems : [])
    .filter((item) => String(item?.id || '').trim() !== id);
  djLibraryState.filteredItems = (Array.isArray(djLibraryState.filteredItems) ? djLibraryState.filteredItems : [])
    .filter((item) => String(item?.id || '').trim() !== id);
  if (djLibraryState.selectedIds instanceof Set) {
    djLibraryState.selectedIds.delete(id);
  }
  ttRebuildDJMatchMapFromState();
  ttDjMatchLoaded = true;
}

function bindDJProfileActionButtons(djId) {
  const id = String(djId || '').trim();
  if (!id) return;
  const saveBtn = document.getElementById('dj-edit-save-btn');
  const headerSaveBtn = document.getElementById('dj-profile-head-save-btn');
  const translateBtn = document.getElementById('dj-edit-translate-btn');
  const deleteBtn = document.getElementById('dj-edit-delete-btn');
  const actionDisabled = !!(djProfileState.saving || djProfileState.translating || djProfileState.deleting);
  if (saveBtn) {
    saveBtn.onclick = () => saveDJProfileEdits(id);
    saveBtn.disabled = actionDisabled;
  }
  if (headerSaveBtn) {
    headerSaveBtn.onclick = () => saveDJProfileEdits(id);
    headerSaveBtn.disabled = actionDisabled;
  }
  if (translateBtn) {
    translateBtn.onclick = () => translateDJProfileBilingual(id);
    translateBtn.disabled = actionDisabled;
  }
  if (deleteBtn) {
    deleteBtn.onclick = () => deleteDJProfile(id);
    deleteBtn.disabled = actionDisabled;
  }
}

function renderDJSocialLinks(detail) {
  const links = [];
  if (detail?.website) links.push({ title: 'Website', url: detail.website });
  if (detail?.sourceWebsite) links.push({ title: 'Source Website', url: detail.sourceWebsite });
  if (detail?.sourceWikipedia) links.push({ title: 'Wikipedia', url: detail.sourceWikipedia });
  if (detail?.soundcloudUrl) links.push({ title: 'SoundCloud', url: detail.soundcloudUrl });
  if (detail?.instagramUrl) links.push({ title: 'Instagram', url: detail.instagramUrl });
  if (detail?.facebookUrl) links.push({ title: 'Facebook', url: detail.facebookUrl });
  if (detail?.twitterUrl) links.push({ title: 'X / Twitter', url: detail.twitterUrl });
  if (detail?.youtubeUrl) links.push({ title: 'YouTube', url: detail.youtubeUrl });
  if (detail?.spotifyUrl) links.push({ title: 'Spotify', url: detail.spotifyUrl });
  else if (detail?.spotifyId) links.push({ title: 'Spotify', url: `https://open.spotify.com/artist/${encodeURIComponent(detail.spotifyId)}` });
  if (detail?.appleMusicId) links.push({ title: 'Apple Music', url: `https://music.apple.com/us/search?term=${encodeURIComponent(detail.appleMusicId)}` });
  if (detail?.neteaseUrl) links.push({ title: 'NetEase', url: detail.neteaseUrl });
  if (detail?.qqMusicUrl) links.push({ title: 'QQ Music', url: detail.qqMusicUrl });
  if (Array.isArray(detail?.sourceSameAs)) {
    detail.sourceSameAs.filter(Boolean).forEach((url, index) => links.push({ title: `SameAs ${index + 1}`, url }));
  }

  if (!links.length) return '<div class="dj-mini-meta">暂无社交链接</div>';
  return `
    <div class="dj-links">
      ${links.map((item) => `<a href="${escapeHtml(item.url)}" target="_blank" rel="noreferrer">${escapeHtml(item.title)}</a>`).join('')}
    </div>
  `;
}

function renderDJSetItems(sets) {
  const list = Array.isArray(sets) ? sets : [];
  if (!list.length) return '<div class="dj-mini-meta">暂无 Sets</div>';
  return `
    <div class="dj-mini-list">
      ${list.slice(0, 12).map((set) => {
        const title = escapeHtml(set?.title || 'Untitled Set');
        const eventName = escapeHtml(set?.eventName || '未知活动');
        const dateText = set?.recordedAt ? new Date(set.recordedAt).toLocaleDateString() : '-';
        const videoUrl = String(set?.videoUrl || '').trim();
        return `
          <div class="dj-mini-item">
            <div class="dj-mini-title">${videoUrl ? `<a href="${escapeHtml(videoUrl)}" target="_blank" rel="noreferrer">${title}</a>` : title}</div>
            <div class="dj-mini-meta">${escapeHtml(eventName)} · ${escapeHtml(dateText)}</div>
          </div>
        `;
      }).join('')}
    </div>
  `;
}

function renderDJEventItems(events) {
  const list = Array.isArray(events) ? events : [];
  if (!list.length) return '<div class="dj-mini-meta">暂无关联活动</div>';
  return `
    <div class="dj-mini-list">
      ${list.slice(0, 12).map((event) => {
        const name = escapeHtml(event?.name || 'Unknown Event');
        const start = event?.startDate ? new Date(event.startDate).toLocaleDateString() : '-';
        const end = event?.endDate ? new Date(event.endDate).toLocaleDateString() : '-';
        const city = String(event?.city || '').trim();
        const country = String(event?.country || '').trim();
        const location = [city, country].filter(Boolean).join(' · ') || '地点未知';
        return `
          <div class="dj-mini-item">
            <div class="dj-mini-title">${name}</div>
            <div class="dj-mini-meta">${escapeHtml(start)} ~ ${escapeHtml(end)} · ${escapeHtml(location)}</div>
          </div>
        `;
      }).join('')}
    </div>
  `;
}

function renderDJProfileContent(detail, sets, events) {
  const name = String(detail?.name || 'Unknown DJ').trim() || 'Unknown DJ';
  const avatarUrl = String(detail?.avatarUrl || '').trim();
  const initial = escapeHtml(String(name).trim().charAt(0).toUpperCase() || '?');
  const country = String(detail?.country || '未知').trim();
  const countryBi = normalizeCountryBiTextValue(
    detail?.countryI18n ?? detail?.country_i18n ?? country,
    country || '未知'
  );
  const followers = Number(detail?.spotifyFollowers ?? detail?.followerCount ?? 0).toLocaleString();
  const verified = detail?.isVerified ? ' · Verified' : '';
  const bio = String(detail?.bio || '').trim() || '暂无简介';
  const bioBi = normalizeBiTextValue(
    detail?.bioI18n ?? detail?.bio_i18n ?? bio,
    bio || '暂无简介'
  );
  const editCountryBi = normalizeCountryBiTextValue(
    detail?.countryI18n ?? detail?.country_i18n ?? detail?.country ?? '',
    detail?.country || ''
  );
  const editBioBi = normalizeBiTextValue(
    detail?.bioI18n ?? detail?.bio_i18n ?? detail?.bio ?? '',
    detail?.bio || ''
  );
  const aliasesText = Array.isArray(detail?.aliases) ? detail.aliases.join(', ') : '';
  const genresText = Array.isArray(detail?.genres) ? detail.genres.join(', ') : '';
  const authDisplayName = getViewerAuthDisplayName() || '未登录';
  const queuedAvatarFile = djProfileState?.avatarFile instanceof File ? djProfileState.avatarFile : null;
  const queuedAvatarPreviewUrl = String(djProfileState?.avatarPreviewUrl || '').trim();
  const avatarEditPreviewUrl = queuedAvatarPreviewUrl || avatarUrl;
  const avatarEditHint = queuedAvatarFile
    ? `已选择新头像：${queuedAvatarFile.name}（${Math.max(1, Math.round(Number(queuedAvatarFile.size || 0) / 1024))} KB）`
    : '未选择新头像，保存时保持当前头像。';

  return `
    <div class="dj-profile-overview">
      <div class="dj-profile-avatar">
        ${avatarUrl ? `<img src="${escapeHtml(avatarUrl)}" alt="${escapeHtml(name)}">` : `<div class="dj-profile-avatar-fallback">${initial}</div>`}
      </div>
      <div>
        <div class="dj-profile-name">${escapeHtml(name)}</div>
        <div class="dj-profile-kv">Country</div>
        <div class="dj-profile-kv">${renderBiTextHtml(countryBi, { compact: true, fallback: country || '未知' })}</div>
        <div class="dj-profile-kv">Spotify Followers ${followers}${verified}</div>
        <div class="dj-profile-kv">Bio</div>
        <div class="dj-profile-kv">${renderBiTextHtml(bioBi, { compact: false, fallback: bio || '暂无简介' })}</div>
      </div>
    </div>

    <div class="dj-profile-block">
      <div class="dj-profile-block-title">编辑 DJ 信息（保存即落库）</div>
      <div class="dj-edit-grid">
        <div class="dj-edit-field">
          <label>名称 *</label>
          <input id="dj-edit-name" type="text" value="${escapeHtml(name)}">
        </div>
        <div class="dj-edit-field">
          <label>国家 (EN)</label>
          <input id="dj-edit-country-en" type="text" value="${escapeHtml(editCountryBi.en || detail?.country || '')}">
        </div>
        <div class="dj-edit-field">
          <label>国家 (EN FULL)</label>
          <input id="dj-edit-country-en-full" type="text" value="${escapeHtml(editCountryBi.enFull || editCountryBi.en || detail?.country || '')}">
        </div>
        <div class="dj-edit-field">
          <label>国家 (ZH)</label>
          <input id="dj-edit-country-zh" type="text" value="${escapeHtml(editCountryBi.zh || '')}">
        </div>
        <div class="dj-edit-field">
          <label>官网链接</label>
          <input id="dj-edit-website" type="text" value="${escapeHtml(detail?.website || '')}">
        </div>
        <div class="dj-edit-field">
          <label>Spotify URL</label>
          <input id="dj-edit-spotify-url" type="text" value="${escapeHtml(detail?.spotifyUrl || '')}">
        </div>
        <div class="dj-edit-field full">
          <label>别名（逗号或换行分隔）</label>
          <input id="dj-edit-aliases" type="text" value="${escapeHtml(aliasesText)}">
        </div>
        <div class="dj-edit-field full">
          <label>GENRES（逗号或换行分隔）</label>
          <input id="dj-edit-genres" type="text" value="${escapeHtml(genresText)}">
        </div>
        <div class="dj-edit-field full">
          <label>头像替换（上传后会覆盖并删除旧 OSS 文件）</label>
          <div class="dj-avatar-edit-row">
            <div class="dj-avatar-edit-preview" id="dj-edit-avatar-preview">
              ${avatarEditPreviewUrl
                ? `<img src="${escapeHtml(avatarEditPreviewUrl)}" alt="${escapeHtml(name)}">`
                : `<div class="dj-profile-avatar-fallback">${initial}</div>`}
            </div>
            <div class="dj-avatar-edit-controls">
              <input id="dj-edit-avatar-file" type="file" accept="image/*" onchange="handleDJEditAvatarFileChange(event)">
              <div class="dj-mini-meta" id="dj-edit-avatar-file-hint">${escapeHtml(avatarEditHint)}</div>
              <button
                type="button"
                class="dj-edit-save-btn dj-edit-source-btn dj-avatar-edit-clear-btn"
                id="dj-edit-avatar-clear-btn"
                onclick="clearDJEditAvatarSelection({ clearInput: true })"
                ${queuedAvatarFile ? '' : 'disabled'}
              >清空已选</button>
            </div>
          </div>
        </div>
        <div class="dj-edit-field full">
          <label>简介 (EN)</label>
          <textarea id="dj-edit-bio-en">${escapeHtml(editBioBi.en || detail?.bio || '')}</textarea>
        </div>
        <div class="dj-edit-field full">
          <label>简介 (ZH)</label>
          <textarea id="dj-edit-bio-zh">${escapeHtml(editBioBi.zh || '')}</textarea>
        </div>
        <div class="dj-edit-field">
          <label>Spotify ID</label>
          <input id="dj-edit-spotify-id" type="text" value="${escapeHtml(detail?.spotifyId || '')}">
        </div>
        <div class="dj-edit-field">
          <label>Spotify Followers</label>
          <input id="dj-edit-spotify-followers" type="text" value="${escapeHtml(detail?.spotifyFollowers ?? '')}">
        </div>
        <div class="dj-edit-field">
          <label>Apple Music ID</label>
          <input id="dj-edit-apple-music-id" type="text" value="${escapeHtml(detail?.appleMusicId || '')}">
        </div>
        <div class="dj-edit-field">
          <label>Instagram URL</label>
          <input id="dj-edit-instagram-url" type="text" value="${escapeHtml(detail?.instagramUrl || '')}">
        </div>
        <div class="dj-edit-field">
          <label>Facebook URL</label>
          <input id="dj-edit-facebook-url" type="text" value="${escapeHtml(detail?.facebookUrl || '')}">
        </div>
        <div class="dj-edit-field">
          <label>SoundCloud URL</label>
          <input id="dj-edit-soundcloud-url" type="text" value="${escapeHtml(detail?.soundcloudUrl || '')}">
        </div>
        <div class="dj-edit-field">
          <label>SoundCloud ID</label>
          <input id="dj-edit-soundcloud-id" type="text" value="${escapeHtml(detail?.soundcloudId || detail?.soundCloudId || '')}">
        </div>
        <div class="dj-edit-field">
          <label>网易云 URL</label>
          <input id="dj-edit-netease-url" type="text" value="${escapeHtml(detail?.neteaseUrl || '')}">
        </div>
        <div class="dj-edit-field">
          <label>QQ 音乐 URL</label>
          <input id="dj-edit-qqmusic-url" type="text" value="${escapeHtml(detail?.qqMusicUrl || '')}">
        </div>
        <div class="dj-edit-field">
          <label>发歌数量</label>
          <input id="dj-edit-track-count" type="text" value="${escapeHtml(detail?.trackCount ?? detail?.track_count ?? '')}">
        </div>
        <div class="dj-edit-field">
          <label>专辑数量</label>
          <input id="dj-edit-playlist-count" type="text" value="${escapeHtml(detail?.playlistCount ?? detail?.playlist_count ?? '')}">
        </div>
        <div class="dj-edit-field">
          <label>SoundCloud 粉丝数量</label>
          <input id="dj-edit-soundcloud-followers" type="text" value="${escapeHtml(detail?.soundCloudFollowers ?? detail?.followers_count ?? '')}">
        </div>
        <div class="dj-edit-field">
          <label>SoundCloud 点赞数量</label>
          <input id="dj-edit-soundcloud-favorites" type="text" value="${escapeHtml(detail?.soundCloudFavorites ?? detail?.public_favorites_count ?? '')}">
        </div>
        <div class="dj-edit-field">
          <label>X / Twitter URL</label>
          <input id="dj-edit-twitter-url" type="text" value="${escapeHtml(detail?.twitterUrl || '')}">
        </div>
        <div class="dj-edit-field">
          <label>YouTube URL</label>
          <input id="dj-edit-youtube-url" type="text" value="${escapeHtml(detail?.youtubeUrl || '')}">
        </div>
        <div class="dj-edit-field">
          <label>认证状态</label>
          <div class="dj-edit-check-row">
            <input id="dj-edit-verified" type="checkbox" ${detail?.isVerified ? 'checked' : ''}>
            <span class="dj-mini-meta">已认证</span>
          </div>
        </div>
        <div class="dj-edit-field full">
          <label>Wikipedia 来源</label>
          <input id="dj-edit-source-wikipedia" type="text" value="${escapeHtml(detail?.sourceWikipedia || '')}">
        </div>
        <div class="dj-edit-field full">
          <label>官网来源</label>
          <input id="dj-edit-source-website" type="text" value="${escapeHtml(detail?.sourceWebsite || '')}">
        </div>
        <div class="dj-edit-field full">
          <label>SameAs（逗号或换行分隔）</label>
          <textarea id="dj-edit-source-sameas">${escapeHtml(Array.isArray(detail?.sourceSameAs) ? detail.sourceSameAs.join('\n') : '')}</textarea>
        </div>
        <div class="dj-edit-field full">
          <label>登录状态</label>
          <div class="dj-mini-meta">当前账号：${escapeHtml(authDisplayName)}（保存时自动带鉴权）</div>
        </div>
        <div class="dj-edit-actions full">
          <button class="dj-edit-save-btn" id="dj-edit-save-btn">保存到数据库</button>
          <button class="dj-edit-save-btn dj-edit-source-btn ai-action-btn" id="dj-edit-translate-btn" title="为当前 DJ 生成 country 和 bio 的中英双语字段，结果回填后需保存">翻译 DJ 国家与简介</button>
          <button class="dj-edit-save-btn dj-edit-source-btn" id="dj-open-source-replace-btn" onclick="openDJSourceReplaceModal()">多源字段替换</button>
          <button class="dj-edit-save-btn dj-edit-danger-btn" id="dj-edit-delete-btn">删除DJ</button>
          <span class="dj-edit-status" id="dj-edit-status"></span>
        </div>
      </div>
    </div>

    <div class="dj-profile-block">
      <div class="dj-profile-block-title">Aliases</div>
      ${renderDJAliasChips(detail?.aliases)}
    </div>

    <div class="dj-profile-block">
      <div class="dj-profile-block-title">GENRES</div>
      ${renderDJGenreChips(detail?.genres)}
    </div>

    <div class="dj-profile-block">
      <div class="dj-profile-block-title">Social Links</div>
      ${renderDJSocialLinks(detail)}
    </div>

    <div class="dj-profile-block">
      <div class="dj-profile-block-title">Source Fields</div>
      <div class="dj-mini-list">
        <div class="dj-mini-item"><div class="dj-mini-title">Spotify URL</div><div class="dj-mini-meta">${escapeHtml(String(detail?.spotifyUrl || '')) || '—'}</div></div>
        <div class="dj-mini-item"><div class="dj-mini-title">NetEase URL</div><div class="dj-mini-meta">${escapeHtml(String(detail?.neteaseUrl || '')) || '—'}</div></div>
        <div class="dj-mini-item"><div class="dj-mini-title">QQ Music URL</div><div class="dj-mini-meta">${escapeHtml(String(detail?.qqMusicUrl || '')) || '—'}</div></div>
        <div class="dj-mini-item"><div class="dj-mini-title">Wikipedia</div><div class="dj-mini-meta">${escapeHtml(String(detail?.sourceWikipedia || '')) || '—'}</div></div>
        <div class="dj-mini-item"><div class="dj-mini-title">Source Website</div><div class="dj-mini-meta">${escapeHtml(String(detail?.sourceWebsite || '')) || '—'}</div></div>
        <div class="dj-mini-item"><div class="dj-mini-title">SameAs</div><div class="dj-mini-meta">${escapeHtml(Array.isArray(detail?.sourceSameAs) ? detail.sourceSameAs.join(' | ') : '') || '—'}</div></div>
      </div>
    </div>

    <div class="dj-profile-block">
      <div class="dj-profile-block-title">Sets</div>
      ${renderDJSetItems(sets)}
    </div>

    <div class="dj-profile-block">
      <div class="dj-profile-block-title">Events</div>
      ${renderDJEventItems(events)}
    </div>
  `;
}
