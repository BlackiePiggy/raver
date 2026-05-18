// Timetable import compare: source selection, apply actions, and avatar preview lifecycle.
function ttSelectImportFieldSource(fieldKey, sourceKey) {
  const st = ttGetImportStateFromFacade();
  if (!st) return;
  if (!ttCanSelectImportSource(sourceKey, fieldKey)) return;
  st.fieldSource[fieldKey] = String(sourceKey || 'manual');
  ttRenderImportCompareTable();
}

function ttSelectImportAvatarSource(sourceKey) {
  const st = ttGetImportStateFromFacade();
  if (!st) return;
  if (!ttCanSelectImportSource(sourceKey, 'avatar')) return;
  st.avatarSource = String(sourceKey || 'manual');
  ttRenderImportCompareTable();
  ttRenderImportAvatarPreview();
}

function ttApplyAllImportFieldsFromSource(sourceKey) {
  const st = ttGetImportStateFromFacade();
  if (!st) return;
  const normalizedSource = String(sourceKey || '').trim().toLowerCase();
  if (!['spotify', 'discogs', 'soundcloud'].includes(normalizedSource)) return;
  let appliedCount = 0;
  for (const field of TT_DJ_IMPORT_FIELDS) {
    if (ttCanSelectImportSource(normalizedSource, field.key)) {
      st.fieldSource[field.key] = normalizedSource;
      appliedCount += 1;
    } else {
      st.fieldSource[field.key] = 'manual';
    }
  }
  st.avatarSource = ttCanSelectImportSource(normalizedSource, 'avatar') ? normalizedSource : 'manual';
  ttRenderImportCompareTable();
  ttRenderImportAvatarPreview();
  if (appliedCount > 0) {
    ttSetBindStatus(`已应用 ${normalizedSource.toUpperCase()} 源的 ${appliedCount} 个字段。`, 'ok');
  } else {
    ttSetBindStatus(`${normalizedSource.toUpperCase()} 当前没有可应用字段。`, '');
  }
}

function ttSelectImportSourceItem(source, index) {
  const st = ttGetImportStateFromFacade();
  if (!st || !st.sources[source]) return;
  const group = st.sources[source];
  const items = Array.isArray(group.items) ? group.items : [];
  if (index < 0 || index >= items.length) return;
  group.selectedIndex = index;
  const selected = items[index];
  const manual = ttReadImportDraftFromForm();
  if (!manual.name && selected?.name) {
    manual.name = selected.name;
  }
  if (!manual.bio && selected?.bio) {
    manual.bio = selected.bio;
  }
  if (!manual.genres && Array.isArray(selected?.genres) && selected.genres.length) {
    manual.genres = selected.genres.join(', ');
  }
  if (!manual.country && selected?.country) manual.country = selected.country;
  if (!manual.website && selected?.website) manual.website = selected.website;
  if (!manual.spotifyId && selected?.spotifyId) manual.spotifyId = selected.spotifyId;
  if (
    !manual.spotifyFollowers &&
    selected?.spotifyFollowers !== null &&
    selected?.spotifyFollowers !== undefined &&
    Number.isFinite(Number(selected.spotifyFollowers))
  ) {
    manual.spotifyFollowers = String(Math.max(0, Math.floor(Number(selected.spotifyFollowers))));
  }
  if (!manual.instagramUrl && selected?.instagramUrl) manual.instagramUrl = selected.instagramUrl;
  if (!manual.facebookUrl && selected?.facebookUrl) manual.facebookUrl = selected.facebookUrl;
  if (!manual.soundcloudUrl && selected?.soundcloudUrl) manual.soundcloudUrl = selected.soundcloudUrl;
  if (!manual.soundcloudId && selected?.soundcloudId) manual.soundcloudId = selected.soundcloudId;
  if (
    !manual.trackCount &&
    selected?.trackCount !== null &&
    selected?.trackCount !== undefined &&
    Number.isFinite(Number(selected.trackCount))
  ) {
    manual.trackCount = String(Math.max(0, Math.floor(Number(selected.trackCount))));
  }
  if (
    !manual.playlistCount &&
    selected?.playlistCount !== null &&
    selected?.playlistCount !== undefined &&
    Number.isFinite(Number(selected.playlistCount))
  ) {
    manual.playlistCount = String(Math.max(0, Math.floor(Number(selected.playlistCount))));
  }
  if (
    !manual.soundCloudFollowers &&
    selected?.soundCloudFollowers !== null &&
    selected?.soundCloudFollowers !== undefined &&
    Number.isFinite(Number(selected.soundCloudFollowers))
  ) {
    manual.soundCloudFollowers = String(Math.max(0, Math.floor(Number(selected.soundCloudFollowers))));
  }
  if (
    !manual.soundCloudFavorites &&
    selected?.soundCloudFavorites !== null &&
    selected?.soundCloudFavorites !== undefined &&
    Number.isFinite(Number(selected.soundCloudFavorites))
  ) {
    manual.soundCloudFavorites = String(Math.max(0, Math.floor(Number(selected.soundCloudFavorites))));
  }
  if (!manual.twitterUrl && selected?.twitterUrl) manual.twitterUrl = selected.twitterUrl;
  if (!manual.youtubeUrl && selected?.youtubeUrl) manual.youtubeUrl = selected.youtubeUrl;
  ttWriteImportDraftToForm(manual);
  ttNormalizeImportSelections();
  ttRenderImportSourceGrid();
  ttRenderImportCompareTable();
  ttRenderImportAvatarPreview();
}

function ttAutoPrefillImportDraftFromSources() {
  const st = ttGetImportStateFromFacade();
  if (!st) return;
  const preferredOrder = ['spotify', 'discogs', 'soundcloud'];
  for (const source of preferredOrder) {
    const group = st.sources?.[source];
    const items = Array.isArray(group?.items) ? group.items : [];
    if (!items.length) continue;
    const index = group.selectedIndex >= 0 && group.selectedIndex < items.length ? group.selectedIndex : 0;
    ttSelectImportSourceItem(source, index);
    return;
  }
}

function ttRenderImportAvatarPreview() {
  const preview = document.getElementById('tt-dj-avatar-preview');
  const fileInput = document.getElementById('tt-dj-avatar-file');
  if (!preview) return;
  const st = ttGetImportStateFromFacade();
  const avatarSource = String(st?.avatarSource || 'manual');
  const file = fileInput?.files?.[0] || null;
  if (avatarSource === 'manual') {
    if (file) {
      const url = URL.createObjectURL(file);
      preview.innerHTML = `<img src="${escapeHtml(url)}" alt="avatar preview">`;
      return;
    }
  } else {
    const avatarUrl = ttGetImportAvatarDisplayUrlFromSource(avatarSource);
    if (avatarUrl) {
      preview.innerHTML = `<img src="${escapeHtml(avatarUrl)}" alt="source avatar">`;
      return;
    }
  }
  const fallbackName = String(ttReadImportDraftFromForm().name || '?').trim();
  preview.innerHTML = `<span class="tt-dj-existing-avatar-fallback">${escapeHtml((fallbackName.charAt(0) || '?').toUpperCase())}</span>`;
}

function ttClearImportAvatarFile() {
  const input = document.getElementById('tt-dj-avatar-file');
  if (input) input.value = '';
  const st = ttGetImportStateFromFacade();
  if (st) st.avatarSource = 'manual';
  ttRenderImportCompareTable();
  ttRenderImportAvatarPreview();
}
