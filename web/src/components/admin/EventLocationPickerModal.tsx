'use client';

import { useEffect, useMemo, useRef, useState } from 'react';
import useOverlayBodyLock from '@/hooks/useOverlayBodyLock';

export type EventLocationProvider = 'amap' | 'mapkit' | 'mapbox' | 'geoapify';
export type EventLocationSourceMode =
  | 'manual_search'
  | 'pin_drag'
  | 'map_poi_click'
  | 'my_location'
  | 'legacy_coords';

export type EventLocationProviderMeta = {
  amap?: { poiId?: string; adcode?: string };
  mapkit?: { mapItemIdentifier?: string };
  mapbox?: { placeId?: string; featureType?: string };
  geoapify?: { placeId?: string; featureType?: string };
  google?: { placeId?: string; types?: string[] };
} | null;

export type EventLocationPoint = {
  provider: EventLocationProvider | 'google';
  sourceMode: EventLocationSourceMode;
  providerPlaceId?: string;
  poiId?: string;
  adcode?: string;
  location: { lng: number; lat: number };
  nameI18n: { zh: string; en: string };
  addressI18n: { zh: string; en: string };
  formattedAddressI18n: { zh: string; en: string };
  city: string;
  district: string;
  province: string;
  countryCode: string;
  providerMeta?: EventLocationProviderMeta;
  i18nPending?: boolean;
  selectedAt?: string;
};

type EventLocationPickerModalProps = {
  open: boolean;
  initialPoint: EventLocationPoint | null;
  initialProvider?: EventLocationProvider;
  composedQuery?: string;
  composedQueryZh?: string;
  composedQueryEn?: string;
  onClose: () => void;
  onConfirm: (point: EventLocationPoint) => void;
};

type EventLocationRuntime = {
  normalizeEventLocationProvider?: (value: unknown) => EventLocationProvider;
  setPreferredEventLocationProvider?: (provider: EventLocationProvider) => EventLocationProvider;
  normalizeEventLocationPoint?: (raw: unknown) => EventLocationPoint | null;
  openEventLocationPickerModal?: (options?: Record<string, unknown>) => Promise<void> | void;
  closeEventLocationPickerModal?: () => void;
  eventLocationCurrentPreviewPoint?: () => EventLocationPoint | null;
  eventLocationCurrentPoint?: () => EventLocationPoint | null;
  eventLocationSearchByKeyword?: (sourceMode?: string) => Promise<void> | void;
  eventLocationLocateMe?: () => Promise<void> | void;
  eventLocationFillAddressToCurrentPanel?: (locale?: string) => void;
  eventLocationPickerState?: {
    provider?: EventLocationProvider;
    open?: boolean;
    selectedPoint?: EventLocationPoint | null;
    previewPoint?: EventLocationPoint | null;
  };
};

type StandalonePickerRequest = {
  initialPoint: EventLocationPoint | null;
  provider: EventLocationProvider;
  composedQuery: string;
  composedQueryZh: string;
  composedQueryEn: string;
};

type StandalonePickerMessage = {
  source?: string;
  channel?: string;
  requestId?: string;
  type?: 'ready' | 'confirm' | 'cancel' | 'error';
  point?: EventLocationPoint | null;
  message?: string;
};

type StandaloneRequestFrame = {
  channel: string;
  requestId: string;
  requestKey: string;
  src: string;
};

type PickerMode = 'native' | 'legacy';

declare global {
  interface Window {
    __RAVER_VIEWER_RUNTIME_CONFIG__?: {
      amap?: { jsApiKey?: string; securityJsCode?: string };
      mapkit?: { jsToken?: string };
      mapbox?: { accessToken?: string };
      geoapify?: { apiKey?: string };
    };
    apiGet?: (path: string, options?: RequestInit) => Promise<any>;
    apiPost?: (path: string, body?: unknown, options?: RequestInit) => Promise<any>;
    getScraperApiBase?: () => string;
    escapeHtml?: (value: string) => string;
    openLightboxItems?: (items: unknown[], startIdx: number, titleText?: string) => void;
    guessImageExtFromNameOrUrl?: (nameOrUrl: string, mimeType?: string) => string;
    normalizeBiTextValue?: (value: unknown, fallback?: string) => { en?: string; zh?: string; ja?: string };
    normalizeCountryBiTextValue?: (value: unknown, fallback?: string) => { en?: string; zh?: string; ja?: string; enFull?: string };
    formatFestivalUnifiedAddress?: (value: unknown) => string;
  }
}

