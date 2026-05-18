// ── IMAGE LIGHTBOX ──
const EVENT_DJ_IMAGE_SCOPE_SELECTOR = [
  '#archive-page',
  '#event-editor-overlay',
  '#add-event-modal-overlay',
  '#dj-page',
  '#dj-profile-overlay',
  '#tt-modal-overlay',
  '#tt-dj-bind-overlay',
  '#dj-source-replace-overlay',
].join(', ');

const EVENT_DJ_IMAGE_GROUP_SELECTOR = [
  '.edit-existing-assets-list',
  '.dj-grid',
  '.tt-dj-existing-list',
  '.tt-dj-source-list',
  '.tt-dj-compare-table',
  '.dj-profile-body',
  '.dj-source-replace-body',
  '.tt-dj-avatar-preview',
  '.dj-avatar-edit-preview',
].join(', ');

function lbEmitEvent(key, fallback, detail = {}) {
  const bus = window.AppEventBus;
  if (!bus || typeof bus.emit !== 'function') return;
  const eventName = String(window.AppEvents?.[key] || fallback);
  bus.emit(eventName, detail);
}

function resolveFestivalImageDisplayUrl(img) {
  const raw = String(img?.url || img?.remoteUrl || '').trim();
  return ttToAbsoluteLocalUrl(raw) || EVENT_IMAGE_PLACEHOLDER_DATA_URL;
}

function lbNormalizeItemType(value) {
  const normalized = String(value || '').trim().toLowerCase();
  if (!normalized) return 'other';
  if (TYPE_COLOR[normalized]) return normalized;
  if (normalized.includes('cover')) return 'cover';
  if (normalized.includes('lineup')) return 'luall';
  if (normalized.includes('time')) return 'tt';
  return 'other';
}

