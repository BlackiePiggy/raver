// Feature module extracted from monolith (add event modal)
const importAddEventStateModal = (function resolveImportAddEventStateForModal() {
  const facade = window.ImportStateFacade;
  if (facade && typeof facade.addEventState === 'function') return facade.addEventState();
  return {
    get draftFest() {
      return addEventDraftFest;
    },
    set draftFest(value) {
      addEventDraftFest = (value && typeof value === 'object') ? value : null;
    },
    get modalInitialized() {
      return addEventModalInitialized;
    },
    set modalInitialized(value) {
      addEventModalInitialized = !!value;
    },
    get saveRunning() {
      return addEventSaveRunning;
    },
    set saveRunning(value) {
      addEventSaveRunning = !!value;
    },
  };
})();

function todayArchiveDateText() {
  const now = new Date();
  const y = now.getFullYear();
  const m = String(now.getMonth() + 1).padStart(2, '0');
  const d = String(now.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

function ensureAddEventDraftFestival() {
  const today = todayArchiveDateText();
  const year = Number(today.slice(0, 4)) || new Date().getFullYear();
  const month = Number(today.slice(5, 7)) || 1;
  if (!importAddEventStateModal.draftFest) {
    importAddEventStateModal.draftFest = {
      folder: `new-event-${Date.now()}`,
      year,
      month,
      name: '',
      location: '',
      images: [],
      yearHandle: rootDirHandle,
      dirHandle: null,
      infoHandle: null,
      infoFilename: DEFAULT_INFO_FILENAME,
      backendEventId: '',
      sourceMode: 'backend',
      info: normalizeFestivalInfo({
        name: '',
        nameI18n: { en: '', zh: '', ja: '' },
        location: '',
        country: '',
        countryI18n: { en: '', zh: '', ja: '' },
        city: '',
        cityI18n: { en: '', zh: '', ja: '' },
        detailAddressI18n: { en: '', zh: '', ja: '' },
        descriptionI18n: { en: '', zh: '', ja: '' },
        locationPoint: null,
        canceled: false,
        status: 'upcoming',
        eventType: 'festival',
        timeZone: Intl.DateTimeFormat().resolvedOptions().timeZone || 'Asia/Shanghai',
        startDate: today,
        endDate: today,
        relatedLinks: [],
        socialLinks: [],
        lineup: [],
        lineupArtists: [],
        source: mergeSourceMeta({ provider: 'archive-manual' }),
      }, {}),
    };
  }
  importAddEventStateModal.draftFest.year = year;
  importAddEventStateModal.draftFest.month = month;
  importAddEventStateModal.draftFest.yearHandle = rootDirHandle;
  importAddEventStateModal.draftFest.dirHandle = null;
  importAddEventStateModal.draftFest.infoHandle = null;
  importAddEventStateModal.draftFest.infoFilename = DEFAULT_INFO_FILENAME;
  importAddEventStateModal.draftFest.backendEventId = '';
  importAddEventStateModal.draftFest.sourceMode = 'backend';
  return importAddEventStateModal.draftFest;
}

function getAddEventFormPanel() {
  return document.getElementById('add-event-form-panel');
}

function addEventSetModalStatus(text, isError = false) {
  const el = document.getElementById('add-event-save-status');
  if (!el) return;
  el.textContent = String(text || '');
  el.style.color = isError ? 'var(--accent2)' : 'var(--text-dim)';
}

function addEventSetFieldValue(key, value) {
  const panel = getAddEventFormPanel();
  if (!panel) return;
  const input = panel.querySelector(`.fest-info-edit [data-field="${key}"]`);
  if (!input) return;
  input.value = String(value ?? '');
}

function addEventGetFieldValue(key) {
  const panel = getAddEventFormPanel();
  if (!panel) return '';
  return String(panel.querySelector(`.fest-info-edit [data-field="${key}"]`)?.value || '').trim();
}

function initAddEventModalOnce() {
  if (importAddEventStateModal.modalInitialized) return;
  const panel = getAddEventFormPanel();
  const zoneGrid = document.getElementById('add-event-image-zone-grid');
  if (!panel || !zoneGrid) return;

  zoneGrid.innerHTML = buildEventImageZoneCardsHtml();
  const fest = ensureAddEventDraftFestival();
  initEventImageUploadZones(panel, fest);
  ensureEventBrandBindingUI(panel, fest.info || null);
  if (typeof bindEventLineupArtistEditor === 'function') {
    bindEventLineupArtistEditor(panel, fest.info || null);
  }
  if (typeof bindEventMultiLangJsonEditor === 'function') {
    bindEventMultiLangJsonEditor(panel, fest.info || null);
  }
  if (typeof bindEventLocationEditorActions === 'function') {
    bindEventLocationEditorActions(panel, fest);
  }
  if (typeof setEventLocationDraftFromInfo === 'function') {
    setEventLocationDraftFromInfo(panel, fest.info || null);
  }
  importAddEventStateModal.modalInitialized = true;
}

function resetAddEventModalForm() {
  const panel = getAddEventFormPanel();
  if (!panel) return;
  const fest = ensureAddEventDraftFestival();
  const today = todayArchiveDateText();
  fest.images = [];
  fest.info = normalizeFestivalInfo({
    name: '',
    nameI18n: { en: '', zh: '', ja: '' },
    location: '',
    country: '',
    countryI18n: { en: '', zh: '', ja: '' },
    city: '',
    cityI18n: { en: '', zh: '', ja: '' },
    detailAddressI18n: { en: '', zh: '', ja: '' },
    descriptionI18n: { en: '', zh: '', ja: '' },
    locationPoint: null,
    canceled: false,
    status: 'upcoming',
    eventType: 'festival',
    timeZone: Intl.DateTimeFormat().resolvedOptions().timeZone || 'Asia/Shanghai',
    startDate: today,
    endDate: today,
    relatedLinks: [],
    socialLinks: [],
    lineup: [],
    lineupArtists: [],
    source: mergeSourceMeta({ provider: 'archive-manual' }),
  }, fest.info || {});

  addEventSetFieldValue('nameEn', '');
  addEventSetFieldValue('nameZh', '');
  addEventSetFieldValue('nameJa', '');
  addEventSetFieldValue('cityEn', '');
  addEventSetFieldValue('cityZh', '');
  addEventSetFieldValue('cityJa', '');
  addEventSetFieldValue('countryEn', '');
  addEventSetFieldValue('countryEnFull', '');
  addEventSetFieldValue('countryZh', '');
  addEventSetFieldValue('countryJa', '');
  addEventSetFieldValue('detailAddressEn', '');
  addEventSetFieldValue('detailAddressZh', '');
  addEventSetFieldValue('detailAddressJa', '');
  addEventSetFieldValue('multiLangJson', '');
  addEventSetFieldValue('locationPointJson', '');
  addEventSetFieldValue(
    'locationProvider',
    (typeof getPreferredEventLocationProvider === 'function' ? getPreferredEventLocationProvider() : 'amap')
  );
  addEventSetFieldValue('wikiFestivalName', '');
  addEventSetFieldValue('wikiFestivalId', '');
  addEventSetFieldValue('status', 'upcoming');
  addEventSetFieldValue('canceled', 'false');
  addEventSetFieldValue('eventType', 'festival');
  addEventSetFieldValue('timeZone', Intl.DateTimeFormat().resolvedOptions().timeZone || 'Asia/Shanghai');
  addEventSetFieldValue('startDate', today);
  addEventSetFieldValue('endDate', today);
  addEventSetFieldValue('ticketPriceMin', '');
  addEventSetFieldValue('ticketPriceMax', '');
  addEventSetFieldValue('ticketCurrency', '');
  addEventSetFieldValue('ticketUrl', '');
  addEventSetFieldValue('ticketNotes', '');
  addEventSetFieldValue('socialLinks', '');
  addEventSetFieldValue('relatedLinks', '');
  addEventSetFieldValue('lineup', '');
  addEventSetFieldValue('lineupArtists', '');

  clearEventImageDraftState(panel);
  clearExistingEventAssetDraft(panel);
  renderExistingEventAssetDrafts(panel, fest);
  renderEventImageZoneDrafts(panel, fest);
  ensureEventBrandBindingUI(panel, fest.info || null);
  if (typeof bindEventLineupArtistEditor === 'function') {
    bindEventLineupArtistEditor(panel, fest.info || null);
  }
  if (typeof bindEventMultiLangJsonEditor === 'function') {
    bindEventMultiLangJsonEditor(panel, fest.info || null);
  }
  if (typeof bindEventLocationEditorActions === 'function') {
    bindEventLocationEditorActions(panel, fest);
  }
  if (typeof setEventLocationDraftFromInfo === 'function') {
    setEventLocationDraftFromInfo(panel, fest.info || null);
  }

  addEventSetModalStatus('');
  const subEl = document.getElementById('add-event-modal-sub');
  if (subEl) subEl.textContent = `填写活动信息并直接入库（默认日期 ${today}）`;
}

function openAddEventModal() {
  initAddEventModalOnce();
  const overlay = document.getElementById('add-event-modal-overlay');
  if (!overlay) return;
  resetAddEventModalForm();
  overlay.classList.add('open');
  document.body.style.overflow = 'hidden';

  if (!rootDirHandle) {
    addEventSetModalStatus('当前未选择本地缓存目录，图片缓存步骤可能失败；可先点“切换文件夹”。', true);
  } else if (!getViewerAuthHeaders().Authorization) {
    addEventSetModalStatus('未登录，创建时会失败。请先登录后再保存。', true);
  }
}

function closeAddEventModal(force = false) {
  if (importAddEventStateModal.saveRunning && !force) {
    addEventSetModalStatus('创建进行中，请稍候...', true);
    return;
  }
  const overlay = document.getElementById('add-event-modal-overlay');
  if (!overlay) return;
  overlay.classList.remove('open');
  document.body.style.overflow = '';
}

function handleAddEventOverlayClick(event) {
  if (event?.target === document.getElementById('add-event-modal-overlay')) {
    closeAddEventModal();
  }
}

function addEventQueuedImageCount(panel) {
  const draft = collectEventImageDraftPayload(panel);
  return Object.values(draft).reduce((sum, list) => sum + (Array.isArray(list) ? list.length : 0), 0);
}

function buildAddEventRecognitionContext() {
  const panel = getAddEventFormPanel();
  if (!panel) return null;
  const fest = ensureAddEventDraftFestival();
  const collected = collectFestivalPayloadFromPanel(panel, fest);
  if (collected?.payload) {
    fest.info = normalizeFestivalInfo(collected.payload, fest.info || {});
  }
  return { panel, fest };
}

function runAddEventLineupRecognitionWithCoze() {
  const ctx = buildAddEventRecognitionContext();
  const btn = document.getElementById('add-event-coze-lineup-btn');
  const statusEl = document.getElementById('add-event-save-status');
  if (!ctx || !btn || !statusEl) return;
  runCozeLineupRecognition(ctx.fest, ctx.panel, btn, statusEl, { applyMode: 'form' });
}

function runAddEventPosterRecognitionWithCoze() {
  const ctx = buildAddEventRecognitionContext();
  const btn = document.getElementById('add-event-coze-poster-btn');
  const statusEl = document.getElementById('add-event-save-status');
  if (!ctx || !btn || !statusEl) return;
  runCozePosterInfoRecognition(ctx.fest, ctx.panel, btn, statusEl, { applyMode: 'form' });
}

async function runAddEventTranslateWithCoze() {
  const panel = getAddEventFormPanel();
  const btn = document.getElementById('add-event-translate-btn');
  if (!panel || !btn) return;

  const nameEn = addEventGetFieldValue('nameEn');
  const nameZh = addEventGetFieldValue('nameZh');
  const nameJa = addEventGetFieldValue('nameJa');
  const cityEn = addEventGetFieldValue('cityEn');
  const cityZh = addEventGetFieldValue('cityZh');
  const cityJa = addEventGetFieldValue('cityJa');
  const countryEn = addEventGetFieldValue('countryEn');
  const countryEnFull = addEventGetFieldValue('countryEnFull');
  const countryZh = addEventGetFieldValue('countryZh');
  const countryJa = addEventGetFieldValue('countryJa');
  const detailAddressEn = addEventGetFieldValue('detailAddressEn');
  const detailAddressZh = addEventGetFieldValue('detailAddressZh');
  const detailAddressJa = addEventGetFieldValue('detailAddressJa');
  const detailSeed = detailAddressEn || detailAddressZh || detailAddressJa || cityZh || cityEn || cityJa;
  const countrySeed = countryZh || countryEnFull || countryEn || countryJa;
  const hasAnyInput = [nameEn, nameZh, nameJa, detailSeed, countrySeed].some(Boolean);
  if (!hasAnyInput) {
    addEventSetModalStatus('请先填写至少一个语言字段，再执行一键翻译。', true);
    return;
  }

  btn.disabled = true;
  addEventSetModalStatus('正在调用 Coze 翻译...');
  try {
    const currentCountry = normalizeCountryBiTextValue({ en: countryEn, zh: countryZh, ja: countryJa, enFull: countryEnFull }, countrySeed);
    const resp = await apiPost('/api/coze/translate-festival', {
      festival: {
        name_i18n: { en: nameEn, zh: nameZh, ja: nameJa },
        city_i18n: { en: cityEn, zh: cityZh, ja: cityJa },
        detail_address_i18n: { en: detailAddressEn, zh: detailAddressZh, ja: detailAddressJa },
        country_i18n: {
          en: currentCountry.en || '',
          zh: currentCountry.zh || '',
          ja: currentCountry.ja || '',
          en_full: currentCountry.enFull || '',
        },
      }
    });
    const translated = resp?.translated || {};
    const nameOut = parsePartialBiText(translated.nameI18n);
    const cityOut = parsePartialBiText(translated.cityI18n);
    const detailOut = parsePartialBiText(
      translated.detailAddressI18n
      ?? translated.detail_address_i18n
    );
    const countryOut = parsePartialBiText(
      translated.countryI18n
      ?? translated.country_i18n
      ?? translated.country
    );

    let fillCount = 0;
    if (!nameEn && nameOut.en) { addEventSetFieldValue('nameEn', nameOut.en); fillCount += 1; }
    if (!nameZh && nameOut.zh) { addEventSetFieldValue('nameZh', nameOut.zh); fillCount += 1; }
    if (!nameJa && nameOut.ja) { addEventSetFieldValue('nameJa', nameOut.ja); fillCount += 1; }
    if (!detailAddressEn && detailOut.en) { addEventSetFieldValue('detailAddressEn', detailOut.en); fillCount += 1; }
    if (!detailAddressZh && detailOut.zh) { addEventSetFieldValue('detailAddressZh', detailOut.zh); fillCount += 1; }
    if (!detailAddressJa && detailOut.ja) { addEventSetFieldValue('detailAddressJa', detailOut.ja); fillCount += 1; }
    if (!cityEn && cityOut.en) {
      addEventSetFieldValue('cityEn', cityOut.en);
      fillCount += 1;
    }
    if (!cityZh && cityOut.zh) {
      addEventSetFieldValue('cityZh', cityOut.zh);
      fillCount += 1;
    }
    if (!cityJa && cityOut.ja) {
      addEventSetFieldValue('cityJa', cityOut.ja);
      fillCount += 1;
    }
    if (!countryEn && countryOut.en) {
      addEventSetFieldValue('countryEn', countryOut.en);
      fillCount += 1;
    }
    if (!countryEnFull && countryOut.enFull) {
      addEventSetFieldValue('countryEnFull', countryOut.enFull);
      fillCount += 1;
    }
    if (!countryZh && countryOut.zh) {
      addEventSetFieldValue('countryZh', countryOut.zh);
      fillCount += 1;
    }
    if (!countryJa && countryOut.ja) {
      addEventSetFieldValue('countryJa', countryOut.ja);
      fillCount += 1;
    }

    if (typeof eventEditSyncMultiLangDraftFromInputs === 'function') {
      eventEditSyncMultiLangDraftFromInputs(panel);
    }

    if (fillCount > 0) {
      addEventSetModalStatus(`翻译完成，已自动补全 ${fillCount} 个空字段。`);
    } else {
      addEventSetModalStatus('翻译完成，当前字段已齐全，未做覆盖。');
    }
  } catch (error) {
    addEventSetModalStatus(`翻译失败：${error?.message || '未知错误'}`, true);
  } finally {
    btn.disabled = false;
  }
}

async function confirmAddEventCreate() {
  if (importAddEventStateModal.saveRunning) return;
  const panel = getAddEventFormPanel();
  const saveBtn = document.getElementById('add-event-save-btn');
  const translateBtn = document.getElementById('add-event-translate-btn');
  const cozeLineupBtn = document.getElementById('add-event-coze-lineup-btn');
  const cozePosterBtn = document.getElementById('add-event-coze-poster-btn');
  if (!panel || !saveBtn) return;

  const authHeaders = getViewerAuthHeaders();
  if (!authHeaders.Authorization) {
    addEventSetModalStatus('请先登录后再创建活动。', true);
    openViewerLogin();
    return;
  }

  const hasName = !!(addEventGetFieldValue('nameEn') || addEventGetFieldValue('nameZh') || addEventGetFieldValue('nameJa'));
  const hasLocation = !!(addEventGetFieldValue('cityEn') || addEventGetFieldValue('cityZh') || addEventGetFieldValue('cityJa'));
  const hasCountry = !!(
    addEventGetFieldValue('countryEn')
    || addEventGetFieldValue('countryEnFull')
    || addEventGetFieldValue('countryZh')
    || addEventGetFieldValue('countryJa')
  );
  const statusValue = normalizeArchiveEventStatus(addEventGetFieldValue('status'));
  const eventTypeValue = String(addEventGetFieldValue('eventType') || '').trim();
  if (!hasName) {
    addEventSetModalStatus('请至少填写一个语言版本的活动名称。', true);
    return;
  }
  if (!hasLocation) {
    addEventSetModalStatus('请至少填写一个语言版本的地点。', true);
    return;
  }
  if (!hasCountry) {
    addEventSetModalStatus('请至少填写一个语言版本的国家。', true);
    return;
  }
  if (!statusValue) {
    addEventSetModalStatus('请选择开启状态。', true);
    return;
  }
  if (!eventTypeValue) {
    addEventSetModalStatus('请选择活动类型。', true);
    return;
  }

  const queuedImages = addEventQueuedImageCount(panel);
  if (queuedImages < 1) {
    addEventSetModalStatus('请至少上传 1 张图片。', true);
    return;
  }

  const fest = ensureAddEventDraftFestival();
  if (typeof collectEventLocationPointFromPanel === 'function') {
    fest.info.locationPoint = collectEventLocationPointFromPanel(panel);
  }
  const collected = collectFestivalPayloadFromPanel(panel, fest);
  if (!collected || !collected.payload) {
    addEventSetModalStatus(collected?.error || '表单数据校验失败', true);
    return;
  }
  const payload = collected.payload;
  payload.canceled = statusValue === 'cancelled' ? true : !!payload.canceled;
  payload.status = payload.canceled ? 'cancelled' : statusValue;
  payload.eventType = eventTypeValue;
  if (!String(payload.startDate || '').trim()) payload.startDate = todayArchiveDateText();
  if (!String(payload.endDate || '').trim()) payload.endDate = payload.startDate;
  payload.source = mergeSourceMeta(payload.source, { provider: 'archive-manual' });

  const imageZoneDraft = collectEventImageDraftPayload(panel);
  importAddEventStateModal.saveRunning = true;
  saveBtn.disabled = true;
  if (translateBtn) translateBtn.disabled = true;
  if (cozeLineupBtn) cozeLineupBtn.disabled = true;
  if (cozePosterBtn) cozePosterBtn.disabled = true;
  addEventSetModalStatus('正在创建活动并同步数据库 / OSS ...');

  try {
    const syncResult = await persistFestivalPayload(fest, payload, {
      imageZoneDraft,
      existingAssetDraft: [],
    });
    closeAddEventModal(true);
    if (rootDirHandle) {
      await rebuildLibraryIndex('新增活动已保存，正在刷新活动列表...', { preserveView: true });
    } else {
      await loadArchiveEventsFromBackend({ preserveView: true, detail: '新增活动已保存，正在刷新活动列表...' });
    }
    const eventId = String(syncResult?.eventId || syncResult?.event?.id || '').trim();
    setImportStatus(eventId ? `已创建活动（eventId: ${eventId}）` : '已创建活动并刷新列表');
  } catch (error) {
    addEventSetModalStatus(`创建失败：${error?.message || '未知错误'}`, true);
  } finally {
    importAddEventStateModal.saveRunning = false;
    saveBtn.disabled = false;
    if (translateBtn) translateBtn.disabled = false;
    if (cozeLineupBtn) cozeLineupBtn.disabled = false;
    if (cozePosterBtn) cozePosterBtn.disabled = false;
  }
}
