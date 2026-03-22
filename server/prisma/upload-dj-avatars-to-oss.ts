import 'dotenv/config';
import path from 'node:path';
import fs from 'node:fs/promises';
import OSS from 'ali-oss';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const CACHE_DIR = path.join(__dirname, '.cache');
const PROGRESS_FILE = path.join(CACHE_DIR, 'dj-avatar-oss-progress.json');
const REPORT_FILE = path.join(CACHE_DIR, 'dj-avatar-oss-report.json');

const DEFAULT_CONCURRENCY = 6;
const DEFAULT_RETRIES = 3;
const DEFAULT_PREFIX = 'djs/avatar';

type ProgressPayload = {
  completedIds: string[];
  failed: Array<{ id: string; slug: string; error: string }>;
};

function cleanString(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const normalized = value.trim();
  return normalized.length > 0 ? normalized : null;
}

function envNumber(name: string, fallback: number): number {
  const value = process.env[name];
  if (!value) return fallback;
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) return fallback;
  return Math.floor(parsed);
}

function detectExt(url: string, contentType?: string | null): string {
  const lowerType = (contentType || '').toLowerCase();
  if (lowerType.includes('png')) return '.png';
  if (lowerType.includes('webp')) return '.webp';
  if (lowerType.includes('gif')) return '.gif';
  if (lowerType.includes('jpeg') || lowerType.includes('jpg')) return '.jpg';

  const pathname = (url.split('?')[0] || '').toLowerCase();
  if (pathname.endsWith('.png')) return '.png';
  if (pathname.endsWith('.webp')) return '.webp';
  if (pathname.endsWith('.gif')) return '.gif';
  if (pathname.endsWith('.jpg') || pathname.endsWith('.jpeg')) return '.jpg';
  return '.jpg';
}

function normalizeOssUrl(url: string): string {
  if (url.startsWith('http://')) return `https://${url.slice('http://'.length)}`;
  return url;
}

function normalizePrefix(value: string): string {
  return value.replace(/^\/+/, '').replace(/\/+$/, '');
}

function isLikelyRemoteUrl(value: string): boolean {
  return /^https?:\/\//i.test(value);
}

async function sleep(ms: number): Promise<void> {
  await new Promise((resolve) => setTimeout(resolve, ms));
}

async function loadProgress(filePath: string): Promise<ProgressPayload> {
  try {
    const raw = await fs.readFile(filePath, 'utf-8');
    const parsed = JSON.parse(raw) as ProgressPayload;
    return {
      completedIds: Array.isArray(parsed.completedIds) ? parsed.completedIds : [],
      failed: Array.isArray(parsed.failed) ? parsed.failed : [],
    };
  } catch {
    return { completedIds: [], failed: [] };
  }
}

