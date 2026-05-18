// ESM pilot module for startup-chain keyboard action execution.
// Runtime-isolated: event bus / DOM handlers are injected by caller.

export function normalizeLightboxDirection(direction) {
  const value = Number(direction || 0);
  if (!Number.isFinite(value) || value === 0) return null;
  return value < 0 ? -1 : 1;
}

export function applyResolvedAction(action, adapters = {}) {
  if (!action || typeof action !== 'object') return false;
  const requestClose = typeof adapters.requestClose === 'function' ? adapters.requestClose : null;
  const requestLightboxNavigate = typeof adapters.requestLightboxNavigate === 'function' ? adapters.requestLightboxNavigate : null;
  const fallbackCloseByTarget = typeof adapters.fallbackCloseByTarget === 'function' ? adapters.fallbackCloseByTarget : null;

  if (action.type === 'close') {
    const target = String(action.target || '').trim();
    if (!target || !requestClose) return false;
    requestClose(target, () => {
      if (fallbackCloseByTarget) fallbackCloseByTarget(target);
    });
    return true;
  }

  if (action.type === 'lightbox-navigate') {
    const direction = normalizeLightboxDirection(action.direction);
    if (!direction || !requestLightboxNavigate) return false;
    requestLightboxNavigate(direction);
    return true;
  }

  return false;
}
