async function translateDJProfileBilingual(djId) {
  const id = String(djId || '').trim();
  if (!id || djProfileState.saving || djProfileState.translating || djProfileState.deleting) return;

  const countryEnInput = document.getElementById('dj-edit-country-en');
  const countryEnFullInput = document.getElementById('dj-edit-country-en-full');
  const countryZhInput = document.getElementById('dj-edit-country-zh');
  const bioEnInput = document.getElementById('dj-edit-bio-en');
  const bioZhInput = document.getElementById('dj-edit-bio-zh');

  const sourceCountryEn = String(countryEnInput?.value || '').trim();
  const sourceCountryEnFull = String(countryEnFullInput?.value || '').trim();
  const sourceCountryZh = String(countryZhInput?.value || '').trim();
  const sourceBioEn = String(bioEnInput?.value || '').trim();
  const sourceBioZh = String(bioZhInput?.value || '').trim();
  const sourceCountry = sourceCountryEnFull || sourceCountryEn || sourceCountryZh;
  const sourceBio = sourceBioEn || sourceBioZh;
  if (!sourceCountry && !sourceBio) {
    setDJEditStatus('country / bio 至少需要一个非空值才能双语化。', 'err');
    return;
  }

  djProfileState.translating = true;
  bindDJProfileActionButtons(id);
  setDJEditStatus('正在调用 Coze 生成双语 country/bio...', '');

  try {
    const authHeaders = getViewerAuthHeaders();
    const resp = await apiPost(
      '/api/coze/translate-dj-fields',
      { fields: { country: sourceCountry, bio: sourceBio } },
      authHeaders
    );
    const translated = (resp && typeof resp.translated === 'object') ? resp.translated : {};
    const fieldsCn = (translated && typeof translated.fields_cn === 'object') ? translated.fields_cn : {};
    const fieldsEn = (translated && typeof translated.fields_en === 'object') ? translated.fields_en : {};
    const countryBi = normalizeCountryBiTextValue(
      translated.countryI18n ?? translated.country_i18n ?? translated.country ?? null,
      sourceCountry
    );

    const nextCountryEn = String(countryBi.en || fieldsEn.country || '').trim();
    const nextCountryEnFull = String(
      countryBi.enFull
      || fieldsEn.country_en_full
      || fieldsEn.countryEnFull
      || fieldsEn.countryFull
      || ''
    ).trim();
    const nextCountryZh = String(countryBi.zh || fieldsCn.country || '').trim();
    const nextBioEn = String(fieldsEn.bio || '').trim();
    const nextBioZh = String(fieldsCn.bio || '').trim();

    if (countryEnInput) countryEnInput.value = nextCountryEn || sourceCountryEn || sourceCountry;
    if (countryEnFullInput) countryEnFullInput.value = nextCountryEnFull || sourceCountryEnFull || nextCountryEn || sourceCountry;
    if (countryZhInput) countryZhInput.value = nextCountryZh || sourceCountryZh;
    if (bioEnInput) bioEnInput.value = nextBioEn || sourceBioEn || sourceBio;
    if (bioZhInput) bioZhInput.value = nextBioZh || sourceBioZh;
    setDJEditStatus('双语字段已生成并自动回填。', 'ok');
  } catch (error) {
    setDJEditStatus(`双语化失败：${String(error?.message || '未知错误')}`, 'err');
  } finally {
    djProfileState.translating = false;
    bindDJProfileActionButtons(id);
  }
}

async function deleteDJProfile(djId) {
  const id = String(djId || '').trim();
  if (!id || djProfileState.saving || djProfileState.translating || djProfileState.deleting) return;

  const currentName = String(djProfileState?.detail?.name || id).trim() || id;
  const sure = window.confirm(
    `确认删除 DJ「${currentName}」吗？\n\n此操作会删除数据库记录，并清理该 DJ 在 OSS 上的头像/媒体资源，无法撤销。`
  );
  if (!sure) return;

  const authHeaders = getViewerAuthHeaders();
  if (!authHeaders.Authorization) {
    setDJEditStatus('删除失败：请先登录后再执行删除', 'err');
    openViewerLogin();
    return;
  }

  djProfileState.deleting = true;
  bindDJProfileActionButtons(id);
  setDJEditStatus('删除中...', '');

  try {
    await apiPost(`/api/raver/djs/${encodeURIComponent(id)}/delete`, {}, authHeaders);
    removeDJListItemById(id);
    closeDJProfileModal();
    renderDJLibrary();
    setDJStatus(`已删除 DJ：${currentName}`);
  } catch (error) {
    const msg = String(error?.message || '未知错误');
    if (msg.includes('Unauthorized') || msg.includes('401')) {
      setDJEditStatus('删除失败：登录已失效，请重新登录', 'err');
      authState.token = '';
      authState.user = null;
      clearStoredViewerAuth();
      openViewerLogin();
    } else if (msg.includes('403')) {
      setDJEditStatus('删除失败：当前账号不是该 DJ 贡献者或管理员', 'err');
    } else {
      setDJEditStatus(`删除失败：${msg}`, 'err');
    }
  } finally {
    djProfileState.deleting = false;
    bindDJProfileActionButtons(id);
  }
}

