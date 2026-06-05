import crypto from 'crypto';
import type { ChangePathConfig } from './entity-change.types';

const isPlainObject = (value: unknown): value is Record<string, unknown> =>
  Boolean(value) && typeof value === 'object' && !Array.isArray(value) && !(value instanceof Date);

const normalizeString = (value: string, config?: ChangePathConfig): string | null => {
  const normalized = value.trim().replace(/\s+/g, ' ');
  if (!normalized && config?.emptyStringEqualsNull !== false) {
    return null;
  }
  return normalized;
};

const stableStringify = (value: unknown): string => {
  if (value === null || value === undefined) return 'null';
  if (typeof value !== 'object') return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(stableStringify).join(',')}]`;
  const row = value as Record<string, unknown>;
  return `{${Object.keys(row)
    .sort()
    .map((key) => `${JSON.stringify(key)}:${stableStringify(row[key])}`)
    .join(',')}}`;
};

export const hashCanonicalValue = (value: unknown): string =>
  crypto.createHash('sha256').update(stableStringify(value)).digest('hex');

const readConfig = (
  path: string,
  configs: Record<string, ChangePathConfig>
): ChangePathConfig | undefined => configs[path];

export const canonicalizeValue = (
  value: unknown,
  path: string,
  configs: Record<string, ChangePathConfig>
): unknown => {
  const config = readConfig(path, configs);

  if (value === undefined) return null;
  if (value === null) return null;
  if (value instanceof Date) return value.toISOString();
  if (typeof value === 'string') return normalizeString(value, config);
  if (typeof value === 'number' || typeof value === 'boolean') return value;
  if (typeof value === 'bigint') return value.toString();

  if (Array.isArray(value)) {
    const normalized = value.map((item, index) => canonicalizeValue(item, `${path}.${index}`, configs));
    if (config?.arrayStrategy?.type === 'set') {
      return normalized
        .map((item) => ({ item, hash: hashCanonicalValue(item) }))
        .sort((a, b) => a.hash.localeCompare(b.hash))
        .map((row) => row.item);
    }
    return normalized;
  }

  if (isPlainObject(value)) {
    const result: Record<string, unknown> = {};
    for (const key of Object.keys(value).sort()) {
      const child = canonicalizeValue(value[key], path ? `${path}.${key}` : key, configs);
      if (child !== undefined) {
        result[key] = child;
      }
    }
    return result;
  }

  if (typeof (value as { toString?: unknown }).toString === 'function') {
    return String(value);
  }

  return value;
};

export const stableSerialize = stableStringify;
