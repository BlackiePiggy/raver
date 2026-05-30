export type EventStudioLocalizedText = {
  zh: string;
  en: string;
  ja: string;
  enFull: string;
};

export type EventStudioTimezoneLookupItem = {
  city: string;
  cityAscii: string;
  province: string;
  exactProvince: string;
  stateAnsi: string;
  country: string;
  iso2: string;
  iso3: string;
  timezone: string;
  lat: number | null;
  lng: number | null;
  population: number | null;
  label: string;
  matchSource?: string;
};

export type EventStudioImageUsage = 'cover' | 'lineup';

export type EventStudioLineupSyncMode = 'incremental_fill' | 'exact_align';

export type EventStudioImageState = {
  remoteUrl: string;
  fileName: string;
};

export type EventStudioTicketTierDraft = {
  id: string;
  name: string;
  price: string;
  currency: string;
};

export type EventStudioScheduleMode = 'single_day' | 'multi_day' | 'multi_week';

export type EventStudioWeekDraft = {
  id: string;
  weekIndex: number;
  label: string;
  startDate: string;
  endDate: string;
  sortOrder: number;
};

export type EventStudioEventDayDraft = {
  id: string;
  eventDayId: string;
  weekIndex: number;
  dayIndexInWeek: number;
  overallDayIndex: number;
  label: string;
  weekday: string;
  date: string;
  sortOrder: number;
};

export type EventStudioLineupArtistDraft = {
  id: string;
  canonicalArtistId?: string | null;
  djId: string;
  memberDjIds: Array<string | null>;
  memberNamesText: string;
  sortOrder: number;
};

export type EventStudioTimetableSlotDraft = {
  id: string;
  canonicalSlotId?: string | null;
  lineupArtistId?: string | null;
  eventDayId: string;
  weekIndex: number;
  dayIndexInWeek: number;
  overallDayIndex: number;
  localDate: string;
  djId: string;
  memberDjIds: Array<string | null>;
  memberNamesText: string;
  stageName: string;
  sortOrder: number;
  startTime: string;
  endTime: string;
};

export type EventStudioDraft = {
  name: EventStudioLocalizedText;
  description: string;
  abbreviation: string;
  eventType: string;
  organizerFestivalId: string;
  organizerName: string;
  sourceEventUrl: string;
  city: EventStudioLocalizedText;
  country: EventStudioLocalizedText;
  detailAddress: EventStudioLocalizedText;
  venueName: string;
  latitude: string;
  longitude: string;
  pickedPlaceName: string;
  pickedMapAddress: string;
  timeZoneQuery: string;
  timeZoneSelection: EventStudioTimezoneLookupItem | null;
  startDate: string;
  endDate: string;
  dayRolloverHour: string;
  officialWebsite: string;
  ticketUrl: string;
  ticketCurrency: string;
  ticketNotes: string;
  coverImage: EventStudioImageState | null;
  lineupImage: EventStudioImageState | null;
  ticketTiers: EventStudioTicketTierDraft[];
  scheduleMode: EventStudioScheduleMode;
  weeks: EventStudioWeekDraft[];
  eventDays: EventStudioEventDayDraft[];
  stageOrder: string[];
  lineupSyncMode: EventStudioLineupSyncMode;
  lineupArtists: EventStudioLineupArtistDraft[];
  timetableSlots: EventStudioTimetableSlotDraft[];
};

export type EventStudioValidationErrors = Partial<Record<
  | 'name'
  | 'city'
  | 'country'
  | 'detailAddress'
  | 'startDate'
  | 'endDate'
  | 'timeZone'
  | 'coverImage'
  | 'ticketTiers'
  | 'timetableSlots',
  string
>>;

export type EventStudioSubmissionSummary = {
  id: string;
  entityType: string;
  status: string;
  title: string;
  createdEntityId?: string | null;
};

export type EventStudioSubmissionAcceptedPayload = {
  status?: string | null;
  message: string;
  submission: EventStudioSubmissionSummary;
};

export type EventStudioAlignmentIssue = {
  missingFromLineup: string[];
  extraInLineup: string[];
};

