type EventAdminContractMode = 'create' | 'update';

export class EventAdminContractGuardrailError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'EventAdminContractGuardrailError';
  }
}

type EventAdminBody = Record<string, unknown>;

const REQUIRED_BASE_FIELDS = ['name', 'startDate', 'endDate', 'timeZone', 'schedule', 'weeks', 'eventDays'] as const;
const REQUIRED_CLEAR_FLAGS = [
  'clearCityI18n',
  'clearCountryI18n',
  'clearWikiFestivalId',
  'clearManualLocation',
  'clearLocationPoint',
  'clearLatitude',
  'clearLongitude',
  'clearSocialLinks',
  'clearStageOrder',
  'clearLineupSlots',
] as const;
const REMOVED_LEGACY_FIELDS = ['venueName', 'venueAddress'] as const;

const hasOwn = (body: EventAdminBody, key: string): boolean =>
  Object.prototype.hasOwnProperty.call(body, key);

const ensureObjectBody = (body: unknown): EventAdminBody => {
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    throw new EventAdminContractGuardrailError('Event admin payload must be a JSON object');
  }
  return body as EventAdminBody;
};

const ensureNonEmptyString = (value: unknown, field: string): void => {
  if (typeof value !== 'string' || !value.trim()) {
    throw new EventAdminContractGuardrailError(`${field} is required`);
  }
};

const ensureStructuredScheduleFoundation = (body: EventAdminBody): void => {
  if (!body.schedule || typeof body.schedule !== 'object' || Array.isArray(body.schedule)) {
    throw new EventAdminContractGuardrailError('schedule must be provided as an object');
  }
  if (!Array.isArray(body.weeks)) {
    throw new EventAdminContractGuardrailError('weeks must be provided as an array');
  }
  if (!Array.isArray(body.eventDays)) {
    throw new EventAdminContractGuardrailError('eventDays must be provided as an array');
  }
};

const ensureBooleanFlag = (body: EventAdminBody, key: string): boolean => {
  if (!hasOwn(body, key)) {
    throw new EventAdminContractGuardrailError(`${key} must be provided on event update`);
  }
  if (typeof body[key] !== 'boolean') {
    throw new EventAdminContractGuardrailError(`${key} must be a boolean`);
  }
  return body[key] as boolean;
};

const ensureExplicitFieldOrClear = (
  body: EventAdminBody,
  fieldKey: string,
  clearKey: string
): void => {
  const clear = ensureBooleanFlag(body, clearKey);
  if (!clear && !hasOwn(body, fieldKey)) {
    throw new EventAdminContractGuardrailError(
      `${fieldKey} must be present on event update, or ${clearKey} must be true`
    );
  }
};

const hasMeaningfulString = (value: unknown): boolean =>
  typeof value === 'string' && value.trim().length > 0;

const hasMeaningfulValue = (value: unknown): boolean => {
  if (value === null || value === undefined) return false;
  if (typeof value === 'string') return value.trim().length > 0;
  if (Array.isArray(value)) return value.length > 0;
  return true;
};

