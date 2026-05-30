import {
  OrganizerStudioCreateInput,
  OrganizerStudioDraft,
  OrganizerStudioExtraLinkDraft,
  OrganizerStudioLinkPayload,
  OrganizerStudioLocalizedText,
  OrganizerStudioUpdateInput,
} from './types';

const trimOrNull = (value?: string | null): string | null => {
  const trimmed = String(value || '').trim();
  return trimmed || null;
};

const normalizedLocalizedText = (
  value: OrganizerStudioLocalizedText
): OrganizerStudioLocalizedText | null => {
  const next: OrganizerStudioLocalizedText = {
    zh: value.zh.trim(),
    en: value.en.trim(),
    ja: value.ja.trim(),
    enFull: value.enFull.trim(),
  };
  return next.zh || next.en || next.ja || next.enFull ? next : null;
};

const primaryText = (value: OrganizerStudioLocalizedText): string =>
  value.zh.trim() || value.en.trim() || value.ja.trim() || value.enFull.trim();

const splitAliases = (value: string): string[] => {
  const items = value
    .split(/[\n,]/)
    .map((item) => item.trim())
    .filter(Boolean);
  return Array.from(new Set(items));
};

const inferLinkTitle = (rawUrl: string): string => {
  try {
    const host = new URL(rawUrl).host.replace(/^www\./, '');
    const primary = host.split('.')[0];
    return primary ? primary.charAt(0).toUpperCase() + primary.slice(1) : 'Link';
  } catch {
    return 'Link';
  }
};

const normalizedLinks = (
  items: OrganizerStudioExtraLinkDraft[]
): OrganizerStudioLinkPayload[] =>
  items
    .map((item) => {
      const url = item.url.trim();
      if (!url) return null;
      const title = item.title.trim() || inferLinkTitle(url);
      return {
        title,
        icon: item.icon.trim() || 'link',
        url,
      };
    })
    .filter((item): item is OrganizerStudioLinkPayload => Boolean(item));

export const mapOrganizerStudioDraftToCreateInput = (
  draft: OrganizerStudioDraft
): OrganizerStudioCreateInput => {
  const nameI18n = normalizedLocalizedText(draft.name);
  const countryI18n = normalizedLocalizedText(draft.country);
  const cityI18n = normalizedLocalizedText(draft.city);
  const descriptionI18n = normalizedLocalizedText(draft.introduction);
  const aliases = splitAliases(draft.aliasesText);
  const links = normalizedLinks(draft.extraLinks);
  const imageAssets = [
    draft.avatarImage
      ? {
          url: draft.avatarImage.remoteUrl,
          type: 'avatar',
          label: 'AVATAR',
          sort: 0,
          order: 1,
          source: 'web-organizer-studio-v1',
          fileName: draft.avatarImage.fileName,
        }
      : null,
    draft.backgroundImage
      ? {
          url: draft.backgroundImage.remoteUrl,
          type: 'background',
          label: 'BACKGROUND',
          sort: 1,
          order: 1,
          source: 'web-organizer-studio-v1',
          fileName: draft.backgroundImage.fileName,
        }
      : null,
    ...draft.proofImages.map((item, index) => ({
      url: item.remoteUrl,
      type: 'proof',
      label: 'PROOF',
      sort: index,
      order: index + 1,
      source: 'web-organizer-studio-v1',
      fileName: item.fileName,
    })),
  ].filter((item): item is NonNullable<typeof item> => Boolean(item));

  return {
    name: primaryText(draft.name),
    nameI18n,
    abbreviation: trimOrNull(draft.abbreviation),
    aliases,
    country: trimOrNull(primaryText(draft.country)),
    countryI18n,
    city: trimOrNull(primaryText(draft.city)),
    cityI18n,
    foundedYear: trimOrNull(draft.foundedYear),
    frequency: trimOrNull(draft.frequency),
    tagline: trimOrNull(draft.tagline),
    introduction: trimOrNull(primaryText(draft.introduction)),
    descriptionI18n,
    officialWebsite: trimOrNull(draft.officialWebsite),
    facebookUrl: trimOrNull(draft.facebook),
    instagramUrl: trimOrNull(draft.instagram),
    twitterUrl: trimOrNull(draft.twitter),
    youtubeUrl: trimOrNull(draft.youtube),
    tiktokUrl: trimOrNull(draft.tiktok),
    avatarUrl: trimOrNull(draft.avatarImage?.remoteUrl),
    backgroundUrl: trimOrNull(draft.backgroundImage?.remoteUrl),
    proofImageUrl: trimOrNull(draft.proofImages[0]?.remoteUrl),
    imageAssets: imageAssets.length ? imageAssets : null,
    rightsConfirmed: draft.rightsConfirmed,
    identityConfirmed: draft.identityConfirmed,
    links: links.length ? links : null,
  };
};

export const mapOrganizerStudioDraftToUpdateInput = (
  draft: OrganizerStudioDraft
): OrganizerStudioUpdateInput => ({
  ...mapOrganizerStudioDraftToCreateInput(draft),
  baseBrandRevision: draft.baseBrandRevision,
});
