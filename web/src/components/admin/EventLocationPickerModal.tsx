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

function pointTitle(point: EventLocationPoint | null) {
  return (
    point?.nameI18n?.zh?.trim() ||
    point?.nameI18n?.en?.trim() ||
    point?.formattedAddressI18n?.zh?.trim() ||
    point?.formattedAddressI18n?.en?.trim() ||
    '未选择地点'
  );
}

function pointAddress(point: EventLocationPoint | null) {
  return point?.formattedAddressI18n?.zh?.trim() || point?.formattedAddressI18n?.en?.trim() || '-';
}

function pointCoord(point: EventLocationPoint | null) {
  if (!point) return '-';
  return `${point.location.lng.toFixed(6)}, ${point.location.lat.toFixed(6)}`;
}

function pointArea(point: EventLocationPoint | null) {
  if (!point) return '-';
  return [point.district, point.city, point.province].map((item) => item?.trim()).filter(Boolean).join(', ') || '-';
}

function providerLabel(provider: EventLocationProvider | EventLocationPoint['provider'] | null | undefined) {
  const value = String(provider || '').trim();
  return PROVIDER_ITEMS.find((item) => item.value === value)?.label || value || '-';
}

function pointUpdatedAt(point: EventLocationPoint | null) {
  const raw = String(point?.selectedAt || '').trim();
  if (!raw) return '-';
  const date = new Date(raw);
  if (Number.isNaN(date.getTime())) return raw;
  return date.toLocaleString('zh-CN', { hour12: false });
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
    searchInput.value = String(composedQuery || '').trim();

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
      void runtime.eventLocationSearchByKeyword?.('manual_search');
    };
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
    <div className="event-location-picker-shell fixed inset-0 z-[90] flex items-center justify-center overflow-y-auto overscroll-contain bg-black/55 p-3">
      <div className="event-location-picker-frame flex h-[88vh] min-h-[720px] w-full max-w-[1760px] overflow-hidden rounded-[30px] border border-black/10 bg-[#f7f3ea] shadow-[0_30px_120px_rgba(7,17,16,0.24)]">
        <div className="event-location-picker-stage relative flex min-h-0 min-w-0 flex-1 flex-col bg-[#f7f3ea] p-4">
          {pickerMode === 'native' ? (
            <div ref={modalRootRef} className="flex h-full min-h-0 flex-col overflow-hidden rounded-[22px] border border-black/10 bg-[#f7f3ea]">
              <div id="event-location-picker-overlay" className="h-full">
                <div id="event-location-picker-modal" className="flex h-full min-h-0 flex-col">
                  <div className="event-location-picker-head">
                    <div>
                      <div className="event-location-picker-title" id="event-location-picker-title">
                        活动地点绑定（{providerLabel(provider)}）
                      </div>
                    </div>
                    <button
                      type="button"
                      onClick={onClose}
                      className="event-location-picker-close"
                    >
                      关闭
                    </button>
                  </div>

                  <div className="event-location-picker-toolbar">
                    <div className="event-location-picker-segment" aria-label="版本切换">
                      {[
                        { value: 'native' as const, label: '原生版' },
                        { value: 'legacy' as const, label: 'Legacy 版' },
                      ].map((item) => (
                        <button
                          key={item.value}
                          type="button"
                          onClick={() => {
                            setPickerMode(item.value);
                            setRuntimeError(null);
                          }}
                          className={pickerMode === item.value ? 'active' : ''}
                        >
                          {item.label}
                        </button>
                      ))}
                    </div>

                    <div className="event-location-picker-provider-tabs" aria-label="地图供应商">
                      {PROVIDER_ITEMS.map((item) => (
                        <button
                          key={item.value}
                          type="button"
                          onClick={() => {
                            setProvider(item.value);
                            runtimeRef.current?.setPreferredEventLocationProvider?.(item.value);
                          }}
                          className={provider === item.value ? 'active' : ''}
                        >
                          {item.label}
                        </button>
                      ))}
                    </div>
                    <input
                      id="event-location-picker-search-input"
                      className="event-location-picker-search-input"
                      type="text"
                      defaultValue={composedQuery || ''}
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

                  <div className="event-location-picker-content min-h-0 min-w-0 flex-1">
                    <div className="event-location-picker-map-wrap">
                      <div id="event-location-picker-map" ref={mapWrapRef} className="event-location-picker-map-canvas h-full w-full" />
                      <button id="event-location-return-anchor-btn" className="event-location-return-anchor-btn" type="button">
                        回到活动场地
                      </button>
                      <div id="event-location-center-pin" className="event-location-center-pin">
                        📍
                      </div>
                    </div>
                    <div className="event-location-picker-side">
                      <div className="event-location-candidate-panel-head">
                        <span>搜索候选</span>
                        <small>最多展示 10 条</small>
                      </div>
                      <div className="event-location-picker-candidates-wrap">
                        <div className="event-location-picker-candidates" id="event-location-picker-candidates" />
                      </div>
                    </div>
                  </div>

                  <div className="event-location-picker-feedback">
                    <span id="event-location-picker-status" className="event-location-picker-status">
                      {runtimeError || (runtimeReady ? summaryText : '正在加载原生地图能力与 provider 配置...')}
                    </span>
                  </div>

                  <div className="event-location-picker-bottom">
                    <div className="event-location-selected-summary">
                      <div className="event-location-selected-main">
                        <span className="event-location-selected-icon">⌖</span>
                        <div>
                          <strong>{pointTitle(selectedPoint)}</strong>
                          <span>{pointAddress(selectedPoint)}</span>
                          <em>{pointCoord(selectedPoint)}</em>
                          <small>{selectedPoint?.providerPlaceId || selectedPoint?.poiId || '-'}</small>
                        </div>
                      </div>
                      <div className="event-location-selected-meta">
                        <span>{pointArea(selectedPoint)}</span>
                        <span>{selectedPoint?.countryCode || '-'}</span>
                        <span>{providerLabel(selectedPoint?.provider || provider)}</span>
                        <span>{pointUpdatedAt(selectedPoint)}</span>
                      </div>
                    </div>

                    <div className="event-location-picker-footer">
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
            </div>
          ) : (
            <div className="flex h-full min-h-0 flex-col overflow-hidden rounded-[22px] border border-black/10 bg-[#f7f3ea]">
              <div className="event-location-legacy-head">
                <div className="event-location-picker-segment" aria-label="版本切换">
                  {[
                    { value: 'native' as const, label: '原生版' },
                    { value: 'legacy' as const, label: 'Legacy 版' },
                  ].map((item) => (
                    <button
                      key={item.value}
                      type="button"
                      onClick={() => {
                        setPickerMode(item.value);
                        setRuntimeError(null);
                      }}
                      className={pickerMode === item.value ? 'active' : ''}
                    >
                      {item.label}
                    </button>
                  ))}
                </div>
                <button type="button" onClick={onClose} className="event-location-picker-close">
                  关闭
                </button>
              </div>
              {frame ? (
                <iframe
                  key={frame.requestId}
                  src={frame.src}
                  title="Legacy Event Location Picker"
                  className="h-full min-h-0 w-full flex-1 border-0 bg-[#f7f3ea]"
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
      <style jsx global>{`
        .event-location-picker-frame {
          min-width: 0;
        }

        .event-location-picker-stage .event-location-picker-content {
          display: grid;
          grid-template-columns: minmax(0, 1fr) minmax(320px, 35%);
          gap: 10px;
          min-height: 0;
          flex: 1 1 auto;
          padding: 10px;
          background: #f2efe7;
        }

        .event-location-picker-stage #event-location-picker-overlay,
        .event-location-picker-stage #event-location-picker-modal {
          background: transparent;
        }

        .event-location-picker-stage #event-location-picker-modal {
          border: 0;
          box-shadow: none;
          max-height: none;
        }

        .event-location-picker-stage .event-location-picker-head {
          min-height: 54px;
          padding: 12px 22px;
          background: linear-gradient(120deg, rgba(255, 255, 255, 0.86), rgba(246, 242, 232, 0.92));
          border-bottom: 1px solid rgba(7, 17, 16, 0.08);
        }

        .event-location-picker-stage .event-location-picker-title {
          font-family: inherit;
          font-size: 16px;
          font-weight: 750;
          letter-spacing: 0;
          color: #071110;
        }

        .event-location-picker-stage .event-location-picker-sub {
          margin-top: 7px;
          font-family: inherit;
          font-size: 12px;
          letter-spacing: 0;
          color: rgba(7, 17, 16, 0.45);
        }

        .event-location-picker-stage .event-location-picker-close {
          height: 36px;
          min-width: 64px;
          border: 1px solid rgba(7, 17, 16, 0.1);
          border-radius: 999px;
          background: rgba(255, 255, 255, 0.72);
          color: #071110;
          font-family: inherit;
          font-size: 13px;
          font-weight: 650;
          letter-spacing: 0;
          text-transform: none;
          box-shadow: 0 4px 14px rgba(7, 17, 16, 0.07);
        }

        .event-location-picker-stage .event-location-picker-controlbar {
          display: none;
          grid-template-columns: auto minmax(0, 1fr);
          gap: 34px;
          align-items: center;
          padding: 16px 18px 8px;
          border-bottom: 0;
          background: #fff;
        }

        .event-location-picker-stage .event-location-picker-segment,
        .event-location-picker-stage .event-location-picker-provider-tabs {
          display: flex;
          align-items: stretch;
          overflow: hidden;
          border: 1px solid rgba(7, 17, 16, 0.1);
          border-radius: 10px;
          background: #fff;
        }

        .event-location-picker-stage .event-location-picker-provider-tabs {
          overflow-x: auto;
          width: fit-content;
          max-width: 100%;
        }

        .event-location-picker-stage .event-location-picker-segment button,
        .event-location-picker-stage .event-location-picker-provider-tabs button {
          min-height: 34px;
          padding: 0 12px;
          border: 0;
          border-right: 1px solid rgba(7, 17, 16, 0.08);
          background: #fff;
          color: #071110;
          cursor: pointer;
          font-size: 11px;
          font-weight: 650;
          white-space: nowrap;
        }

        .event-location-picker-stage .event-location-picker-segment button:last-child,
        .event-location-picker-stage .event-location-picker-provider-tabs button:last-child {
          border-right: 0;
        }

        .event-location-picker-stage .event-location-picker-segment button.active,
        .event-location-picker-stage .event-location-picker-provider-tabs button.active {
          background: #001310;
          color: #fff;
          box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.08);
        }

        .event-location-picker-stage .event-location-picker-toolbar {
          display: grid;
          grid-template-columns: auto auto minmax(260px, 1fr) auto auto auto auto;
          gap: 8px;
          align-items: center;
          padding: 10px 18px;
          border-bottom: 1px solid rgba(7, 17, 16, 0.08);
          background: #fff;
        }

        .event-location-picker-stage .event-location-picker-search-input {
          height: 40px;
          min-width: 0;
          border: 1px solid rgba(7, 17, 16, 0.12);
          border-radius: 12px;
          background: #fff;
          color: #071110;
          font-family: inherit;
          font-size: 13px;
          font-weight: 650;
          letter-spacing: 0;
          padding: 0 14px;
        }

        .event-location-picker-stage .event-location-picker-search-input:focus {
          border-color: rgba(7, 17, 16, 0.28);
          box-shadow: 0 0 0 3px rgba(0, 19, 16, 0.06);
        }

        .event-location-picker-stage .event-location-picker-btn {
          min-height: 40px;
          border: 1px solid rgba(7, 17, 16, 0.1);
          border-radius: 12px;
          background: #fff;
          color: rgba(7, 17, 16, 0.68);
          cursor: pointer;
          font-family: inherit;
          font-size: 12px;
          font-weight: 650;
          letter-spacing: 0;
          text-transform: none;
          padding: 0 14px;
          white-space: nowrap;
        }

        .event-location-picker-stage .event-location-picker-btn:hover {
          border-color: rgba(7, 17, 16, 0.22);
          color: #071110;
        }

        .event-location-picker-stage .event-location-picker-btn.primary {
          border-color: #001310;
          background: #001310;
          color: #fff;
        }

        .event-location-picker-stage .event-location-picker-map-wrap {
          min-width: 0;
          min-height: 0;
          height: 100%;
          overflow: hidden;
          border: 0;
          border-radius: 0;
          background: #fff;
        }

        .event-location-picker-stage #event-location-picker-map {
          height: 100%;
          min-height: 420px;
          border-radius: 0;
        }

        .event-location-picker-stage .event-location-picker-side {
          min-width: 0;
          min-height: 0;
          display: flex;
          flex-direction: column;
          align-self: start;
          border-radius: 18px;
          background: rgba(255, 255, 255, 0.94);
          box-shadow: 0 12px 30px rgba(7, 17, 16, 0.08);
        }

        .event-location-picker-stage .event-location-candidate-panel-head {
          display: flex;
          align-items: baseline;
          gap: 8px;
          padding: 16px 24px 8px;
          color: #071110;
          font-size: 13px;
          font-weight: 750;
        }

        .event-location-picker-stage .event-location-candidate-panel-head small {
          color: rgba(7, 17, 16, 0.42);
          font-size: 11px;
          font-weight: 650;
        }

        .event-location-picker-stage .event-location-picker-candidates-wrap {
          max-height: min(560px, calc(88vh - 320px));
          overflow: auto;
        }

        .event-location-picker-stage #event-location-picker-candidates {
          flex: 0 0 auto;
          min-height: 0;
          max-height: none;
          padding: 0 18px 18px;
          gap: 0;
          border: 0;
          border-radius: 0;
          background: transparent;
        }

        .event-location-picker-stage .event-location-candidate {
          position: relative;
          display: grid;
          grid-template-columns: minmax(0, 1fr) auto;
          gap: 2px 12px;
          padding: 10px 0;
          border: 0;
          border-bottom: 1px solid rgba(7, 17, 16, 0.08);
          border-radius: 0;
          background: transparent;
          color: #071110;
          box-shadow: none;
        }

        .event-location-picker-stage .event-location-candidate:hover {
          border-color: rgba(7, 17, 16, 0.14);
        }

        .event-location-picker-stage .event-location-candidate.current,
        .event-location-picker-stage .event-location-candidate.active,
        .event-location-picker-stage .event-location-candidate.current.active {
          border-color: rgba(7, 17, 16, 0.12);
          box-shadow: none;
        }

        .event-location-picker-stage .event-location-candidate-head {
          display: contents;
        }

        .event-location-picker-stage .event-location-candidate-badge {
          display: none;
        }

        .event-location-picker-stage .event-location-candidate-set-btn {
          grid-column: 2;
          grid-row: 1 / span 3;
          align-self: center;
          min-height: 28px;
          border: 1px solid rgba(7, 17, 16, 0.1);
          border-radius: 999px;
          background: #fff;
          color: #071110;
          cursor: pointer;
          font-family: inherit;
          font-size: 11px;
          font-weight: 650;
          letter-spacing: 0;
          text-transform: none;
          padding: 0 12px;
          white-space: nowrap;
        }

        .event-location-picker-stage .event-location-candidate-name {
          grid-column: 1;
          font-family: inherit;
          font-size: 12px;
          line-height: 1.3;
          font-weight: 750;
          letter-spacing: 0;
          color: #071110;
        }

        .event-location-picker-stage .event-location-candidate-addr,
        .event-location-picker-stage .event-location-candidate-coord {
          grid-column: 1;
          font-family: inherit;
          font-size: 11px;
          line-height: 1.28;
          color: rgba(7, 17, 16, 0.5);
        }

        .event-location-picker-stage .event-location-candidate-empty {
          margin: 12px 0;
          border: 1px dashed rgba(7, 17, 16, 0.14);
          border-radius: 14px;
          color: rgba(7, 17, 16, 0.46);
          font-family: inherit;
          font-size: 12px;
          letter-spacing: 0;
          padding: 20px;
          text-align: center;
        }

        .event-location-picker-stage .event-location-picker-feedback {
          padding: 8px 14px 0;
          background: #fff;
        }

        .event-location-picker-stage .event-location-picker-bottom {
          display: grid;
          grid-template-columns: minmax(0, 1fr) auto;
          gap: 12px;
          align-items: stretch;
          padding: 12px;
          background: #fff;
          border-top: 1px solid rgba(7, 17, 16, 0.08);
        }

        .event-location-picker-stage .event-location-selected-summary {
          min-width: 0;
          display: flex;
          align-items: center;
          justify-content: space-between;
          gap: 18px;
          overflow: hidden;
          border: 1px solid rgba(7, 17, 16, 0.08);
          border-radius: 16px;
          background: #fff;
          padding: 12px 16px;
        }

        .event-location-picker-stage .event-location-selected-main {
          display: flex;
          min-width: 0;
          gap: 12px;
          align-items: center;
        }

        .event-location-picker-stage .event-location-selected-icon {
          display: inline-flex;
          width: 34px;
          height: 34px;
          flex: 0 0 auto;
          align-items: center;
          justify-content: center;
          border-radius: 999px;
          background: rgba(7, 17, 16, 0.06);
          color: #071110;
          font-size: 16px;
        }

        .event-location-picker-stage .event-location-selected-main strong,
        .event-location-picker-stage .event-location-selected-main em {
          display: block;
          overflow: hidden;
          color: #071110;
          font-size: 12px;
          font-weight: 750;
          line-height: 1.35;
          text-overflow: ellipsis;
          white-space: nowrap;
        }

        .event-location-picker-stage .event-location-selected-main span:not(.event-location-selected-icon) {
          display: block;
          overflow: hidden;
          color: rgba(7, 17, 16, 0.45);
          font-size: 11px;
          line-height: 1.35;
          text-overflow: ellipsis;
          white-space: nowrap;
        }

        .event-location-picker-stage .event-location-selected-main em {
          margin-top: 2px;
          color: rgba(7, 17, 16, 0.72);
          font-size: 11px;
          font-style: normal;
        }

        .event-location-picker-stage .event-location-selected-main small {
          display: block;
          overflow: hidden;
          margin-top: 2px;
          color: rgba(7, 17, 16, 0.38);
          font-size: 10px;
          line-height: 1.3;
          text-overflow: ellipsis;
          white-space: nowrap;
        }

        .event-location-picker-stage .event-location-selected-meta {
          display: flex;
          min-width: 0;
          flex-wrap: wrap;
          justify-content: flex-end;
          gap: 8px 16px;
        }

        .event-location-picker-stage .event-location-selected-meta span {
          color: rgba(7, 17, 16, 0.58);
          font-size: 11px;
          line-height: 1.3;
          white-space: nowrap;
        }

        .event-location-picker-stage .event-location-picker-footer {
          display: flex;
          align-items: center;
          gap: 12px;
          padding: 0;
          background: transparent;
        }

        .event-location-picker-stage .event-location-picker-footer .event-location-picker-btn {
          min-height: 58px;
          border-radius: 16px;
          padding: 0 22px;
          font-size: 13px;
        }

        .event-location-picker-stage .event-location-picker-status {
          display: inline-flex;
          align-items: center;
          min-height: 18px;
          color: rgba(7, 17, 16, 0.56);
          font-size: 12px;
          line-height: 1.3;
        }

        @media (max-width: 1279px) {
          .event-location-picker-frame {
            min-height: 88vh;
          }

          .event-location-picker-stage .event-location-picker-controlbar,
          .event-location-picker-stage .event-location-picker-toolbar,
          .event-location-picker-stage .event-location-picker-content {
            grid-template-columns: minmax(0, 1fr);
          }

          .event-location-picker-stage .event-location-picker-side {
            max-height: 34vh;
          }

          .event-location-picker-stage #event-location-picker-map {
            min-height: 320px;
          }

          .event-location-picker-stage .event-location-selected-summary {
            flex-direction: column;
            align-items: flex-start;
          }

          .event-location-picker-stage .event-location-picker-bottom {
            grid-template-columns: minmax(0, 1fr);
          }

          .event-location-picker-stage #event-location-poi-panel {
            max-height: 120px;
          }
        }
      `}</style>
    </div>
  );
}
