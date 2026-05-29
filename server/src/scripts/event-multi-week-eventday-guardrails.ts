import {
  EventSubmissionValidationError,
  normalizeSubmittedEventScheduleContext,
  normalizeSubmittedTimetableSlots,
} from '../services/content-submission-event.service';
import { eventDateKey } from '../utils/event-timezone';

const assert = (condition: boolean, message: string): void => {
  if (!condition) throw new Error(message);
};

const expectValidationError = (label: string, run: () => void): void => {
  try {
    run();
  } catch (error) {
    if (error instanceof EventSubmissionValidationError) {
      return;
    }
    throw error;
  }
  throw new Error(`${label}: expected EventSubmissionValidationError`);
};

const basePayload = {
  name: 'Tomorrowland Weekend Test',
  schedule: {
    mode: 'multi_week',
    timeZone: 'Europe/Brussels',
    dayRolloverHour: 6,
  },
  weeks: [
    {
      weekIndex: 1,
      label: 'Weekend 1',
      startDate: '2026-07-17',
      endDate: '2026-07-19',
      sortOrder: 1,
    },
    {
      weekIndex: 2,
      label: 'Weekend 2',
      startDate: '2026-07-24',
      endDate: '2026-07-26',
      sortOrder: 2,
    },
  ],
  eventDays: [
    {
      eventDayId: 'w1d1',
      weekIndex: 1,
      dayIndexInWeek: 1,
      overallDayIndex: 1,
      label: 'Weekend 1 Friday',
      weekday: 'friday',
      date: '2026-07-17',
      sortOrder: 1,
    },
    {
      eventDayId: 'w1d2',
      weekIndex: 1,
      dayIndexInWeek: 2,
      overallDayIndex: 2,
      label: 'Weekend 1 Saturday',
      weekday: 'saturday',
      date: '2026-07-18',
      sortOrder: 2,
    },
    {
      eventDayId: 'w1d3',
      weekIndex: 1,
      dayIndexInWeek: 3,
      overallDayIndex: 3,
      label: 'Weekend 1 Sunday',
      weekday: 'sunday',
      date: '2026-07-19',
      sortOrder: 3,
    },
    {
      eventDayId: 'w2d1',
      weekIndex: 2,
      dayIndexInWeek: 1,
      overallDayIndex: 4,
      label: 'Weekend 2 Friday',
      weekday: 'friday',
      date: '2026-07-24',
      sortOrder: 4,
    },
    {
      eventDayId: 'w2d2',
      weekIndex: 2,
      dayIndexInWeek: 2,
      overallDayIndex: 5,
      label: 'Weekend 2 Saturday',
      weekday: 'saturday',
      date: '2026-07-25',
      sortOrder: 5,
    },
    {
      eventDayId: 'w2d3',
      weekIndex: 2,
      dayIndexInWeek: 3,
      overallDayIndex: 6,
      label: 'Weekend 2 Sunday',
      weekday: 'sunday',
      date: '2026-07-26',
      sortOrder: 6,
    },
  ],
};

const main = (): void => {
  const scheduleContext = normalizeSubmittedEventScheduleContext(basePayload);

  assert(scheduleContext.scheduleMode === 'multi_week', 'schedule mode should normalize to multi_week');
  assert(scheduleContext.weeks.length === 2, 'two structured weeks expected');
  assert(scheduleContext.eventDays.length === 6, 'six structured event days expected');
  assert(scheduleContext.eventDays.some((day) => day.eventDayId === 'w1d1'), 'w1d1 should be preserved');
  assert(scheduleContext.eventDays.some((day) => day.eventDayId === 'w2d1'), 'w2d1 should be preserved');

  const normalized = normalizeSubmittedTimetableSlots([
    {
      id: 'slot-1',
      eventDayId: 'w2d1',
      weekIndex: 2,
      dayIndexInWeek: 1,
      overallDayIndex: 4,
      localDate: '2026-07-24',
      festivalDayIndex: 4,
      djName: 'Charlotte de Witte',
      stageName: 'Mainstage',
      startTime: '2026-07-24T23:30:00',
      endTime: '2026-07-24T01:00:00',
      sortOrder: 1,
    },
  ], scheduleContext);

  assert(normalized.length === 1, 'one normalized slot expected');
  assert(normalized[0].eventDayId === 'w2d1', 'normalized slot should keep eventDayId');
  assert(normalized[0].weekIndex === 2, 'normalized slot should keep weekIndex');
  assert(normalized[0].overallDayIndex === 4, 'normalized slot should keep overallDayIndex');
  assert(normalized[0].festivalDayIndex === null, 'normalized slot should stop formally writing festivalDayIndex');
  const weekend2Friday = scheduleContext.eventDays.find((day) => day.eventDayId === 'w2d1');
  assert(Boolean(weekend2Friday), 'w2d1 event day should exist in normalized schedule');
  assert(
    Boolean(normalized[0].localDate)
      && eventDateKey(normalized[0].localDate!, 'UTC') === eventDateKey(weekend2Friday!.date, scheduleContext.timeZone),
    'normalized slot localDate should bind to event day date'
  );
  assert(
    normalized[0].endTime.getTime() > normalized[0].startTime.getTime(),
    'cross-midnight slot endTime should be normalized after startTime'
  );

  expectValidationError('missing eventDayId should be rejected', () => {
    normalizeSubmittedTimetableSlots([
      {
        festivalDayIndex: 4,
        djName: 'Anyma',
        startTime: '2026-07-24T20:00:00',
        endTime: '2026-07-24T21:00:00',
      },
    ], scheduleContext);
  });

  expectValidationError('mismatched legacy day index should be rejected', () => {
    normalizeSubmittedTimetableSlots([
      {
        eventDayId: 'w2d1',
        festivalDayIndex: 1,
        djName: 'Amelie Lens',
        startTime: '2026-07-24T20:00:00',
        endTime: '2026-07-24T21:00:00',
      },
    ], scheduleContext);
  });

  console.log('[event-multi-week-eventday-guardrails] ok');
};

main();
