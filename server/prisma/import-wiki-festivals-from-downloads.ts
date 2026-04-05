import 'dotenv/config';

import fs from 'node:fs';
import path from 'node:path';
import { randomUUID } from 'node:crypto';

import OSS from 'ali-oss';
import { PrismaClient } from '@prisma/client';

type ParsedSource = {
  name: string;
  logoUrl: string;
  coverUrl: string;
};

type FolderEntry = {
  rank: number;
  folderName: string;
  folderPath: string;
  source: ParsedSource;
};

const prisma = new PrismaClient();

const DOWNLOADS_ROOT = path.resolve(
  process.env.WIKI_BRANDS_DOWNLOADS_ROOT || path.join(process.cwd(), '..', 'scrapRave', 'brands', 'downloads')
);
const FESTIVAL_IMAGES_ROOT = path.join(DOWNLOADS_ROOT, 'festival_images');
const RANKING_OUTPUT = path.resolve(
  process.env.WIKI_BRANDS_RANKING_OUTPUT ||
    path.join(process.cwd(), '..', 'web', 'public', 'rankings', 'djmag_festival', '2025.txt')
);

const OSS_REGION = String(process.env.OSS_REGION || '').trim();
const OSS_BUCKET = String(process.env.OSS_BUCKET || '').trim();
const OSS_ACCESS_KEY_ID = String(process.env.OSS_ACCESS_KEY_ID || '').trim();
const OSS_ACCESS_KEY_SECRET = String(process.env.OSS_ACCESS_KEY_SECRET || '').trim();
const OSS_ENDPOINT = String(process.env.OSS_ENDPOINT || '').trim();
const OSS_WIKI_BRANDS_PREFIX = (
  String(process.env.OSS_WIKI_BRANDS_PREFIX || 'wiki/brands').trim() || 'wiki/brands'
).replace(/^\/+|\/+$/g, '');

const LOGO_CANDIDATES = ['logo.png', 'logo.jpg', 'logo.jpeg', 'logo.webp', 'logo.svg', 'logo.avif'];
const COVER_CANDIDATES = ['cover.png', 'cover.jpg', 'cover.jpeg', 'cover.webp', 'cover.svg', 'cover.avif'];

function sanitizeSegment(value: string): string {
  return String(value || '')
    .trim()
    .replace(/[^a-zA-Z0-9-_]/g, '')
    .slice(0, 128);
}

function normalizeNameKey(value: string): string {
  return String(value || '')
    .toLowerCase()
    .replace(/[^a-z0-9\u4e00-\u9fa5]/g, '');
}

function safeExt(fileName: string, contentType = ''): string {
  const fromName = path.extname(String(fileName || '')).toLowerCase();
  if (fromName && fromName.length <= 10) return fromName;
  const mime = String(contentType || '').toLowerCase();
  if (mime.includes('png')) return '.png';
  if (mime.includes('webp')) return '.webp';
  if (mime.includes('gif')) return '.gif';
  if (mime.includes('svg')) return '.svg';
  if (mime.includes('avif')) return '.avif';
  return '.jpg';
}

function inferContentType(fileName: string): string {
  const ext = path.extname(String(fileName || '')).toLowerCase();
  if (ext === '.png') return 'image/png';
  if (ext === '.webp') return 'image/webp';
  if (ext === '.gif') return 'image/gif';
  if (ext === '.svg') return 'image/svg+xml';
  if (ext === '.avif') return 'image/avif';
  if (ext === '.jpeg' || ext === '.jpg') return 'image/jpeg';
  return 'image/jpeg';
}

function prettifyFolderName(folder: string): string {
  return String(folder || '')
    .replace(/^\d+_/, '')
    .replace(/_/g, ' ')
    .replace(/\b[a-z]/g, (x) => x.toUpperCase());
}

