import dotenv from 'dotenv';
import { PrismaClient, Prisma } from '@prisma/client';

dotenv.config();

const prisma = new PrismaClient();

const GENRE_ID = 'house/electro-house/melbourne-bounce';
const PARENT_ID = 'house/electro-house';

const payload = {
  id: GENRE_ID,
  name: 'Melbourne Bounce',
  nameI18n: {
    zh: '墨尔本弹跳',
    en: 'Melbourne Bounce',
    ja: 'メルボルン・バウンス',
  },
  slug: 'melbourne-bounce',
  path: 'Electronic Music/house/house-electro-house/house-electro-house-melbourne-bounce',
  parentId: PARENT_ID,
  sortOrder: 2,
  color: '#F4A340',
  description:
    'Melbourne Bounce 是一种在 2010 年代初期流行起来的 Electro House 相关子流派，以强烈的弹跳感低音线、短促有力的切分节奏、洗脑式主旋律和直接面向大型派对现场的能量表达著称。它和 Big Room House 一样强调主舞台冲击力，但律动上更俏皮、更具反拍弹性，常见于 festival EDM 语境中的高能蹦跳段落。',
  descriptionI18n: {
    zh:
      'Melbourne Bounce 是一种在 2010 年代初期流行起来的 Electro House 相关子流派，以强烈的弹跳感低音线、短促有力的切分节奏、洗脑式主旋律和直接面向大型派对现场的能量表达著称。它和 Big Room House 一样强调主舞台冲击力，但律动上更俏皮、更具反拍弹性，常见于 festival EDM 语境中的高能蹦跳段落。',
    en:
      'Melbourne Bounce is an electro-house-adjacent style that rose to prominence in the early 2010s, known for its springy basslines, punchy syncopated grooves, chant-like hooks, and immediate festival-ready energy. Like Big Room House, it is built for maximum crowd impact, but its rhythmic feel is bouncier, cheekier, and more overtly playful, making it a defining sound of many mainstage EDM drops from that era.',
    ja:
      'Melbourne Bounce は 2010 年代初頭に広く浸透した、Electro House に近いサブジャンルです。弾むようなベースライン、歯切れの良いシンコペーション、耳に残るフック、そしてフェス向けの即効性の高いエネルギー感が特徴です。Big Room House と同様に大箱映えする衝撃力を持ちながら、より跳ねるリズム感と遊び心のあるグルーヴを備えています。',
  },
  example: 'Will Sparks - Ah Yeah!',
  exampleI18n: {
    zh: '参考曲目：Will Sparks - Ah Yeah!',
    en: 'Will Sparks - Ah Yeah!',
    ja: '参考トラック：Will Sparks - Ah Yeah!',
  },
  origin: '澳大利亚 / 墨尔本',
  era: '2010s',
  bpm: '126–130',
  wikipediaUrl: 'https://en.wikipedia.org/wiki/Melbourne_bounce',
  keyArtists: ['Will Sparks', 'Deorro', 'TJR'],
} as const;

async function main() {
  const parent = await prisma.genre.findUnique({
    where: { id: PARENT_ID },
    select: { id: true },
  });

  if (!parent) {
    throw new Error(`Parent genre "${PARENT_ID}" not found`);
  }

  const upserted = await prisma.genre.upsert({
    where: { id: GENRE_ID },
    create: {
      id: payload.id,
      name: payload.name,
      nameI18n: payload.nameI18n as unknown as Prisma.InputJsonValue,
      slug: payload.slug,
      path: payload.path,
      parentId: payload.parentId,
      sortOrder: payload.sortOrder,
      color: payload.color,
      description: payload.description,
      descriptionI18n: payload.descriptionI18n as unknown as Prisma.InputJsonValue,
      example: payload.example,
      exampleI18n: payload.exampleI18n as unknown as Prisma.InputJsonValue,
      origin: payload.origin,
      era: payload.era,
      bpm: payload.bpm,
      wikipediaUrl: payload.wikipediaUrl,
      keyArtists: [...payload.keyArtists],
    },
    update: {
      name: payload.name,
      nameI18n: payload.nameI18n as unknown as Prisma.InputJsonValue,
      slug: payload.slug,
      path: payload.path,
      parentId: payload.parentId,
      sortOrder: payload.sortOrder,
      color: payload.color,
      description: payload.description,
      descriptionI18n: payload.descriptionI18n as unknown as Prisma.InputJsonValue,
      example: payload.example,
      exampleI18n: payload.exampleI18n as unknown as Prisma.InputJsonValue,
      origin: payload.origin,
      era: payload.era,
      bpm: payload.bpm,
      wikipediaUrl: payload.wikipediaUrl,
      keyArtists: [...payload.keyArtists],
    },
    select: {
      id: true,
      name: true,
      path: true,
      parentId: true,
      sortOrder: true,
      color: true,
    },
  });

  console.log('[upsert-melbourne-bounce-genre-node] done', upserted);
}

main()
  .catch((error) => {
    console.error('[upsert-melbourne-bounce-genre-node] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
