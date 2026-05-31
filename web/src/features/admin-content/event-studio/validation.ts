import { EventStudioDraft, EventStudioValidationErrors } from './types';

const firstFilledText = (...values: Array<string | undefined | null>): string => {
  for (const value of values) {
    const trimmed = String(value || '').trim();
    if (trimmed) return trimmed;
  }
  return '';
};

export const validateEventStudioDraft = (draft: EventStudioDraft): EventStudioValidationErrors => {
  const errors: EventStudioValidationErrors = {};
  const hasEntryVisual =
    draft.imageZones.poster.some((item) => item.remoteUrl.trim()) ||
    draft.imageZones.lineup.some((item) => item.remoteUrl.trim()) ||
    draft.imageZones.cover.some((item) => item.remoteUrl.trim());

  if (!firstFilledText(draft.name.zh, draft.name.en, draft.name.ja, draft.name.enFull)) {
    errors.name = '请至少填写一个活动名称';
  }

  if (!firstFilledText(draft.city.zh, draft.city.en, draft.city.ja, draft.city.enFull)) {
    errors.city = '请填写活动城市';
  }

  if (!firstFilledText(draft.country.zh, draft.country.en, draft.country.ja, draft.country.enFull)) {
    errors.country = '请填写活动国家';
  }

  if (!firstFilledText(draft.detailAddress.zh, draft.detailAddress.en, draft.detailAddress.ja, draft.detailAddress.enFull)) {
    errors.detailAddress = '请填写详细地址';
  }

  if (!draft.startDate.trim()) {
    errors.startDate = '请选择开始日期';
  }

  if (!draft.endDate.trim()) {
    errors.endDate = '请选择结束日期';
  }

  if (draft.startDate && draft.endDate && draft.endDate < draft.startDate) {
    errors.endDate = '结束日期不能早于开始日期';
  }

  if (draft.scheduleMode === 'single_day' && draft.startDate && draft.endDate && draft.startDate !== draft.endDate) {
    errors.endDate = '单日活动的开始和结束日期必须相同';
  }

  if (draft.scheduleMode === 'single_day' && (!draft.startDate.trim() || !draft.endDate.trim())) {
    errors.startDate = errors.startDate || '请选择活动日期';
  }

  if (!draft.timeZoneSelection?.timezone?.trim()) {
    errors.timeZone = '请从候选列表中确认活动时区';
  }

  if (draft.scheduleMode === 'multi_week' && draft.weeks.length < 2) {
    errors.endDate = '多周活动至少需要覆盖 2 个 week';
  }

  if (
    draft.scheduleMode === 'multi_week' &&
    draft.weeks.some((week) => !week.startDate.trim() || !week.endDate.trim() || week.endDate < week.startDate)
  ) {
    errors.endDate = '请完整填写每个周次的开始和结束日期，且结束日期不能早于开始日期';
  }

  if (!hasEntryVisual) {
    errors.coverImage = '请至少上传 1 张 Poster、Lineup 或 Cover 图片';
  }

  const invalidTier = draft.ticketTiers.some((tier) => {
    const hasName = tier.name.trim().length > 0;
    const hasPrice = tier.price.trim().length > 0;
    if (!hasName && !hasPrice) return false;
    const numericPrice = Number(tier.price);
    return !hasName || !Number.isFinite(numericPrice);
  });

  if (invalidTier) {
    errors.ticketTiers = '票档需要同时填写名称和有效价格';
  }

  const invalidSlot = draft.timetableSlots.some((slot) => {
    const hasAnyValue = [
      slot.memberNamesText,
      slot.djId,
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
    return !hasIdentity || !hasStage || !hasEventDayId || !hasLocalDate || !hasStart || !hasEnd;
  });

  if (invalidSlot) {
    errors.timetableSlots = '时间表条目需要完整填写演出人、eventDay、舞台、开始时间和结束时间';
  }

  return errors;
};
