function keyboardEmitEvent(key, fallback, detail) {
  const bus = window.AppEventBus;
  if (!bus || typeof bus.emit !== 'function') return false;
  const eventName = String(window.AppEvents?.[key] || fallback);
  bus.emit(eventName, detail || {});
  return true;
}

function keyboardRequestClose(target, fallbackClose) {
  const emitted = keyboardEmitEvent('UI_REQUEST_CLOSE', 'ui:request-close', { target });
  if (!emitted && typeof fallbackClose === 'function') fallbackClose();
}

function keyboardRequestLightboxNavigate(direction) {
  const emitted = keyboardEmitEvent('LIGHTBOX_NAVIGATE', 'lightbox:navigate', { direction });
  if (!emitted && typeof lbNavigate === 'function') lbNavigate(direction);
}

function keyboardGetDispatcher() {
  const dispatcher = window.KeyboardShortcutDispatch;
  if (!dispatcher || typeof dispatcher !== 'object') return null;
  if (typeof dispatcher.getOverlayState !== 'function') return null;
  if (typeof dispatcher.resolveAction !== 'function') return null;
  return dispatcher;
}

function keyboardFallbackCloseByTarget(target) {
  const closeByTarget = {
    'dj-source-replace': closeDJSourceReplaceModal,
    'dj-profile': closeDJProfileModal,
    'brand-editor': closeBrandEditor,
    'news-editor': closeNewsEditor,
    'ranking-board-editor': closeRankingBoardEditor,
    'ranking-entries-editor': closeRankingEntriesEditor,
    'add-event': closeAddEventModal,
    'translate-batch': closeTranslateBatchModal,
    'poster-review': closePosterReviewModal,
    'coze-review': closeCozeReviewModal,
    'event-editor': closeActiveEventEditorByCancel,
    'tt-dj-bind': closeTtDJBindModal,
    'tt-modal': closeTtModal,
    lightbox: closeLightbox,
  };
  const fn = closeByTarget[String(target || '')];
  if (typeof fn === 'function') fn();
}

function keyboardApplyResolvedAction(action) {
  if (!action || typeof action !== 'object') return false;
  if (action.type === 'close') {
    const target = String(action.target || '').trim();
    if (!target) return false;
    keyboardRequestClose(target, () => keyboardFallbackCloseByTarget(target));
    return true;
  }
  if (action.type === 'lightbox-navigate') {
    const direction = Number(action.direction || 0);
    if (!Number.isFinite(direction) || direction === 0) return false;
    keyboardRequestLightboxNavigate(direction < 0 ? -1 : 1);
    return true;
  }
  return false;
}

document.addEventListener('keydown', (event) => {
  const dispatcher = keyboardGetDispatcher();
  if (!dispatcher) return;
  const state = dispatcher.getOverlayState(document);
  const action = dispatcher.resolveAction(event.key, state);
  keyboardApplyResolvedAction(action);
});
