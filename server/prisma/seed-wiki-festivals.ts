import { randomUUID } from 'node:crypto';
import { Prisma, PrismaClient } from '@prisma/client';

type LearnFestivalLinkSeed = {
  title: string;
  icon: string;
  url: string;
};

type LearnFestivalSeed = {
  id: string;
  name: string;
  aliases: string[];
  country: string;
  city: string;
  foundedYear: string;
  frequency: string;
  tagline: string;
  introduction: string;
  avatarUrl: string | null;
  backgroundUrl: string | null;
  links: LearnFestivalLinkSeed[];
};

const prisma = new PrismaClient();

const FESTIVAL_SEEDS: LearnFestivalSeed[] = [
  {
    id: 'tomorrowland',
    name: 'Tomorrowland',
    aliases: ['明日世界', 'TL'],
    country: '比利时',
    city: 'Boom',
    foundedYear: '2005',
    frequency: '每年 7 月',
    tagline: '全球最具辨识度的沉浸式 EDM 电音节之一。',
    introduction:
      'Tomorrowland 以大型主舞台叙事、超高制作和多舞台联动著称，覆盖 Mainstage、Techno、House、Trance 等多类电子音乐。',
    avatarUrl: 'https://logo.clearbit.com/tomorrowland.com',
    backgroundUrl:
      'https://images.unsplash.com/photo-1459749411175-04bf5292ceea?auto=format&fit=crop&w=1800&q=80',
    links: [
      { title: '官网', icon: 'globe', url: 'https://www.tomorrowland.com' },
      { title: 'Instagram', icon: 'camera', url: 'https://www.instagram.com/tomorrowland/' },
      { title: 'Wikipedia', icon: 'book', url: 'https://en.wikipedia.org/wiki/Tomorrowland_(festival)' },
    ],
  },
  {
    id: 'edc',
    name: 'Electric Daisy Carnival',
    aliases: ['EDC', 'EDC Las Vegas'],
    country: '美国',
    city: 'Las Vegas',
    foundedYear: '1997',
    frequency: '每年 5 月（拉斯维加斯站）',
    tagline: 'Insomniac 旗下头部 IP，视觉与舞美强调霓虹和嘉年华体验。',
    introduction:
      'EDC 在北美和全球拥有多站点，核心站点为 EDC Las Vegas，包含大量舞台和夜间演出，强调社区文化与沉浸体验。',
    avatarUrl: 'https://logo.clearbit.com/electricdaisycarnival.com',
    backgroundUrl:
      'https://images.unsplash.com/photo-1470229722913-7c0e2dbbafd3?auto=format&fit=crop&w=1800&q=80',
    links: [
      { title: '官网', icon: 'globe', url: 'https://lasvegas.electricdaisycarnival.com/' },
      { title: 'Instagram', icon: 'camera', url: 'https://www.instagram.com/edc_lasvegas/' },
      { title: 'Wikipedia', icon: 'book', url: 'https://en.wikipedia.org/wiki/Electric_Daisy_Carnival' },
    ],
  },
  {
    id: 'ultra',
    name: 'Ultra Music Festival',
    aliases: ['Ultra', 'UMF'],
    country: '美国',
    city: 'Miami',
    foundedYear: '1999',
    frequency: '每年 3 月',
    tagline: 'Miami 春季大秀，Mainstage 与 Resistance 双核心舞台体系。',
    introduction:
      'Ultra Music Festival 是全球电子音乐节标杆之一，Ultra Worldwide 在多个国家巡回举办，Miami 主站影响力最大。',
    avatarUrl: 'https://logo.clearbit.com/ultramusicfestival.com',
    backgroundUrl:
      'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&w=1800&q=80',
    links: [
      { title: '官网', icon: 'globe', url: 'https://ultramusicfestival.com' },
      { title: 'Instagram', icon: 'camera', url: 'https://www.instagram.com/ultra/' },
      { title: 'Wikipedia', icon: 'book', url: 'https://en.wikipedia.org/wiki/Ultra_Music_Festival' },
    ],
  },
  {
    id: 'soundstorm',
    name: 'MDLBEAST Soundstorm',
    aliases: ['Soundstorm', '利雅得 Soundstorm'],
    country: '沙特阿拉伯',
    city: 'Riyadh',
    foundedYear: '2019',
    frequency: '每年冬季',
    tagline: '中东地区高规格大型电子音乐节 IP。',
    introduction:
      'Soundstorm 由 MDLBEAST 打造，舞台规模和阵容体量增长迅速，已成为中东地区讨论度极高的电子音乐节。',
    avatarUrl: 'https://logo.clearbit.com/mdlbeast.com',
    backgroundUrl:
      'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=1800&q=80',
    links: [
      { title: '官网', icon: 'globe', url: 'https://mdlbeast.com' },
      { title: 'Instagram', icon: 'camera', url: 'https://www.instagram.com/soundstorm/' },
      { title: 'Wikipedia', icon: 'book', url: 'https://en.wikipedia.org/wiki/MDLBEAST' },
    ],
  },
  {
    id: 'creamfields',
    name: 'Creamfields',
    aliases: ['奶油田'],
    country: '英国',
    city: 'Daresbury（主站）',
    foundedYear: '1998',
    frequency: '每年夏季',
    tagline: '英国历史悠久的大型电子音乐节品牌。',
    introduction:
      'Creamfields 以 UK 大型户外电子音乐节体验著称，除英国主站外也发展出国际系列站点。',
    avatarUrl: 'https://logo.clearbit.com/creamfields.com',
    backgroundUrl:
      'https://images.unsplash.com/photo-1571266028243-d220c9c3b5f2?auto=format&fit=crop&w=1800&q=80',
    links: [
      { title: '官网', icon: 'globe', url: 'https://www.creamfields.com' },
      { title: 'Instagram', icon: 'camera', url: 'https://www.instagram.com/creamfieldsofficial/' },
      { title: 'Wikipedia', icon: 'book', url: 'https://en.wikipedia.org/wiki/Creamfields' },
    ],
  },
  {
    id: 'vac-music-festival',
    name: 'VAC Music Festival',
    aliases: ['VAC', 'VAC 电音节'],
    country: '中国',
    city: '多城市巡回',
    foundedYear: '近年兴起',
    frequency: '年度 / 季度站点',
    tagline: '中国本土电子音乐节 IP，强调国际阵容与本土场景融合。',
    introduction:
      'VAC Music Festival 聚焦国际电子音乐艺人与本土社群联动，通常包含多舞台与 Day 分场配置。',
    avatarUrl: 'https://logo.clearbit.com/vacmusicfestival.com',
    backgroundUrl:
      'https://images.unsplash.com/photo-1506157786151-b8491531f063?auto=format&fit=crop&w=1800&q=80',
    links: [{ title: '官网', icon: 'globe', url: 'https://www.vacmusicfestival.com' }],
  },
  {
    id: 'storm-festival',
    name: 'STORM Festival',
    aliases: ['Storm 风暴电音节', '风暴电音节'],
    country: '中国',
    city: '上海 / 多城市',
    foundedYear: '2010 年代',
    frequency: '年度站点',
    tagline: '中国大型电子音乐节品牌之一，覆盖多风格舞台。',
    introduction:
      'STORM Festival 在国内电子音乐场景中有较高认知度，阵容涵盖主流 EDM 与细分舞曲风格。',
    avatarUrl: 'https://logo.clearbit.com/stormfestival.cn',
    backgroundUrl:
      'https://images.unsplash.com/photo-1487180144351-b8472da7d491?auto=format&fit=crop&w=1800&q=80',
    links: [{ title: '官网', icon: 'globe', url: 'https://stormfestival.cn' }],
  },
  {
    id: 'tmc-festival',
    name: 'TMC Festival',
    aliases: ['TMC 电音节'],
    country: '中国',
    city: '多城市',
    foundedYear: '近年兴起',
    frequency: '年度站点',
    tagline: '面向年轻受众的本土电音节 IP。',
    introduction:
      'TMC Festival 以流行电子乐与现场体验为核心，常见多日程排布与跨风格艺人阵容。',
    avatarUrl: 'https://logo.clearbit.com/tmcfestival.com',
    backgroundUrl:
      'https://images.unsplash.com/photo-1429962714451-bb934ecdc4ec?auto=format&fit=crop&w=1800&q=80',
    links: [{ title: '官网', icon: 'globe', url: 'https://tmcfestival.com' }],
  },
];

