// Feature module extracted from monolith
function createEmptyEventImageDraftState() {
  return Object.fromEntries(EVENT_IMAGE_ZONES.map((zone) => [zone.key, []]));
}

function getPanelEventImageDraftState(panel) {
  if (!panel) return createEmptyEventImageDraftState();
  if (!panel._eventImageDraft || typeof panel._eventImageDraft !== 'object') {
    panel._eventImageDraft = createEmptyEventImageDraftState();
  }
  for (const zone of EVENT_IMAGE_ZONES) {
    if (!Array.isArray(panel._eventImageDraft[zone.key])) panel._eventImageDraft[zone.key] = [];
  }
  return panel._eventImageDraft;
}

function createExistingEventAssetDraftEntries(fest) {
  const assets = normalizeBackendEventImageAssets(fest?.info?.imageAssets);
  const entries = assets.map((asset, index) => {
    const url = String(asset?.url || '').trim();
    const originalFileName = sanitizeEventImageFileName(
      asset?.fileName || pathBaseNameFromUrl(url) || `asset-${index + 1}${guessImageExtFromNameOrUrl(url)}`
    );
    const zoneKey = normalizeEventImageZoneKey(inferEventImageZoneFromAsset(asset));
    return {
      id: `ea-${index}-${Math.random().toString(36).slice(2, 7)}`,
      url,
      source: String(asset?.source || '').trim() || undefined,
      originalUrl: String(asset?.originalUrl || '').trim() || undefined,
      oldType: String(asset?.type || '').trim().toLowerCase() || 'other',
      oldLabel: String(asset?.label || '').trim() || undefined,
      oldFileName: originalFileName,
      oldZoneKey: zoneKey,
      zoneKey,
      type: backendTypeForImageZone(zoneKey),
      label: defaultImageLabelForZone(zoneKey),
      order: Number(EVENT_IMAGE_ZONE_MAP[zoneKey]?.order ?? 99),
      sort: Number.isFinite(asset?.sort) ? Number(asset.sort) : (index + 1),
      fileName: originalFileName,
      ext: guessImageExtFromNameOrUrl(originalFileName || url),
    };
  });
  return rebuildExistingEventAssetCanonicalNames(entries);
}

function rebuildExistingEventAssetCanonicalNames(entries) {
  const arr = Array.isArray(entries) ? entries : [];
  const usedNames = new Set();

  const registerName = (name) => {
    const key = String(name || '').trim().toLowerCase();
    if (!key) return false;
    if (usedNames.has(key)) return false;
    usedNames.add(key);
    return true;
  };

  // Keep original filename when zone is unchanged and filename is usable.
  for (const entry of arr) {
    const zoneKey = normalizeEventImageZoneKey(entry?.zoneKey);
    entry.zoneKey = zoneKey;
    const oldName = sanitizeEventImageFileName(entry?.oldFileName || '', '');
    const keepOldName = zoneKey === normalizeEventImageZoneKey(entry?.oldZoneKey) && !!oldName && registerName(oldName);
    entry.fileName = keepOldName ? oldName : '';
  }

  // For changed-zone rows, allocate a new name by zone + running index without colliding.
  for (const entry of arr) {
    if (entry.fileName) continue;
    const zoneKey = normalizeEventImageZoneKey(entry?.zoneKey);
    const ext = guessImageExtFromNameOrUrl(entry?.oldFileName || entry?.url || '', '');
    let index = 1;
    while (index < 9999) {
      const candidate = sanitizeEventImageFileName(
        `${zoneKey}${index > 1 ? `-${index}` : ''}${ext}`,
        `${zoneKey}${index > 1 ? `-${index}` : ''}.jpg`
      );
      if (registerName(candidate)) {
        entry.fileName = candidate;
        break;
      }
      index += 1;
    }
    if (!entry.fileName) {
      entry.fileName = sanitizeEventImageFileName(`${zoneKey}-${Date.now()}${ext}`, `${zoneKey}.jpg`);
      registerName(entry.fileName);
    }
  }

  // Rebuild asset type/order/sort by final zone order.
  const zoneCounters = Object.fromEntries(EVENT_IMAGE_ZONES.map((zone) => [zone.key, 0]));
  for (const entry of arr) {
    const zoneKey = normalizeEventImageZoneKey(entry?.zoneKey);
    zoneCounters[zoneKey] = (zoneCounters[zoneKey] || 0) + 1;
    entry.type = backendTypeForImageZone(zoneKey);
    entry.label = defaultImageLabelForZone(zoneKey);
    entry.order = Number(EVENT_IMAGE_ZONE_MAP[zoneKey]?.order ?? 99);
    entry.sort = zoneCounters[zoneKey];
  }
  return arr;
}

