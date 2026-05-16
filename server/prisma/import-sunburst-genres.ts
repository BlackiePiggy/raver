import fs from 'fs';
import path from 'path';
import { PrismaClient } from '@prisma/client';

type RawGenreNode = {
  id: string;
  name: string;
  path: string;
  description?: string;
  descriptionI18n?: TriText;
  example?: string;
  exampleI18n?: TriText;
  spotifyTrackURL?: string;
  wikipediaURL?: string;
  keyArtists?: string[];
  children?: RawGenreNode[];
};

type TriText = {
  en: string;
  zh: string;
  ja: string;
};

type FlatGenreNode = RawGenreNode & {
  parentId: string | null;
  sortOrder: number;
};

const prisma = new PrismaClient();

const DEFAULT_INPUT_PATH = path.resolve(
  __dirname,
  '../../thirdparty/SwiftSunburstPrototype/Sources/SunburstPreview/Resources/genres_tree.json'
);

const readInputPath = (): string => {
  const argIndex = process.argv.findIndex((arg) => arg === '--input' || arg === '-i');
  if (argIndex >= 0 && process.argv[argIndex + 1]) {
    return path.resolve(process.argv[argIndex + 1]);
  }
  return process.env.SUNBURST_GENRES_JSON
    ? path.resolve(process.env.SUNBURST_GENRES_JSON)
    : DEFAULT_INPUT_PATH;
};

const safeString = (value: unknown): string | null => {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
};

const slugFromId = (id: string): string =>
  id
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '') || 'genre';

const normalizeTriText = (value: unknown, fallback: string, name: string, field: 'description' | 'example'): TriText | null => {
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    const row = value as Record<string, unknown>;
    const en = safeString(row.en) || fallback;
    const zh = safeString(row.zh) || safeString(row.cn) || en;
    const ja = safeString(row.ja) || safeString(row.jp) || en;
    if (!en && !zh && !ja) return null;
    return { en: en || zh || ja, zh: zh || en || ja, ja: ja || en || zh };
  }

  const en = fallback;
  if (!en && !name) return null;
  if (field === 'example') {
    const cue = en || name;
    return {
      en: cue,
      zh: cue ? `参考曲目：${cue}` : '',
      ja: cue ? `参考トラック：${cue}` : '',
    };
  }
  if (!en) {
    return {
      en: `${name} is part of the electronic music genre tree.`,
      zh: `${name} 是电子音乐流派树中的一个节点，可在这里补充更完整的中文介绍。`,
      ja: `${name} はエレクトロニック・ミュージックのジャンルツリーに含まれる項目です。ここで日本語の説明を編集できます。`,
    };
  }
  return {
    en,
    zh: `${name} 是电子音乐流派树中的一个风格。这个版本保留原始资料的声音线索，便于后续精修：${en}`,
    ja: `${name} はエレクトロニック・ミュージックのジャンルツリーに含まれるスタイルです。後から調整しやすいよう、元の説明を手掛かりとして保持しています：${en}`,
  };
};

const flattenTree = (
  node: RawGenreNode,
  parentId: string | null,
  sortOrder: number,
  output: FlatGenreNode[]
): void => {
  output.push({ ...node, parentId, sortOrder });
  (node.children ?? []).forEach((child, index) => {
    flattenTree(child, node.id, index, output);
  });
};

const assertValidNode: (value: unknown) => asserts value is RawGenreNode = (value) => {
  if (!value || typeof value !== 'object') {
    throw new Error('Genre JSON root must be an object.');
  }

  const node = value as Partial<RawGenreNode>;
  if (!safeString(node.id) || !safeString(node.name) || !safeString(node.path)) {
    throw new Error('Genre JSON nodes must include id, name, and path.');
  }
};

const main = async (): Promise<void> => {
  const inputPath = readInputPath();
  const raw: unknown = JSON.parse(fs.readFileSync(inputPath, 'utf8'));
  assertValidNode(raw);

  const flatNodes: FlatGenreNode[] = [];
  flattenTree(raw, null, 0, flatNodes);

  const ids = new Set<string>();
  for (const node of flatNodes) {
    if (ids.has(node.id)) {
      throw new Error(`Duplicate genre id: ${node.id}`);
    }
    ids.add(node.id);
  }

  await prisma.$transaction(async (tx) => {
    await tx.genre.deleteMany({});

    for (const node of flatNodes) {
      await tx.genre.create({
        data: {
          id: node.id,
          name: node.name.trim(),
          slug: slugFromId(node.id),
          path: node.path.trim(),
          description: safeString(node.description),
          descriptionI18n: normalizeTriText(node.descriptionI18n, safeString(node.description) ?? '', node.name.trim(), 'description'),
          example: safeString(node.example),
          exampleI18n: normalizeTriText(node.exampleI18n, safeString(node.example) ?? '', node.name.trim(), 'example'),
          spotifyTrackUrl: safeString(node.spotifyTrackURL),
          wikipediaUrl: safeString(node.wikipediaURL),
          keyArtists: Array.isArray(node.keyArtists)
            ? node.keyArtists.map((artist) => artist.trim()).filter(Boolean)
            : [],
          parentId: node.parentId,
          sortOrder: node.sortOrder,
        },
      });
    }
  });

  console.log(`Imported ${flatNodes.length} sunburst genre nodes from ${inputPath}`);
};

main()
  .catch((error) => {
    console.error('Import sunburst genres failed:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
