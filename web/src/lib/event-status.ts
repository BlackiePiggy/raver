export type EventDisplayStatus = 'upcoming' | 'ongoing' | 'ended' | 'cancelled';
export type EventVisibility = 'visible' | 'hidden';

type EventStatusLike = {
  status?: string | null;
  isCancelled?: boolean | null;
  visibility?: EventVisibility | null;
};

const normalizeText = (value?: string | null): string => String(value || '').trim().toLowerCase();

export const resolveEventDisplayStatus = (event: EventStatusLike): EventDisplayStatus => {
  if (event.isCancelled === true) return 'cancelled';
  return normalizeEventDisplayStatus(event.status);
};

export const resolveEventVisibility = (event: EventStatusLike): EventVisibility => {
  const visibility = normalizeText(event.visibility);
  if (visibility === 'hidden') return 'hidden';

  return 'visible';
};

export const formatEventDisplayStatusText = (event: EventStatusLike): string => {
  const status = resolveEventDisplayStatus(event);
  if (status === 'cancelled') return '已取消';
  if (status === 'ongoing') return '进行中';
  if (status === 'ended') return '已结束';
  return '即将开始';
};

export const formatEventVisibilityText = (event: EventStatusLike): string | null => {
  return resolveEventVisibility(event) === 'hidden' ? '已隐藏' : null;
};

function normalizeEventDisplayStatus(status?: string | null): EventDisplayStatus {
  const normalized = normalizeText(status);
  if (normalized === 'cancelled') return 'cancelled';
  if (normalized === 'ongoing') return 'ongoing';
  if (normalized === 'ended') return 'ended';
  return 'upcoming';
}