function getPanelExistingEventAssetDraft(panel, fest) {
  if (!panel || !fest) return [];
  const currentFestId = String(fest.backendEventId || fest.info?.festivalId || fest.folder || '');
  if (!Array.isArray(panel._existingEventAssets) || panel._existingEventAssetsFestID !== currentFestId) {
    panel._existingEventAssets = createExistingEventAssetDraftEntries(fest);
    panel._existingEventAssetsRemoved = [];
    panel._existingEventAssetsFestID = currentFestId;
  }
  return panel._existingEventAssets;
}

function getPanelRemovedExistingEventAssetDraft(panel, fest) {
  if (!panel || !fest) return [];
  getPanelExistingEventAssetDraft(panel, fest);
  if (!Array.isArray(panel._existingEventAssetsRemoved)) {
    panel._existingEventAssetsRemoved = [];
  }
  return panel._existingEventAssetsRemoved;
}

function markExistingEventAssetDeleted(panel, fest, entryID) {
  const entries = getPanelExistingEventAssetDraft(panel, fest);
  const index = entries.findIndex((entry) => String(entry?.id || '') === String(entryID || ''));
  if (index < 0) return false;
  const [removed] = entries.splice(index, 1);
  if (!removed) return false;
  const removedRows = getPanelRemovedExistingEventAssetDraft(panel, fest);
  removedRows.push({
    id: removed.id,
    url: removed.url,
    oldFileName: removed.oldFileName,
    oldType: removed.oldType,
    oldZoneKey: removed.oldZoneKey,
    fileName: removed.fileName,
  });
  rebuildExistingEventAssetCanonicalNames(entries);
  return true;
}

