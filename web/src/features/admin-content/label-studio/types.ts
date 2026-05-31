export type LabelStudioDraft = {
  id: string;
  name: string;
  slug: string;
  profileUrl: string;
  profileSlug: string;
  nation: string;
  founderName: string;
  foundedAt: string;
  founderDjId: string;
  genresText: string;
  genresPreview: string;
  latestReleaseListing: string;
  locationPeriod: string;
  introductionPreview: string;
  introduction: string;
  generalContactEmail: string;
  demoSubmissionUrl: string;
  demoSubmissionDisplay: string;
  officialWebsiteUrl: string;
  facebookUrl: string;
  soundcloudUrl: string;
  musicPurchaseUrl: string;
  logoUrl: string;
  avatarUrl: string;
  backgroundUrl: string;
  soundcloudFollowers: string;
  likes: string;
};

export type LabelStudioValidationErrors = Partial<Record<'name', string>>;

export type LabelStudioLoadedLabel = {
  id: string;
  name: string;
  slug: string;
  profileUrl: string;
  profileSlug: string | null;
  logoUrl: string | null;
  avatarUrl: string | null;
  backgroundUrl: string | null;
  nation: string | null;
  soundcloudFollowers: number | null;
  likes: number | null;
  genres: string[];
  genresPreview: string | null;
  latestReleaseListing: string | null;
  locationPeriod: string | null;
  introductionPreview: string | null;
  introduction: string | null;
  generalContactEmail: string | null;
  demoSubmissionUrl: string | null;
  demoSubmissionDisplay: string | null;
  facebookUrl: string | null;
  soundcloudUrl: string | null;
  musicPurchaseUrl: string | null;
  officialWebsiteUrl: string | null;
  founderName: string | null;
  foundedAt: string | null;
  founderDjId: string | null;
};

export type LabelStudioCreateInput = {
  name: string;
  slug?: string | null;
  profileUrl?: string | null;
  profileSlug?: string | null;
  nation?: string | null;
  founderName?: string | null;
  foundedAt?: string | null;
  founderDjId?: string | null;
  genres?: string[];
  genresPreview?: string | null;
  latestReleaseListing?: string | null;
  locationPeriod?: string | null;
  introductionPreview?: string | null;
  introduction?: string | null;
  generalContactEmail?: string | null;
  demoSubmissionUrl?: string | null;
  demoSubmissionDisplay?: string | null;
  officialWebsiteUrl?: string | null;
  facebookUrl?: string | null;
  soundcloudUrl?: string | null;
  musicPurchaseUrl?: string | null;
  logoUrl?: string | null;
  avatarUrl?: string | null;
  backgroundUrl?: string | null;
  soundcloudFollowers?: number | null;
  likes?: number | null;
};

export type LabelStudioCreatedLabel = {
  id: string;
  name: string;
  slug: string;
};

export type LabelStudioCreateResult = {
  kind: 'created';
  label: LabelStudioCreatedLabel;
};

export type LabelStudioListResponse = {
  items: LabelStudioLoadedLabel[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
};
