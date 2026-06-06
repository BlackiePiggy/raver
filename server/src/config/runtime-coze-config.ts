import fs from 'fs';
import path from 'path';
import { parse } from 'dotenv';

const resolveServerEnvFile = (): string => {
  const cwd = process.cwd();
  const candidates = [
    path.resolve(cwd, '.env'),
    path.resolve(cwd, 'server', '.env'),
    path.resolve(cwd, '..', 'server', '.env'),
  ];

  for (const candidate of candidates) {
    try {
      if (fs.existsSync(candidate)) {
        return candidate;
      }
    } catch {
      continue;
    }
  }

  return candidates[0];
};

const cleanEnv = (value: string | undefined | null): string | null => {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
};

const readServerEnvFile = (): Record<string, string> => {
  try {
    const serverEnvFile = resolveServerEnvFile();
    if (!fs.existsSync(serverEnvFile)) return {};
    return parse(fs.readFileSync(serverEnvFile, 'utf8'));
  } catch {
    return {};
  }
};

const resolveRuntimeEnvValue = (envFileValues: Record<string, string>, keys: string[]): string | undefined => {
  for (const key of keys) {
    if (Object.prototype.hasOwnProperty.call(envFileValues, key)) {
      return envFileValues[key];
    }
  }
  for (const key of keys) {
    if (Object.prototype.hasOwnProperty.call(process.env, key)) {
      return process.env[key];
    }
  }
  return undefined;
};

const parseCozeTimeoutMs = (value: unknown, fallback: number): number => {
  const parsed = Number(value);
  if (Number.isFinite(parsed) && parsed >= 10_000 && parsed <= 600_000) {
    return Math.floor(parsed);
  }
  return fallback;
};

export type ServerCozeRuntimeConfig = {
  timetable: {
    runUrl: string | null;
    token: string | null;
    timeoutMs: number;
  };
  lineup: {
    runUrl: string | null;
    token: string | null;
    timeoutMs: number;
  };
  poster: {
    runUrl: string | null;
    token: string | null;
    timeoutMs: number;
  };
  djEnrich: {
    runUrl: string | null;
    token: string | null;
    timeoutMs: number;
  };
  publicBaseUrl: string | null;
  ossAccelerateBaseUrl: string | null;
};

export const getServerCozeRuntimeConfig = (
  options?: {
    ossBucket?: string | null;
  }
): ServerCozeRuntimeConfig => {
  const envFileValues = readServerEnvFile();
  const readValue = (...keys: string[]) => resolveRuntimeEnvValue(envFileValues, keys);

  const ossBucket = cleanEnv(options?.ossBucket) || cleanEnv(readValue('OSS_BUCKET'));
  const explicitAccelerateBaseUrl = cleanEnv(
    readValue(
      'COZE_OSS_ACCELERATE_BASE_URL',
      'OSS_ACCELERATE_BASE_URL',
      'COZE_ACCELERATE_OSS_BASE_URL'
    )
  );

  return {
    timetable: {
      runUrl: cleanEnv(readValue('COZE_TIMETABLE_WORKFLOW_RUN_URL')),
      token: cleanEnv(readValue('COZE_TIMETABLE_WORKFLOW_TOKEN')),
      timeoutMs: parseCozeTimeoutMs(readValue('COZE_TIMETABLE_WORKFLOW_TIMEOUT_MS'), 480_000),
    },
    lineup: {
      runUrl: cleanEnv(readValue('COZE_LINEUP_WORKFLOW_RUN_URL')),
      token: cleanEnv(readValue('COZE_LINEUP_WORKFLOW_TOKEN')),
      timeoutMs: parseCozeTimeoutMs(readValue('COZE_LINEUP_WORKFLOW_TIMEOUT_MS'), 480_000),
    },
    poster: {
      runUrl: cleanEnv(readValue('COZE_POSTER_WORKFLOW_RUN_URL')),
      token: cleanEnv(readValue('COZE_POSTER_WORKFLOW_TOKEN')),
      timeoutMs: parseCozeTimeoutMs(readValue('COZE_POSTER_WORKFLOW_TIMEOUT_MS'), 480_000),
    },
    djEnrich: {
      runUrl: cleanEnv(readValue('COZE_DJ_ENRICH_RUN_URL')) || 'https://wd6gv5pg6k.coze.site/run',
      token: cleanEnv(readValue('COZE_DJ_ENRICH_TOKEN', 'COZE_WORKFLOW_TOKEN')),
      timeoutMs: parseCozeTimeoutMs(readValue('COZE_DJ_ENRICH_TIMEOUT_MS'), 120_000),
    },
    publicBaseUrl: cleanEnv(
      readValue('COZE_PUBLIC_BASE_URL', 'PUBLIC_API_BASE_URL', 'PUBLIC_BASE_URL')
    ),
    ossAccelerateBaseUrl:
      explicitAccelerateBaseUrl?.replace(/\/+$/g, '') ||
      (ossBucket ? `https://${ossBucket}.oss-accelerate.aliyuncs.com` : null),
  };
};
