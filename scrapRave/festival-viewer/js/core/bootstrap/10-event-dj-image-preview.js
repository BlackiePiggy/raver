function isEventDjImageInScope(imgEl) {
  return !!imgEl?.closest?.(EVENT_DJ_IMAGE_SCOPE_SELECTOR);
}

function shouldOpenEventDjImagePreview(imgEl) {
  if (!imgEl || !isEventDjImageInScope(imgEl)) return false;
  if (imgEl.closest('#lightbox')) return false;
  if (imgEl.closest('.img-cell')) return false;
  const src = String(imgEl.currentSrc || imgEl.src || '').trim();
  if (!src || src === EVENT_IMAGE_PLACEHOLDER_DATA_URL) return false;
  return true;
}

function buildLightboxItemFromImageElement(imgEl, fallbackIndex = 0) {
  const srcRaw = String(imgEl?.getAttribute('data-full-src') || imgEl?.currentSrc || imgEl?.src || '').trim();
  const displayUrl = ttToAbsoluteLocalUrl(srcRaw) || srcRaw;
  if (!displayUrl) return null;
  const label = String(imgEl?.getAttribute('data-lb-label') || imgEl?.alt || `IMAGE ${fallbackIndex + 1}`).trim() || `IMAGE ${fallbackIndex + 1}`;
  const type = lbNormalizeItemType(imgEl?.getAttribute('data-lb-type') || 'other');
  const downloadUrl = String(
    imgEl?.getAttribute('data-download-url')
    || imgEl?.getAttribute('data-original-url')
    || srcRaw
    || displayUrl
  ).trim();
  const downloadName = String(
    imgEl?.getAttribute('data-filename')
    || imgEl?.getAttribute('data-file-name')
    || pathBaseNameFromUrl(downloadUrl || displayUrl)
  ).trim();
  return {
    url: displayUrl,
    label,
    type,
    downloadUrl: downloadUrl || displayUrl,
    downloadName,
  };
}

function eventDjImagePreviewTitleForElement(imgEl) {
  if (imgEl?.closest('#dj-page')) return 'DJ 图片预览';
  if (imgEl?.closest('#dj-profile-overlay')) return 'DJ 资料图片预览';
  if (imgEl?.closest('#tt-dj-bind-overlay') || imgEl?.closest('#tt-modal-overlay') || imgEl?.closest('#dj-source-replace-overlay')) {
    return 'DJ 候选头像预览';
  }
  if (imgEl?.closest('#archive-page') || imgEl?.closest('#add-event-modal-overlay') || imgEl?.closest('#event-editor-overlay')) {
    return 'Event 图片预览';
  }
  return '图片预览';
}

function collectEventDjImageGroup(imgEl) {
  const groupRoot = imgEl?.closest(EVENT_DJ_IMAGE_GROUP_SELECTOR);
  if (!groupRoot) return [imgEl];
  const group = Array.from(groupRoot.querySelectorAll('img')).filter((node) => shouldOpenEventDjImagePreview(node));
  return group.length ? group : [imgEl];
}

function openEventDjImagePreviewFromElement(imgEl) {
  const group = collectEventDjImageGroup(imgEl);
  const items = [];
  let startIdx = 0;
  group.forEach((node, idx) => {
    const item = buildLightboxItemFromImageElement(node, idx);
    if (!item) return;
    if (node === imgEl) startIdx = items.length;
    items.push(item);
  });
  if (!items.length) return;
  openLightboxItems(items, startIdx, eventDjImagePreviewTitleForElement(imgEl));
}

function handleEventDjImagePreviewClick(event) {
  const imgEl = event?.target?.closest?.('img');
  if (!shouldOpenEventDjImagePreview(imgEl)) return;
  event.preventDefault();
  event.stopPropagation();
  openEventDjImagePreviewFromElement(imgEl);
}

document.addEventListener('click', handleEventDjImagePreviewClick, true);