const PROVIDER_ITEMS: Array<{ value: EventLocationProvider; label: string }> = [
  { value: 'geoapify', label: 'Geoapify' },
  { value: 'mapbox', label: 'Mapbox' },
  { value: 'mapkit', label: 'Apple MapKit' },
  { value: 'amap', label: '高德地图' },
];

const EVENT_LOCATION_SCRIPT_CHAIN = [
  '/admin/country-codes-iso3166.js',
  '/admin/festival-viewer/js/core/00-state-and-api.js',
  '/admin/festival-viewer/js/core/helpers/00-festival-core-utils.js',
  '/admin/festival-viewer/js/core/archive/00-asset-mapping.js',
  '/admin/festival-viewer/js/core/bootstrap/00-lightbox-core.js',
  '/admin/festival-viewer/js/core/map/00-amap-loader.js',
  '/admin/festival-viewer/js/core/map/10-amap-services.js',
  '/admin/festival-viewer/js/core/map/20-map-provider.js',
  '/admin/festival-viewer/js/core/map/20-mapkit-loader.js',
  '/admin/festival-viewer/js/core/map/30-mapkit-services.js',
  '/admin/festival-viewer/js/core/map/40-mapbox-loader.js',
  '/admin/festival-viewer/js/core/map/50-mapbox-services.js',
  '/admin/festival-viewer/js/core/map/60-geoapify-loader.js',
  '/admin/festival-viewer/js/core/map/70-geoapify-services.js',
  '/admin/festival-viewer/js/features/event/location/00-location-state.js',
  '/admin/festival-viewer/js/features/event/location/10-location-picker-modal.js',
  '/admin/festival-viewer/js/features/event/location/15-location-picker-provider-bridge.js',
  '/admin/festival-viewer/js/features/event/location/25-location-manual-and-reuse-modal.js',
  '/admin/festival-viewer/js/features/event/location/20-location-bind-and-sync.js',
] as const;

const STANDALONE_PICKER_SOURCE = 'raver:event-location-picker';

let runtimeBootPromise: Promise<EventLocationRuntime> | null = null;

const ensureScript = (src: string) =>
  new Promise<void>((resolve, reject) => {
    const existing = document.querySelector<HTMLScriptElement>(`script[data-raver-event-location-src="${src}"]`);
    if (existing) {
      if (existing.dataset.loaded === '1') { resolve(); return; }
      existing.addEventListener('load', () => resolve(), { once: true });
      existing.addEventListener('error', () => reject(new Error(`脚本加载失败：${src}`)), { once: true });
      return;
    }
    const script = document.createElement('script');
    script.src = src;
    script.async = false;
    script.defer = false;
    script.dataset.raverEventLocationSrc = src;
    script.addEventListener('load', () => { script.dataset.loaded = '1'; resolve(); }, { once: true });
    script.addEventListener('error', () => reject(new Error(`脚本加载失败：${src}`)), { once: true });
    document.body.appendChild(script);
  });

const ensureEventLocationRuntime = async (): Promise<EventLocationRuntime> => {
  if (!runtimeBootPromise) {
    runtimeBootPromise = (async () => {
      await Promise.all([
        window.__RAVER_VIEWER_RUNTIME_CONFIG__
          ? Promise.resolve()
          : fetch('/api/viewer/runtime-config').then((r) => r.json()).then((p) => { window.__RAVER_VIEWER_RUNTIME_CONFIG__ = p?.data || {}; }).catch(() => { window.__RAVER_VIEWER_RUNTIME_CONFIG__ = {}; }),
        window.apiGet
          ? Promise.resolve()
          : (() => {
              window.getScraperApiBase = () => window.location.origin;
              window.apiGet = async (path, options) => { const r = await fetch(path, { credentials: 'include', ...(options || {}) }); if (!r.ok) throw new Error(`请求失败：${r.status}`); return r.json(); };
              window.apiPost = async (path, body, options) => { const r = await fetch(path, { method: 'POST', credentials: 'include', headers: { 'Content-Type': 'application/json', ...((options?.headers as Record<string, string> | undefined) || {}) }, body: body === undefined ? undefined : JSON.stringify(body), ...(options || {}) }); if (!r.ok) throw new Error(`请求失败：${r.status}`); return r.json(); };
              return Promise.resolve();
            })(),
      ]);
      for (const src of EVENT_LOCATION_SCRIPT_CHAIN) { await ensureScript(src); }
      return window as EventLocationRuntime;
    })();
  }
  return runtimeBootPromise;
};

