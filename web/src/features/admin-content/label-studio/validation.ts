import { LabelStudioDraft, LabelStudioValidationErrors } from './types';

export const validateLabelStudioDraft = (
  draft: LabelStudioDraft
): LabelStudioValidationErrors => {
  const errors: LabelStudioValidationErrors = {};
  if (!draft.name.trim()) {
    errors.name = '请填写厂牌名称';
  }
  return errors;
};
