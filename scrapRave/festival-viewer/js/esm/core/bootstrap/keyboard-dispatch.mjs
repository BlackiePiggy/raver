export const CLOSE_PRIORITY = Object.freeze([
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
]);

export function resolveAction(key, state) {
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

export function getOverlayStateFromElements(getIsOpen) {
  if (typeof getIsOpen !== 'function') {
    return {
      djProfileOpen: false,
      djSourceReplaceOpen: false,
      brandEditorOpen: false,
      newsEditorOpen: false,
      rankingBoardEditorOpen: false,
      rankingEntriesEditorOpen: false,
      cozeOpen: false,
      posterOpen: false,
      translateOpen: false,
      addEventOpen: false,
      eventEditorOpen: false,
      eventLineupOpen: false,
      ttDJBindOpen: false,
      ttOpen: false,
      lbOpen: false,
    };
  }
  return {
    djProfileOpen: !!getIsOpen('djProfileOpen'),
    djSourceReplaceOpen: !!getIsOpen('djSourceReplaceOpen'),
    brandEditorOpen: !!getIsOpen('brandEditorOpen'),
    newsEditorOpen: !!getIsOpen('newsEditorOpen'),
    rankingBoardEditorOpen: !!getIsOpen('rankingBoardEditorOpen'),
    rankingEntriesEditorOpen: !!getIsOpen('rankingEntriesEditorOpen'),
    cozeOpen: !!getIsOpen('cozeOpen'),
    posterOpen: !!getIsOpen('posterOpen'),
    translateOpen: !!getIsOpen('translateOpen'),
    addEventOpen: !!getIsOpen('addEventOpen'),
    eventEditorOpen: !!getIsOpen('eventEditorOpen'),
    eventLineupOpen: !!getIsOpen('eventLineupOpen'),
    ttDJBindOpen: !!getIsOpen('ttDJBindOpen'),
    ttOpen: !!getIsOpen('ttOpen'),
    lbOpen: !!getIsOpen('lbOpen'),
  };
}
