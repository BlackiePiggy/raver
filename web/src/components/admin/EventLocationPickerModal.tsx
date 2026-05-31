'use client';

import { useEffect, useMemo, useRef, useState } from 'react';

export type EventLocationProvider = 'amap' | 'mapkit' | 'mapbox' | 'geoapify';

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
  sourceMode: string;
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
  getEventLocationProviderLabel?: (provider: EventLocationProvider) => string;
  setPreferredEventLocationProvider?: (provider: EventLocationProvider) => EventLocationProvider;
  getPreferredEventLocationProvider?: () => EventLocationProvider;
  ensureAmapLoaded?: () => Promise<unknown>;
  ensureMapkitLoaded?: () => Promise<unknown>;
  ensureMapboxLoaded?: () => Promise<unknown>;
  ensureGeoapifyLoaded?: () => Promise<unknown>;
  normalizeEventLocationPoint?: (raw: unknown) => EventLocationPoint | null;
  openEventLocationPickerModal?: (options?: Record<string, unknown>) => Promise<void> | void;
  closeEventLocationPickerModal?: () => void;
  eventLocationCurrentPreviewPoint?: () => EventLocationPoint | null;
  eventLocationCurrentPoint?: () => EventLocationPoint | null;
  eventLocationGetComposedQueryByLocale?: (locale?: string) => string;
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
  '/festival-viewer/js/core/00-state-and-api.js',
  '/festival-viewer/js/core/helpers/00-festival-core-utils.js',
  '/festival-viewer/js/core/archive/00-asset-mapping.js',
  '/festival-viewer/js/core/bootstrap/00-lightbox-core.js',
  '/festival-viewer/js/core/map/00-amap-loader.js',
  '/festival-viewer/js/core/map/10-amap-services.js',
  '/festival-viewer/js/core/map/20-map-provider.js',
  '/festival-viewer/js/core/map/20-mapkit-loader.js',
  '/festival-viewer/js/core/map/30-mapkit-services.js',
  '/festival-viewer/js/core/map/40-mapbox-loader.js',
  '/festival-viewer/js/core/map/50-mapbox-services.js',
  '/festival-viewer/js/core/map/60-geoapify-loader.js',
  '/festival-viewer/js/core/map/70-geoapify-services.js',
  '/festival-viewer/js/features/event/location/00-location-state.js',
  '/festival-viewer/js/features/event/location/10-location-picker-modal.js',
  '/festival-viewer/js/features/event/location/15-location-picker-provider-bridge.js',
  '/festival-viewer/js/features/event/location/25-location-manual-and-reuse-modal.js',
  '/festival-viewer/js/features/event/location/20-location-bind-and-sync.js',
] as const;

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

const normalizePoint = (runtime: EventLocationRuntime | null, value: unknown): EventLocationPoint | null => {
  if (!runtime?.normalizeEventLocationPoint) return null;
  return runtime.normalizeEventLocationPoint(value);
};

