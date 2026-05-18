// Core map provider selection helpers
const EVENT_LOCATION_PROVIDER_STORAGE_KEY = 'raver.viewer.event.location.provider';
const EVENT_LOCATION_PROVIDER_FALLBACK = 'amap';
const EVENT_LOCATION_PROVIDER_ALLOWLIST = new Set(['amap', 'mapkit', 'mapbox', 'geoapify']);

function normalizeEventLocationProvider(raw) {
  const value = String(raw || '').trim().toLowerCase();
  if (!EVENT_LOCATION_PROVIDER_ALLOWLIST.has(value)) return EVENT_LOCATION_PROVIDER_FALLBACK;
  return value;
}

function getEventLocationProviderLabel(provider) {
  const normalized = normalizeEventLocationProvider(provider);
  if (normalized === 'geoapify') return 'Geoapify';
  if (normalized === 'mapbox') return 'Mapbox';
  if (normalized === 'mapkit') return 'Apple MapKit';
  return '高德地图';
}

function getPreferredEventLocationProvider() {
  try {
    const cached = localStorage.getItem(EVENT_LOCATION_PROVIDER_STORAGE_KEY);
    return normalizeEventLocationProvider(cached);
  } catch (_error) {
    return EVENT_LOCATION_PROVIDER_FALLBACK;
  }
}

function setPreferredEventLocationProvider(provider) {
  const normalized = normalizeEventLocationProvider(provider);
  try {
    localStorage.setItem(EVENT_LOCATION_PROVIDER_STORAGE_KEY, normalized);
  } catch (_error) {
    // Ignore storage exceptions in private mode.
  }
  return normalized;
}