export type EventStudioAlignmentPreview = {
  aligned: boolean;
  issue?: EventStudioAlignmentIssue | null;
  message?: string | null;
  lineupArtists: Array<{
    id?: string | null;
    djId?: string | null;
    memberDjIds?: Array<string | null> | null;
    memberNames?: string[] | null;
    djName: string;
    sortOrder?: number | null;
  }>;
};

export type EventStudioApiErrorCode =
  | 'ACTIVE_EVENT_EDIT_SUBMISSION_EXISTS'
  | 'EVENT_SUBMISSION_INVALID_PAYLOAD';

export type EventStudioApiErrorDetails = {
  targetEventId?: string;
  activeSubmissionId?: string;
  activeSubmissionStatus?: string;
};

export type EventStudioCreatedEvent = {
  id: string;
  name: string;
  slug: string;
  organizerName?: string | null;
  city?: string | null;
  country?: string | null;
  startDate: string;
  endDate: string;
  status?: string | null;
};

export type EventStudioCreateResult =
  | { kind: 'created'; event: EventStudioCreatedEvent }
  | { kind: 'submitted'; payload: EventStudioSubmissionAcceptedPayload };

export type EventStudioOrganizer = {
  id: string;
  name: string;
  nameI18n?: EventStudioLocalizedText | null;
  revision?: number | null;
  abbreviation?: string | null;
  aliases: string[];
  country: string;
  countryI18n?: EventStudioLocalizedText | null;
  city: string;
  cityI18n?: EventStudioLocalizedText | null;
  tagline: string;
  avatarUrl?: string | null;
  backgroundUrl?: string | null;
};

export type EventStudioLoadedEvent = {
  id: string;
  name: string;
  nameI18n?: EventStudioLocalizedText | null;
  wikiFestivalId?: string | null;
  slug: string;
  abbreviation?: string | null;
  description?: string | null;
  countryI18n?: EventStudioLocalizedText | null;
  cityI18n?: EventStudioLocalizedText | null;
  coverImageUrl?: string | null;
  lineupImageUrl?: string | null;
  imageAssets?: Array<{
    url: string;
    type?: string | null;
    label?: string | null;
    sort?: number | null;
    order?: number | null;
    source?: string | null;
    fileName?: string | null;
  }> | null;
  eventType?: string | null;
  organizerName?: string | null;
  sourceEventUrl?: string | null;
  city?: string | null;
  country?: string | null;
  manualLocation?: {
    detailAddressI18n?: EventStudioLocalizedText | null;
    formattedAddressI18n?: EventStudioLocalizedText | null;
    selectedAt?: string | null;
  } | null;
  locationPoint?: {
    provider?: string | null;
    sourceMode?: string | null;
    location?: { lng: number; lat: number } | null;
    nameI18n?: EventStudioLocalizedText | null;
    addressI18n?: EventStudioLocalizedText | null;
    formattedAddressI18n?: EventStudioLocalizedText | null;
    city?: string | null;
  } | null;
  latitude?: number | null;
  longitude?: number | null;
  startDate: string;
  endDate: string;
  schedule?: {
    mode?: string | null;
    timeZone?: string | null;
    dayRolloverHour?: number | null;
  } | null;
  weeks?: Array<{
    id?: string | null;
    weekIndex: number;
    label?: string | null;
    startDate: string;
    endDate: string;
    sortOrder?: number | null;
  }> | null;
  eventDays?: Array<{
    id?: string | null;
    eventDayId: string;
    weekIndex: number;
    dayIndexInWeek: number;
    overallDayIndex: number;
    label?: string | null;
    weekday?: string | null;
    date: string;
    sortOrder?: number | null;
  }> | null;
  stageOrder?: string[] | null;
  lineupArtists?: Array<{
    id?: string | null;
    djId?: string | null;
    memberDjIds?: Array<string | null> | null;
    memberNames?: string[] | null;
    djName: string;
    sortOrder?: number | null;
  }> | null;
  timetableSlots?: Array<{
    id?: string | null;
    lineupArtistId?: string | null;
    eventDayId?: string | null;
    weekIndex?: number | null;
    dayIndexInWeek?: number | null;
    overallDayIndex?: number | null;
    localDate?: string | null;
    djId?: string | null;
    memberDjIds?: Array<string | null> | null;
    memberNames?: string[] | null;
    djName: string;
    stageName?: string | null;
    sortOrder?: number | null;
    startTime?: string | null;
    endTime?: string | null;
  }> | null;
  lineupSlots?: Array<{
    id?: string | null;
    lineupArtistId?: string | null;
    eventDayId?: string | null;
    weekIndex?: number | null;
    dayIndexInWeek?: number | null;
    overallDayIndex?: number | null;
    localDate?: string | null;
    djId?: string | null;
    memberDjIds?: Array<string | null> | null;
    memberNames?: string[] | null;
    djName: string;
    stageName?: string | null;
    sortOrder?: number | null;
    startTime?: string | null;
    endTime?: string | null;
  }> | null;
  timeZone?: string | null;
  dayRolloverHour?: number | null;
  ticketUrl?: string | null;
  ticketCurrency?: string | null;
  ticketNotes?: string | null;
  officialWebsite?: string | null;
  status?: string | null;
  revision?: number | null;
  ticketTiers?: Array<{
    id?: string | null;
    name: string;
    price?: number | null;
    currency?: string | null;
    sortOrder?: number | null;
  }> | null;
};

