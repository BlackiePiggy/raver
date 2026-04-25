import 'dotenv/config';
import { PrismaClient } from '@prisma/client';

type SeedUser = {
  id: string;
  username: string;
  displayName: string | null;
  avatarUrl: string | null;
};

const prisma = new PrismaClient();

const POST_TARGET = Number(process.env.RICH_FEED_POST_COUNT || 100);
const COMMENT_MIN = Number(process.env.RICH_FEED_COMMENT_MIN || 40);
const COMMENT_MAX = Number(process.env.RICH_FEED_COMMENT_MAX || 50);
const LIKE_MIN = Number(process.env.RICH_FEED_LIKE_MIN || 10);
const LIKE_MAX = Number(process.env.RICH_FEED_LIKE_MAX || 30);
const SAVE_MIN = Number(process.env.RICH_FEED_SAVE_MIN || 3);
const SAVE_MAX = Number(process.env.RICH_FEED_SAVE_MAX || 15);
const SHARE_MIN = Number(process.env.RICH_FEED_SHARE_MIN || 1);
const SHARE_MAX = Number(process.env.RICH_FEED_SHARE_MAX || 8);
const REPOST_MIN = Number(process.env.RICH_FEED_REPOST_MIN || 1);
const REPOST_MAX = Number(process.env.RICH_FEED_REPOST_MAX || 8);

const LOCATIONS = [
  'Shanghai',
  'Beijing',
  'Shenzhen',
  'Guangzhou',
  'Hangzhou',
  'Chengdu',
  'Nanjing',
  'Wuhan',
  'Xi an',
  'Chongqing',
  'Suzhou',
  'Tianjin',
  'Qingdao',
  'Xiamen',
];

const TOPIC_PACKS = [
  {
    title: 'Warehouse afterparty notes',
    angle: 'Deep groove to peak-time progression',
    tags: ['#techno', '#afterhours', '#warehouse'],
  },
  {
    title: 'Open-air set recap',
    angle: 'Sunset chords into driving low-end',
    tags: ['#openair', '#progressive', '#sunsetset'],
  },
  {
    title: 'Club night debrief',
    angle: 'Fast transitions and crowd control',
    tags: ['#clubnight', '#djlife', '#setflow'],
  },
  {
    title: 'Track test from rehearsal',
    angle: 'Kick-bass balance and vocal timing',
    tags: ['#newmusic', '#wip', '#mixsession'],
  },
  {
    title: 'B2B chemistry snapshot',
    angle: 'Alternating textures every 3 tracks',
    tags: ['#b2b', '#underground', '#crowdenergy'],
  },
  {
    title: 'Festival lane report',
    angle: 'Heavy percussion and clean breaks',
    tags: ['#festival', '#electronicmusic', '#liverecap'],
  },
  {
    title: 'Booth workflow share',
    angle: 'EQ discipline and monitor strategy',
    tags: ['#djtips', '#sounddesign', '#booth'],
  },
  {
    title: 'Late-night listening dump',
    angle: 'Hypnotic loops and spacey textures',
    tags: ['#latenight', '#melodic', '#selector'],
  },
];

const COMMENT_PHRASES = [
  'Transition at minute 3 was very clean.',
  'This groove is exactly what I needed today.',
  'The second build-up had serious impact.',
  'Low-end is tight without being muddy.',
  'Can you share the track ID from the intro?',
  'Crowd response looked really strong.',
  'Great pacing from warm-up to peak.',
  'The vocal timing is on point.',
  'I like the darker texture in this clip.',
  'That breakdown felt cinematic.',
  'This set would work perfectly at 2AM.',
  'Respect for keeping the energy consistent.',
  'The groove sits nicely with the percussion.',
  'Really good tension-release structure.',
  'I can feel the room from this post.',
  'Smart choice to hold the drop for longer.',
  'These drums hit in the best way.',
  'This is a solid reference for club flow.',
  'Nice detail in the mid-range.',
  'That final transition is super smooth.',
  'Love the hypnotic section in the middle.',
  'Perfect amount of drive and space.',
  'This arrangement feels very intentional.',
  'I replayed this part three times already.',
  'Excellent crowd reading here.',
  'The rhythm section is very controlled.',
  'This has proper warehouse energy.',
  'Really tasteful filter work.',
  'Strong storytelling across the set.',
  'This one belongs on a big system.',
  'Great post, thanks for sharing the vibe.',
  'The atmosphere comes through clearly.',
  'I need the full recording of this.',
  'This is exactly my lane sonically.',
  'Huge moment right before the drop.',
  'Very balanced mix, nothing feels overdone.',
  'I can hear the confidence in these transitions.',
  'This is going straight into my inspiration folder.',
  'Timing choices are excellent throughout.',
  'That groove pocket is addictive.',
];

