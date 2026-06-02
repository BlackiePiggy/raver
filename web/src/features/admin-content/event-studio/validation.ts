import { EventStudioDraft, EventStudioImageState, EventStudioValidationErrors } from './types';

const firstFilledText = (...values: Array<string | undefined | null>): string => {
  for (const value of values) {
    const trimmed = String(value || '').trim();
    if (trimmed) return trimmed;
  }
  return '';
};

const isValidUrl = (value: string): boolean => {
  try {
    new URL(value);
    return true;
  } catch {
    return false;
  }
};

export const validateEventStudioDraft = (draft: EventStudioDraft): EventStudioValidationErrors => {
  const errors: EventStudioValidationErrors = {};
  const expectedPerformersByActType: Record<NonNullable<EventStudioDraft['timetableSlots'][number]['actType']>, number> = {
    solo: 1,
    b2b: 2,
    b3b: 3,
  };
  const hasVisualItem = (item: EventStudioImageState) =>
    item.remoteUrl.trim().length > 0 || Boolean(item.localFile) || Boolean(item.localPreviewUrl?.trim());
  const hasEntryVisual =
    draft.imageZones.poster.some(hasVisualItem) ||
    draft.imageZones.lineup.some(hasVisualItem) ||
    draft.imageZones.cover.some(hasVisualItem);

  if (!firstFilledText(draft.name.zh, draft.name.en, draft.name.ja, draft.name.enFull)) {
    errors.name = '请至少填写一个活动名称。';
  }

  if (!firstFilledText(draft.city.zh, draft.city.en, draft.city.ja, draft.city.enFull)) {
    errors.city = '请填写活动城市。';
  }

  if (!firstFilledText(draft.country.zh, draft.country.en, draft.country.ja, draft.country.enFull)) {
    errors.country = '请填写活动国家。';
  }

  if (!firstFilledText(draft.detailAddress.zh, draft.detailAddress.en, draft.detailAddress.ja, draft.detailAddress.enFull)) {
    errors.detailAddress = '请填写详细地址。';
  }

  if (!draft.startDate.trim()) {
    errors.startDate = '请选择开始日期。';
  }

  if (!draft.endDate.trim()) {
    errors.endDate = '请选择结束日期。';
  }

  if (draft.startDate && draft.endDate && draft.endDate < draft.startDate) {
    errors.endDate = '结束日期不能早于开始日期。';
  }

  if (draft.scheduleMode === 'single_day' && draft.startDate && draft.endDate && draft.startDate !== draft.endDate) {
    errors.endDate = '单日活动的开始和结束日期必须相同。';
  }

  if (draft.scheduleMode === 'single_day' && (!draft.startDate.trim() || !draft.endDate.trim())) {
    errors.startDate = errors.startDate || '请选择活动日期。';
  }

  if (!draft.timeZoneSelection?.timezone?.trim()) {
    errors.timeZone = '请从候选列表中确认活动时区。';
  }

  if (draft.scheduleMode === 'multi_week' && draft.weeks.length < 2) {
    errors.endDate = '多周活动至少需要两个周区间。';
  }

  if (
    draft.scheduleMode === 'multi_week' &&
    draft.weeks.some((week) => !week.startDate.trim() || !week.endDate.trim() || week.endDate < week.startDate)
  ) {
    errors.endDate = '请完整填写每个周区间，且结束日期不能早于开始日期。';
  }

  if (!hasEntryVisual) {
    errors.coverImage = '请至少上传一张 Poster、Lineup 或 Cover 图片。';
  }

  if (draft.ticketUrl.trim() && !isValidUrl(draft.ticketUrl.trim())) {
    errors.ticketUrl = '请填写有效的购票链接。';
  }

  if (draft.socialLinksText.trim()) {
    try {
      JSON.parse(draft.socialLinksText);
    } catch {
      errors.socialLinks = 'Social Links JSON must be valid JSON.';
    }
  }

  const invalidTier = draft.ticketTiers.some((tier) => {
    const hasName = tier.name.trim().length > 0;
    const hasPrice = tier.price.trim().length > 0;
    if (!hasName && !hasPrice) return false;
    const numericPrice = Number(tier.price);
    if (hasName && !hasPrice) return true;
    return hasPrice && !Number.isFinite(numericPrice);
  });

  if (invalidTier) {
    errors.ticketTiers = '票档名称可以为空；如果填写了名称就必须同时填写价格，且价格必须是有效数字。';
  }

  const invalidSlot = draft.timetableSlots.some((slot) => {
    const hasAnyValue = [
      slot.memberNamesText,
      slot.djId,
      slot.actType,
      slot.stageName,
      slot.startTime,
      slot.endTime,
    ].some((value) => String(value || '').trim().length > 0);
    if (!hasAnyValue) return false;

    const hasIdentity = slot.memberNamesText.trim().length > 0 || slot.djId.trim().length > 0;
    const hasStage = slot.stageName.trim().length > 0;
    const hasEventDayId = slot.eventDayId.trim().length > 0;
    const hasLocalDate = slot.localDate.trim().length > 0;
    const hasStart = /^\d{2}:\d{2}$/.test(slot.startTime.trim());
    const hasEnd = /^\d{2}:\d{2}$/.test(slot.endTime.trim());
    const actType = slot.actType || 'solo';
    const expectedCount = expectedPerformersByActType[actType];
    const performerNames = slot.memberNamesText
      .split(/[\/,&]/)
      .map((item) => item.trim())
      .filter(Boolean);
    return (
      !hasIdentity ||
      !hasStage ||
      !hasEventDayId ||
      !hasLocalDate ||
      !hasStart ||
      !hasEnd ||
      performerNames.length < expectedCount
    );
  });

  if (invalidSlot) {
    errors.timetableSlots = '时间表条目需要完整填写演出人、eventDay、舞台、开始时间和结束时间。';
  }

  return errors;
};
