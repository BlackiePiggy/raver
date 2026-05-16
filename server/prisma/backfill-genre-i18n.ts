import { Prisma, PrismaClient } from '@prisma/client';

type TriText = {
  en: string;
  zh: string;
  ja: string;
};

const prisma = new PrismaClient();
const translationCache = new Map<string, string>();
const REQUEST_DELAY_MS = Math.max(0, Number(process.env.GENRE_I18N_TRANSLATE_DELAY_MS || 250));
const REQUEST_TIMEOUT_MS = Math.max(5000, Number(process.env.GENRE_I18N_TRANSLATE_TIMEOUT_MS || 20000));
const FORCE_TRANSLATE = process.env.GENRE_I18N_FORCE_TRANSLATE === '1';
const TRANSLATION_PROVIDER = safeText(process.env.GENRE_I18N_TRANSLATION_PROVIDER).toLowerCase();

const safeText = (value: unknown): string => {
  if (typeof value !== 'string') return '';
  const text = value.trim();
  return /^\[object\s+object\]$/i.test(text) ? '' : text;
};

const readTriText = (value: unknown): Partial<TriText> => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return {};
  const row = value as Record<string, unknown>;
  return {
    en: safeText(row.en ?? row.EN ?? row.english),
    zh: safeText(row.zh ?? row.ZH ?? row.cn ?? row.chinese),
    ja: safeText(row.ja ?? row.JA ?? row.jp ?? row.japanese),
  };
};

const buildDescription = (
  name: string,
  path: string,
  source: string,
  existing: unknown
): TriText => {
  const current = readTriText(existing);
  const en = current.en || source || `${name} is part of the electronic music genre tree.`;
  const pathText = path ? `（层级：${path.replace(/\s*>\s*/g, ' / ')}）` : '';
  const pathTextJa = path ? `（階層：${path.replace(/\s*>\s*/g, ' / ')}）` : '';
  return {
    en,
    zh: current.zh || (
      source
        ? `${name} 是电子音乐流派树中的一个风格${pathText}。它的中文介绍已先以原始英文资料为基础落库，后续可在 Genre 管理页继续精修：${source}`
        : `${name} 是电子音乐流派树中的一个节点${pathText}，可在 Genre 管理页继续补充完整中文介绍。`
    ),
    ja: current.ja || (
      source
        ? `${name} はエレクトロニック・ミュージックのジャンルツリーに含まれるスタイルです${pathTextJa}。日本語説明は元の英語資料を手掛かりとして保存しており、Genre 管理画面でさらに調整できます：${source}`
        : `${name} はエレクトロニック・ミュージックのジャンルツリーに含まれる項目です${pathTextJa}。Genre 管理画面で日本語説明を追記できます。`
    ),
  };
};

const buildExample = (source: string, existing: unknown): TriText | null => {
  const current = readTriText(existing);
  const en = current.en || source;
  if (!en && !current.zh && !current.ja) return null;
  return {
    en,
    zh: current.zh || (en ? `参考曲目：${en}` : ''),
    ja: current.ja || (en ? `参考トラック：${en}` : ''),
  };
};

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

const splitForTranslation = (text: string, maxLength = 450): string[] => {
  const source = safeText(text);
  if (!source) return [];
  if (source.length <= maxLength) return [source];
  const parts: string[] = [];
  let current = '';
  const sentences = source.match(/[^.!?。！？]+[.!?。！？]?/g) || [source];
  for (const sentenceRaw of sentences) {
    const sentence = sentenceRaw.trim();
    if (!sentence) continue;
    if (sentence.length > maxLength) {
      if (current) {
        parts.push(current.trim());
        current = '';
      }
      for (let i = 0; i < sentence.length; i += maxLength) {
        parts.push(sentence.slice(i, i + maxLength).trim());
      }
      continue;
    }
    const next = current ? `${current} ${sentence}` : sentence;
    if (next.length > maxLength) {
      if (current) parts.push(current.trim());
      current = sentence;
    } else {
      current = next;
    }
  }
  if (current) parts.push(current.trim());
  return parts;
};