export type EventStudioCreateInput = {
  name: string;
  nameI18n?: EventStudioLocalizedText | null;
  wikiFestivalId?: string | null;
  abbreviation?: string | null;
  description?: string | null;
  eventType?: string | null;
  organizerName?: string | null;
  sourceEventUrl?: string | null;
  city?: string | null;
  cityI18n?: EventStudioLocalizedText | null;
  country?: string | null;
  countryI18n?: EventStudioLocalizedText | null;
  manualLocation?: {
    detailAddressI18n: EventStudioLocalizedText;
    formattedAddressI18n: EventStudioLocalizedText;
    selectedAt: string;
  } | null;
  locationPoint?: {
    provider: string;
    sourceMode: string;
    location: { lng: number; lat: number };
    nameI18n?: EventStudioLocalizedText | null;
    addressI18n?: EventStudioLocalizedText | null;
    formattedAddressI18n?: EventStudioLocalizedText | null;
    city?: string | null;
  } | null;
  latitude?: number | null;
  longitude?: number | null;
  ticketUrl?: string | null;
  ticketCurrency?: string | null;
  ticketNotes?: string | null;
  officialWebsite?: string | null;
  startDate: string;
  endDate: string;
  timeZone?: string | null;
  timeZoneCity?: string | null;
  timeZoneProvince?: string | null;
  timeZoneCountry?: string | null;
  timeZoneStateAnsi?: string | null;
  timeZoneLat?: number | null;
  timeZoneLng?: number | null;
  dayRolloverHour?: number | null;
  schedule?: {
    mode: EventStudioScheduleMode;
    timeZone: string;
    dayRolloverHour: number;
  } | null;
  weeks?: Array<{
    weekIndex: number;
    label?: string | null;
    startDate: string;
    endDate: string;
    sortOrder?: number;
  }> | null;
  eventDays?: Array<{
    eventDayId: string;
    weekIndex: number;
    dayIndexInWeek: number;
    overallDayIndex: number;
    label?: string | null;
    weekday?: string | null;
    date: string;
    sortOrder?: number;
  }> | null;
  stageOrder?: string[] | null;
  coverImageUrl?: string | null;
  lineupImageUrl?: string | null;
  imageAssets?: Array<{
    url: string;
    type: string;
    label: string;
    sort: number;
    order: number;
    source: string;
    fileName?: string | null;
  }> | null;
  ticketTiers?: Array<{
    name: string;
    price: number;
    currency?: string | null;
    sortOrder?: number;
  }> | null;
  lineupArtists?: Array<{
    id?: string | null;
    djId?: string | null;
    memberDjIds?: Array<string | null> | null;
    memberNames?: string[] | null;
    djName: string;
    sortOrder?: number;
  }> | null;
  lineupSlots?: Array<{
    id?: string | null;
    lineupArtistId?: string | null;
    eventDayId?: string | null;
    weekIndex?: number | null;
    dayIndexInWeek?: number | null;
    overallDayIndex?: number | null;
    localDate?: string | null;
    djId?: string | null;
    memberDjIds?: Array<string | null> | null;
    memberNames?: string[] | null;
    festivalDayIndex?: number | null;
    djName: string;
    stageName?: string | null;
    sortOrder?: number;
    startTime?: string | null;
    endTime?: string | null;
  }> | null;
  lineupSyncMode?: EventStudioLineupSyncMode | null;
  status?: string | null;
};

