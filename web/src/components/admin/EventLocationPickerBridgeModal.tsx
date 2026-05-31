'use client';

import { useEffect, useMemo, useRef, useState } from 'react';

export type EventLocationBridgePoint = {
  provider?: string;
  sourceMode?: string;
  location: {
    lng: number;
    lat: number;
  };
  nameI18n?: {
    zh?: string;
    en?: string;
  };
  addressI18n?: {
    zh?: string;
    en?: string;
  };
  formattedAddressI18n?: {
    zh?: string;
    en?: string;
  };
  city?: string;
  countryCode?: string;
  district?: string;
  province?: string;
  providerPlaceId?: string;
  poiId?: string;
};

type FestivalViewerWindow = Window &
  typeof globalThis & {
    openEventLocationPickerModal?: (options?: Record<string, unknown>) => Promise<void> | void;
    closeEventLocationPickerModal?: () => void;
    __raverBridgePatchedClose?: boolean;
  };

type EventLocationPickerBridgeModalProps = {
  open: boolean;
  initialPoint: EventLocationBridgePoint | null;
  composedQuery?: string;
  composedQueryZh?: string;
  composedQueryEn?: string;
  onClose: () => void;
  onConfirm: (point: EventLocationBridgePoint) => void;
};

const normalizeBridgePoint = (value: unknown): EventLocationBridgePoint | null => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  const row = value as Record<string, unknown>;
  const location = row.location;
  if (!location || typeof location !== 'object' || Array.isArray(location)) return null;
  const lng = Number((location as Record<string, unknown>).lng);
  const lat = Number((location as Record<string, unknown>).lat);
  if (!Number.isFinite(lng) || !Number.isFinite(lat)) return null;

  const readTextMap = (key: string) => {
    const source = row[key];
    if (!source || typeof source !== 'object' || Array.isArray(source)) return undefined;
    const sourceRow = source as Record<string, unknown>;
    return {
      zh: typeof sourceRow.zh === 'string' ? sourceRow.zh : '',
      en: typeof sourceRow.en === 'string' ? sourceRow.en : '',
    };
  };

  return {
    provider: typeof row.provider === 'string' ? row.provider : '',
    sourceMode: typeof row.sourceMode === 'string' ? row.sourceMode : '',
    location: { lng, lat },
    nameI18n: readTextMap('nameI18n'),
    addressI18n: readTextMap('addressI18n'),
    formattedAddressI18n: readTextMap('formattedAddressI18n'),
    city: typeof row.city === 'string' ? row.city : '',
    countryCode: typeof row.countryCode === 'string' ? row.countryCode : '',
    district: typeof row.district === 'string' ? row.district : '',
    province: typeof row.province === 'string' ? row.province : '',
    providerPlaceId: typeof row.providerPlaceId === 'string' ? row.providerPlaceId : '',
    poiId: typeof row.poiId === 'string' ? row.poiId : '',
  };
};

const injectBridgeStyles = (viewerWindow: FestivalViewerWindow) => {
  const doc = viewerWindow.document;
  if (!doc) return;
  const styleId = 'raver-event-location-bridge-style';
  if (doc.getElementById(styleId)) return;

  const style = doc.createElement('style');
  style.id = styleId;
  style.textContent = `
    html, body {
      margin: 0 !important;
      padding: 0 !important;
      background: transparent !important;
      overflow: hidden !important;
    }
    body > * {
      display: none !important;
    }
    #event-location-picker-overlay {
      display: block !important;
      position: fixed !important;
      inset: 0 !important;
      background: transparent !important;
    }
    #event-location-picker-modal {
      width: 100% !important;
      max-width: none !important;
      min-height: 100dvh !important;
      margin: 0 !important;
      border-radius: 0 !important;
      box-shadow: none !important;
    }
  `;
  doc.head.appendChild(style);
};