const translateChunk = async (text: string, target: 'zh-CN' | 'ja'): Promise<string> => {
  const source = safeText(text);
  if (!source) return '';
  const cacheKey = `${target}::${source}`;
  if (translationCache.has(cacheKey)) return translationCache.get(cacheKey) || '';

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  try {
    const url = `https://api.mymemory.translated.net/get?q=${encodeURIComponent(source)}&langpair=en|${encodeURIComponent(target)}`;
    const response = await fetch(url, {
      method: 'GET',
      signal: controller.signal,
      headers: {
        Accept: 'application/json',
        'User-Agent': 'raver-genre-i18n-backfill/1.0',
      },
    });
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }
    const payload = await response.json() as {
      responseStatus?: number;
      responseData?: { translatedText?: string };
      responseDetails?: string;
    };
    if (payload.responseStatus !== 200) {
      throw new Error(payload.responseDetails || `status ${payload.responseStatus || 'unknown'}`);
    }
    const translated = safeText(payload.responseData?.translatedText) || source;
    translationCache.set(cacheKey, translated);
    if (REQUEST_DELAY_MS > 0) await sleep(REQUEST_DELAY_MS);
    return translated;
  } finally {
    clearTimeout(timeout);
  }
};

const translateText = async (text: string, target: 'zh-CN' | 'ja'): Promise<string> => {
  if (TRANSLATION_PROVIDER !== 'mymemory') {
    throw new Error('GENRE_I18N_TRANSLATION_PROVIDER is not configured. Refusing to call external translation services.');
  }
  const chunks = splitForTranslation(text);
  if (!chunks.length) return '';
  const translated = [];
  for (const chunk of chunks) {
    translated.push(await translateChunk(chunk, target));
  }
  return translated.join(target === 'ja' ? '' : '');
};

const needsRealTranslation = (value: string, locale: 'zh' | 'ja'): boolean => {
  const text = safeText(value);
  if (!text) return true;
  if (locale === 'zh') {
    return /后续可在 Genre 管理页继续精修|电子音乐流派树|参考曲目：/.test(text);
  }
  return /Genre 管理画面|エレクトロニック・ミュージックのジャンルツリー|参考トラック：/.test(text);
};

const main = async (): Promise<void> => {
  const force = process.env.GENRE_I18N_FORCE === '1';
  const genres = await prisma.genre.findMany({
    orderBy: [{ parentId: 'asc' }, { sortOrder: 'asc' }, { name: 'asc' }],
    select: {
      id: true,
      name: true,
      path: true,
      description: true,
      descriptionI18n: true,
      example: true,
      exampleI18n: true,
    },
  });

  let updated = 0;
  for (const genre of genres) {
    const description = buildDescription(
      genre.name,
      genre.path,
      safeText(genre.description),
      force ? null : genre.descriptionI18n
    );
    const example = buildExample(safeText(genre.example), force ? null : genre.exampleI18n);

    if (FORCE_TRANSLATE || needsRealTranslation(description.zh, 'zh')) {
      description.zh = await translateText(description.en, 'zh-CN');
    }
    if (FORCE_TRANSLATE || needsRealTranslation(description.ja, 'ja')) {
      description.ja = await translateText(description.en, 'ja');
    }
    if (example?.en) {
      if (FORCE_TRANSLATE || needsRealTranslation(example.zh, 'zh')) {
        example.zh = await translateText(example.en, 'zh-CN');
      }
      if (FORCE_TRANSLATE || needsRealTranslation(example.ja, 'ja')) {
        example.ja = await translateText(example.en, 'ja');
      }
    }

    await prisma.genre.update({
      where: { id: genre.id },
      data: {
        descriptionI18n: description as unknown as Prisma.InputJsonValue,
        exampleI18n: example ? (example as unknown as Prisma.InputJsonValue) : Prisma.DbNull,
      },
    });
    updated += 1;
    if (updated % 10 === 0 || updated === genres.length) {
      console.log(`Translated ${updated}/${genres.length} genres...`);
    }
  }

  console.log(`Backfilled i18n text for ${updated} genres.`);
};

main()
  .catch((error) => {
    console.error('Backfill genre i18n failed:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