async function main() {
  const username = process.env.WIKI_FESTIVAL_CONTRIBUTOR_USERNAME?.trim() || 'uploadtester';
  const preserveExistingMedia = process.env.WIKI_FESTIVAL_PRESERVE_EXISTING_MEDIA !== 'false';

  const user = await prisma.user.findUnique({
    where: { username },
    select: {
      id: true,
      username: true,
      displayName: true,
    },
  });

  if (!user) {
    throw new Error(`Cannot find user by username: ${username}`);
  }

  await prisma.$transaction(async (tx) => {
    for (const festival of FESTIVAL_SEEDS) {
      const existing = await tx.wikiFestival.findUnique({
        where: { id: festival.id },
        select: { avatarUrl: true, backgroundUrl: true },
      });

      const payload = {
        name: festival.name,
        aliases: festival.aliases,
        country: festival.country,
        city: festival.city,
        foundedYear: festival.foundedYear,
        frequency: festival.frequency,
        tagline: festival.tagline,
        introduction: festival.introduction,
        avatarUrl: preserveExistingMedia && existing?.avatarUrl ? existing.avatarUrl : festival.avatarUrl,
        backgroundUrl:
          preserveExistingMedia && existing?.backgroundUrl ? existing.backgroundUrl : festival.backgroundUrl,
        links: festival.links as unknown as Prisma.InputJsonValue,
        isActive: true,
      };

      await tx.wikiFestival.upsert({
        where: { id: festival.id },
        create: {
          id: festival.id,
          ...payload,
        },
        update: payload,
      });
    }

    const allFestivalIDs = (await tx.wikiFestival.findMany({
      select: { id: true },
    })).map((item) => item.id);

    await tx.wikiFestivalContributor.deleteMany({
      where: {
        festivalId: {
          in: allFestivalIDs,
        },
      },
    });

    if (allFestivalIDs.length > 0) {
      await tx.wikiFestivalContributor.createMany({
        data: allFestivalIDs.map((festivalId) => ({
          id: randomUUID(),
          festivalId,
          userId: user.id,
        })),
      });
    }
  });

  const totalFestivals = await prisma.wikiFestival.count();
  const totalContributors = await prisma.wikiFestivalContributor.count();

  console.log(
    `Wiki festivals synced: ${totalFestivals}. Contributors reset to @${user.username} (${user.displayName || user.username}), rows: ${totalContributors}.`
  );
}

main()
  .catch((error) => {
    console.error('Failed to seed wiki festivals:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