function renderExistingEventAssetDrafts(panel, fest) {
  if (!panel || !fest) return;
  const listEl = panel.querySelector('[data-existing-assets-list]');
  const summaryEl = panel.querySelector('[data-existing-assets-summary]');
  if (!listEl || !summaryEl) return;

  const entries = getPanelExistingEventAssetDraft(panel, fest);
  const removedRows = getPanelRemovedExistingEventAssetDraft(panel, fest);
  if (!entries.length) {
    summaryEl.textContent = removedRows.length
      ? `当前无已存在图片 · 已删除 ${removedRows.length} 张`
      : '当前无已存在图片';
    listEl.innerHTML = '<div class="edit-existing-assets-empty">当前无可编辑的已存在图片</div>';
    return;
  }

  const changedCount = entries.filter((entry) => normalizeEventImageZoneKey(entry.zoneKey) !== normalizeEventImageZoneKey(entry.oldZoneKey) || entry.fileName !== entry.oldFileName).length;
  summaryEl.textContent = `共 ${entries.length} 张 · 已调整 ${changedCount} 张${removedRows.length ? ` · 已删除 ${removedRows.length} 张` : ''}`;

  listEl.innerHTML = entries.map((entry) => {
    const thumbUrl = ttToAbsoluteLocalUrl(entry.url);
    const changed = entry.fileName !== entry.oldFileName || entry.type !== entry.oldType;
    const oldText = `${entry.oldType || 'other'} / ${entry.oldFileName || 'unknown'}`;
    const nextText = `${entry.type || 'other'} / ${entry.fileName || 'unknown'}`;
    return `
      <div class="edit-existing-asset-item">
        <img
          class="edit-existing-asset-thumb"
          src="${escapeHtml(thumbUrl || EVENT_IMAGE_PLACEHOLDER_DATA_URL)}"
          alt="${escapeHtml(entry.fileName || 'image')}"
          data-lb-label="${escapeHtml(entry.type || 'IMAGE')}"
          data-lb-type="${escapeHtml(entry.type || 'other')}"
          data-download-url="${escapeHtml(entry.url || thumbUrl || '')}"
          data-filename="${escapeHtml(entry.fileName || '')}"
        >
        <div class="edit-existing-asset-main">
          <div class="edit-existing-asset-name">${escapeHtml(entry.fileName || 'image.jpg')}</div>
          <div class="edit-existing-asset-meta ${changed ? 'changed' : ''}">${changed ? `原始：${escapeHtml(oldText)} → 现在：${escapeHtml(nextText)}` : `原始：${escapeHtml(oldText)}`}</div>
        </div>
        <select class="edit-existing-asset-zone" data-existing-zone-id="${escapeHtml(entry.id)}">
          ${EVENT_IMAGE_ZONES.map((zone) => `
            <option value="${zone.key}" ${entry.zoneKey === zone.key ? 'selected' : ''}>${escapeHtml(zone.label)}</option>
          `).join('')}
        </select>
        <button class="edit-existing-asset-remove" type="button" data-existing-remove-id="${escapeHtml(entry.id)}">删除</button>
      </div>
    `;
  }).join('');
}

function collectExistingEventAssetDraftPayload(panel, fest) {
  const entries = getPanelExistingEventAssetDraft(panel, fest);
  return entries.map((entry) => ({
    type: entry.type,
    label: entry.label,
    url: entry.url,
    source: entry.source,
    originalUrl: entry.originalUrl,
    fileName: entry.fileName,
    order: entry.order,
    sort: entry.sort,
    _oldFileName: entry.oldFileName,
    _oldType: entry.oldType,
  }));
}

function clearExistingEventAssetDraft(panel) {
  if (!panel) return;
  panel._existingEventAssets = null;
  panel._existingEventAssetsRemoved = [];
  panel._existingEventAssetsFestID = '';
}

function getEventExistingAssetZoneCount(fest, zoneKey, panel = null) {
  const key = normalizeEventImageZoneKey(zoneKey);
  if (panel && Array.isArray(panel._existingEventAssets)) {
    return panel._existingEventAssets.reduce((total, entry) => total + (normalizeEventImageZoneKey(entry?.zoneKey) === key ? 1 : 0), 0);
  }
  const assets = Array.isArray(fest?.info?.imageAssets) ? fest.info.imageAssets : [];
  return assets.reduce((total, asset) => total + (inferEventImageZoneFromAsset(asset) === key ? 1 : 0), 0);
}

function buildEventZoneRenamedFileName(zoneKey, index, sourceFile) {
  const normalizedZone = normalizeEventImageZoneKey(zoneKey);
  const suffix = index > 1 ? `-${index}` : '';
  const ext = guessImageExtFromNameOrUrl(sourceFile?.name || '', sourceFile?.type || '');
  return sanitizeEventImageFileName(`${normalizedZone}${suffix}${ext}`, `${normalizedZone}${suffix}.jpg`);
}

