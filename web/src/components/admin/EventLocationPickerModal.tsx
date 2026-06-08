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
  amap?: {
    poiId?: string;
    adcode?: string;
  };
  mapkit?: {
    mapItemIdentifier?: string;
  };
  mapbox?: {
    placeId?: string;
    featureType?: string;
  };
  geoapify?: {
    placeId?: string;
    featureType?: string;
  };
  google?: {
    placeId?: string;
    types?: string[];
  };
} | null;

export type EventLocationPoint = {
  provider: EventLocationProvider | 'google';
  sourceMode: EventLocationSourceMode;
  providerPlaceId?: string;
  poiId?: string;
  adcode?: string;
  location: {
    lng: number;
    lat: number;
  };
  nameI18n: {
    zh: string;
    en: string;
  };
  addressI18n: {
    zh: string;
    en: string;
  };
  formattedAddressI18n: {
    zh: string;
    en: string;
  };
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
      if (existing.dataset.loaded === '1') {
        resolve();
        return;
      }
      existing.addEventListener('load', () => resolve(), { once: true });
      existing.addEventListener('error', () => reject(new Error(`脚本加载失败：${src}`)), { once: true });
      return;
    }

    const script = document.createElement('script');
    script.src = src;
    script.async = false;
    script.defer = false;
    script.dataset.raverEventLocationSrc = src;
    script.addEventListener(
      'load',
      () => {
        script.dataset.loaded = '1';
        resolve();
      },
      { once: true }
    );
    script.addEventListener('error', () => reject(new Error(`脚本加载失败：${src}`)), { once: true });
    document.body.appendChild(script);
  });

const ensureEventLocationRuntime = async (): Promise<EventLocationRuntime> => {
  if (!runtimeBootPromise) {
    runtimeBootPromise = (async () => {
      await Promise.all([
        window.__RAVER_VIEWER_RUNTIME_CONFIG__
          ? Promise.resolve()
          : fetch('/api/viewer/runtime-config')
              .then((res) => res.json())
              .then((payload) => {
                window.__RAVER_VIEWER_RUNTIME_CONFIG__ = payload?.data || {};
              })
              .catch(() => {
                window.__RAVER_VIEWER_RUNTIME_CONFIG__ = {};
              }),
        window.apiGet
          ? Promise.resolve()
          : (() => {
              window.getScraperApiBase = () => window.location.origin;
              window.apiGet = async (path: string, options?: RequestInit) => {
                const response = await fetch(path, {
                  credentials: 'include',
                  ...(options || {}),
                });
                if (!response.ok) {
                  throw new Error(`请求失败：${response.status}`);
                }
                return response.json();
              };
              window.apiPost = async (path: string, body?: unknown, options?: RequestInit) => {
                const response = await fetch(path, {
                  method: 'POST',
                  credentials: 'include',
                  headers: {
                    'Content-Type': 'application/json',
                    ...((options?.headers as Record<string, string> | undefined) || {}),
                  },
                  body: body === undefined ? undefined : JSON.stringify(body),
                  ...(options || {}),
                });
                if (!response.ok) {
                  throw new Error(`请求失败：${response.status}`);
                }
                return response.json();
              };
              return Promise.resolve();
            })(),
      ]);

      for (const src of EVENT_LOCATION_SCRIPT_CHAIN) {
        await ensureScript(src);
      }

      return window as EventLocationRuntime;
    })();
  }

  return runtimeBootPromise;
};

