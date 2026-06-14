import dotenv from 'dotenv';
import { PrismaClient, Prisma } from '@prisma/client';

dotenv.config();

const prisma = new PrismaClient();

const GENRE_ID = 'electronica';
const PARENT_ID = 'electronic-music';

const payload = {
  id: GENRE_ID,
  name: 'Electronica',
  nameI18n: {
    zh: 'Electronica',
    en: 'Electronica',
    ja: 'エレクトロニカ',
  },
  slug: 'electronica',
  path: 'Electronic Music/electronica',
  parentId: PARENT_ID,
  sortOrder: 14,
  color: '#7EC6C2',
  description:
    'Electronica 是一个偏聆听取向的电子音乐大类，通常强调细腻的声音设计、层次丰富的合成器纹理、氛围感与节奏之间的平衡，而不一定完全以舞池功能为核心。它在 1990 年代成为相对固定的标签，常被用来描述介于 IDM、Downtempo、Ambient、Electro-pop 与实验电子之间、既有电子制作语言又更适合专注聆听的作品。',
  descriptionI18n: {
    zh:
      'Electronica 是一个偏聆听取向的电子音乐大类，通常强调细腻的声音设计、层次丰富的合成器纹理、氛围感与节奏之间的平衡，而不一定完全以舞池功能为核心。它在 1990 年代成为相对固定的标签，常被用来描述介于 IDM、Downtempo、Ambient、Electro-pop 与实验电子之间、既有电子制作语言又更适合专注聆听的作品。',
    en:
      'Electronica is a broad, listening-oriented branch of electronic music that emphasizes detailed sound design, layered synthesizer textures, and a balance between atmosphere and rhythm rather than purely dancefloor functionality. The term became widely used in the 1990s to describe music that sits between IDM, downtempo, ambient, electro-pop, and experimental electronic styles: distinctly electronic in production, but often better suited to focused listening than peak-time club use.',
    ja:
      'Electronica は、ダンスフロア機能だけを主軸にするのではなく、緻密なサウンドデザイン、重なり合うシンセの質感、雰囲気とリズムのバランスを重視する、リスニング寄りのエレクトロニック・ミュージックの大きな領域です。1990 年代以降に定着した呼び名で、IDM、Downtempo、Ambient、Electro-pop、実験電子音楽のあいだに位置するような、電子的な制作言語を持ちながらも集中して聴く体験に向いた作品群を指すことが多いです。',
  },
  example: 'Boards of Canada - Dayvan Cowboy',
  exampleI18n: {
    zh: '参考曲目：Boards of Canada - Dayvan Cowboy',
    en: 'Boards of Canada - Dayvan Cowboy',
    ja: '参考トラック：Boards of Canada - Dayvan Cowboy',
  },
  origin: '英国 / 美国',
  era: '1990s',
  bpm: '90–125',
  wikipediaUrl: 'https://en.wikipedia.org/wiki/Electronica',
  keyArtists: ['Boards of Canada', 'Four Tet', 'Caribou'],
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

  console.log('[upsert-electronica-genre-node] done', upserted);
}

main()
  .catch((error) => {
    console.error('[upsert-electronica-genre-node] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
