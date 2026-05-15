import { Prisma } from '@prisma/client';

const truthyValues = new Set(['1', 'true', 'yes', 'y', 'on', 'confirmed']);

const RIGHTS_CONFIRMATION_KEYS = [
  'rightsConfirmed',
  'rightsOrSourceConfirmed',
  'sourceRightsConfirmed',
  'legalSourceConfirmed',
  'rights_confirmation',
  'rights_or_source_confirmed',
];

const mediaLinkKeys = [
  'audioUrl',
  'audioURL',
  'videoUrl',
  'videoURL',
  'musicUrl',
  'musicURL',
  'soundcloudUrl',
  'soundcloudURL',
  'spotifyUrl',
  'spotifyURL',
  'appleMusicUrl',
  'appleMusicURL',
  'youtubeUrl',
  'youtubeURL',
];

const isConfirmed = (value: unknown): boolean => {
  if (value === true) return true;
  if (typeof value === 'number') return value === 1;
  if (typeof value !== 'string') return false;
  return truthyValues.has(value.trim().toLowerCase());
};

const hasNonEmptyValue = (value: unknown): boolean => {
  if (typeof value === 'string') return value.trim().length > 0;
  if (Array.isArray(value)) return value.some(hasNonEmptyValue);
  if (!value || typeof value !== 'object') return false;
  return Object.values(value as Record<string, unknown>).some(hasNonEmptyValue);
};

export const contentCompliance = {
  requiresRightsConfirmation(entityType: string, payload: Record<string, unknown>): boolean {
    const normalizedType = entityType.trim().toLowerCase();
    if (normalizedType === 'set' || normalizedType === 'id') return true;
    return mediaLinkKeys.some((key) => hasNonEmptyValue(payload[key]));
  },

  hasRightsConfirmation(payload: Record<string, unknown>): boolean {
    return RIGHTS_CONFIRMATION_KEYS.some((key) => isConfirmed(payload[key]));
  },

  validationError(entityType: string, payload: Record<string, unknown>): string | null {
    if (this.requiresRightsConfirmation(entityType, payload) && !this.hasRightsConfirmation(payload)) {
      return '请确认你拥有发布权利，或确认链接来源合法且可公开引用';
    }
    return null;
  },

  reviewNotes(entityType: string, payload: Record<string, unknown>): Prisma.InputJsonObject {
    const rightsRequired = this.requiresRightsConfirmation(entityType, payload);
    return {
      prohibitedAdultContent: {
        policy: 'prohibited',
        action: 'reject_remove_enforce',
      },
      rights: {
        required: rightsRequired,
        confirmed: rightsRequired ? this.hasRightsConfirmation(payload) : null,
      },
    };
  },
};