function createStandaloneId(prefix: string) {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
    return `${prefix}-${crypto.randomUUID()}`;
  }
  return `${prefix}-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
}

function toLegacyCompatiblePoint(point: EventLocationPoint | null): EventLocationPoint | null {
  if (!point) return null;
  if (point.provider !== 'google') return point;
  return {
    ...point,
    provider: 'geoapify',
  };
}

const normalizePoint = (runtime: EventLocationRuntime | null, value: unknown): EventLocationPoint | null => {
  if (!runtime?.normalizeEventLocationPoint) return null;
  const normalized = runtime.normalizeEventLocationPoint(value) as (EventLocationPoint & { sourceMode?: string }) | null;
  if (!normalized) return null;
  const sourceMode = String(normalized.sourceMode || '').trim();
  const safeSourceMode: EventLocationSourceMode =
    sourceMode === 'pin_drag'
      ? 'pin_drag'
      : sourceMode === 'map_poi_click'
        ? 'map_poi_click'
        : sourceMode === 'my_location'
          ? 'my_location'
          : sourceMode === 'legacy_coords'
            ? 'legacy_coords'
            : 'manual_search';
  return {
    ...normalized,
    sourceMode: safeSourceMode,
  };
};

function currentPointSummary(point: EventLocationPoint | null) {
  if (!point) return '还没有选中的地点';
  const title =
    point.nameI18n?.zh?.trim() ||
    point.nameI18n?.en?.trim() ||
    point.formattedAddressI18n?.zh?.trim() ||
    point.formattedAddressI18n?.en?.trim() ||
    '已选地点';
  return `${title} · ${point.location.lat.toFixed(6)}, ${point.location.lng.toFixed(6)}`;
}

function buildStandaloneFrame(
  channel: string,
  provider: EventLocationProvider,
  payload: StandalonePickerRequest
): StandaloneRequestFrame {
  const requestId = createStandaloneId('request');
  const requestKey = `${STANDALONE_PICKER_SOURCE}:request:${requestId}`;
  window.sessionStorage.setItem(requestKey, JSON.stringify(payload));

  const url = new URL('/admin/festival-viewer.html', window.location.origin);
  url.searchParams.set('standalone', 'event-location-picker');
  url.searchParams.set('channel', channel);
  url.searchParams.set('requestId', requestId);
  url.searchParams.set('requestKey', requestKey);
  url.searchParams.set('provider', provider);

  return {
    channel,
    requestId,
    requestKey,
    src: url.toString(),
  };
}

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
  const latestPropsRef = useRef({
    initialPoint,
    composedQuery,
    composedQueryZh,
    composedQueryEn,
    onClose,
    onConfirm,
  });

  const [pickerMode, setPickerMode] = useState<PickerMode>('native');
  const [runtimeReady, setRuntimeReady] = useState(false);
  const [runtimeError, setRuntimeError] = useState<string | null>(null);
  const [provider, setProvider] = useState<EventLocationProvider>(initialProvider);
  const [search, setSearch] = useState(composedQuery || '');
  const [selectedPoint, setSelectedPoint] = useState<EventLocationPoint | null>(initialPoint);
  const [frame, setFrame] = useState<StandaloneRequestFrame | null>(null);

  useEffect(() => {
    latestPropsRef.current = {
      initialPoint,
      composedQuery,
      composedQueryZh,
      composedQueryEn,
      onClose,
      onConfirm,
    };
  }, [initialPoint, composedQuery, composedQueryZh, composedQueryEn, onClose, onConfirm]);

  useEffect(() => {
    if (!open) {
      if (activeRequestKeyRef.current) {
        window.sessionStorage.removeItem(activeRequestKeyRef.current);
        activeRequestKeyRef.current = '';
      }
      setFrame(null);
      return;
    }

    setPickerMode('native');
    setRuntimeError(null);
    setRuntimeReady(false);
    setProvider(initialProvider);
    setSearch(composedQuery || '');
    setSelectedPoint(initialPoint);
  }, [open, initialProvider, initialPoint, composedQuery]);

  useEffect(() => {
    if (!open || pickerMode !== 'native') return;

    let cancelled = false;
    setRuntimeError(null);
    setRuntimeReady(false);

    void ensureEventLocationRuntime()
      .then(async (runtime) => {
        if (cancelled) return;
        runtimeRef.current = runtime;
        const normalizedProvider = runtime.normalizeEventLocationProvider?.(initialProvider) || initialProvider;
        setProvider(normalizedProvider);
        setRuntimeReady(true);
      })
      .catch((error) => {
        if (cancelled) return;
        setRuntimeError(error instanceof Error ? error.message : '地图能力加载失败');
      });

    return () => {
      cancelled = true;
    };
  }, [open, pickerMode, initialProvider]);

  useEffect(() => {
    if (!open || pickerMode !== 'native' || !runtimeReady || !runtimeRef.current || !mapWrapRef.current) return;

    const runtime = runtimeRef.current;
    const mapWrap = mapWrapRef.current;
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
    const statusEl = root.querySelector<HTMLElement>('#event-location-picker-status');

    if (!overlay || !modal || !searchInput || !searchBtn || !fillZhBtn || !fillEnBtn || !myPosBtn || !confirmBtn || !cancelBtn) {
      setRuntimeError('地图弹层节点初始化失败');
      return;
    }

    overlay.classList.add('open');
    overlay.style.display = 'flex';
    overlay.style.position = 'relative';
    overlay.style.inset = 'auto';
    overlay.style.padding = '0';
    overlay.style.background = 'transparent';
    overlay.style.backdropFilter = 'none';
    modal.style.width = '100%';
    modal.style.maxWidth = 'none';
    modal.style.margin = '0';
    modal.style.borderRadius = '28px';
    mapWrap.id = 'event-location-picker-map';
    mapWrap.classList.add('event-location-picker-map-canvas');
    searchInput.value = search;

    const syncSelected = () => {
      const nextPoint =
        normalizePoint(runtime, runtime.eventLocationCurrentPreviewPoint?.()) ||
        normalizePoint(runtime, runtime.eventLocationCurrentPoint?.()) ||
        normalizePoint(runtime, runtime.eventLocationPickerState?.selectedPoint) ||
        null;
      setSelectedPoint(nextPoint);
    };

    const syncStatus = () => {
      if (!statusEl) return;
      statusEl.textContent = runtime.eventLocationPickerState?.open ? statusEl.textContent : '';
    };

    void runtime.openEventLocationPickerModal?.({
      mode: 'edit',
      provider,
      initialPoint,
      composedQuery: composedQuery || '',
      composedQueryZh: composedQueryZh || '',
      composedQueryEn: composedQueryEn || '',
      onConfirm: (point: unknown) => {
        const normalized = normalizePoint(runtime, point);
        if (!normalized) return;
        setSelectedPoint(normalized);
        onConfirm(normalized);
      },
    });

    const pollId = window.setInterval(() => {
      syncSelected();
      syncStatus();
    }, 250);

    searchBtn.onclick = () => {
      setSearch(searchInput.value);
      void runtime.eventLocationSearchByKeyword?.('manual_search');
    };
    fillZhBtn.onclick = () => runtime.eventLocationFillAddressToCurrentPanel?.('zh');
    fillEnBtn.onclick = () => runtime.eventLocationFillAddressToCurrentPanel?.('en');
    myPosBtn.onclick = () => void runtime.eventLocationLocateMe?.();
    confirmBtn.onclick = () => {
      const normalized =
        normalizePoint(runtime, runtime.eventLocationCurrentPreviewPoint?.()) ||
        normalizePoint(runtime, runtime.eventLocationCurrentPoint?.()) ||
        null;
      if (!normalized) return;
      setSelectedPoint(normalized);
      onConfirm(normalized);
    };
    cancelBtn.onclick = () => {
      runtime.closeEventLocationPickerModal?.();
      onClose();
    };

    return () => {
      window.clearInterval(pollId);
      overlay.classList.remove('open');
      runtime.closeEventLocationPickerModal?.();
    };
  }, [
    open,
    pickerMode,
    runtimeReady,
    provider,
    search,
    initialPoint,
    composedQuery,
    composedQueryZh,
    composedQueryEn,
    onClose,
    onConfirm,
  ]);

  useEffect(() => {
    if (!open || pickerMode !== 'legacy') {
      if (activeRequestKeyRef.current) {
        window.sessionStorage.removeItem(activeRequestKeyRef.current);
        activeRequestKeyRef.current = '';
      }
      setFrame(null);
      return;
    }

    const channel = createStandaloneId('channel');
    channelRef.current = channel;

    const nextFrame = buildStandaloneFrame(channel, provider, {
      initialPoint: toLegacyCompatiblePoint(selectedPoint || initialPoint),
      provider,
      composedQuery: String(composedQuery || '').trim(),
      composedQueryZh: String(composedQueryZh || '').trim(),
      composedQueryEn: String(composedQueryEn || '').trim(),
    });

    activeRequestKeyRef.current = nextFrame.requestKey;
    setRuntimeError(null);
    setFrame(nextFrame);

    return () => {
      if (activeRequestKeyRef.current) {
        window.sessionStorage.removeItem(activeRequestKeyRef.current);
        activeRequestKeyRef.current = '';
      }
      channelRef.current = '';
    };
  }, [open, pickerMode, provider, selectedPoint, initialPoint, composedQuery, composedQueryZh, composedQueryEn]);

  useEffect(() => {
    if (!open || pickerMode !== 'legacy' || !channelRef.current || !frame) return;
    if (frame.src.includes(`provider=${provider}`)) return;

    if (activeRequestKeyRef.current) {
      window.sessionStorage.removeItem(activeRequestKeyRef.current);
    }

    const latest = latestPropsRef.current;
    const nextFrame = buildStandaloneFrame(channelRef.current, provider, {
      initialPoint: toLegacyCompatiblePoint(selectedPoint || latest.initialPoint),
      provider,
      composedQuery: String(latest.composedQuery || '').trim(),
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

      if (data.type === 'confirm' && data.point) {
        setSelectedPoint(data.point);
        latestPropsRef.current.onConfirm(data.point);
        latestPropsRef.current.onClose();
        return;
      }

      if (data.type === 'error') {
        setRuntimeError(String(data.message || '地图选点页加载失败'));
        return;
      }

      if (data.type === 'cancel') {
        latestPropsRef.current.onClose();
      }
    };

    window.addEventListener('message', handleMessage);
    return () => {
      window.removeEventListener('message', handleMessage);
    };
  }, [open, pickerMode, frame]);

  const summaryText = useMemo(() => currentPointSummary(selectedPoint), [selectedPoint]);

  if (!open) return null;

  return (
    <div className="event-location-picker-shell fixed inset-0 z-[90] flex items-center justify-center overflow-hidden overscroll-contain bg-black/55 p-4">
      <div className="flex h-[88vh] min-h-[88vh] w-full max-w-[1480px] overflow-hidden rounded-[32px] border border-white/70 bg-[#f6f3ea] shadow-[0_30px_120px_rgba(7,17,16,0.24)]">
        <aside className="hidden w-[320px] border-r border-black/8 bg-[linear-gradient(180deg,#f7f0df_0%,#fbf8ef_100%)] p-6 lg:flex lg:flex-col">
          <div className="admin-studio-label">Location Picker</div>
          <h2 className="mt-3 text-[26px] font-semibold tracking-[-0.03em] text-[#071110]">地图选点</h2>
          <p className="mt-3 text-sm leading-6 text-black/52">
            现在同时保留两套选点能力。你可以在原生 web 版和 `festival-viewer` legacy 版之间随时切换。
          </p>

          <div className="mt-6 rounded-[24px] border border-black/8 bg-white/80 p-4 text-sm text-[#071110]">
            <div className="font-semibold">版本切换</div>
            <div className="mt-3 grid gap-2">
              {[
                { value: 'native' as const, label: '原生版', desc: '使用你之前已接入的原生嵌入能力' },
                { value: 'legacy' as const, label: 'Legacy 版', desc: '继续使用 festival-viewer iframe' },
              ].map((item) => (
                <button
                  key={item.value}
                  type="button"
                  onClick={() => {
                    setPickerMode(item.value);
                    setRuntimeError(null);
                  }}
                  className={
                    pickerMode === item.value
                      ? 'rounded-[16px] border border-[#071110] bg-[#071110] px-4 py-3 text-left text-sm font-semibold text-white'
                      : 'rounded-[16px] border border-black/10 bg-white px-4 py-3 text-left text-sm font-semibold text-[#071110]'
                  }
                >
                  <div>{item.label}</div>
                  <div className={`mt-1 text-xs ${pickerMode === item.value ? 'text-white/72' : 'text-black/46'}`}>{item.desc}</div>
                </button>
              ))}
            </div>
          </div>

          <div className="mt-6 rounded-[24px] border border-black/8 bg-white/80 p-4 text-sm text-[#071110]">
            <div className="font-semibold">地图供应商</div>
            <div className="mt-3 grid gap-2">
              {PROVIDER_ITEMS.map((item) => (
                <button
                  key={item.value}
                  type="button"
                  onClick={() => {
                    setProvider(item.value);
                    runtimeRef.current?.setPreferredEventLocationProvider?.(item.value);
                  }}
                  className={
                    provider === item.value
                      ? 'rounded-[16px] border border-[#071110] bg-[#071110] px-4 py-3 text-left text-sm font-semibold text-white'
                      : 'rounded-[16px] border border-black/10 bg-white px-4 py-3 text-left text-sm font-semibold text-[#071110]'
                  }
                >
                  {item.label}
                </button>
              ))}
            </div>
          </div>

          <div className="mt-4 rounded-[24px] border border-black/8 bg-white/80 p-4 text-sm text-[#071110]">
            <div className="font-semibold">当前选择</div>
            <div className="mt-2 text-black/55">{summaryText}</div>
          </div>

          <div className="mt-4 rounded-[24px] border border-black/8 bg-white/80 p-4 text-sm text-[#071110]">
            <div className="font-semibold">使用建议</div>
            <div className="mt-2 space-y-2 text-black/55">
              {pickerMode === 'native' ? (
                <>
                  <p>这版就是你之前做过的原生嵌入实现，直接在当前后台里跑完整地图能力。</p>
                  <p>支持多地图 provider、关键词搜索、拖动 Pin、当前位置与 POI 面板。</p>
                  <p>如果想对照旧桥接方式，可以随时切回 Legacy 版。</p>
                </>
              ) : (
                <>
                  <p>切换地图供应商会重新载入选点页，但不会影响当前表单。</p>
                  <p>Mapbox / Geoapify 更适合国际地址，AMap 更适合国内 POI。</p>
                  <p>确认后会自动回填活动坐标、地点名、地图地址与 provider 元信息。</p>
                </>
              )}
            </div>
          </div>

          <div className="mt-auto rounded-[20px] border border-black/8 bg-[#fffaf0] px-4 py-3 text-xs text-black/48">
            {runtimeError
              ? runtimeError
              : pickerMode === 'native'
                ? runtimeReady
                  ? '原生地图能力已就绪。'
                  : '正在加载原生地图能力与 provider 配置...'
                : `当前模式：Legacy 版 · 当前地图供应商：${provider}`}
          </div>
        </aside>

        <div className="event-location-picker-stage relative flex-1 bg-white p-4">
          <button
            type="button"
            onClick={onClose}
            className="absolute right-8 top-8 z-[3] rounded-full border border-black/10 bg-white/92 px-4 py-2 text-sm font-semibold text-[#071110] shadow-sm"
          >
            关闭
          </button>

          {pickerMode === 'native' ? (
            <div ref={modalRootRef} className="h-full overflow-hidden rounded-[28px] bg-[#f6f3ea]">
              <div id="event-location-picker-overlay" className="h-full">
                <div id="event-location-picker-modal" className="h-full">
                  <div className="event-location-picker-head">
                    <div>
                      <div className="event-location-picker-title" id="event-location-picker-title">
                        活动地点绑定（原生页面）
                      </div>
                      <div className="event-location-picker-sub">支持搜索地点、中心 Pin 选点、拖拽精调与当前位置辅助定位</div>
                    </div>
                  </div>
                  <div className="event-location-picker-toolbar">
                    <input
                      id="event-location-picker-search-input"
                      className="event-location-picker-search-input"
                      type="text"
                      defaultValue={search}
                      placeholder="搜索地点，例如：上海 梅赛德斯奔驰文化中心"
                    />
                    <button id="event-location-picker-search-btn" className="event-location-picker-btn primary" type="button">
                      搜索
                    </button>
                    <button id="event-location-picker-fill-zh-btn" className="event-location-picker-btn" type="button">
                      填入中文地址
                    </button>
                    <button id="event-location-picker-fill-en-btn" className="event-location-picker-btn" type="button">
                      填入英文地址
                    </button>
                    <button id="event-location-picker-my-pos-btn" className="event-location-picker-btn" type="button">
                      定位到我
                    </button>
                  </div>
                  <div className="event-location-picker-map-wrap">
                    <div id="event-location-picker-map" ref={mapWrapRef} className="event-location-picker-map-canvas h-full w-full rounded-[20px]" />
                    <aside id="event-location-poi-panel" className="event-location-poi-panel" aria-live="polite" aria-label="POI 信息面板">
                      <div className="event-location-poi-panel-head">
                        <span>POI 信息</span>
                        <button id="event-location-poi-panel-close" className="event-location-poi-panel-close" type="button" aria-label="关闭">
                          ×
                        </button>
                      </div>
                      <div id="event-location-poi-panel-body" className="event-location-poi-panel-body" />
                    </aside>
                    <button id="event-location-return-anchor-btn" className="event-location-return-anchor-btn" type="button">
                      回到活动场地
                    </button>
                    <div id="event-location-center-pin" className="event-location-center-pin">
                      📍
                    </div>
                  </div>
                  <div className="event-location-picker-candidates" id="event-location-picker-candidates" />
                  <div className="event-location-picker-footer">
                    <span id="event-location-picker-status" className="event-location-picker-status" />
                    <button id="event-location-picker-cancel-btn" className="event-location-picker-btn" type="button">
                      取消
                    </button>
                    <button id="event-location-picker-confirm-btn" className="event-location-picker-btn primary" type="button">
                      确认绑定
                    </button>
                  </div>
                </div>
              </div>
            </div>
          ) : (
            <div className="h-full overflow-hidden rounded-[28px] border border-black/8 bg-[#f6f3ea]">
              {frame ? (
                <iframe
                  key={frame.requestId}
                  src={frame.src}
                  title="Legacy Event Location Picker"
                  className="h-full w-full border-0 bg-[#f6f3ea]"
                />
              ) : (
                <div className="flex h-full items-center justify-center text-sm text-black/48">
                  正在加载 legacy 选点页...
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
