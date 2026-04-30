import crypto from 'crypto';

const UUID_COMPACT_PATTERN = /^[0-9a-f]{32}$/i;
const UUID_WITH_DASHES_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const toCompactUUID = (value: string): string | null => {
  const normalized = value.trim();
  if (UUID_WITH_DASHES_PATTERN.test(normalized)) {
    return normalized.replace(/-/g, '').toLowerCase();
  }
  if (UUID_COMPACT_PATTERN.test(normalized)) {
    return normalized.toLowerCase();
  }
  return null;
};

const toStableShortID = (value: string): string => {
  const compactUUID = toCompactUUID(value);
  if (compactUUID) {
    return Buffer.from(compactUUID, 'hex').toString('base64url');
  }

  return crypto.createHash('sha256').update(value.trim().toLowerCase()).digest('base64url').slice(0, 22);
};

const withPrefix = (prefix: string, value: string): string => `${prefix}${toStableShortID(value)}`;

export const toTencentIMUserID = (raverUserId: string): string => withPrefix('tu_', raverUserId);

export const toTencentIMSquadGroupID = (squadId: string): string => withPrefix('sg_', squadId);

export const toTencentIMEventGroupID = (eventId: string): string => withPrefix('eg_', eventId);
