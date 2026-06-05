import {
  OrganizerStudioDraft,
  OrganizerStudioExtraLinkDraft,
  OrganizerStudioLoadedOrganizer,
  OrganizerStudioLocalizedText,
} from './types';

const emptyLocalizedText = (initialValue = ''): OrganizerStudioLocalizedText => ({
  zh: initialValue,
  en: '',
  ja: '',
  enFull: '',
});

export const createEmptyOrganizerExtraLinkDraft = (): OrganizerStudioExtraLinkDraft => ({
  id: crypto.randomUUID(),
  title: '',
  icon: 'link',
  url: '',
});

export const createOrganizerStudioDraft = (initialName = ''): OrganizerStudioDraft => ({
  id: crypto.randomUUID(),
  name: emptyLocalizedText(initialName),
  abbreviation: '',
  aliases: [''],
  country: emptyLocalizedText(),
  city: emptyLocalizedText(),
  foundedYear: '',
  frequency: '',
  tagline: '',
  introduction: emptyLocalizedText(),
  officialWebsite: '',
  instagram: '',
  facebook: '',
  twitter: '',
  youtube: '',
  tiktok: '',
  extraLinks: [],
  avatarImage: null,
  backgroundImage: null,
  proofImages: [],
  baseBrandRevision: null,
  rightsConfirmed: false,
  identityConfirmed: false,
});

const fromNullableLocalizedText = (
  value?: OrganizerStudioLocalizedText | null,
  fallback?: string | null
): OrganizerStudioLocalizedText => ({
  zh: value?.zh ?? String(fallback || ''),
  en: value?.en ?? '',
  ja: value?.ja ?? '',
  enFull: value?.enFull ?? '',
});

const normalizeUrl = (value?: string | null): string => String(value || '').trim();

const normalizeStringArray = (value?: Array<string | null> | null): string[] =>
  Array.isArray(value)
    ? value
        .map((item) => String(item || '').trim())
        .filter(Boolean)
    : [];

const normalizeLinks = (
  value?: Array<{ title?: string | null; icon?: string | null; url?: string | null }> | null
): Array<{ title: string; icon: string; url: string }> =>
  Array.isArray(value)
    ? value.map((item) => ({
        title: String(item?.title || '').trim(),
        icon: String(item?.icon || 'link').trim() || 'link',
        url: String(item?.url || '').trim(),
      }))
    : [];

export const hydrateOrganizerStudioDraftFromOrganizer = (
  organizer: OrganizerStudioLoadedOrganizer
): OrganizerStudioDraft => {
  const aliases = normalizeStringArray(organizer.aliases);
  const links = normalizeLinks(organizer.links);
  const imageAssets = Array.isArray(organizer.imageAssets) ? organizer.imageAssets : [];

  const avatarImageFromAssets = imageAssets.find((item) => {
    const normalizedType = String(item.type || '').toLowerCase();
    return normalizedType === 'avatar';
  });
  const backgroundImageFromAssets = imageAssets.find((item) => {
    const normalizedType = String(item.type || '').toLowerCase();
    return normalizedType === 'background';
  });
  const proofImages = imageAssets
    .filter((item) => String(item.type || '').toLowerCase() === 'proof')
    .map((item) => ({
      remoteUrl: item.url,
      fileName: item.fileName || item.url.split('/').pop() || 'proof',
      usage: 'proof' as const,
      origin: 'persisted' as const,
    }));

  const canonicalLinks = new Set(
    [
      organizer.officialWebsite,
      organizer.instagramUrl,
      organizer.facebookUrl,
      organizer.twitterUrl,
      organizer.youtubeUrl,
      organizer.tiktokUrl,
    ]
      .map(normalizeUrl)
      .filter(Boolean)
  );

  return {
    id: crypto.randomUUID(),
    name: fromNullableLocalizedText(organizer.nameI18n, organizer.name),
    abbreviation: organizer.abbreviation ?? '',
    aliases: aliases.length ? aliases : [''],
    country: fromNullableLocalizedText(organizer.countryI18n, organizer.country),
    city: fromNullableLocalizedText(organizer.cityI18n, organizer.city),
    foundedYear: organizer.foundedYear ?? '',
    frequency: organizer.frequencyI18n?.zh ?? organizer.frequency ?? '',
    tagline: organizer.tagline ?? '',
    introduction: fromNullableLocalizedText(
      organizer.descriptionI18n,
      organizer.introduction ?? ''
    ),
    officialWebsite: organizer.officialWebsite ?? '',
    instagram: organizer.instagramUrl ?? '',
    facebook: organizer.facebookUrl ?? '',
    twitter: organizer.twitterUrl ?? '',
    youtube: organizer.youtubeUrl ?? '',
    tiktok: organizer.tiktokUrl ?? '',
    extraLinks: links
      .filter((item) => !canonicalLinks.has(normalizeUrl(item.url)))
      .map((item) => ({
        id: crypto.randomUUID(),
        title: item.title || '',
        icon: item.icon || 'link',
        url: item.url || '',
      })),
    avatarImage:
      organizer.avatarUrl || avatarImageFromAssets?.url
        ? {
            remoteUrl: organizer.avatarUrl ?? avatarImageFromAssets?.url ?? '',
            fileName:
              organizer.avatarUrl?.split('/').pop() ||
              avatarImageFromAssets?.fileName ||
              'avatar',
            usage: 'avatar',
            origin: 'persisted',
          }
        : null,
    backgroundImage:
      organizer.backgroundUrl || backgroundImageFromAssets?.url
        ? {
            remoteUrl: organizer.backgroundUrl ?? backgroundImageFromAssets?.url ?? '',
            fileName:
              organizer.backgroundUrl?.split('/').pop() ||
              backgroundImageFromAssets?.fileName ||
              'background',
            usage: 'background',
            origin: 'persisted',
          }
        : null,
    proofImages,
    baseBrandRevision: organizer.revision ?? null,
    rightsConfirmed: false,
    identityConfirmed: false,
  };
};
