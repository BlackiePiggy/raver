import { NewsStudioDraft, NewsStudioValidationErrors } from './types';

export const validateNewsStudioDraft = (
  draft: NewsStudioDraft
): NewsStudioValidationErrors => {
  const errors: NewsStudioValidationErrors = {};
  if (!draft.title.trim()) {
    errors.title = '请填写资讯标题。';
  }
  if (!draft.body.trim()) {
    errors.body = '请填写正文内容。';
  }
  return errors;
};
