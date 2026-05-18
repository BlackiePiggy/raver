// Core state facade for import domain.
(function initImportStateFacade() {
  const runtime = {
    get searchResults() {
      return importSearchResults;
    },
    set searchResults(value) {
      importSearchResults = Array.isArray(value) ? value : [];
    },
    get jobId() {
      return importJobId;
    },
    set jobId(value) {
      importJobId = value ? String(value) : null;
    },
    get pollTimer() {
      return importPollTimer;
    },
    set pollTimer(value) {
      importPollTimer = value || null;
    },
    get progressSince() {
      return importProgressSince;
    },
    set progressSince(value) {
      importProgressSince = Number(value) || 0;
    },
    get liveImportedKeys() {
      return importLiveImportedKeys;
    },
    set liveImportedKeys(value) {
      importLiveImportedKeys = value instanceof Set ? value : new Set();
    },
    get liveQueue() {
      return importLiveQueue;
    },
    set liveQueue(value) {
      importLiveQueue = Array.isArray(value) ? value : [];
    },
    get liveImporting() {
      return importLiveImporting;
    },
    set liveImporting(value) {
      importLiveImporting = !!value;
    },
    get liveInRunIndex() {
      return importLiveInRunIndex;
    },
    set liveInRunIndex(value) {
      importLiveInRunIndex = value instanceof Map ? value : new Map();
    },
    get liveWrittenCount() {
      return importLiveWrittenCount;
    },
    set liveWrittenCount(value) {
      importLiveWrittenCount = Number(value) || 0;
    },
    get liveSkippedCount() {
      return importLiveSkippedCount;
    },
    set liveSkippedCount(value) {
      importLiveSkippedCount = Number(value) || 0;
    },
    get livePhotoCount() {
      return importLivePhotoCount;
    },
    set livePhotoCount(value) {
      importLivePhotoCount = Number(value) || 0;
    },
    get livePhotoFailedCount() {
      return importLivePhotoFailedCount;
    },
    set livePhotoFailedCount(value) {
      importLivePhotoFailedCount = Number(value) || 0;
    },
    get persistStatusByKey() {
      return importPersistStatusByKey;
    },
    set persistStatusByKey(value) {
      importPersistStatusByKey = value instanceof Map ? value : new Map();
    },
    get photoFailureDetails() {
      return importPhotoFailureDetails;
    },
    set photoFailureDetails(value) {
      importPhotoFailureDetails = Array.isArray(value) ? value : [];
    },
    get lastProgress() {
      return importLastProgress;
    },
    set lastProgress(value) {
      importLastProgress = value || null;
    },
  };

  const translate = {
    get batch() {
      return translateBatchState;
    },
    set batch(value) {
      translateBatchState = (value && typeof value === 'object') ? value : null;
    },
  };

  const addEvent = {
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

  function runtimeState() {
    return runtime;
  }

  function translateState() {
    return translate;
  }

  function addEventState() {
    return addEvent;
  }

  function mutateRuntime(updater) {
    if (typeof updater === 'function') updater(runtime);
    return runtime;
  }

  function mutateTranslate(updater) {
    if (typeof updater === 'function') updater(translate);
    return translate;
  }

  function mutateAddEvent(updater) {
    if (typeof updater === 'function') updater(addEvent);
    return addEvent;
  }

  const facade = {
    runtimeState,
    translateState,
    addEventState,
    mutateRuntime,
    mutateTranslate,
    mutateAddEvent,
  };

  window.ImportStateFacade = facade;
})();
