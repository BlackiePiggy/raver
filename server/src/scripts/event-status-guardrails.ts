import {
  buildEventStatusWhere,
  deriveEventStatus,
  mapLegacyEventStatusToEventTruth,
  normalizeEventVisibility,
  resolveEventTruth,
} from '../utils/event-status';
import {
  parseEventDateInput,
} from '../utils/event-timezone';
import { resolveEventSubmissionPayloadTruth } from '../services/content-submission-event.service';

const assert = (condition: boolean, message: string): void => {
  if (!condition) throw new Error(message);
};

const expectJson = (actual: unknown, expected: unknown, label: string): void => {
  const actualJson = JSON.stringify(actual);
  const expectedJson = JSON.stringify(expected);
  assert(actualJson === expectedJson, `${label}: expected ${expectedJson}, got ${actualJson}`);
};

const withMockedNow = <T>(nowIso: string, run: () => T): T => {
  const now = new Date(nowIso).getTime();
  const realNow = Date.now;
  Date.now = () => now;
  try {
    return run();
  } finally {
    Date.now = realNow;
  }
};

const parseRecommendationStatuses = (
  value: unknown
): Array<'ongoing' | 'upcoming' | 'ended' | 'cancelled'> => {
  if (typeof value !== 'string' || !value.trim()) {
    return ['ongoing', 'upcoming', 'ended'];
  }

  const tokens = value
    .split(',')
    .map((item) => item.trim().toLowerCase())
    .filter(Boolean);

  const order: Array<'ongoing' | 'upcoming' | 'ended' | 'cancelled'> = [
    'ongoing',
    'upcoming',
    'ended',
    'cancelled',
  ];
  const seen = new Set<string>();
  return order.filter((status) => {
    if (!tokens.includes(status)) return false;
    if (seen.has(status)) return false;
    seen.add(status);
    return true;
  }).length > 0
    ? order.filter((status) => tokens.includes(status))
    : ['ongoing', 'upcoming', 'ended'];
};

const normalizeEventsRouteStatus = (value: unknown): string => {
  const raw = typeof value === 'string' ? value.trim() : '';
  if (!raw) return 'upcoming';
  return raw.toLowerCase();
};

const normalizeCatalogSummaryStatus = (value: unknown): string => {
  const raw = typeof value === 'string' ? value.trim() : '';
  if (!raw) return 'all';
  return raw.toLowerCase();
};

type SampleEvent = {
  id: string;
  startDate: Date;
  endDate: Date;
  isCancelled: boolean;
  visibility: 'visible' | 'hidden';
  updatedAt: Date;
};

const matchesEventWhere = (event: SampleEvent, where: unknown): boolean => {
  if (!where || typeof where !== 'object' || Array.isArray(where)) return true;
  const input = where as Record<string, unknown>;

  if (Array.isArray(input.AND)) {
    for (const item of input.AND) {
      if (!matchesEventWhere(event, item)) return false;
    }
  }

  if (typeof input.isCancelled === 'boolean' && event.isCancelled !== input.isCancelled) {
    return false;
  }

  if (typeof input.visibility === 'string' && event.visibility !== input.visibility) {
    return false;
  }

  if (input.visibility && typeof input.visibility === 'object' && !Array.isArray(input.visibility)) {
    const visibilityFilter = input.visibility as Record<string, unknown>;
    if (typeof visibilityFilter.not === 'string' && event.visibility === visibilityFilter.not) {
      return false;
    }
  }

  if (input.startDate && typeof input.startDate === 'object' && !Array.isArray(input.startDate)) {
    const filter = input.startDate as Record<string, unknown>;
    if (filter.gt instanceof Date && !(event.startDate > filter.gt)) return false;
    if (filter.gte instanceof Date && !(event.startDate >= filter.gte)) return false;
    if (filter.lt instanceof Date && !(event.startDate < filter.lt)) return false;
    if (filter.lte instanceof Date && !(event.startDate <= filter.lte)) return false;
  }

  if (input.endDate && typeof input.endDate === 'object' && !Array.isArray(input.endDate)) {
    const filter = input.endDate as Record<string, unknown>;
    if (filter.gt instanceof Date && !(event.endDate > filter.gt)) return false;
    if (filter.gte instanceof Date && !(event.endDate >= filter.gte)) return false;
    if (filter.lt instanceof Date && !(event.endDate < filter.lt)) return false;
    if (filter.lte instanceof Date && !(event.endDate <= filter.lte)) return false;
  }

  return true;
};

