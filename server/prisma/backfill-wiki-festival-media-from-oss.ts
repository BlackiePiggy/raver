import 'dotenv/config';
import OSS from 'ali-oss';
import { PrismaClient } from '@prisma/client';

type Usage = 'avatar' | 'background';

type Candidate = {
  modifiedAt: number;
  url: string;
};

type FestivalMediaMap = Map<string, Partial<Record<Usage, Candidate>>>;

const prisma = new PrismaClient();

const normalizePrefix = (value: string): string => value.replace(/^\/+|\/+$/g, '');

async function main() {
  const region = process.env.OSS_REGION?.trim();
  const accessKeyId = process.env.OSS_ACCESS_KEY_ID?.trim();
  const accessKeySecret = process.env.OSS_ACCESS_KEY_SECRET?.trim();
  const bucket = process.env.OSS_BUCKET?.trim();

  if (!region || !accessKeyId || !accessKeySecret || !bucket) {
    throw new Error('Missing OSS env: OSS_REGION/OSS_ACCESS_KEY_ID/OSS_ACCESS_KEY_SECRET/OSS_BUCKET');
  }

  const prefix = normalizePrefix(process.env.OSS_WIKI_BRANDS_PREFIX?.trim() || 'wiki/brands');
  const publicBase = process.env.OSS_PUBLIC_BASE_URL?.trim().replace(/\/+$/g, '') || `https://${bucket}.${region}.aliyuncs.com`;

  const client = new OSS({
    region,
    accessKeyId,
    accessKeySecret,
    bucket,
  });

  const mediaMap: FestivalMediaMap = new Map();
  let marker: string | undefined;

  for (let page = 0; page < 30; page += 1) {
    const listed = await client.list(
      {
        prefix: `${prefix}/`,
        marker,
        'max-keys': 1000,
      },
      {}
    );

    for (const object of listed.objects || []) {
      const objectKey = object.name || '';
      const relative = objectKey.startsWith(`${prefix}/`) ? objectKey.slice(prefix.length + 1) : objectKey;
      const [festivalId, fileName] = relative.split('/');
      if (!festivalId || !fileName) continue;

      const normalizedFileName = fileName.toLowerCase();
      const usage: Usage | null = normalizedFileName.startsWith('avatar-')
        ? 'avatar'
        : normalizedFileName.startsWith('background-')
          ? 'background'
          : null;
      if (!usage) continue;

      const modifiedAt = new Date(object.lastModified || Date.now()).getTime();
      const current = mediaMap.get(festivalId) || {};
      const previous = current[usage];
      if (!previous || modifiedAt >= previous.modifiedAt) {
        current[usage] = {
          modifiedAt,
          url: `${publicBase}/${objectKey}`,
        };
        mediaMap.set(festivalId, current);
      }
    }

    if (!listed.isTruncated) break;
    marker = listed.nextMarker;
  }

  const festivals = await prisma.wikiFestival.findMany({
    select: { id: true },
  });

  let updated = 0;

  for (const festival of festivals) {
    const matched = mediaMap.get(festival.id);
    if (!matched) continue;

    const data: { avatarUrl?: string; backgroundUrl?: string } = {};
    if (matched.avatar?.url) {
      data.avatarUrl = matched.avatar.url;
    }
    if (matched.background?.url) {
      data.backgroundUrl = matched.background.url;
    }
    if (Object.keys(data).length === 0) continue;

    await prisma.wikiFestival.update({ where: { id: festival.id }, data });
    updated += 1;
  }

  console.log(`Wiki festival media backfill finished. Updated rows: ${updated}`);
}

main()
  .catch((error) => {
    console.error('Failed to backfill wiki festival media from OSS:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