const ensureNoClearConflict = (body: EventAdminBody): void => {
  if (ensureBooleanFlag(body, 'clearCityI18n') && hasMeaningfulValue(body.cityI18n)) {
    throw new EventAdminContractGuardrailError('clearCityI18n=true conflicts with cityI18n payload');
  }
  if (ensureBooleanFlag(body, 'clearCountryI18n') && hasMeaningfulValue(body.countryI18n)) {
    throw new EventAdminContractGuardrailError('clearCountryI18n=true conflicts with countryI18n payload');
  }
  if (ensureBooleanFlag(body, 'clearWikiFestivalId') && hasMeaningfulString(body.wikiFestivalId)) {
    throw new EventAdminContractGuardrailError('clearWikiFestivalId=true conflicts with wikiFestivalId payload');
  }
  if (ensureBooleanFlag(body, 'clearManualLocation') && hasMeaningfulValue(body.manualLocation)) {
    throw new EventAdminContractGuardrailError('clearManualLocation=true conflicts with manualLocation payload');
  }
  if (ensureBooleanFlag(body, 'clearLocationPoint') && hasMeaningfulValue(body.locationPoint)) {
    throw new EventAdminContractGuardrailError('clearLocationPoint=true conflicts with locationPoint payload');
  }
  if (ensureBooleanFlag(body, 'clearLatitude') && body.latitude !== null && body.latitude !== undefined) {
    throw new EventAdminContractGuardrailError('clearLatitude=true conflicts with latitude payload');
  }
  if (ensureBooleanFlag(body, 'clearLongitude') && body.longitude !== null && body.longitude !== undefined) {
    throw new EventAdminContractGuardrailError('clearLongitude=true conflicts with longitude payload');
  }
  if (ensureBooleanFlag(body, 'clearSocialLinks') && hasMeaningfulValue(body.socialLinks)) {
    throw new EventAdminContractGuardrailError('clearSocialLinks=true conflicts with socialLinks payload');
  }
  if (ensureBooleanFlag(body, 'clearStageOrder') && Array.isArray(body.stageOrder) && body.stageOrder.length > 0) {
    throw new EventAdminContractGuardrailError('clearStageOrder=true conflicts with stageOrder payload');
  }
  if (ensureBooleanFlag(body, 'clearLineupSlots') && Array.isArray(body.lineupSlots) && body.lineupSlots.length > 0) {
    throw new EventAdminContractGuardrailError('clearLineupSlots=true conflicts with lineupSlots payload');
  }
};

const ensureEventStatusTruthShape = (body: EventAdminBody): void => {
  if (hasOwn(body, 'isCancelled') && body.isCancelled !== null && typeof body.isCancelled !== 'boolean') {
    throw new EventAdminContractGuardrailError('isCancelled must be a boolean or null');
  }
  if (hasOwn(body, 'visibility') && body.visibility !== null && body.visibility !== undefined) {
    if (typeof body.visibility !== 'string') {
      throw new EventAdminContractGuardrailError('visibility must be visible, hidden, or null');
    }
    const normalizedVisibility = body.visibility.trim().toLowerCase();
    if (normalizedVisibility !== 'visible' && normalizedVisibility !== 'hidden') {
      throw new EventAdminContractGuardrailError('visibility must be visible, hidden, or null');
    }
  }
  if (hasOwn(body, 'status')) {
    throw new EventAdminContractGuardrailError('status is no longer accepted on event mutation payloads; use isCancelled / visibility instead');
  }
};

const ensureNoLegacyAddressFields = (body: EventAdminBody): void => {
  for (const key of REMOVED_LEGACY_FIELDS) {
    if (hasOwn(body, key)) {
      throw new EventAdminContractGuardrailError(`${key} is no longer accepted on event mutation payloads`);
    }
  }
};

export const validateEventAdminContractPayload = (
  payload: unknown,
  mode: EventAdminContractMode
): EventAdminBody => {
  const body = ensureObjectBody(payload);

  for (const key of REQUIRED_BASE_FIELDS) {
    if (!hasOwn(body, key)) {
      throw new EventAdminContractGuardrailError(`${key} must be provided on event ${mode}`);
    }
  }

  ensureNonEmptyString(body.name, 'name');
  ensureNonEmptyString(body.startDate, 'startDate');
  ensureNonEmptyString(body.endDate, 'endDate');
  ensureNonEmptyString(body.timeZone, 'timeZone');
  ensureStructuredScheduleFoundation(body);
  ensureEventStatusTruthShape(body);
  ensureNoLegacyAddressFields(body);

  if (mode === 'update') {
    for (const key of REQUIRED_CLEAR_FLAGS) {
      ensureBooleanFlag(body, key);
    }
    ensureExplicitFieldOrClear(body, 'wikiFestivalId', 'clearWikiFestivalId');
    ensureExplicitFieldOrClear(body, 'manualLocation', 'clearManualLocation');
    ensureExplicitFieldOrClear(body, 'locationPoint', 'clearLocationPoint');
    ensureExplicitFieldOrClear(body, 'latitude', 'clearLatitude');
    ensureExplicitFieldOrClear(body, 'longitude', 'clearLongitude');
    ensureExplicitFieldOrClear(body, 'socialLinks', 'clearSocialLinks');
    ensureExplicitFieldOrClear(body, 'stageOrder', 'clearStageOrder');
    ensureExplicitFieldOrClear(body, 'lineupSlots', 'clearLineupSlots');
    ensureNoClearConflict(body);
  }

  return body;
};
