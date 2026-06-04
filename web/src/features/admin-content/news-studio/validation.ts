import { NewsStudioDraft, NewsStudioValidationErrors } from './types';
import { INPUT_LIMITS, countText } from '@/lib/input-rules';

export const validateNewsStudioDraft = (
  draft: NewsStudioDraft
): NewsStudioValidationErrors => {
  const errors: NewsStudioValidationErrors = {};
  if (!draft.title.trim()) {
    errors.title = '请填写资讯标题。';
  } else if (countText(draft.title) > INPUT_LIMITS.news.title) {
    errors.title = `资讯标题不能超过 ${INPUT_LIMITS.news.title} 个字符。`;
  }
  if (!draft.body.trim()) {
    errors.body = '请填写正文内容。';
  } else if (countText(draft.body, true) > INPUT_LIMITS.news.body) {
    errors.body = `正文内容不能超过 ${INPUT_LIMITS.news.body} 个字符。`;
  }
  if (draft.summary.trim() && countText(draft.summary, true) > INPUT_LIMITS.news.summary) {
    errors.title = errors.title || `摘要不能超过 ${INPUT_LIMITS.news.summary} 个字符。`;
  }
  if (draft.source.trim() && countText(draft.source) > INPUT_LIMITS.news.source) {
    errors.title = errors.title || `来源不能超过 ${INPUT_LIMITS.news.source} 个字符。`;
  }
  return errors;
};
