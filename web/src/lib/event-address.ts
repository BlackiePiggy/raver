import type { Event } from '@/lib/api/event';

type LocalizedText = {
  zh?: string | null;
  en?: string | null;
  ja?: string | null;
  enFull?: string | null;
} | null | undefined;

const firstFilledText = (value?: LocalizedText): string | null => {
  if (!value) return null;
  const candidates = [value.zh, value.en, value.ja, value.enFull];
  for (const item of candidates) {
    const trimmed = String(item || '').trim();
    if (trimmed) return trimmed;
  }
  return null;
};

const normalizeText = (value: string | null | undefined): string | null => {
  const trimmed = String(value || '').trim();
  return trimmed || null;
};

export const resolveEventVenueDisplayText = (
  event: Pick<Event, 'venueDisplayAddress' | 'manualLocation' | 'locationPoint'>
): string | null => {
  const explicitVenueDisplayAddress = normalizeText(event.venueDisplayAddress);
  if (explicitVenueDisplayAddress) return explicitVenueDisplayAddress;
  const locationPoint = event.locationPoint;
  if (locationPoint) {
    return (
      firstFilledText(locationPoint.manualSetAddressI18n) ||
      firstFilledText(locationPoint.formattedAddressI18n)
    );
  }

  return (
    firstFilledText(event.manualLocation?.formattedAddressI18n) ||
    firstFilledText(event.manualLocation?.detailAddressI18n)
  );
};

export const resolveEventActivityAddressText = (
  event: Pick<Event, 'activityAddress' | 'manualLocation'>
): string | null =>
  normalizeText(event.activityAddress) || firstFilledText(event.manualLocation?.formattedAddressI18n);