function lbBuildDownloadName(item, blobType = '') {
  const fallbackExt = guessImageExtFromNameOrUrl(
    String(item?.downloadUrl || item?.url || '').trim(),
    blobType
  ) || '.jpg';
  const rawName = String(
    item?.downloadName
    || pathBaseNameFromUrl(item?.downloadUrl || item?.url || '')
    || `image${fallbackExt}`
  ).trim();
  const extFromName = rawName.match(/\.([a-z0-9]{2,8})(?:$|[?#])/i);
  const ext = extFromName ? `.${extFromName[1].toLowerCase()}` : fallbackExt;
  const base = rawName.replace(/\.[a-z0-9]{2,8}(?:$|[?#].*)/i, '').trim() || 'image';
  return sanitizeEventImageFileName(`${base}${ext}`, `image${ext}`);
}

function lbResolveDownloadUrl(rawUrl) {
  const src = String(rawUrl || '').trim();
  if (!src) return '';
  if (/^(?:blob:|data:)/i.test(src)) return src;
  if (/^https?:/i.test(src)) return `${getScraperApiBase()}/api/proxy-image?url=${encodeURIComponent(src)}`;
  return ttToAbsoluteLocalUrl(src) || src;
}

function lbResetDownloadButton(text = '⬇ DOWNLOAD', disabled = false) {
  const btn = document.getElementById('lb-download-btn');
  if (!btn) return;
  btn.textContent = String(text || '⬇ DOWNLOAD');
  btn.disabled = !!disabled;
}

function lbBuildItemsFromFestival(fest) {
  const list = Array.isArray(fest?.images) ? fest.images : [];
  return list.map((img) => {
    const displayUrl = resolveFestivalImageDisplayUrl(img);
    const downloadUrl = String(img?.remoteUrl || img?.url || '').trim() || displayUrl;
    const fileName = sanitizeEventImageFileName(
      String(img?.filename || pathBaseNameFromUrl(downloadUrl)).trim(),
      `image${guessImageExtFromNameOrUrl(downloadUrl)}`
    );
    return {
      url: displayUrl,
      label: img?.classified?.label || img?.sourceAsset?.label || 'IMAGE',
      type: lbNormalizeItemType(img?.classified?.type || img?.sourceAsset?.type || 'other'),
      downloadUrl,
      downloadName: fileName,
    };
  });
}

function openLightboxItems(items, startIdx, titleText = 'IMAGE PREVIEW') {
  const normalizedItems = (Array.isArray(items) ? items : [])
    .map((item, idx) => {
      const displayUrl = ttToAbsoluteLocalUrl(String(item?.url || '').trim()) || String(item?.url || '').trim();
      if (!displayUrl) return null;
      const label = String(item?.label || `IMAGE ${idx + 1}`).trim() || `IMAGE ${idx + 1}`;
      return {
        url: displayUrl,
        label,
        type: lbNormalizeItemType(item?.type || 'other'),
        downloadUrl: String(item?.downloadUrl || displayUrl).trim() || displayUrl,
        downloadName: String(item?.downloadName || '').trim(),
      };
    })
    .filter(Boolean);
  if (!normalizedItems.length) return;

  lbImages = normalizedItems;
  lbIndex = Math.max(0, Math.min(Number(startIdx || 0), lbImages.length - 1));
  document.getElementById('lb-title').textContent = String(titleText || 'IMAGE PREVIEW');
  buildLbFooter(lbImages);
  renderLbImage();
  document.getElementById('lightbox').classList.add('open');
  document.body.style.overflow = 'hidden';
  lbEmitEvent('LIGHTBOX_OPENED', 'lightbox:opened', {
    count: lbImages.length,
    index: lbIndex,
    title: String(titleText || 'IMAGE PREVIEW'),
  });
}

async function openLightboxWithCache(fest, row, startIdx) {
  if (fest?.backendEventId && row && rootDirHandle) {
    try {
      await hydrateFestivalImageCacheForRow(fest, row);
    } catch (_error) {
      // Ignore cache hydration failures and fallback to remote display.
    }
  }
  openLightbox(fest, startIdx);
}

function openLightbox(fest, startIdx) {
  const title = `${fest.name}${fest.location ? ` · ${fest.location}` : ''} — ${fest.year}年${fest.month}月`;
  openLightboxItems(lbBuildItemsFromFestival(fest), startIdx, title);
}

function buildLbFooter(items) {
  const footer = document.getElementById('lb-footer');
  footer.innerHTML = '';
  const groups = [];
  let lastType = null;
  (Array.isArray(items) ? items : []).forEach((img, gi) => {
    const itemType = lbNormalizeItemType(img?.type || 'other');
    if (itemType !== lastType) {
      groups.push({ type: itemType, items: [] });
      lastType = itemType;
    }
    groups[groups.length - 1].items.push({ img, gi });
  });
  groups.forEach((group, idx) => {
    if (idx > 0) { const sep = document.createElement('div'); sep.className = 'lb-thumb-sep'; footer.appendChild(sep); }
    const grp = document.createElement('div'); grp.className = 'lb-thumb-group';
    group.items.forEach(({ img, gi }) => {
      const item = document.createElement('div'); item.className = 'lb-thumb-item'; item.dataset.idx = gi;
      const t = document.createElement('img');
      t.src = String(img?.url || EVENT_IMAGE_PLACEHOLDER_DATA_URL);
      t.alt = String(img?.label || `IMAGE ${gi + 1}`);
      const lbl = document.createElement('div');
      lbl.className = 'lb-thumb-label';
      lbl.textContent = String(img?.label || `IMAGE ${gi + 1}`);
      item.appendChild(t); item.appendChild(lbl);
      item.onclick = () => { lbIndex = gi; renderLbImage(); };
      grp.appendChild(item);
    });
    footer.appendChild(grp);
  });
}

function renderLbImage() {
  const img = lbImages[lbIndex];
  if (!img) {
    lbResetDownloadButton('⬇ DOWNLOAD', true);
    return;
  }
  const el = document.getElementById('lb-main-img');
  el.src = String(img.url || EVENT_IMAGE_PLACEHOLDER_DATA_URL);
  el.alt = String(img.label || 'IMAGE');
  const badge = document.getElementById('lb-type-badge');
  badge.textContent = String(img.label || 'IMAGE');
  const c = TYPE_COLOR[lbNormalizeItemType(img.type)] || '#6b6b8a';
  badge.style.borderColor = c; badge.style.color = c;
  document.getElementById('lb-counter').textContent = `${lbIndex+1} / ${lbImages.length}`;
  document.getElementById('lb-prev').disabled = lbIndex === 0;
  document.getElementById('lb-next').disabled = lbIndex === lbImages.length - 1;
  document.querySelectorAll('.lb-thumb-item').forEach(el => el.classList.toggle('active', parseInt(el.dataset.idx) === lbIndex));
  const active = document.querySelector('.lb-thumb-item.active');
  if (active) active.scrollIntoView({ behavior:'smooth', inline:'center', block:'nearest' });
  const hasDownload = !!String(img.downloadUrl || img.url || '').trim();
  lbResetDownloadButton('⬇ DOWNLOAD', !hasDownload);
}

function lbNavigate(dir) {
  const n = lbIndex + dir;
  if (n < 0 || n >= lbImages.length) return;
  lbIndex = n; renderLbImage();
}

async function downloadCurrentLightboxImage() {
  const img = lbImages[lbIndex];
  if (!img) return;
  const sourceUrl = String(img.downloadUrl || img.url || '').trim();
  if (!sourceUrl) {
    lbResetDownloadButton('NO FILE', true);
    return;
  }
  lbResetDownloadButton('DOWNLOADING...', true);
  try {
    const fetchUrl = lbResolveDownloadUrl(sourceUrl);
    const resp = await fetch(fetchUrl);
    if (!resp.ok) throw new Error(`下载失败 (${resp.status})`);
    const blob = await resp.blob();
    if (!(blob instanceof Blob) || blob.size <= 0) throw new Error('图片内容为空');
    const fileName = lbBuildDownloadName(img, blob.type || '');
    const objectUrl = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = objectUrl;
    a.download = fileName;
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(() => {
      try { URL.revokeObjectURL(objectUrl); } catch (_error) {}
    }, 1000);
    lbResetDownloadButton('DOWNLOADED', false);
    setTimeout(() => {
      const stillOpen = document.getElementById('lightbox')?.classList.contains('open');
      if (stillOpen) renderLbImage();
    }, 700);
  } catch (_error) {
    lbResetDownloadButton('DOWNLOAD FAIL', false);
    setTimeout(() => {
      const stillOpen = document.getElementById('lightbox')?.classList.contains('open');
      if (stillOpen) renderLbImage();
    }, 900);
  }
}

function closeLightbox() {
  document.getElementById('lightbox').classList.remove('open');
  lbImages = [];
  lbIndex = 0;
  lbResetDownloadButton('⬇ DOWNLOAD', false);
  document.body.style.overflow = '';
  lbEmitEvent('LIGHTBOX_CLOSED', 'lightbox:closed', {});
}
