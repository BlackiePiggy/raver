import type { components as EventContractComponents } from '../../../../../contracts/generated/web/event-admin';

type EventContractSchemas = EventContractComponents['schemas'];

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

export type EventStudioImageUsage = 'poster' | 'lineup' | 'timetable' | 'cover' | 'map' | 'other';

export type EventStudioImportJobKind = 'poster' | 'lineup' | 'timetable';

export type EventStudioImportJobStatus = 'pending' | 'running' | 'succeeded' | 'failed' | 'cancelled';

export type EventStudioImportJobSnapshot = {
  jobId: string;
  status: EventStudioImportJobStatus;
  createdAt: string;
  updatedAt: string;
  startedAt?: string | null;
  finishedAt?: string | null;
  result?: {
    rawJson: unknown;
    rawResponse: unknown;
  } | null;
  error?: string | null;
};

export type EventStudioLineupSyncMode = 'incremental_fill' | 'exact_align';

export type EventStudioLocationProviderMeta = {
  amap?: {
    poiId?: string | null;
    adcode?: string | null;
  } | null;
  mapkit?: {
    mapItemIdentifier?: string | null;
  } | null;
  mapbox?: {
    placeId?: string | null;
    featureType?: string | null;
  } | null;
  geoapify?: {
    placeId?: string | null;
    featureType?: string | null;
  } | null;
  google?: {
    placeId?: string | null;
    types?: string[] | null;
  } | null;
} | null;

export type EventStudioLocationPoint = EventContractSchemas['EventLocationPoint'] & {
  adcode?: string | null;
  providerMeta?: EventStudioLocationProviderMeta;
  i18nPending?: boolean;
  selectedAt?: string;
};

export type EventStudioImageOrigin =
  | 'draft-upload'
  | 'event-upload'
  | 'persisted-event';

export type EventStudioImageState = {
  id: string;
  remoteUrl: string;
  fileName: string;
  usage: EventStudioImageUsage;
  origin: EventStudioImageOrigin;
  sortOrder: number;
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
  actType?: 'solo' | 'b2b' | 'b3b';
  sortOrder: number;
};

export type EventStudioTimetableSlotDraft = {
  id: string;
  canonicalSlotId?: string | null;
  lineupArtistId?: string | null;
  actType?: 'solo' | 'b2b' | 'b3b';
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
  startDayOffset?: number;
  endDayOffset?: number;
};

export type EventStudioDraft = {
  id: string;
  name: EventStudioLocalizedText;
  description: string;
  abbreviation: string;
  eventType: string;
  organizerFestivalId: string;
  organizerName: string;
  sourceEventUrl: string;
  sourceProvider: string;
  referenceLinksText: string;
  socialLinksText: string;
  city: EventStudioLocalizedText;
  country: EventStudioLocalizedText;
  detailAddress: EventStudioLocalizedText;
  venueName: string;
  venueAddress: string;
  latitude: string;
  longitude: string;
  locationPoint: EventStudioLocationPoint | null;
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
  imageZones: Record<EventStudioImageUsage, EventStudioImageState[]>;
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

export type EventStudioSubmissionAcceptedPayload = EventContractSchemas['EventSubmissionAccepted'];

export type EventStudioAlignmentIssue = EventContractSchemas['EventLineupTimetableAlignmentIssue'];

export type EventStudioAlignmentPreview = EventContractSchemas['EventAlignmentPreview'];

export type EventStudioApiErrorCode = EventContractSchemas['EventApiErrorCode'];

export type EventStudioApiErrorDetails = EventContractSchemas['EventApiErrorDetails'];

export type EventStudioCreatedEvent = EventContractSchemas['EventSummary'];

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

export type EventStudioLoadedEvent = EventContractSchemas['EventDetail'];
export type EventStudioCreateInput = EventContractSchemas['CreateEventInput'];
export type EventStudioUpdateInput = EventContractSchemas['UpdateEventInput'];
