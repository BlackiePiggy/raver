import { LabelStudioCreateInput, LabelStudioDraft } from './types';
import { INPUT_LIMITS, normalizeMultiline, normalizeSingleLine, trimArrayItems } from '@/lib/input-rules';

const normalizeStringArray = (value: string[]): string[] =>
  trimArrayItems(value, INPUT_LIMITS.label.genre).slice(0, INPUT_LIMITS.label.genresMaxItems);

const parseOptionalNumber = (value: string): number | null => {
  const trimmed = value.trim();
  if (!trimmed) return null;
  const parsed = Number(trimmed);
  return Number.isFinite(parsed) ? parsed : null;
};

export const mapLabelStudioDraftToCreateInput = (
  draft: LabelStudioDraft
): LabelStudioCreateInput => ({
  name: normalizeSingleLine(draft.name).slice(0, INPUT_LIMITS.label.name),
  slug: normalizeSingleLine(draft.slug).slice(0, INPUT_LIMITS.label.slug) || null,
  profileUrl: draft.profileUrl.trim() || null,
  profileSlug: normalizeSingleLine(draft.profileSlug).slice(0, INPUT_LIMITS.label.profileSlug) || null,
  nation: normalizeSingleLine(draft.nation).slice(0, INPUT_LIMITS.label.nation) || null,
  founderName: normalizeSingleLine(draft.founderName).slice(0, INPUT_LIMITS.label.founderName) || null,
  foundedAt: normalizeSingleLine(draft.foundedAt).slice(0, INPUT_LIMITS.label.foundedAt) || null,
  founderDjId: draft.founderDjId.trim() || null,
  genres: normalizeStringArray(draft.genres),
  genresPreview: normalizeSingleLine(draft.genresPreview).slice(0, INPUT_LIMITS.label.genresPreview) || null,
  latestReleaseListing: normalizeSingleLine(draft.latestReleaseListing).slice(0, INPUT_LIMITS.label.latestReleaseListing) || null,
  locationPeriod: normalizeSingleLine(draft.locationPeriod).slice(0, INPUT_LIMITS.label.locationPeriod) || null,
  introductionPreview: normalizeMultiline(draft.introductionPreview).slice(0, INPUT_LIMITS.label.introductionPreview) || null,
  introduction: normalizeMultiline(draft.introduction).slice(0, INPUT_LIMITS.label.introduction) || null,
  generalContactEmail: draft.generalContactEmail.trim() || null,
  demoSubmissionUrl: draft.demoSubmissionUrl.trim() || null,
  demoSubmissionDisplay: normalizeSingleLine(draft.demoSubmissionDisplay).slice(0, INPUT_LIMITS.label.demoSubmissionDisplay) || null,
  officialWebsiteUrl: draft.officialWebsiteUrl.trim() || null,
  facebookUrl: draft.facebookUrl.trim() || null,
  soundcloudUrl: draft.soundcloudUrl.trim() || null,
  musicPurchaseUrl: draft.musicPurchaseUrl.trim() || null,
  logoUrl: draft.logoUrl.trim() || null,
  avatarUrl: draft.avatarUrl.trim() || null,
  backgroundUrl: draft.backgroundUrl.trim() || null,
  soundcloudFollowers: parseOptionalNumber(draft.soundcloudFollowers),
  likes: parseOptionalNumber(draft.likes),
});
