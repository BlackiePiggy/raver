import {
  parseEventDateInput,
  setEventDayAndKeepTime,
  startOfEventDay,
} from '../utils/event-timezone';

const cityTimezones = require('city-timezones') as {
  lookupViaCity: (city: string) => Array<{ city?: string; province?: string; state_ansi?: string; country?: string; timezone?: string }>;
  findFromCityStateProvince: (query: string) => Array<{ city?: string; province?: string; state_ansi?: string; country?: string; timezone?: string }>;
};

const assert = (condition: boolean, message: string): void => {
  if (!condition) throw new Error(message);
};

const assertIso = (actual: Date | null, expectedIso: string, label: string): void => {
  if (!(actual instanceof Date) || Number.isNaN(actual.getTime())) {
    throw new Error(`${label}: expected a valid Date`);
  }
  assert(actual.toISOString() === expectedIso, `${label}: expected ${expectedIso}, got ${actual.toISOString()}`);
};

const main = (): void => {
  const amsterdam = 'Europe/Amsterdam';

  assertIso(
    parseEventDateInput('2026-06-01', amsterdam, 'start'),
    '2026-05-31T22:00:00.000Z',
    'date-only start is event-local midnight'
  );

  assertIso(
    parseEventDateInput('2026-06-01T17:00:00', amsterdam, 'start'),
    '2026-06-01T15:00:00.000Z',
    'local wall time converts through IANA timezone'
  );

  const crossMidnightStart = parseEventDateInput('2026-06-01T23:30:00', amsterdam, 'start');
  const crossMidnightEndRaw = parseEventDateInput('2026-06-01T01:00:00', amsterdam, 'end');
  assertIso(crossMidnightStart, '2026-06-01T21:30:00.000Z', 'cross-midnight start parses as local wall time');
  assertIso(crossMidnightEndRaw, '2026-05-31T23:00:00.000Z', 'cross-midnight raw end remains same local date before slot normalization');
  assert(Boolean(crossMidnightStart && crossMidnightEndRaw && crossMidnightEndRaw < crossMidnightStart), 'cross-midnight raw end should be before start so slot normalization can add one day');

  const nonexistent = parseEventDateInput('2026-03-29T02:30:00', amsterdam, 'start');
  assert(nonexistent === null, 'DST spring-forward nonexistent local time should be rejected');

  assertIso(
    parseEventDateInput('2026-10-25T02:30:00', amsterdam, 'start'),
    '2026-10-25T00:30:00.000Z',
    'DST fall-back ambiguous local time chooses the earlier occurrence'
  );

  const day1Start = parseEventDateInput('2026-06-01T17:00:00', amsterdam, 'start');
  const nextEventStart = startOfEventDay(parseEventDateInput('2026-06-02', amsterdam, 'start')!, amsterdam);
  assertIso(
    setEventDayAndKeepTime(day1Start!, nextEventStart, 1, amsterdam),
    '2026-06-02T15:00:00.000Z',
    'event start-date rebase preserves event-local wall clock'
  );

  const monthBoundaryStart = startOfEventDay(parseEventDateInput('2026-01-31', amsterdam, 'start')!, amsterdam);
  assertIso(
    setEventDayAndKeepTime(day1Start!, monthBoundaryStart, 2, amsterdam),
    '2026-02-01T16:00:00.000Z',
    'festival day rebase crosses month boundaries without producing invalid dates'
  );

  assertIso(
    parseEventDateInput('2026-06-01T17:00:00', 'America/New_York', 'start'),
    '2026-06-01T21:00:00.000Z',
    'event timezone change preserves 17:00 wall clock while changing UTC instant'
  );

  const chicago = cityTimezones.lookupViaCity('Chicago');
  assert(
    chicago.some((item) => item.city === 'Chicago' && item.timezone === 'America/Chicago'),
    'city-timezones exact city lookup should resolve Chicago to America/Chicago'
  );
  assert(
    cityTimezones.findFromCityStateProvince('springfield').length > 1,
    'ambiguous city lookup should return multiple Springfield candidates'
  );
  assert(
    cityTimezones.findFromCityStateProvince('definitely-not-a-real-raver-city-zz').length === 0,
    'no-result city lookup should return an empty list'
  );

  console.log('[event-timetable-timezone-guardrails] ok');
};

main();
