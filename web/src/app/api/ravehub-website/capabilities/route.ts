import { mkdir, readFile, writeFile } from 'fs/promises';
import path from 'path';
import { NextRequest, NextResponse } from 'next/server';

export const runtime = 'nodejs';

type CapabilityMediaType = 'image' | 'video';

type Capability = {
  id: string;
  title: string;
  description: string;
  accent: [string, string, string];
  glowColor: string;
  appScreen: string | null;
  appScreenType: CapabilityMediaType;
};

const webConfigPath = path.join(process.cwd(), 'public', 'ravehub-website', 'capabilities.json');
const standaloneConfigPath = path.resolve(process.cwd(), '..', 'thirdparty', 'ravehubhoutai', 'public', 'capabilities.json');

const isCapabilityMediaType = (value: unknown): value is CapabilityMediaType => (
  value === 'image' || value === 'video'
);

const asString = (value: unknown, fallback = '') => (
  typeof value === 'string' ? value : fallback
);

const normalizeAccent = (value: unknown): [string, string, string] => {
  if (!Array.isArray(value)) {
    return ['#06b6d4', '#14b8a6', '#10b981'];
  }

  return [
    asString(value[0], '#06b6d4'),
    asString(value[1], '#14b8a6'),
    asString(value[2], '#10b981'),
  ];
};

const normalizeCapabilities = (value: unknown): Capability[] => {
  if (!Array.isArray(value)) {
    throw new Error('配置必须是数组。');
  }

  const normalized = value.map((item, index) => {
    if (!item || typeof item !== 'object') {
      throw new Error(`第 ${index + 1} 项不是有效对象。`);
    }

    const source = item as Partial<Capability>;
    const appScreen = typeof source.appScreen === 'string' && source.appScreen.trim()
      ? source.appScreen.trim()
      : null;

    return {
      id: asString(source.id, String(index + 1).padStart(2, '0')),
      title: asString(source.title, '未命名模块'),
      description: asString(source.description),
      accent: normalizeAccent(source.accent),
      glowColor: asString(source.glowColor, 'rgba(6,182,212,0.4)'),
      appScreen,
      appScreenType: isCapabilityMediaType(source.appScreenType) ? source.appScreenType : 'image',
    };
  });

  if (normalized.length === 0) {
    throw new Error('至少需要保留一个功能展示模块。');
  }

  return normalized;
};

const writeConfig = async (items: Capability[]) => {
  const text = `${JSON.stringify(items, null, 2)}\n`;
  await Promise.all([
    mkdir(path.dirname(webConfigPath), { recursive: true }),
    mkdir(path.dirname(standaloneConfigPath), { recursive: true }),
  ]);
  await Promise.all([
    writeFile(webConfigPath, text, 'utf8'),
    writeFile(standaloneConfigPath, text, 'utf8'),
  ]);
};

export async function GET() {
  try {
    const text = await readFile(webConfigPath, 'utf8');
    return new NextResponse(text, {
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Cache-Control': 'no-store',
      },
    });
  } catch {
    return NextResponse.json({ error: '项目配置文件不存在。' }, { status: 404 });
  }
}

export async function POST(request: NextRequest) {
  try {
    const items = normalizeCapabilities(await request.json());
    await writeConfig(items);
    return NextResponse.json({ items });
  } catch (error) {
    const message = error instanceof Error ? error.message : '保存项目配置失败。';
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