const sortEventsByStatusRoute = (events: SampleEvent[], status: string): SampleEvent[] => {
  const rows = [...events];
  rows.sort((left, right) => {
    if (status === 'ended') {
      if (right.startDate.getTime() !== left.startDate.getTime()) {
        return right.startDate.getTime() - left.startDate.getTime();
      }
      return right.id.localeCompare(left.id);
    }

    if (left.startDate.getTime() !== right.startDate.getTime()) {
      return left.startDate.getTime() - right.startDate.getTime();
    }
    return left.id.localeCompare(right.id);
  });
  return rows;
};

const sortCatalogSummaryEvents = (
  events: SampleEvent[],
  sortBy: 'startDateAsc' | 'startDateDesc' | 'updatedAtDesc' | 'updatedAtAsc'
): SampleEvent[] => {
  const rows = [...events];
  rows.sort((left, right) => {
    if (sortBy === 'startDateAsc') {
      if (left.startDate.getTime() !== right.startDate.getTime()) {
        return left.startDate.getTime() - right.startDate.getTime();
      }
      return left.id.localeCompare(right.id);
    }
    if (sortBy === 'updatedAtDesc') {
      if (right.updatedAt.getTime() !== left.updatedAt.getTime()) {
        return right.updatedAt.getTime() - left.updatedAt.getTime();
      }
      return right.id.localeCompare(left.id);
    }
    if (sortBy === 'updatedAtAsc') {
      if (left.updatedAt.getTime() !== right.updatedAt.getTime()) {
        return left.updatedAt.getTime() - right.updatedAt.getTime();
      }
      return left.id.localeCompare(right.id);
    }
    if (right.startDate.getTime() !== left.startDate.getTime()) {
      return right.startDate.getTime() - left.startDate.getTime();
    }
    return right.id.localeCompare(left.id);
  });
  return rows;
};

const verifyDerivedStatusBoundaries = (): void => {
  const start = new Date('2026-08-10T12:00:00.000Z');
  const end = new Date('2026-08-10T14:00:00.000Z');

  withMockedNow('2026-08-10T11:59:59.000Z', () => {
    assert(deriveEventStatus(start, end, { isCancelled: false, visibility: 'visible' }) === 'upcoming', 'before start should be upcoming');
  });

  withMockedNow('2026-08-10T12:00:00.000Z', () => {
    assert(deriveEventStatus(start, end, { isCancelled: false, visibility: 'visible' }) === 'ongoing', 'at start should be ongoing');
  });

  withMockedNow('2026-08-10T14:00:00.000Z', () => {
    assert(deriveEventStatus(start, end, { isCancelled: false, visibility: 'visible' }) === 'ongoing', 'at end should remain ongoing');
  });

  withMockedNow('2026-08-10T14:00:01.000Z', () => {
    assert(deriveEventStatus(start, end, { isCancelled: false, visibility: 'visible' }) === 'ended', 'after end should be ended');
  });
};

const verifyCancelledPriority = (): void => {
  const start = new Date('2026-08-10T12:00:00.000Z');
  const end = new Date('2026-08-10T14:00:00.000Z');

  withMockedNow('2026-08-10T13:00:00.000Z', () => {
    assert(deriveEventStatus(start, end, { isCancelled: true, visibility: 'visible' }) === 'cancelled', 'cancelled should override active window');
  });
};

