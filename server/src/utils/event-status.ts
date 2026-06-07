import { Prisma } from '@prisma/client';

export type EventVisibility = 'visible' | 'hidden';
export type EventDerivedStatus = 'upcoming' | 'ongoing' | 'ended' | 'cancelled';
export type EventStatusFilter = EventDerivedStatus | 'all';

const normalizeStatusValue = (value: unknown): string => {
  if (typeof value !== 'string') return '';
  return value.trim().toLowerCase();
};

export const normalizeEventVisibility = (value: unknown): EventVisibility =>
  normalizeStatusValue(value) === 'hidden' ? 'hidden' : 'visible';

// Historical compatibility only:
// this preserves one-time migration semantics and old submission replay inputs
// that still carry a legacy event status string. New production write paths must
// send isCancelled / visibility truth fields instead of writing legacy status.
export const mapLegacyEventStatusToEventTruth = (legacyStatus: unknown): {
  isCancelled: boolean;
  visibility: EventVisibility;
} => {
  const normalized = normalizeStatusValue(legacyStatus);
  return {
    isCancelled: normalized === 'cancelled' || normalized === 'canceled',
    visibility: normalized === 'hidden' ? 'hidden' : 'visible',
  };
};

type EventTruthInput = {
  isCancelled?: unknown;
  visibility?: unknown;
};

export const resolveEventTruth = ({
  isCancelled,
  visibility,
}: EventTruthInput): {
  isCancelled: boolean;
  visibility: EventVisibility;
} => {
  return {
    isCancelled: isCancelled === true,
    visibility: normalizeEventVisibility(visibility),
  };
};

export const deriveEventStatus = (
  startDate: Date,
  endDate: Date,
  truth: EventTruthInput = {}
): EventDerivedStatus => {
  const resolvedTruth = resolveEventTruth(truth);

  if (resolvedTruth.isCancelled) {
    return 'cancelled';
  }

  const start = startDate.getTime();
  const end = endDate.getTime();
  const now = Date.now();

  if (Number.isFinite(start) && Number.isFinite(end) && end >= start) {
    if (now < start) return 'upcoming';
    if (now > end) return 'ended';
    return 'ongoing';
  }

  return 'upcoming';
};

export const buildEventStatusWhere = (
  status: EventStatusFilter | string,
  now: Date
): Prisma.EventWhereInput | null => {
  const normalized = normalizeStatusValue(status);

  const activeVisibilityWhere: Prisma.EventWhereInput = {
    visibility: { not: 'hidden' },
  };

  const activeCancellationWhere: Prisma.EventWhereInput = {
    isCancelled: false,
  };

  if (!normalized || normalized === 'all') {
    return null;
  }
  if (normalized === 'upcoming') {
    return {
      AND: [
        activeVisibilityWhere,
        activeCancellationWhere,
      ],
      startDate: { gt: now },
    };
  }
  if (normalized === 'ongoing') {
    return {
      AND: [
        activeVisibilityWhere,
        activeCancellationWhere,
      ],
      startDate: { lte: now },
      endDate: { gte: now },
    };
  }
  if (normalized === 'ended') {
    return {
      AND: [
        activeVisibilityWhere,
        activeCancellationWhere,
      ],
      endDate: { lt: now },
    };
  }
  if (normalized === 'cancelled') {
    return {
      isCancelled: true,
    };
  }

  return null;
};