async function saveDJProfileEdits(djId) {
  const id = String(djId || '').trim();
  if (!id || djProfileState.saving || djProfileState.translating || djProfileState.deleting) return;

  const nameInput = document.getElementById('dj-edit-name');
  const aliasesInput = document.getElementById('dj-edit-aliases');
  const genresInput = document.getElementById('dj-edit-genres');
  const countryEnInput = document.getElementById('dj-edit-country-en');
  const countryEnFullInput = document.getElementById('dj-edit-country-en-full');
  const countryZhInput = document.getElementById('dj-edit-country-zh');
  const websiteInput = document.getElementById('dj-edit-website');
  const bioEnInput = document.getElementById('dj-edit-bio-en');
  const bioZhInput = document.getElementById('dj-edit-bio-zh');
  const spotifyUrlInput = document.getElementById('dj-edit-spotify-url');
  const spotifyInput = document.getElementById('dj-edit-spotify-id');
  const spotifyFollowersInput = document.getElementById('dj-edit-spotify-followers');
  const appleInput = document.getElementById('dj-edit-apple-music-id');
  const instagramInput = document.getElementById('dj-edit-instagram-url');
  const facebookInput = document.getElementById('dj-edit-facebook-url');
  const soundcloudInput = document.getElementById('dj-edit-soundcloud-url');
  const soundcloudIdInput = document.getElementById('dj-edit-soundcloud-id');
  const neteaseUrlInput = document.getElementById('dj-edit-netease-url');
  const qqMusicUrlInput = document.getElementById('dj-edit-qqmusic-url');
  const sourceWikipediaInput = document.getElementById('dj-edit-source-wikipedia');
  const sourceWebsiteInput = document.getElementById('dj-edit-source-website');
  const sourceSameAsInput = document.getElementById('dj-edit-source-sameas');
  const trackCountInput = document.getElementById('dj-edit-track-count');
  const playlistCountInput = document.getElementById('dj-edit-playlist-count');
  const soundcloudFollowersInput = document.getElementById('dj-edit-soundcloud-followers');
  const soundcloudFavoritesInput = document.getElementById('dj-edit-soundcloud-favorites');
  const twitterInput = document.getElementById('dj-edit-twitter-url');
  const youtubeInput = document.getElementById('dj-edit-youtube-url');
  const verifiedInput = document.getElementById('dj-edit-verified');
  const saveBtn = document.getElementById('dj-edit-save-btn');
  const translateBtn = document.getElementById('dj-edit-translate-btn');
  const deleteBtn = document.getElementById('dj-edit-delete-btn');

  const name = String(nameInput?.value || '').trim();
  if (!name) {
    setDJEditStatus('名称不能为空', 'err');
    return;
  }

  const authHeaders = getViewerAuthHeaders();
  if (!authHeaders.Authorization) {
    setDJEditStatus('保存失败：请先登录后再编辑 DJ 信息', 'err');
    openViewerLogin();
    return;
  }

  const payload = {
    name,
    aliases: splitDJAliasesInput(aliasesInput?.value || ''),
    genres: splitDJGenresInput(genresInput?.value || ''),
    country: nullableTrimmed(countryEnInput?.value)
      || nullableTrimmed(countryEnFullInput?.value)
      || nullableTrimmed(countryZhInput?.value),
    countryI18n: {
      en: String(countryEnInput?.value || '').trim(),
      enFull: String(countryEnFullInput?.value || '').trim(),
      zh: String(countryZhInput?.value || '').trim(),
    },
    website: nullableTrimmed(websiteInput?.value),
    bio: nullableTrimmed(bioEnInput?.value) || nullableTrimmed(bioZhInput?.value),
    bioI18n: {
      en: String(bioEnInput?.value || '').trim(),
      zh: String(bioZhInput?.value || '').trim(),
    },
    spotifyUrl: nullableTrimmed(spotifyUrlInput?.value),
    spotifyId: nullableTrimmed(spotifyInput?.value),
    spotifyFollowers: parseOptionalNonNegativeInt(spotifyFollowersInput?.value),
    appleMusicId: nullableTrimmed(appleInput?.value),
    instagramUrl: nullableTrimmed(instagramInput?.value),
    facebookUrl: nullableTrimmed(facebookInput?.value),
    soundcloudUrl: nullableTrimmed(soundcloudInput?.value),
    soundcloudId: nullableTrimmed(soundcloudIdInput?.value),
    neteaseUrl: nullableTrimmed(neteaseUrlInput?.value),
    qqMusicUrl: nullableTrimmed(qqMusicUrlInput?.value),
    sourceWikipedia: nullableTrimmed(sourceWikipediaInput?.value),
    sourceWebsite: nullableTrimmed(sourceWebsiteInput?.value),
    sourceSameAs: splitDJAliasesInput(sourceSameAsInput?.value || ''),
    trackCount: parseOptionalNonNegativeInt(trackCountInput?.value),
    playlistCount: parseOptionalNonNegativeInt(playlistCountInput?.value),
    soundCloudFollowers: parseOptionalNonNegativeInt(soundcloudFollowersInput?.value),
    soundCloudFavorites: parseOptionalNonNegativeInt(soundcloudFavoritesInput?.value),
    twitterUrl: nullableTrimmed(twitterInput?.value),
    youtubeUrl: nullableTrimmed(youtubeInput?.value),
    isVerified: !!verifiedInput?.checked,
  };
  const queuedAvatarFile = djProfileState?.avatarFile instanceof File ? djProfileState.avatarFile : null;
  const selectedAvatarSource = String(djProfileState?.sourceReplace?.avatarSource || 'keep');
  const selectedAvatarUrl = getDJProfileSourceAvatarUrl(selectedAvatarSource);
  const shouldUploadSelectedAvatar = queuedAvatarFile instanceof File;
  const shouldReplaceAvatar = !shouldUploadSelectedAvatar && selectedAvatarSource !== 'keep' && !!selectedAvatarUrl;

  djProfileState.saving = true;
  if (saveBtn) saveBtn.disabled = true;
  if (translateBtn) translateBtn.disabled = true;
  if (deleteBtn) deleteBtn.disabled = true;
  setDJEditStatus('保存中...', '');

  try {
    const resp = await apiPost(`/api/raver/djs/${encodeURIComponent(id)}/update`, payload, authHeaders);
    const updated = resp?.data || null;
    if (!updated) throw new Error('后端未返回更新后的 DJ 数据');
    let finalDetail = updated;
    let avatarErrorText = '';
    if (shouldUploadSelectedAvatar) {
      try {
        await ttUploadDJAvatar(updated.id, queuedAvatarFile, authHeaders);
        try {
          const detailResp = await apiGet(`/api/raver/djs/${encodeURIComponent(updated.id)}`, authHeaders);
          finalDetail = detailResp?.data || updated;
        } catch (_fetchError) {
          finalDetail = updated;
        }
        clearDJEditAvatarSelection({ clearInput: true, silent: true });
      } catch (avatarError) {
        avatarErrorText = String(avatarError?.message || '头像上传失败');
      }
    } else if (shouldReplaceAvatar) {
      try {
        await ttUploadDJAvatarFromUrl(updated.id, selectedAvatarUrl, authHeaders);
        try {
          const detailResp = await apiGet(`/api/raver/djs/${encodeURIComponent(updated.id)}`, authHeaders);
          finalDetail = detailResp?.data || updated;
        } catch (_fetchError) {
          finalDetail = updated;
        }
      } catch (avatarError) {
        avatarErrorText = String(avatarError?.message || '头像上传失败');
      }
    }
    djProfileState.detail = finalDetail;
    syncDJListItem(finalDetail);
    renderDJLibrary();
    const bodyEl = document.getElementById('dj-profile-body');
    if (bodyEl) {
      bodyEl.innerHTML = renderDJProfileContent(finalDetail, djProfileState.sets, djProfileState.events);
      initDJProfileSourceReplaceUI(finalDetail);
      refreshDJEditAvatarUploaderUI();
    }
    const titleEl = document.getElementById('dj-profile-title');
    if (titleEl) titleEl.textContent = String(finalDetail?.name || 'DJ PROFILE').toUpperCase();
    if (avatarErrorText) {
      setDJEditStatus(`基础信息已保存，但头像替换失败：${avatarErrorText}`, 'err');
    } else if (shouldUploadSelectedAvatar) {
      setDJEditStatus('保存成功，已落库并替换为新上传头像（旧 OSS 文件已删除）', 'ok');
    } else if (shouldReplaceAvatar) {
      setDJEditStatus('保存成功，已落库并更新头像', 'ok');
    } else {
      setDJEditStatus('保存成功，已落库', 'ok');
    }
    bindDJProfileActionButtons(id);
  } catch (error) {
    const msg = String(error?.message || '未知错误');
    if (msg.includes('Unauthorized') || msg.includes('401')) {
      setDJEditStatus('保存失败：登录已失效，请重新登录', 'err');
      authState.token = '';
      authState.user = null;
      clearStoredViewerAuth();
      openViewerLogin();
    } else if (msg.includes('403')) {
      setDJEditStatus('保存失败：当前账号不是该 DJ 贡献者或管理员', 'err');
    } else {
      setDJEditStatus(`保存失败：${msg}`, 'err');
    }
  } finally {
    djProfileState.saving = false;
    bindDJProfileActionButtons(id);
  }
}