const verifyTruthResolution = (): void => {
  expectJson(
    resolveEventTruth({ isCancelled: true, visibility: 'hidden' }),
    { isCancelled: true, visibility: 'hidden' },
    'explicit truth should be preserved'
  );

  assert(normalizeEventVisibility(' hidden ') === 'hidden', 'visibility normalization should trim and lowercase');
  assert(normalizeEventVisibility('VISIBLE') === 'visible', 'unknown visibility should fall back to visible');
};

const verifyLegacyMigrationMapping = (): void => {
  expectJson(
    mapLegacyEventStatusToEventTruth('cancelled'),
    { isCancelled: true, visibility: 'visible' },
    'legacy cancelled should migrate to isCancelled=true'
  );
  expectJson(
    mapLegacyEventStatusToEventTruth('canceled'),
    { isCancelled: true, visibility: 'visible' },
    'legacy canceled should migrate to isCancelled=true'
  );
  expectJson(
    mapLegacyEventStatusToEventTruth('hidden'),
    { isCancelled: false, visibility: 'hidden' },
    'legacy hidden should migrate to visibility=hidden'
  );
  expectJson(
    mapLegacyEventStatusToEventTruth('active'),
    { isCancelled: false, visibility: 'visible' },
    'legacy active should migrate to visible non-cancelled truth'
  );
  expectJson(
    mapLegacyEventStatusToEventTruth('ongoing'),
    { isCancelled: false, visibility: 'visible' },
    'legacy derived time states should fall back to visible non-cancelled truth'
  );
  expectJson(
    mapLegacyEventStatusToEventTruth(null),
    { isCancelled: false, visibility: 'visible' },
    'missing legacy status should fall back to visible non-cancelled truth'
  );
};

const verifyLegacySubmissionReplayTruthFallback = (): void => {
  expectJson(
    resolveEventSubmissionPayloadTruth({
      payload: {
        status: 'hidden',
      },
    }),
    { isCancelled: false, visibility: 'hidden' },
    'legacy hidden submission replay should resolve to hidden truth'
  );

  expectJson(
    resolveEventSubmissionPayloadTruth({
      payload: {
        status: 'cancelled',
      },
    }),
    { isCancelled: true, visibility: 'visible' },
    'legacy cancelled submission replay should resolve to cancelled truth'
  );

  expectJson(
    resolveEventSubmissionPayloadTruth({
      payload: {
        status: 'hidden',
        visibility: 'visible',
      },
    }),
    { isCancelled: false, visibility: 'visible' },
    'explicit visibility truth should override legacy submission status fallback'
  );

  expectJson(
    resolveEventSubmissionPayloadTruth({
      payload: {},
      existingTruth: {
        isCancelled: true,
        visibility: 'hidden',
      },
    }),
    { isCancelled: true, visibility: 'hidden' },
    'submission replay without truth override should preserve existing event truth'
  );
};

const verifyStatusFilters = (): void => {
  const now = new Date('2026-08-10T13:00:00.000Z');

  expectJson(
    buildEventStatusWhere('upcoming', now),
    {
      AND: [
        { visibility: { not: 'hidden' } },
        { isCancelled: false },
      ],
      startDate: { gt: now },
    },
    'upcoming where'
  );

  expectJson(
    buildEventStatusWhere('ongoing', now),
    {
      AND: [
        { visibility: { not: 'hidden' } },
        { isCancelled: false },
      ],
      startDate: { lte: now },
      endDate: { gte: now },
    },
    'ongoing where'
  );

  expectJson(
    buildEventStatusWhere('ended', now),
    {
      AND: [
        { visibility: { not: 'hidden' } },
        { isCancelled: false },
      ],
      endDate: { lt: now },
    },
    'ended where'
  );

  expectJson(
    buildEventStatusWhere('cancelled', now),
    { isCancelled: true },
    'cancelled where'
  );

  assert(buildEventStatusWhere('all', now) === null, 'all status should not add where');
  assert(buildEventStatusWhere('hidden', now) === null, 'hidden should no longer be treated as event status');
  assert(buildEventStatusWhere('active', now) === null, 'active should no longer be treated as event status');
  assert(buildEventStatusWhere('unknown', now) === null, 'unknown status should not add where');
};

