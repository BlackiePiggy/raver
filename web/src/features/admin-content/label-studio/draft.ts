import { createEmptyFounderDraftItem, hydrateFounderDraftItems } from './founders';
import { LabelStudioDraft, LabelStudioLoadedLabel } from './types';

const fromNullable = (value?: string | null): string => value || '';

export const createLabelStudioDraft = (): LabelStudioDraft => ({
  id: crypto.randomUUID(),
  name: '',
  slug: '',
  profileUrl: '',
  profileSlug: '',
  nation: '',
  foundedAt: '',
  founders: [],
  genres: [''],
  genresPreview: '',
  latestReleaseListing: '',
  locationPeriod: '',
  introductionPreview: '',
  introduction: '',
  generalContactEmail: '',
  demoSubmissionUrl: '',
  demoSubmissionDisplay: '',
  officialWebsiteUrl: '',
  facebookUrl: '',
  soundcloudUrl: '',
  musicPurchaseUrl: '',
  logoUrl: '',
  avatarUrl: '',
  backgroundUrl: '',
  soundcloudFollowers: '',
  likes: '',
});

export const hydrateLabelStudioDraftFromLabel = (
  label: LabelStudioLoadedLabel
): LabelStudioDraft => ({
  id: label.id,
  name: label.name || '',
  slug: label.slug || '',
  profileUrl: label.profileUrl || '',
  profileSlug: label.profileSlug || '',
  nation: fromNullable(label.nation),
  foundedAt: fromNullable(label.foundedAt),
  founders: Array.isArray(label.founders) && label.founders.length
    ? hydrateFounderDraftItems(label.founders)
    : [createEmptyFounderDraftItem()],
  genres: (label.genres || []).length ? [...(label.genres || [])] : [''],
  genresPreview: fromNullable(label.genresPreview),
  latestReleaseListing: fromNullable(label.latestReleaseListing),
  locationPeriod: fromNullable(label.locationPeriod),
  introductionPreview: fromNullable(label.introductionPreview),
  introduction: fromNullable(label.introduction),
  generalContactEmail: fromNullable(label.generalContactEmail),
  demoSubmissionUrl: fromNullable(label.demoSubmissionUrl),
  demoSubmissionDisplay: fromNullable(label.demoSubmissionDisplay),
  officialWebsiteUrl: fromNullable(label.officialWebsiteUrl),
  facebookUrl: fromNullable(label.facebookUrl),
  soundcloudUrl: fromNullable(label.soundcloudUrl),
  musicPurchaseUrl: fromNullable(label.musicPurchaseUrl),
  logoUrl: fromNullable(label.logoUrl),
  avatarUrl: fromNullable(label.avatarUrl),
  backgroundUrl: fromNullable(label.backgroundUrl),
  soundcloudFollowers: label.soundcloudFollowers == null ? '' : String(label.soundcloudFollowers),
  likes: label.likes == null ? '' : String(label.likes),
});