const currentPointSummary = (point: EventLocationPoint | null) => {
  if (!point) return '还没有选中的地点';
  const title =
    point.nameI18n?.zh?.trim() ||
    point.nameI18n?.en?.trim() ||
    point.formattedAddressI18n?.zh?.trim() ||
    point.formattedAddressI18n?.en?.trim() ||
    '已选地点';
  return `${title} · ${point.location.lat.toFixed(6)}, ${point.location.lng.toFixed(6)}`;
};

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
  const mapWrapRef = useRef<HTMLDivElement | null>(null);
  const runtimeRef = useRef<EventLocationRuntime | null>(null);
  const modalRootRef = useRef<HTMLDivElement | null>(null);
  const [runtimeReady, setRuntimeReady] = useState(false);
  const [runtimeError, setRuntimeError] = useState<string | null>(null);
  const [provider, setProvider] = useState<EventLocationProvider>(initialProvider);
  const [search, setSearch] = useState(composedQuery || '');
  const [selectedPoint, setSelectedPoint] = useState<EventLocationPoint | null>(initialPoint);

  const summaryText = useMemo(() => currentPointSummary(selectedPoint), [selectedPoint]);

  useEffect(() => {
    if (!open) return;

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
  }, [open, initialProvider]);

  useEffect(() => {
    if (!open || !runtimeReady || !runtimeRef.current || !mapWrapRef.current) return;

    const runtime = runtimeRef.current;
    const mapWrap = mapWrapRef.current;
    const root = modalRootRef.current;
    if (!root) return;

    const overlay = root.querySelector<HTMLElement>('#event-location-picker-overlay');
    const modal = root.querySelector<HTMLElement>('#event-location-picker-modal');
    const mapEl = root.querySelector<HTMLElement>('#event-location-picker-map');
    const searchInput = root.querySelector<HTMLInputElement>('#event-location-picker-search-input');
    const searchBtn = root.querySelector<HTMLButtonElement>('#event-location-picker-search-btn');
    const fillZhBtn = root.querySelector<HTMLButtonElement>('#event-location-picker-fill-zh-btn');
    const fillEnBtn = root.querySelector<HTMLButtonElement>('#event-location-picker-fill-en-btn');
    const myPosBtn = root.querySelector<HTMLButtonElement>('#event-location-picker-my-pos-btn');
    const confirmBtn = root.querySelector<HTMLButtonElement>('#event-location-picker-confirm-btn');
    const cancelBtn = root.querySelector<HTMLButtonElement>('#event-location-picker-cancel-btn');
    const statusEl = root.querySelector<HTMLElement>('#event-location-picker-status');

    if (!overlay || !modal || !mapEl || !searchInput || !searchBtn || !fillZhBtn || !fillEnBtn || !myPosBtn || !confirmBtn || !cancelBtn) {
      setRuntimeError('地图弹层节点初始化失败');
      return;
    }

    overlay.style.display = 'block';
    overlay.style.position = 'relative';
    overlay.style.inset = 'auto';
    overlay.style.background = 'transparent';
    modal.style.width = '100%';
    modal.style.maxWidth = 'none';
    modal.style.margin = '0';
    modal.style.borderRadius = '28px';
    mapEl.replaceWith(mapWrap);
    mapWrap.id = 'event-location-picker-map';
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
      runtime.closeEventLocationPickerModal?.();
    };
  }, [
    open,
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

  if (!open) return null;

  return (
    <div className="fixed inset-0 z-[90] flex items-center justify-center bg-black/55 p-4">
      <div className="flex h-[88vh] w-full max-w-[1420px] overflow-hidden rounded-[32px] border border-white/70 bg-[#f6f3ea] shadow-[0_30px_120px_rgba(7,17,16,0.24)]">
        <aside className="hidden w-[320px] border-r border-black/8 bg-[linear-gradient(180deg,#f7f0df_0%,#fbf8ef_100%)] p-6 lg:flex lg:flex-col">
          <div className="admin-studio-label">Location Picker</div>
          <h2 className="mt-3 text-[26px] font-semibold tracking-[-0.03em] text-[#071110]">地图选点</h2>
          <p className="mt-3 text-sm leading-6 text-black/52">
            当前页面直接原生接入活动地图能力，支持多地图供应商、关键词搜索、拖动 Pin、当前位置与 POI 详情。
          </p>

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
              <p>先搜索场馆名或地址，再拖动地图微调中心点。</p>
              <p>Mapbox / Geoapify 更适合国际地址，AMap 更适合国内 POI。</p>
              <p>确认后会回填活动坐标、地点名、地图地址与 provider 元信息。</p>
            </div>
          </div>

          <div className="mt-auto rounded-[20px] border border-black/8 bg-[#fffaf0] px-4 py-3 text-xs text-black/48">
            {runtimeError ? runtimeError : runtimeReady ? '地图能力已就绪。' : '正在加载地图能力与 provider 配置...'}
          </div>
        </aside>

        <div className="relative flex-1 bg-white p-4">
          <button
            type="button"
            onClick={onClose}
            className="absolute right-8 top-8 z-[3] rounded-full border border-black/10 bg-white/92 px-4 py-2 text-sm font-semibold text-[#071110] shadow-sm"
          >
            关闭
          </button>

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
                  <div ref={mapWrapRef} className="h-full w-full rounded-[20px]" />
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
        </div>
      </div>
    </div>
  );
}
