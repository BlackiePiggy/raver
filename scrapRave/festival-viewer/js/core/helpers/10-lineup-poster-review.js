const LINEUP_DJ_ID_PLACEHOLDER = '__UNBOUND__';

function isLineupDjIdPlaceholder(rawId) {
  return String(rawId || '').trim() === LINEUP_DJ_ID_PLACEHOLDER;
}

function normalizeLineupEntry(item) {
  const raw = (item && typeof item === 'object') ? { ...item } : {};
  const musician = String(raw.musician || '').trim() || '未知';
  const date = String(raw.date || '').trim() || '未知';
  const time = String(raw.time || '').trim() || '未知';
  // Keep empty stage as empty string: empty stage means single-stage festival.
  const stage = (raw.stage == null ? '' : String(raw.stage).trim());
  const out = { ...raw, musician, date, time, stage };
  const djId = String(raw.djId || raw.dj_id || '').trim();
  if (djId) out.djId = djId;
  else delete out.djId;
  const djIdsRaw = Array.isArray(raw.djIds) ? raw.djIds : (Array.isArray(raw.dj_ids) ? raw.dj_ids : []);
  const djIds = djIdsRaw
    .map((id) => String(id || '').trim())
    .filter(Boolean);
  if (djIds.length) out.djIds = djIds;
  else delete out.djIds;
  const festivalDayIndexRaw = Number(raw.festivalDayIndex ?? raw.festival_day_index);
  if (Number.isInteger(festivalDayIndexRaw) && festivalDayIndexRaw > 0) {
    out.festivalDayIndex = festivalDayIndexRaw;
  } else {
    delete out.festivalDayIndex;
  }
  if ('dj_id' in out) delete out.dj_id;
  if ('dj_ids' in out) delete out.dj_ids;
  if ('avatar' in out) {
    const avatar = String(out.avatar || '').trim();
    if (avatar) out.avatar = avatar;
    else delete out.avatar;
  }
  return out;
}

function dedupeLineupEntries(items) {
  const map = new Map();
  for (const raw of (Array.isArray(items) ? items : [])) {
    if (!raw || typeof raw !== 'object') continue;
    const x = normalizeLineupEntry(raw);
    const key = `${x.musician}|${x.date}|${x.time}|${x.stage}`;
    const prev = map.get(key);
    if (!prev) {
      map.set(key, x);
      continue;
    }
    // Merge duplicates and keep the richer version (e.g. preserve avatar).
    for (const [k, v] of Object.entries(x)) {
      const val = typeof v === 'string' ? v.trim() : v;
      if (val === '' || val == null) continue;
      const prevVal = prev[k];
      if (typeof prevVal === 'string' ? prevVal.trim() === '' : prevVal == null) {
        prev[k] = v;
      }
    }
  }
  return Array.from(map.values());
}

function mergeLineupEntries(existing, incoming) {
  return dedupeLineupEntries([...(Array.isArray(existing) ? existing : []), ...(Array.isArray(incoming) ? incoming : [])]);
}

function blobToDataUrl(blob) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result || ''));
    reader.onerror = () => reject(new Error('读取图片失败'));
    reader.readAsDataURL(blob);
  });
}