export type EventStudioUpdateInput = {
  name: string;
  nameI18n?: EventStudioLocalizedText | null;
  wikiFestivalId?: string | null;
  abbreviation?: string | null;
  description?: string | null;
  eventType?: string | null;
  organizerName?: string | null;
  sourceEventUrl?: string | null;
  city?: string | null;
  cityI18n?: EventStudioLocalizedText | null;
  country?: string | null;
  countryI18n?: EventStudioLocalizedText | null;
  manualLocation?: {
    detailAddressI18n: EventStudioLocalizedText;
    formattedAddressI18n: EventStudioLocalizedText;
    selectedAt: string;
  } | null;
  locationPoint?: {
    provider: string;
    sourceMode: string;
    location: { lng: number; lat: number };
    nameI18n?: EventStudioLocalizedText | null;
    addressI18n?: EventStudioLocalizedText | null;
    formattedAddressI18n?: EventStudioLocalizedText | null;
    city?: string | null;
  } | null;
  latitude?: number | null;
  longitude?: number | null;
  ticketUrl?: string | null;
  ticketCurrency?: string | null;
  ticketNotes?: string | null;
  officialWebsite?: string | null;
  startDate: string;
  endDate: string;
  timeZone?: string | null;
  timeZoneCity?: string | null;
  timeZoneProvince?: string | null;
  timeZoneCountry?: string | null;
  timeZoneStateAnsi?: string | null;
  timeZoneLat?: number | null;
  timeZoneLng?: number | null;
  dayRolloverHour?: number | null;
  schedule?: {
    mode: EventStudioScheduleMode;
    timeZone: string;
    dayRolloverHour: number;
  } | null;
  weeks?: Array<{
    weekIndex: number;
    label?: string | null;
    startDate: string;
    endDate: string;
    sortOrder?: number;
  }> | null;
  eventDays?: Array<{
    eventDayId: string;
    weekIndex: number;
    dayIndexInWeek: number;
    overallDayIndex: number;
    label?: string | null;
    weekday?: string | null;
    date: string;
    sortOrder?: number;
  }> | null;
  stageOrder?: string[] | null;
  coverImageUrl?: string | null;
  lineupImageUrl?: string | null;
  imageAssets?: Array<{
    url: string;
    type: string;
    label: string;
    sort: number;
    order: number;
    source: string;
    fileName?: string | null;
  }> | null;
  ticketTiers?: Array<{
    name: string;
    price: number;
    currency?: string | null;
    sortOrder?: number;
  }> | null;
  lineupArtists?: Array<{
    id?: string | null;
    djId?: string | null;
    memberDjIds?: Array<string | null> | null;
    memberNames?: string[] | null;
    djName: string;
    sortOrder?: number;
  }> | null;
  lineupSlots?: Array<{
    id?: string | null;
    lineupArtistId?: string | null;
    eventDayId?: string | null;
    weekIndex?: number | null;
    dayIndexInWeek?: number | null;
    overallDayIndex?: number | null;
    localDate?: string | null;
    djId?: string | null;
    memberDjIds?: Array<string | null> | null;
    memberNames?: string[] | null;
    festivalDayIndex?: number | null;
    djName: string;
    stageName?: string | null;
    sortOrder?: number;
    startTime?: string | null;
    endTime?: string | null;
  }> | null;
  lineupSyncMode?: EventStudioLineupSyncMode | null;
  status?: string | null;
  clearWikiFestivalId?: boolean;
  clearManualLocation?: boolean;
  clearLocationPoint?: boolean;
  clearLatitude?: boolean;
  clearLongitude?: boolean;
  clearStageOrder?: boolean;
  clearLineupSlots?: boolean;
};
