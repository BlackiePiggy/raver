// Keyboard shortcut routing helper for startup/bootstrap chain.
(function initKeyboardShortcutDispatch() {
  const CLOSE_PRIORITY = [
    { flag: 'djSourceReplaceOpen', target: 'dj-source-replace' },
    { flag: 'djProfileOpen', target: 'dj-profile' },
    { flag: 'brandEditorOpen', target: 'brand-editor' },
    { flag: 'newsEditorOpen', target: 'news-editor' },
    { flag: 'rankingBoardEditorOpen', target: 'ranking-board-editor' },
    { flag: 'rankingEntriesEditorOpen', target: 'ranking-entries-editor' },
    { flag: 'addEventOpen', target: 'add-event' },
    { flag: 'translateOpen', target: 'translate-batch' },
    { flag: 'posterOpen', target: 'poster-review' },
    { flag: 'cozeOpen', target: 'coze-review' },
    { flag: 'eventEditorOpen', target: 'event-editor' },
    { flag: 'eventLineupOpen', target: 'event-lineup' },
    { flag: 'ttDJBindOpen', target: 'tt-dj-bind' },
    { flag: 'ttOpen', target: 'tt-modal' },
    { flag: 'lbOpen', target: 'lightbox' },
  ];

  function isOpen(doc, selector) {
    const el = doc.querySelector(selector);
    return !!(el && el.classList.contains('open'));
  }

  function getOverlayState(doc = document) {
    return {
      djProfileOpen: isOpen(doc, '#dj-profile-overlay'),
      djSourceReplaceOpen: isOpen(doc, '#dj-source-replace-overlay'),
      brandEditorOpen: isOpen(doc, '#brand-editor-overlay'),
      newsEditorOpen: isOpen(doc, '#news-editor-overlay'),
      rankingBoardEditorOpen: isOpen(doc, '#ranking-board-editor-overlay'),
      rankingEntriesEditorOpen: isOpen(doc, '#ranking-entries-editor-overlay'),
      cozeOpen: isOpen(doc, '#coze-modal-overlay'),
      posterOpen: isOpen(doc, '#poster-modal-overlay'),
      translateOpen: isOpen(doc, '#translate-modal-overlay'),
      addEventOpen: isOpen(doc, '#add-event-modal-overlay'),
      eventEditorOpen: isOpen(doc, '#event-editor-overlay'),
      eventLineupOpen: isOpen(doc, '#event-lineup-modal-overlay'),
      ttDJBindOpen: isOpen(doc, '#tt-dj-bind-overlay'),
      ttOpen: isOpen(doc, '#tt-modal-overlay'),
      lbOpen: isOpen(doc, '#lightbox'),
    };
  }

  function resolveAction(key, state) {
    const eventKey = String(key || '').trim();
    const overlayState = (state && typeof state === 'object') ? state : {};

    if (eventKey === 'Escape') {
      for (const item of CLOSE_PRIORITY) {
        if (overlayState[item.flag]) {
          return { type: 'close', target: item.target };
        }
      }
      return null;
    }

    if (overlayState.lbOpen && eventKey === 'ArrowLeft') {
      return { type: 'lightbox-navigate', direction: -1 };
    }
    if (overlayState.lbOpen && eventKey === 'ArrowRight') {
      return { type: 'lightbox-navigate', direction: 1 };
    }
    return null;
  }

  window.KeyboardShortcutDispatch = {
    CLOSE_PRIORITY,
    getOverlayState,
    resolveAction,
  };
})();
