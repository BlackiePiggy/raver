import { OrganizerStudioDraft, OrganizerStudioValidationErrors } from './types';
import { INPUT_LIMITS, countText } from '@/lib/input-rules';

const firstFilledText = (...values: Array<string | undefined | null>): string => {
  for (const value of values) {
    const trimmed = String(value || '').trim();
    if (trimmed) return trimmed;
  }
  return '';
};

const hasAnyLink = (draft: OrganizerStudioDraft): boolean => {
  const directLinks = [
    draft.officialWebsite,
    draft.instagram,
    draft.facebook,
    draft.twitter,
    draft.youtube,
    draft.tiktok,
  ];
  return (
    directLinks.some((item) => item.trim().length > 0) ||
    draft.extraLinks.some((item) => item.url.trim().length > 0)
  );
};

const hasInvalidLink = (draft: OrganizerStudioDraft): boolean => {
  const directLinks = [
    draft.officialWebsite,
    draft.instagram,
    draft.facebook,
    draft.twitter,
    draft.youtube,
    draft.tiktok,
    ...draft.extraLinks.map((item) => item.url),
  ];

  return directLinks.some((item) => {
    const trimmed = item.trim();
    if (!trimmed) return false;
    try {
      new URL(trimmed);
      return false;
    } catch {
      return true;
    }
  });
};

export const validateOrganizerStudioDraft = (
  draft: OrganizerStudioDraft
): OrganizerStudioValidationErrors => {
  const errors: OrganizerStudioValidationErrors = {};
  const name = firstFilledText(draft.name.zh, draft.name.en, draft.name.ja, draft.name.enFull);
  const country = firstFilledText(draft.country.zh, draft.country.en, draft.country.ja, draft.country.enFull);
  const city = firstFilledText(draft.city.zh, draft.city.en, draft.city.ja, draft.city.enFull);
  const introduction = firstFilledText(draft.introduction.zh, draft.introduction.en, draft.introduction.ja, draft.introduction.enFull);

  if (!name) {
    errors.name = '请至少填写一个主办方名称';
  } else if (countText(name) > INPUT_LIMITS.organizer.name) {
    errors.name = `主办方名称不能超过 ${INPUT_LIMITS.organizer.name} 个字符`;
  }

  if (!draft.avatarImage?.remoteUrl.trim()) {
    errors.avatarImage = '请上传主办方头像';
  }

  if (draft.abbreviation.trim() && countText(draft.abbreviation) > INPUT_LIMITS.organizer.abbreviation) {
    errors.name = errors.name || `简称不能超过 ${INPUT_LIMITS.organizer.abbreviation} 个字符`;
  }

  if (draft.aliases.length > INPUT_LIMITS.organizer.aliasesMaxItems) {
    errors.name = errors.name || `别名最多填写 ${INPUT_LIMITS.organizer.aliasesMaxItems} 项`;
  }

  if (draft.aliases.some((item) => countText(item) > INPUT_LIMITS.organizer.alias)) {
    errors.name = errors.name || `别名单项不能超过 ${INPUT_LIMITS.organizer.alias} 个字符`;
  }

  if (country && countText(country) > INPUT_LIMITS.organizer.country) {
    errors.name = errors.name || `国家不能超过 ${INPUT_LIMITS.organizer.country} 个字符`;
  }

  if (city && countText(city) > INPUT_LIMITS.organizer.city) {
    errors.name = errors.name || `城市不能超过 ${INPUT_LIMITS.organizer.city} 个字符`;
  }

  if (draft.foundedYear.trim() && countText(draft.foundedYear) > INPUT_LIMITS.organizer.foundedYear) {
    errors.name = errors.name || `成立年份不能超过 ${INPUT_LIMITS.organizer.foundedYear} 个字符`;
  }

  if (draft.frequency.trim() && countText(draft.frequency) > INPUT_LIMITS.organizer.frequency) {
    errors.name = errors.name || `举办频率不能超过 ${INPUT_LIMITS.organizer.frequency} 个字符`;
  }

  if (draft.tagline.trim() && countText(draft.tagline) > INPUT_LIMITS.organizer.tagline) {
    errors.name = errors.name || `一句话标签不能超过 ${INPUT_LIMITS.organizer.tagline} 个字符`;
  }

  if (introduction && countText(introduction, true) > INPUT_LIMITS.organizer.introduction) {
    errors.name = errors.name || `主办方介绍不能超过 ${INPUT_LIMITS.organizer.introduction} 个字符`;
  }

  if (draft.extraLinks.some((item) => item.title.trim() && countText(item.title) > INPUT_LIMITS.organizer.extraLinkTitle)) {
    errors.links = '额外链接标题过长，请控制在合理范围内';
  }

  if (!hasAnyLink(draft) && draft.proofImages.length === 0) {
    errors.links = '请至少填写一个官方链接，或上传一张证明图片';
  } else if (hasInvalidLink(draft)) {
    errors.links = '存在链接格式不正确，请检查后再提交';
  }

  if (!draft.rightsConfirmed || !draft.identityConfirmed) {
    errors.review = '请确认资料权利与身份声明';
  }

  return errors;
};