function createStandaloneId(prefix: string) {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') return `${prefix}-${crypto.randomUUID()}`;
  return `${prefix}-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
}

function toLegacyCompatiblePoint(point: EventLocationPoint | null): EventLocationPoint | null {
  if (!point) return null;
  if (point.provider !== 'google') return point;
  return { ...point, provider: 'geoapify' };
}

const normalizePoint = (runtime: EventLocationRuntime | null, value: unknown): EventLocationPoint | null => {
  if (!runtime?.normalizeEventLocationPoint) return null;
  const normalized = runtime.normalizeEventLocationPoint(value) as (EventLocationPoint & { sourceMode?: string }) | null;
  if (!normalized) return null;
  const sourceMode = String(normalized.sourceMode || '').trim();
  const safeSourceMode: EventLocationSourceMode =
    sourceMode === 'pin_drag' ? 'pin_drag' :
    sourceMode === 'map_poi_click' ? 'map_poi_click' :
    sourceMode === 'my_location' ? 'my_location' :
    sourceMode === 'legacy_coords' ? 'legacy_coords' : 'manual_search';
  return { ...normalized, sourceMode: safeSourceMode };
};

/** Derive a display name from a point, falling back gracefully */
function pointDisplayName(point: EventLocationPoint | null): string {
  if (!point) return '';
  return (
    point.nameI18n?.zh?.trim() ||
    point.nameI18n?.en?.trim() ||
    point.formattedAddressI18n?.zh?.trim() ||
    point.formattedAddressI18n?.en?.trim() ||
    ''
  );
}

function pointDisplayAddress(point: EventLocationPoint | null): string {
  if (!point) return '';
  return (
    point.formattedAddressI18n?.zh?.trim() ||
    point.addressI18n?.zh?.trim() ||
    point.formattedAddressI18n?.en?.trim() ||
    point.addressI18n?.en?.trim() ||
    ''
  );
}

function buildStandaloneFrame(channel: string, provider: EventLocationProvider, payload: StandalonePickerRequest): StandaloneRequestFrame {
  const requestId = createStandaloneId('request');
  const requestKey = `${STANDALONE_PICKER_SOURCE}:request:${requestId}`;
  window.sessionStorage.setItem(requestKey, JSON.stringify(payload));
  const url = new URL('/admin/festival-viewer.html', window.location.origin);
  url.searchParams.set('standalone', 'event-location-picker');
  url.searchParams.set('channel', channel);
  url.searchParams.set('requestId', requestId);
  url.searchParams.set('requestKey', requestKey);
  url.searchParams.set('provider', provider);
  return { channel, requestId, requestKey, src: url.toString() };
}

// ─── Provider label helper ────────────────────────────────────────────────────

function providerLabel(provider: string): string {
  return PROVIDER_ITEMS.find((p) => p.value === provider)?.label ?? provider;
}

// ─── Main component ───────────────────────────────────────────────────────────

export default function EventLocationPickerModal({
  open,
  initialPoint,
  initialProvider = 'geoapify',
  composedQuery,
  composedQueryZh,
  composedQueryEn,
  onClose,
  onConfirm,
}: EventLocationPickerModalProps) {
  useOverlayBodyLock(open);

  const mapWrapRef = useRef<HTMLDivElement | null>(null);
  const runtimeRef = useRef<EventLocationRuntime | null>(null);
  const modalRootRef = useRef<HTMLDivElement | null>(null);
  const channelRef = useRef<string>('');
  const activeRequestKeyRef = useRef<string>('');
  const latestPropsRef = useRef({ initialPoint, composedQuery, composedQueryZh, composedQueryEn, onClose, onConfirm });

  const [pickerMode, setPickerMode] = useState<PickerMode>('native');
  const [runtimeReady, setRuntimeReady] = useState(false);
  const [runtimeError, setRuntimeError] = useState<string | null>(null);
  const [provider, setProvider] = useState<EventLocationProvider>(initialProvider);
  const [selectedPoint, setSelectedPoint] = useState<EventLocationPoint | null>(initialPoint);
  const [frame, setFrame] = useState<StandaloneRequestFrame | null>(null);

  useEffect(() => {
    latestPropsRef.current = { initialPoint, composedQuery, composedQueryZh, composedQueryEn, onClose, onConfirm };
  }, [initialPoint, composedQuery, composedQueryZh, composedQueryEn, onClose, onConfirm]);

  useEffect(() => {
    if (!open) {
      if (activeRequestKeyRef.current) { window.sessionStorage.removeItem(activeRequestKeyRef.current); activeRequestKeyRef.current = ''; }
      setFrame(null);
      return;
    }
    setPickerMode('native');
    setRuntimeError(null);
    setRuntimeReady(false);
    setProvider(initialProvider);
    setSelectedPoint(initialPoint);
  }, [open, initialProvider, initialPoint, composedQuery]);

  useEffect(() => {
    if (!open || pickerMode !== 'native') return;
    let cancelled = false;
    setRuntimeError(null);
    setRuntimeReady(false);
    void ensureEventLocationRuntime().then(async (runtime) => {
      if (cancelled) return;
      runtimeRef.current = runtime;
      const normalizedProvider = runtime.normalizeEventLocationProvider?.(initialProvider) || initialProvider;
      setProvider(normalizedProvider);
      setRuntimeReady(true);
    }).catch((error) => {
      if (cancelled) return;
      setRuntimeError(error instanceof Error ? error.message : '地图能力加载失败');
    });
    return () => { cancelled = true; };
  }, [open, pickerMode, initialProvider]);

  useEffect(() => {
    if (!open || pickerMode !== 'native' || !runtimeReady || !runtimeRef.current || !mapWrapRef.current) return;
    const runtime = runtimeRef.current;
    const root = modalRootRef.current;
    if (!root) return;

    const overlay = root.querySelector<HTMLElement>('#event-location-picker-overlay');
    const modal = root.querySelector<HTMLElement>('#event-location-picker-modal');
    const searchInput = root.querySelector<HTMLInputElement>('#event-location-picker-search-input');
    const searchBtn = root.querySelector<HTMLButtonElement>('#event-location-picker-search-btn');
    const fillZhBtn = root.querySelector<HTMLButtonElement>('#event-location-picker-fill-zh-btn');
    const fillEnBtn = root.querySelector<HTMLButtonElement>('#event-location-picker-fill-en-btn');
    const myPosBtn = root.querySelector<HTMLButtonElement>('#event-location-picker-my-pos-btn');
    const confirmBtn = root.querySelector<HTMLButtonElement>('#event-location-picker-confirm-btn');
    const cancelBtn = root.querySelector<HTMLButtonElement>('#event-location-picker-cancel-btn');

    if (!overlay || !modal || !searchInput || !searchBtn || !fillZhBtn || !fillEnBtn || !myPosBtn || !confirmBtn || !cancelBtn) {
      setRuntimeError('地图弹层节点初始化失败');
      return;
    }

    overlay.classList.add('open');
    overlay.style.cssText = 'display:flex;position:relative;inset:auto;padding:0;background:transparent;backdrop-filter:none;';
    modal.style.cssText = 'width:100%;max-width:none;margin:0;border-radius:0;';
    mapWrapRef.current!.id = 'event-location-picker-map';
    mapWrapRef.current!.classList.add('event-location-picker-map-canvas');
    searchInput.value = String(composedQuery || '').trim();

    const syncSelected = () => {
      const next = normalizePoint(runtime, runtime.eventLocationCurrentPreviewPoint?.()) ||
        normalizePoint(runtime, runtime.eventLocationCurrentPoint?.()) ||
        normalizePoint(runtime, runtime.eventLocationPickerState?.selectedPoint) || null;
      setSelectedPoint(next);
    };

    void runtime.openEventLocationPickerModal?.({
      mode: 'edit', provider, initialPoint, composedQuery: composedQuery || '',
      composedQueryZh: composedQueryZh || '', composedQueryEn: composedQueryEn || '',
      onConfirm: (point: unknown) => {
        const normalized = normalizePoint(runtime, point);
        if (!normalized) return;
        setSelectedPoint(normalized);
        onConfirm(normalized);
      },
    });

    const pollId = window.setInterval(syncSelected, 250);
    searchBtn.onclick = () => void runtime.eventLocationSearchByKeyword?.('manual_search');
    myPosBtn.onclick = () => void runtime.eventLocationLocateMe?.();
    confirmBtn.onclick = () => {
      const normalized = normalizePoint(runtime, runtime.eventLocationCurrentPreviewPoint?.()) ||
        normalizePoint(runtime, runtime.eventLocationCurrentPoint?.()) || null;
      if (!normalized) return;
      setSelectedPoint(normalized);
      onConfirm(normalized);
    };
    cancelBtn.onclick = () => { runtime.closeEventLocationPickerModal?.(); onClose(); };

    return () => {
      window.clearInterval(pollId);
      overlay.classList.remove('open');
      runtime.closeEventLocationPickerModal?.();
    };
  }, [open, pickerMode, runtimeReady, provider, initialPoint, composedQuery, composedQueryZh, composedQueryEn, onClose, onConfirm]);

  useEffect(() => {
    if (!open || pickerMode !== 'legacy') {
      if (activeRequestKeyRef.current) { window.sessionStorage.removeItem(activeRequestKeyRef.current); activeRequestKeyRef.current = ''; }
      setFrame(null);
      return;
    }
    const channel = createStandaloneId('channel');
    channelRef.current = channel;
    const nextFrame = buildStandaloneFrame(channel, provider, {
      initialPoint: toLegacyCompatiblePoint(selectedPoint || initialPoint),
      provider, composedQuery: String(composedQuery || '').trim(),
      composedQueryZh: String(composedQueryZh || '').trim(),
      composedQueryEn: String(composedQueryEn || '').trim(),
    });
    activeRequestKeyRef.current = nextFrame.requestKey;
    setRuntimeError(null);
    setFrame(nextFrame);
    return () => { if (activeRequestKeyRef.current) { window.sessionStorage.removeItem(activeRequestKeyRef.current); activeRequestKeyRef.current = ''; } channelRef.current = ''; };
  }, [open, pickerMode, provider, selectedPoint, initialPoint, composedQuery, composedQueryZh, composedQueryEn]);

  useEffect(() => {
    if (!open || pickerMode !== 'legacy' || !channelRef.current || !frame) return;
    if (frame.src.includes(`provider=${provider}`)) return;
    if (activeRequestKeyRef.current) window.sessionStorage.removeItem(activeRequestKeyRef.current);
    const latest = latestPropsRef.current;
    const nextFrame = buildStandaloneFrame(channelRef.current, provider, {
      initialPoint: toLegacyCompatiblePoint(selectedPoint || latest.initialPoint),
      provider, composedQuery: String(latest.composedQuery || '').trim(),
      composedQueryZh: String(latest.composedQueryZh || '').trim(),
      composedQueryEn: String(latest.composedQueryEn || '').trim(),
    });
    activeRequestKeyRef.current = nextFrame.requestKey;
    setRuntimeError(null);
    setFrame(nextFrame);
  }, [open, pickerMode, provider, frame, selectedPoint]);

  useEffect(() => {
    if (!open || pickerMode !== 'legacy' || !frame) return;
    const handleMessage = (event: MessageEvent<StandalonePickerMessage>) => {
      if (event.origin !== window.location.origin) return;
      const data = event.data;
      if (!data || data.source !== STANDALONE_PICKER_SOURCE) return;
      if (data.channel !== frame.channel || data.requestId !== frame.requestId) return;
      if (data.type === 'confirm' && data.point) { setSelectedPoint(data.point); latestPropsRef.current.onConfirm(data.point); latestPropsRef.current.onClose(); return; }
      if (data.type === 'error') { setRuntimeError(String(data.message || '地图选点页加载失败')); return; }
      if (data.type === 'cancel') latestPropsRef.current.onClose();
    };
    window.addEventListener('message', handleMessage);
    return () => window.removeEventListener('message', handleMessage);
  }, [open, pickerMode, frame]);

  const displayName = useMemo(() => pointDisplayName(selectedPoint), [selectedPoint]);
  const displayAddress = useMemo(() => pointDisplayAddress(selectedPoint), [selectedPoint]);

  // Current provider label for the header
  const currentProviderLabel = providerLabel(provider);

  if (!open) return null;

  return (
    <div className="elp-shell fixed inset-0 z-[90] flex flex-col overflow-hidden bg-[#f5f3ed]">

      {/* ── Top header bar ─────────────────────────────────────────────────── */}
      <div className="elp-header flex flex-shrink-0 flex-col border-b border-gray-200 bg-[#f5f3ed] px-6 py-4">
        <div className="flex items-start justify-between gap-4">
          <div>
            <h2 className="text-xl font-bold text-gray-900">
              活动地点绑定（{currentProviderLabel}）
            </h2>
            <p className="mt-0.5 text-sm text-gray-500">
              支持搜索地点、中心 Pin 选点、拖拽精确与当前位置辅助定位
            </p>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="flex-shrink-0 rounded-lg border border-gray-300 bg-white px-4 py-2 text-sm font-semibold text-gray-700 shadow-sm hover:bg-gray-50 transition-colors"
          >
            关闭
          </button>
        </div>

        {/* ── Toolbar row ── */}
        <div className="mt-4 flex flex-wrap items-center gap-2">
          {/* Mode switcher */}
          <div className="flex items-center gap-1 rounded-lg border border-gray-200 bg-white p-1">
            {(['native', 'legacy'] as const).map((mode) => (
              <button
                key={mode}
                type="button"
                onClick={() => { setPickerMode(mode); setRuntimeError(null); }}
                className={`rounded-md px-3 py-1.5 text-sm font-semibold transition-colors ${
                  pickerMode === mode
                    ? 'bg-gray-900 text-white shadow-sm'
                    : 'text-gray-600 hover:text-gray-900'
                }`}
              >
                {mode === 'native' ? '原生版' : 'Legacy 版'}
              </button>
            ))}
          </div>

          {/* Divider */}
          <div className="h-6 w-px bg-gray-200" />

          {/* Provider switcher */}
          <div className="flex items-center gap-1 rounded-lg border border-gray-200 bg-white p-1">
            {PROVIDER_ITEMS.map((item) => (
              <button
                key={item.value}
                type="button"
                onClick={() => {
                  setProvider(item.value);
                  runtimeRef.current?.setPreferredEventLocationProvider?.(item.value);
                }}
                className={`rounded-md px-3 py-1.5 text-sm font-semibold transition-colors ${
                  provider === item.value
                    ? 'bg-gray-900 text-white shadow-sm'
                    : 'text-gray-600 hover:text-gray-900'
                }`}
              >
                {item.label}
              </button>
            ))}
          </div>

          {/* Divider */}
          <div className="h-6 w-px bg-gray-200" />

          {/* Search input + action buttons – only shown in native mode */}
          {pickerMode === 'native' && (
            <>
              <input
                id="event-location-picker-search-input"
                type="text"
                defaultValue={composedQuery || ''}
                placeholder="搜索地点，例如：上海 梅赛德斯奔驰文化中心"
                className="min-w-[280px] flex-1 rounded-lg border border-gray-200 bg-white px-3 py-2 text-sm text-gray-800 placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-gray-900/10"
              />
              <button
                id="event-location-picker-search-btn"
                type="button"
                className="rounded-lg bg-gray-900 px-4 py-2 text-sm font-semibold text-white hover:bg-gray-800 transition-colors"
              >
                搜索
              </button>
              <button
                id="event-location-picker-fill-zh-btn"
                type="button"
                className="rounded-lg border border-gray-200 bg-white px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 transition-colors"
              >
                填入中文地址
              </button>
              <button
                id="event-location-picker-fill-en-btn"
                type="button"
                className="rounded-lg border border-gray-200 bg-white px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 transition-colors"
              >
                填入英文地址
              </button>
              <button
                id="event-location-picker-my-pos-btn"
                type="button"
                className="rounded-lg border border-gray-200 bg-white px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 transition-colors"
              >
                定位到我
              </button>
            </>
          )}

          {/* Error badge */}
          {runtimeError && (
            <span className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-xs font-medium text-red-700">
              {runtimeError}
            </span>
          )}
          {pickerMode === 'native' && !runtimeReady && !runtimeError && (
            <span className="text-xs text-gray-400">正在加载地图能力…</span>
          )}
        </div>
      </div>

      {/* ── Main area ──────────────────────────────────────────────────────── */}
      <div className="elp-body min-h-0 flex-1 overflow-hidden">
        {pickerMode === 'native' ? (
          <div ref={modalRootRef} className="flex h-full flex-col">
            <div id="event-location-picker-overlay" className="flex h-full flex-col">
              <div id="event-location-picker-modal" className="flex h-full flex-col">
                {/* Map + candidates panel – legacy CSS drives internal layout */}
                <div className="event-location-picker-content elp-content-override min-h-0 flex-1">
                  <div className="event-location-picker-map-wrap elp-map-override">
                    <div
                      id="event-location-picker-map"
                      ref={mapWrapRef}
                      className="event-location-picker-map-canvas h-full w-full"
                    />
                    <button
                      id="event-location-return-anchor-btn"
                      className="event-location-return-anchor-btn"
                      type="button"
                    >
                      回到活动场地
                    </button>
                    <div id="event-location-center-pin" className="event-location-center-pin">
                      📍
                    </div>
                  </div>

                  {/* Right column: POI panel + candidates */}
                  <div className="event-location-picker-side elp-side-override">
                    <aside
                      id="event-location-poi-panel"
                      className="event-location-poi-panel"
                      aria-live="polite"
                      aria-label="POI 信息面板"
                    >
                      <div className="event-location-poi-panel-head">
                        <span>POI 信息</span>
                        <button
                          id="event-location-poi-panel-close"
                          className="event-location-poi-panel-close"
                          type="button"
                          aria-label="关闭"
                        >
                          ×
                        </button>
                      </div>
                      <div
                        id="event-location-poi-panel-body"
                        className="event-location-poi-panel-body"
                      />
                    </aside>
                    <div
                      className="event-location-picker-candidates elp-candidates-override"
                      id="event-location-picker-candidates"
                    />
                  </div>
                </div>
              </div>
            </div>
          </div>
        ) : (
          /* Legacy iframe mode */
          <div className="h-full bg-[#f5f3ed]">
            {frame ? (
              <iframe
                key={frame.requestId}
                src={frame.src}
                title="Legacy Event Location Picker"
                className="h-full w-full border-0"
              />
            ) : (
              <div className="flex h-full items-center justify-center text-sm text-gray-400">
                正在加载 legacy 选点页…
              </div>
            )}
          </div>
        )}
      </div>

      {/* ── Bottom confirm bar ─────────────────────────────────────────────── */}
      <div className="elp-footer flex flex-shrink-0 items-center gap-4 border-t border-gray-200 bg-white px-6 py-3">
        {/* Location icon + name + address */}
        <div className="flex min-w-0 flex-1 items-center gap-3">
          <div className="flex h-9 w-9 flex-shrink-0 items-center justify-center rounded-xl bg-gray-100 text-gray-500">
            <svg className="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8}>
              <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0118 0z" strokeLinecap="round" strokeLinejoin="round" />
              <circle cx={12} cy={10} r={3} />
            </svg>
          </div>
          <div className="min-w-0">
            <div className="truncate text-sm font-semibold text-gray-900">
              {displayName || '还没有选中的地点'}
            </div>
            <div className="truncate text-xs text-gray-500">{displayAddress}</div>
          </div>
        </div>

        {/* Coordinate */}
        {selectedPoint && (
          <div className="hidden flex-shrink-0 flex-col xl:flex">
            <div className="text-[10px] font-semibold uppercase tracking-wider text-gray-400">坐标（经/纬度）</div>
            <div className="mt-0.5 font-mono text-xs text-gray-700">
              {selectedPoint.location.lng.toFixed(6)}, {selectedPoint.location.lat.toFixed(6)}
            </div>
          </div>
        )}

        {/* Formatted address */}
        {selectedPoint && (
          <div className="hidden min-w-0 max-w-[200px] flex-shrink-0 flex-col lg:flex">
            <div className="text-[10px] font-semibold uppercase tracking-wider text-gray-400">标准地址</div>
            <div className="mt-0.5 truncate text-xs text-gray-700">
              {selectedPoint.formattedAddressI18n?.en?.trim() ||
               selectedPoint.addressI18n?.en?.trim() ||
               selectedPoint.formattedAddressI18n?.zh?.trim() ||
               '—'}
            </div>
          </div>
        )}

        {/* City / district */}
        {selectedPoint && (
          <div className="hidden flex-shrink-0 flex-col xl:flex">
            <div className="text-[10px] font-semibold uppercase tracking-wider text-gray-400">城市 / 区域</div>
            <div className="mt-0.5 text-xs text-gray-700">
              {[selectedPoint.city, selectedPoint.district].filter(Boolean).join(', ') || '—'}
            </div>
          </div>
        )}

        {/* Country code */}
        {selectedPoint && (
          <div className="hidden flex-shrink-0 flex-col xl:flex">
            <div className="text-[10px] font-semibold uppercase tracking-wider text-gray-400">国家 / 地区</div>
            <div className="mt-0.5 text-xs text-gray-700">{selectedPoint.countryCode || '—'}</div>
          </div>
        )}

        {/* Provider */}
        {selectedPoint && (
          <div className="hidden flex-shrink-0 flex-col xl:flex">
            <div className="text-[10px] font-semibold uppercase tracking-wider text-gray-400">数据来源</div>
            <div className="mt-0.5 text-xs text-gray-700">{providerLabel(selectedPoint.provider)}</div>
          </div>
        )}

        {/* Source mode */}
        {selectedPoint && (
          <div className="hidden flex-shrink-0 flex-col xl:flex">
            <div className="text-[10px] font-semibold uppercase tracking-wider text-gray-400">选点方式</div>
            <div className="mt-0.5 text-xs text-gray-700">{selectedPoint.sourceMode || '—'}</div>
          </div>
        )}

        {/* Action buttons */}
        <div className="flex flex-shrink-0 items-center gap-2">
          {pickerMode === 'native' && (
            <button
              id="event-location-picker-cancel-btn"
              type="button"
              onClick={onClose}
              className="rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-semibold text-gray-700 hover:bg-gray-50 transition-colors"
            >
              取消
            </button>
          )}
          {pickerMode === 'native' && (
            <button
              id="event-location-picker-confirm-btn"
              type="button"
              className="rounded-lg bg-gray-900 px-5 py-2 text-sm font-semibold text-white hover:bg-gray-800 transition-colors disabled:opacity-40"
              disabled={!selectedPoint}
            >
              确认绑定
            </button>
          )}
        </div>
      </div>

      {/* ── Override styles for legacy map DOM ─────────────────────────────── */}
      <style jsx global>{`
        /* Full-screen shell resets */
        .elp-shell * { box-sizing: border-box; }

        /* Content area: map on left, candidates on right */
        .elp-content-override {
          display: grid !important;
          grid-template-columns: minmax(0, 1fr) 340px !important;
          gap: 0 !important;
          padding: 0 !important;
          background: #f5f3ed !important;
          height: 100% !important;
          min-height: 0 !important;
        }

        /* Map wrapper fills its cell */
        .elp-map-override {
          min-width: 0 !important;
          min-height: 0 !important;
          height: 100% !important;
          border-radius: 0 !important;
          border: none !important;
          border-right: 1px solid rgba(0,0,0,0.06) !important;
          overflow: hidden !important;
          background: #fff !important;
        }

        .elp-map-override #event-location-picker-map {
          height: 100% !important;
          min-height: 0 !important;
          border-radius: 0 !important;
        }

        /* Right side: POI panel + candidates list */
        .elp-side-override {
          display: flex !important;
          flex-direction: column !important;
          min-height: 0 !important;
          height: 100% !important;
          background: #fff !important;
          overflow: hidden !important;
        }

        /* Candidates panel fills remaining space */
        .elp-candidates-override {
          flex: 1 1 auto !important;
          min-height: 0 !important;
          max-height: none !important;
          overflow-y: auto !important;
          border: none !important;
          border-radius: 0 !important;
          background: #fff !important;
          padding: 0 !important;
        }

        /* Individual candidate rows */
        .elp-candidates-override .event-location-candidate {
          border-radius: 0 !important;
          border-bottom: 1px solid #f0f0f0 !important;
          padding: 10px 16px !important;
        }

        .elp-candidates-override .event-location-candidate:last-child {
          border-bottom: none !important;
        }

        /* POI panel: hide when empty, show when visible */
        .elp-side-override #event-location-poi-panel {
          position: relative !important;
          top: auto !important; right: auto !important;
          width: 100% !important;
          max-height: 220px !important;
          min-height: 0 !important;
          flex: 0 0 auto !important;
          display: none !important;
          border-radius: 0 !important;
          border-bottom: 1px solid #e8e8e8 !important;
          overflow: hidden !important;
        }

        .elp-side-override #event-location-poi-panel.visible {
          display: flex !important;
          flex-direction: column !important;
        }

        .elp-side-override .event-location-poi-panel-body {
          flex: 1 1 auto !important;
          min-height: 0 !important;
          max-height: none !important;
          overflow: auto !important;
          padding: 12px 16px !important;
        }

        /* Hide legacy modal chrome we don't need */
        .elp-shell .event-location-picker-head,
        .elp-shell .event-location-picker-toolbar,
        .elp-shell .event-location-picker-footer {
          display: none !important;
        }

        /* Ensure the overlay/modal wrappers don't add unwanted styling */
        .elp-shell #event-location-picker-overlay,
        .elp-shell #event-location-picker-modal {
          background: transparent !important;
          border: none !important;
          box-shadow: none !important;
          padding: 0 !important;
          margin: 0 !important;
          border-radius: 0 !important;
          width: 100% !important;
          max-width: none !important;
          height: 100% !important;
        }
      `}</style>
    </div>
  );
}