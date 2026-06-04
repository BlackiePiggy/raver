import { OrganizerStudioDraft, OrganizerStudioValidationErrors } from './types';

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

  if (!firstFilledText(draft.name.zh, draft.name.en, draft.name.ja, draft.name.enFull)) {
    errors.name = '请至少填写一个主办方名称';
  }

  if (!draft.avatarImage?.remoteUrl.trim()) {
    errors.avatarImage = '请上传主办方头像';
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