const verifyTimezoneAndOvernightDerivation = (): void => {
  const overnightShanghaiStart = parseEventDateInput('2026-08-10', 'Asia/Shanghai', 'start', '23:00:00');
  const overnightShanghaiEnd = parseEventDateInput('2026-08-11', 'Asia/Shanghai', 'end', '02:00:00');
  assert(Boolean(overnightShanghaiStart), 'overnight Shanghai start should parse');
  assert(Boolean(overnightShanghaiEnd), 'overnight Shanghai end should parse');

  withMockedNow('2026-08-10T16:30:00.000Z', () => {
    assert(
      deriveEventStatus(overnightShanghaiStart!, overnightShanghaiEnd!, {
        isCancelled: false,
        visibility: 'visible',
      }) === 'ongoing',
      'overnight Shanghai event should be ongoing during local after-midnight window'
    );
  });

  withMockedNow('2026-08-10T14:59:59.000Z', () => {
    assert(
      deriveEventStatus(overnightShanghaiStart!, overnightShanghaiEnd!, {
        isCancelled: false,
        visibility: 'visible',
      }) === 'upcoming',
      'overnight Shanghai event should still be upcoming before local start'
    );
  });

  const laStart = parseEventDateInput('2026-08-10', 'America/Los_Angeles', 'start', '20:00:00');
  const laEnd = parseEventDateInput('2026-08-11', 'America/Los_Angeles', 'end', '02:00:00');
  assert(Boolean(laStart), 'Los Angeles start should parse');
  assert(Boolean(laEnd), 'Los Angeles end should parse');

  withMockedNow('2026-08-11T02:59:59.000Z', () => {
    assert(
      deriveEventStatus(laStart!, laEnd!, {
        isCancelled: false,
        visibility: 'visible',
      }) === 'upcoming',
      'Los Angeles overnight event should remain upcoming before local start even on next UTC day'
    );
  });

  withMockedNow('2026-08-11T03:00:00.000Z', () => {
    assert(
      deriveEventStatus(laStart!, laEnd!, {
        isCancelled: false,
        visibility: 'visible',
      }) === 'ongoing',
      'Los Angeles overnight event should become ongoing at local start'
    );
  });
};

const verifyRecommendationBuckets = (): void => {
  const now = new Date('2026-08-10T13:00:00.000Z');
  withMockedNow(now.toISOString(), () => {
    const derivedById = {
      upcoming: deriveEventStatus(
        new Date('2026-08-10T14:00:00.000Z'),
        new Date('2026-08-10T16:00:00.000Z'),
        { isCancelled: false, visibility: 'visible' }
      ),
      ongoing: deriveEventStatus(
        new Date('2026-08-10T12:00:00.000Z'),
        new Date('2026-08-10T14:00:00.000Z'),
        { isCancelled: false, visibility: 'visible' }
      ),
      ended: deriveEventStatus(
        new Date('2026-08-10T10:00:00.000Z'),
        new Date('2026-08-10T12:59:59.000Z'),
        { isCancelled: false, visibility: 'visible' }
      ),
      cancelled: deriveEventStatus(
        new Date('2026-08-10T12:00:00.000Z'),
        new Date('2026-08-10T14:00:00.000Z'),
        { isCancelled: true, visibility: 'visible' }
      ),
    };

    expectJson(
      derivedById,
      {
        upcoming: 'upcoming',
        ongoing: 'ongoing',
        ended: 'ended',
        cancelled: 'cancelled',
      },
      'derived statuses should map cleanly to recommendation buckets'
    );
  });

  expectJson(
    parseRecommendationStatuses(undefined),
    ['ongoing', 'upcoming', 'ended'],
    'empty recommendation status query should default to ongoing/upcoming/ended'
  );

  expectJson(
    parseRecommendationStatuses('cancelled,upcoming'),
    ['upcoming', 'cancelled'],
    'recommendation status query should normalize to canonical order'
  );

  expectJson(
    parseRecommendationStatuses('foo,bar'),
    ['ongoing', 'upcoming', 'ended'],
    'invalid recommendation status query should fall back to default buckets'
  );

  expectJson(
    buildEventStatusWhere('ongoing', now),
    {
      AND: [
        { visibility: { not: 'hidden' } },
        { isCancelled: false },
      ],
      startDate: { lte: now },
      endDate: { gte: now },
    },
    'ongoing bucket where should match derived ongoing semantics'
  );
};

