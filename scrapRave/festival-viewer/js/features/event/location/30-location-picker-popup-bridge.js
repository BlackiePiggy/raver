(function initEventLocationStandalonePopupBridge() {
  const params = new URLSearchParams(window.location.search || '');
  if (params.get('standalone') !== 'event-location-picker') return;

  const channel = String(params.get('channel') || '').trim();
  const requestId = String(params.get('requestId') || '').trim();
  const requestKey = String(params.get('requestKey') || '').trim();
  const messageSource = 'raver:event-location-picker';

  let bootstrapped = false;
  let resolved = false;

  function postToOpener(type, payload = {}) {
    const message = {
      source: messageSource,
      channel,
      requestId,
      type,
      ...payload,
    };
    if (window.parent && window.parent !== window) {
      try {
        window.parent.postMessage(message, window.location.origin);
      } catch (_error) {
        // ignore parent post failures
      }
    }
    if (window.opener && !window.opener.closed) {
      try {
        window.opener.postMessage(message, window.location.origin);
      } catch (_error) {
        // ignore opener post failures
      }
    }
  }

  function closeStandaloneWindowSoon() {
    if (window.parent && window.parent !== window) return;
    window.setTimeout(() => {
      try {
        window.close();
      } catch (_error) {
        // ignore
      }
    }, 60);
  }

  function readRequestPayload() {
    if (!requestKey) return null;
    try {
      const raw = window.sessionStorage.getItem(requestKey);
      if (!raw) return null;
      window.sessionStorage.removeItem(requestKey);
      const parsed = JSON.parse(raw);
      return parsed && typeof parsed === 'object' ? parsed : null;
    } catch (_error) {
      return null;
    }
  }

  function applyStandaloneLayout() {
    document.documentElement.classList.add('standalone-event-location-picker');
    document.body.classList.add('standalone-event-location-picker');

    const hideIds = [
      'auth-gate-overlay',
      'float-nav-edge',
      'float-nav-trigger',
      'float-nav',
      'archive-page',
      'dj-page',
      'genre-page',
      'brand-page',
      'event-brand-page',
      'news-page',
      'ranking-page',
      'review-page',
      'pick-zone',
      'loading',
      'year-nav',
      'filter-bar',
      'main',
      'app-page-nav',
    ];

    for (const id of hideIds) {
      const el = document.getElementById(id);
      if (el) el.style.display = 'none';
    }

    const header = document.querySelector('header');
    if (header) header.style.display = 'none';

    document.body.style.background = '#f3efe4';
    document.body.style.overflow = 'hidden';

    if (typeof closeViewerLogin === 'function') {
      try {
        closeViewerLogin();
      } catch (_error) {
        // ignore
      }
    }
  }

  async function bootstrapStandalonePicker() {
    if (bootstrapped) return;
    if (typeof window.openEventLocationPickerModal !== 'function') return;
    if (typeof window.closeEventLocationPickerModal !== 'function') return;

    bootstrapped = true;
    applyStandaloneLayout();

    const request = readRequestPayload();
    if (!request) {
      resolved = true;
      postToOpener('error', { message: 'Missing standalone location picker request payload.' });
      closeStandaloneWindowSoon();
      return;
    }

    const originalClose = window.closeEventLocationPickerModal;
    window.closeEventLocationPickerModal = function closeStandaloneEventLocationPicker(...args) {
      const result = originalClose.apply(this, args);
      if (!resolved) {
        resolved = true;
        postToOpener('cancel');
        closeStandaloneWindowSoon();
      }
      return result;
    };

    postToOpener('ready');

    try {
      await window.openEventLocationPickerModal({
        mode: 'edit',
        provider: request.provider,
        initialPoint: request.initialPoint || null,
        composedQuery: request.composedQuery || '',
        composedQueryZh: request.composedQueryZh || '',
        composedQueryEn: request.composedQueryEn || '',
        onConfirm: (point) => {
          if (resolved) return;
          resolved = true;
          postToOpener('confirm', { point });
          closeStandaloneWindowSoon();
        },
      });
    } catch (error) {
      if (resolved) return;
      resolved = true;
      postToOpener('error', { message: String(error?.message || error || 'Standalone picker failed to open.') });
      closeStandaloneWindowSoon();
    }
  }

  const bootstrapPoll = window.setInterval(() => {
    if (bootstrapped) {
      window.clearInterval(bootstrapPoll);
      return;
    }
    bootstrapStandalonePicker();
    if (bootstrapped) {
      window.clearInterval(bootstrapPoll);
    }
  }, 120);

  if (document.readyState === 'complete' || document.readyState === 'interactive') {
    bootstrapStandalonePicker();
  } else {
    document.addEventListener('DOMContentLoaded', bootstrapStandalonePicker, { once: true });
  }
})();
