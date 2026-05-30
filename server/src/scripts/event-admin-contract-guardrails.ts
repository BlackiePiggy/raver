import {
  EventAdminContractGuardrailError,
  validateEventAdminContractPayload,
} from '../services/event-admin-contract-guardrail.service';

const assert = (condition: boolean, message: string): void => {
  if (!condition) throw new Error(message);
};

const expectGuardrailError = (label: string, run: () => void): void => {
  try {
    run();
  } catch (error) {
    if (error instanceof EventAdminContractGuardrailError) {
      return;
    }
    throw error;
  }
  throw new Error(`${label}: expected EventAdminContractGuardrailError`);
};

const baseUpdatePayload = {
  name: 'Contract Guardrail Event',
  nameI18n: { en: 'Contract Guardrail Event', zh: '契约校验活动' },
  wikiFestivalId: null,
  abbreviation: null,
  description: 'Phase 4 event contract guardrail payload',
  eventType: 'festival',
  organizerName: 'Raver Crew',
  sourceEventUrl: 'https://example.com/events/contract-guardrail',
  city: 'Shanghai',
  cityI18n: { en: 'Shanghai', zh: '上海' },
  country: 'China',
  countryI18n: { en: 'China', zh: '中国', enFull: 'China' },
  manualLocation: null,
  locationPoint: null,
  latitude: null,
  longitude: null,
  ticketUrl: null,
  ticketCurrency: 'CNY',
  ticketNotes: null,
  officialWebsite: null,
  startDate: '2099-12-24',
  endDate: '2099-12-26',
  schedule: {
    mode: 'multi_day',
    timeZone: 'Asia/Shanghai',
    dayRolloverHour: 6,
  },
  weeks: [
    {
      weekIndex: 1,
      label: 'Main Week',
      startDate: '2099-12-24',
      endDate: '2099-12-26',
      sortOrder: 1,
    },
  ],
  eventDays: [
    {
      eventDayId: 'd1',
      weekIndex: 1,
      dayIndexInWeek: 1,
      overallDayIndex: 1,
      label: 'Day 1',
      weekday: 'thursday',
      date: '2099-12-24',
      sortOrder: 1,
    },
    {
      eventDayId: 'd2',
      weekIndex: 1,
      dayIndexInWeek: 2,
      overallDayIndex: 2,
      label: 'Day 2',
      weekday: 'friday',
      date: '2099-12-25',
      sortOrder: 2,
    },
    {
      eventDayId: 'd3',
      weekIndex: 1,
      dayIndexInWeek: 3,
      overallDayIndex: 3,
      label: 'Day 3',
      weekday: 'saturday',
      date: '2099-12-26',
      sortOrder: 3,
    },
  ],
  timeZone: 'Asia/Shanghai',
  timeZoneCity: 'Shanghai',
  timeZoneProvince: 'Shanghai',
  timeZoneCountry: 'China',
  timeZoneStateAnsi: 'SH',
  timeZoneLat: 31.2304,
  timeZoneLng: 121.4737,
  startTime: null,
  endTime: null,
  dayRolloverHour: 6,
  stageOrder: null,
  coverImageUrl: null,
  lineupImageUrl: null,
  imageAssets: null,
  ticketTiers: null,
  lineupArtists: null,
  lineupSlots: null,
  lineupSyncMode: 'incremental_fill',
  status: 'upcoming',
  clearCityI18n: false,
  clearCountryI18n: false,
  clearWikiFestivalId: true,
  clearManualLocation: true,
  clearLocationPoint: true,
  clearLatitude: true,
  clearLongitude: true,
  clearStageOrder: true,
  clearLineupSlots: true,
};

const main = (): void => {
  const createPayload = {
    ...baseUpdatePayload,
  };
  delete (createPayload as Partial<typeof createPayload>).clearCityI18n;
  delete (createPayload as Partial<typeof createPayload>).clearCountryI18n;
  delete (createPayload as Partial<typeof createPayload>).clearWikiFestivalId;
  delete (createPayload as Partial<typeof createPayload>).clearManualLocation;
  delete (createPayload as Partial<typeof createPayload>).clearLocationPoint;
  delete (createPayload as Partial<typeof createPayload>).clearLatitude;
  delete (createPayload as Partial<typeof createPayload>).clearLongitude;
  delete (createPayload as Partial<typeof createPayload>).clearStageOrder;
  delete (createPayload as Partial<typeof createPayload>).clearLineupSlots;

  const validatedCreate = validateEventAdminContractPayload(createPayload, 'create');
  assert(validatedCreate.name === 'Contract Guardrail Event', 'create payload should validate');

  const validatedUpdate = validateEventAdminContractPayload(baseUpdatePayload, 'update');
  assert(validatedUpdate.timeZone === 'Asia/Shanghai', 'update payload should validate');

  expectGuardrailError('update should reject missing schedule', () => {
    const payload = { ...baseUpdatePayload };
    delete (payload as Partial<typeof payload>).schedule;
    validateEventAdminContractPayload(payload, 'update');
  });

  expectGuardrailError('update should reject missing clear flag', () => {
    const payload = { ...baseUpdatePayload };
    delete (payload as Partial<typeof payload>).clearManualLocation;
    validateEventAdminContractPayload(payload, 'update');
  });

  expectGuardrailError('update should reject partial patch omission for locationPoint', () => {
    const payload = {
      ...baseUpdatePayload,
      clearLocationPoint: false,
    };
    delete (payload as Partial<typeof payload>).locationPoint;
    validateEventAdminContractPayload(payload, 'update');
  });

  expectGuardrailError('update should reject clear/manualLocation conflict', () => {
    validateEventAdminContractPayload(
      {
        ...baseUpdatePayload,
        clearManualLocation: true,
        manualLocation: {
          detailAddressI18n: { en: '88 Xuhui', zh: '徐汇 88 号' },
          formattedAddressI18n: { en: 'China · Shanghai · 88 Xuhui', zh: '中国 · 上海 · 徐汇 88 号' },
          selectedAt: '2099-12-01T12:00:00.000Z',
        },
      },
      'update'
    );
  });

  console.log('[event-admin-contract-guardrails] ok');
};

main();