async function saveProgress(filePath: string, payload: ProgressPayload): Promise<void> {
  await fs.writeFile(
    filePath,
    JSON.stringify(
      {
        completedIds: Array.from(new Set(payload.completedIds)),
        failed: payload.failed,
      },
      null,
      2
    ),
    'utf-8'
  );
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

async function fetchBufferWithRetry(url: string, retries: number): Promise<{ buffer: Buffer; contentType?: string }> {
  let attempt = 0;
  while (attempt <= retries) {
    try {
      const response = await fetch(url, { redirect: 'follow' });
      if (!response.ok) {
        if (response.status >= 500 || response.status === 429) {
          throw new Error(`HTTP ${response.status}`);
        }
        throw new Error(`HTTP ${response.status}`);
      }
      const buffer = Buffer.from(await response.arrayBuffer());
      return { buffer, contentType: response.headers.get('content-type') || undefined };
    } catch (error) {
      if (attempt === retries) throw error;
      await sleep(350 * (attempt + 1));
      attempt += 1;
    }
  }
  throw new Error('unreachable');
}

async function main(): Promise<void> {
  const startedAt = new Date();
  const concurrency = envNumber('DJ_AVATAR_OSS_CONCURRENCY', DEFAULT_CONCURRENCY);
  const retries = envNumber('DJ_AVATAR_OSS_RETRIES', DEFAULT_RETRIES);
  const limit = process.env.DJ_AVATAR_OSS_LIMIT ? envNumber('DJ_AVATAR_OSS_LIMIT', 0) : 0;
  const resetProgress = process.env.DJ_AVATAR_OSS_RESET_PROGRESS === '1';
  const ignoreProgress = process.env.DJ_AVATAR_OSS_IGNORE_PROGRESS === '1';
  const onlySlugs = (process.env.DJ_AVATAR_OSS_ONLY_SLUGS || '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
  const onlySlugSet = new Set(onlySlugs);
  const prefix = normalizePrefix(cleanString(process.env.OSS_DJ_AVATAR_PREFIX) || DEFAULT_PREFIX);
  const region = cleanString(process.env.OSS_REGION)!;
  const bucket = cleanString(process.env.OSS_BUCKET)!;
  const canonicalPrefix = `https://${bucket}.${region}.aliyuncs.com/${prefix}/`;

  await fs.mkdir(CACHE_DIR, { recursive: true });
  if (resetProgress) {
    await saveProgress(PROGRESS_FILE, { completedIds: [], failed: [] });
  }

  const progress = await loadProgress(PROGRESS_FILE);
  const completedSet = new Set(ignoreProgress ? [] : progress.completedIds);
  const failedRows = ignoreProgress ? [] : [...progress.failed];

  const ossClient = buildOssClient();

  const allRows = await prisma.dJ.findMany({
    select: {
      id: true,
      slug: true,
      name: true,
      avatarUrl: true,
      avatarSourceUrl: true,
    },
    orderBy: { name: 'asc' },
  });

  let targets = allRows.filter((row) => {
    if (completedSet.has(row.id)) return false;
    const source = cleanString(row.avatarSourceUrl) || cleanString(row.avatarUrl);
    if (!source) return false;
    if (!isLikelyRemoteUrl(source)) return false;
    const currentAvatar = cleanString(row.avatarUrl);
    if (currentAvatar && currentAvatar.startsWith(canonicalPrefix)) return false;
    return true;
  });
  if (onlySlugSet.size > 0) {
    targets = targets.filter((row) => onlySlugSet.has(row.slug));
  }

  if (limit > 0) targets = targets.slice(0, limit);

  const stats = {
    totalRows: allRows.length,
    targets: targets.length,
    uploaded: 0,
    skippedAlreadyOss: allRows.length - targets.length,
    failed: 0,
    processed: 0,
  };

  console.log(`头像上传开始: total=${stats.totalRows}, targets=${stats.targets}, concurrency=${concurrency}`);

  let cursor = 0;
  const checkpointEvery = 50;

  async function worker(workerId: number): Promise<void> {
    while (true) {
      const index = cursor;
      cursor += 1;
      if (index >= targets.length) return;
      const target = targets[index];
      if (!target) return;

      const sourceUrl = (cleanString(target.avatarSourceUrl) || cleanString(target.avatarUrl)) as string;
      try {
        const { buffer, contentType } = await fetchBufferWithRetry(sourceUrl, retries);
        const ext = detectExt(sourceUrl, contentType);
        const objectKey = `${prefix}/${target.slug}${ext}`;

        const result = await ossClient.put(objectKey, buffer, {
          headers: contentType
            ? {
                'Content-Type': contentType,
                'Cache-Control': 'public, max-age=31536000',
              }
            : {
                'Cache-Control': 'public, max-age=31536000',
              },
        });

        const uploaded = normalizeOssUrl(result.url || `${canonicalPrefix}${target.slug}${ext}`);
        await prisma.dJ.update({
          where: { id: target.id },
          data: {
            avatarUrl: uploaded,
            avatarSourceUrl: cleanString(target.avatarSourceUrl) || sourceUrl,
            lastSyncedAt: new Date(),
          },
        });

        stats.uploaded += 1;
        stats.processed += 1;
        completedSet.add(target.id);

        if (!ignoreProgress && stats.processed % checkpointEvery === 0) {
          await saveProgress(PROGRESS_FILE, {
            completedIds: Array.from(completedSet),
            failed: failedRows,
          });
          console.log(`头像进度: ${stats.processed}/${targets.length}, uploaded=${stats.uploaded}, failed=${stats.failed}`);
        }
      } catch (error) {
        stats.failed += 1;
        stats.processed += 1;
        const message = error instanceof Error ? error.message : String(error);
        failedRows.push({ id: target.id, slug: target.slug, error: message });
        console.error(`[avatar-worker-${workerId}] 失败 ${target.slug}: ${message}`);
      }
    }
  }

  await Promise.all(Array.from({ length: concurrency }, (_, i) => worker(i + 1)));

  if (!ignoreProgress) {
    await saveProgress(PROGRESS_FILE, {
      completedIds: Array.from(completedSet),
      failed: failedRows,
    });
  }

  const finishedAt = new Date();
  const report = {
    startedAt: startedAt.toISOString(),
    finishedAt: finishedAt.toISOString(),
    durationSeconds: Math.round((finishedAt.getTime() - startedAt.getTime()) / 1000),
    prefix,
    canonicalPrefix,
    stats,
    files: {
      progress: PROGRESS_FILE,
      report: REPORT_FILE,
    },
  };

  await fs.writeFile(REPORT_FILE, JSON.stringify(report, null, 2), 'utf-8');
  console.log('头像上传完成');
  console.log(JSON.stringify(report, null, 2));
}

main()
  .catch((error) => {
    console.error('头像上传失败:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
