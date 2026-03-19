import fs from 'node:fs/promises';
import path from 'node:path';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const MARKER_PREFIX = '[LIVE_FEED_SEED]';
const DEFAULT_COUNT = 50;
const MAX_COUNT = 200;
const IMAGE_ROUTE_PREFIX = '/uploads/feed-seed';

const CONTENT_OPENERS = [
  '今晚的氛围太顶了，低频一出来全场一起抬手。',
  '这个 drop 一响，直接把周中疲惫清空。',
  '刚到场就听到最爱的段落，状态瞬间拉满。',
  '灯光和节奏完全同步，现场沉浸感很强。',
  '朋友说这段必须录下来，回放还是起鸡皮疙瘩。',
  '今天这套编排很丝滑，从开场到现在几乎没冷场。',
  '卡点转场太顺了，周围人都在跟着点头。',
  '舞池里每个人都在笑，能量真的很干净。',
  '这段旋律一出来，像是把整个场子点亮了。',
  '收工后回听这段，还是会想再来一次现场。',
];

const CONTENT_TAGS = [
  '#Raver测试',
  '#LiveSeed',
  '#EDM',
  '#HouseMusic',
  '#TechnoNight',
  '#AfterHours',
];

function parseCountArg(argv: string[]): number {
  const arg = argv.find((item) => item.startsWith('--count='));
  if (!arg) return DEFAULT_COUNT;
  const parsed = Number(arg.slice('--count='.length));
  if (!Number.isFinite(parsed) || parsed <= 0) return DEFAULT_COUNT;
  return Math.min(Math.floor(parsed), MAX_COUNT);
}

function pad2(value: number): string {
  return String(value).padStart(2, '0');
}

function pad3(value: number): string {
  return String(value).padStart(3, '0');
}

async function fileExists(filePath: string): Promise<boolean> {
  try {
    await fs.access(filePath);
    return true;
  } catch {
    return false;
  }
}

async function collectLocalImagePool(): Promise<string[]> {
  const assetsRoot = path.join(
    process.cwd(),
    '..',
    'mobile',
    'ios',
    'RaverMVP',
    'RaverMVP',
    'Assets.xcassets'
  );

  const userCandidates = Array.from({ length: 24 }, (_, index) => {
    const id = pad2(index + 1);
    return path.join(assetsRoot, `LocalUserAvatar${id}.imageset`, `LocalUserAvatar${id}.png`);
  });

  const groupCandidates = Array.from({ length: 12 }, (_, index) => {
    const id = pad2(index + 1);
    return path.join(assetsRoot, `LocalGroupAvatar${id}.imageset`, `LocalGroupAvatar${id}.png`);
  });

  const allCandidates = [...userCandidates, ...groupCandidates];
  const results: string[] = [];
  for (const candidate of allCandidates) {
    if (await fileExists(candidate)) {
      results.push(candidate);
    }
  }
  return results;
}

async function ensureSeedImages(count: number, sourceImages: string[]): Promise<string[]> {
  if (sourceImages.length === 0) {
    throw new Error('No local source images found in iOS Assets.xcassets.');
  }

  const targetDir = path.join(process.cwd(), 'uploads', 'feed-seed');
  await fs.mkdir(targetDir, { recursive: true });

  const urls: string[] = [];
  for (let index = 0; index < count; index += 1) {
    const source = sourceImages[index % sourceImages.length]!;
    const ext = path.extname(source) || '.png';
    const fileName = `live-feed-${pad3(index + 1)}${ext}`;
    const targetPath = path.join(targetDir, fileName);
    await fs.copyFile(source, targetPath);
    urls.push(`${IMAGE_ROUTE_PREFIX}/${fileName}`);
  }
  return urls;
}

function buildPostContent(index: number, username: string): string {
  const opener = CONTENT_OPENERS[index % CONTENT_OPENERS.length]!;
  const tagA = CONTENT_TAGS[index % CONTENT_TAGS.length]!;
  const tagB = CONTENT_TAGS[(index + 2) % CONTENT_TAGS.length]!;
  return `${MARKER_PREFIX} ${pad3(index + 1)} · @${username}\n${opener}\n${tagA} ${tagB}`;
}

async function main() {
  const apply = process.argv.includes('--apply');
  const append = process.argv.includes('--append');
  const count = parseCountArg(process.argv);

  const activeUsers = await prisma.user.findMany({
    where: { isActive: true },
    select: {
      id: true,
      username: true,
      displayName: true,
    },
    orderBy: [{ username: 'asc' }],
  });

  if (activeUsers.length === 0) {
    throw new Error('No active users found. Cannot generate feed posts.');
  }

  const sourceImages = await collectLocalImagePool();

  console.log(`Active users: ${activeUsers.length}`);
  console.log(`Local source images: ${sourceImages.length}`);
  console.log(`Seed count: ${count}`);
  console.log(`Mode: ${apply ? 'apply' : 'dry-run'}`);
  console.log(`Behavior: ${append ? 'append' : 'replace previous LIVE_FEED_SEED posts'}`);

  if (!apply) {
    const previewUsers = activeUsers.slice(0, 5).map((item) => item.username).join(', ');
    const previewImage = sourceImages[0] ?? '-';
    console.log(`Preview users: ${previewUsers}`);
    console.log(`Preview local image: ${previewImage}`);
    console.log('Dry run only. Re-run with --apply to persist changes.');
    return;
  }

  const imageUrls = await ensureSeedImages(count, sourceImages);

  let removed = 0;
  if (!append) {
    const deleted = await prisma.post.deleteMany({
      where: {
        content: {
          startsWith: MARKER_PREFIX,
        },
      },
    });
    removed = deleted.count;
  }

  const now = Date.now();
  let created = 0;
  for (let index = 0; index < count; index += 1) {
    const author = activeUsers[index % activeUsers.length]!;
    const createdAt = new Date(now - (count - index) * 90_000);
    await prisma.post.create({
      data: {
        userId: author.id,
        content: buildPostContent(index, author.username),
        images: [imageUrls[index]!],
        type: 'general',
        visibility: 'public',
        createdAt,
      },
    });
    created += 1;
  }

  console.log(`Removed old seed posts: ${removed}`);
  console.log(`Created new seed posts: ${created}`);
  console.log(`Local images prepared in: ${path.join(process.cwd(), 'uploads', 'feed-seed')}`);
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
