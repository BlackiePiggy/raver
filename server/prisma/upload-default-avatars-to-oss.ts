import 'dotenv/config';
import path from 'node:path';
import fs from 'node:fs/promises';
import OSS from 'ali-oss';

type AvatarManifest = {
  generatedAt: string;
  user: string[];
  group: string[];
};

const USER_COUNT = 24;
const GROUP_COUNT = 12;
const DEFAULT_PREFIX = 'defaults/avatars';
const MANIFEST_FILE = path.join(__dirname, 'default-avatar-manifest.json');

function cleanString(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const normalized = value.trim();
  return normalized.length > 0 ? normalized : null;
}

function buildOssClient(): OSS {
  const region = cleanString(process.env.OSS_REGION);
  const accessKeyId = cleanString(process.env.OSS_ACCESS_KEY_ID);
  const accessKeySecret = cleanString(process.env.OSS_ACCESS_KEY_SECRET);
  const bucket = cleanString(process.env.OSS_BUCKET);
  const endpoint = cleanString(process.env.OSS_ENDPOINT);

  if (!region || !accessKeyId || !accessKeySecret || !bucket) {
    throw new Error('Missing OSS env. Require OSS_REGION/OSS_ACCESS_KEY_ID/OSS_ACCESS_KEY_SECRET/OSS_BUCKET');
  }

  return new OSS({
    region,
    accessKeyId,
    accessKeySecret,
    bucket,
    endpoint: endpoint || undefined,
    secure: true,
  });
}

function normalizePrefix(value: string): string {
  return value.replace(/^\/+/, '').replace(/\/+$/, '');
}

function publicOssUrl(objectKey: string): string {
  const region = cleanString(process.env.OSS_REGION);
  const bucket = cleanString(process.env.OSS_BUCKET);
  const endpoint = cleanString(process.env.OSS_ENDPOINT);
  if (!region || !bucket) {
    throw new Error('Missing OSS_REGION/OSS_BUCKET');
  }

  const endpointHost = endpoint
    ? endpoint.replace(/^https?:\/\//, '').replace(/^\/+|\/+$/g, '')
    : `${region}.aliyuncs.com`;
  const bucketHost = endpointHost.startsWith(`${bucket}.`) ? endpointHost : `${bucket}.${endpointHost}`;
  return `https://${bucketHost}/${objectKey}`;
}

function pad2(value: number): string {
  return String(value).padStart(2, '0');
}

function assetRoot(): string {
  return path.join(
    process.cwd(),
    '..',
    'mobile',
    'ios',
    'RaverMVP',
    'RaverMVP',
    'Assets.xcassets'
  );
}

function assetPath(kind: 'user' | 'group', index: number): string {
  const folder = kind === 'user' ? `LocalUserAvatar${pad2(index)}.imageset` : `LocalGroupAvatar${pad2(index)}.imageset`;
  const file = kind === 'user' ? `LocalUserAvatar${pad2(index)}.png` : `LocalGroupAvatar${pad2(index)}.png`;
  return path.join(assetRoot(), folder, file);
}

async function uploadOne(
  client: OSS,
  prefix: string,
  kind: 'user' | 'group',
  index: number
): Promise<string> {
  const sourcePath = assetPath(kind, index);
  const fileBuffer = await fs.readFile(sourcePath);
  const objectKey = `${prefix}/${kind}/${kind}-avatar-${pad2(index)}.png`;
  const result = await client.put(objectKey, fileBuffer, {
    headers: {
      'Content-Type': 'image/png',
      'Cache-Control': 'public, max-age=31536000, immutable',
    },
  });
  return result.url?.replace(/^http:\/\//, 'https://') || publicOssUrl(objectKey);
}

async function main(): Promise<void> {
  const client = buildOssClient();
  const prefix = normalizePrefix(cleanString(process.env.OSS_DEFAULT_AVATARS_PREFIX) || DEFAULT_PREFIX);

  const manifest: AvatarManifest = {
    generatedAt: new Date().toISOString(),
    user: [],
    group: [],
  };

  for (let index = 1; index <= USER_COUNT; index += 1) {
    manifest.user.push(await uploadOne(client, prefix, 'user', index));
  }

  for (let index = 1; index <= GROUP_COUNT; index += 1) {
    manifest.group.push(await uploadOne(client, prefix, 'group', index));
  }

  await fs.writeFile(MANIFEST_FILE, JSON.stringify(manifest, null, 2) + '\n', 'utf-8');
  console.log(JSON.stringify(manifest, null, 2));
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
