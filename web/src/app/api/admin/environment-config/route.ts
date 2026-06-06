import fs from 'fs';
import { NextResponse } from 'next/server';
import { resolveAdminEnvFilePaths } from '@/lib/server/env-file-paths';

export const runtime = 'nodejs';

type EnvFileTarget = 'server/.env' | 'web/.env.local';
type EffectiveScope = 'server_runtime' | 'web_runtime';

type ConfigFieldDefinition = {
  key: string;
  label: string;
  placeholder?: string;
  secret?: boolean;
  multiline?: boolean;
  description?: string;
  envFile: EnvFileTarget;
  effectiveScope: EffectiveScope;
  immediateEffect: boolean;
};

type ConfigSectionDefinition = {
  id: string;
  title: string;
  description: string;
  fields: ConfigFieldDefinition[];
};

const SECTION_DEFINITIONS: ConfigSectionDefinition[] = [
  {
    id: 'coze-workflows',
    title: 'Coze 工作流',
    description: 'Event 创建编辑流程里直接调用的 Coze 工作流配置，保存后新的导入请求会立即读取新值。',
    fields: [
      {
        key: 'COZE_TIMETABLE_WORKFLOW_RUN_URL',
        label: 'Timetable Run URL',
        envFile: 'server/.env',
        effectiveScope: 'server_runtime',
        immediateEffect: true,
      },
      {
        key: 'COZE_TIMETABLE_WORKFLOW_TOKEN',
        label: 'Timetable Token',
        envFile: 'server/.env',
        effectiveScope: 'server_runtime',
        immediateEffect: true,
        secret: true,
      },
      {
        key: 'COZE_TIMETABLE_WORKFLOW_TIMEOUT_MS',
        label: 'Timetable Timeout (ms)',
        envFile: 'server/.env',
        effectiveScope: 'server_runtime',
        immediateEffect: true,
      },
      {
        key: 'COZE_LINEUP_WORKFLOW_RUN_URL',
        label: 'Lineup Run URL',
        envFile: 'server/.env',
        effectiveScope: 'server_runtime',
        immediateEffect: true,
      },
      {
        key: 'COZE_LINEUP_WORKFLOW_TOKEN',
        label: 'Lineup Token',
        envFile: 'server/.env',
        effectiveScope: 'server_runtime',
        immediateEffect: true,
        secret: true,
      },
      {
        key: 'COZE_LINEUP_WORKFLOW_TIMEOUT_MS',
        label: 'Lineup Timeout (ms)',
        envFile: 'server/.env',
        effectiveScope: 'server_runtime',
        immediateEffect: true,
      },
      {
        key: 'COZE_POSTER_WORKFLOW_RUN_URL',
        label: 'Poster Run URL',
        envFile: 'server/.env',
        effectiveScope: 'server_runtime',
        immediateEffect: true,
      },
      {
        key: 'COZE_POSTER_WORKFLOW_TOKEN',
        label: 'Poster Token',
        envFile: 'server/.env',
        effectiveScope: 'server_runtime',
        immediateEffect: true,
        secret: true,
      },
      {
        key: 'COZE_POSTER_WORKFLOW_TIMEOUT_MS',
        label: 'Poster Timeout (ms)',
        envFile: 'server/.env',
        effectiveScope: 'server_runtime',
        immediateEffect: true,
      },
    ],
  },
  {
    id: 'coze-web-tools',
    title: 'Coze 辅助能力',
    description: 'Festival 翻译、DJ 字段翻译、地点规范化等 Web API route 使用的 Coze 配置，保存后新的请求会立即生效。',
    fields: [
      {
        key: 'COZE_TRANSLATE_RUN_URL',
        label: 'Festival Translate Run URL',
        envFile: 'web/.env.local',
        effectiveScope: 'web_runtime',
        immediateEffect: true,
      },
      {
        key: 'COZE_TOKEN_TRANSLATE',
        label: 'Festival Translate Token',
        envFile: 'web/.env.local',
        effectiveScope: 'web_runtime',
        immediateEffect: true,
        secret: true,
      },
      {
        key: 'COZE_TRANSLATE_TIMEOUT_MS',
        label: 'Festival Translate Timeout (ms)',
        envFile: 'web/.env.local',
        effectiveScope: 'web_runtime',
        immediateEffect: true,
      },
      {
        key: 'COZE_DJ_TRANS_RUN_URL',
        label: 'DJ Translate Run URL',
        envFile: 'web/.env.local',
        effectiveScope: 'web_runtime',
        immediateEffect: true,
      },
      {
        key: 'COZE_DJ_TRANS_TOKEN',
        label: 'DJ Translate Token',
        envFile: 'web/.env.local',
        effectiveScope: 'web_runtime',
        immediateEffect: true,
        secret: true,
      },
      {
        key: 'COZE_DJ_TRANS_TIMEOUT_MS',
        label: 'DJ Translate Timeout (ms)',
        envFile: 'web/.env.local',
        effectiveScope: 'web_runtime',
        immediateEffect: true,
      },
      {
        key: 'COZE_LOCATION_NORMALIZE_RUN_URL',
        label: 'Location Normalize Run URL',
        envFile: 'web/.env.local',
        effectiveScope: 'web_runtime',
        immediateEffect: true,
      },
      {
        key: 'COZE_LOCATION_NORMALIZE_TOKEN',
        label: 'Location Normalize Token',
        envFile: 'web/.env.local',
        effectiveScope: 'web_runtime',
        immediateEffect: true,
        secret: true,
      },
      {
        key: 'COZE_LOCATION_NORMALIZE_TIMEOUT_MS',
        label: 'Location Normalize Timeout (ms)',
        envFile: 'web/.env.local',
        effectiveScope: 'web_runtime',
        immediateEffect: true,
      },
    ],
  },
  {
    id: 'coze-shared',
    title: 'Coze 公共链接',
    description: 'Coze 返回资源地址、公开域名与加速域名配置。主要影响导入图片地址拼装和工作流可访问性。',
    fields: [
      {
        key: 'COZE_PUBLIC_BASE_URL',
        label: 'Coze Public Base URL',
        envFile: 'server/.env',
        effectiveScope: 'server_runtime',
        immediateEffect: true,
      },
      {
        key: 'COZE_OSS_ACCELERATE_BASE_URL',
        label: 'Coze OSS Accelerate Base URL',
        envFile: 'server/.env',
        effectiveScope: 'server_runtime',
        immediateEffect: true,
      },
      {
        key: 'COZE_DJ_ENRICH_RUN_URL',
        label: 'DJ Enrich Run URL',
        envFile: 'server/.env',
        effectiveScope: 'server_runtime',
        immediateEffect: true,
      },
      {
        key: 'COZE_DJ_ENRICH_TOKEN',
        label: 'DJ Enrich Token',
        envFile: 'server/.env',
        effectiveScope: 'server_runtime',
        immediateEffect: true,
        secret: true,
      },
      {
        key: 'COZE_DJ_ENRICH_TIMEOUT_MS',
        label: 'DJ Enrich Timeout (ms)',
        envFile: 'server/.env',
        effectiveScope: 'server_runtime',
        immediateEffect: true,
      },
    ],
  },
];