const TRACK_REFERENCES = [
  'acid line from the second section',
  'pads in the breakdown',
  'ride pattern in the outro',
  'kick swap near the midpoint',
  'vocal chop before the drop',
  'percussion roll in bar 16',
  'sub movement in the low-end',
  'lead stab in the high register',
];

const randomInt = (min: number, max: number): number => {
  const low = Math.min(min, max);
  const high = Math.max(min, max);
  return Math.floor(Math.random() * (high - low + 1)) + low;
};

const pickOne = <T>(arr: T[]): T => {
  return arr[Math.floor(Math.random() * arr.length)];
};

const pickManyUnique = <T>(arr: T[], count: number): T[] => {
  if (arr.length === 0 || count <= 0) return [];
  const target = Math.min(count, arr.length);
  const copy = [...arr];
  for (let i = copy.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy.slice(0, target);
};

const buildImageUrls = (postIndex: number): string[] => {
  const imageCount = randomInt(1, 4);
  const urls: string[] = [];
  for (let i = 0; i < imageCount; i += 1) {
    const seed = `raver-feed-${postIndex + 1}-${i + 1}-${randomInt(10, 9999)}`;
    const width = pickOne([960, 1080, 1200, 1280]);
    const height = pickOne([1280, 1350, 1440, 900]);
    urls.push(`https://picsum.photos/seed/${seed}/${width}/${height}`);
  }
  return urls;
};

const buildPostContent = (author: SeedUser): string => {
  const topic = pickOne(TOPIC_PACKS);
  const bpm = randomInt(122, 138);
  const energyBand = randomInt(7, 10);
  const ref = pickOne(TRACK_REFERENCES);
  const authorName = (author.displayName || author.username || 'DJ').trim();
  return [
    `${topic.title} by ${authorName}.`,
    `${topic.angle}.`,
    `Tonight I kept the set around ${bpm} BPM with energy ${energyBand}/10 and focused on ${ref}.`,
    `What would you change in this sequence?`,
    topic.tags.join(' '),
  ].join('\n');
};

const buildCommentContent = (index: number): string => {
  const base = COMMENT_PHRASES[index % COMMENT_PHRASES.length];
  const addon = Math.random() < 0.35 ? ` Also loved the ${pickOne(TRACK_REFERENCES)}.` : '';
  return `${base}${addon}`;
};

const run = async (): Promise<void> => {
  if (POST_TARGET <= 0) {
    throw new Error('POST_TARGET must be > 0');
  }

  const users = await prisma.user.findMany({
    where: { isActive: true },
    select: {
      id: true,
      username: true,
      displayName: true,
      avatarUrl: true,
    },
    orderBy: [{ createdAt: 'asc' }],
  });

  if (users.length === 0) {
    throw new Error('No active users found in database.');
  }

  console.log('[seed-rich-feed] users available:', users.length);
  console.log('[seed-rich-feed] target posts:', POST_TARGET);
  console.log('[seed-rich-feed] comments per post range:', COMMENT_MIN, COMMENT_MAX);

  let totalPosts = 0;
  let totalLikes = 0;
  let totalComments = 0;
  let totalSaves = 0;
  let totalShares = 0;
  let totalReposts = 0;

  const now = Date.now();

  for (let i = 0; i < POST_TARGET; i += 1) {
    const author = pickOne(users);
    const audience = users.filter((user) => user.id !== author.id);
    const interactionPool = audience.length > 0 ? audience : users;

    const daysAgo = randomInt(0, 45);
    const hoursAgo = randomInt(0, 23);
    const minutesAgo = randomInt(0, 59);
    const createdAt = new Date(now - (((daysAgo * 24 + hoursAgo) * 60 + minutesAgo) * 60 * 1000));
    const displayPublishedAt = new Date(createdAt.getTime() + randomInt(1, 45) * 60 * 1000);

    const location = Math.random() < 0.8 ? pickOne(LOCATIONS) : null;

    const post = await prisma.post.create({
      data: {
        userId: author.id,
        content: buildPostContent(author),
        images: buildImageUrls(i),
        location,
        type: 'general',
        visibility: 'public',
        displayPublishedAt,
        createdAt,
        updatedAt: createdAt,
      },
      select: { id: true },
    });

    const likeUsers = pickManyUnique(interactionPool, randomInt(LIKE_MIN, LIKE_MAX));
    const saveUsers = pickManyUnique(interactionPool, randomInt(SAVE_MIN, SAVE_MAX));
    const repostUsers = pickManyUnique(interactionPool, randomInt(REPOST_MIN, REPOST_MAX));
    const shareUsers = pickManyUnique(interactionPool, randomInt(SHARE_MIN, SHARE_MAX));

    if (likeUsers.length > 0) {
      await prisma.postLike.createMany({
        data: likeUsers.map((user) => ({
          postId: post.id,
          userId: user.id,
          createdAt: new Date(createdAt.getTime() + randomInt(5, 240) * 60 * 1000),
        })),
        skipDuplicates: true,
      });
    }

    if (saveUsers.length > 0) {
      await prisma.postSave.createMany({
        data: saveUsers.map((user) => ({
          postId: post.id,
          userId: user.id,
          createdAt: new Date(createdAt.getTime() + randomInt(10, 720) * 60 * 1000),
        })),
        skipDuplicates: true,
      });
    }

    if (repostUsers.length > 0) {
      await prisma.postRepost.createMany({
        data: repostUsers.map((user) => ({
          postId: post.id,
          userId: user.id,
          createdAt: new Date(createdAt.getTime() + randomInt(15, 900) * 60 * 1000),
        })),
        skipDuplicates: true,
      });
    }

    if (shareUsers.length > 0) {
      await prisma.postShare.createMany({
        data: shareUsers.map((user) => ({
          postId: post.id,
          userId: user.id,
          channel: pickOne(['system', 'copy_link', 'wechat', 'moments', 'instagram']),
          status: 'completed',
          createdAt: new Date(createdAt.getTime() + randomInt(30, 1200) * 60 * 1000),
        })),
      });
    }

    const commentCount = randomInt(COMMENT_MIN, COMMENT_MAX);
    const commentsData = Array.from({ length: commentCount }).map((_, idx) => {
      const commenter = pickOne(interactionPool);
      const commentCreatedAt = new Date(createdAt.getTime() + randomInt(20, 2400) * 60 * 1000 + idx * 2000);
      return {
        postId: post.id,
        userId: commenter.id,
        content: buildCommentContent(idx + i),
        createdAt: commentCreatedAt,
        updatedAt: commentCreatedAt,
      };
    });

    await prisma.postComment.createMany({ data: commentsData });

    await prisma.post.update({
      where: { id: post.id },
      data: {
        likeCount: likeUsers.length,
        repostCount: repostUsers.length,
        saveCount: saveUsers.length,
        shareCount: shareUsers.length,
        commentCount: commentCount,
      },
    });

    totalPosts += 1;
    totalLikes += likeUsers.length;
    totalSaves += saveUsers.length;
    totalReposts += repostUsers.length;
    totalShares += shareUsers.length;
    totalComments += commentCount;

    if ((i + 1) % 10 === 0 || i + 1 === POST_TARGET) {
      console.log(`[seed-rich-feed] progress ${i + 1}/${POST_TARGET}`);
    }
  }

  console.log('[seed-rich-feed] done');
  console.log('[seed-rich-feed] summary', {
    totalPosts,
    totalLikes,
    totalSaves,
    totalReposts,
    totalShares,
    totalComments,
  });
};

run()
  .catch((error) => {
    console.error('[seed-rich-feed] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
