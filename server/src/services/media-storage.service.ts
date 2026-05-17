import OSS from 'ali-oss';
import crypto from 'crypto';
import fs from 'fs/promises';
import path from 'path';

const cleanEnv = (value: string | undefined): string | null => {
  if (!value) return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
};

const ossRegion = cleanEnv(process.env.OSS_REGION);
const ossAccessKeyId = cleanEnv(process.env.OSS_ACCESS_KEY_ID);
const ossAccessKeySecret = cleanEnv(process.env.OSS_ACCESS_KEY_SECRET);
const ossBucket = cleanEnv(process.env.OSS_BUCKET);
const ossEndpoint = cleanEnv(process.env.OSS_ENDPOINT);

const ossClient =
  ossRegion && ossAccessKeyId && ossAccessKeySecret && ossBucket
    ? new OSS({
        region: ossRegion,
        accessKeyId: ossAccessKeyId,
        accessKeySecret: ossAccessKeySecret,
        bucket: ossBucket,
        endpoint: ossEndpoint || undefined,
      })
    : null;

export const isObjectStorageConfigured = (): boolean => ossClient !== null;

export const shouldAllowLocalUploadFallback = (): boolean =>
  cleanEnv(process.env.ALLOW_LOCAL_UPLOAD_STORAGE) === 'true' || process.env.NODE_ENV !== 'production';

export const assertObjectStorageConfigured = (operation: string): void => {
  if (!isObjectStorageConfigured()) {
    throw new Error(`${operation} requires OSS configuration`);
  }
};

export const publicObjectStorageUrlForKey = (objectKey: string): string => {
  if (!ossBucket || !ossRegion) {
    return `/${objectKey}`;
  }

  const endpointHost = ossEndpoint
    ? ossEndpoint.replace(/^https?:\/\//, '').replace(/^\/+|\/+$/g, '')
    : `${ossRegion}.aliyuncs.com`;
  const bucketHost = endpointHost.startsWith(`${ossBucket}.`) ? endpointHost : `${ossBucket}.${endpointHost}`;
  return `https://${bucketHost}/${objectKey}`;
};

export const securePublicAssetUrl = (rawUrl: string | undefined | null, objectKey: string): string => {
  const fallback = publicObjectStorageUrlForKey(objectKey);
  if (!rawUrl) return fallback;
  if (rawUrl.startsWith('//')) return `https:${rawUrl}`;
  if (rawUrl.startsWith('http://')) return `https://${rawUrl.slice('http://'.length)}`;
  if (rawUrl.startsWith('https://')) return rawUrl;
  return fallback;
};

export const extensionForMimeType = (mimeType: string): string => {
  const normalized = mimeType.toLowerCase();
  if (normalized.includes('png')) return '.png';
  if (normalized.includes('webp')) return '.webp';
  if (normalized.includes('gif')) return '.gif';
  if (normalized.includes('mp4')) return '.mp4';
  if (normalized.includes('quicktime')) return '.mov';
  return normalized.startsWith('video/') ? '.mp4' : '.jpg';
};

export const sanitizePathSegment = (value: string): string =>
  value
    .trim()
    .replace(/[^a-zA-Z0-9-_]/g, '')
    .slice(0, 128);

const safeExtension = (originalName: string, mimeType: string): string => {
  const rawExt = path.extname(originalName || '').toLowerCase();
  return rawExt && rawExt.length <= 10 ? rawExt : extensionForMimeType(mimeType);
};

export const buildMediaObjectKey = (
  prefix: string,
  ownerKey: string | null | undefined,
  usage: string | null | undefined,
  originalName: string,
  mimeType: string
): string => {
  const normalizedPrefix = prefix.replace(/^\/+|\/+$/g, '');
  const normalizedOwner = sanitizePathSegment(ownerKey || '') || 'drafts';
  const normalizedUsage = sanitizePathSegment(usage || '') || 'asset';
  const ext = safeExtension(originalName, mimeType);
  return `${normalizedPrefix}/${normalizedOwner}/${normalizedUsage}-${Date.now()}-${crypto.randomBytes(4).toString('hex')}${ext}`;
};

export const uploadBufferToObjectStorage = async (input: {
  buffer: Buffer;
  mimeType: string;
  objectKey: string;
  cacheControl?: string;
}): Promise<{ url: string; objectKey: string }> => {
  assertObjectStorageConfigured('Media upload');
  const client = ossClient as OSS;
  const result = await client.put(input.objectKey, input.buffer, {
    headers: {
      'Content-Type': input.mimeType,
      'Cache-Control': input.cacheControl || 'public, max-age=31536000, immutable',
    },
  });
  return {
    url: securePublicAssetUrl(result.url, input.objectKey),
    objectKey: input.objectKey,
  };
};

export const uploadFileToObjectStorage = async (input: {
  filePath: string;
  mimeType: string;
  objectKey: string;
  cacheControl?: string;
  unlinkAfterUpload?: boolean;
}): Promise<{ url: string; objectKey: string }> => {
  assertObjectStorageConfigured('Media upload');
  const client = ossClient as OSS;

  try {
    const result = await client.put(input.objectKey, input.filePath, {
      headers: {
        'Content-Type': input.mimeType,
        'Cache-Control': input.cacheControl || 'public, max-age=31536000, immutable',
      },
    });
    return {
      url: securePublicAssetUrl(result.url, input.objectKey),
      objectKey: input.objectKey,
    };
  } finally {
    if (input.unlinkAfterUpload) {
      await fs.unlink(input.filePath).catch(() => undefined);
    }
  }
};

export const deleteObjectStorageObject = async (objectKey: string): Promise<void> => {
  assertObjectStorageConfigured('Media purge');
  const client = ossClient as OSS;
  await client.delete(objectKey);
};

export const saveBufferToLocalUploads = async (input: {
  buffer: Buffer;
  localDir: string;
  publicSubdir: string;
  originalName: string;
  mimeType: string;
}): Promise<{ url: string; fileName: string }> => {
  await fs.mkdir(input.localDir, { recursive: true });
  const fileName = `${Date.now()}-${crypto.randomBytes(4).toString('hex')}${safeExtension(input.originalName, input.mimeType)}`;
  await fs.writeFile(path.join(input.localDir, fileName), input.buffer);
  return {
    url: `/uploads/${input.publicSubdir.replace(/^\/+|\/+$/g, '')}/${fileName}`,
    fileName,
  };
};
