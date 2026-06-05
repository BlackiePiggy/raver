import {
  OrganizerStudioCreateInput,
  OrganizerStudioDraft,
  OrganizerStudioExtraLinkDraft,
  OrganizerStudioLinkPayload,
  OrganizerStudioLocalizedText,
  OrganizerStudioUpdateInput,
} from './types';
import { INPUT_LIMITS, normalizeMultiline, normalizeSingleLine, trimArrayItems } from '@/lib/input-rules';

const trimSingleLineOrNull = (value: string | null | undefined, max: number): string | null => {
  const trimmed = normalizeSingleLine(value).slice(0, max);
  return trimmed || null;
};

const trimMultilineOrNull = (value: string | null | undefined, max: number): string | null => {
  const trimmed = normalizeMultiline(value).slice(0, max);
  return trimmed || null;
};

const trimUrlOrNull = (value?: string | null): string | null =>
  trimSingleLineOrNull(value, INPUT_LIMITS.common.url);

const normalizedLocalizedText = (
  value: OrganizerStudioLocalizedText,
  max: number,
  multiline = false
): OrganizerStudioLocalizedText | null => {
  const next: OrganizerStudioLocalizedText = {
    zh: (multiline ? normalizeMultiline(value.zh) : normalizeSingleLine(value.zh)).slice(0, max),
    en: (multiline ? normalizeMultiline(value.en) : normalizeSingleLine(value.en)).slice(0, max),
    ja: (multiline ? normalizeMultiline(value.ja) : normalizeSingleLine(value.ja)).slice(0, max),
    enFull: (multiline ? normalizeMultiline(value.enFull) : normalizeSingleLine(value.enFull)).slice(0, max),
  };
  return next.zh || next.en || next.ja || next.enFull ? next : null;
};

const primaryText = (value: OrganizerStudioLocalizedText): string =>
  normalizeSingleLine(value.zh) || normalizeSingleLine(value.en) || normalizeSingleLine(value.ja) || normalizeSingleLine(value.enFull);

const normalizeStringArray = (value: string[], itemMax: number, maxItems: number): string[] =>
  trimArrayItems(value, itemMax).slice(0, maxItems);

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
      const url = normalizeSingleLine(item.url).slice(0, INPUT_LIMITS.common.url);
      if (!url) return null;
      const title = normalizeSingleLine(item.title).slice(0, INPUT_LIMITS.organizer.extraLinkTitle) || inferLinkTitle(url).slice(0, INPUT_LIMITS.organizer.extraLinkTitle);
      return {
        title,
        icon: normalizeSingleLine(item.icon).slice(0, INPUT_LIMITS.common.linkIcon) || 'link',
        url,
      };
    })
    .filter((item): item is OrganizerStudioLinkPayload => Boolean(item));

export const mapOrganizerStudioDraftToCreateInput = (
  draft: OrganizerStudioDraft
): OrganizerStudioCreateInput => {
  const nameI18n = normalizedLocalizedText(draft.name, INPUT_LIMITS.organizer.name);
  const countryI18n = normalizedLocalizedText(draft.country, INPUT_LIMITS.organizer.country);
  const cityI18n = normalizedLocalizedText(draft.city, INPUT_LIMITS.organizer.city);
  const descriptionI18n = normalizedLocalizedText(draft.introduction, INPUT_LIMITS.organizer.introduction, true);
  const aliases = normalizeStringArray(
    draft.aliases,
    INPUT_LIMITS.organizer.alias,
    INPUT_LIMITS.organizer.aliasesMaxItems
  );
  const links = normalizedLinks(draft.extraLinks);
  const imageAssets = [
    draft.avatarImage
      ? {
          url: normalizeSingleLine(draft.avatarImage.remoteUrl).slice(0, INPUT_LIMITS.common.url),
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
          url: normalizeSingleLine(draft.backgroundImage.remoteUrl).slice(0, INPUT_LIMITS.common.url),
          type: 'background',
          label: 'BACKGROUND',
          sort: 1,
          order: 1,
          source: 'web-organizer-studio-v1',
          fileName: draft.backgroundImage.fileName,
        }
      : null,
    ...draft.proofImages.map((item, index) => ({
      url: normalizeSingleLine(item.remoteUrl).slice(0, INPUT_LIMITS.common.url),
      type: 'proof',
      label: 'PROOF',
      sort: index,
      order: index + 1,
      source: 'web-organizer-studio-v1',
      fileName: item.fileName,
    })),
  ].filter((item): item is NonNullable<typeof item> => Boolean(item));

  return {
    name: primaryText(nameI18n ?? draft.name).slice(0, INPUT_LIMITS.organizer.name),
    nameI18n,
    abbreviation: trimSingleLineOrNull(draft.abbreviation, INPUT_LIMITS.organizer.abbreviation),
    aliases,
    country: trimSingleLineOrNull(primaryText(draft.country), INPUT_LIMITS.organizer.country),
    countryI18n,
    city: trimSingleLineOrNull(primaryText(draft.city), INPUT_LIMITS.organizer.city),
    cityI18n,
    foundedYear: trimSingleLineOrNull(draft.foundedYear, INPUT_LIMITS.organizer.foundedYear),
    frequency: trimSingleLineOrNull(draft.frequency, INPUT_LIMITS.organizer.frequency),
    tagline: trimSingleLineOrNull(draft.tagline, INPUT_LIMITS.organizer.tagline),
    introduction: trimMultilineOrNull(primaryText(draft.introduction), INPUT_LIMITS.organizer.introduction),
    descriptionI18n,
    officialWebsite: trimUrlOrNull(draft.officialWebsite),
    facebookUrl: trimUrlOrNull(draft.facebook),
    instagramUrl: trimUrlOrNull(draft.instagram),
    twitterUrl: trimUrlOrNull(draft.twitter),
    youtubeUrl: trimUrlOrNull(draft.youtube),
    tiktokUrl: trimUrlOrNull(draft.tiktok),
    avatarUrl: trimUrlOrNull(draft.avatarImage?.remoteUrl),
    backgroundUrl: trimUrlOrNull(draft.backgroundImage?.remoteUrl),
    proofImageUrl: trimUrlOrNull(draft.proofImages[0]?.remoteUrl),
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
