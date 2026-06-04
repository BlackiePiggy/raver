import { LabelStudioDraft, LabelStudioValidationErrors } from './types';
import { INPUT_LIMITS, countText } from '@/lib/input-rules';

export const validateLabelStudioDraft = (
  draft: LabelStudioDraft
): LabelStudioValidationErrors => {
  const errors: LabelStudioValidationErrors = {};
  if (!draft.name.trim()) {
    errors.name = '请填写厂牌名称';
  } else if (countText(draft.name) > INPUT_LIMITS.label.name) {
    errors.name = `厂牌名称不能超过 ${INPUT_LIMITS.label.name} 个字符`;
  }
  if (draft.slug.trim() && countText(draft.slug) > INPUT_LIMITS.label.slug) {
    errors.name = errors.name || `Slug 不能超过 ${INPUT_LIMITS.label.slug} 个字符`;
  }
  if (draft.profileSlug.trim() && countText(draft.profileSlug) > INPUT_LIMITS.label.profileSlug) {
    errors.name = errors.name || `Profile Slug 不能超过 ${INPUT_LIMITS.label.profileSlug} 个字符`;
  }
  if (draft.nation.trim() && countText(draft.nation) > INPUT_LIMITS.label.nation) {
    errors.name = errors.name || `国家/地区不能超过 ${INPUT_LIMITS.label.nation} 个字符`;
  }
  if (draft.founderName.trim() && countText(draft.founderName) > INPUT_LIMITS.label.founderName) {
    errors.name = errors.name || `创始人名称不能超过 ${INPUT_LIMITS.label.founderName} 个字符`;
  }
  if (draft.foundedAt.trim() && countText(draft.foundedAt) > INPUT_LIMITS.label.foundedAt) {
    errors.name = errors.name || `成立时间不能超过 ${INPUT_LIMITS.label.foundedAt} 个字符`;
  }
  if (draft.genresText.trim() && countText(draft.genresText) > INPUT_LIMITS.label.genre * 10) {
    errors.name = errors.name || '风格标签内容过长，请精简后再提交';
  }
  if (draft.genresPreview.trim() && countText(draft.genresPreview) > INPUT_LIMITS.label.genresPreview) {
    errors.name = errors.name || `Genres Preview 不能超过 ${INPUT_LIMITS.label.genresPreview} 个字符`;
  }
  if (draft.latestReleaseListing.trim() && countText(draft.latestReleaseListing) > INPUT_LIMITS.label.latestReleaseListing) {
    errors.name = errors.name || `Latest Release 不能超过 ${INPUT_LIMITS.label.latestReleaseListing} 个字符`;
  }
  if (draft.locationPeriod.trim() && countText(draft.locationPeriod) > INPUT_LIMITS.label.locationPeriod) {
    errors.name = errors.name || `Location Period 不能超过 ${INPUT_LIMITS.label.locationPeriod} 个字符`;
  }
  if (draft.introductionPreview.trim() && countText(draft.introductionPreview, true) > INPUT_LIMITS.label.introductionPreview) {
    errors.name = errors.name || `Introduction Preview 不能超过 ${INPUT_LIMITS.label.introductionPreview} 个字符`;
  }
  if (draft.introduction.trim() && countText(draft.introduction, true) > INPUT_LIMITS.label.introduction) {
    errors.name = errors.name || `Introduction 不能超过 ${INPUT_LIMITS.label.introduction} 个字符`;
  }
  if (draft.demoSubmissionDisplay.trim() && countText(draft.demoSubmissionDisplay) > INPUT_LIMITS.label.demoSubmissionDisplay) {
    errors.name = errors.name || `Demo Submission Display 不能超过 ${INPUT_LIMITS.label.demoSubmissionDisplay} 个字符`;
  }
  return errors;
};
