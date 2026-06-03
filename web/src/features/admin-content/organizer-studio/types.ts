export type OrganizerStudioLocalizedText = {
  zh: string;
  en: string;
  ja: string;
  enFull: string;
};

export type OrganizerStudioImageUsage = 'avatar' | 'background' | 'proof';

export type OrganizerStudioImageState = {
  remoteUrl: string;
  fileName: string;
  usage: OrganizerStudioImageUsage;
  origin: 'draft-upload' | 'persisted';
};

export type OrganizerStudioExtraLinkDraft = {
  id: string;
  title: string;
  icon: string;
  url: string;
};

export type OrganizerStudioDraft = {
  id: string;
  name: OrganizerStudioLocalizedText;
  abbreviation: string;
  aliasesText: string;
  country: OrganizerStudioLocalizedText;
  city: OrganizerStudioLocalizedText;
  foundedYear: string;
  frequency: string;
  tagline: string;
  introduction: OrganizerStudioLocalizedText;
  officialWebsite: string;
  instagram: string;
  facebook: string;
  twitter: string;
  youtube: string;
  tiktok: string;
  extraLinks: OrganizerStudioExtraLinkDraft[];
  avatarImage: OrganizerStudioImageState | null;
  backgroundImage: OrganizerStudioImageState | null;
  proofImages: OrganizerStudioImageState[];
  baseBrandRevision: number | null;
  rightsConfirmed: boolean;
  identityConfirmed: boolean;
};

export type OrganizerStudioValidationErrors = Partial<Record<
  'name' | 'avatarImage' | 'links' | 'review',
  string
>>;

export type OrganizerStudioLinkPayload = {
  title: string;
  icon: string;
  url: string;
};

export type OrganizerStudioSubmissionSummary = {
  id: string;
  entityType: string;
  status: string;
  title: string;
  createdEntityId?: string | null;
};

export type OrganizerStudioSubmissionAcceptedPayload = {
  status?: string | null;
  message: string;
  submission: OrganizerStudioSubmissionSummary;
};

export type OrganizerStudioCreatedOrganizer = {
  id: string;
  name: string;
  city?: string | null;
  country?: string | null;
  revision?: number | null;
};

export type OrganizerStudioCreateResult =
  | { kind: 'created'; organizer: OrganizerStudioCreatedOrganizer }
  | { kind: 'submitted'; payload: OrganizerStudioSubmissionAcceptedPayload };

export type OrganizerStudioLoadedOrganizer = {
  id: string;
  name: string;
  nameI18n?: OrganizerStudioLocalizedText | null;
  revision?: number | null;
  abbreviation?: string | null;
  aliases?: string[] | null;
  country?: string | null;
  countryI18n?: OrganizerStudioLocalizedText | null;
  city?: string | null;
  cityI18n?: OrganizerStudioLocalizedText | null;
  foundedYear?: string | null;
  frequency?: string | null;
  frequencyI18n?: OrganizerStudioLocalizedText | null;
  tagline?: string | null;
  introduction?: string | null;
  descriptionI18n?: OrganizerStudioLocalizedText | null;
  officialWebsite?: string | null;
  facebookUrl?: string | null;
  instagramUrl?: string | null;
  twitterUrl?: string | null;
  youtubeUrl?: string | null;
  tiktokUrl?: string | null;
  avatarUrl?: string | null;
  backgroundUrl?: string | null;
  imageAssets?: Array<{
    url: string;
    type?: string | null;
    label?: string | null;
    sort?: number | null;
    order?: number | null;
    source?: string | null;
    fileName?: string | null;
  }> | null;
  links?: OrganizerStudioLinkPayload[] | null;
  contributors?: Array<{
    id: string;
    username: string;
    displayName?: string | null;
    avatarUrl?: string | null;
  }> | null;
  canEdit?: boolean | null;
};

export type OrganizerStudioPagination = {
  page: number;
  limit: number;
  total: number;
  totalPages: number;
};

export type OrganizerStudioRelatedEvent = {
  id: string;
  name: string;
  nameI18n?: OrganizerStudioLocalizedText | null;
  slug?: string | null;
  city?: string | null;
  country?: string | null;
  coverImageUrl?: string | null;
  cardImageUrl?: string | null;
  eventType?: string | null;
  status?: string | null;
  startDate?: string | null;
  endDate?: string | null;
  timeZone?: string | null;
  organizerName?: string | null;
};

export type OrganizerStudioRelatedArticle = {
  id: string;
  title: string;
  summary?: string | null;
  source?: string | null;
  category?: string | null;
  publishedAt?: string | null;
  coverImageURL?: string | null;
  coverImageUrl?: string | null;
};

export type OrganizerStudioRelatedPage<T> = {
  items: T[];
  pagination: OrganizerStudioPagination;
};

export type OrganizerStudioEventFeed = {
  upcoming: OrganizerStudioRelatedPage<OrganizerStudioRelatedEvent>;
  ended: OrganizerStudioRelatedPage<OrganizerStudioRelatedEvent>;
};

export type OrganizerStudioCreateInput = {
  name: string;
  nameI18n?: OrganizerStudioLocalizedText | null;
  abbreviation?: string | null;
  aliases?: string[] | null;
  country?: string | null;
  countryI18n?: OrganizerStudioLocalizedText | null;
  city?: string | null;
  cityI18n?: OrganizerStudioLocalizedText | null;
  foundedYear?: string | null;
  frequency?: string | null;
  tagline?: string | null;
  introduction?: string | null;
  descriptionI18n?: OrganizerStudioLocalizedText | null;
  officialWebsite?: string | null;
  facebookUrl?: string | null;
  instagramUrl?: string | null;
  twitterUrl?: string | null;
  youtubeUrl?: string | null;
  tiktokUrl?: string | null;
  avatarUrl?: string | null;
  backgroundUrl?: string | null;
  proofImageUrl?: string | null;
  imageAssets?: Array<{
    url: string;
    type: string;
    label: string;
    sort: number;
    order: number;
    source: string;
    fileName?: string | null;
  }> | null;
  rightsConfirmed: boolean;
  identityConfirmed: boolean;
  links?: OrganizerStudioLinkPayload[] | null;
};

export type OrganizerStudioUpdateInput = OrganizerStudioCreateInput & {
  baseBrandRevision?: number | null;
};
