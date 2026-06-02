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

const PROVIDER_ITEMS: Array<{ value: EventLocationProvider; label: string }> = [
  { value: 'geoapify', label: 'Geoapify' },
  { value: 'mapbox', label: 'Mapbox' },
  { value: 'mapkit', label: 'Apple MapKit' },
  { value: 'amap', label: '高德地图' },
];

const STANDALONE_PICKER_SOURCE = 'raver:event-location-picker';

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
  const [provider, setProvider] = useState<EventLocationProvider>(initialProvider);
  const [selectedPoint, setSelectedPoint] = useState<EventLocationPoint | null>(initialPoint);
  const [runtimeError, setRuntimeError] = useState<string | null>(null);
  const [frame, setFrame] = useState<StandaloneRequestFrame | null>(null);
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

    const channel = createStandaloneId('channel');
    channelRef.current = channel;
    setProvider(initialProvider);
    setSelectedPoint(initialPoint);
    setRuntimeError(null);

    const nextFrame = buildStandaloneFrame(channel, initialProvider, {
      initialPoint: toLegacyCompatiblePoint(initialPoint),
      provider: initialProvider,
      composedQuery: String(composedQuery || '').trim(),
      composedQueryZh: String(composedQueryZh || '').trim(),
      composedQueryEn: String(composedQueryEn || '').trim(),
    });

    activeRequestKeyRef.current = nextFrame.requestKey;
    setFrame(nextFrame);

    return () => {
      if (activeRequestKeyRef.current) {
        window.sessionStorage.removeItem(activeRequestKeyRef.current);
        activeRequestKeyRef.current = '';
      }
      channelRef.current = '';
    };
  }, [open, initialProvider, initialPoint, composedQuery, composedQueryZh, composedQueryEn]);

  useEffect(() => {
    if (!open || !channelRef.current || !frame) return;
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
  }, [open, provider, frame, selectedPoint]);

  useEffect(() => {
    if (!open || !frame) return;

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
  }, [open, frame]);

  const summaryText = useMemo(() => currentPointSummary(selectedPoint), [selectedPoint]);

  if (!open || !frame) return null;

  return (
    <div className="event-location-picker-shell fixed inset-0 z-[90] flex items-center justify-center bg-black/55 p-4">
      <div className="flex h-[88vh] w-full max-w-[1480px] overflow-hidden rounded-[32px] border border-white/70 bg-[#f6f3ea] shadow-[0_30px_120px_rgba(7,17,16,0.24)]">
        <aside className="hidden w-[320px] border-r border-black/8 bg-[linear-gradient(180deg,#f7f0df_0%,#fbf8ef_100%)] p-6 lg:flex lg:flex-col">
          <div className="admin-studio-label">Location Picker</div>
          <h2 className="mt-3 text-[26px] font-semibold tracking-[-0.03em] text-[#071110]">地图选点</h2>
          <p className="mt-3 text-sm leading-6 text-black/52">
            这里展示的是原版 `festival-viewer` 选点能力，但它在当前页面里以浮窗方式运行，和表单环境隔离。
          </p>

          <div className="mt-6 rounded-[24px] border border-black/8 bg-white/80 p-4 text-sm text-[#071110]">
            <div className="font-semibold">地图供应商</div>
            <div className="mt-3 grid gap-2">
              {PROVIDER_ITEMS.map((item) => (
                <button
                  key={item.value}
                  type="button"
                  onClick={() => setProvider(item.value)}
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
              <p>切换地图供应商会重新载入选点页，但不会影响当前表单。</p>
              <p>Mapbox / Geoapify 更适合国际地址，AMap 更适合国内 POI。</p>
              <p>确认后会自动回填活动坐标、地点名、地图地址与 provider 元信息。</p>
            </div>
          </div>

          <div className="mt-auto rounded-[20px] border border-black/8 bg-[#fffaf0] px-4 py-3 text-xs text-black/48">
            {runtimeError || `当前地图供应商：${provider}`}
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

          <div className="h-full overflow-hidden rounded-[28px] border border-black/8 bg-[#f6f3ea]">
            <iframe
              key={frame.requestId}
              src={frame.src}
              title="Legacy Event Location Picker"
              className="h-full w-full border-0 bg-[#f6f3ea]"
            />
          </div>
        </div>
      </div>
    </div>
  );
}
