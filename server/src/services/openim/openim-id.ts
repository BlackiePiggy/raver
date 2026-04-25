import crypto from 'crypto';

const normalize = (value: string): string => value.trim().toLowerCase();

const stripUnsafe = (value: string): string => normalize(value).replace(/[^a-z0-9]/g, '');

const withPrefix = (prefix: 'u' | 'g', value: string): string => {
  const stripped = stripUnsafe(value);
  if (stripped.length >= 8 && stripped.length <= 60) {
    return `${prefix}_${stripped}`;
  }

  const hashed = crypto.createHash('sha1').update(normalize(value)).digest('hex');
  return `${prefix}_${hashed.slice(0, 40)}`;
};

export const toOpenIMUserID = (raverUserId: string): string => withPrefix('u', raverUserId);

export const toOpenIMGroupID = (raverGroupId: string): string => withPrefix('g', raverGroupId);