function renderEventImageZoneDrafts(panel, fest) {
  if (!panel || !fest) return;
  const draft = getPanelEventImageDraftState(panel);
  for (const zone of EVENT_IMAGE_ZONES) {
    const listEl = panel.querySelector(`[data-zone-list="${zone.key}"]`);
    const countEl = panel.querySelector(`[data-zone-count="${zone.key}"]`);
    if (!listEl || !countEl) continue;
    const existingCount = getEventExistingAssetZoneCount(fest, zone.key, panel);
    const queued = Array.isArray(draft[zone.key]) ? draft[zone.key] : [];
    countEl.textContent = `已存在 ${existingCount} · 待上传 ${queued.length}`;
    if (!queued.length) {
      listEl.innerHTML = '<div class="edit-image-zone-empty">未添加新图片</div>';
      continue;
    }
    listEl.innerHTML = queued.map((item) => `
      <div class="edit-image-zone-item">
        <span class="edit-image-zone-name">${escapeHtml(item.fileName || item.file?.name || 'image.jpg')}</span>
        <button class="edit-image-zone-remove" type="button" data-zone-remove="${zone.key}" data-zone-item-id="${escapeHtml(item.id)}">删除</button>
      </div>
    `).join('');
  }
}

async function queueEventImageFilesToZone(panel, fest, zoneKey, fileList) {
  if (!panel || !fest) return;
  const zone = EVENT_IMAGE_ZONE_MAP[normalizeEventImageZoneKey(zoneKey)];
  if (!zone) return;
  const files = Array.from(fileList || []).filter((file) => file && String(file.type || '').startsWith('image/'));
  if (!files.length) return;
  const draft = getPanelEventImageDraftState(panel);
  let nextIndex = getEventExistingAssetZoneCount(fest, zone.key, panel) + draft[zone.key].length + 1;
  for (const file of files) {
    const renamed = buildEventZoneRenamedFileName(zone.key, nextIndex, file);
    const renamedFile = new File([file], renamed, { type: file.type || 'image/jpeg', lastModified: file.lastModified || Date.now() });
    draft[zone.key].push({
      id: `z-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
      zoneKey: zone.key,
      file: renamedFile,
      fileName: renamed,
      addedAt: Date.now(),
    });
    nextIndex += 1;
  }
  renderEventImageZoneDrafts(panel, fest);
}

function removeEventImageDraftById(panel, zoneKey, itemId) {
  const zone = normalizeEventImageZoneKey(zoneKey);
  const draft = getPanelEventImageDraftState(panel);
  draft[zone] = (draft[zone] || []).filter((item) => String(item?.id || '') !== String(itemId || ''));
}

function clearEventImageDraftState(panel) {
  if (!panel) return;
  panel._eventImageDraft = createEmptyEventImageDraftState();
}

function collectEventImageDraftPayload(panel) {
  const draft = getPanelEventImageDraftState(panel);
  const out = {};
  for (const zone of EVENT_IMAGE_ZONES) {
    const items = Array.isArray(draft[zone.key]) ? draft[zone.key] : [];
    if (!items.length) continue;
    out[zone.key] = items
      .map((item) => {
        const file = item?.file;
        if (!file) return null;
        return {
          file,
          fileName: sanitizeEventImageFileName(item.fileName || file.name || ''),
          zoneKey: zone.key,
        };
      })
      .filter(Boolean);
  }
  return out;
}

function initEventImageUploadZones(panel, fest) {
  if (!panel || !fest) return;
  const draft = getPanelEventImageDraftState(panel);
  getPanelExistingEventAssetDraft(panel, fest);
  for (const zone of EVENT_IMAGE_ZONES) {
    const card = panel.querySelector(`[data-zone-card="${zone.key}"]`);
    const drop = panel.querySelector(`[data-zone-drop="${zone.key}"]`);
    const input = panel.querySelector(`[data-zone-input="${zone.key}"]`);
    const pickBtn = panel.querySelector(`[data-zone-pick="${zone.key}"]`);
    if (!card || !drop || !input || !pickBtn) continue;
    drop.addEventListener('dragover', (event) => {
      event.preventDefault();
      card.classList.add('drag-over');
    });
    drop.addEventListener('dragleave', () => {
      card.classList.remove('drag-over');
    });
    drop.addEventListener('drop', async (event) => {
      event.preventDefault();
      card.classList.remove('drag-over');
      const files = event.dataTransfer?.files;
      if (!files || !files.length) return;
      await queueEventImageFilesToZone(panel, fest, zone.key, files);
    });
    pickBtn.addEventListener('click', (event) => {
      event.preventDefault();
      input.click();
    });
    input.addEventListener('change', async () => {
      if (!input.files || !input.files.length) return;
      await queueEventImageFilesToZone(panel, fest, zone.key, input.files);
      input.value = '';
    });
  }

  panel.addEventListener('click', (event) => {
    const removeBtn = event.target.closest('[data-zone-remove]');
    if (removeBtn) {
      const zoneKey = removeBtn.getAttribute('data-zone-remove') || '';
      const itemId = removeBtn.getAttribute('data-zone-item-id') || '';
      removeEventImageDraftById(panel, zoneKey, itemId);
      renderEventImageZoneDrafts(panel, fest);
      return;
    }
    const removeExistingBtn = event.target.closest('[data-existing-remove-id]');
    if (!removeExistingBtn) return;
    const entryID = String(removeExistingBtn.getAttribute('data-existing-remove-id') || '').trim();
    if (!entryID) return;
    const sure = window.confirm('确认删除这张图片吗？保存后会同时删除本地缓存和 OSS 文件。');
    if (!sure) return;
    const deleted = markExistingEventAssetDeleted(panel, fest, entryID);
    if (!deleted) return;
    renderExistingEventAssetDrafts(panel, fest);
    renderEventImageZoneDrafts(panel, fest);
  });

  panel.addEventListener('change', (event) => {
    const zoneSelect = event.target.closest('[data-existing-zone-id]');
    if (!zoneSelect) return;
    const entryID = String(zoneSelect.getAttribute('data-existing-zone-id') || '').trim();
    const nextZoneKey = normalizeEventImageZoneKey(zoneSelect.value);
    const entries = getPanelExistingEventAssetDraft(panel, fest);
    const target = entries.find((entry) => entry.id === entryID);
    if (!target) return;
    target.zoneKey = nextZoneKey;
    rebuildExistingEventAssetCanonicalNames(entries);
    renderExistingEventAssetDrafts(panel, fest);
    renderEventImageZoneDrafts(panel, fest);
  });

  for (const zone of EVENT_IMAGE_ZONES) {
    if (!Array.isArray(draft[zone.key])) draft[zone.key] = [];
  }
  renderExistingEventAssetDrafts(panel, fest);
  renderEventImageZoneDrafts(panel, fest);
}

function patchFestivalFromBackendEvent(fest, backendEvent) {
  if (!fest || !backendEvent) return;
  const nextFest = mapBackendEventToFestival(backendEvent);
  releaseFestivalImageObjectUrls(fest);
  fest.year = nextFest.year;
  fest.month = nextFest.month;
  fest.name = nextFest.name;
  fest.location = nextFest.location;
  fest.backendEventId = nextFest.backendEventId;
  fest.sourceMode = 'backend';
  fest.info = nextFest.info;
  fest.images = nextFest.images;
  fest.cacheHydrated = false;
  fest.cacheHydrating = false;
  fest.cacheReconciled = false;
}

function buildEventImageZoneCardsHtml() {
  return EVENT_IMAGE_ZONES.map((zone) => `
    <div class="edit-image-zone-card" data-zone-card="${zone.key}">
      <div class="edit-image-zone-head">
        <span class="edit-image-zone-title">${escapeHtml(zone.label)}</span>
        <span class="edit-image-zone-count" data-zone-count="${zone.key}">已存在 0 · 待上传 0</span>
      </div>
      <div class="edit-image-zone-drop" data-zone-drop="${zone.key}">
        <input class="edit-image-zone-input" data-zone-input="${zone.key}" type="file" accept="image/*" multiple>
        <button class="edit-image-zone-pick" type="button" data-zone-pick="${zone.key}">选择图片</button>
        <div class="edit-image-zone-tip">拖拽图片到此处（可多选）</div>
      </div>
      <div class="edit-image-zone-list" data-zone-list="${zone.key}"></div>
    </div>
  `).join('');
}