function normalizeBrandId(folderName: string): string {
  const raw = String(folderName || '').replace(/^\d+_/, '');
  const id = raw
    .replace(/[^a-zA-Z0-9-_]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .toLowerCase();
  return id || `brand_${Date.now()}`;
}

function parseSourceFile(filePath: string): ParsedSource {
  const text = fs.readFileSync(filePath, 'utf8');
  const lines = text
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean);
  const name = lines[0] || '';
  let logoUrl = '';
  let coverUrl = '';
  for (const line of lines.slice(1)) {
    const logoMatch = line.match(/^Logo:\s*(.+)$/i);
    if (logoMatch) {
      logoUrl = logoMatch[1].trim();
      continue;
    }
    const coverMatch = line.match(/^Cover:\s*(.+)$/i);
    if (coverMatch) {
      coverUrl = coverMatch[1].trim();
    }
  }
  const normalizeMaybeUrl = (value: string): string => {
    const text = String(value || '').trim();
    if (!text) return '';
    if (/^(nan|null|none|n\/a)$/i.test(text)) return '';
    return text;
  };
  return {
    name,
    logoUrl: normalizeMaybeUrl(logoUrl),
    coverUrl: normalizeMaybeUrl(coverUrl),
  };
}

function readFolders(): FolderEntry[] {
  const dirs = fs
    .readdirSync(FESTIVAL_IMAGES_ROOT, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort((a, b) => a.localeCompare(b));
  const results: FolderEntry[] = [];
  for (const folderName of dirs) {
    const rankMatch = folderName.match(/^(\d+)_/);
    if (!rankMatch) continue;
    const rank = Number(rankMatch[1]);
    const folderPath = path.join(FESTIVAL_IMAGES_ROOT, folderName);
    const sourcePath = path.join(folderPath, 'SOURCE.txt');
    if (!fs.existsSync(sourcePath)) continue;
    const source = parseSourceFile(sourcePath);
    results.push({
      rank,
      folderName,
      folderPath,
      source,
    });
  }
  return results.sort((a, b) => a.rank - b.rank);
}

function pickLocalImage(folderPath: string, candidates: string[]): string {
  for (const fileName of candidates) {
    const absolute = path.join(folderPath, fileName);
    if (fs.existsSync(absolute) && fs.statSync(absolute).isFile()) {
      return absolute;
    }
  }
  return '';
}

function buildObjectKey(brandId: string, usage: 'avatar' | 'background', sourceName: string, contentType: string): string {
  const safeBrandId = sanitizeSegment(brandId) || 'unknown-brand';
  const safeUsage = sanitizeSegment(usage) || 'image';
  const ext = safeExt(sourceName, contentType);
  return `${OSS_WIKI_BRANDS_PREFIX}/${safeBrandId}/${safeUsage}-${Date.now()}-${Math.random().toString(36).slice(2, 10)}${ext}`;
}

function normalizeOssUrl(rawUrl: string | undefined, objectKey: string): string {
  if (rawUrl && /^https?:\/\//i.test(rawUrl)) {
    return rawUrl.replace(/^http:\/\//i, 'https://');
  }
  const endpointHost = OSS_ENDPOINT
    ? OSS_ENDPOINT.replace(/^https?:\/\//, '').replace(/^\/+|\/+$/g, '')
    : `${OSS_REGION}.aliyuncs.com`;
  const bucketHost = endpointHost.startsWith(`${OSS_BUCKET}.`) ? endpointHost : `${OSS_BUCKET}.${endpointHost}`;
  return `https://${bucketHost}/${objectKey}`;
}

async function fetchRemoteBuffer(url: string): Promise<{ buffer: Buffer; contentType: string; fileName: string } | null> {
  const target = String(url || '').trim();
  if (!target) return null;
  try {
    const resp = await fetch(target, {
      headers: { 'User-Agent': 'raver-brand-import/1.0' },
      redirect: 'follow',
    });
    if (!resp.ok) return null;
    const arrayBuffer = await resp.arrayBuffer();
    const buffer = Buffer.from(arrayBuffer);
    if (!buffer.length) return null;
    const contentType = String(resp.headers.get('content-type') || '').trim();
    let fileName = '';
    try {
      const parsed = new URL(target);
      fileName = path.basename(parsed.pathname || '');
    } catch (_error) {
      fileName = '';
    }
    return { buffer, contentType, fileName };
  } catch (_error) {
    return null;
  }
}

async function uploadLocalFile(
  client: OSS,
  brandId: string,
  usage: 'avatar' | 'background',
  absolutePath: string
): Promise<string> {
  const sourceName = path.basename(absolutePath);
  const contentType = inferContentType(sourceName);
  const objectKey = buildObjectKey(brandId, usage, sourceName, contentType);
  const putRes = await client.put(objectKey, absolutePath, {
    headers: {
      'Content-Type': contentType,
      'Cache-Control': 'public, max-age=31536000, immutable',
    },
  });
  return normalizeOssUrl(String((putRes as any)?.url || ''), objectKey);
}

async function uploadRemoteFile(
  client: OSS,
  brandId: string,
  usage: 'avatar' | 'background',
  remoteUrl: string
): Promise<string> {
  const data = await fetchRemoteBuffer(remoteUrl);
  if (!data) throw new Error(`download failed: ${remoteUrl}`);
  const contentType = data.contentType || inferContentType(data.fileName);
  const objectKey = buildObjectKey(brandId, usage, data.fileName || 'image.jpg', contentType);
  const putRes = await client.put(objectKey, data.buffer, {
    headers: {
      'Content-Type': contentType,
      'Cache-Control': 'public, max-age=31536000, immutable',
    },
  });
  return normalizeOssUrl(String((putRes as any)?.url || ''), objectKey);
}

function mergeAliases(baseName: string, ...values: Array<string | null | undefined>): string[] {
  const seen = new Set<string>();
  const result: string[] = [];
  const push = (value: string | null | undefined) => {
    const text = String(value || '').trim();
    if (!text) return;
    const key = normalizeNameKey(text);
    if (!key || seen.has(key)) return;
    seen.add(key);
    result.push(text);
  };
  push(baseName);
  for (const value of values) push(value);
  return result.filter((x) => normalizeNameKey(x) !== normalizeNameKey(baseName));
}

async function ensureContributor(festivalId: string, userId: string | null): Promise<void> {
  if (!userId) return;
  await prisma.wikiFestivalContributor.upsert({
    where: {
      festivalId_userId: {
        festivalId,
        userId,
      },
    },
    create: {
      id: randomUUID(),
      festivalId,
      userId,
    },
    update: {},
  });
}

async function main(): Promise<void> {
  if (!OSS_REGION || !OSS_BUCKET || !OSS_ACCESS_KEY_ID || !OSS_ACCESS_KEY_SECRET) {
    throw new Error('Missing OSS config: OSS_REGION/OSS_BUCKET/OSS_ACCESS_KEY_ID/OSS_ACCESS_KEY_SECRET');
  }
  if (!fs.existsSync(FESTIVAL_IMAGES_ROOT)) {
    throw new Error(`festival_images not found: ${FESTIVAL_IMAGES_ROOT}`);
  }

  const client = new OSS({
    region: OSS_REGION,
    bucket: OSS_BUCKET,
    accessKeyId: OSS_ACCESS_KEY_ID,
    accessKeySecret: OSS_ACCESS_KEY_SECRET,
    endpoint: OSS_ENDPOINT || undefined,
    secure: true,
  });

  const allEntries = readFolders();
  console.log(`[brand-import] folders=${allEntries.length} root=${FESTIVAL_IMAGES_ROOT}`);

  const existingRows = await prisma.wikiFestival.findMany();
  const byId = new Map<string, typeof existingRows[number]>();
  const byNameKey = new Map<string, typeof existingRows[number]>();
  for (const row of existingRows) {
    byId.set(row.id, row);
    byNameKey.set(normalizeNameKey(row.name), row);
    for (const alias of row.aliases || []) {
      byNameKey.set(normalizeNameKey(alias), row);
    }
  }

  const uploadtester = await prisma.user.findUnique({
    where: { username: 'uploadtester' },
    select: { id: true },
  });
  const contributorUserId = uploadtester?.id || null;

  const rankingLines: string[] = [];
  let created = 0;
  let updated = 0;
  let logoUploaded = 0;
  let coverUploaded = 0;
  let skippedImages = 0;

  for (let idx = 0; idx < allEntries.length; idx += 1) {
    const entry = allEntries[idx];
    const sourceName = String(entry.source.name || '').trim() || prettifyFolderName(entry.folderName);
    const normalizedSourceName = normalizeNameKey(sourceName);
    const folderId = normalizeBrandId(entry.folderName);
    const matchedExisting = byId.get(folderId) || byNameKey.get(normalizedSourceName) || null;
    const targetId = matchedExisting?.id || folderId;

    const localLogo = pickLocalImage(entry.folderPath, LOGO_CANDIDATES);
    const localCover = pickLocalImage(entry.folderPath, COVER_CANDIDATES);

    let avatarUrl = matchedExisting?.avatarUrl || '';
    let backgroundUrl = matchedExisting?.backgroundUrl || '';

    try {
      if (localLogo) {
        avatarUrl = await uploadLocalFile(client, targetId, 'avatar', localLogo);
        logoUploaded += 1;
      } else if (entry.source.logoUrl) {
        avatarUrl = await uploadRemoteFile(client, targetId, 'avatar', entry.source.logoUrl);
        logoUploaded += 1;
      } else {
        skippedImages += 1;
      }
    } catch (error: any) {
      console.warn(`[brand-import] logo upload failed ${entry.folderName}: ${String(error?.message || error)}`);
      skippedImages += 1;
    }

    try {
      if (localCover) {
        backgroundUrl = await uploadLocalFile(client, targetId, 'background', localCover);
        coverUploaded += 1;
      } else if (entry.source.coverUrl) {
        backgroundUrl = await uploadRemoteFile(client, targetId, 'background', entry.source.coverUrl);
        coverUploaded += 1;
      } else {
        skippedImages += 1;
      }
    } catch (error: any) {
      console.warn(`[brand-import] cover upload failed ${entry.folderName}: ${String(error?.message || error)}`);
      skippedImages += 1;
    }

    const finalName = sourceName;
    const aliases = mergeAliases(finalName, prettifyFolderName(entry.folderName), matchedExisting?.name || '');

    const upserted = await prisma.wikiFestival.upsert({
      where: { id: targetId },
      create: {
        id: targetId,
        name: finalName,
        aliases,
        country: matchedExisting?.country || 'Unknown',
        city: matchedExisting?.city || 'Unknown',
        foundedYear: matchedExisting?.foundedYear || '',
        frequency: matchedExisting?.frequency || '',
        tagline: matchedExisting?.tagline || '',
        introduction: matchedExisting?.introduction || '',
        avatarUrl: avatarUrl || null,
        backgroundUrl: backgroundUrl || null,
        links: [],
        isActive: true,
      },
      update: {
        name: finalName,
        aliases,
        avatarUrl: avatarUrl || null,
        backgroundUrl: backgroundUrl || null,
        isActive: true,
      },
    });
    if (matchedExisting) updated += 1;
    else created += 1;
    await ensureContributor(upserted.id, contributorUserId);

    const rankName = upserted.name || finalName;
    rankingLines.push(`${entry.rank}. ${rankName}`);
    console.log(
      `[brand-import] ${idx + 1}/${allEntries.length} rank=${entry.rank} id=${upserted.id} name=${rankName} logo=${avatarUrl ? 'yes' : 'no'} cover=${backgroundUrl ? 'yes' : 'no'}`
    );
  }

  fs.mkdirSync(path.dirname(RANKING_OUTPUT), { recursive: true });
  fs.writeFileSync(RANKING_OUTPUT, `${rankingLines.join('\n')}\n`, 'utf8');

  console.log(
    `[brand-import] done created=${created} updated=${updated} logoUploaded=${logoUploaded} coverUploaded=${coverUploaded} skippedImages=${skippedImages}`
  );
  console.log(`[brand-import] ranking_file=${RANKING_OUTPUT}`);
}

main()
  .catch((error) => {
    console.error('[brand-import] fatal', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