async function imageToCozeInput(img) {
  const u = String(img?.url || '').trim();
  if (/^https?:\/\//i.test(u)) return u;
  if (img?.file) return await blobToDataUrl(img.file);
  if (u.startsWith('blob:')) {
    const resp = await fetch(u);
    if (!resp.ok) throw new Error(`读取本地图片失败 (${resp.status})`);
    const blob = await resp.blob();
    return await blobToDataUrl(blob);
  }
  throw new Error('无法获取图片数据');
}

function buildDraftFestivalImageItem(zoneKey, item, sortIndex) {
  const normalizedZone = normalizeEventImageZoneKey(zoneKey);
  const zoneMeta = EVENT_IMAGE_ZONE_MAP[normalizedZone] || EVENT_IMAGE_ZONE_MAP.other;
  const file = item?.file || null;
  const fileName = sanitizeEventImageFileName(item?.fileName || file?.name || `${normalizedZone}-${sortIndex + 1}.jpg`);
  return {
    file,
    url: '',
    remoteUrl: '',
    filename: fileName,
    zoneKey: normalizedZone,
    classified: {
      type: backendTypeForImageZone(normalizedZone),
      label: defaultImageLabelForZone(normalizedZone),
      order: Number(zoneMeta?.order ?? 99),
      sort: Number(sortIndex || 0),
    },
    _fromDraft: true,
  };
}

function collectPanelDraftFestivalImages(panelEl) {
  if (!panelEl || typeof collectEventImageDraftPayload !== 'function') return [];
  const draft = collectEventImageDraftPayload(panelEl);
  const out = [];
  for (const zone of EVENT_IMAGE_ZONES) {
    const rows = Array.isArray(draft?.[zone.key]) ? draft[zone.key] : [];
    rows.forEach((row, idx) => {
      const item = buildDraftFestivalImageItem(zone.key, row, idx);
      if (item.file || item.url || item.remoteUrl) out.push(item);
    });
  }
  return out;
}

function mergeFestivalImagesWithPanelDraft(fest, panelEl) {
  const base = Array.isArray(fest?.images) ? fest.images : [];
  const draft = collectPanelDraftFestivalImages(panelEl);
  if (!draft.length) return base;
  return [...base, ...draft];
}

function pickFestivalAiImages(fest, panelEl = null) {
  const allowTypes = new Set(['tt', 'luall', 'other']);
  const allImages = mergeFestivalImagesWithPanelDraft(fest, panelEl);
  const list = allImages.filter((img) => img?.classified && allowTypes.has(img.classified.type));
  return list.sort((a, b) => {
    const oa = Number(a?.classified?.order || 99);
    const ob = Number(b?.classified?.order || 99);
    if (oa !== ob) return oa - ob;
    const sa = Number(a?.classified?.sort || 99);
    const sb = Number(b?.classified?.sort || 99);
    return sa - sb;
  });
}

function pickFestivalPosterImages(fest, panelEl = null) {
  const imgs = [...mergeFestivalImagesWithPanelDraft(fest, panelEl)];
  return imgs.sort((a, b) => {
    const oa = Number(a?.classified?.order || 99);
    const ob = Number(b?.classified?.order || 99);
    if (oa !== ob) return oa - ob;
    const sa = Number(a?.classified?.sort || 99);
    const sb = Number(b?.classified?.sort || 99);
    if (sa !== sb) return sa - sb;
    return String(a?.filename || '').localeCompare(String(b?.filename || ''));
  });
}

function detectImageFileType(img, imageInput = '') {
  // Poster workflow expects coarse type literals: image/video/audio/document/default.
  // For this button we always submit image posters.
  return 'image';
}

function posterEmptyFields() {
  return {
    name_en: '',
    name_zh: '',
    start_date: '',
    end_date: '',
    country_en: '',
    country_en_full: '',
    country_zh: '',
    city_en: '',
    city_zh: '',
    detail_address_en: '',
    detail_address_zh: '',
  };
}

function normalizePosterDate(text) {
  const src = String(text || '').trim();
  if (!src) return '';
  const m = src.match(/^(\d{4})[\/.:-](\d{1,2})[\/.:-](\d{1,2})$/);
  if (!m) return src;
  return `${m[1]}-${String(parseInt(m[2], 10)).padStart(2, '0')}-${String(parseInt(m[3], 10)).padStart(2, '0')}`;
}

function normalizePosterBi(raw, fallback = '') {
  if (typeof normalizeBiTextValue === 'function') {
    return normalizeBiTextValue(raw, fallback);
  }
  const fallbackText = String(fallback || '').trim();
  if (raw && typeof raw === 'object') {
    const en = String(raw.en || raw.english || raw.name_en || '').trim();
    const zh = String(raw.zh || raw.chinese || raw.name_zh || raw.cn || '').trim();
    if (en || zh) {
      return { en: en || zh || fallbackText, zh: zh || en || fallbackText };
    }
  }
  const scalar = String(raw || fallbackText || '').trim();
  return { en: scalar, zh: scalar };
}

function normalizePosterInfo(raw) {
  const src = (raw && typeof raw === 'object') ? raw : {};
  const manualLocation = (src.manualLocation && typeof src.manualLocation === 'object')
    ? src.manualLocation
    : ((src.manual_location && typeof src.manual_location === 'object') ? src.manual_location : {});
  const nameBi = normalizePosterBi(
    src.nameI18n
      ?? src.name_i18n
      ?? src.eventNameI18n
      ?? src.event_name_i18n
      ?? src.event_name
      ?? src.eventName
      ?? src.name
      ?? src.title,
    String(src.event_name || src.eventName || src.name || src.title || '').trim()
  );
  const countrySeed = src.countryI18n
    ?? src.country_i18n
    ?? {
      en: src.country_en ?? src.countryEn ?? src.country ?? '',
      zh: src.country_zh ?? src.countryZh ?? src.country ?? '',
      enFull: src.country_en_full ?? src.countryEnFull ?? src.countryEnglishFull ?? '',
    };
  const countryBi = normalizeCountryBiTextValue(
    countrySeed,
    String(src.country || '').trim()
  );
  const cityBi = normalizePosterBi(
    src.cityI18n ?? src.city_i18n ?? src.city,
    String(src.city || '').trim()
  );
  const detailAddressBi = normalizePosterBi(
    src.detailAddressI18n
      ?? src.detail_address_i18n
      ?? src.venueI18n
      ?? src.venue_i18n
      ?? manualLocation.detailAddressI18n
      ?? manualLocation.detail_address_i18n
      ?? src.venue
      ?? src.location
      ?? src.place
      ?? src.address,
    String(src.venue || src.location || src.place || src.address || '').trim()
  );
  const out = {
    name_en: String(nameBi.en || '').trim(),
    name_zh: String(nameBi.zh || '').trim(),
    start_date: normalizePosterDate(src.start_date || src.startDate || ''),
    end_date: normalizePosterDate(src.end_date || src.endDate || ''),
    country_en: String(countryBi.en || '').trim(),
    country_en_full: String(countryBi.enFull || countryBi.en || '').trim(),
    country_zh: String(countryBi.zh || '').trim(),
    city_en: String(cityBi.en || '').trim(),
    city_zh: String(cityBi.zh || '').trim(),
    detail_address_en: String(detailAddressBi.en || '').trim(),
    detail_address_zh: String(detailAddressBi.zh || '').trim(),
  };
  if (out.start_date && !out.end_date) out.end_date = out.start_date;
  if (out.end_date && !out.start_date) out.start_date = out.end_date;
  return out;
}

function countPosterFields(info) {
  const x = normalizePosterInfo(info);
  return POSTER_INFO_FIELDS.reduce((n, k) => n + (x[k] ? 1 : 0), 0);
}

function posterSetModalStatus(text, isError = false) {
  const el = document.getElementById('poster-modal-status');
  if (!el) return;
  el.textContent = String(text || '');
  el.style.color = isError ? 'var(--accent2)' : 'var(--text-dim)';
}

function posterSetRunStatus(text) {
  const el = document.getElementById('poster-run-status');
  if (el) el.textContent = String(text || '');
}

function posterRefreshButtonState() {
  const st = posterReviewState;
  const runBtn = document.getElementById('poster-run-btn');
  const applyBtn = document.getElementById('poster-apply-btn');
  if (!runBtn || !applyBtn) return;
  if (!st) {
    runBtn.disabled = true;
    applyBtn.disabled = true;
    return;
  }
  const hasField = POSTER_INFO_FIELDS.some((k) => String(st.fields[k] || '').trim());
  runBtn.disabled = !!st.running;
  applyBtn.disabled = !!st.running || !hasField;
}

function posterRenderImageList() {
  const st = posterReviewState;
  const listEl = document.getElementById('poster-image-list');
  if (!st || !listEl) return;
  if (!st.images.length) {
    listEl.innerHTML = '<div class="coze-result-empty">该活动没有图片可识别</div>';
    posterRefreshButtonState();
    return;
  }
  listEl.innerHTML = st.images.map((img, i) => {
    const selected = st.imageSelected[i] ? 'checked' : '';
    const status = st.imageStates[i] || { state: 'idle', message: '待识别' };
    const statusClass = status.state === 'done' ? 'ok' : (status.state === 'error' ? 'err' : (status.state === 'running' ? 'run' : ''));
    return `
      <div class="poster-image-item">
        <div class="poster-image-top">
          <input type="checkbox" ${selected} ${st.running ? 'disabled' : ''} onchange="posterToggleImage(${i}, this.checked)">
          <div>
            <div class="poster-image-name">${escapeHtml(img.filename || `图片${i + 1}`)}</div>
            <div class="poster-image-type">${escapeHtml(img.classified?.label || 'UNKNOWN')}</div>
          </div>
        </div>
        <div class="poster-image-status ${statusClass}">${escapeHtml(status.message || '待识别')}</div>
      </div>
    `;
  }).join('');
  posterRefreshButtonState();
}

function posterRenderFields() {
  const st = posterReviewState;
  if (!st) return;
  for (const f of POSTER_INFO_FIELDS) {
    const el = document.getElementById(`poster-field-${f}`);
    if (el) el.value = String(st.fields[f] || '');
  }
  const summary = document.getElementById('poster-fields-summary');
  if (summary) {
    const recognized = st.imageInfos.filter(Boolean).length;
    const selectedCount = st.imageSelected.filter(Boolean).length;
    const filled = POSTER_INFO_FIELDS.filter((k) => String(st.fields[k] || '').trim()).length;
    summary.textContent = `已识别 ${recognized} 张图片（当前勾选 ${selectedCount} 张），整合后有 ${filled}/${POSTER_INFO_FIELDS.length} 个字段。`;
  }
  posterRefreshButtonState();
}

function posterSelectAllImages(checked) {
  const st = posterReviewState;
  if (!st || st.running) return;
  st.imageSelected = st.images.map(() => !!checked);
  posterRenderImageList();
  posterRenderFields();
}

function posterToggleImage(idx, checked) {
  const st = posterReviewState;
  if (!st || st.running) return;
  st.imageSelected[idx] = !!checked;
  posterRenderFields();
}

function posterSetImageState(idx, state, message) {
  const st = posterReviewState;
  if (!st) return;
  st.imageStates[idx] = { state, message };
  posterRenderImageList();
}

function posterSelectedImageIndexes() {
  const st = posterReviewState;
  if (!st) return [];
  const out = [];
  for (let i = 0; i < st.images.length; i += 1) {
    if (st.imageSelected[i]) out.push(i);
  }
  return out;
}

function pickBestPosterValue(values) {
  const arr = values.map((v) => String(v || '').trim()).filter(Boolean);
  if (!arr.length) return '';
  const stat = new Map();
  arr.forEach((v, i) => {
    if (!stat.has(v)) stat.set(v, { count: 0, first: i });
    stat.get(v).count += 1;
  });
  const sorted = [...stat.entries()].sort((a, b) => {
    if (b[1].count !== a[1].count) return b[1].count - a[1].count;
    if (b[0].length !== a[0].length) return b[0].length - a[0].length;
    return a[1].first - b[1].first;
  });
  return sorted[0][0];
}

function aggregatePosterFields(imageInfos, imageSelected) {
  const out = posterEmptyFields();
  const candidates = Object.fromEntries(POSTER_INFO_FIELDS.map((fieldKey) => [fieldKey, []]));
  for (let i = 0; i < imageInfos.length; i += 1) {
    if (!imageSelected[i]) continue;
    const info = imageInfos[i];
    if (!info) continue;
    for (const f of POSTER_INFO_FIELDS) {
      const v = String(info[f] || '').trim();
      if (v) candidates[f].push(v);
    }
  }
  for (const f of POSTER_INFO_FIELDS) {
    out[f] = pickBestPosterValue(candidates[f]);
  }
  if (out.start_date && !out.end_date) out.end_date = out.start_date;
  if (out.end_date && !out.start_date) out.start_date = out.end_date;
  return out;
}

function refreshPosterAggregatedFields() {
  const st = posterReviewState;
  if (!st) return;
  st.fields = aggregatePosterFields(st.imageInfos, st.imageSelected);
  posterRenderFields();
}

function posterUpdateField(field, value) {
  const st = posterReviewState;
  if (!st || !POSTER_INFO_FIELDS.includes(field)) return;
  st.fields[field] = (field === 'start_date' || field === 'end_date')
    ? normalizePosterDate(value)
    : String(value || '').trim();
  posterRenderFields();
}

function posterClearFields() {
  const st = posterReviewState;
  if (!st) return;
  st.fields = posterEmptyFields();
  posterRenderFields();
  posterSetModalStatus('已清空整合字段。');
}

function openPosterReviewModal(fest, panelEl, btnEl, statusEl, imgs, options = {}) {
  posterReviewState = {
    fest,
    panelEl,
    statusEl,
    originBtn: btnEl,
    images: imgs,
    imageSelected: imgs.map(() => true),
    imageStates: imgs.map(() => ({ state: 'idle', message: '待识别' })),
    imageInfos: imgs.map(() => null),
    fields: posterEmptyFields(),
    running: false,
    applyMode: options?.applyMode === 'form' ? 'form' : 'edit',
  };
  btnEl.disabled = true;
  const titleEl = document.getElementById('poster-modal-title');
  const subEl = document.getElementById('poster-modal-sub');
  if (titleEl) {
    const nameBi = normalizeBiTextValue(fest.info.nameI18n ?? fest.info.name ?? fest.name ?? fest.folder, fest.folder);
    titleEl.innerHTML = `海报活动信息识别 · ${renderBiTextHtml(nameBi, { compact: true, fallback: fest.folder })}`;
  }
  if (subEl) subEl.textContent = `${imgs.length} 张候选图片，可多选识别并统一整合`;
  posterSetModalStatus('');
  posterSetRunStatus('请选择一个或多个海报图片后点击“识别选中海报的活动信息”，识别结果会自动整合到右侧。');
  posterRenderImageList();
  posterRenderFields();
  document.getElementById('poster-modal-overlay').classList.add('open');
  document.body.style.overflow = 'hidden';
  posterRefreshButtonState();
}

function closePosterReviewModal() {
  const st = posterReviewState;
  if (st?.running) {
    posterSetModalStatus('识别进行中，请等待当前任务完成后再关闭。', true);
    return;
  }
  document.getElementById('poster-modal-overlay').classList.remove('open');
  document.body.style.overflow = '';
  if (st?.originBtn) st.originBtn.disabled = false;
  posterReviewState = null;
}

function handlePosterOverlayClick(e) {
  if (e.target === document.getElementById('poster-modal-overlay')) closePosterReviewModal();
}

async function runCozePosterInfoRecognition(fest, panelEl, btnEl, statusEl, options = {}) {
  const customImages = Array.isArray(options?.images) ? options.images : null;
  const imgs = customImages || pickFestivalPosterImages(fest, panelEl);
  if (!imgs.length) {
    statusEl.textContent = '未找到可用于海报识别的图片';
    return;
  }
  openPosterReviewModal(fest, panelEl, btnEl, statusEl, imgs, options);
}

async function posterRecognizeSelectedImages() {
  const st = posterReviewState;
  if (!st || st.running) return;
  const indexes = posterSelectedImageIndexes();
  if (!indexes.length) {
    posterSetModalStatus('请先至少勾选一张图片。', true);
    return;
  }

  st.running = true;
  posterSetModalStatus('');
  posterRefreshButtonState();
  posterRenderImageList();

  let okCount = 0;
  let failCount = 0;
  try {
    for (let i = 0; i < indexes.length; i += 1) {
      const idx = indexes[i];
      const img = st.images[idx];
      posterSetImageState(idx, 'running', `识别中 ${i + 1}/${indexes.length}...`);
      posterSetRunStatus(`海报识别中 ${i + 1}/${indexes.length}: ${img.filename}`);
      try {
        const posterImage = await imageToCozeInput(img);
        const resp = await apiPost('/api/coze/poster-info', {
          poster_image: posterImage,
          file_type: detectImageFileType(img, posterImage),
        });
        const info = normalizePosterInfo(resp?.event_info || {});
        const n = countPosterFields(info);
        if (!n) {
          st.imageInfos[idx] = null;
          posterSetImageState(idx, 'error', '未提取到有效字段');
          failCount += 1;
        } else {
          st.imageInfos[idx] = info;
          posterSetImageState(idx, 'done', `提取到 ${n} 个字段`);
          okCount += 1;
        }
      } catch (e) {
        st.imageInfos[idx] = null;
        posterSetImageState(idx, 'error', `失败：${e.message}`);
        failCount += 1;
      }
      refreshPosterAggregatedFields();
    }
  } finally {
    st.running = false;
    posterRenderImageList();
    posterRenderFields();
    posterRefreshButtonState();
  }

  posterSetRunStatus(`识别完成：成功 ${okCount} 张，失败 ${failCount} 张。你可以继续手动修改整合结果，然后应用到编辑区。`);
}

function posterApplyToEditForm() {
  const st = posterReviewState;
  if (!st || st.running) return;
  const f = st.fields || posterEmptyFields();
  const hasAny = POSTER_INFO_FIELDS.some((k) => String(f[k] || '').trim());
  if (!hasAny) {
    posterSetModalStatus('当前没有可应用的识别结果。', true);
    return;
  }

  if (st.applyMode !== 'form') {
    setEditInputs(st.panelEl, st.fest.info);
    toggleInfoEdit(st.panelEl, true);
  }
  if (f.name_en) setEditFieldValue(st.panelEl, 'nameEn', f.name_en);
  if (f.name_zh) setEditFieldValue(st.panelEl, 'nameZh', f.name_zh);
  if (f.start_date) setEditFieldValue(st.panelEl, 'startDate', f.start_date);
  if (f.end_date) setEditFieldValue(st.panelEl, 'endDate', f.end_date);
  if (f.country_en) setEditFieldValue(st.panelEl, 'countryEn', f.country_en);
  if (f.country_en_full) setEditFieldValue(st.panelEl, 'countryEnFull', f.country_en_full);
  if (f.country_zh) setEditFieldValue(st.panelEl, 'countryZh', f.country_zh);
  if (f.city_en) setEditFieldValue(st.panelEl, 'cityEn', f.city_en);
  if (f.city_zh) setEditFieldValue(st.panelEl, 'cityZh', f.city_zh);
  if (f.detail_address_en) setEditFieldValue(st.panelEl, 'detailAddressEn', f.detail_address_en);
  if (f.detail_address_zh) setEditFieldValue(st.panelEl, 'detailAddressZh', f.detail_address_zh);

  const parts = [];
  if (f.name_en || f.name_zh) parts.push('名称');
  if (f.start_date || f.end_date) parts.push('日期');
  if (f.country_en || f.country_en_full || f.country_zh) parts.push('国家');
  if (f.city_en || f.city_zh) parts.push('城市');
  if (f.detail_address_en || f.detail_address_zh) parts.push('详细地址');
  setPanelEditStatus(st.panelEl, `海报识别结果已回填：${parts.join('、') || '基础字段'}。请确认后点击“保存到 JSON”。`);
  if (st.statusEl) {
    st.statusEl.textContent = st.applyMode === 'form'
      ? '海报识别结果已回填到表单（未自动保存）'
      : '海报识别结果已回填到编辑状态（未自动保存）';
  }
  closePosterReviewModal();
}

function setEditFieldValue(panelEl, key, value) {
  const val = String(value ?? '');
  const setByKey = (k, v) => {
    const el = panelEl.querySelector(`.fest-info-edit [data-field="${k}"]`);
    if (el) el.value = String(v ?? '');
    return el;
  };

  // Backward-compatible aliases from old single-language fields.
  if (key === 'name') {
    const enEl = setByKey('nameEn', val);
    const zhEl = panelEl.querySelector(`.fest-info-edit [data-field="nameZh"]`);
    if (zhEl && !String(zhEl.value || '').trim()) zhEl.value = val;
    return enEl;
  }
  if (key === 'location') {
    const zhEl = setByKey('detailAddressZh', val);
    const enEl = panelEl.querySelector(`.fest-info-edit [data-field="detailAddressEn"]`);
    if (enEl && !String(enEl.value || '').trim()) enEl.value = val;
    return zhEl;
  }
  if (key === 'country') {
    const zhEl = setByKey('countryZh', val);
    const enEl = panelEl.querySelector(`.fest-info-edit [data-field="countryEn"]`);
    const enFullEl = panelEl.querySelector(`.fest-info-edit [data-field="countryEnFull"]`);
    if (enEl && !String(enEl.value || '').trim()) enEl.value = val;
    if (enFullEl && !String(enFullEl.value || '').trim()) enFullEl.value = val;
    return zhEl;
  }

  return setByKey(key, val);
}

function setPanelEditStatus(panelEl, text, isError = false) {
  const el = panelEl.querySelector('.edit-save-status');
  if (!el) return;
  el.textContent = String(text || '');
  el.style.color = isError ? 'var(--accent2)' : 'var(--text-dim)';
}