async function openDJProfileById(djId) {
  const id = String(djId || '').trim();
  if (!id) return;
  const overlay = document.getElementById('dj-profile-overlay');
  const titleEl = document.getElementById('dj-profile-title');
  const subEl = document.getElementById('dj-profile-sub');
  const bodyEl = document.getElementById('dj-profile-body');
  const headSaveBtn = document.getElementById('dj-profile-head-save-btn');
  if (!overlay || !titleEl || !subEl || !bodyEl) return;

  overlay.classList.add('open');
  closeDJSourceReplaceModal();
  titleEl.textContent = 'DJ PROFILE';
  subEl.textContent = 'LOADING';
  if (headSaveBtn) headSaveBtn.disabled = true;
  bodyEl.innerHTML = '<div class="dj-profile-loading">正在加载 DJ 详情...</div>';
  djProfileState.djId = id;
  djProfileState.detail = null;
  djProfileState.sets = [];
  djProfileState.events = [];
  djProfileState.saving = false;
  djProfileState.translating = false;
  djProfileState.deleting = false;
  djProfileState.sourceReplace = null;
  clearDJEditAvatarSelection({ clearInput: false, silent: true });

  try {
    const [detailResp, setsResp, eventsResp] = await Promise.all([
      apiGet(`/api/raver/djs/${encodeURIComponent(id)}`),
      apiGet(`/api/raver/djs/${encodeURIComponent(id)}/sets`),
      apiGet(`/api/raver/djs/${encodeURIComponent(id)}/events`),
    ]);
    const detail = detailResp?.data || {};
    const sets = setsResp?.data?.items || [];
    const events = eventsResp?.data?.items || [];
    djProfileState.detail = detail;
    djProfileState.sets = sets;
    djProfileState.events = events;

    const name = String(detail?.name || 'Unknown DJ').trim() || 'Unknown DJ';
    titleEl.textContent = name.toUpperCase();
    subEl.textContent = detail?.id ? `ID · ${detail.id}` : 'DJ DETAIL';
    bodyEl.innerHTML = renderDJProfileContent(detail, sets, events);
    initDJProfileSourceReplaceUI(detail);
    refreshDJEditAvatarUploaderUI();
    bindDJProfileActionButtons(id);
  } catch (error) {
    titleEl.textContent = 'DJ PROFILE';
    subEl.textContent = 'LOAD FAILED';
    if (headSaveBtn) headSaveBtn.disabled = true;
    bodyEl.innerHTML = `<div class="dj-profile-loading">加载失败：${escapeHtml(error?.message || '未知错误')}</div>`;
  }
}

function saveCurrentDJProfileFromHeader() {
  const id = String(djProfileState?.djId || '').trim();
  if (!id) return;
  void saveDJProfileEdits(id);
}

function closeDJProfileModal() {
  closeDJSourceReplaceModal();
  const overlay = document.getElementById('dj-profile-overlay');
  if (overlay) overlay.classList.remove('open');
  djProfileState.djId = null;
  djProfileState.detail = null;
  djProfileState.sets = [];
  djProfileState.events = [];
  djProfileState.saving = false;
  djProfileState.translating = false;
  djProfileState.deleting = false;
  djProfileState.sourceReplace = null;
  clearDJEditAvatarSelection({ clearInput: false, silent: true });
}

window.saveCurrentDJProfileFromHeader = saveCurrentDJProfileFromHeader;

function handleDJProfileOverlayClick(event) {
  if (event.target === event.currentTarget) {
    closeDJProfileModal();
  }
}
