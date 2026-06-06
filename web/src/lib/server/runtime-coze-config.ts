import fs from 'fs';
import path from 'path';

const WEB_ENV_FILE = path.resolve(process.cwd(), '.env.local');
const SERVER_ENV_FILE = path.resolve(process.cwd(), '..', 'server', '.env');

const cleanText = (value: string | undefined | null): string => String(value || '').trim();

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

const readEnvFile = (filePath: string): Record<string, string> => {
  try {
    if (!fs.existsSync(filePath)) return {};
    return parseEnvText(fs.readFileSync(filePath, 'utf8'));
  } catch {
    return {};
  }
};

const resolveValue = (keys: string[], ...sources: Array<Record<string, string> | NodeJS.ProcessEnv>): string => {
  for (const key of keys) {
    for (const source of sources) {
      const value = source[key];
      if (typeof value === 'string') return value;
    }
  }
  return '';
};

const parseTimeoutMs = (value: string, fallback: number): number => {
  const parsed = Number(value);
  if (Number.isFinite(parsed) && parsed > 0) {
    return parsed < 1000 ? Math.floor(parsed * 1000) : Math.floor(parsed);
  }
  return fallback;
};

export type WebCozeRuntimeConfig = {
  festivalTranslate: {
    runUrl: string;
    token: string;
    timeoutMs: number;
  };
  djTranslate: {
    runUrl: string;
    token: string;
    timeoutMs: number;
  };
  locationNormalize: {
    runUrl: string;
    token: string;
    timeoutMs: number;
  };
};

export const getWebCozeRuntimeConfig = (): WebCozeRuntimeConfig => {
  const webEnv = readEnvFile(WEB_ENV_FILE);
  const serverEnv = readEnvFile(SERVER_ENV_FILE);

  const fallbackWorkflowToken = cleanText(
    resolveValue(
      ['COZE_WORKFLOW_TOKEN', 'COZE_TIMETABLE_WORKFLOW_TOKEN', 'COZE_LINEUP_WORKFLOW_TOKEN'],
      webEnv,
      serverEnv,
      process.env
    )
  );
  const fallbackTranslateToken = cleanText(
    resolveValue(['COZE_TOKEN_TRANSLATE'], webEnv, serverEnv, process.env)
  ) || fallbackWorkflowToken;

  return {
    festivalTranslate: {
      runUrl: cleanText(resolveValue(['COZE_TRANSLATE_RUN_URL'], webEnv, serverEnv, process.env)),
      token: fallbackTranslateToken,
      timeoutMs: parseTimeoutMs(
        cleanText(resolveValue(['COZE_TRANSLATE_TIMEOUT_MS', 'COZE_TRANSLATE_TIMEOUT_SEC'], webEnv, serverEnv, process.env)),
        90_000
      ),
    },
    djTranslate: {
      runUrl: cleanText(resolveValue(['COZE_DJ_TRANS_RUN_URL'], webEnv, serverEnv, process.env)),
      token:
        cleanText(resolveValue(['COZE_DJ_TRANS_TOKEN', 'COZE_TOKEN_DJ_TRANS'], webEnv, serverEnv, process.env)) ||
        fallbackTranslateToken,
      timeoutMs: parseTimeoutMs(
        cleanText(resolveValue(['COZE_DJ_TRANS_TIMEOUT_MS', 'COZE_DJ_TRANS_TIMEOUT_SEC'], webEnv, serverEnv, process.env)),
        90_000
      ),
    },
    locationNormalize: {
      runUrl: cleanText(resolveValue(['COZE_LOCATION_NORMALIZE_RUN_URL'], webEnv, serverEnv, process.env)),
      token:
        cleanText(resolveValue(['COZE_LOCATION_NORMALIZE_TOKEN', 'COZE_TOKEN_LOCATION_NORMALIZE'], webEnv, serverEnv, process.env)) ||
        fallbackTranslateToken,
      timeoutMs: parseTimeoutMs(
        cleanText(
          resolveValue(
            ['COZE_LOCATION_NORMALIZE_TIMEOUT_MS', 'COZE_LOCATION_NORMALIZE_TIMEOUT_SEC'],
            webEnv,
            serverEnv,
            process.env
          )
        ),
        90_000
      ),
    },
  };
};
