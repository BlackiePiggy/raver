// Core state facade for timetable domain.
(function initTimetableStateFacade() {
  function bindState() {
    return ttDJBindState;
  }

  function importState() {
    const bind = bindState();
    return bind && typeof bind === 'object' ? (bind.importState || null) : null;
  }

  function mutateBind(updater) {
    const bind = bindState();
    if (bind && typeof updater === 'function') updater(bind);
    return bind;
  }

  function mutateImport(updater) {
    const st = importState();
    if (st && typeof updater === 'function') updater(st);
    return st;
  }

  const modal = {
    get currentFest() {
      return ttCurrentFest;
    },
    set currentFest(value) {
      ttCurrentFest = value;
    },
    get currentRowEl() {
      return ttCurrentRowEl;
    },
    set currentRowEl(value) {
      ttCurrentRowEl = value;
    },
    get activeDateIdx() {
      return ttActiveDateIdx;
    },
    set activeDateIdx(value) {
      ttActiveDateIdx = Number(value) || 0;
    },
    get editMode() {
      return ttEditMode;
    },
    set editMode(value) {
      ttEditMode = !!value;
    },
    get draftLineup() {
      return ttDraftLineup;
    },
    set draftLineup(value) {
      ttDraftLineup = Array.isArray(value) ? value : [];
    },
    get draftRowSeed() {
      return ttDraftRowSeed;
    },
    set draftRowSeed(value) {
      ttDraftRowSeed = Number(value) || 1;
    },
    get saving() {
      return ttSaving;
    },
    set saving(value) {
      ttSaving = !!value;
    },
    get quickBindMode() {
      return ttQuickBindMode;
    },
    set quickBindMode(value) {
      ttQuickBindMode = !!value;
    },
  };

  function modalState() {
    return modal;
  }

  const facade = {
    bindState,
    importState,
    modalState,
    mutateBind,
    mutateImport,
  };

  window.TimetableStateFacade = facade;
})();
