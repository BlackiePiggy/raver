export const INPUT_LIMITS = {
  common: {
    url: 2000,
    externalId: 120,
    currency: 16,
    linkTitle: 60,
    linkIcon: 40,
    ticketTierName: 80,
    stageName: 120,
  },
  user: {
    username: { min: 3, max: 24 },
    displayName: { min: 2, max: 24 },
    bio: 300,
    location: 60,
    passwordMin: 6,
  },
  dj: {
    name: 120,
    bio: 2000,
    country: 80,
    alias: 80,
    aliasesMaxItems: 20,
    genre: 40,
    genresMaxItems: 20,
  },
  event: {
    name: 120,
    abbreviation: 32,
    organizerName: 120,
    venueName: 120,
    venueAddress: 200,
    description: 4000,
    city: 80,
    country: 80,
    detailAddress: 200,
    sourceProvider: 80,
    referenceLinksText: 4000,
    socialLinksText: 4000,
    ticketNotes: 1000,
  },
  organizer: {
    name: 120,
    abbreviation: 40,
    alias: 80,
    country: 80,
    city: 80,
    foundedYear: 20,
    frequency: 80,
    tagline: 160,
    introduction: 4000,
    extraLinkTitle: 60,
  },
  news: {
    title: 140,
    summary: 300,
    body: 20000,
    source: 80,
  },
  label: {
    name: 120,
    slug: 80,
    profileSlug: 80,
    nation: 80,
    founderName: 120,
    foundedAt: 40,
    genre: 40,
    genresPreview: 160,
    latestReleaseListing: 160,
    locationPeriod: 120,
    introductionPreview: 300,
    introduction: 4000,
    demoSubmissionDisplay: 80,
  },
} as const;

export const USERNAME_PATTERN = /^[a-z0-9._]+$/;

const SINGLE_LINE_CONTROL_REGEX = /[\u0000-\u001f\u007f]+/g;
const MULTI_LINE_CONTROL_REGEX = /[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]+/g;

export const normalizeSingleLine = (value: unknown): string =>
  String(value || '')
    .replace(SINGLE_LINE_CONTROL_REGEX, ' ')
    .trim()
    .replace(/\s+/g, ' ');

export const normalizeSingleLineLowercase = (value: unknown): string =>
  normalizeSingleLine(value).toLowerCase();

export const normalizeMultiline = (value: unknown): string =>
  String(value || '')
    .replace(/\r\n?/g, '\n')
    .replace(MULTI_LINE_CONTROL_REGEX, '')
    .trim();

export const normalizeOptionalSingleLine = (value: unknown, max: number): string | null => {
  const normalized = normalizeSingleLine(value).slice(0, max);
  return normalized || null;
};

export const normalizeOptionalMultiline = (value: unknown, max: number): string | null => {
  const normalized = normalizeMultiline(value).slice(0, max);
  return normalized || null;
};

export const normalizeStringArray = (value: unknown, options?: { itemMax?: number; maxItems?: number }): string[] => {
  const rawItems = Array.isArray(value)
    ? value
    : typeof value === 'string'
      ? value.split(/[\n,/\u3001\uff0c]/g)
      : [];

  const normalized = Array.from(
    new Set(
      rawItems
        .map((item) => normalizeSingleLine(item))
        .map((item) => (options?.itemMax ? item.slice(0, options.itemMax) : item))
        .filter(Boolean)
    )
  );
  return typeof options?.maxItems === 'number' ? normalized.slice(0, options.maxItems) : normalized;
};

export const validateUsername = (value: unknown): string | null => {
  const normalized = normalizeSingleLineLowercase(value);
  if (!normalized) return 'Username is required';
  if (normalized.length < INPUT_LIMITS.user.username.min || normalized.length > INPUT_LIMITS.user.username.max) {
    return `Username must be ${INPUT_LIMITS.user.username.min}-${INPUT_LIMITS.user.username.max} characters`;
  }
  if (!USERNAME_PATTERN.test(normalized)) {
    return 'Username may only contain lowercase letters, numbers, dots, and underscores';
  }
  return null;
};

export const validateDisplayName = (value: unknown): string | null => {
  const normalized = normalizeSingleLine(value);
  if (!normalized) return '昵称不能为空';
  if (normalized.length < INPUT_LIMITS.user.displayName.min || normalized.length > INPUT_LIMITS.user.displayName.max) {
    return `昵称需为 ${INPUT_LIMITS.user.displayName.min}-${INPUT_LIMITS.user.displayName.max} 个字符`;
  }
  return null;
};

export const validateMaxLength = (value: unknown, max: number, label: string, multiline = false): string | null => {
  const normalized = multiline ? normalizeMultiline(value) : normalizeSingleLine(value);
  if (normalized.length > max) {
    return `${label}不能超过 ${max} 个字符`;
  }
  return null;
};
