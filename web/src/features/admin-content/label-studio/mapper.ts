import { LabelStudioCreateInput, LabelStudioDraft } from './types';

const parseTextList = (value: string): string[] =>
  value
    .split(/[\n,]/)
    .map((item) => item.trim())
    .filter(Boolean);

const parseOptionalNumber = (value: string): number | null => {
  const trimmed = value.trim();
  if (!trimmed) return null;
  const parsed = Number(trimmed);
  return Number.isFinite(parsed) ? parsed : null;
};

export const mapLabelStudioDraftToCreateInput = (
  draft: LabelStudioDraft
): LabelStudioCreateInput => ({
  name: draft.name.trim(),
  slug: draft.slug.trim() || null,
  profileUrl: draft.profileUrl.trim() || null,
  profileSlug: draft.profileSlug.trim() || null,
  nation: draft.nation.trim() || null,
  founderName: draft.founderName.trim() || null,
  foundedAt: draft.foundedAt.trim() || null,
  founderDjId: draft.founderDjId.trim() || null,
  genres: parseTextList(draft.genresText),
  genresPreview: draft.genresPreview.trim() || null,
  latestReleaseListing: draft.latestReleaseListing.trim() || null,
  locationPeriod: draft.locationPeriod.trim() || null,
  introductionPreview: draft.introductionPreview.trim() || null,
  introduction: draft.introduction.trim() || null,
  generalContactEmail: draft.generalContactEmail.trim() || null,
  demoSubmissionUrl: draft.demoSubmissionUrl.trim() || null,
  demoSubmissionDisplay: draft.demoSubmissionDisplay.trim() || null,
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