const FIELD_MAP = new Map(
  SECTION_DEFINITIONS.flatMap((section) => section.fields.map((field) => [field.key, field] as const))
);

const parseEnvText = (raw: string): Record<string, string> => {
  const out: Record<string, string> = {};
  for (const line of raw.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const equalIndex = trimmed.indexOf('=');
    if (equalIndex <= 0) continue;
    const key = trimmed.slice(0, equalIndex).trim();
    let value = trimmed.slice(equalIndex + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    out[key] = value;
  }
  return out;
};

const maskSecret = (value: string): string => {
  if (!value) return '';
  if (value.length <= 10) return '********';
  return `${value.slice(0, 4)}********${value.slice(-4)}`;
};

const readEnvFile = (filePath: string): Record<string, string> => {
  try {
    if (!fs.existsSync(filePath)) return {};
    return parseEnvText(fs.readFileSync(filePath, 'utf8'));
  } catch {
    return {};
  }
};

const serializeEnv = (entries: Record<string, string>): string =>
  `${Object.entries(entries)
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([key, value]) => `${key}=${String(value ?? '')}`)
    .join('\n')}\n`;

const resolveEnvPath = (target: EnvFileTarget): string => {
  const { serverEnvPath, webEnvPath } = resolveAdminEnvFilePaths();
  return target === 'server/.env' ? serverEnvPath : webEnvPath;
};

const buildResponse = (): {
  sections: Array<{
    id: string;
    title: string;
    description: string;
    fields: Array<{
      key: string;
      label: string;
      value: string;
      placeholder?: string;
      secret?: boolean;
      multiline?: boolean;
      description?: string;
      effectiveScope: EffectiveScope;
      envFile: EnvFileTarget;
      immediateEffect: boolean;
    }>;
  }>;
  summary: {
    saveWritesTo: EnvFileTarget[];
    immediateEffect: string[];
    restartRecommended: string[];
  };
} => {
  const serverEnv = readEnvFile(resolveEnvPath('server/.env'));
  const webEnv = readEnvFile(resolveEnvPath('web/.env.local'));

  return {
    sections: SECTION_DEFINITIONS.map((section) => ({
      ...section,
      fields: section.fields.map((field) => {
        const source = field.envFile === 'server/.env' ? serverEnv : webEnv;
        const rawValue = String(source[field.key] || '').trim();
        return {
          ...field,
          value: rawValue,
          displayValue: field.secret ? maskSecret(rawValue) : rawValue,
        };
      }),
    })),
    summary: {
      saveWritesTo: ['server/.env', 'web/.env.local'],
      immediateEffect: [
        'Event 的 Coze timetable / lineup / poster 导入新请求会立即读取新值',
        'Web 的 festival translate / DJ translate / location normalize 新请求会立即读取新值',
        'DJ enrich 主动调用新请求会立即读取新值',
      ],
      restartRecommended: [
        '不需要为这批 Coze 配置专门重启才能生效',
        '但如果你同时改了其它非运行时读取的环境变量，仍建议按原部署流程重启对应服务',
      ],
    },
  };
};

const readBearer = (request: Request): string => {
  const authorization = request.headers.get('authorization') || '';
  const match = authorization.match(/^Bearer\s+(.+)$/i);
  return match?.[1]?.trim() || '';
};

const ensureAdmin = async (request: Request): Promise<NextResponse | null> => {
  const token = readBearer(request);
  if (!token) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const profileResponse = await fetch('http://127.0.0.1:3901/v1/profile/me', {
    headers: {
      Authorization: `Bearer ${token}`,
    },
    cache: 'no-store',
  }).catch(() => null);

  if (!profileResponse || !profileResponse.ok) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const profile = (await profileResponse.json().catch(() => null)) as { role?: string } | null;
  if (profile?.role !== 'admin') {
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
  }

  return null;
};

export async function GET(request: Request) {
  const guard = await ensureAdmin(request);
  if (guard) return guard;
  return NextResponse.json(buildResponse(), {
    headers: { 'Cache-Control': 'no-store' },
  });
}

export async function PUT(request: Request) {
  const guard = await ensureAdmin(request);
  if (guard) return guard;

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON body' }, { status: 400 });
  }

  const values = body && typeof body === 'object' && !Array.isArray(body)
    ? (body as { values?: Record<string, unknown> }).values
    : null;

  if (!values || typeof values !== 'object' || Array.isArray(values)) {
    return NextResponse.json({ error: 'values is required' }, { status: 400 });
  }

  const serverEnvPath = resolveEnvPath('server/.env');
  const webEnvPath = resolveEnvPath('web/.env.local');
  const serverEnv = readEnvFile(serverEnvPath);
  const webEnv = readEnvFile(webEnvPath);

  for (const [key, rawValue] of Object.entries(values)) {
    const definition = FIELD_MAP.get(key);
    if (!definition) continue;
    const value = String(rawValue ?? '').trim();
    const targetEnv = definition.envFile === 'server/.env' ? serverEnv : webEnv;
    targetEnv[key] = value;
  }

  fs.writeFileSync(serverEnvPath, serializeEnv(serverEnv), 'utf8');
  fs.writeFileSync(webEnvPath, serializeEnv(webEnv), 'utf8');

  return NextResponse.json(buildResponse(), {
    headers: { 'Cache-Control': 'no-store' },
  });
}
