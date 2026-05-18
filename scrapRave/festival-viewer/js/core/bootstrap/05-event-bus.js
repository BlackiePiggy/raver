// Lightweight app event bus for cross-module decoupling.
(function initFestivalViewerEventBus() {
  function createEventBus() {
    const listeners = new Map();

    function on(eventName, handler) {
      const name = String(eventName || '').trim();
      if (!name || typeof handler !== 'function') return () => {};
      const set = listeners.get(name) || new Set();
      set.add(handler);
      listeners.set(name, set);
      return () => off(name, handler);
    }

    function off(eventName, handler) {
      const name = String(eventName || '').trim();
      const set = listeners.get(name);
      if (!set || typeof handler !== 'function') return;
      set.delete(handler);
      if (!set.size) listeners.delete(name);
    }

    function emit(eventName, detail) {
      const name = String(eventName || '').trim();
      if (!name) return;
      const set = listeners.get(name);
      if (!set || !set.size) return;
      const snapshot = [...set];
      snapshot.forEach((handler) => {
        try {
          handler(detail);
        } catch (err) {
          console.error('[EventBus] listener error:', name, err);
        }
      });
    }

    function once(eventName, handler) {
      const name = String(eventName || '').trim();
      if (!name || typeof handler !== 'function') return () => {};
      let unsub = null;
      const wrapped = (detail) => {
        if (typeof unsub === 'function') unsub();
        handler(detail);
      };
      unsub = on(name, wrapped);
      return unsub;
    }

    return { on, off, emit, once };
  }

  const AppEvents = Object.freeze({
    APP_DOM_READY: 'app:dom-ready',
    APP_AUTH_READY: 'app:auth-ready',
    UI_REQUEST_CLOSE: 'ui:request-close',
    LIGHTBOX_CLOSE: 'lightbox:close',
    LIGHTBOX_NAVIGATE: 'lightbox:navigate',
    LIGHTBOX_OPENED: 'lightbox:opened',
    LIGHTBOX_CLOSED: 'lightbox:closed',
  });

  window.AppEventBus = createEventBus();
  window.AppEvents = AppEvents;
})();