export default function EventLocationPickerBridgeModal({
  open,
  initialPoint,
  composedQuery,
  composedQueryZh,
  composedQueryEn,
  onClose,
  onConfirm,
}: EventLocationPickerBridgeModalProps) {
  const iframeRef = useRef<HTMLIFrameElement | null>(null);
  const onCloseRef = useRef(onClose);
  const onConfirmRef = useRef(onConfirm);
  const [iframeLoaded, setIframeLoaded] = useState(false);
  const [bridgeStatus, setBridgeStatus] = useState<'booting' | 'ready' | 'failed'>('booting');

  useEffect(() => {
    onCloseRef.current = onClose;
  }, [onClose]);

  useEffect(() => {
    onConfirmRef.current = onConfirm;
  }, [onConfirm]);

  useEffect(() => {
    if (!open) {
      setIframeLoaded(false);
      setBridgeStatus('booting');
    }
  }, [open]);

  const locationSummary = useMemo(() => {
    if (!initialPoint) return '当前还没有已绑定的地图坐标。';
    const name =
      initialPoint.nameI18n?.zh?.trim() ||
      initialPoint.nameI18n?.en?.trim() ||
      initialPoint.formattedAddressI18n?.zh?.trim() ||
      initialPoint.formattedAddressI18n?.en?.trim() ||
      '已存在地图点位';
    return `${name} · ${initialPoint.location.lat.toFixed(6)}, ${initialPoint.location.lng.toFixed(6)}`;
  }, [initialPoint]);

  useEffect(() => {
    if (!open || !iframeLoaded) return;

    let cancelled = false;
    let attempts = 0;
    const iframe = iframeRef.current;

    const tryOpenPicker = () => {
      if (cancelled) return;
      attempts += 1;
      const viewerWindow = iframe?.contentWindow as FestivalViewerWindow | null;
      if (!viewerWindow || typeof viewerWindow.openEventLocationPickerModal !== 'function') {
        if (attempts < 30) {
          window.setTimeout(tryOpenPicker, 250);
          return;
        }
        setBridgeStatus('failed');
        return;
      }

      try {
        injectBridgeStyles(viewerWindow);

        if (!viewerWindow.__raverBridgePatchedClose && typeof viewerWindow.closeEventLocationPickerModal === 'function') {
          const originalClose = viewerWindow.closeEventLocationPickerModal.bind(viewerWindow);
          viewerWindow.closeEventLocationPickerModal = () => {
            originalClose();
            onCloseRef.current();
          };
          viewerWindow.__raverBridgePatchedClose = true;
        }

        const preferredProvider = initialPoint?.provider?.trim() || 'geoapify';
        void viewerWindow.openEventLocationPickerModal({
          mode: 'edit',
          provider: preferredProvider,
          initialPoint,
          composedQuery: composedQuery || '',
          composedQueryZh: composedQueryZh || '',
          composedQueryEn: composedQueryEn || '',
          onConfirm: (picked: unknown) => {
            const normalized = normalizeBridgePoint(picked);
            if (!normalized) return;
            onConfirmRef.current(normalized);
          },
        });
        setBridgeStatus('ready');
      } catch {
        if (attempts < 30) {
          window.setTimeout(tryOpenPicker, 250);
          return;
        }
        setBridgeStatus('failed');
      }
    };

    tryOpenPicker();

    return () => {
      cancelled = true;
    };
  }, [open, iframeLoaded, initialPoint, composedQuery, composedQueryZh, composedQueryEn]);

  if (!open) return null;

  return (
    <div className="fixed inset-0 z-[90] flex items-center justify-center bg-black/55 p-4">
      <div className="flex h-[88vh] w-full max-w-[1360px] overflow-hidden rounded-[32px] border border-white/70 bg-[#f6f3ea] shadow-[0_30px_120px_rgba(7,17,16,0.24)]">
        <aside className="hidden w-[300px] border-r border-black/8 bg-[linear-gradient(180deg,#f7f0df_0%,#fbf8ef_100%)] p-6 lg:flex lg:flex-col">
          <div className="admin-studio-label">Location Picker</div>
          <h2 className="mt-3 text-[26px] font-semibold tracking-[-0.03em] text-[#071110]">地图选点</h2>
          <p className="mt-3 text-sm leading-6 text-black/52">
            这里直接桥接了旧版 `festival-viewer` 的活动地点工具，搜索、拖拽 Pin、当前位置和 POI 候选都可继续使用。
          </p>

          <div className="mt-6 rounded-[24px] border border-black/8 bg-white/80 p-4 text-sm text-[#071110]">
            <div className="font-semibold">当前绑定</div>
            <div className="mt-2 text-black/55">{locationSummary}</div>
          </div>

          <div className="mt-4 rounded-[24px] border border-black/8 bg-white/80 p-4 text-sm text-[#071110]">
            <div className="font-semibold">使用建议</div>
            <div className="mt-2 space-y-2 text-black/55">
              <p>先搜场馆名或地址，再拖动地图微调中心点。</p>
              <p>确认后会自动回填活动坐标、地点名和地图地址。</p>
              <p>如果只想退出，直接点右上角关闭即可。</p>
            </div>
          </div>

          <div className="mt-auto rounded-[20px] border border-black/8 bg-[#fffaf0] px-4 py-3 text-xs text-black/48">
            {bridgeStatus === 'booting' ? '正在接入 legacy 地图工具...' : null}
            {bridgeStatus === 'ready' ? 'legacy 地图工具已就绪。' : null}
            {bridgeStatus === 'failed' ? 'legacy 地图工具接入失败，请检查本地 festival-viewer 服务是否已启动。' : null}
          </div>
        </aside>

        <div className="relative flex-1 bg-white">
          <button
            type="button"
            onClick={onClose}
            className="absolute right-5 top-5 z-[2] rounded-full border border-black/10 bg-white/92 px-4 py-2 text-sm font-semibold text-[#071110] shadow-sm"
          >
            关闭
          </button>

          <iframe
            ref={iframeRef}
            title="Event location picker"
            src="/admin/festival-viewer.html"
            className="h-full w-full border-0"
            onLoad={() => setIframeLoaded(true)}
          />
        </div>
      </div>
    </div>
  );
}
