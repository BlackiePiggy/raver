'use client';

import { useEffect, useRef } from 'react';

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
  type?: 'ready' | 'confirm' | 'cancel' | 'error';
  point?: EventLocationPoint | null;
  message?: string;
};

const STANDALONE_PICKER_SOURCE = 'raver:event-location-picker';

function createStandaloneChannelId() {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
    return crypto.randomUUID();
  }
  return `picker-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
}

function toLegacyCompatiblePoint(point: EventLocationPoint | null): EventLocationPoint | null {
  if (!point) return null;
  if (point.provider !== 'google') return point;
  return {
    ...point,
    provider: 'geoapify',
  };
}

function openStandalonePickerWindow(channel: string) {
  const url = new URL('/admin/festival-viewer.html', window.location.origin);
  url.searchParams.set('standalone', 'event-location-picker');
  url.searchParams.set('channel', channel);
  url.searchParams.set('requestKey', `${STANDALONE_PICKER_SOURCE}:request:${channel}`);

  const width = Math.min(window.screen.availWidth - 80, 1520);
  const height = Math.min(window.screen.availHeight - 80, 960);
  const left = Math.max(0, Math.round((window.screen.availWidth - width) / 2));
  const top = Math.max(0, Math.round((window.screen.availHeight - height) / 2));
  const features = [
    'popup=yes',
    'resizable=yes',
    'scrollbars=yes',
    `width=${width}`,
    `height=${height}`,
    `left=${left}`,
    `top=${top}`,
  ].join(',');

  return window.open(url.toString(), `raver-event-location-picker-${channel}`, features);
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
  const popupRef = useRef<Window | null>(null);
  const closeHandledRef = useRef(false);
  const latestPropsRef = useRef({
    initialPoint,
    initialProvider,
    composedQuery,
    composedQueryZh,
    composedQueryEn,
    onClose,
    onConfirm,
  });

  useEffect(() => {
    latestPropsRef.current = {
      initialPoint,
      initialProvider,
      composedQuery,
      composedQueryZh,
      composedQueryEn,
      onClose,
      onConfirm,
    };
  }, [initialPoint, initialProvider, composedQuery, composedQueryZh, composedQueryEn, onClose, onConfirm]);

  useEffect(() => {
    if (!open) return;

    const channel = createStandaloneChannelId();
    const latest = latestPropsRef.current;
    const requestKey = `${STANDALONE_PICKER_SOURCE}:request:${channel}`;
    const payload: StandalonePickerRequest = {
      initialPoint: toLegacyCompatiblePoint(latest.initialPoint),
      provider: latest.initialProvider,
      composedQuery: String(latest.composedQuery || '').trim(),
      composedQueryZh: String(latest.composedQueryZh || '').trim(),
      composedQueryEn: String(latest.composedQueryEn || '').trim(),
    };

    closeHandledRef.current = false;
    window.sessionStorage.setItem(requestKey, JSON.stringify(payload));

    const popup = openStandalonePickerWindow(channel);
    popupRef.current = popup;

    const finalizeClose = () => {
      if (closeHandledRef.current) return;
      closeHandledRef.current = true;
      latestPropsRef.current.onClose();
    };

    const handleMessage = (event: MessageEvent<StandalonePickerMessage>) => {
      if (event.origin !== window.location.origin) return;
      const data = event.data;
      if (!data || data.source !== STANDALONE_PICKER_SOURCE || data.channel !== channel) return;

      if (data.type === 'confirm' && data.point) {
        closeHandledRef.current = true;
        latestPropsRef.current.onConfirm(data.point);
        latestPropsRef.current.onClose();
        return;
      }

      if (data.type === 'cancel' || data.type === 'error') {
        finalizeClose();
      }
    };

    window.addEventListener('message', handleMessage);

    const closeWatch = window.setInterval(() => {
      if (popupRef.current && !popupRef.current.closed) return;
      window.clearInterval(closeWatch);
      finalizeClose();
    }, 400);

    if (!popup) {
      window.clearInterval(closeWatch);
      window.removeEventListener('message', handleMessage);
      window.sessionStorage.removeItem(requestKey);
      finalizeClose();
      return;
    }

    return () => {
      window.removeEventListener('message', handleMessage);
      window.clearInterval(closeWatch);
      window.sessionStorage.removeItem(requestKey);
      if (popupRef.current && !popupRef.current.closed) {
        popupRef.current.close();
      }
      popupRef.current = null;
    };
  }, [open]);

  return null;
}