const verifyWebReadPathBuckets = (): void => {
  const now = new Date('2026-08-10T13:00:00.000Z');
  const sampleEvents: SampleEvent[] = [
    {
      id: 'upcoming-visible',
      startDate: new Date('2026-08-10T15:00:00.000Z'),
      endDate: new Date('2026-08-10T18:00:00.000Z'),
      isCancelled: false,
      visibility: 'visible',
      updatedAt: new Date('2026-08-10T09:00:00.000Z'),
    },
    {
      id: 'upcoming-hidden',
      startDate: new Date('2026-08-10T16:00:00.000Z'),
      endDate: new Date('2026-08-10T19:00:00.000Z'),
      isCancelled: false,
      visibility: 'hidden',
      updatedAt: new Date('2026-08-10T09:30:00.000Z'),
    },
    {
      id: 'ongoing-visible-a',
      startDate: new Date('2026-08-10T11:00:00.000Z'),
      endDate: new Date('2026-08-10T13:30:00.000Z'),
      isCancelled: false,
      visibility: 'visible',
      updatedAt: new Date('2026-08-10T08:00:00.000Z'),
    },
    {
      id: 'ongoing-visible-b',
      startDate: new Date('2026-08-10T12:00:00.000Z'),
      endDate: new Date('2026-08-10T15:00:00.000Z'),
      isCancelled: false,
      visibility: 'visible',
      updatedAt: new Date('2026-08-10T08:30:00.000Z'),
    },
    {
      id: 'ended-visible-old',
      startDate: new Date('2026-08-09T10:00:00.000Z'),
      endDate: new Date('2026-08-09T12:00:00.000Z'),
      isCancelled: false,
      visibility: 'visible',
      updatedAt: new Date('2026-08-09T16:00:00.000Z'),
    },
    {
      id: 'ended-visible-recent',
      startDate: new Date('2026-08-10T09:00:00.000Z'),
      endDate: new Date('2026-08-10T12:00:00.000Z'),
      isCancelled: false,
      visibility: 'visible',
      updatedAt: new Date('2026-08-10T12:15:00.000Z'),
    },
    {
      id: 'cancelled-visible',
      startDate: new Date('2026-08-10T12:00:00.000Z'),
      endDate: new Date('2026-08-10T16:00:00.000Z'),
      isCancelled: true,
      visibility: 'visible',
      updatedAt: new Date('2026-08-10T07:00:00.000Z'),
    },
  ];

  const bootstrapOngoing = sortEventsByStatusRoute(
    sampleEvents.filter((event) => matchesEventWhere(event, buildEventStatusWhere('ongoing', now))),
    'ongoing'
  ).map((event) => event.id);
  const bootstrapUpcoming = sortEventsByStatusRoute(
    sampleEvents.filter((event) => matchesEventWhere(event, buildEventStatusWhere('upcoming', now))),
    'upcoming'
  ).map((event) => event.id);

  expectJson(
    bootstrapOngoing,
    ['ongoing-visible-a', 'ongoing-visible-b'],
    'bootstrap ongoing bucket should include only visible non-cancelled ongoing events'
  );
  expectJson(
    bootstrapUpcoming,
    ['upcoming-visible'],
    'bootstrap upcoming bucket should exclude hidden and cancelled upcoming events'
  );

  const eventsDefaultStatus = normalizeEventsRouteStatus(undefined);
  const eventsDefaultRows = sortEventsByStatusRoute(
    sampleEvents.filter((event) => matchesEventWhere(event, buildEventStatusWhere(eventsDefaultStatus, now))),
    eventsDefaultStatus
  ).map((event) => event.id);
  expectJson(
    eventsDefaultRows,
    ['upcoming-visible'],
    '/events default status should be upcoming'
  );

  const eventsEndedRows = sortEventsByStatusRoute(
    sampleEvents.filter((event) => matchesEventWhere(event, buildEventStatusWhere('ended', now))),
    'ended'
  ).map((event) => event.id);
  expectJson(
    eventsEndedRows,
    ['ended-visible-recent', 'ended-visible-old'],
    '/events ended bucket should sort by startDate desc'
  );

  const catalogAllRows = sortCatalogSummaryEvents(
    sampleEvents.filter((event) => matchesEventWhere(event, buildEventStatusWhere(normalizeCatalogSummaryStatus(undefined), now))),
    'startDateDesc'
  ).map((event) => event.id);
  expectJson(
    catalogAllRows,
    [
      'upcoming-hidden',
      'upcoming-visible',
      'ongoing-visible-b',
      'cancelled-visible',
      'ongoing-visible-a',
      'ended-visible-recent',
      'ended-visible-old',
    ],
    'catalog summary default all should not apply status filtering'
  );

  const catalogUpdatedDesc = sortCatalogSummaryEvents(sampleEvents, 'updatedAtDesc').map((event) => event.id);
  expectJson(
    catalogUpdatedDesc,
    [
      'ended-visible-recent',
      'upcoming-hidden',
      'upcoming-visible',
      'ongoing-visible-b',
      'ongoing-visible-a',
      'cancelled-visible',
      'ended-visible-old',
    ],
    'catalog summary updatedAtDesc should follow route sort semantics'
  );

  const derivedStatuses = withMockedNow(now.toISOString(), () =>
    Object.fromEntries(
      sampleEvents.map((event) => [
        event.id,
        deriveEventStatus(event.startDate, event.endDate, {
          isCancelled: event.isCancelled,
          visibility: event.visibility,
        }),
      ])
    )
  );
  expectJson(
    derivedStatuses,
    {
      'upcoming-visible': 'upcoming',
      'upcoming-hidden': 'upcoming',
      'ongoing-visible-a': 'ongoing',
      'ongoing-visible-b': 'ongoing',
      'ended-visible-old': 'ended',
      'ended-visible-recent': 'ended',
      'cancelled-visible': 'cancelled',
    },
    'catalog summary returned statuses should remain derived from truth fields after filtering'
  );

  const festivalFeedUpcoming = sortEventsByStatusRoute(
    sampleEvents.filter((event) => matchesEventWhere(event, buildEventStatusWhere('upcoming', now))),
    'upcoming'
  ).map((event) => event.id);
  const festivalFeedEnded = sortEventsByStatusRoute(
    sampleEvents.filter((event) => matchesEventWhere(event, buildEventStatusWhere('ended', now))),
    'ended'
  ).map((event) => event.id);
  expectJson(
    { upcoming: festivalFeedUpcoming, ended: festivalFeedEnded },
    {
      upcoming: ['upcoming-visible'],
      ended: ['ended-visible-recent', 'ended-visible-old'],
    },
    'festival feed should expose only upcoming and ended visible non-cancelled events'
  );
};

const main = (): void => {
  verifyDerivedStatusBoundaries();
  verifyCancelledPriority();
  verifyTruthResolution();
  verifyLegacyMigrationMapping();
  verifyLegacySubmissionReplayTruthFallback();
  verifyStatusFilters();
  verifyTimezoneAndOvernightDerivation();
  verifyRecommendationBuckets();
  verifyWebReadPathBuckets();

  console.log('[event-status-guardrails] ok');
};

main();
